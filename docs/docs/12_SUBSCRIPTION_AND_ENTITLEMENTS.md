# 12. 구독과 Household Entitlement

- 상태: ACCEPTED
- 모바일 Provider: RevenueCat + Apple App Store + Google Play
- Web paid purchase: OPEN, Mobile MVP 차단 요소 아님

## 1. 제품 원칙

KinFlow Plus는 개인 구매가 아니라 선택된 household에 혜택을 제공한다. 구매자, 로그인 사용자, Household Owner, billing owner, paid household는 서로 다른 개념이다.

## 2. 식별자

| 식별자 | 의미 |
|---|---|
| `auth_user_id` | KinFlow 로그인 identity |
| RevenueCat App User ID | 로그인 후 auth_user_id 기반 stable identity |
| `store_transaction_id` | Apple/Google transaction |
| `billing_customer_id` | 서버에서 관리하는 결제 identity |
| `billing_household_id` | 혜택을 연결한 household |
| `household_entitlement` | 서버가 materialize한 최종 기능 권한 |

anonymous RevenueCat user로 purchase를 완료하게 두지 않는다. 로그인 이전 paywall은 상품 정보만 보여주고 구매 전 identity를 확정한다.

## 3. 권위 흐름

```text
mobile purchase/restore
  → RevenueCat SDK 결과
  → RevenueCat webhook 또는 server verification
  → idempotent billing event
  → store transaction/customer 상태
  → billing household assignment policy
  → household_entitlement materialization
  → client refetch
```

클라이언트 SDK의 `CustomerInfo`만으로 server mutation 권한이나 household Plus 한도를 열지 않는다.

### WP06-03A local client flow (2026-08-08)

- client는 current user + active household의 server entitlement를 먼저 읽고 exact authenticated user identity만 billing port에 bind한다.
- Store catalog와 localized price는 provider-neutral immutable object로만 운반하며, catalog/SDK unavailable은 server entitlement를 지우지 않는다.
- Store purchase success와 provider snapshot은 refetch 신호일 뿐이다. current household의 newer server Plus와 billing-owner flag가 일치해야 purchase confirmed가 된다.
- confirmation timeout은 pending을 유지하고 explicit refresh를 제공한다. restore conflict나 identity mismatch는 자동 이전·재구매 없이 fail closed한다.
- account/household switch, logout과 dispose는 in-flight generation을 무효화하며 account switch는 이전 provider identity clear 성공 뒤에만 새 identity를 bind한다.
- Evidence: `docs/evidence/phase-06/WP06_03A_EVIDENCE.md`. RevenueCat SDK, UI와 실제 sandbox/account/device 결과는 아직 포함하지 않는다.

### WP06-04 local server flow (2026-08-08)

- RevenueCat webhook은 full Authorization과 300초 raw-body HMAC을 모두 통과해야 metadata-only inbox에 들어간다. exact event replay는 delivery count만 올리고 같은 ID/다른 raw hash는 거부한다.
- webhook payload 자체는 entitlement를 열지 않는다. leased worker가 RevenueCat API v1 subscriber snapshot을 다시 조회하고 exact auth UUID, environment, configured entitlement/product/subscription/store를 검증한다.
- provider request time으로 normalized reconciliation event를 만들어 기존 server entitlement command에 적용한다. out-of-order webhook delivery가 materialized state를 직접 회귀시키지 않는다.
- active billing assignment가 없으면 client active household를 추정하지 않고 `ASSIGNMENT_REQUIRED` dead letter로 닫는다. WP06-05 prepare가 같은 identity/environment의 해당 work만 명시적으로 다시 연다.
- worker는 최대 5 attempts, 네 번의 bounded retry, `FOR UPDATE SKIP LOCKED`, lease-token idempotency와 periodic stale-customer repair를 사용한다. raw webhook/API response는 저장하지 않고 aggregate health와 immutable transition만 남긴다.
- Evidence: `docs/evidence/phase-06/WP06_04_EVIDENCE.md`. hosted scheduler/alert, RevenueCat project/API key, actual subscriber/Store/account/device는 마지막 Billing Gate다.

### WP06-05 local household assignment flow (2026-08-08)

- purchase/restore 전에 active Owner/Admin이 혜택을 받을 household를 명시적으로 선택한다. server는 authenticated UUID와 runtime provider/environment로 customer를 파생하고 30분 provisional binding을 만든다.
- provisional binding은 entitlement가 아니다. verified provider transaction이 적용될 때만 confirmed가 되며, cancel·restore empty·final provider failure에서는 client가 만든 provisional만 해제한다.
- 한 customer가 confirmed로 다른 household에 연결됐거나 target household가 다른 customer에 연결됐으면 Store를 호출하지 않는다. client에는 `customer_conflict` 또는 `household_conflict`와 aggregate 상태만 보이고 반대편 식별자는 노출하지 않는다.
- purchaser가 household에서 제거되거나 역할이 바뀌어도 기존 Plus를 자동 삭제·이전하지 않는다. 상태는 `requires_support`를 표시하고 Owner/Admin은 free-form text 없는 aggregate remediation request를 만들 수 있다.
- 실제 이전은 service-only command다. expected assignment version, allowlisted reason, SHA-256 case reference와 correlation ID를 요구하고 source entitlement reset, target confirmed assignment와 entitlement 이동을 한 transaction에서 수행해 immutable audit를 남긴다.
- Evidence: `docs/evidence/phase-06/WP06_05_EVIDENCE.md`. provider alias/ownership verification, support ticket/operator UI와 실제 Store account/reinstall/device는 마지막 Billing Gate다.

