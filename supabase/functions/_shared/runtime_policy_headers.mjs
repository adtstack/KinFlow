export const runtimePolicyClientHeaderNames = Object.freeze([
  "x-kinflow-client-version",
  "x-kinflow-client-build",
  "x-kinflow-contract-version",
  "x-kinflow-platform",
  "x-kinflow-environment",
]);

export const runtimePolicyCorsAllowHeaders =
  runtimePolicyClientHeaderNames.join(", ");

const invalidHeaderSentinel = "__invalid_runtime_policy_header__";
const maximumHeaderLength = 128;
const controlCharacterPattern = /[\u0000-\u001f\u007f]/;

export function runtimePolicyClientHeadersFor(request) {
  if (!(request instanceof Request)) {
    throw new TypeError("Invalid runtime policy request");
  }
  const forwarded = {};
  for (const name of runtimePolicyClientHeaderNames) {
    const value = request.headers.get(name);
    if (value === null) continue;
    const normalized = value.trim();
    forwarded[name] = normalized.length > 0 &&
        normalized.length <= maximumHeaderLength &&
        !controlCharacterPattern.test(normalized)
      ? normalized
      : invalidHeaderSentinel;
  }
  return Object.freeze(forwarded);
}

export function runtimePolicyServiceHeaders(clientHeaders) {
  const headers = {
    "x-kinflow-forwarded-user-operation": "1",
  };
  if (clientHeaders === null ||
    typeof clientHeaders !== "object" ||
    Array.isArray(clientHeaders)) {
    return Object.freeze(headers);
  }
  for (const name of runtimePolicyClientHeaderNames) {
    if (!Object.hasOwn(clientHeaders, name)) continue;
    const value = clientHeaders[name];
    headers[name] = typeof value === "string" &&
        value.length > 0 &&
        value.length <= maximumHeaderLength &&
        !controlCharacterPattern.test(value)
      ? value
      : invalidHeaderSentinel;
  }
  return Object.freeze(headers);
}
