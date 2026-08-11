export const notificationEmailContractVersion = "2026-08-10-wp05-14";

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const claimKeys = Object.freeze([
  "attempt",
  "category",
  "delivery_id",
  "expires_at",
  "household_id",
  "inbox_item_id",
  "lease_expires_at",
  "lease_token",
  "locale",
  "max_attempts",
  "recipient_email",
  "scheduled_at",
  "source_event_id",
  "subject_id",
  "subject_type",
]);
const submissionMarkerKeys = Object.freeze([
  "delivery_id",
  "submission_started_at",
]);
const completionKeys = Object.freeze([
  "attempts",
  "completed_at",
  "delivery_id",
  "max_attempts",
  "next_attempt_at",
  "processing_status",
  "result_code",
]);
const retryableCodes = new Set([
  "EMAIL_PROVIDER_INTERNAL",
  "EMAIL_PROVIDER_UNAVAILABLE",
  "EMAIL_RATE_LIMITED",
]);
const permanentCodes = new Set([
  "EMAIL_AUTH_REJECTED",
  "EMAIL_PAYLOAD_REJECTED",
  "EMAIL_REQUEST_REJECTED",
]);
const resultCodes = new Set([
  "ATTEMPTS_EXHAUSTED",
  "EMAIL_ACCEPTED",
  "EMAIL_SUBMISSION_AMBIGUOUS",
  ...retryableCodes,
  ...permanentCodes,
]);

export class NotificationEmailContractError extends Error {
  constructor(code) {
    super("Notification email contract failed");
    this.name = "NotificationEmailContractError";
    this.code = code;
  }
}

export function createNotificationEmailHandler({
  authorizeRequest,
  batchSize = 20,
  clock = () => new Date().toISOString(),
  invokeRpc,
  leaseSeconds = 60,
  randomUuid = () => crypto.randomUUID(),
  sendEmail,
  sha256Base64,
}) {
  if (typeof authorizeRequest !== "function" ||
    typeof clock !== "function" ||
    typeof invokeRpc !== "function" ||
    typeof randomUuid !== "function" ||
    typeof sendEmail !== "function" ||
    typeof sha256Base64 !== "function" ||
    !integerBetween(batchSize, 1, 100) ||
    !integerBetween(leaseSeconds, 5, 300)) {
    throw new NotificationEmailContractError("INVALID_HANDLER_CONFIG");
  }

  return async function notificationEmailHandler(request) {
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
      return errorResponse(503, "EMAIL_WORKER_UNAVAILABLE", true);
    }
    if (authorized !== true) {
      return errorResponse(401, "EMAIL_WORKER_AUTH_REQUIRED", false);
    }

    try {
      const data = await runNotificationEmailBatch({
        asOf: clock(),
        batchSize,
        invokeRpc,
        leaseSeconds,
        sendEmail,
        sha256Base64,
        workerId: randomUuid(),
      });
      return jsonResponse(200, {
        data,
        meta: {contractVersion: notificationEmailContractVersion},
      });
    } catch {
      return errorResponse(503, "EMAIL_WORKER_UNAVAILABLE", true);
    }
  };
}

