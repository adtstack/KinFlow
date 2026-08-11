import assert from "node:assert/strict";
import test from "node:test";

import {
  BillingReconciliationFailure,
  billingReconciliationContractVersion,
  createBillingReconciliationWorkerHandler,
  createRevenueCatSubscriberMapper,
} from "../../supabase/functions/_shared/billing_reconciliation_contract.mjs";
import {
  createBillingReconciliationRpcInvoker,
  createRevenueCatSubscriberFetcher,
} from "../../supabase/functions/_shared/billing_reconciliation_runtime.mjs";

const asOf = "2030-01-01T00:00:00.000Z";
const workerId = "65000000-0000-4000-8000-000000000001";
const jobId = "65000000-0000-4000-8000-000000000002";
const leaseToken = "65000000-0000-4000-8000-000000000003";
const userId = "00000000-0000-4000-8000-000000000101";
const householdId = "20000000-0000-4000-8000-000000000101";
const entitlementId = "kinflow_plus";
const transactionRef = "play-transaction-0001";

test("subscriber mapper covers access lifecycle and renewal independently", () => {
  const map = createRevenueCatSubscriberMapper({entitlementId});
  const cases = [
    [{period_type: "trial"}, "trialing", "plus", true],
    [{}, "active", "plus", true],
    [{billing_issues_detected_at: "2029-12-31T12:00:00Z"}, "billing_issue", "plus", true],
    [{unsubscribe_detected_at: "2029-12-31T12:00:00Z"}, "active", "plus", false],
    [{
      expires_date: "2029-12-31T12:00:00Z",
      grace_period_expires_date: "2030-01-02T00:00:00Z",
    }, "grace", "plus", true],
    [{expires_date: "2029-12-31T12:00:00Z"}, "expired", "free", false],
    [{refunded_at: "2029-12-31T12:00:00Z"}, "revoked", "free", false],
    [{period_type: "prepaid"}, "active", "plus", false],
  ];
  for (const [subscription, status, planCode, willRenew] of cases) {
    const mapped = map(snapshot({subscription}), claim(), asOf);
    assert.equal(mapped.status, status);
    assert.equal(mapped.planCode, planCode);
    assert.equal(mapped.willRenew, willRenew);
    assert.equal(mapped.source, "play_store");
    assert.equal(mapped.transactionRef, transactionRef);
    assert.equal(mapped.providerOccurredAt, asOf);
  }
});

test("subscriber mapper rejects identity environment store and schema mismatches", () => {
  const map = createRevenueCatSubscriberMapper({entitlementId});
  const cases = [
    [snapshot({originalAppUserId: "00000000-0000-4000-8000-000000000201"}), "PROVIDER_IDENTITY_MISMATCH"],
    [snapshot({subscription: {is_sandbox: false}}), "PROVIDER_ENVIRONMENT_MISMATCH"],
    [snapshot({subscription: {store: "stripe"}}), "UNSUPPORTED_STORE"],
    [snapshot({subscription: {period_type: "future_period"}}), "PROVIDER_RESPONSE_INVALID"],
    [snapshot({subscription: {store_transaction_id: ""}}), "PROVIDER_RESPONSE_INVALID"],
    [snapshot({omitEntitlement: true}), "ENTITLEMENT_UNMAPPED"],
    [snapshot({omitSubscription: true}), "SUBSCRIPTION_UNMAPPED"],
    [{subscriber: {}}, "PROVIDER_RESPONSE_INVALID"],
    [{
      ...snapshot(),
      request_date: "2030-01-01T00:05:01.000Z",
      request_date_ms: Date.parse("2030-01-01T00:05:01.000Z"),
    }, "PROVIDER_RESPONSE_INVALID"],
  ];
  for (const [payload, code] of cases) {
    assert.throws(
      () => map(payload, claim(), asOf),
      (error) => error instanceof BillingReconciliationFailure &&
        error.code === code && error.retryable === false,
    );
  }
});

