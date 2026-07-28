import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

export const handleAllUrlsRelation =
  'delegate_permission/common.handle_all_urls';

const packageNamePattern =
  /^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$/u;
const sha256FingerprintPattern =
  /^(?:[0-9A-F]{2}:){31}[0-9A-F]{2}$/u;

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

function validateExpectation(expectedPackageName, expectedFingerprints) {
  if (!packageNamePattern.test(expectedPackageName)) {
    throw new Error('Expected Android package name is invalid.');
  }
  if (
    !Array.isArray(expectedFingerprints) ||
    expectedFingerprints.length === 0 ||
    expectedFingerprints.some(
      (fingerprint) =>
        typeof fingerprint !== 'string' ||
        !sha256FingerprintPattern.test(fingerprint),
    )
  ) {
    throw new Error('Expected Android SHA-256 fingerprints are invalid.');
  }
  if (new Set(expectedFingerprints).size !== expectedFingerprints.length) {
    throw new Error('Expected Android SHA-256 fingerprints must be unique.');
  }
}

export function validateAndroidAssetLinks(
  decoded,
  { expectedPackageName, expectedSha256Fingerprints },
) {
  validateExpectation(expectedPackageName, expectedSha256Fingerprints);

  if (!Array.isArray(decoded) || decoded.length !== 1) {
    throw new Error(
      'Android asset links must contain exactly one environment-specific statement.',
    );
  }

  const [statement] = decoded;
  if (
    !isPlainObject(statement) ||
    !hasExactKeys(statement, ['relation', 'target'])
  ) {
    throw new Error('Android asset links statement shape is invalid.');
  }
  if (
    !Array.isArray(statement.relation) ||
    statement.relation.length !== 1 ||
    statement.relation[0] !== handleAllUrlsRelation
  ) {
    throw new Error('Android asset links relation is invalid.');
  }

  const target = statement.target;
  if (
    !isPlainObject(target) ||
    !hasExactKeys(target, [
      'namespace',
      'package_name',
      'sha256_cert_fingerprints',
    ])
  ) {
    throw new Error('Android asset links target shape is invalid.');
  }
  if (target.namespace !== 'android_app') {
    throw new Error('Android asset links namespace is invalid.');
  }
  if (
    typeof target.package_name !== 'string' ||
    !packageNamePattern.test(target.package_name) ||
    target.package_name !== expectedPackageName
  ) {
    throw new Error('Android asset links package does not match the environment.');
  }

  const fingerprints = target.sha256_cert_fingerprints;
  if (
    !Array.isArray(fingerprints) ||
    fingerprints.length === 0 ||
    fingerprints.some(
      (fingerprint) =>
        typeof fingerprint !== 'string' ||
        !sha256FingerprintPattern.test(fingerprint),
    )
  ) {
    throw new Error('Android asset links SHA-256 fingerprint list is invalid.');
  }
  if (new Set(fingerprints).size !== fingerprints.length) {
    throw new Error('Android asset links SHA-256 fingerprints must be unique.');
  }

  const expected = [...expectedSha256Fingerprints].sort();
  const actual = [...fingerprints].sort();
  if (
    actual.length !== expected.length ||
    actual.some((fingerprint, index) => fingerprint !== expected[index])
  ) {
    throw new Error(
      'Android asset links SHA-256 fingerprints do not match the installed artifact.',
    );
  }

  return Object.freeze({
    packageName: target.package_name,
    sha256CertFingerprints: Object.freeze([...fingerprints]),
  });
}

export async function loadAndroidAssetLinks(path, expectations) {
  let decoded;
  try {
    decoded = JSON.parse(await readFile(path, 'utf8'));
  } catch {
    throw new Error('Android asset links file could not be read as JSON.');
  }
  return validateAndroidAssetLinks(decoded, expectations);
}

async function main() {
  const [path, expectedPackageName, ...expectedSha256Fingerprints] =
    process.argv.slice(2);
  if (
    !path ||
    !expectedPackageName ||
    expectedSha256Fingerprints.length === 0
  ) {
    process.stderr.write(
      'Usage: node scripts/ci/android-asset-links.mjs <assetlinks.json> <package> <sha256> [sha256...]\n',
    );
    process.exitCode = 64;
    return;
  }

  await loadAndroidAssetLinks(path, {
    expectedPackageName,
    expectedSha256Fingerprints,
  });
  process.stdout.write('Android asset links contract passed.\n');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
