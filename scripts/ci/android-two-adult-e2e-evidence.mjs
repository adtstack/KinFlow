import { execFile as execFileCallback } from 'node:child_process';
import { createHash } from 'node:crypto';
import { createReadStream } from 'node:fs';
import { readFile, stat } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { promisify } from 'node:util';

export const maximumTwoAdultEvidenceBytes = 32 * 1024;
export const maximumTwoAdultApkBytes = 1024 * 1024 * 1024;

export const twoAdultE2ECheckKeys = Object.freeze([
  'device_a_google_login',
  'device_a_supabase_session',
  'pre_session_protected_route_blocked',
  'household_created_once',
  'device_a_empty_today_opened',
  'invite_issued_once',
  'device_b_invite_link_dispatched_to_app',
  'device_b_cold_start_invite_captured',
  'device_b_google_login',
  'device_b_supabase_session',
  'device_b_invite_restored_after_login',
  'device_b_invite_previewed',
  'device_b_invite_accepted',
  'same_household_visible_on_both_devices',
  'distinct_adult_members_confirmed',
  'device_b_cold_session_restored',
  'device_b_logout_purged',
  'device_b_account_chooser_reopened',
  'device_b_account_switch_isolated',
  'google_cancel_stable',
  'google_offline_stable',
  'wrong_signing_sha_fail_closed',
  'expired_session_fail_closed',
  'revoked_session_fail_closed',
  'offline_launch_stable',
  'invite_replay_idempotent',
  'concurrent_invite_accept_idempotent',
]);

const rootKeys = Object.freeze([
  'applicationId',
  'artifactSha256',
  'checks',
  'commit',
  'contractVersion',
  'devices',
  'environment',
  'recordedAtUtc',
]);
const deviceKeys = Object.freeze(['alias', 'apiLevel', 'preflight']);
const resultCodes = new Set(['fail', 'not_run', 'pass']);
const applicationIds = Object.freeze({
  dev: 'me.newlines.kinflow.dev',
  prod: 'me.newlines.kinflow',
});
const commitPlaceholder = 'replace_with_40_hex_commit';
const artifactPlaceholder = 'replace_with_64_hex_apk_sha256';
const timePlaceholder = 'replace_with_utc_timestamp';
const commitPattern = /^[0-9a-f]{40}$/u;
const artifactSha256Pattern = /^[0-9a-f]{64}$/u;
const utcTimestampPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/u;
const execFile = promisify(execFileCallback);

function isPlainObject(value) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    return false;
  }
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

function hasExactKeys(value, expectedKeys) {
  const actualKeys = Object.keys(value).sort();
  const sortedExpectedKeys = [...expectedKeys].sort();
  return (
    actualKeys.length === sortedExpectedKeys.length &&
    actualKeys.every((key, index) => key === sortedExpectedKeys[index])
  );
}

function validateBuildIdentity(decoded, requireComplete) {
  if (!Object.hasOwn(applicationIds, decoded.environment)) {
    throw new Error('Two-adult E2E environment is invalid.');
  }
  if (decoded.applicationId !== applicationIds[decoded.environment]) {
    throw new Error(
      'Two-adult E2E application ID does not match the environment.',
    );
  }

  const commitIsPlaceholder = decoded.commit === commitPlaceholder;
  if (
    typeof decoded.commit !== 'string' ||
    (!commitPattern.test(decoded.commit) &&
      !(commitIsPlaceholder && !requireComplete))
  ) {
    throw new Error('Two-adult E2E commit is invalid.');
  }

  const artifactIsPlaceholder =
    decoded.artifactSha256 === artifactPlaceholder;
  if (
    typeof decoded.artifactSha256 !== 'string' ||
    (!artifactSha256Pattern.test(decoded.artifactSha256) &&
      !(artifactIsPlaceholder && !requireComplete))
  ) {
    throw new Error('Two-adult E2E APK SHA-256 is invalid.');
  }

  const timeIsPlaceholder = decoded.recordedAtUtc === timePlaceholder;
  if (
    typeof decoded.recordedAtUtc !== 'string' ||
    (!utcTimestampPattern.test(decoded.recordedAtUtc) &&
      !(timeIsPlaceholder && !requireComplete))
  ) {
    throw new Error('Two-adult E2E recorded UTC timestamp is invalid.');
  }
  if (!timeIsPlaceholder) {
    const milliseconds = Date.parse(decoded.recordedAtUtc);
    const canonical = decoded.recordedAtUtc.replace(/Z$/u, '.000Z');
    if (
      !Number.isFinite(milliseconds) ||
      new Date(milliseconds).toISOString() !== canonical
    ) {
      throw new Error('Two-adult E2E recorded UTC timestamp is invalid.');
    }
  }
}

