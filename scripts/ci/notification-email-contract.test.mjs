import assert from "node:assert/strict";
import test from "node:test";

import {
  createNotificationEmailHandler,
  NotificationEmailContractError,
  notificationEmailContractVersion,
  runNotificationEmailBatch,
} from "../../supabase/functions/_shared/notification_email_contract.mjs";
import {
  createSendGridEmailSender,
  notificationEmailMessage,
  sendGridMailSendEndpoint,
} from "../../supabase/functions/_shared/notification_email_runtime.mjs";

const workerId = "5e030000-0000-4000-8000-000000000001";
const deliveryId = "5e040000-0000-4000-8000-000000000001";
const sourceEventId = "5e050000-0000-4000-8000-000000000001";
const inboxItemId = "5e060000-0000-4000-8000-000000000001";
const householdId = "20000000-0000-4000-8000-000000000101";
const subjectId = "5e070000-0000-4000-8000-000000000001";
const leaseToken = "5e080000-0000-4000-8000-000000000001";
const asOf = "2030-01-01T00:00:00.000Z";
const leaseExpiresAt = "2030-01-01T00:01:00.000Z";
const expiresAt = "2030-01-01T01:00:00.000Z";
const recipientEmail = "adult-b@local.kinflow.invalid";
const fromEmail = "reminders@local.kinflow.invalid";
const apiKey = `test-sendgrid-api-key-${"x".repeat(32)}`;
const messageId = "sendgrid-message-id.0123456789";
const messageIdHash = encodeBase64(new Uint8Array(32).fill(0x5e));

test("accepted batch marks before send and stores only the message ID digest", async () => {
  const calls = [];
  let sentContext;
  const summary = await runNotificationEmailBatch({
    asOf,
    batchSize: 2,
    invokeRpc: async (name, parameters) => {
      calls.push({name, parameters});
      if (name === "claim_notification_email_deliveries") return [claimRow()];
      if (name === "mark_notification_email_submission_started") {
        return [submissionMarkerRow()];
      }
      return [completionRow({status: "succeeded", resultCode: "EMAIL_ACCEPTED"})];
    },
    leaseSeconds: 45,
    sendEmail: async (context) => {
      sentContext = context;
      await context.beginSubmission();
      return {
        outcome: "accepted",
        providerMessageId: messageId,
        resultCode: "EMAIL_ACCEPTED",
      };
    },
    sha256Base64: async (value) => {
      assert.equal(value, messageId);
      return messageIdHash;
    },
    workerId,
  });

  assert.deepEqual(summary, emptySummary({
    acceptedCount: 1,
    claimedCount: 1,
    submissionStartedCount: 1,
  }));
  assert.deepEqual(calls, [
    {
      name: "claim_notification_email_deliveries",
      parameters: {
        p_as_of: asOf,
        p_batch_size: 2,
        p_lease_seconds: 45,
        p_worker_id: workerId,
      },
    },
    {
      name: "mark_notification_email_submission_started",
      parameters: {
        p_as_of: asOf,
        p_delivery_id: deliveryId,
        p_lease_token: leaseToken,
      },
    },
    {
      name: "complete_notification_email_delivery",
      parameters: {
        p_as_of: asOf,
        p_delivery_id: deliveryId,
        p_lease_token: leaseToken,
        p_outcome: "accepted",
        p_provider_message_id_hash_base64: messageIdHash,
        p_result_code: "EMAIL_ACCEPTED",
        p_retry_after_seconds: null,
      },
    },
  ]);
  assert.equal(sentContext.recipientEmail, recipientEmail);
  assert.deepEqual(Object.keys(sentContext).sort(), [
    "attempt",
    "beginSubmission",
    "locale",
    "recipientEmail",
  ]);
  assert.doesNotMatch(JSON.stringify(calls), /adult-b|sendgrid-message-id/);
  assert.doesNotMatch(JSON.stringify(summary), /@|5e0|EMAIL_/);
});

