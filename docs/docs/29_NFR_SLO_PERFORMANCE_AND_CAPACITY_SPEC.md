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
