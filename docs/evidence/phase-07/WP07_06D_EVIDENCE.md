# Phase 07 WP07-06D Regional Date/Time Preview Evidence

## 결과

- 상태: **LOCAL IMPLEMENTED (2026-08-09)** — WP07-06 전체와 G7 완료는 아님
- 구현 요구사항: `FR-SET-002`, `FR-PLAT-001`, `NFR-I18N-01`
- 완료 수직 조각: profile regional draft → bundled catalog exact lookup → same-instant personal/household wall time → draft-locale formatting → explicit refresh/retry → unchanged save command
- profile 설정에서 개인과 active household의 현재 날짜·시간을 같은 UTC instant 기준으로 비교하며, 언어 또는 timezone draft를 바꾸면 어떤 저장 mutation도 호출하기 전에 결과가 갱신된다.

## 구현 범위

### Same-instant regional preview

- 공용 `TimezoneDateTimePreviewPanel`이 bundled catalog snapshot을 한 번 load하고 개인·가구 row 모두에 하나의 UTC instant를 사용한다.
- catalog의 exact, case-sensitive `entryForIdentifier`만 허용하며 substring, case folding, device timezone 또는 다른 identifier로 대체하지 않는다.
- 각 row는 exact IANA identifier, locale-aware full date/time, current UTC offset과 daylight-saving/standard-time metadata를 함께 보여 준다.
- profile·household timezone picker의 선택 callback은 기존 controller draft만 갱신하고 panel을 즉시 rebuild한다.

### Draft locale and system time format

- draft language는 저장 전에 앱 전역 locale을 바꾸지 않고 preview subtree의 Material date/time localization에만 `en` 또는 `ko`로 적용한다.
- 시간 표현은 `MediaQuery.alwaysUse24HourFormat`을 따르므로 OS의 12/24-hour 선택을 보존한다.
- 자동 timer는 두지 않는다. 사용자가 48dp 이상 refresh action을 명시적으로 누를 때만 새 instant와 catalog offset/DST snapshot을 함께 가져온다.

### Failure, retry, and accessibility

- 최초 load 실패는 localized retry를 제공하고 모든 profile draft를 보존한다.
- 이미 완성된 snapshot을 refresh하다 실패하면 이전 instant와 두 row를 계속 표시하면서 bounded failure 상태만 알린다.
- bundle에 exact identifier가 없으면 원래 identifier를 표시하고 해당 row만 unavailable로 닫으며 다른 row나 device timezone으로 대체하지 않는다.
- row는 고정 높이를 사용하지 않고 semantic summary를 제공한다. compact `320×568`, EN-XA, 200% text에서 parent scroll과 refresh 48dp target을 widget test로 확인했다.

주요 앱 파일:

- `apps/kinflow_app/lib/app/presentation/widgets/timezone_date_time_preview.dart`
- `apps/kinflow_app/lib/app/providers/timezone_catalog_dependencies.dart`
- `apps/kinflow_app/lib/features/settings/domain/entities/timezone_catalog.dart`
- `apps/kinflow_app/lib/features/settings/presentation/screens/profile_preferences_screen.dart`
- `apps/kinflow_app/lib/l10n/app_en.arb`
- `apps/kinflow_app/lib/l10n/app_ko.arb`
- `apps/kinflow_app/lib/l10n/app_en_XA.arb`
- `apps/kinflow_app/test/app/timezone_date_time_preview_test.dart`
- `apps/kinflow_app/test/features/settings/profile_preferences_widget_test.dart`
- `apps/kinflow_app/test/features/settings/timezone_catalog_domain_test.dart`

## Server, security, and privacy impact

- migration, RPC, table, grant, RLS policy, Edge Function, remote DTO와 profile update payload shape를 추가·변경하지 않았다.
- preview는 표시 전용 snapshot이며 timezone persistence나 authorization의 권위자가 아니다. 저장은 기존 `update_profile_preferences` expected-version transaction과 PostgreSQL IANA validation을 그대로 사용한다.
- UTC instant, preview 결과, locale/timezone 조합, 검색·선택 이력, account/household identifier를 저장·전송·로그·분석하지 않는다.
- raw exception이나 catalog 내부 오류는 사용자에게 노출하지 않고 localized bounded failure/retry로 닫는다.

