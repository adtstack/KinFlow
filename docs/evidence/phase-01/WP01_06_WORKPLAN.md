# Phase 01 WP01-06 Work Plan

- 작성일: 2026-07-25
- 기준 commit: `c9d92f8`
- Work Package: WP01-06 Observability/config
- 상태: COMPLETE (automated); Android device와 remote Sentry smoke는 evidence에 NOT RUN으로 분리

## Requirements

| ID | 구현 범위 |
|---|---|
| WP01-06 | structured logger/redaction, Sentry dev/prod, public configuration loader/validator, no-secret scan |
| D-033 / NFR-SEC-02 | 공개 client config만 bundle에 허용하고 server/CI secret을 거부 |
| D-034 | Sentry Flutter를 오류 추적 경계로 사용하되 PII allowlist와 before-send redaction 강제 |
| NFR-PRIV-01 | 위치·연락처·광고 ID를 수집하지 않고 log/telemetry payload를 allowlist |
| NFR-OBS-01 | PII 없는 structured log와 release/environment/contract correlation 기반 |
| FR-SET-007 | 향후 진단 정보의 app/build/environment/incident 값만 제공할 수 있는 안전한 record contract |
| T-STATIC-04 | repository/config no-secret scan에서 high-confidence finding 0 |
| T-PRIV-03 | 금지 field와 email/token/JWT/credential 유사 값이 log/Sentry payload에 남지 않음 |
| RISK-014 / GAP-017 | PII logging과 client bundle secret 위험을 allowlist/redaction/scan으로 완화 |

## Public Configuration Contract

- source는 compile-time `String.fromEnvironment`이며 native flavor와 별도로 `APP_ENV`/`APP_ID` 일치를 검증한다.
- 허용 key는 `APP_ENV`, `APP_ID`, `APP_VERSION`, `CONTRACT_VERSION`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `GOOGLE_WEB_CLIENT_ID`, `REVENUECAT_ANDROID_PUBLIC_SDK_KEY`, `SENTRY_DSN`, `PUBLIC_SITE_URL`, `AUTH_REDIRECT_HOST`, `SUPPORT_URL`, `PRIVACY_REQUEST_URL`, `FEATURE_CONFIG_URL`로 고정한다.
- `SUPABASE_SERVICE_ROLE_KEY`, DB password/URL, OAuth client secret, webhook/provider server secret, signing credential, Sentry auth token은 server-only이며 public config validator가 거부한다.
- production origin은 HTTPS만 허용한다. dev의 Supabase URL만 emulator/localhost HTTP를 허용한다.
- Sentry DSN과 아직 도입하지 않은 provider 공개 key는 optional이다. 값이 없으면 capability를 명시적으로 disabled로 유지하고 fake 값이나 외부 요청을 만들지 않는다.
- placeholder publishable key는 example 파일 정적 검증에서는 허용하지만 runtime configuration에서는 fail-closed 한다. 잘못된 runtime config는 raw value 없이 stable issue code만 반환한다.
- release correlation은 `APP_ID@APP_VERSION`, contract correlation은 `CONTRACT_VERSION`을 사용한다.

## Structured Logging / Privacy Contract

- record는 UTC timestamp, level, `domain_object.action.outcome` event, environment, release, contract version, platform과 allowlisted attributes만 가진다.
- 허용 attribute는 `feature`, `screen`, `operation`, `result`, `error_code`, `request_id`, `duration_ms`, `retry_count`, `provider`, `provider_status`, `capability`, `reason`이다.
- attribute value는 bounded scalar(String/num/bool)만 허용한다. unknown key와 nested/free-form payload는 기록하지 않는다.
- email, bearer/JWT, credential/query fragment 등 민감 패턴은 `[REDACTED]`로 치환하며 금지 key는 allowlist보다 먼저 제거한다.
- logger sink failure는 사용자 작업이나 app startup을 실패시키지 않는다.
- dev만 JSON console sink를 사용하고 prod는 verbose console output을 만들지 않는다.
- startup success/failure는 stable event/error code로 기록하며 raw exception/message/stack은 structured log에 전달하지 않는다.

