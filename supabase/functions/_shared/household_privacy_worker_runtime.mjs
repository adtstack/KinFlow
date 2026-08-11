import {
  createHouseholdPrivacyWorkerHandler,
  HouseholdPrivacyWorkerFailure,
} from "./household_privacy_worker_contract.mjs";

export function serveHouseholdPrivacyWorker() {
  const supabaseUrl = requiredEnvironment("SUPABASE_URL").replace(/\/$/, "");
  const serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
  const workerSecret = requiredEnvironment("KINFLOW_HOUSEHOLD_PRIVACY_WORKER_SECRET");
  const invoke = (name, parameters) =>
    invokeRpc({name, parameters, serviceRoleKey, supabaseUrl});
  Deno.serve(createHouseholdPrivacyWorkerHandler({
    workerSecret,
    recoverExports: (parameters) =>
      invoke("recover_expired_household_export_leases", parameters),
    recoverPurges: (parameters) =>
      invoke("recover_expired_household_export_purge_leases", parameters),
    recoverDeletions: (parameters) =>
      invoke("recover_expired_household_deletion_leases", parameters),
    claimExports: (parameters) => invoke("claim_household_export_requests", parameters),
    claimPurges: (parameters) => invoke("claim_household_export_purge_jobs", parameters),
    claimDeletions: (parameters) =>
      invoke("claim_household_deletion_requests", parameters),
    loadExportPackage: (parameters) => invoke("load_household_export_package", parameters),
    uploadArtifact: (artifact) =>
      uploadArtifact({...artifact, serviceRoleKey, supabaseUrl}),
    completeExport: (parameters) =>
      invoke("complete_household_export_request", parameters),
    failExport: (parameters) => invoke("fail_household_export_request", parameters),
    removeArtifacts: (objectKeys) =>
      removeArtifacts({objectKeys, serviceRoleKey, supabaseUrl}),
    completePurge: (parameters) =>
      invoke("complete_household_export_purge_job", parameters),
    failPurge: (parameters) => invoke("fail_household_export_purge_job", parameters),
    completeDeletion: (parameters) =>
      invoke("complete_household_deletion_request", parameters),
    failDeletion: (parameters) =>
      invoke("fail_household_deletion_request", parameters),
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
        signal: AbortSignal.timeout(12000),
      },
    );
  } catch {
    throw new HouseholdPrivacyWorkerFailure("EXPORT_UPLOAD_UNAVAILABLE", true);
  }
  if (!response.ok) {
    throw new HouseholdPrivacyWorkerFailure(
      "EXPORT_UPLOAD_UNAVAILABLE",
      response.status >= 500,
    );
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
    throw new HouseholdPrivacyWorkerFailure("EXPORT_PURGE_UNAVAILABLE", true);
  }
  if (!response.ok && response.status !== 404) {
    throw new HouseholdPrivacyWorkerFailure(
      "EXPORT_PURGE_UNAVAILABLE",
      response.status >= 500,
    );
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
      signal: AbortSignal.timeout(12000),
    });
  } catch {
    throw new HouseholdPrivacyWorkerFailure(defaultCode(name), true);
  }
  const payload = await safeJson(response);
  if (response.ok) return payload;
  if (payload?.code === "KHP03") {
    throw new HouseholdPrivacyWorkerFailure("OWNER_AUTHORIZATION_CHANGED");
  }
  if (payload?.code === "KHP17") {
    throw new HouseholdPrivacyWorkerFailure("HOUSEHOLD_ALREADY_DELETED");
  }
  if (["KHP02", "KHP16"].includes(payload?.code)) {
    throw new HouseholdPrivacyWorkerFailure("PROCESSING_PRECONDITION_FAILED");
  }
  throw new HouseholdPrivacyWorkerFailure(defaultCode(name), true);
}

function defaultCode(name) {
  if (name.includes("purge")) return "EXPORT_PURGE_UNAVAILABLE";
  if (name.includes("deletion")) return "HOUSEHOLD_REDACTION_UNAVAILABLE";
  return "EXPORT_BUILD_UNAVAILABLE";
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
