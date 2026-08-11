export const notificationPushContractVersion = "2026-08-08-wp05-05";
export const notificationPushEnvelopeContractVersion = "2026-08-08-wp05-04";

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const localePattern = /^[A-Za-z]{2,3}(?:[_-][A-Za-z0-9]{2,8})*$/;
const claimKeys = Object.freeze([
  "attempt",
  "category",
  "delivery_id",
  "endpoint_id",
  "expires_at",
  "household_id",
  "inbox_item_id",
  "lease_expires_at",
  "lease_token",
  "locale",
  "max_attempts",
  "scheduled_at",
  "source_event_id",
  "subject_id",
  "subject_type",
  "token_ciphertext_base64",
  "token_fingerprint_base64",
  "token_key_version",
]);
const completionKeys = Object.freeze([
  "attempts",
  "completed_at",
  "delivery_id",
  "endpoint_invalidated",
  "max_attempts",
  "next_attempt_at",
  "processing_status",
  "result_code",
]);
const submissionMarkerKeys = Object.freeze([
  "delivery_id",
  "submission_started_at",
]);
const retryableCodes = new Set([
  "FCM_INTERNAL",
  "FCM_QUOTA_EXCEEDED",
  "FCM_UNKNOWN",
  "FCM_UNAVAILABLE",
]);
const invalidTokenCodes = new Set([
  "FCM_INVALID_ARGUMENT",
  "FCM_UNREGISTERED",
]);
const permanentCodes = new Set([
  "FCM_REQUEST_REJECTED",
  "FCM_SENDER_ID_MISMATCH",
  "FCM_THIRD_PARTY_AUTH_ERROR",
  "TOKEN_DECRYPTION_FAILED",
]);
const ambiguousCodes = new Set(["FCM_SUBMISSION_AMBIGUOUS"]);
const resultCodes = new Set([
  "ATTEMPTS_EXHAUSTED",
  "ENDPOINT_MATERIAL_CHANGED",
  "FCM_ACCEPTED",
  ...retryableCodes,
  ...invalidTokenCodes,
  ...permanentCodes,
  ...ambiguousCodes,
]);

export class NotificationPushContractError extends Error {
  constructor(code) {
    super("Notification push contract failed");
    this.name = "NotificationPushContractError";
    this.code = code;
  }
}

export function createNotificationPushHandler({
  authorizeRequest,
  batchSize = 20,
  clock = () => new Date().toISOString(),
  invokeRpc,
  leaseSeconds = 60,
  openToken,
  randomUuid = () => crypto.randomUUID(),
  sendFcm,
  sha256Base64,
}) {
  if (typeof authorizeRequest !== "function" ||
    typeof clock !== "function" ||
    typeof invokeRpc !== "function" ||
    typeof openToken !== "function" ||
    typeof randomUuid !== "function" ||
    typeof sendFcm !== "function" ||
    typeof sha256Base64 !== "function" ||
    !integerBetween(batchSize, 1, 100) ||
    !integerBetween(leaseSeconds, 5, 300)) {
    throw new NotificationPushContractError("INVALID_HANDLER_CONFIG");
  }

  return async function notificationPushHandler(request) {
    if (!(request instanceof Request)) {
      return errorResponse(400, "INVALID_REQUEST", false);
    }
    if (request.method !== "POST") {
      return errorResponse(405, "METHOD_NOT_ALLOWED", false, {allow: "POST"});
    }
    if (new URL(request.url).search.length > 0 || request.body !== null) {
      return errorResponse(400, "INVALID_REQUEST", false);
    }

    let authorized = false;
    try {
      authorized = await authorizeRequest(
        request.headers.get("authorization") ?? "",
      );
    } catch {
      return errorResponse(503, "PUSH_WORKER_UNAVAILABLE", true);
    }
    if (authorized !== true) {
      return errorResponse(401, "PUSH_WORKER_AUTH_REQUIRED", false);
    }

    try {
      const data = await runNotificationPushBatch({
        asOf: clock(),
        batchSize,
        invokeRpc,
        leaseSeconds,
        openToken,
        sendFcm,
        sha256Base64,
        workerId: randomUuid(),
      });
      return jsonResponse(200, {
        data,
        meta: {contractVersion: notificationPushContractVersion},
      });
    } catch {
      return errorResponse(503, "PUSH_WORKER_UNAVAILABLE", true);
    }
  };
}

