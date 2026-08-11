import {
  createNotificationPushHandler,
  notificationPushEnvelopeContractVersion,
} from "./notification_push_contract.mjs";
import {
  createNotificationWorkerRpcInvoker,
} from "./notification_worker_contract.mjs";
import {matchesWorkerSecret} from "./notification_worker_runtime.mjs";
import {sha256Base64} from "./notification_endpoint_runtime.mjs";

const firebaseMessagingScope =
  "https://www.googleapis.com/auth/firebase.messaging";
const googleTokenEndpoint = "https://oauth2.googleapis.com/token";
const providerTokenPattern = /^[\x21-\x7e]{20,4096}$/;
const pkcs8Label = ["PRIVATE", "KEY"].join(" ");
const pkcs8Begin = `-----BEGIN ${pkcs8Label}-----`;
const pkcs8End = `-----END ${pkcs8Label}-----`;

export function serveNotificationPushWorker() {
  const serviceAccount = parseFirebaseServiceAccount(
    requiredEnvironment("KINFLOW_FIREBASE_SERVICE_ACCOUNT_JSON"),
  );
  const openToken = createNotificationTokenOpener({
    keyMaterialsByVersion: parseNotificationTokenKeyring(
      requiredEnvironment("KINFLOW_NOTIFICATION_TOKEN_DECRYPTION_KEYS"),
    ),
  });
  const getAccessToken = createFirebaseAccessTokenProvider({serviceAccount});
  const sendFcm = createFcmHttpV1Sender({
    androidPackageName: requiredAndroidPackageName(
      "KINFLOW_ANDROID_PACKAGE_NAME",
    ),
    getAccessToken,
    projectId: serviceAccount.projectId,
  });
  const workerSecret = requiredSecretEnvironment(
    "KINFLOW_NOTIFICATION_PUSH_WORKER_SECRET",
  );
  const handler = createNotificationPushHandler({
    authorizeRequest: (authorization) => matchesWorkerSecret(
      authorization,
      workerSecret,
    ),
    batchSize: boundedIntegerEnvironment(
      "KINFLOW_NOTIFICATION_PUSH_BATCH_SIZE",
      20,
      1,
      100,
    ),
    invokeRpc: createNotificationWorkerRpcInvoker({
      serviceRoleKey: requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY"),
      supabaseUrl: requiredEnvironment("SUPABASE_URL"),
    }),
    leaseSeconds: boundedIntegerEnvironment(
      "KINFLOW_NOTIFICATION_PUSH_LEASE_SECONDS",
      60,
      5,
      300,
    ),
    openToken,
    sendFcm,
    sha256Base64,
  });
  Deno.serve(handler);
}

export function parseNotificationTokenKeyring(value) {
  let parsed;
  try {
    parsed = JSON.parse(value);
  } catch {
    throw new TypeError("Invalid notification token keyring");
  }
  if (!isPlainObject(parsed) ||
    Object.keys(parsed).length < 1 ||
    Object.keys(parsed).length > 10) {
    throw new TypeError("Invalid notification token keyring");
  }
  const result = {};
  for (const [rawVersion, material] of Object.entries(parsed)) {
    if (!/^[1-9][0-9]{0,5}$/.test(rawVersion)) {
      throw new TypeError("Invalid notification token keyring");
    }
    const version = Number(rawVersion);
    const bytes = decodeCanonicalBase64(material, 32, 32);
    if (!Number.isSafeInteger(version) || version > 1000000) {
      throw new TypeError("Invalid notification token keyring");
    }
    result[version] = bytes;
  }
  return Object.freeze(result);
}

