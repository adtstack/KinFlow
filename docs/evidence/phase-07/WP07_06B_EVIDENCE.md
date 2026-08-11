# Phase 07 WP07-06B Searchable IANA Timezone Evidence

## 결과

- 상태: **LOCAL IMPLEMENTED (2026-08-09)** — WP07-06 전체와 G7 완료는 아님
- 구현 요구사항: `FR-SET-002`, `FR-HH-002`
- 유지 결정: `D-013` Store MVP authenticated adult scope
- 완료 수직 조각: profile/household 현재 시간대 → 번들 IANA catalog load → 지역·도시 token 검색 → 현재 offset/DST 확인 → 명시적 선택 → 기존 atomic save 및 선택적 household impact confirmation

## 구현 범위

### Catalog and domain

- 기존 고정 dependency `timezone 0.11.1`의 IANA database `2025c`를 Calendar resolver와 picker가 동일한 process-level initializer로 사용한다.
- provider-independent `TimezoneCatalogEntry`는 `UTC` 또는 slash가 있는 bounded IANA identifier와 현재 offset `-14:00..+14:00`, DST flag만 보유한다.
- catalog는 exact identifier 중복과 `UTC` 누락을 fail closed하고 `posix/`, `right/`, slash 없는 abbreviation을 노출하지 않는다.
- 검색은 최대 80자, trim/lowercase, slash·underscore→space, whitespace collapse 후 모든 token 포함을 요구한다.
- exact normalized ID → 마지막 도시 segment prefix → 전체 ID prefix → 나머지 token match 순으로 rank하고 identifier로 결정적 정렬하며 최대 100건만 노출한다.
- 빈 검색은 현재 선택과 `UTC`를 먼저 보여 주고, 현재 server value가 bundle에 없더라도 별도 current-value 영역에 유지한다.
- current offset/DST는 catalog load 시점 표시 metadata이며 저장, recurrence, 권한 또는 server validation authority로 사용하지 않는다.

### Flutter UX

- 개인 및 Owner/Admin 가구 시간대의 자유 입력을 read-only 선택 trigger로 교체하고 같은 `TimezonePickerSheet`를 재사용한다.
- 선택기는 current value, labelled search, clear, loading, retry, empty result, selected semantics, exact IANA ID, UTC offset/DST metadata를 제공한다.
- catalog failure 시 current draft를 유지하고 retry만 제공하며 server validation을 우회하는 자유 입력 fallback은 제공하지 않는다.
- picker row 선택은 form draft만 바꾸고 기존 저장 버튼 전에는 repository/RPC를 호출하지 않는다.
- Member의 가구 시간대는 계속 read-only이며, Owner/Admin이 실제 가구 시간대를 바꿔 저장할 때만 기존 반복 semantics 영향 확인 dialog가 열린다.
- 전체 picker를 하나의 scroll surface로 만들어 compact 320×568, EN-XA, 200% text에서도 header·current value·search·results·48dp close target에 blocker overflow가 없다.
- EN/KO/EN-XA ARB와 생성 localization을 갱신했다.

주요 앱 파일:

- `apps/kinflow_app/lib/features/settings/domain/entities/timezone_catalog.dart`
- `apps/kinflow_app/lib/features/settings/domain/repositories/timezone_catalog_repository.dart`
- `apps/kinflow_app/lib/features/settings/data/repositories/bundled_timezone_catalog_repository.dart`
- `apps/kinflow_app/lib/infrastructure/timezone/bundled_timezone_database.dart`
- `apps/kinflow_app/lib/app/providers/timezone_catalog_dependencies.dart`
- `apps/kinflow_app/lib/app/presentation/widgets/timezone_picker_sheet.dart`
- `apps/kinflow_app/lib/features/settings/presentation/screens/profile_preferences_screen.dart`
- `apps/kinflow_app/lib/features/calendar/data/services/timezone_calendar_time_resolver.dart`

## Server, security, and privacy impact

- migration, RPC, table, grant, RLS policy, Storage, Edge Function 또는 remote DTO를 추가·변경하지 않았다.
- 실제 저장은 계속 `update_profile_preferences(...)`가 `auth.uid()`, active membership role, expected versions와 PostgreSQL `app_private.is_valid_iana_timezone`을 다시 검증한다.
- household timezone audit와 기존 chore/calendar series timezone 및 materialized canonical instant 보존 계약은 변경하지 않았다.
- catalog load/search에는 network, account ID, household ID, 위치 권한, analytics, log 또는 persisted search history가 없다.
- bundle/server tzdb version 차이가 있으면 server save가 최종 fail closed하며 current authoritative value는 picker failure나 catalog miss로 자동 변경되지 않는다.

