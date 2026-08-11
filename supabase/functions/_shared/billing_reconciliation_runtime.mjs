import {
  BillingReconciliationFailure,
  createBillingReconciliationWorkerHandler,
  createRevenueCatSubscriberMapper,
} from "./billing_reconciliation_contract.mjs";
import {createExactAuthorizationVerifier} from "./billing_webhook_contract.mjs";

const revenueCatSubscriberEndpoint =
  "https://api.revenuecat.com/v1/subscribers";
const rpcNames = new Set([
  "apply_verified_billing_event",
  "claim_billing_reconciliation_jobs",
  "complete_billing_reconciliation_job",
  "schedule_due_billing_reconciliations",
]);
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function serveBillingReconciliationWorker() {
  const serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
  const rpc = createBillingReconciliationRpcInvoker({
    serviceRoleKey,
    supabaseUrl: requiredEnvironment("SUPABASE_URL"),
  });
  const handler = createBillingReconciliationWorkerHandler({
    applyEvent: (parameters) => rpc(
      "apply_verified_billing_event",
      parameters,
    ),
    authorize: createExactAuthorizationVerifier(
      `Bearer ${requiredSecretEnvironment(
        "KINFLOW_BILLING_RECONCILIATION_WORKER_SECRET",
      )}`,
    ),
    batchLimit: boundedIntegerEnvironment(
      "KINFLOW_BILLING_RECONCILIATION_BATCH_LIMIT",
      50,
      1,
      100,
    ),
    claimJobs: (parameters) => rpc(
      "claim_billing_reconciliation_jobs",
      parameters,
    ),
    completeJob: (parameters) => rpc(
      "complete_billing_reconciliation_job",
      parameters,
    ),
    fetchSubscriber: createRevenueCatSubscriberFetcher({
      secretApiKey: requiredSecretEnvironment(
        "KINFLOW_REVENUECAT_SECRET_API_KEY",
      ),
    }),
    leaseSeconds: boundedIntegerEnvironment(
      "KINFLOW_BILLING_RECONCILIATION_LEASE_SECONDS",
      120,
      5,
      300,
    ),
    mapSubscriber: createRevenueCatSubscriberMapper({
      entitlementId: requiredEnvironment("KINFLOW_REVENUECAT_ENTITLEMENT_ID"),
    }),
    scheduleDue: (parameters) => rpc(
      "schedule_due_billing_reconciliations",
      parameters,
    ),
    staleAfterSeconds: boundedIntegerEnvironment(
      "KINFLOW_BILLING_RECONCILIATION_STALE_SECONDS",
      3600,
      300,
      86400,
    ),
  });
  Deno.serve(handler);
}

export function createBillingReconciliationRpcInvoker({
  fetchImplementation = globalThis.fetch,
  serviceRoleKey,
  supabaseUrl,
  timeoutMilliseconds = 8000,
}) {
  const url = normalizedSupabaseUrl(supabaseUrl);
  if (typeof serviceRoleKey !== "string" || serviceRoleKey.length < 16 ||
    typeof fetchImplementation !== "function" ||
    !integerBetween(timeoutMilliseconds, 1000, 15000)) {
    throw new TypeError("Invalid billing reconciliation RPC configuration");
  }
  return async function invokeBillingRpc(name, parameters) {
    if (!rpcNames.has(name) || !isPlainObject(parameters)) {
      throw new BillingReconciliationFailure("RPC_UNAVAILABLE", true);
    }
    let response;
    try {
      response = await fetchImplementation(`${url}/rest/v1/rpc/${name}`, {
        method: "POST",
        headers: {
          apikey: serviceRoleKey,
          authorization: `Bearer ${serviceRoleKey}`,
          "content-type": "application/json",
        },
        body: JSON.stringify(parameters),
        redirect: "error",
        signal: AbortSignal.timeout(timeoutMilliseconds),
      });
    } catch {
      throw new BillingReconciliationFailure("RPC_UNAVAILABLE", true);
    }
    if (!response.ok) {
      throw new BillingReconciliationFailure("RPC_UNAVAILABLE", true);
    }
    try {
      return await readBoundedJson(response, 1024 * 1024);
    } catch {
      throw new BillingReconciliationFailure("RPC_UNAVAILABLE", true);
    }
  };
}

