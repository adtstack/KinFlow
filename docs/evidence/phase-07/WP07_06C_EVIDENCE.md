# Phase 07 WP07-06C Cross-Feature Timezone Picker Adoption Evidence

## 결과

- 상태: **LOCAL IMPLEMENTED (2026-08-09)** — WP07-06 전체와 G7 완료는 아님
- 구현 요구사항: `FR-HH-002`, `FR-NOTIF-004`, `FR-SET-002`
- 완료 수직 조각: Store MVP timezone editor 전수 확인 → 공용 read-only selection field → 첫 가구 검색·선택·create → 알림 preference 검색·선택·save/cancel → 기존 server validation 유지
- 자동화로 확인한 사용자 편집 가능한 timezone 자유 입력은 0개이며 첫 가구·개인 profile·기존 가구·알림 recipient의 네 필드가 같은 공용 선택 component를 사용한다.

## 구현 범위

### Shared selection component

- settings 전용 picker를 `app/presentation/widgets`로 이동하고 `TimezoneSelectionFormField`와 modal launcher를 함께 제공한다.
- form field는 `readOnly`, cursor/interactive text selection 비활성, keyboard submit callback 없음으로 구성해 catalog를 우회하는 자유 입력 경로를 제공하지 않는다.
- picker를 닫거나 back으로 나가거나 catalog load가 실패하면 기존 controller draft를 유지하고, 실제 row를 선택했을 때만 exact IANA identifier로 바꾼다.
- loading, failure/retry, current value, selected semantics, UTC pin, current offset/DST, 최대 100건 결정적 검색과 compact 200% full-scroll 계약은 WP07-06B와 동일하다.

### First household

- 첫 가구 기본값 `Asia/Seoul`을 유지하고 시간대 field를 공용 선택 component로 교체했다.
- widget 회귀에서 `London` 검색 후 `Europe/London`을 선택하고 exact create request가 전달되며 기존 guided setup으로 이어지는 것을 확인했다.
- form validation, single-flight/idempotent create command, safe retry와 오류 draft 보존은 변경하지 않았다.

### Notification preference

- category preference dialog는 authoritative recipient timezone으로 시작하고 공용 선택 component를 사용한다.
- widget 회귀에서 `New York` 검색 후 `America/New_York`을 선택해 저장했으며 기존 `22:00–07:00` quiet interval, category/household scope와 optimistic version을 그대로 전달했다.
- 새 dialog에서 `Europe/London`을 선택한 뒤 cancel하면 update가 추가 호출되지 않고 모든 dialog draft가 폐기되는 것을 확인했다.
- 선택 직후 이전 field validation 오류만 지우며 실제 repository update는 save에만 발생한다.

### Profile regression and localization

- 개인 profile과 Owner/Admin 기존 가구 timezone도 같은 `TimezoneSelectionFormField`를 사용하도록 공용 API에 맞췄다.
- Member의 가구 timezone read-only 표시, household 영향 확인, atomic profile save와 immediate locale 적용은 변경하지 않았다.
- 첫 가구와 알림 picker title, hint, validation을 EN/KO/EN-XA ARB의 선택 표현으로 추가하고 generated localization을 갱신했다.

주요 앱 파일:

- `apps/kinflow_app/lib/app/presentation/widgets/timezone_picker_sheet.dart`
- `apps/kinflow_app/lib/features/household/presentation/screens/household_onboarding_screen.dart`
- `apps/kinflow_app/lib/features/notifications/presentation/screens/notification_center_screen.dart`
- `apps/kinflow_app/lib/features/settings/presentation/screens/profile_preferences_screen.dart`
- `apps/kinflow_app/test/architecture/timezone_picker_adoption_test.dart`
- `apps/kinflow_app/test/features/household/household_onboarding_widget_test.dart`
- `apps/kinflow_app/test/features/notifications/notification_center_widget_test.dart`

## Server, security, and privacy impact

- migration, RPC, table, grant, RLS policy, Storage, Edge Function, remote DTO 또는 payload shape를 추가·변경하지 않았다.
- 첫 가구 submit은 기존 atomic `create_first_household`, 알림 save는 기존 expected-version `update_notification_preference`를 사용하며 둘 다 PostgreSQL `app_private.is_valid_iana_timezone`이 최종 권위로 다시 검증한다.
- client bundle catalog는 authorization, persistence, quiet-hours delivery 또는 recurrence authority가 아니다.
- 검색어, 선택 이력, offset/DST, account/household identifier를 저장·전송·로그·분석하지 않으며 catalog load에 network 요청이 없다.
- raw exception이나 catalog 내부 오류를 사용자에게 노출하지 않고 기존 localized bounded failure/retry UI를 유지한다.

