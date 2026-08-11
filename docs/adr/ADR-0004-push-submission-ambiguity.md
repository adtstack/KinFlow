# ADR-0004 — Push submission ambiguity와 bounded retry

- 상태: ACCEPTED
- 작성일: 2026-08-08
- 결정일: 2026-08-08
- 결정자: Product owner direction / Engineering
- 관련 요구사항: WP05-05, FR-NOTIF-006, NFR-REL-01, NFR-OBS-01
- 관련 결정: D-021, D-022, D-023, D-049
- 관련 위험: RISK-008, RISK-009, RISK-015
- 대체 ADR: 없음

## Context

FCM HTTP v1 응답이 `429` 또는 `5xx`로 돌아오면 provider가 요청을 거절했다는 사실을 확인할 수 있어 backoff 뒤 재시도할 수 있다. 반면 요청 전송 뒤 network timeout, 성공 응답 파싱 실패 또는 FCM accepted 뒤 DB completion 유실은 provider 수락 여부를 증명할 수 없다. FCM send API에는 KinFlow delivery key를 이용한 idempotent submit이나 receipt 조회가 없으므로 같은 token에 자동 재전송하면 중복 알림을 만들 수 있다.

KinFlow에서 push는 best effort이고 durable inbox가 권위 있는 기록이다. 따라서 불확실한 push 하나를 놓치는 비용보다 같은 가족 알림을 반복 노출해 신뢰를 잃는 비용이 더 크다. 동시에 명시적으로 거절된 요청은 Firebase가 권고하는 Retry-After, exponential backoff와 jitter를 따라 제한적으로 재시도해야 한다.

## Decision Drivers

- provider accepted 뒤 completion 유실에서도 자동 중복 submit 방지
- durable inbox와 push best-effort 경계 유지
- FCM quota/outage 중 retry amplification 방지
- quiet hours 이후에도 오래된 알림을 무기한 전달하지 않음
- content-free aggregate로 low-volume SLO와 운영 상태 판정
- 실제 Firebase 계정 없이 DB/Edge fake provider로 결정적 검증

## Options Considered

### Option A — 모든 timeout을 at-least-once 재시도

- 장점: 일시적 network 오류에서 provider submit 성공 확률이 높다.
- 단점: accepted/completion-loss window에서 동일 알림이 반복될 수 있고 FCM은 application idempotency key나 message receipt lookup을 제공하지 않는다.
- 운영 영향: 장애 중 retry amplification과 duplicate storm 위험이 가장 크다.

### Option B — provider I/O 전 durable marker + ambiguity terminalization

- 장점: marker 이후 결과가 불명확하면 자동 재전송하지 않아 duplicate storm을 제한한다. 사용자에게는 durable inbox가 남는다.
- 단점: marker commit 뒤 실제 network call 전 process가 죽으면 보내지 않은 push도 ambiguous로 간주되어 누락될 수 있다.
- 운영 영향: ambiguity alert를 조사하되 자동 replay는 금지한다.

### Option C — client/provider 추정 dedupe만 사용

- 장점: server state가 단순하다.
- 단점: background OS presentation, terminated state와 provider accepted/completion-loss를 server가 증명하지 못한다. Android notification tag는 drawer replacement일 뿐 submit idempotency가 아니다.

## Decision

