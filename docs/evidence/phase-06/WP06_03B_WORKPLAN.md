# Phase 06 WP06-03B RevenueCat Android Adapter and Composition Workplan

- 상태: `LOCAL IMPLEMENTED (2026-08-08)`
- 범위: pinned `purchases_flutter` Android runtime dependency, provider-private SDK facade, provider-neutral `BillingPort` concrete adapter, authenticated identity lifecycle, offerings/purchase/restore/error mapping, app composition과 keyless/non-Android unavailable fallback
- 제외: paywall/settings 화면과 Store copy, 실제 product/offering 생성, RevenueCat project/webhook, purchase-intent/reconciliation HTTP, iOS target, 실제 account/sandbox/device 검증

## Entry Decision

- WP06-03A가 provider-neutral billing state machine과 deterministic fake 계약을 고정했으므로 이번 slice는 그 port 뒤에만 RevenueCat SDK를 연결한다. application/domain/presentation에는 SDK type을 노출하지 않는다.
- D-027 가격·limits·trial/annual 정책은 OPEN이다. adapter는 RevenueCat current offering의 opaque package/product ID, Store-localized price와 기간만 전달하고 실제 product ID나 가격을 하드코딩하지 않는다.
- 현재 저장소는 Android target만 갖는다. Android public SDK key가 비어 있거나 Android runtime이 아니면 composition은 명시적인 unavailable port를 주입하며 SDK를 configure하지 않는다.
- 실제 계정·상품·sandbox·실기기 검증은 사용자의 순서에 따라 마지막 Billing Gate로 유지한다. 이번 완료 근거는 fake SDK 경계와 local automated regression이다.

## Requirements

| ID | 이번 slice의 수용 기준 |
|---|---|
| WP06-03 / FR-SUB-001 | RevenueCat current offering을 provider-neutral immutable catalog로 변환한다. SDK 객체, 실제 가격/통화 계산, receipt/customer/transaction reference는 adapter 밖으로 나가지 않는다. |
| WP06-03 / D-024 / FR-SUB-002 | 첫 configure에는 authenticated KinFlow `AuthUserId`를 custom App User ID로 전달하고, 이후 account switch는 exact custom ID login 후 returned/current identity를 검증한다. anonymous identity에서는 catalog/purchase/restore를 fail closed한다. |
| WP06-03 / D-025 / FR-SUB-005 | SDK purchase/restore success와 customer-info listener는 client invalidation signal일 뿐 Plus를 직접 활성화하지 않는다. 기존 WP06-03A controller가 server household entitlement를 최종 확인한다. |
| WP06-03 / FR-SUB-002 / FR-SUB-003 | SDK cancellation, pending, network/store unavailable, not allowed, invalid configuration와 restore conflict를 stable provider-neutral result/failure로 매핑한다. raw provider exception/message는 UI/state/log에 넣지 않는다. |
| WP06-03 / D-049 / NFR-SEC-01 | logout/account/household detach 시 adapter는 local binding과 package cache를 제거해 operation을 즉시 막는다. RevenueCat `logOut()`은 anonymous ID를 만들기 때문에 custom-only 정책에서는 호출하지 않으며 다음 authenticated bind에서 `logIn(newUserId)`으로 SDK identity를 교체한다. |
| WP06-03 / D-047 | `purchases_flutter` import는 `lib/infrastructure/revenuecat/` 경계에만 허용한다. domain/application/presentation/data와 SDK-neutral facade 소비자는 Flutter/plugin type에 의존하지 않는다. |
| WP06-03 / NFR-PRIV-01 | public SDK key만 client config에서 허용하고 secret key prefix는 거부한다. email/name/family content/customer info/receipt/transaction ID를 SDK attribute, state 또는 log로 보내지 않는다. SDK debug logging을 활성화하지 않는다. |
| WP06-03 / NFR-REL-01 | configure-once process state, exact identity check, exact cached package lookup, listener detach/dispose와 late callback containment을 deterministic fake SDK tests로 검증한다. |

## Identity and Authority Contract

- adapter는 authenticated UUID user ID가 없으면 SDK를 configure하거나 Store operation을 실행하지 않는다.
- SDK가 아직 configure되지 않았으면 Android public SDK key와 current authenticated user ID를 함께 사용해 한 번 configure한다.
- SDK가 이미 configure됐으면 current custom identity를 읽고 다를 때 `logIn(requestedUserId)`을 실행한다. 결과/current ID가 exact match가 아니거나 anonymous이면 bind failure다.
- local `clearIdentity()`는 binding, catalog와 package cache만 제거한다. SDK `logOut()`을 호출해 anonymous customer를 만들지 않는다. clear 이후 모든 operation은 새 authenticated bind 전까지 거부된다.
- Store success, restore success와 customer-info update는 권한 근거가 아니다. `EntitlementRepository`의 current household server projection만 Plus를 확정한다.

## Dependency, Platform, Privacy Audit

