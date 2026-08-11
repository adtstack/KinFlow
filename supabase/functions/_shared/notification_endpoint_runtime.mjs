import {
  createNotificationEndpointHandler,
  NotificationEndpointRpcError,
} from "./notification_endpoint_contract.mjs";
import {runtimePolicyServiceHeaders} from "./runtime_policy_headers.mjs";

export function serveNotificationEndpoint() {
  const supabaseUrl = requiredEnvironment("SUPABASE_URL").replace(/\/$/, "");
  const serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
  const apiKey = environment("SUPABASE_ANON_KEY") || serviceRoleKey;
  const allowedOrigins = (
    environment("KINFLOW_ALLOWED_ORIGINS") || "http://127.0.0.1:3000"
  )
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);
  const sealToken = createNotificationTokenSealer({
    keyMaterialBase64: requiredEnvironment(
      "KINFLOW_NOTIFICATION_TOKEN_ENCRYPTION_KEY",
    ),
    keyVersion: requiredPositiveIntegerEnvironment(
      "KINFLOW_NOTIFICATION_TOKEN_KEY_VERSION",
    ),
  });

  const handler = createNotificationEndpointHandler({
    allowedOrigins,
    authenticate: createNotificationEndpointAuthenticator({
      apiKey,
      supabaseUrl,
    }),
    invokeRpc: createNotificationEndpointRpcInvoker({
      serviceRoleKey,
      supabaseUrl,
    }),
    sealToken,
    sha256Base64,
  });
  Deno.serve(handler);
}

export function createNotificationTokenSealer({
  keyMaterialBase64,
  keyVersion,
  randomBytes = secureRandomBytes,
}) {
  const keyBytes = decodeCanonicalBase64(keyMaterialBase64);
  if (keyBytes.byteLength !== 32 ||
    !Number.isSafeInteger(keyVersion) ||
    keyVersion < 1 ||
    keyVersion > 1000000 ||
    typeof randomBytes !== "function") {
    throw new TypeError("Invalid notification token encryption configuration");
  }
  const keyPromise = crypto.subtle.importKey(
    "raw",
    keyBytes,
    {name: "AES-GCM"},
    false,
    ["encrypt"],
  );
  const additionalData = new TextEncoder().encode(
    `kinflow:notification-token:v${keyVersion}`,
  );

  return async function sealToken(token) {
    if (typeof token !== "string" || token.length === 0) {
      throw new TypeError("Invalid provider token");
    }
    const iv = randomBytes(12);
    if (!(iv instanceof Uint8Array) || iv.byteLength !== 12) {
      throw new TypeError("Invalid notification token nonce");
    }
    const ciphertext = new Uint8Array(await crypto.subtle.encrypt(
      {name: "AES-GCM", iv, additionalData, tagLength: 128},
      await keyPromise,
      new TextEncoder().encode(token),
    ));
    const envelope = new Uint8Array(iv.byteLength + ciphertext.byteLength);
    envelope.set(iv);
    envelope.set(ciphertext, iv.byteLength);
    return Object.freeze({
      ciphertextBase64: encodeBase64(envelope),
      keyVersion,
    });
  };
}

export async function sha256Base64(value) {
  if (typeof value !== "string") {
    throw new TypeError("Invalid digest input");
  }
  const digest = new Uint8Array(await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  ));
  return encodeBase64(digest);
}

