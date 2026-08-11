import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import {describe, test} from "node:test";

import {
  createDataExportHandler,
  DataExportRpcError,
  dataExportContractVersion,
} from "../functions/_shared/data_export_contract.mjs";

const userId = "00000000-0000-4000-8000-000000000102";
const otherUserId = "00000000-0000-4000-8000-000000000201";
const requestId = "70000000-0000-4000-8000-000000000101";
const privacyRequestId = "75000000-0000-4000-8000-000000000101";
const artifactId = "76000000-0000-4000-8000-000000000101";
const grantId = "77000000-0000-4000-8000-000000000101";
const idempotencyKey = "80000000-0000-4000-8000-000000000101";
const recentProof = "recent-oauth-proof-token";
const nowSeconds = 1_800_000_000;
const tokenBytes = Uint8Array.from({length: 32}, (_, index) => index + 1);

describe("personal data export Edge contract", () => {
  test("preflight returns the safe runtime projection", async () => {
    const calls = [];
    const response = await handlerFor({calls})(jsonRequest({operation: "preflight"}));
    assert.equal(response.status, 200);
    assert.equal(response.headers.get("cache-control"), "no-store");
    assert.deepEqual((await response.json()).data, {
      canRequest: true,
      pendingRequestId: null,
      pendingStatus: null,
      pendingRequestVersion: null,
      conflictingRequestPending: false,
      requestsEnabled: true,
      downloadsEnabled: true,
      artifactTtlSeconds: 86400,
      downloadGrantTtlSeconds: 300,
      evaluatedAt: "2027-01-15T08:00:00Z",
    });
    assert.deepEqual(calls[0], {
      name: "get_data_export_preflight",
      parameters: {p_authenticated_user_id: userId},
    });
  });

  test("request requires recent OAuth and sends no proof to the database", async () => {
    const calls = [];
    const response = await handlerFor({calls})(jsonRequest(
      {operation: "request"},
      {idempotent: true, recent: true},
    ));
    assert.equal(response.status, 202);
    const payload = await response.json();
    assert.equal(payload.meta.contractVersion, dataExportContractVersion);
    assert.equal(payload.data.id, privacyRequestId);
    assert.equal(payload.data.artifact.available, false);
    assert.deepEqual(calls[0], {
      name: "request_data_export",
      parameters: {
        p_authenticated_user_id: userId,
        p_correlation_id: requestId,
        p_idempotency_key: idempotencyKey,
      },
    });
    assert.equal(JSON.stringify(calls).includes(recentProof), false);
  });

  test("download returns only a short-lived one-time URL and hashes the raw token", async () => {
    const calls = [];
    const response = await handlerFor({calls})(jsonRequest({
      operation: "download",
      requestId: privacyRequestId,
      format: "json",
    }, {recent: true}));
    assert.equal(response.status, 200);
    const data = (await response.json()).data;
    const url = new URL(data.downloadUrl);
    const rawToken = url.searchParams.get("token");
    assert.match(rawToken, /^[A-Za-z0-9_-]{43}$/);
    assert.equal(data.format, "json");
    assert.equal(data.expiresAt, "2027-01-15T08:05:00Z");
    const expectedHash = createHash("sha256").update(tokenBytes).digest("base64");
    assert.deepEqual(calls[0], {
      name: "create_data_export_download_grant",
      parameters: {
        p_authenticated_user_id: userId,
        p_correlation_id: requestId,
        p_export_format: "json",
        p_request_id: privacyRequestId,
        p_token_hash_base64: expectedHash,
      },
    });
    assert.equal(JSON.stringify(calls).includes(rawToken), false);
  });

  test("revoke requires recent OAuth and forwards the artifact version", async () => {
    const calls = [];
    const response = await handlerFor({calls})(jsonRequest({
      operation: "revoke",
      requestId: privacyRequestId,
      expectedArtifactVersion: 3,
    }, {idempotent: true, recent: true}));
    assert.equal(response.status, 200);
    assert.deepEqual(calls[0], {
      name: "revoke_data_export",
      parameters: {
        p_authenticated_user_id: userId,
        p_correlation_id: requestId,
        p_expected_artifact_version: 3,
        p_idempotency_key: idempotencyKey,
        p_request_id: privacyRequestId,
      },
    });
  });

  test("missing stale and cross-account recent proofs fail before RPC", async () => {
    for (const authenticate of [
      undefined,
      async (authorization) => authorization.includes(recentProof)
        ? {userId, claims: {amr: [{method: "oauth", timestamp: nowSeconds - 601}]}}
        : {userId, claims: {}},
      async (authorization) => authorization.includes(recentProof)
        ? {userId: otherUserId, claims: {amr: [{method: "oauth", timestamp: nowSeconds}]}}
        : {userId, claims: {}},
    ]) {
      let calls = 0;
      const handler = handlerFor({
        authenticate,
        invokeRpc: async () => {
          calls += 1;
          return [requestRow()];
        },
      });
      const response = await handler(jsonRequest(
        {operation: "request"},
        {idempotent: true, recent: authenticate !== undefined},
      ));
      assert.equal(response.status, 403);
      assert.equal((await response.json()).error.code, "RECENT_AUTH_REQUIRED");
      assert.equal(calls, 0);
    }
  });

  test("status and cancellation preserve exact lookup and optimistic concurrency", async () => {
    const calls = [];
    const handler = handlerFor({calls});
    const status = await handler(jsonRequest({operation: "status", requestId: privacyRequestId}));
    assert.equal((await status.json()).data.id, privacyRequestId);
    const cancelled = await handler(jsonRequest({
      operation: "cancel",
      requestId: privacyRequestId,
      expectedVersion: 1,
    }, {idempotent: true}));
    assert.equal(cancelled.status, 200);
    assert.equal(calls[1].name, "cancel_data_export");
    assert.equal(calls[1].parameters.p_expected_version, 1);
  });

  for (const [sqlState, code, status] of [
    ["KFX03", "REQUESTS_PAUSED", 503],
    ["KFX04", "IDEMPOTENCY_KEY_REUSED", 409],
    ["KFX05", "PRIVACY_REQUEST_ALREADY_PENDING", 409],
    ["KFX06", "NOT_FOUND", 404],
    ["KFX07", "VERSION_CONFLICT", 409],
    ["KFX08", "REQUEST_NOT_CANCELLABLE", 409],
    ["KFX10", "DOWNLOADS_PAUSED", 503],
    ["KFX11", "ARTIFACT_UNAVAILABLE", 410],
  ]) {
    test(`maps ${sqlState} to stable ${code}`, async () => {
      const response = await handlerFor({
        invokeRpc: async () => { throw new DataExportRpcError(sqlState); },
      })(jsonRequest({operation: "preflight"}));
      const payload = await response.json();
      assert.equal(response.status, status);
      assert.equal(payload.error.code, code);
      assert.deepEqual(Object.keys(payload.error).sort(), [
        "code", "messageKey", "requestId", "retryable",
      ]);
    });
  }

  test("auth method origin idempotency and exact body fail closed", async () => {
    let calls = 0;
    const handler = handlerFor({invokeRpc: async () => { calls += 1; return [requestRow()]; }});
    const cases = [
      [jsonRequest({operation: "preflight"}, {authenticated: false}), 401, "AUTH_REQUIRED"],
      [jsonRequest({operation: "request"}, {recent: true}), 400, "IDEMPOTENCY_KEY_REQUIRED"],
      [jsonRequest({operation: "preflight", extra: true}), 400, "VALIDATION_FAILED"],
      [new Request("http://local/data-export", {method: "GET"}), 405, "METHOD_NOT_ALLOWED"],
      [jsonRequest({operation: "preflight"}, {origin: "https://evil.invalid"}), 403, "PERMISSION_DENIED"],
    ];
    for (const [request, status, code] of cases) {
      const response = await handler(request);
      assert.equal(response.status, status);
      assert.equal((await response.json()).error.code, code);
    }
    assert.equal(calls, 0);
  });

  test("unexpected private fields are redacted behind an unavailable error", async () => {
    const response = await handlerFor({
      invokeRpc: async () => [{...preflightRow(), object_key: "private/path"}],
    })(jsonRequest({operation: "preflight"}));
    const text = await response.text();
    assert.equal(response.status, 503);
    assert.doesNotMatch(text, /object_key|private\/path/);
  });

  test("download base URL requires HTTPS except for loopback development", () => {
    assert.throws(() => createDataExportHandler({
      allowedOrigins: [],
      downloadBaseUrl: "http://downloads.example.invalid/data-export-download",
      authenticate: async () => null,
      invokeRpc: async () => [],
    }), /Invalid data export download URL/);
    assert.doesNotThrow(() => createDataExportHandler({
      allowedOrigins: [],
      downloadBaseUrl: "http://127.0.0.1:54321/functions/v1/data-export-download",
      authenticate: async () => null,
      invokeRpc: async () => [],
    }));
  });
});

