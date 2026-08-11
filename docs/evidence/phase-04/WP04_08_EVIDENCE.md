# Phase 04 WP04-08 Detailed Today Feed Evidence

- Work Package: WP04-08 — Today의 결정적 5-section feed
- 기준 commit: base `a85f262`; implementation은 2026-08-08 현재 연속 workspace
- 검증일: 2026-08-08
- 환경: macOS arm64, Flutter 3.44.7 stable, Dart 3.12.2
- 결과: **LOCAL AUTOMATED PASS / REMOTE·REAL-ACCOUNT·TWO-DEVICE·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP04-08 / FR-TODAY-001 | PASS FOR LOCAL AUTOMATED SLICE | exact household, timezone, server-local date와 member filter가 일치하는 overdue Chore, Today Chore와 Calendar source를 overdue → now/next → due-today scheduled → remaining → due-today completed 순서로 합성한다. |
| FR-TODAY-001 / NFR-REL-01 | PASS FOR SERVER-AUTHORITATIVE PARTITION | Calendar server `generatedAt`을 기준으로 all-day, `[startsAt, endsAt)` 진행 중 timed event와 가장 이른 future timed event 정확히 1건을 now/next로 분류한다. remaining은 canonical source order를 보존하는 exact complement이며 occurrence 중복이 없다. |
| FR-TODAY-002 | PASS FOR LOCAL FILTER CONTRACT | Everyone/Me 변경은 두 Chore source와 Calendar source에 같은 member filter를 적용하고 pending source가 있는 동안 query race를 막는다. visibility를 확장하지 않는다. |
| FR-TODAY-003 | PASS FOR BOTH CHORE SECTIONS | overdue와 due-today scheduled 항목 모두 기존 optimistic complete, duplicate coalescing, rollback과 authoritative reconciliation을 유지한다. |
| FR-TODAY-004 / FR-TODAY-005 | PASS FOR NEW SOURCE ISOLATION | overdue initial/refresh/action 실패는 다른 ready section을 숨기지 않고 section-local retry와 stale/cache 상태를 사용한다. persistent Calendar cache는 후속 기능으로 남아 있다. |
| NFR-A11Y-01 / NFR-I18N-01 | PASS FOR LOCAL AUTOMATION | 5개 heading과 완료 펼침/접힘 action을 EN/KO/EN-XA ARB로 제공하며 200% pseudo-locale widget 회귀를 통과했다. 실제 screen reader와 기기는 남았다. |

`FR-TODAY-001`의 상세 feed semantics는 local automation을 통과했다. production-size
latency와 hosted/실사용 흐름은 실행하지 않았으므로 요구사항 전체 상태는 `PARTIAL`로
기록한다.

## Composition Contract

- 기본 Chore source는 기존 `get_chore_list(view=today)`, overdue source는 기존
  `get_chore_list(view=overdue)`, Calendar source는 기존 agenda query를 사용한다.
- source envelope의 household ID, household timezone, server-local date와 optional
  member filter가 모두 같아야 합성한다. mismatch source는 fail closed한다.
- now/next는 Calendar envelope의 `generatedAt`만 사용한다. device clock으로 날짜나
  현재/다음 occurrence를 다시 판정하지 않는다.
- all-day event는 now/next에 포함한다. timed event는 half-open interval에 현재가
  포함되거나 아직 시작하지 않은 것 중 canonical order상 첫 1건일 때 포함한다.
- remaining은 now/next에 속하지 않은 모든 occurrence의 stable complement다. 이미
  끝난 오늘 일정도 사라지지 않고 remaining에 남는다.
- completed section은 `view=today`의 due-today completed subset만 포함하며 최초에는
  접혀 있다. 전체 과거 완료 이력은 기존 completed tab에 유지한다.
- normative 계약은 `docs/contracts/today-composition.yaml.md` v2다.

## Client Behavior

- Today 진입, app resume와 Everyone/Me 변경 시 두 Chore query와 Calendar query를
  함께 시작하거나 authoritative refresh한다. non-Today tab은 기존 단일 Chore
  source를 유지한다.
- overdue는 별도 auto-dispose controller/provider가 pagination, refresh와 mutation
  상태를 소유한다. due-today source의 요청이나 action 상태를 덮어쓰지 않는다.
- ready source가 하나라도 있으면 표시 가능한 section을 렌더한다. 다른 source의
  initial/refresh failure는 해당 section에서만 retry한다.
- 완료 heading의 펼치기 action 전에는 완료 card를 만들지 않는다. 접힘 상태는 화면
  lifetime 범위이며 앱 재시작 후 영속화하지 않는다.
- source 오류는 content-free localized copy만 표시하고 raw provider exception,
  occurrence title, participant 또는 assignee material을 포함하지 않는다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| focused Today domain/provider/widget | PASS, 23/23 |
| existing Chore widget regression | PASS, 23/23 |
| full Flutter regression | PASS, 834 tests + local-connectivity real-environment opt-in 1 skip |
| exact analyzer | PASS, issue 0 (`--no-pub --fatal-infos --fatal-warnings`) |
| exact formatter | PASS, 517 files / changed 0 |
| public config | PASS, exact public allowlist |
| secret scan | PASS, high-confidence finding 0 |
| localization/codegen drift | PASS, generated localizations current; 8 generated files verified; build runner wrote 0 outputs |
| repository CI contracts | PASS, Node CI 134/134; workflow contract 5 jobs and 17 pinned action uses |
| whitespace | PASS, `git diff --check` output 0 |
| database regression | **NOT RUN BY DESIGN**; migration, DB object와 RPC signature 변경이 없어 WP04-07의 47 files / 2,422 pgTAP full baseline에 의존 |

