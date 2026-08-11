# WP04-04C Work Plan — Whole Recurring Calendar Series Change and Horizon Repair

- 상태: LOCAL AUTOMATED COMPLETE (remote·real-account·real-device gate deferred)
- 범위: FR-CAL-006 전체 시리즈 향후 수정·종료, TIME-018/TIME-019, exception-aware rolling materialization repair
- 선행 조건: WP04-04A recurring create/materialization, WP04-04B single-occurrence edit/cancel local automated baseline
- 후속 범위: Today Chore+Calendar composition은 WP04-05, Realtime multi-client conflict는 WP04-06, remote·real-account·device gates는 기능 개발 후 마지막 단계다.

## 요구사항과 수용 기준

| ID | 수용 기준 |
|---|---|
| FR-CAL-006 / TIME-018 | 전체 시리즈 수정의 effective boundary는 client 날짜가 아니라 server-derived household local today다. boundary 이전 occurrence의 revision/content/status/time identity는 바뀌지 않고 boundary 이후 non-exception occurrence만 새 immutable active revision으로 rebuild된다. |
| FR-CAL-006 | 전체 시리즈 종료는 series를 future-ended 상태로 만들고 boundary 이후 scheduled occurrence를 취소한다. 과거 occurrence/revision/history row는 삭제하거나 변경하지 않으며 과거 Calendar 조회에 남는다. |
| TIME-019 | future single-occurrence exception은 series update와 rolling repair가 revision, local projection, cancelled marker 또는 occurrence version을 덮어쓰지 않는다. 새 rule에서 source slot이 사라져도 explicit exception은 보존한다. |
| D-019/D-020 | series/revision/occurrence/exception 분리를 유지하고 Store MVP는 “이번 회차”와 “전체 시리즈”만 제공한다. arbitrary “이번 이후” boundary를 UI/API에 추가하지 않는다. |
| NFR-REL-01 | series update/cancel은 expected series version과 UUID idempotency를 사용한다. worker는 bounded window, `skip locked`, unique slot과 repair state를 사용해 retry/concurrent run에 안전하다. |
| FR-CAL-004 | rolling worker는 active recurring series를 household/event timezone local intent와 PostgreSQL resolver로 current local date + bounded horizon까지 확장한다. DST gap은 partial write 없이 content-free failure state로 관찰 가능하다. |
| NFR-SEC-01 / NFR-PRIV-01 | commands는 JWT actor와 active household/participant를 다시 검증한다. worker는 service-role only이며 command/change/run/state storage에는 title, description, display name 또는 participant list를 복제하지 않는다. |
| NFR-COMP-01 | additive columns/tables/RPC와 새 read endpoint를 사용하며 legacy one-time CRUD/list/v1, recurring create/single-exception/v2 page/month signatures를 유지한다. |

## DB/API 영향

1. `event_series`에 nullable `ended_at`과 `ended_effective_local_date`를 additive하게 추가한다. 종료는 soft delete와 구분해 과거 occurrence 조회를 보존하며 active materialization만 중지한다.
2. `app_private.calendar_revision_candidate_dates(...)`는 anchor에서 365일로 제한하지 않고 요청 window 자체를 최대 397 local dates로 제한한다. count/until/month-end semantics는 기존 strict recurrence contract를 유지한다.
3. `app_private.materialize_calendar_revision_window(...)`는 expected active slots를 insert하거나 non-exception stale projection만 조건부 repair한다. 동일 projection replay는 0이고 exception row가 있는 occurrence는 update conflict target에서 제외한다.
4. `update_recurring_calendar_series(...)`는 full recurring draft와 participants를 검증하고 새 immutable active revision을 만든다. household-local today 이전 row와 모든 exception row는 보존하고 미래 non-exception matching slots는 reuse/rebuild, removed slots는 cancel, new slots는 insert한다.
5. `cancel_recurring_calendar_series(...)`는 household-local today 이후 scheduled rows만 cancel하고 series lifecycle을 ended로 전진시킨다. past rows/revisions/exceptions는 보존한다.
6. `get_recurring_calendar_series(...)`는 editor에 필요한 active revision snapshot과 household-local effective boundary만 exact-key envelope로 반환한다. occurrence exception content를 series editor seed로 오인하지 않는다.
7. `run_calendar_horizon_worker(...)`는 service-role only, bounded batch/repair lookback/horizon, `for update skip locked`, per-series state와 immutable run summary를 사용한다. `pg_cron` hourly schedule은 API role에 cron schema 권한을 열지 않는다.
8. public series change event는 content-free history와 RLS read-only access를 제공한다. private idempotency/worker state에는 identifiers, digest, counts, stable error code와 timestamps만 저장한다.

