# Phase 07 WP07-06A Profile and Regional Settings Evidence

## 결과

- 상태: **LOCAL IMPLEMENTED (2026-08-08)** — WP07-06 전체와 G7 완료는 아님
- 구현 요구사항: `FR-SET-001`, `FR-SET-002`, `FR-HH-002`
- 유지 결정: `D-013` Store MVP authenticated adult scope
- 완료 수직 조각: authenticated active-household load → 본인 display/avatar/language/personal-timezone 편집 → 선택적 Owner/Admin household-timezone 영향 확인 → atomic expected-version save → authoritative locale 즉시 반영 → logout/account-switch 격리

## 구현 범위

### Database

- `supabase/migrations/20260808140000_profile_preferences_and_household_timezone.sql`
  - authenticated-only `get_profile_preferences()` exact minimal projection
  - authenticated-only `update_profile_preferences(...)` atomic command
  - 본인 profile과 active membership display/avatar 동기화
  - active Owner/Admin만 household timezone 변경, Member는 personal-only 변경
  - profile/household optimistic version conflict를 `KFS05`/`KFS06`으로 구분
  - PostgreSQL timezone catalog 기반 IANA 검증과 `en`/`ko`, preset avatar, display-name validation
  - 직접 profile update policy/grant 제거로 mediated command 우회 차단
  - client/service 비공개 append-only `app_private.household_timezone_audit_events`
  - no-op version 안정성과 실패 시 profile/membership/household/audit 전체 rollback
- 기존 chore/calendar series timezone과 materialized canonical instant를 변경하는 query는 없다.

### Flutter

- domain: provider-free `ProfilePreferences`, update command, role-derived household authority, bounded failures
- data: exact Supabase record parser → mapper → domain, stable SQLSTATE mapping, nullable household mutation boundary
- application: authoritative load/save, double-submit 차단, conflict 보존, generation 기반 stale in-flight 무시, locale sink
- lifecycle: authenticated user+active household scope에서만 load하고 logout/account switch 시 state와 app locale reset
- UI: 설정 route/tile, display name, nullable preset avatar, EN/KO dropdown, personal IANA timezone, role별 household timezone editor/read-only 상태
- 실제 household timezone 변경에만 영향 확인 dialog를 띄우고 기존 반복 item timezone/instant 보존을 명시
- server refresh가 바뀐 locale을 반환하면 dropdown 내부 상태와 app locale을 함께 교체
- EN/KO/EN-XA, stable widget keys, compact 200% text scroll layout

주요 앱 파일:

- `apps/kinflow_app/lib/features/settings/domain/entities/profile_preferences.dart`
- `apps/kinflow_app/lib/features/settings/domain/repositories/profile_preferences_repository.dart`
- `apps/kinflow_app/lib/features/settings/application/profile_preferences_controller.dart`
- `apps/kinflow_app/lib/features/settings/application/unavailable_profile_preferences_repository.dart`
- `apps/kinflow_app/lib/features/settings/data/datasources/profile_preferences_data_source.dart`
- `apps/kinflow_app/lib/features/settings/data/repositories/provider_profile_preferences_repository.dart`
- `apps/kinflow_app/lib/features/settings/presentation/providers/profile_preferences_providers.dart`
- `apps/kinflow_app/lib/features/settings/presentation/screens/profile_preferences_screen.dart`
- `apps/kinflow_app/lib/features/settings/presentation/widgets/profile_preferences_lifecycle_host.dart`
- `apps/kinflow_app/lib/infrastructure/supabase/supabase_profile_preferences_data_source.dart`
- `apps/kinflow_app/lib/app/providers/app_providers.dart`
- `apps/kinflow_app/lib/app/providers/auth_dependencies.dart`
- `apps/kinflow_app/lib/app/router/app_router.dart`

## 계약과 추적성

- `docs/contracts/profile-preferences.yaml.md`
- `docs/contracts/database-schema.sql.md`, `docs/contracts/rls-contract.sql.md`, `docs/contracts/error-catalog.yaml.md`
- `docs/matrices/REQUIREMENTS_TRACEABILITY.csv.md`, `docs/matrices/TEST_MATRIX.csv.md`
- `docs/phases/PHASE_07_PRIVACY_SECURITY_ACCESSIBILITY_AND_GLOBAL.md`

## 자동 검증 결과

