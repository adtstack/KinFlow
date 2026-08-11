import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import {describe, test} from "node:test";

import {
  createHouseholdExportDownloadHandler,
  HouseholdExportDownloadFailure,
} from "../functions/_shared/household_export_download_contract.mjs";

const requestId = "70000000-0000-4000-8000-000000000101";
const artifactId = "78000000-0000-4000-8000-000000000101";
const bytes = new TextEncoder().encode('{"schemaVersion":"2026-08-08-wp07-02b"}\n');
const checksum = createHash("sha256").update(bytes).digest("hex");
const tokenBytes = Uint8Array.from({length: 32}, (_, index) => index + 1);
const token = Buffer.from(tokenBytes).toString("base64url");

describe("household export one-time download contract", () => {
  test("consumes a hash-only grant verifies bytes and returns an attachment", async () => {
    const calls = [];
    const response = await createHouseholdExportDownloadHandler({
      consumeGrant: async (parameters) => {
        calls.push(parameters);
        return [artifactRow()];
      },
      downloadObject: async (objectKey) => {
        calls.push(objectKey);
        return bytes;
      },
    })(downloadRequest(token));
    assert.equal(response.status, 200);
    assert.equal(response.headers.get("content-disposition"),
      'attachment; filename="kinflow-household.json"');
    assert.equal(response.headers.get("cache-control"), "private, no-store, max-age=0");
    assert.equal(response.headers.get("x-content-sha256"), checksum);
    assert.deepEqual(new Uint8Array(await response.arrayBuffer()), bytes);
    assert.equal(calls[0].p_token_hash_base64,
      createHash("sha256").update(tokenBytes).digest("base64"));
    assert.equal(calls[1], `household-exports/${artifactId}/kinflow-household.json`);
  });

  test("consumed or expired grant is a redacted terminal response", async () => {
    const response = await createHouseholdExportDownloadHandler({
      consumeGrant: async () => {
        throw new HouseholdExportDownloadFailure("DOWNLOAD_GRANT_INVALID");
      },
      downloadObject: async () => { throw new Error("must not run"); },
    })(downloadRequest(token));
    assert.equal(response.status, 410);
    const body = await response.text();
    assert.match(body, /DOWNLOAD_GRANT_INVALID/);
    assert.doesNotMatch(body, new RegExp(token));
  });

  test("checksum size and 20 MiB bound fail closed after consumption", async () => {
    for (const row of [
      artifactRow({checksum_sha256: "0".repeat(64)}),
      artifactRow({size_bytes: bytes.byteLength + 1}),
      artifactRow({size_bytes: 20 * 1024 * 1024 + 1}),
    ]) {
      const response = await createHouseholdExportDownloadHandler({
        consumeGrant: async () => [row],
        downloadObject: async () => bytes,
      })(downloadRequest(token));
      assert.equal(response.status, 503);
      assert.equal((await response.json()).error.code, "TEMPORARILY_UNAVAILABLE");
    }
  });

  test("method duplicate query malformed token path and metadata fail closed", async () => {
    let calls = 0;
    const handler = createHouseholdExportDownloadHandler({
      consumeGrant: async () => {
        calls += 1;
        return [{...artifactRow(), provider_ref: "private"}];
      },
      downloadObject: async () => bytes,
    });
    assert.equal((await handler(new Request(
      `https://api.test/download?token=${token}`,
      {method: "POST"},
    ))).status, 405);
    for (const url of [
      `https://api.test/download?token=${token}&token=${token}`,
      "https://api.test/download?token=short",
      "https://api.test/download?extra=value",
    ]) {
      assert.equal((await handler(new Request(url))).status, 410);
    }
    const malformed = await handler(downloadRequest(token));
    assert.equal(malformed.status, 503);
    assert.doesNotMatch(await malformed.text(), /provider_ref|private/);
    assert.equal(calls, 1);
  });
});

function downloadRequest(rawToken) {
  return new Request(`https://api.test/download?token=${rawToken}`, {
    headers: {"x-request-id": requestId},
  });
}

function artifactRow(overrides = {}) {
  return {
    export_format: "json",
    object_key: `household-exports/${artifactId}/kinflow-household.json`,
    file_name: "kinflow-household.json",
    content_type: "application/json; charset=utf-8",
    checksum_sha256: checksum,
    size_bytes: bytes.byteLength,
    ...overrides,
  };
}