export function createNotificationTokenOpener({keyMaterialsByVersion}) {
  if (!isPlainObject(keyMaterialsByVersion) ||
    Object.keys(keyMaterialsByVersion).length < 1 ||
    Object.keys(keyMaterialsByVersion).length > 10) {
    throw new TypeError("Invalid notification token opener configuration");
  }
  const keyPromises = new Map();
  for (const [rawVersion, material] of Object.entries(keyMaterialsByVersion)) {
    const version = Number(rawVersion);
    const bytes = material instanceof Uint8Array
      ? material
      : decodeCanonicalBase64(material, 32, 32);
    if (!Number.isSafeInteger(version) || version < 1 || version > 1000000 ||
      bytes.byteLength !== 32) {
      throw new TypeError("Invalid notification token opener configuration");
    }
    keyPromises.set(version, crypto.subtle.importKey(
      "raw",
      bytes,
      {name: "AES-GCM"},
      false,
      ["decrypt"],
    ));
  }

  return async function openToken({ciphertextBase64, keyVersion}) {
    if (!Number.isSafeInteger(keyVersion) || !keyPromises.has(keyVersion)) {
      throw new TypeError("Unknown notification token key version");
    }
    const envelope = decodeCanonicalBase64(ciphertextBase64, 29, 8192);
    const iv = envelope.slice(0, 12);
    const ciphertext = envelope.slice(12);
    const plaintext = await crypto.subtle.decrypt(
      {
        name: "AES-GCM",
        iv,
        additionalData: new TextEncoder().encode(
          `kinflow:notification-token:v${keyVersion}`,
        ),
        tagLength: 128,
      },
      await keyPromises.get(keyVersion),
      ciphertext,
    );
    const token = new TextDecoder("utf-8", {fatal: true}).decode(plaintext);
    if (!providerTokenPattern.test(token)) {
      throw new TypeError("Invalid decrypted notification token");
    }
    return token;
  };
}

export function parseFirebaseServiceAccount(value) {
  let parsed;
  try {
    parsed = typeof value === "string" ? JSON.parse(value) : value;
  } catch {
    throw new TypeError("Invalid Firebase service account");
  }
  if (!isPlainObject(parsed) ||
    parsed.type !== "service_account" ||
    !projectIdPattern(parsed.project_id) ||
    typeof parsed.client_email !== "string" ||
    !/^[A-Za-z0-9._%+-]{1,128}@[A-Za-z0-9.-]{1,190}\.iam\.gserviceaccount\.com$/.test(
      parsed.client_email,
    ) ||
    typeof parsed.private_key !== "string" ||
    !parsed.private_key.startsWith(`${pkcs8Begin}\n`) ||
    !parsed.private_key.endsWith(`\n${pkcs8End}\n`)) {
    throw new TypeError("Invalid Firebase service account");
  }
  return Object.freeze({
    clientEmail: parsed.client_email,
    privateKey: parsed.private_key,
    projectId: parsed.project_id,
  });
}

export function createFirebaseServiceAccountJwtSigner({
  clientEmail,
  privateKey,
}) {
  if (typeof clientEmail !== "string" ||
    !clientEmail.endsWith(".iam.gserviceaccount.com") ||
    typeof privateKey !== "string") {
    throw new TypeError("Invalid Firebase JWT signer configuration");
  }
  const pkcs8 = pemPrivateKeyBytes(privateKey);
  const keyPromise = crypto.subtle.importKey(
    "pkcs8",
    pkcs8,
    {name: "RSASSA-PKCS1-v1_5", hash: "SHA-256"},
    false,
    ["sign"],
  );
  const encodedHeader = base64UrlEncode(
    new TextEncoder().encode(JSON.stringify({alg: "RS256", typ: "JWT"})),
  );

  return async function createAssertion(issuedAtSeconds) {
    if (!Number.isSafeInteger(issuedAtSeconds) || issuedAtSeconds < 0) {
      throw new TypeError("Invalid Firebase JWT clock");
    }
    const encodedClaims = base64UrlEncode(new TextEncoder().encode(JSON.stringify({
      aud: googleTokenEndpoint,
      exp: issuedAtSeconds + 3600,
      iat: issuedAtSeconds,
      iss: clientEmail,
      scope: firebaseMessagingScope,
    })));
    const signingInput = `${encodedHeader}.${encodedClaims}`;
    const signature = new Uint8Array(await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      await keyPromise,
      new TextEncoder().encode(signingInput),
    ));
    return `${signingInput}.${base64UrlEncode(signature)}`;
  };
}