export function createNotificationEndpointAuthenticator({
  apiKey,
  fetchImplementation = globalThis.fetch,
  supabaseUrl,
  timeoutMilliseconds = 5000,
}) {
  const url = normalizedRuntimeUrl(supabaseUrl);
  if (typeof apiKey !== "string" || apiKey.length < 16 ||
    typeof fetchImplementation !== "function" ||
    !boundedTimeout(timeoutMilliseconds)) {
    throw new TypeError("Invalid notification authentication configuration");
  }
  return async function authenticate(authorization) {
    if (!/^Bearer\s+[^\s]+$/i.test(authorization)) return null;
    let response;
    try {
      response = await fetchImplementation(`${url}/auth/v1/user`, {
        headers: {apikey: apiKey, authorization},
        signal: AbortSignal.timeout(timeoutMilliseconds),
      });
    } catch {
      throw new NotificationEndpointRpcError("AUTH_PROVIDER_UNAVAILABLE");
    }
    if (!response.ok) return null;
    try {
      const payload = await response.json();
      return typeof payload?.id === "string" ? {userId: payload.id} : null;
    } catch {
      throw new NotificationEndpointRpcError("AUTH_PROVIDER_UNAVAILABLE");
    }
  };
}

export function createNotificationEndpointRpcInvoker({
  fetchImplementation = globalThis.fetch,
  serviceRoleKey,
  supabaseUrl,
  timeoutMilliseconds = 8000,
}) {
  const url = normalizedRuntimeUrl(supabaseUrl);
  if (typeof serviceRoleKey !== "string" || serviceRoleKey.length < 16 ||
    typeof fetchImplementation !== "function" ||
    !boundedTimeout(timeoutMilliseconds)) {
    throw new TypeError("Invalid notification RPC configuration");
  }
  return async function invokeRpc(name, parameters, runtimePolicyHeaders) {
    if (!/^[a-z][a-z0-9_]{0,63}$/.test(name) ||
      parameters === null ||
      typeof parameters !== "object" ||
      Array.isArray(parameters)) {
      throw new NotificationEndpointRpcError("INVALID_RPC_INPUT");
    }
    let response;
    try {
      response = await fetchImplementation(
        `${url}/rest/v1/rpc/${encodeURIComponent(name)}`,
        {
          method: "POST",
          headers: {
            apikey: serviceRoleKey,
            authorization: `Bearer ${serviceRoleKey}`,
            "content-type": "application/json",
            ...runtimePolicyServiceHeaders(runtimePolicyHeaders),
          },
          body: JSON.stringify(parameters),
          signal: AbortSignal.timeout(timeoutMilliseconds),
        },
      );
    } catch {
      throw new NotificationEndpointRpcError("RPC_UNAVAILABLE");
    }
    const payload = await safeJson(response);
    if (!response.ok) {
      throw new NotificationEndpointRpcError(payload?.code);
    }
    if (payload === null) {
      throw new NotificationEndpointRpcError("INVALID_RPC_RESPONSE");
    }
    return payload;
  };
}

async function safeJson(response) {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

function normalizedRuntimeUrl(value) {
  const url = typeof value === "string" ? value.trim().replace(/\/$/, "") : "";
  if (!/^https?:\/\/[^\s/]+(?::\d+)?(?:\/.*)?$/i.test(url)) {
    throw new TypeError("Invalid Supabase URL");
  }
  return url;
}

function decodeCanonicalBase64(value) {
  if (typeof value !== "string" || !/^[A-Za-z0-9+/]+={0,2}$/.test(value)) {
    throw new TypeError("Invalid encryption key encoding");
  }
  let bytes;
  try {
    bytes = Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
  } catch {
    throw new TypeError("Invalid encryption key encoding");
  }
  if (encodeBase64(bytes) !== value) {
    throw new TypeError("Invalid encryption key encoding");
  }
  return bytes;
}

function encodeBase64(bytes) {
  let binary = "";
  for (const value of bytes) binary += String.fromCharCode(value);
  return btoa(binary);
}

function secureRandomBytes(length) {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return bytes;
}

function boundedTimeout(value) {
  return Number.isSafeInteger(value) && value >= 1000 && value <= 30000;
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

function requiredPositiveIntegerEnvironment(name) {
  const raw = requiredEnvironment(name);
  if (!/^[0-9]+$/.test(raw)) {
    throw new Error(`Invalid server environment: ${name}`);
  }
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value < 1 || value > 1000000) {
    throw new Error(`Invalid server environment: ${name}`);
  }
  return value;
}
