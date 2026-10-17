// The Long Night's server (plans/11 v2): a Cloudflare Worker + D1, free tier. POST /run checks a run (the CrazyGames
// token says who, checks.js says whether a body could have run it), keeps each player's best and its tape, and puts it
// on the CrazyGames board server-side (the API key never leaves here). GET /board and GET /ghost read the week's board.
import { bytes, checkRun, verifyToken } from './checks.js';
import data from './weeks.json';

const KEY_URL = 'https://sdk.crazygames.com/publicKey.json';
const WEEK_MS = 7 * 86400e3;
// A rank is counted one D1 row read per runner ahead, up to here; deeper reads as null ("1000+"). It keeps a board
// read under ~1,030 rows: D1's free 5M reads a day is the budget that runs out first.
const RANK_SCAN = 1000;
// Weeks kept (tapes are ~25 KB each against D1's free 5 GB); older ones go in the cron.
const KEEP_WEEKS = 4;
// Board answers are kept this long in the isolate (and the browser), per query.
const CACHE_MS = 60e3;
// An hour of race, and the body that carries its tape.
const MAX_TIME = 3600;
const MAX_BODY = 700e3;
// CrazyGames errors that no resend will fix.
const FOR_GOOD = ['user-not-found', 'privacy-disabled'];
const CORS = {
	'Access-Control-Allow-Origin': '*',
	'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
	'Access-Control-Allow-Headers': 'Content-Type',
};
const UPSERT = `INSERT INTO runs (week, player, name, ms, splits, tape, at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
	ON CONFLICT (week, player) DO UPDATE SET name = excluded.name, ms = excluded.ms, splits = excluded.splits,
		tape = excluded.tape, at = excluded.at, sent = 0
	WHERE excluded.ms < runs.ms`;

// Week 1 began with CrazyGames' board season, Monday 12 Oct 2026 09:00 UTC (Race.FIRST_WEEK).
export const weekOf = (ms) => Math.floor((ms - Date.parse(data.first)) / WEEK_MS) + 1;

const reply = (body, status = 200, headers = {}) =>
	new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json', ...CORS, ...headers } });

export default {
	async fetch(request, env) {
		if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
		const url = new URL(request.url);
		try {
			if (request.method === 'POST' && url.pathname === '/run') return await postRun(request, env);
			if (request.method === 'GET' && url.pathname === '/board') return await getBoard(url, env);
			if (request.method === 'GET' && url.pathname === '/ghost') return await getGhost(url, env);
			return reply({ error: 'not found' }, 404);
		} catch (e) {
			console.error(e);
			return reply({ error: 'server error' }, 500);
		}
	},

	async scheduled(controller, env) {
		const week = weekOf(controller.scheduledTime);
		const { results } = await env.DB.prepare('SELECT week, player, ms, at FROM runs WHERE week = ? AND sent = 0 LIMIT 100').bind(week).all();
		await send(env, results);
		await env.DB.prepare('DELETE FROM runs WHERE week <= ?').bind(week - KEEP_WEEKS).run();
	},
};

// A finished run: {token, week, time_ms, splits, tape (base64 float32), breach ([x, y, t] or [])}.
async function postRun(request, env) {
	const text = await request.text();
	if (text.length > MAX_BODY) return reply({ ok: false, error: 'too long' }, 413);
	let run;
	try {
		run = JSON.parse(text);
	} catch {
		return reply({ ok: false, error: 'bad run' }, 400);
	}
	const user = await verifyToken(run.token, getPem, Date.now() / 1000, env.CG_GAME_ID);
	if (!user) return reply({ ok: false, error: 'log in' }, 401);
	const week = weekOf(Date.now());
	if (run.week !== week) return reply({ ok: false, error: 'week over' }, 409);
	const maze = data.weeks[week];
	if (!maze) return reply({ ok: false, error: 'week not exported' }, 503);
	let tape = null;
	try {
		tape = new Float32Array(bytes(run.tape).buffer);
	} catch {
		// not base64, or not whole floats
	}
	const breach = Array.isArray(run.breach) && run.breach.length > 0 ? run.breach : null;
	const splits = run.splits;
	if (!tape || !Number.isInteger(run.time_ms) || run.time_ms <= 0 || run.time_ms > MAX_TIME * 1000
			|| !Array.isArray(splits) || splits.length > maze.keys.length || !splits.every(Number.isFinite)
			|| (breach && !(breach.length === 3 && breach.every(Number.isFinite)))) {
		return reply({ ok: false, error: 'bad run' }, 400);
	}
	const why = checkRun(maze, data.rules, { time: run.time_ms / 1000, tape, breach });
	if (why) return reply({ ok: false, error: why }, 422);
	const at = new Date().toISOString();
	const { meta } = await env.DB.prepare(UPSERT).bind(week, user.userId, String(user.username ?? ''), run.time_ms, JSON.stringify(splits), run.tape, at).run();
	const best = meta.changes > 0;
	if (best) await send(env, [{ week, player: user.userId, ms: run.time_ms, at }]);
	return reply({ ok: true, best });
}

