export const dataExportWorkerContractVersion = "2026-08-08-wp07-02a";

const maximumArtifactBytes = 10 * 1024 * 1024;
const schemaVersion = "2026-08-08-wp07-02a";
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export class DataExportWorkerFailure extends Error {
  constructor(code, retryable = false) {
    super("Data export worker operation failed");
    this.name = "DataExportWorkerFailure";
    this.code = typeof code === "string" ? code : "PROCESSING_PRECONDITION_FAILED";
    this.retryable = retryable === true;
  }
}

export function createDataExportWorkerHandler({
  claimGeneration,
  claimPurges,
  completeGeneration,
  completePurge,
  failGeneration,
  failPurge,
  loadPackage,
  recoverGeneration,
  recoverPurges,
  removeArtifacts,
  uploadArtifact,
  workerSecret,
  now = () => new Date().toISOString(),
  workerId = () => crypto.randomUUID(),
}) {
  return async function handleDataExportWorker(request) {
    const requestId = requestIdFor(request);
    const headers = responseHeaders(requestId);
    if (request.method !== "POST") {
      return errorResponse("METHOD_NOT_ALLOWED", 405, false, requestId, headers);
    }
    if (!constantTimeEqual(request.headers.get("authorization") ?? "", `Bearer ${workerSecret}`)) {
      return errorResponse("AUTH_REQUIRED", 401, false, requestId, headers);
    }
    if ((await request.text()).trim().length !== 0) {
      return errorResponse("VALIDATION_FAILED", 400, false, requestId, headers);
    }

    const asOf = now();
    const id = workerId();
    if (!validTimestamp(asOf) || !uuidPattern.test(id)) {
      return errorResponse("TEMPORARILY_UNAVAILABLE", 503, true, requestId, headers);
    }

    let generationRecovery;
    let purgeRecovery;
    let generationClaims;
    let purgeClaims;
    try {
      generationRecovery = recoveryRow(await recoverGeneration({p_as_of: asOf}));
      purgeRecovery = recoveryRow(await recoverPurges({p_as_of: asOf}));
      generationClaims = generationClaimRows(await claimGeneration({
        p_as_of: asOf,
        p_lease_seconds: 240,
        p_limit: 3,
        p_worker_id: id.toLowerCase(),
      }));
      purgeClaims = purgeClaimRows(await claimPurges({
        p_as_of: asOf,
        p_lease_seconds: 120,
        p_limit: 10,
        p_worker_id: id.toLowerCase(),
      }));
    } catch {
      return errorResponse("TEMPORARILY_UNAVAILABLE", 503, true, requestId, headers);
    }

    const summary = {
      generationRecoveredRetryScheduled: generationRecovery.retry_scheduled,
      generationRecoveredDeadLetter: generationRecovery.dead_letter,
      generationClaimed: generationClaims.length,
      generationSucceeded: 0,
      generationRetryScheduled: 0,
      generationDeadLetter: 0,
      purgeRecoveredRetryScheduled: purgeRecovery.retry_scheduled,
      purgeRecoveredDeadLetter: purgeRecovery.dead_letter,
      purgeClaimed: purgeClaims.length,
      purgeSucceeded: 0,
      purgeRetryScheduled: 0,
      purgeDeadLetter: 0,
    };

    for (const claim of generationClaims) {
      try {
        await processGeneration({
          asOf,
          claim,
          completeGeneration,
          loadPackage,
          uploadArtifact,
        });
        summary.generationSucceeded += 1;
      } catch (error) {
        const failure = normalizedGenerationFailure(error);
        try {
          const failed = generationFailureRow(await failGeneration({
            p_as_of: asOf,
            p_error_code: failure.code,
            p_lease_token: claim.lease_token,
            p_request_id: claim.privacy_request_id,
            p_retryable: failure.retryable,
          }), claim.privacy_request_id);
          if (failed.status === "processing") summary.generationRetryScheduled += 1;
          else summary.generationDeadLetter += 1;
        } catch {
          return errorResponse("TEMPORARILY_UNAVAILABLE", 503, true, requestId, headers);
        }
      }
    }

    for (const claim of purgeClaims) {
      try {
        await removeArtifacts([claim.machine_object_key, claim.human_object_key]);
        purgeCompletionRow(await completePurge({
          p_as_of: asOf,
          p_data_export_id: claim.data_export_id,
          p_lease_token: claim.lease_token,
        }), claim.data_export_id);
        summary.purgeSucceeded += 1;
      } catch (error) {
        const failure = error instanceof DataExportWorkerFailure
          ? error
          : new DataExportWorkerFailure("EXPORT_PURGE_UNAVAILABLE", true);
        try {
          const failed = purgeFailureRow(await failPurge({
            p_as_of: asOf,
            p_data_export_id: claim.data_export_id,
            p_error_code: failure.code === "PROCESSING_PRECONDITION_FAILED"
              ? failure.code
              : "EXPORT_PURGE_UNAVAILABLE",
            p_lease_token: claim.lease_token,
            p_retryable: failure.retryable,
          }), claim.data_export_id);
          if (failed.status === "retry_wait") summary.purgeRetryScheduled += 1;
          else summary.purgeDeadLetter += 1;
        } catch {
          return errorResponse("TEMPORARILY_UNAVAILABLE", 503, true, requestId, headers);
        }
      }
    }

    return Response.json(
      {data: summary, meta: {requestId, contractVersion: dataExportWorkerContractVersion}},
      {status: 200, headers},
    );
  };
}

