import assert from 'node:assert/strict';
import test from 'node:test';

import { loadSiteConfig } from '../src/config/site-config.mjs';

const validProductionEnvironment = Object.freeze({
  SITE_RELEASE_MODE: 'production',
  PUBLIC_SITE_ORIGIN: 'https://kinflow.app',
  PUBLIC_SUPPORT_EMAIL: 'privacy@kinflow.app',
  PUBLIC_DEVELOPER_NAME: 'KinFlow',
  PUBLIC_LEGAL_ENTITY_NAME: 'Newlines Studio',
  PUBLIC_POLICY_VERSION: '2026-08-09.1',
  PUBLIC_POLICY_PUBLISHED_ON: '2026-08-09',
  PUBLIC_POLICY_STATUS: 'approved',
});

const approvedContentManifest = Object.freeze({
  revision: '2026-08-09-wp07-07b-approved-1',
  status: 'approved',
});

test('development defaults are visibly draft and non-indexable', () => {
  const config = loadSiteConfig({});

  assert.equal(config.mode, 'development');
  assert.equal(config.production, false);
  assert.equal(config.origin, 'https://example.invalid');
  assert.equal(config.supportEmail, 'support@example.invalid');
  assert.equal(config.policyStatus, 'draft');
  assert.equal(config.robots, 'noindex, nofollow');
  assert.equal(
    config.deletionMailto,
    'mailto:support@example.invalid?subject=KinFlow%20account%20deletion%20request',
  );
  assert.equal(config.deletionMailto.includes('body='), false);
});

test('approved production configuration creates exact content-free mailto links', () => {
  const config = loadSiteConfig(
    validProductionEnvironment,
    approvedContentManifest,
  );

  assert.equal(config.production, true);
  assert.equal(config.origin, 'https://kinflow.app');
  assert.equal(config.policyStatus, 'approved');
  assert.equal(config.robots, 'index, follow');
  assert.equal(
    config.supportMailto,
    'mailto:privacy@kinflow.app?subject=KinFlow%20support%20request',
  );
  assert.equal(
    config.deletionMailto,
    'mailto:privacy@kinflow.app?subject=KinFlow%20account%20deletion%20request',
  );
  assert.doesNotMatch(config.deletionMailto, /body=|user|household|token|receipt/iu);
});

test('source-controlled draft content blocks a production build configuration', () => {
  assert.throws(
    () => loadSiteConfig(validProductionEnvironment),
    /content is not approved for production/u,
  );
});

test('production configuration fails closed when any authority is missing', () => {
  for (const key of Object.keys(validProductionEnvironment)) {
    if (key === 'SITE_RELEASE_MODE') {
      continue;
    }
    const incomplete = { ...validProductionEnvironment };
    delete incomplete[key];
    assert.throws(
      () => loadSiteConfig(incomplete, approvedContentManifest),
      { name: 'Error' },
      key,
    );
  }
});

test('release mode and policy approval must agree', () => {
  assert.throws(() => loadSiteConfig({ SITE_RELEASE_MODE: 'preview' }));
  assert.throws(() =>
    loadSiteConfig(
      {
        ...validProductionEnvironment,
        PUBLIC_POLICY_STATUS: 'draft',
      },
      approvedContentManifest,
    ),
  );
  assert.throws(() =>
    loadSiteConfig({
      SITE_RELEASE_MODE: 'development',
      PUBLIC_POLICY_STATUS: 'approved',
    }),
  );
});

test('production origin is an owned-shaped credential-free HTTPS root', () => {
  const invalidOrigins = [
    'http://kinflow.app',
    'https://user:password@kinflow.app',
    'https://kinflow.app:8443',
    'https://kinflow.app/legal',
    'https://kinflow.app?source=store',
    'https://kinflow.app/#privacy',
    'https://localhost',
    'https://example.invalid',
    'not-a-url',
  ];

  for (const origin of invalidOrigins) {
    assert.throws(
      () =>
        loadSiteConfig(
          {
            ...validProductionEnvironment,
            PUBLIC_SITE_ORIGIN: origin,
          },
          approvedContentManifest,
        ),
      { name: 'Error' },
      origin,
    );
  }
});

test('production mailbox and public names reject injection and placeholders', () => {
  const invalidEmails = [
    'KinFlow <privacy@kinflow.app>',
    'privacy@localhost',
    'privacy@example.invalid',
    'privacy@kinflow.app\nBcc: attacker@example.com',
  ];
  for (const email of invalidEmails) {
    assert.throws(() =>
      loadSiteConfig(
        {
          ...validProductionEnvironment,
          PUBLIC_SUPPORT_EMAIL: email,
        },
        approvedContentManifest,
      ),
    );
  }

  for (const [key, value] of [
    ['PUBLIC_DEVELOPER_NAME', 'TBD developer'],
    ['PUBLIC_LEGAL_ENTITY_NAME', 'Example operator'],
    ['PUBLIC_LEGAL_ENTITY_NAME', '<script>'],
    ['PUBLIC_POLICY_VERSION', 'draft-2026-08-09'],
    ['PUBLIC_POLICY_VERSION', 'v 1'],
    ['PUBLIC_POLICY_PUBLISHED_ON', '2026-02-30'],
  ]) {
    assert.throws(() =>
      loadSiteConfig(
        {
          ...validProductionEnvironment,
          [key]: value,
        },
        approvedContentManifest,
      ),
    );
  }
});
