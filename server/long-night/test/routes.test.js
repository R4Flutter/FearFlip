import { createScheduledController } from 'cloudflare:test';
import { env } from 'cloudflare:workers';
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import worker from '../src/index.js';
import data from '../src/weeks.json';
import route from './route.json';
import { base64, makeKeys, sign, walk } from './helpers.js';

const WEEK = route.week;
const NOW = Date.parse(data.first) + (WEEK - 1) * 7 * 86400e3 + 3 * 3600e3; // three hours into the route's week
const rules = data.rules;
let keys;
let sentToCrazyGames; // each Leaderboard API call: {key, scores}
let crazyGames; // (scores) => {status, body}: how the Leaderboard API answers

const takesAll = (scores) => ({ status: 200, body: { success: true, total: scores.length, successCount: scores.length, failureCount: 0, errors: [] } });

beforeAll(async () => {
	keys = await makeKeys();
});

beforeEach(() => {
	vi.useFakeTimers({ toFake: ['Date'] });
	vi.setSystemTime(NOW);
	sentToCrazyGames = [];
	crazyGames = takesAll;
	vi.spyOn(globalThis, 'fetch').mockImplementation(async (input, init) => {
		const url = String(input instanceof Request ? input.url : input);
		if (url === 'https://sdk.crazygames.com/publicKey.json') return Response.json({ publicKey: keys.pem });
		if (url === env.CG_LEADERBOARD_URL) {
			const { scores } = JSON.parse(init.body);
			sentToCrazyGames.push({ key: init.headers['X-API-Key'], scores });
			const answer = crazyGames(scores);
			return Response.json(answer.body, { status: answer.status });
		}
		throw new Error(`unexpected fetch: ${url}`);
	});
});

afterEach(() => {
	vi.useRealTimers();
	vi.restoreAllMocks();
});

const token = (id, extra = {}) => sign(keys.privateKey, { userId: id, gameId: '20267', username: `${id}.name`, iat: NOW / 1e3, exp: NOW / 1e3 + 3600, ...extra });

// The game's own route through the week at `speed` (m/s or a function of race seconds), sent by `id`.
async function runBy(id, speed = rules.walk, extra = {}) {
	const { tape, time } = walk(route.cells, speed, rules);
	return { token: await token(id), week: WEEK, time_ms: Math.round(time * 1000), splits: [12.5, 40.25], tape: base64(tape), breach: [], ...extra };
}

async function post(body) {
	const res = await worker.fetch(new Request('https://long-night.test/run', { method: 'POST', body: typeof body === 'string' ? body : JSON.stringify(body) }), env);
	return { status: res.status, ...(await res.json()) };
}

async function get(path) {
	const res = await worker.fetch(new Request(`https://long-night.test${path}`), env);
	return { status: res.status, ...(await res.json()) };
}

const row = (player, week = WEEK) => env.DB.prepare('SELECT * FROM runs WHERE week = ? AND player = ?').bind(week, player).first();

// `count` runners p01, p02, ... at 10 s, 11 s, ... (faster than any real run; already on the CrazyGames board).
async function seed(count) {
	const insert = env.DB.prepare("INSERT OR REPLACE INTO runs (week, player, name, ms, splits, tape, at, sent) VALUES (?, ?, ?, ?, '[1]', 'AAAAAAAAAAAAAAAA', ?, 1)");
	await env.DB.batch(Array.from({ length: count }, (_, i) => {
		const id = `p${String(i + 1).padStart(2, '0')}`;
		return insert.bind(WEEK, id, `Runner ${i + 1}`, 10000 + i * 1000, new Date(NOW).toISOString());
	}));
}

