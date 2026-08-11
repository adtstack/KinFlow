# Phase 01 WP01-10 Privacy-safe Analytics Governance Evidence

## Result

- 상태: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-09)**
- 사용자 기능: Settings에서 optional usage analytics 기본 OFF 상태와 수집 경계·Managed Child 정책·현재 SDK 목적을 확인하고 versioned device preference를 변경한다.
- runtime 기능: authenticated active-household entry를 exact typed event로 최대 한 번 dispatch하되 child mode, preference와 sink availability를 순서대로 검사한다.
- 범위: Android local composition만 변경한다. 외부 behavioral analytics SDK/sink, DB/API/server consent record, 새 permission과 raw attribute map은 추가하지 않는다.

## Implemented contract

- event는 exact six-value enum이고 sink envelope는 `event_name`, `event_version`, `platform`, `app_release`, `environment`의 exact five fields다.
- account/user/household/member/child ID, pseudonym, email/name/content, token/receipt/URL/raw error, locale/timezone/request ID, location/contact/ad ID/device fingerprint와 arbitrary attribute를 받는 API가 없다.
- dispatch 순서는 `Managed Child block → granted preference → available sink → best-effort emit`이다. child mode는 preference storage read보다 먼저 닫힌다.
- preference는 `analytics-usage-v1|granted` 또는 `analytics-usage-v1|withdrawn` 중 하나만 전용 backup-disabled secure namespace에 저장한다. missing/stale/malformed는 withdrawn이고 read/write 예외는 stable failure로 축약한다.
- device/environment-local preference는 identifier와 timestamp를 저장하지 않아 logout 뒤에도 유지한다. provider, 목적, field 또는 policy version이 바뀌면 token version을 바꿔 기존 granted를 무효화해야 한다.
- current production composition은 `UnavailableAnalyticsSink`다. 따라서 preference가 granted여도 외부 behavioral event를 보내지 않으며 Settings에 이 상태를 표시한다.
- Sentry는 기존 PII-filtered operational error reporting에만 사용하고 optional usage analytics sink와 분리한다.
- authenticated active-household entry는 process lifetime에서 연속 ready/refresh 중 한 번만 `application.session.started`를 시도하며 auth/household scope 값을 envelope에 전달하지 않는다.

## Changed surfaces

- 계약·계획: `docs/contracts/analytics-governance.yaml.md`, `docs/evidence/phase-01/WP01_10_WORKPLAN.md`
- domain/application: `apps/kinflow_app/lib/features/analytics/domain/`, `apps/kinflow_app/lib/features/analytics/application/`
- data/storage: `apps/kinflow_app/lib/features/analytics/data/repositories/secure_analytics_preference_repository.dart`, 기존 `SecureStringStore` adapter와 전용 namespace composition
- composition/lifecycle: `apps/kinflow_app/lib/app/providers/analytics_dependencies.dart`, `bootstrap.dart`, `app.dart`, `analytics_lifecycle_host.dart`
- UI/router/localization: `/settings/analytics-privacy`, Settings tile, EN/KO/EN-XA ARB와 generated localization files
- tests: typed gate/envelope, secure preference, controller, lifecycle, SDK inventory와 widget/accessibility suites
- traceability: Phase 01, analytics product doc, contract index, changelog, requirements/test/platform matrices
- 변경 없음: PostgreSQL/migration/RLS/RPC/Edge/API/remote DTO, external analytics provider/config key, runtime dependency, Android permission

## Automated evidence

### Focused and impact Flutter tests

- analytics domain/dispatcher/storage/controller/lifecycle/SDK inventory/widget와 architecture focused set: **35 passed**
- app shell/bootstrap/auth router/Settings/platform capability/diagnostics/legal/a11y/localization impact set: **110 passed**
- 주요 증명:
  - exact six event names와 exact five-field immutable content-free envelope
  - Managed Child가 preference load 0회·sink emit 0회로 가장 먼저 차단됨
  - missing/stale/malformed/withdrawn/read failure에서 emit 0회
  - unavailable sink와 throwing sink가 각각 stable result로 닫히고 예외를 전파하지 않음
  - granted adult fake sink success와 authenticated-entry exact-once/reset behavior
  - exact secure key/value round-trip, concurrent initialization single-flight와 failed-write preservation
  - Settings load/save/retry/single-flight, unavailable sink 공개와 raw storage detail 비노출
  - exact 18 direct dependency inventory, forbidden analytics/advertising/tracking package 0, Sentry sink 분리
  - KO 및 EN-XA compact 320×568 200% scroll과 48dp preference action

