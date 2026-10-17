import { cloudflareTest } from '@cloudflare/vitest-plugin';
import { defineConfig } from 'vitest/config';

// The tests run inside the Workers runtime (Miniflare, as `wrangler dev` does), rooms and all.
export default defineConfig({
	plugins: [cloudflareTest({ wrangler: { configPath: './wrangler.jsonc' } })],
});
