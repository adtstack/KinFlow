import assert from "node:assert/strict";
import test from "node:test";

import {
  createNotificationWorkerHandler,
  createNotificationWorkerRpcInvoker,
  NotificationWorkerContractError,
  notificationWorkerContractVersion,
  runNotificationOutboxBatch,
} from "../../supabase/functions/_shared/notification_worker_contract.mjs";
import {matchesWorkerSecret} from
  "../../supabase/functions/_shared/notification_worker_runtime.mjs";

const workerId = "51000000-0000-4000-8000-000000000001";
const eventA = "51000000-0000-4000-8000-000000000101";
const eventB = "51000000-0000-4000-8000-000000000102";
const tokenA = "51000000-0000-4000-8000-000000000201";
const tokenB = "51000000-0000-4000-8000-000000000202";
const asOf = "2030-01-01T00:00:00.000Z";

test("worker claims a bounded batch and counts candidate and suppression", async () => {
  const calls = [];
  const summary = await runNotificationOutboxBatch({
    asOf,
    batchSize: 2,
    leaseSeconds: 60,
    workerId,
    invokeRpc: async (name, parameters) => {
      calls.push({name, parameters});
      if (name === "claim_chore_notification_events") {
        return [claim(eventA, tokenA), claim(eventB, tokenB)];
      }
      if (name === "materialize_chore_notification_inbox") {
        return [materialization({claimed: 2, created: 1, suppressed: 1})];
      }
      return name === "process_chore_notification_event" &&
          parameters.p_event_id === eventA
        ? [resolution(eventA, "candidate")]
        : [resolution(eventB, "suppressed")];
    },
  });

  assert.deepEqual(summary, {
    candidateCount: 1,
    claimedCount: 2,
    deadLetterCount: 0,
    inboxCancelledCount: 0,
    inboxClaimedCount: 2,
    inboxCreatedCount: 1,
    inboxDisabledCount: 0,
    inboxStaleCount: 0,
    inboxSuppressedCount: 1,
    retryScheduledCount: 0,
    suppressedCount: 1,
    unrecordedFailureCount: 0,
  });
  assert.deepEqual(calls[0], {
    name: "claim_chore_notification_events",
    parameters: {
      p_as_of: asOf,
      p_batch_size: 2,
      p_lease_seconds: 60,
      p_worker_id: workerId,
    },
  });
});

test("calendar candidate is accepted only with its canonical subject type", async () => {
  const calls = [];
  const summary = await runNotificationOutboxBatch({
    asOf,
    batchSize: 1,
    workerId,
    invokeRpc: async (name, parameters) => {
      calls.push({name, parameters});
      if (name === "claim_chore_notification_events") {
        return [claim(eventA, tokenA)];
      }
      if (name === "process_chore_notification_event") {
        return [resolution(eventA, "candidate", {
          notification_category: "calendar_event",
          subject_type: "calendar_occurrence",
        })];
      }
      return [materialization({claimed: 1, created: 1})];
    },
  });

  assert.equal(summary.candidateCount, 1);
  assert.equal(summary.retryScheduledCount, 0);
  assert.equal(
    calls.some((call) => call.name === "fail_chore_notification_event"),
    false,
  );
});

test("calendar category with a chore subject fails closed", async () => {
  const calls = [];
  const summary = await runNotificationOutboxBatch({
    asOf,
    batchSize: 1,
    workerId,
    invokeRpc: async (name, parameters) => {
      calls.push({name, parameters});
      if (name === "claim_chore_notification_events") {
        return [claim(eventA, tokenA)];
      }
      if (name === "process_chore_notification_event") {
        return [resolution(eventA, "candidate", {
          notification_category: "calendar_event",
        })];
      }
      if (name === "fail_chore_notification_event") {
        return [failure(eventA, "retry_wait")];
      }
      return [materialization()];
    },
  });

  assert.equal(summary.candidateCount, 0);
  assert.equal(summary.retryScheduledCount, 1);
  assert.equal(
    calls.some((call) => call.name === "fail_chore_notification_event"),
    true,
  );
});

