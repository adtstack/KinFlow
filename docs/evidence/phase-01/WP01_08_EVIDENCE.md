# Phase 01 WP01-08 Android Platform Capability Registry Evidence

## Result

- 상태: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-09)**
- 사용자 기능: Settings → 기기 기능 상태에서 Android 알림 전달, Google Play 결제, 암호화 로컬 저장소, 외부 링크·다운로드, background delivery의 선택 연동·현재 상태·안전한 대안을 확인한다.
- 범위: 기존 provider composition의 local snapshot과 in-process notification permission 상태만 사용한다. 이 화면에서 network, Store SDK, permission request, persistence, DB/API mutation은 발생하지 않는다.

## Implemented contract

- domain registry는 `notification_delivery`, `store_billing`, `secure_local_storage`, `external_links`, `background_delivery` exact 5개를 중복 없는 고정 순서로만 materialize한다.
- production `AuthDependencies`는 실제 push coordinator availability, billing port availability, Android encrypted read cache, Android URI launcher composition 결과를 registry에 한 번 주입한다. configuration failure composition은 모두 unavailable인 fail-closed registry를 주입한다.
- presentation provider는 기존 `NotificationPushState`를 `unavailable | notDetermined | denied | authorized | temporaryFailure`로 축약한다. raw failure, provider exception, credential/configuration 값은 registry에 전달하지 않는다.
- 상태는 `available | actionRequired | limited | fallbackOnly | temporaryIssue`이고 provider·reason·fallback·action은 enum-only다. WP08 remote mutation policy와 provider/server health를 추론하지 않는다.
- `/settings/device-capabilities`는 인증된 Settings 하위 route이며 active household 없이도 local snapshot을 읽을 수 있다. 문제가 있는 항목은 기존 notification center, subscription settings 또는 privacy-safe diagnostics route만 연다.
- EN/KO/EN-XA 화면은 상태를 색상뿐 아니라 text/icon으로 표시하고, compact 320×568 200%에서 전체 목록과 마지막 48dp action까지 scroll 가능하다.

## Changed surfaces

- 계약·계획: `docs/contracts/platform-capability-registry.yaml.md`, `docs/evidence/phase-01/WP01_08_WORKPLAN.md`
- domain/provider/UI: `apps/kinflow_app/lib/features/platform_capabilities/`
- composition: `apps/kinflow_app/lib/app/providers/auth_dependencies.dart`, `apps/kinflow_app/lib/app/bootstrap.dart`
- route/settings: `apps/kinflow_app/lib/app/router/app_router.dart`, `apps/kinflow_app/lib/features/settings/presentation/screens/settings_screen.dart`
- localization: `app_en.arb`, `app_ko.arb`, `app_en_XA.arb`와 generated localization files
- tests: `platform_capability_registry_test.dart`, `platform_capabilities_widget_test.dart`, `auth_dependencies_test.dart`
- traceability: Phase 01 follow-on, contract index, changelog, requirements traceability와 platform capability matrix
- 변경 없음: migration, PostgreSQL, RLS, RPC, Edge Function, remote DTO, provider lifecycle, stored data

## Automated evidence

### Focused and impact Flutter tests

- exact registry/provider/fallback domain tests: **5 passed**
- capability screen route/i18n/fallback/EN-XA 200% widget tests: **5 passed**
- composition, route guard, existing diagnostics, localization, architecture impact set: **52 passed**
- 주요 증명:
  - exact 5개 ID/order와 immutable snapshot
  - 모든 notification signal의 deterministic state/reason/action
  - unavailable composition에서 provider 문자열·오류 없이 named fallback 유지
  - production composition에서 encrypted cache와 external URI 지원 결과 반영
  - denied notification copy와 durable inbox route
  - KO fallback copy, EN-XA compact 200%, 48dp action, Settings tile navigation
  - domain에 Flutter/Riverpod/Supabase/provider SDK import 없음

### Full local regression

- Flutter full suite: **1,063 passed + 1 explicit live opt-in skipped**, failures 0
- Flutter analyzer `--fatal-infos --fatal-warnings`: **0 issues**
- Dart format gate: **612 files, 0 changed**
- root Node contract suite: **141 passed**, failures/skips 0
- localization contract: **4 passed** inside full Flutter suite; EN/KO/EN-XA exact key coverage와 pseudo 30% expansion 포함
- public configuration validation: **PASS**
- high-confidence secret scan: **PASS**
- generated code drift: **8 generated files, 0 drift**
- Markdown embedded YAML parse, CSV row/column consistency, file references and trailing whitespace: **PASS**

## Security and privacy evidence

- registry는 boolean composition signal과 enum-only local notification signal만 소비한다.
- 화면과 semantics에는 선택 연동의 안전한 제품명, stable state/reason, fallback만 포함된다.
- Firebase option, RevenueCat key, URI, provider error, account/household/device/payment identifier는 entity, provider, widget copy, test fixture와 log에 포함하지 않았다.
- status action은 이미 존재하는 allowlisted app route만 사용하며 capability 화면 자체는 permission/provider/network/Store/storage operation을 호출하지 않는다.
- background delivery는 client handler를 authoritative로 오인하지 않고 항상 server notification pipeline과 durable inbox를 명시한다.

## Manual and deferred evidence

- 실제 Android 알림 permission dialog와 system settings 복귀
- Firebase delivery/token lifecycle, RevenueCat/Google Play sandbox와 실제 entitlement 반영
- Android Keystore process restart/forensic, system browser/chooser와 export download
- hosted notification worker/inbox fallback, 실계정·다중기기·실기기
- TalkBack/physical keyboard, iOS provider composition, Web capability registry/fallback matrix

사용자 지시에 따라 위 검증은 마지막 통합 Gate까지 미룬다. 따라서 `FR-PLAT-008`, `FR-PLAT-014`, `NFR-PLAT-001`, `NFR-PLAT-002`는 Android local 구현 증거가 추가되었지만 전체 cross-platform 완료가 아닌 `PARTIAL`이다.

## Rollback

- `platform_capabilities` feature, `AuthDependencies.platformCapabilityRegistry`, bootstrap override와 Settings tile/route를 제거하면 기존 알림·결제·secure cache·URL launcher·background handler 동작으로 돌아간다.
- DB/API/storage payload가 바뀌지 않았으므로 migration rollback, data backfill, account/provider cleanup은 필요 없다.
