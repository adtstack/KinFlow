import assert from "node:assert/strict";
import test from "node:test";

import {
  BillingWebhookRpcError,
  billingWebhookContractVersion,
  createExactAuthorizationVerifier,
  createRevenueCatSignatureVerifier,
  createRevenueCatWebhookHandler,
  digestSha256Base64,
} from "../../supabase/functions/_shared/billing_webhook_contract.mjs";
import {
  createBillingWebhookRpcInvoker,
} from "../../supabase/functions/_shared/billing_webhook_runtime.mjs";

const asOf = "2030-01-01T00:00:00.000Z";
const timestamp = Math.floor(Date.parse(asOf) / 1000);
const authorization = "Bearer " + "a".repeat(40);
const signingSecret = "s".repeat(40);
const requestId = "64000000-0000-4000-8000-000000000001";
const eventId = "revenuecat-event-0001";
const userId = "00000000-0000-4000-8000-000000000101";
const jobId = "64000000-0000-4000-8000-000000000002";

test("signed webhook queues metadata without reflecting provider identifiers", async () => {
  const calls = [];
  const raw = JSON.stringify(webhookBody());
  const handler = handlerFor({
    enqueue: async (parameters) => {
      calls.push(parameters);
      return [enqueueRow()];
    },
  });

  const response = await handler(await signedRequest(raw));
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.equal(response.headers.get("x-request-id"), requestId);
  const payload = await response.json();
  assert.deepEqual(payload, {
    data: {accepted: true, disposition: "queued", duplicate: false},
    meta: {contractVersion: billingWebhookContractVersion, requestId},
  });
  assert.deepEqual(calls, [{
    p_api_version: "1.0",
    p_auth_user_id: userId,
    p_correlation_id: requestId,
    p_environment: "sandbox",
    p_event_type: "INITIAL_PURCHASE",
    p_provider_event_id: eventId,
    p_provider_occurred_at: "2029-12-31T23:59:00.000Z",
    p_received_at: asOf,
    p_request_hash_base64: await digestSha256Base64(new TextEncoder().encode(raw)),
    p_routing_action: "reconcile",
  }]);
  assert.doesNotMatch(JSON.stringify(payload), /revenuecat-event|000000000101/);
});

test("signature is checked against exact raw bytes before JSON parsing", async () => {
  const raw = JSON.stringify(webhookBody(), null, 2);
  const valid = await signedRequest(raw);
  assert.equal((await handlerFor()(valid)).status, 200);

  const tampered = await signedRequest(`${raw}\n`, {signedRaw: raw});
  const tamperedPayload = await (await handlerFor()(tampered)).json();
  assert.equal(tamperedPayload.error.code, "AUTHENTICATION_FAILED");

  for (const signatureHeader of [
    "",
    `t=${timestamp}`,
    `t=${timestamp},v1=${"0".repeat(64)},v1=${"0".repeat(64)}`,
    `v1=${"0".repeat(64)},x=1,t=${timestamp}`,
  ]) {
    const response = await handlerFor()(await signedRequest(raw, {signatureHeader}));
    assert.equal((await response.json()).error.code, "AUTHENTICATION_FAILED");
  }
});

test("authorization and signature timestamp both fail closed", async () => {
  const raw = JSON.stringify(webhookBody());
  const wrongAuthorization = await handlerFor()(await signedRequest(raw, {
    authorizationHeader: "Bearer " + "b".repeat(40),
  }));
  assert.equal(wrongAuthorization.status, 401);

  for (const signedTimestamp of [timestamp - 301, timestamp + 301]) {
    const response = await handlerFor()(await signedRequest(raw, {signedTimestamp}));
    assert.equal(response.status, 401);
    assert.equal((await response.json()).error.code, "AUTHENTICATION_FAILED");
  }
});

test("transport and common event validation are bounded and content free", async () => {
  const raw = JSON.stringify(webhookBody());
  const handler = handlerFor();
  const method = await handler(new Request("http://local/revenuecat-webhook", {
    method: "PUT",
  }));
  assert.equal(method.status, 405);
  assert.equal(method.headers.get("allow"), "POST");

  const query = await handler(await signedRequest(raw, {
    url: "http://local/revenuecat-webhook?debug=true",
  }));
  assert.equal(query.status, 400);

  const contentType = await handler(await signedRequest(raw, {
    contentType: "text/plain",
  }));
  assert.equal(contentType.status, 400);

  const oversized = "x".repeat(256 * 1024 + 1);
  const tooLarge = await handler(await signedRequest(oversized));
  assert.equal(tooLarge.status, 413);

  for (const invalidBody of [
    "{",
    JSON.stringify({...webhookBody(), extra: {future: true}, event: null}),
    JSON.stringify(webhookBody({id: ""})),
    JSON.stringify(webhookBody({event_timestamp_ms: Date.parse(asOf) + 86400001})),
    JSON.stringify(webhookBody({type: "initial_purchase"})),
  ]) {
    const response = await handler(await signedRequest(invalidBody));
    assert.equal(response.status, 400);
    assert.equal((await response.json()).error.code, "VALIDATION_FAILED");
  }
});

