import assert from "node:assert/strict";
import test from "node:test";

import {
  runtimePolicyClientHeadersFor,
  runtimePolicyClientHeaderNames,
  runtimePolicyCorsAllowHeaders,
  runtimePolicyServiceHeaders,
} from "../../supabase/functions/_shared/runtime_policy_headers.mjs";

const compatibilityHeaders = Object.freeze({
  "x-kinflow-client-version": "0.1.0-dev+10",
  "x-kinflow-client-build": "10",
  "x-kinflow-contract-version": "2026-08-09",
  "x-kinflow-platform": "android",
  "x-kinflow-environment": "dev",
});

test("client compatibility extraction is an exact non-privileged allowlist", () => {
  const request = new Request("http://local/runtime-policy", {
    headers: {
      ...compatibilityHeaders,
      authorization: "Bearer private-session",
      "x-kinflow-forwarded-user-operation": "0",
      "x-unrelated": "must-not-forward",
    },
  });

  assert.deepEqual(
    runtimePolicyClientHeadersFor(request),
    compatibilityHeaders,
  );
  assert.deepEqual(
    runtimePolicyClientHeaderNames,
    Object.keys(compatibilityHeaders),
  );
  assert.equal(
    runtimePolicyCorsAllowHeaders,
    Object.keys(compatibilityHeaders).join(", "),
  );
});

test("service forwarding owns the marker and rejects malformed values", () => {
  const headers = runtimePolicyServiceHeaders({
    ...compatibilityHeaders,
    "x-kinflow-client-build": "\t",
    "x-kinflow-forwarded-user-operation": "0",
    authorization: "Bearer private-session",
  });

  assert.deepEqual(headers, {
    "x-kinflow-forwarded-user-operation": "1",
    ...compatibilityHeaders,
    "x-kinflow-client-build": "__invalid_runtime_policy_header__",
  });
  assert.equal(Object.isFrozen(headers), true);
  assert.deepEqual(runtimePolicyClientHeadersFor(
    new Request("http://local/runtime-policy"),
  ), {});
});
