import {
  createHouseholdExportDownloadHandler,
  HouseholdExportDownloadFailure,
} from "./household_export_download_contract.mjs";

export function serveHouseholdExportDownload() {
  const supabaseUrl = requiredEnvironment("SUPABASE_URL").replace(/\/$/, "");
  const serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
  Deno.serve(createHouseholdExportDownloadHandler({
    consumeGrant: (parameters) => invokeRpc({parameters, serviceRoleKey, supabaseUrl}),
    downloadObject: (objectKey) =>
      downloadObject({objectKey, serviceRoleKey, supabaseUrl}),
  }));
}

async function invokeRpc({parameters, serviceRoleKey, supabaseUrl}) {
  let response;
  try {
    response = await fetch(
      `${supabaseUrl}/rest/v1/rpc/consume_household_export_download_grant`,
      {
        method: "POST",
        headers: {
          apikey: serviceRoleKey,
          authorization: `Bearer ${serviceRoleKey}`,
          "content-type": "application/json",
        },
        body: JSON.stringify(parameters),
        signal: AbortSignal.timeout(5000),
      },
    );
  } catch {
    throw new HouseholdExportDownloadFailure();
  }
  const payload = await safeJson(response);
  if (!response.ok) {
    const invalid = ["KHP13", "KHP15"].includes(payload?.code);
    throw new HouseholdExportDownloadFailure(
      invalid ? "DOWNLOAD_GRANT_INVALID" : "TEMPORARILY_UNAVAILABLE",
    );
  }
  return payload;
}

async function downloadObject({objectKey, serviceRoleKey, supabaseUrl}) {
  const encodedPath = objectKey.split("/").map(encodeURIComponent).join("/");
  let response;
  try {
    response = await fetch(
      `${supabaseUrl}/storage/v1/object/privacy-exports/${encodedPath}`,
      {
        headers: {
          apikey: serviceRoleKey,
          authorization: `Bearer ${serviceRoleKey}`,
        },
        redirect: "error",
        signal: AbortSignal.timeout(8000),
      },
    );
  } catch {
    throw new HouseholdExportDownloadFailure();
  }
  if (!response.ok) throw new HouseholdExportDownloadFailure();
  const declared = Number(response.headers.get("content-length") ?? "0");
  if (Number.isFinite(declared) && declared > 20 * 1024 * 1024) {
    throw new HouseholdExportDownloadFailure();
  }
  return new Uint8Array(await response.arrayBuffer());
}

async function safeJson(response) {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

function requiredEnvironment(name) {
  const value = Deno.env.get(name)?.trim() ?? "";
  if (value.length === 0) throw new Error(`Missing required server environment: ${name}`);
  return value;
}