export function createFirebaseAccessTokenProvider({
  clockSeconds = () => Math.floor(Date.now() / 1000),
  createAssertion,
  fetchImplementation = globalThis.fetch,
  serviceAccount,
  timeoutMilliseconds = 8000,
}) {
  if (!isPlainObject(serviceAccount) ||
    !projectIdPattern(serviceAccount.projectId) ||
    typeof serviceAccount.clientEmail !== "string" ||
    typeof serviceAccount.privateKey !== "string" ||
    typeof clockSeconds !== "function" ||
    typeof fetchImplementation !== "function" ||
    !integerBetween(timeoutMilliseconds, 1000, 30000)) {
    throw new TypeError("Invalid Firebase token provider configuration");
  }
  const assertionFactory = createAssertion ??
    createFirebaseServiceAccountJwtSigner(serviceAccount);
  if (typeof assertionFactory !== "function") {
    throw new TypeError("Invalid Firebase token provider configuration");
  }
  let cached = null;

  return async function getAccessToken() {
    const now = clockSeconds();
    if (!Number.isSafeInteger(now) || now < 0) {
      throw new TypeError("Invalid Firebase token clock");
    }
    if (cached !== null && cached.expiresAt - 60 > now) {
      return cached.value;
    }
    const assertion = await assertionFactory(now);
    if (typeof assertion !== "string" || assertion.split(".").length !== 3) {
      throw new TypeError("Invalid Firebase assertion");
    }
    let response;
    try {
      response = await fetchImplementation(googleTokenEndpoint, {
        method: "POST",
        headers: {"content-type": "application/x-www-form-urlencoded"},
        body: new URLSearchParams({
          assertion,
          grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        }).toString(),
        signal: AbortSignal.timeout(timeoutMilliseconds),
      });
    } catch {
      throw new TypeError("Firebase token exchange unavailable");
    }
    if (!response.ok) {
      throw new TypeError("Firebase token exchange rejected");
    }
    let payload;
    try {
      payload = await response.json();
    } catch {
      throw new TypeError("Invalid Firebase token response");
    }
    if (!isPlainObject(payload) ||
      typeof payload.access_token !== "string" ||
      !/^[\x21-\x7e]{16,4096}$/.test(payload.access_token) ||
      payload.token_type !== "Bearer" ||
      !integerBetween(payload.expires_in, 60, 3600)) {
      throw new TypeError("Invalid Firebase token response");
    }
    cached = Object.freeze({
      expiresAt: now + payload.expires_in,
      value: payload.access_token,
    });
    return cached.value;
  };
}

