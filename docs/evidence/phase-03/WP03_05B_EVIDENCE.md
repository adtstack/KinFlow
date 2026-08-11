# Phase 03 WP03-05B Single-Occurrence Skip Evidence

- Work Package: WP03-05B — versioned single-occurrence skip
- 기준 commit: base `a85f262`; implementation은 2026-08-07 현재 WP02-06/WP03-04/WP03-05A 연속 workspace
- 검증일: 2026-08-07
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 29.6.2
- 결과: **LOCAL AUTOMATED PASS / REAL-ACCOUNT·TWO-DEVICE LIVE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP03-05B | PASS FOR LOCAL AUTOMATED SLICE | materialized repeating occurrence 하나를 `scheduled → skipped`로 전이하고 Today에서 제거하는 서버·Flutter vertical slice를 연결했다. |
| FR-CHORE-007 | PARTIAL | 한 회차 skip, 권한, version/idempotency와 audit는 구현했다. reschedule/reassign/restore는 후속 slice다. |
| D-020 | PARTIAL | “이번 회차” 예외 범위만 열었고 series/revision 또는 미래 회차 편집 API는 열지 않았다. |
| D-048/NFR-REL-01 | PASS FOR SKIP COMMAND | expected version과 user-scoped command UUID를 함께 검증한다. 동일 입력 replay는 최초 version을 반환하고 다른 입력 재사용은 거부한다. |
| NFR-SEC-01 | PASS FOR NEW SURFACE | Owner/Admin, 자기 담당 Member, 비담당 Member, outsider와 removed member 권한 경계를 DB에서 계산하고 direct mutation/private state 접근을 차단했다. |

## Implementation

- `20260807010000_chore_occurrence_skip.sql`은 기존 append-only occurrence audit에 `skipped` event를 추가하고, content-free private idempotency result와 `skip_chore_occurrence` security-definer RPC를 추가한다.
- RPC는 JWT user와 active membership을 DB에서 다시 읽는다. Owner/Admin은 같은 household occurrence를, Member는 `IS DISTINCT FROM`으로 비교한 자기 담당 occurrence만 변경할 수 있다.
- 대상은 canonical repeating revision에 속한 `scheduled` occurrence여야 한다. one-time, completed, skipped/cancelled와 stale version은 mutation 전에 거부한다.
- 성공 transaction은 대상 occurrence의 status/version만 변경하고 completion actor/time 필드는 비운 채 `skipped` audit와 command result를 한 번 기록한다.
- series, revision, recurrence rule과 sibling occurrence는 변경하지 않는다. stable occurrence key를 재사용하는 materializer replay도 skipped row를 덮어쓰지 않는다.
- Today v2는 기존대로 scheduled/completed만 반환하므로 skip된 회차가 즉시 목록에서 사라진다.
- Flutter domain/application은 SDK와 UI에 독립적인 versioned skip draft/request/snapshot을 사용한다. adapter/repository는 exact payload shape, household/occurrence binding, literal `skipped`와 `expectedVersion + 1`을 fail-closed로 확인한다.
- Today는 scheduled repeating row에만 메뉴를 노출하고 scope 설명 dialog를 거친다. pending 중 중복 동작을 합치며, 성공 시 대상만 제거하고 실패 시 동일 command UUID 재시도 또는 authoritative reload를 수행한다.
- EN/KO/pseudo-locale 문구와 320dp·200% text에서 완료/메뉴 각각 최소 48dp 동작 영역을 검증했다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean `npx supabase db reset` | PASS, ordered forward migration 9개와 synthetic seed 적용 |
| DB schema lint | PASS, `public,app_private` warning/error 0 |
| focused skip pgTAP | PASS, 49/49 |
| full pgTAP/RLS regression | PASS, 신규 skip 49 + predecessor 452 = 501 tests |
| focused Flutter skip suite | PASS, domain/repository/adapter/controller/widget/adaptive 55 tests |
| full Flutter regression | PASS, 254 tests + local-connectivity opt-in 1 skip |
| exact formatter/analyzer | PASS, quality scope 214 files changed 0; analyzer issue 0 |
| repository CI self-test/workflow | PASS, 47/47; 5 jobs, pinned action 17개, `contents:read` |
| config/secret/codegen | PASS, public config allowlist, high-confidence secret 0, generated output drift 0 |
| coverage | PASS, 4,242 / 5,623 lines = 75.44% |
| local Flutter/Supabase smoke | PASS, health adapter 1/1 |
| whitespace | PASS, `git diff --check` output 0 |

