import assert from "node:assert/strict";
import {randomBytes, randomUUID} from "node:crypto";

const apiUrl = requiredEnvironment("KINFLOW_LOCAL_SUPABASE_API_URL").replace(/\/$/, "");
const functionsUrl = requiredEnvironment("KINFLOW_LOCAL_SUPABASE_FUNCTIONS_URL").replace(/\/$/, "");
const serviceRoleKey = requiredEnvironment("KINFLOW_LOCAL_SUPABASE_SERVICE_ROLE_KEY");

for (const url of [apiUrl, functionsUrl]) {
  const host = new URL(url).hostname;
  assert.ok(["127.0.0.1", "localhost"].includes(host), "invite live test is local-only");
}

const ownerUserId = "00000000-0000-4000-8000-000000000101";
const existingMemberUserId = "00000000-0000-4000-8000-000000000102";
const otherHouseholdUserId = "00000000-0000-4000-8000-000000000201";
const householdId = "20000000-0000-4000-8000-000000000101";

const raceInvite = await createInviteFixture();
const preview = await fetch(`${functionsUrl}/preview-invite`, {
  method: "POST",
  headers: {
    "content-type": "application/json",
    "x-forwarded-for": "192.0.2.10",
    "x-request-id": randomUUID(),
  },
  body: JSON.stringify({token: raceInvite.rawToken}),
});
const previewPayload = await preview.json();
assert.equal(
  preview.status,
  200,
  `valid preview failed with ${previewPayload?.error?.code ?? "unknown"}`,
);
assert.deepEqual(Object.keys(previewPayload.data).sort(), [
  "expiresAt",
  "householdDisplayName",
  "inviterDisplayName",
  "role",
  "valid",
]);
assert.equal(previewPayload.data.householdDisplayName, "Primary Local Household");
assert.equal(previewPayload.data.inviterDisplayName, "Adult A");
assert.equal(JSON.stringify(previewPayload).includes(raceInvite.rawToken), false);

const invalidRawToken = randomBytes(32).toString("base64url");
const invalidPreview = await fetch(`${functionsUrl}/preview-invite`, {
  method: "POST",
  headers: {
    "content-type": "application/json",
    "x-forwarded-for": "192.0.2.11",
    "x-request-id": randomUUID(),
  },
  body: JSON.stringify({token: invalidRawToken}),
});
assert.equal(invalidPreview.status, 404);
const invalidPayload = await invalidPreview.json();
assert.equal(invalidPayload.error.code, "INVITE_INVALID");
assert.equal(JSON.stringify(invalidPayload).includes(invalidRawToken), false);

const [firstContender, secondContender] = await Promise.all([
  acceptInvite({
    userId: existingMemberUserId,
    idempotencyKey: randomUUID(),
    tokenHashHex: raceInvite.tokenHashHex,
  }),
  acceptInvite({
    userId: otherHouseholdUserId,
    idempotencyKey: randomUUID(),
    tokenHashHex: raceInvite.tokenHashHex,
  }),
]);
const contenders = [firstContender, secondContender];
assert.equal(contenders.filter((result) => result.response.ok).length, 1);
const losingResult = contenders.find((result) => !result.response.ok);
assert.equal(losingResult?.payload?.code, "KFI09");

const idempotentInvite = await createInviteFixture();
const sameAcceptKey = randomUUID();
const [firstRetry, secondRetry] = await Promise.all([
  acceptInvite({
    userId: existingMemberUserId,
    idempotencyKey: sameAcceptKey,
    tokenHashHex: idempotentInvite.tokenHashHex,
  }),
  acceptInvite({
    userId: existingMemberUserId,
    idempotencyKey: sameAcceptKey,
    tokenHashHex: idempotentInvite.tokenHashHex,
  }),
]);
assert.equal(firstRetry.response.status, 200);
assert.equal(secondRetry.response.status, 200);
assert.equal(firstRetry.payload[0].member_id, secondRetry.payload[0].member_id);
assert.equal(firstRetry.payload[0].household_id, householdId);

process.stdout.write("Invite Edge live preview and concurrent/idempotent accept passed.\n");

async function createInviteFixture() {
  const rawToken = randomBytes(32).toString("base64url");
  const tokenHashHex = Buffer.from(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(rawToken)),
  ).toString("hex");
  const result = await rpc("create_household_invite", {
    p_authenticated_user_id: ownerUserId,
    p_household_id: householdId,
    p_idempotency_key: randomUUID(),
    p_token_hash_hex: tokenHashHex,
    p_role: "member",
    p_target_email: null,
    p_expires_in_hours: 24,
  });
  assert.equal(result.response.status, 200);
  assert.equal(result.payload.length, 1);
  assert.equal(result.payload[0].created, true);
  return {rawToken, tokenHashHex};
}

async function acceptInvite({userId, idempotencyKey, tokenHashHex}) {
  return rpc("accept_household_invite", {
    p_authenticated_user_id: userId,
    p_idempotency_key: idempotencyKey,
    p_token_hash_hex: tokenHashHex,
    p_set_active_household: false,
  });
}

async function rpc(name, body) {
  const response = await fetch(`${apiUrl}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      apikey: serviceRoleKey,
      authorization: `Bearer ${serviceRoleKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
  let payload = null;
  try {
    payload = await response.json();
  } catch {
    // Assertion below reports only status/shape and never credential material.
  }
  return {response, payload};
}

function requiredEnvironment(name) {
  const value = process.env[name]?.trim() ?? "";
  assert.notEqual(value, "", `missing ${name}`);
  return value;
}
