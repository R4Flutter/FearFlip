import { DurableObject } from 'cloudflare:workers';
import { CODE, MAX_BYTES, MAX_PER_SECOND, PLAYERS, originAllowed } from './rules.js';

// VERSUS's relay (plans/12). Two players open /room/<CODE>; whatever one sends as binary (the game's own messages)
// goes to the other. Text frames belong to the room: it tells players {"peer":"joined"|"left"} and {"error":"full"},
// and a player's {"log":{...}} goes to the logs, never on. The runner's game is the referee, so the room only checks
// who comes in, how big and how fast (rules.js).

export default {
	async fetch(request, env) {
		const code = new URL(request.url).pathname.match(/^\/room\/([^/]+)$/)?.[1];
		if (!code || !CODE.test(code)) return new Response('not found', { status: 404 });
		if (request.headers.get('Upgrade') !== 'websocket') return new Response('websocket only', { status: 426 });
		if (!originAllowed(request.headers.get('Origin'), env.ALLOWED_ORIGINS)) return new Response('forbidden', { status: 403 });
		// ponytail: one room = one Durable Object, billed as duration for its whole match (~330 five-minute rounds a
		// day free). Past ~$20/month, share per-region rooms through socket tags (plans/12).
		return env.ROOMS.getByName(code).fetch(request);
	},
};

export class Room extends DurableObject {
	async fetch() {
		const [client, socket] = Object.values(new WebSocketPair());
		const here = this.ctx.getWebSockets();
		if (here.length >= PLAYERS) {
			socket.accept();
			socket.send(JSON.stringify({ error: 'full' }));
			socket.close(4001, 'full');
			return new Response(null, { status: 101, webSocket: client });
		}
		// Hibernation: a room waiting for a friend costs nothing.
		this.ctx.acceptWebSocket(socket);
		socket.serializeAttachment({ second: 0, count: 0 });
		if (here.length === 1) {
			for (const ws of [here[0], socket]) ws.send(JSON.stringify({ peer: 'joined' }));
		}
		return new Response(null, { status: 101, webSocket: client });
	}

	webSocketMessage(ws, message) {
		const size = typeof message === 'string' ? message.length : message.byteLength;
		if (size > MAX_BYTES) return this.drop(ws, 4002, 'too big');
		const second = Math.floor(Date.now() / 1000);
		const meter = ws.deserializeAttachment();
		meter.count = meter.second === second ? meter.count + 1 : 1;
		meter.second = second;
		ws.serializeAttachment(meter);
		if (meter.count > MAX_PER_SECOND) return this.drop(ws, 4003, 'too fast');
		if (typeof message === 'string') return this.log(message);
		for (const other of this.others(ws)) other.send(message);
	}

	webSocketClose(ws) {
		this.drop(ws, 1000, 'bye');
	}

	webSocketError(ws) {
		this.drop(ws, 1011, 'error');
	}

	// Close `ws` (if it isn't already) and tell whoever is left.
	drop(ws, code, reason) {
		try {
			ws.close(code, reason);
		} catch {
			// already closing
		}
		for (const other of this.others(ws)) other.send(JSON.stringify({ peer: 'left' }));
	}

	others(ws) {
		return this.ctx.getWebSockets().filter((other) => other !== ws && other.readyState === WebSocket.OPEN);
	}

	// A player's line for the dashboard's logs: {"log": {result, seconds, mode, ...}}. Anything else is ignored.
	log(text) {
		let line;
		try {
			line = JSON.parse(text);
		} catch {
			return;
		}
		if (line && typeof line.log === 'object' && line.log !== null) console.log(JSON.stringify({ room: this.ctx.id.name, ...line.log }));
	}
}
