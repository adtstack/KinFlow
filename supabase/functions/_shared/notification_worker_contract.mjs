export const notificationWorkerContractVersion = "2026-08-08-wp05-02";

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const claimKeys = Object.freeze([
  "attempt",
  "event_id",
  "lease_expires_at",
  "lease_token",
  "max_attempts",
]);
const resolutionKeys = Object.freeze([
  "notification_category",
  "outcome",
  "recipient_member_id",
  "recipient_user_id",
  "resolved_at",
  "scheduled_at",
  "source_event_id",
  "subject_id",
  "subject_type",
  "suppression_reason",
  "timezone",
]);
const failureKeys = Object.freeze([
  "attempts",
  "dead_lettered_at",
  "event_id",
  "max_attempts",
  "next_attempt_at",
  "processing_status",
]);
const materializationKeys = Object.freeze([
  "cancelled_count",
  "captured_at",
  "claimed_count",
  "created_count",
  "disabled_count",
  "stale_count",
  "suppressed_count",
]);

export class NotificationWorkerContractError extends Error {
  constructor(code) {
    super("Notification worker contract failed");
    this.name = "NotificationWorkerContractError";
    this.code = code;
  }
}

export function createNotificationWorkerHandler({
  authorizeRequest,
  batchSize = 20,
  clock = () => new Date().toISOString(),
  invokeRpc,
  leaseSeconds = 60,
  randomUuid = () => crypto.randomUUID(),
}) {
  if (typeof authorizeRequest !== "function" ||
    typeof clock !== "function" ||
    typeof invokeRpc !== "function" ||
    typeof randomUuid !== "function" ||
    !integerBetween(batchSize, 1, 100) ||
    !integerBetween(leaseSeconds, 5, 300)) {
    throw new NotificationWorkerContractError("INVALID_HANDLER_CONFIG");
  }

  return async function notificationWorkerHandler(request) {
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
      return errorResponse(503, "WORKER_UNAVAILABLE", true);
    }
    if (authorized !== true) {
      return errorResponse(401, "WORKER_AUTH_REQUIRED", false);
    }

    try {
      const data = await runNotificationOutboxBatch({
        asOf: clock(),
        batchSize,
        invokeRpc,
        leaseSeconds,
        workerId: randomUuid(),
      });
      return jsonResponse(200, {
        data,
        meta: {contractVersion: notificationWorkerContractVersion},
      });
    } catch {
      return errorResponse(503, "WORKER_UNAVAILABLE", true);
    }
  };
}

export async function runNotificationOutboxBatch({
  asOf,
  batchSize = 20,
  invokeRpc,
  leaseSeconds = 60,
  workerId,
}) {
  if (typeof invokeRpc !== "function" ||
    !uuidPattern.test(workerId ?? "") ||
    !integerBetween(batchSize, 1, 100) ||
    !integerBetween(leaseSeconds, 5, 300) ||
    !isUtcTimestamp(asOf)) {
    throw new NotificationWorkerContractError("INVALID_WORKER_INPUT");
  }

  let claimPayload;
  try {
    claimPayload = await invokeRpc("claim_chore_notification_events", {
      p_as_of: asOf,
      p_batch_size: batchSize,
      p_lease_seconds: leaseSeconds,
      p_worker_id: workerId.toLowerCase(),
    });
  } catch {
    throw new NotificationWorkerContractError("CLAIM_UNAVAILABLE");
  }

  const claims = parseClaims(claimPayload);
  const summary = {
    candidateCount: 0,
    claimedCount: claims.length,
    deadLetterCount: 0,
    inboxCancelledCount: 0,
    inboxClaimedCount: 0,
    inboxCreatedCount: 0,
    inboxDisabledCount: 0,
    inboxStaleCount: 0,
    inboxSuppressedCount: 0,
    retryScheduledCount: 0,
    suppressedCount: 0,
    unrecordedFailureCount: 0,
  };

  for (const claim of claims) {
    try {
      const resolutionPayload = await invokeRpc(
        "process_chore_notification_event",
        {
          p_as_of: asOf,
          p_event_id: claim.eventId,
          p_lease_token: claim.leaseToken,
        },
      );
      const resolution = parseResolution(resolutionPayload, claim.eventId);
      if (resolution.outcome === "candidate") {
        summary.candidateCount += 1;
      } else {
        summary.suppressedCount += 1;
      }
    } catch {
      try {
        const failurePayload = await invokeRpc(
          "fail_chore_notification_event",
          {
            p_as_of: asOf,
            p_error_code: "WORKER_PROCESSING_FAILED",
            p_event_id: claim.eventId,
            p_lease_token: claim.leaseToken,
          },
        );
        const failure = parseFailure(failurePayload, claim.eventId);
        if (failure.processingStatus === "dead_letter") {
          summary.deadLetterCount += 1;
        } else {
          summary.retryScheduledCount += 1;
        }
      } catch {
        summary.unrecordedFailureCount += 1;
      }
    }
  }

  let materializationPayload;
  try {
    materializationPayload = await invokeRpc(
      "materialize_chore_notification_inbox",
      {p_as_of: asOf, p_batch_size: batchSize},
    );
  } catch {
    throw new NotificationWorkerContractError("MATERIALIZER_UNAVAILABLE");
  }
  const materialization = parseMaterialization(
    materializationPayload,
    asOf,
    batchSize,
  );
  summary.inboxCancelledCount = materialization.cancelledCount;
  summary.inboxClaimedCount = materialization.claimedCount;
  summary.inboxCreatedCount = materialization.createdCount;
  summary.inboxDisabledCount = materialization.disabledCount;
  summary.inboxStaleCount = materialization.staleCount;
  summary.inboxSuppressedCount = materialization.suppressedCount;

  return Object.freeze(summary);
}

