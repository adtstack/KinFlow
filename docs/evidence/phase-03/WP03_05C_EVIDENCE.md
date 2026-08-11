# Phase 03 WP03-05C Skipped-Occurrence Immediate Restore Evidence

- Work Package: WP03-05C — versioned immediate restore of the most recently skipped occurrence
- 기준 commit: base `a85f262`; implementation은 2026-08-07 현재 WP02-06/WP03-04/WP03-05A/WP03-05B 연속 workspace
- 검증일: 2026-08-07
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 29.6.2
- 결과: **LOCAL AUTOMATED PASS / REAL-ACCOUNT·TWO-DEVICE LIVE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP03-05C | PASS FOR LOCAL AUTOMATED SLICE | 방금 건너뛴 materialized repeating occurrence를 `skipped → scheduled`로 복구하고 원래 Today 위치에 되돌리는 서버·Flutter vertical slice를 연결했다. |
| FR-CHORE-007 | PARTIAL | 한 회차 skip과 즉시 Undo, 권한, version/idempotency와 audit를 구현했다. reschedule/reassign와 persistent 과거 skip 복구는 후속 slice다. |
| D-020 | PARTIAL | 선택한 이번 회차의 상태만 되돌리고 series/revision, assignee와 sibling occurrence를 변경하지 않는다. |
| D-048/NFR-REL-01 | PASS FOR RESTORE COMMAND | skipped version과 user-scoped command UUID를 함께 검증한다. 같은 입력 replay는 최초 scheduled version을 반환하고 다른 입력 재사용은 거부한다. |
| NFR-SEC-01 | PASS FOR NEW SURFACE | Owner/Admin, 자기 담당 Member, 비담당 Member, outsider와 removed member 권한 경계를 DB에서 계산하고 direct mutation/private state 접근을 차단했다. |

## Implementation

- `20260807020000_chore_occurrence_restore.sql`은 content-free private idempotency result와 authenticated-only `restore_skipped_chore_occurrence` security-definer RPC를 추가한다.
- RPC는 JWT user와 active membership을 DB에서 다시 읽는다. Owner/Admin은 같은 household occurrence를, Member는 `IS DISTINCT FROM`으로 비교한 자기 담당 occurrence만 복구할 수 있다.
- 대상은 canonical repeating revision에 속한 `skipped` occurrence여야 한다. one-time, scheduled, completed/cancelled와 stale version은 mutation 전에 거부한다.
- 성공 transaction은 occurrence를 `scheduled`로 바꾸고 version을 정확히 1 증가시키며 completion actor/time을 null로 유지한다. 기존 append-only audit allowlist를 확장하지 않고 `reopened` event를 한 번 추가해 직전 `skipped` event/version과 함께 복구 의미를 표현한다.
- 동일 user+command UUID의 동일 요청은 version/audit를 다시 증가시키지 않는다. series, revision, recurrence rule, assignee, sibling occurrence와 과거 audit는 보존되며 materializer replay도 복구된 stable occurrence를 덮어쓰지 않는다.
- Flutter domain/application은 SDK와 UI에 독립적인 restore draft/request/snapshot을 사용한다. adapter/repository는 exact payload shape, household/occurrence binding, literal `scheduled`와 `expectedVersion + 1`을 fail-closed로 확인한다.
- skip 성공 시 제거 전 occurrence, 원래 index와 서버 skipped version을 메모리의 단일 Undo token으로 보존한다. Undo는 원래 위치에 optimistic하게 다시 넣고 성공 version을 reconcile하며, retryable failure는 같은 command UUID로 다시 시도한다.
- stale/invalid restore는 authoritative Today를 다시 읽는다. scheduled row가 이미 보이면 목표 달성으로 처리하고, 아니면 만료된 Undo token을 폐기한다.
- EN/KO/pseudo-locale 문구를 추가했다. 320×568dp·200% text에서도 skip dialog 전체와 긴 Undo 라벨을 스크롤/줄바꿈할 수 있고 확인·Undo 동작 영역이 최소 48dp임을 검증했다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean `npx supabase db reset` | PASS, ordered forward migration 10개와 synthetic seed 적용 |
| DB schema lint | PASS, `public,app_private` warning/error 0 |
| focused restore pgTAP | PASS, 55/55 |
| full pgTAP/RLS regression | PASS, 신규 restore 55 + predecessor 501 = 556 tests, 10 files |
| focused Flutter restore suite | PASS, domain/repository/adapter/controller/widget/adaptive 65 tests |
| full Flutter regression | PASS, 264 tests + local-connectivity opt-in 1 skip |
| exact formatter/analyzer | PASS, quality scope 215 files changed 0; analyzer issue 0 |
| repository CI self-test/workflow | PASS, 47/47; 5 jobs, pinned action 17개, `contents:read` |
| config/secret/codegen | PASS, public config allowlist, high-confidence secret 0, generated output drift 0 |
| coverage | PASS, 4,465 / 5,836 lines = 76.51% |
| local Edge/Flutter Supabase smoke | PASS, health contract와 Flutter adapter 각각 통과 |
| whitespace | PASS, `git diff --check` output 0 |

