import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import {
  loadTwoAdultE2EEvidence,
  maximumTwoAdultEvidenceBytes,
  twoAdultE2ECheckKeys,
  validateTwoAdultE2EEvidence,
  verifyTwoAdultE2ECompletion,
} from './android-two-adult-e2e-evidence.mjs';

const templateUrl = new URL(
  '../../docs/evidence/phase-02/templates/GOOGLE_ANDROID_TWO_ADULT_E2E_TEMPLATE.json',
  import.meta.url,
);

async function loadTemplate() {
  const result = await loadTwoAdultE2EEvidence(templateUrl, {
    requireComplete: false,
  });
  const decoded = JSON.parse(await readFile(templateUrl, 'utf8'));
  return { decoded, result };
}

function completeEvidence(template) {
  const decoded = structuredClone(template);
  decoded.commit = 'a'.repeat(40);
  decoded.artifactSha256 = 'b'.repeat(64);
  decoded.recordedAtUtc = '2026-07-29T02:00:00Z';
  decoded.devices.A.apiLevel = 35;
  decoded.devices.A.preflight = 'pass';
  decoded.devices.B.apiLevel = 36;
  decoded.devices.B.preflight = 'pass';
  for (const key of twoAdultE2ECheckKeys) {
    decoded.checks[key] = 'pass';
  }
  return decoded;
}

test('tracked template is structurally valid but cannot prove completion', async () => {
  const { decoded, result } = await loadTemplate();

  assert.deepEqual(result, {
    applicationId: 'me.newlines.kinflow.dev',
    checkCount: 27,
    completed: false,
    environment: 'dev',
  });
  await assert.rejects(
    loadTwoAdultE2EEvidence(templateUrl),
    /commit is invalid/u,
  );
  assert.equal(
    Object.values(decoded.checks).every((value) => value === 'not_run'),
    true,
  );
});

test('accepts complete evidence and returns a redacted summary', async () => {
  const { decoded } = await loadTemplate();
  const complete = completeEvidence(decoded);
  const result = validateTwoAdultE2EEvidence(complete);

  assert.deepEqual(result, {
    applicationId: 'me.newlines.kinflow.dev',
    checkCount: 27,
    completed: true,
    environment: 'dev',
  });
  const serialized = JSON.stringify(result);
  assert.equal(serialized.includes(complete.commit), false);
  assert.equal(serialized.includes(complete.artifactSha256), false);
  assert.equal(serialized.includes(complete.recordedAtUtc), false);
});

test('binds complete evidence to an existing commit and exact APK digest', async (context) => {
  const directory = await mkdtemp(join(tmpdir(), 'kinflow-e2e-binding-'));
  context.after(async () => {
    await rm(directory, { recursive: true });
  });
  const { decoded } = await loadTemplate();
  const apkBytes = Buffer.from('synthetic APK bytes for contract testing');
  const complete = completeEvidence(decoded);
  complete.artifactSha256 = createHash('sha256')
    .update(apkBytes)
    .digest('hex');
  const evidencePath = join(directory, 'complete.json');
  const apkPath = join(directory, 'app.apk');
  await writeFile(evidencePath, JSON.stringify(complete), 'utf8');
  await writeFile(apkPath, apkBytes);

  let verifiedCommit;
  const result = await verifyTwoAdultE2ECompletion({
    apkPath,
    commitVerifier: async (commit) => {
      verifiedCommit = commit;
      return true;
    },
    evidencePath,
  });
  assert.equal(result.completed, true);
  assert.equal(verifiedCommit, complete.commit);

  complete.artifactSha256 = 'c'.repeat(64);
  await writeFile(evidencePath, JSON.stringify(complete), 'utf8');
  await assert.rejects(
    verifyTwoAdultE2ECompletion({
      apkPath,
      commitVerifier: async () => true,
      evidencePath,
    }),
    /APK SHA-256 does not match/u,
  );
});