export function createFcmHttpV1Sender({
  androidPackageName,
  fetchImplementation = globalThis.fetch,
  getAccessToken,
  projectId,
  timeoutMilliseconds = 10000,
}) {
  if (!projectIdPattern(projectId) ||
    !androidPackagePattern(androidPackageName) ||
    typeof fetchImplementation !== "function" ||
    typeof getAccessToken !== "function" ||
    !integerBetween(timeoutMilliseconds, 10000, 30000)) {
    throw new TypeError("Invalid FCM sender configuration");
  }
  const endpoint =
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  return async function sendFcm(context) {
    const message = fcmMessage(context, androidPackageName);
    let accessToken;
    try {
      accessToken = await getAccessToken();
    } catch {
      return Object.freeze({
        outcome: "retryable",
        resultCode: "FCM_UNAVAILABLE",
        retryAfterSeconds: retryDelay(
          context.attempt,
          context.deliveryId,
        ),
      });
    }
    if (typeof accessToken !== "string" ||
      !/^[\x21-\x7e]{16,4096}$/.test(accessToken)) {
      return Object.freeze({
        outcome: "retryable",
        resultCode: "FCM_UNAVAILABLE",
        retryAfterSeconds: retryDelay(
          context.attempt,
          context.deliveryId,
        ),
      });
    }

    try {
      await context.beginSubmission();
    } catch {
      return Object.freeze({
        outcome: "retryable",
        resultCode: "FCM_UNAVAILABLE",
        retryAfterSeconds: retryDelay(
          context.attempt,
          context.deliveryId,
        ),
      });
    }

    let response;
    try {
      response = await fetchImplementation(endpoint, {
        method: "POST",
        headers: {
          authorization: `Bearer ${accessToken}`,
          "content-type": "application/json; charset=utf-8",
        },
        body: JSON.stringify({message}),
        signal: AbortSignal.timeout(timeoutMilliseconds),
      });
    } catch {
      return Object.freeze({
        outcome: "ambiguous",
        resultCode: "FCM_SUBMISSION_AMBIGUOUS",
      });
    }

    if (response.ok) {
      let payload;
      try {
        payload = await response.json();
      } catch {
        return Object.freeze({
          outcome: "ambiguous",
          resultCode: "FCM_SUBMISSION_AMBIGUOUS",
        });
      }
      if (!isPlainObject(payload) ||
        typeof payload.name !== "string" ||
        !/^projects\/[A-Za-z0-9._~-]{1,128}\/messages\/[A-Za-z0-9%:._~-]{1,512}$/.test(
          payload.name,
        )) {
        return Object.freeze({
          outcome: "ambiguous",
          resultCode: "FCM_SUBMISSION_AMBIGUOUS",
        });
      }
      return Object.freeze({
        outcome: "accepted",
        receiptName: payload.name,
        resultCode: "FCM_ACCEPTED",
      });
    }

    const status = await providerStatus(response);
    if (status === "UNREGISTERED") {
      return Object.freeze({
        outcome: "invalid_token",
        resultCode: "FCM_UNREGISTERED",
      });
    }
    if (status === "INVALID_ARGUMENT") {
      return Object.freeze({
        outcome: "invalid_token",
        resultCode: "FCM_INVALID_ARGUMENT",
      });
    }
    if (status === "SENDER_ID_MISMATCH" || response.status === 403) {
      return Object.freeze({
        outcome: "permanent",
        resultCode: "FCM_SENDER_ID_MISMATCH",
      });
    }
    if (status === "THIRD_PARTY_AUTH_ERROR" || response.status === 401) {
      return Object.freeze({
        outcome: "permanent",
        resultCode: "FCM_THIRD_PARTY_AUTH_ERROR",
      });
    }
    const declaredRetryAfter = retryAfter(response);
    if (status === "QUOTA_EXCEEDED" || response.status === 429) {
      return Object.freeze({
        outcome: "retryable",
        resultCode: "FCM_QUOTA_EXCEEDED",
        retryAfterSeconds: declaredRetryAfter === null
          ? retryDelay(context.attempt, context.deliveryId, 60)
          : jitteredDelay(declaredRetryAfter, context.deliveryId),
      });
    }
    if (status === "UNAVAILABLE" || response.status === 503) {
      return Object.freeze({
        outcome: "retryable",
        resultCode: "FCM_UNAVAILABLE",
        retryAfterSeconds: declaredRetryAfter === null
          ? retryDelay(context.attempt, context.deliveryId)
          : jitteredDelay(declaredRetryAfter, context.deliveryId),
      });
    }
    if (status === "INTERNAL" || response.status >= 500) {
      return Object.freeze({
        outcome: "retryable",
        resultCode: "FCM_INTERNAL",
        retryAfterSeconds: declaredRetryAfter === null
          ? retryDelay(context.attempt, context.deliveryId)
          : jitteredDelay(declaredRetryAfter, context.deliveryId),
      });
    }
    return Object.freeze({
      outcome: "permanent",
      resultCode: "FCM_REQUEST_REJECTED",
    });
  };
}

function fcmMessage(context, androidPackageName) {
  const validSubject = (
    ["chore_assignment", "chore_due"].includes(context?.category) &&
      context?.subjectType === "chore_occurrence"
  ) || (
    context?.category === "calendar_event" &&
      context?.subjectType === "calendar_occurrence"
  );
  if (!isPlainObject(context) ||
    !integerBetween(context.attempt, 1, 5) ||
    typeof context.beginSubmission !== "function" ||
    !uuid(context.deliveryId) ||
    !uuid(context.sourceEventId) ||
    !uuid(context.householdId) ||
    context.inboxItemId !== null && !uuid(context.inboxItemId) ||
    !validSubject ||
    !uuid(context.subjectId) ||
    !integerBetween(context.ttlSeconds, 1, 3600) ||
    typeof context.token !== "string" ||
    !providerTokenPattern.test(context.token)) {
    throw new TypeError("Invalid FCM message context");
  }
  const data = {
    category: context.category,
    contractVersion: notificationPushEnvelopeContractVersion,
    deliveryId: context.deliveryId.toLowerCase(),
    householdId: context.householdId.toLowerCase(),
    sourceEventId: context.sourceEventId.toLowerCase(),
    subjectId: context.subjectId.toLowerCase(),
    subjectType: context.subjectType,
  };
  if (context.inboxItemId !== null) {
    data.inboxItemId = context.inboxItemId.toLowerCase();
  }
  return {
    android: {
      notification: {
        body_loc_key: "notification_push_body",
        channel_id: "kinflow_reminders",
        default_sound: true,
        tag: context.deliveryId.toLowerCase(),
        title_loc_key: "notification_push_title",
      },
      priority: "high",
      restricted_package_name: androidPackageName,
      ttl: `${context.ttlSeconds}s`,
    },
    data,
    token: context.token,
  };
}

