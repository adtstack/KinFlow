import {
  createInviteHandler,
  InviteRpcError,
} from "./invite_contract.mjs";
import {runtimePolicyServiceHeaders} from "./runtime_policy_headers.mjs";

export function serveInviteOperation(operation) {
  const supabaseUrl = requiredEnvironment("SUPABASE_URL").replace(/\/$/, "");
  const serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
  const apiKey = environment("SUPABASE_ANON_KEY") || serviceRoleKey;
  const allowedOrigins = (environment("KINFLOW_ALLOWED_ORIGINS") || "http://127.0.0.1:3000")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);

  const handler = createInviteHandler({
    operation,
    allowedOrigins,
    authenticate: (authorization) => authenticate({
      apiKey,
      authorization,
      supabaseUrl,
    }),
    invokeRpc: (name, parameters, runtimePolicyHeaders) => invokeRpc({
      name,
      parameters,
      runtimePolicyHeaders,
      serviceRoleKey,
      supabaseUrl,
    }),
    randomShortCode: generateInviteShortCode,
    randomToken: generateInviteToken,
    sha256Hex,
  });
  Deno.serve(handler);
}

async function authenticate({apiKey, authorization, supabaseUrl}) {
  if (!/^Bearer\s+[^\s]+$/i.test(authorization)) {
    return null;
  }
  let response;
  try {
    response = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: {apikey: apiKey, authorization},
      signal: AbortSignal.timeout(5000),
    });
  } catch {
    throw new InviteRpcError("AUTH_PROVIDER_UNAVAILABLE");
  }
  if (!response.ok) {
    return null;
  }
  const payload = await response.json();
  return typeof payload?.id === "string" ? {userId: payload.id} : null;
}

async function invokeRpc({
  name,
  parameters,
  runtimePolicyHeaders,
  serviceRoleKey,
  supabaseUrl,
}) {
  let response;
  try {
    response = await fetch(`${supabaseUrl}/rest/v1/rpc/${encodeURIComponent(name)}`, {
      method: "POST",
      headers: {
        apikey: serviceRoleKey,
        authorization: `Bearer ${serviceRoleKey}`,
        "content-type": "application/json",
        ...runtimePolicyServiceHeaders(runtimePolicyHeaders),
      },
      body: JSON.stringify(parameters),
      signal: AbortSignal.timeout(8000),
    });
  } catch {
    throw new InviteRpcError("RPC_UNAVAILABLE");
  }
  const payload = await safeJson(response);
  if (!response.ok) {
    throw new InviteRpcError(payload?.code);
  }
  return payload;
}

async function safeJson(response) {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

function generateInviteToken() {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  let binary = "";
  for (const value of bytes) {
    binary += String.fromCharCode(value);
  }
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

export function generateInviteShortCode(
  fillRandom = (bytes) => crypto.getRandomValues(bytes),
) {
  const alphabet = "23456789ABCDEFGHJKMNPQRSTVWXYZ";
  let normalized = "";
  while (normalized.length < 8) {
    const bytes = new Uint8Array(16);
    fillRandom(bytes);
    for (const value of bytes) {
      if (value >= 240) continue;
      normalized += alphabet[value % alphabet.length];
      if (normalized.length === 8) break;
    }
  }
  return `${normalized.slice(0, 4)}-${normalized.slice(4)}`;
}

async function sha256Hex(value) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
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
