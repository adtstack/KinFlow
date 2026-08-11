# WP03-07 Work Plan — Chore notification event hooks

- 상태: COMPLETE (LOCAL AUTOMATED SLICE) / PUSH·DURABLE INBOX·REAL-ACCOUNT LIVE DEFERRED
- 범위: occurrence 생성과 due/status/assignee 변화가 발생한 동일 DB transaction에서 content-free, versioned notification outbox event를 기록하고 Phase 05 consumer가 최신 occurrence·recipient 상태를 재검증할 수 있는 resolver 및 inbox payload 계약을 고정한다.
- 실제 notification intent/job 생성, preference/quiet hours, durable inbox/read state, FCM endpoint·delivery와 permission UI는 Phase 05 범위다.

## 요구사항과 결정

| ID | 이번 slice의 수용 기준 |
|---|---|
| WP03-07 | due/assignment domain event가 모든 기존 chore mutation/materialization 경로에서 빠짐없이 transactionally 기록되고 inbox consumer contract가 문서화된다. |
| FR-NOTIF-003 (FOUNDATION) | intent 생성과 send를 분리할 수 있도록 due/assignment 변화 event와 latest-state resolver를 제공한다. 실제 reminder intent/job/send는 Phase 05다. |
| FR-NOTIF-006 (EVENT DEDUPE) | event ID와 `(household, type, occurrence, aggregate version)` unique key로 replay·중복 trigger 결과를 dedupe한다. provider receipt/retry cap은 Phase 05다. |
| FR-NOTIF-007 (CONTRACT) | assignment와 due category를 versioned vocabulary로 고정한다. 사용자 preference UI는 Phase 05다. |
| D-019 | materialized occurrence가 알림 subject의 stable aggregate이며 series/revision definition과 분리된다. |
| D-022 | 기기 local schedule이 아니라 서버 DB outbox가 알림 파이프라인의 권위 있는 입력이다. |
| D-023 | client background task나 app lifecycle은 event 생산의 정확성에 관여하지 않는다. |
| NFR-SEC-01 | anon/authenticated/service-role direct table access를 주지 않고 consumer resolver도 public API로 노출하지 않는다. 향후 worker grant는 별도 Phase 05 migration이다. |
| NFR-PRIV-01 | event payload는 UUID/date/instant/timezone/status만 허용하고 title, description, display name, email, token, auth subject와 raw error를 포함하지 않는다. |
| NFR-REL-01 | insert/update trigger가 기존 create/materializer/exception/completion/series-change transaction과 원자적으로 동작하며 late/out-of-order event는 latest-state resolver에서 current 여부를 판정한다. |
| NFR-COMP-01 | append-only table/trigger/function/contract 추가이며 기존 RPC signature와 Flutter client를 변경하지 않는다. |

## Database와 producer 계약

1. `app_private.chore_notification_outbox`를 추가한다. envelope은 UUID event/correlation, event type/version, household, optional actor, occurrence aggregate/version, exact typed payload, UTC occurred-at과 future dispatcher state를 가진다.
2. event vocabulary는 `chore.occurrence_due_changed`와 `chore.occurrence_assigned` version 1이다. aggregate type은 `chore_occurrence`로 고정한다.
3. due payload exact keys는 `dueLocalDate`, `dueAt`, `timezone`, `status`다. assignment payload exact keys는 `assigneeMemberId`, `status`다. payload에 free-form household content를 저장하지 않는다.
4. `AFTER INSERT OR UPDATE` occurrence trigger는 insert 때 두 event를 만들고, update 때 due local date/instant/timezone/status가 바뀌면 due event를, assignee가 바뀌면 assignment event를 만든다.
5. occurrence version trigger 이후의 `NEW.version`을 aggregate version으로 사용한다. 동일 aggregate version/type unique key가 duplicate 생산을 막는다.
6. authenticated RPC 안에서는 session `auth.uid()`와 active member를 optional actor로 기록한다. service-role worker/materializer처럼 session actor가 없으면 actor fields는 null이다.
7. command replay가 mutation을 다시 실행하지 않으면 새 event도 만들지 않는다. materializer `ON CONFLICT DO NOTHING`은 기존 occurrence에 duplicate insert event를 만들지 않는다.
8. envelope/payload는 dispatcher state 외 update를 거부한다. API role에는 read/write/delete privilege를 주지 않으며 privileged retention/delete 정책은 Phase 05에서 별도로 고정한다.

