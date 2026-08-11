export const billingReconciliationContractVersion = "2026-08-08-wp06-04";

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const claimRowKeys = Object.freeze([
  "attempt_count",
  "auth_user_id",
  "environment",
  "household_id",
  "job_id",
  "lease_token",
  "provider_occurred_at",
]);
const completionRowKeys = Object.freeze([
  "attempt_count",
  "completed_at",
  "job_id",
  "last_error_code",
  "next_attempt_at",
  "processing_status",
]);
const applyRowKeys = Object.freeze([
  "assignment_id",
  "billing_customer_id",
  "billing_transaction_id",
  "duplicate",
  "entitlement_status",
  "entitlement_version",
  "household_id",
  "plan_code",
  "processing_status",
  "provider_updated_at",
  "receipt_id",
]);

export class BillingReconciliationFailure extends Error {
  constructor(code, retryable = false) {
    super("Billing reconciliation failed");
    this.name = "BillingReconciliationFailure";
    this.code = typeof code === "string" ? code : "PROVIDER_RESPONSE_INVALID";
    this.retryable = retryable === true;
  }
}

export function createBillingReconciliationWorkerHandler({
  applyEvent,
  authorize,
  batchLimit = 50,
  claimJobs,
  clock = () => new Date().toISOString(),
  completeJob,
  fetchSubscriber,
  leaseSeconds = 120,
  mapSubscriber,
  scheduleDue,
  staleAfterSeconds = 3600,
  workerId = () => crypto.randomUUID(),
}) {
  if (typeof applyEvent !== "function" || typeof authorize !== "function" ||
    typeof claimJobs !== "function" || typeof clock !== "function" ||
    typeof completeJob !== "function" || typeof fetchSubscriber !== "function" ||
    typeof mapSubscriber !== "function" || typeof scheduleDue !== "function" ||
    typeof workerId !== "function" ||
    !Number.isSafeInteger(batchLimit) || batchLimit < 1 || batchLimit > 100 ||
    !Number.isSafeInteger(leaseSeconds) || leaseSeconds < 5 || leaseSeconds > 300 ||
    !Number.isSafeInteger(staleAfterSeconds) ||
    staleAfterSeconds < 300 || staleAfterSeconds > 86400) {
    throw new TypeError("Invalid billing reconciliation worker configuration");
  }

  return async function handleBillingReconciliation(request) {
    const requestId = crypto.randomUUID();
    if (!(request instanceof Request)) {
      return workerError(400, "VALIDATION_FAILED", false, requestId);
    }
    if (request.method !== "POST") {
      const response = workerError(405, "METHOD_NOT_ALLOWED", false, requestId);
      response.headers.set("allow", "POST");
      return response;
    }
    if (new URL(request.url).search.length > 0 || !(await hasEmptyBody(request))) {
      return workerError(400, "VALIDATION_FAILED", false, requestId);
    }
    let authorized = false;
    try {
      authorized = await authorize(request.headers.get("authorization") ?? "") === true;
    } catch {
      authorized = false;
    }
    if (!authorized) {
      return workerError(401, "AUTHENTICATION_FAILED", false, requestId);
    }

    const asOf = clock();
    const resolvedWorkerId = workerId();
    if (!isUtcTimestamp(asOf) || !uuidPattern.test(resolvedWorkerId)) {
      return workerError(503, "TEMPORARILY_UNAVAILABLE", true, requestId);
    }

    try {
      const scheduled = await scheduleDue({
        p_as_of: asOf,
        p_correlation_id: requestId,
        p_limit: batchLimit,
        p_stale_after_seconds: staleAfterSeconds,
      });
      if (!Number.isSafeInteger(scheduled) || scheduled < 0 || scheduled > batchLimit) {
        throw new BillingReconciliationFailure("RPC_UNAVAILABLE", true);
      }
      const claims = claimRows(await claimJobs({
        p_as_of: asOf,
        p_lease_seconds: leaseSeconds,
        p_limit: batchLimit,
        p_worker_id: resolvedWorkerId.toLowerCase(),
      }), batchLimit);
      const counts = {
        claimed: claims.length,
        deadLetter: 0,
        retryScheduled: 0,
        scheduled,
        succeeded: 0,
      };
      for (const claim of claims) {
        const outcome = await reconcileClaim({
          applyEvent,
          asOf,
          claim,
          completeJob,
          fetchSubscriber,
          mapSubscriber,
        });
        counts[outcome] += 1;
      }
      return workerJson(200, {
        data: counts,
        meta: {contractVersion: billingReconciliationContractVersion, requestId},
      }, requestId);
    } catch {
      return workerError(503, "TEMPORARILY_UNAVAILABLE", true, requestId);
    }
  };
}