## 계약과 추적성

- `docs/contracts/timezone-catalog.yaml.md`
- `docs/contracts/profile-preferences.yaml.md`
- `docs/evidence/phase-07/WP07_06B_WORKPLAN.md`
- `docs/matrices/REQUIREMENTS_TRACEABILITY.csv.md`
- `docs/matrices/TEST_MATRIX.csv.md`
- `docs/phases/PHASE_07_PRIVACY_SECURITY_ACCESSIBILITY_AND_GLOBAL.md`

## 자동 검증 결과

| 영역 | 명령/검사 | 결과 |
|---|---|---|
| Focused timezone/profile | catalog domain, bundled repository, profile domain, profile widget suites | PASS, 19 tests |
| Settings + architecture + localization | `flutter test test/features/settings test/architecture/dependency_boundary_test.dart test/localization/localization_contract_test.dart` | PASS, 134 tests |
| Flutter full | `flutter test --reporter compact` | PASS, 1041 tests + opt-in live 1 skip |
| Analyzer | `flutter analyze` | PASS, issue 0 |
| Format | `dart format --output=none --set-exit-if-changed lib test` | PASS, 600 files / drift 0 |
| Localization generation | `flutter gen-l10n` with analytics disabled | PASS |
| Root contract tests | `npm run ci:test` | PASS |
| Matrix/contract parse | Markdown fenced CSV/YAML parse contract | PASS |
| Secret scan | `dart --suppress-analytics run tool/scan_secrets.dart` | PASS, high-confidence finding 0 |
| Whitespace | `git diff --check` | PASS |

첫 widget run은 fixed header/current/search 위에 결과만 scroll하던 구조가 compact 200% EN-XA에서 bottom overflow를 만드는 문제를 검출했다. 선택기 전체를 단일 scroll surface로 바꾸고 직접 200% pseudo render에서 search까지 scroll 가능한지 검증한 뒤 focused, settings, architecture, localization, full regression이 통과했다.

## 수동·실환경 검증

사용자 우선순위에 따라 다음 항목은 **NOT RUN / 마지막 통합 Gate**로 유지한다.

- hosted PostgreSQL timezone catalog와 bundle `2025c` identifier parity
- 실제 Google/Supabase 계정의 개인/Owner/Admin/Member 저장과 다중기기 authoritative refresh
- Android process kill/restart 뒤 저장값 복원
- 실제 keyboard, TalkBack, font scale, tablet/split-screen
- DST 전환·여행 전후 실제 기기의 offset label, Today, 새 항목 default와 notification 표시

로컬 bundle/search/save-contract 자동 검증을 hosted catalog, 실계정, cross-device 또는 실기기 완료로 해석하지 않는다.

## 남은 위험과 OPEN 항목

- bundle `2025c`와 hosted PostgreSQL tzdb가 다른 release이면 bundle에 없는 신규 zone은 current value로 유지되지만 새로 검색할 수 없고, server에서 제거·변경된 alias 선택은 저장 시 거부될 수 있다.
- IANA identifier 검색은 localized 도시 번역 catalog가 아니므로 사용자는 `Seoul`, `New_York`, `Europe` 같은 IANA 영문 token을 사용한다.
- WP07-06B 당시 선택기는 profile/household 설정에 우선 적용했으며, 첫 가구 onboarding과 notification editor 확장은 후속 `WP07-06C`에서 완료했다.
- 전체 EN/KO copy review, RTL structural audit, Store metadata와 G7 실기기 접근성은 아직 완료하지 않았다.

## Rollback

- `TimezonePickerSheet` trigger와 catalog provider를 제거하거나 current-value read-only 표시로 되돌려도 기존 profile save RPC와 저장 데이터는 유지된다.
- shared initializer를 기존 Calendar resolver 내부 초기화로 되돌려도 database version과 recurrence result는 유지된다.
- dependency/tzdb update는 lockfile과 database-version test를 함께 전진 변경하며 DB rollback은 필요하지 않다.

## 다음 진입 조건

- 기능 우선순위상 다음 수직 조각을 계속 구현하고 hosted/실계정/cross-device/실기기 검증은 사용자 지시대로 마지막 통합 Gate에 둔다.
- 후속 후보는 동일 picker의 onboarding/notification/Calendar editor 확장 또는 locale-date/RTL 구조 audit이다.