### Full local regression and repository gates

- Flutter full suite: **1,104 passed + 1 explicit live opt-in skipped, 0 failed**
- Flutter analyzer `--fatal-infos --fatal-warnings`: **0 issues**
- Dart format gate: **635 files checked, 0 changed**
- generated code drift: **8 files checked, 0 outputs, passed**
- root `npm run ci:test`: **141 passed, 0 failed, 0 skipped**
- public configuration allowlist: **passed**
- high-confidence secret scan: **passed**
- dependency/license audit: **167 Pub, 15 npm runtime, 365 npm build-only packages passed**
- offline OSV vulnerability scan with current local database: **passed**
- embedded analytics contract: **6 events, 5 envelope fields, 18 direct dependencies, 0 behavioral SDKs, passed**
- matrix CSV structure: **requirements 116×18, platform 20×12, tests 81×11, passed**
- new localization source: **27 keys in EN/KO/EN-XA**, pseudo expansion minimum 130%, valid JSON
- scoped changed-surface references: **24/24 present**, trailing whitespace **0**, evidence placeholders **0**, Flutter crash logs **0**
- repository `git diff --check`: **passed**

첫 impact run은 `analyticsPrivacyAllowlistBody`와 세 SDK/privacy EN-XA 문장이 영어 대비 30% 확장 기준에 부족함을 드러냈다. 새 키 전체 비율을 계산해 네 문장을 보강하고 localization/widget 11개, impact 110개와 full suite를 다시 실행해 통과했다. 최초 dependency audit은 sandbox DNS 제한으로 OSV database를 받기 전에 중단됐고, 같은 audit를 승인된 network 환경에서 재실행해 license와 offline scan을 모두 통과했다. 두 건 모두 제품 runtime 실패가 아니다.

## Security and privacy evidence

- external sink API는 arbitrary string/map을 받지 않고 compile-time event enum과 public build metadata만 받는다.
- secure preference는 고정 key와 policy/status token 하나뿐이며 account·household·device identifier나 timestamp가 없다. Android backup migration은 꺼져 있고 auth/cache/token namespace와 분리된다.
- malformed 또는 과거 policy token은 자동 granted로 복구하지 않고 withdrawn으로 닫힌다. storage/sink 예외 문자열은 state/UI/log에 전달되지 않는다.
- current dependency inventory는 `pubspec.yaml` direct dependency 전체와 exact match하며 Firebase Analytics, 광고, attribution, tracking package는 없다.
- Sentry, Firebase Messaging, RevenueCat, Google Sign-In과 Supabase의 목적을 UI와 계약에 분리하고 Sentry를 behavioral sink로 조합하지 않는다.
- analytics 실패는 auth, navigation, bootstrap과 application mutation을 실패시키지 않는다. 새 logger attribute, public config, network call 또는 remote retention surface가 없다.

## Manual and deferred evidence

- approved analytics provider 선정·계약, 실제 event 수신/dashboard, retention/region/access/deletion과 outage behavior
- 최종 법적 근거·동의 문구·policy version·server `consent_records` write/read와 Store disclosure
- 실제 Managed Child runtime과 보호자 정책, real account/multi-device/physical-device
- Android Keystore persistence/uninstall/backup forensic, TalkBack, signed artifact와 provider console SDK inventory
- iOS/Web analytics preference·sink composition

사용자 지시에 따라 위 live/provider 검증은 마지막 통합 Gate까지 미룬다. 따라서 `FR-PLAT-003`과 `CAP-014`는 local governance 기능이 생겼지만 approved remote sink와 법률/실환경 증거가 없는 `PARTIAL`이다.

## Rollback

- analytics route/tile/lifecycle host, providers/domain/application/data files와 bootstrap overrides를 제거하면 기존 no-behavioral-analytics 앱으로 돌아간다.
- Android 전용 `kinflow_analytics_<environment>_v1` secure namespace의 exact preference key를 제거하면 local choice도 초기 OFF로 돌아간다.
- DB/API/provider가 바뀌지 않았으므로 migration, backfill, remote event deletion, account 또는 provider cleanup은 없다.

## Next Entry Condition

- 기능 우선 다음 local slice는 deep-link/share capability(`CAP-002`/`CAP-016`) 또는 아직 `NOT_STARTED`인 server-authoritative entitlement read(`CAP-007`) 중 요구사항 우선순위가 높은 하나를 계약화할 수 있다.
- approved analytics sink, 법률 consent와 실계정·실기기 검증은 사용자 지시에 따라 마지막 통합 Gate에 유지한다.
