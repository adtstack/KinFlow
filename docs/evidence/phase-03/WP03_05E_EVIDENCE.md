# Phase 03 WP03-05E Single-Occurrence Reassignment Evidence

- Work Package: WP03-05E — versioned reassignment for one repeating occurrence
- 기준 commit: base `a85f262`; implementation은 2026-08-07 현재 WP02-06/WP03-04/WP03-05A/B/C/D 연속 workspace
- 검증일: 2026-08-07
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 29.6.2
- 결과: **LOCAL AUTOMATED PASS / REAL-ACCOUNT·TWO-DEVICE LIVE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP03-05E | PASS FOR LOCAL AUTOMATED SLICE | materialized repeating occurrence 한 건의 effective assignee만 다른 active household adult로 변경하고 Today 표시까지 연결했다. |
| FR-CHORE-002 | PARTIAL | 모든 occurrence는 계속 정확히 한 명의 active adult primary assignee를 가진다. unassigned/multiple assignment는 열지 않았다. |
| FR-CHORE-007 | PARTIAL | skip/restore/reschedule에 이어 single-occurrence reassign을 구현했다. persistent exception history/recovery는 후속 slice다. |
| D-019 | PASS FOR NEW SURFACE | revision default assignee와 occurrence effective assignee를 분리하고 materializer replay가 override를 덮지 않음을 검증했다. |
| D-020 | PARTIAL | “이번 회차” assignee만 변경한다. future-series revision/edit는 열지 않았다. |
| D-048/NFR-REL-01 | PASS FOR REASSIGN COMMAND | expected occurrence version과 user-scoped command UUID로 stale write, retry와 duplicate audit/version 증가를 차단했다. |
| NFR-SEC-01 | PASS FOR NEW SURFACE | Owner/Admin, 자기 담당 Member, 비담당 Member, outsider, removed actor/target 경계를 DB에서 계산하고 direct/private mutation을 차단했다. |

## Implementation

- `20260807040000_chore_occurrence_reassignment.sql`은 authenticated-only `reassign_chore_occurrence` security-definer RPC, private idempotency result, 별도 immutable `chore_assignment_events`를 추가한다.
- RPC는 JWT user와 active membership, 현재 role, occurrence의 현재 assignee, target membership을 DB에서 다시 읽는다. Owner/Admin은 같은 household occurrence를, Member는 현재 자기 담당 occurrence만 다른 active member에게 넘길 수 있다.
- 대상은 canonical repeating revision의 `scheduled` occurrence여야 한다. one-time, completed, skipped/cancelled, stale version, removed/cross-household target과 현재 담당자로의 no-op은 mutation 전에 거부한다.
- 성공 transaction은 occurrence의 `assignee_member_id`와 trigger-managed version/timestamp만 변경한다. stable `occurrence_key`, status, due/completion fields, series/revision/default assignee와 sibling occurrence는 보존한다.
- 동일 user+command UUID의 동일 normalized input은 최초 assignee/version과 `changed=false`를 반환한다. 다른 input 재사용은 거부하며 version과 audit는 한 번만 증가한다.
- 별도 assignment audit는 generated actor/member/occurrence/correlation IDs, 이전·새 assignee IDs와 occurrence version만 append한다. chore title, notes, display name, email, token과 provider payload는 저장하지 않는다.
- `get_today_chores_v2`는 occurrence의 effective assignee ID와 해당 active member의 현재 display name을 읽으므로 한 회차만 새 담당자로 표시한다.
- Flutter는 SDK/UI 독립적인 reassignment draft/request/snapshot을 사용한다. Supabase adapter와 repository는 exact response shape/type, request household/occurrence/target binding, literal `scheduled`, normalized display name과 `expectedVersion + 1`을 fail-closed로 검증한다.
- Today controller는 새 target ID/display name을 즉시 optimistic하게 표시하고 duplicate save를 합친다. retryable failure에는 원본 row와 동일 command UUID를 재사용하며 stale/invalid transition에는 authoritative Today를 다시 읽는다.
- 첫 focused pgTAP 실행은 Member가 자기 occurrence를 넘긴 뒤 같은 command를 재시도할 때 현재 assignee 검사에 먼저 막히는 결함을 발견했다. exact same actor/key/hash replay를 새 command authorization보다 먼저 판정하도록 순서를 교정하고 clean reset부터 다시 검증했다.
- scheduled repeating row의 3항목 메뉴에 localized reassignment dialog를 추가했다. roster를 새로 읽고 active adult 한 명을 선택하며 현재 담당자 no-op 제출을 막고 성공을 SnackBar로 알린다. one-time/completed row에는 해당 occurrence action 메뉴가 노출되지 않는다.
- dialog와 3항목 popup은 320×568dp, 200% text, KO/pseudo locale에서 스크롤 가능하고 cancel/confirm/기존 reschedule/skip/Undo action은 최소 48dp임을 검증했다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean `npx supabase db reset` | PASS, ordered forward migration 12개와 synthetic seed 적용 |
| DB schema lint | PASS, `app_private`, `extensions`, `public` warning/error 0 |
| focused reassignment pgTAP | PASS, 59/59 |
| full pgTAP/RLS regression | PASS, 신규 reassignment 59 + predecessor 617 = 676 tests, 12 files |
| focused Flutter domain/boundary/controller | PASS, 69 tests |
| focused Flutter widget/adaptive 포함 | PASS, 총 89 tests; KO/pseudo 200% text 포함 |
| full Flutter regression | PASS, 288 tests + local-connectivity opt-in 1 skip |
| exact formatter/analyzer | PASS, quality scope 217 files changed 0; analyzer issue 0 |
| repository CI self-test/workflow | PASS, 47/47; 5 jobs, pinned action 17개, `contents:read` |
| Edge/backend regression | PASS, invite 22/22, member lifecycle 18/18, health, invite live와 Flutter local adapter |
| config/secret/codegen | PASS, public config allowlist, high-confidence secret 0, generated output drift 0/8 files |
| coverage | PASS, 4,978 / 6,392 lines = 77.88% |
| whitespace | PASS, `git diff --check` output 0 |

