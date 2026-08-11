import {
  runtimePolicyClientHeadersFor,
  runtimePolicyCorsAllowHeaders,
} from "./runtime_policy_headers.mjs";

export const notificationEndpointContractVersion = "2026-08-09-wp08-04b";

const maximumBodyBytes = 16 * 1024;
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const providerTokenPattern = /^[\x21-\x7e]{20,4096}$/;
const revocationSecretPattern = /^[A-Za-z0-9_-]{43}$/;
const localePattern = /^[A-Za-z]{2,3}(?:[_-][A-Za-z0-9]{2,8})*$/;

const registrationKeys = Object.freeze([
  "appVersion",
  "expectedVersion",
  "householdId",
  "installationId",
  "locale",
  "permissionState",
  "platform",
  "revocationSecret",
  "runtimeVersion",
  "timezone",
  "token",
]);
const requiredRegistrationKeys = Object.freeze(
  registrationKeys.filter((key) => key !== "locale"),
);
const revocationKeys = Object.freeze([
  "channel",
  "installationId",
  "registrationId",
  "revocationSecret",
]);
const endpointRowKeys = Object.freeze([
  "app_version",
  "channel",
  "endpoint_id",
  "household_id",
  "installation_id",
  "last_registration_id",
  "last_seen_at",
  "locale",
  "member_id",
  "permission_state",
  "platform",
  "revocation_reason",
  "revoked_at",
  "runtime_version",
  "timezone",
  "version",
]);

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
  PERMISSION_DENIED: [403, false, "errors.permissionDenied"],
  RUNTIME_POLICY_UNAVAILABLE: [503, true, "errors.runtimePolicyUnavailable"],
  TEMPORARILY_UNAVAILABLE: [503, true, "errors.temporarilyUnavailable"],
  VALIDATION_FAILED: [400, false, "errors.validationFailed"],
  VERSION_CONFLICT: [409, false, "errors.versionConflict"],
});

const sqlStateErrors = Object.freeze({
  KND01: "VALIDATION_FAILED",
  KND03: "NOT_FOUND_OR_FORBIDDEN",
  KND04: "IDEMPOTENCY_KEY_REUSED",
  KND06: "VERSION_CONFLICT",
  KFR01: "CLIENT_UPDATE_REQUIRED",
  KFR02: "CLIENT_MUTATIONS_DISABLED",
  KFR03: "RUNTIME_POLICY_UNAVAILABLE",
  KFR06: "CLIENT_FEATURE_DISABLED",
});

export class NotificationEndpointRpcError extends Error {
  constructor(code) {
    super("Notification endpoint RPC failed");
    this.name = "NotificationEndpointRpcError";
    this.code = typeof code === "string" ? code : "";
  }
}