export function createRevenueCatSubscriberMapper({entitlementId}) {
  if (!boundedNonControlText(entitlementId, 1, 255)) {
    throw new TypeError("Invalid RevenueCat entitlement configuration");
  }
  return function mapSubscriber(payload, claim, asOf) {
    if (!isPlainObject(payload) || !isPlainObject(payload.subscriber) ||
      !isUtcTimestamp(asOf) ||
      !isUtcDateText(payload.request_date) ||
      payload.request_date_ms !== undefined &&
        (!Number.isSafeInteger(payload.request_date_ms) ||
          Math.abs(payload.request_date_ms - Date.parse(payload.request_date)) > 1000) ||
      !uuidPattern.test(payload.subscriber.original_app_user_id ?? "") ||
      payload.subscriber.original_app_user_id.toLowerCase() !== claim.auth_user_id ||
      !isPlainObject(payload.subscriber.entitlements) ||
      !isPlainObject(payload.subscriber.subscriptions)) {
      throw new BillingReconciliationFailure(
        uuidPattern.test(payload?.subscriber?.original_app_user_id ?? "")
          ? "PROVIDER_IDENTITY_MISMATCH"
          : "PROVIDER_RESPONSE_INVALID",
      );
    }
    const entitlement = payload.subscriber.entitlements[entitlementId];
    if (!isPlainObject(entitlement) ||
      !boundedNonControlText(entitlement.product_identifier, 1, 255)) {
      throw new BillingReconciliationFailure("ENTITLEMENT_UNMAPPED");
    }
    const productId = entitlement.product_identifier;
    const subscription = payload.subscriber.subscriptions[productId];
    if (!isPlainObject(subscription)) {
      throw new BillingReconciliationFailure("SUBSCRIPTION_UNMAPPED");
    }
    const source = providerSource(subscription.store);
    if (source === null) {
      throw new BillingReconciliationFailure("UNSUPPORTED_STORE");
    }
    if (typeof subscription.is_sandbox !== "boolean") {
      throw new BillingReconciliationFailure("PROVIDER_RESPONSE_INVALID");
    }
    const snapshotEnvironment = subscription.is_sandbox ? "sandbox" : "production";
    if (snapshotEnvironment !== claim.environment) {
      throw new BillingReconciliationFailure("PROVIDER_ENVIRONMENT_MISMATCH");
    }
    if (!boundedNonControlText(subscription.store_transaction_id, 1, 512)) {
      throw new BillingReconciliationFailure("PROVIDER_RESPONSE_INVALID");
    }
    const purchaseDate = requiredUtcDate(subscription.purchase_date);
    const expirationDate = requiredUtcDate(subscription.expires_date);
    if (Date.parse(expirationDate) <= Date.parse(purchaseDate)) {
      throw new BillingReconciliationFailure("PROVIDER_RESPONSE_INVALID");
    }
    const requestDate = requiredUtcDate(payload.request_date);
    if (Date.parse(requestDate) < Date.UTC(2000, 0, 1) ||
      Date.parse(requestDate) > Date.parse(asOf) + 5 * 60 * 1000) {
      throw new BillingReconciliationFailure("PROVIDER_RESPONSE_INVALID");
    }
    const periodType = String(subscription.period_type ?? "").toLowerCase();
    if (!["intro", "normal", "prepaid", "trial"].includes(periodType)) {
      throw new BillingReconciliationFailure("PROVIDER_RESPONSE_INVALID");
    }
    const graceDate = optionalUtcDate(subscription.grace_period_expires_date);
    const billingIssueDate = optionalUtcDate(subscription.billing_issues_detected_at);
    const unsubscribeDate = optionalUtcDate(subscription.unsubscribe_detected_at);
    const refundedDate = optionalUtcDate(subscription.refunded_at);
    const requestMilliseconds = Date.parse(requestDate);
    const expirationMilliseconds = Date.parse(expirationDate);
    const graceMilliseconds = graceDate === null ? -Infinity : Date.parse(graceDate);
    const accessActive = expirationMilliseconds > requestMilliseconds ||
      graceMilliseconds > requestMilliseconds;
    const refunded = refundedDate !== null;
    let status;
    let planCode;
    if (refunded) {
      status = "revoked";
      planCode = "free";
    } else if (graceMilliseconds > requestMilliseconds &&
      expirationMilliseconds <= requestMilliseconds) {
      status = "grace";
      planCode = "plus";
    } else if (billingIssueDate !== null && accessActive) {
      status = "billing_issue";
      planCode = "plus";
    } else if (accessActive) {
      status = periodType === "trial"
        ? "trialing"
        : "active";
      planCode = "plus";
    } else {
      status = "expired";
      planCode = "free";
    }
    const willRenew = accessActive && !refunded && unsubscribeDate === null &&
      periodType !== "prepaid";
    const requestTimestamp = Date.parse(requestDate);
    return Object.freeze({
      currentPeriodEnd: expirationDate,
      currentPeriodStart: purchaseDate,
      eventId: `reconciliation:${claim.job_id}:${requestTimestamp}`,
      originalTransactionRef: subscription.store_transaction_id,
      planCode,
      productId,
      providerOccurredAt: requestDate,
      source,
      status,
      transactionRef: subscription.store_transaction_id,
      willRenew,
    });
  };
}

