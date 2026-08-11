import {hasRecentOAuthAuthentication} from "./member_lifecycle_contract.mjs";

export const householdPrivacyContractVersion = "2026-08-08-wp07-02b";

const maximumBodyBytes = 12 * 1024;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const errorCatalog = Object.freeze({
  ARTIFACT_UNAVAILABLE: [410, false, "errors.householdExportUnavailable"],
  AUTH_REQUIRED: [401, false, "errors.authRequired"],
  CONFIRMATION_MISMATCH: [409, false, "errors.householdNameConfirmationMismatch"],
  DELETION_REQUESTS_PAUSED: [503, true, "errors.temporarilyUnavailable"],
  DOWNLOADS_PAUSED: [503, true, "errors.temporarilyUnavailable"],
  HOUSEHOLD_ALREADY_DELETED: [410, false, "errors.householdAlreadyDeleted"],
  IDEMPOTENCY_KEY_REQUIRED: [400, false, "errors.idempotencyKeyRequired"],
  IDEMPOTENCY_KEY_REUSED: [409, false, "errors.idempotencyKeyReused"],
  INTERNAL_ERROR: [500, true, "errors.internal"],
  METHOD_NOT_ALLOWED: [405, false, "errors.validationFailed"],
  NOT_FOUND: [404, false, "errors.notFound"],
  OWNER_REQUIRED: [403, false, "errors.householdOwnerRequired"],
  PRIVACY_REQUEST_ALREADY_PENDING: [409, false, "errors.privacyRequestAlreadyPending"],
  RECENT_AUTH_REQUIRED: [403, false, "errors.recentAuthRequired"],
  REQUEST_NOT_MUTABLE: [409, false, "errors.householdPrivacyRequestNotMutable"],
  EXPORT_REQUESTS_PAUSED: [503, true, "errors.temporarilyUnavailable"],
  SUBSCRIPTION_ACK_REQUIRED: [409, false, "errors.subscriptionAcknowledgmentRequired"],
  TEMPORARILY_UNAVAILABLE: [503, true, "errors.temporarilyUnavailable"],
  VALIDATION_FAILED: [400, false, "errors.validationFailed"],
  VERSION_CONFLICT: [409, false, "errors.versionConflict"],
});

const sqlStateErrors = Object.freeze({
  KHP01: "AUTH_REQUIRED",
  KHP02: "VALIDATION_FAILED",
  KHP03: "OWNER_REQUIRED",
  KHP04: "IDEMPOTENCY_KEY_REUSED",
  KHP05: "PRIVACY_REQUEST_ALREADY_PENDING",
  KHP06: "NOT_FOUND",
  KHP07: "VERSION_CONFLICT",
  KHP08: "REQUEST_NOT_MUTABLE",
  KHP09: "EXPORT_REQUESTS_PAUSED",
  KHP10: "CONFIRMATION_MISMATCH",
  KHP11: "SUBSCRIPTION_ACK_REQUIRED",
  KHP12: "DELETION_REQUESTS_PAUSED",
  KHP13: "ARTIFACT_UNAVAILABLE",
  KHP14: "DOWNLOADS_PAUSED",
  KHP15: "ARTIFACT_UNAVAILABLE",
  KHP16: "TEMPORARILY_UNAVAILABLE",
  KHP17: "HOUSEHOLD_ALREADY_DELETED",
});

export class HouseholdPrivacyRpcError extends Error {
  constructor(code) {
    super("Household privacy RPC failed");
    this.name = "HouseholdPrivacyRpcError";
    this.code = typeof code === "string" ? code : "";
  }
}

