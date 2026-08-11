import {hasRecentOAuthAuthentication} from "./member_lifecycle_contract.mjs";

export const accountDeletionContractVersion = "2026-08-08-wp07-01";

const maximumBodyBytes = 8 * 1024;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const errorCatalog = Object.freeze({
  AUTH_REQUIRED: [401, false, "errors.authRequired"],
  IDEMPOTENCY_KEY_REQUIRED: [400, false, "errors.idempotencyKeyRequired"],
  IDEMPOTENCY_KEY_REUSED: [409, false, "errors.idempotencyKeyReused"],
  INTERNAL_ERROR: [500, true, "errors.internal"],
  METHOD_NOT_ALLOWED: [405, false, "errors.validationFailed"],
  NOT_FOUND: [404, false, "errors.notFound"],
  OWNER_TRANSFER_REQUIRED: [409, false, "errors.ownerTransferRequired"],
  PERMISSION_DENIED: [403, false, "errors.permissionDenied"],
  PRIVACY_REQUEST_ALREADY_PENDING: [409, false, "errors.privacyRequestAlreadyPending"],
  RECENT_AUTH_REQUIRED: [403, false, "errors.recentAuthRequired"],
  REQUEST_NOT_CANCELLABLE: [409, false, "errors.privacyRequestNotCancellable"],
  REQUESTS_PAUSED: [503, true, "errors.temporarilyUnavailable"],
  SUBSCRIPTION_ACKNOWLEDGEMENT_REQUIRED: [409, false, "errors.subscriptionAcknowledgementRequired"],
  TEMPORARILY_UNAVAILABLE: [503, true, "errors.temporarilyUnavailable"],
  VALIDATION_FAILED: [400, false, "errors.validationFailed"],
  VERSION_CONFLICT: [409, false, "errors.versionConflict"],
});

const sqlStateErrors = Object.freeze({
  KFP01: "AUTH_REQUIRED",
  KFP02: "VALIDATION_FAILED",
  KFP03: "REQUESTS_PAUSED",
  KFP04: "IDEMPOTENCY_KEY_REUSED",
  KFP05: "PRIVACY_REQUEST_ALREADY_PENDING",
  KFP06: "NOT_FOUND",
  KFP07: "VERSION_CONFLICT",
  KFP08: "OWNER_TRANSFER_REQUIRED",
  KFP09: "SUBSCRIPTION_ACKNOWLEDGEMENT_REQUIRED",
  KFP10: "REQUEST_NOT_CANCELLABLE",
  KFP11: "TEMPORARILY_UNAVAILABLE",
  KFP12: "TEMPORARILY_UNAVAILABLE",
  KFP13: "AUTH_REQUIRED",
});

export class AccountDeletionRpcError extends Error {
  constructor(code) {
    super("Account deletion RPC failed");
    this.name = "AccountDeletionRpcError";
    this.code = typeof code === "string" ? code : "";
  }
}

