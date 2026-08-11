# Phase 04 WP04-04C Whole Recurring Calendar Series and Horizon Evidence

- Work Package: WP04-04C — whole-series edit/end, immutable future revision, exception-aware rolling materialization repair
- 기준 commit: base `a85f262`; implementation은 2026-08-07 현재 WP02-06/WP03/WP04 연속 workspace
- 검증일: 2026-08-07
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 29.6.2
- 결과: **LOCAL AUTOMATED PASS / TODAY COMPOSITION·REALTIME·REMOTE·REAL-ACCOUNT·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP04-04C | PASS FOR LOCAL AUTOMATED SLICE | UI→controller→repository→strict Supabase adapter→authenticated series RPC→immutable revision/materializer와 service-role rolling worker 경계가 동작한다. |
| FR-CAL-004 | PASS FOR ROLLING LOCAL SLICE | active recurring series를 bounded household-local horizon까지 확장·repair하고 exact replay는 0-change다. canonical PostgreSQL timezone resolver, end condition, ended exclusion과 compact failure state를 검증했다. |
| FR-CAL-005 / TIME-019 | PASS FOR REGENERATION LOCAL SLICE | moved future exception의 revision, projection, cancel marker, occurrence/exception version을 whole-series update와 rolling repair가 덮어쓰지 않는다. |
| FR-CAL-006 / TIME-018 | PASS FOR LOCAL AUTOMATED SLICE | server-derived household-local today 이전 occurrence는 유지하고 이후 non-exception source slot만 새 immutable active revision으로 rebuild한다. 전체 종료는 today 이후를 취소하고 과거 조회를 보존한다. |
| FR-CAL-007 | IN PROGRESS | series change/end 뒤 v2 page/month projection과 과거 조회를 검증했다. Today 조합, remote query plan과 두 기기 propagation은 남았다. |
| NFR-SEC-01 | PASS FOR NEW BOUNDARY | series commands는 JWT actor, active membership, target과 participants를 서버에서 다시 검증한다. worker는 service-role only이고 API roles에는 cron/private state 접근이 없다. |
| NFR-PRIV-01 | PASS FOR NEW STORAGE | command replay, public change history, worker state/run에는 title, description, display name 또는 participant list가 없고 stable identifiers/digest/count/error code만 있다. |
| NFR-REL-01 | PASS FOR LOCAL COMMAND/WORKER SLICE | expected series version, UUID idempotency, unique slot, bounded skip-locked claim과 exact replay가 duplicate revision/event/occurrence와 exception overwrite를 막는다. |
| NFR-COMP-01 | PASS FOR ADDITIVE LOCAL SLICE | additive lifecycle columns/tables/RPC를 적용하고 기존 one-time CRUD/list/v1, recurring create/occurrence exception/v2 signatures를 유지한 채 clean reset/full regression을 통과했다. |

## Database and API Contract

