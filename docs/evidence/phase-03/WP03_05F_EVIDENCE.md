# Phase 03 WP03-05F Recurrence Horizon Worker Evidence

- Work Package: WP03-05F — sliding recurrence horizon extension and bounded repair worker
- 기준 commit: base `a85f262`; implementation은 2026-08-07 현재 WP02-06/WP03-04/WP03-05A/B/C/D/E 연속 workspace
- 검증일: 2026-08-07
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 29.6.2, pg_cron 1.6.4
- 결과: **LOCAL AUTOMATED PASS / REMOTE SCHEDULER·REAL-ACCOUNT LIVE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP03-05F | PASS FOR LOCAL AUTOMATED SLICE | active repeating series를 household-local today + 365일까지 시간당 bounded batch로 연장하고 7일 lookback repair를 연결했다. |
| FR-CHORE-006 | PASS FOR LOCAL AUTOMATED SURFACE | named periodic job, stable occurrence key, conflict-ignore replay, bounded manual repair와 실제 two-connection overlap을 검증했다. |
| D-019 | PASS FOR NEW SURFACE | worker는 canonical series/revision을 읽고 missing occurrence만 insert하며 기존 occurrence와 recurrence definition을 수정하지 않는다. |
| D-048/NFR-REL-01 | PASS FOR HORIZON WORKER | normal eligibility, count/until completion, replay, batch continuation, `FOR UPDATE SKIP LOCKED`와 per-series failure isolation이 duplicate 또는 batch rollback을 막는다. |
| NFR-SEC-01 | PASS FOR NEW SURFACE | worker는 `service_role`만 실행하고 private materializer/state/run 및 cron mutation은 anon/authenticated/service client에서 차단했다. |
| NFR-OBS-01 | PARTIAL | PII 없는 series coverage/result와 run aggregate를 저장한다. dashboard/alert/dead-letter 운영면은 후속 WP05/08 범위다. |

## Implementation

- `20260807050000_chore_horizon_worker.sql`은 Supabase 번들 `pg_cron`, private bounded window materializer, series coverage state, immutable aggregate run audit와 service-role-only worker를 추가한다.
- 기존 `materialize_chore_revision`은 create API 호환을 위해 revision start + 365일 제한을 유지한다. 새 `materialize_chore_revision_window`는 한 번에 최대 397일만 생성해 오래된 series가 revision start부터 매번 재스캔되지 않게 한다.
- window recurrence math는 daily day offset, monthly month offset, weekly anchored active-week/weekday ordinal로 전체 series 기준 count 순번을 계산한다. 첫 주 중간 시작, multi-weekday, interval, count/until/never와 monthly day-31 skip을 bounded late window에서도 유지한다.
- 기본 scheduled window는 series timezone의 local today - 7일부터 local today + 365일까지다. timed occurrence는 series timezone에서 UTC instant로 변환하고 all-day는 `due_at = null`을 유지한다.
- stable key는 기존 `series UUID:original local date`를 그대로 사용하고 `ON CONFLICT DO NOTHING`으로 completed/skipped/reassigned/rescheduled/cancelled row, version과 audit history를 overwrite하지 않는다. owner가 만든 missing future-row fixture는 같은 key/default state로 복구됐다.
- normal worker는 coverage가 부족하거나 revision이 바뀌었거나 repair due인 active repeating series만 deterministic하게 선택하고 `FOR UPDATE SKIP LOCKED`로 최대 500개까지 claim한다. specific series ID를 전달하면 service role이 한 series만 bounded manual repair할 수 있다.
- 각 series는 nested exception boundary에서 처리한다. removed default assignee는 새 occurrence 없이 `assignee_unavailable`로 격리되고 같은 batch의 healthy series는 계속 연장된다. raw SQL error/message는 state나 반환값에 기록하지 않는다.
- count 또는 until이 끝난 state는 `next_repair_at = infinity`로 normal claim에서 제외한다. 구현 중 focused test가 이 infinity state보다 coverage date 비교가 먼저 적용되어 다음 해 count series를 재선택하는 결함을 발견했고, completed state를 eligibility 최우선 gate로 교정했다.
- `chore_materialization_states`는 household/series/revision IDs, coverage/window dates, next repair, counts와 allowlisted result/error만 저장한다. `chore_materialization_runs`는 optional target series ID, 실행 인자와 aggregate counts만 append하며 household ID, title, notes, display name, email과 token을 저장하지 않는다.
- named cron job `kinflow-chore-horizon-v1`은 매시 17분에 365/7/100 default worker를 호출한다. hourly wake는 timezone midnight와 batch backlog를 처리하고 state gate가 같은 series의 불필요한 hourly 실행을 막는다.
- authenticated와 anon은 worker execute 권한이 없다. service role은 public worker 결과만 받고 private materializer/table 또는 cron schema를 직접 사용할 수 없다. pg_cron extension의 default function ACL과 무관하게 schema usage denial을 실제 호출로 검증했다.