function handlerFor({calls = [], authenticate, invokeRpc} = {}) {
  return createDataExportHandler({
    allowedOrigins: ["https://app.kinflow.test"],
    downloadBaseUrl: "https://api.kinflow.test/functions/v1/data-export-download",
    nowEpochSeconds: () => nowSeconds,
    randomTokenBytes: () => tokenBytes,
    authenticate: authenticate ?? (async (authorization) => {
      if (authorization === "Bearer access-token") return {userId, claims: {}};
      if (authorization === `Bearer ${recentProof}`) {
        return {userId, claims: {amr: [{method: "oauth", timestamp: nowSeconds}]}};
      }
      return null;
    }),
    invokeRpc: invokeRpc ?? (async (name, parameters) => {
      calls.push({name, parameters});
      if (name === "get_data_export_preflight") return [preflightRow()];
      if (name === "create_data_export_download_grant") return [grantRow()];
      return [requestRow()];
    }),
  });
}

function jsonRequest(body, {
  authenticated = true,
  idempotent = false,
  origin = "https://app.kinflow.test",
  recent = false,
} = {}) {
  const headers = new Headers({
    "content-type": "application/json",
    "x-request-id": requestId,
  });
  if (authenticated) headers.set("authorization", "Bearer access-token");
  if (idempotent) headers.set("idempotency-key", idempotencyKey);
  if (origin !== null) headers.set("origin", origin);
  if (recent) headers.set("x-kinflow-recent-auth", recentProof);
  return new Request("http://local/data-export", {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
}

function preflightRow() {
  return {
    can_request: true,
    pending_request_id: null,
    pending_status: null,
    pending_request_version: null,
    conflicting_request_pending: false,
    requests_enabled: true,
    downloads_enabled: true,
    artifact_ttl_seconds: 86400,
    download_grant_ttl_seconds: 300,
    evaluated_at: "2027-01-15T08:00:00Z",
  };
}

function requestRow(overrides = {}) {
  return {
    request_id: privacyRequestId,
    status: "queued",
    requested_at: "2027-01-15T08:00:00Z",
    processing_started_at: null,
    completed_at: null,
    failed_at: null,
    cancelled_at: null,
    failure_code: null,
    cancellable: true,
    request_version: 1,
    artifact_id: artifactId,
    artifact_version: 1,
    schema_version: dataExportContractVersion,
    artifact_expires_at: null,
    revoked_at: null,
    purged_at: null,
    machine_size_bytes: null,
    human_size_bytes: null,
    available: false,
    ...overrides,
  };
}

function grantRow() {
  return {
    grant_id: grantId,
    export_format: "json",
    expires_at: "2027-01-15T08:05:00Z",
  };
}
