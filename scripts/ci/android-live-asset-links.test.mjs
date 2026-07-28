import assert from 'node:assert/strict';
import test from 'node:test';

import { handleAllUrlsRelation } from './android-asset-links.mjs';
import {
  maximumAssetLinksBytes,
  probeLiveAndroidAssetLinks,
} from './android-live-asset-links.mjs';

const host = 'auth.dev.kinflow.example';
const packageName = 'me.newlines.kinflow.dev';
const fingerprint =
  '6A:C5:22:6C:F7:1B:20:1C:99:49:E8:1F:75:14:49:AD:94:53:64:A9:46:5C:ED:0C:69:19:00:51:C5:6E:C7:D5';

function statement(overrides = {}) {
  return [
    {
      relation: [handleAllUrlsRelation],
      target: {
        namespace: 'android_app',
        package_name: packageName,
        sha256_cert_fingerprints: [fingerprint],
        ...overrides,
      },
    },
  ];
}

function jsonResponse(body = statement(), options = {}) {
  return new Response(JSON.stringify(body), {
    headers: {
      'content-type': 'application/json; charset=utf-8',
      ...options.headers,
    },
    status: options.status ?? 200,
  });
}

function expectations(fetchImpl) {
  return {
    expectedPackageName: packageName,
    expectedSha256Fingerprints: [fingerprint],
    fetchImpl,
    host,
  };
}

test('probes the exact HTTPS well-known URL without redirects', async () => {
  let request;
  const result = await probeLiveAndroidAssetLinks(
    expectations(async (url, options) => {
      request = { options, url };
      return jsonResponse();
    }),
  );

  assert.equal(
    request.url,
    'https://auth.dev.kinflow.example/.well-known/assetlinks.json',
  );
  assert.equal(request.options.method, 'GET');
  assert.equal(request.options.redirect, 'manual');
  assert.equal(request.options.headers.accept, 'application/json');
  assert.equal(result.packageName, packageName);
});

test('rejects non-200, redirect, and non-JSON responses', async () => {
  await assert.rejects(
    probeLiveAndroidAssetLinks(
      expectations(async () => jsonResponse([], { status: 302 })),
    ),
    /HTTPS 200/u,
  );
  await assert.rejects(
    probeLiveAndroidAssetLinks(
      expectations(
        async () =>
          jsonResponse(undefined, { headers: { location: '/other' } }),
      ),
    ),
    /must not redirect/u,
  );
  await assert.rejects(
    probeLiveAndroidAssetLinks(
      expectations(
        async () =>
          new Response('{}', {
            headers: { 'content-type': 'text/plain' },
            status: 200,
          }),
      ),
    ),
    /Content-Type/u,
  );
});

test('rejects oversized and malformed response bodies', async () => {
  await assert.rejects(
    probeLiveAndroidAssetLinks(
      expectations(
        async () =>
          jsonResponse(undefined, {
            headers: {
              'content-length': String(maximumAssetLinksBytes + 1),
            },
          }),
      ),
    ),
    /size limit/u,
  );
  await assert.rejects(
    probeLiveAndroidAssetLinks(
      expectations(
        async () =>
          new Response('{', {
            headers: { 'content-type': 'application/json' },
            status: 200,
          }),
      ),
    ),
    /UTF-8 JSON/u,
  );

  const oversizedStream = new ReadableStream({
    start(controller) {
      controller.enqueue(new Uint8Array(maximumAssetLinksBytes));
      controller.enqueue(new Uint8Array(1));
      controller.close();
    },
  });
  await assert.rejects(
    probeLiveAndroidAssetLinks(
      expectations(
        async () =>
          new Response(oversizedStream, {
            headers: { 'content-type': 'application/json' },
            status: 200,
          }),
      ),
    ),
    /size limit/u,
  );
});

test('rejects unsafe hosts and deployed statement drift', async () => {
  await assert.rejects(
    probeLiveAndroidAssetLinks({
      ...expectations(async () => jsonResponse()),
      host: 'https://auth.example.com',
    }),
    /App Link host/u,
  );
  await assert.rejects(
    probeLiveAndroidAssetLinks(
      expectations(
        async () => jsonResponse(statement({ package_name: 'example.app' })),
      ),
    ),
    /package/u,
  );
});