export function createHouseholdPrivacyHandler({
  allowedOrigins,
  authenticate,
  downloadBaseUrl,
  invokeRpc,
  nowEpochSeconds = () => Math.floor(Date.now() / 1000),
  randomTokenBytes = secureRandomTokenBytes,
}) {
  const origins = new Set(allowedOrigins);
  const validatedDownloadBaseUrl = safeDownloadBaseUrl(downloadBaseUrl);
  return async function handleHouseholdPrivacy(request) {
    const requestId = requestIdFor(request);
    const origin = request.headers.get("origin");
    const headers = responseHeaders(requestId, origin, origins);
    if (origin !== null && !origins.has(origin)) {
      return errorResponse("OWNER_REQUIRED", requestId, headers);
    }
    if (request.method === "OPTIONS") return new Response(null, {status: 204, headers});
    if (request.method !== "POST") {
      return errorResponse("METHOD_NOT_ALLOWED", requestId, headers);
    }
    if (!isJsonContentType(request.headers.get("content-type"))) {
      return errorResponse("VALIDATION_FAILED", requestId, headers);
    }
    const context = validatedContext(await parseBody(request));
    if (context === null) return errorResponse("VALIDATION_FAILED", requestId, headers);

    try {
      const authorization = request.headers.get("authorization") ?? "";
      const identity = await authenticate(authorization);
      if (identity === null || !uuidPattern.test(identity.userId)) {
        return errorResponse("AUTH_REQUIRED", requestId, headers);
      }
      if (context.requiresIdempotency) {
        const key = request.headers.get("idempotency-key")?.trim() ?? "";
        if (!validIdempotencyKey(key)) {
          return errorResponse("IDEMPOTENCY_KEY_REQUIRED", requestId, headers);
        }
        context.idempotencyKey = key;
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
      const data = await execute({
        context,
        correlationId: requestId,
        downloadBaseUrl: validatedDownloadBaseUrl,
        invokeRpc,
        randomTokenBytes,
        userId: identity.userId.toLowerCase(),
      });
      const accepted = ["requestExport", "requestDeletion"].includes(context.operation);
      return Response.json(
        {data, meta: {requestId, contractVersion: householdPrivacyContractVersion}},
        {status: accepted ? 202 : 200, headers},
      );
    } catch (error) {
      const code = error instanceof HouseholdPrivacyRpcError
        ? sqlStateErrors[error.code] ?? "TEMPORARILY_UNAVAILABLE"
        : "TEMPORARILY_UNAVAILABLE";
      return errorResponse(code, requestId, headers);
    }
  };
}

async function execute({
  context,
  correlationId,
  downloadBaseUrl,
  invokeRpc,
  randomTokenBytes,
  userId,
}) {
  if (context.operation === "preflight") {
    return preflight(resultRow(await invokeRpc("get_household_privacy_preflight", {
      p_authenticated_user_id: userId,
      p_household_id: context.householdId,
    })));
  }
  if (context.operation === "status") {
    return privacyRequest(resultRow(await invokeRpc("get_household_privacy_request", {
      p_authenticated_user_id: userId,
      p_request_id: context.requestId,
    })));
  }
  if (context.operation === "requestExport") {
    return privacyRequest(resultRow(await invokeRpc("request_household_export", {
      p_authenticated_user_id: userId,
      p_correlation_id: correlationId,
      p_household_id: context.householdId,
      p_idempotency_key: context.idempotencyKey,
    })));
  }
  if (context.operation === "requestDeletion") {
    return privacyRequest(resultRow(await invokeRpc("request_household_deletion", {
      p_acknowledge_member_access_loss: context.acknowledgeMemberAccessLoss,
      p_acknowledge_shared_data_redaction: context.acknowledgeSharedDataRedaction,
      p_acknowledge_subscription_not_cancelled:
        context.acknowledgeSubscriptionNotCancelled,
      p_authenticated_user_id: userId,
      p_confirmation_name: context.confirmationName,
      p_correlation_id: correlationId,
      p_expected_household_version: context.expectedHouseholdVersion,
      p_household_id: context.householdId,
      p_idempotency_key: context.idempotencyKey,
    })));
  }
  if (["cancelExport", "cancelDeletion"].includes(context.operation)) {
    return privacyRequest(resultRow(await invokeRpc("cancel_household_privacy_request", {
      p_authenticated_user_id: userId,
      p_correlation_id: correlationId,
      p_expected_version: context.expectedVersion,
      p_idempotency_key: context.idempotencyKey,
      p_request_id: context.requestId,
      p_request_kind: context.operation === "cancelExport" ? "export" : "deletion",
    })));
  }
  if (context.operation === "revokeExport") {
    return privacyRequest(resultRow(await invokeRpc("revoke_household_export", {
      p_authenticated_user_id: userId,
      p_correlation_id: correlationId,
      p_expected_artifact_version: context.expectedArtifactVersion,
      p_idempotency_key: context.idempotencyKey,
      p_request_id: context.requestId,
    })));
  }

  const rawToken = randomTokenBytes();
  if (!(rawToken instanceof Uint8Array) || rawToken.byteLength !== 32) {
    throw new TypeError("Invalid token source");
  }
  const token = base64Url(rawToken);
  const hash = new Uint8Array(await crypto.subtle.digest("SHA-256", rawToken));
  const grant = downloadGrant(resultRow(await invokeRpc(
    "create_household_export_download_grant",
    {
      p_authenticated_user_id: userId,
      p_correlation_id: correlationId,
      p_export_format: context.format,
      p_request_id: context.requestId,
      p_token_hash_base64: base64(hash),
    },
  )));
  const url = new URL(downloadBaseUrl);
  url.searchParams.set("token", token);
  return {format: grant.format, expiresAt: grant.expiresAt, downloadUrl: url.toString()};
}

function validatedContext(body) {
  if (!isPlainObject(body) || typeof body.operation !== "string") return null;
  const keys = Object.keys(body).sort();
  if (body.operation === "preflight" &&
    sameKeys(keys, ["householdId", "operation"]) && validUuid(body.householdId)) {
    return {...operationContext("preflight"), householdId: body.householdId.toLowerCase()};
  }
  if (body.operation === "status" &&
    sameKeys(keys, ["operation", "requestId"]) && validUuid(body.requestId)) {
    return {...operationContext("status"), requestId: body.requestId.toLowerCase()};
  }
  if (body.operation === "requestExport" &&
    sameKeys(keys, ["householdId", "operation"]) && validUuid(body.householdId)) {
    return {
      ...operationContext("requestExport", {idempotency: true, recent: true}),
      householdId: body.householdId.toLowerCase(),
    };
  }
  if (body.operation === "requestDeletion" && sameKeys(keys, [
    "acknowledgeMemberAccessLoss",
    "acknowledgeSharedDataRedaction",
    "acknowledgeSubscriptionNotCancelled",
    "confirmationName",
    "expectedHouseholdVersion",
    "householdId",
    "operation",
  ]) && validUuid(body.householdId) && positiveInteger(body.expectedHouseholdVersion) &&
    validConfirmationName(body.confirmationName) &&
    body.acknowledgeMemberAccessLoss === true &&
    body.acknowledgeSharedDataRedaction === true &&
    typeof body.acknowledgeSubscriptionNotCancelled === "boolean") {
    return {
      ...operationContext("requestDeletion", {idempotency: true, recent: true}),
      acknowledgeMemberAccessLoss: true,
      acknowledgeSharedDataRedaction: true,
      acknowledgeSubscriptionNotCancelled: body.acknowledgeSubscriptionNotCancelled,
      confirmationName: body.confirmationName,
      expectedHouseholdVersion: body.expectedHouseholdVersion,
      householdId: body.householdId.toLowerCase(),
    };
  }
  if (["cancelExport", "cancelDeletion"].includes(body.operation) &&
    sameKeys(keys, ["expectedVersion", "operation", "requestId"]) &&
    validUuid(body.requestId) && positiveInteger(body.expectedVersion)) {
    return {
      ...operationContext(body.operation, {idempotency: true}),
      expectedVersion: body.expectedVersion,
      requestId: body.requestId.toLowerCase(),
    };
  }
  if (body.operation === "revokeExport" && sameKeys(keys, [
    "expectedArtifactVersion", "operation", "requestId",
  ]) && validUuid(body.requestId) && positiveInteger(body.expectedArtifactVersion)) {
    return {
      ...operationContext("revokeExport", {idempotency: true, recent: true}),
      expectedArtifactVersion: body.expectedArtifactVersion,
      requestId: body.requestId.toLowerCase(),
    };
  }
  if (body.operation === "downloadExport" &&
    sameKeys(keys, ["format", "operation", "requestId"]) &&
    validUuid(body.requestId) && ["json", "text"].includes(body.format)) {
    return {
      ...operationContext("downloadExport", {recent: true}),
      format: body.format,
      requestId: body.requestId.toLowerCase(),
    };
  }
  return null;
}

function operationContext(operation, {idempotency = false, recent = false} = {}) {
  return {
    operation,
    requiresIdempotency: idempotency,
    requiresRecentAuthentication: recent,
  };
}

function preflight(value) {
  exactKeys(value, [
    "activeSubscription", "artifactTtlSeconds", "canDelete", "canExport",
    "conflictingRequestPending", "deletionCancellationWindowSeconds",
    "deletionRequestsEnabled", "downloadGrantTtlSeconds", "downloadsEnabled",
    "evaluatedAt", "exportRequestsEnabled", "household", "memberCount",
    "pendingRequest", "retentionBlocked", "retentionReviewAt",
  ]);
  exactKeys(value.household, ["id", "name", "version"]);
  const pending = value.pendingRequest === null ? null : privacyRequest(value.pendingRequest);
  if (!validUuid(value.household.id) || !validHouseholdName(value.household.name) ||
    !positiveInteger(value.household.version) || !nonNegativeInteger(value.memberCount) ||
    typeof value.activeSubscription !== "boolean" ||
    typeof value.canExport !== "boolean" || typeof value.canDelete !== "boolean" ||
    typeof value.conflictingRequestPending !== "boolean" ||
    typeof value.exportRequestsEnabled !== "boolean" ||
    typeof value.deletionRequestsEnabled !== "boolean" ||
    typeof value.downloadsEnabled !== "boolean" ||
    !positiveInteger(value.artifactTtlSeconds) ||
    !positiveInteger(value.downloadGrantTtlSeconds) ||
    !positiveInteger(value.deletionCancellationWindowSeconds) ||
    typeof value.retentionBlocked !== "boolean" ||
    !optionalTimestamp(value.retentionReviewAt) || !validTimestamp(value.evaluatedAt)) {
    throw new TypeError("Invalid household privacy preflight");
  }
  return {...value, household: {...value.household, id: value.household.id.toLowerCase()}, pendingRequest: pending};
}

function privacyRequest(value) {
  exactKeys(value, [
    "activeSubscriptionAtRequest", "artifact", "cancellable", "cancelledAt",
    "completedAt", "deletion", "failedAt", "failureCode", "householdId", "kind",
    "processingStartedAt", "requestId", "requestedAt", "scheduledFor", "status", "version",
  ]);
  if (!validUuid(value.requestId) || !validUuid(value.householdId) ||
    !["export", "deletion"].includes(value.kind) || !validStatus(value.status) ||
    !validTimestamp(value.requestedAt) || !validTimestamp(value.scheduledFor) ||
    !optionalTimestamp(value.processingStartedAt) || !optionalTimestamp(value.completedAt) ||
    !optionalTimestamp(value.failedAt) || !optionalTimestamp(value.cancelledAt) ||
    (value.failureCode !== null && typeof value.failureCode !== "string") ||
    typeof value.cancellable !== "boolean" || !positiveInteger(value.version) ||
    typeof value.activeSubscriptionAtRequest !== "boolean") {
    throw new TypeError("Invalid household privacy request");
  }
  const artifact = value.artifact === null ? null : exportArtifact(value.artifact);
  const deletion = value.deletion === null ? null : deletionProgress(value.deletion);
  if ((value.kind === "export") !== (artifact !== null) ||
    (value.kind === "deletion") !== (deletion !== null)) {
    throw new TypeError("Invalid household privacy request kind");
  }
  return {
    ...value,
    requestId: value.requestId.toLowerCase(),
    householdId: value.householdId.toLowerCase(),
    artifact,
    deletion,
  };
}

function exportArtifact(value) {
  exactKeys(value, [
    "available", "expiresAt", "humanSizeBytes", "id", "machineSizeBytes",
    "purgedAt", "revokedAt", "schemaVersion", "version",
  ]);
  if (!validUuid(value.id) || !positiveInteger(value.version) ||
    value.schemaVersion !== householdPrivacyContractVersion ||
    !optionalTimestamp(value.expiresAt) || !optionalTimestamp(value.revokedAt) ||
    !optionalTimestamp(value.purgedAt) ||
    !optionalPositiveInteger(value.machineSizeBytes) ||
    !optionalPositiveInteger(value.humanSizeBytes) || typeof value.available !== "boolean") {
    throw new TypeError("Invalid household export artifact");
  }
  return {...value, id: value.id.toLowerCase()};
}

function deletionProgress(value) {
  exactKeys(value, [
    "accessRevokedAt", "billingUnlinkedAt", "redactedAt",
    "retentionBlocked", "retentionReviewAt",
  ]);
  if (typeof value.retentionBlocked !== "boolean" ||
    !optionalTimestamp(value.retentionReviewAt) || !optionalTimestamp(value.accessRevokedAt) ||
    !optionalTimestamp(value.redactedAt) || !optionalTimestamp(value.billingUnlinkedAt)) {
    throw new TypeError("Invalid household deletion progress");
  }
  return value;
}

function downloadGrant(value) {
  exactKeys(value, ["expiresAt", "format"]);
  if (!["json", "text"].includes(value.format) || !validTimestamp(value.expiresAt)) {
    throw new TypeError("Invalid household export grant");
  }
  return value;
}

function resultRow(payload) {
  if (!Array.isArray(payload) || payload.length !== 1 || !isPlainObject(payload[0])) {
    throw new TypeError("Invalid household privacy RPC payload");
  }
  exactKeys(payload[0], ["result"]);
  if (!isPlainObject(payload[0].result)) {
    throw new TypeError("Invalid household privacy RPC result");
  }
  return payload[0].result;
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

async function parseBody(request) {
  const declared = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declared) && declared > maximumBodyBytes) return null;
  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > maximumBodyBytes) return null;
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function safeDownloadBaseUrl(value) {
  const url = new URL(value);
  const loopbackHttp = url.protocol === "http:" &&
    ["127.0.0.1", "localhost"].includes(url.hostname);
  if (!(url.protocol === "https:" || loopbackHttp) ||
    url.username || url.password || url.hash) {
    throw new TypeError("Invalid household export download URL");
  }
  url.search = "";
  return url.toString();
}