test("worker schedules, claims, refreshes and applies one authoritative snapshot", async () => {
  const calls = [];
  const handler = handlerFor({
    applyEvent: async (parameters) => {
      calls.push({name: "apply", parameters});
      return [applyRow()];
    },
    claimJobs: async (parameters) => {
      calls.push({name: "claim", parameters});
      return [claim()];
    },
    completeJob: async (parameters) => {
      calls.push({name: "complete", parameters});
      return [completionRow()];
    },
    fetchSubscriber: async (id) => {
      calls.push({name: "fetch", id});
      return snapshot();
    },
    scheduleDue: async (parameters) => {
      calls.push({name: "schedule", parameters});
      return 1;
    },
  });
  const response = await handler(workerRequest());
  assert.equal(response.status, 200);
  const payload = await response.json();
  assert.deepEqual(payload.data, {
    claimed: 1,
    deadLetter: 0,
    retryScheduled: 0,
    scheduled: 1,
    succeeded: 1,
  });
  assert.equal(payload.meta.contractVersion, billingReconciliationContractVersion);
  assert.match(payload.meta.requestId, /^[0-9a-f-]{36}$/);
  assert.equal(JSON.stringify(payload).includes(jobId), false);
  assert.deepEqual(calls.map((entry) => entry.name), [
    "schedule", "claim", "fetch", "apply", "complete",
  ]);
  assert.equal(calls[2].id, userId);
  assert.deepEqual(calls[4].parameters, {
    p_as_of: asOf,
    p_error_code: null,
    p_job_id: jobId,
    p_lease_token: leaseToken,
    p_outcome: "succeeded",
  });
  assert.equal(calls[3].parameters.p_household_id, householdId);
  assert.equal(calls[3].parameters.p_status, "active");
  assert.equal(calls[3].parameters.p_payload_ciphertext, null);
  assert.equal(calls[3].parameters.p_payload_version, billingReconciliationContractVersion);
});

test("missing household assignment dead-letters without a provider call", async () => {
  let providerCalls = 0;
  let completion;
  const handler = handlerFor({
    claimJobs: async () => [claim({household_id: null})],
    completeJob: async (parameters) => {
      completion = parameters;
      return [completionRow({
        completed_at: asOf,
        last_error_code: "ASSIGNMENT_REQUIRED",
        processing_status: "dead_letter",
      })];
    },
    fetchSubscriber: async () => {
      providerCalls += 1;
      return snapshot();
    },
  });
  const response = await handler(workerRequest());
  assert.equal((await response.json()).data.deadLetter, 1);
  assert.equal(providerCalls, 0);
  assert.equal(completion.p_outcome, "dead_letter");
  assert.equal(completion.p_error_code, "ASSIGNMENT_REQUIRED");
});

test("transient provider failures schedule retries and permanent failures dead-letter", async () => {
  for (const [failure, expectedStatus, expectedOutcome] of [
    [new BillingReconciliationFailure("PROVIDER_RATE_LIMITED", true), "retry_wait", "retryScheduled"],
    [new BillingReconciliationFailure("PROVIDER_NOT_FOUND"), "dead_letter", "deadLetter"],
  ]) {
    let completion;
    const handler = handlerFor({
      claimJobs: async () => [claim()],
      completeJob: async (parameters) => {
        completion = parameters;
        return [completionRow({
          completed_at: expectedStatus === "dead_letter" ? asOf : null,
          last_error_code: failure.code,
          next_attempt_at: expectedStatus === "retry_wait"
            ? "2030-01-01T00:01:00.000Z"
            : null,
          processing_status: expectedStatus,
        })];
      },
      fetchSubscriber: async () => {
        throw failure;
      },
    });
    const payload = await (await handler(workerRequest())).json();
    assert.equal(payload.data[expectedOutcome], 1);
    assert.equal(completion.p_error_code, failure.code);
    assert.equal(
      completion.p_outcome,
      expectedStatus === "retry_wait" ? "retryable" : "dead_letter",
    );
  }
});

