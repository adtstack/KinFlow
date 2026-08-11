import assert from "node:assert/strict";
import {describe, test} from "node:test";

import {
  createHouseholdPrivacyWorkerHandler,
  HouseholdPrivacyWorkerFailure,
  householdPrivacyWorkerContractVersion,
  renderHouseholdExport,
} from "../../supabase/functions/_shared/household_privacy_worker_contract.mjs";

const workerSecret = "household-privacy-worker-secret";
const requestId = "70000000-0000-4000-8000-000000000101";
const workerId = "71000000-0000-4000-8000-000000000101";
const exportRequestId = "72000000-0000-4000-8000-000000000101";
const deletionRequestId = "72000000-0000-4000-8000-000000000102";
const exportId = "73000000-0000-4000-8000-000000000101";
const householdId = "20000000-0000-4000-8000-000000000101";
const exportLease = "75000000-0000-4000-8000-000000000101";
const purgeLease = "76000000-0000-4000-8000-000000000101";
const deletionLease = "77000000-0000-4000-8000-000000000101";
const asOf = "2027-01-15T08:00:00Z";
const leaseExpiry = "2027-01-15T08:03:00Z";

describe("household privacy worker contract", () => {
  test("builds both formats purges objects and atomically completes deletion", async () => {
    const calls = [];
    const uploads = [];
    const removals = [];
    const response = await handlerFor({
      calls,
      uploads,
      removals,
      includePurge: true,
      includeDeletion: true,
    })(workerRequest());
    assert.equal(response.status, 200);
    const payload = await response.json();
    assert.equal(payload.meta.contractVersion, householdPrivacyWorkerContractVersion);
    assert.deepEqual(payload.data, {
      exportRecoveredRetryScheduled: 1,
      exportRecoveredDeadLetter: 0,
      exportClaimed: 1,
      exportSucceeded: 1,
      exportRetryScheduled: 0,
      exportDeadLetter: 0,
      purgeRecoveredRetryScheduled: 0,
      purgeRecoveredDeadLetter: 1,
      purgeClaimed: 1,
      purgeSucceeded: 1,
      purgeRetryScheduled: 0,
      purgeDeadLetter: 0,
      deletionRecoveredRetryScheduled: 0,
      deletionRecoveredDeadLetter: 0,
      deletionClaimed: 1,
      deletionSucceeded: 1,
      deletionRetryScheduled: 0,
      deletionDeadLetter: 0,
    });
    assert.deepEqual(uploads.map((upload) => [upload.objectKey, upload.contentType]), [
      [`household-exports/${exportId}/kinflow-household.json`, "application/json"],
      [`household-exports/${exportId}/kinflow-household.txt`, "text/plain"],
    ]);
    assert.match(new TextDecoder().decode(uploads[1].bytes), /HOUSEHOLD\n/);
    assert.match(new TextDecoder().decode(uploads[1].bytes), /Name: Primary household/);
    assert.deepEqual(removals[0], [
      `household-exports/${exportId}/kinflow-household.json`,
      `household-exports/${exportId}/kinflow-household.txt`,
    ]);
    const completion = calls.find((call) => call.name === "completeExport").parameters;
    assert.match(completion.p_machine_checksum_sha256, /^[0-9a-f]{64}$/);
    assert.match(completion.p_human_checksum_sha256, /^[0-9a-f]{64}$/);
    assert.equal(completion.p_machine_size_bytes, uploads[0].bytes.byteLength);
    assert.equal(completion.p_human_size_bytes, uploads[1].bytes.byteLength);
    assert.equal(calls.find((call) => call.name === "completeDeletion")
      .parameters.p_request_id, deletionRequestId);
  });

  test("upload outage schedules a bounded retry without exposing archive contents", async () => {
    const calls = [];
    const response = await handlerFor({
      calls,
      uploadArtifact: async () => {
        throw new HouseholdPrivacyWorkerFailure("EXPORT_UPLOAD_UNAVAILABLE", true);
      },
    })(workerRequest());
    assert.equal(response.status, 200);
    const data = (await response.json()).data;
    assert.equal(data.exportRetryScheduled, 1);
    assert.equal(data.exportSucceeded, 0);
    const failure = calls.find((call) => call.name === "failExport").parameters;
    assert.equal(failure.p_error_code, "EXPORT_UPLOAD_UNAVAILABLE");
    assert.equal(failure.p_retryable, true);
    assert.equal(JSON.stringify(failure).includes("Primary household"), false);
  });

  test("malformed archive payload never reaches private Storage", async () => {
    let uploads = 0;
    const response = await handlerFor({
      loadExportPackage: async () => [{result: {...householdPayload(), secret: true}}],
      uploadArtifact: async () => { uploads += 1; },
    })(workerRequest());
    assert.equal(response.status, 200);
    assert.equal((await response.json()).data.exportRetryScheduled, 1);
    assert.equal(uploads, 0);
  });

  test("Owner authorization change dead-letters deletion without retry", async () => {
    const calls = [];
    const response = await handlerFor({
      calls,
      includeDeletion: true,
      completeDeletion: async () => {
        throw new HouseholdPrivacyWorkerFailure("OWNER_AUTHORIZATION_CHANGED");
      },
    })(workerRequest());
    assert.equal(response.status, 200);
    const data = (await response.json()).data;
    assert.equal(data.deletionSucceeded, 0);
    assert.equal(data.deletionDeadLetter, 1);
    const failure = calls.find((call) => call.name === "failDeletion").parameters;
    assert.equal(failure.p_error_code, "OWNER_AUTHORIZATION_CHANGED");
    assert.equal(failure.p_retryable, false);
  });

  test("purge outage is isolated from export generation and deletion", async () => {
    const response = await handlerFor({
      includePurge: true,
      includeDeletion: true,
      removeArtifacts: async () => {
        throw new HouseholdPrivacyWorkerFailure("EXPORT_PURGE_UNAVAILABLE", true);
      },
    })(workerRequest());
    const data = (await response.json()).data;
    assert.equal(data.exportSucceeded, 1);
    assert.equal(data.purgeRetryScheduled, 1);
    assert.equal(data.deletionSucceeded, 1);
  });

  test("human archive rendering is deterministic complete and control-safe", () => {
    const payload = householdPayload();
    payload.household.note = "Line one\nLine two";
    const first = renderHouseholdExport(payload);
    const second = renderHouseholdExport(payload);
    assert.equal(first, second);
    assert.match(first, /KinFlow household data export/);
    assert.match(first, /Line one\\nLine two/);
    assert.match(first, /PRIVACY REQUESTS/);
    assert.equal(first.endsWith("\n"), true);
  });

  test("authentication method and nonempty body fail before worker operations", async () => {
    let calls = 0;
    const handler = handlerFor({recoverExports: async () => {
      calls += 1;
      return [recoveryRow()];
    }});
    for (const [request, status, code] of [
      [workerRequest({authorized: false}), 401, "AUTH_REQUIRED"],
      [workerRequest({body: "{}"}), 400, "VALIDATION_FAILED"],
      [new Request("https://api.test/household-privacy-worker", {method: "GET"}),
        405, "METHOD_NOT_ALLOWED"],
    ]) {
      const response = await handler(request);
      assert.equal(response.status, status);
      assert.equal((await response.json()).error.code, code);
    }
    assert.equal(calls, 0);
  });
});