- `20260807150000_recurring_calendar_series_change_and_horizon.sql`은 `event_series.ended_at`과 `ended_effective_local_date`를 함께 nullable한 lifecycle pair로 추가한다. 종료는 delete와 구분되며 past occurrence/revision을 제거하지 않는다.
- `calendar_revision_candidate_dates(...)`는 immutable anchor에서 계산하되 caller가 지정한 최대 397 local-date window를 지원한다. daily/weekly/monthly interval과 count/until/month-day skip 의미는 기존 validator와 동일하다.
- `materialize_calendar_revision_window(...)`는 missing source slot을 insert하고 stale non-exception projection만 repair한다. projection이 같으면 0을 반환하고 explicit exception이 연결된 occurrence는 conflict update에서 제외한다.
- `get_recurring_calendar_series(...)`는 active recurring revision의 full canonical draft, recurrence rule, participant snapshot, household timezone/local today와 version을 반환한다. 화면에 보이는 modified occurrence를 whole-series editor source로 사용하지 않는다.
- `update_recurring_calendar_series(...)`는 full draft/participants, expected series version과 UUID idempotency를 검증하고 새 immutable active revision을 만든다. effective boundary 이전 source slots는 byte-for-byte 보존하고 이후 non-exception slots만 rebuild/cancel/insert한다.
- interval 변경 fixture에서 future source partition은 rebuilt 183, cancelled 181, preserved exception 1, preserved past 3으로 정확히 나뉜다. matching slot identity는 재사용하고 obsolete row는 history를 위해 cancelled 상태로 남는다.
- update replay는 새 revision/change event를 만들지 않고 동일 compact result를 반환한다. key/payload conflict, stale version, one-time/ended target, outsider, removed/cross-household participant와 DST gap은 stable code로 원자적으로 거부된다.
- `cancel_recurring_calendar_series(...)`는 server household-local today부터 scheduled source/exception occurrence 184개를 취소하고 past 3개를 그대로 둔다. series는 ended lifecycle로 전진하며 deleted 상태가 아니므로 과거 v2 query는 이전 revision content를 계속 반환한다.
- `event_series_change_events`는 operation, old/new revision identifiers, local boundary, counts, version과 correlation만 저장하는 immutable public history다. active household member에게 RLS read-only이고 direct mutation grant는 없다.
- `calendar_series_change_command_requests`, `calendar_materialization_states`, `calendar_materialization_runs`는 private content-free storage다. run rows는 immutable하고 failure는 `invalid_recurrence`, `nonexistent_local_time`, `materialization_failed`만 기록한다.
- `run_calendar_horizon_worker(...)`는 horizon 30–365일, repair lookback 0–31일, batch 1–500으로 제한되고 `for update skip locked`로 active series를 claim한다. targeted fixture는 missing slot 1개를 repair하고 initial year 밖 5일을 확장해 6 changes를 기록하며 replay는 0이다.
- worker는 explicit moved exception을 version bump 없이 보존하고 count/until completion과 ended series를 제외한다. `pg_cron`은 매시 29분 bounded default worker를 호출하며 cron schema/table/function은 API roles에 열리지 않는다.

## Flutter Vertical Slice

- platform-free domain에 active series detail, whole-series update/cancel request와 strict compact result snapshot을 추가했다. result의 effective local date는 server household-local date와 정확히 같아야 한다.
- data source와 repository는 detail/update/cancel RPC exact-key envelope, UUID/date/time/count/version과 recurrence JSON을 fail closed로 해석한다. provider raw error/message는 domain이나 UI로 유출하지 않는다.
- controller는 visible series/version을 확인한 뒤 active revision detail을 별도로 읽는다. update/cancel은 stable fingerprint별 같은 command UUID를 재사용하고 성공 후 현재 page/month를 authoritative하게 다시 읽는다.
- recurring card에는 occurrence edit/cancel과 분리된 whole-series menu가 있다. 같은 series의 여러 occurrence가 한 화면에 있어도 control key는 occurrence identity로 고유하다.
- whole-series editor는 active revision content/participants/rule로 seed된다. 현재 UI가 직접 표현하지 않는 interval/end/multiple-weekday rule은 frequency를 바꾸지 않으면 exact typed rule을 보존한다.
- 전체 종료 확인은 “오늘과 이후 회차 취소, 과거 기록 보존” 범위를 명시한다. 사용자 문자열은 en/ko/en-XA ARB와 generated localization에만 있다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean `npx --no-install supabase db reset --local --yes` | PASS, ordered forward migration 23개와 synthetic seed 적용 |
| focused whole-series pgTAP | PASS, 64/64 |
| focused Calendar horizon worker pgTAP | PASS, 56/56 |
| focused WP04-04C pgTAP total | PASS, 120/120 |
| full pgTAP/RLS regression | PASS, 26 files, 1,527 tests; final clean-reset state에서 재실행 |
| strict DB lint | PASS, `public`, `app_private`, `extensions` warning/error 0 |
| focused Calendar Flutter tests | PASS, 69/69 |
| full Flutter regression | PASS, 432 tests + local-connectivity opt-in 1 skip |
| full Flutter coverage | PASS, 9,270/11,708 lines, 79.18% |
| exact formatter/analyzer | PASS, 257 files changed 0; fatal infos/warnings 포함 analyzer issue 0 |
| exact dependency replay | PASS, `flutter pub get --enforce-lockfile --offline` |
| localization/codegen | PASS, en/ko/en-XA generated drift 0/8 files |
| public config/secret scan | PASS, public config allowlist valid; high-confidence secret 0 |
| whitespace | PASS, `git diff --check` output 0 |

