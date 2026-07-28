export const inviteContractVersion = "2026-07-21";

const maximumBodyBytes = 8 * 1024;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const tokenPattern = /^[A-Za-z0-9_-]{20,512}$/;
const idempotencyPattern = /^[^\u0000-\u001f\u007f]{16,200}$/;
const emailPattern = /^[^\s@]+@[^\s@]+$/;

const errorCatalog = Object.freeze({
  AUTH_REQUIRED: [401, false, "errors.authRequired"],
  CAPABILITY_UNSUPPORTED: [501, false, "errors.capabilityUnsupported"],
  IDEMPOTENCY_KEY_REQUIRED: [400, false, "errors.idempotencyKeyRequired"],
  IDEMPOTENCY_KEY_REUSED: [409, false, "errors.idempotencyKeyReused"],
  INTERNAL_ERROR: [500, true, "errors.internal"],
  INVITE_ALREADY_USED: [409, false, "errors.inviteAlreadyUsed"],
  INVITE_EMAIL_MISMATCH: [403, false, "errors.inviteEmailMismatch"],
  INVITE_EXPIRED: [410, false, "errors.inviteExpired"],
  INVITE_INVALID: [404, false, "errors.inviteInvalid"],
  INVITE_REVOKED: [410, false, "errors.inviteRevoked"],
  METHOD_NOT_ALLOWED: [405, false, "errors.validationFailed"],
  PERMISSION_DENIED: [403, false, "errors.permissionDenied"],
  PROFILE_UNAVAILABLE: [409, true, "errors.profileUnavailable"],
  RATE_LIMITED: [429, true, "errors.rateLimited"],
  TEMPORARILY_UNAVAILABLE: [503, true, "errors.temporarilyUnavailable"],
  VALIDATION_FAILED: [400, false, "errors.validationFailed"],
});

const sqlStateErrors = Object.freeze({
  KFI01: "AUTH_REQUIRED",
  KFI02: "VALIDATION_FAILED",
  KFI03: "PERMISSION_DENIED",
  KFI04: "IDEMPOTENCY_KEY_REUSED",
  KFI05: "INVITE_INVALID",
  KFI06: "INVITE_EXPIRED",
  KFI08: "INVITE_REVOKED",
  KFI09: "INVITE_ALREADY_USED",
  KFI10: "INVITE_EMAIL_MISMATCH",
  KFI11: "PROFILE_UNAVAILABLE",
});

export class InviteRpcError extends Error {
  constructor(code) {
    super("Invite RPC failed");
    this.name = "InviteRpcError";
    this.code = typeof code === "string" ? code : "";
  }
}

export function createInviteHandler({
  operation,
  allowedOrigins,
  authenticate,
  invokeRpc,
  randomToken,
  sha256Hex,
}) {
  if (!["create", "preview", "accept", "revoke"].includes(operation)) {
    throw new TypeError("Unsupported invite operation");
  }
  const origins = new Set(allowedOrigins);

  return async function handleInviteRequest(request) {
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
      const context = await validatedContext({
        operation,
        request,
        body,
        authenticate,
        sha256Hex,
      });
      if (context.errorCode !== null) {
        return errorResponse(context.errorCode, requestId, headers);
      }

      const allowed = await consumeRateLimit({
        operation,
        request,
        context,
        invokeRpc,
        sha256Hex,
      });
      if (!allowed) {
        return errorResponse("RATE_LIMITED", requestId, headers);
      }

      const data = await executeOperation({
        operation,
        context,
        invokeRpc,
        randomToken,
        sha256Hex,
      });
      return Response.json(
        {
          data,
          meta: {requestId, contractVersion: inviteContractVersion},
        },
        {status: operation === "create" ? 201 : 200, headers},
      );
    } catch (error) {
      const errorCode = error instanceof InviteRpcError
        ? sqlStateErrors[error.code] ?? "TEMPORARILY_UNAVAILABLE"
        : "TEMPORARILY_UNAVAILABLE";
      return errorResponse(errorCode, requestId, headers);
    }
  };
}