test("accepted response without an optional message ID stores no receipt", async () => {
  const completionParameters = [];
  let hashCalls = 0;
  const summary = await runNotificationEmailBatch({
    asOf,
    invokeRpc: async (name, parameters) => {
      if (name === "claim_notification_email_deliveries") return [claimRow()];
      if (name === "mark_notification_email_submission_started") {
        return [submissionMarkerRow()];
      }
      completionParameters.push(parameters);
      return [completionRow({status: "succeeded", resultCode: "EMAIL_ACCEPTED"})];
    },
    sendEmail: async (context) => {
      await context.beginSubmission();
      return {
        outcome: "accepted",
        providerMessageId: null,
        resultCode: "EMAIL_ACCEPTED",
      };
    },
    sha256Base64: async () => {
      hashCalls += 1;
      return messageIdHash;
    },
    workerId,
  });
  assert.equal(summary.acceptedCount, 1);
  assert.equal(hashCalls, 0);
  assert.equal(
    completionParameters[0].p_provider_message_id_hash_base64,
    null,
  );
});

test("SendGrid sender uses fixed endpoint and exact generic EN and KO payloads", async () => {
  for (const locale of ["en", "ko"]) {
    const requests = [];
    let markerCount = 0;
    const response = new Response("private provider response", {
      status: 202,
      headers: {"x-message-id": messageId},
    });
    const sender = createSendGridEmailSender({
      apiKey,
      fetchImplementation: async (url, init) => {
        requests.push({url, init});
        return response;
      },
      fromEmail,
    });
    assert.deepEqual(await sender(messageContext({
      beginSubmission: async () => {
        markerCount += 1;
      },
      locale,
    })), {
      outcome: "accepted",
      providerMessageId: messageId,
      resultCode: "EMAIL_ACCEPTED",
    });
    assert.equal(markerCount, 1);
    assert.equal(response.bodyUsed, false);
    assert.equal(requests[0].url, sendGridMailSendEndpoint);
    assert.equal(requests[0].init.method, "POST");
    assert.equal(requests[0].init.headers.authorization, `Bearer ${apiKey}`);
    assert.deepEqual(JSON.parse(requests[0].init.body), {
      content: [{
        type: "text/plain",
        value: notificationEmailMessage(locale).text,
      }],
      from: {email: fromEmail, name: "KinFlow"},
      personalizations: [{to: [{email: recipientEmail}]}],
      subject: notificationEmailMessage(locale).subject,
    });
    assert.doesNotMatch(
      requests[0].init.body,
      /household|sourceEvent|subjectId|inboxItem|custom_args|attachments|html/i,
    );
  }
});

test("SendGrid completed statuses map without reading provider bodies", async () => {
  for (const [status, expected] of [
    [429, retryResult("EMAIL_RATE_LIMITED", 60)],
    [500, retryResult("EMAIL_PROVIDER_INTERNAL", 60)],
    [502, retryResult("EMAIL_PROVIDER_UNAVAILABLE", 60)],
    [503, retryResult("EMAIL_PROVIDER_UNAVAILABLE", 60)],
    [504, retryResult("EMAIL_PROVIDER_UNAVAILABLE", 60)],
    [401, permanentResult("EMAIL_AUTH_REJECTED")],
    [403, permanentResult("EMAIL_AUTH_REJECTED")],
    [400, permanentResult("EMAIL_PAYLOAD_REJECTED")],
    [413, permanentResult("EMAIL_PAYLOAD_REJECTED")],
    [404, permanentResult("EMAIL_REQUEST_REJECTED")],
    [501, permanentResult("EMAIL_REQUEST_REJECTED")],
  ]) {
    const response = new Response("private provider diagnostic", {status});
    const sender = createSendGridEmailSender({
      apiKey,
      fetchImplementation: async () => response,
      fromEmail,
    });
    assert.deepEqual(await sender(messageContext()), expected);
    assert.equal(response.bodyUsed, false);
    assert.doesNotMatch(JSON.stringify(expected), /private provider/);
  }
});