export function createNotificationWorkerRpcInvoker({
  fetchImplementation = globalThis.fetch,
  serviceRoleKey,
  supabaseUrl,
  timeoutMilliseconds = 8000,
}) {
  const normalizedUrl = typeof supabaseUrl === "string"
    ? supabaseUrl.trim().replace(/\/$/, "")
    : "";
  if (typeof fetchImplementation !== "function" ||
    !/^https?:\/\/[^\s/]+(?::\d+)?(?:\/.*)?$/i.test(normalizedUrl) ||
    typeof serviceRoleKey !== "string" ||
    serviceRoleKey.trim().length < 16 ||
    !integerBetween(timeoutMilliseconds, 1000, 30000)) {
    throw new NotificationWorkerContractError("INVALID_RUNTIME_CONFIG");
  }

  return async function invokeRpc(name, parameters) {
    if (!/^[a-z][a-z0-9_]{0,63}$/.test(name) || !isPlainObject(parameters)) {
      throw new NotificationWorkerContractError("INVALID_RPC_INPUT");
    }
    let response;
    try {
      response = await fetchImplementation(
        `${normalizedUrl}/rest/v1/rpc/${encodeURIComponent(name)}`,
        {
          method: "POST",
          headers: {
            apikey: serviceRoleKey,
            authorization: `Bearer ${serviceRoleKey}`,
            "content-type": "application/json",
          },
          body: JSON.stringify(parameters),
          signal: AbortSignal.timeout(timeoutMilliseconds),
        },
      );
    } catch {
      throw new NotificationWorkerContractError("RPC_UNAVAILABLE");
    }
    if (!response.ok) {
      throw new NotificationWorkerContractError("RPC_REJECTED");
    }
    try {
      return await response.json();
    } catch {
      throw new NotificationWorkerContractError("INVALID_RPC_RESPONSE");
    }
  };
}

function parseClaims(value) {
  if (!Array.isArray(value) || value.length > 100) {
    throw new NotificationWorkerContractError("INVALID_CLAIM_RESPONSE");
  }
  const eventIds = new Set();
  return value.map((row) => {
    if (!hasExactKeys(row, claimKeys) ||
      !uuidPattern.test(row.event_id) ||
      !uuidPattern.test(row.lease_token) ||
      !integerBetween(row.attempt, 1, 10) ||
      !integerBetween(row.max_attempts, row.attempt, 10) ||
      !isUtcTimestamp(row.lease_expires_at) ||
      eventIds.has(row.event_id.toLowerCase())) {
      throw new NotificationWorkerContractError("INVALID_CLAIM_RESPONSE");
    }
    eventIds.add(row.event_id.toLowerCase());
    return {
      eventId: row.event_id.toLowerCase(),
      leaseToken: row.lease_token.toLowerCase(),
    };
  });
}

