export const householdPrivacyWorkerContractVersion = "2026-08-08-wp07-02b";

const maximumArtifactBytes = 20 * 1024 * 1024;
const schemaVersion = "2026-08-08-wp07-02b";
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export class HouseholdPrivacyWorkerFailure extends Error {
  constructor(code, retryable = false) {
    super("Household privacy worker operation failed");
    this.name = "HouseholdPrivacyWorkerFailure";
    this.code = typeof code === "string" ? code : "PROCESSING_PRECONDITION_FAILED";
    this.retryable = retryable === true;
  }
}

export function createHouseholdPrivacyWorkerHandler({
  claimDeletions,
  claimExports,
  claimPurges,
  completeDeletion,
  completeExport,
  completePurge,
  failDeletion,
  failExport,
  failPurge,
  loadExportPackage,
  recoverDeletions,
  recoverExports,
  recoverPurges,
  removeArtifacts,
  uploadArtifact,
  workerSecret,
  now = () => new Date().toISOString(),
  workerId = () => crypto.randomUUID(),
}) {
  return async function handleHouseholdPrivacyWorker(request) {
    const requestId = requestIdFor(request);
    const headers = responseHeaders(requestId);
    if (request.method !== "POST") {
      return errorResponse("METHOD_NOT_ALLOWED", 405, false, requestId, headers);
    }
    if (!constantTimeEqual(
      request.headers.get("authorization") ?? "",
      `Bearer ${workerSecret}`,
    )) {
      return errorResponse("AUTH_REQUIRED", 401, false, requestId, headers);
    }
    if ((await request.text()).trim().length !== 0) {
      return errorResponse("VALIDATION_FAILED", 400, false, requestId, headers);
    }
    const asOf = now();
    const id = workerId();
    if (!validTimestamp(asOf) || !validUuid(id)) {
      return errorResponse("TEMPORARILY_UNAVAILABLE", 503, true, requestId, headers);
    }

    let exportRecovery;
    let purgeRecovery;
    let deletionRecovery;
    let exportClaims;
    let purgeClaims;
    let deletionClaims;
    try {
      [exportRecovery, purgeRecovery, deletionRecovery] = await Promise.all([
        recoverExports({p_as_of: asOf}),
        recoverPurges({p_as_of: asOf}),
        recoverDeletions({p_as_of: asOf}),
      ]).then((rows) => rows.map(recoveryRow));
      [exportClaims, purgeClaims, deletionClaims] = await Promise.all([
        claimExports({
          p_as_of: asOf,
          p_lease_seconds: 240,
          p_limit: 2,
          p_worker_id: id.toLowerCase(),
        }).then(exportClaimRows),
        claimPurges({
          p_as_of: asOf,
          p_lease_seconds: 120,
          p_limit: 10,
          p_worker_id: id.toLowerCase(),
        }).then(purgeClaimRows),
        claimDeletions({
          p_as_of: asOf,
          p_lease_seconds: 180,
          p_limit: 5,
          p_worker_id: id.toLowerCase(),
        }).then(deletionClaimRows),
      ]);
    } catch {
      return errorResponse("TEMPORARILY_UNAVAILABLE", 503, true, requestId, headers);
    }

    const summary = {
      exportRecoveredRetryScheduled: exportRecovery.retry_scheduled,
      exportRecoveredDeadLetter: exportRecovery.dead_letter,
      exportClaimed: exportClaims.length,
      exportSucceeded: 0,
      exportRetryScheduled: 0,
      exportDeadLetter: 0,
      purgeRecoveredRetryScheduled: purgeRecovery.retry_scheduled,
      purgeRecoveredDeadLetter: purgeRecovery.dead_letter,
      purgeClaimed: purgeClaims.length,
      purgeSucceeded: 0,
      purgeRetryScheduled: 0,
      purgeDeadLetter: 0,
      deletionRecoveredRetryScheduled: deletionRecovery.retry_scheduled,
      deletionRecoveredDeadLetter: deletionRecovery.dead_letter,
      deletionClaimed: deletionClaims.length,
      deletionSucceeded: 0,
      deletionRetryScheduled: 0,
      deletionDeadLetter: 0,
    };

    for (const claim of exportClaims) {
      try {
        await processExport({
          asOf,
          claim,
          completeExport,
          loadExportPackage,
          uploadArtifact,
        });
        summary.exportSucceeded += 1;
      } catch (error) {
        const failure = normalizedExportFailure(error);
        try {
          const result = privacyResult(await failExport({
            p_as_of: asOf,
            p_error_code: exportFailureCode(failure.code),
            p_lease_token: claim.lease_token,
            p_request_id: claim.privacy_request_id,
            p_retryable: failure.retryable,
          }), claim.privacy_request_id);
          if (result.status === "processing") summary.exportRetryScheduled += 1;
          else summary.exportDeadLetter += 1;
        } catch {
          return errorResponse("TEMPORARILY_UNAVAILABLE", 503, true, requestId, headers);
        }
      }
    }

    for (const claim of purgeClaims) {
      try {
        await removeArtifacts([claim.machine_object_key, claim.human_object_key]);
        const result = privacyResult(await completePurge({
          p_as_of: asOf,
          p_household_export_id: claim.household_export_id,
          p_lease_token: claim.lease_token,
        }), claim.privacy_request_id);
        if (result.artifact?.purgedAt === null) {
          throw new HouseholdPrivacyWorkerFailure("PROCESSING_PRECONDITION_FAILED");
        }
        summary.purgeSucceeded += 1;
      } catch (error) {
        const failure = normalizedPurgeFailure(error);
        try {
          privacyResult(await failPurge({
            p_as_of: asOf,
            p_error_code: failure.code === "PROCESSING_PRECONDITION_FAILED"
              ? failure.code
              : "EXPORT_PURGE_UNAVAILABLE",
            p_household_export_id: claim.household_export_id,
            p_lease_token: claim.lease_token,
            p_retryable: failure.retryable,
          }), claim.privacy_request_id);
          if (failure.retryable && claim.attempts < 5) summary.purgeRetryScheduled += 1;
          else summary.purgeDeadLetter += 1;
        } catch {
          return errorResponse("TEMPORARILY_UNAVAILABLE", 503, true, requestId, headers);
        }
      }
    }

    for (const claim of deletionClaims) {
      try {
        const result = privacyResult(await completeDeletion({
          p_as_of: asOf,
          p_lease_token: claim.lease_token,
          p_request_id: claim.privacy_request_id,
        }), claim.privacy_request_id);
        if (result.status !== "completed" || result.kind !== "deletion" ||
          result.deletion?.accessRevokedAt === null ||
          result.deletion?.redactedAt === null ||
          result.deletion?.billingUnlinkedAt === null) {
          throw new HouseholdPrivacyWorkerFailure("PROCESSING_PRECONDITION_FAILED");
        }
        summary.deletionSucceeded += 1;
      } catch (error) {
        const failure = normalizedDeletionFailure(error);
        try {
          const result = privacyResult(await failDeletion({
            p_as_of: asOf,
            p_error_code: deletionFailureCode(failure.code),
            p_lease_token: claim.lease_token,
            p_request_id: claim.privacy_request_id,
            p_retryable: failure.retryable,
          }), claim.privacy_request_id);
          if (result.status === "processing") summary.deletionRetryScheduled += 1;
          else summary.deletionDeadLetter += 1;
        } catch {
          return errorResponse("TEMPORARILY_UNAVAILABLE", 503, true, requestId, headers);
        }
      }
    }

    return Response.json(
      {data: summary, meta: {requestId, contractVersion: householdPrivacyWorkerContractVersion}},
      {status: 200, headers},
    );
  };
}