export async function runNotificationPushBatch({
  asOf,
  batchSize = 20,
  invokeRpc,
  leaseSeconds = 60,
  openToken,
  sendFcm,
  sha256Base64,
  workerId,
}) {
  if (!isUtcTimestamp(asOf) ||
    !uuidPattern.test(workerId ?? "") ||
    !integerBetween(batchSize, 1, 100) ||
    !integerBetween(leaseSeconds, 5, 300) ||
    typeof invokeRpc !== "function" ||
    typeof openToken !== "function" ||
    typeof sendFcm !== "function" ||
    typeof sha256Base64 !== "function") {
    throw new NotificationPushContractError("INVALID_WORKER_INPUT");
  }

  let claimPayload;
  try {
    claimPayload = await invokeRpc("claim_notification_push_deliveries", {
      p_as_of: asOf,
      p_batch_size: batchSize,
      p_lease_seconds: leaseSeconds,
      p_worker_id: workerId.toLowerCase(),
    });
  } catch {
    throw new NotificationPushContractError("CLAIM_UNAVAILABLE");
  }
  const claims = parseClaims(claimPayload, asOf);
  const summary = {
    acceptedCount: 0,
    ambiguousCount: 0,
    claimedCount: claims.length,
    endpointInvalidatedCount: 0,
    failedCount: 0,
    retryScheduledCount: 0,
    submissionStartedCount: 0,
    unrecordedCompletionCount: 0,
  };

  for (const claim of claims) {
    let token;
    let providerResult;
    let submissionStarted = false;
    const beginSubmission = async () => {
      if (submissionStarted) return;
      let markerPayload;
      try {
        markerPayload = await invokeRpc(
          "mark_notification_push_submission_started",
          {
            p_as_of: asOf,
            p_delivery_id: claim.deliveryId,
            p_lease_token: claim.leaseToken,
            p_token_fingerprint_base64: claim.tokenFingerprintBase64,
          },
        );
      } catch {
        throw new NotificationPushContractError("SUBMISSION_MARK_UNAVAILABLE");
      }
      parseSubmissionMarker(markerPayload, claim);
      submissionStarted = true;
      summary.submissionStartedCount += 1;
    };
    try {
      token = await openToken({
        ciphertextBase64: claim.tokenCiphertextBase64,
        keyVersion: claim.tokenKeyVersion,
      });
      if (typeof token !== "string" ||
        token.length < 20 ||
        token.length > 4096 ||
        !/^[\x21-\x7e]+$/.test(token)) {
        throw new TypeError("Invalid provider token");
      }
    } catch {
      providerResult = {
        outcome: "permanent",
        resultCode: "TOKEN_DECRYPTION_FAILED",
      };
    }
    if (token !== undefined) {
      try {
        providerResult = parseProviderResult(await sendFcm({
          attempt: claim.attempt,
          beginSubmission,
          category: claim.category,
          deliveryId: claim.deliveryId,
          expiresAt: claim.expiresAt,
          householdId: claim.householdId,
          inboxItemId: claim.inboxItemId,
          locale: claim.locale,
          sourceEventId: claim.sourceEventId,
          subjectId: claim.subjectId,
          subjectType: claim.subjectType,
          token,
          ttlSeconds: claim.ttlSeconds,
        }));
        if (!submissionStarted && !(
          providerResult.outcome === "retryable" &&
          providerResult.resultCode === "FCM_UNAVAILABLE"
        )) {
          throw new NotificationPushContractError(
            "PROVIDER_SUBMISSION_NOT_MARKED",
          );
        }
      } catch {
        providerResult = submissionStarted
          ? {
            outcome: "ambiguous",
            resultCode: "FCM_SUBMISSION_AMBIGUOUS",
          }
          : {
            outcome: "retryable",
            resultCode: "FCM_UNAVAILABLE",
            retryAfterSeconds: 60,
          };
      }
    }

    let receiptHash = null;
    if (providerResult.outcome === "accepted") {
      try {
        receiptHash = requiredDigest(
          await sha256Base64(providerResult.receiptName),
        );
      } catch {
        providerResult = {
          outcome: "ambiguous",
          resultCode: "FCM_SUBMISSION_AMBIGUOUS",
        };
      }
    }

    if (providerResult.outcome === "ambiguous") {
      summary.ambiguousCount += 1;
    }

    try {
      const completionPayload = await invokeRpc(
        "complete_notification_push_delivery",
        {
          p_as_of: asOf,
          p_delivery_id: claim.deliveryId,
          p_lease_token: claim.leaseToken,
          p_outcome: providerResult.outcome,
          p_provider_receipt_hash_base64: receiptHash,
          p_result_code: providerResult.resultCode,
          p_retry_after_seconds:
            providerResult.outcome === "retryable"
              ? providerResult.retryAfterSeconds
              : null,
          p_token_fingerprint_base64: claim.tokenFingerprintBase64,
        },
      );
      const completion = parseCompletion(completionPayload, claim);
      if (completion.processingStatus === "succeeded") {
        summary.acceptedCount += 1;
      } else if (completion.processingStatus === "retry_wait") {
        summary.retryScheduledCount += 1;
      } else {
        summary.failedCount += 1;
      }
      if (completion.endpointInvalidated) {
        summary.endpointInvalidatedCount += 1;
      }
    } catch {
      summary.unrecordedCompletionCount += 1;
    }
  }

  return Object.freeze(summary);
}

