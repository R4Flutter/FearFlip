// Test kit: CrazyGames-style tokens signed with a test key, and tapes that walk a list of cells like the game records
// them (RaceGhost: x, z, yaw every rules.step, then one sample where you stand at the chest).

const url64 = (bytes) => btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

// A test key pair. `pem` is the public key the way CrazyGames publishes theirs (PKCS#1, "BEGIN RSA PUBLIC KEY": for
// a 2048-bit key, the SPKI after its 4 + 15 + 5 header bytes); `spkiPem` the usual SPKI form.
export async function makeKeys() {
	const pair = await crypto.subtle.generateKey(
		{ name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
		true,
		['sign', 'verify'],
	);
	const spki = new Uint8Array(await crypto.subtle.exportKey('spki', pair.publicKey));
	const pem = (label, der) => `-----BEGIN ${label}-----\n${btoa(String.fromCharCode(...der)).match(/.{1,64}/g).join('\n')}\n-----END ${label}-----\n`;
	return { privateKey: pair.privateKey, pem: pem('RSA PUBLIC KEY', spki.slice(24)), spkiPem: pem('PUBLIC KEY', spki) };
}

export async function sign(privateKey, payload, header = { alg: 'RS256', typ: 'JWT' }) {
	const part = (o) => url64(new TextEncoder().encode(JSON.stringify(o)));
	const signed = `${part(header)}.${part(payload)}`;
	const sig = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', privateKey, new TextEncoder().encode(signed)));
	return `${signed}.${url64(sig)}`;
}

// Walks `cells` (one grid step apart) from the first cell's centre at `speed` (m/s, or a function of race seconds),
// to the last one's centre, then stands at the chest. Returns {tape: Float32Array, time: seconds at the exit}.
export function walk(cells, speed, rules) {
	const points = cells.map(([x, y]) => [x * rules.cell, y * rules.cell]);
	const along = [0];
	for (let i = 1; i < points.length; i++) {
		along.push(along[i - 1] + Math.hypot(points[i][0] - points[i - 1][0], points[i][1] - points[i - 1][1]));
	}
	const total = along.at(-1);
	const pace = typeof speed === 'function' ? speed : () => speed;
	const out = [];
	let d = 0;
	let t = 0;
	for (;;) {
		let i = 1;
		while (i < points.length - 1 && along[i] < d) i++;
		const f = along[i] === along[i - 1] ? 0 : (d - along[i - 1]) / (along[i] - along[i - 1]);
		out.push(points[i - 1][0] + (points[i][0] - points[i - 1][0]) * f, points[i - 1][1] + (points[i][1] - points[i - 1][1]) * f, 0);
		const step = pace(t) * rules.step;
		if (d + step > total) {
			t += (total - d) / Math.max(pace(t), 1e-9);
			break;
		}
		d += step;
		t += rules.step;
	}
	const [ex, ez] = points.at(-1);
	const [px, pz] = points.at(-2);
	const back = Math.hypot(px - ex, pz - ez);
	out.push(ex + ((px - ex) / back) * rules.chest, ez + ((pz - ez) / back) * rules.chest, 0);
	return { tape: new Float32Array(out), time: t };
}

export function base64(tape) {
	let text = '';
	for (const byte of new Uint8Array(tape.buffer)) text += String.fromCharCode(byte);
	return btoa(text);
}
