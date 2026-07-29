import assert from 'node:assert/strict';
import {
  lstat,
  mkdtemp,
  readFile,
  readdir,
  rm,
  symlink,
} from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import {
  readTwoAdultE2EEvidence,
  twoAdultApplicationIds,
  twoAdultE2ECheckKeys,
  validateTwoAdultE2EEvidence,
} from './android-two-adult-e2e-evidence.mjs';
import {
  formatTwoAdultE2ESessionSummary,
  initializeTwoAdultE2ESession,
  readTwoAdultE2ESessionStatus,
  recordTwoAdultE2EResult,
} from './android-two-adult-e2e-session.mjs';

async function createHarness(context) {
  const repositoryRoot = await mkdtemp(join(tmpdir(), 'kinflow-e2e-session-'));
  context.after(async () => {
    await rm(repositoryRoot, { recursive: true });
  });
  return {
    evidencePath: join(
      repositoryRoot,
      'ci-reports',
      'manual',
      'two-adult.json',
    ),
    repositoryRoot,
  };
}

function artifactInspector(expectedApplicationId = twoAdultApplicationIds.dev) {
  return async ({ expectedApplicationId: requested }) => {
    assert.equal(requested, expectedApplicationId);
    return {
      applicationId: expectedApplicationId,
      artifactSha256: 'b'.repeat(64),
      commit: 'a'.repeat(40),
    };
  };
}

test('initializes one private exact-schema session without auto-pass', async (context) => {
  const harness = await createHarness(context);
  const summary = await initializeTwoAdultE2ESession({
    apkPath: 'synthetic.apk',
    artifactInspector: artifactInspector(),
    clock: () => new Date('2026-07-29T04:00:00.999Z'),
    deviceAApiLevel: 35,
    deviceBApiLevel: 36,
    environment: 'dev',
    ...harness,
  });

  assert.deepEqual(summary, {
    applicationId: twoAdultApplicationIds.dev,
    checkCount: 27,
    environment: 'dev',
    failCount: 0,
    notRunCount: 29,
    passCount: 0,
    resultCount: 29,
  });
  const evidence = await readTwoAdultE2EEvidence(harness.evidencePath);
  assert.equal(evidence.recordedAtUtc, '2026-07-29T04:00:00Z');
  assert.equal(evidence.devices.A.apiLevel, 35);
  assert.equal(evidence.devices.B.apiLevel, 36);
  assert.equal(
    twoAdultE2ECheckKeys.every((key) => evidence.checks[key] === 'not_run'),
    true,
  );
  assert.equal(
    validateTwoAdultE2EEvidence(evidence, { requireComplete: false })
      .completed,
    false,
  );
  assert.equal((await lstat(harness.evidencePath)).mode & 0o777, 0o600);

  await assert.rejects(
    initializeTwoAdultE2ESession({
      apkPath: 'synthetic.apk',
      artifactInspector: artifactInspector(),
      deviceAApiLevel: 35,
      deviceBApiLevel: 36,
      environment: 'dev',
      ...harness,
    }),
    /already exists or could not be written/u,
  );
});

test('records only allowlisted targets and stable result codes atomically', async (context) => {
  const harness = await createHarness(context);
  await initializeTwoAdultE2ESession({
    apkPath: 'synthetic.apk',
    artifactInspector: artifactInspector(),
    clock: () => new Date('2026-07-29T04:00:00Z'),
    deviceAApiLevel: 35,
    deviceBApiLevel: 36,
    environment: 'dev',
    ...harness,
  });

  await recordTwoAdultE2EResult({
    clock: () => new Date('2026-07-29T04:01:00Z'),
    result: 'pass',
    target: 'device_a_preflight',
    ...harness,
  });
  const summary = await recordTwoAdultE2EResult({
    clock: () => new Date('2026-07-29T04:02:00Z'),
    result: 'pass',
    target: 'device_a_google_login',
    ...harness,
  });
  assert.equal(summary.passCount, 2);
  assert.equal(summary.notRunCount, 27);
  const evidence = await readTwoAdultE2EEvidence(harness.evidencePath);
  assert.equal(evidence.devices.A.preflight, 'pass');
  assert.equal(evidence.checks.device_a_google_login, 'pass');
  assert.equal(evidence.recordedAtUtc, '2026-07-29T04:02:00Z');

  const beforeInvalid = await readFile(harness.evidencePath, 'utf8');
  for (const [target, result, pattern] of [
    ['account_email', 'pass', /target is invalid/u],
    ['device_b_google_login', 'observed for user', /result is invalid/u],
  ]) {
    await assert.rejects(
      recordTwoAdultE2EResult({ target, result, ...harness }),
      pattern,
    );
  }
  assert.equal(await readFile(harness.evidencePath, 'utf8'), beforeInvalid);
  const entries = await readdir(join(harness.repositoryRoot, 'ci-reports', 'manual'));
  assert.deepEqual(entries, ['two-adult.json']);
});

test('restricts sessions to direct ignored JSON paths and rejects symlinks', async (context) => {
  const harness = await createHarness(context);
  await assert.rejects(
    initializeTwoAdultE2ESession({
      apkPath: 'synthetic.apk',
      artifactInspector: artifactInspector(),
      deviceAApiLevel: 35,
      deviceBApiLevel: 36,
      environment: 'dev',
      evidencePath: join(harness.repositoryRoot, 'tracked.json'),
      repositoryRoot: harness.repositoryRoot,
    }),
    /session path is invalid/u,
  );

  await initializeTwoAdultE2ESession({
    apkPath: 'synthetic.apk',
    artifactInspector: artifactInspector(),
    deviceAApiLevel: 35,
    deviceBApiLevel: 36,
    environment: 'dev',
    ...harness,
  });
  const linkPath = join(
    harness.repositoryRoot,
    'ci-reports',
    'manual',
    'linked.json',
  );
  await symlink(harness.evidencePath, linkPath);
  await assert.rejects(
    readTwoAdultE2ESessionStatus({
      evidencePath: linkPath,
      repositoryRoot: harness.repositoryRoot,
    }),
    /session file could not be read/u,
  );
});

test('status summary is redacted and does not expose build binding', async (context) => {
  const harness = await createHarness(context);
  await initializeTwoAdultE2ESession({
    apkPath: 'synthetic.apk',
    artifactInspector: artifactInspector(),
    deviceAApiLevel: 35,
    deviceBApiLevel: 36,
    environment: 'dev',
    ...harness,
  });
  const summary = await readTwoAdultE2ESessionStatus(harness);
  const serialized = JSON.stringify(summary);
  const output = formatTwoAdultE2ESessionSummary(summary);
  assert.equal(serialized.includes('a'.repeat(40)), false);
  assert.equal(serialized.includes('b'.repeat(64)), false);
  assert.equal(serialized.includes(harness.evidencePath), false);
  assert.equal(serialized.includes('email'), false);
  assert.equal(output.includes('a'.repeat(40)), false);
  assert.equal(output.includes('b'.repeat(64)), false);
  assert.equal(output.includes(harness.evidencePath), false);
  assert.match(output, /29 not_run/u);
});
