import {
  runtimePolicyClientHeadersFor,
  runtimePolicyCorsAllowHeaders,
} from "./runtime_policy_headers.mjs";

export const memberLifecycleContractVersion = "2026-08-09-wp08-04b";

const maximumBodyBytes = 8 * 1024;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const recentAuthenticationWindowSeconds = 10 * 60;

const errorCatalog = Object.freeze({
  AUTH_REQUIRED: [401, false, "errors.authRequired"],
  CLIENT_FEATURE_DISABLED: [503, true, "errors.clientFeatureDisabled"],
  CLIENT_MUTATIONS_DISABLED: [503, true, "errors.clientMutationsDisabled"],
  CLIENT_UPDATE_REQUIRED: [426, false, "errors.clientUpdateRequired"],
  IDEMPOTENCY_KEY_REQUIRED: [400, false, "errors.idempotencyKeyRequired"],
  IDEMPOTENCY_KEY_REUSED: [409, false, "errors.idempotencyKeyReused"],
  INTERNAL_ERROR: [500, true, "errors.internal"],
  METHOD_NOT_ALLOWED: [405, false, "errors.validationFailed"],
  NOT_FOUND_OR_FORBIDDEN: [404, false, "errors.notFound"],
  OWNER_TRANSFER_REQUIRED: [409, false, "errors.ownerTransferRequired"],
  PERMISSION_DENIED: [403, false, "errors.permissionDenied"],
  RECENT_AUTH_REQUIRED: [403, false, "errors.recentAuthRequired"],
  ROLE_NOT_ALLOWED: [403, false, "errors.roleNotAllowed"],
  RUNTIME_POLICY_UNAVAILABLE: [503, true, "errors.runtimePolicyUnavailable"],
  TEMPORARILY_UNAVAILABLE: [503, true, "errors.temporarilyUnavailable"],
  VALIDATION_FAILED: [400, false, "errors.validationFailed"],
  VERSION_CONFLICT: [409, false, "errors.versionConflict"],
});

const sqlStateErrors = Object.freeze({
  KFM01: "AUTH_REQUIRED",
  KFM02: "VALIDATION_FAILED",
  KFM03: "PERMISSION_DENIED",
  KFM04: "IDEMPOTENCY_KEY_REUSED",
  KFM05: "NOT_FOUND_OR_FORBIDDEN",
  KFM06: "VERSION_CONFLICT",
  KFM07: "ROLE_NOT_ALLOWED",
  KFM08: "OWNER_TRANSFER_REQUIRED",
  KFR01: "CLIENT_UPDATE_REQUIRED",
  KFR02: "CLIENT_MUTATIONS_DISABLED",
  KFR03: "RUNTIME_POLICY_UNAVAILABLE",
  KFR06: "CLIENT_FEATURE_DISABLED",
});

export class MemberLifecycleRpcError extends Error {
  constructor(code) {
    super("Household member lifecycle RPC failed");
    this.name = "MemberLifecycleRpcError";
    this.code = typeof code === "string" ? code : "";
  }
}

export function createMemberLifecycleHandler({
  allowedOrigins,
  authenticate,
  invokeRpc,
  nowEpochSeconds = () => Math.floor(Date.now() / 1000),
}) {
  const origins = new Set(allowedOrigins);

  return async function handleMemberLifecycleRequest(request) {
    const requestId = requestIdFor(request);
    const origin = request.headers.get("origin");
    const headers = responseHeaders(requestId, origin, origins);

    if (origin !== null && !origins.has(origin)) {
      return errorResponse("PERMISSION_DENIED", requestId, headers);
    }
    if (request.method === "OPTIONS") {
      return new Response(null, {status: 204, headers});
    }
    if (request.method !== "POST") {
      return errorResponse("METHOD_NOT_ALLOWED", requestId, headers);
    }
    if (!isJsonContentType(request.headers.get("content-type"))) {
      return errorResponse("VALIDATION_FAILED", requestId, headers);
    }

    const body = await parseBody(request);
    if (body === null) {
      return errorResponse("VALIDATION_FAILED", requestId, headers);
    }

    try {
      const runtimePolicyHeaders = runtimePolicyClientHeadersFor(request);
      const authorization = request.headers.get("authorization") ?? "";
      const identity = await authenticate(authorization);
      if (identity === null || !uuidPattern.test(identity.userId)) {
        return errorResponse("AUTH_REQUIRED", requestId, headers);
      }

      const idempotencyKey = request.headers.get("idempotency-key")?.trim() ?? "";
      if (!uuidPattern.test(idempotencyKey)) {
        return errorResponse("IDEMPOTENCY_KEY_REQUIRED", requestId, headers);
      }

      const context = validatedContext(body, identity.userId, idempotencyKey);
      if (context === null) {
        return errorResponse("VALIDATION_FAILED", requestId, headers);
      }

      if (context.requiresRecentAuthentication) {
        const proof = request.headers.get("x-kinflow-recent-auth")?.trim() ?? "";
        if (proof.length < 16 || proof.length > 2048) {
          return errorResponse("RECENT_AUTH_REQUIRED", requestId, headers);
        }
        const recentIdentity = await authenticate(`Bearer ${proof}`);
        if (recentIdentity === null ||
          recentIdentity.userId.toLowerCase() !== identity.userId.toLowerCase() ||
          !hasRecentOAuthAuthentication(recentIdentity.claims, nowEpochSeconds())) {
          return errorResponse("RECENT_AUTH_REQUIRED", requestId, headers);
        }
      }

      const data = await executeOperation(
        context,
        invokeRpc,
        runtimePolicyHeaders,
      );
      return Response.json(
        {
          data,
          meta: {requestId, contractVersion: memberLifecycleContractVersion},
        },
        {status: 200, headers},
      );
    } catch (error) {
      const errorCode = error instanceof MemberLifecycleRpcError
        ? sqlStateErrors[error.code] ?? "TEMPORARILY_UNAVAILABLE"
        : "TEMPORARILY_UNAVAILABLE";
      return errorResponse(errorCode, requestId, headers);
    }
  };
}

