export const billingWebhookContractVersion = "2026-08-08-wp06-04";

const maximumBodyBytes = 256 * 1024;
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const digestBase64Pattern = /^[A-Za-z0-9+/]{43}=$/;
const eventTypePattern = /^[A-Z][A-Z0-9_]{0,79}$/;
const signatureHexPattern = /^[0-9a-f]{64}$/;
const signatureTimestampPattern = /^[0-9]{10,12}$/;

const ignoredEventTypes = new Set([
  "EXPERIMENT_ENROLLMENT",
  "INVOICE_ISSUANCE",
  "TEST",
  "VIRTUAL_CURRENCY_TRANSACTION",
  "PRICE_INCREASE_CONSENT_APPROVED",
  "PRICE_INCREASE_CONSENT_REQUIRED",
]);
const manualReviewEventTypes = new Set([
  "PURCHASE_REDEEMED",
  "SUBSCRIBER_ALIAS",
  "TRANSFER",
]);
const enqueueRowKeys = Object.freeze([
  "delivery_count",
  "duplicate",
  "job_id",
  "processing_status",
]);

const errorCatalog = Object.freeze({
  AUTHENTICATION_FAILED: [401, false],
  BODY_TOO_LARGE: [413, false],
  EVENT_ID_COLLISION: [409, false],
  METHOD_NOT_ALLOWED: [405, false],
  TEMPORARILY_UNAVAILABLE: [503, true],
  VALIDATION_FAILED: [400, false],
});

export class BillingWebhookRpcError extends Error {
  constructor(code) {
    super("Billing webhook RPC failed");
    this.name = "BillingWebhookRpcError";
    this.code = typeof code === "string" ? code : "";
  }
}

export function createRevenueCatWebhookHandler({
  authorize,
  clock = () => new Date().toISOString(),
  enqueue,
  sha256Base64 = digestSha256Base64,
  verifySignature,
}) {
  if (typeof authorize !== "function" ||
    typeof clock !== "function" ||
    typeof enqueue !== "function" ||
    typeof sha256Base64 !== "function" ||
    typeof verifySignature !== "function") {
    throw new TypeError("Invalid billing webhook handler configuration");
  }

  return async function handleRevenueCatWebhook(request) {
    if (!(request instanceof Request)) {
      return errorResponse("VALIDATION_FAILED", crypto.randomUUID());
    }
    const requestId = requestIdFor(request);
    if (request.method !== "POST") {
      const response = errorResponse("METHOD_NOT_ALLOWED", requestId);
      response.headers.set("allow", "POST");
      return response;
    }
    const url = new URL(request.url);
    if (url.search.length > 0 ||
      !isJsonContentType(request.headers.get("content-type"))) {
      return errorResponse("VALIDATION_FAILED", requestId);
    }

    const declaredLength = declaredBodyLength(request.headers.get("content-length"));
    if (declaredLength === null) {
      return errorResponse("VALIDATION_FAILED", requestId);
    }
    if (declaredLength > maximumBodyBytes) {
      return errorResponse("BODY_TOO_LARGE", requestId);
    }

    const rawBody = await readBoundedBody(request);
    if (rawBody === null) {
      return errorResponse("BODY_TOO_LARGE", requestId);
    }

    const asOf = clock();
    if (!isUtcTimestamp(asOf)) {
      return errorResponse("TEMPORARILY_UNAVAILABLE", requestId);
    }
    let authenticated = false;
    try {
      const [authorizationAccepted, signatureAccepted] = await Promise.all([
        authorize(request.headers.get("authorization") ?? ""),
        verifySignature(
          rawBody,
          request.headers.get("x-revenuecat-webhook-signature") ?? "",
          asOf,
        ),
      ]);
      authenticated = authorizationAccepted === true && signatureAccepted === true;
    } catch {
      authenticated = false;
    }
    if (!authenticated) {
      return errorResponse("AUTHENTICATION_FAILED", requestId);
    }

    const body = parseJsonBody(rawBody);
    const context = validatedWebhookContext(body, asOf);
    if (context === null) {
      return errorResponse("VALIDATION_FAILED", requestId);
    }

    try {
      const requestHash = await sha256Base64(rawBody);
      if (!digestBase64Pattern.test(requestHash)) {
        throw new TypeError("Invalid webhook digest");
      }
      const row = singleEnqueueRow(await enqueue({
        p_api_version: context.apiVersion,
        p_auth_user_id: context.authUserId,
        p_correlation_id: requestId,
        p_environment: context.environment,
        p_event_type: context.eventType,
        p_provider_event_id: context.eventId,
        p_provider_occurred_at: context.providerOccurredAt,
        p_received_at: asOf,
        p_request_hash_base64: requestHash,
        p_routing_action: context.routingAction,
      }));
      const disposition = row.duplicate
        ? "duplicate"
        : dispositionFor(row.processing_status);
      return jsonResponse(200, {
        data: {
          accepted: true,
          disposition,
          duplicate: row.duplicate,
        },
        meta: {contractVersion: billingWebhookContractVersion, requestId},
      });
    } catch (error) {
      const code = error instanceof BillingWebhookRpcError && error.code === "KFB40"
        ? "EVENT_ID_COLLISION"
        : "TEMPORARILY_UNAVAILABLE";
      return errorResponse(code, requestId);
    }
  };
}