function requestIdFor(request) {
  const candidate = request.headers.get("x-request-id")?.trim() ?? "";
  return validUuid(candidate) ? candidate.toLowerCase() : crypto.randomUUID();
}

function secureRandomTokenBytes() {
  return crypto.getRandomValues(new Uint8Array(32));
}

function base64(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function base64Url(bytes) {
  return base64(bytes).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

function validUuid(value) {
  return typeof value === "string" && uuidPattern.test(value);
}

function validTimestamp(value) {
  return typeof value === "string" && Number.isFinite(Date.parse(value));
}

function optionalTimestamp(value) {
  return value === null || validTimestamp(value);
}

function validStatus(value) {
  return ["queued", "verifying", "processing", "completed", "failed", "cancelled"]
    .includes(value);
}

function positiveInteger(value) {
  return Number.isSafeInteger(value) && value > 0;
}

function nonNegativeInteger(value) {
  return Number.isSafeInteger(value) && value >= 0;
}

function optionalPositiveInteger(value) {
  return value === null || positiveInteger(value);
}

function validConfirmationName(value) {
  return validHouseholdName(value) && value === value.trim();
}

function validHouseholdName(value) {
  return typeof value === "string" && value.length >= 1 && value.length <= 80 &&
    !/[\u0000-\u001f\u007f]/.test(value);
}

function validIdempotencyKey(value) {
  return value.length >= 16 && value.length <= 200 &&
    !/[\u0000-\u001f\u007f]/.test(value);
}

function sameKeys(actual, expected) {
  const sorted = [...expected].sort();
  return actual.length === sorted.length &&
    actual.every((key, index) => key === sorted[index]);
}

function exactKeys(value, expected) {
  if (!isPlainObject(value) || !sameKeys(Object.keys(value).sort(), expected)) {
    throw new TypeError("Unexpected household privacy fields");
  }
}

function isJsonContentType(value) {
  return typeof value === "string" && /^application\/json(?:\s*;|$)/i.test(value);
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