## Consumer와 inbox 계약

1. `app_private.resolve_chore_notification_event(event_id)`는 event와 현재 occurrence/series/recipient를 다시 읽어 current/deliverable 여부를 계산한다.
2. due event는 같은 occurrence/type 중 최신 event이고 payload의 due date/instant/timezone/status가 현재 occurrence와 모두 같을 때 current다. 현재 assignee를 recipient로 사용한다.
3. assignment event는 같은 occurrence/type 중 최신 event이고 payload assignee/status가 현재 occurrence와 같을 때 current다. payload assignee를 recipient로 사용한다.
4. active series, scheduled occurrence, active adult recipient와 recipient auth user가 모두 존재할 때만 `should_create_intent=true`다.
5. stale, inactive series, non-scheduled, inactive recipient는 allowlisted suppression reason으로 반환한다. content와 provider error는 반환하지 않는다.
6. resolver는 private security-definer가 아니라 internal SQL function으로 두고 모든 API role execute를 revoke한다. Phase 05 worker는 별도 mediated claim/evaluator RPC를 통해 사용한다.
7. `contracts/domain-events.yaml.md`에 두 event를 추가하고 `notification-inbox.yaml.md`에 future inbox item/version/category/dedupe/minimal payload/read-state/deep-link refetch 규칙을 기록한다.
8. inbox contract는 title/name/notes snapshot을 요구하지 않는다. client는 household/occurrence ID만 받아 로그인·active household·resource 권한을 재검증한 뒤 authoritative content를 조회한다.

## 자동 검증

- exact table columns/checks/FK/unique/index, private grants와 immutable envelope
- one-time/repeating creation에서 due+assignment event, command replay duplicate 0
- initial materializer와 trusted actor-null insert를 통해 row-level producer가 호출 경로와 무관하게 동작함을 확인
- reschedule, complete/reopen, skip/restore, series rebuild/cancel에서 due event
- reassign과 assignee column change에서 assignment event
- event type/version/aggregate/version, optional actor와 exact payload privacy
- latest-state resolver current/deliverable, stale due/assignment, completed/skipped/cancelled/deleted series, removed recipient
- anon/authenticated/service-role direct select/insert/update/delete/execute denial
- existing pgTAP/RLS/Flutter regression, formatter/analyzer, config/secret/codegen, contract drift와 whitespace

## 배포 중단 조건과 rollback

- business mutation이 성공했는데 필요한 event가 없거나 event insert 실패가 mutation과 분리되면 배포하지 않는다.
- replay/materializer repair가 duplicate event를 만들거나 out-of-order resolver가 stale event를 deliverable로 표시하면 배포하지 않는다.
- payload에 title, description, display name, email, auth user ID, token 또는 raw error가 포함되면 배포하지 않는다.
- production 적용 전에는 migration/contract/tests/evidence를 함께 revert하고 이전 16-migration/966-test baseline을 clean reset으로 확인한다.
- production 적용 후에는 applied migration을 수정·삭제하지 않는다. occurrence trigger를 먼저 disable하는 forward migration으로 생산을 멈추고, 기존 outbox row는 forensic/replay evidence로 보존한 채 corrective migration을 적용한다.

## 완료 경계

이 slice가 green이어도 notification rule/job worker, preferences/quiet hours, durable inbox/read state, device registration, FCM delivery, deep link, provider outage와 실제 계정·기기 검증이 남으므로 FR-NOTIF와 전체 목표를 완료로 표시하지 않는다.