1. Option B를 채택한다. worker는 유효 token과 OAuth access token을 얻은 뒤 FCM network I/O 직전에 exact delivery/lease/token fingerprint submission marker를 DB에 기록한다.
2. `429`, `500`, `503`처럼 explicit provider response가 있는 오류만 retryable이다. `Retry-After`를 우선하고, 없으면 30초 exponential delay를 사용한다. quota fallback은 최소 60초이며 delivery ID 기반 0–30초 deterministic jitter를 더한다.
3. marker 이후 network timeout, malformed success, receipt hashing 실패 또는 completion loss는 `FCM_SUBMISSION_AMBIGUOUS` terminal failure다. 자동 replay와 operator replay 모두 금지한다.
4. marker 전 OAuth/DB 준비 실패는 provider 호출 없이 retryable로 남긴다.
5. 명시적 retry가 5회 소진된 `ATTEMPTS_EXHAUSTED`만, 1시간 usefulness window 안에서 service-role operator가 한 번의 새 bounded attempt sequence로 replay할 수 있다.
6. delivery usefulness window는 quiet-hours/current preference/latest-state 평가를 통과해 provider row가 materialize된 시점부터 1시간이다. claim 시 만료됐으면 `STALE_DELIVERY_WINDOW`로 취소하고 FCM에는 남은 초만 TTL로 보낸다.
7. Android notification `tag`는 delivery ID다. 같은 delivery가 provider transport에서 중복되더라도 notification drawer에서 교체 가능하도록 하되 이를 server idempotency의 대체로 보지 않는다.
8. explicit retryable 결과는 다음 retry instant까지 provider-wide backoff를 연다. health API는 queue counts, oldest ready, expired lease, ambiguity/permanent/stale counts, 24시간 provider-submit 5분 SLO와 stable alert code만 반환한다.
9. SLO 목표는 eligible delivery의 95%가 materialized provider schedule 기준 5분 이내 accepted다. low volume에서는 비율만 사용하지 않고 3건 absolute miss 또는 1건 stale suppression도 alert 근거로 사용한다.

## Consequences

### Positive

- accepted/completion-loss가 lease expiry 뒤 자동 duplicate submit으로 바뀌지 않는다.
- quota/outage가 모든 delivery의 동시 재시도로 증폭되지 않는다.
- stale push와 provider TTL이 같은 server usefulness deadline을 공유한다.
- alert와 runbook이 raw token, family content, delivery/household ID 없이 동작한다.

### Negative / Debt

- marker와 network call 사이 crash는 실제 미전송이어도 ambiguous terminal이므로 push 누락 가능성이 있다. durable inbox가 의도된 fallback이다.
- provider-wide backoff는 현재 batch에서 이미 claim된 나머지 send를 중단시키지 않는다. launch volume과 hosted metrics를 보고 adaptive circuit breaker 필요성을 재검토한다.
- 자동 aggregate alert primitive만 있으며 hosted scheduler/dashboard/pager 연결과 incident drill은 마지막 운영 Gate에 남는다.
- FCM Data API/BigQuery export를 쓰지 않으므로 device delivery/open SLO가 아니라 provider submit SLO만 측정한다.

## Implementation

- migration: `20260808050000_notification_push_reliability.sql`
- DB: submission marker, stale deadline, provider backoff, immutable transitions, bounded replay, aggregate health/SLO
- Edge: marker callback, 10초 send timeout, Retry-After/exponential jitter, dynamic TTL, notification tag, ambiguity result
- feature flag/kill switch: 기존 `set_notification_push_worker_paused`와 scheduler disable
- runbook: `docs/evidence/phase-05/WP05_05_RUNBOOK.md`

## Validation

- pgTAP: explicit retry/backoff, marker idempotency, completion-loss ambiguity, stale expiry, replay allow/deny, no-endpoint wake, aggregate alert, immutable audit와 privilege boundary
- Edge: marker-before-send, marker failure no-send, timeout/malformed success ambiguity, quota fallback+jitter, unknown 4xx abort, dynamic TTL/tag와 aggregate-only response
- actual provider/device: 사용자 지시에 따라 마지막 Gate로 연기

## Rollback / Revisit Trigger

- rollback: scheduler를 중지하고 push worker를 `ROLLBACK_DISABLED`로 pause한다. durable inbox/source event는 유지한다.
- production migration 적용 후에는 기존 migration을 수정하지 않고 forward migration으로 claim/marker/finalize execute를 revoke하거나 정책을 교체한다.
- 재검토: ambiguity가 provider submit의 0.5%를 초과, durable inbox open fallback이 충분하지 않음, duplicate support report, FCM idempotency/receipt-query 기능 출시, 또는 provider-wide backoff로 5분 SLO가 반복 실패할 때.

## Sources reviewed on 2026-08-08

- <https://firebase.google.com/docs/cloud-messaging/scale-fcm>
- <https://firebase.google.com/docs/cloud-messaging/error-codes>
- <https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages>
