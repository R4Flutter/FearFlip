import { applyD1Migrations } from 'cloudflare:test';
import { env } from 'cloudflare:workers';

// Safe to run more than once: only migrations not yet applied run.
await applyD1Migrations(env.DB, env.TEST_MIGRATIONS);
