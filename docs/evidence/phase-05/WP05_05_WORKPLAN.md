# Phase 05 WP05-05 Notification Reliability Workplan

- 상태: `LOCAL IMPLEMENTED (2026-08-08)`
- 범위: WP05-04 Android FCM delivery 위에 provider outage/backoff, accepted/completion-loss ambiguity, duplicate/out-of-order containment, stale suppression, aggregate queue/provider SLO와 operator recovery 계약을 추가한다.
- 제외: hosted scheduler/dashboard/pager, 실제 Firebase outage/quota injection, production traffic tuning, 실계정·실기기 중복/순서/OEM 검증, iOS/APNs, WP05-06 offline/read cache

## Requirements

| ID | 이번 slice의 수용 기준 |
|---|---|
| WP05-05 / FR-NOTIF-006 / NFR-REL-01 | exact lease/token marker가 provider I/O 전에 durable해야 한다. explicit provider rejection만 최대 5회 재시도하고, marker 이후 timeout·malformed success·completion loss는 terminal ambiguity로 격리해 자동/수동 duplicate replay를 금지한다. |
| WP05-05 / NFR-REL-01 | Retry-After, 30초 exponential delay, quota 최소 60초, delivery 기반 0–30초 jitter와 provider-wide backoff를 적용한다. 1시간 usefulness window 뒤에는 provider token을 반환하지 않고 stale cancellation한다. |
| WP05-05 / FR-NOTIF-003 / FR-NOTIF-004 | usefulness window는 quiet hours와 최신 preference/state를 통과해 provider delivery가 materialize된 시점부터 시작한다. permission/endpoint가 최근 no-endpoint 평가 뒤 복구되면 1시간 안에서 한 번 재평가한다. |
| WP05-05 / NFR-OBS-01 | service-only health가 pause/backoff, queue state, oldest ready, expired lease, ambiguity/permanent/stale 24시간 건수와 95% within-5m provider-submit SLO를 identifier 없이 반환한다. low volume은 3건 absolute miss와 stale 1건을 함께 본다. |
| WP05-05 / NFR-PRIV-01 / NFR-SEC-01 | provider health/transition에는 family content, household/member/subject ID, raw token, provider body/error/receipt를 저장하거나 반환하지 않는다. transition은 immutable이고 table direct access는 없다. |
| WP05-05 / NFR-COMP-01 | additive migration과 기존 claim/finalize HTTP surface를 유지하고 Edge response에는 aggregate field만 additive한다. hosted 적용 전 clean reset과 전체 DB/JS/Flutter 회귀를 통과한다. |

## Decisions

- ADR-0004에 따라 push는 durable inbox를 fallback으로 둔 best effort다. marker 이후 불확실성은 at-most-once bias로 terminal 처리한다.
- Android notification `tag=deliveryId`와 remaining-window TTL은 provider/client duplicate presentation을 줄이지만 server idempotency의 대체가 아니다.
- `ATTEMPTS_EXHAUSTED`만 expiry 전 operator replay가 가능하다. `FCM_SUBMISSION_AMBIGUOUS`, invalid token, configuration/request permanent failure, stale cancellation은 replay할 수 없다.
- provider backoff는 다음 invocation의 새 claim을 막는다. 이미 claim된 현재 batch를 adaptive하게 차단하는 circuit breaker는 실제 launch volume 지표 후 재검토한다.

## Data and API Impact

- migration: `supabase/migrations/20260808050000_notification_push_reliability.sql`
- `notification_push_deliveries`: `scheduled_at`, `expires_at`, `replay_count`, `submission_started_at`, `submission_lease_token`
- new private tables: content-free singleton `notification_push_provider_health`, immutable `notification_push_delivery_transitions`
- new service-role APIs:
  - `mark_notification_push_submission_started(...)`
  - `replay_notification_push_delivery(...)`
  - `reset_notification_push_provider_backoff(...)`
  - `get_notification_push_reliability_health(...)`
- extended service APIs:
  - claim returns schedule/deadline and refuses new work during provider backoff
  - complete accepts `ambiguous` and non-retryable request rejection
- endpoint insert/update trigger wakes only recent matching `no_endpoint` evaluations.

## Edge Impact

- contract version `2026-08-08-wp05-05`
- FCM send timeout floor 10 seconds
- OAuth success 뒤 FCM fetch 직전에 marker RPC
- timeout/malformed 2xx/hash failure → `FCM_SUBMISSION_AMBIGUOUS`
- documented 429/5xx → Retry-After or deterministic jittered backoff
- unknown non-retryable response → `FCM_REQUEST_REJECTED`
- payload remains content-free; Android notification tag is delivery ID and TTL is 1–3600 seconds remaining
- aggregate response adds `ambiguousCount` and `submissionStartedCount`

## Verification

- clean reset and DB lint
- WP05-05 focused 48 pgTAP plus WP05-04 focused 48 pgTAP
- Edge focused 21 tests plus repository JavaScript suite
- full DB regression, Flutter regression/analyzer/formatter/config/secret/dependency/workflow/OpenAPI/matrix/whitespace gates
- no actual Firebase account/provider/device invocation

## Rollback

- normal outage에는 provider backoff가 자동으로 새 claim을 늦춘다. recovery 확인 뒤에만 mediated reset을 사용한다.
- 긴급 rollback은 hosted scheduler를 먼저 중지한 뒤 기존 pause API로 active queue를 `ROLLBACK_DISABLED` 취소한다. 이 pause는 destructive queue cancellation이므로 단순 outage 회복에 사용하지 않는다.
- production 전에는 migration/Edge/contracts/tests를 함께 revert할 수 있다. production 적용 후에는 forward migration으로 execute revoke/정책 교체한다.

## Completion Boundary

- synthetic DB/Edge provider에서 ambiguity와 명시적 retry를 구분하고 stale/SLO/health가 deterministic하게 green이면 WP05-05를 `LOCAL IMPLEMENTED`로 기록한다.
- hosted alert wiring, Firebase console/provider traffic, 실계정·실기기와 incident drill은 사용자 지시에 따라 기능 개발 이후 마지막 Gate다.
