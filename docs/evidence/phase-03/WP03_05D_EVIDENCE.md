# Phase 03 WP03-05D Single-Occurrence Reschedule Evidence

- Work Package: WP03-05D — versioned date/time reschedule for one repeating occurrence
- 기준 commit: base `a85f262`; implementation은 2026-08-07 현재 WP02-06/WP03-04/WP03-05A/WP03-05B/WP03-05C 연속 workspace
- 검증일: 2026-08-07
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 29.6.2
- 결과: **LOCAL AUTOMATED PASS / REAL-ACCOUNT·TWO-DEVICE LIVE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP03-05D | PASS FOR LOCAL AUTOMATED SLICE | materialized repeating occurrence 한 건의 effective local date/time만 변경하고 Today 제거·재정렬까지 연결했다. |
| FR-CHORE-007 | PARTIAL | skip/restore에 이어 single-occurrence reschedule을 구현했다. reassign와 persistent exception history는 후속 slice다. |
| D-019 | PASS FOR NEW SURFACE | canonical series/revision 정의와 occurrence의 effective schedule override를 분리하고 materializer replay가 override를 덮지 않음을 검증했다. |
| D-020 | PARTIAL | “이번 회차”의 date/time만 변경한다. future-series revision/edit와 reassign는 열지 않았다. |
| D-048/NFR-REL-01 | PASS FOR RESCHEDULE COMMAND | expected occurrence version과 user-scoped command UUID로 stale write, retry와 duplicate audit/version 증가를 차단했다. |
| NFR-SEC-01 | PASS FOR NEW SURFACE | Owner/Admin, 자기 담당 Member, 비담당 Member, outsider와 removed member 경계를 DB에서 계산하고 direct/private mutation을 차단했다. |

## Implementation

- `20260807030000_chore_occurrence_reschedule.sql`은 authenticated-only `reschedule_chore_occurrence` security-definer RPC, private idempotency result와 별도 immutable `chore_reschedule_events`를 추가한다.
- RPC는 JWT user와 active membership, 현재 role, occurrence assignee를 DB에서 다시 읽는다. Owner/Admin은 같은 household occurrence를, Member는 자기 담당 occurrence만 변경할 수 있다.
- 대상은 canonical repeating revision의 `scheduled` occurrence여야 한다. one-time, completed, skipped/cancelled, stale version, non-minute time과 현재와 같은 schedule은 mutation 전에 거부한다.
- 성공 transaction은 effective `due_local_date`와 `due_at` 및 trigger-managed version/timestamp만 변경한다. stable `occurrence_key`, status, assignee, completion fields, series/revision과 sibling occurrence는 보존한다.
- timed schedule은 occurrence가 보유한 IANA timezone으로 local date/time을 UTC instant로 변환한다. all-day는 `due_at`을 null로 유지한다.
- 동일 user+command UUID의 동일 normalized input은 최초 schedule/version과 `changed=false`를 반환한다. 다른 input 재사용은 거부하며 version과 audit는 한 번만 증가한다.
- 별도 reschedule audit는 이전/새 date/time/UTC instant, generated actor·occurrence·correlation IDs와 occurrence version만 append한다. completion audit vocabulary와 completion history는 변경하지 않는다.
- `get_today_chores_v2`는 immutable revision time이 아니라 occurrence의 effective `due_at`에서 local time을 계산한다. 다른 날짜로 이동한 row는 Today에서 빠지고, 같은 날짜 변경과 timed→all-day가 새 schedule로 표시된다.
- Flutter는 SDK/UI 독립적인 reschedule draft/request/snapshot을 사용한다. Supabase adapter와 repository는 exact response shape/type, request household/occurrence/date/time binding, literal `scheduled`, UTC parity와 `expectedVersion + 1`을 fail-closed로 검증한다.
- Today controller는 다른 날짜 이동을 즉시 제거하고 같은 날짜 변경을 effective local time, title, ID로 재정렬한다. pending duplicate action을 합치고 retryable failure에는 원본 row와 동일 command UUID를 재사용하며 stale/invalid transition에는 authoritative Today를 다시 읽는다.
- 구현 중 optimistic 새 시각의 임시 UTC 표현과 기존 서버 UTC instant를 직접 비교하면 timezone offset 때문에 순서가 뒤집히는 결함을 집중 테스트가 발견했다. 같은 household local date의 정렬을 normalized local time으로 통일해 서버 순서와 동치가 되도록 교정했다.
- scheduled repeating row 메뉴에 localized reschedule dialog를 추가했다. 날짜, optional time/all-day를 편집하고 no-op 제출을 막으며 성공을 SnackBar로 알린다. one-time/completed row에는 메뉴가 노출되지 않는다.
- dialog와 2항목 popup은 320×568dp, 200% text, KO/pseudo locale에서 스크롤 가능하고 cancel/confirm/기존 skip/Undo action은 최소 48dp임을 검증했다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean `npx supabase db reset` | PASS, ordered forward migration 11개와 synthetic seed 적용 |
| DB schema lint | PASS, `app_private`, `extensions`, `public` warning/error 0 |
| focused reschedule pgTAP | PASS, 61/61 |
| full pgTAP/RLS regression | PASS, 신규 reschedule 61 + predecessor 556 = 617 tests, 11 files |
| focused Flutter domain/boundary/controller | PASS, 59 tests |
| focused Flutter widget/adaptive | PASS, 18 tests; KO/pseudo 200% text 포함 |
| full Flutter regression | PASS, 276 tests + local-connectivity opt-in 1 skip |
| exact formatter/analyzer | PASS, quality scope 216 files changed 0; analyzer issue 0 |
| repository CI self-test/workflow | PASS, 47/47; 5 jobs, pinned action 17개, `contents:read` |
| Edge/backend regression | PASS, invite 22/22, member lifecycle 18/18, health, invite live와 Flutter local adapter |
| config/secret/codegen | PASS, public config allowlist, high-confidence secret 0, generated output drift 0/8 files |
| coverage | PASS, 4,733 / 6,132 lines = 77.19% |
| whitespace | PASS, `git diff --check` output 0 |

