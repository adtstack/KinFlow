import assert from 'node:assert/strict';
import test from 'node:test';

import {
  handleAllUrlsRelation,
  loadAndroidAssetLinks,
  validateAndroidAssetLinks,
} from './android-asset-links.mjs';

const devPackage = 'me.newlines.kinflow.dev';
const devFingerprint =
  '6A:C5:22:6C:F7:1B:20:1C:99:49:E8:1F:75:14:49:AD:94:53:64:A9:46:5C:ED:0C:69:19:00:51:C5:6E:C7:D5';
const otherFingerprint =
  '00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF';

const expectations = {
  expectedPackageName: devPackage,
  expectedSha256Fingerprints: [devFingerprint],
};
const checkedInDevAssetLinks = new URL(
  '../../apps/public_site/public/.well-known/assetlinks.json',
  import.meta.url,
);

function validStatement(overrides = {}) {
  return [
    {
      relation: [handleAllUrlsRelation],
      target: {
        namespace: 'android_app',
        package_name: devPackage,
        sha256_cert_fingerprints: [devFingerprint],
        ...overrides,
      },
    },
  ];
}

test('validates the exact dev package and signing fingerprint', () => {
  const result = validateAndroidAssetLinks(validStatement(), expectations);

  assert.equal(result.packageName, devPackage);
  assert.deepEqual(result.sha256CertFingerprints, [devFingerprint]);
});

test('checked-in dev statement matches the current dev association', async () => {
  const result = await loadAndroidAssetLinks(
    checkedInDevAssetLinks,
    expectations,
  );

  assert.equal(result.packageName, devPackage);
  assert.deepEqual(result.sha256CertFingerprints, [devFingerprint]);
});

test('rejects malformed statement, relation, namespace, and extra fields', () => {
  assert.throws(
    () => validateAndroidAssetLinks({}, expectations),
    /exactly one/u,
  );
  assert.throws(
    () =>
      validateAndroidAssetLinks(
        [{ ...validStatement()[0], relation: ['unknown/relation'] }],
        expectations,
      ),
    /relation/u,
  );
  assert.throws(
    () =>
      validateAndroidAssetLinks(
        validStatement({ namespace: 'web' }),
        expectations,
      ),
    /namespace/u,
  );
  assert.throws(
    () =>
      validateAndroidAssetLinks(
        [{ ...validStatement()[0], include: ['https://example.invalid'] }],
        expectations,
      ),
    /statement shape/u,
  );
});

test('rejects package and SHA-256 fingerprint drift', () => {
  assert.throws(
    () =>
      validateAndroidAssetLinks(
        validStatement({ package_name: 'me.newlines.kinflow' }),
        expectations,
      ),
    /package/u,
  );
  assert.throws(
    () =>
      validateAndroidAssetLinks(
        validStatement({ sha256_cert_fingerprints: [otherFingerprint] }),
        expectations,
      ),
    /installed artifact/u,
  );
  assert.throws(
    () =>
      validateAndroidAssetLinks(
        validStatement({ sha256_cert_fingerprints: ['not-a-fingerprint'] }),
        expectations,
      ),
    /fingerprint list/u,
  );
});

test('rejects duplicate fingerprints and additional app associations', () => {
  assert.throws(
    () =>
      validateAndroidAssetLinks(
        validStatement({
          sha256_cert_fingerprints: [devFingerprint, devFingerprint],
        }),
        expectations,
      ),
    /must be unique/u,
  );
  assert.throws(
    () =>
      validateAndroidAssetLinks(
        [...validStatement(), ...validStatement()],
        expectations,
      ),
    /exactly one/u,
  );
});
