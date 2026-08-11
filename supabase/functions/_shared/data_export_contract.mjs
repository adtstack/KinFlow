import {hasRecentOAuthAuthentication} from "./member_lifecycle_contract.mjs";

export const dataExportContractVersion = "2026-08-08-wp07-02a";

const maximumBodyBytes = 8 * 1024;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const errorCatalog = Object.freeze({
  ARTIFACT_UNAVAILABLE: [410, false, "errors.dataExportUnavailable"],
  AUTH_REQUIRED: [401, false, "errors.authRequired"],
  DOWNLOADS_PAUSED: [503, true, "errors.temporarilyUnavailable"],
  EXPORT_TOO_LARGE: [413, false, "errors.dataExportTooLarge"],
  IDEMPOTENCY_KEY_REQUIRED: [400, false, "errors.idempotencyKeyRequired"],
  IDEMPOTENCY_KEY_REUSED: [409, false, "errors.idempotencyKeyReused"],
  INTERNAL_ERROR: [500, true, "errors.internal"],
  METHOD_NOT_ALLOWED: [405, false, "errors.validationFailed"],
  NOT_FOUND: [404, false, "errors.notFound"],
  PERMISSION_DENIED: [403, false, "errors.permissionDenied"],
  PRIVACY_REQUEST_ALREADY_PENDING: [409, false, "errors.privacyRequestAlreadyPending"],
  RECENT_AUTH_REQUIRED: [403, false, "errors.recentAuthRequired"],
  REQUEST_NOT_CANCELLABLE: [409, false, "errors.dataExportNotCancellable"],
  REQUESTS_PAUSED: [503, true, "errors.temporarilyUnavailable"],
  TEMPORARILY_UNAVAILABLE: [503, true, "errors.temporarilyUnavailable"],
  VALIDATION_FAILED: [400, false, "errors.validationFailed"],
  VERSION_CONFLICT: [409, false, "errors.versionConflict"],
});

const sqlStateErrors = Object.freeze({
  KFX01: "AUTH_REQUIRED",
  KFX02: "VALIDATION_FAILED",
  KFX03: "REQUESTS_PAUSED",
  KFX04: "IDEMPOTENCY_KEY_REUSED",
  KFX05: "PRIVACY_REQUEST_ALREADY_PENDING",
  KFX06: "NOT_FOUND",
  KFX07: "VERSION_CONFLICT",
  KFX08: "REQUEST_NOT_CANCELLABLE",
  KFX10: "DOWNLOADS_PAUSED",
  KFX11: "ARTIFACT_UNAVAILABLE",
  KFX12: "ARTIFACT_UNAVAILABLE",
  KFX13: "TEMPORARILY_UNAVAILABLE",
  KFX14: "EXPORT_TOO_LARGE",
  KFX15: "TEMPORARILY_UNAVAILABLE",
});

export class DataExportRpcError extends Error {
  constructor(code) {
    super("Data export RPC failed");
    this.name = "DataExportRpcError";
    this.code = typeof code === "string" ? code : "";
  }
}

