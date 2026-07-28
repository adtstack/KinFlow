import { pathToFileURL } from 'node:url';

import { validateAndroidAssetLinks } from './android-asset-links.mjs';
import { validateAndroidAppLinkHost } from './android-public-config.mjs';

export const maximumAssetLinksBytes = 64 * 1024;

function parseContentLength(value) {
  if (value === null) {
    return null;
  }
  if (!/^\d+$/u.test(value)) {
    throw new Error('Live Android asset links Content-Length is invalid.');
  }
  const length = Number(value);
  if (!Number.isSafeInteger(length)) {
    throw new Error('Live Android asset links Content-Length is invalid.');
  }
  return length;
}

function decodeJson(bytes) {
  try {
    const text = new TextDecoder('utf-8', { fatal: true }).decode(bytes);
    return JSON.parse(text);
  } catch {
    throw new Error('Live Android asset links body is not valid UTF-8 JSON.');
  }
}

async function readBoundedBody(response) {
  if (response.body === null) {
    return new Uint8Array();
  }
  if (typeof response.body?.getReader !== 'function') {
    throw new Error('Live Android asset links body could not be read.');
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
        throw new Error('Live Android asset links body could not be read.');
      }
      totalBytes += value.byteLength;
      if (totalBytes > maximumAssetLinksBytes) {
        await reader.cancel().catch(() => {});
        throw new Error('Live Android asset links body exceeds the size limit.');
      }
      chunks.push(value);
    }
  } catch (error) {
    if (
      error instanceof Error &&
      (error.message ===
        'Live Android asset links body exceeds the size limit.' ||
        error.message === 'Live Android asset links body could not be read.')
    ) {
      throw error;
    }
    throw new Error('Live Android asset links body could not be read.');
  } finally {
    reader.releaseLock();
  }

  const bytes = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return bytes;
}

export async function probeLiveAndroidAssetLinks({
  fetchImpl = globalThis.fetch,
  host,
  expectedPackageName,
  expectedSha256Fingerprints,
  timeoutMilliseconds = 10_000,
}) {
  const validatedHost = validateAndroidAppLinkHost(host);
  if (typeof fetchImpl !== 'function') {
    throw new Error('HTTPS fetch implementation is unavailable.');
  }
  if (
    !Number.isSafeInteger(timeoutMilliseconds) ||
    timeoutMilliseconds <= 0
  ) {
    throw new Error('Live Android asset links timeout is invalid.');
  }

  const url = `https://${validatedHost}/.well-known/assetlinks.json`;
  let response;
  try {
    response = await fetchImpl(url, {
      headers: { accept: 'application/json' },
      method: 'GET',
      redirect: 'manual',
      signal: AbortSignal.timeout(timeoutMilliseconds),
    });
  } catch {
    throw new Error('Live Android asset links HTTPS request failed.');
  }

  if (response.status !== 200) {
    throw new Error('Live Android asset links must return HTTPS 200.');
  }
  if (response.redirected || response.headers.get('location') !== null) {
    throw new Error('Live Android asset links must not redirect.');
  }
  const mediaType = (response.headers.get('content-type') ?? '')
    .split(';', 1)[0]
    .trim()
    .toLowerCase();
  if (mediaType !== 'application/json') {
    throw new Error(
      'Live Android asset links Content-Type must be application/json.',
    );
  }

  const declaredLength = parseContentLength(
    response.headers.get('content-length'),
  );
  if (declaredLength !== null && declaredLength > maximumAssetLinksBytes) {
    throw new Error('Live Android asset links body exceeds the size limit.');
  }

  const bytes = await readBoundedBody(response);
  const decoded = decodeJson(bytes);
  const contract = validateAndroidAssetLinks(decoded, {
    expectedPackageName,
    expectedSha256Fingerprints,
  });

  return Object.freeze({
    bytes: bytes.byteLength,
    packageName: contract.packageName,
    url,
  });
}

async function main() {
  const [host, expectedPackageName, ...expectedSha256Fingerprints] =
    process.argv.slice(2);
  if (
    !host ||
    !expectedPackageName ||
    expectedSha256Fingerprints.length === 0
  ) {
    process.stderr.write(
      'Usage: node scripts/ci/android-live-asset-links.mjs <host> <package> <sha256> [sha256...]\n',
    );
    process.exitCode = 64;
    return;
  }

  try {
    await probeLiveAndroidAssetLinks({
      host,
      expectedPackageName,
      expectedSha256Fingerprints,
    });
    process.stdout.write('Live Android asset links contract passed.\n');
  } catch (error) {
    process.stderr.write(
      `${error instanceof Error ? error.message : 'Live Android asset links verification failed.'}\n`,
    );
    process.exitCode = 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
