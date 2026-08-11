import {
  createNotificationEmailHandler,
} from "./notification_email_contract.mjs";
import {
  createNotificationWorkerRpcInvoker,
} from "./notification_worker_contract.mjs";
import {sha256Base64} from "./notification_endpoint_runtime.mjs";
import {matchesWorkerSecret} from "./notification_worker_runtime.mjs";

export const sendGridMailSendEndpoint =
  "https://api.sendgrid.com/v3/mail/send";

const messages = Object.freeze({
  en: Object.freeze({
    subject: "KinFlow reminder",
    text: "You have a family reminder waiting in KinFlow. Open KinFlow to view the details.",
  }),
  ko: Object.freeze({
    subject: "KinFlow 알림",
    text: "KinFlow에 가족 알림이 도착했습니다. 자세한 내용은 KinFlow를 열어 확인하세요.",
  }),
});

export function serveNotificationEmailWorker() {
  const workerSecret = requiredSecretEnvironment(
    "NOTIFICATION_EMAIL_WORKER_SECRET",
  );
  const handler = createNotificationEmailHandler({
    authorizeRequest: (authorization) => matchesWorkerSecret(
      authorization,
      workerSecret,
    ),
    batchSize: boundedIntegerEnvironment(
      "KINFLOW_NOTIFICATION_EMAIL_BATCH_SIZE",
      20,
      1,
      100,
    ),
    invokeRpc: createNotificationWorkerRpcInvoker({
      serviceRoleKey: requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY"),
      supabaseUrl: requiredEnvironment("SUPABASE_URL"),
    }),
    leaseSeconds: boundedIntegerEnvironment(
      "KINFLOW_NOTIFICATION_EMAIL_LEASE_SECONDS",
      60,
      5,
      300,
    ),
    sendEmail: createSendGridEmailSender({
      apiKey: requiredSecretEnvironment("SENDGRID_API_KEY"),
      fromEmail: requiredEmailEnvironment("KINFLOW_NOTIFICATION_EMAIL_FROM"),
    }),
    sha256Base64,
  });
  Deno.serve(handler);
}

export function createSendGridEmailSender({
  apiKey,
  fetchImplementation = globalThis.fetch,
  fromEmail,
  timeoutMilliseconds = 10000,
}) {
  if (typeof apiKey !== "string" || apiKey.length < 32 || apiKey.length > 512 ||
    !/^[\x21-\x7e]+$/.test(apiKey) ||
    typeof fetchImplementation !== "function" ||
    !emailAddress(fromEmail) ||
    !integerBetween(timeoutMilliseconds, 1000, 30000)) {
    throw new TypeError("Invalid SendGrid sender configuration");
  }

  return async function sendEmail(context) {
    if (!hasExactKeys(
      context,
      ["attempt", "beginSubmission", "locale", "recipientEmail"],
    ) || !integerBetween(context.attempt, 1, 5) ||
      typeof context.beginSubmission !== "function" ||
      !["en", "ko"].includes(context.locale) ||
      !emailAddress(context.recipientEmail)) {
      throw new TypeError("Invalid SendGrid message context");
    }
    const message = messages[context.locale];
    const payload = {
      content: [{type: "text/plain", value: message.text}],
      from: {email: fromEmail, name: "KinFlow"},
      personalizations: [{to: [{email: context.recipientEmail}]}],
      subject: message.subject,
    };

    await context.beginSubmission();

    let response;
    try {
      response = await fetchImplementation(sendGridMailSendEndpoint, {
        method: "POST",
        headers: {
          authorization: `Bearer ${apiKey}`,
          "content-type": "application/json; charset=utf-8",
        },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(timeoutMilliseconds),
      });
    } catch {
      return Object.freeze({
        outcome: "ambiguous",
        resultCode: "EMAIL_SUBMISSION_AMBIGUOUS",
      });
    }

    if (response.status === 202) {
      const messageId = response.headers.get("x-message-id");
      if (messageId !== null && !providerMessageId(messageId)) {
        return Object.freeze({
          outcome: "ambiguous",
          resultCode: "EMAIL_SUBMISSION_AMBIGUOUS",
        });
      }
      return Object.freeze({
        outcome: "accepted",
        providerMessageId: messageId,
        resultCode: "EMAIL_ACCEPTED",
      });
    }
    if (response.status === 429) {
      return retryable("EMAIL_RATE_LIMITED", context.attempt);
    }
    if (response.status === 500) {
      return retryable("EMAIL_PROVIDER_INTERNAL", context.attempt);
    }
    if ([502, 503, 504].includes(response.status)) {
      return retryable("EMAIL_PROVIDER_UNAVAILABLE", context.attempt);
    }
    if ([401, 403].includes(response.status)) {
      return Object.freeze({
        outcome: "permanent",
        resultCode: "EMAIL_AUTH_REJECTED",
      });
    }
    if ([400, 413].includes(response.status)) {
      return Object.freeze({
        outcome: "permanent",
        resultCode: "EMAIL_PAYLOAD_REJECTED",
      });
    }
    return Object.freeze({
      outcome: "permanent",
      resultCode: "EMAIL_REQUEST_REJECTED",
    });
  };
}

export function notificationEmailMessage(locale) {
  if (!["en", "ko"].includes(locale)) {
    throw new TypeError("Invalid notification email locale");
  }
  return messages[locale];
}

function retryable(resultCode, attempt) {
  return Object.freeze({
    outcome: "retryable",
    resultCode,
    retryAfterSeconds: [60, 300, 1800, 7200][Math.min(attempt - 1, 3)],
  });
}

function providerMessageId(value) {
  return typeof value === "string" && /^[\x21-\x7e]{1,256}$/.test(value);
}

function emailAddress(value) {
  if (typeof value !== "string" || value.length < 3 || value.length > 320 ||
    /[\x00-\x20\x7f]/.test(value)) {
    return false;
  }
  const at = value.indexOf("@");
  if (at < 1 || at !== value.lastIndexOf("@") || at > 64) return false;
  const local = value.slice(0, at);
  const domain = value.slice(at + 1);
  if (!/^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+$/.test(local) ||
    local.startsWith(".") || local.endsWith(".") || local.includes("..") ||
    domain.length < 1 || domain.length > 255) {
    return false;
  }
  return domain.split(".").every((label) =>
    /^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$/.test(label)
  );
}

function hasExactKeys(value, keys) {
  return isPlainObject(value) &&
    JSON.stringify(Object.keys(value).sort()) === JSON.stringify([...keys].sort());
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" &&
    !Array.isArray(value) &&
    (Object.getPrototypeOf(value) === Object.prototype ||
      Object.getPrototypeOf(value) === null);
}

function integerBetween(value, minimum, maximum) {
  return Number.isSafeInteger(value) && value >= minimum && value <= maximum;
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
  if (value.length < 32 || value.length > 512 || !/^[\x21-\x7e]+$/.test(value)) {
    throw new Error(`Invalid server environment: ${name}`);
  }
  return value;
}

function requiredEmailEnvironment(name) {
  const value = requiredEnvironment(name);
  if (!emailAddress(value)) {
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
