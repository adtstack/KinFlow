import assert from "node:assert/strict";
import {describe, test} from "node:test";

import {
  createInviteHandler,
  InviteRpcError,
  inviteContractVersion,
} from "../functions/_shared/invite_contract.mjs";
import {generateInviteShortCode} from "../functions/_shared/invite_runtime.mjs";

const userId = "00000000-0000-4000-8000-000000000101";
const householdId = "20000000-0000-4000-8000-000000000101";
const inviteId = "50000000-0000-4000-8000-000000000101";
const memberId = "30000000-0000-4000-8000-000000000102";
const requestId = "70000000-0000-4000-8000-000000000101";
const rawToken = "A".repeat(43);
const rawShortCode = "ABCD-EFGH";
const runtimePolicyHeaders = Object.freeze({
  "x-kinflow-client-version": "0.1.0-dev+10",
  "x-kinflow-client-build": "10",
  "x-kinflow-contract-version": "2026-08-09",
  "x-kinflow-platform": "android",
  "x-kinflow-environment": "dev",
});

describe("invite Edge contract", () => {
  test("create returns a raw token once and sends only its hash to the DB", async () => {
    const calls = [];
    const handler = handlerFor("create", {
      invokeRpc: async (name, parameters, compatibilityHeaders) => {
        calls.push({name, parameters, compatibilityHeaders});
        if (name === "consume_invite_rate_limit") return true;
        return [{
          invite_id: inviteId,
          household_id: householdId,
          role: "member",
          expires_at: "2026-08-04T00:00:00Z",
          short_code_expires_at: "2026-07-29T00:00:00Z",
          status: "active",
          created: true,
        }];
      },
    });

    const response = await handler(jsonRequest("create-invite", {
      householdId,
      role: "member",
      targetEmail: " ADULT-B@LOCAL.KINFLOW.INVALID ",
      expiresInHours: 168,
    }, {authenticated: true, idempotent: true, runtimePolicy: true}));

    assert.equal(response.status, 201);
    assert.equal(response.headers.get("cache-control"), "no-store");
    assert.equal(response.headers.get("x-request-id"), requestId);
    const payload = await response.json();
    assert.deepEqual(payload, {
      data: {
        id: inviteId,
        householdId,
        role: "member",
        expiresAt: "2026-08-04T00:00:00Z",
        status: "active",
        rawToken,
        shortCode: rawShortCode,
        shortCodeExpiresAt: "2026-07-29T00:00:00Z",
      },
      meta: {requestId, contractVersion: inviteContractVersion},
    });
    assert.equal(calls[0].name, "consume_invite_rate_limit");
    assert.equal(calls[1].name, "create_household_invite_with_short_code");
    assert.deepEqual(calls[0].compatibilityHeaders, runtimePolicyHeaders);
    assert.deepEqual(calls[1].compatibilityHeaders, runtimePolicyHeaders);
    assert.equal(calls[1].parameters.p_target_email, "adult-b@local.kinflow.invalid");
    assert.match(calls[1].parameters.p_token_hash_hex, /^[0-9a-f]{64}$/);
    assert.match(calls[1].parameters.p_short_code_hash_hex, /^[0-9a-f]{64}$/);
    assert.equal(calls[1].parameters.p_short_code_expires_in_hours, 24);
    assert.equal(JSON.stringify(calls).includes(rawToken), false);
    assert.equal(JSON.stringify(calls).includes(rawShortCode), false);
  });

  test("idempotent create retry omits a new raw token", async () => {
    const handler = handlerFor("create", {
      invokeRpc: async (name) => name === "consume_invite_rate_limit"
        ? true
        : [{
          invite_id: inviteId,
          household_id: householdId,
          role: "member",
          expires_at: "2026-08-04T00:00:00Z",
          status: "active",
          created: false,
        }],
    });
    const response = await handler(jsonRequest("create-invite", {
      householdId,
      role: "member",
    }, {authenticated: true, idempotent: true}));
    const payload = await response.json();
    assert.equal(response.status, 201);
    assert.equal(Object.hasOwn(payload.data, "rawToken"), false);
    assert.equal(Object.hasOwn(payload.data, "shortCode"), false);
    assert.equal(Object.hasOwn(payload.data, "shortCodeExpiresAt"), false);
  });

  test("public preview returns only minimal display data", async () => {
    let authenticateCalled = false;
    const handler = handlerFor("preview", {
      authenticate: async () => {
        authenticateCalled = true;
        return null;
      },
      invokeRpc: async (name) => name === "consume_invite_rate_limit"
        ? true
        : [{
          valid: true,
          household_display_name: "Primary household",
          inviter_display_name: "Adult A",
          role: "member",
          expires_at: "2026-08-04T00:00:00Z",
        }],
    });
    const response = await handler(jsonRequest("preview-invite", {token: rawToken}));
    assert.equal(response.status, 200);
    const payload = await response.json();
    assert.deepEqual(Object.keys(payload.data).sort(), [
      "expiresAt",
      "householdDisplayName",
      "inviterDisplayName",
      "role",
      "valid",
    ]);
    assert.equal(authenticateCalled, false);
  });

  test("accept forwards verified identity, hash, idempotency, and explicit switch", async () => {
    const calls = [];
    const handler = handlerFor("accept", {
      invokeRpc: async (name, parameters) => {
        calls.push({name, parameters});
        return name === "consume_invite_rate_limit"
          ? true
          : [{
            member_id: memberId,
            household_id: householdId,
            display_name: "Adult B",
            role: "member",
            active_household_set: false,
          }];
      },
    });
    const response = await handler(jsonRequest("accept-invite", {
      token: rawToken,
      setActiveHousehold: false,
    }, {authenticated: true, idempotent: true}));
    assert.equal(response.status, 200);
    assert.deepEqual((await response.json()).data, {
      id: memberId,
      householdId,
      displayName: "Adult B",
      role: "member",
      activeHouseholdSet: false,
    });
    assert.equal(calls[1].parameters.p_authenticated_user_id, userId);
    assert.equal(calls[1].parameters.p_set_active_household, false);
    assert.equal(calls[1].parameters.p_idempotency_key, "80000000-0000-4000-8000-000000000101");
    assert.equal(JSON.stringify(calls).includes(rawToken), false);
  });

  test("accept defaults setActiveHousehold according to OpenAPI", async () => {
    let acceptedParameters;
    const handler = handlerFor("accept", {
      invokeRpc: async (name, parameters) => {
        if (name === "consume_invite_rate_limit") return true;
        acceptedParameters = parameters;
        return [{
          member_id: memberId,
          household_id: householdId,
          display_name: "Adult B",
          role: "member",
          active_household_set: true,
        }];
      },
    });
    const response = await handler(jsonRequest("accept-invite", {token: rawToken}, {
      authenticated: true,
      idempotent: true,
    }));
    assert.equal(response.status, 200);
    assert.equal(acceptedParameters.p_set_active_household, true);
  });

  test("revoke uses authenticated command fields and no token", async () => {
    const calls = [];
    const handler = handlerFor("revoke", {
      invokeRpc: async (name, parameters) => {
        calls.push({name, parameters});
        return name === "consume_invite_rate_limit"
          ? true
          : [{invite_id: inviteId, household_id: householdId, status: "revoked"}];
      },
    });
    const response = await handler(jsonRequest("revoke-invite", {householdId, inviteId}, {
      authenticated: true,
      idempotent: true,
    }));
    assert.equal(response.status, 200);
    assert.deepEqual((await response.json()).data, {id: inviteId, householdId, status: "revoked"});
    assert.equal(calls[1].parameters.p_authenticated_user_id, userId);
  });

  test("rate limit rejects before the command RPC", async () => {
    const calls = [];
    const handler = handlerFor("preview", {
      invokeRpc: async (name, parameters) => {
        calls.push({name, parameters});
        return false;
      },
    });
    const response = await handler(jsonRequest("preview-invite", {token: rawToken}));
    assert.equal(response.status, 429);
    assert.equal((await response.json()).error.retryable, true);
    assert.equal(calls.length, 1);
    assert.equal(calls[0].name, "consume_invite_rate_limit");
    assert.match(calls[0].parameters.p_key_hash_hex, /^[0-9a-f]{64}$/);
  });

  for (const [sqlState, code, status] of [
    ["KFI02", "VALIDATION_FAILED", 400],
    ["KFI03", "PERMISSION_DENIED", 403],
    ["KFI04", "IDEMPOTENCY_KEY_REUSED", 409],
    ["KFI05", "INVITE_INVALID", 404],
    ["KFI06", "INVITE_EXPIRED", 410],
    ["KFI08", "INVITE_REVOKED", 410],
    ["KFI09", "INVITE_ALREADY_USED", 409],
    ["KFI10", "INVITE_EMAIL_MISMATCH", 403],
    ["KFI11", "PROFILE_UNAVAILABLE", 409],
    ["KFB10", "FEATURE_POLICY_UNAVAILABLE", 503],
    ["KFB11", "FEATURE_POLICY_UNAVAILABLE", 503],
    ["KFB12", "FEATURE_LIMIT_REACHED", 409],
    ["KFR01", "CLIENT_UPDATE_REQUIRED", 426],
    ["KFR02", "CLIENT_MUTATIONS_DISABLED", 503],
    ["KFR03", "RUNTIME_POLICY_UNAVAILABLE", 503],
    ["KFR06", "CLIENT_FEATURE_DISABLED", 503],
  ]) {
    test(`maps ${sqlState} to stable ${code}`, async () => {
      const handler = handlerFor("preview", {
        invokeRpc: async (name) => {
          if (name === "consume_invite_rate_limit") return true;
          throw new InviteRpcError(sqlState);
        },
      });
      const response = await handler(jsonRequest("preview-invite", {token: rawToken}));
      const payload = await response.json();
      assert.equal(response.status, status);
      assert.equal(payload.error.code, code);
      assert.deepEqual(Object.keys(payload.error).sort(), [
        "code",
        "messageKey",
        "requestId",
        "retryable",
      ]);
      assert.equal(JSON.stringify(payload).includes(rawToken), false);
    });
  }

  test("missing or invalid bearer identity is rejected before rate limiting", async () => {
    let invoked = false;
    const handler = handlerFor("accept", {
      authenticate: async () => null,
      invokeRpc: async () => {
        invoked = true;
        return true;
      },
    });
    const response = await handler(jsonRequest("accept-invite", {token: rawToken}, {
      idempotent: true,
    }));
    assert.equal(response.status, 401);
    assert.equal((await response.json()).error.code, "AUTH_REQUIRED");
    assert.equal(invoked, false);
  });

  test("missing idempotency key is a stable validation error", async () => {
    const handler = handlerFor("create");
    const response = await handler(jsonRequest("create-invite", {
      householdId,
      role: "member",
    }, {authenticated: true}));
    assert.equal(response.status, 400);
    assert.equal((await response.json()).error.code, "IDEMPOTENCY_KEY_REQUIRED");
  });

  test("short-code preview normalizes input and sends only its hash", async () => {
    const calls = [];
    const handler = handlerFor("preview", {
      invokeRpc: async (name, parameters) => {
        calls.push({name, parameters});
        if (name === "consume_invite_rate_limit") return true;
        return [{
          valid: true,
          household_display_name: "Primary household",
          inviter_display_name: "Adult A",
          role: "member",
          expires_at: "2026-07-29T00:00:00Z",
        }];
      },
    });
    const response = await handler(jsonRequest("preview-invite", {
      shortCode: " abcd efgh ",
    }));
    assert.equal(response.status, 200);
    assert.equal(calls[0].parameters.p_scope, "preview_short_code");
    assert.equal(calls[1].name, "preview_household_invite_short_code");
    assert.match(calls[1].parameters.p_short_code_hash_hex, /^[0-9a-f]{64}$/);
    assert.equal(JSON.stringify(calls).includes("ABCDEFGH"), false);
  });

  test("authenticated short-code acceptance is user-locked and idempotent", async () => {
    const calls = [];
    const handler = handlerFor("accept", {
      invokeRpc: async (name, parameters) => {
        calls.push({name, parameters});
        if (name === "consume_invite_rate_limit") return true;
        return [{
          member_id: memberId,
          household_id: householdId,
          display_name: "Adult B",
          role: "member",
          active_household_set: true,
        }];
      },
    });
    const response = await handler(jsonRequest("accept-invite", {
      shortCode: rawShortCode,
    }, {authenticated: true, idempotent: true}));
    assert.equal(response.status, 200);
    assert.equal(calls[0].parameters.p_scope, "accept_short_code");
    assert.equal(calls[1].name, "accept_household_invite_short_code");
    assert.equal(calls[1].parameters.p_authenticated_user_id, userId);
    assert.match(calls[1].parameters.p_short_code_hash_hex, /^[0-9a-f]{64}$/);
    assert.equal(JSON.stringify(calls).includes(rawShortCode), false);
  });

  test("preview and accept require exactly one invite credential", async () => {
    const preview = await handlerFor("preview")(jsonRequest("preview-invite", {
      token: rawToken,
      shortCode: rawShortCode,
    }));
    assert.equal(preview.status, 400);
    const accept = await handlerFor("accept")(jsonRequest("accept-invite", {}, {
      authenticated: true,
      idempotent: true,
    }));
    assert.equal(accept.status, 400);
  });

  test("production short-code generator uses the bounded unambiguous alphabet", () => {
    const generated = generateInviteShortCode((bytes) => {
      for (let index = 0; index < bytes.length; index += 1) bytes[index] = index;
      return bytes;
    });
    assert.equal(generated, "2345-6789");
    assert.match(generated, /^[23456789ABCDEFGHJKMNPQRSTVWXYZ]{4}-[23456789ABCDEFGHJKMNPQRSTVWXYZ]{4}$/);
  });

  test("malformed, extra-field, and oversized bodies fail closed", async () => {
    const handler = handlerFor("preview");
    const malformed = await handler(new Request("http://local/preview-invite", {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: "{",
    }));
    assert.equal(malformed.status, 400);

    const extra = await handler(jsonRequest("preview-invite", {
      token: rawToken,
      householdId,
    }));
    assert.equal(extra.status, 400);

    const oversized = await handler(new Request("http://local/preview-invite", {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({token: "A".repeat(9000)}),
    }));
    assert.equal(oversized.status, 400);
  });

  test("method, content type, and exact CORS origin are enforced", async () => {
    const handler = handlerFor("preview");
    const method = await handler(new Request("http://local/preview-invite", {method: "GET"}));
    assert.equal(method.status, 405);

    const contentType = await handler(new Request("http://local/preview-invite", {
      method: "POST",
      body: JSON.stringify({token: rawToken}),
    }));
    assert.equal(contentType.status, 400);

    const forbiddenOrigin = await handler(new Request("http://local/preview-invite", {
      method: "POST",
      headers: {"content-type": "application/json", origin: "https://evil.invalid"},
      body: JSON.stringify({token: rawToken}),
    }));
    assert.equal(forbiddenOrigin.status, 403);

    const preflight = await handler(new Request("http://local/preview-invite", {
      method: "OPTIONS",
      headers: {origin: "http://127.0.0.1:3000"},
    }));
    assert.equal(preflight.status, 204);
    assert.equal(preflight.headers.get("access-control-allow-origin"), "http://127.0.0.1:3000");
    assert.match(
      preflight.headers.get("access-control-allow-headers"),
      /x-kinflow-contract-version/,
    );
  });

  test("invalid provider payload becomes a redacted retryable error", async () => {
    const handler = handlerFor("preview", {
      invokeRpc: async (name) => name === "consume_invite_rate_limit" ? true : [{valid: true}],
    });
    const response = await handler(jsonRequest("preview-invite", {token: rawToken}));
    const payload = await response.json();
    assert.equal(response.status, 503);
    assert.equal(payload.error.code, "TEMPORARILY_UNAVAILABLE");
    assert.equal(payload.error.retryable, true);
    assert.equal(JSON.stringify(payload).includes(rawToken), false);
  });
});

function handlerFor(operation, overrides = {}) {
  return createInviteHandler({
    operation,
    allowedOrigins: ["http://127.0.0.1:3000"],
    authenticate: overrides.authenticate ?? (async (authorization) =>
      authorization === "Bearer synthetic-session" ? {userId} : null),
    invokeRpc: overrides.invokeRpc ?? (async (name) => {
      if (name === "consume_invite_rate_limit") return true;
      throw new Error(`Unexpected RPC ${name}`);
    }),
    randomShortCode: () => rawShortCode,
    randomToken: () => rawToken,
    sha256Hex,
  });
}

function jsonRequest(path, body, {
  authenticated = false,
  idempotent = false,
  runtimePolicy = false,
} = {}) {
  const headers = {
    "content-type": "application/json",
    "x-request-id": requestId,
  };
  if (authenticated) headers.authorization = "Bearer synthetic-session";
  if (idempotent) headers["idempotency-key"] = "80000000-0000-4000-8000-000000000101";
  if (runtimePolicy) Object.assign(headers, runtimePolicyHeaders, {
    "x-kinflow-forwarded-user-operation": "0",
  });
  return new Request(`http://local/${path}`, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
}

async function sha256Hex(value) {
  return Buffer.from(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)))
    .toString("hex");
}
