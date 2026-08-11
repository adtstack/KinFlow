# Phase 03 WP03-05F Recurrence Horizon Worker Work Plan

- 작성일: 2026-08-07
- 기준 commit: `a85f262` + current WP02-06/WP03-04/WP03-05A/B/C/D/E workspace
- 상태: COMPLETE — LOCAL AUTOMATED SLICE (remote scheduler/live gates deferred)
- 범위: active repeating chore를 household-local today 기준 미래 365일까지 주기적으로 연장하고 짧은 lookback window를 replay-safe하게 복구하는 server-only vertical slice

## Requirements

| ID | 이번 vertical slice |
|---|---|
| WP03-05 (PARTIAL) | initial first-year materialization 이후에도 active recurrence가 sliding future horizon을 유지한다. |
| FR-CHORE-006 | periodic horizon job, stable series/date occurrence key와 conflict-ignore replay를 실제 scheduled worker로 연결한다. |
| D-019 | canonical series/revision과 materialized occurrence 상태를 분리한다. worker는 recurrence definition이나 기존 occurrence 상태를 수정하지 않는다. |
| D-048 / NFR-REL-01 | retry, overlap과 partial series failure가 duplicate occurrence 또는 전체 batch 손실로 이어지지 않는다. |
| NFR-SEC-01 | worker와 운영 상태는 `service_role`/database owner만 접근하고 mobile authenticated/anon에는 노출하지 않는다. |
| NFR-OBS-01 (PARTIAL) | PII 없는 run aggregate와 series별 coverage/result code로 horizon 상태를 점검할 수 있다. |

## Materialization Contract

1. 기존 initial materializer의 “revision start부터 최대 365일” 계약은 호환용으로 유지한다.
2. 새 private window materializer는 한 번에 최대 397일만 스캔한다. daily/weekly/monthly anchor와 count/until/never end semantics는 initial materializer와 동일하다.
3. worker window는 각 series timezone의 local date에서 repair lookback을 뺀 날짜부터 local date + horizon days까지다. 기본은 lookback 7일, horizon 365일이다.
4. stable `household_id + series_id:original-local-date` key와 `ON CONFLICT DO NOTHING`으로 existing scheduled/completed/skipped/cancelled, reassigned 또는 rescheduled occurrence를 overwrite하지 않는다.
5. count ordinal은 전체 recurrence anchor 기준으로 계산한다. 오래된 series도 revision start부터 다시 scan하지 않고 bounded window 안에서 정확한 global ordinal을 계산한다.
6. until/count가 끝난 series는 completion을 감지해 다시 schedule하지 않는다. future start가 horizon 밖인 series와 deleted/one-time series도 claim하지 않는다.
7. active revision default assignee가 removed 상태면 새 occurrence를 만들지 않고 allowlisted `assignee_unavailable` 결과로 격리한다.

## Worker / Schedule Contract

1. `public.run_chore_horizon_worker(asOf, horizonDays, repairLookbackDays, batchSize, targetSeriesId)`는 security-definer이며 `service_role`만 실행한다. `targetSeriesId = null`은 scheduled batch, 특정 ID는 bounded manual repair다.
2. 인자는 timestamp non-null, horizon 30..365, lookback 0..31, batch 1..500으로 제한한다. target series ID 외 자유형 payload는 받지 않는다.
3. batch claim은 active series row의 `FOR UPDATE SKIP LOCKED`를 사용한다. normal run은 uncovered/revision-changed/due-for-repair series만 deterministic order로 최대 batch size만큼 선택한다.
4. 한 series 실패는 nested transaction boundary에서 rollback하고 다음 series를 계속 처리한다. raw exception은 저장하거나 반환하지 않고 allowlisted stable error code만 기록한다.
5. private state는 revision ID, covered/window dates, next repair time, inserted count와 stable result/error만 저장한다. private run audit는 invocation parameters와 aggregate counts만 append한다.
6. `pg_cron` named job `kinflow-chore-horizon-v1`은 매시 17분에 기본 worker를 호출한다. 하루 경계의 timezone 차이와 batch backlog를 처리하되 state gate로 같은 series의 불필요한 hourly replay를 막는다.
7. `cron.schedule/unschedule/alter_job`, cron tables, private state/run tables와 private materializer는 anon/authenticated에서 읽거나 실행할 수 없다.

## Automated Validation

- clean migration reset, `pg_cron` exact schedule/command/owner와 least-privilege grants
- long-running daily extension beyond original start+365 boundary
- weekly multi-weekday global count ordinal across a late bounded window
- monthly day-31 missing-month behavior와 until/count exhaustion
- household timezone local-date target과 timed UTC/all-day parity
- missing future occurrence repair, same-window replay no duplicate, stable key preservation
- completed/skipped/reassigned/rescheduled occurrence와 series/revision/default assignee/history isolation
- removed default assignee failure isolation과 following healthy series success
- batch limit, deterministic continuation, targeted manual repair와 invalid input denial
- scheduled normal run eligibility, next-repair gate와 revision mismatch recovery
- direct client/private/cron mutation denial, privacy-minimal exact columns, immutable run audit
- full pgTAP/RLS, Edge/backend, exact Flutter analyzer/test/coverage regression

## Explicit Non-scope

- general-purpose background job queue, lease heartbeat, retries with jitter, dead letter UI와 notification outbox (WP05)
- future-series revision/edit/cancel과 old revision invalidation
- assignment notification intent recalculation
- persistent exception history/detail와 end-user repair/Undo UI
- on-demand materialization from Today reads
- production deploy, external scheduler monitoring/alerting, actual Google accounts/two-device validation

## Stop / Rollback

- worker가 397일 초과 window를 scan하거나 existing occurrence state/assignee/due/version을 변경하거나 duplicate key를 만들면 배포하지 않는다.
- authenticated/anon이 worker, private state 또는 cron mutation에 접근하거나 한 poison series가 healthy series를 rollback시키면 배포하지 않는다.
- production 적용 전에는 migration과 test/evidence wiring을 revert하고 clean reset으로 prior 12 migrations를 검증한다.
- production 적용 후에는 applied migration을 수정·삭제하지 않는다. named cron job을 먼저 `cron.unschedule`하고 worker execute grant를 회수한 뒤 forward migration으로 materializer/state를 교정한다. 기존 occurrence와 coverage/run audit는 보존한다.

## Completion Boundary

자동 검증이 green이어도 future-series edit, persistent exception history, general WP05 job reliability/monitoring과 실제 성인 2계정·2기기 결과가 없으므로 WP03-05 또는 Chores Value Gate 전체를 완료로 표시하지 않는다. 실계정 검증은 사용자 지시에 따라 기능 개발 이후 마지막 gate로 유지한다.
