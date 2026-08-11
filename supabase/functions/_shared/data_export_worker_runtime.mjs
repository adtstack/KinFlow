import {
  createDataExportWorkerHandler,
  DataExportWorkerFailure,
} from "./data_export_worker_contract.mjs";

export function serveDataExportWorker() {
  const supabaseUrl = requiredEnvironment("SUPABASE_URL").replace(/\/$/, "");
  const serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
  const workerSecret = requiredEnvironment("KINFLOW_DATA_EXPORT_WORKER_SECRET");
  const invoke = (name, parameters) => invokeRpc({name, parameters, serviceRoleKey, supabaseUrl});
  Deno.serve(createDataExportWorkerHandler({
    workerSecret,
    recoverGeneration: (parameters) =>
      invoke("recover_expired_data_export_generation_leases", parameters),
    recoverPurges: (parameters) =>
      invoke("recover_expired_data_export_purge_leases", parameters),
    claimGeneration: (parameters) => invoke("claim_data_export_requests", parameters),
    claimPurges: (parameters) => invoke("claim_data_export_purges", parameters),
    loadPackage: (parameters) => invoke("build_personal_data_export_package", parameters),
    uploadArtifact: (artifact) =>
      uploadArtifact({...artifact, serviceRoleKey, supabaseUrl}),
    completeGeneration: (parameters) => invoke("complete_data_export_request", parameters),
    failGeneration: (parameters) => invoke("fail_data_export_request", parameters),
    removeArtifacts: (objectKeys) =>
      removeArtifacts({objectKeys, serviceRoleKey, supabaseUrl}),
    completePurge: (parameters) => invoke("complete_data_export_purge", parameters),
    failPurge: (parameters) => invoke("fail_data_export_purge", parameters),
  }));
}

async function uploadArtifact({bytes, contentType, objectKey, serviceRoleKey, supabaseUrl}) {
  const encodedPath = objectKey.split("/").map(encodeURIComponent).join("/");
  let response;
  try {
    response = await fetch(
      `${supabaseUrl}/storage/v1/object/privacy-exports/${encodedPath}`,
      {
        method: "POST",
        headers: {
          apikey: serviceRoleKey,
          authorization: `Bearer ${serviceRoleKey}`,
          "cache-control": "no-store, max-age=0",
          "content-type": contentType,
          "x-upsert": "true",
        },
        body: bytes,
        redirect: "error",
        signal: AbortSignal.timeout(10000),
      },
    );
  } catch {
    throw new DataExportWorkerFailure("EXPORT_UPLOAD_UNAVAILABLE", true);
  }
  if (!response.ok) {
    throw new DataExportWorkerFailure("EXPORT_UPLOAD_UNAVAILABLE", response.status >= 500);
  }
}

async function removeArtifacts({objectKeys, serviceRoleKey, supabaseUrl}) {
  let response;
  try {
    response = await fetch(`${supabaseUrl}/storage/v1/object/privacy-exports`, {
      method: "DELETE",
      headers: {
        apikey: serviceRoleKey,
        authorization: `Bearer ${serviceRoleKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({prefixes: objectKeys}),
      redirect: "error",
      signal: AbortSignal.timeout(8000),
    });
  } catch {
    throw new DataExportWorkerFailure("EXPORT_PURGE_UNAVAILABLE", true);
  }
  if (!response.ok && response.status !== 404) {
    throw new DataExportWorkerFailure("EXPORT_PURGE_UNAVAILABLE", response.status >= 500);
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
      signal: AbortSignal.timeout(10000),
    });
  } catch {
    throw new DataExportWorkerFailure("EXPORT_BUILD_UNAVAILABLE", true);
  }
  const payload = await safeJson(response);
  if (response.ok) return payload;
  if (payload?.code === "KFX14") {
    throw new DataExportWorkerFailure("EXPORT_SIZE_LIMIT_EXCEEDED");
  }
  if (["KFX13", "KFX15"].includes(payload?.code)) {
    throw new DataExportWorkerFailure("PROCESSING_PRECONDITION_FAILED");
  }
  throw new DataExportWorkerFailure("EXPORT_BUILD_UNAVAILABLE", true);
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
