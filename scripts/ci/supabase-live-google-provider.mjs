import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

import { validateAndroidPublicConfiguration } from './android-public-config.mjs';

export const maximumSupabaseSettingsBytes = 64 * 1024;

const projectHostPattern = /^[a-z0-9]{20}\.supabase\.co$/u;
const publishableKeyPattern =
  /^(?:sb_publishable_[A-Za-z0-9_-]+|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/u;

function validatePublicEndpoint(urlValue, publishableKey) {
  let url;
  try {
    url = new URL(urlValue);
  } catch {
    throw new Error('Supabase public URL is invalid.');
  }
  if (
    url.protocol !== 'https:' ||
    url.username !== '' ||
    url.password !== '' ||
    url.port !== '' ||
    url.pathname !== '/' ||
    url.search !== '' ||
    url.hash !== '' ||
    !projectHostPattern.test(url.hostname)
  ) {
    throw new Error('Supabase public URL must be an exact project HTTPS origin.');
  }
  if (
    typeof publishableKey !== 'string' ||
    !publishableKeyPattern.test(publishableKey)
  ) {
    throw new Error('Supabase publishable key format is invalid.');
  }
  return Object.freeze({
    publishableKey,
    settingsUrl: new URL('/auth/v1/settings', url).href,
  });
}

function parseContentLength(value) {
  if (value === null) {
    return null;
  }
  if (!/^\d+$/u.test(value)) {
    throw new Error('Supabase Auth settings Content-Length is invalid.');
  }
  const length = Number(value);
  if (!Number.isSafeInteger(length)) {
    throw new Error('Supabase Auth settings Content-Length is invalid.');
  }
  return length;
}

async function readBoundedJson(response) {
  if (response.body === null || typeof response.body?.getReader !== 'function') {
    throw new Error('Supabase Auth settings body could not be read.');
  }

  const reader = response.body.getReader();
  const chunks = [];
  let totalBytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) {
        break;
      }
      if (!(value instanceof Uint8Array)) {
        throw new Error('Supabase Auth settings body could not be read.');
      }
      totalBytes += value.byteLength;
      if (totalBytes > maximumSupabaseSettingsBytes) {
        await reader.cancel().catch(() => {});
        throw new Error('Supabase Auth settings body exceeds the size limit.');
      }
      chunks.push(value);
    }
  } catch (error) {
    if (
      error instanceof Error &&
      (error.message === 'Supabase Auth settings body could not be read.' ||
        error.message === 'Supabase Auth settings body exceeds the size limit.')
    ) {
      throw error;
    }
    throw new Error('Supabase Auth settings body could not be read.');
  } finally {
    reader.releaseLock();
  }

  const bytes = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }

  try {
    const text = new TextDecoder('utf-8', { fatal: true }).decode(bytes);
    return JSON.parse(text);
  } catch {
    throw new Error('Supabase Auth settings body is not valid UTF-8 JSON.');
  }
}

export async function probeSupabaseGoogleProvider({
  fetchImpl = globalThis.fetch,
  publishableKey,
  timeoutMilliseconds = 10_000,
  url,
}) {
  const endpoint = validatePublicEndpoint(url, publishableKey);
  if (typeof fetchImpl !== 'function') {
    throw new Error('HTTPS fetch implementation is unavailable.');
  }
  if (
    !Number.isSafeInteger(timeoutMilliseconds) ||
    timeoutMilliseconds <= 0
  ) {
    throw new Error('Supabase Auth settings timeout is invalid.');
  }

  let response;
  try {
    response = await fetchImpl(endpoint.settingsUrl, {
      headers: {
        accept: 'application/json',
        apikey: endpoint.publishableKey,
      },
      method: 'GET',
      redirect: 'manual',
      signal: AbortSignal.timeout(timeoutMilliseconds),
    });
  } catch {
    throw new Error('Supabase Auth settings HTTPS request failed.');
  }

  if (response.status !== 200) {
    throw new Error('Supabase Auth settings must return HTTPS 200.');
  }
  if (response.redirected || response.headers.get('location') !== null) {
    throw new Error('Supabase Auth settings must not redirect.');
  }
  const mediaType = (response.headers.get('content-type') ?? '')
    .split(';', 1)[0]
    .trim()
    .toLowerCase();
  if (mediaType !== 'application/json') {
    throw new Error(
      'Supabase Auth settings Content-Type must be application/json.',
    );
  }

  const declaredLength = parseContentLength(
    response.headers.get('content-length'),
  );
  if (
    declaredLength !== null &&
    declaredLength > maximumSupabaseSettingsBytes
  ) {
    throw new Error('Supabase Auth settings body exceeds the size limit.');
  }

  const decoded = await readBoundedJson(response);
  if (decoded === null || typeof decoded !== 'object' || Array.isArray(decoded)) {
    throw new Error('Supabase Auth settings body has an invalid shape.');
  }
  if (decoded.external?.google !== true) {
    throw new Error('Supabase Google provider is not publicly enabled.');
  }

  return Object.freeze({
    googleEnabled: true,
    settingsUrl: endpoint.settingsUrl,
  });
}

async function main() {
  const [configPath, expectedEnvironment, expectedApplicationId] =
    process.argv.slice(2);
  if (!configPath || !expectedEnvironment || !expectedApplicationId) {
    process.stderr.write(
      'Usage: node scripts/ci/supabase-live-google-provider.mjs <config.json> <dev|prod> <application-id>\n',
    );
    process.exitCode = 64;
    return;
  }

  try {
    const decoded = JSON.parse(await readFile(configPath, 'utf8'));
    validateAndroidPublicConfiguration(decoded, {
      expectedApplicationId,
      expectedEnvironment,
    });
    await probeSupabaseGoogleProvider({
      publishableKey: decoded.SUPABASE_PUBLISHABLE_KEY,
      url: decoded.SUPABASE_URL,
    });
    process.stdout.write('Supabase Google provider public settings passed.\n');
  } catch (error) {
    process.stderr.write(
      `${error instanceof Error ? error.message : 'Supabase Google provider verification failed.'}\n`,
    );
    process.exitCode = 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
