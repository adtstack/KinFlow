# Phase 03 WP03-10 First-Household Guided Chore Setup Evidence

## 결과

- 상태: **LOCAL AUTOMATED COMPLETE (2026-08-09)** — WP03/G3/출시 완료는 아님
- 범위: `FR-HH-001`, `FR-CHORE-002`, `FR-CHORE-005`, `FR-CHORE-010`, `NFR-REL-01`, `NFR-PRIV-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-048`, `D-051`
- 구현 수직 조각: 첫 가구 생성 → active household snapshot → protected guided route → template 정확히 3개 선택·수정 → 기존 recurring-create 3회 → 부분 재시도 또는 Today
- DB migration, RPC/Edge/RLS/API shape, dependency, native permission, persistent cache와 analytics 추가: 없음
- 실제 계정·remote Supabase·두 기기·실기기 사용: 없음

## 수용 기준

| 기준 | 결과 |
|---|---|
| 첫 가구 handoff | PASS — local active-household snapshot write가 성공한 뒤 `/onboarding/chores`로 이동 |
| protected route | PASS — active household만 유지; no-household는 가구 onboarding, unauthenticated/locked는 sign-in으로 이동 |
| exact 3 selection | PASS — PII-free exact 6-entry catalog에서 서로 다른 항목 3개만 선택하고 나머지 chip 비활성화 |
| 편집 가능 | PASS — selected localized title과 추천 daily/weekly 반복을 제출 전 각각 수정 가능 |
| authoritative defaults | PASS — exact household `loadToday`의 server local date, current active adult, all-day로 생성; cached result 거부 |
| 기존 API 재사용 | PASS — `CreateRecurringChoreRequest` shape 그대로 세 번 사용하고 template key/version 미전송 |
| 멱등·부분 실패 | PASS — entry별 unique command ID, 순차 실행, 성공 항목 non-resend, 실패 항목 same-key retry와 exact progress |
| 명시적 이탈 | PASS — 0개 skip과 부분 성공 exit 모두 확인하며 생성된 항목 보존을 설명 |
| 접근성·국제화 | PASS — EN/KO/EN-XA, progress live region, scroll, 48dp, 320×568 200% overflow 0 |

## Domain과 실패 모델

`GuidedChoreSetupDraft.tryCreate`가 다음 invariant를 한 곳에서 강제한다.

- entry 수는 정확히 3개이고 `ChoreTemplatePreset`이 서로 달라야 한다.
- 입력 순서와 무관하게 immutable catalog 순서로 정렬한다.
- title은 trim 후 1~160자이며 control character를 거부한다.
- guided recurrence는 daily/weekly만 허용한다.
- 각 entry는 기존 `RecurringChoreDraft` validation을 다시 통과하며 description과 due time은 `null`이다.

controller는 `loadToday`의 household ID가 요청과 다르거나 cache metadata가 있으면 각각 `invalidPayload`/`offlineReadOnly`로 fail closed한다. 첫 제출 때 세 개의 서로 다른 command ID를 한 번만 생성하고 batch fingerprint를 freeze한다. 요청은 catalog 순서로 실행하며 성공할 때마다 `completedCount`를 올린다. 실패하면 성공한 index 앞부분은 다시 보내지 않고, 동일 draft retry가 실패한 index의 같은 command ID부터 계속한다. response-loss가 있었다면 기존 server idempotency replay가 동일 결과를 회수한다.

세 create RPC는 하나의 transaction이 아니다. 따라서 일부가 성공한 뒤 나가면 이미 생성된 정상 user data를 유지하며 UI가 exact count와 보존 사실을 알린다. ambiguous failure 뒤 draft를 바꾸는 것은 `invalidTransition`으로 막는다.

## 사용자 흐름

1. 첫 가구 생성 RPC와 active snapshot 교체가 성공한다.
2. 라우터가 guided setup 화면을 열고 repository에서 authoritative household Today date를 읽는다.
3. 사용자가 six-entry catalog 중 세 개를 선택한다. 세 개가 되면 다른 unselected chip은 비활성화된다.
4. 선택된 각 title과 daily/weekly 반복을 검토·수정한다. 담당자는 현재 성인, 시작일은 household today, 시간은 any time임을 화면에 표시한다.
5. `Add 3 chores`가 기존 recurring create를 순차 실행한다.
6. 전부 성공하면 Today provider를 invalidate하고 Today로 이동한다.
7. 중간 실패 시 fields를 잠그고 `n/3` progress와 safe localized failure를 표시한다. retry는 남은 항목만 실행한다.
8. skip 또는 부분 exit는 dialog 확인 후 Today로 이동하며 이미 생성된 chore를 지우지 않는다.