test("process failure stores only a stable retry code", async () => {
  const calls = [];
  const summary = await runNotificationOutboxBatch({
    asOf,
    workerId,
    invokeRpc: async (name, parameters) => {
      calls.push({name, parameters});
      if (name === "claim_chore_notification_events") {
        return [claim(eventA, tokenA)];
      }
      if (name === "process_chore_notification_event") {
        throw new Error("provider body with private household content");
      }
      if (name === "materialize_chore_notification_inbox") {
        return [materialization()];
      }
      return [failure(eventA, "retry_wait")];
    },
  });

  assert.equal(summary.retryScheduledCount, 1);
  assert.equal(summary.unrecordedFailureCount, 0);
  assert.deepEqual(calls[2], {
    name: "fail_chore_notification_event",
    parameters: {
      p_as_of: asOf,
      p_error_code: "WORKER_PROCESSING_FAILED",
      p_event_id: eventA,
      p_lease_token: tokenA,
    },
  });
  assert.doesNotMatch(JSON.stringify(calls), /provider body|private household/i);
});

test("final-attempt failure is counted as dead letter", async () => {
  const summary = await runNotificationOutboxBatch({
    asOf,
    workerId,
    invokeRpc: async (name) => {
      if (name === "claim_chore_notification_events") {
        return [claim(eventA, tokenA, 5, 5)];
      }
      if (name === "process_chore_notification_event") {
        throw new Error("opaque");
      }
      if (name === "materialize_chore_notification_inbox") {
        return [materialization()];
      }
      return [failure(eventA, "dead_letter", 5, 5)];
    },
  });

  assert.equal(summary.deadLetterCount, 1);
  assert.equal(summary.retryScheduledCount, 0);
});

test("a failure API outage stays aggregate-only", async () => {
  const summary = await runNotificationOutboxBatch({
    asOf,
    workerId,
    invokeRpc: async (name) => {
      if (name === "claim_chore_notification_events") {
        return [claim(eventA, tokenA)];
      }
      if (name === "materialize_chore_notification_inbox") {
        return [materialization()];
      }
      throw new Error("raw transport response");
    },
  });

  assert.deepEqual(summary, {
    candidateCount: 0,
    claimedCount: 1,
    deadLetterCount: 0,
    inboxCancelledCount: 0,
    inboxClaimedCount: 0,
    inboxCreatedCount: 0,
    inboxDisabledCount: 0,
    inboxStaleCount: 0,
    inboxSuppressedCount: 0,
    retryScheduledCount: 0,
    suppressedCount: 0,
    unrecordedFailureCount: 1,
  });
  assert.doesNotMatch(JSON.stringify(summary), /transport|event/i);
});

test("claim response rejects extra content-shaped keys before processing", async () => {
  let callCount = 0;
  await assert.rejects(
    runNotificationOutboxBatch({
      asOf,
      workerId,
      invokeRpc: async () => {
        callCount += 1;
        return [{...claim(eventA, tokenA), title: "must not cross worker"}];
      },
    }),
    (error) => error instanceof NotificationWorkerContractError &&
      error.code === "INVALID_CLAIM_RESPONSE",
  );
  assert.equal(callCount, 1);
});

test("duplicate claim identities fail closed", async () => {
  await assert.rejects(
    runNotificationOutboxBatch({
      asOf,
      workerId,
      invokeRpc: async () => [claim(eventA, tokenA), claim(eventA, tokenB)],
    }),
    (error) => error.code === "INVALID_CLAIM_RESPONSE",
  );
});

test("worker bounds and UTC clock are validated locally", async () => {
  for (const input of [
    {batchSize: 0, asOf, leaseSeconds: 60, workerId},
    {batchSize: 101, asOf, leaseSeconds: 60, workerId},
    {batchSize: 1, asOf, leaseSeconds: 4, workerId},
    {batchSize: 1, asOf: "2030-01-01", leaseSeconds: 60, workerId},
    {batchSize: 1, asOf, leaseSeconds: 60, workerId: "not-a-uuid"},
  ]) {
    await assert.rejects(
      runNotificationOutboxBatch({...input, invokeRpc: async () => []}),
      (error) => error.code === "INVALID_WORKER_INPUT",
    );
  }
});

test("claim transport failure exposes only a stable contract code", async () => {
  await assert.rejects(
    runNotificationOutboxBatch({
      asOf,
      workerId,
      invokeRpc: async () => {
        throw new Error("secret-shaped response");
      },
    }),
    (error) => error instanceof NotificationWorkerContractError &&
      error.code === "CLAIM_UNAVAILABLE" &&
      !error.message.includes("secret"),
  );
});

