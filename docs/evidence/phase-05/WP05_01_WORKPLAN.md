# Phase 05 WP05-01 Notification Outbox Worker Workplan

- 상태: `LOCAL AUTOMATED COMPLETE (2026-08-08)` — remote scheduler·provider·real-account·real-device gate deferred
- 범위: 기존 content-free Chore notification outbox를 최소권한 worker가 lease로 claim하고, latest-state 평가를 멱등하게 durable candidate/suppression으로 확정하며, bounded retry·dead letter·manual replay·pause·queue health를 제공한다.
- 제외: notification preferences/quiet hours와 durable user inbox(WP05-02), FCM endpoint/token(WP05-03), 실제 push/permission/deep-link tap(WP05-04), hosted scheduler와 실계정·실기기 검증

## Requirements

| ID | 이번 slice의 수용 기준 |
|---|---|
| WP05-01 / FR-NOTIF-003 | source event 처리와 외부 send를 분리한다. worker는 claim 뒤 최신 occurrence/series/recipient를 다시 평가하고 actionable candidate 또는 allowlisted suppression을 durable하게 기록한다. |
| WP05-01 / FR-NOTIF-006 | source event별 결과는 한 번만 확정된다. attempt는 최대 5회, 서버 계산 exponential backoff+jitter 뒤 재시도하며 마지막 실패나 만료 lease는 dead letter가 된다. |
| D-022 / D-023 | 서버 outbox/worker가 알림 정확성의 권위이며 client background task나 앱 lifecycle에 의존하지 않는다. |
| NFR-REL-01 | `FOR UPDATE SKIP LOCKED`, expiring lease token, heartbeat, response-loss replay, expired lease reclaim, poison isolation, dead-letter replay를 결정적으로 검증한다. |
| NFR-SEC-01 / NFR-SEC-02 | anon/authenticated는 모든 worker API와 private tables에 접근할 수 없다. service role도 table/helper를 직접 읽거나 변경하지 않고 public security-definer worker API만 실행한다. |
| NFR-PRIV-01 | claim/health/transition은 event content·title·description·display name·email·token·raw error를 반환하거나 저장하지 않는다. worker error는 uppercase allowlist code로만 저장한다. |
| NFR-OBS-01 | content-free transition audit와 queue health가 ready/retry/leased/expired/dead-letter 수, oldest ready, next retry와 pause 상태를 제공한다. |
| NFR-COMP-01 | 기존 Chore mutation/RPC와 outbox producer envelope은 additive migration으로 유지한다. 새 dispatcher state는 기존 undispatched row를 `pending`으로 backfill한다. |

## Data and API Impact

- `app_private.chore_notification_outbox`에 `processing_status`, `max_attempts`, lease owner/token/expiry, `dead_lettered_at`, `replay_count`를 additive로 추가한다. 기존 `dispatched_at`, `attempts`, `next_attempt_at`, `last_error_code`는 호환 유지한다.
- `app_private.notification_event_resolutions`는 source event당 한 행으로 `candidate|suppressed` 결과를 저장한다. candidate는 category, subject/recipient IDs, schedule/timezone만 가지며 household content는 저장하지 않는다.
- `app_private.notification_worker_transitions`는 claim/retry/succeeded/dead-letter/replay 전환의 content-free immutable audit다.
- `app_private.notification_worker_control`은 `chore_notification_outbox` worker의 pause와 stable reason code를 보존한다.
- service-role-only public API:
  - `claim_chore_notification_events(worker_id, batch_size, lease_seconds, as_of)`
  - `heartbeat_chore_notification_event(event_id, lease_token, extend_seconds, as_of)`
  - `process_chore_notification_event(event_id, lease_token, as_of)`
  - `fail_chore_notification_event(event_id, lease_token, error_code, as_of)`
  - `replay_chore_notification_dead_letter(event_id, reason_code, as_of)`
  - `set_chore_notification_worker_paused(paused, reason_code, as_of)`
  - `get_chore_notification_queue_health(as_of)`
- pure server worker adapter는 claim → process를 순회하고 process transport/internal failure만 stable `WORKER_PROCESSING_FAILED`로 fail API에 전달한다. raw exception을 payload/result/log에 포함하지 않는다.