test("worker validates exact auth, empty POST and RPC response shapes", async () => {
  let calls = 0;
  const handler = handlerFor({
    scheduleDue: async () => {
      calls += 1;
      return 0;
    },
  });
  const unauthorized = await handler(workerRequest("wrong"));
  assert.equal(unauthorized.status, 401);
  assert.equal(calls, 0);

  const method = await handler(new Request("http://local/worker", {
    method: "GET",
    headers: {authorization: "Bearer worker-secret"},
  }));
  assert.equal(method.status, 405);

  const body = await handler(new Request("http://local/worker", {
    method: "POST",
    headers: {authorization: "Bearer worker-secret"},
    body: "{}",
  }));
  assert.equal(body.status, 400);

  const malformed = handlerFor({claimJobs: async () => [{...claim(), raw: "private"}]});
  const response = await malformed(workerRequest());
  const text = await response.text();
  assert.equal(response.status, 503);
  assert.doesNotMatch(text, /private|raw/);
});

test("RevenueCat fetcher fixes endpoint and maps transport status without body leakage", async () => {
  const calls = [];
  const fetchSubscriber = createRevenueCatSubscriberFetcher({
    fetchImplementation: async (url, init) => {
      calls.push({url, init});
      return jsonResponse(snapshot());
    },
    secretApiKey: "r".repeat(40),
  });
  assert.deepEqual(await fetchSubscriber(userId), snapshot());
  assert.equal(calls[0].url, `https://api.revenuecat.com/v1/subscribers/${userId}`);
  assert.equal(calls[0].init.method, "GET");
  assert.equal(calls[0].init.redirect, "error");
  assert.equal(calls[0].init.headers.authorization, `Bearer ${"r".repeat(40)}`);

  for (const [status, code, retryable] of [
    [401, "PROVIDER_AUTH_REJECTED", false],
    [403, "PROVIDER_AUTH_REJECTED", false],
    [404, "PROVIDER_NOT_FOUND", false],
    [429, "PROVIDER_RATE_LIMITED", true],
    [503, "PROVIDER_UNAVAILABLE", true],
    [422, "PROVIDER_RESPONSE_INVALID", false],
  ]) {
    const rejected = createRevenueCatSubscriberFetcher({
      fetchImplementation: async () => new Response(
        "private provider body",
        {status},
      ),
      secretApiKey: "r".repeat(40),
    });
    await assert.rejects(
      rejected(userId),
      (error) => error.code === code && error.retryable === retryable &&
        !error.message.includes("private"),
    );
  }
});

test("RevenueCat fetcher bounds JSON and treats network failure as retryable", async () => {
  const malformedCases = [
    new Response("{", {status: 200, headers: {"content-type": "application/json"}}),
    new Response("x".repeat(2049), {status: 200, headers: {"content-type": "application/json"}}),
    new Response("{}", {status: 200, headers: {"content-type": "text/plain"}}),
  ];
  for (const providerResponse of malformedCases) {
    const fetchSubscriber = createRevenueCatSubscriberFetcher({
      fetchImplementation: async () => providerResponse,
      maximumResponseBytes: 2048,
      secretApiKey: "r".repeat(40),
    });
    await assert.rejects(fetchSubscriber(userId), (error) =>
      error.code === "PROVIDER_RESPONSE_INVALID" && !error.retryable);
  }
  const unavailable = createRevenueCatSubscriberFetcher({
    fetchImplementation: async () => {
      throw new Error("network response with secret");
    },
    secretApiKey: "r".repeat(40),
  });
  await assert.rejects(unavailable(userId), (error) =>
    error.code === "PROVIDER_NETWORK" && error.retryable);
});

