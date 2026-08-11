import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import {describe, test} from "node:test";

import {
  createDataExportDownloadHandler,
  DataExportDownloadFailure,
} from "../functions/_shared/data_export_download_contract.mjs";

const requestId = "70000000-0000-4000-8000-000000000101";
const artifactPrefix = "78000000-0000-4000-8000-000000000101";
const bytes = new TextEncoder().encode('{"schemaVersion":"2026-08-08-wp07-02a"}\n');
const checksum = createHash("sha256").update(bytes).digest("hex");
const tokenBytes = Uint8Array.from({length: 32}, (_, index) => index + 1);
const token = Buffer.from(tokenBytes).toString("base64url");

describe("personal data export one-time download contract", () => {
  test("consumes a hash-only grant, verifies bytes, and returns an attachment", async () => {
    const calls = [];
    const handler = createDataExportDownloadHandler({
      consumeGrant: async (parameters) => {
        calls.push(parameters);
        return [artifactRow()];
      },
      downloadObject: async (objectKey) => {
        calls.push(objectKey);
        return bytes;
      },
    });
    const response = await handler(downloadRequest(token));
    assert.equal(response.status, 200);
    assert.equal(response.headers.get("content-disposition"),
      'attachment; filename="kinflow-data.json"');
    assert.equal(response.headers.get("cache-control"), "private, no-store, max-age=0");
    assert.equal(response.headers.get("x-content-sha256"), checksum);
    assert.deepEqual(new Uint8Array(await response.arrayBuffer()), bytes);
    assert.equal(calls[0].p_token_hash_base64,
      createHash("sha256").update(tokenBytes).digest("base64"));
    assert.equal(calls[1], `exports/${artifactPrefix}/kinflow-data.json`);
  });

  test("an already consumed or expired grant is a redacted terminal response", async () => {
    const handler = createDataExportDownloadHandler({
      consumeGrant: async () => {
        throw new DataExportDownloadFailure("DOWNLOAD_GRANT_INVALID");
      },
      downloadObject: async () => { throw new Error("must not run"); },
    });
    const response = await handler(downloadRequest(token));
    assert.equal(response.status, 410);
    const body = await response.text();
    assert.match(body, /DOWNLOAD_GRANT_INVALID/);
    assert.doesNotMatch(body, new RegExp(token));
  });

  test("checksum or size mismatch fails closed after grant consumption", async () => {
    for (const row of [
      artifactRow({checksum_sha256: "0".repeat(64)}),
      artifactRow({size_bytes: bytes.byteLength + 1}),
    ]) {
      const handler = createDataExportDownloadHandler({
        consumeGrant: async () => [row],
        downloadObject: async () => bytes,
      });
      const response = await handler(downloadRequest(token));
      assert.equal(response.status, 503);
      assert.equal((await response.json()).error.code, "TEMPORARILY_UNAVAILABLE");
    }
  });

  test("method, duplicated query, malformed token, and unexpected metadata fail closed", async () => {
    let calls = 0;
    const handler = createDataExportDownloadHandler({
      consumeGrant: async () => {
        calls += 1;
        return [{...artifactRow(), provider_ref: "private"}];
      },
      downloadObject: async () => bytes,
    });
    const method = await handler(new Request(`https://api.test/download?token=${token}`, {
      method: "POST",
    }));
    assert.equal(method.status, 405);
    for (const url of [
      `https://api.test/download?token=${token}&token=${token}`,
      "https://api.test/download?token=short",
      "https://api.test/download?extra=value",
    ]) {
      const response = await handler(new Request(url));
      assert.equal(response.status, 410);
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
    object_key: `exports/${artifactPrefix}/kinflow-data.json`,
    file_name: "kinflow-data.json",
    content_type: "application/json; charset=utf-8",
    checksum_sha256: checksum,
    size_bytes: bytes.byteLength,
    ...overrides,
  };
}
