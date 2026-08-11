# Phase 05 WP05-05 Notification Reliability Evidence

- Work Package: WP05-05 — provider outage/backoff, submission ambiguity, duplicate containment, stale suppression, aggregate queue/provider SLO
- 기준 commit: base `a85f262`; implementation은 2026-08-08 현재 WP02-06/WP03/WP04/Phase 05 연속 workspace
- 검증일: 2026-08-08
- 환경: macOS arm64, Node 24.15.0, npm 11.12.1, Supabase CLI 2.109.1, PostgreSQL 17 local stack
- 결과: **WP05-05 LOCAL AUTOMATED PASS / HOSTED·PROVIDER·REAL-ACCOUNT·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP05-05 / FR-NOTIF-006 / NFR-REL-01 | PASS FOR LOCAL SYNTHETIC RELIABILITY / OVERALL PARTIAL | exact lease/token submission marker를 provider I/O 직전에 durable하게 기록한다. 명시적 429/5xx만 bounded retry하고 marker 이후 timeout·malformed success·completion loss는 terminal ambiguity로 격리해 duplicate amplification을 막는다. 실제 FCM outage/acceptance는 남았다. |
| WP05-05 / FR-NOTIF-003 / FR-NOTIF-004 | PASS FOR LOCAL USEFULNESS POLICY / OVERALL PARTIAL | quiet hours와 최신 preference/state 뒤 materialization 시각부터 1시간 usefulness window를 적용한다. 만료 claim은 token을 반환하지 않고 stale cancellation하며 최근 `no_endpoint`는 endpoint 복구 시 window 안에서 한 번 재평가한다. 실제 사용자 timing 정책 검증은 남았다. |
| WP05-05 / NFR-OBS-01 | PASS FOR LOCAL AGGREGATE HEALTH / OVERALL PARTIAL | pause/backoff, ready lag, next retry, ambiguity/permanent/stale/expired lease 건수와 24시간 95%-within-5m submit SLO를 식별자 없이 반환한다. hosted dashboard/pager와 incident drill은 남았다. |
| WP05-05 / NFR-SEC-01 / NFR-SEC-02 / NFR-PRIV-01 | PASS FOR NEW SURFACE | private health/transition tables, service-only mediated APIs, immutable transition과 aggregate-only response를 검증했다. family content, household/member/subject ID, raw token, provider body/error/receipt는 새 저장·응답 surface에 없다. |
| WP05-05 / NFR-COMP-01 | PASS FOR LOCAL ADDITIVE CONTRACT / OVERALL PARTIAL | additive migration, 기존 claim/complete 함수 surface, N-1 Android payload envelope와 기존 Flutter parser를 유지하고 worker response에는 aggregate field만 추가했다. remote migration과 실제 N-1 binary rehearsal은 남았다. |

## Reliability Decision and Behavior

- ADR-0004에 따라 durable inbox를 권위 있는 fallback으로 유지하고 push provider 제출은 at-most-once 쪽으로 기울인다.
- worker는 OAuth 준비 뒤 FCM network I/O 직전에 `mark_notification_push_submission_started`를 호출한다. exact current lease와 token fingerprint만 marker를 기록할 수 있고 같은 marker 호출은 멱등이다.
- marker 전에 worker가 실패하면 lease expiry 뒤 안전하게 다시 claim할 수 있다. marker 이후 provider acceptance를 증명할 수 없는 timeout, malformed 2xx, receipt hash failure 또는 DB completion loss는 `FCM_SUBMISSION_AMBIGUOUS`로 terminal 처리한다.
- explicit 429/503/5xx만 재시도한다. `Retry-After`, 30초 exponential base, quota 응답의 최소 60초 fallback과 delivery ID 기반 0–30초 deterministic jitter를 적용한다.
- retry 또는 ambiguity는 provider-wide backoff를 연다. 새 invocation의 claim은 가장 긴 현재 backoff까지 멈추지만 이미 claim된 현재 batch는 계속 처리한다.
- `ATTEMPTS_EXHAUSTED`만 expiry 전 operator replay가 가능하다. ambiguity, stale, invalid token, auth/sender/decrypt/request permanent failure는 자동·수동 replay할 수 없다.
- Android notification `tag=deliveryId`로 동일 delivery 표시를 교체하고 provider TTL은 남은 usefulness window의 1–3,600초로 제한한다. 이는 server idempotency의 대체가 아니다.

## Database Contract