export function hasRecentOAuthAuthentication(claims, nowEpochSeconds) {
  if (!isPlainObject(claims) || !Array.isArray(claims.amr)) {
    return false;
  }
  const latestOAuthTimestamp = claims.amr.reduce((latest, entry) => {
    if (!isPlainObject(entry) ||
      !["oauth", "oauth_provider/authorization_code"].includes(entry.method) ||
      !Number.isInteger(entry.timestamp)) {
      return latest;
    }
    return Math.max(latest, entry.timestamp);
  }, 0);
  return latestOAuthTimestamp > 0 &&
    latestOAuthTimestamp <= nowEpochSeconds + 60 &&
    latestOAuthTimestamp >= nowEpochSeconds - recentAuthenticationWindowSeconds;
}

function validatedContext(body, userId, idempotencyKey) {
  const operation = body.operation;
  if (!["changeRole", "removeMember", "leaveHousehold", "transferOwner"].includes(operation)) {
    return null;
  }
  const keys = Object.keys(body).sort();
  if (!uuidPattern.test(body.householdId) || !positiveInteger(body.expectedVersion)) {
    return null;
  }

  if (operation === "changeRole") {
    if (!sameKeys(keys, ["expectedVersion", "householdId", "memberId", "operation", "role"]) ||
      !uuidPattern.test(body.memberId) ||
      !["admin", "member"].includes(body.role)) {
      return null;
    }
    return {
      expectedVersion: body.expectedVersion,
      householdId: body.householdId.toLowerCase(),
      idempotencyKey: idempotencyKey.toLowerCase(),
      memberId: body.memberId.toLowerCase(),
      operation,
      requiresRecentAuthentication: true,
      role: body.role,
      userId: userId.toLowerCase(),
    };
  }

  if (operation === "removeMember") {
    if (!sameKeys(keys, ["expectedVersion", "householdId", "memberId", "operation"]) ||
      !uuidPattern.test(body.memberId)) {
      return null;
    }
    return {
      expectedVersion: body.expectedVersion,
      householdId: body.householdId.toLowerCase(),
      idempotencyKey: idempotencyKey.toLowerCase(),
      memberId: body.memberId.toLowerCase(),
      operation,
      requiresRecentAuthentication: false,
      userId: userId.toLowerCase(),
    };
  }

  if (operation === "leaveHousehold") {
    if (!sameKeys(keys, ["expectedVersion", "householdId", "operation"])) {
      return null;
    }
    return {
      expectedVersion: body.expectedVersion,
      householdId: body.householdId.toLowerCase(),
      idempotencyKey: idempotencyKey.toLowerCase(),
      operation,
      requiresRecentAuthentication: false,
      userId: userId.toLowerCase(),
    };
  }

  if (!sameKeys(keys, ["expectedVersion", "householdId", "newOwnerMemberId", "operation"]) ||
    !uuidPattern.test(body.newOwnerMemberId)) {
    return null;
  }
  return {
    expectedVersion: body.expectedVersion,
    householdId: body.householdId.toLowerCase(),
    idempotencyKey: idempotencyKey.toLowerCase(),
    newOwnerMemberId: body.newOwnerMemberId.toLowerCase(),
    operation,
    requiresRecentAuthentication: true,
    userId: userId.toLowerCase(),
  };
}

