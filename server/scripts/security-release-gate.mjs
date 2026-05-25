import { spawnSync } from 'node:child_process';

const checks = [
  ['npm', ['audit', '--audit-level=moderate']],
  ['npx', ['tsc', '--noEmit']],
  ['npm', ['test', '--', '--run']],
  ['node', ['scripts/check-security-config.mjs']],
];

for (const [command, args] of checks) {
  console.log(`\n> ${command} ${args.join(' ')}`);
  const result = spawnSync(command, args, {
    cwd: new URL('..', import.meta.url),
    stdio: 'inherit',
    shell: process.platform === 'win32',
  });

  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}
