import path from 'node:path';
import { cloudflareTest, readD1Migrations } from '@cloudflare/vitest-plugin';
import { defineConfig } from 'vitest/config';

// The tests run inside the Workers runtime (Miniflare, as `wrangler dev` does) with a local D1 per test file.
export default defineConfig(async () => ({
	plugins: [
		cloudflareTest({
			wrangler: { configPath: './wrangler.jsonc' },
			miniflare: {
				bindings: {
					TEST_MIGRATIONS: await readD1Migrations(path.join(import.meta.dirname, 'migrations')),
					CG_API_KEY: 'test-api-key',
					CG_GAME_ID: '20267',
				},
			},
		}),
	],
	test: { setupFiles: ['./test/apply-migrations.js'] },
}));
