# 원본 파일 문서화: `contracts/subscription-settings.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/subscription-settings.yaml`
- 원본 형식: `yaml`
- 범위: WP06-02A subscription status, paywall, restore, management and policy links

```yaml
version: "2026-08-08-wp06-02a"
requirements: [FR-SUB-001, FR-SUB-002, FR-SUB-003, FR-SUB-008, FR-SET-006]
decisions: [D-024, D-025, D-027, D-028, D-047, D-054]
authority:
  displayedEntitlement: active-household server projection
  storeSnapshot: invalid as entitlement authority
  purchaseConfirmation: newer server Plus with current billing owner
viewer:
  status: every authenticated active household member
  purchaseAndRestore:
    role: active Owner or Admin
    householdIdentity: profile household ID must equal billing context household ID
  manage:
    actor: current server-declared billing owner
    source: app_store or play_store
statusProjection:
  fields:
    - household name or current-household fallback
    - plan and lifecycle status
    - provider-safe source label
    - billing owner relation
    - will renew
    - current period end when present
    - verified timestamp freshness
  forbidden:
    - provider customer ID
    - transaction or receipt
    - purchaser user or member ID
    - package or product identifier in UI copy
paywall:
  price: exact Store localized price
  period: Store-derived count and unit
  hardcodedPrice: forbidden
  hardcodedNumericLimits: forbidden
  benefits:
    - household member capacity
    - active repeating chore and calendar series capacity
    - existing data preservation after downgrade
  confirmation:
    - active household name
    - localized price and period
    - possible automatic renewal
    - server confirmation required after Store result
  catalogFailure:
    statusRead: preserved
    purchase: disabled
    restore: available when the Store runtime is supported
states:
  - loading
  - ready
  - assignment_preparing
  - assignment_conflict
  - purchasing
  - restoring
  - store_pending
  - server_confirmation_pending
  - restore_empty
  - restore_conflict
  - failed
pending:
  duplicatePurchaseOrRestoreAction: hidden
  recovery: explicit server refresh
conflict:
  automaticTransfer: forbidden
  oppositeIdentityDisclosure: forbidden
  recovery: aggregate remediation request and configured support link
externalLinks:
  input: enum only
  launchMode: external application
  destinations:
    googlePlayManagement: "https://play.google.com/store/account/subscriptions"
    appleAppStoreManagement: "https://apps.apple.com/account/subscriptions"
    terms: public site origin plus /terms
    privacy: public site origin plus /privacy
    support: configured support URI
  userSuppliedUri: forbidden
  queryOrTokenAugmentation: forbidden
client:
  localization: [EN, KO, EN-XA]
  compactTextScale: 200 percent scrollable
  minimumActionTarget: 48 dp
rollback:
  routeCanBeRemoved: true
  unavailableStorePreservesEntitlementRead: true
  linkFailureDoesNotMutateBilling: true
deferred:
  - final price, trial and limit policy approval
  - RevenueCat and Google Play real-account sandbox
  - actual Play management activity
  - refund, expiry and network-loss device runs
  - iOS runtime validation
```
