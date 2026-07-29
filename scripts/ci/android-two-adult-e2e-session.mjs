import { randomUUID } from 'node:crypto';
import {
  lstat,
  mkdir,
  realpath,
  rename,
  unlink,
  writeFile,
} from 'node:fs/promises';
import { basename, dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import {
  inspectTwoAdultE2EApk,
  readTwoAdultE2EEvidence,
  twoAdultApplicationIds,
  twoAdultE2ECheckKeys,
  validateTwoAdultE2EEvidence,
} from './android-two-adult-e2e-evidence.mjs';

const repositoryRootFromModule = fileURLToPath(new URL('../..', import.meta.url));
const resultCodes = new Set(['fail', 'not_run', 'pass']);
const preflightTargets = Object.freeze({
  device_a_preflight: 'A',
  device_b_preflight: 'B',
});
const sessionFileNamePattern = /^[a-z0-9][a-z0-9._-]*\.json$/u;

function canonicalUtcTimestamp(clock) {
  const value = clock();
  const date = value instanceof Date ? value : new Date(value);
  if (!Number.isFinite(date.getTime())) {
    throw new Error('Two-adult E2E session clock is invalid.');
  }
  return date.toISOString().replace(/\.\d{3}Z$/u, 'Z');
}

function validateApiLevel(value) {
  if (!Number.isSafeInteger(value) || value < 24 || value > 100) {
    throw new Error('Two-adult E2E session Android API level is invalid.');
  }
}

async function resolveManualEvidencePath(
  evidencePath,
  { createRoot = false, repositoryRoot },
) {
  if (typeof evidencePath !== 'string' || evidencePath.length === 0) {
    throw new Error('Two-adult E2E session path is invalid.');
  }
  const manualRoot = resolve(repositoryRoot, 'ci-reports', 'manual');
  const candidate = resolve(repositoryRoot, evidencePath);
  const candidateRelative = relative(manualRoot, candidate);
  if (
    dirname(candidate) !== manualRoot ||
    candidateRelative === '' ||
    candidateRelative === '..' ||
    candidateRelative.startsWith(`..${sep}`) ||
    !sessionFileNamePattern.test(basename(candidate))
  ) {
    throw new Error('Two-adult E2E session path is invalid.');
  }

  if (createRoot) {
    try {
      await mkdir(manualRoot, { mode: 0o700, recursive: true });
    } catch {
      throw new Error('Two-adult E2E manual report directory is unavailable.');
    }
  }
  let rootMetadata;
  let canonicalRoot;
  let canonicalRepositoryRoot;
  try {
    [rootMetadata, canonicalRoot, canonicalRepositoryRoot] = await Promise.all([
      lstat(manualRoot),
      realpath(manualRoot),
      realpath(repositoryRoot),
    ]);
  } catch {
    throw new Error('Two-adult E2E manual report directory is unavailable.');
  }
  if (
    !rootMetadata.isDirectory() ||
    rootMetadata.isSymbolicLink() ||
    canonicalRoot !== resolve(canonicalRepositoryRoot, 'ci-reports', 'manual')
  ) {
    throw new Error('Two-adult E2E manual report directory is unavailable.');
  }
  return Object.freeze({ candidate, manualRoot });
}

async function requireRegularSessionFile(path) {
  let metadata;
  try {
    metadata = await lstat(path);
  } catch {
    throw new Error('Two-adult E2E session file could not be read.');
  }
  if (!metadata.isFile() || metadata.isSymbolicLink()) {
    throw new Error('Two-adult E2E session file could not be read.');
  }
}

function serializeSession(evidence) {
  validateTwoAdultE2EEvidence(evidence, { requireComplete: false });
  return `${JSON.stringify(evidence, null, 2)}\n`;
}

async function writeNewSession(path, evidence) {
  try {
    await writeFile(path, serializeSession(evidence), {
      encoding: 'utf8',
      flag: 'wx',
      mode: 0o600,
    });
  } catch {
    throw new Error('Two-adult E2E session file already exists or could not be written.');
  }
}

async function replaceSessionAtomically(path, manualRoot, evidence) {
  const temporaryPath = join(
    manualRoot,
    `.${basename(path)}.${randomUUID()}.tmp`,
  );
  let temporaryCreated = false;
  try {
    await writeFile(temporaryPath, serializeSession(evidence), {
      encoding: 'utf8',
      flag: 'wx',
      mode: 0o600,
    });
    temporaryCreated = true;
    await rename(temporaryPath, path);
  } catch {
    if (temporaryCreated) {
      await unlink(temporaryPath).catch(() => {});
    }
    throw new Error('Two-adult E2E session file could not be updated.');
  }
}

export function summarizeTwoAdultE2ESession(evidence) {
  const validated = validateTwoAdultE2EEvidence(evidence, {
    requireComplete: false,
  });
  const results = [
    evidence.devices.A.preflight,
    evidence.devices.B.preflight,
    ...twoAdultE2ECheckKeys.map((key) => evidence.checks[key]),
  ];
  const count = (result) => results.filter((value) => value === result).length;
  return Object.freeze({
    applicationId: validated.applicationId,
    checkCount: validated.checkCount,
    environment: validated.environment,
    failCount: count('fail'),
    notRunCount: count('not_run'),
    passCount: count('pass'),
    resultCount: results.length,
  });
}

export async function initializeTwoAdultE2ESession({
  apkPath,
  artifactInspector = inspectTwoAdultE2EApk,
  clock = () => new Date(),
  deviceAApiLevel,
  deviceBApiLevel,
  environment,
  evidencePath,
  repositoryRoot = repositoryRootFromModule,
}) {
  if (!Object.hasOwn(twoAdultApplicationIds, environment)) {
    throw new Error('Two-adult E2E session environment is invalid.');
  }
  validateApiLevel(deviceAApiLevel);
  validateApiLevel(deviceBApiLevel);
  const { candidate } = await resolveManualEvidencePath(evidencePath, {
    createRoot: true,
    repositoryRoot,
  });
  const expectedApplicationId = twoAdultApplicationIds[environment];
  const artifact = await artifactInspector({
    apkPath,
    expectedApplicationId,
  });
  const evidence = {
    contractVersion: '1',
    environment,
    applicationId: artifact.applicationId,
    commit: artifact.commit,
    artifactSha256: artifact.artifactSha256,
    recordedAtUtc: canonicalUtcTimestamp(clock),
    devices: {
      A: {
        alias: 'Device A',
        apiLevel: deviceAApiLevel,
        preflight: 'not_run',
      },
      B: {
        alias: 'Device B',
        apiLevel: deviceBApiLevel,
        preflight: 'not_run',
      },
    },
    checks: Object.fromEntries(
      twoAdultE2ECheckKeys.map((key) => [key, 'not_run']),
    ),
  };
  await writeNewSession(candidate, evidence);
  return summarizeTwoAdultE2ESession(evidence);
}

export async function recordTwoAdultE2EResult({
  clock = () => new Date(),
  evidencePath,
  repositoryRoot = repositoryRootFromModule,
  result,
  target,
}) {
  if (!resultCodes.has(result)) {
    throw new Error('Two-adult E2E session result is invalid.');
  }
  const isPreflight = Object.hasOwn(preflightTargets, target);
  if (!isPreflight && !twoAdultE2ECheckKeys.includes(target)) {
    throw new Error('Two-adult E2E session target is invalid.');
  }
  const { candidate, manualRoot } = await resolveManualEvidencePath(
    evidencePath,
    { repositoryRoot },
  );
  await requireRegularSessionFile(candidate);
  const evidence = await readTwoAdultE2EEvidence(candidate);
  validateTwoAdultE2EEvidence(evidence, { requireComplete: false });
  if (isPreflight) {
    evidence.devices[preflightTargets[target]].preflight = result;
  } else {
    evidence.checks[target] = result;
  }
  evidence.recordedAtUtc = canonicalUtcTimestamp(clock);
  await replaceSessionAtomically(candidate, manualRoot, evidence);
  return summarizeTwoAdultE2ESession(evidence);
}

export async function readTwoAdultE2ESessionStatus({
  evidencePath,
  repositoryRoot = repositoryRootFromModule,
}) {
  const { candidate } = await resolveManualEvidencePath(evidencePath, {
    repositoryRoot,
  });
  await requireRegularSessionFile(candidate);
  return summarizeTwoAdultE2ESession(
    await readTwoAdultE2EEvidence(candidate),
  );
}

export function formatTwoAdultE2ESessionSummary(summary) {
  return `Two-adult E2E session: ${summary.environment}/${summary.applicationId}, ${summary.checkCount} checks, ${summary.passCount} pass, ${summary.failCount} fail, ${summary.notRunCount} not_run.`;
}

function printSummary(summary) {
  process.stdout.write(`${formatTwoAdultE2ESessionSummary(summary)}\n`);
}

function parseApiLevel(value) {
  if (!/^\d+$/u.test(value ?? '')) {
    throw new Error('Two-adult E2E session Android API level is invalid.');
  }
  return Number(value);
}

async function main() {
  const [command, ...arguments_] = process.argv.slice(2);
  try {
    if (command === 'init' && arguments_.length === 5) {
      const [evidencePath, apkPath, environment, deviceAApi, deviceBApi] =
        arguments_;
      printSummary(
        await initializeTwoAdultE2ESession({
          apkPath,
          deviceAApiLevel: parseApiLevel(deviceAApi),
          deviceBApiLevel: parseApiLevel(deviceBApi),
          environment,
          evidencePath,
        }),
      );
      return;
    }
    if (command === 'record' && arguments_.length === 3) {
      const [evidencePath, target, result] = arguments_;
      printSummary(
        await recordTwoAdultE2EResult({ evidencePath, result, target }),
      );
      return;
    }
    if (command === 'status' && arguments_.length === 1) {
      printSummary(
        await readTwoAdultE2ESessionStatus({ evidencePath: arguments_[0] }),
      );
      return;
    }
    process.stderr.write(
      'Usage: node scripts/ci/android-two-adult-e2e-session.mjs <init|record|status> ...\n',
    );
    process.exitCode = 64;
  } catch (error) {
    process.stderr.write(
      `${error instanceof Error ? error.message : 'Two-adult E2E session command failed.'}\n`,
    );
    process.exitCode = 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
