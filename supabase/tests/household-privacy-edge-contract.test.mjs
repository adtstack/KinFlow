import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import {describe, test} from "node:test";

import {
  createHouseholdPrivacyHandler,
  HouseholdPrivacyRpcError,
  householdPrivacyContractVersion,
} from "../functions/_shared/household_privacy_contract.mjs";

const userId = "00000000-0000-4000-8000-000000000101";
const otherUserId = "00000000-0000-4000-8000-000000000201";
const householdId = "20000000-0000-4000-8000-000000000101";
const requestId = "70000000-0000-4000-8000-000000000101";
const privacyRequestId = "75000000-0000-4000-8000-000000000101";
const artifactId = "76000000-0000-4000-8000-000000000101";
const idempotencyKey = "80000000-0000-4000-8000-000000000101";
const recentProof = "recent-household-oauth-proof";
const nowSeconds = 1_800_000_000;
const tokenBytes = Uint8Array.from({length: 32}, (_, index) => index + 1);

describe("Owner household privacy Edge contract", () => {
  test("preflight returns the complete safe impact projection", async () => {
    const calls = [];
    const response = await handlerFor({calls})(jsonRequest({
      operation: "preflight",
      householdId,
    }));
    assert.equal(response.status, 200);
    assert.equal(response.headers.get("cache-control"), "no-store");
    const payload = await response.json();
    assert.equal(payload.data.household.name, "Primary household");
    assert.equal(payload.data.memberCount, 2);
    assert.equal(payload.data.activeSubscription, true);
    assert.equal(payload.meta.contractVersion, householdPrivacyContractVersion);
    assert.deepEqual(calls[0], {
      name: "get_household_privacy_preflight",
      parameters: {p_authenticated_user_id: userId, p_household_id: householdId},
    });
  });

  test("export request requires recent OAuth and forwards no proof", async () => {
    const calls = [];
    const response = await handlerFor({calls})(jsonRequest({
      operation: "requestExport",
      householdId,
    }, {idempotent: true, recent: true}));
    assert.equal(response.status, 202);
    assert.equal((await response.json()).data.kind, "export");
    assert.deepEqual(calls[0], {
      name: "request_household_export",
      parameters: {
        p_authenticated_user_id: userId,
        p_correlation_id: requestId,
        p_household_id: householdId,
        p_idempotency_key: idempotencyKey,
      },
    });
    assert.equal(JSON.stringify(calls).includes(recentProof), false);
  });

  test("deletion forwards exact version name and three acknowledgments", async () => {
    const calls = [];
    const response = await handlerFor({calls})(jsonRequest({
      operation: "requestDeletion",
      householdId,
      expectedHouseholdVersion: 4,
      confirmationName: "Primary household",
      acknowledgeMemberAccessLoss: true,
      acknowledgeSharedDataRedaction: true,
      acknowledgeSubscriptionNotCancelled: true,
    }, {idempotent: true, recent: true}));
    assert.equal(response.status, 202);
    assert.deepEqual(calls[0], {
      name: "request_household_deletion",
      parameters: {
        p_acknowledge_member_access_loss: true,
        p_acknowledge_shared_data_redaction: true,
        p_acknowledge_subscription_not_cancelled: true,
        p_authenticated_user_id: userId,
        p_confirmation_name: "Primary household",
        p_correlation_id: requestId,
        p_expected_household_version: 4,
        p_household_id: householdId,
        p_idempotency_key: idempotencyKey,
      },
    });
  });

  test("deletion body fails closed if an impact acknowledgment is absent", async () => {
    let calls = 0;
    const response = await handlerFor({
      invokeRpc: async () => { calls += 1; return [{result: exportRequest()}]; },
    })(jsonRequest({
      operation: "requestDeletion",
      householdId,
      expectedHouseholdVersion: 4,
      confirmationName: "Primary household",
      acknowledgeMemberAccessLoss: true,
      acknowledgeSharedDataRedaction: false,
      acknowledgeSubscriptionNotCancelled: true,
    }, {idempotent: true, recent: true}));
    assert.equal(response.status, 400);
    assert.equal((await response.json()).error.code, "VALIDATION_FAILED");
    assert.equal(calls, 0);
  });

  test("download exposes a raw capability only in its short-lived URL", async () => {
    const calls = [];
    const response = await handlerFor({calls})(jsonRequest({
      operation: "downloadExport",
      requestId: privacyRequestId,
      format: "json",
    }, {recent: true}));
    assert.equal(response.status, 200);
    const data = (await response.json()).data;
    const token = new URL(data.downloadUrl).searchParams.get("token");
    assert.match(token, /^[A-Za-z0-9_-]{43}$/);
    assert.equal(data.format, "json");
    assert.deepEqual(calls[0], {
      name: "create_household_export_download_grant",
      parameters: {
        p_authenticated_user_id: userId,
        p_correlation_id: requestId,
        p_export_format: "json",
        p_request_id: privacyRequestId,
        p_token_hash_base64: createHash("sha256").update(tokenBytes).digest("base64"),
      },
    });
    assert.equal(JSON.stringify(calls).includes(token), false);
  });

  test("status cancellation and revoke preserve exact optimistic versions", async () => {
    const calls = [];
    const handler = handlerFor({calls});
    const status = await handler(jsonRequest({operation: "status", requestId: privacyRequestId}));
    assert.equal((await status.json()).data.requestId, privacyRequestId);
    await handler(jsonRequest({
      operation: "cancelExport",
      requestId: privacyRequestId,
      expectedVersion: 2,
    }, {idempotent: true}));
    await handler(jsonRequest({
      operation: "revokeExport",
      requestId: privacyRequestId,
      expectedArtifactVersion: 3,
    }, {idempotent: true, recent: true}));
    assert.equal(calls[1].name, "cancel_household_privacy_request");
    assert.equal(calls[1].parameters.p_request_kind, "export");
    assert.equal(calls[1].parameters.p_expected_version, 2);
    assert.equal(calls[2].name, "revoke_household_export");
    assert.equal(calls[2].parameters.p_expected_artifact_version, 3);
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
      const response = await handlerFor({
        authenticate,
        invokeRpc: async () => { calls += 1; return [{result: exportRequest()}]; },
      })(jsonRequest(
        {operation: "requestExport", householdId},
        {idempotent: true, recent: authenticate !== undefined},
      ));
      assert.equal(response.status, 403);
      assert.equal((await response.json()).error.code, "RECENT_AUTH_REQUIRED");
      assert.equal(calls, 0);
    }
  });

  for (const [sqlState, code, status] of [
    ["KHP03", "OWNER_REQUIRED", 403],
    ["KHP04", "IDEMPOTENCY_KEY_REUSED", 409],
    ["KHP05", "PRIVACY_REQUEST_ALREADY_PENDING", 409],
    ["KHP06", "NOT_FOUND", 404],
    ["KHP07", "VERSION_CONFLICT", 409],
    ["KHP08", "REQUEST_NOT_MUTABLE", 409],
    ["KHP09", "EXPORT_REQUESTS_PAUSED", 503],
    ["KHP10", "CONFIRMATION_MISMATCH", 409],
    ["KHP11", "SUBSCRIPTION_ACK_REQUIRED", 409],
    ["KHP12", "DELETION_REQUESTS_PAUSED", 503],
    ["KHP13", "ARTIFACT_UNAVAILABLE", 410],
    ["KHP14", "DOWNLOADS_PAUSED", 503],
    ["KHP17", "HOUSEHOLD_ALREADY_DELETED", 410],
  ]) {
    test(`maps ${sqlState} to stable ${code}`, async () => {
      const response = await handlerFor({
        invokeRpc: async () => { throw new HouseholdPrivacyRpcError(sqlState); },
      })(jsonRequest({operation: "preflight", householdId}));
      assert.equal(response.status, status);
      assert.equal((await response.json()).error.code, code);
    });
  }

  test("auth origin idempotency method and exact body fail closed", async () => {
    let calls = 0;
    const handler = handlerFor({
      invokeRpc: async () => { calls += 1; return [{result: exportRequest()}]; },
    });
    const cases = [
      [jsonRequest({operation: "preflight", householdId}, {authenticated: false}), 401],
      [jsonRequest({operation: "requestExport", householdId}, {recent: true}), 400],
      [jsonRequest({operation: "preflight", householdId, extra: true}), 400],
      [new Request("http://local/household-privacy", {method: "GET"}), 405],
      [jsonRequest(
        {operation: "preflight", householdId},
        {origin: "https://evil.invalid"},
      ), 403],
    ];
    for (const [request, expectedStatus] of cases) {
      assert.equal((await handler(request)).status, expectedStatus);
    }
    assert.equal(calls, 0);
  });

  test("accepts exactly 12 KiB and rejects a larger request body", async () => {
    const handler = handlerFor();
    const validBody = JSON.stringify({operation: "preflight", householdId});
    const atLimit = validBody.padEnd(12 * 1024, " ");
    const overLimit = atLimit + " ";

    assert.equal(new TextEncoder().encode(atLimit).byteLength, 12 * 1024);
    assert.equal((await handler(rawJsonRequest(atLimit))).status, 200);
    const rejected = await handler(rawJsonRequest(overLimit));
    assert.equal(rejected.status, 400);
    assert.equal((await rejected.json()).error.code, "VALIDATION_FAILED");
  });

  test("unexpected private fields are hidden behind an unavailable error", async () => {
    const response = await handlerFor({
      invokeRpc: async () => [{result: {...preflight(), objectKey: "private/path"}}],
    })(jsonRequest({operation: "preflight", householdId}));
    const text = await response.text();
    assert.equal(response.status, 503);
    assert.doesNotMatch(text, /objectKey|private\/path/);
  });

  test("download base URL requires HTTPS except for loopback development", () => {
    assert.throws(() => createHouseholdPrivacyHandler({
      allowedOrigins: [],
      downloadBaseUrl: "http://downloads.example.invalid/household-export-download",
      authenticate: async () => null,
      invokeRpc: async () => [],
    }), /Invalid household export download URL/);
    assert.doesNotThrow(() => createHouseholdPrivacyHandler({
      allowedOrigins: [],
      downloadBaseUrl: "http://127.0.0.1:54321/functions/v1/household-export-download",
      authenticate: async () => null,
      invokeRpc: async () => [],
    }));
  });
});

