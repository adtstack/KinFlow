import assert from "node:assert/strict";
import {describe, test} from "node:test";

import {
  createMemberLifecycleHandler,
  hasRecentOAuthAuthentication,
  MemberLifecycleRpcError,
  memberLifecycleContractVersion,
} from "../functions/_shared/member_lifecycle_contract.mjs";

const nowEpochSeconds = 1_800_000_000;
const userId = "00000000-0000-4000-8000-000000000101";
const otherUserId = "00000000-0000-4000-8000-000000000102";
const householdId = "20000000-0000-4000-8000-000000000101";
const memberId = "30000000-0000-4000-8000-000000000102";
const fallbackHouseholdId = "20000000-0000-4000-8000-000000000201";
const fallbackMemberId = "30000000-0000-4000-8000-000000000202";
const requestId = "70000000-0000-4000-8000-000000000101";
const idempotencyKey = "80000000-0000-4000-8000-000000000101";
const freshProof = "fresh-oauth-proof";

describe("household member lifecycle Edge contract", () => {
  test("change role requires fresh OAuth proof and forwards exact command fields", async () => {
    const calls = [];
    const handler = handlerFor({
      invokeRpc: async (name, parameters) => {
        calls.push({name, parameters});
        return [{
          household_id: householdId,
          member_id: memberId,
          role: "admin",
          version: 8,
        }];
      },
    });

    const response = await handler(jsonRequest({
      operation: "changeRole",
      householdId,
      memberId,
      role: "admin",
      expectedVersion: 7,
    }, {proof: freshProof}));

    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {
      data: {householdId, memberId, role: "admin", version: 8},
      meta: {requestId, contractVersion: memberLifecycleContractVersion},
    });
    assert.deepEqual(calls, [{
      name: "change_household_member_role",
      parameters: {
        p_authenticated_user_id: userId,
        p_expected_version: 7,
        p_household_id: householdId,
        p_idempotency_key: idempotencyKey,
        p_new_role: "admin",
        p_target_member_id: memberId,
      },
    }]);
    assert.equal(JSON.stringify(calls).includes(freshProof), false);
  });

  test("owner transfer accepts authorization-code AMR and allowlists its response", async () => {
    const handler = handlerFor({
      authenticate: authenticationFor({
        "Bearer authorization-code-proof": {
          userId,
          claims: {
            amr: [{
              method: "oauth_provider/authorization_code",
              timestamp: nowEpochSeconds - 45,
            }],
          },
        },
      }),
      invokeRpc: async (name, parameters) => {
        assert.equal(name, "transfer_household_owner");
        assert.equal(parameters.p_new_owner_member_id, memberId);
        return [{
          household_id: householdId,
          owner_member_id: memberId,
          version: 3,
          ignored_provider_field: "must-not-escape",
        }];
      },
    });

    const response = await handler(jsonRequest({
      operation: "transferOwner",
      householdId,
      newOwnerMemberId: memberId,
      expectedVersion: 2,
    }, {proof: "authorization-code-proof"}));

    assert.equal(response.status, 200);
    assert.deepEqual((await response.json()).data, {
      householdId,
      ownerMemberId: memberId,
      version: 3,
    });
  });

  test("remove member does not require or forward a recent-auth credential", async () => {
    let parameters;
    const handler = handlerFor({
      invokeRpc: async (name, value) => {
        assert.equal(name, "remove_household_member");
        parameters = value;
        return [{
          household_id: householdId,
          member_id: memberId,
          version: 5,
          removed_at: "2026-07-30T00:00:00Z",
        }];
      },
    });
    const response = await handler(jsonRequest({
      operation: "removeMember",
      householdId,
      memberId,
      expectedVersion: 4,
    }));

    assert.equal(response.status, 200);
    assert.deepEqual(parameters, {
      p_authenticated_user_id: userId,
      p_expected_version: 4,
      p_household_id: householdId,
      p_idempotency_key: idempotencyKey,
      p_target_member_id: memberId,
    });
  });

  test("leave household preserves a paired nullable fallback selection", async () => {
    const handler = handlerFor({
      invokeRpc: async (name) => {
        assert.equal(name, "leave_household");
        return [{
          household_id: householdId,
          member_id: memberId,
          version: 6,
          removed_at: "2026-07-30T00:00:00Z",
          active_household_id: fallbackHouseholdId,
          active_member_id: fallbackMemberId,
        }];
      },
    });
    const response = await handler(jsonRequest({
      operation: "leaveHousehold",
      householdId,
      expectedVersion: 5,
    }));

    assert.equal(response.status, 200);
    assert.deepEqual((await response.json()).data, {
      householdId,
      memberId,
      removedAt: "2026-07-30T00:00:00Z",
      version: 6,
      activeHouseholdId: fallbackHouseholdId,
      activeMemberId: fallbackMemberId,
    });
  });

  test("recent OAuth validation ignores refresh, malformed, expired, and future AMR", () => {
    assert.equal(hasRecentOAuthAuthentication({
      amr: [{method: "token_refresh", timestamp: nowEpochSeconds}],
    }, nowEpochSeconds), false);
    assert.equal(hasRecentOAuthAuthentication({
      amr: [{method: "oauth", timestamp: nowEpochSeconds - 601}],
    }, nowEpochSeconds), false);
    assert.equal(hasRecentOAuthAuthentication({
      amr: [{method: "oauth", timestamp: nowEpochSeconds + 61}],
    }, nowEpochSeconds), false);
    assert.equal(hasRecentOAuthAuthentication({
      amr: [{method: "oauth", timestamp: "1800000000"}],
    }, nowEpochSeconds), false);
    assert.equal(hasRecentOAuthAuthentication({
      amr: [null, {method: "oauth", timestamp: nowEpochSeconds - 600}],
    }, nowEpochSeconds), true);
  });

  test("sensitive commands reject missing, refresh-only, expired, and wrong-user proof", async () => {
    const handler = handlerFor();
    const body = {
      operation: "changeRole",
      householdId,
      memberId,
      role: "admin",
      expectedVersion: 1,
    };
    for (const proof of [undefined, "refresh-only-proof", "expired-oauth-proof", "wrong-user-proof"]) {
      const response = await handler(jsonRequest(body, {proof}));
      assert.equal(response.status, 403, proof ?? "missing");
      assert.equal((await response.json()).error.code, "RECENT_AUTH_REQUIRED");
    }
  });

  for (const [sqlState, code, status] of [
    ["KFM01", "AUTH_REQUIRED", 401],
    ["KFM02", "VALIDATION_FAILED", 400],
    ["KFM03", "PERMISSION_DENIED", 403],
    ["KFM04", "IDEMPOTENCY_KEY_REUSED", 409],
    ["KFM05", "NOT_FOUND_OR_FORBIDDEN", 404],
    ["KFM06", "VERSION_CONFLICT", 409],
    ["KFM07", "ROLE_NOT_ALLOWED", 403],
    ["KFM08", "OWNER_TRANSFER_REQUIRED", 409],
  ]) {
    test(`maps ${sqlState} to stable ${code}`, async () => {
      const handler = handlerFor({
        invokeRpc: async () => {
          throw new MemberLifecycleRpcError(sqlState);
        },
      });
      const response = await handler(jsonRequest({
        operation: "removeMember",
        householdId,
        memberId,
        expectedVersion: 1,
      }));
      const payload = await response.json();
      assert.equal(response.status, status);
      assert.equal(payload.error.code, code);
      assert.deepEqual(Object.keys(payload.error).sort(), [
        "code",
        "messageKey",
        "requestId",
        "retryable",
      ]);
    });
  }

  test("authentication and UUID idempotency are required before RPC invocation", async () => {
    let calls = 0;
    const handler = handlerFor({
      invokeRpc: async () => {
        calls += 1;
        return [];
      },
    });
    const body = {
      operation: "removeMember",
      householdId,
      memberId,
      expectedVersion: 1,
    };

    const unauthenticated = await handler(jsonRequest(body, {authenticated: false}));
    assert.equal(unauthenticated.status, 401);
    const missingKey = await handler(jsonRequest(body, {idempotent: false}));
    assert.equal(missingKey.status, 400);
    assert.equal((await missingKey.json()).error.code, "IDEMPOTENCY_KEY_REQUIRED");
    assert.equal(calls, 0);
  });

  test("operation bodies are exact, typed, bounded, and owner role is rejected", async () => {
    const handler = handlerFor();
    for (const body of [
      {operation: "unknown", householdId, expectedVersion: 1},
      {operation: "removeMember", householdId, memberId, expectedVersion: 0},
      {operation: "changeRole", householdId, memberId, role: "owner", expectedVersion: 1},
      {operation: "leaveHousehold", householdId, expectedVersion: 1, memberId},
    ]) {
      const response = await handler(jsonRequest(body));
      assert.equal(response.status, 400);
      assert.equal((await response.json()).error.code, "VALIDATION_FAILED");
    }

    const oversized = await handler(new Request("http://local/manage-household-members", {
      method: "POST",
      headers: {
        authorization: "Bearer synthetic-session",
        "content-type": "application/json",
        "idempotency-key": idempotencyKey,
      },
      body: JSON.stringify({padding: "A".repeat(9000)}),
    }));
    assert.equal(oversized.status, 400);
  });

  test("invalid provider payload fails closed without leaking credentials", async () => {
    const handler = handlerFor({invokeRpc: async () => [{household_id: householdId}]});
    const response = await handler(jsonRequest({
      operation: "changeRole",
      householdId,
      memberId,
      role: "admin",
      expectedVersion: 1,
    }, {proof: freshProof}));
    const payload = await response.json();
    assert.equal(response.status, 503);
    assert.equal(payload.error.code, "TEMPORARILY_UNAVAILABLE");
    assert.equal(payload.error.retryable, true);
    assert.equal(JSON.stringify(payload).includes(freshProof), false);
  });

  test("method, content type, CORS origin, and cache policy are enforced", async () => {
    const handler = handlerFor();
    assert.equal((await handler(new Request("http://local/manage", {method: "GET"}))).status, 405);
    assert.equal((await handler(new Request("http://local/manage", {
      method: "POST",
      body: "{}",
    }))).status, 400);
    assert.equal((await handler(new Request("http://local/manage", {
      method: "POST",
      headers: {"content-type": "application/json", origin: "https://evil.invalid"},
      body: "{}",
    }))).status, 403);

    const preflight = await handler(new Request("http://local/manage", {
      method: "OPTIONS",
      headers: {origin: "http://127.0.0.1:3000"},
    }));
    assert.equal(preflight.status, 204);
    assert.equal(preflight.headers.get("access-control-allow-origin"), "http://127.0.0.1:3000");
    assert.equal(preflight.headers.get("cache-control"), "no-store");
  });
});

