# 27. Billing과 Entitlement 구현 스펙

- 상태: ACCEPTED

## 1. Flutter adapter

```dart
abstract interface class BillingService {
  Future<List<StoreOffering>> loadOfferings();
  Future<PurchaseAttempt> purchase(StorePackage package);
  Future<RestoreAttempt> restore();
  Stream<BillingClientSnapshot> get snapshots;
}
```

`purchases_flutter` type은 adapter 밖으로 노출하지 않는다.

## 2. Initialization

- app boot에서 configuration 가능
- purchase action 전 authenticated KinFlow user 필요
- RevenueCat App User ID login/logout을 auth lifecycle과 일치
- 환경별 API key/product 분리
- debug log에 receipt/PII 금지

## 3. UI 상태

```text
catalogLoading
catalogReady
purchasing
storeSuccessServerPending
active
restoreEmpty
restoreConflict
billingIssue
expired
errorRetryable/errorFinal
```

Store success 직후 Plus를 영구 활성화하지 않고 server confirmation pending을 표시한다.

## 4. Server reconciliation

- webhook primary asynchronous signal
- 필요 시 authenticated refresh endpoint
- customer identity mapping
- provider transaction unique
- authoritative entitlement recompute
- client polling/backoff 제한
- mismatch alert

## 5. Household assignment

구매 전 active household를 확인하고 혜택을 명시한다. 한 구매가 여러 household를 자동으로 유료화하지 않는다. billing household 변경/이전은 정책과 audit가 필요한 command다.

## 6. Feature flags와 limits

서버 response:

```json
{
  "entitlement": "plus",
  "status": "active",
  "validUntil": "...",
  "limits": {
    "members": 10,
    "activeSeries": 100
  },
  "verifiedAt": "..."
}
```

client는 UX에 사용하고 server가 mutation에서 다시 강제한다.

## 7. Restore conflict

같은 store purchase가 다른 KinFlow identity/household에 연결된 경우 임의 이전하지 않는다.

- 현재 연결 상태를 민감 정보 없이 설명
- 중복 purchase 유도 금지
- support/ownership verification path
- manual action audit

## 8. Cancellation/Expiry

사용자가 만든 family data를 즉시 삭제하지 않는다. Plus-only creation/advanced feature를 제한하고 read/export/delete는 유지한다. grace와 billing issue 동안 제품 정책에 맞는 유예를 제공한다.

## 9. Testing

- fake adapter unit tests
- RevenueCat sandbox integration
- Apple Sandbox/TestFlight
- Google license tester/internal track
- webhook local fixture/signature
- reinstall/account/household switching
- refund/revoke/expiry
- network loss after store success
- duplicate tap and transaction

## 10. Store copy

- 가격/기간/자동 갱신
- trial 조건
- household benefit
- restore
- terms/privacy
- cancellation path
- 지역별 store price 사용

하드코딩된 통화 환산을 사용하지 않는다.
