import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

export const androidPublicConfigurationKeys = Object.freeze([
  'APP_ENV',
  'APP_ID',
  'APP_VERSION',
  'AUTH_REDIRECT_HOST',
  'CONTRACT_VERSION',
  'FEATURE_CONFIG_URL',
  'GOOGLE_WEB_CLIENT_ID',
  'PRIVACY_REQUEST_URL',
  'PUBLIC_SITE_URL',
  'REVENUECAT_ANDROID_PUBLIC_SDK_KEY',
  'SENTRY_DSN',
  'SUPABASE_PUBLISHABLE_KEY',
  'SUPABASE_URL',
  'SUPPORT_URL',
]);

const appLinkHostPattern =
  /^(?=.{1,253}$)(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$/u;

export function validateAndroidAppLinkHost(
  value,
  fieldName = 'Android App Link host',
) {
  if (typeof value !== 'string' || !appLinkHostPattern.test(value)) {
    throw new Error(
      `${fieldName} must be a DNS host without scheme, port, path, wildcard, or whitespace.`,
    );
  }
  return value;
}

export function validateAndroidPublicConfiguration(
  decoded,
  { expectedApplicationId, expectedEnvironment },
) {
  if (decoded === null || typeof decoded !== 'object' || Array.isArray(decoded)) {
    throw new Error('Android public config must be a JSON object.');
  }

  const entries = Object.entries(decoded);
  if (entries.some(([, value]) => typeof value !== 'string')) {
    throw new Error('Android public config values must all be strings.');
  }

  const actualKeys = entries.map(([key]) => key).sort();
  const expectedKeys = [...androidPublicConfigurationKeys].sort();
  if (
    actualKeys.length !== expectedKeys.length ||
    actualKeys.some((key, index) => key !== expectedKeys[index])
  ) {
    throw new Error('Android public config must use the exact public key allowlist.');
  }

  if (decoded.APP_ENV !== expectedEnvironment) {
    throw new Error('Android public config APP_ENV does not match the flavor.');
  }
  if (decoded.APP_ID !== expectedApplicationId) {
    throw new Error('Android public config APP_ID does not match the package.');
  }

  const authRedirectHost = validateAndroidAppLinkHost(
    decoded.AUTH_REDIRECT_HOST,
    'Android public config AUTH_REDIRECT_HOST',
  );

  return Object.freeze({ authRedirectHost });
}

export async function loadAndroidPublicConfiguration(
  path,
  expectations,
) {
  let decoded;
  try {
    decoded = JSON.parse(await readFile(path, 'utf8'));
  } catch {
    throw new Error('Android public config could not be read as JSON.');
  }
  return validateAndroidPublicConfiguration(decoded, expectations);
}

async function main() {
  const [path, expectedEnvironment, expectedApplicationId] = process.argv.slice(2);
  if (!path || !expectedEnvironment || !expectedApplicationId) {
    process.stderr.write(
      'Usage: node scripts/ci/android-public-config.mjs <config.json> <dev|prod> <application-id>\n',
    );
    process.exitCode = 64;
    return;
  }

  const configuration = await loadAndroidPublicConfiguration(path, {
    expectedApplicationId,
    expectedEnvironment,
  });
  process.stdout.write(configuration.authRedirectHost);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