describe('POST /run', () => {
	it('keeps a verified best and puts it on the CrazyGames board from here', async () => {
		const first = await runBy('ann');
		expect(await post(first)).toMatchObject({ status: 200, ok: true, best: true });
		expect(sentToCrazyGames).toEqual([{ key: 'test-api-key', scores: [{ userId: 'ann', score: first.time_ms, timestamp: new Date(NOW).toISOString() }] }]);
		expect(await row('ann')).toMatchObject({ name: 'ann.name', ms: first.time_ms, splits: '[12.5,40.25]', tape: first.tape, sent: 1 });

		expect(await post(await runBy('ann', rules.walk * 0.9))).toMatchObject({ status: 200, ok: true, best: false });
		expect((await row('ann')).ms, 'a slower run leaves the best').toBe(first.time_ms);
		expect(sentToCrazyGames.length).toBe(1);

		const cycle = rules.sprint_time + rules.rest_time;
		const faster = await runBy('ann', (t) => (t % cycle < rules.sprint_time ? rules.sprint : rules.walk));
		expect(await post(faster)).toMatchObject({ ok: true, best: true });
		expect((await row('ann')).ms).toBe(faster.time_ms);
		expect(sentToCrazyGames.length).toBe(2);
	});

	it('refuses who it cannot verify and what no body could run', async () => {
		const honest = await runBy('bob');
		expect(await post({ ...honest, token: await sign((await makeKeys()).privateKey, { userId: 'bob', exp: NOW / 1e3 + 60 }) })).toMatchObject({ status: 401, error: 'log in' });
		expect(await post({ ...honest, token: await token('bob', { exp: NOW / 1e3 - 1 }) })).toMatchObject({ status: 401 });
		expect(await post({ ...honest, token: await token('bob', { gameId: '1' }) })).toMatchObject({ status: 401 });
		expect(await post({ ...honest, week: WEEK - 1 })).toMatchObject({ status: 409, error: 'week over' });
		expect(await post(await runBy('bob', rules.sprint))).toMatchObject({ status: 422, error: 'too fast' });
		expect(await post({ ...honest, time_ms: 1000 })).toMatchObject({ status: 422, error: 'clock behind tape' });
		expect(await post({ ...honest, tape: 'not base64!' })).toMatchObject({ status: 400 });
		expect(await post({ ...honest, splits: [1, 2, 3, 4, 5, 6, 7, 8, 9] })).toMatchObject({ status: 400 });
		expect(await post({ ...honest, breach: [1, 2] })).toMatchObject({ status: 400 });
		expect(await post('{not json')).toMatchObject({ status: 400 });
		expect(await row('bob')).toBeNull();
		expect(sentToCrazyGames).toEqual([]);
	});
});

describe('the cron', () => {
	it('sends again what CrazyGames missed, and drops old weeks', async () => {
		crazyGames = () => ({ status: 503, body: { error: 'Service Unavailable' } });
		await post(await runBy('cat'));
		await post(await runBy('dan', rules.walk * 0.95));
		expect((await row('cat')).sent, 'kept, waiting for CrazyGames').toBe(0);
		await env.DB.prepare("INSERT INTO runs (week, player, name, ms, splits, tape, at) VALUES (?, 'old', 'Old', 1, '[]', '', '')").bind(WEEK - 4).run();

		crazyGames = (scores) => ({
			status: 200,
			body: { success: false, total: scores.length, successCount: 1, failureCount: 1, errors: [{ score: scores.find((s) => s.userId === 'dan'), type: 'user-not-found' }] },
		});
		sentToCrazyGames = [];
		await worker.scheduled(createScheduledController({ scheduledTime: NOW, cron: '*/10 * * * *' }), env);
		expect(sentToCrazyGames[0].scores.map((s) => s.userId).sort()).toEqual(['cat', 'dan']);
		expect((await row('cat')).sent, 'on the board').toBe(1);
		expect((await row('dan')).sent, 'refused for good: never resent').toBe(2);
		expect(await row('old', WEEK - 4), 'past KEEP_WEEKS').toBeNull();
	});
});

describe('GET /board and /ghost', () => {
	it('reads the top 10 and the 5 either side of you', async () => {
		await seed(30);
		const board = await get(`/board?week=${WEEK}&player=p15`);
		expect(board.top.map((r) => r.rank)).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
		expect(board.top[0]).toEqual({ rank: 1, name: 'Runner 1', ms: 10000, me: false });
		expect(board.you).toEqual({ rank: 15, ms: 24000 });
		expect(board.around.map((r) => [r.rank, r.name, r.me])).toEqual([
			[10, 'Runner 10', false], [11, 'Runner 11', false], [12, 'Runner 12', false], [13, 'Runner 13', false], [14, 'Runner 14', false],
			[15, 'Runner 15', true],
			[16, 'Runner 16', false], [17, 'Runner 17', false], [18, 'Runner 18', false], [19, 'Runner 19', false], [20, 'Runner 20', false],
		]);
		expect((await get(`/board?week=${WEEK}&player=p02`)).top[1].me, 'you, in the top 10').toBe(true);
		expect((await get(`/board?week=${WEEK}&ms=29500`)).you, "a guest's time: where it would stand").toEqual({ rank: 21, ms: 29500 });
		expect((await get(`/board?week=${WEEK}&player=nobody`)).you, 'no time yet').toBeNull();
	});

	it('gives you your rival: the run just ahead of yours, tape and all', async () => {
		await seed(30);
		expect(await get(`/ghost?week=${WEEK}&player=p15`)).toMatchObject({ status: 200, name: 'Runner 14', ms: 23000, splits: [1], tape: 'AAAAAAAAAAAAAAAA' });
		expect(await get(`/ghost?week=${WEEK}&player=p01`)).toMatchObject({ status: 404, error: 'you lead' });
		const slowest = await env.DB.prepare('SELECT name FROM runs WHERE week = ? ORDER BY ms DESC LIMIT 1').bind(WEEK).first('name');
		expect(await get(`/ghost?week=${WEEK}&ms=0`), 'no time yet: the slowest finisher to beat').toMatchObject({ name: slowest });
	});
});