function validateDevice(value, { alias, requireComplete }) {
  if (!isPlainObject(value) || !hasExactKeys(value, deviceKeys)) {
    throw new Error('Two-adult E2E device evidence shape is invalid.');
  }
  if (value.alias !== alias) {
    throw new Error('Two-adult E2E device alias is invalid.');
  }
  if (
    !Number.isSafeInteger(value.apiLevel) ||
    value.apiLevel < 24 ||
    value.apiLevel > 100
  ) {
    throw new Error('Two-adult E2E Android API level is invalid.');
  }
  if (!resultCodes.has(value.preflight)) {
    throw new Error('Two-adult E2E device preflight result is invalid.');
  }
  if (requireComplete && value.preflight !== 'pass') {
    throw new Error('Two-adult E2E device preflight is incomplete.');
  }
}

function validateChecks(value, requireComplete) {
  if (!isPlainObject(value) || !hasExactKeys(value, twoAdultE2ECheckKeys)) {
    throw new Error('Two-adult E2E check set is invalid.');
  }
  for (const key of twoAdultE2ECheckKeys) {
    if (!resultCodes.has(value[key])) {
      throw new Error('Two-adult E2E check result is invalid.');
    }
    if (requireComplete && value[key] !== 'pass') {
      throw new Error('Two-adult E2E checks are incomplete.');
    }
  }
}

export function validateTwoAdultE2EEvidence(
  decoded,
  { requireComplete = true } = {},
) {
  if (!isPlainObject(decoded) || !hasExactKeys(decoded, rootKeys)) {
    throw new Error('Two-adult E2E evidence shape is invalid.');
  }
  if (decoded.contractVersion !== '1') {
    throw new Error('Two-adult E2E contract version is invalid.');
  }
  if (typeof requireComplete !== 'boolean') {
    throw new Error('Two-adult E2E completion mode is invalid.');
  }

  validateBuildIdentity(decoded, requireComplete);
  if (
    !isPlainObject(decoded.devices) ||
    !hasExactKeys(decoded.devices, ['A', 'B'])
  ) {
    throw new Error('Two-adult E2E device set is invalid.');
  }
  validateDevice(decoded.devices.A, {
    alias: 'Device A',
    requireComplete,
  });
  validateDevice(decoded.devices.B, {
    alias: 'Device B',
    requireComplete,
  });
  validateChecks(decoded.checks, requireComplete);

  const completed =
    decoded.devices.A.preflight === 'pass' &&
    decoded.devices.B.preflight === 'pass' &&
    twoAdultE2ECheckKeys.every((key) => decoded.checks[key] === 'pass');
  return Object.freeze({
    applicationId: decoded.applicationId,
    checkCount: twoAdultE2ECheckKeys.length,
    completed,
    environment: decoded.environment,
  });
}

