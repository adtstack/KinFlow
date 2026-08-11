export const accountDeletionWorkerContractVersion = "2026-08-08-wp07-01";

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export class AccountDeletionWorkerFailure extends Error {
  constructor(code, retryable = false) {
    super("Account deletion worker operation failed");
    this.name = "AccountDeletionWorkerFailure";
    this.code = typeof code === "string" ? code : "PROCESSING_PRECONDITION_FAILED";
    this.retryable = retryable === true;
  }
}

export function createAccountDeletionWorkerHandler({
  workerSecret,
  recoverLeases,
  claimRequests,
  prepareRequest,
  softDeleteUser,
  completeRequest,
  failRequest,
  now = () => new Date().toISOString(),
  workerId = () => crypto.randomUUID(),
}) {
  return async function handleAccountDeletionWorker(request) {
    const requestId = requestIdFor(request);
    const headers = responseHeaders(requestId);
    if (request.method !== "POST") {
      return errorResponse("METHOD_NOT_ALLOWED", 405, false, requestId, headers);
    }
    if (!constantTimeEqual(request.headers.get("authorization") ?? "", `Bearer ${workerSecret}`)) {
      return errorResponse("AUTH_REQUIRED", 401, false, requestId, headers);
    }
    if ((await request.text()).trim().length !== 0) {
      return errorResponse("VALIDATION_FAILED", 400, false, requestId, headers);
    }

    const asOf = now();
    if (!validTimestamp(asOf)) {
      return errorResponse("TEMPORARILY_UNAVAILABLE", 503, true, requestId, headers);
    }
    let recovery;
    let claims;
    try {
      recovery = recoveryRow(await recoverLeases({p_as_of: asOf}));
      const id = workerId();
      if (!uuidPattern.test(id)) throw new TypeError("Invalid worker ID");
      claims = claimRows(await claimRequests({
        p_as_of: asOf,
        p_lease_seconds: 120,
        p_limit: 10,
        p_worker_id: id.toLowerCase(),
      }));
    } catch {
      return errorResponse("TEMPORARILY_UNAVAILABLE", 503, true, requestId, headers);
    }

    const summary = {
      recoveredRetryScheduled: recovery.retry_scheduled,
      recoveredDeadLetter: recovery.dead_letter,
      claimed: claims.length,
      succeeded: 0,
      retryScheduled: 0,
      deadLetter: 0,
    };

    for (const claim of claims) {
      try {
        const prepared = prepareRow(await prepareRequest({
          p_as_of: asOf,
          p_lease_token: claim.lease_token,
          p_request_id: claim.privacy_request_id,
        }));
        if (prepared.auth_user_id !== claim.auth_user_id) {
          throw new AccountDeletionWorkerFailure("PROCESSING_PRECONDITION_FAILED");
        }
        await softDeleteUser(claim.auth_user_id);
        completionRow(await completeRequest({
          p_as_of: asOf,
          p_lease_token: claim.lease_token,
          p_request_id: claim.privacy_request_id,
        }), claim.privacy_request_id);
        summary.succeeded += 1;
      } catch (error) {
        const failure = normalizedFailure(error);
        try {
          const failed = failureRow(await failRequest({
            p_as_of: asOf,
            p_error_code: failure.code,
            p_lease_token: claim.lease_token,
            p_request_id: claim.privacy_request_id,
            p_retryable: failure.retryable,
          }), claim.privacy_request_id);
          if (failed.status === "processing") summary.retryScheduled += 1;
          else summary.deadLetter += 1;
        } catch {
          return errorResponse("TEMPORARILY_UNAVAILABLE", 503, true, requestId, headers);
        }
      }
    }

    return Response.json(
      {data: summary, meta: {requestId, contractVersion: accountDeletionWorkerContractVersion}},
      {status: 200, headers},
    );
  };
}

function normalizedFailure(error) {
  if (error instanceof AccountDeletionWorkerFailure) {
    return error;
  }
  return new AccountDeletionWorkerFailure("AUTH_DELETE_UNAVAILABLE", true);
}

function recoveryRow(payload) {
  const row = singleRow(payload);
  exactKeys(row, ["dead_letter", "retry_scheduled"]);
  if (!nonNegativeInteger(row.retry_scheduled) || !nonNegativeInteger(row.dead_letter)) {
    throw new TypeError("Invalid recovery payload");
  }
  return row;
}

