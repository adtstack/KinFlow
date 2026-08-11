# Phase 04 WP04-15 Calendar Series Cancellation From Selected Occurrence Work Plan

## Status

- 상태: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)** — WP04/G4 또는 P1 activation 완료는 아님
- 수직 조각: Calendar recurring occurrence → `이 회차부터 취소` → server-derived recurrence boundary → bounded terminal revision or immediate series end → authoritative Calendar reconciliation
- 요구사항: `FR-CAL-004`, `FR-CAL-005`, `FR-CAL-006`, `FR-CAL-011`, `NFR-SEC-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-063`
- 계약: `docs/contracts/calendar-series-cancel-from-occurrence.yaml.md`
- 증거: `docs/evidence/phase-04/WP04_15_EVIDENCE.md`
- 실제 계정, hosted Supabase, 두 기기, timezone boundary와 physical-device 검증은 사용자 지시에 따라 마지막 Gate로 유지한다.

## Product boundary

- active household member는 현재 Calendar page의 scheduled recurring non-exception 회차에서 `이 회차부터 취소`를 선택할 수 있다.
- 서버는 선택한 occurrence ID의 immutable `recurrence_local_start_date`를 경계로 사용한다. 화면 날짜와 클라이언트 날짜는 authority가 아니다.
- 경계 이전 occurrence와 explicit one-occurrence exception은 현재 content, time, participant, status와 recurrence identity를 유지한다.
- 경계 시점과 이후의 scheduled occurrence는 explicit exception 여부와 표시 날짜 이동 여부에 상관없이 immutable recurrence slot 기준으로 취소한다.
- 경계 이전 scheduled non-exception prefix가 남으면 source snapshot과 anchor를 복제한 `until = boundary - 1 day` terminal revision을 활성화한다. 남지 않으면 기존 전체 종료와 같은 ended state를 사용한다.
- 기존 오늘 경계 전체 시리즈 종료, 전체/선택 시리즈 수정과 한 회차 수정/취소는 유지한다. immediate process-memory Undo는 후속 `WP04-16`이 확장한다.

## DB/API and authority design

1. additive `cancel_recurring_calendar_series_from_occurrence` RPC는 occurrence ID와 exact series expected version만 받는다.
2. private shared engine은 series와 target occurrence를 lock하고 target이 active revision의 scheduled non-exception occurrence이며 immutable slot이 household-local 오늘 이후인지 검증한다.
3. selected command hash에는 target occurrence identity를 포함하되 legacy whole-series command name, normalized hash, public signature와 nine-field result는 그대로 유지한다.
4. boundary 이후 모든 non-cancelled occurrence를 취소한다. moved exception도 표시 날짜가 아닌 recurrence slot으로 판단하며 prefix exception은 수정하지 않는다.
5. prefix가 남으면 immutable terminal revision, revision participants, active denormalized series snapshot과 completed materialization state를 원자적으로 기록해 worker가 boundary 이후를 재생성하지 못하게 한다.
6. series-change replay/event shape는 cancellation의 optional terminal revision/materialized-through pair만 허용하도록 제한을 확장한다. 새 cutoff column, target identity column, RLS policy 또는 content-bearing audit field는 추가하지 않는다.

## Flutter design

1. selected-cancellation draft/request는 operation, household, series, occurrence, immutable slot과 expected series version을 retry fingerprint에 포함한다.
2. data source는 client boundary date를 보내지 않고 exact occurrence UUID만 additive RPC에 전달하며 optional terminal revision pair를 strict parse한다.
3. controller는 current page의 exact occurrence, active revision/version, scheduled recurring non-exception state와 future boundary를 mutation I/O 전에 재검증한다.
4. Calendar runtime policy는 command ID와 repository보다 먼저 확인하고 동일 입력 transient retry는 command ID를 재사용한다. target/input 변경은 새 key를 만든다.
5. UI는 한 회차 취소·전체 종료와 구분된 destructive confirmation을 표시하고 boundary 이후 explicit exception도 함께 취소된다는 사실을 저장 전에 고지한다.
6. success, stale version, invalid transition과 unavailable target은 authoritative current Calendar query reload로 수렴하며 성공 시 Today Calendar cache를 제거한다.

## Automated evidence plan

1. DB schema/grant/private-engine boundary, unauthenticated and cross-household denial
2. active revision/scheduled/non-exception/future target lock and server-derived recurrence boundary
3. prefix row and moved-prefix-exception exact preservation, boundary/later normal and moved-exception cancellation
4. terminal revision snapshot/participants/end rule, worker no-regeneration and no-prefix immediate ending
5. exact optimistic conflict, same-command replay, cross-operation/different-input collision, audit/state and legacy wrapper compatibility
6. strict domain fingerprint, repository payload/result parsing, malformed result failure and Today cache invalidation
7. controller exact target/revision/past/runtime gates, retry identity and authoritative reconciliation
8. menu/confirmation target mapping, exception/past action hiding, disclosure and EN/KO/EN-XA compact 200%
9. full DB/Flutter/Node regression, lint, analyzer, formatter, codegen, config, secret, docs, whitespace and Android dev compile

## Stop conditions and rollback

- client date가 boundary authority가 되거나 target occurrence가 active scheduled non-exception revision임을 서버가 확인하지 않으면 배포하지 않는다.
- prefix occurrence/exception의 recurrence identity, content, time, participant 또는 status가 바뀌거나 boundary 이후 moved exception이 남으면 배포하지 않는다.
- terminal revision의 종료 경계 이후 worker가 occurrence를 다시 scheduled로 만들거나 legacy whole-series hash/signature/result가 바뀌면 배포하지 않는다.
- rollback은 UI action과 Flutter adapter를 제거하고 additive RPC execute를 forward migration으로 revoke한다. legacy wrapper가 의존하는 private engine은 유지하거나 이전 body를 forward migration으로 복원한다.
- 이미 생성된 immutable terminal revision, cancellation state와 append-only audit/history는 삭제하거나 rewrite하지 않는다.

## Non-scope

- persistent cancellation history와 arbitrary historical resume beyond WP04-16, arbitrary end-date picker, occurrence resurrection
- ordinal/yearly/business-day/multiple-month-day recurrence와 split-series table
- provider account, remote account, hosted production size, two-device, timezone-boundary and physical-device evidence
