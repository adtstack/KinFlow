import assert from 'node:assert/strict';
import test from 'node:test';

import { androidPublicConfigurationKeys } from './android-public-config.mjs';
import { validateWebPublicConfiguration } from './web-public-config.mjs';

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

test('Web config derives exact Flutter build metadata', () => {
  assert.deepEqual(
    validateWebPublicConfiguration(validConfiguration(), expectations),
    { buildName: '0.1.0-dev', buildNumber: '1' },
  );
});

test('Web config rejects versions without canonical positive build numbers', () => {
  for (const APP_VERSION of [
    '0.1.0-dev',
    '0.1.0-dev+0',
    '0.1.0-dev+01',
    '0.1.0-dev+2147483648',
  ]) {
    assert.throws(
      () =>
        validateWebPublicConfiguration(
          validConfiguration({ APP_VERSION }),
          expectations,
        ),
      /APP_VERSION/u,
    );
  }
});

test('Web config preserves exact public allowlist and flavor binding', () => {
  assert.throws(
    () =>
      validateWebPublicConfiguration(
        validConfiguration({ APP_ENV: 'prod' }),
        expectations,
      ),
    /APP_ENV/u,
  );
  assert.throws(
    () =>
      validateWebPublicConfiguration(
        {
          ...validConfiguration(),
          SUPABASE_SERVICE_ROLE_KEY: 'replace-with-forbidden-test-value',
        },
        expectations,
      ),
    /public key allowlist/u,
  );
});