## 계약과 추적성

- `docs/contracts/timezone-date-time-preview.yaml.md`
- `docs/contracts/timezone-catalog.yaml.md`
- `docs/contracts/profile-preferences.yaml.md`
- `docs/evidence/phase-07/WP07_06D_WORKPLAN.md`
- `docs/matrices/REQUIREMENTS_TRACEABILITY.csv.md`
- `docs/matrices/TEST_MATRIX.csv.md`
- `docs/phases/PHASE_07_PRIVACY_SECURITY_ACCESSIBILITY_AND_GLOBAL.md`

## 자동 검증 결과

| 영역 | 명령/검사 | 결과 |
|---|---|---|
| Focused preview | preview, catalog domain/repository, profile, localization suites | PASS, 26 tests |
| Settings/global impact | `flutter test test/features/settings test/localization test/architecture test/app` | PASS, 200 tests |
| Flutter full | `flutter test --reporter compact` | PASS, 1053 tests + opt-in live 1 skip |
| Analyzer | `flutter analyze` | PASS, issue 0 |
| Format | exact Dart 3.12.2 format drift | PASS, 603 files / drift 0 |
| Localization generation | exact Flutter 3.44.7 `gen-l10n` | PASS |
| Root contract tests | `npm run ci:test` | PASS, 141 tests |
| Preview contract | fenced YAML parse and exact boundary assertions | PASS |
| Matrix parse | fenced CSV declared-row/column 검사 | PASS, 13 matrices / requirements 116×18 / tests 78×11 |
| Secret scan | exact Dart 3.12.2 `--suppress-analytics` scanner | PASS, high-confidence finding 0 |
| Whitespace | `git diff --check` plus scoped new-file trailing-space scan | PASS, 15 scoped files / finding 0 |

모든 instant, timezone, profile과 household 값은 synthetic local fixture였다. production credential, 실제 가족 content, Supabase/Google/Store 계정, hosted project 또는 physical device를 사용하지 않았다.

## 수동·실환경 검증

사용자 우선순위에 따라 다음 항목은 **NOT RUN / 마지막 통합 Gate**로 유지한다.

- hosted PostgreSQL timezone catalog와 bundled `2025c` identifier/offset parity
- 실제 계정의 저장·authoritative reload, 두 계정·다중기기와 process restart 동기화
- 실제 Android locale과 system 12/24-hour setting 전환
- DST 경계 직전·직후와 여행 중 명시적 refresh 결과
- TalkBack/VoiceOver, physical keyboard, system font scale, tablet/split-screen

로컬 Material formatting과 fake repository 회귀 통과를 hosted 저장, 실계정 동기화, DST 실환경 또는 실기기 완료로 해석하지 않는다.

## 남은 위험과 OPEN 항목

- bundled `2025c`와 hosted PostgreSQL tzdb release가 다르면 bundle에 없는 신규 zone은 unavailable이며 저장 시 server 판정과 표시 snapshot이 달라질 수 있다.
- preview는 의도적으로 background timer가 없으므로 화면을 오래 열어 둔 경우 사용자가 refresh하기 전까지 instant와 offset/DST snapshot이 고정된다.
- 실제 OS locale·12/24-hour 전환, DST boundary와 assistive technology 읽기 순서는 widget contract만으로 완전히 검증할 수 없다.
- 전체 앱 EN/KO copy review, RTL structural audit, Store metadata와 G7 실기기 접근성은 아직 완료하지 않았다.

## Rollback

- preview panel과 exact lookup helper를 제거해도 기존 picker, profile controller, locale sink, RPC command와 저장된 timezone은 호환된다.
- client-only rollback은 PostgreSQL validation, private audit, recurrence/materialized instant, notification semantics 또는 RLS를 변경하지 않는다.
- catalog failure 시 자유 입력이나 device timezone fallback을 복원하지 않고 기존 authoritative 값의 read-only 표시로 fail closed한다.

## 다음 진입 조건

- 기능 우선순위상 다음 독립 수직 조각을 계속 구현하고 hosted/실계정/cross-device/실기기 검증은 사용자 지시대로 마지막 통합 Gate에 둔다.
- WP07-06의 남은 후보인 RTL structural audit와 Store metadata는 각각 별도 계약과 증적으로 진행한다.
