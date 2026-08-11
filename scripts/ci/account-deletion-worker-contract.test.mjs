import assert from "node:assert/strict";
import test from "node:test";

import {
  AccountDeletionWorkerFailure,
  accountDeletionWorkerContractVersion,
  createAccountDeletionWorkerHandler,
} from "../../supabase/functions/_shared/account_deletion_worker_contract.mjs";
import {softDeleteAuthUser} from "../../supabase/functions/_shared/account_deletion_worker_runtime.mjs";

const asOf = "2027-01-16T08:00:00.000Z";
const workerId = "76000000-0000-4000-8000-000000000001";
const requestId = "75000000-0000-4000-8000-000000000101";
const userId = "00000000-0000-4000-8000-000000000102";
const leaseToken = "76000000-0000-4000-8000-000000000002";

test("worker recovers claims tombstones soft-deletes and completes without identifier leakage", async () => {
  const calls = [];
  const response = await handlerFor({calls})(workerRequest());
  assert.equal(response.status, 200);
  const payload = await response.json();
  assert.deepEqual(payload.data, {
    recoveredRetryScheduled: 0,
    recoveredDeadLetter: 0,
    claimed: 1,
    succeeded: 1,
    retryScheduled: 0,
    deadLetter: 0,
  });
  assert.equal(payload.meta.contractVersion, accountDeletionWorkerContractVersion);
  assert.deepEqual(calls.map((entry) => entry.name), [
    "recover", "claim", "prepare", "softDelete", "complete",
  ]);
  assert.equal(calls[3].userId, userId);
  assert.deepEqual(calls[4].parameters, {
    p_as_of: asOf,
    p_lease_token: leaseToken,
    p_request_id: requestId,
  });
  assert.equal(JSON.stringify(payload).includes(userId), false);
  assert.equal(JSON.stringify(payload).includes(requestId), false);
});

test("transient Auth failure schedules DB retry and terminal rejection dead-letters", async () => {
  for (const [failure, expectedKey] of [
    [new AccountDeletionWorkerFailure("AUTH_DELETE_UNAVAILABLE", true), "retryScheduled"],
    [new AccountDeletionWorkerFailure("AUTH_DELETE_REJECTED", false), "deadLetter"],
  ]) {
    let failedParameters;
    const response = await handlerFor({
      softDeleteUser: async () => { throw failure; },
      failRequest: async (parameters) => {
        failedParameters = parameters;
        return [failureRow({
          status: failure.retryable ? "processing" : "failed",
          next_attempt_at: failure.retryable ? "2027-01-16T08:01:00Z" : null,
          failure_code: failure.retryable ? "AUTH_DELETE_UNAVAILABLE" : "AUTH_DELETE_REJECTED",
        })];
      },
    })(workerRequest());
    const payload = await response.json();
    assert.equal(payload.data[expectedKey], 1);
    assert.equal(payload.data.succeeded, 0);
    assert.equal(failedParameters.p_error_code, failure.code);
    assert.equal(failedParameters.p_retryable, failure.retryable);
  }
});

test("prepare identity mismatch never calls Auth and fails terminally", async () => {
  let authCalls = 0;
  let failure;
  const response = await handlerFor({
    prepareRequest: async () => [prepareRow({auth_user_id: "00000000-0000-4000-8000-000000000201"})],
    softDeleteUser: async () => { authCalls += 1; },
    failRequest: async (parameters) => {
      failure = parameters;
      return [failureRow({status: "failed", failure_code: parameters.p_error_code})];
    },
  })(workerRequest());
  assert.equal((await response.json()).data.deadLetter, 1);
  assert.equal(authCalls, 0);
  assert.equal(failure.p_error_code, "PROCESSING_PRECONDITION_FAILED");
  assert.equal(failure.p_retryable, false);
});

test("recovery counters are reported even when no request is due", async () => {
  const response = await handlerFor({
    recoverLeases: async () => [{retry_scheduled: 2, dead_letter: 1}],
    claimRequests: async () => [],
  })(workerRequest());
  assert.deepEqual((await response.json()).data, {
    recoveredRetryScheduled: 2,
    recoveredDeadLetter: 1,
    claimed: 0,
    succeeded: 0,
    retryScheduled: 0,
    deadLetter: 0,
  });
});