async function processGeneration({
  asOf,
  claim,
  completeGeneration,
  loadPackage,
  uploadArtifact,
}) {
  let packageRow;
  try {
    packageRow = exportPackageRow(await loadPackage({
      p_as_of: asOf,
      p_lease_token: claim.lease_token,
      p_request_id: claim.privacy_request_id,
    }));
  } catch (error) {
    if (error instanceof DataExportWorkerFailure) throw error;
    throw new DataExportWorkerFailure("EXPORT_BUILD_UNAVAILABLE", true);
  }
  if (packageRow.auth_user_id !== claim.auth_user_id ||
    packageRow.artifact_prefix !== claim.artifact_prefix) {
    throw new DataExportWorkerFailure("PROCESSING_PRECONDITION_FAILED");
  }

  let machineBytes;
  let humanBytes;
  try {
    machineBytes = new TextEncoder().encode(`${JSON.stringify(packageRow.payload, null, 2)}\n`);
    humanBytes = new TextEncoder().encode(renderHumanReadableExport(packageRow.payload));
  } catch {
    throw new DataExportWorkerFailure("PROCESSING_PRECONDITION_FAILED");
  }
  if (machineBytes.byteLength < 1 || humanBytes.byteLength < 1 ||
    machineBytes.byteLength > maximumArtifactBytes ||
    humanBytes.byteLength > maximumArtifactBytes) {
    throw new DataExportWorkerFailure("EXPORT_SIZE_LIMIT_EXCEEDED");
  }

  const prefix = `exports/${claim.artifact_prefix}`;
  const machineObjectKey = `${prefix}/kinflow-data.json`;
  const humanObjectKey = `${prefix}/kinflow-data.txt`;
  let machineChecksum;
  let humanChecksum;
  try {
    [machineChecksum, humanChecksum] = await Promise.all([
      sha256Hex(machineBytes),
      sha256Hex(humanBytes),
    ]);
    await uploadArtifact({
      bytes: machineBytes,
      contentType: "application/json",
      objectKey: machineObjectKey,
    });
    await uploadArtifact({
      bytes: humanBytes,
      contentType: "text/plain",
      objectKey: humanObjectKey,
    });
  } catch {
    throw new DataExportWorkerFailure("EXPORT_UPLOAD_UNAVAILABLE", true);
  }

  try {
    generationCompletionRow(await completeGeneration({
      p_as_of: asOf,
      p_human_checksum_sha256: humanChecksum,
      p_human_object_key: humanObjectKey,
      p_human_size_bytes: humanBytes.byteLength,
      p_lease_token: claim.lease_token,
      p_machine_checksum_sha256: machineChecksum,
      p_machine_object_key: machineObjectKey,
      p_machine_size_bytes: machineBytes.byteLength,
      p_request_id: claim.privacy_request_id,
    }), claim.privacy_request_id);
  } catch (error) {
    if (error instanceof DataExportWorkerFailure) throw error;
    throw new DataExportWorkerFailure("PROCESSING_PRECONDITION_FAILED");
  }
}

export function renderHumanReadableExport(payload) {
  validatePayload(payload);
  const lines = [
    "KinFlow personal data export",
    `Schema version: ${payload.schemaVersion}`,
    `Generated at: ${payload.generatedAt}`,
    "",
  ];
  for (const [key, value] of Object.entries(payload)) {
    if (["schemaVersion", "generatedAt"].includes(key)) continue;
    lines.push(humanizeKey(key).toUpperCase());
    renderValue(lines, value, 1);
    lines.push("");
  }
  return `${lines.join("\n").trimEnd()}\n`;
}