pgTAP fixture는 strict schema/grant/content minimization, assigned Member/Owner/Admin success, 비담당 Member/outsider/removed actor denial, active same-household target과 no-op 검증, stale/idempotency conflict와 same-input replay, one-time/completed/skipped denial, exact version과 immutable before/after audit, Today effective assignee/display, sibling/series/revision/default assignee/identity/due/completion-history isolation, materializer replay, direct write/private state/immutable audit denial을 포함한다.

## Data / API / Privacy

- 검증은 fresh local Supabase와 deterministic synthetic UUID/텍스트만 사용했다. production migration, 실제 계정, 실제 household와 고객 콘텐츠는 사용하지 않았다.
- private command table은 user/household/occurrence/event IDs, SHA-256 request hash, result assignee/version과 생성 시각만 저장한다. chore title, description, display name, email, token과 JWT는 저장하지 않는다.
- public assignment audit는 generated actor IDs, 이전·새 assignee IDs와 version만 보존한다. 자유형 content와 provider payload는 저장하지 않으며 active household member read RLS와 client mutation denial을 적용한다.
- authenticated client는 public RPC만 실행할 수 있다. occurrence와 audit direct mutation, private command state 읽기·쓰기는 허용되지 않는다.
- 새 runtime dependency, Android/iOS permission, analytics event, persistent local cache와 offline outbox를 추가하지 않았다.
- 검증용 local Supabase stack은 최종 DB/Edge/Flutter adapter smoke 이후 중지했다.

## Manual / Deferred Validation

- 사용자 지시에 따라 실제 Google 성인 계정 2개와 Android 기기 2대에서 reassign → 양쪽 Today 반영을 확인하는 검증은 **NOT RUN**이며 기능 개발 완료 후 마지막 gate에서 수행한다.
- production Supabase deploy, remote migration smoke, backup/restore와 forward rollback rehearsal은 **NOT RUN**이다.
- offline/reconnect, process death, Realtime/resume, simultaneous two-client race와 representative-device performance는 **NOT RUN**이다.
- assignment history/detail, 이전 담당자로 Undo, future-series edit/cancel, periodic horizon extension/repair와 notification intent 재계산은 이번 slice 범위가 아니다.

## Remaining Risks / Completion Boundary

1. assignment audit는 DB에 보존되지만 앱에 history/detail/Undo surface가 없어 사용자가 이전 담당자로 직접 복원할 수 없다.
2. stable occurrence identity는 기존 key를 유지하므로 future-series revision 구현 시 effective assignee override를 명시적으로 보존하는 merge 계약이 필요하다.
3. notification intent 재계산이 아직 없어 이미 예약된 담당자 알림과 새 effective assignee의 정합성은 Phase 05 전까지 미확정이다.
4. initial materialization window 뒤 회차를 만드는 periodic horizon extension/repair worker가 아직 없다.
5. 로컬 transaction/RLS/adapter 검증은 통과했지만 실제 두 client의 전달 지연·재시도·동기화 경험은 마지막 실계정 gate 전까지 미확정이다.

FR-CHORE-002, FR-CHORE-007과 WP03-05 전체는 unassigned/multiple 정책 확정, persistent exception recovery, horizon worker와 실제 계정·두 기기 결과가 없으므로 완료로 표시하지 않는다.

## Rollback

- production 적용 전에는 WP03-05E reassignment domain/UI wiring과 migration을 revert하고 clean reset으로 create/complete/reopen/repeat/skip/restore/reschedule 회귀를 확인한다.
- production 적용 후에는 적용된 migration을 수정·삭제하지 않는다. `reassign_chore_occurrence` execute grant를 먼저 회수하고 권한/transition/audit/Today 계약을 교정하는 forward migration을 추가한다.
- UI-only rollback은 reassign 메뉴를 숨기고 기존 Today read, create, complete/reopen, skip/Undo, reschedule을 유지한다. 이미 변경된 occurrence와 append-only assignment audit는 보존한다.

## Next Entry Condition

- 다음 기능 우선순위는 WP03-05F periodic horizon extension/repair worker다. bounded initial materialization 뒤에도 반복 회차가 계속 생기도록 stable key, lease/concurrency와 replay-safe repair 계약을 별도 work plan으로 고정한다.
- 그 다음 persistent exception history/detail 또는 future-series edit/cancel 중 선행 의존성이 큰 항목을 별도 slice로 선택한다.
- 실제 계정·두 기기 gate는 사용자 지시에 따라 기능 개발이 끝난 마지막 단계까지 유지한다.