export function createRevenueCatSubscriberFetcher({
  fetchImplementation = globalThis.fetch,
  maximumResponseBytes = 1024 * 1024,
  secretApiKey,
  timeoutMilliseconds = 8000,
}) {
  if (typeof fetchImplementation !== "function" ||
    typeof secretApiKey !== "string" || secretApiKey.length < 32 ||
    !/^[\x21-\x7e]+$/.test(secretApiKey) ||
    !integerBetween(maximumResponseBytes, 1024, 2 * 1024 * 1024) ||
    !integerBetween(timeoutMilliseconds, 1000, 15000)) {
    throw new TypeError("Invalid RevenueCat subscriber configuration");
  }
  return async function fetchSubscriber(appUserId) {
    if (typeof appUserId !== "string" || !uuidPattern.test(appUserId)) {
      throw new BillingReconciliationFailure("PROVIDER_IDENTITY_MISMATCH");
    }
    let response;
    try {
      response = await fetchImplementation(
        `${revenueCatSubscriberEndpoint}/${encodeURIComponent(
          appUserId.toLowerCase(),
        )}`,
        {
          method: "GET",
          headers: {
            accept: "application/json",
            authorization: `Bearer ${secretApiKey}`,
          },
          redirect: "error",
          signal: AbortSignal.timeout(timeoutMilliseconds),
        },
      );
    } catch {
      throw new BillingReconciliationFailure("PROVIDER_NETWORK", true);
    }
    if (response.status === 401 || response.status === 403) {
      throw new BillingReconciliationFailure("PROVIDER_AUTH_REJECTED");
    }
    if (response.status === 404) {
      throw new BillingReconciliationFailure("PROVIDER_NOT_FOUND");
    }
    if (response.status === 408 || response.status === 429 ||
      response.status >= 500 && response.status <= 599) {
      throw new BillingReconciliationFailure(
        response.status === 429
          ? "PROVIDER_RATE_LIMITED"
          : "PROVIDER_UNAVAILABLE",
        true,
      );
    }
    if (!response.ok) {
      throw new BillingReconciliationFailure("PROVIDER_RESPONSE_INVALID");
    }
    const contentType = response.headers.get("content-type");
    if (contentType !== null &&
      !/^application\/json(?:\s*;\s*charset=utf-8)?$/i.test(contentType.trim())) {
      throw new BillingReconciliationFailure("PROVIDER_RESPONSE_INVALID");
    }
    try {
      return await readBoundedJson(response, maximumResponseBytes);
    } catch {
      throw new BillingReconciliationFailure("PROVIDER_RESPONSE_INVALID");
    }
  };
}

async function readBoundedJson(response, maximumBytes) {
  const declared = response.headers.get("content-length");
  if (declared !== null &&
    (!/^[0-9]{1,10}$/.test(declared) || Number(declared) > maximumBytes)) {
    throw new TypeError("Invalid bounded JSON response");
  }
  if (response.body === null) {
    throw new TypeError("Invalid bounded JSON response");
  }
  const reader = response.body.getReader();
  const chunks = [];
  let length = 0;
  try {
    while (true) {
      const {done, value} = await reader.read();
      if (done) break;
      if (!(value instanceof Uint8Array)) {
        throw new TypeError("Invalid bounded JSON response");
      }
      length += value.byteLength;
      if (length > maximumBytes) {
        await reader.cancel();
        throw new TypeError("Invalid bounded JSON response");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  const text = new TextDecoder("utf-8", {fatal: true}).decode(bytes);
  return JSON.parse(text);
}

function boundedIntegerEnvironment(name, fallback, minimum, maximum) {
  const raw = environment(name);
  if (raw.length === 0) return fallback;
  if (!/^[0-9]+$/.test(raw)) {
    throw new TypeError(`Invalid server environment: ${name}`);
  }
  const value = Number(raw);
  if (!integerBetween(value, minimum, maximum)) {
    throw new TypeError(`Invalid server environment: ${name}`);
  }
  return value;
}

function environment(name) {
  return Deno.env.get(name)?.trim() ?? "";
}

function requiredEnvironment(name) {
  const value = environment(name);
  if (value.length === 0) {
    throw new TypeError(`Missing server environment: ${name}`);
  }
  return value;
}

function requiredSecretEnvironment(name) {
  const value = requiredEnvironment(name);
  if (value.length < 32 || value.length > 4096 || !/^[\x21-\x7e]+$/.test(value)) {
    throw new TypeError(`Invalid server environment: ${name}`);
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

function integerBetween(value, minimum, maximum) {
  return Number.isSafeInteger(value) && value >= minimum && value <= maximum;
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