export function createNotificationEndpointHandler({
  allowedOrigins,
  authenticate,
  clock = () => new Date().toISOString(),
  invokeRpc,
  sealToken,
  sha256Base64,
}) {
  if (!Array.isArray(allowedOrigins) ||
    typeof authenticate !== "function" ||
    typeof clock !== "function" ||
    typeof invokeRpc !== "function" ||
    typeof sealToken !== "function" ||
    typeof sha256Base64 !== "function") {
    throw new TypeError("Invalid notification endpoint handler configuration");
  }
  const origins = new Set(allowedOrigins);

  return async function handleNotificationEndpointRequest(request) {
    if (!(request instanceof Request)) {
      return Response.json(
        {error: {
          code: "VALIDATION_FAILED",
          messageKey: "errors.validationFailed",
          requestId: crypto.randomUUID(),
          retryable: false,
        }},
        {status: 400},
      );
    }
    const requestId = requestIdFor(request);
    const origin = request.headers.get("origin");
    const headers = responseHeaders(requestId, origin, origins);

    if (origin !== null && !origins.has(origin)) {
      return errorResponse("PERMISSION_DENIED", requestId, headers);
    }
    if (request.method === "OPTIONS") {
      return new Response(null, {status: 204, headers});
    }
    if (!["POST", "DELETE"].includes(request.method)) {
      return errorResponse("METHOD_NOT_ALLOWED", requestId, headers);
    }
    if (new URL(request.url).search.length > 0 ||
      !isJsonContentType(request.headers.get("content-type"))) {
      return errorResponse("VALIDATION_FAILED", requestId, headers);
    }

    const body = await parseBody(request);
    if (body === null) {
      return errorResponse("VALIDATION_FAILED", requestId, headers);
    }

    try {
      const runtimePolicyHeaders = runtimePolicyClientHeadersFor(request);
      const asOf = clock();
      if (!isUtcTimestamp(asOf)) {
        throw new TypeError("Invalid endpoint clock");
      }
      if (request.method === "DELETE") {
        const context = validatedRevocationContext(body);
        if (context === null) {
          return errorResponse("VALIDATION_FAILED", requestId, headers);
        }
        const secretHash = await sha256Base64(context.revocationSecret);
        const result = await invokeRpc(
          "revoke_notification_endpoint_by_secret",
          {
            p_as_of: asOf,
            p_channel: context.channel,
            p_installation_id: context.installationId,
            p_registration_id: context.registrationId,
            p_revocation_secret_hash_base64: requiredDigest(secretHash),
          },
          runtimePolicyHeaders,
        );
        if (!Number.isInteger(result) || result < 0 || result > 1) {
          throw new TypeError("Invalid revocation response");
        }
        return jsonResponse(200, {
          data: {revoked: true},
          meta: {requestId, contractVersion: notificationEndpointContractVersion},
        }, headers);
      }

      const authorization = request.headers.get("authorization") ?? "";
      const identity = await authenticate(authorization);
      if (identity === null || !uuidPattern.test(identity.userId ?? "")) {
        return errorResponse("AUTH_REQUIRED", requestId, headers);
      }
      const registrationId = request.headers.get("idempotency-key")?.trim() ?? "";
      if (!uuidPattern.test(registrationId)) {
        return errorResponse("IDEMPOTENCY_KEY_REQUIRED", requestId, headers);
      }
      const context = validatedRegistrationContext(body);
      if (context === null) {
        return errorResponse("VALIDATION_FAILED", requestId, headers);
      }

      const [sealed, tokenFingerprint, secretHash] = await Promise.all([
        sealToken(context.token),
        sha256Base64(context.token),
        sha256Base64(context.revocationSecret),
      ]);
      if (!isPlainObject(sealed) ||
        typeof sealed.ciphertextBase64 !== "string" ||
        !positiveInteger(sealed.keyVersion)) {
        throw new TypeError("Invalid token sealer response");
      }
      const row = singleEndpointRow(await invokeRpc(
        "upsert_notification_endpoint",
        {
          p_app_version: context.appVersion,
          p_as_of: asOf,
          p_authenticated_user_id: identity.userId.toLowerCase(),
          p_channel: "native_push",
          p_expected_version: context.expectedVersion,
          p_household_id: context.householdId,
          p_installation_id: context.installationId,
          p_locale: context.locale,
          p_permission_state: context.permissionState,
          p_platform: context.platform,
          p_registration_id: registrationId.toLowerCase(),
          p_revocation_secret_hash_base64: requiredDigest(secretHash),
          p_runtime_version: context.runtimeVersion,
          p_timezone: context.timezone,
          p_token_ciphertext_base64: requiredBase64(sealed.ciphertextBase64, 29, 8192),
          p_token_fingerprint_base64: requiredDigest(tokenFingerprint),
          p_token_key_version: sealed.keyVersion,
        },
        runtimePolicyHeaders,
      ));
      return jsonResponse(200, {
        data: endpointData(row),
        meta: {requestId, contractVersion: notificationEndpointContractVersion},
      }, headers);
    } catch (error) {
      const code = error instanceof NotificationEndpointRpcError
        ? sqlStateErrors[error.code] ?? "TEMPORARILY_UNAVAILABLE"
        : "TEMPORARILY_UNAVAILABLE";
      return errorResponse(code, requestId, headers);
    }
  };
}