## Queue Semantics

1. `pending`, due `retry_wait`, expired `leased` 중 ready row를 stable occurred-at/event-id 순서로 `SKIP LOCKED` claim한다.
2. claim은 attempt를 증가시키고 opaque lease token을 발급한다. 최대 attempt에서 worker crash로 lease가 만료되면 다음 claim sweep가 dead letter로 전환한다.
3. heartbeat는 현재 token과 만료 전 lease만 최대 5분 범위 안에서 연장한다.
4. process는 token을 검증하고 기존 latest-state resolver를 실행한다. actionable은 candidate, stale/completed/skipped/cancelled/deleted/inactive/unresolved는 suppression으로 기록한다.
5. resolution insert와 outbox succeeded 전환은 한 transaction이다. 응답 유실 뒤 같은 process 재호출은 기존 resolution을 반환한다.
6. 실패는 attempt 기반 30초 exponential backoff(최대 1시간)와 event/attempt 기반 deterministic 0–15초 jitter를 사용한다. 최대 attempt는 즉시 dead letter다.
7. dead letter replay만 attempts를 0으로 되돌릴 수 있고 replay reason과 count를 immutable transition에 기록한다.
8. pause 중 claim은 빈 결과를 반환한다. 기존 lease process/heartbeat/fail은 마무리할 수 있어 강제 중단으로 인한 중복을 만들지 않는다.

## Verification

- schema/check/index/immutability/grants/security-definer/search-path exact pgTAP
- pending/due retry/expired lease ordering, two-worker `SKIP LOCKED`, token mismatch와 heartbeat expiry
- candidate와 every suppression reason, source-event dedupe와 response-loss process replay
- retry interval bounds/jitter, final attempt/dead letter, crashed final lease sweep, manual replay
- pause/resume, content-free health/transition audit, invalid/raw-shaped error rejection
- pure worker adapter success/failure/malformed RPC contract tests
- clean local reset, focused/full pgTAP and DB lint, unchanged full Flutter regression, repository CI/config/secret/whitespace checks

## Security and Privacy

- worker runtime만 service-role secret을 사용하며 mobile/web bundle과 client Provider에 추가하지 않는다.
- service role에는 private table/helper direct grants를 주지 않는다. public mediated functions는 exact bounded inputs와 empty search path를 사용한다.
- resolution은 routing identifier와 schedule만 저장한다. title, notes, member name, email, auth token, push token, receipt, provider body와 raw exception은 금지한다.
- queue health와 worker summary는 aggregate counts/timestamps만 반환하고 event/household/recipient identifiers를 노출하지 않는다.

## Rollback

- worker adapter를 중지하고 pause control을 켜면 새 claim을 즉시 막을 수 있다. 기존 business mutation과 outbox producer는 계속 동작한다.
- production 전에는 새 migration/tests/contracts를 함께 revert한다.
- production 후에는 applied migration을 수정하지 않는다. forward migration으로 worker APIs를 revoke/pause하고 새 columns/tables는 forensic evidence로 보존한다. source outbox rows나 Chore data를 삭제하지 않는다.

## Completion Boundary

- local automated lease/retry/dead-letter/replay/health와 pure worker orchestration이 green이면 WP05-01 local slice를 완료한다.
- actionable resolution은 아직 사용자 inbox나 push delivery가 아니다. preference/quiet hours/inbox는 WP05-02, endpoint/token은 WP05-03, FCM/permission/device는 WP05-04에 남긴다.
- remote scheduled invocation, production alert/dashboard와 실제 계정·실기기 검증은 사용자 지시에 따라 대다수 기능 개발 이후 마지막 gate에 남긴다.

## Result

- clean 25-migration reset, DB lint, focused 86 + concurrency 7 + predecessor 79 pgTAP과 full 29-file/1,658-test DB regression이 통과했다.
- pure worker/Edge contract 15개와 repository JS contract 62개가 통과했다.
- unchanged Flutter regression 464개 + opt-in 1 skip, analyzer 0, formatter 275 files/0 changed, coverage 79.29%가 통과했다.
- 상세 증거와 deferred/manual 경계는 `docs/evidence/phase-05/WP05_01_EVIDENCE.md`에 기록했다.