async function validatedContext({operation, request, body, authenticate, sha256Hex}) {
  const invalid = {errorCode: "VALIDATION_FAILED"};
  const keys = Object.keys(body).sort();
  if (operation === "preview") {
    if (keys.length !== 1 || keys[0] !== "token" || !validToken(body.token)) {
      if (typeof body.shortCode === "string") {
        return {errorCode: "CAPABILITY_UNSUPPORTED"};
      }
      return invalid;
    }
    return {
      errorCode: null,
      tokenHash: await sha256Hex(body.token),
    };
  }

  const authorization = request.headers.get("authorization") ?? "";
  const identity = await authenticate(authorization);
  if (identity === null || !uuidPattern.test(identity.userId)) {
    return {errorCode: "AUTH_REQUIRED"};
  }
  const idempotencyKey = request.headers.get("idempotency-key")?.trim() ?? "";
  if (!idempotencyPattern.test(idempotencyKey)) {
    return {errorCode: "IDEMPOTENCY_KEY_REQUIRED"};
  }

  if (operation === "create") {
    if (!sameKeys(keys, ["expiresInHours", "householdId", "role", "targetEmail"], [
      "householdId",
      "role",
    ])) {
      return invalid;
    }
    const expiresInHours = body.expiresInHours ?? 168;
    if (body.targetEmail !== undefined && typeof body.targetEmail !== "string") {
      return invalid;
    }
    const targetEmail = body.targetEmail === undefined ? null : body.targetEmail.trim().toLowerCase();
    if (!uuidPattern.test(body.householdId) ||
      !["admin", "member"].includes(body.role) ||
      !Number.isInteger(expiresInHours) ||
      expiresInHours < 1 ||
      expiresInHours > 720 ||
      (targetEmail !== null &&
        (targetEmail.length > 254 || !emailPattern.test(targetEmail)))) {
      return invalid;
    }
    return {
      errorCode: null,
      expiresInHours,
      householdId: body.householdId.toLowerCase(),
      idempotencyKey,
      role: body.role,
      targetEmail,
      userId: identity.userId.toLowerCase(),
    };
  }

  if (operation === "accept") {
    if (typeof body.shortCode === "string" && body.token === undefined) {
      return {errorCode: "CAPABILITY_UNSUPPORTED"};
    }
    if (!sameKeys(keys, ["setActiveHousehold", "token"], ["token"]) ||
      !validToken(body.token) ||
      (body.setActiveHousehold !== undefined &&
        typeof body.setActiveHousehold !== "boolean")) {
      return invalid;
    }
    return {
      errorCode: null,
      idempotencyKey,
      setActiveHousehold: body.setActiveHousehold ?? true,
      tokenHash: await sha256Hex(body.token),
      userId: identity.userId.toLowerCase(),
    };
  }

  if (!sameKeys(keys, ["householdId", "inviteId"], ["householdId", "inviteId"]) ||
    !uuidPattern.test(body.householdId) ||
    !uuidPattern.test(body.inviteId)) {
    return invalid;
  }
  return {
    errorCode: null,
    householdId: body.householdId.toLowerCase(),
    idempotencyKey,
    inviteId: body.inviteId.toLowerCase(),
    userId: identity.userId.toLowerCase(),
  };
}

async function consumeRateLimit({operation, request, context, invokeRpc, sha256Hex}) {
  const rateMaterial = operation === "preview"
    ? `preview\n${clientAddress(request)}`
    : operation === "accept"
    ? `accept\n${context.userId}\n${context.tokenHash}`
    : `${operation}\n${context.userId}\n${context.householdId}`;
  const payload = await invokeRpc("consume_invite_rate_limit", {
    p_scope: operation,
    p_key_hash_hex: await sha256Hex(rateMaterial),
  });
  return payload === true;
}

