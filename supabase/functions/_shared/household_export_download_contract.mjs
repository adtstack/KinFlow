export const householdExportDownloadContractVersion = "2026-08-08-wp07-02b";

const maximumArtifactBytes = 20 * 1024 * 1024;
const tokenPattern = /^[A-Za-z0-9_-]{43}$/;
const objectKeyPattern =
  /^household-exports\/[0-9a-f-]{36}\/kinflow-household\.(json|txt)$/;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export class HouseholdExportDownloadFailure extends Error {
  constructor(code = "TEMPORARILY_UNAVAILABLE") {
    super("Household export download failed");
    this.name = "HouseholdExportDownloadFailure";
    this.code = code;
  }
}

export function createHouseholdExportDownloadHandler({consumeGrant, downloadObject}) {
  return async function handleHouseholdExportDownload(request) {
    const requestId = requestIdFor(request);
    if (request.method !== "GET") {
      return errorResponse("METHOD_NOT_ALLOWED", 405, false, requestId);
    }
    const token = tokenFor(request.url);
    if (token === null) {
      return errorResponse("DOWNLOAD_GRANT_INVALID", 410, false, requestId);
    }
    try {
      const tokenBytes = decodeBase64Url(token);
      const tokenHash = new Uint8Array(await crypto.subtle.digest("SHA-256", tokenBytes));
      const artifact = artifactRow(await consumeGrant({
        p_as_of: new Date().toISOString(),
        p_token_hash_base64: base64(tokenHash),
      }));
      const bytes = await downloadObject(artifact.object_key);
      if (!(bytes instanceof Uint8Array) || bytes.byteLength !== artifact.size_bytes ||
        bytes.byteLength > maximumArtifactBytes) {
        throw new HouseholdExportDownloadFailure();
      }
      const checksum = hex(new Uint8Array(await crypto.subtle.digest("SHA-256", bytes)));
      if (!constantTimeEqual(checksum, artifact.checksum_sha256)) {
        throw new HouseholdExportDownloadFailure();
      }
      return new Response(bytes, {status: 200, headers: artifactHeaders(artifact, requestId)});
    } catch (error) {
      const invalid = error instanceof HouseholdExportDownloadFailure &&
        error.code === "DOWNLOAD_GRANT_INVALID";
      return errorResponse(
        invalid ? "DOWNLOAD_GRANT_INVALID" : "TEMPORARILY_UNAVAILABLE",
        invalid ? 410 : 503,
        !invalid,
        requestId,
      );
    }
  };
}

function artifactRow(payload) {
  if (!Array.isArray(payload) || payload.length !== 1 || !isPlainObject(payload[0])) {
    throw new TypeError("Invalid household download grant payload");
  }
  const row = payload[0];
  exactKeys(row, [
    "checksum_sha256", "content_type", "export_format",
    "file_name", "object_key", "size_bytes",
  ]);
  const expected = row.export_format === "json"
    ? ["kinflow-household.json", "application/json; charset=utf-8", "json"]
    : ["kinflow-household.txt", "text/plain; charset=utf-8", "txt"];
  if (!["json", "text"].includes(row.export_format) ||
    row.file_name !== expected[0] || row.content_type !== expected[1] ||
    typeof row.object_key !== "string" || !objectKeyPattern.test(row.object_key) ||
    !row.object_key.endsWith(`.${expected[2]}`) ||
    typeof row.checksum_sha256 !== "string" ||
    !/^[0-9a-f]{64}$/.test(row.checksum_sha256) ||
    !Number.isSafeInteger(row.size_bytes) || row.size_bytes < 1 ||
    row.size_bytes > maximumArtifactBytes) {
    throw new TypeError("Invalid household download artifact metadata");
  }
  return row;
}

function tokenFor(rawUrl) {
  let url;
  try {
    url = new URL(rawUrl);
  } catch {
    return null;
  }
  if (url.searchParams.size !== 1 || !url.searchParams.has("token")) return null;
  const values = url.searchParams.getAll("token");
  return values.length === 1 && tokenPattern.test(values[0]) ? values[0] : null;
}

function decodeBase64Url(value) {
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
  const binary = atob(normalized.padEnd(44, "="));
  const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
  if (bytes.byteLength !== 32) throw new TypeError("Invalid token");
  return bytes;
}

function artifactHeaders(artifact, requestId) {
  return new Headers({
    "cache-control": "private, no-store, max-age=0",
    "content-disposition": `attachment; filename="${artifact.file_name}"`,
    "content-length": String(artifact.size_bytes),
    "content-security-policy": "default-src 'none'; sandbox",
    "content-type": artifact.content_type,
    "referrer-policy": "no-referrer",
    "x-content-sha256": artifact.checksum_sha256,
    "x-content-type-options": "nosniff",
    "x-request-id": requestId,
  });
}

function errorResponse(code, status, retryable, requestId) {
  return Response.json(
    {
      error: {
        code,
        messageKey: code === "DOWNLOAD_GRANT_INVALID"
          ? "errors.householdExportUnavailable"
          : code === "METHOD_NOT_ALLOWED"
          ? "errors.validationFailed"
          : "errors.temporarilyUnavailable",
        retryable,
        requestId,
      },
    },
    {status, headers: errorHeaders(requestId)},
  );
}

function errorHeaders(requestId) {
  return new Headers({
    "allow": "GET",
    "cache-control": "private, no-store, max-age=0",
    "content-type": "application/json; charset=utf-8",
    "content-security-policy": "default-src 'none'; sandbox",
    "referrer-policy": "no-referrer",
    "x-content-type-options": "nosniff",
    "x-request-id": requestId,
  });
}

function requestIdFor(request) {
  const candidate = request.headers.get("x-request-id")?.trim() ?? "";
  return uuidPattern.test(candidate) ? candidate.toLowerCase() : crypto.randomUUID();
}

function base64(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function hex(bytes) {
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
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

function exactKeys(value, expected) {
  const actual = Object.keys(value).sort();
  const sorted = [...expected].sort();
  if (actual.length !== sorted.length ||
    actual.some((key, index) => key !== sorted[index])) {
    throw new TypeError("Unexpected household download fields");
  }
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