- dependency: `purchases_flutter` `10.8.0`을 exact pin하고 `pubspec.lock`으로 고정한다. 구현 중 resolver가 확인한 current stable을 local official package changelog/source와 대조해 API·native bridge를 재검증했다.
- purpose: RevenueCat Android native bridge의 configure, custom App User ID, offerings, package purchase, restore와 customer-info invalidation을 사용한다.
- alternatives: WP06-03A fake port만 유지하면 실제 Store operation이 불가능하다. `in_app_purchase` 또는 custom BillingClient bridge는 RevenueCat reconciliation 계약을 별도로 재구현하고 native/privacy surface를 넓혀 이번 baseline과 맞지 않는다.
- maintenance/license: RevenueCat이 유지하는 Flutter package이며 MIT license다. major upgrade는 새 ADR과 dependency audit 없이는 수행하지 않는다.
- platform: app minSdk 24는 SDK 요구 범위 안이고 `MainActivity`의 `singleTop`은 유지한다. Google Play Billing을 위해 `com.android.vending.BILLING` normal permission을 manifest에 추가한다. RevenueCat paywall UI를 사용하지 않으므로 `FlutterFragmentActivity`로 변경하지 않는다.
- privacy/network: SDK는 RevenueCat/Store와 통신하며 custom App User ID와 purchase/device/app metadata를 처리할 수 있다. KinFlow은 auth UUID 외 customer attributes, email, display name, household/family content를 설정하지 않고 raw CustomerInfo/receipt/transaction ID를 앱 state·log에 보관하지 않는다.
- config/secrets: `REVENUECAT_ANDROID_PUBLIC_SDK_KEY`는 client-embeddable public key다. 빈 값은 기능 unavailable이고 `sk_` 등 secret key 형식은 configuration validation에서 거부한다. dev/prod 실제 값은 repository에 넣지 않는다.
- native/build: Android manifest permission과 generated plugin registration만 영향이 있다. database, RLS, RPC, Edge/OpenAPI migration은 없다.

## Implementation Plan

1. SDK types를 내부 DTO/error로 닫는 `RevenueCatSdk` facade와 `purchases_flutter` driver를 `lib/infrastructure/revenuecat/`에 추가한다.
2. exact authenticated identity, catalog mapping/cache, purchase/restore error mapping, listener invalidation과 local detach를 수행하는 `RevenueCatBillingPort`를 구현한다.
3. keyless/non-Android/boot failure용 unavailable billing port와 entitlement repository를 조립하고 `AuthDependencies` 및 bootstrap provider override에 연결한다.
4. auth lifecycle을 billing controller에 동기화하는 host/provider를 추가해 login, household selection, logout/account switch가 같은 generation contract를 사용하도록 한다.
5. fake SDK adapter tests, composition/lifecycle tests, SDK import boundary와 Android manifest/config tests를 추가한다.
6. focused/full Flutter test, analyzer, formatter, codegen, dependency/license/config/secret/architecture gates를 실행하고 evidence를 남긴다.

## Test Plan

- first bind configure exact custom user ID; preconfigured same/different user; returned/current mismatch와 anonymous denial
- clear가 local binding/cache만 제거하고 새 bind 전 catalog/purchase/restore를 거부함
- current offering과 package/product/localized price/subscription period strict mapping; missing current, malformed/duplicate package와 stale package denial
- purchase success/cancel/pending/network/store unavailable/not allowed/configuration/unknown mapping
- restore records found/empty/conflict/pending/retryable/final mapping
- customer-info listener가 bound user의 provider-neutral invalidation만 emit하고 clear/dispose 이후 무시함
- missing key/non-Android/unavailable boot composition과 Android key-enabled concrete composition
- login/household/logout/account switch lifecycle synchronization과 sensitive local purge participant inclusion
- SDK import boundary, secret-prefix rejection, manifest Billing permission와 `singleTop`
- focused billing, full Flutter, analyzer, formatter, generated files/codegen, dependency/config/secret/architecture/whitespace gates

## Rollback

- `purchases_flutter` dependency/lock entry, Android Billing permission, `lib/infrastructure/revenuecat/`, concrete billing composition/provider/lifecycle와 관련 tests/docs를 함께 revert한다.
- unavailable `BillingPort`를 다시 주입해 purchase entry를 닫아도 WP06-01 server entitlement read와 WP06-03A provider-neutral controller는 유지된다.
- database/API migration이 없으므로 data rollback은 없다. public SDK key는 빈 값으로 두면 SDK configure와 Store operation이 모두 비활성화된다.

## Completion Boundary

- fake SDK로 concrete adapter와 app composition의 identity/catalog/purchase/restore/listener/error/fallback 경로가 실행되고 full local regression과 static gates가 통과하면 `WP06-03B LOCAL IMPLEMENTED`다.
- 이는 WP06-02 paywall, WP06-04/05 server reconciliation·assignment 또는 production billing 완료가 아니다. 실제 RevenueCat/Google Play account, product/offering, sandbox, internal track와 실기기는 마지막 Billing Gate까지 `NOT RUN`으로 명시한다.

## Official References

- RevenueCat Flutter installation: <https://www.revenuecat.com/docs/getting-started/installation/flutter>
- RevenueCat customer identity: <https://www.revenuecat.com/docs/customers/identifying-customers>
- RevenueCat SDK configuration: <https://www.revenuecat.com/docs/getting-started/configuring-sdk>
- RevenueCat purchases/restores: <https://www.revenuecat.com/docs/getting-started/making-purchases>, <https://www.revenuecat.com/docs/getting-started/restoring-purchases>
- RevenueCat public versus secret API keys: <https://www.revenuecat.com/docs/projects/authentication>
- Official Flutter package/API: <https://pub.dev/packages/purchases_flutter>, <https://pub.dev/documentation/purchases_flutter/latest/purchases_flutter/Purchases-class.html>
