import {
  AccountDeletionWorkerFailure,
  createAccountDeletionWorkerHandler,
} from "./account_deletion_worker_contract.mjs";

export function serveAccountDeletionWorker() {
  const supabaseUrl = requiredEnvironment("SUPABASE_URL").replace(/\/$/, "");
  const serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
  const workerSecret = requiredEnvironment("KINFLOW_ACCOUNT_DELETION_WORKER_SECRET");
  const invoke = (name, parameters) => invokeRpc({name, parameters, serviceRoleKey, supabaseUrl});
  Deno.serve(createAccountDeletionWorkerHandler({
    workerSecret,
    recoverLeases: (parameters) => invoke("recover_expired_account_deletion_leases", parameters),
    claimRequests: (parameters) => invoke("claim_account_deletion_requests", parameters),
    prepareRequest: (parameters) => invoke("prepare_account_deletion_request", parameters),
    softDeleteUser: (userId) => softDeleteAuthUser({serviceRoleKey, supabaseUrl, userId}),
    completeRequest: (parameters) => invoke("complete_account_deletion_request", parameters),
    failRequest: (parameters) => invoke("fail_account_deletion_request", parameters),
  }));
}

export async function softDeleteAuthUser({serviceRoleKey, supabaseUrl, userId, fetcher = fetch}) {
  let response;
  try {
    response = await fetcher(
      `${supabaseUrl.replace(/\/$/, "")}/auth/v1/admin/users/${encodeURIComponent(userId)}?should_soft_delete=true`,
      {
        method: "DELETE",
        headers: {apikey: serviceRoleKey, authorization: `Bearer ${serviceRoleKey}`},
        signal: AbortSignal.timeout(8000),
      },
    );
  } catch {
    throw new AccountDeletionWorkerFailure("AUTH_DELETE_UNAVAILABLE", true);
  }
  if (response.ok || response.status === 404) return;
  if (response.status === 408 || response.status === 425 || response.status === 429 || response.status >= 500) {
    throw new AccountDeletionWorkerFailure("AUTH_DELETE_UNAVAILABLE", true);
  }
  throw new AccountDeletionWorkerFailure("AUTH_DELETE_REJECTED", false);
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
    throw new AccountDeletionWorkerFailure("AUTH_DELETE_UNAVAILABLE", true);
  }
  const payload = await safeJson(response);
  if (response.ok) return payload;
  const mapped = switchSqlState(payload?.code);
  throw new AccountDeletionWorkerFailure(mapped.code, mapped.retryable);
}

function switchSqlState(code) {
  if (code === "KFP08") return {code: "OWNER_TRANSFER_REQUIRED", retryable: false};
  if (code === "KFP11" || code === "KFP12") {
    return {code: "PROCESSING_PRECONDITION_FAILED", retryable: false};
  }
  return {code: "AUTH_DELETE_UNAVAILABLE", retryable: true};
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