test("retry delays follow the exact bounded attempt schedule", async () => {
  for (const [attempt, retryAfterSeconds] of [
    [1, 60],
    [2, 300],
    [3, 1800],
    [4, 7200],
    [5, 7200],
  ]) {
    const sender = createSendGridEmailSender({
      apiKey,
      fetchImplementation: async () => new Response(null, {status: 503}),
      fromEmail,
    });
    assert.deepEqual(await sender(messageContext({attempt})), {
      outcome: "retryable",
      resultCode: "EMAIL_PROVIDER_UNAVAILABLE",
      retryAfterSeconds,
    });
  }
});

test("network failure after the marker is terminally ambiguous", async () => {
  let markerCount = 0;
  const sender = createSendGridEmailSender({
    apiKey,
    fetchImplementation: async () => {
      throw new Error("private network diagnostic");
    },
    fromEmail,
  });
  assert.deepEqual(await sender(messageContext({
    beginSubmission: async () => {
      markerCount += 1;
    },
  })), {
    outcome: "ambiguous",
    resultCode: "EMAIL_SUBMISSION_AMBIGUOUS",
  });
  assert.equal(markerCount, 1);
});

test("malformed success receipt and digest failure become terminal ambiguity", async () => {
  const sender = createSendGridEmailSender({
    apiKey,
    fetchImplementation: async () => new Response(null, {
      status: 202,
      headers: {"x-message-id": "contains whitespace"},
    }),
    fromEmail,
  });
  assert.deepEqual(await sender(messageContext()), {
    outcome: "ambiguous",
    resultCode: "EMAIL_SUBMISSION_AMBIGUOUS",
  });

  let completion;
  const summary = await runNotificationEmailBatch({
    asOf,
    invokeRpc: async (name, parameters) => {
      if (name === "claim_notification_email_deliveries") return [claimRow()];
      if (name === "mark_notification_email_submission_started") {
        return [submissionMarkerRow()];
      }
      completion = parameters;
      return [completionRow({
        status: "failed",
        resultCode: "EMAIL_SUBMISSION_AMBIGUOUS",
      })];
    },
    sendEmail: async (context) => {
      await context.beginSubmission();
      return {
        outcome: "accepted",
        providerMessageId: messageId,
        resultCode: "EMAIL_ACCEPTED",
      };
    },
    sha256Base64: async () => "not-a-digest",
    workerId,
  });
  assert.equal(summary.ambiguousCount, 1);
  assert.equal(summary.failedCount, 1);
  assert.equal(completion.p_outcome, "ambiguous");
  assert.equal(completion.p_provider_message_id_hash_base64, null);
});

test("submission marker failure defers before any provider network call", async () => {
  let providerCalls = 0;
  const sender = createSendGridEmailSender({
    apiKey,
    fetchImplementation: async () => {
      providerCalls += 1;
      return new Response(null, {status: 202});
    },
    fromEmail,
  });
  let completion;
  const summary = await runNotificationEmailBatch({
    asOf,
    invokeRpc: async (name, parameters) => {
      if (name === "claim_notification_email_deliveries") return [claimRow()];
      if (name === "mark_notification_email_submission_started") {
        throw new Error("private database response");
      }
      completion = parameters;
      return [completionRow({
        nextAttemptAt: "2030-01-01T00:01:00.000Z",
        status: "retry_wait",
        resultCode: "EMAIL_PROVIDER_UNAVAILABLE",
      })];
    },
    sendEmail: sender,
    sha256Base64: async () => messageIdHash,
    workerId,
  });
  assert.equal(providerCalls, 0);
  assert.equal(completion.p_outcome, "retryable");
  assert.equal(completion.p_retry_after_seconds, 60);
  assert.deepEqual(summary, emptySummary({
    claimedCount: 1,
    retryScheduledCount: 1,
  }));
});

