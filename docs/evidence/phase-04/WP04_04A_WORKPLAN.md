# WP04-04A Work Plan — Recurring Calendar Creation and Materialization

- 상태: LOCAL AUTOMATED SLICE COMPLETE (후속 04B/04C 및 live/device gate 대기)
- 범위: FR-CAL-004의 daily/weekly/monthly 반복 생성, immutable recurrence source intent, bounded server materialization, mixed one-time/recurring agenda·day·month reads
- 후속 범위: single occurrence edit/cancel은 WP04-04B, future/whole-series edit/cancel과 repair worker는 WP04-04C, Today composition은 WP04-05다.

## 요구사항과 수용 기준

| ID | 수용 기준 |
|---|---|
| FR-CAL-004 | canonical recurrence JSON은 daily/weekly/monthly, interval 1–30, never/count/until end만 허용하고 unknown/duplicate/locale-dependent 값을 거부한다. |
| FR-CAL-004 | timed occurrence는 각 local recurrence date와 pinned IANA timezone에서 서버가 다시 resolve한다. UTC instant에 고정 간격을 더하지 않으며 DST 전후에도 local wall time을 보존한다. |
| FR-CAL-004 | all-day occurrence는 date-only half-open span을 유지하고 timezone/instant를 저장하지 않는다. |
| FR-CAL-004 | 생성은 UUID idempotency, active household membership, same-household active participant 검증과 content-free command/audit storage를 사용한다. |
| FR-CAL-005 foundation | occurrence는 immutable recurrence local date와 unique household occurrence key를 가지며 materialization replay가 중복 row를 만들지 않는다. |
| FR-CAL-007 | 신규 v2 view RPC는 one-time과 recurring occurrence를 같은 overlap/order/cursor/month-count 계약으로 반환하고 v1 RPC는 N-1 one-time 동작을 유지한다. |
| D-019/D-047 | series/revision/occurrence를 분리하고 recurrence domain은 Flutter/Riverpod/provider SDK에 의존하지 않는다. |

## DB/API 영향

1. Calendar 전용 strict recurrence validator와 recurrence candidate/materialization private functions를 추가한다.
2. occurrence에 immutable recurrence slot date를 expand/backfill하고 recurring revision content snapshot 및 revision participant snapshot을 추가한다.
3. `create_recurring_calendar_event(...)` authenticated command를 추가한다. 최초 window는 anchor date부터 최대 366 calendar dates로 제한한다.
4. `get_calendar_event_page_v2(...)`와 `get_calendar_month_summary_v2(...)`를 추가한다. 기존 v1 functions/signatures는 변경하지 않는다.
5. public family tables는 force RLS/read-only grant, private helper·idempotency tables는 API role 접근 금지를 유지한다.

## Flutter 영향

1. platform-free recurrence rule/draft/snapshot과 recurring occurrence metadata invariant를 추가한다.
2. strict data-source DTO/provider adapter/repository/controller command 경계를 추가한다.
3. 생성 editor에서 once/daily/weekly/monthly를 선택하고 recurring badge/rule summary를 agenda/day/month occurrence에 표시한다.
4. 04A에서 recurring edit/delete를 one-time RPC로 잘못 보내지 않도록 명시적으로 차단한다. scope 선택은 04B/04C에서 활성화한다.

## 자동 검증

- pgTAP: strict rule, auth/RLS/grants, idempotency, participant boundary, daily/weekly/monthly, count/until/month-end, timed DST spring/fall wall time, all-day span, mixed v2 views, replay uniqueness.
- Flutter: recurrence value objects, strict DTO mapping, provider RPC parameters, controller refresh/idempotent retry, create editor and recurring card/accessibility/pseudo-locale behavior.
- clean database reset, focused/full pgTAP, DB lint, Flutter analyze/test/format, config/secret/codegen checks.

## 보안·개인정보

- 서버가 JWT actor, household membership과 participant membership을 다시 판정한다.
- command/audit storage에 title, description, display name, recurrence participant identity list를 복제하지 않는다.
- recurrence JSON에는 locale 문자열, device timezone, resolved instant 또는 사용자 콘텐츠를 저장하지 않는다.
- 새 native permission, OS Calendar access, analytics payload, persistent event cache를 추가하지 않는다.

## Rollback

- production 적용 전에는 WP04-04A migration, v2 client adapter, recurrence UI/tests/contracts/evidence를 함께 revert하고 WP04-03의 20-migration/1,261-pgTAP 및 392-Flutter baseline을 clean reset으로 확인한다.
- production 적용 후에는 migration을 수정하지 않는다. forward migration으로 recurring create EXECUTE와 v2 app selection을 disable하고 one-time v1 path를 유지한다.

## Stop 조건

- occurrence가 fixed UTC addition으로 생성되거나 local wall time/all-day date span이 DST·travel semantics에서 변하면 출시하지 않는다.
- replay duplicate, cross-household participant, RLS bypass, malformed recurrence acceptance 또는 one-time v1 regression이 있으면 04B로 진입하지 않는다.

## 완료 판단

04A가 green이어도 occurrence exception, series edit/cancel, rolling repair worker, Today composition, conflict/Reconnecting Realtime, remote·real-account·two-device·device-travel 검증이 남으므로 FR-CAL/Phase 04/전체 제품 목표를 완료로 표시하지 않는다.
