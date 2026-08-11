import assert from "node:assert/strict";
import test from "node:test";

import {
  createNotificationEndpointHandler,
  NotificationEndpointRpcError,
  notificationEndpointContractVersion,
} from "../../supabase/functions/_shared/notification_endpoint_contract.mjs";
import {
  createNotificationEndpointAuthenticator,
  createNotificationEndpointRpcInvoker,
  createNotificationTokenSealer,
  sha256Base64,
} from "../../supabase/functions/_shared/notification_endpoint_runtime.mjs";

const userId = "00000000-0000-4000-8000-000000000101";
const householdId = "20000000-0000-4000-8000-000000000101";
const memberId = "30000000-0000-4000-8000-000000000101";
const installationId = "53000000-0000-4000-8000-000000000001";
const registrationId = "53010000-0000-4000-8000-000000000001";
const endpointId = "53020000-0000-4000-8000-000000000001";
const requestId = "53030000-0000-4000-8000-000000000001";
const asOf = "2030-01-01T00:00:00.000Z";
const providerToken = "fcm:provider-token-value-0123456789";
const revocationSecret = "A".repeat(43);
const runtimePolicyHeaders = Object.freeze({
  "x-kinflow-client-version": "0.1.0-dev+10",
  "x-kinflow-client-build": "10",
  "x-kinflow-contract-version": "2026-08-09",
  "x-kinflow-platform": "android",
  "x-kinflow-environment": "dev",
});

test("authenticated registration seals token and returns metadata only", async () => {
  const calls = [];
  const ciphertextBase64 = encodeBase64(new Uint8Array(48).fill(0x51));
  const handler = handlerFor({
    invokeRpc: async (name, parameters, compatibilityHeaders) => {
      calls.push({name, parameters, compatibilityHeaders});
      return [endpointRow()];
    },
    sealToken: async (token) => {
      assert.equal(token, providerToken);
      return {ciphertextBase64, keyVersion: 7};
    },
  });

  const response = await handler(registrationRequest(
    registrationBody(),
    {
      ...runtimePolicyHeaders,
      "x-kinflow-forwarded-user-operation": "0",
    },
  ));
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.equal(response.headers.get("x-request-id"), requestId);
  const payload = await response.json();
  assert.deepEqual(payload, {
    data: {
      appVersion: "0.1.0+1",
      channel: "native_push",
      endpointId,
      householdId,
      installationId,
      lastRegistrationId: registrationId,
      lastSeenAt: asOf,
      locale: "ko-KR",
      memberId,
      permissionState: "granted",
      platform: "android",
      revocationReason: null,
      revokedAt: null,
      runtimeVersion: "Flutter 3.44.7",
      timezone: "Asia/Seoul",
      version: 1,
    },
    meta: {contractVersion: notificationEndpointContractVersion, requestId},
  });
  assert.equal(calls.length, 1);
  assert.equal(calls[0].name, "upsert_notification_endpoint");
  assert.deepEqual(calls[0].compatibilityHeaders, runtimePolicyHeaders);
  assert.deepEqual(calls[0].parameters, {
    p_app_version: "0.1.0+1",
    p_as_of: asOf,
    p_authenticated_user_id: userId,
    p_channel: "native_push",
    p_expected_version: 0,
    p_household_id: householdId,
    p_installation_id: installationId,
    p_locale: "ko-KR",
    p_permission_state: "granted",
    p_platform: "android",
    p_registration_id: registrationId,
    p_revocation_secret_hash_base64: await sha256Base64(revocationSecret),
    p_runtime_version: "Flutter 3.44.7",
    p_timezone: "Asia/Seoul",
    p_token_ciphertext_base64: ciphertextBase64,
    p_token_fingerprint_base64: await sha256Base64(providerToken),
    p_token_key_version: 7,
  });
  assert.doesNotMatch(JSON.stringify(calls), new RegExp(providerToken));
  assert.doesNotMatch(JSON.stringify(calls), new RegExp(revocationSecret));
  assert.doesNotMatch(JSON.stringify(payload), /token|secret|fingerprint|ciphertext/i);
});