function renderValue(lines, value, depth) {
  const indent = "  ".repeat(depth);
  if (Array.isArray(value)) {
    lines.push(`${indent}Items: ${value.length}`);
    value.forEach((item, index) => {
      lines.push(`${indent}${index + 1}.`);
      renderValue(lines, item, depth + 1);
    });
    return;
  }
  if (isPlainObject(value)) {
    for (const [key, child] of Object.entries(value)) {
      if (Array.isArray(child) || isPlainObject(child)) {
        lines.push(`${indent}${humanizeKey(key)}:`);
        renderValue(lines, child, depth + 1);
      } else {
        lines.push(`${indent}${humanizeKey(key)}: ${printable(child)}`);
      }
    }
    return;
  }
  lines.push(`${indent}${printable(value)}`);
}

function printable(value) {
  if (value === null) return "(not set)";
  return String(value)
    .replaceAll("\\", "\\\\")
    .replaceAll("\r", "\\r")
    .replaceAll("\n", "\\n")
    .replaceAll("\t", "\\t");
}

function humanizeKey(value) {
  return value
    .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .replace(/^./, (character) => character.toUpperCase());
}

function validatePayload(payload) {
  exactKeys(payload, [
    "authoredCalendarEvents",
    "authoredChores",
    "billingSummary",
    "calendarParticipation",
    "choreActions",
    "generatedAt",
    "memberships",
    "notificationInbox",
    "notificationPreferences",
    "privacyRequests",
    "profile",
    "schemaVersion",
    "scope",
  ]);
  if (payload.schemaVersion !== schemaVersion || !validTimestamp(payload.generatedAt) ||
    !isPlainObject(payload.profile) || !isPlainObject(payload.scope)) {
    throw new TypeError("Invalid personal data export package");
  }
  for (const key of [
    "authoredCalendarEvents",
    "authoredChores",
    "billingSummary",
    "calendarParticipation",
    "choreActions",
    "memberships",
    "notificationInbox",
    "notificationPreferences",
    "privacyRequests",
  ]) {
    if (!Array.isArray(payload[key])) throw new TypeError("Invalid export collection");
  }
}

function recoveryRow(payload) {
  const row = singleRow(payload);
  exactKeys(row, ["dead_letter", "retry_scheduled"]);
  if (!nonNegativeInteger(row.retry_scheduled) || !nonNegativeInteger(row.dead_letter)) {
    throw new TypeError("Invalid export recovery payload");
  }
  return row;
}

function generationClaimRows(payload) {
  if (!Array.isArray(payload) || payload.length > 3) throw new TypeError("Invalid export claims");
  return payload.map((row) => {
    exactKeys(row, [
      "artifact_prefix",
      "attempts",
      "auth_user_id",
      "data_export_id",
      "lease_token",
      "privacy_request_id",
      "request_version",
    ]);
    if (!positiveInteger(row.attempts) || !positiveInteger(row.request_version)) {
      throw new TypeError("Invalid export claim");
    }
    return {
      ...row,
      artifact_prefix: requiredUuid(row.artifact_prefix),
      auth_user_id: requiredUuid(row.auth_user_id),
      data_export_id: requiredUuid(row.data_export_id),
      lease_token: requiredUuid(row.lease_token),
      privacy_request_id: requiredUuid(row.privacy_request_id),
    };
  });
}

function purgeClaimRows(payload) {
  if (!Array.isArray(payload) || payload.length > 10) throw new TypeError("Invalid purge claims");
  return payload.map((row) => {
    exactKeys(row, [
      "attempts",
      "data_export_id",
      "human_object_key",
      "lease_token",
      "machine_object_key",
      "privacy_request_id",
    ]);
    if (!positiveInteger(row.attempts) ||
      !validObjectKey(row.machine_object_key, "json") ||
      !validObjectKey(row.human_object_key, "txt")) {
      throw new TypeError("Invalid purge claim");
    }
    return {
      ...row,
      data_export_id: requiredUuid(row.data_export_id),
      lease_token: requiredUuid(row.lease_token),
      privacy_request_id: requiredUuid(row.privacy_request_id),
    };
  });
}

function exportPackageRow(payload) {
  const row = singleRow(payload);
  exactKeys(row, ["artifact_prefix", "auth_user_id", "payload", "schema_version"]);
  if (row.schema_version !== schemaVersion) throw new TypeError("Invalid export schema");
  validatePayload(row.payload);
  return {
    ...row,
    artifact_prefix: requiredUuid(row.artifact_prefix),
    auth_user_id: requiredUuid(row.auth_user_id),
  };
}

