import assert from "node:assert/strict";
import test from "node:test";

import {
  createNotificationPushHandler,
  NotificationPushContractError,
  notificationPushContractVersion,
  notificationPushEnvelopeContractVersion,
  runNotificationPushBatch,
} from "../../supabase/functions/_shared/notification_push_contract.mjs";
import {
  createFirebaseAccessTokenProvider,
  createFirebaseServiceAccountJwtSigner,
  createFcmHttpV1Sender,
  createNotificationTokenOpener,
  parseFirebaseServiceAccount,
  parseNotificationTokenKeyring,
} from "../../supabase/functions/_shared/notification_push_runtime.mjs";
import {
  createNotificationTokenSealer,
  sha256Base64,
} from "../../supabase/functions/_shared/notification_endpoint_runtime.mjs";

const workerId = "55000000-0000-4000-8000-000000000001";
const deliveryId = "55010000-0000-4000-8000-000000000001";
const sourceEventId = "55020000-0000-4000-8000-000000000001";
const inboxItemId = "55030000-0000-4000-8000-000000000001";
const endpointId = "55040000-0000-4000-8000-000000000001";
const householdId = "20000000-0000-4000-8000-000000000101";
const subjectId = "55050000-0000-4000-8000-000000000001";
const leaseToken = "55060000-0000-4000-8000-000000000001";
const asOf = "2030-01-01T00:00:00.000Z";
const leaseExpiresAt = "2030-01-01T00:01:00.000Z";
const expiresAt = "2030-01-01T01:00:00.000Z";
const providerToken = "fcm:provider-token-value-0123456789";
const ciphertextBase64 = encodeBase64(new Uint8Array(48).fill(0x51));
const fingerprintBase64 = encodeBase64(new Uint8Array(32).fill(0x52));
const receiptHashBase64 = encodeBase64(new Uint8Array(32).fill(0x53));
const receiptName = "projects/kinflow-dev/messages/0:123456%abcdef";