test("registration validates authentication idempotency and exact input", async () => {
  const validBody = registrationBody();
  const cases = [
    {
      expected: "AUTH_REQUIRED",
      request: registrationRequest(validBody, {authorization: ""}),
    },
    {
      expected: "IDEMPOTENCY_KEY_REQUIRED",
      request: registrationRequest(validBody, {"idempotency-key": "bad"}),
    },
    {
      expected: "VALIDATION_FAILED",
      request: registrationRequest({...validBody, extra: true}),
    },
    {
      expected: "VALIDATION_FAILED",
      request: registrationRequest({...validBody, permissionState: "prompt"}),
    },
    {
      expected: "VALIDATION_FAILED",
      request: registrationRequest({...validBody, revocationSecret: "short"}),
    },
    {
      expected: "VALIDATION_FAILED",
      request: registrationRequest({...validBody, expectedVersion: -1}),
    },
  ];
  for (const entry of cases) {
    const response = await handlerFor({
      authenticate: async (authorization) =>
        authorization === "Bearer access-token" ? {userId} : null,
    })(entry.request);
    assert.equal((await response.json()).error.code, entry.expected);
  }
});

test("transport surface rejects query strings methods and oversized bodies", async () => {
  const handler = handlerFor();
  const queryResponse = await handler(registrationRequest(
    registrationBody(),
    {},
    "http://local/notification-endpoint?debug=true",
  ));
  assert.equal((await queryResponse.json()).error.code, "VALIDATION_FAILED");

  const methodResponse = await handler(new Request(
    "http://local/notification-endpoint",
    {method: "PUT", headers: {"content-type": "application/json"}, body: "{}"},
  ));
  assert.equal(methodResponse.status, 405);
  assert.equal(methodResponse.headers.get("access-control-allow-methods"), "POST, DELETE, OPTIONS");

  const typeResponse = await handler(new Request(
    "http://local/notification-endpoint",
    {method: "POST", headers: {"content-type": "text/plain"}, body: "{}"},
  ));
  assert.equal(typeResponse.status, 400);

  const largeResponse = await handler(new Request(
    "http://local/notification-endpoint",
    {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({padding: "x".repeat(17 * 1024)}),
    },
  ));
  assert.equal((await largeResponse.json()).error.code, "VALIDATION_FAILED");
});

test("CORS is exact and preflight is content free", async () => {
  const handler = handlerFor();
  const denied = await handler(registrationRequest(
    registrationBody(),
    {origin: "https://evil.example"},
  ));
  assert.equal(denied.status, 403);
  assert.equal(denied.headers.get("access-control-allow-origin"), null);

  const allowed = await handler(new Request(
    "http://local/notification-endpoint",
    {method: "OPTIONS", headers: {origin: "https://app.kinflow.test"}},
  ));
  assert.equal(allowed.status, 204);
  assert.equal(
    allowed.headers.get("access-control-allow-origin"),
    "https://app.kinflow.test",
  );
  assert.equal(await allowed.text(), "");
  assert.match(
    allowed.headers.get("access-control-allow-headers"),
    /x-kinflow-environment/,
  );
});

test("database conflicts map to stable content-free errors", async () => {
  for (const [sqlState, status, code] of [
    ["KND01", 400, "VALIDATION_FAILED"],
    ["KND03", 404, "NOT_FOUND_OR_FORBIDDEN"],
    ["KND04", 409, "IDEMPOTENCY_KEY_REUSED"],
    ["KND06", 409, "VERSION_CONFLICT"],
    ["KFR01", 426, "CLIENT_UPDATE_REQUIRED"],
    ["KFR02", 503, "CLIENT_MUTATIONS_DISABLED"],
    ["KFR03", 503, "RUNTIME_POLICY_UNAVAILABLE"],
    ["KFR06", 503, "CLIENT_FEATURE_DISABLED"],
    ["XX000", 503, "TEMPORARILY_UNAVAILABLE"],
  ]) {
    const handler = handlerFor({
      invokeRpc: async () => {
        throw new NotificationEndpointRpcError(sqlState);
      },
    });
    const response = await handler(registrationRequest());
    const text = await response.text();
    assert.equal(response.status, status);
    assert.equal(JSON.parse(text).error.code, code);
    assert.doesNotMatch(text, /provider-token|revocation|sql/i);
  }
});

test("malformed service response fails closed without endpoint material", async () => {
  const handler = handlerFor({
    invokeRpc: async () => [{...endpointRow(), token_ciphertext: "unsafe"}],
  });
  const response = await handler(registrationRequest());
  assert.equal(response.status, 503);
  const text = await response.text();
  assert.equal(JSON.parse(text).error.code, "TEMPORARILY_UNAVAILABLE");
  assert.doesNotMatch(text, /unsafe|ciphertext/i);
});

