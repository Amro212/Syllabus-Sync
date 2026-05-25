import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join, resolve } from 'node:path';

const serverRoot = resolve(fileURLToPath(new URL('..', import.meta.url)));
const repoRoot = resolve(serverRoot, '..');

function read(relativePath) {
  return readFileSync(join(repoRoot, relativePath), 'utf8');
}

function fail(message) {
  console.error(`security config check failed: ${message}`);
  process.exitCode = 1;
}

const trackedFiles = execFileSync('/usr/bin/env', ['git', 'ls-files'], { cwd: repoRoot, encoding: 'utf8' })
  .split('\n')
  .filter(Boolean);

for (const file of trackedFiles) {
  if (/(^|\/)(\.env|\.dev\.vars)\.example$/.test(file)) {
    continue;
  }
  if (/(^|\/)(\.env|\.dev\.vars)(\.|$)/.test(file)) {
    fail(`tracked local secret file: ${file}`);
  }
}

const wrangler = read('server/wrangler.jsonc');
if (!wrangler.includes('"ABUSE_LIMITER"') || !wrangler.includes('"AbuseLimiter"')) {
  fail('Cloudflare Durable Object abuse limiter binding is missing');
}
if (!wrangler.includes('"new_sqlite_classes": ["AbuseLimiter"]')) {
  fail('Durable Object migration for AbuseLimiter is missing');
}

const worker = read('server/src/index.ts');
for (const marker of [
  'validateProductionConfig',
  'isUnsafeProductionOrigin',
  'PRODUCTION_CONFIG_INVALID',
  'RATE_LIMIT_SOCIAL',
  'openai:budget:',
]) {
  if (!worker.includes(marker)) {
    fail(`worker security marker missing: ${marker}`);
  }
}

const migration = read('supabase/migrations/202605250001_security_rls.sql');
for (const table of [
  'users',
  'courses',
  'events',
  'grading_entries',
  'friend_requests',
  'friends',
  'blocked_users',
  'user_preferences',
  'social_action_rate_limits',
]) {
  if (!migration.includes(`alter table public.${table} enable row level security`)) {
    fail(`RLS enable statement missing for public.${table}`);
  }
}
for (const marker of [
  'check_social_action_rate_limit',
  'friend_requests_rate_limit',
  'friends_rate_limit',
  'blocked_users_rate_limit',
]) {
  if (!migration.includes(marker)) {
    fail(`social abuse control missing from migration: ${marker}`);
  }
}

const ci = read('.github/workflows/ci.yml');
if (!ci.includes('npm run security:scan')) {
  fail('CI release gate does not run npm run security:scan');
}

if (!process.exitCode) {
  console.log('security config check passed');
}