## Dependency Review — pg_cron

- 목적: 모바일 client나 외부 secret-bearing scheduler 없이 Postgres 안에서 periodic horizon command를 실행한다.
- 대안: Edge Function/외부 CI cron은 별도 deployment, service-role secret, network failure와 운영 surface가 추가되어 이번 DB-local slice에서는 채택하지 않았다.
- 지원/유지보수: local Supabase PostgreSQL image가 pg_cron 1.6.4와 named schedules를 제공한다. production Supabase extension enable/version과 timed execution monitoring은 remote deployment gate에서 다시 확인한다.
- 라이선스: upstream은 사용·복사·수정·배포를 허용하는 [Citus Data permissive license](https://github.com/citusdata/pg_cron/blob/main/LICENSE)를 제공한다.
- 개인정보/권한: cron command에는 content나 user payload가 없고 database owner가 service-role-only aggregate worker를 호출한다. 앱 SDK, native platform, analytics, local storage와 permission 변화는 없다.
- rollback: named job을 unschedule하고 worker execute grant를 회수한 뒤 forward migration으로 상태를 교정한다. 앱 dependency 제거 또는 store binary rollback은 필요 없다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean `npx supabase db reset` | PASS, ordered forward migration 13개와 synthetic seed 적용 |
| DB schema lint | PASS, `app_private`, `extensions`, `public` warning/error 0 |
| focused horizon worker pgTAP | PASS, 101/101 |
| focused two-connection concurrency pgTAP | PASS, 7/7; externally locked first series skip 후 다음 invocation에서 복구 |
| full pgTAP/RLS regression | PASS, 신규 worker 108 + predecessor 676 = 784 tests, 14 files |
| full Flutter regression | PASS, 288 tests + local-connectivity opt-in 1 skip |
| exact formatter/analyzer | PASS, quality scope 217 files changed 0; analyzer issue 0 |
| repository CI self-test/workflow | PASS, 47/47; 5 jobs, pinned action 17개, `contents:read` |
| Edge/backend regression | PASS, invite 22/22, member lifecycle 18/18, health, invite live와 Flutter local adapter |
| config/secret/codegen | PASS, public config allowlist, high-confidence secret 0, generated output drift 0/8 files |
| coverage | PASS, 4,978 / 6,392 lines = 77.88% |
| whitespace | PASS, `git diff --check` output 0 |

Worker fixture는 exact extension/job/grant/schema/column contract, invalid bounds, unknown target minimization, local-date boundary, daily timed extension, missing row repair, existing complete/skip/reassign/reschedule isolation, legacy initial limit, weekly count와 midweek first-week ordinal, monthly day-31/until/all-day, batch exhaustion/continuation/replay, removed assignee failure isolation, immutable aggregate audit와 direct client denial을 포함한다.

별도 concurrency fixture는 외부 dblink transaction이 lexicographically first series row를 `FOR UPDATE`로 보유한 상태에서 batch-size 1 worker가 unlocked second series만 373개 occurrence로 채우고, lock release 뒤 다음 invocation이 first series를 같은 373개 stable key로 채우는 것을 검증했다. fixture와 test-only dblink extension은 검증 종료 후 정리된다.

## Data / API / Privacy

- 검증은 fresh local Supabase와 deterministic synthetic UUID/텍스트만 사용했다. production migration, 실제 계정, 실제 household와 고객 콘텐츠는 사용하지 않았다.
- public worker response는 generated run ID와 claimed/succeeded/failed/inserted aggregate, batch exhausted flag뿐이다. unknown target ID는 모두 0인 동일 형태를 반환한다.
- per-series state는 private schema이고 service role에도 direct table privilege를 주지 않았다. error는 `assignee_unavailable`, `invalid_recurrence`, `materialization_failed` allowlist만 저장한다.
- run audit에는 household ID가 없고 optional target series ID 외에는 aggregate만 있다. append-only trigger가 update/delete를 거부한다.
- 새 모바일 runtime dependency, Android/iOS permission, user-facing string, analytics event, persistent client cache와 offline outbox를 추가하지 않았다.
- 검증용 local Supabase stack은 최종 DB/Edge/Flutter adapter smoke 이후 중지했다.

## Manual / Deferred Validation

- 사용자 지시에 따라 실제 Google 성인 계정 2개와 Android 기기 2대의 장기 recurrence 동기화는 **NOT RUN**이며 기능 개발 완료 후 마지막 gate에서 수행한다.
- production Supabase deploy, remote pg_cron enable/version, 실제 clock wake/job_run_details, alert/retention, backup/restore와 unschedule forward rollback rehearsal은 **NOT RUN**이다.
- production-size 수천 series의 query plan/throughput, crash 중간 복구, retry jitter/dead letter와 operational dashboard는 **NOT RUN**이다.
- DST gap/fold 정책의 실제 timezone matrix와 timezone data/version upgrade rehearsal은 **NOT RUN**이다.

## Remaining Risks / Completion Boundary

1. local pg_cron 1.6.4 schedule과 exact command는 검증했지만 remote Supabase의 extension activation, timed wake와 alert 전달은 production deployment 전까지 미확정이다.
2. poison series는 hourly retry되지만 general queue의 max-attempt/dead-letter/alert가 없어 장기 failure 운영은 WP05 worker 기반이 필요하다.
3. run/state는 SQL 운영 근거만 제공하며 dashboard, retention과 support-facing repair runbook은 아직 없다.
4. future-series revision/edit는 아직 없어 revision mismatch recovery path는 schema상 준비됐지만 end-to-end로 사용되지 않는다.
5. DST gap/fold 최종 정책과 actual tzdata 경계는 Phase 04 time gate까지 남아 있다.
6. 로컬 overlap/replay는 통과했지만 production-size concurrent load와 실제 두 client 경험은 마지막 live/release gate 전까지 미확정이다.

FR-CHORE-006의 local functional surface는 구현됐지만 WP03-05와 Chores Value Gate는 future-series edit, persistent exception history와 실제 계정·두 기기 결과가 없으므로 완료로 표시하지 않는다.

## Rollback

- production 적용 전에는 WP03-05F migration/tests/evidence를 revert하고 clean reset으로 이전 12개 migration과 676-test baseline을 확인한다.
- production 적용 후에는 적용된 migration을 수정·삭제하지 않는다. `cron.unschedule('kinflow-chore-horizon-v1')`로 wake를 먼저 중단하고 `run_chore_horizon_worker` execute grant를 회수한 뒤 forward migration으로 materializer/state를 교정한다.
- 이미 생성된 occurrence는 stable canonical rows이므로 rollback 시 삭제하지 않는다. private coverage/run audit도 forensic evidence로 보존한다.
- worker pause는 create/Today/complete/skip/restore/reschedule/reassign 앱 경로를 중단하지 않지만 현재 coverage 끝 이후 새 occurrence 생성은 멈춘다.

## Next Entry Condition

- 다음 기능 우선순위는 WP03-05G future-series edit/cancel이다. 새 immutable revision effective boundary, 과거/완료 이력 보존, 미래 미완료 occurrence 재계산과 worker coverage reset을 하나의 bounded contract로 고정한다.
- 그 다음 persistent exception history/detail 또는 WP03-06 Today upcoming/overdue/filter·resume invalidation 중 선행 의존성이 큰 항목을 선택한다.
- 실제 계정·두 기기 gate는 사용자 지시에 따라 기능 개발이 끝난 마지막 단계까지 유지한다.