async function reconcileClaim({
  applyEvent,
  asOf,
  claim,
  completeJob,
  fetchSubscriber,
  mapSubscriber,
}) {
  let outcome = "succeeded";
  let errorCode = null;
  try {
    if (claim.household_id === null) {
      throw new BillingReconciliationFailure("ASSIGNMENT_REQUIRED");
    }
    const snapshot = await fetchSubscriber(claim.auth_user_id);
    const normalized = mapSubscriber(snapshot, claim, asOf);
    const applied = singleApplyRow(await applyEvent({
      p_auth_user_id: claim.auth_user_id,
      p_correlation_id: claim.job_id,
      p_current_period_end: normalized.currentPeriodEnd,
      p_current_period_start: normalized.currentPeriodStart,
      p_effective_plan_code: normalized.planCode,
      p_environment: claim.environment,
      p_event_type: "reconciliation",
      p_household_id: claim.household_id,
      p_original_transaction_ref: normalized.originalTransactionRef,
      p_payload_ciphertext: null,
      p_payload_version: billingReconciliationContractVersion,
      p_product_id: normalized.productId,
      p_provider: "revenuecat",
      p_provider_customer_ref: claim.auth_user_id,
      p_provider_event_id: normalized.eventId,
      p_provider_occurred_at: normalized.providerOccurredAt,
      p_source: normalized.source,
      p_status: normalized.status,
      p_transaction_ref: normalized.transactionRef,
      p_will_renew: normalized.willRenew,
    }));
    if (!["applied", "stale"].includes(applied.processing_status)) {
      throw new BillingReconciliationFailure("NORMALIZED_EVENT_QUARANTINED");
    }
  } catch (error) {
    const failure = error instanceof BillingReconciliationFailure
      ? error
      : new BillingReconciliationFailure("PROVIDER_RESPONSE_INVALID");
    outcome = failure.retryable ? "retryable" : "dead_letter";
    errorCode = failure.code;
  }
  const completion = singleCompletionRow(await completeJob({
    p_as_of: asOf,
    p_error_code: errorCode,
    p_job_id: claim.job_id,
    p_lease_token: claim.lease_token,
    p_outcome: outcome,
  }));
  return completion.processing_status === "succeeded"
    ? "succeeded"
    : completion.processing_status === "retry_wait"
    ? "retryScheduled"
    : "deadLetter";
}