export function createDataExportHandler({
  allowedOrigins,
  authenticate,
  downloadBaseUrl,
  invokeRpc,
  nowEpochSeconds = () => Math.floor(Date.now() / 1000),
  randomTokenBytes = secureRandomTokenBytes,
}) {
  const origins = new Set(allowedOrigins);
  const validatedDownloadBaseUrl = safeDownloadBaseUrl(downloadBaseUrl);
  return async function handleDataExport(request) {
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

    const context = validatedContext(await parseBody(request));
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

      const data = await execute({
        context,
        correlationId: requestId,
        downloadBaseUrl: validatedDownloadBaseUrl,
        invokeRpc,
        randomTokenBytes,
        userId: identity.userId.toLowerCase(),
      });
      return Response.json(
        {data, meta: {requestId, contractVersion: dataExportContractVersion}},
        {status: context.operation === "request" ? 202 : 200, headers},
      );
    } catch (error) {
      const code = error instanceof DataExportRpcError
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
    return preflight(singleRow(await invokeRpc("get_data_export_preflight", {
      p_authenticated_user_id: userId,
    })));
  }
  if (context.operation === "status") {
    const rows = await invokeRpc("get_data_export_request", {
      p_authenticated_user_id: userId,
      p_request_id: context.requestId,
    });
    return rows.length === 0 ? null : exportRequest(singleRow(rows));
  }
  if (context.operation === "request") {
    return exportRequest(singleRow(await invokeRpc("request_data_export", {
      p_authenticated_user_id: userId,
      p_correlation_id: correlationId,
      p_idempotency_key: context.idempotencyKey,
    })));
  }
  if (context.operation === "cancel") {
    return exportRequest(singleRow(await invokeRpc("cancel_data_export", {
      p_authenticated_user_id: userId,
      p_correlation_id: correlationId,
      p_expected_version: context.expectedVersion,
      p_idempotency_key: context.idempotencyKey,
      p_request_id: context.requestId,
    })));
  }
  if (context.operation === "revoke") {
    return exportRequest(singleRow(await invokeRpc("revoke_data_export", {
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
  const grant = downloadGrant(singleRow(await invokeRpc(
    "create_data_export_download_grant",
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
  return {
    format: grant.export_format,
    expiresAt: grant.expires_at,
    downloadUrl: url.toString(),
  };
}

function validatedContext(body) {
  if (!isPlainObject(body) || typeof body.operation !== "string") return null;
  const keys = Object.keys(body).sort();
  if (body.operation === "preflight" && sameKeys(keys, ["operation"])) {
    return operationContext("preflight");
  }
  if (body.operation === "status" &&
    (sameKeys(keys, ["operation"]) || sameKeys(keys, ["operation", "requestId"])) &&
    (body.requestId === undefined || uuidPattern.test(body.requestId))) {
    return {
      ...operationContext("status"),
      requestId: body.requestId?.toLowerCase() ?? null,
    };
  }
  if (body.operation === "request" && sameKeys(keys, ["operation"])) {
    return operationContext("request", {idempotency: true, recent: true});
  }
  if (body.operation === "cancel" &&
    sameKeys(keys, ["expectedVersion", "operation", "requestId"]) &&
    uuidPattern.test(body.requestId) && positiveInteger(body.expectedVersion)) {
    return {
      ...operationContext("cancel", {idempotency: true}),
      expectedVersion: body.expectedVersion,
      requestId: body.requestId.toLowerCase(),
    };
  }
  if (body.operation === "revoke" &&
    sameKeys(keys, ["expectedArtifactVersion", "operation", "requestId"]) &&
    uuidPattern.test(body.requestId) && positiveInteger(body.expectedArtifactVersion)) {
    return {
      ...operationContext("revoke", {idempotency: true, recent: true}),
      expectedArtifactVersion: body.expectedArtifactVersion,
      requestId: body.requestId.toLowerCase(),
    };
  }
  if (body.operation === "download" &&
    sameKeys(keys, ["format", "operation", "requestId"]) &&
    uuidPattern.test(body.requestId) && ["json", "text"].includes(body.format)) {
    return {
      ...operationContext("download", {recent: true}),
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

function preflight(row) {
  exactKeys(row, [
    "artifact_ttl_seconds",
    "can_request",
    "conflicting_request_pending",
    "download_grant_ttl_seconds",
    "downloads_enabled",
    "evaluated_at",
    "pending_request_id",
    "pending_request_version",
    "pending_status",
    "requests_enabled",
  ]);
  const pendingRequestId = optionalUuid(row.pending_request_id);
  const pendingStatus = optionalStatus(row.pending_status);
  const pendingVersion = row.pending_request_version;
  if (typeof row.can_request !== "boolean" ||
    typeof row.conflicting_request_pending !== "boolean" ||
    typeof row.requests_enabled !== "boolean" ||
    typeof row.downloads_enabled !== "boolean" ||
    !positiveInteger(row.artifact_ttl_seconds) ||
    !positiveInteger(row.download_grant_ttl_seconds) ||
    !validTimestamp(row.evaluated_at) ||
    (pendingVersion !== null && !positiveInteger(pendingVersion)) ||
    (pendingRequestId === null) !== (pendingStatus === null) ||
    (pendingRequestId === null) !== (pendingVersion === null)) {
    throw new TypeError("Invalid data export preflight");
  }
  return {
    canRequest: row.can_request,
    pendingRequestId,
    pendingStatus,
    pendingRequestVersion: pendingVersion,
    conflictingRequestPending: row.conflicting_request_pending,
    requestsEnabled: row.requests_enabled,
    downloadsEnabled: row.downloads_enabled,
    artifactTtlSeconds: row.artifact_ttl_seconds,
    downloadGrantTtlSeconds: row.download_grant_ttl_seconds,
    evaluatedAt: row.evaluated_at,
  };
}

function exportRequest(row) {
  exactKeys(row, [
    "artifact_expires_at",
    "artifact_id",
    "artifact_version",
    "available",
    "cancellable",
    "cancelled_at",
    "completed_at",
    "failed_at",
    "failure_code",
    "human_size_bytes",
    "machine_size_bytes",
    "processing_started_at",
    "purged_at",
    "request_id",
    "request_version",
    "requested_at",
    "revoked_at",
    "schema_version",
    "status",
  ]);
  const status = requiredStatus(row.status);
  const optionalTimestamps = [
    row.processing_started_at,
    row.completed_at,
    row.failed_at,
    row.cancelled_at,
    row.artifact_expires_at,
    row.revoked_at,
    row.purged_at,
  ];
  if (!validTimestamp(row.requested_at) ||
    optionalTimestamps.some((value) => value !== null && !validTimestamp(value)) ||
    (row.failure_code !== null && typeof row.failure_code !== "string") ||
    typeof row.cancellable !== "boolean" || typeof row.available !== "boolean" ||
    !positiveInteger(row.request_version) || !positiveInteger(row.artifact_version) ||
    row.schema_version !== dataExportContractVersion ||
    !optionalPositiveInteger(row.machine_size_bytes) ||
    !optionalPositiveInteger(row.human_size_bytes)) {
    throw new TypeError("Invalid data export request");
  }
  return {
    id: requiredUuid(row.request_id),
    status,
    requestedAt: row.requested_at,
    processingStartedAt: row.processing_started_at,
    completedAt: row.completed_at,
    failedAt: row.failed_at,
    cancelledAt: row.cancelled_at,
    failureCode: row.failure_code,
    cancellable: row.cancellable,
    version: row.request_version,
    artifact: {
      id: requiredUuid(row.artifact_id),
      version: row.artifact_version,
      schemaVersion: row.schema_version,
      expiresAt: row.artifact_expires_at,
      revokedAt: row.revoked_at,
      purgedAt: row.purged_at,
      machineSizeBytes: row.machine_size_bytes,
      humanSizeBytes: row.human_size_bytes,
      available: row.available,
    },
  };
}

function downloadGrant(row) {
  exactKeys(row, ["expires_at", "export_format", "grant_id"]);
  if (!["json", "text"].includes(row.export_format) || !validTimestamp(row.expires_at)) {
    throw new TypeError("Invalid data export grant");
  }
  requiredUuid(row.grant_id);
  return row;
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
  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > maximumBodyBytes) return null;
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function secureRandomTokenBytes() {
  return crypto.getRandomValues(new Uint8Array(32));
}

function safeDownloadBaseUrl(value) {
  const url = new URL(value);
  const loopbackHttp = url.protocol === "http:" &&
    ["127.0.0.1", "localhost"].includes(url.hostname);
  if (!(url.protocol === "https:" || loopbackHttp) ||
    url.username || url.password || url.hash) {
    throw new TypeError("Invalid data export download URL");
  }
  url.search = "";
  return url.toString();
}

function base64(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function base64Url(bytes) {
  return base64(bytes).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

function optionalUuid(value) {
  return value === null ? null : requiredUuid(value);
}

function requiredUuid(value) {
  if (typeof value !== "string" || !uuidPattern.test(value)) {
    throw new TypeError("Invalid UUID");
  }
  return value.toLowerCase();
}

function optionalStatus(value) {
  return value === null ? null : requiredStatus(value);
}

function requiredStatus(value) {
  if (!["queued", "verifying", "processing", "completed", "failed", "cancelled"].includes(value)) {
    throw new TypeError("Invalid status");
  }
  return value;
}

function optionalPositiveInteger(value) {
  return value === null || positiveInteger(value);
}

function validTimestamp(value) {
  return typeof value === "string" && Number.isFinite(Date.parse(value));
}

function positiveInteger(value) {
  return Number.isSafeInteger(value) && value > 0;
}

function validIdempotencyKey(value) {
  return value.length >= 16 && value.length <= 200 && !/[\u0000-\u001f\u007f]/.test(value);
}

function sameKeys(actual, expected) {
  const sorted = [...expected].sort();
  return actual.length === sorted.length && actual.every((key, index) => key === sorted[index]);
}

function exactKeys(value, expected) {
  if (!isPlainObject(value) || !sameKeys(Object.keys(value).sort(), expected)) {
    throw new TypeError("Unexpected data export fields");
  }
}

function isJsonContentType(value) {
  return typeof value === "string" && /^application\/json(?:\s*;|$)/i.test(value);
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function singleRow(payload) {
  if (!Array.isArray(payload) || payload.length !== 1 || !isPlainObject(payload[0])) {
    throw new TypeError("Invalid data export RPC payload");
  }
  return payload[0];
}