function generationCompletionRow(payload, expectedRequestId) {
  const row = singleRow(payload);
  exactKeys(row, [
    "artifact_expires_at",
    "artifact_version",
    "request_id",
    "request_version",
    "status",
  ]);
  if (requiredUuid(row.request_id) !== expectedRequestId || row.status !== "completed" ||
    !validTimestamp(row.artifact_expires_at) || !positiveInteger(row.request_version) ||
    !positiveInteger(row.artifact_version)) {
    throw new TypeError("Invalid export completion");
  }
  return row;
}

function generationFailureRow(payload, expectedRequestId) {
  const row = singleRow(payload);
  exactKeys(row, ["failure_code", "next_attempt_at", "request_id", "status", "version"]);
  if (requiredUuid(row.request_id) !== expectedRequestId ||
    !["processing", "failed"].includes(row.status) ||
    typeof row.failure_code !== "string" ||
    (row.next_attempt_at !== null && !validTimestamp(row.next_attempt_at)) ||
    !positiveInteger(row.version)) {
    throw new TypeError("Invalid export failure");
  }
  return row;
}

function purgeCompletionRow(payload, expectedExportId) {
  const row = singleRow(payload);
  exactKeys(row, ["artifact_version", "data_export_id", "purged_at"]);
  if (requiredUuid(row.data_export_id) !== expectedExportId ||
    !validTimestamp(row.purged_at) || !positiveInteger(row.artifact_version)) {
    throw new TypeError("Invalid purge completion");
  }
  return row;
}

function purgeFailureRow(payload, expectedExportId) {
  const row = singleRow(payload);
  exactKeys(row, ["data_export_id", "failure_code", "next_attempt_at", "status"]);
  if (requiredUuid(row.data_export_id) !== expectedExportId ||
    !["retry_wait", "dead_letter"].includes(row.status) ||
    typeof row.failure_code !== "string" ||
    (row.next_attempt_at !== null && !validTimestamp(row.next_attempt_at))) {
    throw new TypeError("Invalid purge failure");
  }
  return row;
}

function normalizedGenerationFailure(error) {
  if (error instanceof DataExportWorkerFailure) return error;
  return new DataExportWorkerFailure("EXPORT_BUILD_UNAVAILABLE", true);
}

async function sha256Hex(bytes) {
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
  return [...digest].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function validObjectKey(value, extension) {
  return typeof value === "string" &&
    new RegExp(`^exports/[0-9a-f-]{36}/kinflow-data\\.${extension}$`).test(value);
}

function responseHeaders(requestId) {
  return new Headers({
    "allow": "POST",
    "cache-control": "no-store",
    "content-type": "application/json; charset=utf-8",
    "x-content-type-options": "nosniff",
    "x-request-id": requestId,
  });
}

function errorResponse(code, status, retryable, requestId, headers) {
  return Response.json(
    {
      error: {
        code,
        messageKey: code === "AUTH_REQUIRED"
          ? "errors.authRequired"
          : code === "VALIDATION_FAILED" || code === "METHOD_NOT_ALLOWED"
          ? "errors.validationFailed"
          : "errors.temporarilyUnavailable",
        retryable,
        requestId,
      },
    },
    {status, headers},
  );
}

function requestIdFor(request) {
  const candidate = request.headers.get("x-request-id")?.trim() ?? "";
  return uuidPattern.test(candidate) ? candidate.toLowerCase() : crypto.randomUUID();
}

function constantTimeEqual(left, right) {
  const encoder = new TextEncoder();
  const a = encoder.encode(left);
  const b = encoder.encode(right);
  const length = Math.max(a.length, b.length);
  let difference = a.length ^ b.length;
  for (let index = 0; index < length; index += 1) {
    difference |= (a[index] ?? 0) ^ (b[index] ?? 0);
  }
  return difference === 0;
}

function requiredUuid(value) {
  if (typeof value !== "string" || !uuidPattern.test(value)) throw new TypeError("Invalid UUID");
  return value.toLowerCase();
}

function validTimestamp(value) {
  return typeof value === "string" && Number.isFinite(Date.parse(value));
}

function positiveInteger(value) {
  return Number.isSafeInteger(value) && value > 0;
}

function nonNegativeInteger(value) {
  return Number.isSafeInteger(value) && value >= 0;
}

function singleRow(payload) {
  if (!Array.isArray(payload) || payload.length !== 1 || !isPlainObject(payload[0])) {
    throw new TypeError("Invalid worker RPC payload");
  }
  return payload[0];
}

function exactKeys(value, expected) {
  if (!isPlainObject(value)) throw new TypeError("Invalid worker object");
  const actual = Object.keys(value).sort();
  const sorted = [...expected].sort();
  if (actual.length !== sorted.length || actual.some((key, index) => key !== sorted[index])) {
    throw new TypeError("Unexpected worker fields");
  }
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