async function executeOperation(context, invokeRpc, runtimePolicyHeaders) {
  if (context.operation === "changeRole") {
    const row = singleRow(await invokeRpc("change_household_member_role", {
      p_authenticated_user_id: context.userId,
      p_expected_version: context.expectedVersion,
      p_household_id: context.householdId,
      p_idempotency_key: context.idempotencyKey,
      p_new_role: context.role,
      p_target_member_id: context.memberId,
    }, runtimePolicyHeaders));
    return {
      householdId: requiredUuid(row.household_id),
      memberId: requiredUuid(row.member_id),
      role: requiredRole(row.role),
      version: requiredPositiveInteger(row.version),
    };
  }

  if (context.operation === "removeMember") {
    const row = singleRow(await invokeRpc("remove_household_member", {
      p_authenticated_user_id: context.userId,
      p_expected_version: context.expectedVersion,
      p_household_id: context.householdId,
      p_idempotency_key: context.idempotencyKey,
      p_target_member_id: context.memberId,
    }, runtimePolicyHeaders));
    return memberRemovalData(row);
  }

  if (context.operation === "leaveHousehold") {
    const row = singleRow(await invokeRpc("leave_household", {
      p_authenticated_user_id: context.userId,
      p_expected_version: context.expectedVersion,
      p_household_id: context.householdId,
      p_idempotency_key: context.idempotencyKey,
    }, runtimePolicyHeaders));
    return {
      ...memberRemovalData(row),
      activeHouseholdId: optionalUuid(row.active_household_id),
      activeMemberId: optionalUuid(row.active_member_id),
    };
  }

  const row = singleRow(await invokeRpc("transfer_household_owner", {
    p_authenticated_user_id: context.userId,
    p_expected_version: context.expectedVersion,
    p_household_id: context.householdId,
    p_idempotency_key: context.idempotencyKey,
    p_new_owner_member_id: context.newOwnerMemberId,
  }, runtimePolicyHeaders));
  return {
    householdId: requiredUuid(row.household_id),
    ownerMemberId: requiredUuid(row.owner_member_id),
    version: requiredPositiveInteger(row.version),
  };
}

function memberRemovalData(row) {
  return {
    householdId: requiredUuid(row.household_id),
    memberId: requiredUuid(row.member_id),
    removedAt: requiredTimestamp(row.removed_at),
    version: requiredPositiveInteger(row.version),
  };
}

function errorResponse(code, requestId, headers) {
  const [status, retryable, messageKey] = errorCatalog[code] ?? errorCatalog.INTERNAL_ERROR;
  return Response.json(
    {error: {code, messageKey, retryable, requestId}},
    {status, headers},
  );
}

function responseHeaders(requestId, origin, allowedOrigins) {
  const headers = new Headers({
    "access-control-allow-headers":
      `authorization, content-type, idempotency-key, x-kinflow-recent-auth, x-request-id, ${runtimePolicyCorsAllowHeaders}`,
    "access-control-allow-methods": "POST, OPTIONS",
    "cache-control": "no-store",
    "content-type": "application/json; charset=utf-8",
    "referrer-policy": "no-referrer",
    "x-content-type-options": "nosniff",
    "x-request-id": requestId,
  });
  if (origin !== null && allowedOrigins.has(origin)) {
    headers.set("access-control-allow-origin", origin);
    headers.set("vary", "Origin");
  }
  return headers;
}

function requestIdFor(request) {
  const candidate = request.headers.get("x-request-id")?.trim() ?? "";
  return uuidPattern.test(candidate) ? candidate.toLowerCase() : crypto.randomUUID();
}

async function parseBody(request) {
  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > maximumBodyBytes) {
    return null;
  }
  let text;
  try {
    text = await request.text();
  } catch {
    return null;
  }
  if (new TextEncoder().encode(text).byteLength > maximumBodyBytes) {
    return null;
  }
  try {
    const payload = JSON.parse(text);
    return isPlainObject(payload) ? payload : null;
  } catch {
    return null;
  }
}

function sameKeys(actual, expected) {
  return actual.length === expected.length && actual.every((key, index) => key === expected[index]);
}

function singleRow(payload) {
  if (!Array.isArray(payload) || payload.length !== 1 || !isPlainObject(payload[0])) {
    throw new TypeError("Invalid RPC payload");
  }
  return payload[0];
}

function requiredUuid(value) {
  if (typeof value !== "string" || !uuidPattern.test(value)) {
    throw new TypeError("Invalid UUID payload");
  }
  return value.toLowerCase();
}

function optionalUuid(value) {
  if (value === null) {
    return null;
  }
  return requiredUuid(value);
}

function requiredRole(value) {
  if (!["admin", "member"].includes(value)) {
    throw new TypeError("Invalid role payload");
  }
  return value;
}

function requiredPositiveInteger(value) {
  if (!positiveInteger(value)) {
    throw new TypeError("Invalid version payload");
  }
  return value;
}

function requiredTimestamp(value) {
  if (typeof value !== "string" || !Number.isFinite(Date.parse(value))) {
    throw new TypeError("Invalid timestamp payload");
  }
  return value;
}

function positiveInteger(value) {
  return Number.isSafeInteger(value) && value > 0;
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isJsonContentType(value) {
  return typeof value === "string" && /^application\/json(?:\s*;|$)/i.test(value);
}