export function createAccountDeletionHandler({
  allowedOrigins,
  authenticate,
  invokeRpc,
  nowEpochSeconds = () => Math.floor(Date.now() / 1000),
}) {
  const origins = new Set(allowedOrigins);
  return async function handleAccountDeletion(request) {
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
    const context = validatedContext(body);
    if (context === null) {
      return errorResponse("VALIDATION_FAILED", requestId, headers);
    }

    try {
      const authorization = request.headers.get("authorization") ?? "";
      const identity = await authenticate(authorization);
      if (identity === null || !uuidPattern.test(identity.userId)) {
        return errorResponse("AUTH_REQUIRED", requestId, headers);
      }

      if (context.requiresIdempotency) {
        const idempotencyKey = request.headers.get("idempotency-key")?.trim() ?? "";
        if (!validIdempotencyKey(idempotencyKey)) {
          return errorResponse("IDEMPOTENCY_KEY_REQUIRED", requestId, headers);
        }
        context.idempotencyKey = idempotencyKey;
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

      const data = await execute(context, identity.userId.toLowerCase(), requestId, invokeRpc);
      return Response.json(
        {data, meta: {requestId, contractVersion: accountDeletionContractVersion}},
        {status: context.operation === "request" ? 202 : 200, headers},
      );
    } catch (error) {
      const code = error instanceof AccountDeletionRpcError
        ? sqlStateErrors[error.code] ?? "TEMPORARILY_UNAVAILABLE"
        : "TEMPORARILY_UNAVAILABLE";
      return errorResponse(code, requestId, headers);
    }
  };
}

async function execute(context, userId, correlationId, invokeRpc) {
  if (context.operation === "preflight") {
    return preflight(singleRow(await invokeRpc("get_account_deletion_preflight", {
      p_authenticated_user_id: userId,
    })));
  }
  if (context.operation === "status") {
    const rows = await invokeRpc("get_account_deletion_request", {
      p_authenticated_user_id: userId,
      p_request_id: context.requestId,
    });
    return rows.length === 0 ? null : privacyRequest(singleRow(rows));
  }
  if (context.operation === "request") {
    return privacyRequest(singleRow(await invokeRpc("request_account_deletion", {
      p_authenticated_user_id: userId,
      p_correlation_id: correlationId,
      p_idempotency_key: context.idempotencyKey,
      p_subscription_acknowledged: context.subscriptionAcknowledged,
    })));
  }
  return privacyRequest(singleRow(await invokeRpc("cancel_account_deletion", {
    p_authenticated_user_id: userId,
    p_correlation_id: correlationId,
    p_expected_version: context.expectedVersion,
    p_idempotency_key: context.idempotencyKey,
    p_request_id: context.requestId,
  })));
}

function validatedContext(body) {
  if (!isPlainObject(body) || typeof body.operation !== "string") return null;
  const keys = Object.keys(body).sort();
  if (body.operation === "preflight" && sameKeys(keys, ["operation"])) {
    return {operation: "preflight", requiresIdempotency: false, requiresRecentAuthentication: false};
  }
  if (body.operation === "status" &&
    (sameKeys(keys, ["operation"]) || sameKeys(keys, ["operation", "requestId"])) &&
    (body.requestId === undefined || uuidPattern.test(body.requestId))) {
    return {
      operation: "status",
      requestId: body.requestId?.toLowerCase() ?? null,
      requiresIdempotency: false,
      requiresRecentAuthentication: false,
    };
  }
  if (body.operation === "request" &&
    sameKeys(keys, ["operation", "subscriptionAcknowledged"]) &&
    typeof body.subscriptionAcknowledged === "boolean") {
    return {
      operation: "request",
      subscriptionAcknowledged: body.subscriptionAcknowledged,
      requiresIdempotency: true,
      requiresRecentAuthentication: true,
    };
  }
  if (body.operation === "cancel" &&
    sameKeys(keys, ["expectedVersion", "operation", "requestId"]) &&
    uuidPattern.test(body.requestId) && positiveInteger(body.expectedVersion)) {
    return {
      operation: "cancel",
      expectedVersion: body.expectedVersion,
      requestId: body.requestId.toLowerCase(),
      requiresIdempotency: true,
      requiresRecentAuthentication: false,
    };
  }
  return null;
}

function preflight(row) {
  exactKeys(row, [
    "can_request",
    "cancellation_window_seconds",
    "evaluated_at",
    "has_active_subscription",
    "owner_household_count",
    "pending_request_id",
    "pending_request_version",
    "pending_status",
    "requests_enabled",
  ]);
  const pendingRequestId = optionalUuid(row.pending_request_id);
  const pendingStatus = optionalStatus(row.pending_status);
  const pendingRequestVersion = optionalPositiveInteger(row.pending_request_version);
  if (typeof row.can_request !== "boolean" ||
    !nonNegativeInteger(row.owner_household_count) ||
    typeof row.has_active_subscription !== "boolean" ||
    typeof row.requests_enabled !== "boolean" ||
    !positiveInteger(row.cancellation_window_seconds) ||
    !validTimestamp(row.evaluated_at) ||
    (pendingRequestVersion !== null && !positiveInteger(pendingRequestVersion)) ||
    (pendingRequestId === null) !== (pendingStatus === null) ||
    (pendingRequestId === null) !== (pendingRequestVersion === null)) {
    throw new TypeError("Invalid preflight payload");
  }
  return {
    canRequest: row.can_request,
    ownerHouseholdCount: row.owner_household_count,
    hasActiveSubscription: row.has_active_subscription,
    pendingRequestId,
    pendingStatus,
    pendingRequestVersion,
    requestsEnabled: row.requests_enabled,
    cancellationWindowSeconds: row.cancellation_window_seconds,
    evaluatedAt: row.evaluated_at,
  };
}

function privacyRequest(row) {
  exactKeys(row, [
    "active_subscription_at_request",
    "cancellable",
    "cancelled_at",
    "completed_at",
    "failed_at",
    "failure_code",
    "processing_started_at",
    "request_id",
    "request_type",
    "requested_at",
    "scheduled_for",
    "status",
    "subscription_acknowledged",
    "version",
  ]);
  const id = requiredUuid(row.request_id);
  const status = requiredStatus(row.status);
  const nullableTimestamps = [
    row.processing_started_at,
    row.completed_at,
    row.failed_at,
    row.cancelled_at,
  ];
  if (row.request_type !== "delete_account" ||
    !validTimestamp(row.requested_at) ||
    !validTimestamp(row.scheduled_for) ||
    nullableTimestamps.some((value) => value !== null && !validTimestamp(value)) ||
    (row.failure_code !== null && typeof row.failure_code !== "string") ||
    typeof row.active_subscription_at_request !== "boolean" ||
    typeof row.subscription_acknowledged !== "boolean" ||
    typeof row.cancellable !== "boolean" ||
    !positiveInteger(row.version)) {
    throw new TypeError("Invalid privacy request payload");
  }
  return {
    id,
    type: "deleteAccount",
    status: camelStatus(status),
    requestedAt: row.requested_at,
    scheduledFor: row.scheduled_for,
    processingStartedAt: row.processing_started_at,
    completedAt: row.completed_at,
    failedAt: row.failed_at,
    cancelledAt: row.cancelled_at,
    failureCode: row.failure_code,
    activeSubscriptionAtRequest: row.active_subscription_at_request,
    subscriptionAcknowledged: row.subscription_acknowledged,
    cancellable: row.cancellable,
    version: row.version,
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
      "authorization, content-type, idempotency-key, x-kinflow-recent-auth, x-request-id",
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
  const declared = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declared) && declared > maximumBodyBytes) return null;
  let text;
  try {
    text = await request.text();
  } catch {
    return null;
  }
  if (new TextEncoder().encode(text).byteLength > maximumBodyBytes) return null;
  try {
    const payload = JSON.parse(text);
    return isPlainObject(payload) ? payload : null;
  } catch {
    return null;
  }
}

