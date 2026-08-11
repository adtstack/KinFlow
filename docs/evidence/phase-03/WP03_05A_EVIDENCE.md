# Phase 03 WP03-05A Repeating Chore Creation Evidence

- Work Package: WP03-05A — canonical recurrence creation and bounded initial materialization
- 기준 commit: base `a85f262`; implementation은 2026-08-07 현재 WP02-06/WP03-04 연속 workspace
- 검증일: 2026-08-07
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 29.6.2
- 결과: **LOCAL AUTOMATED PASS / REAL-ACCOUNT·TWO-DEVICE LIVE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP03-05A | PASS FOR LOCAL AUTOMATED SLICE | canonical rule 검증, repeating create transaction, 시작일 포함 최대 366일 initial materialization, 앱 생성 surface와 Today 반복 표시를 연결했다. |
| FR-CHORE-005 | PARTIAL | 서버는 daily/weekly/monthly, interval 1~30, never/count/until을 strict하게 검증한다. 앱은 시작일에 anchor된 interval 1·never의 daily/weekly/monthly만 안전하게 노출한다. custom rule UI와 edit는 남아 있다. |
| FR-CHORE-006 | PARTIAL | 생성 시 bounded window를 물질화하고 series+local-date stable key와 conflict-ignore로 재실행을 안전하게 한다. periodic horizon extension/repair worker는 후속 slice다. |
| D-019 | PASS FOR NEW SURFACE | series identity, immutable revision definition, occurrence state를 분리했고 한 occurrence 완료가 다음 occurrence와 recurrence rule을 바꾸지 않음을 검증했다. |
| D-020 | EXPLICITLY DEFERRED | 이번 회차 예외와 future-series revision은 잘못된 overwrite를 피하기 위해 UI/API를 열지 않았다. |
| D-048/NFR-REL-01 | PASS FOR REPEATING CREATE | 동일 user+command UUID의 normalized same-input replay는 최초 결과를 반환하고 다른 input은 거부한다. materializer 재실행은 중복 occurrence를 만들지 않는다. |
| NFR-SEC-01 | PASS FOR NEW SURFACE | caller/household/assignee는 JWT와 active membership에서 검증하며 outsider, removed member, direct mutation과 private helper/state 접근을 거부한다. |

## Implementation

- `20260807000000_repeating_chore_materialization.sql`은 one-time 호환을 유지하는 canonical JSON validator와 validated revision constraint를 추가한다.
- private materializer는 시작 local date에서 요청 horizon까지 daily/weekly/monthly 날짜를 계산한다. monthly의 존재하지 않는 day는 clamp하지 않고 건너뛰며, timed occurrence는 household IANA timezone에서 UTC instant로 변환한다.
- `create_repeating_chore`는 JWT caller와 active household/assignee를 서버에서 검증한 뒤 series, revision, 최대 366개 occurrence, 최소 idempotency result와 content-free event를 한 transaction으로 기록한다.
- occurrence key는 generated series UUID와 ISO local date로 고정하고 conflict-ignore를 사용한다. 동일 command replay는 같은 series/first occurrence/materialization summary를 반환한다.
- 기존 `get_today_chores`는 N-1 호환을 위해 유지한다. 새 `get_today_chores_v2`만 allowlisted recurrence frequency를 추가하며 one-time row는 null을 반환한다.
- Flutter domain/application은 Flutter, Riverpod와 Supabase SDK에 독립적이다. adapter와 repository는 exact response shape, household/rule binding, UUID/date/count/window를 fail-closed로 검증한다.
- 생성 화면은 반복 안 함/매일/매주/매월을 제공하고 선택한 첫 due date에 weekly weekday 또는 monthly day를 anchor한다. 성공 후 optimistic 가짜 row 대신 Today를 다시 읽는다.
- Today card는 반복 occurrence에만 localized frequency label을 표시하며 기존 one-time과 complete/reopen 동작을 유지한다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean `npx supabase db reset` | PASS, ordered forward migration 8개와 synthetic seed 적용 |
| DB schema lint | PASS, `public,app_private` warning/error 0 |
| pgTAP/RLS | PASS, 신규 recurrence 64 + predecessor 388 = 452 tests |
| focused Flutter recurrence suite | PASS, domain/controller/repository/adapter/widget/adaptive 44 tests |
| full Flutter regression | PASS, 243 tests + local-connectivity opt-in 1 skip |
| exact formatter/analyzer | PASS, quality scope 213 files changed 0; analyzer issue 0 |
| repository CI self-test/workflow | PASS, 47/47; 5 jobs, pinned action 17개, `contents:read` |
| config/secret/codegen | PASS, public config allowlist, high-confidence secret 0, generated output drift 0 |
| coverage | PASS, 4,092 / 5,443 lines = 75.18% |
| local HTTP/Flutter Supabase smoke | PASS, health contract와 opt-in Flutter adapter 1/1 |
| whitespace | PASS, `git diff --check` output 0 |