## Flutter 영향

1. platform-free active series detail, update/cancel request와 compact command snapshot/result types를 추가한다.
2. repository/controller는 active series detail을 authoritative하게 읽고 occurrence exception row의 display snapshot과 분리한다.
3. update/cancel은 series version optimistic concurrency와 same-key retry를 사용하고 성공 후 현재 page/month를 authoritative하게 refresh한다.
4. recurring card는 occurrence actions와 별도로 localized whole-series menu를 제공한다. destructive confirmation은 “가구 현지 오늘 이후” 범위와 과거 보존을 명시한다.
5. whole-series editor는 active revision content/participants/rule로 seed되고 recurrence scope를 명시한다. 현재 UI가 표현할 수 없는 advanced rule은 필드를 바꾸지 않으면 exact rule을 보존한다.
6. 새 사용자 문자열은 en/ko/en-XA ARB와 generated localization을 통해서만 제공한다. raw provider error나 stack trace를 표시하지 않는다.

## 자동 검증

- pgTAP series change: schema/FK/index/trigger/RLS/grants, unauthenticated/anonymous/outsider/cross-household denial, malformed/one-time/ended/stale/no-op, participant/DST, idempotency replay/conflict, immutable revision, past preservation, future rebuild/cancel, exception preservation, v2 page/month and legacy regression.
- pgTAP worker: signature/search path/service-role only, invalid inputs, target/all-series batch, horizon extension, replay=0, repair missing slot, exception non-overwrite, ended exclusion, state/run privacy, failure isolation/retry schedule, skip-locked concurrency where deterministic.
- Flutter: series detail/request/snapshot invariants, exact DTO and error mapping, repository mapping, controller load/update/cancel/refresh/same-key retry/stale/time validation, whole-series menu/editor/confirmation, active-series seed for exception card, Korean/pseudo/200% regression.
- clean database reset, focused/full pgTAP, strict DB lint, Flutter focused/full test, analyzer/formatter, lockfile replay, l10n/codegen drift, config/secret and whitespace checks.

## 보안·개인정보

- public lifecycle/change event tables는 force RLS/read-only authenticated household access다. direct user mutation grant는 없다.
- security-definer commands는 empty search path, JWT-derived actor와 server-side membership/participant validation을 사용한다.
- worker execute는 service role만 가능하고 cron schema/table/function은 API roles에 revoke 상태를 유지한다.
- command replay/change event/materialization state/run에는 content와 participant identity list를 저장하지 않는다. stable error code 외 raw exception text를 저장하지 않는다.
- 새 native permission, OS Calendar access, analytics payload, persistent device cache 또는 runtime dependency를 추가하지 않는다.

## Rollback

- production 적용 전에는 04C migration, Flutter series action/UI/l10n, tests/contracts/evidence를 함께 revert하고 04B의 22-migration/1,407-pgTAP 및 419-Flutter baseline을 clean reset으로 확인한다.
- production 적용 후에는 applied migration을 수정·삭제하지 않는다. corrective forward migration으로 cron job과 worker/series RPC execute를 revoke하고 client whole-series menu를 숨긴다.
- 이미 생성된 revision/change event/materialization state와 occurrence history는 파괴적으로 삭제하지 않는다. lifecycle column은 forward correction으로 해제하거나 series별 repair한다.

## Stop 조건

- past source slot이 변경되거나 future exception revision/status/version이 series update/worker replay로 바뀌면 출시하지 않는다.
- whole-series cancel이 past Calendar row를 숨기거나 삭제하면 출시하지 않는다.
- retry가 duplicate revision/event/occurrence를 만들거나 concurrent worker가 같은 series를 이중 처리하면 출시하지 않는다.
- cross-household participant/RLS bypass, service-role worker grant 노출, content-bearing private state, DST partial write 또는 v1/v2 regression이 있으면 WP04-05로 진입하지 않는다.

## 완료 판단

04C가 green이어도 Today composition, overlap hint, Realtime conflict/reconnect, remote production-size execution과 real-account/two-device/device-timezone validation이 남으므로 Phase 04와 전체 제품 목표를 완료로 표시하지 않는다.
