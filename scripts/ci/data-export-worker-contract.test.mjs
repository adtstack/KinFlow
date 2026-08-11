import assert from "node:assert/strict";
import {describe, test} from "node:test";

import {
  createDataExportWorkerHandler,
  DataExportWorkerFailure,
  dataExportWorkerContractVersion,
  renderHumanReadableExport,
} from "../../supabase/functions/_shared/data_export_worker_contract.mjs";

const workerSecret = "data-export-worker-secret";
const requestId = "70000000-0000-4000-8000-000000000101";
const workerId = "71000000-0000-4000-8000-000000000101";
const privacyRequestId = "72000000-0000-4000-8000-000000000101";
const dataExportId = "73000000-0000-4000-8000-000000000101";
const authUserId = "00000000-0000-4000-8000-000000000102";
const artifactPrefix = "74000000-0000-4000-8000-000000000101";
const generationLease = "75000000-0000-4000-8000-000000000101";
const purgeLease = "76000000-0000-4000-8000-000000000101";
const asOf = "2027-01-15T08:00:00Z";

describe("personal data export worker contract", () => {
  test("builds both formats, records checksums, and purges expired objects", async () => {
    const calls = [];
    const uploads = [];
    const removals = [];
    const handler = handlerFor({calls, uploads, removals, includePurge: true});
    const response = await handler(workerRequest());
    assert.equal(response.status, 200);
    const payload = await response.json();
    assert.equal(payload.meta.contractVersion, dataExportWorkerContractVersion);
    assert.deepEqual(payload.data, {
      generationRecoveredRetryScheduled: 1,
      generationRecoveredDeadLetter: 0,
      generationClaimed: 1,
      generationSucceeded: 1,
      generationRetryScheduled: 0,
      generationDeadLetter: 0,
      purgeRecoveredRetryScheduled: 0,
      purgeRecoveredDeadLetter: 1,
      purgeClaimed: 1,
      purgeSucceeded: 1,
      purgeRetryScheduled: 0,
      purgeDeadLetter: 0,
    });
    assert.deepEqual(uploads.map((upload) => [upload.objectKey, upload.contentType]), [
      [`exports/${artifactPrefix}/kinflow-data.json`, "application/json"],
      [`exports/${artifactPrefix}/kinflow-data.txt`, "text/plain"],
    ]);
    assert.match(new TextDecoder().decode(uploads[1].bytes), /PROFILE\n/);
    assert.match(new TextDecoder().decode(uploads[1].bytes), /Display Name: Adult B/);
    assert.deepEqual(removals[0], [
      `exports/${artifactPrefix}/kinflow-data.json`,
      `exports/${artifactPrefix}/kinflow-data.txt`,
    ]);
    const completion = calls.find((call) => call.name === "completeGeneration").parameters;
    assert.match(completion.p_machine_checksum_sha256, /^[0-9a-f]{64}$/);
    assert.match(completion.p_human_checksum_sha256, /^[0-9a-f]{64}$/);
    assert.equal(completion.p_machine_size_bytes, uploads[0].bytes.byteLength);
    assert.equal(completion.p_human_size_bytes, uploads[1].bytes.byteLength);
  });

  test("upload outage is recorded as retryable without exposing package contents", async () => {
    const calls = [];
    const handler = handlerFor({
      calls,
      uploadArtifact: async () => {
        throw new DataExportWorkerFailure("EXPORT_UPLOAD_UNAVAILABLE", true);
      },
    });
    const response = await handler(workerRequest());
    assert.equal(response.status, 200);
    const data = (await response.json()).data;
    assert.equal(data.generationRetryScheduled, 1);
    assert.equal(data.generationSucceeded, 0);
    const failure = calls.find((call) => call.name === "failGeneration").parameters;
    assert.equal(failure.p_error_code, "EXPORT_UPLOAD_UNAVAILABLE");
    assert.equal(failure.p_retryable, true);
    assert.equal(JSON.stringify(failure).includes("Adult B"), false);
  });

  test("malformed package becomes a bounded retry instead of an unvalidated upload", async () => {
    let uploads = 0;
    const calls = [];
    const handler = handlerFor({
      calls,
      loadPackage: async () => [{...packageRow(), payload: {...personalPayload(), secret: true}}],
      uploadArtifact: async () => { uploads += 1; },
    });
    const response = await handler(workerRequest());
    assert.equal(response.status, 200);
    assert.equal((await response.json()).data.generationRetryScheduled, 1);
    assert.equal(uploads, 0);
  });

  test("human rendering is deterministic, complete, and control-safe", () => {
    const first = renderHumanReadableExport(personalPayload());
    const second = renderHumanReadableExport(personalPayload());
    assert.equal(first, second);
    assert.match(first, /KinFlow personal data export/);
    assert.match(first, /Line one\\nLine two/);
    assert.match(first, /PRIVACY REQUESTS/);
    assert.equal(first.endsWith("\n"), true);
  });

  test("authentication method and body fail closed before worker operations", async () => {
    let calls = 0;
    const handler = handlerFor({recoverGeneration: async () => {
      calls += 1;
      return [recoveryRow()];
    }});
    for (const [request, status, code] of [
      [workerRequest({authorized: false}), 401, "AUTH_REQUIRED"],
      [workerRequest({body: "{}"}), 400, "VALIDATION_FAILED"],
      [new Request("https://api.test/data-export-worker", {method: "GET"}), 405, "METHOD_NOT_ALLOWED"],
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
  recoverGeneration,
  loadPackage,
  uploadArtifact,
} = {}) {
  return createDataExportWorkerHandler({
    workerSecret,
    now: () => asOf,
    workerId: () => workerId,
    recoverGeneration: recoverGeneration ?? (async (parameters) => {
      calls.push({name: "recoverGeneration", parameters});
      return [recoveryRow({retry_scheduled: 1})];
    }),
    recoverPurges: async (parameters) => {
      calls.push({name: "recoverPurges", parameters});
      return [recoveryRow({dead_letter: 1})];
    },
    claimGeneration: async (parameters) => {
      calls.push({name: "claimGeneration", parameters});
      return [generationClaimRow()];
    },
    claimPurges: async (parameters) => {
      calls.push({name: "claimPurges", parameters});
      return includePurge ? [purgeClaimRow()] : [];
    },
    loadPackage: loadPackage ?? (async (parameters) => {
      calls.push({name: "loadPackage", parameters});
      return [packageRow()];
    }),
    uploadArtifact: uploadArtifact ?? (async (artifact) => uploads.push(artifact)),
    completeGeneration: async (parameters) => {
      calls.push({name: "completeGeneration", parameters});
      return [generationCompletionRow()];
    },
    failGeneration: async (parameters) => {
      calls.push({name: "failGeneration", parameters});
      return [generationFailureRow()];
    },
    removeArtifacts: async (keys) => removals.push(keys),
    completePurge: async (parameters) => {
      calls.push({name: "completePurge", parameters});
      return [purgeCompletionRow()];
    },
    failPurge: async (parameters) => {
      calls.push({name: "failPurge", parameters});
      return [purgeFailureRow()];
    },
  });
}

function workerRequest({authorized = true, body = ""} = {}) {
  const headers = new Headers({"x-request-id": requestId});
  if (authorized) headers.set("authorization", `Bearer ${workerSecret}`);
  return new Request("https://api.test/data-export-worker", {
    method: "POST",
    headers,
    body,
  });
}

function recoveryRow(overrides = {}) {
  return {retry_scheduled: 0, dead_letter: 0, ...overrides};
}

function generationClaimRow() {
  return {
    privacy_request_id: privacyRequestId,
    data_export_id: dataExportId,
    auth_user_id: authUserId,
    artifact_prefix: artifactPrefix,
    lease_token: generationLease,
    request_version: 2,
    attempts: 1,
  };
}

function purgeClaimRow() {
  return {
    data_export_id: dataExportId,
    privacy_request_id: privacyRequestId,
    machine_object_key: `exports/${artifactPrefix}/kinflow-data.json`,
    human_object_key: `exports/${artifactPrefix}/kinflow-data.txt`,
    lease_token: purgeLease,
    attempts: 1,
  };
}

function packageRow() {
  return {
    auth_user_id: authUserId,
    artifact_prefix: artifactPrefix,
    schema_version: dataExportWorkerContractVersion,
    payload: personalPayload(),
  };
}

function personalPayload() {
  return {
    schemaVersion: dataExportWorkerContractVersion,
    generatedAt: asOf,
    scope: {
      type: "personal",
      sharedHouseholdExportIncluded: false,
      otherMemberProfilesIncluded: false,
      providerIdentifiersIncluded: false,
    },
    profile: {
      id: "01000000-0000-4000-8000-000000000102",
      displayName: "Adult B",
      note: "Line one\nLine two",
    },
    memberships: [],
    authoredChores: [],
    choreActions: [],
    authoredCalendarEvents: [],
    calendarParticipation: [],
    notificationPreferences: [],
    notificationInbox: [],
    billingSummary: [],
    privacyRequests: [],
  };
}

function generationCompletionRow() {
  return {
    request_id: privacyRequestId,
    status: "completed",
    artifact_expires_at: "2027-01-16T08:00:00Z",
    request_version: 3,
    artifact_version: 2,
  };
}

function generationFailureRow() {
  return {
    request_id: privacyRequestId,
    status: "processing",
    failure_code: "EXPORT_UPLOAD_UNAVAILABLE",
    next_attempt_at: "2027-01-15T08:01:00Z",
    version: 3,
  };
}

function purgeCompletionRow() {
  return {
    data_export_id: dataExportId,
    purged_at: asOf,
    artifact_version: 4,
  };
}

function purgeFailureRow() {
  return {
    data_export_id: dataExportId,
    status: "retry_wait",
    failure_code: "EXPORT_PURGE_UNAVAILABLE",
    next_attempt_at: "2027-01-15T08:01:00Z",
  };
}