pgTAP fixture는 strict schema/grant, authenticated-only RPC, explicit assignee invariant, assigned Member/Owner/Admin success, 비담당 Member/outsider/removed member denial, stale/idempotency/transition failure, exact version/audit, Today exclusion, sibling/series/revision/history isolation, materializer replay와 direct-write/private-read denial을 포함한다.

## Data / API / Privacy

- 검증은 fresh local Supabase와 deterministic synthetic UUID/텍스트만 사용했다. production migration, 실제 계정, 실제 household와 고객 콘텐츠는 사용하지 않았다.
- private skip command table은 user/household/occurrence/event IDs, request SHA-256, result version과 생성 시각만 저장한다. chore title, description, display name, email, token과 JWT를 저장하지 않는다.
- audit에는 allowlisted event type과 generated actor/aggregate/correlation IDs 및 occurrence version만 기록한다. recurrence payload와 자유형 콘텐츠를 넣지 않는다.
- authenticated client는 public RPC만 실행할 수 있고 occurrence/audit table direct mutation과 private command state 읽기·쓰기는 허용되지 않는다.
- 새 runtime dependency, Android/iOS permission, analytics event, persistent local cache와 offline outbox를 추가하지 않았다.
- 검증용 local Supabase stack은 최종 DB/adapter smoke 이후 중지했다.

## Manual / Deferred Validation

- 사용자 지시에 따라 실제 Google 성인 계정 2개와 Android 기기 2대에서 상대 담당 반복 회차 skip → 양쪽 Today 반영을 확인하는 검증은 **NOT RUN**이며 기능 개발 완료 후 마지막 gate에서 수행한다.
- production Supabase deploy, remote migration smoke, backup/restore와 forward rollback rehearsal은 **NOT RUN**이다.
- offline/reconnect, process death, Realtime/resume, simultaneous two-client race와 representative-device performance는 **NOT RUN**이다.
- reschedule/reassign/restore UI, future-series edit/cancel과 periodic horizon extension/repair worker는 이번 slice 범위가 아니다.

## Remaining Risks / Completion Boundary

1. skip은 현재 앱에서 복구할 수 없다. 잘못 건너뛴 회차의 restore/unskip 계약과 UI가 필요하다.
2. 한 회차 reschedule/reassign와 전체 future-series revision이 없으므로 FR-CHORE-007과 WP03-05 전체는 완료가 아니다.
3. initial materialization window 뒤의 회차를 만드는 periodic horizon extension/repair가 아직 없다.
4. 로컬 transaction/concurrency 검증은 통과했지만 실제 두 client의 전달 지연·재시도·동기화 경험은 마지막 실계정 gate 전까지 미확정이다.
5. skipped 회차는 Today에서 제외되지만 별도 history/detail 화면이 없어 사용자가 앱에서 audit를 조회할 수 없다.

## Rollback

- production 적용 전에는 WP03-05B skip 메뉴/domain wiring과 migration을 revert하고 clean reset으로 create/complete/reopen/recurrence 흐름을 확인한다.
- production 적용 후에는 적용된 migration을 수정·삭제하지 않는다. `skip_chore_occurrence` execute grant를 먼저 회수하고 권한/transition/audit를 교정하는 forward migration을 추가한다.
- UI-only rollback은 skip 메뉴를 숨기고 Today read, complete/reopen과 recurrence create 기능을 유지한다. 이미 skipped 상태인 row와 append-only audit는 보존한다.

## Next Entry Condition

- 다음 기능 slice는 별도 work plan에서 single-occurrence reschedule/reassign/restore 중 하나를 version/history 보존 계약과 함께 선택한다.
- 장기 반복 안정성을 위해 periodic horizon extension/repair worker도 WP03-05 완료 전에 별도 bounded slice로 구현한다.
- 실제 계정·두 기기 gate는 사용자 지시에 따라 기능 개발이 끝난 마지막 단계까지 유지한다.
