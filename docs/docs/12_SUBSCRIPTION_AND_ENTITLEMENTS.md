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

## 4. 상태 모델

`household_entitlement.status` 예시:

- `inactive`
- `trialing`
- `active`
- `grace_period`
- `billing_issue`
- `expired`
- `revoked`

필드:

- entitlement_key
- source/provider
- purchaser_user_id
- billing_household_id
- valid_from/valid_until
- will_renew
- last_verified_at
- provider_event_id
- state_reason

## 5. 구매 사용자 흐름

1. 로그인과 active household 확인
2. 상품과 가격을 store에서 조회
3. household 혜택 범위와 자동 갱신 설명
4. 구매 진행
5. SDK success를 임시 pending으로 표시
6. 서버 entitlement 확인
7. timeout 시 중복 구매를 유도하지 않고 복원/상태 갱신 제공

## 6. 복원과 계정 변경

반드시 별도 테스트한다.

- 앱 재설치 후 같은 KinFlow 계정
- 같은 store 계정, 다른 KinFlow 계정
- 다른 store 계정, 같은 KinFlow 계정
- purchaser가 household를 떠남
- Household Owner 변경
- billing household 변경 요청
- 구매가 다른 RevenueCat App User ID에 연결됨

자동 이전 정책은 사업 결정 없이는 구현하지 않는다. 충돌 시 안전하게 잠그고 지원 경로를 제공한다.

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

- 서버: Plus 전용 mutation과 한도를 강제
- 클라이언트: UX용 visibility/upsell
- offline cache의 오래된 Plus 상태로 destructive mutation을 허용하지 않음
- entitlement downgrade 시 기존 데이터는 유지하되 새 생성/확장을 제한하는 정책을 명시

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