test('masks commit and artifact verifier failures', async (context) => {
  const directory = await mkdtemp(join(tmpdir(), 'kinflow-e2e-masking-'));
  context.after(async () => {
    await rm(directory, { recursive: true });
  });
  const { decoded } = await loadTemplate();
  const complete = completeEvidence(decoded);
  const evidencePath = join(directory, 'complete.json');
  await writeFile(evidencePath, JSON.stringify(complete), 'utf8');

  const sensitiveCanary = 'SENSITIVE_VERIFIER_OUTPUT_DO_NOT_EMIT';
  await assert.rejects(
    verifyTwoAdultE2ECompletion({
      apkPath: join(directory, 'missing.apk'),
      commitVerifier: async () => {
        throw new Error(sensitiveCanary);
      },
      evidencePath,
    }),
    (error) => {
      assert.equal(error.message, 'Two-adult E2E commit could not be verified.');
      assert.equal(error.message.includes(sensitiveCanary), false);
      return true;
    },
  );

  await assert.rejects(
    verifyTwoAdultE2ECompletion({
      apkPath: join(directory, 'missing.apk'),
      commitVerifier: async () => true,
      evidencePath,
      fileHasher: async () => {
        throw new Error(sensitiveCanary);
      },
    }),
    (error) => {
      assert.equal(error.message, 'Two-adult E2E APK could not be verified.');
      assert.equal(error.message.includes(sensitiveCanary), false);
      return true;
    },
  );
});

test('rejects incomplete preflight and scenario results', async () => {
  const { decoded } = await loadTemplate();
  const complete = completeEvidence(decoded);

  complete.devices.B.preflight = 'fail';
  assert.throws(
    () => validateTwoAdultE2EEvidence(complete),
    /device preflight is incomplete/u,
  );

  complete.devices.B.preflight = 'pass';
  complete.checks.device_b_invite_accepted = 'not_run';
  assert.throws(
    () => validateTwoAdultE2EEvidence(complete),
    /checks are incomplete/u,
  );
});

test('rejects build, time, device, and result drift', async () => {
  const { decoded } = await loadTemplate();
  const scenarios = [
    {
      mutate: (value) => {
        value.applicationId = 'me.newlines.kinflow';
      },
      pattern: /application ID/u,
    },
    {
      mutate: (value) => {
        value.commit = 'ABC';
      },
      pattern: /commit is invalid/u,
    },
    {
      mutate: (value) => {
        value.artifactSha256 = 'not-a-digest';
      },
      pattern: /APK SHA-256/u,
    },
    {
      mutate: (value) => {
        value.recordedAtUtc = '2026-07-29T02:00:00+09:00';
      },
      pattern: /UTC timestamp/u,
    },
    {
      mutate: (value) => {
        value.devices.B.alias = 'Physical device serial';
      },
      pattern: /device alias/u,
    },
    {
      mutate: (value) => {
        value.devices.A.apiLevel = 23;
      },
      pattern: /Android API level/u,
    },
    {
      mutate: (value) => {
        value.checks.google_cancel_stable = 'unknown';
      },
      pattern: /check result/u,
    },
  ];

  for (const scenario of scenarios) {
    const candidate = completeEvidence(decoded);
    scenario.mutate(candidate);
    assert.throws(
      () => validateTwoAdultE2EEvidence(candidate),
      scenario.pattern,
    );
  }
});

test('rejects free-form identity and secret-shaped fields', async () => {
  const { decoded } = await loadTemplate();

  for (const mutate of [
    (value) => {
      value.notes = 'free form';
    },
    (value) => {
      value.devices.A.serial = 'device-identifier';
    },
    (value) => {
      value.checks.account_email = 'pass';
    },
  ]) {
    const candidate = completeEvidence(decoded);
    mutate(candidate);
    assert.throws(
      () => validateTwoAdultE2EEvidence(candidate),
      /shape|device evidence shape|check set/u,
    );
  }
});

test('rejects malformed and oversized evidence files', async (context) => {
  const directory = await mkdtemp(join(tmpdir(), 'kinflow-e2e-evidence-'));
  context.after(async () => {
    await rm(directory, { recursive: true });
  });

  const malformedPath = join(directory, 'malformed.json');
  await writeFile(malformedPath, '{', 'utf8');
  await assert.rejects(
    loadTwoAdultE2EEvidence(malformedPath),
    /not valid UTF-8 JSON/u,
  );

  const oversizedPath = join(directory, 'oversized.json');
  await writeFile(oversizedPath, 'x'.repeat(maximumTwoAdultEvidenceBytes + 1));
  await assert.rejects(
    loadTwoAdultE2EEvidence(oversizedPath),
    /could not be read|size limit/u,
  );
});