function parseClaims(value, asOf) {
  if (!Array.isArray(value) || value.length > 100) {
    throw new NotificationPushContractError("INVALID_CLAIM_RESPONSE");
  }
  const asOfMilliseconds = Date.parse(asOf);
  const deliveryIds = new Set();
  return value.map((row) => {
    const scheduledMilliseconds = Date.parse(row.scheduled_at ?? "");
    const expiresMilliseconds = Date.parse(row.expires_at ?? "");
    const validSubject = (
      ["chore_assignment", "chore_due"].includes(row?.category) &&
        row?.subject_type === "chore_occurrence"
    ) || (
      row?.category === "calendar_event" &&
        row?.subject_type === "calendar_occurrence"
    );
    if (!hasExactKeys(row, claimKeys) ||
      !uuidPattern.test(row.delivery_id ?? "") ||
      !uuidPattern.test(row.source_event_id ?? "") ||
      row.inbox_item_id !== null && !uuidPattern.test(row.inbox_item_id ?? "") ||
      !uuidPattern.test(row.endpoint_id ?? "") ||
      !uuidPattern.test(row.household_id ?? "") ||
      !validSubject ||
      !uuidPattern.test(row.subject_id ?? "") ||
      !canonicalBase64(row.token_ciphertext_base64, 29, 8192) ||
      !canonicalBase64(row.token_fingerprint_base64, 32, 32) ||
      !integerBetween(row.token_key_version, 1, 1000000) ||
      row.locale !== null && !localePattern.test(row.locale ?? "") ||
      !integerBetween(row.attempt, 1, 5) ||
      !integerBetween(row.max_attempts, row.attempt, 5) ||
      !uuidPattern.test(row.lease_token ?? "") ||
      !isUtcTimestamp(row.lease_expires_at) ||
      !isUtcTimestamp(row.scheduled_at) ||
      !isUtcTimestamp(row.expires_at) ||
      scheduledMilliseconds > asOfMilliseconds ||
      expiresMilliseconds <= asOfMilliseconds ||
      expiresMilliseconds - scheduledMilliseconds !== 3600000 ||
      deliveryIds.has(row.delivery_id.toLowerCase())) {
      throw new NotificationPushContractError("INVALID_CLAIM_RESPONSE");
    }
    deliveryIds.add(row.delivery_id.toLowerCase());
    return Object.freeze({
      attempt: row.attempt,
      category: row.category,
      deliveryId: row.delivery_id.toLowerCase(),
      expiresAt: row.expires_at,
      householdId: row.household_id.toLowerCase(),
      inboxItemId: row.inbox_item_id?.toLowerCase() ?? null,
      leaseToken: row.lease_token.toLowerCase(),
      locale: row.locale,
      maxAttempts: row.max_attempts,
      scheduledAt: row.scheduled_at,
      sourceEventId: row.source_event_id.toLowerCase(),
      subjectId: row.subject_id.toLowerCase(),
      subjectType: row.subject_type,
      tokenCiphertextBase64: row.token_ciphertext_base64,
      tokenFingerprintBase64: row.token_fingerprint_base64,
      tokenKeyVersion: row.token_key_version,
      ttlSeconds: Math.max(
        1,
        Math.min(
          3600,
          Math.floor((expiresMilliseconds - asOfMilliseconds) / 1000),
        ),
      ),
    });
  });
}

function parseSubmissionMarker(value, claim) {
  if (!Array.isArray(value) || value.length !== 1 ||
    !hasExactKeys(value[0], submissionMarkerKeys) ||
    value[0].delivery_id?.toLowerCase() !== claim.deliveryId ||
    !isUtcTimestamp(value[0].submission_started_at)) {
    throw new NotificationPushContractError("INVALID_SUBMISSION_MARK_RESPONSE");
  }
}

