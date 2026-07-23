# 원본 파일 문서화: `contracts/toolchain.json`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/toolchain.json`
- 원본 형식: `json`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "name": "KinFlow Flutter implementation baseline",
  "version": "1.0",
  "acceptedAt": "2026-07-23",
  "flutter": {
    "channel": "stable",
    "version": "3.44.7",
    "dart": "3.12.2 bundled with Flutter SDK 3.44.7",
    "pinPolicy": "exact toolchain; pubspec.lock committed and frozen in CI"
  },
  "platforms": {
    "storeMvp": {
      "android": {
        "minApi": 24,
        "targetApi": 36,
        "applicationId": "me.newlines.kinflow",
        "formFactors": [
          "phone",
          "tablet"
        ]
      }
    },
    "deferred": [
      "iOS",
      "iPadOS",
      "Web Companion",
      "Windows native",
      "macOS native",
      "Linux native"
    ]
  },
  "environments": {
    "dev": {
      "applicationId": "me.newlines.kinflow.dev"
    },
    "prod": {
      "applicationId": "me.newlines.kinflow"
    }
  },
  "client": {
    "state": [
      "flutter_riverpod",
      "riverpod_annotation"
    ],
    "routing": "go_router",
    "models": [
      "freezed",
      "json_serializable"
    ],
    "backend": "supabase_flutter",
    "billing": "purchases_flutter",
    "push": [
      "firebase_core",
      "firebase_messaging",
      "flutter_local_notifications"
    ],
    "secureStorage": "flutter_secure_storage",
    "observability": "sentry_flutter",
    "localization": "Flutter gen_l10n + ARB"
  },
  "backend": {
    "database": "Supabase PostgreSQL",
    "authorization": "PostgreSQL RLS plus transactional RPC/Edge authorization",
    "auth": "Supabase Auth",
    "edgeFunctions": "TypeScript/Deno",
    "migrations": "Supabase CLI migrations only"
  },
  "auth": {
    "initialProvider": "Google",
    "accountAudience": "adults only"
  },
  "testing": {
    "unitWidget": [
      "flutter_test",
      "mocktail"
    ],
    "integration": "integration_test",
    "mobileE2e": "Maestro",
    "webE2e": "Playwright",
    "database": [
      "pgTAP",
      "RLS authorization matrix"
    ]
  },
  "delivery": {
    "ci": "GitHub Actions",
    "storeAutomation": "Fastlane with human production approval",
    "androidArtifact": "AAB",
    "web": "immutable atomic deployment",
    "runtimeCodePush": "not in MVP baseline"
  },
  "policies": {
    "domainMustNotImportFlutterOrSdk": true,
    "generatedCodeCommitted": true,
    "codegenDiffMustBeClean": true,
    "serverAuthoritativeAuthorization": true,
    "serverAuthoritativeEntitlement": true,
    "serverAuthoritativeOccurrenceMaterialization": true,
    "noSecretInDartDefine": true,
    "desktopRequiresDemandGate": true
  }
}
```