test("proof revocation works without a live JWT and hides existence", async () => {
  const responses = [];
  const calls = [];
  for (const databaseCount of [0, 1]) {
    let authenticationCalls = 0;
    const handler = handlerFor({
      authenticate: async () => {
        authenticationCalls += 1;
        return null;
      },
      invokeRpc: async (name, parameters) => {
        calls.push({name, parameters});
        return databaseCount;
      },
    });
    const response = await handler(revocationRequest());
    responses.push(await response.json());
    assert.equal(authenticationCalls, 0);
  }
  assert.deepEqual(responses[0], responses[1]);
  assert.deepEqual(responses[0], {
    data: {revoked: true},
    meta: {contractVersion: notificationEndpointContractVersion, requestId},
  });
  assert.deepEqual(calls[0], {
    name: "revoke_notification_endpoint_by_secret",
    parameters: {
      p_as_of: asOf,
      p_channel: "native_push",
      p_installation_id: installationId,
      p_registration_id: registrationId,
      p_revocation_secret_hash_base64: await sha256Base64(revocationSecret),
    },
  });
  assert.doesNotMatch(JSON.stringify(calls), new RegExp(revocationSecret));
});

test("proof revocation requires exact channel UUIDs and 256-bit-shaped secret", async () => {
  for (const body of [
    {...revocationBody(), channel: "email"},
    {...revocationBody(), registrationId: "invalid"},
    {...revocationBody(), revocationSecret: "B".repeat(42)},
    {...revocationBody(), extra: true},
  ]) {
    const response = await handlerFor()(revocationRequest(body));
    assert.equal((await response.json()).error.code, "VALIDATION_FAILED");
  }
});

test("AES-GCM sealing is randomized and decrypts only with version-bound AAD", async () => {
  const keyBytes = Uint8Array.from({length: 32}, (_, index) => index);
  let nonce = 0;
  const sealToken = createNotificationTokenSealer({
    keyMaterialBase64: encodeBase64(keyBytes),
    keyVersion: 12,
    randomBytes: (length) => new Uint8Array(length).fill(++nonce),
  });
  const first = await sealToken(providerToken);
  const second = await sealToken(providerToken);
  assert.equal(first.keyVersion, 12);
  assert.notEqual(first.ciphertextBase64, second.ciphertextBase64);
  assert.equal(await decryptEnvelope(first.ciphertextBase64, keyBytes, 12), providerToken);
  await assert.rejects(decryptEnvelope(first.ciphertextBase64, keyBytes, 13));
  assert.doesNotMatch(first.ciphertextBase64, new RegExp(providerToken));
});

test("token sealer rejects weak non-canonical or invalid-version key material", () => {
  for (const configuration of [
    {keyMaterialBase64: encodeBase64(new Uint8Array(16)), keyVersion: 1},
    {keyMaterialBase64: `${encodeBase64(new Uint8Array(32))}=`, keyVersion: 1},
    {keyMaterialBase64: encodeBase64(new Uint8Array(32)), keyVersion: 0},
  ]) {
    assert.throws(() => createNotificationTokenSealer(configuration));
  }
});

test("SHA-256 material is canonical standard base64 and deterministic", async () => {
  const first = await sha256Base64(providerToken);
  assert.equal(first, await sha256Base64(providerToken));
  assert.equal(decodeBase64(first).byteLength, 32);
  assert.match(first, /^[A-Za-z0-9+/]+={0,2}$/);
});

test("runtime authenticator verifies Bearer token with the configured API key", async () => {
  const calls = [];
  const authenticate = createNotificationEndpointAuthenticator({
    apiKey: "local-anon-key-placeholder",
    supabaseUrl: "http://127.0.0.1:54321/",
    fetchImplementation: async (url, init) => {
      calls.push({url, init});
      return Response.json({id: userId});
    },
  });
  assert.deepEqual(await authenticate("Bearer verified-token"), {userId});
  assert.equal(calls[0].url, "http://127.0.0.1:54321/auth/v1/user");
  assert.equal(calls[0].init.headers.apikey, "local-anon-key-placeholder");
  assert.equal(await authenticate("invalid"), null);
  assert.equal(calls.length, 1);
});