function handlerFor(overrides = {}) {
  return createMemberLifecycleHandler({
    allowedOrigins: ["http://127.0.0.1:3000"],
    authenticate: overrides.authenticate ?? authenticationFor(),
    invokeRpc: overrides.invokeRpc ?? (async () => {
      throw new Error("RPC must not be invoked by this test");
    }),
    nowEpochSeconds: () => nowEpochSeconds,
  });
}

function authenticationFor(additional = {}) {
  const identities = {
    "Bearer synthetic-session": {userId, claims: {amr: []}},
    "Bearer fresh-oauth-proof": {
      userId,
      claims: {amr: [{method: "oauth", timestamp: nowEpochSeconds - 30}]},
    },
    "Bearer refresh-only-proof": {
      userId,
      claims: {amr: [{method: "token_refresh", timestamp: nowEpochSeconds}]},
    },
    "Bearer expired-oauth-proof": {
      userId,
      claims: {amr: [{method: "oauth", timestamp: nowEpochSeconds - 601}]},
    },
    "Bearer wrong-user-proof": {
      userId: otherUserId,
      claims: {amr: [{method: "oauth", timestamp: nowEpochSeconds - 30}]},
    },
    ...additional,
  };
  return async (authorization) => identities[authorization] ?? null;
}

function jsonRequest(body, {
  authenticated = true,
  idempotent = true,
  proof,
} = {}) {
  const headers = {
    "content-type": "application/json",
    "x-request-id": requestId,
  };
  if (authenticated) headers.authorization = "Bearer synthetic-session";
  if (idempotent) headers["idempotency-key"] = idempotencyKey;
  if (proof !== undefined) headers["x-kinflow-recent-auth"] = proof;
  return new Request("http://local/manage-household-members", {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
}