function singleRow(payload) {
  if (!Array.isArray(payload) || payload.length !== 1 || !isPlainObject(payload[0])) {
    throw new TypeError("Invalid RPC payload");
  }
  return payload[0];
}

function exactKeys(value, expected) {
  if (!isPlainObject(value) || !sameKeys(Object.keys(value).sort(), [...expected].sort())) {
    throw new TypeError("Unexpected RPC fields");
  }
}

function requiredUuid(value) {
  if (typeof value !== "string" || !uuidPattern.test(value)) throw new TypeError("Invalid UUID");
  return value.toLowerCase();
}

function optionalUuid(value) {
  return value === null ? null : requiredUuid(value);
}

function requiredStatus(value) {
  if (!["queued", "verifying", "processing", "completed", "failed", "cancelled"].includes(value)) {
    throw new TypeError("Invalid status");
  }
  return value;
}

function optionalStatus(value) {
  return value === null ? null : camelStatus(requiredStatus(value));
}

function camelStatus(value) {
  return value;
}

function validTimestamp(value) {
  return typeof value === "string" && Number.isFinite(Date.parse(value));
}

function validIdempotencyKey(value) {
  return value.length >= 16 && value.length <= 200 && !/[\u0000-\u001f\u007f]/.test(value);
}

function optionalPositiveInteger(value) {
  return value === null ? null : positiveInteger(value) ? value : NaN;
}

function positiveInteger(value) {
  return Number.isSafeInteger(value) && value > 0;
}

function nonNegativeInteger(value) {
  return Number.isSafeInteger(value) && value >= 0;
}

function sameKeys(actual, expected) {
  return actual.length === expected.length && actual.every((key, index) => key === expected[index]);
}

function isJsonContentType(value) {
  return typeof value === "string" && /^application\/json(?:\s*;|$)/i.test(value);
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