pgTAP fixture는 strict schema/grant/content minimization, minute precision, assigned Member/Owner/Admin success, 비담당 Member/outsider/removed member denial, timed→timed, timed→all-day, date move, stale/no-op/idempotency conflict, one-time/completed/skipped denial, exact version과 immutable before/after audit, Today effective time/exclusion, sibling/series/revision/identity/completion-history isolation, materializer replay와 direct-write/private-state denial을 포함한다.

## Data / API / Privacy

- 검증은 fresh local Supabase와 deterministic synthetic UUID/텍스트만 사용했다. production migration, 실제 계정, 실제 household와 고객 콘텐츠는 사용하지 않았다.
- private command table은 user/household/occurrence/event IDs, SHA-256 request hash, result schedule/version과 생성 시각만 저장한다. chore title, description, display name, email, token과 JWT는 저장하지 않는다.
- public reschedule audit는 generated actor IDs와 구조화된 이전/새 schedule만 보존한다. 자유형 content와 provider payload는 저장하지 않으며 active household member read RLS와 client mutation denial을 적용한다.
- authenticated client는 public RPC만 실행할 수 있다. occurrence와 audit direct mutation, private command state 읽기·쓰기는 허용되지 않는다.
- 새 runtime dependency, Android/iOS permission, analytics event, persistent local cache와 offline outbox를 추가하지 않았다.
- 검증용 local Supabase stack은 최종 DB/Edge/Flutter adapter smoke 이후 중지했다.

## Manual / Deferred Validation

- 사용자 지시에 따라 실제 Google 성인 계정 2개와 Android 기기 2대에서 reschedule → 양쪽 Today 반영을 확인하는 검증은 **NOT RUN**이며 기능 개발 완료 후 마지막 gate에서 수행한다.
- production Supabase deploy, remote migration smoke, backup/restore와 forward rollback rehearsal은 **NOT RUN**이다.
- offline/reconnect, process death, Realtime/resume, simultaneous two-client race와 representative-device performance는 **NOT RUN**이다.
- DST gap/fold의 최종 사용자 정책과 timezone 경계의 실제 기기 검증은 Phase 04 dependency gate 전까지 **NOT RUN**이다.
- single-occurrence reassign, persistent exception history/detail, future-series edit/cancel, periodic horizon extension/repair와 notification intent 재계산은 이번 slice 범위가 아니다.

## Remaining Risks / Completion Boundary

1. reschedule history는 DB에 보존되지만 앱에 history/detail surface가 없어 사용자가 이전 schedule로 직접 복원할 수 없다.
2. stable occurrence identity는 원래 occurrence key를 유지하므로 future-series revision 구현 시 effective override를 명시적으로 보존하는 merge 계약이 필요하다.
3. 담당자 변경과 notification intent 재계산이 아직 없어 single-occurrence exception 경험이 완성되지 않았다.
4. initial materialization window 뒤 회차를 만드는 periodic horizon extension/repair worker가 아직 없다.
5. 로컬 transaction/RLS/adapter 검증은 통과했지만 실제 두 client의 전달 지연·재시도·동기화 경험은 마지막 실계정 gate 전까지 미확정이다.

FR-CHORE-007과 WP03-05 전체는 reassign, persistent exception recovery, horizon worker와 실제 계정·두 기기 결과가 없으므로 완료로 표시하지 않는다.

## Rollback

- production 적용 전에는 WP03-05D reschedule domain/UI wiring과 migration을 revert하고 clean reset으로 create/complete/reopen/repeat/skip/restore 회귀를 확인한다.
- production 적용 후에는 적용된 migration을 수정·삭제하지 않는다. `reschedule_chore_occurrence` execute grant를 먼저 회수하고 권한/transition/audit/Today 계약을 교정하는 forward migration을 추가한다.
- UI-only rollback은 reschedule 메뉴를 숨기고 기존 Today read, create, complete/reopen, skip/Undo를 유지한다. 이미 이동한 occurrence와 append-only reschedule audit는 보존한다.

## Next Entry Condition

- 다음 기능 우선순위는 WP03-05E single-occurrence reassign을 stable occurrence identity, explicit assignee, version/idempotency와 structured audit를 유지하는 bounded slice로 추가하는 것이다.
- 그 다음 persistent exception history/detail 또는 periodic horizon extension/repair 중 사용자 가치와 선행 의존성이 큰 항목을 별도 work plan으로 선택한다.
- 실제 계정·두 기기 gate는 사용자 지시에 따라 기능 개발이 끝난 마지막 단계까지 유지한다.