Focused DB fixtures는 table/column/FK/index/trigger, function signature/search path/grant, force RLS, unauthenticated/anonymous/outsider/cross-household denial, malformed/one-time/ended/stale/no-op, participant validation, DST gap atomicity, idempotency replay/conflict, immutable revision/history, exact past/future partition, exception preservation, active detail source, v2 past/future projection, bounded worker input, service-role isolation, skip-locked implementation, missing-slot repair, horizon extension/replay, end condition, state/run privacy와 immutability를 포함한다.

Focused Flutter fixtures는 active series detail/request/snapshot invariant, strict DTO/error mapping, full canonical request forwarding, controller authoritative load/update/cancel/refresh/same-key retry, stale active detail 차단, whole-series DST gap 선검증, exception card에서 active source seed, advanced rule preservation, distinct occurrence/series actions, confirmation copy와 multi-occurrence key uniqueness를 포함한다.

## Files and Contract Surfaces

- Database: `supabase/migrations/20260807150000_recurring_calendar_series_change_and_horizon.sql`
- Related lint cleanup: `supabase/migrations/20260807140000_recurring_calendar_occurrence_exceptions.sql`
- Database tests: `supabase/tests/database/recurring_calendar_series_change.test.sql`, `supabase/tests/database/calendar_horizon_worker.test.sql`
- Flutter domain/application/data/UI: `apps/kinflow_app/lib/features/calendar/`
- Supabase adapter: `apps/kinflow_app/lib/infrastructure/supabase/supabase_calendar_data_source.dart`
- Flutter tests: `apps/kinflow_app/test/features/calendar/`, `apps/kinflow_app/test/infrastructure/supabase_calendar_data_source_test.dart`, `apps/kinflow_app/test/support/fakes/fake_calendar_dependencies.dart`
- Contracts/matrices: `docs/contracts/database-schema.sql.md`, `docs/contracts/rls-contract.sql.md`, `docs/contracts/domain-events.yaml.md`, `docs/matrices/REQUIREMENTS_TRACEABILITY.csv.md`, `docs/matrices/TEST_MATRIX.csv.md`, `docs/matrices/TIME_RECURRENCE_TEST_MATRIX.csv.md`, `docs/matrices/RISK_REGISTER.csv.md`, `docs/matrices/RELEASE_CHECKLIST.csv.md`

## Data, Security, Privacy, and Platform

- 검증은 fresh local Supabase와 deterministic synthetic UUID/name/event content만 사용했다. production migration, 실제 계정/household, 고객 일정 또는 provider token은 사용하지 않았다.
- authenticated public series RPC는 security-definer와 empty search path를 사용하고 caller/household/participant/target/version을 서버에서 다시 검증한다. client가 보낸 날짜를 effective boundary로 신뢰하지 않는다.
- public change history는 force RLS/read-only이고 private command/worker tables에는 API role grant가 없다. worker execute는 service role만 가능하며 cron schema도 anon/authenticated/service role에서 직접 접근할 수 없다.
- private operational state와 audit에는 event content나 participant identity list가 없다. raw exception text 대신 stable error code만 남긴다.
- Flutter domain/application은 Flutter, Riverpod와 Supabase SDK를 import하지 않는다. provider SDK와 SQLSTATE mapping은 infrastructure adapter에 남는다.
- 새 runtime dependency, native permission, OS Calendar access, analytics payload, persistent device cache 또는 external network dependency를 추가하지 않았다.