test("accepted batch sends minimal routing data and stores only receipt hash", async () => {
  const calls = [];
  const sent = [];
  const summary = await runNotificationPushBatch({
    asOf,
    batchSize: 2,
    invokeRpc: async (name, parameters) => {
      calls.push({name, parameters});
      if (name === "claim_notification_push_deliveries") return [claimRow()];
      if (name === "mark_notification_push_submission_started") {
        return [submissionMarkerRow()];
      }
      return [completionRow({status: "succeeded", resultCode: "FCM_ACCEPTED"})];
    },
    leaseSeconds: 45,
    openToken: async (envelope) => {
      assert.deepEqual(envelope, {ciphertextBase64, keyVersion: 7});
      return providerToken;
    },
    sendFcm: async (context) => {
      sent.push(context);
      await context.beginSubmission();
      return {outcome: "accepted", receiptName, resultCode: "FCM_ACCEPTED"};
    },
    sha256Base64: async (value) => {
      assert.equal(value, receiptName);
      return receiptHashBase64;
    },
    workerId,
  });

  assert.deepEqual(summary, {
    acceptedCount: 1,
    ambiguousCount: 0,
    claimedCount: 1,
    endpointInvalidatedCount: 0,
    failedCount: 0,
    retryScheduledCount: 0,
    submissionStartedCount: 1,
    unrecordedCompletionCount: 0,
  });
  assert.deepEqual(calls[0], {
    name: "claim_notification_push_deliveries",
    parameters: {
      p_as_of: asOf,
      p_batch_size: 2,
      p_lease_seconds: 45,
      p_worker_id: workerId,
    },
  });
  assert.deepEqual(calls[1], {
    name: "mark_notification_push_submission_started",
    parameters: {
      p_as_of: asOf,
      p_delivery_id: deliveryId,
      p_lease_token: leaseToken,
      p_token_fingerprint_base64: fingerprintBase64,
    },
  });
  assert.deepEqual(calls[2], {
    name: "complete_notification_push_delivery",
    parameters: {
      p_as_of: asOf,
      p_delivery_id: deliveryId,
      p_lease_token: leaseToken,
      p_outcome: "accepted",
      p_provider_receipt_hash_base64: receiptHashBase64,
      p_result_code: "FCM_ACCEPTED",
      p_retry_after_seconds: null,
      p_token_fingerprint_base64: fingerprintBase64,
    },
  });
  assert.equal(sent[0].token, providerToken);
  assert.equal(typeof sent[0].beginSubmission, "function");
  const sentContext = {...sent[0]};
  delete sentContext.beginSubmission;
  assert.deepEqual(
    {...sentContext, token: "redacted"},
    {
      attempt: 1,
      category: "chore_due",
      deliveryId,
      expiresAt,
      householdId,
      inboxItemId,
      locale: "ko-KR",
      sourceEventId,
      subjectId,
      subjectType: "chore_occurrence",
      token: "redacted",
      ttlSeconds: 3600,
    },
  );
  assert.doesNotMatch(JSON.stringify(calls), /provider-token|projects\//);
});

test("calendar push claim reaches the provider with canonical routing", async () => {
  let sentContext;
  const summary = await runNotificationPushBatch({
    asOf,
    invokeRpc: async (name) => {
      if (name === "claim_notification_push_deliveries") {
        return [claimRow({
          category: "calendar_event",
          subject_type: "calendar_occurrence",
        })];
      }
      if (name === "mark_notification_push_submission_started") {
        return [submissionMarkerRow()];
      }
      return [completionRow({status: "succeeded", resultCode: "FCM_ACCEPTED"})];
    },
    openToken: async () => providerToken,
    sendFcm: async (context) => {
      sentContext = context;
      await context.beginSubmission();
      return {outcome: "accepted", receiptName, resultCode: "FCM_ACCEPTED"};
    },
    sha256Base64: async () => receiptHashBase64,
    workerId,
  });

  assert.equal(summary.acceptedCount, 1);
  assert.equal(sentContext.category, "calendar_event");
  assert.equal(sentContext.subjectType, "calendar_occurrence");
});

test("invalid token and retry outcomes remain aggregate-only", async () => {
  const outcomes = [
    {outcome: "invalid_token", resultCode: "FCM_UNREGISTERED"},
    {outcome: "retryable", resultCode: "FCM_UNAVAILABLE", retryAfterSeconds: 60},
  ];
  let completionIndex = 0;
  const summary = await runNotificationPushBatch({
    asOf,
    invokeRpc: async (name) => {
      if (name === "claim_notification_push_deliveries") {
        return [
          claimRow(),
          claimRow({
            delivery_id: "55010000-0000-4000-8000-000000000002",
            lease_token: "55060000-0000-4000-8000-000000000002",
          }),
        ];
      }
      if (name === "mark_notification_push_submission_started") {
        const markedDeliveryId = completionIndex === 0
          ? deliveryId
          : "55010000-0000-4000-8000-000000000002";
        return [submissionMarkerRow({delivery_id: markedDeliveryId})];
      }
      const current = completionIndex++;
      return [completionRow(current === 0
        ? {
          endpointInvalidated: true,
          resultCode: "FCM_UNREGISTERED",
          status: "failed",
        }
        : {
          nextAttemptAt: "2030-01-01T00:01:00.000Z",
          resultCode: "FCM_UNAVAILABLE",
          status: "retry_wait",
          deliveryId: "55010000-0000-4000-8000-000000000002",
        })];
    },
    openToken: async () => providerToken,
    sendFcm: async (context) => {
      await context.beginSubmission();
      return outcomes.shift();
    },
    sha256Base64,
    workerId,
  });

  assert.deepEqual(summary, {
    acceptedCount: 0,
    ambiguousCount: 0,
    claimedCount: 2,
    endpointInvalidatedCount: 1,
    failedCount: 1,
    retryScheduledCount: 1,
    submissionStartedCount: 2,
    unrecordedCompletionCount: 0,
  });
  const serializedSummary = JSON.stringify(summary);
  assert.doesNotMatch(serializedSummary, /[0-9a-f]{8}-[0-9a-f-]{27,}/i);
  assert.doesNotMatch(serializedSummary, /FCM_|provider-token/i);
});

test("decryption failure is finalized without invoking FCM", async () => {
  const calls = [];
  let sendCalls = 0;
  const summary = await runNotificationPushBatch({
    asOf,
    invokeRpc: async (name, parameters) => {
      calls.push({name, parameters});
      return name === "claim_notification_push_deliveries"
        ? [claimRow({
          expires_at: "2030-01-01T01:00:00+00:00",
          lease_expires_at: "2030-01-01T00:01:00+00:00",
          scheduled_at: "2030-01-01T00:00:00+00:00",
        })]
        : [completionRow({
          resultCode: "TOKEN_DECRYPTION_FAILED",
          status: "failed",
        })];
    },
    openToken: async () => {
      throw new Error("ciphertext details must not escape");
    },
    sendFcm: async () => {
      sendCalls += 1;
    },
    sha256Base64,
    workerId,
  });

  assert.equal(sendCalls, 0);
  assert.equal(summary.failedCount, 1);
  assert.equal(calls[1].parameters.p_outcome, "permanent");
  assert.equal(calls[1].parameters.p_result_code, "TOKEN_DECRYPTION_FAILED");
  assert.doesNotMatch(JSON.stringify(calls), /ciphertext details/);
});

test("provider and completion failures are bounded and non-reflective", async () => {
  let completionCalls = 0;
  const summary = await runNotificationPushBatch({
    asOf,
    invokeRpc: async (name) => {
      if (name === "claim_notification_push_deliveries") return [claimRow()];
      if (name === "mark_notification_push_submission_started") {
        return [submissionMarkerRow()];
      }
      completionCalls += 1;
      throw new Error("private database response");
    },
    openToken: async () => providerToken,
    sendFcm: async (context) => {
      await context.beginSubmission();
      throw new Error("raw provider body");
    },
    sha256Base64,
    workerId,
  });

  assert.equal(completionCalls, 1);
  assert.deepEqual(summary, {
    acceptedCount: 0,
    ambiguousCount: 1,
    claimedCount: 1,
    endpointInvalidatedCount: 0,
    failedCount: 0,
    retryScheduledCount: 0,
    submissionStartedCount: 1,
    unrecordedCompletionCount: 1,
  });
});

test("claim contract rejects extra material and duplicate identities", async () => {
  for (const rows of [
    [{...claimRow(), title: "private family content"}],
    [claimRow(), claimRow({lease_token: "55060000-0000-4000-8000-000000000002"})],
    [{...claimRow(), token_fingerprint_base64: ciphertextBase64}],
    [claimRow({category: "calendar_event"})],
    [claimRow({subject_type: "calendar_occurrence"})],
  ]) {
    await assert.rejects(
      runNotificationPushBatch({
        asOf,
        invokeRpc: async () => rows,
        openToken: async () => providerToken,
        sendFcm: async () => ({outcome: "accepted", receiptName, resultCode: "FCM_ACCEPTED"}),
        sha256Base64,
        workerId,
      }),
      (error) => error instanceof NotificationPushContractError &&
        error.code === "INVALID_CLAIM_RESPONSE" &&
        !error.message.includes("family"),
    );
  }
});

test("worker input and claim transport fail with stable codes", async () => {
  await assert.rejects(
    runNotificationPushBatch({
      asOf: "2030-01-01",
      invokeRpc: async () => [],
      openToken: async () => providerToken,
      sendFcm: async () => ({}),
      sha256Base64,
      workerId,
    }),
    (error) => error.code === "INVALID_WORKER_INPUT",
  );
  await assert.rejects(
    runNotificationPushBatch({
      asOf,
      invokeRpc: async () => {
        throw new Error("raw service response");
      },
      openToken: async () => providerToken,
      sendFcm: async () => ({}),
      sha256Base64,
      workerId,
    }),
    (error) => error.code === "CLAIM_UNAVAILABLE" &&
      !error.message.includes("service"),
  );
});

test("internal handler authenticates scheduler and returns aggregate counts", async () => {
  const handler = createNotificationPushHandler({
    authorizeRequest: async (authorization) =>
      authorization === "Bearer scheduler-secret",
    clock: () => asOf,
    invokeRpc: async (name) => name === "claim_notification_push_deliveries"
      ? []
      : assert.fail("unexpected completion"),
    openToken: async () => providerToken,
    randomUuid: () => workerId,
    sendFcm: async () => assert.fail("unexpected send"),
    sha256Base64,
  });
  const unauthorized = await handler(new Request(
    "http://local/notification-push-worker",
    {method: "POST"},
  ));
  assert.equal(unauthorized.status, 401);
  const response = await handler(new Request(
    "http://local/notification-push-worker",
    {method: "POST", headers: {authorization: "Bearer scheduler-secret"}},
  ));
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.deepEqual(await response.json(), {
    data: {
      acceptedCount: 0,
      ambiguousCount: 0,
      claimedCount: 0,
      endpointInvalidatedCount: 0,
      failedCount: 0,
      retryScheduledCount: 0,
      submissionStartedCount: 0,
      unrecordedCompletionCount: 0,
    },
    meta: {contractVersion: notificationPushContractVersion},
  });
});

test("handler rejects methods query strings and bodies", async () => {
  const handler = createNotificationPushHandler({
    authorizeRequest: async () => true,
    clock: () => asOf,
    invokeRpc: async () => [],
    openToken: async () => providerToken,
    randomUuid: () => workerId,
    sendFcm: async () => ({}),
    sha256Base64,
  });
  const method = await handler(new Request(
    "http://local/notification-push-worker",
    {method: "GET"},
  ));
  assert.equal(method.status, 405);
  assert.equal(method.headers.get("allow"), "POST");
  for (const request of [
    new Request("http://local/notification-push-worker?debug=1", {method: "POST"}),
    new Request("http://local/notification-push-worker", {method: "POST", body: "{}"}),
  ]) {
    assert.equal((await handler(request)).status, 400);
  }
});

test("versioned token opener reverses the WP05-03 AES-GCM envelope", async () => {
  const key = new Uint8Array(32).fill(0x61);
  const sealer = createNotificationTokenSealer({
    keyMaterialBase64: encodeBase64(key),
    keyVersion: 7,
    randomBytes: () => new Uint8Array(12).fill(0x62),
  });
  const sealed = await sealer(providerToken);
  const opener = createNotificationTokenOpener({
    keyMaterialsByVersion: {7: key},
  });
  assert.equal(await opener(sealed), providerToken);

  const tampered = decodeBase64(sealed.ciphertextBase64);
  tampered[tampered.length - 1] ^= 1;
  await assert.rejects(
    opener({ciphertextBase64: encodeBase64(tampered), keyVersion: 7}),
  );
  await assert.rejects(
    opener({ciphertextBase64: sealed.ciphertextBase64, keyVersion: 8}),
    /Unknown notification token key version/,
  );
});

test("token keyring accepts only bounded canonical 256-bit versions", () => {
  const key = encodeBase64(new Uint8Array(32).fill(0x63));
  const parsed = parseNotificationTokenKeyring(JSON.stringify({1: key, 7: key}));
  assert.deepEqual(Object.keys(parsed), ["1", "7"]);
  assert.equal(parsed[7].byteLength, 32);
  for (const value of [
    "not-json",
    JSON.stringify({0: key}),
    JSON.stringify({1: encodeBase64(new Uint8Array(31))}),
    JSON.stringify({1: `${key}=`}),
  ]) {
    assert.throws(() => parseNotificationTokenKeyring(value));
  }
});

test("service-account parser keeps only required server credential fields", async () => {
  const pair = await generateSigningKeyPair();
  const privateKey = pem(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  const parsed = parseFirebaseServiceAccount(JSON.stringify({
    auth_uri: "https://accounts.google.com/o/oauth2/auth",
    client_email: "push@kinflow-dev.iam.gserviceaccount.com",
    private_key: privateKey,
    private_key_id: "not-retained",
    project_id: "kinflow-dev",
    token_uri: "https://evil.example/token",
    type: "service_account",
  }));
  assert.deepEqual(Object.keys(parsed), ["clientEmail", "privateKey", "projectId"]);
  assert.equal(parsed.projectId, "kinflow-dev");
  assert.throws(() => parseFirebaseServiceAccount(JSON.stringify({
    ...parsed,
    type: "service_account",
  })));
});

test("JWT signer emits scoped one-hour RS256 service assertion", async () => {
  const pair = await generateSigningKeyPair();
  const signer = createFirebaseServiceAccountJwtSigner({
    clientEmail: "push@kinflow-dev.iam.gserviceaccount.com",
    privateKey: pem(await crypto.subtle.exportKey("pkcs8", pair.privateKey)),
  });
  const jwt = await signer(1_900_000_000);
  const [header, claims, signature] = jwt.split(".");
  assert.deepEqual(JSON.parse(decodeBase64Url(header)), {alg: "RS256", typ: "JWT"});
  assert.deepEqual(JSON.parse(decodeBase64Url(claims)), {
    aud: "https://oauth2.googleapis.com/token",
    exp: 1_900_003_600,
    iat: 1_900_000_000,
    iss: "push@kinflow-dev.iam.gserviceaccount.com",
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  });
  assert.equal(await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    pair.publicKey,
    decodeBase64UrlBytes(signature),
    new TextEncoder().encode(`${header}.${claims}`),
  ), true);
});

test("OAuth token provider posts assertion to fixed Google endpoint and caches", async () => {
  const requests = [];
  let now = 1_900_000_000;
  const provider = createFirebaseAccessTokenProvider({
    clockSeconds: () => now,
    createAssertion: async (issuedAt) => {
      assert.equal(issuedAt, now);
      return "header.claims.signature";
    },
    fetchImplementation: async (url, init) => {
      requests.push({url, init});
      return Response.json({
        access_token: "access-token-value-0123456789",
        expires_in: 3600,
        token_type: "Bearer",
      });
    },
    serviceAccount: {
      clientEmail: "push@kinflow-dev.iam.gserviceaccount.com",
      privateKey: "server-only-private-key",
      projectId: "kinflow-dev",
    },
  });
  assert.equal(await provider(), "access-token-value-0123456789");
  now += 30;
  assert.equal(await provider(), "access-token-value-0123456789");
  assert.equal(requests.length, 1);
  assert.equal(requests[0].url, "https://oauth2.googleapis.com/token");
  assert.equal(requests[0].init.method, "POST");
  const body = new URLSearchParams(requests[0].init.body);
  assert.equal(body.get("assertion"), "header.claims.signature");
  assert.equal(
    body.get("grant_type"),
    "urn:ietf:params:oauth:grant-type:jwt-bearer",
  );
});

test("OAuth rejection does not parse or reflect provider credential body", async () => {
  const provider = createFirebaseAccessTokenProvider({
    createAssertion: async () => "header.claims.signature",
    fetchImplementation: async () => Response.json(
      {error_description: "private credential diagnostic"},
      {status: 401},
    ),
    serviceAccount: {
      clientEmail: "push@kinflow-dev.iam.gserviceaccount.com",
      privateKey: "server-only-private-key",
      projectId: "kinflow-dev",
    },
  });
  await assert.rejects(
    provider(),
    (error) => !error.message.includes("credential diagnostic"),
  );
});

test("FCM sender uses Android localization keys and minimal exact data", async () => {
  const requests = [];
  const sender = createFcmHttpV1Sender({
    androidPackageName: "me.newlines.kinflow.dev",
    fetchImplementation: async (url, init) => {
      requests.push({url, init});
      return Response.json({name: receiptName});
    },
    getAccessToken: async () => "access-token-value-0123456789",
    projectId: "kinflow-dev",
  });
  assert.deepEqual(await sender(messageContext()), {
    outcome: "accepted",
    receiptName,
    resultCode: "FCM_ACCEPTED",
  });
  assert.equal(
    requests[0].url,
    "https://fcm.googleapis.com/v1/projects/kinflow-dev/messages:send",
  );
  const body = JSON.parse(requests[0].init.body);
  assert.deepEqual(body, {
    message: {
      android: {
        notification: {
          body_loc_key: "notification_push_body",
          channel_id: "kinflow_reminders",
          default_sound: true,
          tag: deliveryId,
          title_loc_key: "notification_push_title",
        },
        priority: "high",
        restricted_package_name: "me.newlines.kinflow.dev",
        ttl: "3599s",
      },
      data: {
        category: "chore_due",
        contractVersion: notificationPushEnvelopeContractVersion,
        deliveryId,
        householdId,
        inboxItemId,
        sourceEventId,
        subjectId,
        subjectType: "chore_occurrence",
      },
      token: providerToken,
    },
  });
  assert.doesNotMatch(JSON.stringify(body), /title one|description|displayName|email/i);
});

test("FCM sender accepts only canonical calendar category-subject routing", async () => {
  const requests = [];
  const sender = createFcmHttpV1Sender({
    androidPackageName: "me.newlines.kinflow.dev",
    fetchImplementation: async (_url, init) => {
      requests.push(JSON.parse(init.body));
      return Response.json({name: receiptName});
    },
    getAccessToken: async () => "access-token-value-0123456789",
    projectId: "kinflow-dev",
  });
  await sender({
    ...messageContext(),
    category: "calendar_event",
    subjectType: "calendar_occurrence",
  });
  assert.equal(requests[0].message.data.category, "calendar_event");
  assert.equal(
    requests[0].message.data.subjectType,
    "calendar_occurrence",
  );

  for (const context of [
    {...messageContext(), category: "calendar_event"},
    {...messageContext(), subjectType: "calendar_occurrence"},
  ]) {
    await assert.rejects(sender(context), /Invalid FCM message context/);
  }
  assert.equal(requests.length, 1);
});

test("FCM sender maps documented provider statuses without returning bodies", async () => {
  for (const [status, httpStatus, expected] of [
    ["UNREGISTERED", 404, {outcome: "invalid_token", resultCode: "FCM_UNREGISTERED"}],
    ["INVALID_ARGUMENT", 400, {outcome: "invalid_token", resultCode: "FCM_INVALID_ARGUMENT"}],
    ["SENDER_ID_MISMATCH", 403, {outcome: "permanent", resultCode: "FCM_SENDER_ID_MISMATCH"}],
    ["THIRD_PARTY_AUTH_ERROR", 401, {outcome: "permanent", resultCode: "FCM_THIRD_PARTY_AUTH_ERROR"}],
    ["QUOTA_EXCEEDED", 429, {outcome: "retryable", resultCode: "FCM_QUOTA_EXCEEDED", retryAfterSeconds: 121}],
    ["UNAVAILABLE", 503, {outcome: "retryable", resultCode: "FCM_UNAVAILABLE", retryAfterSeconds: 121}],
    ["INTERNAL", 500, {outcome: "retryable", resultCode: "FCM_INTERNAL", retryAfterSeconds: 121}],
  ]) {
    const sender = createFcmHttpV1Sender({
      androidPackageName: "me.newlines.kinflow",
      fetchImplementation: async () => Response.json(
        {error: {message: "private provider body", status}},
        {status: httpStatus, headers: {"retry-after": "120"}},
      ),
      getAccessToken: async () => "access-token-value-0123456789",
      projectId: "kinflow-prod",
    });
    const result = await sender(messageContext());
    assert.deepEqual(result, expected);
    assert.doesNotMatch(JSON.stringify(result), /private provider/);
  }
});

test("FCM network ambiguity and malformed success are never auto-retried", async () => {
  for (const fetchImplementation of [
    async () => {
      throw new Error("network response with token");
    },
    async () => Response.json({name: "malformed"}),
  ]) {
    const sender = createFcmHttpV1Sender({
      androidPackageName: "me.newlines.kinflow",
      fetchImplementation,
      getAccessToken: async () => "access-token-value-0123456789",
      projectId: "kinflow-prod",
    });
    const result = await sender(messageContext());
    assert.deepEqual(result, {
      outcome: "ambiguous",
      resultCode: "FCM_SUBMISSION_AMBIGUOUS",
    });
  }
});

test("batch finalizes a marked provider ambiguity without automatic resend", async () => {
  const calls = [];
  const summary = await runNotificationPushBatch({
    asOf,
    invokeRpc: async (name, parameters) => {
      calls.push({name, parameters});
      if (name === "claim_notification_push_deliveries") return [claimRow()];
      if (name === "mark_notification_push_submission_started") {
        return [submissionMarkerRow()];
      }
      assert.equal(parameters.p_outcome, "ambiguous");
      assert.equal(parameters.p_result_code, "FCM_SUBMISSION_AMBIGUOUS");
      return [completionRow({
        resultCode: "FCM_SUBMISSION_AMBIGUOUS",
        status: "failed",
      })];
    },
    openToken: async () => providerToken,
    sendFcm: async (context) => {
      await context.beginSubmission();
      throw new Error("acceptance cannot be proven");
    },
    sha256Base64,
    workerId,
  });

  assert.deepEqual(summary, {
    acceptedCount: 0,
    ambiguousCount: 1,
    claimedCount: 1,
    endpointInvalidatedCount: 0,
    failedCount: 1,
    retryScheduledCount: 0,
    submissionStartedCount: 1,
    unrecordedCompletionCount: 0,
  });
  assert.deepEqual(calls.map((call) => call.name), [
    "claim_notification_push_deliveries",
    "mark_notification_push_submission_started",
    "complete_notification_push_delivery",
  ]);
});

test("submission marker failure defers before any provider send", async () => {
  let providerSendCount = 0;
  let completionParameters;
  const summary = await runNotificationPushBatch({
    asOf,
    invokeRpc: async (name, parameters) => {
      if (name === "claim_notification_push_deliveries") return [claimRow()];
      if (name === "mark_notification_push_submission_started") {
        throw new Error("private marker failure");
      }
      completionParameters = parameters;
      return [completionRow({
        nextAttemptAt: "2030-01-01T00:01:00.000Z",
        resultCode: "FCM_UNAVAILABLE",
        status: "retry_wait",
      })];
    },
    openToken: async () => providerToken,
    sendFcm: async (context) => {
      await context.beginSubmission();
      providerSendCount += 1;
      return {outcome: "accepted", receiptName, resultCode: "FCM_ACCEPTED"};
    },
    sha256Base64,
    workerId,
  });

  assert.equal(providerSendCount, 0);
  assert.equal(completionParameters.p_outcome, "retryable");
  assert.equal(completionParameters.p_result_code, "FCM_UNAVAILABLE");
  assert.equal(summary.retryScheduledCount, 1);
  assert.equal(summary.submissionStartedCount, 0);
});

test("FCM quota fallback uses one-minute jitter and unknown 4xx aborts", async () => {
  for (const [status, responseStatus, expected] of [
    [
      "QUOTA_EXCEEDED",
      429,
      {
        outcome: "retryable",
        resultCode: "FCM_QUOTA_EXCEEDED",
        retryAfterSeconds: 61,
      },
    ],
    [
      "FAILED_PRECONDITION",
      400,
      {outcome: "permanent", resultCode: "FCM_REQUEST_REJECTED"},
    ],
  ]) {
    const sender = createFcmHttpV1Sender({
      androidPackageName: "me.newlines.kinflow",
      fetchImplementation: async () => Response.json(
        {error: {status}},
        {status: responseStatus},
      ),
      getAccessToken: async () => "access-token-value-0123456789",
      projectId: "kinflow-prod",
    });
    assert.deepEqual(await sender(messageContext()), expected);
  }
});

test("FCM send timeout floor is ten seconds and OAuth failure stays unmarked", async () => {
  assert.throws(() => createFcmHttpV1Sender({
    androidPackageName: "me.newlines.kinflow",
    fetchImplementation: async () => assert.fail("unexpected fetch"),
    getAccessToken: async () => "access-token-value-0123456789",
    projectId: "kinflow-prod",
    timeoutMilliseconds: 9999,
  }));

  let markerCount = 0;
  const sender = createFcmHttpV1Sender({
    androidPackageName: "me.newlines.kinflow",
    fetchImplementation: async () => assert.fail("unexpected fetch"),
    getAccessToken: async () => {
      throw new Error("OAuth unavailable");
    },
    projectId: "kinflow-prod",
  });
  assert.deepEqual(await sender({
    ...messageContext(),
    beginSubmission: async () => {
      markerCount += 1;
    },
  }), {
    outcome: "retryable",
    resultCode: "FCM_UNAVAILABLE",
    retryAfterSeconds: 31,
  });
  assert.equal(markerCount, 0);
});

function claimRow(overrides = {}) {
  return {
    attempt: 1,
    category: "chore_due",
    delivery_id: deliveryId,
    endpoint_id: endpointId,
    expires_at: expiresAt,
    household_id: householdId,
    inbox_item_id: inboxItemId,
    lease_expires_at: leaseExpiresAt,
    lease_token: leaseToken,
    locale: "ko-KR",
    max_attempts: 5,
    scheduled_at: asOf,
    source_event_id: sourceEventId,
    subject_id: subjectId,
    subject_type: "chore_occurrence",
    token_ciphertext_base64: ciphertextBase64,
    token_fingerprint_base64: fingerprintBase64,
    token_key_version: 7,
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
  endpointInvalidated = false,
  nextAttemptAt = null,
  resultCode,
  status,
}) {
  return {
    attempts: 1,
    completed_at: status === "retry_wait" ? null : asOf,
    delivery_id: completedDeliveryId,
    endpoint_invalidated: endpointInvalidated,
    max_attempts: 5,
    next_attempt_at: nextAttemptAt,
    processing_status: status,
    result_code: resultCode,
  };
}

function messageContext() {
  return {
    attempt: 1,
    beginSubmission: async () => {},
    category: "chore_due",
    deliveryId,
    householdId,
    inboxItemId,
    locale: "ko-KR",
    sourceEventId,
    subjectId,
    subjectType: "chore_occurrence",
    token: providerToken,
    ttlSeconds: 3599,
  };
}

async function generateSigningKeyPair() {
  return crypto.subtle.generateKey(
    {
      hash: "SHA-256",
      modulusLength: 2048,
      name: "RSASSA-PKCS1-v1_5",
      publicExponent: new Uint8Array([1, 0, 1]),
    },
    true,
    ["sign", "verify"],
  );
}

function pem(buffer) {
  const encoded = encodeBase64(new Uint8Array(buffer));
  const lines = encoded.match(/.{1,64}/g).join("\n");
  const label = ["PRIVATE", "KEY"].join(" ");
  return `-----BEGIN ${label}-----\n${lines}\n-----END ${label}-----\n`;
}

function encodeBase64(bytes) {
  let binary = "";
  for (const value of bytes) binary += String.fromCharCode(value);
  return btoa(binary);
}

function decodeBase64(value) {
  return Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
}

function decodeBase64Url(value) {
  return new TextDecoder().decode(decodeBase64UrlBytes(value));
}

function decodeBase64UrlBytes(value) {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  return decodeBase64(padded);
}
