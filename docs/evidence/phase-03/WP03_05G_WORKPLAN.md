# WP03-05G Work Plan — Repeating series future edit and termination

- 상태: COMPLETE — LOCAL AUTOMATED PASS / REMOTE·REAL-ACCOUNT LIVE DEFERRED
- 범위: Store MVP의 “전체 반복 항목 변경”과 “시리즈 종료”를 가구 현지 오늘 경계의 원자적·멱등 명령으로 제공한다.
- 실제 성인 계정·2기기·remote Supabase 검증은 사용자 지시에 따라 기능 개발 후 마지막 gate로 유지한다.

## 요구사항과 결정

| ID | 이번 slice의 수용 기준 |
|---|---|
| FR-CHORE-005 | 새 immutable revision이 canonical daily/weekly/monthly rule, local time, 기본 담당자와 content snapshot을 보유한다. |
| FR-CHORE-006 | 수정 직후 가구 현지 오늘부터 365일 bounded horizon을 재계산하고 worker coverage를 reset한다. stable recurrence date는 중복을 막는다. |
| FR-CHORE-008 | 전체 시리즈 변경은 미래 미완료 occurrence만 새 revision으로 rebuild하고 과거 occurrence와 모든 completed occurrence를 보존한다. 종료는 미래 미완료 occurrence를 cancelled로 만들고 history를 삭제하지 않는다. |
| D-019 | series identity, immutable revision, recurrence slot, materialized occurrence state와 audit를 분리한다. |
| D-020 | Store MVP에는 서버가 산출한 “현재 시점 이후의 전체 시리즈”만 제공한다. 사용자가 임의 effective boundary를 보내는 “이번 이후” API는 만들지 않는다. |
| NFR-SEC-01 | active owner/admin만 mediated RPC를 실행한다. member/outsider/anon과 direct table mutation은 거부한다. |
| NFR-REL-01 | expected series version, per-user command UUID, request hash와 row lock으로 retry/concurrent edit를 안전하게 처리한다. |
| NFR-OBS-01 | content-free immutable change event에 actor, operation, boundary, version과 aggregate counts만 기록한다. |

## 기능 계약

1. `update_repeating_chore_series`는 command UUID, household/series, expected series version, 정규화된 title/description, active assignee, local time과 canonical repeating rule을 받는다.
2. effective boundary는 client input이 아니라 `statement_timestamp()`를 series timezone으로 변환한 local date다.
3. 현재 active revision과 입력이 동일한 no-op, one-time/deleted series, stale version, invalid rule/time/assignee는 변경 전에 거부한다.
4. 새 revision number는 row lock 아래 단조 증가하며 이전 revision은 update하지 않는다. title/description도 revision에 snapshot해 과거 표시가 최신 series content에 의해 바뀌지 않게 한다.
5. occurrence의 `recurrence_local_date`는 one-off reschedule과 독립적인 원래 recurrence slot이다. 경계 이전 occurrence와 status가 `completed`인 occurrence는 revision, content, due, assignee, status, version과 audit를 그대로 보존한다.
6. 경계 이후 현재 revision의 미완료 occurrence 중 새 rule에 포함되는 slot은 같은 occurrence ID/key를 유지한 채 새 revision 기본값으로 rebuild한다. 포함되지 않는 slot은 삭제하지 않고 `cancelled`로 보존한다. 새 slot만 insert한다.
7. `cancel_repeating_chore_series`는 active series를 soft-delete하고 경계 이후 현재 revision의 미완료 occurrence를 `cancelled`로 전이한다. 과거와 completed occurrence, revision, exception/audit row는 보존한다.
8. update/cancel은 private command record와 public immutable content-free change event를 같은 transaction에 기록한다. replay는 최초 결과를 `changed=false`로 반환하고 다른 input 재사용은 거부한다.
9. update는 현지 오늘부터 최대 365일까지 즉시 materialize한 뒤 private worker state를 삭제해 다음 worker가 active revision 기준 coverage를 다시 확정하게 한다. cancel도 stale worker state를 삭제한다.

## Client surface

1. Today DTO는 series version, canonical rule, 기본 담당자/local time과 서버가 산출한 `can_manage_series`를 strict parse한다.
2. owner/admin의 scheduled repeating item 메뉴에 “전체 반복 항목 변경”과 “반복 종료”를 노출한다. member에게는 노출하지 않고 서버도 다시 거부한다.
3. 변경 dialog는 현재 title/notes/default assignee/local time/rule을 prefill한다. 기존 frequency를 유지하면 full canonical rule을 보존하고, frequency를 바꾸면 가구 현지 오늘에 anchor된 interval-1/never rule을 만든다.
4. destructive confirm은 오늘 이후 미래 미완료 항목이 바뀌며 과거·완료 이력은 유지된다는 범위를 ARB 문자열로 설명한다.
5. 성공 후 Today를 authoritative reload한다. stale/invalid transition도 reload해 최신 series version과 occurrence set을 복구한다.

## 자동 검증

- schema/grant/RLS/privacy/immutable revision and event contract
- owner/admin success; member/outsider/anon/direct mutation denial
- request normalization, invalid rule/time/assignee, one-time/deleted/no-op/stale rejection
- update idempotency replay and conflicting key; cancel replay after soft delete
- past scheduled/skipped/rescheduled/reassigned and all completed rows preserved
- future matching occurrence identity reuse/reset, obsolete cancellation, new slot insertion and unique-key safety
- title/description revision snapshot history; all-day/timed timezone result
- count/until/month-end/weekly rules, worker state reset and replay/worker compatibility
- concurrent expected-version winner/loser behavior
- Dart domain/parser/repository/controller/widget tests, formatter, analyzer and full regression

## 배포 중단 조건과 rollback

- 과거 또는 completed occurrence가 수정/삭제되거나 revision/event audit가 mutable이면 배포하지 않는다.
- member/outsider가 전체 series mutation을 실행하거나 client가 effective boundary를 조작할 수 있으면 배포하지 않는다.
- retry가 revision/version/event를 중복 증가시키거나 worker가 old revision을 다시 materialize하면 배포하지 않는다.
- production 적용 후 migration을 수정·삭제하지 않는다. 두 RPC execute grant와 UI action을 먼저 회수하고 forward migration으로 active revision/materializer를 교정한다. 이미 생성된 revision, occurrence와 audit는 삭제하지 않는다.

## 완료 경계

이 slice가 green이어도 persistent exception history/detail, Today upcoming/overdue/completed filter, notification hook, remote scheduler와 실제 계정·2기기 검증이 남으므로 WP03 또는 전체 목표를 완료로 표시하지 않는다.