pgTAP fixture는 strict validator, fresh constraint, grant, daily 366일, weekly multi-day, monthly day-31 skip, never/count/until, all-day/timed UTC, command/materializer replay, Today v1/v2 호환, completion isolation, outsider/removed member/direct write denial과 private-state 최소화를 포함한다.

## Data / API / Privacy

- 검증은 fresh local Supabase와 deterministic synthetic UUID/텍스트만 사용했다. production migration, 실제 계정, 실제 household와 고객 콘텐츠는 사용하지 않았다.
- private repeating command table은 request SHA-256, generated IDs, canonical schedule rule, 마지막 materialized date와 count만 저장한다. title, notes, display name, email, token과 JWT는 저장하지 않는다.
- domain event에는 allowlisted event name, generated aggregate/actor/correlation IDs와 version만 기록한다. recurrence payload와 자유형 콘텐츠를 넣지 않는다.
- authenticated client는 public security-definer RPC만 실행할 수 있고 private validator/materializer/idempotency table 및 chore table direct mutation 권한은 없다.
- 새 runtime dependency, Android/iOS permission, analytics event, persistent local cache와 offline outbox를 추가하지 않았다.
- 로컬 Supabase stack은 DB와 adapter 검증 후 중지했다.

## Manual / Deferred Validation

- 사용자 지시에 따라 실제 Google 성인 계정 2개와 Android 기기 2대의 recurring create → 양쪽 Today 확인 → 서로 다른 회차 완료는 **NOT RUN**이며 기능 개발이 끝난 뒤 마지막 gate에서 수행한다.
- production Supabase deploy, remote migration smoke, backup/restore, forward rollback과 production-size query/repair rehearsal은 **NOT RUN**이다.
- DST gap/fold의 최종 제품 정책, 실제 timezone boundary 기기 fixture와 여행/device-timezone preview는 Phase 04 dependency gate까지 **NOT RUN**이다.
- custom interval/end/multiple-weekday UI, process death, offline/reconnect, Realtime/resume와 representative-device performance는 **NOT RUN**이다.

## Remaining Risks / Completion Boundary

1. initial occurrence window는 시작일부터 최대 365일 뒤까지다. periodic horizon extension/repair가 없으므로 장기 series는 이 경계 이후 자동 확장되지 않는다.
2. 한 회차 skip/reschedule/reassign와 future-series edit/cancel이 없다. 기존 occurrence나 완료 history를 overwrite하지 않는 revision/exception 계약이 필요하다.
3. timed recurrence는 PostgreSQL IANA 변환을 사용하지만 DST gap/fold 사용자 의미는 아직 확정하지 않았다.
4. 앱은 interval 1·never·single anchored weekday/day만 생성한다. 서버의 interval/count/until/multiple-weekday subset은 후속 UI 전까지 API 계약으로만 존재한다.
5. local automated slice는 green이지만 real-account/two-device evidence가 없으므로 WP03-05 전체와 Chores Value Gate를 완료로 표시하지 않는다.

## Rollback

- production 적용 전에는 WP03-05A Flutter repeat selector/Today label과 migration을 revert하고 clean reset으로 one-time create/complete 흐름을 확인한다.
- production 적용 후에는 적용된 migration을 수정·삭제하지 않는다. `create_repeating_chore`와 `get_today_chores_v2` execute grant를 먼저 회수하고 validator/materializer/schema를 교정하는 forward migration을 추가한다.
- UI-only rollback은 반복 selector를 숨겨 one-time create만 유지하고 Today v1-compatible data는 그대로 보존한다.

## Next Entry Condition

- 다음 기능 우선순위는 별도 work plan을 만든 뒤 WP03-05B의 periodic horizon extension/repair 또는 single-occurrence/future-series revision 중 가장 작은 vertical slice로 진행한다.
- 그 slice도 stable occurrence identity, 과거 완료 history 보존, household-local semantics와 replay safety를 먼저 고정한다.
- 실제 계정·두 기기 gate는 사용자 지시에 따라 기능 개발이 끝난 마지막 단계까지 유지한다.
