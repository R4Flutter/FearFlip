import { beforeAll, describe, expect, it } from 'vitest';
import { bytes, checkRun, reach, spki, verifyToken } from '../src/checks.js';
import data from '../src/weeks.json';
import theirKey from './crazygames_public_key.json';
import route from './route.json';
import { makeKeys, sign, walk } from './helpers.js';

const rules = data.rules;
const NOW = 1_800_000_000;

describe('the CrazyGames token', () => {
	const user = { userId: 'UOuZBKgjwpY9k4TSBB2NPugbsHD3', gameId: '20267', username: 'RustyCake.ZU9H', iat: NOW - 60, exp: NOW + 3600 };
	let keys;
	let old;
	const theirs = async () => keys.pem;
	beforeAll(async () => {
		keys = await makeKeys();
		old = await makeKeys();
	});

	it('says who sent a run', async () => {
		const payload = await verifyToken(await sign(keys.privateKey, user), theirs, NOW, '20267');
		expect(payload?.userId).toBe(user.userId);
		expect(payload?.username).toBe('RustyCake.ZU9H');
	});

	it('reads the key as CrazyGames publishes it (PKCS#1), and SPKI too', async () => {
		const key = await crypto.subtle.importKey('spki', spki(theirKey.publicKey), { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
		expect(key.algorithm.modulusLength, 'their real key, fetched 16 Oct 2026').toBe(4096);
		expect((await verifyToken(await sign(keys.privateKey, user), async () => keys.spkiPem, NOW))?.userId).toBe(user.userId);
	});

	it("refuses an expired token, another game's, and one without a user", async () => {
		expect(await verifyToken(await sign(keys.privateKey, { ...user, exp: NOW - 1 }), theirs, NOW)).toBeNull();
		expect(await verifyToken(await sign(keys.privateKey, { ...user, gameId: '999' }), theirs, NOW, '20267')).toBeNull();
		expect(await verifyToken(await sign(keys.privateKey, { ...user, userId: '' }), theirs, NOW)).toBeNull();
	});

	it('refuses a forged signature, a changed payload, alg none and junk', async () => {
		expect(await verifyToken(await sign(old.privateKey, user), theirs, NOW)).toBeNull();
		const [head, , sig] = (await sign(keys.privateKey, user)).split('.');
		const someoneElse = btoa(JSON.stringify({ ...user, userId: 'someone-else' })).replace(/=+$/, '');
		expect(await verifyToken(`${head}.${someoneElse}.${sig}`, theirs, NOW)).toBeNull();
		expect(await verifyToken(await sign(keys.privateKey, user, { alg: 'none' }), theirs, NOW)).toBeNull();
		for (const junk of ['', 'a.b', 'a.b.c', null, undefined, 42]) expect(await verifyToken(junk, theirs, NOW)).toBeNull();
	});

	it("passes an unreachable key up (the server answers 500 and the game sends again): it isn't the token's fault", async () => {
		const offline = async () => {
			throw new Error('offline');
		};
		await expect(verifyToken(await sign(keys.privateKey, user), offline, NOW)).rejects.toThrow('offline');
	});

	it('fetches the key again when the cached one fails (CrazyGames may change it), once', async () => {
		const asked = [];
		const rotated = async (fresh) => {
			asked.push(fresh);
			return fresh ? keys.pem : old.pem;
		};
		expect((await verifyToken(await sign(keys.privateKey, user), rotated, NOW))?.userId).toBe(user.userId);
		expect(asked).toEqual([false, true]);
		asked.length = 0;
		expect(await verifyToken(await sign(old.privateKey, { ...user, exp: NOW - 1 }), rotated, NOW)).toBeNull();
		expect(asked, 'a good signature that has expired needs no second key').toEqual([false]);
	});
});

// A small maze ('1' open, rooms on odd cells). (5,4) is a shortcut to the exit that skips the key at (1,5).
const ROWS = ['0000000', '0111110', '0000010', '0111110', '0100010', '0111110', '0000000'];
const MAZE = { size: 7, open: ROWS.join(''), spawn: [1, 1], exit: [5, 5], keys: [[3, 1], [1, 5]], flips: [20, 60] };
const ROUTE = [[1, 1], [2, 1], [3, 1], [4, 1], [5, 1], [5, 2], [5, 3], [4, 3], [3, 3], [2, 3], [1, 3], [1, 4], [1, 5], [2, 5], [3, 5], [4, 5], [5, 5]];
const LONG = [...ROUTE, ...[...ROUTE].reverse().slice(1), ...ROUTE.slice(1)]; // there, back, there again: 26 s sprinting
const run = (cells, speed, extra = {}) => ({ ...walk(cells, speed, rules), breach: null, ...extra });

describe('the run', () => {
	it('lets a walk through every key to the exit through', () => {
		expect(checkRun(MAZE, rules, run(ROUTE, rules.walk))).toBe('');
	});

	it('paces a body: sprint speed at most, and a sprint only as long as stamina lasts', () => {
		const cycle = rules.sprint_time + rules.rest_time;
		const honest = (t) => (t % cycle < rules.sprint_time ? rules.sprint : rules.walk);
		expect(checkRun(MAZE, rules, run(LONG, honest)), 'sprint, rest at a walk, sprint again').toBe('');
		expect(checkRun(MAZE, rules, run(ROUTE, rules.sprint * 1.15))).toBe('too fast');
		expect(checkRun(MAZE, rules, run(ROUTE, rules.sprint)), 'a sprint past its stamina').toBe('too fast');
		expect(checkRun(MAZE, rules, run(LONG, rules.sprint)), 'an endless sprint').toBe('too fast');
		expect(reach(rules, 2)).toBeCloseTo(rules.sprint * 2 + 0.25);
		expect(reach(rules, cycle)).toBeCloseTo(rules.walk * cycle + (rules.sprint - rules.walk) * rules.sprint_time + 0.25);
	});

	it('keeps a body inside the maze', () => {
		const through = [[1, 1], [1, 2], [1, 3], [1, 4], [1, 5], [2, 5], [3, 5], [4, 5], [5, 5]];
		expect(checkRun({ ...MAZE, keys: [[1, 5]] }, rules, run(through, rules.walk))).toBe('through a wall');
		const jump = run(ROUTE, rules.walk);
		jump.tape[3] = 3 * rules.cell; // the second sample two cells on
		expect(checkRun(MAZE, rules, jump)).toBe('through a wall');
	});

	it('cuts a corner only past an open side', () => {
		const corner = { size: 2, open: '1001', spawn: [0, 0], exit: [1, 1], keys: [], flips: [] };
		const tape = new Float32Array([1.0, 1.0, 0, 1.5, 1.5, 0]);
		expect(checkRun(corner, rules, { time: 0.2, tape, breach: null })).toBe('through a wall');
		expect(checkRun({ ...corner, open: '1101' }, rules, { time: 0.2, tape, breach: null })).toBe('');
	});

	it('needs every key before the exit, from the spawn, all the way to the chest', () => {
		const skip = [[1, 1], [2, 1], [3, 1], [4, 1], [5, 1], [5, 2], [5, 3], [5, 4], [5, 5]];
		expect(checkRun(MAZE, rules, run(skip, rules.walk))).toBe('missed a key');
		expect(checkRun(MAZE, rules, run(ROUTE.slice(2), rules.walk))).toBe('not from the spawn');
		expect(checkRun({ ...MAZE, keys: [[3, 1]] }, rules, run(ROUTE.slice(0, -2), rules.walk))).toBe('never reached the exit');
	});

	it('holds the clock to the tape', () => {
		const honest = run(ROUTE, rules.walk);
		expect(checkRun(MAZE, rules, { ...honest, time: honest.time - 1 })).toBe('clock behind tape');
		expect(checkRun(MAZE, rules, { ...honest, time: honest.time + 30 }), 'a slower clock only hurts you').toBe('');
		expect(checkRun(MAZE, rules, { ...honest, tape: honest.tape.slice(1) })).toBe('bad tape');
		const broken = honest.tape.slice();
		broken[7] = NaN;
		expect(checkRun(MAZE, rules, { ...honest, tape: broken })).toBe('bad tape');
	});

	describe('through a wall the Devil broke', () => {
		// Wait in the spawn room for Flipping Time (20 s), when the Devil breaks the wall at (1,2), then go through it.
		const SHORT = [[1, 1], [1, 2], [1, 3], [1, 4], [1, 5], [2, 5], [3, 5], [4, 5], [5, 5]];
		const maze = { ...MAZE, keys: [[1, 5]] };
		const wait = (t) => (t < 20 ? 0 : rules.walk);

		it('lets the tape through from the breach on', () => {
			expect(checkRun(maze, rules, run(SHORT, wait, { breach: [1, 2, 20.02] }))).toBe('');
			expect(checkRun(maze, rules, run(SHORT, wait)), 'unclaimed').toBe('through a wall');
		});

		it('only as Flipping Time begins, at a wall between rooms, beside where you stood', () => {
			expect(checkRun(maze, rules, run(SHORT, wait, { breach: [1, 2, 35] })), 'no flip then').toBe('bad breach');
			expect(checkRun(maze, rules, run(SHORT, wait, { breach: [3, 4, 20.02] })), 'never beside it').toBe('bad breach');
			expect(checkRun(maze, rules, run(SHORT, wait, { breach: [2, 2, 20.02] })), 'a pillar').toBe('bad breach');
			const early = run(SHORT, (t) => (t < 10 ? 0 : rules.walk), { breach: [1, 2, 20.02] });
			expect(checkRun(maze, rules, early), 'through before it broke').toBe('through a wall');
		});
	});
});

describe('the tape', () => {
	it('arrives as the game sends it: base64 little-endian float32 (tests/test_race.gd pins the same string)', () => {
		expect([...new Float32Array(bytes('AACAPwAAAEAAAAA/').buffer)]).toEqual([1, 2, 0.5]);
	});
});

// The first exported week's real maze, walked along the game's own route (export_weeks.gd): both sides read the grid
// the same way, and a route with its axes swapped is caught.
describe('the exported week', () => {
	const maze = data.weeks[route.week];

	it("lets the game's own route through and catches a transposed one", () => {
		expect(checkRun(maze, rules, run(route.cells, rules.walk))).toBe('');
		expect(checkRun(maze, rules, run(route.cells.map(([x, y]) => [y, x]), rules.walk))).not.toBe('');
	});

	it('catches the whole route sprinted', () => {
		expect(checkRun(maze, rules, run(route.cells, rules.sprint))).toBe('too fast');
	});
});
