# Phase 06 — 구독과 Household Entitlement

## 목표

App Store/Google Play 구매·복원·갱신·만료·환불을 RevenueCat과 서버가 처리하고, 최종 Plus 권한을 선택된 household에 일관되게 적용한다.

## Entry

가격/limits/restore policy 승인, Store/RevenueCat sandbox 준비.

## Work Packages

### WP06-01 Billing domain/schema

- customer/transaction/event/household entitlement
- state model와 audit
- server feature limit

### WP06-02 Product catalog/paywall

- store local price
- monthly/annual/trial copy
- household benefit
- terms/privacy/restore
- accessibility/localization

### WP06-03 Flutter RevenueCat adapter

- authenticated App User ID
- offerings/purchase/restore
- pending server confirmation
- error mapping

### WP06-04 Webhook/reconciliation

- signature, idempotency, ordering
- transaction/customer upsert
- entitlement materialize
- dead letter/alert

### WP06-05 Household assignment/conflicts

- billing household 선택
- purchaser leaves/owner change
- restore conflict
- manual remediation audit

### WP06-06 Lifecycle/limits

- active/trial/grace/billing issue/expired/refund
- server/client gates
- downgrade data preservation

## 자동 검증

- BILLING_TEST_MATRIX
- adapter fake tests
- webhook duplicate/out-of-order/signature
- entitlement RLS/server enforcement
- account/household mapping

## 수동 검증

- Apple sandbox/TestFlight
- Google license tester/internal track
- purchase/restore/reinstall
- pending network loss
- expiry/refund/grace
- price/localization/store copy

## Exit Gate

Store success와 server entitlement가 분리되어도 사용자가 안전한 pending/recovery 경로를 갖고, 다른 account/household에 Plus가 누출되지 않는다.

## Stop/Rollback

mismatch 또는 중복 결제 위험 시 purchase entry를 remote kill switch로 닫고 기존 entitlement read와 support를 유지한다.