function handlerFor({
  calls = [],
  uploads = [],
  removals = [],
  includePurge = false,
  includeDeletion = false,
  recoverExports,
  loadExportPackage,
  uploadArtifact,
  removeArtifacts,
  completeDeletion,
} = {}) {
  return createHouseholdPrivacyWorkerHandler({
    workerSecret,
    now: () => asOf,
    workerId: () => workerId,
    recoverExports: recoverExports ?? (async (parameters) => {
      calls.push({name: "recoverExports", parameters});
      return [recoveryRow({retry_scheduled: 1})];
    }),
    recoverPurges: async (parameters) => {
      calls.push({name: "recoverPurges", parameters});
      return [recoveryRow({dead_letter: 1})];
    },
    recoverDeletions: async (parameters) => {
      calls.push({name: "recoverDeletions", parameters});
      return [recoveryRow()];
    },
    claimExports: async (parameters) => {
      calls.push({name: "claimExports", parameters});
      return [exportClaimRow()];
    },
    claimPurges: async (parameters) => {
      calls.push({name: "claimPurges", parameters});
      return includePurge ? [purgeClaimRow()] : [];
    },
    claimDeletions: async (parameters) => {
      calls.push({name: "claimDeletions", parameters});
      return includeDeletion ? [deletionClaimRow()] : [];
    },
    loadExportPackage: loadExportPackage ?? (async (parameters) => {
      calls.push({name: "loadExportPackage", parameters});
      return [{result: householdPayload()}];
    }),
    uploadArtifact: uploadArtifact ?? (async (artifact) => uploads.push(artifact)),
    completeExport: async (parameters) => {
      calls.push({name: "completeExport", parameters});
      return [{result: exportStatus({status: "completed", available: true})}];
    },
    failExport: async (parameters) => {
      calls.push({name: "failExport", parameters});
      return [{result: exportStatus({
        status: parameters.p_retryable ? "processing" : "failed",
        failureCode: parameters.p_error_code,
      })}];
    },
    removeArtifacts: removeArtifacts ?? (async (keys) => removals.push(keys)),
    completePurge: async (parameters) => {
      calls.push({name: "completePurge", parameters});
      return [{result: exportStatus({status: "completed", purgedAt: asOf})}];
    },
    failPurge: async (parameters) => {
      calls.push({name: "failPurge", parameters});
      return [{result: exportStatus({status: "completed"})}];
    },
    completeDeletion: completeDeletion ?? (async (parameters) => {
      calls.push({name: "completeDeletion", parameters});
      return [{result: deletionStatus("completed")}];
    }),
    failDeletion: async (parameters) => {
      calls.push({name: "failDeletion", parameters});
      return [{result: deletionStatus(
        parameters.p_retryable ? "processing" : "failed",
        parameters.p_error_code,
      )}];
    },
  });
}

