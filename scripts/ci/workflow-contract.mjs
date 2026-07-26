#!/usr/bin/env node

import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const actionPins = new Map([
  ['actions/checkout', 'de0fac2e4500dabe0009e67214ff5f5447ce83dd'],
  ['actions/setup-java', 'be666c2fcd27ec809703dec50e508c2fdc7f6654'],
  ['actions/setup-node', '48b55a011bda9f5d6aeb4c2d9c7362e8dae4041e'],
  ['actions/upload-artifact', '043fb46d1a93c77aae656e7c1c64a875d1fc6a0a'],
  ['subosito/flutter-action', '1a449444c387b1966244ae4d4f8c696479add0b2'],
]);

export function verifyWorkflowSource(source) {
  const failures = [];
  const requireMatch = (description, pattern) => {
    if (!pattern.test(source)) failures.push(description);
  };
  const requireText = (description, value) => {
    if (!source.includes(value)) failures.push(description);
  };

  requireMatch('pull_request trigger', /^  pull_request:\s*$/mu);
  requireMatch('main push trigger', /^  push:\s*\n    branches: \[main\]\s*$/mu);
  requireMatch('workflow_dispatch trigger', /^  workflow_dispatch:\s*$/mu);
  requireMatch(
    'top-level read-only permission',
    /^permissions:\s*\n  contents: read\s*$/mu,
  );
  requireText('concurrency cancellation', 'cancel-in-progress: true');
  requireText('exact Flutter SDK pin', 'FLUTTER_VERSION: 3.44.7');
  requireText('exact Node SDK pin', 'NODE_VERSION: 24.15.0');
  requireText(
    'verified APK success-only upload',
    '- name: Upload verified APK\n        if: success()',
  );
  requireText('verified APK missing-file failure', 'if-no-files-found: error');

  for (const job of [
    'quality',
    'dependency_audit',
    'backend',
    'android',
    'gate',
  ]) {
    requireMatch(`required ${job} job`, new RegExp(`^  ${job}:\\s*$`, 'mu'));
  }
  requireText(
    'gate dependency aggregation',
    'needs: [quality, dependency_audit, backend, android]',
  );

  for (const command of [
    'scripts/ci/flutter-quality.sh',
    'scripts/ci/dependency-audit.mjs',
    'scripts/ci/osv-offline-scan.sh',
    'scripts/ci/supabase-backend.sh',
    'scripts/ci/android-build.sh ${{ matrix.flavor }}',
    'npm ci --ignore-scripts --no-audit --no-fund',
  ]) {
    requireText(`required command ${command}`, command);
  }

  const actionReferences = [
    ...source.matchAll(/^\s*uses:\s+([^\s#]+)(?:\s+#.*)?$/gmu),
  ].map((match) => match[1]);
  if (actionReferences.length === 0) failures.push('external actions');
  for (const reference of actionReferences) {
    if (reference.startsWith('./')) continue;
    const separator = reference.lastIndexOf('@');
    const action = reference.slice(0, separator);
    const revision = reference.slice(separator + 1);
    if (separator < 0 || !/^[0-9a-f]{40}$/u.test(revision)) {
      failures.push(`full-SHA action pin for ${reference}`);
      continue;
    }
    if (!actionPins.has(action) || actionPins.get(action) !== revision) {
      failures.push(`reviewed action pin for ${action}`);
    }
  }
  for (const [action, revision] of actionPins) {
    requireText(`required action ${action}`, `${action}@${revision}`);
  }

  const checkoutHardeningCount = (
    source.match(/persist-credentials: false/gu) ?? []
  ).length;
  if (checkoutHardeningCount < 4) {
    failures.push('credential-disabled checkout in all source jobs');
  }
  const timeoutCount = (source.match(/timeout-minutes:/gu) ?? []).length;
  if (timeoutCount < 5) failures.push('timeout on every job');
  const retentionCount = (source.match(/retention-days: 14/gu) ?? []).length;
  if (retentionCount < 4) failures.push('14-day retention on every report/artifact');

  for (const forbidden of [
    ['pull_request_target trigger', /pull_request_target/u],
    ['secret context reference', /\$\{\{\s*secrets\./u],
    ['write permission', /^\s+[A-Za-z-]+: write\s*$/gmu],
    ['production environment binding', /^\s+environment:/gmu],
    ['continue-on-error bypass', /continue-on-error:\s*true/u],
  ]) {
    if (forbidden[1].test(source)) failures.push(forbidden[0]);
  }

  if (failures.length > 0) {
    throw new Error(`CI workflow contract failed:\n- ${failures.join('\n- ')}`);
  }
  return {
    actionCount: actionReferences.length,
    jobCount: 5,
    permissions: 'contents:read',
  };
}

export function verifySupplyChainSources({
  actionlint,
  backend,
  osv,
  quality,
  workflow,
}) {
  const failures = [];
  const requireText = (source, description, value) => {
    if (!source.includes(value)) failures.push(description);
  };

  requireText(osv, 'OSV-Scanner exact version', "kinflow_scanner_version='2.3.8'");
  requireText(
    osv,
    'OSV-Scanner Linux checksum',
    'bc98e15319ed0d515e3f9235287ba53cdc5535d576d24fd573978ecfe9ab92dc',
  );
  requireText(osv, 'OSV public seed npm lock', 'fixtures/osv/package-lock.json');
  requireText(osv, 'OSV public seed Pub lock', 'fixtures/osv/pubspec.lock');
  requireText(osv, 'OSV local database download', '--download-offline-databases');
  requireText(osv, 'OSV actual scan offline mode', '--offline \\');
  requireText(osv, 'OSV native package data', '--data-source native');
  requireText(osv, 'OSV lockfile-only resolution', '--no-resolve');
  requireText(
    osv,
    'OSV isolated database cache',
    'OSV_SCANNER_LOCAL_DB_CACHE_DIRECTORY',
  );
  requireText(osv, 'OSV actual npm lock', '"$kinflow_repo_root/package-lock.json"');
  requireText(
    osv,
    'OSV actual Pub lock',
    '"$kinflow_repo_root/apps/kinflow_app/pubspec.lock"',
  );
  if (osv.includes('api.osv.dev')) failures.push('OSV API metadata egress');

  requireText(
    actionlint,
    'actionlint exact version',
    "kinflow_actionlint_version='1.7.12'",
  );
  requireText(quality, 'quality actionlint invocation', 'scripts/ci/actionlint.sh');
  requireText(
    actionlint,
    'actionlint Linux archive checksum',
    '8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8',
  );
  requireText(
    actionlint,
    'actionlint Linux binary checksum',
    'c872d6db8c6bf83a8eaa704fc93999f027d55dffbc63b8a6abdccb47df5f4cd4',
  );

  const installSources = `${backend}\n${workflow}`;
  const safeInstall = 'npm ci --ignore-scripts --no-audit --no-fund';
  const npmInstallCount = (installSources.match(/npm ci/gu) ?? []).length;
  const safeInstallCount = (installSources.match(
    /npm ci --ignore-scripts --no-audit --no-fund/gu,
  ) ?? []).length;
  if (npmInstallCount !== safeInstallCount || npmInstallCount < 2) {
    failures.push('safe npm install flags');
  }

  if (failures.length > 0) {
    throw new Error(`Supply-chain contract failed:\n- ${failures.join('\n- ')}`);
  }
  return { npmInstallCount, offlineVulnerabilityScan: true };
}

async function main() {
  const repositoryRoot = resolve(import.meta.dirname, '../..');
  const path = resolve(
    process.argv[2] ?? resolve(import.meta.dirname, '../../.github/workflows/ci.yml'),
  );
  const workflow = await readFile(path, 'utf8');
  const result = verifyWorkflowSource(workflow);
  verifySupplyChainSources({
    actionlint: await readFile(resolve(repositoryRoot, 'scripts/ci/actionlint.sh'), 'utf8'),
    backend: await readFile(
      resolve(repositoryRoot, 'scripts/ci/supabase-backend.sh'),
      'utf8',
    ),
    osv: await readFile(
      resolve(repositoryRoot, 'scripts/ci/osv-offline-scan.sh'),
      'utf8',
    ),
    quality: await readFile(
      resolve(repositoryRoot, 'scripts/ci/flutter-quality.sh'),
      'utf8',
    ),
    workflow,
  });
  process.stdout.write(
    `CI workflow and supply-chain contract passed: ${result.jobCount} jobs, ${result.actionCount} pinned action uses, ${result.permissions}.\n`,
  );
}

const entrypoint = process.argv[1] ? pathToFileURL(resolve(process.argv[1])).href : '';
if (import.meta.url === entrypoint) {
  main().catch((error) => {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  });
}