| 영역 | 명령/검사 | 결과 |
|---|---|---|
| Clean migration | `supabase db reset --local` | PASS, migration 39개 적용 |
| Focused pgTAP | `supabase test db supabase/tests/database/profile_preferences_and_household_timezone.test.sql` | PASS, 39 tests |
| DB lint | `supabase db lint --local --level warning` | PASS, schema warning/error 0 |
| Full pgTAP | `supabase test db` | PASS, 46 files / 2386 tests / 349s |
| Flutter focused | composition/locale/domain/repository/controller/lifecycle/parser/widget/settings suites | PASS, 36 tests |
| Flutter full | `flutter test` | PASS, 756 tests + opt-in live 1 skip |
| Analyzer | `flutter analyze` | PASS, issue 0 |
| Format | `dart format --output=none --set-exit-if-changed lib test` | PASS, 466 files / drift 0 |
| Codegen | `dart run build_runner build --delete-conflicting-outputs` | PASS, output write 0; current runner reports the legacy flag ignored |
| Localization | exact EN/KO/EN-XA keys, pseudo 30% expansion, compact 200% widget | PASS |
| Contract parse | profile/error fenced YAML + 3 ARB JSON | PASS |
| Matrix parse | fenced CSV matrix 13개 declared-row/column 검사 | PASS |
| Secret scan | `dart run tool/scan_secrets.dart` | PASS, high-confidence finding 0 |
| Whitespace | `git diff --check` | PASS |

전체 회귀는 처음에 presentation→data fallback import와 pseudo 문구 30% 확장 부족, 강화된 direct-profile-write 정책에 대한 과거 baseline 기대값을 탐지했다. fallback을 application 계층으로 이동하고 pseudo copy와 foundation RLS expectation을 갱신한 뒤 관련 집중 테스트와 Flutter full suite가 통과했다.

## 수동·실환경 검증

사용자 우선순위에 따라 다음 항목은 **NOT RUN / 마지막 통합 Gate**로 유지한다.

- 실제 Google/Supabase 성인 계정에서 EN↔KO 저장과 다른 기기 authoritative refresh
- hosted PostgreSQL timezone catalog 및 실제 network/version-conflict 동작
- Android process kill/restart 뒤 저장 locale 복원
- 실제 기기 keyboard, TalkBack, font scale, tablet/split-screen
- 이동·DST 전후 실제 기기 Today/notification 표시와 새 항목 default 확인

로컬 자동 검증 결과를 실계정, hosted, cross-device 또는 실기기 완료로 해석하지 않는다.

## 보안·개인정보 영향

- 법적 이름, 이메일, 생년월일, 사용자 업로드 URL/object key를 새로 수집하지 않는다.
- avatar는 앱에 내장된 네 preset key 또는 `null`만 허용한다.
- caller/profile/active membership/role을 server에서 다시 계산하고 client capability flag를 신뢰하지 않는다.
- direct profile update grant와 policy를 제거해 active membership 표기 동기화를 우회할 수 없다.
- household 변경은 expected version과 Owner/Admin 권한을 동시에 요구하며 private audit에는 actor ID, 전후 timezone, aggregate version만 저장한다.
- provider payload는 exact record → mapper → domain 순으로 fail closed 처리하고 raw provider message를 UI에 반영하지 않는다.

## 남은 위험과 OPEN 항목

- 자유 입력 IANA timezone은 server-authoritative validation이지만 선택형 timezone 검색 UX는 후속 개선 후보다.
- 계정별 다중 active household와 profile별 household-specific display/avatar는 현재 단일 active-household 모델 밖이다.
- 업로드 avatar는 storage, moderation, crop, deletion, CDN privacy 계약 전까지 의도적으로 제외한다.
- WP07-06의 전체 EN/KO copy review, RTL structural audit, Store metadata는 아직 완료하지 않았다.

## Rollback

- Flutter route/tile/lifecycle host와 repository override를 제거하면 기존 설정·Today·Chore·Calendar 기능은 유지된다.
- `get_profile_preferences`/`update_profile_preferences` execute를 revoke해 신규 변경을 즉시 중단할 수 있다.
- migration은 forward-only다. 후속 migration으로 RPC를 교체하되 기존 profile/household/series와 private audit을 삭제하지 않는다.
- household timezone을 이전 값으로 되돌리는 경우에도 새 versioned command와 audit event를 사용한다.

## 다음 진입 조건

- 기능 우선순위상 다음 수직 조각을 계속 구현하고, hosted/실계정/cross-device/실기기 검증은 사용자 지시대로 마지막 통합 Gate에서 수행한다.
- WP07-06 후속 후보는 timezone 검색 UX 또는 전체 locale-date/RTL 구조 audit이며, Store metadata·법률 copy는 별도 승인과 함께 진행한다.
