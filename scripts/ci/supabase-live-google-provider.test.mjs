import assert from 'node:assert/strict';
import test from 'node:test';

import {
  maximumSupabaseSettingsBytes,
  probeSupabaseGoogleProvider,
} from './supabase-live-google-provider.mjs';

const url = 'https://abcdefghijklmnopqrst.supabase.co';
const publishableKey = 'sb_publishable_test_public_value';

function jsonResponse(body, init = {}) {
  return new Response(JSON.stringify(body), {
    headers: { 'content-type': 'application/json', ...init.headers },
    status: init.status ?? 200,
  });
}

test('probes exact Supabase settings without exposing the publishable key', async () => {
  let request;
  const result = await probeSupabaseGoogleProvider({
    fetchImpl: async (...arguments_) => {
      request = arguments_;
      return jsonResponse({ external: { google: true } });
    },
    publishableKey,
    url,
  });

  assert.equal(
    request[0],
    'https://abcdefghijklmnopqrst.supabase.co/auth/v1/settings',
  );
  assert.deepEqual(request[1].headers, {
    accept: 'application/json',
    apikey: publishableKey,
  });
  assert.equal(request[1].method, 'GET');
  assert.equal(request[1].redirect, 'manual');
  assert.deepEqual(result, {
    googleEnabled: true,
    settingsUrl:
      'https://abcdefghijklmnopqrst.supabase.co/auth/v1/settings',
  });
  assert.equal(JSON.stringify(result).includes(publishableKey), false);
});

test('rejects unsafe Supabase origins and invalid public keys', async () => {
  for (const invalidUrl of [
    'http://abcdefghijklmnopqrst.supabase.co',
    'https://abcdefghijklmnopqrst.supabase.co/path',
    'https://example.com',
  ]) {
    await assert.rejects(
      probeSupabaseGoogleProvider({
        fetchImpl: async () => jsonResponse({ external: { google: true } }),
        publishableKey,
        url: invalidUrl,
      }),
      /Supabase public URL/u,
    );
  }

  await assert.rejects(
    probeSupabaseGoogleProvider({
      fetchImpl: async () => jsonResponse({ external: { google: true } }),
      publishableKey: 'not-a-key',
      url,
    }),
    /publishable key/u,
  );
});

test('rejects non-200, redirect, and non-JSON settings responses', async () => {
  await assert.rejects(
    probeSupabaseGoogleProvider({
      fetchImpl: async () => jsonResponse({}, { status: 401 }),
      publishableKey,
      url,
    }),
    /HTTPS 200/u,
  );
  await assert.rejects(
    probeSupabaseGoogleProvider({
      fetchImpl: async () =>
        new Response(null, {
          headers: { location: 'https://example.com' },
          status: 302,
        }),
      publishableKey,
      url,
    }),
    /HTTPS 200/u,
  );
  await assert.rejects(
    probeSupabaseGoogleProvider({
      fetchImpl: async () =>
        new Response('{}', {
          headers: { 'content-type': 'text/plain' },
          status: 200,
        }),
      publishableKey,
      url,
    }),
    /Content-Type/u,
  );
});

test('rejects oversized, malformed, and disabled provider settings', async () => {
  await assert.rejects(
    probeSupabaseGoogleProvider({
      fetchImpl: async () =>
        new Response('{}', {
          headers: {
            'content-length': String(maximumSupabaseSettingsBytes + 1),
            'content-type': 'application/json',
          },
          status: 200,
        }),
      publishableKey,
      url,
    }),
    /size limit/u,
  );
  await assert.rejects(
    probeSupabaseGoogleProvider({
      fetchImpl: async () =>
        new Response('{', {
          headers: { 'content-type': 'application/json' },
          status: 200,
        }),
      publishableKey,
      url,
    }),
    /UTF-8 JSON/u,
  );
  await assert.rejects(
    probeSupabaseGoogleProvider({
      fetchImpl: async () => jsonResponse({ external: { google: false } }),
      publishableKey,
      url,
    }),
    /not publicly enabled/u,
  );
});
