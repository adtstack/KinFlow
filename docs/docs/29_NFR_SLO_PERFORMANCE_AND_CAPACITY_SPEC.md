# 29. NFR, SLO, 성능, 용량 스펙

- 상태: PROVISIONAL, Beta 측정 후 수치 승인

## 1. 대표 데이터 규모

MVP 성능 fixture:

- household당 active member 2~10
- managed member 0~8
- active chore series 0~200
- event series 0~500
- materialized occurrence 1년 window
- 계정당 household 1~5

과도한 enterprise 규모를 선제 최적화하지 않지만 N+1과 무제한 payload를 허용하지 않는다.

## 2. Client 성능 budget

| 지표 | 목표 예시 |
|---|---|
| warm start to usable shell p95 | ≤ 1.5s representative device |
| cold authenticated Today p95 | ≤ 3.0s stable network |
| interaction frame | 60fps target, visible jank 없음 |
| chore complete perceived feedback | ≤ 150ms optimistic/pending 표시 |
| release Android binary size | baseline 대비 변화 Gate |
| memory | low-memory device에서 task 완료, leak 없음 |

## 3. Server budget

| 지표 | 목표 예시 |
|---|---|
| Today API p95 | ≤ 800ms |
| simple mutation p95 | ≤ 700ms |
| invite accept p95 | ≤ 1.5s |
| entitlement materialization | 99% ≤ 10m |
| notification provider submit | 95% scheduled ±5m |

정확한 정의에는 region/network/cache/data volume을 포함한다.

## 4. Availability와 reliability

- core authenticated read 99.9% monthly target
- critical mutation 99.5% excluding user error
- no silent data loss
- outbox/worker at-least-once + idempotent consumer
- notification push는 best effort, inbox가 durable record

## 5. Capacity

- launch household/user forecast
- daily occurrence materialization량
- push job peak (아침/저녁 local time)
- webhook burst
- DB connection/function concurrency
- storage/export size

Beta 전 load test model과 비용 alarm을 설정한다.

## 6. Mobile network

- payload pagination/compression
- app resume targeted refetch
- reconnect thundering herd jitter
- timeout/cancellation
- retry budget
- large avatar/media는 MVP 비범위

## 7. Battery

- persistent polling 금지
- Realtime screen/lifecycle scoped
- background task 최소화
- server scheduled notification
- location 없음

## 8. Accessibility NFR

- screen reader task success
- text scale 200%
- orientation/split view
- minimum target/contrast
- keyboard/focus for Web/tablet
- motion reduction

## 9. Localization NFR

- EN/KO 100% key coverage
- pseudo locale CI/screenshot
- locale-independent API/date storage
- IANA timezone
- first day/calendar formatting locale-aware
- RTL structural check before RTL locale launch

## 10. Privacy/Security NFR

- household isolation test 100%
- secret scan 0 high
- PII logging test
- deletion/export documented SLA
- backup/restore drill
- dependency critical CVE release Gate

## 11. SLO 운영

각 SLO는 numerator/denominator, exclusions, source, owner, alert, review cadence를 갖는다. 사용자 기반이 작을 때 비율만으로 alert하지 않고 절대 건수와 synthetic test를 함께 사용한다.

### Android push provider-submit SLO

- target: provider delivery가 quiet hours/current preference/latest state를 통과해 materialize된 시점부터 5분 안에 FCM accepted 95%
- rolling local primitive: 최근 24시간 중 관찰 시각 5분 이전에 eligible해진 delivery
- exclusions: preference/latest-state/endpoint 변화로 정상 취소된 delivery. `STALE_DELIVERY_WINDOW`는 miss에 포함한다.
- low-volume trigger: 비율 표본이 20건 미만이어도 miss 3건 또는 stale suppression 1건이면 critical 후보
- degraded trigger: active provider backoff, ambiguity 1건 또는 expired lease
- source: `get_notification_push_reliability_health`; raw token, household/member/subject/delivery identifier와 provider body는 dashboard/alert에 금지
- owner/runbook: backend operator / `docs/evidence/phase-05/WP05_05_RUNBOOK.md`
- production status: local aggregate contract only. hosted dashboard/pager와 실제 outage drill은 release Gate다.

### Billing reconciliation health baseline

- local signal: queued, leased, retry-wait, dead-letter, 최근 24시간 succeeded/dead-letter, expired lease, oldest due와 next retry aggregate
- retry primitive: 최대 5 attempts; 첫 네 실패는 1분, 5분, 30분, 2시간 뒤 재시도하고 마지막 실패는 terminal dead letter
- periodic repair: active persisted household assignment가 있는 stale RevenueCat customer만 bounded enqueue하며 active job이 있으면 중복 생성하지 않음
- privacy: provider event/customer/transaction/product ID, subscriber attribute, receipt와 raw webhook/API body는 queue health·transition·alert에 금지
- source: `get_billing_reconciliation_health`; worker response도 scheduled/claimed/succeeded/retry/dead-letter count만 포함
- production status: local synthetic contract only. hosted cron, dashboard/pager, 실제 RevenueCat latency/outage와 10분 materialization target은 마지막 Billing Gate에서 측정·승인

### Billing assignment safety baseline

- purchase/restore preflight: Store 호출 전에 authenticated Owner/Admin의 explicit assignment prepare가 terminal outcome을 반환해야 함
- provisional bound: 30분 뒤 만료하며 verified transaction 없이는 Plus grant·periodic reconciliation 대상이 아님
- concurrency: user + household advisory lock과 active unique indexes로 동시 선택에서 최대 하나만 `ready`
- conflict safety: customer/household conflict에서 Store call 0, implicit release/transfer 0, 반대편 identifier leakage 0
- recovery: same identity/environment `ASSIGNMENT_REQUIRED`만 idempotent requeue; immutable transition 필수
- support: expected version + allowlisted reason + SHA-256 case reference + correlation ID 없이 resolution 금지; source reset과 target move는 atomic
- production status: local pgTAP/Flutter synthetic contract only. provider ownership, hosted cleanup/operator workflow, Store account/reinstall/device는 마지막 Billing Gate