function validatedRegistrationContext(body) {
  const keys = Object.keys(body).sort();
  if (!sameAllowedAndRequiredKeys(keys, registrationKeys, requiredRegistrationKeys) ||
    !uuidPattern.test(body.householdId ?? "") ||
    !uuidPattern.test(body.installationId ?? "") ||
    !["ios", "android"].includes(body.platform) ||
    body.permissionState !== "granted" ||
    typeof body.token !== "string" ||
    !providerTokenPattern.test(body.token) ||
    typeof body.revocationSecret !== "string" ||
    !revocationSecretPattern.test(body.revocationSecret) ||
    !nonControlText(body.timezone, 1, 100) ||
    !nonControlText(body.appVersion, 1, 64) ||
    !nonControlText(body.runtimeVersion, 1, 64) ||
    !Number.isSafeInteger(body.expectedVersion) ||
    body.expectedVersion < 0 ||
    body.locale !== undefined && (
      typeof body.locale !== "string" ||
      !localePattern.test(body.locale)
    )) {
    return null;
  }
  return {
    appVersion: body.appVersion,
    expectedVersion: body.expectedVersion,
    householdId: body.householdId.toLowerCase(),
    installationId: body.installationId.toLowerCase(),
    locale: body.locale ?? null,
    permissionState: body.permissionState,
    platform: body.platform,
    revocationSecret: body.revocationSecret,
    runtimeVersion: body.runtimeVersion,
    timezone: body.timezone,
    token: body.token,
  };
}

function validatedRevocationContext(body) {
  const keys = Object.keys(body).sort();
  if (!sameKeys(keys, revocationKeys) ||
    !uuidPattern.test(body.installationId ?? "") ||
    body.channel !== "native_push" ||
    !uuidPattern.test(body.registrationId ?? "") ||
    typeof body.revocationSecret !== "string" ||
    !revocationSecretPattern.test(body.revocationSecret)) {
    return null;
  }
  return {
    channel: body.channel,
    installationId: body.installationId.toLowerCase(),
    registrationId: body.registrationId.toLowerCase(),
    revocationSecret: body.revocationSecret,
  };
}

function endpointData(row) {
  return {
    appVersion: requiredText(row.app_version, 1, 64),
    channel: requiredEnum(row.channel, ["native_push"]),
    endpointId: requiredUuid(row.endpoint_id),
    householdId: requiredUuid(row.household_id),
    installationId: requiredUuid(row.installation_id),
    lastRegistrationId: requiredUuid(row.last_registration_id),
    lastSeenAt: requiredTimestamp(row.last_seen_at),
    locale: optionalLocale(row.locale),
    memberId: requiredUuid(row.member_id),
    permissionState: requiredEnum(row.permission_state, ["granted"]),
    platform: requiredEnum(row.platform, ["ios", "android"]),
    revocationReason: optionalEnum(row.revocation_reason, [
      "client_revoked",
      "token_reassigned",
      "provider_unregistered",
      "provider_invalid_argument",
      "membership_removed",
      "permission_revoked",
      "rollback_disabled",
    ]),
    revokedAt: optionalTimestamp(row.revoked_at),
    runtimeVersion: requiredText(row.runtime_version, 1, 64),
    timezone: requiredText(row.timezone, 1, 100),
    version: requiredPositiveInteger(row.version),
  };
}

function singleEndpointRow(payload) {
  if (!Array.isArray(payload) || payload.length !== 1 || !isPlainObject(payload[0]) ||
    !sameKeys(Object.keys(payload[0]).sort(), endpointRowKeys)) {
    throw new TypeError("Invalid endpoint response");
  }
  return payload[0];
}