test("PostgREST invoker sends server credentials without returning them", async () => {
  const requests = [];
  const invokeRpc = createNotificationWorkerRpcInvoker({
    serviceRoleKey: "local-service-role-placeholder",
    supabaseUrl: "http://127.0.0.1:54321/",
    fetchImplementation: async (url, init) => {
      requests.push({url, init});
      return new Response(JSON.stringify([]), {
        status: 200,
        headers: {"content-type": "application/json"},
      });
    },
  });

  assert.deepEqual(await invokeRpc("claim_chore_notification_events", {}), []);
  assert.equal(
    requests[0].url,
    "http://127.0.0.1:54321/rest/v1/rpc/claim_chore_notification_events",
  );
  assert.equal(requests[0].init.method, "POST");
  assert.equal(requests[0].init.headers.apikey, "local-service-role-placeholder");
});

test("PostgREST invoker maps provider failures without reading their body", async () => {
  const invokeRpc = createNotificationWorkerRpcInvoker({
    serviceRoleKey: "local-service-role-placeholder",
    supabaseUrl: "http://127.0.0.1:54321",
    fetchImplementation: async () => new Response(
      JSON.stringify({message: "private provider response"}),
      {status: 503},
    ),
  });

  await assert.rejects(
    invokeRpc("claim_chore_notification_events", {}),
    (error) => error.code === "RPC_REJECTED" &&
      !error.message.includes("provider"),
  );
});

test("internal Edge handler runs one deterministic aggregate-only batch", async () => {
  const calls = [];
  const handler = createNotificationWorkerHandler({
    authorizeRequest: async (authorization) =>
      authorization === "Bearer scheduler-secret",
    batchSize: 2,
    clock: () => asOf,
    invokeRpc: async (name, parameters) => {
      calls.push({name, parameters});
      if (name === "claim_chore_notification_events") {
        return [claim(eventA, tokenA)];
      }
      if (name === "materialize_chore_notification_inbox") {
        return [materialization({claimed: 1, created: 1})];
      }
      return [resolution(eventA, "candidate")];
    },
    leaseSeconds: 45,
    randomUuid: () => workerId,
  });

  const response = await handler(new Request(
    "http://local/notification-outbox-worker",
    {method: "POST", headers: {authorization: "Bearer scheduler-secret"}},
  ));
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("cache-control"), "no-store");
  const payload = await response.json();
  assert.deepEqual(payload, {
    data: {
      candidateCount: 1,
      claimedCount: 1,
      deadLetterCount: 0,
      inboxCancelledCount: 0,
      inboxClaimedCount: 1,
      inboxCreatedCount: 1,
      inboxDisabledCount: 0,
      inboxStaleCount: 0,
      inboxSuppressedCount: 0,
      retryScheduledCount: 0,
      suppressedCount: 0,
      unrecordedFailureCount: 0,
    },
    meta: {contractVersion: notificationWorkerContractVersion},
  });
  assert.deepEqual(calls[0].parameters, {
    p_as_of: asOf,
    p_batch_size: 2,
    p_lease_seconds: 45,
    p_worker_id: workerId,
  });
  assert.deepEqual(calls.at(-1), {
    name: "materialize_chore_notification_inbox",
    parameters: {p_as_of: asOf, p_batch_size: 2},
  });
  assert.equal(JSON.stringify(payload).includes(eventA), false);
  assert.equal(JSON.stringify(payload).includes(workerId), false);
});

test("internal Edge handler rejects unauthorised calls before RPC", async () => {
  let calls = 0;
  const handler = createNotificationWorkerHandler({
    authorizeRequest: async () => false,
    clock: () => asOf,
    invokeRpc: async () => {
      calls += 1;
      return [];
    },
    randomUuid: () => workerId,
  });
  const response = await handler(new Request(
    "http://local/notification-outbox-worker",
    {method: "POST", headers: {authorization: "Bearer user-session"}},
  ));
  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), {
    error: {code: "WORKER_AUTH_REQUIRED", retryable: false},
  });
  assert.equal(calls, 0);
});

