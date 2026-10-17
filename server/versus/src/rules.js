// What the relay checks (plans/12). Kept out of index.js: the Workers runtime takes every export of the main module
// for an entrypoint, so only the Worker and its Durable Object live there.

// Five letters with no 0/O or 1/I: they look alike when a friend reads a code out.
export const CODE = /^[A-HJ-NP-Z2-9]{5}$/;
export const PLAYERS = 2;
export const MAX_BYTES = 256;
export const MAX_PER_SECOND = 30;

// A browser page's Origin must be a listed hostname or under one; no Origin (desktop builds, tests) is fine.
export function originAllowed(origin, list = '') {
	if (!origin) return true;
	let host;
	try {
		host = new URL(origin).hostname;
	} catch {
		return false;
	}
	return list.split(',').map((name) => name.trim()).filter(Boolean).some((name) => host === name || host.endsWith('.' + name));
}
