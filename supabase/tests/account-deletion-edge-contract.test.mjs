import assert from "node:assert/strict";
import {describe, test} from "node:test";

import {
  AccountDeletionRpcError,
  accountDeletionContractVersion,
  createAccountDeletionHandler,
} from "../functions/_shared/account_deletion_contract.mjs";

const userId = "00000000-0000-4000-8000-000000000102";
const otherUserId = "00000000-0000-4000-8000-000000000201";
const requestId = "70000000-0000-4000-8000-000000000101";
const privacyRequestId = "75000000-0000-4000-8000-000000000101";
const idempotencyKey = "80000000-0000-4000-8000-000000000101";
const nowSeconds = 1_800_000_000;
const recentProof = "recent-oauth-proof-token";

describe("account deletion Edge contract", () => {
  test("preflight returns only the safe aggregate projection", async () => {
    const calls = [];
    const response = await handlerFor({calls})(jsonRequest({operation: "preflight"}));
    assert.equal(response.status, 200);
    assert.equal(response.headers.get("cache-control"), "no-store");
    assert.deepEqual((await response.json()).data, {
      canRequest: true,
      ownerHouseholdCount: 0,
      hasActiveSubscription: true,
      pendingRequestId: null,
      pendingStatus: null,
      pendingRequestVersion: null,
      requestsEnabled: true,
      cancellationWindowSeconds: 86400,
      evaluatedAt: "2027-01-15T08:00:00Z",
    });
    assert.deepEqual(calls[0], {
      name: "get_account_deletion_preflight",
      parameters: {p_authenticated_user_id: userId},
    });
  });

  test("request verifies recent OAuth separately and forwards no proof to DB", async () => {
    const calls = [];
    const response = await handlerFor({calls})(jsonRequest({
      operation: "request",
      subscriptionAcknowledged: true,
    }, {idempotent: true, recent: true}));
    assert.equal(response.status, 202);
    const payload = await response.json();
    assert.equal(payload.meta.contractVersion, accountDeletionContractVersion);
    assert.equal(payload.data.id, privacyRequestId);
    assert.equal(payload.data.activeSubscriptionAtRequest, true);
    assert.deepEqual(calls[0], {
      name: "request_account_deletion",
      parameters: {
        p_authenticated_user_id: userId,
        p_correlation_id: requestId,
        p_idempotency_key: idempotencyKey,
        p_subscription_acknowledged: true,
      },
    });
    assert.equal(JSON.stringify(calls).includes(recentProof), false);
  });

  test("missing stale or cross-account recent proof is rejected before RPC", async () => {
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
      const response = await handler(jsonRequest({
        operation: "request",
        subscriptionAcknowledged: false,
      }, {idempotent: true, recent: authenticate !== undefined}));
      assert.equal(response.status, 403);
      assert.equal((await response.json()).error.code, "RECENT_AUTH_REQUIRED");
      assert.equal(calls, 0);
    }
  });

  test("status supports latest null and exact request lookup", async () => {
    for (const [body, rpcResult, expected] of [
      [{operation: "status"}, [], null],
      [{operation: "status", requestId: privacyRequestId}, [requestRow()], privacyRequestId],
    ]) {
      const response = await handlerFor({invokeRpc: async () => rpcResult})(jsonRequest(body));
      assert.equal(response.status, 200);
      assert.equal((await response.json()).data?.id ?? null, expected);
    }
  });

  test("cancel forwards optimistic version and idempotency", async () => {
    const calls = [];
    const response = await handlerFor({calls})(jsonRequest({
      operation: "cancel",
      requestId: privacyRequestId,
      expectedVersion: 2,
    }, {idempotent: true}));
    assert.equal(response.status, 200);
    assert.deepEqual(calls[0], {
      name: "cancel_account_deletion",
      parameters: {
        p_authenticated_user_id: userId,
        p_correlation_id: requestId,
        p_expected_version: 2,
        p_idempotency_key: idempotencyKey,
        p_request_id: privacyRequestId,
      },
    });
  });

  for (const [sqlState, code, status] of [
    ["KFP03", "REQUESTS_PAUSED", 503],
    ["KFP04", "IDEMPOTENCY_KEY_REUSED", 409],
    ["KFP05", "PRIVACY_REQUEST_ALREADY_PENDING", 409],
    ["KFP06", "NOT_FOUND", 404],
    ["KFP07", "VERSION_CONFLICT", 409],
    ["KFP08", "OWNER_TRANSFER_REQUIRED", 409],
    ["KFP09", "SUBSCRIPTION_ACKNOWLEDGEMENT_REQUIRED", 409],
    ["KFP10", "REQUEST_NOT_CANCELLABLE", 409],
  ]) {
    test(`maps ${sqlState} to stable ${code}`, async () => {
      const response = await handlerFor({
        invokeRpc: async () => { throw new AccountDeletionRpcError(sqlState); },
      })(jsonRequest({operation: "preflight"}));
      const payload = await response.json();
      assert.equal(response.status, status);
      assert.equal(payload.error.code, code);
      assert.deepEqual(Object.keys(payload.error).sort(), [
        "code", "messageKey", "requestId", "retryable",
      ]);
    });
  }

  test("auth idempotency method origin and exact body fail closed", async () => {
    let calls = 0;
    const handler = handlerFor({invokeRpc: async () => { calls += 1; return [requestRow()]; }});
    const cases = [
      [jsonRequest({operation: "preflight"}, {authenticated: false}), 401, "AUTH_REQUIRED"],
      [jsonRequest({operation: "cancel", requestId: privacyRequestId, expectedVersion: 1}), 400, "IDEMPOTENCY_KEY_REQUIRED"],
      [jsonRequest({operation: "preflight", extra: true}), 400, "VALIDATION_FAILED"],
      [new Request("http://local/account-deletion", {method: "GET"}), 405, "METHOD_NOT_ALLOWED"],
      [jsonRequest({operation: "preflight"}, {origin: "https://evil.invalid"}), 403, "PERMISSION_DENIED"],
    ];
    for (const [request, status, code] of cases) {
      const response = await handler(request);
      assert.equal(response.status, status);
      assert.equal((await response.json()).error.code, code);
    }
    assert.equal(calls, 0);
  });

  test("malformed RPC fields return a redacted unavailable error", async () => {
    const response = await handlerFor({
      invokeRpc: async () => [{...preflightRow(), provider_customer_ref: "private"}],
    })(jsonRequest({operation: "preflight"}));
    const text = await response.text();
    assert.equal(response.status, 503);
    assert.doesNotMatch(text, /provider_customer_ref|private/);
  });
});

