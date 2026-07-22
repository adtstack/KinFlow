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

SENTRY_DSN=
PUBLIC_SITE_URL=https://example.invalid
AUTH_REDIRECT_HOST=auth.example.invalid
SUPPORT_URL=https://example.invalid/support
PRIVACY_REQUEST_URL=https://example.invalid/privacy-request
FEATURE_CONFIG_URL=

# SERVER/CI ONLY — NEVER EMBED IN FLUTTER OR WEB BUNDLE
SUPABASE_SERVICE_ROLE_KEY=
SUPABASE_DB_URL=
REVENUECAT_WEBHOOK_SECRET=
REVENUECAT_SECRET_API_KEY=
FCM_SERVER_CREDENTIAL=
APPLE_APP_STORE_API_PRIVATE_KEY=
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=
INVITE_TOKEN_HMAC_KEY=
DATA_EXPORT_SIGNING_KEY=
INTERNAL_JOB_AUTH_SECRET=
SENTRY_AUTH_TOKEN=
```
