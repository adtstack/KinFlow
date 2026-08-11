# 원본 파일 문서화: `contracts/env.example`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/env.example`
- 원본 형식: `dotenv`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.

```dotenv
# PUBLIC CLIENT CONFIGURATION ONLY
# Actual secret values must never be committed.

APP_ENV=dev
APP_VERSION=0.0.0-dev
CONTRACT_VERSION=2026-07-21

SUPABASE_URL=https://example.supabase.co
SUPABASE_PUBLISHABLE_KEY=replace-with-environment-key

REVENUECAT_IOS_PUBLIC_SDK_KEY=
REVENUECAT_ANDROID_PUBLIC_SDK_KEY=

# Optional Android Firebase public identifiers. Configure all four or leave all
# four empty so the client fails closed to the durable inbox.
FIREBASE_ANDROID_API_KEY=
FIREBASE_ANDROID_APP_ID=
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_PROJECT_ID=

SENTRY_DSN=
PUBLIC_SITE_URL=https://example.invalid
AUTH_REDIRECT_HOST=auth.example.invalid
SUPPORT_URL=https://example.invalid/support
PRIVACY_REQUEST_URL=https://example.invalid/privacy-request
FEATURE_CONFIG_URL=

# SERVER/CI ONLY — NEVER EMBED IN FLUTTER OR WEB BUNDLE
SUPABASE_SERVICE_ROLE_KEY=
SUPABASE_DB_URL=
KINFLOW_REVENUECAT_WEBHOOK_AUTHORIZATION=
KINFLOW_REVENUECAT_WEBHOOK_SIGNING_SECRET=
KINFLOW_REVENUECAT_SECRET_API_KEY=
KINFLOW_REVENUECAT_ENTITLEMENT_ID=
KINFLOW_BILLING_RECONCILIATION_WORKER_SECRET=
KINFLOW_BILLING_RECONCILIATION_BATCH_LIMIT=50
KINFLOW_BILLING_RECONCILIATION_LEASE_SECONDS=120
KINFLOW_BILLING_RECONCILIATION_STALE_SECONDS=3600
FCM_SERVER_CREDENTIAL=
APPLE_APP_STORE_API_PRIVATE_KEY=
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=
INVITE_TOKEN_HMAC_KEY=
INTERNAL_JOB_AUTH_SECRET=
KINFLOW_ALLOWED_ORIGINS=https://app.example.invalid
KINFLOW_DATA_EXPORT_DOWNLOAD_URL=https://example.supabase.co/functions/v1/data-export-download
KINFLOW_DATA_EXPORT_WORKER_SECRET=
KINFLOW_HOUSEHOLD_EXPORT_DOWNLOAD_URL=https://example.supabase.co/functions/v1/household-export-download
KINFLOW_HOUSEHOLD_PRIVACY_WORKER_SECRET=
KINFLOW_NOTIFICATION_WORKER_SECRET=
KINFLOW_NOTIFICATION_WORKER_BATCH_SIZE=20
KINFLOW_NOTIFICATION_WORKER_LEASE_SECONDS=60
# Canonical standard base64 of exactly 32 random bytes. Rotate only with a new
# positive key version while retaining old decrypt keys until endpoint refresh.
KINFLOW_NOTIFICATION_TOKEN_ENCRYPTION_KEY=
KINFLOW_NOTIFICATION_TOKEN_KEY_VERSION=1
# Android FCM HTTP v1 worker. The decrypt keyring is a compact JSON object whose
# positive integer keys map to canonical base64 32-byte AES keys, for example
# {"1":"<canonical-base64>"}. Keep old versions until all endpoints refresh.
KINFLOW_FIREBASE_SERVICE_ACCOUNT_JSON=
KINFLOW_NOTIFICATION_TOKEN_DECRYPTION_KEYS=
KINFLOW_NOTIFICATION_PUSH_WORKER_SECRET=
KINFLOW_NOTIFICATION_PUSH_BATCH_SIZE=20
KINFLOW_NOTIFICATION_PUSH_LEASE_SECONDS=60
KINFLOW_ANDROID_PACKAGE_NAME=me.newlines.kinflow
# Generic notification email fallback. These values are server-only; the
# confirmed recipient address is resolved ephemerally from Auth at claim time.
NOTIFICATION_EMAIL_WORKER_SECRET=
KINFLOW_NOTIFICATION_EMAIL_BATCH_SIZE=20
KINFLOW_NOTIFICATION_EMAIL_LEASE_SECONDS=60
SENDGRID_API_KEY=
KINFLOW_NOTIFICATION_EMAIL_FROM=
SENTRY_AUTH_TOKEN=
```