export function createExactAuthorizationVerifier(expectedAuthorization) {
  if (!boundedVisibleText(expectedAuthorization, 32, 512)) {
    throw new TypeError("Invalid RevenueCat webhook authorization configuration");
  }
  const expectedDigest = digestSha256(new TextEncoder().encode(expectedAuthorization));
  return async function authorize(candidate) {
    if (typeof candidate !== "string" || candidate.length > 2048) return false;
    return constantTimeEqual(
      await expectedDigest,
      await digestSha256(new TextEncoder().encode(candidate)),
    );
  };
}

export function createRevenueCatSignatureVerifier({
  secret,
  toleranceSeconds = 300,
}) {
  if (!boundedVisibleText(secret, 32, 512) ||
    !Number.isSafeInteger(toleranceSeconds) ||
    toleranceSeconds < 60 ||
    toleranceSeconds > 900) {
    throw new TypeError("Invalid RevenueCat webhook signing configuration");
  }
  const keyPromise = crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    {hash: "SHA-256", name: "HMAC"},
    false,
    ["verify"],
  );

  return async function verifySignature(rawBody, header, asOf) {
    if (!(rawBody instanceof Uint8Array) || rawBody.byteLength > maximumBodyBytes ||
      typeof header !== "string" || !isUtcTimestamp(asOf)) {
      return false;
    }
    const parts = signatureParts(header);
    if (parts === null) return false;
    const nowSeconds = Math.floor(Date.parse(asOf) / 1000);
    const signatureSeconds = Number(parts.timestamp);
    if (!Number.isSafeInteger(signatureSeconds) ||
      Math.abs(nowSeconds - signatureSeconds) > toleranceSeconds) {
      return false;
    }
    const prefix = new TextEncoder().encode(`${parts.timestamp}.`);
    const signedBody = new Uint8Array(prefix.byteLength + rawBody.byteLength);
    signedBody.set(prefix);
    signedBody.set(rawBody, prefix.byteLength);
    return crypto.subtle.verify(
      "HMAC",
      await keyPromise,
      decodeHex(parts.signature),
      signedBody,
    );
  };
}

export async function digestSha256Base64(bytes) {
  if (!(bytes instanceof Uint8Array)) {
    throw new TypeError("Invalid billing webhook digest input");
  }
  return encodeBase64(new Uint8Array(await digestSha256(bytes)));
}

function validatedWebhookContext(body, asOf) {
  if (!isPlainObject(body) || !isPlainObject(body.event) ||
    !boundedNonControlText(body.api_version, 1, 32)) {
    return null;
  }
  const event = body.event;
  if (!boundedNonControlText(event.id, 1, 255) ||
    typeof event.type !== "string" || !eventTypePattern.test(event.type) ||
    !Number.isSafeInteger(event.event_timestamp_ms) ||
    event.event_timestamp_ms < Date.UTC(2000, 0, 1) ||
    event.event_timestamp_ms > Date.parse(asOf) + 24 * 60 * 60 * 1000) {
    return null;
  }
  const environment = event.environment === "SANDBOX"
    ? "sandbox"
    : event.environment === "PRODUCTION"
    ? "production"
    : null;
  const authUserId = typeof event.app_user_id === "string" &&
      uuidPattern.test(event.app_user_id)
    ? event.app_user_id.toLowerCase()
    : null;
  let routingAction = "reconcile";
  if (ignoredEventTypes.has(event.type) || event.type.startsWith("PAYWALL_")) {
    routingAction = "ignore";
  } else if (manualReviewEventTypes.has(event.type) ||
    authUserId === null || environment === null) {
    routingAction = "manual_review";
  }
  return Object.freeze({
    apiVersion: body.api_version,
    authUserId,
    environment,
    eventId: event.id,
    eventType: event.type,
    providerOccurredAt: new Date(event.event_timestamp_ms).toISOString(),
    routingAction,
  });
}