### WP06-06 local lifecycle and feature enforcement (2026-08-08)

- D-027의 실제 수치 한도는 여전히 OPEN이다. Free/Plus 양쪽 정책이 active·finalized이고 `members`, `activeSeries`를 모두 포함한 뒤 service-only expected-version command가 activation해야 실제 mutation enforcement가 켜진다.
- activation 전 client gate는 `policy_unavailable`로 fail closed하지만 기존 기능 개발을 막지 않도록 mutation trigger는 비활성이다. 앱이나 migration에 임의 Free/Plus 숫자를 넣지 않는다.
- activation 후 active member 추가/복구와 첫 번째 또는 재활성화된 recurring chore/calendar series는 household+feature transaction advisory lock 안에서 server usage를 다시 계산한다. one-time chore/event는 `activeSeries`에 포함하지 않는다.
- downgrade·expiry·refund·revoke로 기존 한도를 넘더라도 가족 데이터는 삭제하지 않는다. 기존 read/update/cancel/delete와 one-time 생성은 유지하고 새 member 또는 recurring expansion만 제한한다.
- active household member가 읽는 gate는 decision, aggregate usage/limit, plan/status, version과 timestamp만 포함한다. provider/customer/transaction/receipt/billing owner/member ID와 가족 콘텐츠는 반환하지 않는다.
- Flutter는 exact 15-field gate를 UTC·plan/status·산술 invariant까지 검증하고 `KFB10/KFB11/KFB12`를 localized policy-unavailable/limit-reached UX로 매핑한다.
- Evidence: `docs/evidence/phase-06/WP06_06_EVIDENCE.md`. 실제 D-027 수치, hosted activation, paywall과 Store/provider/account/device 검증은 마지막 Billing Gate다.

## 4. 상태 모델

`household_entitlement.status` 예시:

- `none`
- `trialing`
- `active`
- `grace`
- `billing_issue`
- `expired`
- `revoked`

필드:

- household_id
- plan_code
- status/source
- product_id
- current_period_start/current_period_end
- will_renew
- features
- provider_updated_at/verified_at
- version/is_billing_owner

provider customer/event/transaction/receipt 식별자는 client entitlement projection에 포함하지 않는다.

## 5. 구매 사용자 흐름

1. 로그인과 active household 확인
2. 상품과 가격을 store에서 조회
3. household 혜택 범위와 자동 갱신 설명
4. Owner/Admin이 혜택 household를 명시적으로 선택하고 server provisional binding 준비
5. assignment conflict면 Store 호출 없이 support 경로 제공
6. 구매 진행
7. SDK success를 임시 pending으로 표시
8. verified transaction과 서버 entitlement 확인
9. timeout 시 중복 구매를 유도하지 않고 복원/상태 갱신 제공

## 6. 복원과 계정 변경

반드시 별도 테스트한다.

- 앱 재설치 후 같은 KinFlow 계정
- 같은 store 계정, 다른 KinFlow 계정
- 다른 store 계정, 같은 KinFlow 계정
- purchaser가 household를 떠남
- Household Owner 변경
- billing household 변경 요청
- 구매가 다른 RevenueCat App User ID에 연결됨

자동 이전은 하지 않는다. 충돌 시 Store 호출 전에 안전하게 잠그고 aggregate support request를 제공하며, 실제 이전은 ownership verification 뒤 service-only audited command로만 실행한다.

## 7. Store lifecycle

- trial 시작/전환
- active renewal
- grace period
- billing issue
- cancellation but valid until
- expiration
- refund/revoke
- upgrade/downgrade
- price consent
- family sharing 여부

각 상태에서 서버 entitlement와 UI 문구가 일치해야 한다.

## 8. Webhook

- signature/authorization 검증
- provider event ID unique
- duplicate는 idempotent success
- out-of-order event를 event time과 authoritative refresh로 처리
- unknown product/customer는 quarantine
- failure retry와 dead letter
- 민감 receipt 원문 log 금지

## 9. Feature gate

- 서버: activation된 finalized policy만 member와 recurring-series expansion에서 직렬화해 강제
- 클라이언트: aggregate gate를 UX용 visibility/upsell에만 사용하며 mutation authority로 사용하지 않음
- offline cache의 오래된 Plus 상태로 destructive mutation을 허용하지 않음
- entitlement downgrade 시 기존 데이터와 비확장 작업은 유지하고 새 member/recurring 생성·재활성화만 제한
- 정책 미준비·필수 feature 누락은 임의 수치 fallback 없이 fail closed

## 10. Free/Plus OPEN 결정

출시 전 확정:

- household 최대 구성원
- active recurring chores/events 한도
- history retention 또는 advanced reminder
- 월간/연간 가격과 trial
- 국가·통화·세금
- refund/support policy

가격이나 제한은 앱 코드에 흩어놓지 않고 remote catalog + server policy로 관리한다.

## 11. Sandbox와 출시 Gate

Apple Sandbox/TestFlight와 Google license tester에서 `matrices/BILLING_TEST_MATRIX.csv` 전체를 실행한다. 특히 purchase success만으로 통과하지 않는다.

증거:

- transaction/provider event ID redacted log
- webhook 처리 상태
- entitlement DB snapshot
- purchaser/household UI
- 재설치·restore 화면 녹화
- refund/expiry/grace 시나리오