## Sentry Contract

- `sentry_flutter` stable SDK는 infrastructure adapter 뒤에서만 사용하고 app/domain에 SDK type을 노출하지 않는다.
- dev/prod 모두 동일한 bootstrap path를 사용하되 config의 DSN, environment, `APP_ID@APP_VERSION`, contract tag로 분리한다.
- DSN이 비어 있으면 SDK/network를 시작하지 않고 app은 정상 실행한다. 실제 dev/prod Sentry project/DSN 설정은 manual setup으로 남긴다.
- `sendDefaultPii=false`, screenshot/view-hierarchy/failed-request capture와 tracing/replay는 foundation에서 비활성화한다.
- before-send/breadcrumb filter는 user, request, free-form extra/context와 raw exception/message를 제거하거나 stable redacted 값으로 바꾼다.
- 자동화는 options/privacy filter와 fake runner를 검증한다. 실제 Sentry 수신/redaction smoke는 DSN과 승인된 dev project가 없으므로 NOT RUN으로 기록한다.

## Data / API / Dependency Impact

- DB migration, seed, RLS, Edge/API contract 변경 없음.
- `sentry_flutter` runtime dependency 1개를 추가하고 `pubspec.lock`으로 exact resolution을 고정한다.
- Android native crash SDK가 포함되어 APK 크기가 변할 수 있다. 기존 `INTERNET` 외 dangerous runtime permission 추가 여부를 merged APK에서 검사한다.
- DSN이 설정된 환경에서 privacy-filtered crash/error metadata가 Sentry로 전송될 수 있다. 사용자/가구/content identity는 이번 WP에서 설정하지 않는다.

## Planned Tests

1. dev/prod `APP_ENV`/`APP_ID` binding, version/contract/URL/DSN validation
2. production HTTP 거부, dev loopback HTTP 허용, placeholder runtime fail-closed
3. public config examples exact key allowlist와 server-only key 0
4. structured record correlation과 deterministic JSON shape
5. unknown/nested/forbidden key drop, email/bearer/JWT/query redaction, bounded value
6. sink failure isolation과 prod console sink 제외
7. startup log가 stable code만 기록하고 raw exception을 전달하지 않음
8. Sentry options의 environment/release/privacy-disabled flags와 before-send/breadcrumb scrubber
9. repository high-confidence secret scan 0과 scanner positive fixtures
10. architecture boundary에서 Sentry SDK import가 observability infrastructure만 존재
11. format/analyzer warning 0, full Flutter test/coverage, l10n/build_runner drift 0
12. dev/prod APK build, metadata/permission/size audit와 staged-index clean reproduction

## Manual Validation

- 연결 Android가 있으면 dev/prod boot와 invalid-config recovery를 확인한다.
- 승인된 dev Sentry DSN이 있으면 synthetic stable-code event를 전송해 environment/release tag와 PII redaction을 Sentry UI에서 확인한다.
- device 또는 DSN이 없으면 해당 수동 항목은 NOT RUN이며 automated options/filter와 APK audit만 PASS로 기록한다.

## Non-scope

- production Sentry organization/project 생성, DSN 저장, alert/dashboard/on-call 구성
- analytics/experimentation SDK와 behavioral event 전송
- user/household pseudonymous identifier 생성 또는 hashing 정책
- performance tracing, profiling, session replay, screenshot/attachment 수집
- remote config fetch/cache/kill-switch 구현
- CI workflow wiring(WP01-07)

## Rollback

- observability/config infrastructure, bootstrap/provider wiring, config keys, tools/tests/docs와 `sentry_flutter` dependency/lock 변경을 함께 되돌리면 `c9d92f8`의 WP01-05 상태로 복귀한다.
- remote Sentry project, DB/API/data 변경이 없으므로 remote/data rollback은 없다. DSN을 빈 값으로 배포하면 SDK/network initialization이 즉시 비활성화된다.