function handlerFor({calls = [], authenticate, invokeRpc} = {}) {
  return createAccountDeletionHandler({
    allowedOrigins: ["https://app.kinflow.test"],
    nowEpochSeconds: () => nowSeconds,
    authenticate: authenticate ?? (async (authorization) => {
      if (authorization === "Bearer access-token") return {userId, claims: {}};
      if (authorization === `Bearer ${recentProof}`) {
        return {userId, claims: {amr: [{method: "oauth", timestamp: nowSeconds}]}};
      }
      return null;
    }),
    invokeRpc: invokeRpc ?? (async (name, parameters) => {
      calls.push({name, parameters});
      if (name === "get_account_deletion_preflight") return [preflightRow()];
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
  return new Request("http://local/account-deletion", {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
}

function preflightRow() {
  return {
    can_request: true,
    owner_household_count: 0,
    has_active_subscription: true,
    pending_request_id: null,
    pending_status: null,
    pending_request_version: null,
    requests_enabled: true,
    cancellation_window_seconds: 86400,
    evaluated_at: "2027-01-15T08:00:00Z",
  };
}

function requestRow(overrides = {}) {
  return {
    request_id: privacyRequestId,
    request_type: "delete_account",
    status: "queued",
    requested_at: "2027-01-15T08:00:00Z",
    scheduled_for: "2027-01-16T08:00:00Z",
    processing_started_at: null,
    completed_at: null,
    failed_at: null,
    cancelled_at: null,
    failure_code: null,
    active_subscription_at_request: true,
    subscription_acknowledged: true,
    cancellable: true,
    version: 1,
    ...overrides,
  };
}
