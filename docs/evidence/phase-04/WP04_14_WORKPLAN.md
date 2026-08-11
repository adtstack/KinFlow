# Phase 04 WP04-14 Calendar Series Edit From Selected Occurrence Work Plan

## Status

- 상태: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)** — WP04/G4 또는 P1 activation 완료는 아님
- 수직 조각: Calendar recurring occurrence → `이 회차부터 수정` → server-derived recurrence boundary → immutable revision rebuild with exception preservation → authoritative Calendar reconciliation
- 요구사항: `FR-CAL-004`, `FR-CAL-005`, `FR-CAL-006`, `FR-CAL-010`, `NFR-SEC-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-062`
- 계약: `docs/contracts/calendar-series-from-occurrence.yaml.md`
- 증거: `docs/evidence/phase-04/WP04_14_EVIDENCE.md` (전체 회귀 후 작성)
- 실제 계정, hosted Supabase, 두 기기, timezone boundary와 physical-device 검증은 사용자 지시에 따라 마지막 Gate로 유지한다.

## Product boundary

- active household member는 현재 Calendar page의 scheduled recurring non-exception 회차에서 `이 회차부터 수정`을 선택할 수 있다.
- 서버는 선택한 occurrence ID의 immutable `recurrence_local_start_date`를 경계로 사용한다. 클라이언트 날짜는 authority가 아니다.
- 경계 이전 occurrence와 경계 이후 explicit one-occurrence exception은 기존 revision·content·time·participant·cancel state와 함께 그대로 보존한다.
- 경계 이후 non-exception source slot은 새 title, description, participant, time/all-day shape와 daily/weekly/monthly bounded rule로 재구성한다.
- 기존 `오늘부터 전체 시리즈 수정`, 한 회차 수정/취소와 전체 시리즈 종료는 유지한다. 선택 회차 이후 Calendar 취소는 별도 work package다.

## DB/API and authority design

1. additive `update_recurring_calendar_series_from_occurrence` RPC는 occurrence ID와 existing full recurring update payload를 받는다.
2. private shared engine은 series와 target occurrence를 lock하고 target이 active revision의 scheduled non-exception occurrence이며 recurrence slot이 household-local 오늘 이후인지 검증한다.
3. selected command의 normalized hash에 target occurrence identity를 넣되 legacy command는 이전 command name과 exact hash shape를 유지한다.
4. 기존 canonical candidate generator와 stable occurrence identity를 사용해 matching non-exception row를 reuse/rebuild하고 obsolete row를 cancel하며 selected boundary부터 365일 window를 materialize한다.
5. 이전 occurrence와 모든 explicit exception은 update/cancel/repoint하지 않고 aggregate count만 content-free series-change state에 기록한다.
6. 기존 public `update_recurring_calendar_series` signature와 result는 shared engine의 null-target wrapper로 유지하고 table/column/RLS policy는 추가하지 않는다.

## Flutter design

1. selected-boundary domain draft는 operation, household, series, occurrence, immutable local slot, expected version과 normalized full recurring draft를 retry fingerprint에 포함한다.
2. data source는 client date를 보내지 않고 exact occurrence UUID와 existing recurring payload만 additive RPC에 전달한다.
3. controller는 current page의 exact occurrence, series/revision/version, scheduled recurring non-exception state와 future boundary를 mutation I/O 전에 재검증한다.
4. Calendar runtime policy는 command ID와 repository보다 먼저 확인하고 동일 입력 transient retry는 command ID를 재사용한다. target/input 변경은 새 key를 만든다.
5. 기존 series editor를 재사용하되 selected slot을 initial/minimum date와 overlap preview window start로 사용하고 all-day span을 유지한다.
6. success, stale version, invalid transition과 unavailable target은 authoritative current Calendar query reload로 수렴한다.

## Automated evidence plan

1. DB schema/grant/private-engine boundary, unauthenticated and cross-household denial
2. active revision/scheduled/non-exception/future target lock and server-derived recurrence boundary
3. earlier row preservation, selected identity reuse, obsolete slot cancellation, explicit exception exact preservation and view projection
4. exact optimistic conflict, same-command replay, cross-operation/different-input collision, audit/state and legacy wrapper compatibility
5. strict domain boundary/fingerprint, repository payload/result parsing, malformed result failure and Today cache invalidation
6. controller exact target/revision/past/runtime gates, retry identity and authoritative reconciliation
7. menu/editor target mapping, locked minimum date, exception action hiding, disclosure and EN/KO/EN-XA compact 200%
8. full DB/Flutter/Node regression, lint, analyzer, formatter, codegen, config, secret, docs, whitespace and Android dev compile

## Stop conditions and rollback

- client date가 boundary authority가 되거나 target occurrence가 active non-exception revision임을 서버가 확인하지 않으면 배포하지 않는다.
- 이전 occurrence 또는 explicit exception이 새 revision으로 이동하거나 내용·시간·상태가 바뀌면 배포하지 않는다.
- legacy whole-series request hash/signature/result가 바뀌거나 같은 normalized retry가 새 command ID를 만들면 배포하지 않는다.
- rollback은 UI action과 Flutter adapter를 제거하고 additive RPC execute를 forward migration으로 revoke한다. 이미 생성된 immutable revision과 occurrence history는 기존 reader와 worker가 계속 읽을 수 있다.

## Non-scope

- selected occurrence 이후 Calendar cancel, explicit edit undo/resume
- ordinal/yearly/business-day/multiple-month-day recurrence와 series fork table
- provider account, remote account, hosted production size, two-device, timezone-boundary and physical-device evidence
