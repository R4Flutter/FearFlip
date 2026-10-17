# FearFlip VERSUS relay (plans/12)

A Cloudflare Worker with one Durable Object per room. Two players open `wss://<worker>/room/<CODE>`, and every binary
message one sends goes to the other. The runner's game is the referee, so the room never reads the game's messages.

Free tier: about 28 hours of 1v1 play a day (about 330 five-minute rounds). At the cap, new rooms fail until 00:00 UTC:
nothing is billed.

## Run

```
npm install
npm test      # vitest inside the Workers runtime
npm run dev   # ws://127.0.0.1:8787: where a dev build's Net.SERVER points
```

## Deploy (once, by you)

```
npx wrangler login
npm run deploy   # prints https://fearflip-versus.<your-subdomain>.workers.dev
```

Then set `SERVER` in `godot/scripts/net.gd` to `wss://fearflip-versus.<your-subdomain>.workers.dev` for the web build.
To let another portal's pages in, add its hostname to `ALLOWED_ORIGINS` in `wrangler.jsonc` and deploy again.

## What the room checks

| Check | Answer |
|---|---|
| Path `/room/<5 of A-H J-N P-Z 2-9>` | 404 otherwise |
| WebSocket upgrade | 426 otherwise |
| `Origin` under `ALLOWED_ORIGINS`, or no `Origin` (desktop builds) | 403 otherwise |
| Two players | the third gets `{"error":"full"}`, then close 4001 |
| At most 256 B a message | close 4002 |
| At most 30 messages a second | close 4003 |

The room's own text frames: `{"peer":"joined"}` (to both, once the second player arrives), `{"peer":"left"}`,
`{"error":"full"}`. Text a player sends is never passed on; `{"log":{...}}` lands in Workers Logs (one line per round).

## When to pay (plans/12)

Free tier over 70% for 3 days running: Workers Paid ($5/month, about 3,300 rounds a month included). A bill over
$20/month: share per-region rooms through socket tags. Over $50/month: WebRTC P2P, with this Worker only signaling.