export async function runNotificationEmailBatch({
  asOf,
  batchSize = 20,
  invokeRpc,
  leaseSeconds = 60,
  sendEmail,
  sha256Base64,
  workerId,
}) {
  if (!isUtcTimestamp(asOf) ||
    !uuidPattern.test(workerId ?? "") ||
    !integerBetween(batchSize, 1, 100) ||
    !integerBetween(leaseSeconds, 5, 300) ||
    typeof invokeRpc !== "function" ||
    typeof sendEmail !== "function" ||
    typeof sha256Base64 !== "function") {
    throw new NotificationEmailContractError("INVALID_WORKER_INPUT");
  }

  let claimPayload;
  try {
    claimPayload = await invokeRpc("claim_notification_email_deliveries", {
      p_as_of: asOf,
      p_batch_size: batchSize,
      p_lease_seconds: leaseSeconds,
      p_worker_id: workerId.toLowerCase(),
    });
  } catch {
    throw new NotificationEmailContractError("CLAIM_UNAVAILABLE");
  }
  const claims = parseClaims(claimPayload, asOf);
  const summary = {
    acceptedCount: 0,
    ambiguousCount: 0,
    claimedCount: claims.length,
    failedCount: 0,
    retryScheduledCount: 0,
    submissionStartedCount: 0,
    unrecordedCompletionCount: 0,
  };

  for (const claim of claims) {
    let submissionStarted = false;
    const beginSubmission = async () => {
      if (submissionStarted) return;
      let markerPayload;
      try {
        markerPayload = await invokeRpc(
          "mark_notification_email_submission_started",
          {
            p_as_of: asOf,
            p_delivery_id: claim.deliveryId,
            p_lease_token: claim.leaseToken,
          },
        );
      } catch {
        throw new NotificationEmailContractError("SUBMISSION_MARK_UNAVAILABLE");
      }
      parseSubmissionMarker(markerPayload, claim);
      submissionStarted = true;
      summary.submissionStartedCount += 1;
    };

    let providerResult;
    try {
      providerResult = parseProviderResult(await sendEmail({
        attempt: claim.attempt,
        beginSubmission,
        locale: claim.locale,
        recipientEmail: claim.recipientEmail,
      }));
      if (!submissionStarted && !(
        providerResult.outcome === "retryable" &&
        providerResult.resultCode === "EMAIL_PROVIDER_UNAVAILABLE"
      )) {
        throw new NotificationEmailContractError(
          "PROVIDER_SUBMISSION_NOT_MARKED",
        );
      }
    } catch {
      providerResult = submissionStarted
        ? {
          outcome: "ambiguous",
          resultCode: "EMAIL_SUBMISSION_AMBIGUOUS",
        }
        : {
          outcome: "retryable",
          resultCode: "EMAIL_PROVIDER_UNAVAILABLE",
          retryAfterSeconds: retryDelay(claim.attempt),
        };
    }

    let providerMessageIdHash = null;
    if (providerResult.outcome === "accepted" &&
      providerResult.providerMessageId !== null) {
      try {
        providerMessageIdHash = requiredDigest(
          await sha256Base64(providerResult.providerMessageId),
        );
      } catch {
        providerResult = {
          outcome: "ambiguous",
          resultCode: "EMAIL_SUBMISSION_AMBIGUOUS",
        };
      }
    }
    if (providerResult.outcome === "ambiguous") {
      summary.ambiguousCount += 1;
    }

    try {
      const completionPayload = await invokeRpc(
        "complete_notification_email_delivery",
        {
          p_as_of: asOf,
          p_delivery_id: claim.deliveryId,
          p_lease_token: claim.leaseToken,
          p_outcome: providerResult.outcome,
          p_provider_message_id_hash_base64: providerMessageIdHash,
          p_result_code: providerResult.resultCode,
          p_retry_after_seconds:
            providerResult.outcome === "retryable"
              ? providerResult.retryAfterSeconds
              : null,
        },
      );
      const completion = parseCompletion(
        completionPayload,
        claim,
        providerResult,
      );
      if (completion.processingStatus === "succeeded") {
        summary.acceptedCount += 1;
      } else if (completion.processingStatus === "retry_wait") {
        summary.retryScheduledCount += 1;
      } else {
        summary.failedCount += 1;
      }
    } catch {
      summary.unrecordedCompletionCount += 1;
    }
  }

  return Object.freeze(summary);
}

function parseClaims(value, asOf) {
  if (!Array.isArray(value) || value.length > 100) {
    throw new NotificationEmailContractError("INVALID_CLAIM_RESPONSE");
  }
  const asOfMilliseconds = Date.parse(asOf);
  const deliveryIds = new Set();
  const sourceEventIds = new Set();
  return value.map((row) => {
    const scheduledMilliseconds = Date.parse(row?.scheduled_at ?? "");
    const expiresMilliseconds = Date.parse(row?.expires_at ?? "");
    const leaseExpiresMilliseconds = Date.parse(row?.lease_expires_at ?? "");
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
      !uuidPattern.test(row.household_id ?? "") ||
      !validSubject ||
      !uuidPattern.test(row.subject_id ?? "") ||
      !emailAddress(row.recipient_email) ||
      !["en", "ko"].includes(row.locale) ||
      !integerBetween(row.attempt, 1, 5) ||
      row.max_attempts !== 5 ||
      row.attempt > row.max_attempts ||
      !uuidPattern.test(row.lease_token ?? "") ||
      !isUtcTimestamp(row.lease_expires_at) ||
      !isUtcTimestamp(row.scheduled_at) ||
      !isUtcTimestamp(row.expires_at) ||
      scheduledMilliseconds > asOfMilliseconds ||
      expiresMilliseconds <= asOfMilliseconds ||
      expiresMilliseconds <= scheduledMilliseconds ||
      expiresMilliseconds - scheduledMilliseconds > 3600000 ||
      leaseExpiresMilliseconds <= asOfMilliseconds ||
      leaseExpiresMilliseconds > asOfMilliseconds + 300000 ||
      deliveryIds.has(row.delivery_id.toLowerCase()) ||
      sourceEventIds.has(row.source_event_id.toLowerCase())) {
      throw new NotificationEmailContractError("INVALID_CLAIM_RESPONSE");
    }
    deliveryIds.add(row.delivery_id.toLowerCase());
    sourceEventIds.add(row.source_event_id.toLowerCase());
    return Object.freeze({
      attempt: row.attempt,
      deliveryId: row.delivery_id.toLowerCase(),
      leaseToken: row.lease_token.toLowerCase(),
      locale: row.locale,
      maxAttempts: row.max_attempts,
      recipientEmail: row.recipient_email,
    });
  });
}

function parseSubmissionMarker(value, claim) {
  if (!Array.isArray(value) || value.length !== 1 ||
    !hasExactKeys(value[0], submissionMarkerKeys) ||
    value[0].delivery_id?.toLowerCase() !== claim.deliveryId ||
    !isUtcTimestamp(value[0].submission_started_at)) {
    throw new NotificationEmailContractError("INVALID_SUBMISSION_MARK_RESPONSE");
  }
}

