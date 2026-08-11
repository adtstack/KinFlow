import {
  createMemberLifecycleHandler,
  MemberLifecycleRpcError,
} from "./member_lifecycle_contract.mjs";
import {runtimePolicyServiceHeaders} from "./runtime_policy_headers.mjs";

export function serveMemberLifecycle() {
  const supabaseUrl = requiredEnvironment("SUPABASE_URL").replace(/\/$/, "");
  const serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
  const apiKey = environment("SUPABASE_ANON_KEY") || serviceRoleKey;
  const allowedOrigins = (environment("KINFLOW_ALLOWED_ORIGINS") || "http://127.0.0.1:3000")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);

  const handler = createMemberLifecycleHandler({
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
  });
  Deno.serve(handler);
}

async function authenticate({apiKey, authorization, supabaseUrl}) {
  const match = /^Bearer\s+([^\s]+)$/i.exec(authorization);
  if (match === null) {
    return null;
  }
  let response;
  try {
    response = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: {apikey: apiKey, authorization},
      signal: AbortSignal.timeout(5000),
    });
  } catch {
    throw new MemberLifecycleRpcError("AUTH_PROVIDER_UNAVAILABLE");
  }
  if (!response.ok) {
    return null;
  }
  const payload = await response.json();
  if (typeof payload?.id !== "string") {
    return null;
  }
  return {userId: payload.id, claims: decodeVerifiedJwtPayload(match[1])};
}

function decodeVerifiedJwtPayload(token) {
  const segments = token.split(".");
  if (segments.length !== 3) {
    return null;
  }
  try {
    const base64 = segments[1].replaceAll("-", "+").replaceAll("_", "/");
    const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=");
    const bytes = Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
    const payload = JSON.parse(new TextDecoder().decode(bytes));
    return payload !== null && typeof payload === "object" && !Array.isArray(payload)
      ? payload
      : null;
  } catch {
    return null;
  }
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
    throw new MemberLifecycleRpcError("RPC_UNAVAILABLE");
  }
  const payload = await safeJson(response);
  if (!response.ok) {
    throw new MemberLifecycleRpcError(payload?.code);
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