pgTAP fixture는 strict schema/grant, authenticated-only RPC, baseline audit vocabulary, assigned Member/Owner/Admin success, 비담당 Member/outsider/removed member denial, stale/idempotency/transition failure, exact version/audit history, Today 재등장, sibling/series/revision isolation, materializer replay, one-time/completed/scheduled 거부와 direct-write/private-read denial을 포함한다.

## Data / API / Privacy

- 검증은 fresh local Supabase와 deterministic synthetic UUID/텍스트만 사용했다. production migration, 실제 계정, 실제 household와 고객 콘텐츠는 사용하지 않았다.
- private restore command table은 user/household/occurrence/event IDs, request SHA-256, result version과 생성 시각만 저장한다. chore title, description, display name, email, token과 JWT를 저장하지 않는다.
- audit에는 allowlisted event type과 generated actor/aggregate/correlation IDs 및 occurrence version만 기록한다. recurrence payload와 자유형 콘텐츠를 넣지 않는다.
- authenticated client는 public RPC만 실행할 수 있고 occurrence/audit table direct mutation과 private command state 읽기·쓰기는 허용되지 않는다.
- Undo token은 메모리에만 있고 앱 재시작 뒤 보존되지 않는다. 새 runtime dependency, Android/iOS permission, analytics event, persistent local cache와 offline outbox를 추가하지 않았다.
- 검증용 local Supabase stack은 최종 DB/adapter smoke 이후 중지했다.

## Manual / Deferred Validation

- 사용자 지시에 따라 실제 Google 성인 계정 2개와 Android 기기 2대에서 skip → Undo → 양쪽 Today 반영을 확인하는 검증은 **NOT RUN**이며 기능 개발 완료 후 마지막 gate에서 수행한다.
- production Supabase deploy, remote migration smoke, backup/restore와 forward rollback rehearsal은 **NOT RUN**이다.
- offline/reconnect, process death, Realtime/resume, simultaneous two-client race와 representative-device performance는 **NOT RUN**이다.
- 앱 재시작 뒤 과거 skip을 찾는 history/detail 복구 UI, 여러 Undo queue, 한 회차 reschedule/reassign, future-series edit/cancel과 periodic horizon extension/repair worker는 이번 slice 범위가 아니다.

## Remaining Risks / Completion Boundary

1. Undo는 방금 성공한 skip 한 건만 메모리에 보존한다. Snackbar dismissal 또는 process death 뒤에는 skipped history/detail에서 복구할 앱 surface가 없다.
2. 한 회차 reschedule/reassign와 전체 future-series revision이 없으므로 FR-CHORE-007과 WP03-05 전체는 완료가 아니다.
3. initial materialization window 뒤의 회차를 만드는 periodic horizon extension/repair가 아직 없다.
4. 로컬 transaction/concurrency 검증은 통과했지만 실제 두 client의 전달 지연·재시도·동기화 경험은 마지막 실계정 gate 전까지 미확정이다.
5. 복구 audit는 baseline `reopened`를 재사용하므로 downstream history/analytics는 직전 `skipped` event와 occurrence version sequence로 completion reopen과 구분해야 한다. 앱에는 아직 audit history 화면이 없다.

## Rollback

- production 적용 전에는 WP03-05C restore domain/UI wiring과 migration을 revert하고 clean reset으로 create/complete/reopen/recurrence/skip 흐름을 확인한다.
- production 적용 후에는 적용된 migration을 수정·삭제하지 않는다. `restore_skipped_chore_occurrence` execute grant를 먼저 회수하고 권한/transition/audit를 교정하는 forward migration을 추가한다.
- UI-only rollback은 Undo action을 숨기고 기존 Today read, create, complete/reopen과 skip을 유지한다. 이미 복구된 occurrence와 append-only audit는 보존한다.

## Next Entry Condition

- 다음 기능 우선순위는 한 회차 reschedule을 series/revision과 기존 audit를 오염시키지 않는 versioned exception으로 추가하는 bounded slice다. reassign과 persistent exception history는 그 다음 후보로 둔다.
- 장기 반복 안정성을 위해 periodic horizon extension/repair worker도 WP03-05 완료 전에 별도 bounded slice로 구현한다.
- 실제 계정·두 기기 gate는 사용자 지시에 따라 기능 개발이 끝난 마지막 단계까지 유지한다.
