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

### 1.1 WP06-03A local contract

- `BillingPort`는 provider-neutral identity, catalog, purchase, restore, clear와 client invalidation snapshot만 노출한다.
- catalog/package는 opaque Store identifier, Store-localized price와 billing period를 immutable value로 운반한다. 실제 product ID·가격·통화·trial 문구를 앱에 하드코딩하지 않는다.
- `BillingFlowController`는 server entitlement를 먼저 읽는다. provider 또는 catalog가 unavailable이어도 기존 server status는 표시하고 새 purchase만 닫는다.
- purchase Store success는 newer server Plus이면서 current user가 billing owner일 때만 확정한다. bounded confirmation이 끝나도 Free를 Plus로 추정하지 않고 pending + explicit refresh를 유지한다.
- restore empty/conflict/pending/found, purchase cancel/pending/retryable/final failure는 서로 다른 stable state/result다.
- duplicate action은 한 provider call로 합치며 logout/account/household switch와 dispose는 이전 generation의 늦은 결과를 무효화한다. identity clear 실패 시 새 user bind를 막는다.
- 이 local contract는 deterministic fake port로 검증됐다. concrete SDK 연결은 1.2에 기록하고 paywall과 actual sandbox/account/device는 후속 Gate로 남긴다.

### 1.2 WP06-03B concrete Android contract

- exact `purchases_flutter 10.8.0` dependency는 provider-private driver 안에만 존재한다. facade와 `BillingPort` 밖으로 SDK object, `CustomerInfo`, receipt, transaction/customer reference 또는 provider message를 노출하지 않는다.
- Android public SDK key가 있고 authenticated user가 확정된 후에만 configure한다. 첫 configure와 모든 account switch의 custom App User ID는 exact KinFlow auth UUID여야 하며 anonymous 또는 returned/current mismatch는 fail closed한다.
- SDK diagnostics와 automatic device identifier collection은 비활성화하고 customer attribute, email, display name, household/family content를 설정하지 않는다.
- current offering의 exact cached package만 purchase할 수 있다. Store success, restore와 CustomerInfo callback은 server entitlement refresh signal이며 client snapshot으로 Plus를 부여하지 않는다.
- logout/account detach는 local binding과 catalog/package cache를 제거한다. SDK `logOut()`으로 anonymous ID를 만들지 않고, 다음 authenticated bind에서 `logIn(newUserId)` 후 exact identity를 다시 검증한다.
- keyless/non-Android는 unavailable billing port만 주입해 server entitlement read를 유지하고 새 Store operation만 닫는다. 전체 dependency boot 실패 shell에서는 port와 repository 모두 unavailable fallback으로 닫힌다.
- concrete adapter와 composition은 local fake/MethodChannel, full Flutter, Android native build로 검증됐다. paywall/product/provider account/sandbox/device는 완료 범위가 아니다.

## 2. Initialization

- app boot에서 configuration 가능
- purchase action 전 authenticated KinFlow user 필요
- RevenueCat custom App User ID bind/local detach를 auth lifecycle과 일치시키고 anonymous SDK logout은 사용하지 않음
- 환경별 API key/product 분리
- debug log에 receipt/PII 금지

## 3. UI 상태