test("internal Edge handler accepts only an empty POST without query input", async () => {
  const handler = createNotificationWorkerHandler({
    authorizeRequest: async () => true,
    clock: () => asOf,
    invokeRpc: async () => [],
    randomUuid: () => workerId,
  });
  const getResponse = await handler(new Request(
    "http://local/notification-outbox-worker",
  ));
  assert.equal(getResponse.status, 405);
  assert.equal(getResponse.headers.get("allow"), "POST");
  assert.equal((await handler(new Request(
    "http://local/notification-outbox-worker?batch=100",
    {method: "POST"},
  ))).status, 400);
  assert.equal((await handler(new Request(
    "http://local/notification-outbox-worker",
    {method: "POST", body: "{}"},
  ))).status, 400);
});

test("internal Edge handler maps worker failures without leaking details", async () => {
  const handler = createNotificationWorkerHandler({
    authorizeRequest: async () => true,
    clock: () => asOf,
    invokeRpc: async () => {
      throw new Error("private provider body");
    },
    randomUuid: () => workerId,
  });
  const response = await handler(new Request(
    "http://local/notification-outbox-worker",
    {method: "POST"},
  ));
  assert.equal(response.status, 503);
  const payload = await response.json();
  assert.deepEqual(payload, {
    error: {code: "WORKER_UNAVAILABLE", retryable: true},
  });
  assert.doesNotMatch(JSON.stringify(payload), /provider|private/i);
});

test("materializer response is exact, bounded, and aggregate-only", async () => {
  await assert.rejects(
    runNotificationOutboxBatch({
      asOf,
      batchSize: 1,
      workerId,
      invokeRpc: async (name) => name === "claim_chore_notification_events"
        ? []
        : [{...materialization(), source_event_id: eventA}],
    }),
    (error) => error instanceof NotificationWorkerContractError &&
      error.code === "INVALID_MATERIALIZER_RESPONSE",
  );
  await assert.rejects(
    runNotificationOutboxBatch({
      asOf,
      batchSize: 1,
      workerId,
      invokeRpc: async (name) => name === "claim_chore_notification_events"
        ? []
        : [materialization({claimed: 1, created: 1, disabled: 1})],
    }),
    (error) => error.code === "INVALID_MATERIALIZER_RESPONSE",
  );
});

test("scheduler secret comparison is exact and accepts only Bearer syntax", async () => {
  const secret = "S".repeat(32);
  assert.equal(await matchesWorkerSecret(`Bearer ${secret}`, secret), true);
  assert.equal(await matchesWorkerSecret(`bearer ${secret}`, secret), true);
  assert.equal(await matchesWorkerSecret(`Bearer ${"s".repeat(32)}`, secret), false);
  assert.equal(await matchesWorkerSecret(secret, secret), false);
  assert.equal(await matchesWorkerSecret("Bearer short", "short"), false);
});

function claim(eventId, leaseToken, attempt = 1, maximum = 5) {
  return {
    attempt,
    event_id: eventId,
    lease_expires_at: "2030-01-01T00:01:00.000Z",
    lease_token: leaseToken,
    max_attempts: maximum,
  };
}

function resolution(eventId, outcome, overrides = {}) {
  const candidate = outcome === "candidate";
  return {
    notification_category: "chore_due",
    outcome,
    recipient_member_id: candidate
      ? "30000000-0000-4000-8000-000000000101"
      : null,
    recipient_user_id: candidate
      ? "00000000-0000-4000-8000-000000000101"
      : null,
    resolved_at: asOf,
    scheduled_at: candidate ? "2030-01-02T00:00:00.000Z" : null,
    source_event_id: eventId,
    subject_id: "52000000-0000-4000-8000-000000000001",
    subject_type: "chore_occurrence",
    suppression_reason: candidate ? null : "stale_event",
    timezone: "Asia/Seoul",
    ...overrides,
  };
}

function failure(eventId, status, attempts = 1, maximum = 5) {
  return {
    attempts,
    dead_lettered_at: status === "dead_letter" ? asOf : null,
    event_id: eventId,
    max_attempts: maximum,
    next_attempt_at: status === "retry_wait"
      ? "2030-01-01T00:00:35.000Z"
      : null,
    processing_status: status,
  };
}

function materialization({
  cancelled = 0,
  claimed = 0,
  created = 0,
  disabled = 0,
  stale = 0,
  suppressed = 0,
} = {}) {
  return {
    cancelled_count: cancelled,
    captured_at: asOf,
    claimed_count: claimed,
    created_count: created,
    disabled_count: disabled,
    stale_count: stale,
    suppressed_count: suppressed,
  };
}