## 구현 파일

- domain/application/provider:
  - `apps/kinflow_app/lib/features/chores/domain/entities/guided_chore_setup.dart`
  - `apps/kinflow_app/lib/features/chores/application/guided_chore_setup_state.dart`
  - `apps/kinflow_app/lib/features/chores/application/guided_chore_setup_controller.dart`
  - `apps/kinflow_app/lib/features/chores/presentation/providers/chore_providers.dart`
- presentation/routing/handoff:
  - `apps/kinflow_app/lib/features/chores/presentation/chore_template_localization.dart`
  - `apps/kinflow_app/lib/features/chores/presentation/screens/guided_chore_setup_screen.dart`
  - `apps/kinflow_app/lib/features/chores/presentation/screens/one_time_chore_creation_screen.dart`
  - `apps/kinflow_app/lib/features/household/presentation/screens/household_onboarding_screen.dart`
  - `apps/kinflow_app/lib/app/router/auth_route_guard.dart`
  - `apps/kinflow_app/lib/app/router/app_router.dart`
- localization/generated:
  - `apps/kinflow_app/lib/l10n/app_en.arb`
  - `apps/kinflow_app/lib/l10n/app_ko.arb`
  - `apps/kinflow_app/lib/l10n/app_en_XA.arb`
  - `apps/kinflow_app/lib/l10n/app_localizations.dart`
  - `apps/kinflow_app/lib/l10n/app_localizations_en.dart`
  - `apps/kinflow_app/lib/l10n/app_localizations_ko.dart`
- tests/contracts/docs:
  - `apps/kinflow_app/test/features/chores/guided_chore_setup_domain_test.dart`
  - `apps/kinflow_app/test/features/chores/guided_chore_setup_controller_test.dart`
  - `apps/kinflow_app/test/features/chores/guided_chore_setup_widget_test.dart`
  - `apps/kinflow_app/test/features/household/household_onboarding_widget_test.dart`
  - `apps/kinflow_app/test/app/auth_route_guard_test.dart`
  - `docs/contracts/guided-chore-setup.yaml.md`
  - `docs/contracts/chore-templates.yaml.md`
  - `docs/evidence/phase-03/WP03_10_WORKPLAN.md`

## 자동 검증 결과

| 영역 | 실제 명령/검사 | 결과 |
|---|---|---|
| Guided focused | domain/controller 신규 테스트 | PASS, 8 tests |
| Integrated focused | guided + 기존 create/onboarding/router/localization/architecture | PASS, 68 tests |
| Flutter full | `flutter test --no-pub --reporter failures-only` | PASS, 878 tests + opt-in live 1 skip |
| Analyzer | `flutter analyze --no-pub --fatal-infos --fatal-warnings` | PASS, issue 0 |
| Format | `dart format --output=none --set-exit-if-changed lib test tool` | PASS, 531 files / drift 0 |
| Codegen | `dart run tool/verify_codegen.dart` | PASS, 8 generated files / drift 0 |
| Public config | `dart run tool/validate_public_config.dart` | PASS, examples valid/allowlisted |
| Secret scan | `dart run tool/scan_secrets.dart` | PASS, high-confidence finding 0 |
| Contract parse | guided/template fenced YAML exact assertions | PASS, exact 3 + unique IDs + success non-resend + metadata absent |
| Matrix parse | fenced CSV 13개 구조와 declared count | PASS, requirements 116 / tests 65 |
| Whitespace | `git diff --check` | PASS |

처음 public-config와 codegen/secret 검사를 병렬로 실행했을 때 `.dart_tool/lib/objective_c.dylib` native asset codesign 경합으로 public-config process만 실패했다. 설정 validation failure는 아니었고, 다른 Dart process가 끝난 뒤 동일 public-config 명령을 단독 재실행해 `Public configuration examples are valid and allowlisted.`로 통과했다. 최종 결과에는 단독 PASS만 사용한다.

