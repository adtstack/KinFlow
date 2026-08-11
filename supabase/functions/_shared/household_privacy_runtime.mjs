import {
  createHouseholdPrivacyHandler,
  HouseholdPrivacyRpcError,
} from "./household_privacy_contract.mjs";

export function serveHouseholdPrivacy() {
  const supabaseUrl = requiredEnvironment("SUPABASE_URL").replace(/\/$/, "");
  const serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
  const apiKey = environment("SUPABASE_ANON_KEY") || serviceRoleKey;
  const allowedOrigins = (environment("KINFLOW_ALLOWED_ORIGINS") || "http://127.0.0.1:3000")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);
  const downloadBaseUrl = environment("KINFLOW_HOUSEHOLD_EXPORT_DOWNLOAD_URL") ||
    `${supabaseUrl}/functions/v1/household-export-download`;
  Deno.serve(createHouseholdPrivacyHandler({
    allowedOrigins,
    downloadBaseUrl,
    authenticate: (authorization) => authenticate({apiKey, authorization, supabaseUrl}),
    invokeRpc: (name, parameters) =>
      invokeRpc({name, parameters, serviceRoleKey, supabaseUrl}),
  }));
}

async function authenticate({apiKey, authorization, supabaseUrl}) {
  const match = /^Bearer\s+([^\s]+)$/i.exec(authorization);
  if (match === null) return null;
  let response;
  try {
    response = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: {apikey: apiKey, authorization},
      signal: AbortSignal.timeout(5000),
    });
  } catch {
    throw new HouseholdPrivacyRpcError("AUTH_PROVIDER_UNAVAILABLE");
  }
  if (!response.ok) return null;
  const payload = await response.json();
  if (typeof payload?.id !== "string") return null;
  return {userId: payload.id, claims: decodeVerifiedJwtPayload(match[1])};
}

function decodeVerifiedJwtPayload(token) {
  const segments = token.split(".");
  if (segments.length !== 3) return null;
  try {
    const encoded = segments[1].replaceAll("-", "+").replaceAll("_", "/");
    const padded = encoded.padEnd(Math.ceil(encoded.length / 4) * 4, "=");
    const bytes = Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
    const payload = JSON.parse(new TextDecoder().decode(bytes));
    return payload !== null && typeof payload === "object" && !Array.isArray(payload)
      ? payload
      : null;
  } catch {
    return null;
  }
}

async function invokeRpc({name, parameters, serviceRoleKey, supabaseUrl}) {
  let response;
  try {
    response = await fetch(`${supabaseUrl}/rest/v1/rpc/${encodeURIComponent(name)}`, {
      method: "POST",
      headers: {
        apikey: serviceRoleKey,
        authorization: `Bearer ${serviceRoleKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(parameters),
      signal: AbortSignal.timeout(8000),
    });
  } catch {
    throw new HouseholdPrivacyRpcError("RPC_UNAVAILABLE");
  }
  const payload = await safeJson(response);
  if (!response.ok) throw new HouseholdPrivacyRpcError(payload?.code);
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
  if (value.length === 0) throw new Error(`Missing required server environment: ${name}`);
  return value;
}
