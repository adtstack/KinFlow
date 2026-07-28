import assert from 'node:assert/strict';
import test from 'node:test';

import {
  androidPublicConfigurationKeys,
  validateAndroidPublicConfiguration,
} from './android-public-config.mjs';

function validConfiguration(overrides = {}) {
  const values = Object.fromEntries(
    androidPublicConfigurationKeys.map((key) => [key, '']),
  );
  return {
    ...values,
    APP_ENV: 'dev',
    APP_ID: 'me.newlines.kinflow.dev',
    APP_VERSION: '0.1.0-dev+1',
    AUTH_REDIRECT_HOST: 'auth.dev.kinflow.example',
    CONTRACT_VERSION: '2026-07-25',
    ...overrides,
  };
}

const expectations = {
  expectedApplicationId: 'me.newlines.kinflow.dev',
  expectedEnvironment: 'dev',
};

test('Android public config binds the exact flavor, package, and DNS host', () => {
  const result = validateAndroidPublicConfiguration(
    validConfiguration(),
    expectations,
  );

  assert.equal(result.authRedirectHost, 'auth.dev.kinflow.example');
});

test('Android public config rejects environment and package drift', () => {
  assert.throws(
    () =>
      validateAndroidPublicConfiguration(
        validConfiguration({ APP_ENV: 'prod' }),
        expectations,
      ),
    /APP_ENV/u,
  );
  assert.throws(
    () =>
      validateAndroidPublicConfiguration(
        validConfiguration({ APP_ID: 'me.newlines.kinflow' }),
        expectations,
      ),
    /APP_ID/u,
  );
});

test('Android public config rejects unsafe App Link host forms', () => {
  for (const invalidHost of [
    'https://auth.example.com',
    'auth.example.com/invite',
    'auth.example.com:443',
    '*.example.com',
    ' auth.example.com',
    'localhost',
    '127.0.0.1',
  ]) {
    assert.throws(
      () =>
        validateAndroidPublicConfiguration(
          validConfiguration({ AUTH_REDIRECT_HOST: invalidHost }),
          expectations,
        ),
      /AUTH_REDIRECT_HOST/u,
    );
  }
});

test('Android public config rejects unknown, missing, and non-string values', () => {
  assert.throws(
    () =>
      validateAndroidPublicConfiguration(
        {
          ...validConfiguration(),
          GOOGLE_CLIENT_SECRET: 'replace-with-server-secret',
        },
        expectations,
      ),
    /public key allowlist/u,
  );

  const missing = validConfiguration();
  delete missing.GOOGLE_WEB_CLIENT_ID;
  assert.throws(
    () => validateAndroidPublicConfiguration(missing, expectations),
    /public key allowlist/u,
  );

  assert.throws(
    () =>
      validateAndroidPublicConfiguration(
        validConfiguration({ APP_VERSION: 1 }),
        expectations,
      ),
    /values must all be strings/u,
  );
});