function parseResolution(value, eventId) {
  const row = singleRow(value, "INVALID_PROCESS_RESPONSE");
  const validSubject = (
    ["chore_due", "chore_assignment"].includes(row?.notification_category) &&
      row?.subject_type === "chore_occurrence"
  ) || (
    row?.notification_category === "calendar_event" &&
      row?.subject_type === "calendar_occurrence"
  );
  if (!hasExactKeys(row, resolutionKeys) ||
    row.source_event_id?.toLowerCase() !== eventId ||
    !["candidate", "suppressed"].includes(row.outcome) ||
    !validSubject ||
    !uuidPattern.test(row.subject_id ?? "") ||
    typeof row.timezone !== "string" ||
    row.timezone.length < 1 ||
    row.timezone.length > 100 ||
    !isUtcTimestamp(row.resolved_at)) {
    throw new NotificationWorkerContractError("INVALID_PROCESS_RESPONSE");
  }
  if (row.outcome === "candidate") {
    if (!uuidPattern.test(row.recipient_member_id ?? "") ||
      !uuidPattern.test(row.recipient_user_id ?? "") ||
      !isUtcTimestamp(row.scheduled_at) ||
      row.suppression_reason !== null) {
      throw new NotificationWorkerContractError("INVALID_PROCESS_RESPONSE");
    }
  } else if (row.recipient_member_id !== null ||
    row.recipient_user_id !== null ||
    row.scheduled_at !== null ||
    !["inactive_recipient", "inactive_series", "occurrence_not_scheduled", "schedule_unresolved", "stale_event"]
      .includes(row.suppression_reason)) {
    throw new NotificationWorkerContractError("INVALID_PROCESS_RESPONSE");
  }
  return {outcome: row.outcome};
}

function parseFailure(value, eventId) {
  const row = singleRow(value, "INVALID_FAILURE_RESPONSE");
  if (!hasExactKeys(row, failureKeys) ||
    row.event_id?.toLowerCase() !== eventId ||
    !["retry_wait", "dead_letter"].includes(row.processing_status) ||
    !integerBetween(row.attempts, 1, 10) ||
    !integerBetween(row.max_attempts, row.attempts, 10)) {
    throw new NotificationWorkerContractError("INVALID_FAILURE_RESPONSE");
  }
  if (row.processing_status === "retry_wait") {
    if (!isUtcTimestamp(row.next_attempt_at) || row.dead_lettered_at !== null) {
      throw new NotificationWorkerContractError("INVALID_FAILURE_RESPONSE");
    }
  } else if (row.next_attempt_at !== null ||
    !isUtcTimestamp(row.dead_lettered_at)) {
    throw new NotificationWorkerContractError("INVALID_FAILURE_RESPONSE");
  }
  return {processingStatus: row.processing_status};
}

function parseMaterialization(value, asOf, batchSize) {
  const row = singleRow(value, "INVALID_MATERIALIZER_RESPONSE");
  if (!hasExactKeys(row, materializationKeys) ||
    row.captured_at !== asOf ||
    !integerBetween(row.claimed_count, 0, batchSize) ||
    !integerBetween(row.created_count, 0, row.claimed_count) ||
    !integerBetween(row.disabled_count, 0, row.claimed_count) ||
    !integerBetween(row.stale_count, 0, row.claimed_count) ||
    !integerBetween(row.suppressed_count, 0, row.claimed_count) ||
    !Number.isInteger(row.cancelled_count) ||
    row.cancelled_count < 0 ||
    row.created_count + row.disabled_count + row.stale_count +
      row.suppressed_count !== row.claimed_count) {
    throw new NotificationWorkerContractError("INVALID_MATERIALIZER_RESPONSE");
  }
  return {
    cancelledCount: row.cancelled_count,
    claimedCount: row.claimed_count,
    createdCount: row.created_count,
    disabledCount: row.disabled_count,
    staleCount: row.stale_count,
    suppressedCount: row.suppressed_count,
  };
}

function singleRow(value, errorCode) {
  if (!Array.isArray(value) || value.length !== 1 || !isPlainObject(value[0])) {
    throw new NotificationWorkerContractError(errorCode);
  }
  return value[0];
}

function hasExactKeys(value, keys) {
  return isPlainObject(value) &&
    Object.keys(value).sort().join("\u0000") === keys.join("\u0000");
}

function integerBetween(value, minimum, maximum) {
  return Number.isInteger(value) && value >= minimum && value <= maximum;
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isUtcTimestamp(value) {
  return typeof value === "string" &&
    /Z$/i.test(value) &&
    Number.isFinite(Date.parse(value));
}

function errorResponse(status, code, retryable, extraHeaders = {}) {
  return jsonResponse(status, {error: {code, retryable}}, extraHeaders);
}

function jsonResponse(status, payload, extraHeaders = {}) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "cache-control": "no-store",
      "content-type": "application/json; charset=utf-8",
      "x-content-type-options": "nosniff",
      ...extraHeaders,
    },
  });
}