- `app_private.notification_push_deliveries`에 `scheduled_at`, `expires_at`, `replay_count`, `submission_started_at`, `submission_lease_token`을 additive하게 추가했다.
- content-free singleton `app_private.notification_push_provider_health`와 immutable `app_private.notification_push_delivery_transitions`를 추가했다. 두 table 모두 client와 service role direct access가 없다.
- public service-only wrapper는 기존 claim/complete signature를 보존하면서 schedule/deadline과 ambiguity 결과를 확장한다. legacy implementation은 `app_private`에 격리했다.
- expired marked lease는 재전송하지 않고 `FCM_SUBMISSION_AMBIGUOUS`로 종결한다. expired unmarked lease만 기존 안전 재처리 경로를 따른다.
- claim은 provider backoff 중 새 delivery를 반환하지 않으며 expiry에 도달한 delivery를 `STALE_DELIVERY_WINDOW`로 취소하고 token material을 반환하지 않는다.
- `reset_notification_push_provider_backoff`는 delivery를 변경하지 않는다. `replay_notification_push_delivery`는 `ATTEMPTS_EXHAUSTED`와 아직 유효한 deadline만 허용한다.
- endpoint insert/update trigger는 최근 같은 endpoint의 `no_endpoint` 평가만 한 번 깨워 과거 source의 무제한 소급 발송을 막는다.

## Edge and Provider Contract

- worker contract/meta version은 `2026-08-08-wp05-05`이고 Android payload envelope version은 N-1 parser 호환을 위해 `2026-08-08-wp05-04`로 유지했다.
- FCM request timeout은 최소 10초다. network timeout과 malformed success는 retryable timeout으로 위장하지 않고 ambiguity로 반환한다.
- unknown non-retryable 4xx는 `FCM_REQUEST_REJECTED` permanent 결과로 변환한다. invalid token, auth/sender mismatch와 decrypt/configuration failure의 기존 permanent 분류도 유지한다.
- claim timestamp parser는 strict UTC `Z`와 PostgREST `+00:00`을 허용한다. TTL 계산은 server deadline을 기준으로 하고 Android tag는 exact delivery ID다.
- worker 응답에는 `ambiguousCount`와 `submissionStartedCount`를 additive하게 추가한다. raw FCM token, ciphertext, provider body, receipt, credential 또는 exception detail은 반환하지 않는다.

## Observability and Runbook

- `get_notification_push_reliability_health(as_of)`는 `healthy|degraded|critical`과 stable alert code, pause/backoff, queue counts, `oldestReadyAt`, `nextRetryAt`, 최근 24시간 ambiguity/permanent/stale/expired lease 및 submit SLO aggregate를 한 행으로 반환한다.
- submit SLO는 정상 state/preference/endpoint 취소를 제외하고 materialization 뒤 5분 안 provider submit 95%를 목표로 한다. 20건 미만 low-volume에서도 absolute miss 3건 또는 stale 1건을 critical 후보로 본다.
- operator 순서, safe reset/replay, ambiguity non-replay, emergency destructive pause와 forward-only production rollback을 `WP05_05_RUNBOOK.md`에 고정했다.
- 이 SLO는 provider 제출 시점만 측정하며 OS 수신, 알림 표시, 사용자 열람을 증명하지 않는다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean local Supabase reset | PASS, ordered 29 migrations including `20260808050000_notification_push_reliability.sql` and synthetic seed |
| focused WP05-05 reliability pgTAP | PASS, 48/48 |
| prior WP05-04 push delivery pgTAP against new schema | PASS, 48/48 |
| full database regression | PASS, 34 files / 1,907 pgTAP tests |
| database lint | PASS, warning level with fail-on-error; schema error 0 |
| focused push reliability Edge/runtime contract | PASS, 21/21 |
| repository JavaScript contract suite | PASS, 97/97 |
| OpenAPI and matrix structure | PASS, OpenAPI 3.1 parses with 18 paths/31 schemas; API 34×6, billing 38×11, NFR 20×6, platform capability 20×12, platform DoD 55×8, release checklist 23×10, release gate 12×9, requirements 116×18, risk 30×15, RLS auth 266×12, spec trace 12×6, tests 62×11, time recurrence 30×12 |
| repository secret scan | PASS, high-confidence secret 0 |
| Flutter inherited baseline | NO MOBILE DELTA; immediately preceding WP05-04 full run remains 514 tests + local-connectivity opt-in 1 skip, 78.30% coverage, analyzer issue 0, formatter drift 0, Android dev APK PASS. WP05-05 변경은 DB/Edge/contracts/docs뿐이므로 full Flutter suite는 재실행하지 않았다. |
| whitespace | PASS, final `git diff --check` output 0 before evidence finalization; post-document check repeated |

Focused DB fixtures cover private schema/grants, marker exactness/idempotency, explicit retry/provider backoff/reset, ambiguity and replay denial, immutable transitions, stale deadline, low-volume/SLO alert, exhausted replay, request rejection, completion-loss lease expiry and recent no-endpoint wake-up.

Edge fixtures cover marker-before-fetch ordering, marker failure with zero provider calls, timeout/malformed success ambiguity, explicit quota/5xx retry, Retry-After and deterministic jitter, unknown 4xx permanent abort, 10-second timeout floor, remaining TTL/tag, PostgREST UTC offset and aggregate response.

## Files and Migration