function claimRows(payload, limit) {
  if (!Array.isArray(payload) || payload.length > limit) {
    throw new BillingReconciliationFailure("RPC_UNAVAILABLE", true);
  }
  return payload.map((row) => {
    if (!isPlainObject(row) || !sameKeys(Object.keys(row).sort(), claimRowKeys) ||
      !uuidPattern.test(row.job_id ?? "") || !uuidPattern.test(row.lease_token ?? "") ||
      !uuidPattern.test(row.auth_user_id ?? "") ||
      !["sandbox", "production"].includes(row.environment) ||
      row.household_id !== null && !uuidPattern.test(row.household_id ?? "") ||
      !isUtcDateText(row.provider_occurred_at) ||
      !Number.isSafeInteger(row.attempt_count) ||
      row.attempt_count < 1 || row.attempt_count > 5) {
      throw new BillingReconciliationFailure("RPC_UNAVAILABLE", true);
    }
    return Object.freeze({
      ...row,
      auth_user_id: row.auth_user_id.toLowerCase(),
      household_id: row.household_id?.toLowerCase() ?? null,
      job_id: row.job_id.toLowerCase(),
      lease_token: row.lease_token.toLowerCase(),
    });
  });
}

function singleCompletionRow(payload) {
  if (!Array.isArray(payload) || payload.length !== 1 ||
    !isPlainObject(payload[0]) ||
    !sameKeys(Object.keys(payload[0]).sort(), completionRowKeys) ||
    !uuidPattern.test(payload[0].job_id ?? "") ||
    !["retry_wait", "succeeded", "dead_letter"].includes(
      payload[0].processing_status,
    ) ||
    !Number.isSafeInteger(payload[0].attempt_count) ||
    payload[0].attempt_count < 1 || payload[0].attempt_count > 5 ||
    !optionalUtcDateIsValid(payload[0].next_attempt_at) ||
    !optionalUtcDateIsValid(payload[0].completed_at) ||
    payload[0].last_error_code !== null &&
      !boundedNonControlText(payload[0].last_error_code, 1, 80)) {
    throw new BillingReconciliationFailure("RPC_UNAVAILABLE", true);
  }
  return payload[0];
}

function singleApplyRow(payload) {
  if (!Array.isArray(payload) || payload.length !== 1 ||
    !isPlainObject(payload[0]) ||
    !sameKeys(Object.keys(payload[0]).sort(), applyRowKeys) ||
    !["applied", "stale", "quarantined"].includes(payload[0].processing_status) ||
    typeof payload[0].duplicate !== "boolean") {
    throw new BillingReconciliationFailure("RPC_UNAVAILABLE", true);
  }
  return payload[0];
}

function providerSource(value) {
  return String(value ?? "").toLowerCase() === "play_store"
    ? "play_store"
    : String(value ?? "").toLowerCase() === "app_store"
    ? "app_store"
    : null;
}

function requiredUtcDate(value) {
  if (!isUtcDateText(value)) {
    throw new BillingReconciliationFailure("PROVIDER_RESPONSE_INVALID");
  }
  return new Date(value).toISOString();
}

function optionalUtcDate(value) {
  if (value === null || value === undefined) return null;
  return requiredUtcDate(value);
}

function optionalUtcDateIsValid(value) {
  return value === null || isUtcDateText(value);
}

function isUtcDateText(value) {
  if (typeof value !== "string" || !/(?:Z|[+-]00:00)$/.test(value)) return false;
  const parsed = Date.parse(value);
  return Number.isFinite(parsed);
}

function isUtcTimestamp(value) {
  return isUtcDateText(value) && new Date(Date.parse(value)).toISOString() === value;
}

async function hasEmptyBody(request) {
  const declared = request.headers.get("content-length");
  if (declared !== null && declared !== "0") return false;
  try {
    return (await request.arrayBuffer()).byteLength === 0;
  } catch {
    return false;
  }
}

function workerError(status, code, retryable, requestId) {
  return workerJson(status, {error: {code, requestId, retryable}}, requestId);
}

function workerJson(status, payload, requestId) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "cache-control": "no-store",
      "content-type": "application/json; charset=utf-8",
      "referrer-policy": "no-referrer",
      "x-content-type-options": "nosniff",
      "x-request-id": requestId,
    },
  });
}

function boundedNonControlText(value, minimum, maximum) {
  return typeof value === "string" && value.length >= minimum &&
    value.length <= maximum && value === value.trim() &&
    !/[\x00-\x1f\x7f]/.test(value);
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function sameKeys(left, right) {
  return left.length === right.length && left.every((key, index) => key === right[index]);
}
