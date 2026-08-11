import {
  BillingWebhookRpcError,
  createExactAuthorizationVerifier,
  createRevenueCatSignatureVerifier,
  createRevenueCatWebhookHandler,
} from "./billing_webhook_contract.mjs";

export function serveRevenueCatWebhook() {
  const supabaseUrl = requiredEnvironment("SUPABASE_URL");
  const serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
  const handler = createRevenueCatWebhookHandler({
    authorize: createExactAuthorizationVerifier(
      requiredEnvironment("KINFLOW_REVENUECAT_WEBHOOK_AUTHORIZATION"),
    ),
    enqueue: createBillingWebhookRpcInvoker({serviceRoleKey, supabaseUrl}),
    verifySignature: createRevenueCatSignatureVerifier({
      secret: requiredEnvironment("KINFLOW_REVENUECAT_WEBHOOK_SIGNING_SECRET"),
    }),
  });
  Deno.serve(handler);
}

export function createBillingWebhookRpcInvoker({
  fetchImplementation = globalThis.fetch,
  serviceRoleKey,
  supabaseUrl,
  timeoutMilliseconds = 8000,
}) {
  const url = normalizedSupabaseUrl(supabaseUrl);
  if (typeof serviceRoleKey !== "string" || serviceRoleKey.length < 16 ||
    typeof fetchImplementation !== "function" ||
    !Number.isSafeInteger(timeoutMilliseconds) ||
    timeoutMilliseconds < 1000 || timeoutMilliseconds > 15000) {
    throw new TypeError("Invalid billing webhook RPC configuration");
  }
  return async function enqueue(parameters) {
    if (!isPlainObject(parameters)) {
      throw new BillingWebhookRpcError("INVALID_RPC_INPUT");
    }
    let response;
    try {
      response = await fetchImplementation(
        `${url}/rest/v1/rpc/enqueue_revenuecat_webhook`,
        {
          method: "POST",
          headers: {
            apikey: serviceRoleKey,
            authorization: `Bearer ${serviceRoleKey}`,
            "content-type": "application/json",
          },
          body: JSON.stringify(parameters),
          redirect: "error",
          signal: AbortSignal.timeout(timeoutMilliseconds),
        },
      );
    } catch {
      throw new BillingWebhookRpcError("RPC_UNAVAILABLE");
    }
    const payload = await safeJson(response);
    if (!response.ok) {
      throw new BillingWebhookRpcError(payload?.code);
    }
    if (payload === null) {
      throw new BillingWebhookRpcError("INVALID_RPC_RESPONSE");
    }
    return payload;
  };
}

function requiredEnvironment(name) {
  const value = Deno.env.get(name)?.trim() ?? "";
  if (value.length === 0) {
    throw new TypeError(`Missing server environment: ${name}`);
  }
  return value;
}

function normalizedSupabaseUrl(value) {
  const candidate = typeof value === "string" ? value.trim().replace(/\/$/, "") : "";
  const url = new URL(candidate);
  if (!["http:", "https:"].includes(url.protocol) ||
    url.username.length > 0 || url.password.length > 0 ||
    url.search.length > 0 || url.hash.length > 0) {
    throw new TypeError("Invalid Supabase URL");
  }
  return url.toString().replace(/\/$/, "");
}

async function safeJson(response) {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