실행한 핵심 명령은 다음과 같다.

```text
flutter test test/features/chores/today_overdue_provider_test.dart test/features/today
flutter test test/features/chores/one_time_chore_widget_test.dart
flutter test --reporter compact
flutter analyze --no-pub --fatal-infos --fatal-warnings
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/validate_public_config.dart
dart run tool/scan_secrets.dart
dart run tool/verify_codegen.dart
npm run ci:test
npm run ci:workflow
git diff --check
```

## Files and Data Impact

- Domain: `apps/kinflow_app/lib/features/today/domain/entities/today_snapshot.dart`
- Providers: `apps/kinflow_app/lib/features/chores/presentation/providers/chore_providers.dart`
- UI: `apps/kinflow_app/lib/features/chores/presentation/screens/today_chores_screen.dart`,
  `apps/kinflow_app/lib/features/today/presentation/widgets/today_calendar_section.dart`
- Localization: EN/KO/EN-XA ARB와 generated localizations
- Tests: Today domain/composition widgets, overdue provider와 기존 Chore widget regression
- Contract/tracking: Today composition v2, workplan, Phase 04, requirement/test matrices,
  changelog와 이 evidence

새 migration, table, index, RPC signature, runtime package, persistent storage,
analytics/log event 또는 native permission을 추가하지 않았다.

## Security, Privacy, and Data

- 세 source는 기존 authenticated household membership/RLS와 active-member projection을
  그대로 사용한다. Me filter는 이미 읽을 수 있는 row를 좁힐 뿐이다.
- independent source context가 다르면 해당 source를 합성하지 않는다. 다른 household,
  timezone, local date 또는 member-filter content가 화면에 섞이지 않는다.
- 요청과 상태에 새 title, description, participant, assignee, auth identity 또는 token
  logging을 추가하지 않았다.
- 자동 검증은 fake/synthetic content만 사용했으며 production project, 실제 계정,
  token 또는 고객 데이터에 접근하지 않았다.

## Manual and Deferred Validation

사용자 지시에 따라 다음 항목은 **NOT RUN / 마지막 통합 Gate**로 유지한다.

- 실제 Google/Supabase 성인 계정에서 Today 5구간과 권한변경 race
- 두 계정·두 기기의 동시 complete와 source refresh propagation
- hosted production-size household의 supplemental overdue RPC 비용과 p75/p95
- 실제 Android의 TalkBack, 200% font, keyboard, phone/tablet/split layout
- background/resume, DST 자정과 device timezone travel의 실제 흐름
- remote network loss/throttle 및 long-lived Realtime reconnect

## Remaining Risks and Completion Boundary

1. Today 화면은 기존 두 source에 overdue Chore RPC를 하나 더 호출한다. local bounded
   tests는 통과했지만 production cardinality와 p75 latency를 측정하지 않았다.
2. 독립 query의 server envelope가 자정 경계를 사이에 둘 수 있다. exact local-date
   mismatch인 supplemental source는 섞지 않고 fail closed하므로 잘못된 항목 대신
   section omission/retry가 발생할 수 있다.
3. Calendar page cap과 기존 backend pagination 범위를 넘어선 초대형 하루 데이터는
   production-size test 전까지 완전성·성능 완료 근거가 아니다.
4. completed 펼침 상태는 화면 lifetime에서만 유지한다. 영속 사용자 환경 설정이 아니다.
5. Calendar는 아직 Android 영속 offline first-page cache가 없어 process restart 후에는
   Chore만 stale snapshot을 복원할 수 있다.
6. 따라서 WP04-08 local automated slice만 완료하며 Phase 04, release gate와 장기 기능
   목표는 `PARTIAL/IN_PROGRESS`를 유지한다.

## Rollback

- Today 5-section domain/provider/widget/l10n/tests와 composition contract v2를 함께
  revert하면 WP04-05의 Calendar → Chore 합성 화면으로 돌아간다.
- DB migration과 persisted data 변경이 없어 data rollback은 없다.
- 운영 중 supplemental overdue query 비용이 문제가 되면 overdue provider/section만
  제거해도 기존 Today Chore·Calendar query와 mutations는 독립적으로 동작한다.

## Next Entry Condition

- 다음 기능 우선순위는 `FR-TODAY-004`의 Today Calendar persistent offline first-page
  cache다. 기존 Android encrypted fixed-slot cache와 exact session/household/query
  scope를 재사용하고 Calendar schedule content를 plaintext storage나 log에 남기지
  않아야 한다.
- cached Calendar는 stale/read-only 이유와 마지막 성공 시각을 표시하고 refresh 전
  mutation·filter·pagination을 안전하게 제한해야 한다. source context mismatch는
  복원하지 않는다.
- 실계정·remote·두 기기·실기기 검증은 사용자 지시에 따라 기능 개발 뒤 마지막
  gate에 계속 유지한다.