```text
catalogLoading
catalogReady
assignmentPreparing
assignmentConflict
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

- \`POST /functions/v1/revenuecat-webhook\`은 dedicated full Authorization과 \`X-RevenueCat-Webhook-Signature\` HMAC을 모두 검증한다. HMAC 입력은 재직렬화 JSON이 아니라 \`timestamp + "." + raw body bytes\`이고 허용 오차는 300초다.
- 최대 256 KiB JSON만 수용하며 인증을 JSON parse보다 먼저 수행한다. 성공·중복·ignore·manual-review는 provider/customer/transaction 식별자 없이 빠른 200 aggregate response를 반환한다.
- private inbox는 provider event ID + raw SHA-256 hash로 exact replay를 한 row에 합치고 같은 ID/다른 body를 거부한다. 동일 event의 동시 최초 delivery도 transaction advisory lock으로 직렬화한다.
- webhook payload는 entitlement authority가 아니라 refresh trigger다. leased worker가 고정된 RevenueCat API v1 subscriber endpoint를 exact auth UUID로 다시 조회하고 identity, environment, configured entitlement, product, subscription, store와 timestamp를 strict parse한다.
- provider request time을 ordering clock으로 active/trial/grace/billing issue/cancel-valid/expired/refunded snapshot을 normalized \`reconciliation\` event로 바꿔 WP06-01 \`apply_verified_billing_event\`에 전달한다.
- worker는 \`FOR UPDATE SKIP LOCKED\`, opaque lease, 최대 5 attempts와 1m/5m/30m/2h의 네 retry를 사용하고 5번째 실패를 terminal로 닫는다. network/429/5xx/RPC failure만 retry하고 identity/environment/schema/unmapped failure는 dead letter다.
- persisted active billing assignment가 없으면 현재 active household를 추정하지 않고 \`ASSIGNMENT_REQUIRED\` dead letter로 닫는다. WP06-05 explicit prepare만 같은 identity/environment의 해당 dead letter를 idempotently requeue한다.
- raw webhook/provider response는 저장하지 않으며 immutable aggregate transition audit와 queue health만 남긴다. RevenueCat dashboard/API key, hosted scheduler/alert와 실계정·Store·기기 검증은 마지막 Billing Gate다.

## 5. Household assignment

구매 전 active household를 확인하고 혜택을 명시한다. 한 구매가 여러 household를 자동으로 유료화하지 않는다.

### 5.1 WP06-05 local contract

- `prepare_billing_household_assignment(household, idempotencyKey)`는 active Owner/Admin만 호출한다. provider, sandbox/production environment와 customer identity는 request에서 받지 않고 server runtime + `auth.uid()`로 파생한다.
- command는 user와 target household advisory lock을 잡고 한 customer↔한 household, 한 household↔한 customer active unique invariant를 유지한다. exact replay는 같은 결과를 반환하고 같은 key/다른 input은 `KFB50`이다.
- `ready | already_ready | customer_conflict | household_conflict`만 client에 반환한다. conflict 결과에는 provider/customer/다른 household/billing-owner identifier가 없다.
- 새 선택은 30분 `provisional` binding이다. 이는 Plus 권한이 아니며 verified transaction insert/update trigger만 `confirmed`로 승격하고 intent를 소비한다.
- purchase cancel, restore empty와 final provider failure는 current user의 matching provisional version만 best-effort release한다. confirmed release는 `support_required`; pending/success는 reconciliation을 위해 binding을 유지한다.
- assignment status는 `none|provisional|confirmed`, `unassigned|current_user|another_user`, owner membership `none|active|removed`, can-prepare/support/version/expiry만 반환한다.
- account/household switch는 늦은 prepare/release/Store 결과를 무효화한다. conflict는 Store call count 0을 보장한다.
- exact RPC/state/error/privacy 계약은 `docs/contracts/billing-assignment.yaml.md`에 정의한다.

### 5.2 Reconciliation and remediation

- prepare 성공은 같은 auth UUID/environment의 terminal `ASSIGNMENT_REQUIRED` job만 `retry_wait`로 되돌리고 immutable `requeued` transition을 남긴다.
- reconciliation claim은 confirmed 또는 아직 유효한 provisional만 household에 연결한다. periodic stale-customer schedule은 confirmed만 사용하며 service cleanup은 transaction 없는 expired provisional만 끝낸다.
- purchaser membership/role drift는 assignment 또는 entitlement를 자동 삭제·이전하지 않는다. client aggregate status의 `requires_support`로 나타낸다.
- Owner/Admin remediation request는 conflict kind만 저장하며 ticket text/provider reference를 저장하지 않는다. 동일 open request로 수렴하는 모든 accepted idempotency key도 별도 command-result alias에 보존한다.
- service-only resolution은 `transfer_customer | release_expired_provisional | reject`, expected version, allowlisted reason, 32-byte SHA-256 case-reference와 correlation ID를 요구한다. transfer는 verified requester/customer ownership, target Owner/Admin, empty target를 확인한 뒤 source reset + target confirmed assignment/entitlement를 원자적으로 적용한다.
- assignment lifecycle와 support action audit는 private/immutable이며 direct table access는 service role까지 revoke한다.

## 6. Feature flags와 limits

D-027 확정 전 기본 gate response 예시:

```json
{
  "decision": "policy_unavailable",
  "householdId": "<current-household-uuid>",
  "featureKey": "members",
  "requestedDelta": 1,
  "currentUsage": 0,
  "limit": null,
  "remainingAfterDelta": null,
  "plan": "free",
  "entitlementStatus": "none",
  "enforcementEnabled": false,
  "limitsFinalized": false,
  "entitlementVersion": 1,
  "policyVersion": 1,
  "runtimeVersion": 1,
  "evaluatedAt": "2026-08-08T00:00:00Z"
}
```

client는 이 aggregate projection을 UX에만 사용하고 server가 mutation에서 다시 강제한다. provider/customer/transaction/receipt/billing owner/member identifier와 가족 콘텐츠는 projection에 포함하지 않는다.

### 6.1 WP06-06 activation and enforcement

- `configure_billing_feature_enforcement(enabled, expectedVersion, correlationId)`는 service role만 호출한다. enable은 active finalized Free/Plus 정책 모두에 `members`, `activeSeries`가 존재하고 Plus가 Free보다 작지 않을 때만 허용하며 immutable policy audit를 남긴다.
- enabled 상태의 필수 plan을 inactive/unfinalized로 만들거나 필수 key를 제거할 수 없다. incident 대응을 위한 runtime emergency disable은 허용한다.
- `get_household_feature_gate(household, feature, delta)`는 active member에게 `allowed | policy_unavailable | feature_unconfigured | limit_reached`만 반환한다. delta 범위는 1..1000이고 결과는 entitlement/policy/runtime version을 함께 운반한다.
- actual enforcement는 household+feature transaction advisory lock과 entitlement/catalog row lock 뒤 usage를 재계산한다. client count나 cached Plus는 authority가 아니다.
- `members`는 removed member를 제외한다. `activeSeries`는 recurring active chore/event series만 합산하고 one-time은 제외한다.
- member insert/reactivation 및 recurring series 최초 revision/reactivation은 같은 authority를 호출한다. `KFB10/KFB11`은 policy unavailable, `KFB12`는 limit reached로 Flutter와 invite Edge에 전달한다.
- exact 계약은 `docs/contracts/billing-feature-enforcement.yaml.md`에 정의한다. numeric limits는 D-027 승인 전까지 설정·활성화하지 않는다.

## 7. Restore conflict

같은 store purchase가 다른 KinFlow identity/household에 연결된 경우 임의 이전하지 않는다.

- 현재 연결 상태를 민감 정보 없이 설명
- 중복 purchase 유도 금지
- support/ownership verification path
- manual action audit

WP06-05는 aggregate support request와 versioned audited server resolution을 local automation으로 구현한다. RevenueCat alias/ownership verification, 실제 ticket/operator UI와 Store-account evidence는 마지막 Billing Gate 전까지 실행하지 않는다.

## 8. Cancellation/Expiry

사용자가 만든 family data를 즉시 삭제하지 않는다. WP06-06은 over-limit 상태에서도 기존 read/update/cancel/delete와 one-time 생성은 유지하고 새 member/recurring expansion만 제한한다. grace와 billing issue는 server가 materialize한 effective plan을 그대로 사용하며 client가 별도 권한을 추정하지 않는다.

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

Local evidence: `docs/evidence/phase-06/WP06_03A_EVIDENCE.md` (provider-neutral flow), `docs/evidence/phase-06/WP06_03B_EVIDENCE.md` (concrete Android adapter), `docs/evidence/phase-06/WP06_05_EVIDENCE.md` (explicit assignment/conflict/remediation), `docs/evidence/phase-06/WP06_06_EVIDENCE.md` (lifecycle/feature enforcement). 실제 Store 항목은 완료로 간주하지 않는다.

## 10. Store copy

- 가격/기간/자동 갱신
- trial 조건
- household benefit
- restore
- terms/privacy
- cancellation path
- 지역별 store price 사용

하드코딩된 통화 환산을 사용하지 않는다.
