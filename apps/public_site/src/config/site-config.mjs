import { policyContentManifest } from './policy-content-manifest.mjs';

const DEVELOPMENT_DEFAULTS = Object.freeze({
  SITE_RELEASE_MODE: 'development',
  PUBLIC_SITE_ORIGIN: 'https://example.invalid',
  PUBLIC_SUPPORT_EMAIL: 'support@example.invalid',
  PUBLIC_DEVELOPER_NAME: 'KinFlow',
  PUBLIC_LEGAL_ENTITY_NAME: 'KinFlow development operator',
  PUBLIC_POLICY_VERSION: 'draft-2026-08-09',
  PUBLIC_POLICY_PUBLISHED_ON: '2026-08-09',
  PUBLIC_POLICY_STATUS: 'draft',
});

const RESERVED_HOSTS = new Set([
  'example.com',
  'example.net',
  'example.org',
  'localhost',
]);

const RESERVED_SUFFIXES = ['.example', '.invalid', '.localhost', '.test'];
const PLACEHOLDER_PATTERN = /(?:draft|example|placeholder|replace|tbd|test)/iu;
const VERSION_PATTERN = /^[a-z0-9][a-z0-9._-]{2,63}$/iu;
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/u;
const EMAIL_PATTERN = /^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$/iu;

function required(environment, key, production) {
  const fallback = production ? undefined : DEVELOPMENT_DEFAULTS[key];
  const value = environment[key] ?? fallback;
  if (typeof value !== 'string' || value.trim() === '') {
    throw new Error(`Missing public-site configuration: ${key}`);
  }
  if (value !== value.trim() || /[\r\n\0]/u.test(value)) {
    throw new Error(`Invalid public-site configuration: ${key}`);
  }
  return value;
}

function isReservedHost(hostname) {
  const normalized = hostname.toLowerCase();
  return (
    RESERVED_HOSTS.has(normalized) ||
    RESERVED_SUFFIXES.some((suffix) => normalized.endsWith(suffix))
  );
}

function parseOrigin(rawOrigin, production) {
  let origin;
  try {
    origin = new URL(rawOrigin);
  } catch {
    throw new Error('PUBLIC_SITE_ORIGIN must be an absolute URL');
  }

  if (
    origin.protocol !== 'https:' ||
    origin.username !== '' ||
    origin.password !== '' ||
    origin.port !== '' ||
    origin.pathname !== '/' ||
    origin.search !== '' ||
    origin.hash !== ''
  ) {
    throw new Error('PUBLIC_SITE_ORIGIN must be a credential-free HTTPS root origin');
  }
  if (production && isReservedHost(origin.hostname)) {
    throw new Error('PUBLIC_SITE_ORIGIN cannot use a reserved production hostname');
  }
  return origin.origin;
}

function parseSupportEmail(rawEmail, production) {
  if (!EMAIL_PATTERN.test(rawEmail)) {
    throw new Error('PUBLIC_SUPPORT_EMAIL must be one mailbox without a display name');
  }
  const domain = rawEmail.slice(rawEmail.lastIndexOf('@') + 1);
  if (production && isReservedHost(domain)) {
    throw new Error('PUBLIC_SUPPORT_EMAIL cannot use a reserved production domain');
  }
  return rawEmail;
}

function parsePublishedOn(rawDate) {
  if (!DATE_PATTERN.test(rawDate)) {
    throw new Error('PUBLIC_POLICY_PUBLISHED_ON must be an ISO calendar date');
  }
  const parsed = new Date(`${rawDate}T00:00:00.000Z`);
  if (Number.isNaN(parsed.valueOf()) || parsed.toISOString().slice(0, 10) !== rawDate) {
    throw new Error('PUBLIC_POLICY_PUBLISHED_ON must be a valid ISO calendar date');
  }
  return rawDate;
}

function parsePublicName(rawName, key, production) {
  if (rawName.length < 2 || rawName.length > 120 || /[<>\r\n\0]/u.test(rawName)) {
    throw new Error(`${key} is invalid`);
  }
  if (production && PLACEHOLDER_PATTERN.test(rawName)) {
    throw new Error(`${key} cannot be a production placeholder`);
  }
  return rawName;
}

function parsePolicyVersion(rawVersion, production) {
  if (!VERSION_PATTERN.test(rawVersion)) {
    throw new Error('PUBLIC_POLICY_VERSION is invalid');
  }
  if (production && PLACEHOLDER_PATTERN.test(rawVersion)) {
    throw new Error('PUBLIC_POLICY_VERSION cannot be a production placeholder');
  }
  return rawVersion;
}

function mailto(email, subject) {
  return `mailto:${email}?subject=${encodeURIComponent(subject)}`;
}

export function loadSiteConfig(
  environment = {},
  contentManifest = policyContentManifest,
) {
  const mode = environment.SITE_RELEASE_MODE ?? DEVELOPMENT_DEFAULTS.SITE_RELEASE_MODE;
  if (mode !== 'development' && mode !== 'production') {
    throw new Error('SITE_RELEASE_MODE must be development or production');
  }
  const production = mode === 'production';
  if (
    contentManifest === null ||
    typeof contentManifest !== 'object' ||
    !VERSION_PATTERN.test(contentManifest.revision ?? '') ||
    (contentManifest.status !== 'draft' && contentManifest.status !== 'approved')
  ) {
    throw new Error('Public policy content manifest is invalid');
  }
  if (production && contentManifest.status !== 'approved') {
    throw new Error('Public policy content is not approved for production');
  }
  const policyStatus = required(environment, 'PUBLIC_POLICY_STATUS', production);
  if ((production && policyStatus !== 'approved') || (!production && policyStatus !== 'draft')) {
    throw new Error('PUBLIC_POLICY_STATUS must match the release mode');
  }

  const origin = parseOrigin(
    required(environment, 'PUBLIC_SITE_ORIGIN', production),
    production,
  );
  const supportEmail = parseSupportEmail(
    required(environment, 'PUBLIC_SUPPORT_EMAIL', production),
    production,
  );
  const developerName = parsePublicName(
    required(environment, 'PUBLIC_DEVELOPER_NAME', production),
    'PUBLIC_DEVELOPER_NAME',
    production,
  );
  const legalEntityName = parsePublicName(
    required(environment, 'PUBLIC_LEGAL_ENTITY_NAME', production),
    'PUBLIC_LEGAL_ENTITY_NAME',
    production,
  );
  const policyVersion = parsePolicyVersion(
    required(environment, 'PUBLIC_POLICY_VERSION', production),
    production,
  );
  const publishedOn = parsePublishedOn(
    required(environment, 'PUBLIC_POLICY_PUBLISHED_ON', production),
  );

  return Object.freeze({
    mode,
    production,
    origin,
    supportEmail,
    developerName,
    legalEntityName,
    policyVersion,
    publishedOn,
    policyStatus,
    policyContentRevision: contentManifest.revision,
    policyContentStatus: contentManifest.status,
    robots: production ? 'index, follow' : 'noindex, nofollow',
    supportMailto: mailto(supportEmail, 'KinFlow support request'),
    deletionMailto: mailto(supportEmail, 'KinFlow account deletion request'),
  });
}

export const siteConfig = loadSiteConfig(process.env);