// Bests to the CrazyGames board (Leaderboard API, up to 100 a call). Marks those it took (sent 1) and those it refused
// for good (2); the rest stay 0 for the cron. A 400 refuses the whole batch, naming only the bad ones.
async function send(env, rows) {
	if (!env.CG_API_KEY || rows.length === 0) return;
	let res;
	try {
		res = await fetch(env.CG_LEADERBOARD_URL, {
			method: 'POST',
			headers: { 'X-API-Key': env.CG_API_KEY, 'Content-Type': 'application/json' },
			body: JSON.stringify({ scores: rows.map((r) => ({ userId: r.player, score: r.ms, timestamp: r.at })) }),
		});
	} catch {
		return; // unreachable: the cron tries again
	}
	if (res.status !== 200 && res.status !== 400) return; // a bad key, too many requests, their outage: later
	const errors = (await res.json().catch(() => ({}))).errors ?? [];
	const mark = env.DB.prepare('UPDATE runs SET sent = ?1 WHERE week = ?2 AND player = ?3 AND ms = ?4');
	const marks = [];
	for (const r of rows) {
		const error = errors.find((e) => e?.score?.userId === r.player);
		const sent = error ? (res.status === 400 || FOR_GOOD.includes(error.type) ? 2 : 0) : res.status === 200 ? 1 : 0;
		if (sent) marks.push(mark.bind(sent, r.week, r.player, r.ms));
	}
	if (marks.length > 0) await env.DB.batch(marks);
}

// The week's top 10 and the 5 either side of you: you are `player` (a CrazyGames userId) or, for a guest, `ms` (your
// best on this device). {week, top: [{rank, name, ms, me}], around: [...], you: {rank, ms} | null}; a rank past
// RANK_SCAN is null.
async function getBoard(url, env) {
	const week = Number(url.searchParams.get('week')) || weekOf(Date.now());
	const board = await cached(url.search, async () => {
		const db = env.DB;
		const player = url.searchParams.get('player') ?? '';
		const top = (await db.prepare('SELECT player, name, ms FROM runs WHERE week = ? ORDER BY ms LIMIT 10').bind(week).all()).results;
		const out = { week, top: top.map((r, i) => ({ rank: i + 1, name: r.name, ms: r.ms, me: !!player && r.player === player })), around: [], you: null };
		const mine = player ? await db.prepare('SELECT name, ms FROM runs WHERE week = ? AND player = ?').bind(week, player).first() : null;
		const ms = mine?.ms ?? (Number(url.searchParams.get('ms')) || 0);
		if (!ms) return out;
		const ahead = await db.prepare('SELECT COUNT(*) AS n FROM (SELECT 1 FROM runs WHERE week = ? AND ms < ? LIMIT ?)').bind(week, ms, RANK_SCAN).first('n');
		const rank = ahead < RANK_SCAN ? ahead + 1 : null;
		const above = (await db.prepare('SELECT name, ms FROM runs WHERE week = ? AND ms < ? ORDER BY ms DESC LIMIT 5').bind(week, ms).all()).results.reverse();
		const below = (await db.prepare('SELECT name, ms FROM runs WHERE week = ? AND ms > ? ORDER BY ms LIMIT 5').bind(week, ms).all()).results;
		const at = (offset) => (rank === null ? null : rank + offset);
		out.you = { rank, ms };
		out.around = [
			...above.map((r, i) => ({ rank: at(i - above.length), name: r.name, ms: r.ms, me: false })),
			{ rank, name: mine?.name ?? '', ms, me: true },
			...below.map((r, i) => ({ rank: at(i + 1), name: r.name, ms: r.ms, me: false })),
		];
		return out;
	});
	return reply(board, 200, { 'Cache-Control': `public, max-age=${CACHE_MS / 1000}` });
}

// Your rival: the run just ahead of yours (`player`, or a guest's `ms`; no time yet: the slowest finisher), with its
// tape for the ghost. {name, ms, splits, tape}, or 404 when you lead.
async function getGhost(url, env) {
	const week = Number(url.searchParams.get('week')) || weekOf(Date.now());
	const player = url.searchParams.get('player') ?? '';
	const mine = player ? await env.DB.prepare('SELECT ms FROM runs WHERE week = ? AND player = ?').bind(week, player).first('ms') : null;
	const ms = mine ?? (Number(url.searchParams.get('ms')) || Number.MAX_SAFE_INTEGER);
	const rival = await env.DB.prepare('SELECT name, ms, splits, tape FROM runs WHERE week = ? AND ms < ? ORDER BY ms DESC LIMIT 1').bind(week, ms).first();
	if (!rival) return reply({ error: 'you lead' }, 404);
	return reply({ ...rival, splits: JSON.parse(rival.splits) }, 200, { 'Cache-Control': `public, max-age=${CACHE_MS / 1000}` });
}

// CrazyGames' public key (PEM), fetched again at most once a minute: a forged token mustn't hammer their CDN.
let pem = '';
let pemAt = 0;
async function getPem(fresh) {
	if (pem && (!fresh || Date.now() - pemAt < 60e3)) return pem;
	pem = (await (await fetch(KEY_URL)).json()).publicKey;
	pemAt = Date.now();
	return pem;
}

// Answers kept in this isolate for CACHE_MS (the client adds its best to the query, so a new best reads fresh).
const memo = new Map();
async function cached(key, make) {
	const hit = memo.get(key);
	if (hit && Date.now() - hit.at < CACHE_MS) return hit.value;
	if (memo.size > 1000) memo.clear();
	const value = await make();
	memo.set(key, { at: Date.now(), value });
	return value;
}