async function providerStatus(response) {
  try {
    const payload = await response.json();
    const status = payload?.error?.status;
    return typeof status === "string" &&
        /^[A-Z][A-Z0-9_]{0,63}$/.test(status)
      ? status
      : "";
  } catch {
    return "";
  }
}

function retryAfter(response) {
  const raw = response.headers.get("retry-after")?.trim() ?? "";
  if (!/^[0-9]{1,4}$/.test(raw)) return null;
  const seconds = Number(raw);
  return integerBetween(seconds, 5, 3600) ? seconds : null;
}

function retryDelay(attempt, deliveryId, minimumSeconds = 30) {
  return jitteredDelay(
    Math.max(
      minimumSeconds,
      30 * (2 ** Math.max(0, attempt - 1)),
    ),
    deliveryId,
  );
}

function jitteredDelay(baseSeconds, deliveryId) {
  if (!integerBetween(baseSeconds, 5, 3600) || !uuid(deliveryId)) {
    throw new TypeError("Invalid FCM retry delay input");
  }
  const compactId = deliveryId.replaceAll("-", "");
  const jitter = Number.parseInt(compactId.slice(-8), 16) % 31;
  return Math.min(3600, baseSeconds + jitter);
}

function pemPrivateKeyBytes(value) {
  if (typeof value !== "string" ||
    !value.startsWith(`${pkcs8Begin}\n`) ||
    !value.endsWith(`\n${pkcs8End}\n`)) {
    throw new TypeError("Invalid Firebase private key");
  }
  const encoded = value
    .replace(pkcs8Begin, "")
    .replace(pkcs8End, "")
    .replace(/\s/g, "");
  return decodeCanonicalBase64(encoded, 256, 8192);
}

function decodeCanonicalBase64(value, minimumBytes, maximumBytes) {
  if (typeof value !== "string" ||
    !/^[A-Za-z0-9+/]+={0,2}$/.test(value) ||
    value.length > Math.ceil(maximumBytes / 3) * 4 + 4) {
    throw new TypeError("Invalid base64 material");
  }
  let bytes;
  try {
    bytes = Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
  } catch {
    throw new TypeError("Invalid base64 material");
  }
  if (bytes.byteLength < minimumBytes || bytes.byteLength > maximumBytes ||
    encodeBase64(bytes) !== value) {
    throw new TypeError("Invalid base64 material");
  }
  return bytes;
}

function encodeBase64(bytes) {
  let binary = "";
  for (const value of bytes) binary += String.fromCharCode(value);
  return btoa(binary);
}

function base64UrlEncode(bytes) {
  return encodeBase64(bytes)
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function projectIdPattern(value) {
  return typeof value === "string" &&
    /^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(value);
}

function androidPackagePattern(value) {
  return typeof value === "string" &&
    /^me\.newlines\.kinflow(?:\.dev)?$/.test(value);
}

function uuid(value) {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      value,
    );
}

function integerBetween(value, minimum, maximum) {
  return Number.isSafeInteger(value) && value >= minimum && value <= maximum;
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" &&
    !Array.isArray(value) &&
    (Object.getPrototypeOf(value) === Object.prototype ||
      Object.getPrototypeOf(value) === null);
}

function environment(name) {
  return Deno.env.get(name)?.trim() ?? "";
}

function requiredEnvironment(name) {
  const value = environment(name);
  if (value.length === 0) {
    throw new Error(`Missing required server environment: ${name}`);
  }
  return value;
}

function requiredSecretEnvironment(name) {
  const value = requiredEnvironment(name);
  if (value.length < 32) {
    throw new Error(`Invalid server environment: ${name}`);
  }
  return value;
}

function requiredAndroidPackageName(name) {
  const value = requiredEnvironment(name);
  if (!androidPackagePattern(value)) {
    throw new Error(`Invalid server environment: ${name}`);
  }
  return value;
}

function boundedIntegerEnvironment(name, fallback, minimum, maximum) {
  const raw = environment(name);
  if (raw.length === 0) return fallback;
  if (!/^[0-9]+$/.test(raw)) {
    throw new Error(`Invalid server environment: ${name}`);
  }
  const value = Number(raw);
  if (!integerBetween(value, minimum, maximum)) {
    throw new Error(`Invalid server environment: ${name}`);
  }
  return value;
}