function errorResponse(code, requestId, headers) {
  const [status, retryable, messageKey] = errorCatalog[code] ?? errorCatalog.INTERNAL_ERROR;
  return jsonResponse(status, {
    error: {code, messageKey, retryable, requestId},
  }, headers);
}

function jsonResponse(status, payload, headers) {
  return new Response(JSON.stringify(payload), {status, headers});
}

function responseHeaders(requestId, origin, allowedOrigins) {
  const headers = new Headers({
    "access-control-allow-headers":
      `authorization, content-type, idempotency-key, x-request-id, ${runtimePolicyCorsAllowHeaders}`,
    "access-control-allow-methods": "POST, DELETE, OPTIONS",
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
    const value = JSON.parse(text);
    return isPlainObject(value) ? value : null;
  } catch {
    return null;
  }
}

function requiredDigest(value) {
  return requiredBase64(value, 32, 32);
}

function requiredBase64(value, minimumBytes, maximumBytes) {
  if (typeof value !== "string" ||
    !/^[A-Za-z0-9+/]+={0,2}$/.test(value) ||
    value.length > Math.ceil(maximumBytes / 3) * 4 + 4) {
    throw new TypeError("Invalid base64 material");
  }
  let bytes;
  try {
    bytes = Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
  } catch {
    throw new TypeError("Invalid base64 material");
  }
  if (bytes.byteLength < minimumBytes || bytes.byteLength > maximumBytes ||
    encodeBase64(bytes) !== value) {
    throw new TypeError("Invalid base64 material");
  }
  return value;
}

function encodeBase64(bytes) {
  let binary = "";
  for (const value of bytes) binary += String.fromCharCode(value);
  return btoa(binary);
}

function requiredUuid(value) {
  if (typeof value !== "string" || !uuidPattern.test(value)) {
    throw new TypeError("Invalid UUID response");
  }
  return value.toLowerCase();
}

function requiredText(value, minimum, maximum) {
  if (!nonControlText(value, minimum, maximum)) {
    throw new TypeError("Invalid text response");
  }
  return value;
}

function optionalLocale(value) {
  if (value === null) return null;
  if (typeof value !== "string" || !localePattern.test(value)) {
    throw new TypeError("Invalid locale response");
  }
  return value;
}

function requiredEnum(value, values) {
  if (!values.includes(value)) throw new TypeError("Invalid enum response");
  return value;
}

function optionalEnum(value, values) {
  if (value === null) return null;
  return requiredEnum(value, values);
}

function requiredTimestamp(value) {
  if (typeof value !== "string" || !Number.isFinite(Date.parse(value))) {
    throw new TypeError("Invalid timestamp response");
  }
  return value;
}

function optionalTimestamp(value) {
  return value === null ? null : requiredTimestamp(value);
}

function requiredPositiveInteger(value) {
  if (!positiveInteger(value)) throw new TypeError("Invalid integer response");
  return value;
}

function nonControlText(value, minimum, maximum) {
  return typeof value === "string" &&
    value.length >= minimum &&
    value.length <= maximum &&
    value === value.trim() &&
    !/[\u0000-\u001f\u007f]/.test(value);
}

function positiveInteger(value) {
  return Number.isSafeInteger(value) && value > 0;
}

function sameAllowedAndRequiredKeys(actual, allowed, required) {
  return actual.every((key) => allowed.includes(key)) &&
    required.every((key) => actual.includes(key));
}

function sameKeys(actual, expected) {
  return actual.length === expected.length &&
    actual.every((key, index) => key === expected[index]);
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isJsonContentType(value) {
  return typeof value === "string" && /^application\/json(?:\s*;|$)/i.test(value);
}

function isUtcTimestamp(value) {
  return typeof value === "string" &&
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$/.test(value) &&
    Number.isFinite(Date.parse(value));
}
