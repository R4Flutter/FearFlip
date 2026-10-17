import { env } from 'cloudflare:workers';
import { afterEach, describe, expect, it } from 'vitest';
import worker from '../src/index.js';
import { MAX_BYTES, MAX_PER_SECOND, originAllowed } from '../src/rules.js';

const opened = [];

// One player's socket into room `code`: `next()` waits for what arrives (a string, an ArrayBuffer, or {close: code}).
async function join(code, headers = {}) {
	const response = await worker.fetch(new Request(`http://relay/room/${code}`, { headers: { Upgrade: 'websocket', ...headers } }), env);
	const ws = response.webSocket;
	if (!ws) return { status: response.status };
	const inbox = [];
	let wake = null;
	ws.binaryType = 'arraybuffer'; // the runtime's default is Blob
	ws.accept();
	ws.addEventListener('message', (event) => {
		inbox.push(event.data);
		wake?.();
	});
	ws.addEventListener('close', (event) => {
		inbox.push({ close: event.code });
		wake?.();
	});
	opened.push(ws);
	const next = async () => {
		while (inbox.length === 0) await new Promise((resolve) => (wake = resolve));
		return inbox.shift();
	};
	return { ws, next, status: response.status };
}

const notice = (data) => JSON.parse(data);
const bytes = (data) => [...new Uint8Array(data)];

afterEach(() => {
	for (const ws of opened.splice(0)) {
		try {
			ws.close(1000, 'done');
		} catch {
			// already closed by the room
		}
	}
});

describe('a room', () => {
	it('tells both players when the second one arrives, then passes binary messages both ways', async () => {
		const a = await join('ABCDE');
		const b = await join('ABCDE');
		expect(a.status).toBe(101);
		expect(notice(await a.next())).toEqual({ peer: 'joined' });
		expect(notice(await b.next())).toEqual({ peer: 'joined' });
		a.ws.send(new Uint8Array([1, 2, 3]));
		expect(bytes(await b.next())).toEqual([1, 2, 3]);
		b.ws.send(new Uint8Array([9]));
		expect(bytes(await a.next())).toEqual([9]);
	});

	it('keeps rooms apart', async () => {
		const a = await join('AAAAA');
		const c = await join('CCCCC');
		const b = await join('AAAAA');
		await a.next();
		await b.next();
		const d = await join('CCCCC');
		await c.next();
		await d.next();
		a.ws.send(new Uint8Array([7]));
		c.ws.send(new Uint8Array([8]));
		expect(bytes(await b.next())).toEqual([7]);
		expect(bytes(await d.next())).toEqual([8]);
	});

	it('turns a third player away', async () => {
		const a = await join('FULLR');
		const b = await join('FULLR');
		await a.next();
		await b.next();
		const c = await join('FULLR');
		expect(notice(await c.next())).toEqual({ error: 'full' });
		expect(await c.next()).toEqual({ close: 4001 });
	});

	it('tells the other player when one leaves', async () => {
		const a = await join('LEAVE');
		const b = await join('LEAVE');
		await a.next();
		await b.next();
		b.ws.close(1000, 'bye');
		expect(notice(await a.next())).toEqual({ peer: 'left' });
	});

	it('closes a socket that sends a message over the size limit', async () => {
		const a = await join('HUGEE');
		const b = await join('HUGEE');
		await a.next();
		await b.next();
		a.ws.send(new Uint8Array(MAX_BYTES + 1));
		expect(await a.next()).toEqual({ close: 4002 });
		expect(notice(await b.next())).toEqual({ peer: 'left' });
	});

	it('closes a socket that floods', async () => {
		const a = await join('SPAMM');
		const b = await join('SPAMM');
		await a.next();
		await b.next();
		// Twice the limit and one more: however the burst falls across a second's edge, one second holds too many.
		for (let i = 0; i <= MAX_PER_SECOND * 2; i++) a.ws.send(new Uint8Array([i]));
		let got;
		do got = await a.next();
		while (!got.close);
		expect(got).toEqual({ close: 4003 });
	});

	it("keeps a player's log line to itself and never passes text on", async () => {
		const a = await join('LGTXT');
		const b = await join('LGTXT');
		await a.next();
		await b.next();
		a.ws.send(JSON.stringify({ log: { result: 'escaped', seconds: 140, mode: 'hard' } }));
		a.ws.send(JSON.stringify({ peer: 'left' })); // a player can't fake the room's own notices
		a.ws.send(new Uint8Array([5]));
		expect(bytes(await b.next())).toEqual([5]);
	});
});

describe('the door', () => {
	it('exports only the Worker and its room: the runtime takes every export for an entrypoint', async () => {
		expect(Object.keys(await import('../src/index.js')).sort()).toEqual(['Room', 'default']);
	});

	it('opens only /room/<5 letters> as a websocket', async () => {
		expect((await join('abcde')).status).toBe(404);
		expect((await join('ABCD')).status).toBe(404);
		expect((await join('ABCD0')).status).toBe(404); // no 0/O or 1/I: they look alike
		const plain = await worker.fetch(new Request('http://relay/room/ABCDE'), env);
		expect(plain.status).toBe(426);
		expect((await worker.fetch(new Request('http://relay/'), env)).status).toBe(404);
	});

	it('lets in CrazyGames pages, localhost and sockets without a page; turns other sites away', async () => {
		expect((await join('PAGES', { Origin: 'https://evil.example' })).status).toBe(403);
		expect((await join('PAGES', { Origin: 'https://notcrazygames.com' })).status).toBe(403);
		expect((await join('PAGES', { Origin: 'https://games.crazygames.com' })).status).toBe(101);
		expect((await join('PAGES', { Origin: 'http://localhost:8060' })).status).toBe(101);
	});

	it('matches whole hostnames', () => {
		const list = 'crazygames.com,localhost';
		expect(originAllowed('https://crazygames.com', list)).toBe(true);
		expect(originAllowed('https://a.b.crazygames.com', list)).toBe(true);
		expect(originAllowed('https://crazygames.com.evil.example', list)).toBe(false);
		expect(originAllowed('not a url', list)).toBe(false);
		expect(originAllowed(null, list)).toBe(true);
		expect(originAllowed('https://localhost', '')).toBe(false);
	});
});