function parseProviderResult(value) {
  if (!isPlainObject(value) || typeof value.outcome !== "string" ||
    typeof value.resultCode !== "string") {
    throw new NotificationPushContractError("INVALID_PROVIDER_RESULT");
  }
  if (value.outcome === "accepted") {
    if (!hasExactKeys(value, ["outcome", "receiptName", "resultCode"]) ||
      value.resultCode !== "FCM_ACCEPTED" ||
      typeof value.receiptName !== "string" ||
      !/^projects\/[A-Za-z0-9._~-]{1,128}\/messages\/[A-Za-z0-9%:._~-]{1,512}$/.test(
        value.receiptName,
      )) {
      throw new NotificationPushContractError("INVALID_PROVIDER_RESULT");
    }
  } else if (value.outcome === "retryable") {
    if (!hasExactKeys(value, ["outcome", "resultCode", "retryAfterSeconds"]) ||
      !retryableCodes.has(value.resultCode) ||
      !integerBetween(value.retryAfterSeconds, 5, 3600)) {
      throw new NotificationPushContractError("INVALID_PROVIDER_RESULT");
    }
  } else if (value.outcome === "invalid_token") {
    if (!hasExactKeys(value, ["outcome", "resultCode"]) ||
      !invalidTokenCodes.has(value.resultCode)) {
      throw new NotificationPushContractError("INVALID_PROVIDER_RESULT");
    }
  } else if (value.outcome === "permanent") {
    if (!hasExactKeys(value, ["outcome", "resultCode"]) ||
      !permanentCodes.has(value.resultCode)) {
      throw new NotificationPushContractError("INVALID_PROVIDER_RESULT");
    }
  } else if (value.outcome === "ambiguous") {
    if (!hasExactKeys(value, ["outcome", "resultCode"]) ||
      !ambiguousCodes.has(value.resultCode)) {
      throw new NotificationPushContractError("INVALID_PROVIDER_RESULT");
    }
  } else {
    throw new NotificationPushContractError("INVALID_PROVIDER_RESULT");
  }
  return value;
}

function parseCompletion(value, claim) {
  if (!Array.isArray(value) || value.length !== 1 ||
    !hasExactKeys(value[0], completionKeys)) {
    throw new NotificationPushContractError("INVALID_COMPLETION_RESPONSE");
  }
  const row = value[0];
  if (row.delivery_id?.toLowerCase() !== claim.deliveryId ||
    !["failed", "retry_wait", "succeeded"].includes(row.processing_status) ||
    !integerBetween(row.attempts, claim.attempt, 5) ||
    row.attempts !== claim.attempt ||
    row.max_attempts !== claim.maxAttempts ||
    !resultCodes.has(row.result_code) ||
    typeof row.endpoint_invalidated !== "boolean") {
    throw new NotificationPushContractError("INVALID_COMPLETION_RESPONSE");
  }
  if (row.processing_status === "retry_wait") {
    if (!isUtcTimestamp(row.next_attempt_at) || row.completed_at !== null) {
      throw new NotificationPushContractError("INVALID_COMPLETION_RESPONSE");
    }
  } else if (row.next_attempt_at !== null || !isUtcTimestamp(row.completed_at)) {
    throw new NotificationPushContractError("INVALID_COMPLETION_RESPONSE");
  }
  if (row.endpoint_invalidated && row.processing_status !== "failed") {
    throw new NotificationPushContractError("INVALID_COMPLETION_RESPONSE");
  }
  return {
    endpointInvalidated: row.endpoint_invalidated,
    processingStatus: row.processing_status,
  };
}

function requiredDigest(value) {
  if (!canonicalBase64(value, 32, 32)) {
    throw new NotificationPushContractError("INVALID_RECEIPT_DIGEST");
  }
  return value;
}

function canonicalBase64(value, minimumBytes, maximumBytes) {
  if (typeof value !== "string" ||
    !/^[A-Za-z0-9+/]+={0,2}$/.test(value) ||
    value.length > Math.ceil(maximumBytes / 3) * 4 + 4) {
    return false;
  }
  let bytes;
  try {
    bytes = Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
  } catch {
    return false;
  }
  return bytes.byteLength >= minimumBytes &&
    bytes.byteLength <= maximumBytes &&
    encodeBase64(bytes) === value;
}

function encodeBase64(bytes) {
  let binary = "";
  for (const value of bytes) binary += String.fromCharCode(value);
  return btoa(binary);
}

function hasExactKeys(value, keys) {
  return isPlainObject(value) &&
    JSON.stringify(Object.keys(value).sort()) === JSON.stringify([...keys].sort());
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" &&
    !Array.isArray(value) &&
    (Object.getPrototypeOf(value) === Object.prototype ||
      Object.getPrototypeOf(value) === null);
}

function integerBetween(value, minimum, maximum) {
  return Number.isSafeInteger(value) && value >= minimum && value <= maximum;
}

function isUtcTimestamp(value) {
  return typeof value === "string" &&
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|\+00:00)$/.test(
      value,
    ) &&
    Number.isFinite(Date.parse(value));
}

function errorResponse(status, code, retryable, extraHeaders = {}) {
  return jsonResponse(status, {
    error: {code, retryable},
    meta: {contractVersion: notificationPushContractVersion},
  }, extraHeaders);
}

function jsonResponse(status, payload, extraHeaders = {}) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "cache-control": "no-store",
      "content-type": "application/json; charset=utf-8",
      "referrer-policy": "no-referrer",
      "x-content-type-options": "nosniff",
      ...extraHeaders,
    },
  });
}
