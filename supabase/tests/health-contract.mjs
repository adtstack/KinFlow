import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";

const schema = JSON.parse(
  await readFile(
    new URL("../../contracts/supabase-health.schema.json", import.meta.url),
    "utf8",
  ),
);

const baseUrl = process.env.KINFLOW_LOCAL_FUNCTIONS_URL ??
  "http://127.0.0.1:54321/functions/v1";
const requestId = "wp01-04-health";

const response = await fetch(`${baseUrl}/health`, {
  headers: {"x-request-id": requestId},
});

assert.equal(response.status, 200);
assert.match(response.headers.get("content-type") ?? "", /^application\/json/);
assert.equal(response.headers.get("cache-control"), "no-store");
assert.equal(response.headers.get("x-request-id"), requestId);

const payload = await response.json();
const requiredKeys = [
  "contractVersion",
  "environment",
  "requestId",
  "service",
  "status",
];
assert.equal(schema.additionalProperties, false);
assert.deepEqual([...schema.required].sort(), requiredKeys);
assert.deepEqual(Object.keys(payload).sort(), requiredKeys);
assert.deepEqual(payload, {
  status: schema.properties.status.const,
  service: schema.properties.service.const,
  contractVersion: schema.properties.contractVersion.const,
  environment: schema.properties.environment.const,
  requestId,
});
assert.match(requestId, new RegExp(schema.properties.requestId.pattern));
assert.ok(requestId.length >= schema.properties.requestId.minLength);
assert.ok(requestId.length <= schema.properties.requestId.maxLength);

const rejected = await fetch(`${baseUrl}/health`, {method: "DELETE"});
assert.equal(rejected.status, 405);
const rejectedPayload = await rejected.json();
assert.deepEqual(Object.keys(rejectedPayload).sort(), [
  "code",
  "requestId",
  "status",
]);
assert.equal(rejectedPayload.status, "error");
assert.equal(rejectedPayload.code, "METHOD_NOT_ALLOWED");
assert.equal(typeof rejectedPayload.requestId, "string");

process.stdout.write("Supabase health contract passed.\n");