- Migration: `supabase/migrations/20260808050000_notification_push_reliability.sql`
- Database tests: `supabase/tests/database/notification_push_reliability.test.sql`, updated `notification_push_delivery.test.sql`
- Edge contract/runtime/tests: `supabase/functions/_shared/notification_push_contract.mjs`, `notification_push_runtime.mjs`, `scripts/ci/notification-push-contract.test.mjs`
- Contracts: `docs/contracts/notification-push.yaml.md`, `database-schema.sql.md`, `rls-contract.sql.md`, `openapi.yaml`
- Decision/runbook: `docs/adr/ADR-0004-push-submission-ambiguity.md`, `docs/evidence/phase-05/WP05_05_RUNBOOK.md`
- Governance: Phase 05, consolidated implementation/master specs and requirement/test/risk/release/platform matrices

## Security, Privacy, and Data Impact

- transition과 provider health는 stable timing/outcome/count만 보존하며 family content, household/member/subject ID, raw token, token fingerprint, ciphertext, receipt 또는 provider raw response를 저장하지 않는다.
- delivery 내부 row에는 기존 endpoint/delivery identity와 cryptographic material이 남지만 direct table grant가 없고 service-only exact lease API로만 접근한다. public health 결과는 delivery ID도 포함하지 않는다.
- provider error는 allowlisted stable code로만 정규화하고 worker aggregate 응답과 runbook evidence에 credential/token/error body를 반사하지 않는다.
- submission ambiguity를 자동 replay하지 않아 duplicate family notifications를 줄인다. 가능한 miss는 durable inbox에서 확인하게 한다.
- 자동 검증은 synthetic UUID/token/receipt와 fake provider/local Supabase만 사용했다. production credential, 고객 계정, 가족 데이터 또는 실제 Firebase project는 사용하지 않았다.

## Manual and Deferred Validation

- 사용자 지시에 따라 실제 Google/Firebase 계정, staging/production Firebase project, service-account secret injection, remote Supabase migration/Edge deployment와 hosted scheduler는 **NOT RUN**이다.
- 실제 FCM quota/outage/Retry-After, provider accepted 뒤 network loss, hosted completion loss와 dashboard/pager alert delivery/incident drill은 **NOT RUN**이다.
- physical Android의 duplicate/out-of-order/TTL/tag/OEM battery behavior, foreground/background/terminated 수신과 알림 shade/open은 **NOT RUN**이다.
- 실계정 permission/endpoint recovery와 한 시간 usefulness 정책의 사용자 기대 검증은 **NOT RUN**이다.
- iOS/APNs는 D-021 Android Store MVP 범위 밖이며 별도 ADR 전에는 구현·완료로 주장하지 않는다.

## Remaining Risks and Completion Boundary

1. marker commit 뒤 실제 FCM request 전에 worker가 종료되면 이미 보낸 것으로 보수 처리되어 push miss가 생길 수 있다. duplicate amplification을 피하는 의도적 tradeoff이며 durable inbox가 fallback이다.
2. 첫 retryable 결과가 provider backoff를 열어도 이미 claim된 현재 batch는 계속 제출한다. adaptive in-batch circuit breaker는 실제 launch volume/latency 지표 뒤 조정한다.
3. hosted scheduler, dashboard, pager와 incident drill이 없어 local aggregate health가 실제 운영 alert 전달을 증명하지 않는다.
4. 한 시간 usefulness window와 low-volume alert threshold는 제품 정책 기본값이며 Beta 관찰 후 조정이 필요하다.
5. submit SLO는 FCM API 제출까지만 측정한다. device delivery/display/open과 OEM별 background 제한은 마지막 실기기 Gate다.
6. WP05-06 offline/read cache와 Phase 05 상위 Exit Gate가 남아 전체 기능 목표는 계속 `PARTIAL`이다.

WP05-05 자체는 local synthetic DB/Edge reliability slice로 완료했다. 실제 provider·실계정·실기기 검증은 사용자 지시에 따라 대부분의 기능 개발 뒤 마지막 Gate에 유지한다.

## Rollback

- 일반 provider outage에는 자동 backoff를 사용하고 recovery 확인 뒤에만 mediated reset을 호출한다. destructive pause를 단순 outage 회복에 사용하지 않는다.
- 긴급 rollback은 hosted scheduler를 먼저 중지하고 `set_notification_push_worker_paused(true, 'ROLLBACK_DISABLED', ...)`로 active queue를 명시적으로 취소한다.
- production 적용 전에는 migration, Edge runtime/contracts/tests와 문서를 함께 revert할 수 있다.
- production 적용 후 applied migration을 수정·삭제하지 않는다. forward migration으로 execute revoke, policy/function 교체와 corrective worker를 배포한다.

## Next Entry Condition

- 다음 기능 우선순위는 Phase 05 WP05-06 offline/read cache다.
- user/account/household/session/version/TTL namespace를 fail closed하게 검증하는 stale read cache와 logout/account-switch/membership-removal purge를 먼저 만든다.
- offline mutation은 별도 안전성 수용 기준을 통과할 때만 one chore-completion outbox PoC로 제한하며, 위험하거나 가치가 낮으면 read-only cache로 유지한다.
- 실제 Firebase project·실계정·실기기 검증은 계속 마지막 Gate에 둔다.