function handlerFor({calls = [], authenticate, invokeRpc} = {}) {
  return createHouseholdPrivacyHandler({
    allowedOrigins: ["https://app.kinflow.test"],
    downloadBaseUrl: "https://api.kinflow.test/functions/v1/household-export-download",
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
      if (name === "get_household_privacy_preflight") return [{result: preflight()}];
      if (name === "create_household_export_download_grant") {
        return [{result: {format: "json", expiresAt: "2027-01-15T08:05:00Z"}}];
      }
      return [{result: exportRequest()}];
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
  return new Request("http://local/household-privacy", {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
}

function rawJsonRequest(body) {
  return new Request("http://local/household-privacy", {
    method: "POST",
    headers: {
      authorization: "Bearer access-token",
      "content-type": "application/json",
      origin: "https://app.kinflow.test",
      "x-request-id": requestId,
    },
    body,
  });
}

function preflight() {
  return {
    household: {id: householdId, name: "Primary household", version: 4},
    memberCount: 2,
    activeSubscription: true,
    canExport: true,
    canDelete: true,
    conflictingRequestPending: false,
    pendingRequest: null,
    exportRequestsEnabled: true,
    deletionRequestsEnabled: true,
    downloadsEnabled: true,
    artifactTtlSeconds: 86400,
    downloadGrantTtlSeconds: 300,
    deletionCancellationWindowSeconds: 86400,
    retentionBlocked: false,
    retentionReviewAt: null,
    evaluatedAt: "2027-01-15T08:00:00Z",
  };
}

function exportRequest() {
  return {
    requestId: privacyRequestId,
    kind: "export",
    householdId,
    status: "completed",
    requestedAt: "2027-01-15T07:59:00Z",
    scheduledFor: "2027-01-15T07:59:00Z",
    processingStartedAt: "2027-01-15T08:00:00Z",
    completedAt: "2027-01-15T08:00:01Z",
    failedAt: null,
    cancelledAt: null,
    failureCode: null,
    cancellable: false,
    version: 3,
    activeSubscriptionAtRequest: false,
    artifact: {
      id: artifactId,
      version: 3,
      schemaVersion: householdPrivacyContractVersion,
      expiresAt: "2027-01-16T08:00:01Z",
      revokedAt: null,
      purgedAt: null,
      machineSizeBytes: 4096,
      humanSizeBytes: 2048,
      available: true,
    },
    deletion: null,
  };
}
