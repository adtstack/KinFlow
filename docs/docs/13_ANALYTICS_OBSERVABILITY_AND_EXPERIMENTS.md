# 13. 분석, 관측성, 실험

- 상태: ACCEPTED

## 1. 목표

분석은 가족의 실제 가치와 시스템 신뢰성을 측정하며, 아동 프로필이나 가족 콘텐츠를 수집하기 위한 수단이 아니다.

## 2. North Star와 핵심 지표

- Activated Household: 7일 안에 성인 2명 이상 가입 + chore/event 생성 + 완료/확인
- Weekly Coordinated Household: 한 주에 2명 이상이 서로 다른 기기에서 핵심 행동 수행
- Week 4 household retention
- invite acceptance rate
- chore completion latency
- Today successful load rate
- notification useful-action conversion
- trial-to-paid, paid household retention, refund rate

## 3. 이벤트 규칙

이벤트 이름은 `domain_object.action.outcome` 형태를 권장한다.

예:

```text
household.create.succeeded
invite.accept.failed
chore.complete.succeeded
calendar.occurrence.opened
billing.purchase.pending_server_confirmation
```

공통 속성:

- event_version
- platform/app_version
- locale/timezone bucket
- pseudonymous user/household ID
- actor role category
- request ID
- result/error code

콘텐츠 제목, 이메일, child 이름, raw token은 금지한다.

## 4. Managed Child analytics

- child mode에서는 외부 behavioral analytics 기본 off
- 필수 운영 event는 child identity 없이 household-level aggregate
- 광고/추적 SDK 사용 금지
- 대상 연령 법률 검토 전 실험 참여 금지

### WP01-10 Android local governance baseline

- optional usage analytics는 `analytics-usage-v1` device/environment preference가 명시적으로 granted일 때만 허용하며 missing, withdrawn, stale, malformed와 storage failure는 모두 off로 닫는다.
- 호출자는 exact six-value enum만 사용하고 sink에는 event name/version, Android platform, public app release, dev/prod environment의 exact five fields만 전달한다. identifier, pseudonym, content, locale/timezone, request ID와 arbitrary attribute는 이 baseline에 없다.
- Managed Child mode는 preference storage를 읽거나 sink에 접근하기 전에 차단한다. Store MVP에 child runtime을 노출하지 않는 D-013과 별개로 미래 조합도 fail closed다.
- current Android composition에는 외부 behavioral analytics sink가 없다. Sentry는 PII-filtered operational error reporter이며 usage analytics sink로 재사용하지 않는다.
- direct runtime dependency inventory는 `pubspec.yaml`과 자동 대조하고 미승인 analytics, advertising, tracking SDK 추가를 차단한다.
- provider, 목적, 필드 또는 정책이 확대되면 policy version을 변경해 기존 granted preference를 무효화해야 한다. 승인 provider, 법률 동의·server record와 hosted retention/region/access/deletion은 마지막 Gate다.

## 5. 관측성

| 신호 | 도구/소스 | 목적 |
|---|---|---|
| Crash | Sentry/Store console | release 품질 |
| Error | structured server/client error | 원인과 영향 범위 |
| Trace | request ID, Edge Function timing | latency bottleneck |
| DB | query latency, lock, RLS failure | backend health |
| Jobs | queue depth, retry, dead letter | notification/billing reliability |
| Billing | webhook lag, entitlement mismatch | revenue risk |
| Push | provider success, invalid token | delivery health |

## 6. SLO 예시

- authenticated Today API availability 99.9%/30d
- Today p95 server response ≤ 800ms (정의된 데이터 규모)
- critical mutation success ≥ 99.5% excluding validation/authz
- notification job 95%가 scheduled time ±5분 내 provider 제출
- entitlement webhook 99%가 10분 내 materialize
- crash-free sessions ≥ 99.7% mobile release

정확한 수치는 Beta 데이터 후 승인한다.

WP05-05 local baseline은 Android push의 schedule을 quiet hours/current state 통과 후 provider materialization 시각으로 정의한다. accepted 5분 SLO, ready lag, explicit retry backoff, ambiguity, permanent failure와 stale suppression은 content-free aggregate로만 측정한다. low-volume에서는 20건 미만 비율 단독 alert를 피하고 miss 3건 또는 stale 1건을 함께 사용한다. 실제 Firebase submit/delivery 간 차이와 threshold 재승인은 Beta 데이터 후 수행한다.

WP06-04 local baseline은 billing reconciliation의 queued/leased/retry/dead-letter, 최근 24시간 succeeded/dead-letter, expired lease, oldest due와 next retry만 aggregate로 노출한다. provider event/customer/transaction/product, raw webhook/API response와 household/user ID는 health·alert payload에 포함하지 않는다. hosted scheduler/dashboard/pager와 실제 RevenueCat outage threshold는 마지막 Billing Gate에서 확정한다.

WP06-05 assignment 관측은 `prepared|renewed|confirmed|released|expired|transferred` lifecycle과 support resolution action을 private immutable audit로 남긴다. client/analytics에는 binding/ownership/member-health의 aggregate enum과 stable failure만 허용하며 provider/customer/transaction/receipt, 다른 household/user, case reference는 금지한다. `ASSIGNMENT_REQUIRED` 복구는 requeued count와 immutable queue transition으로 확인하고 hosted operator dashboard·ticket aging·provider ownership evidence는 마지막 Billing Gate에서 연결한다.

## 7. Alert

- symptom 기반, 사용자 영향 기준
- owner와 runbook link 필수
- alert storm 방지
- low-volume billing/security는 절대 건수와 비율 모두 사용
- child/privacy breach 의심은 즉시 incident 분류

## 8. 실험 Gate

실험 전 다음을 문서화한다.

- 가설과 사용자 가치
- primary/guardrail metric
- 표본·기간·중단 기준
- 개인정보·아동 영향
- 서버 feature flag와 rollback
- 실험 종료 후 정리

pricing, child UX, account deletion, security gate는 일반 A/B 실험 대상으로 다루지 않는다.