test("claim parser accepts all canonical category-subject pairs", async () => {
  let sendCount = 0;
  const rows = [
    claimRow(),
    claimRow({
      category: "chore_assignment",
      delivery_id: "5e040000-0000-4000-8000-000000000002",
      lease_token: "5e080000-0000-4000-8000-000000000002",
      source_event_id: "5e050000-0000-4000-8000-000000000002",
    }),
    claimRow({
      category: "calendar_event",
      delivery_id: "5e040000-0000-4000-8000-000000000003",
      lease_token: "5e080000-0000-4000-8000-000000000003",
      source_event_id: "5e050000-0000-4000-8000-000000000003",
      subject_type: "calendar_occurrence",
    }),
  ];
  let markerIndex = 0;
  let completionIndex = 0;
  const summary = await runNotificationEmailBatch({
    asOf,
    invokeRpc: async (name) => {
      if (name === "claim_notification_email_deliveries") return rows;
      if (name === "mark_notification_email_submission_started") {
        return [submissionMarkerRow({
          delivery_id: rows[markerIndex++].delivery_id,
        })];
      }
      return [completionRow({
        deliveryId: rows[completionIndex++].delivery_id,
        status: "succeeded",
        resultCode: "EMAIL_ACCEPTED",
      })];
    },
    sendEmail: async (context) => {
      sendCount += 1;
      await context.beginSubmission();
      return {
        outcome: "accepted",
        providerMessageId: null,
        resultCode: "EMAIL_ACCEPTED",
      };
    },
    sha256Base64: async () => messageIdHash,
    workerId,
  });
  assert.equal(sendCount, 3);
  assert.equal(summary.acceptedCount, 3);
});

test("claim parser rejects extra content malformed identity and duplicate sources", async () => {
  for (const rows of [
    [{...claimRow(), title: "private family title"}],
    [claimRow({recipient_email: "line-break\n@example.invalid"})],
    [claimRow({locale: "ko-KR"})],
    [claimRow({category: "calendar_event"})],
    [claimRow({subject_type: "calendar_occurrence"})],
    [claimRow({expires_at: "2030-01-01T01:00:01.000Z"})],
    [claimRow(), claimRow({
      delivery_id: "5e040000-0000-4000-8000-000000000002",
      lease_token: "5e080000-0000-4000-8000-000000000002",
    })],
  ]) {
    await assert.rejects(
      runNotificationEmailBatch({
        asOf,
        invokeRpc: async () => rows,
        sendEmail: async () => assert.fail("unexpected send"),
        sha256Base64: async () => messageIdHash,
        workerId,
      }),
      (error) => error instanceof NotificationEmailContractError &&
        error.code === "INVALID_CLAIM_RESPONSE" &&
        !error.message.includes("family"),
    );
  }
});

test("provider and completion failures stay stable and aggregate-only", async () => {
  const summary = await runNotificationEmailBatch({
    asOf,
    invokeRpc: async (name) => {
      if (name === "claim_notification_email_deliveries") return [claimRow()];
      if (name === "mark_notification_email_submission_started") {
        return [submissionMarkerRow()];
      }
      throw new Error("private completion body");
    },
    sendEmail: async (context) => {
      await context.beginSubmission();
      throw new Error(`provider echoed ${recipientEmail}`);
    },
    sha256Base64: async () => messageIdHash,
    workerId,
  });
  assert.deepEqual(summary, emptySummary({
    ambiguousCount: 1,
    claimedCount: 1,
    submissionStartedCount: 1,
    unrecordedCompletionCount: 1,
  }));
  assert.doesNotMatch(JSON.stringify(summary), /provider|@|EMAIL_/i);
});

