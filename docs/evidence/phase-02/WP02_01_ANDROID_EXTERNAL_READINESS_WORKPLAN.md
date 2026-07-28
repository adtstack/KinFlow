# Phase 02 WP02-01 Android External Readiness Work Plan

- 작성일: 2026-07-29
- 기준 commit: `8882cd0`
- Work Package: WP02-01 Auth lifecycle — owned App Link build input and Android integration readiness
- 상태: LOCAL PASS / REMOTE CI PENDING

## Requirements

| ID | 이번 vertical slice |
|---|---|
| WP02-01 / FR-AUTH-004 | runtime `AUTH_REDIRECT_HOST`와 Android manifest App Link host를 하나의 public config에서 파생해 login 전후 invite continuation의 host 불일치를 막는다. |
| WP02-04 / D-055 | placeholder host를 유지하는 reproducible CI와 owned host를 주입하는 실제 dev build를 모두 exact APK audit로 검증한다. |
| Phase 02 manual gate | Android 16 Google Play AVD에서 dev APK 설치, cold start, package/signing/App Link OS 상태를 확인한다. Google/Supabase provider와 성인 2인 E2E는 외부 입력 전까지 별도 pending으로 유지한다. |
| Security | OAuth secret, service-role key, signing private key와 token을 build argument, log, report와 Git에 넣지 않는다. App Link DNS host와 OAuth client ID는 public input으로만 취급한다. |

## Scope

1. Android manifest host를 Gradle project property `kinflowAuthRedirectHost`로 주입하고 DNS host 형식을 fail-closed 검증한다.
2. Android build gate가 선택한 public config의 `APP_ENV`, `APP_ID`, `AUTH_REDIRECT_HOST`를 검증한 뒤 같은 host를 Dart define과 Gradle manifest에 사용한다.
3. APK audit와 report에서 hard-coded placeholder 대신 선택된 exact host를 확인한다.
4. public config parser에 unit tests를 추가해 scheme, path, port, wildcard, whitespace, environment/package drift를 거부한다.
5. 실제 Google Play AVD에서 현재 dev APK의 설치/cold-start와 placeholder domain verification failure를 기록한다.
6. runbook에 owned host를 주입하는 pinned Flutter 명령과 현재 debug signing fingerprint를 기록하는 절차를 보강한다.

## Explicit Non-scope Until External Inputs Exist

- Google Cloud/Supabase project 생성 또는 provider 설정 변경
- 실제 client secret, service-role key, signing private key와 token의 저장·출력
- owned HTTPS domain 또는 `assetlinks.json` 배포
- Google 성인 계정 2개 로그인과 Android 기기 2대 E2E 완료 주장
- production release/Play App Signing certificate 생성 또는 등록

## Data / API Impact

- DB migration, RLS, RPC, Edge/API contract 변경 없음.
- 앱 runtime dependency와 public config key 변경 없음.
- Gradle public build property, build audit helper/test와 문서만 변경한다.

## Automated / Device Validation

- `npm run ci:test`
- Flutter fatal analyze와 관련 regression tests
- default example host dev/prod APK build/audit
- non-placeholder synthetic owned-style host APK build/audit
- invalid Gradle host build failure
- Android 16 Google Play AVD install, cold-start, foreground activity와 App Link OS state
- repository secret/config scan

## Stop / Rollback

- Dart runtime host와 merged manifest host가 다르면 build를 실패시킨다.
- scheme/path/port/wildcard/whitespace가 포함된 host는 Gradle 실행 전에 거부한다.
- credential 또는 token이 command output/report/evidence에 나타나면 즉시 중단하고 폐기한다.
- 이 slice의 commit을 revert하면 manifest와 CI는 기존 `auth.example.invalid` 고정 상태로 돌아간다. DB rollback은 없다.

## Completion Boundary

- 이 slice는 owned host를 안전하게 주입할 수 있는 build/device readiness만 완료한다.
- 실제 dev provider, verified owned domain, Google 성인 2계정·2기기 E2E 전에는 WP02-01과 Phase 02 Exit Gate를 완료로 선언하지 않는다.