test("known ignored, manual review and future events route deterministically", async () => {
  const cases = [
    [webhookBody({type: "TEST"}), "ignore", "ignored", "ignored"],
    [webhookBody({type: "PAYWALL_IMPRESSION"}), "ignore", "ignored", "ignored"],
    [webhookBody({type: "TRANSFER"}), "manual_review", "dead_letter", "manualReview"],
    [webhookBody({type: "FUTURE_EVENT"}), "reconcile", "queued", "queued"],
    [webhookBody({app_user_id: "legacy-alias"}), "manual_review", "dead_letter", "manualReview"],
  ];
  for (const [body, action, status, disposition] of cases) {
    let parameters;
    const handler = handlerFor({
      enqueue: async (value) => {
        parameters = value;
        return [enqueueRow({processing_status: status})];
      },
    });
    const response = await handler(await signedRequest(JSON.stringify(body)));
    assert.equal(response.status, 200);
    assert.equal((await response.json()).data.disposition, disposition);
    assert.equal(parameters.p_routing_action, action);
  }
});

test("exact replay and event ID collision produce stable responses", async () => {
  const raw = JSON.stringify(webhookBody());
  const duplicate = handlerFor({
    enqueue: async () => [enqueueRow({delivery_count: 2, duplicate: true})],
  });
  const duplicatePayload = await (await duplicate(await signedRequest(raw))).json();
  assert.deepEqual(duplicatePayload.data, {
    accepted: true,
    disposition: "duplicate",
    duplicate: true,
  });

  const collision = handlerFor({
    enqueue: async () => {
      throw new BillingWebhookRpcError("KFB40");
    },
  });
  const response = await collision(await signedRequest(raw));
  assert.equal(response.status, 409);
  const text = await response.text();
  assert.equal(JSON.parse(text).error.code, "EVENT_ID_COLLISION");
  assert.doesNotMatch(text, new RegExp(eventId));
});

test("malformed database rows and outages become aggregate 503", async () => {
  for (const enqueue of [
    async () => [{...enqueueRow(), raw_payload: "private"}],
    async () => {
      throw new Error("private database response");
    },
  ]) {
    const response = await handlerFor({enqueue})(
      await signedRequest(JSON.stringify(webhookBody())),
    );
    const text = await response.text();
    assert.equal(response.status, 503);
    assert.equal(JSON.parse(text).error.code, "TEMPORARILY_UNAVAILABLE");
    assert.doesNotMatch(text, /private|raw_payload/);
  }
});

test("exact authorization verifier accepts only the configured full value", async () => {
  const verify = createExactAuthorizationVerifier(authorization);
  assert.equal(await verify(authorization), true);
  assert.equal(await verify(`${authorization} `), false);
  assert.equal(await verify(""), false);
  assert.equal(await verify("x".repeat(2049)), false);
});

test("PostgREST webhook invoker fixes URL, credentials and redacts failures", async () => {
  const calls = [];
  const invoke = createBillingWebhookRpcInvoker({
    fetchImplementation: async (url, init) => {
      calls.push({url, init});
      return new Response(JSON.stringify([enqueueRow()]), {
        status: 200,
        headers: {"content-type": "application/json"},
      });
    },
    serviceRoleKey: "service-role-placeholder-value",
    supabaseUrl: "http://127.0.0.1:54321/",
  });
  assert.deepEqual(await invoke({value: 1}), [enqueueRow()]);
  assert.equal(
    calls[0].url,
    "http://127.0.0.1:54321/rest/v1/rpc/enqueue_revenuecat_webhook",
  );
  assert.equal(calls[0].init.redirect, "error");
  assert.equal(calls[0].init.headers.apikey, "service-role-placeholder-value");

  const rejected = createBillingWebhookRpcInvoker({
    fetchImplementation: async () => new Response(
      JSON.stringify({code: "XX000", message: "private provider material"}),
      {status: 503},
    ),
    serviceRoleKey: "service-role-placeholder-value",
    supabaseUrl: "http://127.0.0.1:54321",
  });
  await assert.rejects(
    rejected({value: 1}),
    (error) => error instanceof BillingWebhookRpcError &&
      !error.message.includes("private"),
  );
});

function handlerFor(overrides = {}) {
  return createRevenueCatWebhookHandler({
    authorize: createExactAuthorizationVerifier(authorization),
    clock: () => asOf,
    enqueue: async () => [enqueueRow()],
    verifySignature: createRevenueCatSignatureVerifier({secret: signingSecret}),
    ...overrides,
  });
}

async function signedRequest(raw, {
  authorizationHeader = authorization,
  contentType = "application/json; charset=utf-8",
  signatureHeader,
  signedRaw = raw,
  signedTimestamp = timestamp,
  url = "http://local/revenuecat-webhook",
} = {}) {
  const signature = signatureHeader ?? await hmacHeader(signedRaw, signedTimestamp);
  return new Request(url, {
    method: "POST",
    headers: {
      authorization: authorizationHeader,
      "content-type": contentType,
      "x-request-id": requestId,
      "x-revenuecat-webhook-signature": signature,
    },
    body: raw,
  });
}

async function hmacHeader(raw, signedTimestamp) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(signingSecret),
    {hash: "SHA-256", name: "HMAC"},
    false,
    ["sign"],
  );
  const signature = new Uint8Array(await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${signedTimestamp}.${raw}`),
  ));
  return `t=${signedTimestamp},v1=${[...signature]
    .map((value) => value.toString(16).padStart(2, "0")).join("")}`;
}

function webhookBody(event = {}) {
  return {
    api_version: "1.0",
    event: {
      app_user_id: userId,
      environment: "SANDBOX",
      event_timestamp_ms: Date.parse("2029-12-31T23:59:00.000Z"),
      id: eventId,
      type: "INITIAL_PURCHASE",
      future_provider_field: {accepted: true},
      ...event,
    },
    future_root_field: true,
  };
}

function enqueueRow(overrides = {}) {
  return {
    delivery_count: 1,
    duplicate: false,
    job_id: jobId,
    processing_status: "queued",
    ...overrides,
  };
}
