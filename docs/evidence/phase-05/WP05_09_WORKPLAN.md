# Phase 05 WP05-09 Actionable Chore Occurrence Target Workplan

## Status

- 상태: **LOCAL IMPLEMENTED (2026-08-09) / REAL-ACCOUNT·REAL-DEVICE GATE DEFERRED**
- 수직 조각: Chore inbox/push exact target → server-derived actionability → versioned/idempotent complete or reopen → authoritative target and activity reconciliation
- 요구사항: `FR-NOTIF-005`, `FR-CHORE-004`, `FR-TODAY-003`, `NFR-SEC-01`, `NFR-PRIV-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`
- 결정: `D-002`, `D-006`, `D-013`, `D-017`, `D-018`, `D-022`, `D-048`, `D-051`
- 계약: `docs/contracts/chore-occurrence-target-actions.yaml.md`
- 예정 증거: `docs/evidence/phase-05/WP05_09_EVIDENCE.md`
- 테스트 ID: `T-CHORE-TARGET-02`, `T-CHORE-02`, `T-NOTIF-02`

## Product boundary

1. WP05-08의 exact Chore 상세에서 scheduled occurrence는 완료, completed occurrence는 다시 열기 action을 제공한다.
2. action은 현재 active household의 최신 target read가 `canSetCompletion=true`라고 반환한 경우에만 표시한다. 이 값은 UI 힌트이며 mutation authorization을 대체하지 않는다.
3. Owner/Admin은 활성 series의 가구 occurrence에 action할 수 있고 일반 성인 member는 현재 자신에게 배정된 occurrence에만 action할 수 있다. 삭제된 series의 completed historical target은 계속 읽을 수 있지만 다시 열 수 없다.
4. 기존 `set_chore_occurrence_completion`의 expected version, caller-scoped idempotency, role/assignee 검증과 immutable history를 그대로 사용한다.
5. 성공 뒤 단건 target과 기존 activity history를 권위적으로 다시 읽는다. direct target과 mutation에는 encrypted read cache나 offline outbox를 사용하지 않는다.
6. skip, reschedule, reassign, one-time/series edit와 cancel은 기존 Chores/Today surface에 남기며 이번 작은 action slice에 복제하지 않는다.

## DB, API and rollback design

- additive migration으로 `public.get_chore_occurrence_action_target(p_household_id, p_occurrence_id)`를 추가한다.
- 새 함수는 WP05-08 exact projection과 `can_set_completion` 한 필드만 반환한다. 기존 `get_chore_occurrence_target` 함수와 응답 shape는 strict N-1 client를 위해 변경하지 않는다.
- 함수는 authenticated active membership을 다시 확인하고 caller member/role 및 series deletion 상태로 actionability를 계산한다. mutation RPC는 동일 조건과 현재 occurrence version을 다시 검사한다.
- 새 table, index, data backfill, direct table grant와 Edge function은 없다. 함수 execute는 authenticated에만 부여하고 anon/service-role은 거부한다.
- rollback은 client action을 숨기고 WP05-08 read로 되돌린 뒤 forward migration으로 새 함수 execute를 revoke한다. 데이터 정리는 없다.

## Client design

1. strict target DTO는 새 RPC의 exact `can_set_completion` boolean을 요구하고 domain occurrence의 presentation capability로 매핑한다.
2. target controller는 기존 load/retry/household supersession에 completion command ID generator, in-flight coalescing, same-fingerprint retry-key reuse와 action failure를 추가한다.
3. mutation 성공 응답은 exact household/occurrence, requested status와 next version을 확인한 뒤 locally reconcile하고 authoritative target refetch를 수행한다.
4. stale version 또는 invalid transition은 새 version으로 자동 재시도하지 않고 authoritative state를 다시 읽어 typed conflict를 표시한다.
5. mutation 성공 뒤 refetch만 실패하면 성공 상태를 되돌리지 않는다. reconciled status/version과 읽기 가능한 상세를 유지하고 별도 refresh warning/action을 제공한다.
6. action button은 Chores runtime feature mutation policy 또는 in-flight 상태에서 I/O 전에 disable하며 기존 localized complete/reopen copy와 48dp Material target을 사용한다.

## Automated evidence plan

1. 새 RPC existence, stable security-definer/search-path, authenticated-only grant와 exact output fields
2. Owner/Admin, assigned regular member, unassigned regular member, deleted completed history, outsider와 removed-member actionability
3. strict target DTO boolean/type/extra-key rejection and repository domain mapping
4. controller complete/reopen, duplicate coalescing, response-loss retry-key reuse, success refetch and history version rebuild
5. stale/invalid transition reconciliation, post-commit refetch failure, household change late-result suppression and unexpected exception normalization
6. widget scheduled/completed actions, busy state, runtime-policy block, permission-hidden historical read, typed failure and compact EN-XA 200% layout
7. focused/full pgTAP and Flutter regressions; analyzer, format, codegen, config, secret, contract, matrix and whitespace gates

## Local implementation result

- additive migration은 기존 local history에 forward 적용되었고 action-target pgTAP 78/78 및 전체 DB 54 files / 2,733 tests가 통과했다.
- strict DTO/repository/controller/widget 집중 Flutter 85 tests와 전체 Flutter 1,157 tests가 통과했다. 기존 local-connectivity opt-in 1건만 skip이다.
- analyzer issue 0, formatter 655 files drift 0, codegen 8 files current, public config와 high-confidence secret scan, Node contract 141/141이 통과했다.
- clean-from-zero·hosted migration, 실계정·다중기기·실기기 validation은 아래 deferred gate로 유지한다.

## Stop conditions

- 기존 WP05-08 RPC response shape를 변경하거나 N-1 strict parser를 깨면 중단한다.
- `canSetCompletion`만으로 mutation을 승인하고 existing server role/assignee/version 검증을 우회하면 중단한다.
- mutation 성공 뒤 refetch 실패를 mutation 실패로 되돌리거나 새 idempotency key로 자동 재제출하면 중단한다.
- direct target/action에 stale cache, offline mutation outbox 또는 raw provider error를 사용하면 중단한다.

## Deferred validation

- 실제 Google 성인 계정의 Owner/Admin/member assignment matrix와 두 기기 stale-version race
- 실제 Firebase foreground/background/terminated tap에서 completion까지의 Android 여정
- physical-device TalkBack, large text와 network response-loss recovery
- Managed Child acting-member 및 approval workflow

위 항목은 사용자 지시에 따라 기능 개발 대부분이 끝난 뒤 마지막 통합 Gate에서 수행한다.
