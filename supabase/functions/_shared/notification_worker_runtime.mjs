import {
  createNotificationWorkerHandler,
  createNotificationWorkerRpcInvoker,
} from "./notification_worker_contract.mjs";

export function serveNotificationOutboxWorker() {
  const serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
  const workerSecret = requiredSecretEnvironment(
    "KINFLOW_NOTIFICATION_WORKER_SECRET",
  );
  const handler = createNotificationWorkerHandler({
    authorizeRequest: (authorization) => matchesWorkerSecret(
      authorization,
      workerSecret,
    ),
    batchSize: boundedIntegerEnvironment(
      "KINFLOW_NOTIFICATION_WORKER_BATCH_SIZE",
      20,
      1,
      100,
    ),
    invokeRpc: createNotificationWorkerRpcInvoker({
      serviceRoleKey,
      supabaseUrl: requiredEnvironment("SUPABASE_URL"),
    }),
    leaseSeconds: boundedIntegerEnvironment(
      "KINFLOW_NOTIFICATION_WORKER_LEASE_SECONDS",
      60,
      5,
      300,
    ),
  });
  Deno.serve(handler);
}

export async function matchesWorkerSecret(authorization, expectedSecret) {
  const match = /^Bearer\s+([^\s]+)$/i.exec(authorization);
  if (match === null ||
    typeof expectedSecret !== "string" ||
    expectedSecret.length < 32) {
    return false;
  }
  const [actualDigest, expectedDigest] = await Promise.all([
    sha256(match[1]),
    sha256(expectedSecret),
  ]);
  let difference = actualDigest.length ^ expectedDigest.length;
  for (let index = 0; index < actualDigest.length; index += 1) {
    difference |= actualDigest[index] ^ (expectedDigest[index] ?? 0);
  }
  return difference === 0;
}

async function sha256(value) {
  return new Uint8Array(await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  ));
}

function boundedIntegerEnvironment(name, fallback, minimum, maximum) {
  const raw = environment(name);
  if (raw.length === 0) return fallback;
  if (!/^[0-9]+$/.test(raw)) {
    throw new Error(`Invalid server environment: ${name}`);
  }
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value < minimum || value > maximum) {
    throw new Error(`Invalid server environment: ${name}`);
  }
  return value;
}

function environment(name) {
  return Deno.env.get(name)?.trim() ?? "";
}

function requiredEnvironment(name) {
  const value = environment(name);
  if (value.length === 0) {
    throw new Error(`Missing required server environment: ${name}`);
  }
  return value;
}

function requiredSecretEnvironment(name) {
  const value = requiredEnvironment(name);
  if (value.length < 32) {
    throw new Error(`Invalid server environment: ${name}`);
  }
  return value;
}
