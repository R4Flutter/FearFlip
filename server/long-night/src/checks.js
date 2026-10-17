// The Long Night's checks (plans/11 v2), pure so the tests call them directly: who sent a run (the CrazyGames user
// token) and whether a body could have run it (the tape against the week's maze, as export_weeks.gd wrote it).

const ALG = { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' };
// rsaEncryption's AlgorithmIdentifier: what turns a PKCS#1 key into the SPKI that WebCrypto imports.
const RSA_ID = [0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00];

export const bytes = (base64) => Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
const unurl = (part) => bytes(part.replace(/-/g, '+').replace(/_/g, '/'));
const json = (part) => JSON.parse(new TextDecoder().decode(unurl(part)));

// A PEM public key as SPKI bytes. CrazyGames publishes PKCS#1 ("BEGIN RSA PUBLIC KEY"), which WebCrypto won't take:
// it goes into a BIT STRING beside rsaEncryption's id, inside a SEQUENCE (DER lengths: short, or 0x81/0x82 long).
export function spki(pem) {
	const der = bytes(pem.replace(/-----[^-]+-----|\s/g, ''));
	if (!pem.includes('BEGIN RSA PUBLIC KEY')) return der;
	const length = (n) => (n < 0x80 ? [n] : n < 0x100 ? [0x81, n] : [0x82, n >> 8, n & 0xff]);
	const bits = [0x03, ...length(der.length + 1), 0x00, ...der];
	return new Uint8Array([0x30, ...length(RSA_ID.length + bits.length), ...RSA_ID, ...bits]);
}

// The token's payload ({userId, username, gameId, iat, exp}) when CrazyGames signed it (RS256), it hasn't expired at
// `now` (unix seconds) and it was issued to `gameId` (when set); else null. `getPem(fresh)` returns their public key:
// a token that fails on the cached key gets one more try on a fresh one, since the key may change. When the key can't
// be had at all, getPem's error goes up: that's the server's trouble, not the token's.
export async function verifyToken(token, getPem, now, gameId = '') {
	let head, body, sig, payload;
	try {
		[head, body, sig] = String(token).split('.');
		payload = json(body);
		if (json(head).alg !== 'RS256' || sig === undefined) return null;
	} catch {
		return null; // not a JWT
	}
	const signed = new TextEncoder().encode(`${head}.${body}`);
	for (const fresh of [false, true]) {
		const pem = await getPem(fresh);
		try {
			const key = await crypto.subtle.importKey('spki', spki(pem), ALG, false, ['verify']);
			if (await crypto.subtle.verify(ALG, key, unurl(sig), signed)) {
				const fits = payload.exp > now && typeof payload.userId === 'string' && payload.userId !== '' && (!gameId || String(payload.gameId) === String(gameId));
				return fits ? payload : null;
			}
		} catch {
			// a key that won't load or a signature that won't decode: a miss
		}
	}
	return null;
}

// What a run must fit, both from export_weeks.gd. `rules` hold for every week: {cell (m), step (s between samples),
// walk and sprint (m/s), sprint_time and rest_time (s: a sprint lasts up to sprint_time, then rest_time without one),
// lookahead (s: the Devil picks the wall it breaks this long before Flipping Time), chest (m: you stand this far from
// the exit's centre at the end)}. `maze` is the week's: {size, open ('1' = open, row by row), spawn, exit, keys
// ([[x, y]...]), flips (race seconds at each Flipping Time's start)}.

// A sample is due every step of race time and taken on the next frame, up to FRAME late (below ~7 fps the game slows
// down instead: 8 physics steps a frame). SLACK metres cover the easing after a sprint ends.
const FRAME = 0.15;
const SLACK = 0.25;
// Paced over one sample (a jump), two seconds (sprint speed), and six and ten seconds (a sprint past its stamina, a
// sprint-and-rest cycle), in samples.
const WINDOWS = [1, 10, 30, 50];
// A frame hiccup's catch-up takes samples late, so one may sit this far behind the clock (s).
const LAG = 1;

// The farthest a body gets in `s` seconds: walking, plus sprinting for as long as stamina allows.
export function reach(rules, s) {
	const cycle = rules.sprint_time + rules.rest_time;
	const sprinting = Math.floor(s / cycle) * rules.sprint_time + Math.min(s % cycle, rules.sprint_time);
	return rules.walk * s + (rules.sprint - rules.walk) * sprinting + SLACK;
}

// '' when `run` could have happened in `maze`, else the reason. `run`: {time (s), tape (Float32Array: x, z, yaw each
// step from the spawn, then one more at the chest), breach ([x, y, race seconds] when the Devil broke a wall, else
// null)}.
export function checkRun(maze, rules, run) {
	const { tape, time, breach } = run;
	const n = tape.length / 3;
	if (!Number.isInteger(n) || n < 2 || !tape.every(Number.isFinite)) return 'bad tape';
	// sample k is taken at k * step or later, the last at the finish: a clock short of the tape ran fast
	if (!(time >= (n - 2) * rules.step - 0.001)) return 'clock behind tape';
	const cell = (i) => [Math.round(tape[i * 3] / rules.cell), Math.round(tape[i * 3 + 1] / rules.cell)];
	const open = (x, y) => x >= 0 && y >= 0 && x < maze.size && y < maze.size && maze.open[y * maze.size + x] === '1';
	if (breach && !breachFits(maze, rules, run, cell, open)) return 'bad breach';
	const walkable = (x, y, i) => open(x, y) || (!!breach && x === breach[0] && y === breach[1] && i * rules.step >= breach[2] - LAG);
	let [px, py] = cell(0);
	if (px !== maze.spawn[0] || py !== maze.spawn[1]) return 'not from the spawn';
	const keys = new Set(maze.keys.map(([x, y]) => `${x},${y}`));
	for (let i = 0; i < n; i++) {
		const [x, y] = cell(i);
		const [dx, dy] = [x - px, y - py];
		// one cell at most between samples, and a corner only past an open side
		if (!walkable(x, y, i) || Math.abs(dx) > 1 || Math.abs(dy) > 1
				|| (dx && dy && !walkable(px + dx, py, i) && !walkable(px, py + dy, i))) return 'through a wall';
		keys.delete(`${x},${y}`);
		[px, py] = [x, y];
	}
	if (keys.size > 0) return 'missed a key';
	if (Math.hypot(tape[n * 3 - 3] - maze.exit[0] * rules.cell, tape[n * 3 - 2] - maze.exit[1] * rules.cell) > rules.chest + 0.1) {
		return 'never reached the exit';
	}
	// paced on the beat: every sample but the last, taken at the chest after a short walk-in
	const walked = [0];
	for (let i = 1; i < n - 1; i++) walked.push(walked[i - 1] + Math.hypot(tape[i * 3] - tape[i * 3 - 3], tape[i * 3 + 1] - tape[i * 3 - 2]));
	for (const w of WINDOWS) {
		for (let i = 0; i + w < n - 1; i++) {
			if (walked[i + w] - walked[i] > reach(rules, w * rules.step + FRAME)) return 'too fast';
		}
	}
	return '';
}

// A breach the Devil could have made (main.gd::_breach_thin_wall): a wall between two rooms in a line, broken as a
// Flipping Time began (each start and end lands up to a frame late, so later ones drift), beside a room you stood in
// within `lookahead` before it (where it picked that wall).
function breachFits(maze, rules, run, cell, open) {
	const [x, y, t] = run.breach;
	const sides = x % 2 === 0 ? [[x - 1, y], [x + 1, y]] : [[x, y - 1], [x, y + 1]];
	if (!Number.isInteger(x) || !Number.isInteger(y) || x % 2 === y % 2 || open(x, y) || !sides.every(([a, b]) => open(a, b))) return false;
	if (!maze.flips.some((start, k) => t >= start - 0.05 && t <= start + 0.25 + 2 * (k + 1) * FRAME)) return false;
	const n = run.tape.length / 3;
	for (let i = Math.max(0, Math.floor((t - rules.lookahead - LAG) / rules.step)); i < n && i * rules.step <= t; i++) {
		const [cx, cy] = cell(i);
		if (cx % 2 === 1 && cy % 2 === 1 && Math.abs(cx - x) + Math.abs(cy - y) === 1) return true;
	}
	return false;
}