async function readTwoAdultE2EEvidence(path) {
  let metadata;
  try {
    metadata = await stat(path);
  } catch {
    throw new Error('Two-adult E2E evidence file could not be read.');
  }
  if (!metadata.isFile()) {
    throw new Error('Two-adult E2E evidence file could not be read.');
  }
  if (metadata.size > maximumTwoAdultEvidenceBytes) {
    throw new Error('Two-adult E2E evidence file exceeds the size limit.');
  }

  let bytes;
  try {
    bytes = await readFile(path);
  } catch {
    throw new Error('Two-adult E2E evidence file could not be read.');
  }
  if (bytes.byteLength > maximumTwoAdultEvidenceBytes) {
    throw new Error('Two-adult E2E evidence file exceeds the size limit.');
  }

  let decoded;
  try {
    const text = new TextDecoder('utf-8', { fatal: true }).decode(bytes);
    decoded = JSON.parse(text);
  } catch {
    throw new Error('Two-adult E2E evidence file is not valid UTF-8 JSON.');
  }
  return decoded;
}

export async function loadTwoAdultE2EEvidence(
  path,
  { requireComplete = true } = {},
) {
  return validateTwoAdultE2EEvidence(await readTwoAdultE2EEvidence(path), {
    requireComplete,
  });
}

async function verifyCommitExists(commit, cwd = process.cwd()) {
  await execFile('git', ['cat-file', '-e', `${commit}^{commit}`], {
    cwd,
    encoding: 'utf8',
    maxBuffer: 4 * 1024,
    timeout: 10_000,
    windowsHide: true,
  });
  return true;
}

async function sha256File(path) {
  let metadata;
  try {
    metadata = await stat(path);
  } catch {
    throw new Error('Two-adult E2E APK could not be read.');
  }
  if (
    !metadata.isFile() ||
    metadata.size <= 0 ||
    metadata.size > maximumTwoAdultApkBytes
  ) {
    throw new Error('Two-adult E2E APK is invalid.');
  }

  const digest = createHash('sha256');
  try {
    for await (const chunk of createReadStream(path)) {
      digest.update(chunk);
    }
  } catch {
    throw new Error('Two-adult E2E APK could not be read.');
  }
  return digest.digest('hex');
}

export async function verifyTwoAdultE2ECompletion({
  apkPath,
  commitVerifier = verifyCommitExists,
  evidencePath,
  fileHasher = sha256File,
}) {
  const decoded = await readTwoAdultE2EEvidence(evidencePath);
  const result = validateTwoAdultE2EEvidence(decoded);

  let commitExists;
  try {
    commitExists = await commitVerifier(decoded.commit);
  } catch {
    throw new Error('Two-adult E2E commit could not be verified.');
  }
  if (commitExists !== true) {
    throw new Error('Two-adult E2E commit could not be verified.');
  }

  let artifactSha256;
  try {
    artifactSha256 = await fileHasher(apkPath);
  } catch (error) {
    if (
      error instanceof Error &&
      (error.message === 'Two-adult E2E APK could not be read.' ||
        error.message === 'Two-adult E2E APK is invalid.')
    ) {
      throw error;
    }
    throw new Error('Two-adult E2E APK could not be verified.');
  }
  if (
    typeof artifactSha256 !== 'string' ||
    !artifactSha256Pattern.test(artifactSha256) ||
    artifactSha256 !== decoded.artifactSha256
  ) {
    throw new Error('Two-adult E2E APK SHA-256 does not match.');
  }

  return result;
}

async function main() {
  const [evidencePath, apkPath, ...unexpectedArguments] = process.argv.slice(2);
  if (!evidencePath || !apkPath || unexpectedArguments.length > 0) {
    process.stderr.write(
      'Usage: node scripts/ci/android-two-adult-e2e-evidence.mjs <evidence.json> <apk>\n',
    );
    process.exitCode = 64;
    return;
  }

  try {
    const result = await verifyTwoAdultE2ECompletion({
      apkPath,
      evidencePath,
    });
    process.stdout.write(
      `Two-adult Android E2E evidence contract passed: ${result.environment}/${result.applicationId}, ${result.checkCount} checks.\n`,
    );
  } catch (error) {
    process.stderr.write(
      `${error instanceof Error ? error.message : 'Two-adult E2E evidence validation failed.'}\n`,
    );
    process.exitCode = 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