function claimRows(payload) {
  if (!Array.isArray(payload) || payload.length > 10) throw new TypeError("Invalid claims");
  return payload.map((row) => {
    exactKeys(row, [
      "active_subscription_at_request",
      "attempts",
      "auth_user_id",
      "lease_token",
      "privacy_request_id",
      "request_version",
    ]);
    if (typeof row.active_subscription_at_request !== "boolean" ||
      !positiveInteger(row.attempts) || !positiveInteger(row.request_version)) {
      throw new TypeError("Invalid claim payload");
    }
    return {
      ...row,
      auth_user_id: requiredUuid(row.auth_user_id),
      lease_token: requiredUuid(row.lease_token),
      privacy_request_id: requiredUuid(row.privacy_request_id),
    };
  });
}

function prepareRow(payload) {
  const row = singleRow(payload);
  exactKeys(row, [
    "affected_membership_count",
    "already_tombstoned",
    "auth_user_id",
    "erased_endpoint_count",
    "revoked_invite_count",
  ]);
  if (typeof row.already_tombstoned !== "boolean" ||
    !nonNegativeInteger(row.affected_membership_count) ||
    !nonNegativeInteger(row.erased_endpoint_count) ||
    !nonNegativeInteger(row.revoked_invite_count)) {
    throw new TypeError("Invalid prepare payload");
  }
  return {...row, auth_user_id: requiredUuid(row.auth_user_id)};
}

function completionRow(payload, expectedRequestId) {
  const row = singleRow(payload);
  exactKeys(row, ["completed_at", "request_id", "status", "version"]);
  if (requiredUuid(row.request_id) !== expectedRequestId ||
    row.status !== "completed" || !validTimestamp(row.completed_at) ||
    !positiveInteger(row.version)) {
    throw new TypeError("Invalid completion payload");
  }
  return row;
}

function failureRow(payload, expectedRequestId) {
  const row = singleRow(payload);
  exactKeys(row, ["failure_code", "next_attempt_at", "request_id", "status", "version"]);
  if (requiredUuid(row.request_id) !== expectedRequestId ||
    !["processing", "failed"].includes(row.status) ||
    typeof row.failure_code !== "string" ||
    (row.next_attempt_at !== null && !validTimestamp(row.next_attempt_at)) ||
    !positiveInteger(row.version)) {
    throw new TypeError("Invalid failure payload");
  }
  return row;
}

function singleRow(payload) {
  if (!Array.isArray(payload) || payload.length !== 1 || !isPlainObject(payload[0])) {
    throw new TypeError("Invalid RPC payload");
  }
  return payload[0];
}

function exactKeys(value, expected) {
  if (!isPlainObject(value)) throw new TypeError("Invalid object");
  const actual = Object.keys(value).sort();
  const sorted = [...expected].sort();
  if (actual.length !== sorted.length || actual.some((key, index) => key !== sorted[index])) {
    throw new TypeError("Unexpected fields");
  }
}

function requiredUuid(value) {
  if (typeof value !== "string" || !uuidPattern.test(value)) throw new TypeError("Invalid UUID");
  return value.toLowerCase();
}

function validTimestamp(value) {
  return typeof value === "string" && Number.isFinite(Date.parse(value));
}

function positiveInteger(value) {
  return Number.isSafeInteger(value) && value > 0;
}

function nonNegativeInteger(value) {
  return Number.isSafeInteger(value) && value >= 0;
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function errorResponse(code, status, retryable, requestId, headers) {
  return Response.json(
    {error: {code, messageKey: messageKey(code), retryable, requestId}},
    {status, headers},
  );
}

function messageKey(code) {
  return code === "AUTH_REQUIRED"
    ? "errors.authRequired"
    : code === "VALIDATION_FAILED" || code === "METHOD_NOT_ALLOWED"
    ? "errors.validationFailed"
    : "errors.temporarilyUnavailable";
}

function responseHeaders(requestId) {
  return new Headers({
    "allow": "POST",
    "cache-control": "no-store",
    "content-type": "application/json; charset=utf-8",
    "x-content-type-options": "nosniff",
    "x-request-id": requestId,
  });
}

function requestIdFor(request) {
  const candidate = request.headers.get("x-request-id")?.trim() ?? "";
  return uuidPattern.test(candidate) ? candidate.toLowerCase() : crypto.randomUUID();
}

function constantTimeEqual(left, right) {
  const encoder = new TextEncoder();
  const a = encoder.encode(left);
  const b = encoder.encode(right);
  const length = Math.max(a.length, b.length);
  let difference = a.length ^ b.length;
  for (let index = 0; index < length; index += 1) {
    difference |= (a[index] ?? 0) ^ (b[index] ?? 0);
  }
  return difference === 0;
}
