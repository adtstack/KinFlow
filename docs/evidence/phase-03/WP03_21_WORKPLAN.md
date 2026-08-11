# Phase 03 WP03-21 Chore Series Cancellation From Selected Occurrence Work Plan

## Status

- 상태: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)** — P1 activation과 WP03/G3 live Gate 완료는 아님
- 수직 조각: Upcoming recurring chore → 선택 회차 이후 취소 확인 → server-derived recurrence boundary → bounded terminal prefix 또는 immediate end → authoritative list reconciliation
- 요구사항: `FR-CHORE-005`, `FR-CHORE-008`, `FR-CHORE-013`, `NFR-SEC-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-061`
- 계약: `docs/contracts/chore-series-cancel-from-occurrence.yaml.md`
- 증거: `docs/evidence/phase-03/WP03_21_EVIDENCE.md` (검증 후 작성)
- 실제 계정, hosted Supabase, 두 기기와 physical-device 검증은 사용자 지시에 따라 마지막 Gate로 유지한다.

## Product boundary

- Owner/Admin은 Upcoming의 미래 active scheduled 반복 회차에서 `이 회차부터 취소`를 선택할 수 있다.
- 서버는 occurrence ID의 immutable `recurrence_local_date`를 경계로 사용하고 client due date를 신뢰하지 않는다.
- 경계 전 회차와 경계 이후 완료 회차는 그대로 남고, 경계 이후 미완료 회차만 취소된다.
- 경계 전 scheduled prefix가 있으면 그 prefix의 latest applicable revision을 bounded terminal revision으로 복제해 기존 목록과 worker가 종료 전 항목을 계속 처리한다.
- prefix가 없으면 기존 전체 취소처럼 즉시 soft-delete한다. 기존 전체 취소와 선택 회차 이후 수정은 유지한다.

## DB/API and authority design

1. additive `cancel_repeating_chore_series_from_occurrence` RPC가 exact series version과 authenticated-user idempotency hash를 사용한다.
2. series와 exact active-revision target row를 lock하고 target recurrence slot이 가구-local 오늘 이후인지 검증한다.
3. 경계 이후 completed는 historical revision에 남기고 나머지 non-cancelled row는 revision과 무관하게 cancelled로 전이한다.
4. prefix가 남으면 latest surviving scheduled row의 revision content·anchor를 복제하고 never/until은 boundary-1, count는 existing prefix slot count로 bound한다.
5. source revision의 surviving scheduled row만 equivalent terminal revision으로 연결하고 due/assignee exception은 변경하지 않는다.
6. materialization state를 지우고 terminal revision을 audit event와 replay result에 기록한다. table/column/RLS grant와 legacy RPC는 유지하고 기존 cancellation audit/replay revision-shape check만 optional terminal revision을 허용하도록 넓힌다.

## Flutter design

1. separate cancellation draft/request가 target occurrence ID를 fingerprint에 포함한다.
2. exact nine-key response는 nullable terminal revision pair invariant까지 strict parse/map한다.
3. controller는 current Upcoming query의 future scheduled manageable occurrence와 online cache를 확인하고 provider는 exact Chores runtime policy를 I/O 전에 적용한다.
4. 동일 target/version transient retry는 command ID를 재사용하고 target/version 변경은 새 ID를 만든다. 성공·stale·invalid transition·target unavailable은 authoritative current query를 reload한다.
5. 기존 destructive confirmation 스타일을 재사용하되 from-occurrence 전용 title/body/action/success를 EN/KO/EN-XA로 구분하고 compact 200% layout을 검증한다.

## Automated evidence plan

1. DB function/grant/search-path, no schema widening, role/cross-household/one-time/completed/skipped/old-revision/past target denial
2. target row and server recurrence boundary, earlier scheduled/completed preservation, later completion preservation, later incomplete cancellation
3. prefix terminal revision content/anchor/end invariants, count-rule bound, no-prefix soft-delete and worker no-regeneration
4. exact optimistic conflict, same-key replay, different-input collision, content-free audit and legacy whole-cancel/edit compatibility
5. domain fingerprint, strict repository payload/result mapping, cache invalidation and invalid payload rejection
6. controller query/status/cache/runtime gates, retry-key reuse/rotation and authoritative reconciliation
7. Upcoming confirmation request mapping, failure/retry/success, EN/KO/EN-XA compact 200% and full regression gates

## Stop conditions and rollback

- client date가 boundary authority가 되거나 active target row를 서버가 확인하지 않으면 배포하지 않는다.
- 경계 전 scheduled occurrence가 목록에서 사라지거나 경계 이후 completed 이력이 변경되면 배포하지 않는다.
- terminal revision이 source content·anchor를 바꾸거나 worker가 boundary 이후 occurrence를 다시 만들면 배포하지 않는다.
- rollback은 UI action과 adapter를 제거하고 additive RPC execute를 forward migration으로 revoke한다. 이미 생성된 terminal revision은 유효한 bounded recurrence로 계속 처리할 수 있다.

## Non-scope

- immediate Undo/resume is a separate successor slice (implemented by WP03-22); persistent or arbitrary historical resume remains out of scope
- Calendar this-and-future cancellation
- provider, remote account, hosted production size, two-device and physical-device evidence