## 계약과 추적성

- `docs/contracts/timezone-picker-adoption.yaml.md`
- `docs/contracts/timezone-catalog.yaml.md`
- `docs/evidence/phase-07/WP07_06C_WORKPLAN.md`
- `docs/matrices/REQUIREMENTS_TRACEABILITY.csv.md`
- `docs/matrices/TEST_MATRIX.csv.md`
- `docs/phases/PHASE_07_PRIVACY_SECURITY_ACCESSIBILITY_AND_GLOBAL.md`

## 자동 검증 결과

| 영역 | 명령/검사 | 결과 |
|---|---|---|
| Focused adoption | shared static adoption, catalog domain/repository, profile, household, notification, localization suites | PASS, 30 tests |
| Cross-feature regression | `flutter test test/features/household test/features/notifications test/features/settings test/architecture test/localization` | PASS, 261 tests |
| Flutter full | `flutter test --reporter compact` | PASS, 1045 tests + opt-in live 1 skip |
| Analyzer | `flutter analyze` | PASS, issue 0 |
| Format | `dart --suppress-analytics format --output=none --set-exit-if-changed lib test` | PASS, 601 files / drift 0 |
| Localization generation | `flutter gen-l10n` with analytics disabled | PASS |
| Root contract tests | `npm run ci:test` | PASS, 141 tests |
| Adoption source contract | exact shared-field count and editable timezone-controller scan | PASS, four shared fields / editable free text 0 |
| Timezone YAML parse | fenced catalog and picker-adoption contracts | PASS, 2 contracts |
| Matrix parse | fenced CSV declared-row/column 검사 | PASS, 13 matrices / requirements 116×18 / tests 78×11 |
| Secret scan | exact Dart 3.12.2 `--suppress-analytics` scanner | PASS, high-confidence finding 0 |
| Whitespace | `git diff --check` | PASS |

모든 account, household, preference와 command 값은 synthetic local fixture였다. production credential, 실제 가족 content, Supabase/Google/Store 계정, hosted project, push provider 또는 physical device를 사용하지 않았다.

## 수동·실환경 검증

사용자 우선순위에 따라 다음 항목은 **NOT RUN / 마지막 통합 Gate**로 유지한다.

- hosted PostgreSQL timezone catalog와 bundle `2025c` identifier parity
- 실제 계정의 첫 가구 생성과 notification preference 저장·authoritative reload
- 두 계정·다중기기·process restart 뒤 선택값 동기화
- 실제 keyboard, TalkBack/VoiceOver, system font scale, tablet/split-screen
- DST 전환과 여행 전후 quiet-hours delivery 및 실제 기기 offset 표시

로컬 picker와 fake repository 회귀 통과를 hosted 저장, push delivery, cross-device 또는 실기기 완료로 해석하지 않는다.

## 남은 위험과 OPEN 항목

- bundle `2025c`와 hosted PostgreSQL tzdb release가 다르면 bundle에 없는 신규 zone은 검색할 수 없고 server에서 제거·변경된 alias는 저장 시 거부될 수 있다.
- 검색은 IANA identifier의 영문 region/city token을 사용하며 localized 도시 별칭 catalog는 아직 없다.
- 실제 OS keyboard·screen reader와 DST/여행 시점의 notification delivery는 자동 widget 계약만으로 검증할 수 없다.
- 전체 EN/KO copy review, RTL structural audit, Store metadata와 G7 실기기 접근성은 아직 완료하지 않았다.

## Rollback

- 공용 `TimezoneSelectionFormField`를 current-value display로 되돌려도 기존 first-household create와 notification/profile update command 및 저장값은 호환된다.
- picker 소비 화면별 rollback은 server validation, audit, recurrence, quiet-hours delivery 또는 RLS를 변경하지 않는다.
- bundle catalog dependency를 제거할 때도 자유 입력을 복원하지 않고 server-compatible read-only 표시로 fail closed한다.

## 다음 진입 조건

- 기능 우선순위상 다음 독립 수직 조각을 계속 구현하고 hosted/실계정/cross-device/실기기 검증은 사용자 지시대로 마지막 통합 Gate에 둔다.
- WP07-06의 남은 후보는 locale-aware date/time 표현과 RTL structural audit이며, 별도 우선순위 기능 WP와 섞지 않는다.
