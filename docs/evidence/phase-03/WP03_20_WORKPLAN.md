# Phase 03 WP03-20 Chore Series Edit From Selected Occurrence Work Plan

## Status

- 상태: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)** — P1 activation과 WP03/G3 live Gate 완료는 아님
- 수직 조각: upcoming recurring chore → 선택 회차 이후 편집 → server-derived recurrence boundary → immutable revision rebuild → authoritative list reconciliation
- 요구사항: `FR-CHORE-005`, `FR-CHORE-008`, `FR-CHORE-012`, `NFR-SEC-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-060`
- 계약: `docs/contracts/chore-series-from-occurrence.yaml.md`
- 증거: `docs/evidence/phase-03/WP03_20_EVIDENCE.md` (검증 후 작성)
- 실제 계정, hosted Supabase, 두 기기와 physical-device 검증은 사용자 지시에 따라 마지막 Gate로 유지한다.

## Product boundary

- Owner/Admin은 upcoming 목록의 active scheduled 반복 회차에서 `이 회차부터 수정`을 선택할 수 있다.
- 서버는 선택한 occurrence ID의 immutable `recurrence_local_date`를 경계로 사용한다. 클라이언트 날짜는 authority가 아니다.
- 경계 이전 회차와 경계 이후 완료 회차는 기존 revision·content·completion actor와 함께 보존한다.
- 경계 이후 미완료 회차는 새 title, notes, assignee, time과 daily/weekly/monthly bounded rule로 재구성한다. 기존 한 회차 reschedule/reassign/skip은 새 기본값으로 초기화될 수 있음을 저장 전에 알린다.
- 기존 `오늘부터 시리즈 수정`, 한 회차 예외, 시리즈 취소는 유지한다. Calendar의 같은 기능과 선택 회차 이후 취소는 별도 work package다.

## DB/API and authority design

1. additive `update_repeating_chore_series_from_occurrence` RPC가 기존 series expected-version과 authenticated-user idempotency hash를 재사용한다.
2. RPC는 series와 target occurrence를 lock하고 target이 active revision의 scheduled repeating occurrence이며 recurrence slot이 가구-local 오늘 이후인지 검증한다.
3. 기존 canonical candidate generator와 stable occurrence identity를 그대로 사용해 경계 이후 matching incomplete row를 재사용하고 obsolete row를 cancel하며 365일 window를 materialize한다.
4. completed occurrence는 경계 이후라도 historical revision에 남기고 content-free aggregate event만 추가한다.
5. legacy 오늘-boundary RPC signature와 RLS/table grants는 바꾸지 않는다.

## Flutter design

1. domain draft는 occurrence ID, series version과 normalized full recurrence rule을 fingerprint에 포함한다.
2. data source와 repository는 exact additive RPC payload/response만 매핑하고 extra·missing·wrong-type output을 거부한다.
3. controller는 upcoming current query의 scheduled manageable occurrence만 허용하고 read-only cache와 runtime chores policy를 I/O 전에 차단한다.
4. 동일 입력 transient retry는 command ID를 재사용하고 입력이나 target occurrence 변경은 새 ID를 만든다. stale/invalid transition과 성공은 authoritative current query를 reload한다.
5. 기존 editor를 재사용하되 선택 항목 날짜를 최소 날짜/changed-frequency anchor로 사용하고 from-occurrence 전용 disclosure·성공 메시지를 EN/KO/EN-XA로 표시한다.

## Automated evidence plan

1. DB role, cross-household, one-time, completed/skipped/old-revision/past-boundary denial
2. target row/server boundary, previous occurrence and future completion preservation, future incomplete rebuild, exception reset
3. exact optimistic conflict, same-command replay, different-input collision, content-free audit and legacy RPC compatibility
4. strict Dart draft fingerprint, repository payload/result mapping, invalid payload failure
5. controller scope/view/status/runtime/read-cache gates, retry-key reuse/rotation and authoritative reconciliation
6. upcoming action/dialog request mapping, disclosure, failure/retry/success, EN/KO/EN-XA compact 200% layout
7. full DB/Flutter/Node regression, analyzer, formatter, codegen, config, secret, docs and Android dev debug compile

## Stop conditions and rollback

- client-supplied date가 boundary authority가 되거나 target occurrence가 active revision임을 서버가 확인하지 않으면 배포하지 않는다.
- 이전 회차 또는 완료 이력이 새 revision으로 이동하거나 삭제되면 배포하지 않는다.
- 같은 normalized retry가 새 command ID를 만들거나 다른 target/input이 이전 key를 재사용하면 배포하지 않는다.
- rollback은 UI action과 Flutter adapter를 제거하고 additive RPC execute를 forward migration으로 revoke한다. 이미 생성된 immutable revision과 occurrence history는 기존 reader와 worker가 계속 읽을 수 있다.

## Non-scope

- selected occurrence 이후 cancel, Calendar this-and-future
- ordinal/yearly/business-day recurrence와 series fork table
- later incomplete one-occurrence exception preservation
- provider, remote account, hosted production size, two-device and physical-device evidence
