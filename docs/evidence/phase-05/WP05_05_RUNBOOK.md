# WP05-05 Push Reliability Runbook

이 문서는 hosted 배포 전 검토용이다. 아래 운영 동작은 로컬 synthetic state에서만 계약 검증됐으며 production/staging Firebase나 실제 사용자 계정에는 실행하지 않았다.

## Signal

service-role 운영 경계에서 현재 시각으로 `get_notification_push_reliability_health(as_of)` 한 행을 읽는다. 결과는 identifier 없이 다음 stable state 중 하나다.

| health / alert | 의미 | 첫 대응 |
|---|---|---|
| `healthy / OK` | ready lag, active backoff, 최근 ambiguity/permanent/stale alert 없음 | scheduler 유지 |
| `degraded / PROVIDER_BACKOFF_ACTIVE` | explicit 429/5xx 또는 ambiguity 뒤 보호 backoff | 자동 만료를 기다리고 FCM status/quota 확인 |
| `degraded / AMBIGUOUS_SUBMISSION` | marker 뒤 accepted 여부를 증명할 수 없음 | 자동/수동 replay 금지, durable inbox 정상 여부 확인 |
| `degraded / EXPIRED_LEASE` | marker 전 worker crash/lease lag | worker/scheduler 상태 확인; claim sweep가 안전하게 재처리 |
| `critical / PROVIDER_CONFIGURATION_FAILURE` | 최근 auth/sender/request/decrypt permanent failure | scheduler 중지, secret/package/project/key version 확인 |
| `critical / PROVIDER_SUBMIT_SLO_BREACH` | oldest ready 5분 초과, stale 1건, 3건 absolute miss 또는 충분한 표본에서 95% 미달 | scheduler/provider/DB 상태를 함께 조사하고 필요 시 rollback |
| `critical / WORKER_PAUSED` | rollback pause 활성 | pause 사유와 승인자 확인; 자동 resume 금지 |

## Safe Triage Order

1. raw token, ciphertext, provider body, receipt, household/member/subject ID를 로그나 ticket에 복사하지 않는다.
2. hosted scheduler invocation 성공률과 Edge aggregate response만 확인한다. `unrecordedCompletionCount`가 증가하면 DB availability/timeout을 먼저 본다.
3. `providerBackoffActive=true`이면 backoff 만료 전 강제 invocation이나 병렬 worker 증설을 하지 않는다.
4. FCM status, project quota, service-account scope, restricted Android package와 keyring version을 secret manager/console에서 확인한다.
5. durable inbox materialization과 unread access가 정상인지 확인한다. push 누락 시 사용자의 권위 있는 fallback이다.
6. health의 `oldestReadyAt`, `nextRetryAt`, 24시간 ambiguity/permanent/stale/SLO counts로 영향 시간을 판단한다. 식별자 단위 조회는 승인된 private operational tooling 밖으로 내보내지 않는다.

## Recovery

- explicit provider outage가 끝나고 FCM/credential 상태가 정상임을 확인한 경우에만 `reset_notification_push_provider_backoff(as_of)`를 호출한다. 이 함수는 delivery를 변경하지 않는다.
- `ATTEMPTS_EXHAUSTED` delivery는 usefulness deadline 전이고 latest state가 여전히 유효한 경우에만 승인된 operator가 `replay_notification_push_delivery(delivery_id, as_of)`를 호출할 수 있다.
- `FCM_SUBMISSION_AMBIGUOUS`는 provider가 이미 수락했을 가능성이 있으므로 replay하지 않는다. durable inbox로 복구하고 aggregate ambiguity를 incident evidence로 남긴다.
- `STALE_DELIVERY_WINDOW`, invalid token, sender/auth/request/decrypt permanent result도 replay하지 않는다. 각각 최신 앱 상태, endpoint refresh 또는 configuration correction으로 다음 source event부터 회복한다.
- 최근 `no_endpoint`는 permission/token registration이 1시간 안에 복구되면 trigger가 한 번 재평가한다. 과거 stale source를 임의 소급 발송하지 않는다.

## Emergency Stop / Rollback

1. hosted scheduler를 중지한다.
2. 단순 provider outage가 아니라 duplicate storm, credential compromise 또는 rollback이 필요한지 확인한다.
3. 긴급 rollback이면 `set_notification_push_worker_paused(true, 'ROLLBACK_DISABLED', as_of)`를 호출한다. 이 동작은 pending/retry/leased delivery를 취소하므로 recovery backoff 용도로 사용하지 않는다.
4. Firebase client public options를 disable하면 새 device token binding은 unavailable adapter로 fail closed하고 durable inbox는 유지된다.
5. production migration 적용 후 schema를 되돌려 삭제하지 않는다. forward migration으로 API execute를 revoke하고 corrective worker를 배포한다.

## Exit Criteria

- provider backoff가 만료 또는 승인된 reset으로 해제됨
- 새 synthetic provider submit 성공과 queue lag 5분 미만
- 새 ambiguity/permanent/stale 증가 없음
- durable inbox 정상
- incident timeline, stable alert/count, release/environment만 기록되고 family content/credential/token/provider raw body가 없음

실제 hosted alert/pager 연결과 outage drill 결과는 release evidence에서 별도로 승인한다.