function workerRequest({authorized = true, body = ""} = {}) {
  const headers = new Headers({"x-request-id": requestId});
  if (authorized) headers.set("authorization", `Bearer ${workerSecret}`);
  return new Request("https://api.test/household-privacy-worker", {
    method: "POST",
    headers,
    body,
  });
}

function recoveryRow(overrides = {}) {
  return {retry_scheduled: 0, dead_letter: 0, ...overrides};
}

function exportClaimRow() {
  return {
    privacy_request_id: exportRequestId,
    household_export_id: exportId,
    household_id: householdId,
    lease_token: exportLease,
    lease_expires_at: leaseExpiry,
    attempts: 1,
  };
}

function purgeClaimRow() {
  return {
    household_export_id: exportId,
    privacy_request_id: exportRequestId,
    machine_object_key: `household-exports/${exportId}/kinflow-household.json`,
    human_object_key: `household-exports/${exportId}/kinflow-household.txt`,
    lease_token: purgeLease,
    lease_expires_at: leaseExpiry,
    attempts: 1,
  };
}

function deletionClaimRow() {
  return {
    privacy_request_id: deletionRequestId,
    household_id: householdId,
    lease_token: deletionLease,
    lease_expires_at: leaseExpiry,
    attempts: 1,
  };
}

function householdPayload() {
  return {
    schemaVersion: householdPrivacyWorkerContractVersion,
    generatedAt: asOf,
    scope: {
      kind: "sharedHousehold",
      memberAuthIdentitiesIncluded: false,
      personalNotificationInboxIncluded: false,
      providerIdentifiersIncluded: false,
      removedMemberDisplayIdentityIncluded: false,
    },
    household: {id: householdId, name: "Primary household", timezone: "Asia/Seoul"},
    members: [],
    choreSeries: [],
    choreRevisions: [],
    choreOccurrences: [],
    choreActions: [],
    calendarSeries: [],
    calendarRevisions: [],
    calendarOccurrences: [],
    calendarExceptions: [],
    calendarParticipation: [],
    notificationSummary: [],
    billingSummary: {activeAssignment: false, planCode: "free", status: "none"},
    privacyRequests: [],
  };
}

function exportStatus({
  status,
  failureCode = null,
  available = false,
  purgedAt = null,
}) {
  return {
    requestId: exportRequestId,
    kind: "export",
    status,
    failureCode,
    artifact: {
      id: exportId,
      version: 2,
      available,
      purgedAt,
    },
    deletion: null,
  };
}

function deletionStatus(status, failureCode = null) {
  return {
    requestId: deletionRequestId,
    kind: "deletion",
    status,
    failureCode,
    artifact: null,
    deletion: status === "completed"
      ? {
        accessRevokedAt: asOf,
        redactedAt: asOf,
        billingUnlinkedAt: asOf,
      }
      : {
        accessRevokedAt: null,
        redactedAt: null,
        billingUnlinkedAt: null,
      },
  };
}