async function processExport({
  asOf,
  claim,
  completeExport,
  loadExportPackage,
  uploadArtifact,
}) {
  let payload;
  try {
    payload = exportPackage(await loadExportPackage({
      p_as_of: asOf,
      p_lease_token: claim.lease_token,
      p_request_id: claim.privacy_request_id,
    }));
  } catch (error) {
    if (error instanceof HouseholdPrivacyWorkerFailure) throw error;
    throw new HouseholdPrivacyWorkerFailure("EXPORT_BUILD_UNAVAILABLE", true);
  }
  if (payload.household.id.toLowerCase() !== claim.household_id) {
    throw new HouseholdPrivacyWorkerFailure("PROCESSING_PRECONDITION_FAILED");
  }
  let machineBytes;
  let humanBytes;
  try {
    machineBytes = new TextEncoder().encode(`${JSON.stringify(payload, null, 2)}\n`);
    humanBytes = new TextEncoder().encode(renderHouseholdExport(payload));
  } catch {
    throw new HouseholdPrivacyWorkerFailure("PROCESSING_PRECONDITION_FAILED");
  }
  if (machineBytes.byteLength < 1 || humanBytes.byteLength < 1 ||
    machineBytes.byteLength > maximumArtifactBytes ||
    humanBytes.byteLength > maximumArtifactBytes) {
    throw new HouseholdPrivacyWorkerFailure("EXPORT_SIZE_LIMIT_EXCEEDED");
  }
  const prefix = `household-exports/${claim.household_export_id}`;
  const machineObjectKey = `${prefix}/kinflow-household.json`;
  const humanObjectKey = `${prefix}/kinflow-household.txt`;
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
    throw new HouseholdPrivacyWorkerFailure("EXPORT_UPLOAD_UNAVAILABLE", true);
  }
  try {
    const result = privacyResult(await completeExport({
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
    if (result.status !== "completed" || result.kind !== "export" ||
      result.artifact?.id !== claim.household_export_id ||
      result.artifact.available !== true) {
      throw new TypeError("Invalid export completion");
    }
  } catch (error) {
    if (error instanceof HouseholdPrivacyWorkerFailure) throw error;
    throw new HouseholdPrivacyWorkerFailure("PROCESSING_PRECONDITION_FAILED");
  }
}

export function renderHouseholdExport(payload) {
  validatePayload(payload);
  const lines = [
    "KinFlow household data export",
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

function exportPackage(payload) {
  const value = resultValue(payload);
  validatePayload(value);
  return value;
}

function validatePayload(payload) {
  exactKeys(payload, [
    "billingSummary", "calendarExceptions", "calendarOccurrences",
    "calendarParticipation", "calendarRevisions", "calendarSeries",
    "choreActions", "choreOccurrences", "choreRevisions", "choreSeries",
    "generatedAt", "household", "members", "notificationSummary",
    "privacyRequests", "schemaVersion", "scope",
  ]);
  if (payload.schemaVersion !== schemaVersion || !validTimestamp(payload.generatedAt) ||
    !isPlainObject(payload.scope) || !isPlainObject(payload.household) ||
    !validUuid(payload.household.id) || !isPlainObject(payload.billingSummary)) {
    throw new TypeError("Invalid household export package");
  }
  for (const key of [
    "calendarExceptions", "calendarOccurrences", "calendarParticipation",
    "calendarRevisions", "calendarSeries", "choreActions", "choreOccurrences",
    "choreRevisions", "choreSeries", "members", "notificationSummary",
    "privacyRequests",
  ]) {
    if (!Array.isArray(payload[key])) throw new TypeError("Invalid household collection");
  }
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

function recoveryRow(payload) {
  const row = singleRow(payload);
  exactKeys(row, ["dead_letter", "retry_scheduled"]);
  if (!nonNegativeInteger(row.retry_scheduled) || !nonNegativeInteger(row.dead_letter)) {
    throw new TypeError("Invalid household worker recovery");
  }
  return row;
}

function exportClaimRows(payload) {
  if (!Array.isArray(payload) || payload.length > 2) throw new TypeError("Invalid export claims");
  return payload.map((row) => {
    exactKeys(row, [
      "attempts", "household_export_id", "household_id", "lease_expires_at",
      "lease_token", "privacy_request_id",
    ]);
    if (!positiveInteger(row.attempts) || !validTimestamp(row.lease_expires_at)) {
      throw new TypeError("Invalid export claim");
    }
    return uuidFields(row, [
      "household_export_id", "household_id", "lease_token", "privacy_request_id",
    ]);
  });
}

function purgeClaimRows(payload) {
  if (!Array.isArray(payload) || payload.length > 10) throw new TypeError("Invalid purge claims");
  return payload.map((row) => {
    exactKeys(row, [
      "attempts", "household_export_id", "human_object_key", "lease_expires_at",
      "lease_token", "machine_object_key", "privacy_request_id",
    ]);
    if (!positiveInteger(row.attempts) || !validTimestamp(row.lease_expires_at) ||
      !validObjectKey(row.machine_object_key, "json") ||
      !validObjectKey(row.human_object_key, "txt")) {
      throw new TypeError("Invalid purge claim");
    }
    return uuidFields(row, ["household_export_id", "lease_token", "privacy_request_id"]);
  });
}

function deletionClaimRows(payload) {
  if (!Array.isArray(payload) || payload.length > 5) {
    throw new TypeError("Invalid deletion claims");
  }
  return payload.map((row) => {
    exactKeys(row, [
      "attempts", "household_id", "lease_expires_at", "lease_token",
      "privacy_request_id",
    ]);
    if (!positiveInteger(row.attempts) || !validTimestamp(row.lease_expires_at)) {
      throw new TypeError("Invalid deletion claim");
    }
    return uuidFields(row, ["household_id", "lease_token", "privacy_request_id"]);
  });
}

function privacyResult(payload, expectedRequestId) {
  const value = resultValue(payload);
  if (!validUuid(value.requestId) || value.requestId.toLowerCase() !== expectedRequestId ||
    !["export", "deletion"].includes(value.kind) ||
    !["processing", "completed", "failed"].includes(value.status) ||
    (value.failureCode !== null && typeof value.failureCode !== "string")) {
    throw new TypeError("Invalid household worker result");
  }
  if (value.artifact !== null && value.artifact !== undefined) {
    if (!isPlainObject(value.artifact) || !validUuid(value.artifact.id) ||
      !positiveInteger(value.artifact.version)) {
      throw new TypeError("Invalid worker artifact result");
    }
    value.artifact = {...value.artifact, id: value.artifact.id.toLowerCase()};
  }
  if (value.deletion !== null && value.deletion !== undefined &&
    !isPlainObject(value.deletion)) {
    throw new TypeError("Invalid worker deletion result");
  }
  return value;
}

function resultValue(payload) {
  const row = singleRow(payload);
  exactKeys(row, ["result"]);
  if (!isPlainObject(row.result)) throw new TypeError("Invalid worker result");
  return row.result;
}

function normalizedExportFailure(error) {
  if (error instanceof HouseholdPrivacyWorkerFailure) return error;
  return new HouseholdPrivacyWorkerFailure("EXPORT_BUILD_UNAVAILABLE", true);
}

function normalizedPurgeFailure(error) {
  if (error instanceof HouseholdPrivacyWorkerFailure) return error;
  return new HouseholdPrivacyWorkerFailure("EXPORT_PURGE_UNAVAILABLE", true);
}

function normalizedDeletionFailure(error) {
  if (error instanceof HouseholdPrivacyWorkerFailure) return error;
  return new HouseholdPrivacyWorkerFailure("HOUSEHOLD_REDACTION_UNAVAILABLE", true);
}

function exportFailureCode(code) {
  return [
    "OWNER_AUTHORIZATION_CHANGED", "HOUSEHOLD_ALREADY_DELETED",
    "EXPORT_BUILD_UNAVAILABLE", "EXPORT_UPLOAD_UNAVAILABLE",
    "EXPORT_SIZE_LIMIT_EXCEEDED", "PROCESSING_PRECONDITION_FAILED",
  ].includes(code) ? code : "EXPORT_BUILD_UNAVAILABLE";
}

function deletionFailureCode(code) {
  return [
    "OWNER_AUTHORIZATION_CHANGED", "HOUSEHOLD_ALREADY_DELETED",
    "HOUSEHOLD_REDACTION_UNAVAILABLE", "PROCESSING_PRECONDITION_FAILED",
  ].includes(code) ? code : "HOUSEHOLD_REDACTION_UNAVAILABLE";
}

async function sha256Hex(bytes) {
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
  return [...digest].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function validObjectKey(value, extension) {
  return typeof value === "string" && new RegExp(
    `^household-exports/[0-9a-f-]{36}/kinflow-household\\.${extension}$`,
  ).test(value);
}

function uuidFields(row, keys) {
  const result = {...row};
  for (const key of keys) {
    if (!validUuid(result[key])) throw new TypeError("Invalid UUID");
    result[key] = result[key].toLowerCase();
  }
  return result;
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
  if (actual.length !== sorted.length ||
    actual.some((key, index) => key !== sorted[index])) {
    throw new TypeError("Unexpected worker fields");
  }
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
          : ["VALIDATION_FAILED", "METHOD_NOT_ALLOWED"].includes(code)
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
  return validUuid(candidate) ? candidate.toLowerCase() : crypto.randomUUID();
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

function validUuid(value) {
  return typeof value === "string" && uuidPattern.test(value);
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

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