test("internal handler authenticates exact empty POST and returns aggregates", async () => {
  const handler = createNotificationEmailHandler({
    authorizeRequest: async (authorization) =>
      authorization === "Bearer scheduler-secret",
    clock: () => asOf,
    invokeRpc: async (name) => name === "claim_notification_email_deliveries"
      ? []
      : assert.fail("unexpected RPC"),
    randomUuid: () => workerId,
    sendEmail: async () => assert.fail("unexpected send"),
    sha256Base64: async () => messageIdHash,
  });
  const unauthorized = await handler(new Request(
    "http://local/notification-email-worker",
    {method: "POST"},
  ));
  assert.equal(unauthorized.status, 401);
  const response = await handler(new Request(
    "http://local/notification-email-worker",
    {method: "POST", headers: {authorization: "Bearer scheduler-secret"}},
  ));
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.deepEqual(await response.json(), {
    data: emptySummary(),
    meta: {contractVersion: notificationEmailContractVersion},
  });

  const method = await handler(new Request(
    "http://local/notification-email-worker",
    {method: "GET"},
  ));
  assert.equal(method.status, 405);
  assert.equal(method.headers.get("allow"), "POST");
  for (const request of [
    new Request("http://local/notification-email-worker?debug=1", {method: "POST"}),
    new Request("http://local/notification-email-worker", {method: "POST", body: "{}"}),
  ]) {
    assert.equal((await handler(request)).status, 400);
  }
});

test("sender configuration and context reject credential or address injection", async () => {
  for (const configuration of [
    {apiKey: "short", fromEmail},
    {apiKey, fromEmail: "bad\n@example.invalid"},
    {apiKey, fromEmail: "missing-at.invalid"},
  ]) {
    assert.throws(() => createSendGridEmailSender(configuration));
  }
  const sender = createSendGridEmailSender({
    apiKey,
    fetchImplementation: async () => assert.fail("unexpected fetch"),
    fromEmail,
  });
  for (const context of [
    {...messageContext(), deliveryId},
    messageContext({locale: "en-US"}),
    messageContext({recipientEmail: "victim@example.invalid\nBcc:x@example.invalid"}),
  ]) {
    await assert.rejects(sender(context), /Invalid SendGrid message context/);
  }
});

function claimRow(overrides = {}) {
  return {
    attempt: 1,
    category: "chore_due",
    delivery_id: deliveryId,
    expires_at: expiresAt,
    household_id: householdId,
    inbox_item_id: inboxItemId,
    lease_expires_at: leaseExpiresAt,
    lease_token: leaseToken,
    locale: "ko",
    max_attempts: 5,
    recipient_email: recipientEmail,
    scheduled_at: asOf,
    source_event_id: sourceEventId,
    subject_id: subjectId,
    subject_type: "chore_occurrence",
    ...overrides,
  };
}

function submissionMarkerRow(overrides = {}) {
  return {
    delivery_id: deliveryId,
    submission_started_at: asOf,
    ...overrides,
  };
}

function completionRow({
  deliveryId: completedDeliveryId = deliveryId,
  nextAttemptAt = null,
  resultCode,
  status,
}) {
  return {
    attempts: 1,
    completed_at: status === "retry_wait" ? null : asOf,
    delivery_id: completedDeliveryId,
    max_attempts: 5,
    next_attempt_at: nextAttemptAt,
    processing_status: status,
    result_code: resultCode,
  };
}

function messageContext(overrides = {}) {
  return {
    attempt: 1,
    beginSubmission: async () => {},
    locale: "ko",
    recipientEmail,
    ...overrides,
  };
}

function emptySummary(overrides = {}) {
  return {
    acceptedCount: 0,
    ambiguousCount: 0,
    claimedCount: 0,
    failedCount: 0,
    retryScheduledCount: 0,
    submissionStartedCount: 0,
    unrecordedCompletionCount: 0,
    ...overrides,
  };
}

function retryResult(resultCode, retryAfterSeconds) {
  return {outcome: "retryable", resultCode, retryAfterSeconds};
}

function permanentResult(resultCode) {
  return {outcome: "permanent", resultCode};
}

function encodeBase64(bytes) {
  let binary = "";
  for (const value of bytes) binary += String.fromCharCode(value);
  return btoa(binary);
}