test("runtime RPC invoker uses service role and preserves only SQLSTATE", async () => {
  const calls = [];
  const invokeRpc = createNotificationEndpointRpcInvoker({
    serviceRoleKey: "local-service-role-placeholder",
    supabaseUrl: "http://127.0.0.1:54321/",
    fetchImplementation: async (url, init) => {
      calls.push({url, init});
      return Response.json(
        {code: "KND06", details: providerToken},
        {status: 409},
      );
    },
  });
  await assert.rejects(
    invokeRpc("upsert_notification_endpoint", {}, {
      ...runtimePolicyHeaders,
      authorization: "Bearer private-session",
      "x-kinflow-forwarded-user-operation": "0",
    }),
    (error) => error instanceof NotificationEndpointRpcError &&
      error.code === "KND06" &&
      !error.message.includes(providerToken),
  );
  assert.equal(
    calls[0].url,
    "http://127.0.0.1:54321/rest/v1/rpc/upsert_notification_endpoint",
  );
  assert.equal(calls[0].init.headers.apikey, "local-service-role-placeholder");
  assert.equal(
    calls[0].init.headers.authorization,
    "Bearer local-service-role-placeholder",
  );
  assert.equal(
    calls[0].init.headers["x-kinflow-forwarded-user-operation"],
    "1",
  );
  for (const [name, value] of Object.entries(runtimePolicyHeaders)) {
    assert.equal(calls[0].init.headers[name], value);
  }
});

function handlerFor({
  authenticate = async (authorization) =>
    authorization === "Bearer access-token" ? {userId} : null,
  invokeRpc = async () => [endpointRow()],
  sealToken = async () => ({
    ciphertextBase64: encodeBase64(new Uint8Array(48).fill(0x51)),
    keyVersion: 1,
  }),
} = {}) {
  return createNotificationEndpointHandler({
    allowedOrigins: ["https://app.kinflow.test"],
    authenticate,
    clock: () => asOf,
    invokeRpc,
    sealToken,
    sha256Base64,
  });
}

function registrationBody() {
  return {
    appVersion: "0.1.0+1",
    expectedVersion: 0,
    householdId,
    installationId,
    locale: "ko-KR",
    permissionState: "granted",
    platform: "android",
    revocationSecret,
    runtimeVersion: "Flutter 3.44.7",
    timezone: "Asia/Seoul",
    token: providerToken,
  };
}

function registrationRequest(
  body = registrationBody(),
  headers = {},
  url = "http://local/notification-endpoint",
) {
  return new Request(url, {
    method: "POST",
    headers: {
      authorization: "Bearer access-token",
      "content-type": "application/json",
      "idempotency-key": registrationId,
      "x-request-id": requestId,
      ...headers,
    },
    body: JSON.stringify(body),
  });
}

function revocationBody() {
  return {
    channel: "native_push",
    installationId,
    registrationId,
    revocationSecret,
  };
}

function revocationRequest(body = revocationBody()) {
  return new Request("http://local/notification-endpoint", {
    method: "DELETE",
    headers: {
      "content-type": "application/json",
      "x-request-id": requestId,
    },
    body: JSON.stringify(body),
  });
}

function endpointRow() {
  return {
    app_version: "0.1.0+1",
    channel: "native_push",
    endpoint_id: endpointId,
    household_id: householdId,
    installation_id: installationId,
    last_registration_id: registrationId,
    last_seen_at: asOf,
    locale: "ko-KR",
    member_id: memberId,
    permission_state: "granted",
    platform: "android",
    revocation_reason: null,
    revoked_at: null,
    runtime_version: "Flutter 3.44.7",
    timezone: "Asia/Seoul",
    version: 1,
  };
}

async function decryptEnvelope(ciphertextBase64, keyBytes, keyVersion) {
  const envelope = decodeBase64(ciphertextBase64);
  const key = await crypto.subtle.importKey(
    "raw",
    keyBytes,
    {name: "AES-GCM"},
    false,
    ["decrypt"],
  );
  const plaintext = await crypto.subtle.decrypt(
    {
      name: "AES-GCM",
      iv: envelope.slice(0, 12),
      additionalData: new TextEncoder().encode(
        `kinflow:notification-token:v${keyVersion}`,
      ),
      tagLength: 128,
    },
    key,
    envelope.slice(12),
  );
  return new TextDecoder().decode(plaintext);
}

function encodeBase64(bytes) {
  return Buffer.from(bytes).toString("base64");
}

function decodeBase64(value) {
  return new Uint8Array(Buffer.from(value, "base64"));
}