function parseProviderResult(value) {
  if (!isPlainObject(value) || typeof value.outcome !== "string" ||
    typeof value.resultCode !== "string") {
    throw new NotificationEmailContractError("INVALID_PROVIDER_RESULT");
  }
  if (value.outcome === "accepted") {
    if (!hasExactKeys(
      value,
      ["outcome", "providerMessageId", "resultCode"],
    ) || value.resultCode !== "EMAIL_ACCEPTED" ||
      value.providerMessageId !== null && !providerMessageId(
        value.providerMessageId,
      )) {
      throw new NotificationEmailContractError("INVALID_PROVIDER_RESULT");
    }
  } else if (value.outcome === "retryable") {
    if (!hasExactKeys(value, ["outcome", "resultCode", "retryAfterSeconds"]) ||
      !retryableCodes.has(value.resultCode) ||
      !integerBetween(value.retryAfterSeconds, 5, 7200)) {
      throw new NotificationEmailContractError("INVALID_PROVIDER_RESULT");
    }
  } else if (value.outcome === "permanent") {
    if (!hasExactKeys(value, ["outcome", "resultCode"]) ||
      !permanentCodes.has(value.resultCode)) {
      throw new NotificationEmailContractError("INVALID_PROVIDER_RESULT");
    }
  } else if (value.outcome === "ambiguous") {
    if (!hasExactKeys(value, ["outcome", "resultCode"]) ||
      value.resultCode !== "EMAIL_SUBMISSION_AMBIGUOUS") {
      throw new NotificationEmailContractError("INVALID_PROVIDER_RESULT");
    }
  } else {
    throw new NotificationEmailContractError("INVALID_PROVIDER_RESULT");
  }
  return value;
}

function parseCompletion(value, claim, providerResult) {
  if (!Array.isArray(value) || value.length !== 1 ||
    !hasExactKeys(value[0], completionKeys)) {
    throw new NotificationEmailContractError("INVALID_COMPLETION_RESPONSE");
  }
  const row = value[0];
  const expectedStatuses = providerResult.outcome === "accepted"
    ? ["succeeded"]
    : providerResult.outcome === "retryable"
    ? ["failed", "retry_wait"]
    : ["failed"];
  if (row.delivery_id?.toLowerCase() !== claim.deliveryId ||
    !expectedStatuses.includes(row.processing_status) ||
    row.attempts !== claim.attempt ||
    row.max_attempts !== claim.maxAttempts ||
    !resultCodes.has(row.result_code) ||
    row.result_code !== providerResult.resultCode) {
    throw new NotificationEmailContractError("INVALID_COMPLETION_RESPONSE");
  }
  if (row.processing_status === "retry_wait") {
    if (!isUtcTimestamp(row.next_attempt_at) || row.completed_at !== null) {
      throw new NotificationEmailContractError("INVALID_COMPLETION_RESPONSE");
    }
  } else if (row.next_attempt_at !== null || !isUtcTimestamp(row.completed_at)) {
    throw new NotificationEmailContractError("INVALID_COMPLETION_RESPONSE");
  }
  return {processingStatus: row.processing_status};
}

function requiredDigest(value) {
  if (!canonicalBase64(value, 32)) {
    throw new NotificationEmailContractError("INVALID_MESSAGE_ID_DIGEST");
  }
  return value;
}

function canonicalBase64(value, expectedBytes) {
  if (typeof value !== "string" ||
    !/^[A-Za-z0-9+/]+={0,2}$/.test(value) ||
    value.length > Math.ceil(expectedBytes / 3) * 4 + 4) {
    return false;
  }
  let bytes;
  try {
    bytes = Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
  } catch {
    return false;
  }
  return bytes.byteLength === expectedBytes && encodeBase64(bytes) === value;
}

function encodeBase64(bytes) {
  let binary = "";
  for (const value of bytes) binary += String.fromCharCode(value);
  return btoa(binary);
}

function retryDelay(attempt) {
  return [60, 300, 1800, 7200][Math.min(attempt - 1, 3)];
}

function providerMessageId(value) {
  return typeof value === "string" && /^[\x21-\x7e]{1,256}$/.test(value);
}

function emailAddress(value) {
  if (typeof value !== "string" || value.length < 3 || value.length > 320 ||
    /[\x00-\x20\x7f]/.test(value)) {
    return false;
  }
  const at = value.indexOf("@");
  if (at < 1 || at !== value.lastIndexOf("@") || at > 64) return false;
  const local = value.slice(0, at);
  const domain = value.slice(at + 1);
  if (!/^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+$/.test(local) ||
    local.startsWith(".") || local.endsWith(".") || local.includes("..") ||
    domain.length < 1 || domain.length > 255) {
    return false;
  }
  return domain.split(".").every((label) =>
    /^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$/.test(label)
  );
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
    ) && Number.isFinite(Date.parse(value));
}

function errorResponse(status, code, retryable, extraHeaders = {}) {
  return jsonResponse(status, {
    error: {code, retryable},
    meta: {contractVersion: notificationEmailContractVersion},
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