test("billing RPC invoker allows only fixed service RPCs and redacts failures", async () => {
  const calls = [];
  const invoke = createBillingReconciliationRpcInvoker({
    fetchImplementation: async (url, init) => {
      calls.push({url, init});
      return jsonResponse([]);
    },
    serviceRoleKey: "service-role-placeholder-value",
    supabaseUrl: "http://127.0.0.1:54321/",
  });
  assert.deepEqual(await invoke("claim_billing_reconciliation_jobs", {}), []);
  assert.equal(
    calls[0].url,
    "http://127.0.0.1:54321/rest/v1/rpc/claim_billing_reconciliation_jobs",
  );
  assert.equal(calls[0].init.headers.apikey, "service-role-placeholder-value");
  await assert.rejects(
    invoke("untrusted_rpc", {}),
    (error) => error.code === "RPC_UNAVAILABLE" && error.retryable,
  );

  const rejected = createBillingReconciliationRpcInvoker({
    fetchImplementation: async () => new Response("private SQL response", {status: 500}),
    serviceRoleKey: "service-role-placeholder-value",
    supabaseUrl: "http://127.0.0.1:54321",
  });
  await assert.rejects(
    rejected("schedule_due_billing_reconciliations", {}),
    (error) => error.code === "RPC_UNAVAILABLE" &&
      !error.message.includes("private"),
  );
});

function handlerFor(overrides = {}) {
  return createBillingReconciliationWorkerHandler({
    applyEvent: async () => [applyRow()],
    authorize: async (value) => value === "Bearer worker-secret",
    batchLimit: 2,
    claimJobs: async () => [],
    clock: () => asOf,
    completeJob: async () => [completionRow()],
    fetchSubscriber: async () => snapshot(),
    leaseSeconds: 60,
    mapSubscriber: createRevenueCatSubscriberMapper({entitlementId}),
    scheduleDue: async () => 0,
    staleAfterSeconds: 3600,
    workerId: () => workerId,
    ...overrides,
  });
}

function workerRequest(authorization = "Bearer worker-secret") {
  return new Request("http://local/billing-reconciliation-worker", {
    method: "POST",
    headers: {authorization},
  });
}

function claim(overrides = {}) {
  return {
    attempt_count: 1,
    auth_user_id: userId,
    environment: "sandbox",
    household_id: householdId,
    job_id: jobId,
    lease_token: leaseToken,
    provider_occurred_at: "2029-12-31T23:59:00.000Z",
    ...overrides,
  };
}

function snapshot({
  omitEntitlement = false,
  omitSubscription = false,
  originalAppUserId = userId,
  subscription = {},
} = {}) {
  const productId = "kinflow_plus_monthly";
  return {
    request_date: asOf,
    request_date_ms: Date.parse(asOf),
    subscriber: {
      entitlements: omitEntitlement ? {} : {
        [entitlementId]: {product_identifier: productId},
      },
      original_app_user_id: originalAppUserId,
      subscriptions: omitSubscription ? {} : {
        [productId]: {
          expires_date: "2030-02-01T00:00:00Z",
          is_sandbox: true,
          period_type: "normal",
          purchase_date: "2029-12-01T00:00:00Z",
          store: "play_store",
          store_transaction_id: transactionRef,
          ...subscription,
        },
      },
    },
  };
}

function applyRow(overrides = {}) {
  return {
    assignment_id: "65000000-0000-4000-8000-000000000011",
    billing_customer_id: "65000000-0000-4000-8000-000000000012",
    billing_transaction_id: "65000000-0000-4000-8000-000000000013",
    duplicate: false,
    entitlement_status: "active",
    entitlement_version: 2,
    household_id: householdId,
    plan_code: "plus",
    processing_status: "applied",
    provider_updated_at: asOf,
    receipt_id: "65000000-0000-4000-8000-000000000014",
    ...overrides,
  };
}

function completionRow(overrides = {}) {
  return {
    attempt_count: 1,
    completed_at: asOf,
    job_id: jobId,
    last_error_code: null,
    next_attempt_at: null,
    processing_status: "succeeded",
    ...overrides,
  };
}

function jsonResponse(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {"content-type": "application/json"},
  });
}