이번 slice에는 DB/API/RLS 변경이 없으므로 Supabase reset/pgTAP을 재실행하지 않았다. 사용하는 `loadToday`와 `createRecurringChore` server 계약은 WP03-05/WP03-09까지의 누적 DB 증거를 그대로 사용하며, 이를 이번 Flutter local flow의 remote/live 완료로 해석하지 않는다.

## 보안·개인정보 영향

- 새 domain catalog content는 기존 generic stable key와 daily/weekly cadence뿐이다.
- template stable key는 in-memory batch identity와 widget key에만 사용하고 request, DB, cache, analytics와 log에 넣지 않는다.
- 저장되는 새 content는 사용자가 확인·수정한 일반 chore title뿐이다. 새 description, 이름, 이메일, household/member identifier telemetry는 없다.
- client active household/member는 routing과 draft 기본값에 쓰지만 authorization authority가 아니다. 기존 server RPC의 active membership, exact household/assignee, entitlement와 recurrence 검증을 우회하지 않는다.
- cached Today snapshot은 mutation start date authority로 사용하지 않는다.
- repository/provider exception과 typed failure는 기존 localized safe message로만 표시하고 raw error/stack을 노출하지 않는다.
- DB/RLS/public config/native permission/dependency/local persistent data surface가 늘지 않았다.

## 수동·실환경 검증

다음은 **NOT RUN / NOT IMPLEMENTED**다.

- 실제 Google 성인 계정과 remote Supabase에서 첫 가구 → guided 3개 생성 → Today 확인
- response-loss, latency와 entitlement limit를 remote 환경에서 발생시킨 partial retry
- 두 기기 Realtime에서 세 series가 중복 없이 보이는지 확인
- process kill/relaunch 후 부분 setup 자동 재개
- Android 물리 기기 keyboard, TalkBack, system font 200%, landscape/tablet와 iOS VoiceOver
- activation completion marker/analytics, invite 결합과 server/household-specific template

로컬 fake repository와 widget test를 실제 사용자·네트워크·기기 완료로 해석하지 않는다. 사용자 지시에 따라 실계정 테스트는 기능 개발이 충분히 끝난 마지막 Gate에 둔다.

## 남은 위험과 완료 경계

1. 세 RPC는 비원자적이다. 현재 route에서는 exact progress/same-key retry가 안전하지만 process death 뒤 앱이 partial setup을 자동 발견·재개하지 않는다.
2. `/onboarding/chores`는 protected이지만 persisted completion marker가 없어 active household 사용자가 내부 route를 다시 열면 추가 세 개를 만들 수 있다. 공개 navigation entry는 없으며 marker 도입은 analytics/privacy 및 resume 정책과 함께 별도 결정한다.
3. quick defaults는 current active adult와 all-day다. 다른 성인 초대·담당 변경은 생성 후 기존 edit/reassign flow에서 수행한다.
4. localized template title은 저장 시 user content가 되므로 이후 locale 변경으로 자동 번역하지 않는다.
5. template 선택/완료 analytics가 없어 activation funnel 운영 지표는 아직 측정하지 않는다. D-051 제품 검증 완료로 표시할 수 없다.
6. 실제 screen reader·keyboard·touch와 remote response-loss 증거가 없어 G3/G7/출시 Gate는 미완료다.

`FR-CHORE-010`의 **첫 가구 exact-three guided local template variant**는 local automated complete다. server/household catalog와 실환경 경계 때문에 요구사항 전체 상태는 `IN_PROGRESS`를 유지한다.

## Rollback

- household 성공 후 destination을 `/today`로 되돌린다.
- guided route/screen/controller/state/domain/provider, 공용 template localization 변경, 신규 ARB와 관련 tests/docs를 제거한다.
- 기존 일반 one-time/repeating create 화면과 API는 그대로 유지한다.
- 이미 guided flow로 생성한 chores는 정상 user data이므로 rollback에서 자동 삭제하지 않는다.
- DB/API migration이 없어 server rollback 또는 data cleanup은 없다.

## 다음 기능 후보

- 실계정 Gate를 계속 마지막에 둔 채, D-051 활성화 흐름의 다음 local 기능은 **첫 세 집안일 완료 후 가족 초대/두 번째 성인 참여 진행 상태**와 **process-death-safe guided setup resume**를 비교한다.
- 다음 slice는 persisted activation state가 필요한지, 기존 server data에서 안전하게 파생할지 먼저 결정하고 analytics/PII 저장을 암묵적으로 추가하지 않는다.