async function executeOperation({operation, context, invokeRpc, randomToken, sha256Hex}) {
  if (operation === "create") {
    const rawToken = randomToken();
    if (!validToken(rawToken)) {
      throw new TypeError("Token generator contract violated");
    }
    const payload = await invokeRpc("create_household_invite", {
      p_authenticated_user_id: context.userId,
      p_expires_in_hours: context.expiresInHours,
      p_household_id: context.householdId,
      p_idempotency_key: context.idempotencyKey,
      p_role: context.role,
      p_target_email: context.targetEmail,
      p_token_hash_hex: await sha256Hex(rawToken),
    });
    const row = singleRow(payload);
    const data = {
      id: requiredUuid(row.invite_id),
      householdId: requiredUuid(row.household_id),
      role: requiredRole(row.role),
      expiresAt: requiredTimestamp(row.expires_at),
      status: requiredStatus(row.status),
    };
    if (row.created === true) {
      data.rawToken = rawToken;
    }
    return data;
  }

  if (operation === "preview") {
    const row = singleRow(await invokeRpc("preview_household_invite", {
      p_token_hash_hex: context.tokenHash,
    }));
    if (row.valid !== true) {
      throw new TypeError("Invalid preview result");
    }
    return {
      valid: true,
      householdDisplayName: requiredDisplayText(row.household_display_name),
      inviterDisplayName: requiredDisplayText(row.inviter_display_name),
      role: requiredRole(row.role),
      expiresAt: requiredTimestamp(row.expires_at),
    };
  }

  if (operation === "accept") {
    const row = singleRow(await invokeRpc("accept_household_invite", {
      p_authenticated_user_id: context.userId,
      p_idempotency_key: context.idempotencyKey,
      p_set_active_household: context.setActiveHousehold,
      p_token_hash_hex: context.tokenHash,
    }));
    return {
      id: requiredUuid(row.member_id),
      householdId: requiredUuid(row.household_id),
      displayName: requiredDisplayText(row.display_name),
      role: requiredRole(row.role),
      activeHouseholdSet: requiredBoolean(row.active_household_set),
    };
  }

  const row = singleRow(await invokeRpc("revoke_household_invite", {
    p_authenticated_user_id: context.userId,
    p_household_id: context.householdId,
    p_idempotency_key: context.idempotencyKey,
    p_invite_id: context.inviteId,
  }));
  return {
    id: requiredUuid(row.invite_id),
    householdId: requiredUuid(row.household_id),
    status: requiredStatus(row.status),
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
    "access-control-allow-headers": "authorization, content-type, idempotency-key, x-request-id",
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

function sameKeys(actual, allowed, required) {
  return actual.every((key) => allowed.includes(key)) &&
    required.every((key) => actual.includes(key));
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

function requiredDisplayText(value) {
  if (typeof value !== "string" || value.trim().length < 1 || value.length > 80) {
    throw new TypeError("Invalid display payload");
  }
  return value;
}

function requiredRole(value) {
  if (!["admin", "member"].includes(value)) {
    throw new TypeError("Invalid role payload");
  }
  return value;
}

function requiredStatus(value) {
  if (!["active", "accepted", "revoked", "expired"].includes(value)) {
    throw new TypeError("Invalid status payload");
  }
  return value;
}

function requiredTimestamp(value) {
  if (typeof value !== "string" || !Number.isFinite(Date.parse(value))) {
    throw new TypeError("Invalid timestamp payload");
  }
  return value;
}

function requiredBoolean(value) {
  if (typeof value !== "boolean") {
    throw new TypeError("Invalid boolean payload");
  }
  return value;
}

function validToken(value) {
  return typeof value === "string" && tokenPattern.test(value);
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isJsonContentType(value) {
  return typeof value === "string" && /^application\/json(?:\s*;|$)/i.test(value);
}

function clientAddress(request) {
  const forwarded = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  const connecting = request.headers.get("cf-connecting-ip")?.trim();
  const candidate = forwarded || connecting || "unknown";
  return candidate.slice(0, 128);
}