function singleEnqueueRow(payload) {
  if (!Array.isArray(payload) || payload.length !== 1 ||
    !isPlainObject(payload[0]) ||
    !sameKeys(Object.keys(payload[0]).sort(), enqueueRowKeys) ||
    !uuidPattern.test(payload[0].job_id ?? "") ||
    !["queued", "leased", "retry_wait", "succeeded", "ignored", "dead_letter"]
      .includes(payload[0].processing_status) ||
    typeof payload[0].duplicate !== "boolean" ||
    !Number.isSafeInteger(payload[0].delivery_count) ||
    payload[0].delivery_count < 1) {
    throw new TypeError("Invalid billing webhook enqueue response");
  }
  return payload[0];
}

function dispositionFor(status) {
  return status === "ignored"
    ? "ignored"
    : status === "dead_letter"
    ? "manualReview"
    : "queued";
}

function signatureParts(header) {
  if (typeof header !== "string" || header.length > 256) return null;
  const values = new Map();
  for (const part of header.split(",")) {
    const separator = part.indexOf("=");
    if (separator < 1) return null;
    const key = part.slice(0, separator).trim();
    const value = part.slice(separator + 1).trim();
    if (!new Set(["t", "v1"]).has(key) || values.has(key)) return null;
    values.set(key, value);
  }
  if (values.size !== 2 ||
    !signatureTimestampPattern.test(values.get("t") ?? "") ||
    !signatureHexPattern.test(values.get("v1") ?? "")) {
    return null;
  }
  return {signature: values.get("v1"), timestamp: values.get("t")};
}

async function readBoundedBody(request) {
  try {
    const bytes = new Uint8Array(await request.arrayBuffer());
    return bytes.byteLength <= maximumBodyBytes ? bytes : null;
  } catch {
    return null;
  }
}

function parseJsonBody(bytes) {
  try {
    const text = new TextDecoder("utf-8", {fatal: true}).decode(bytes);
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function declaredBodyLength(value) {
  if (value === null) return 0;
  if (!/^[0-9]{1,10}$/.test(value)) return null;
  const length = Number(value);
  return Number.isSafeInteger(length) ? length : null;
}

function errorResponse(code, requestId) {
  const [status, retryable] = errorCatalog[code] ?? errorCatalog.TEMPORARILY_UNAVAILABLE;
  return jsonResponse(status, {
    error: {code, requestId, retryable},
  });
}

function jsonResponse(status, payload) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: responseHeaders(payload?.meta?.requestId ?? payload?.error?.requestId),
  });
}

function responseHeaders(requestId) {
  return new Headers({
    "cache-control": "no-store",
    "content-type": "application/json; charset=utf-8",
    "referrer-policy": "no-referrer",
    "x-content-type-options": "nosniff",
    "x-request-id": requestId,
  });
}

function requestIdFor(request) {
  const candidate = request.headers.get("x-request-id")?.trim() ?? "";
  return uuidPattern.test(candidate) ? candidate.toLowerCase() : crypto.randomUUID();
}

function isJsonContentType(value) {
  return typeof value === "string" &&
    /^application\/json(?:\s*;\s*charset=utf-8)?$/i.test(value.trim());
}

function isUtcTimestamp(value) {
  if (typeof value !== "string" || !/(?:Z|[+-]00:00)$/.test(value)) return false;
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) && new Date(parsed).toISOString() === value;
}

function boundedVisibleText(value, minimum, maximum) {
  return typeof value === "string" && value.length >= minimum &&
    value.length <= maximum && value === value.trim() &&
    /^[\x20-\x7e]+$/.test(value);
}

function boundedNonControlText(value, minimum, maximum) {
  return typeof value === "string" && value.length >= minimum &&
    value.length <= maximum && !/[\x00-\x1f\x7f]/.test(value) &&
    value === value.trim();
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function sameKeys(left, right) {
  return left.length === right.length && left.every((key, index) => key === right[index]);
}

function digestSha256(bytes) {
  return crypto.subtle.digest("SHA-256", bytes);
}

function decodeHex(value) {
  const bytes = new Uint8Array(value.length / 2);
  for (let index = 0; index < bytes.length; index += 1) {
    bytes[index] = Number.parseInt(value.slice(index * 2, index * 2 + 2), 16);
  }
  return bytes;
}

function constantTimeEqual(left, right) {
  const leftBytes = new Uint8Array(left);
  const rightBytes = new Uint8Array(right);
  if (leftBytes.byteLength !== rightBytes.byteLength) return false;
  let mismatch = 0;
  for (let index = 0; index < leftBytes.byteLength; index += 1) {
    mismatch |= leftBytes[index] ^ rightBytes[index];
  }
  return mismatch === 0;
}

function encodeBase64(bytes) {
  let binary = "";
  for (const value of bytes) binary += String.fromCharCode(value);
  return btoa(binary);
}
