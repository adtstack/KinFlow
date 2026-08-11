# Phase 01 WP01-09 Android Capability Self-Check and Recovery Evidence

## Result

- 상태: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-09)**
- 사용자 기능: Settings → 기기 기능 상태에서 exact five capability를 준비됨·조치 필요·대안/제한으로 집계하고, 문제를 우선순위대로 복구하며 알림 권한·기기 연결 상태를 명시적으로 다시 확인한다.
- 범위: 기존 capability snapshot, notification state/provider와 coordinator만 재사용한다. 별도 permission prompt, system settings, Store/provider health probe, DB/API schema는 추가하지 않는다.

## Implemented contract

- `PlatformCapabilityRecoveryPlan`은 available을 준비됨으로 집계하고 non-ready 상태를 `temporaryIssue → actionRequired → fallbackOnly → limited`와 registry exact order tie-break로 정확히 한 번 정렬한다.
- ready, attention, alternative count는 exact five entry를 중복 없이 분할하며 recovery step 목록은 immutable이다.
- 기존 `/settings/device-capabilities`는 summary와 권장 복구 순서를 상세 provider 카드보다 먼저 표시하고 각 단계에서 기존 notification, subscription 또는 diagnostics route만 연다.
- 사용자의 명시적 자체 점검은 `NotificationPushNotifier.refreshPermission()`만 single-flight로 호출한다. 새 permission request나 system settings를 열지 않으며, 권한 변화에 필요한 endpoint 정리 또는 authorized binding 재조정은 기존 coordinator 경계 안에서만 수행한다.
- 성공/실패 결과는 localized live region으로 표시한다. raw provider exception, configuration, account, household, device, payment identifier는 plan, UI, semantics와 log에 추가하지 않는다.
- EN/KO/EN-XA에서 320×568, text scale 200%, 전체 scroll과 48dp action을 유지한다.

## Changed surfaces

- 계약·계획: `docs/contracts/platform-capability-self-check.yaml.md`, `docs/evidence/phase-01/WP01_09_WORKPLAN.md`
- domain/provider/UI: `apps/kinflow_app/lib/features/platform_capabilities/domain/entities/platform_capability_recovery_plan.dart`, `apps/kinflow_app/lib/features/platform_capabilities/presentation/providers/platform_capability_providers.dart`, `apps/kinflow_app/lib/features/platform_capabilities/presentation/screens/platform_capabilities_screen.dart`
- localization: `app_en.arb`, `app_ko.arb`, `app_en_XA.arb`와 generated localization files
- tests: `platform_capability_recovery_plan_test.dart`, `platform_capabilities_widget_test.dart`, `notification_push_coordinator_test.dart`
- traceability: Phase 01 follow-on, contract index, changelog, requirements/test/platform matrices
- 변경 없음: migration, PostgreSQL, RLS, RPC, Edge Function, remote DTO, 새 runtime dependency, Store/provider adapter, stored payload

## Automated evidence

### Focused and impact Flutter tests

- registry, recovery plan, self-check UI와 notification coordinator focused set: **27 passed**
- notification center, route guard, accessibility, localization, architecture 포함 impact set: **68 passed**
- 주요 증명:
  - exact five summary partition과 immutable stable recovery ordering
  - 같은 severity의 registry-order tie-break와 named fallback/action 보존
  - single-flight refresh와 완료 즉시 notification state/plan recomposition
  - explicit refresh가 permission prompt와 settings를 열지 않고 authorized bind 및 revoked cleanup을 기존 coordinator로 조정
  - exception detail 비노출, durable inbox와 safe route 보존
  - KO와 EN-XA 200% scroll, 48dp action, exact localization coverage

### Full local regression

- Flutter full suite: **1,071 passed + 1 explicit live opt-in skipped, 0 failed**
- Flutter analyzer `--fatal-infos --fatal-warnings`: **0 issues**
- Dart format gate: **614 files checked, 0 changed**
- root `npm run ci:test`: **141 passed, 0 failed, 0 skipped**
- localization/pseudo-localization focused set: **12 passed**
- generated code drift: **8 files checked, 0 outputs, passed**
- public configuration allowlist: **passed**
- high-confidence secret scan: **passed**
- embedded contract YAML: **14 top-level keys parsed, passed**
- matrix CSV structure: **requirements 116×18, platform 20×12, tests 79×11, passed**
- changed-surface references / trailing whitespace / `git diff --check`: **9 references present / 0 / passed**

## Security and privacy evidence

- recovery plan은 enum-only in-process snapshot만 소비하고 free-form field, identifier 또는 provider payload를 생성하지 않는다.
- UI는 stable localized result만 노출하며 fake exception의 private detail이 렌더링되지 않는 것을 자동 검증한다.
- permission refresh의 endpoint reconciliation은 새 호출 경로를 만들지 않고 기존 coordinator의 authenticated scope, minimal endpoint material과 purge 규칙을 그대로 사용한다.
- self-check action은 permission prompt, system settings, Store SDK 또는 arbitrary URI를 직접 호출하지 않는다.

## Manual and deferred evidence

- 실제 Android system settings에서 permission 변경 후 app 복귀와 OS별 prompt/settings UI
- Firebase token/binding/delivery, RevenueCat/Google Play, Keystore, system browser와 hosted fallback
- 실계정·다중기기·실기기, TalkBack/physical keyboard
- iOS/Web capability registry와 recovery plan

사용자 지시에 따라 위 검증은 마지막 통합 Gate까지 미룬다. 따라서 관련 요구사항은 Android local 기능 증거가 강화됐지만 전체 provider/cross-platform 완료가 아닌 `PARTIAL`이다.

## Rollback

- recovery plan entity/provider와 capability 화면의 self-check section을 제거하면 WP01-08 read-only status 화면으로 돌아간다.
- DB/API/storage schema나 provider configuration이 바뀌지 않았으므로 rollback migration, data backfill, account 또는 provider cleanup은 필요 없다.