test("worker rejects wrong auth method body and malformed private claims", async () => {
  let claims = 0;
  const handler = handlerFor({claimRequests: async () => { claims += 1; return [claim()]; }});
  for (const [request, status] of [
    [workerRequest("wrong"), 401],
    [new Request("http://local/worker", {method: "GET", headers: {authorization: "Bearer worker-secret"}}), 405],
    [new Request("http://local/worker", {method: "POST", headers: {authorization: "Bearer worker-secret"}, body: "{}"}), 400],
  ]) {
    assert.equal((await handler(request)).status, status);
  }
  assert.equal(claims, 0);

  const malformed = handlerFor({claimRequests: async () => [{...claim(), private_email: "hidden"}]});
  const response = await malformed(workerRequest());
  const text = await response.text();
  assert.equal(response.status, 503);
  assert.doesNotMatch(text, /private_email|hidden/);
});

test("soft-delete adapter uses irreversible Auth Admin endpoint and treats absent user idempotently", async () => {
  const calls = [];
  for (const status of [200, 404]) {
    await softDeleteAuthUser({
      serviceRoleKey: "service-secret",
      supabaseUrl: "https://project.supabase.co/",
      userId,
      fetcher: async (url, options) => {
        calls.push({url, options});
        return new Response(null, {status});
      },
    });
  }
  assert.equal(calls.length, 2);
  assert.equal(calls[0].options.method, "DELETE");
  assert.equal(calls[0].options.headers.apikey, "service-secret");
  assert.match(calls[0].url, /\/auth\/v1\/admin\/users\/.*\?should_soft_delete=true$/);
});

test("soft-delete adapter classifies retryable and permanent responses without body leakage", async () => {
  for (const [status, code, retryable] of [
    [429, "AUTH_DELETE_UNAVAILABLE", true],
    [503, "AUTH_DELETE_UNAVAILABLE", true],
    [400, "AUTH_DELETE_REJECTED", false],
  ]) {
    await assert.rejects(
      softDeleteAuthUser({
        serviceRoleKey: "service-secret",
        supabaseUrl: "https://project.supabase.co",
        userId,
        fetcher: async () => new Response("private provider response", {status}),
      }),
      (error) => error instanceof AccountDeletionWorkerFailure &&
        error.code === code && error.retryable === retryable &&
        !error.message.includes("private"),
    );
  }
});

function handlerFor({
  calls = [],
  recoverLeases,
  claimRequests,
  prepareRequest,
  softDeleteUser,
  completeRequest,
  failRequest,
} = {}) {
  return createAccountDeletionWorkerHandler({
    workerSecret: "worker-secret",
    now: () => asOf,
    workerId: () => workerId,
    recoverLeases: recoverLeases ?? (async (parameters) => {
      calls.push({name: "recover", parameters});
      return [{retry_scheduled: 0, dead_letter: 0}];
    }),
    claimRequests: claimRequests ?? (async (parameters) => {
      calls.push({name: "claim", parameters});
      return [claim()];
    }),
    prepareRequest: prepareRequest ?? (async (parameters) => {
      calls.push({name: "prepare", parameters});
      return [prepareRow()];
    }),
    softDeleteUser: softDeleteUser ?? (async (value) => {
      calls.push({name: "softDelete", userId: value});
    }),
    completeRequest: completeRequest ?? (async (parameters) => {
      calls.push({name: "complete", parameters});
      return [completionRow()];
    }),
    failRequest: failRequest ?? (async (parameters) => {
      calls.push({name: "fail", parameters});
      return [failureRow()];
    }),
  });
}

function workerRequest(secret = "worker-secret") {
  return new Request("http://local/account-deletion-worker", {
    method: "POST",
    headers: {authorization: `Bearer ${secret}`},
  });
}

function claim(overrides = {}) {
  return {
    privacy_request_id: requestId,
    auth_user_id: userId,
    lease_token: leaseToken,
    request_version: 2,
    active_subscription_at_request: false,
    attempts: 1,
    ...overrides,
  };
}

function prepareRow(overrides = {}) {
  return {
    auth_user_id: userId,
    affected_membership_count: 1,
    erased_endpoint_count: 1,
    revoked_invite_count: 0,
    already_tombstoned: false,
    ...overrides,
  };
}

function completionRow(overrides = {}) {
  return {
    request_id: requestId,
    status: "completed",
    completed_at: asOf,
    version: 3,
    ...overrides,
  };
}

function failureRow(overrides = {}) {
  return {
    request_id: requestId,
    status: "processing",
    failure_code: "AUTH_DELETE_UNAVAILABLE",
    next_attempt_at: "2027-01-16T08:01:00Z",
    version: 3,
    ...overrides,
  };
}