## Manual and Deferred Validation

- 사용자 지시에 따라 실제 Google 성인 계정, 실제 household, Android/iOS 실기기와 성인 2계정·두 기기 whole-series edit/end propagation은 **NOT RUN**이다.
- production/remote Supabase migration, remote `pg_cron` wake, service-role execution, production-size cardinality/query plan/worker throughput과 alert는 **NOT RUN**이다.
- device timezone travel, actual OS locale/date picker, VoiceOver/TalkBack, background/resume와 push/display는 **NOT RUN**이다.
- Today Chore+Calendar partial-failure-safe composition은 **NOT IMPLEMENTED / NOT RUN**이며 WP04-05 범위다.
- Realtime multi-client stale/conflict/reconnect는 **NOT IMPLEMENTED / NOT RUN**이며 WP04-06 범위다.
- series change에 대응하는 domain outbox/notification intent는 이번 범위에 추가하지 않았고 Phase 05 notification integration에서 결정한다.

## Remaining Risks and Completion Boundary

1. worker의 bounded claim, replay와 failure isolation은 local deterministic fixture에서 검증됐지만 process termination 중 crash recovery, true concurrent remote workers, scheduler lag와 production alerting은 남았다.
2. UI는 frequency와 일반 event fields를 편집한다. interval, count/until, multiple weekdays를 직접 편집하는 control은 없으며 frequency를 유지할 때만 기존 advanced rule을 exact 보존한다.
3. whole-series 종료는 확인 뒤 되돌리기 UI/API가 없다. 종료된 series의 past history는 남지만 resume/restore 정책은 후속 결정이 필요하다.
4. whole-series update 중 미래 DST gap은 partial write 없이 전체 거부된다. 사용자가 문제 occurrence를 찾고 예외로 해결하도록 안내하는 UX는 아직 없다.
5. update/end 뒤 다른 기기의 즉시 동기화는 authoritative refetch만 구현했고 Realtime reconnect/conflict semantics는 WP04-06에 남아 있다.
6. Today composition, Realtime, remote scheduler/scale 및 real-account/device evidence가 없으므로 FR-CAL 전체, T-CAL-01, REL-014, Phase 04 또는 제품 목표를 완료로 표시하지 않는다.

WP04-04C 자체는 local automated whole-series/rolling-repair slice로 완료했다. Calendar product/release gate와 현재 장기 기능 목표는 이후 WP와 마지막 real-account/device 검증까지 `IN_PROGRESS/PARTIAL`을 유지한다.

## Rollback

- production 적용 전에는 WP04-04C migration, Flutter series actions/l10n/tests/contracts/evidence를 함께 revert하고 WP04-04B의 22-migration/1,407-pgTAP 및 419-Flutter baseline을 clean reset으로 확인한다.
- production 적용 후에는 applied migration을 수정하거나 삭제하지 않는다. corrective forward migration에서 cron job과 worker/series RPC execute를 revoke하고 client whole-series menu를 숨긴다.
- 이미 생성된 revision/change event/materialization state와 occurrence history는 파괴적으로 삭제하지 않는다. lifecycle이나 projection 문제는 series별 forward repair로 교정한다.

## Next Entry Condition

- 다음 기능 우선순위는 WP04-05 Today Chore+Calendar composition이다. 두 source는 같은 server household-local today를 사용하고 source별 실패가 다른 source content를 숨기지 않아야 한다.
- composition은 deterministic timed/all-day/chore order, bounded loading/refresh, partial failure와 stale 표시를 domain/controller/widget/DB contract 전체에서 고정해야 한다.
- 그 다음 WP04-06에서 expected-version conflict UI와 Realtime reconnect/full refetch를 닫는다.
- 실계정·두 기기·remote Supabase와 device timezone gate는 사용자 지시에 따라 기능 개발이 충분히 끝난 마지막 단계까지 유지한다.
