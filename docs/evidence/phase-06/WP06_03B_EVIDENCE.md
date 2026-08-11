# Phase 06 WP06-03B RevenueCat Android Adapter and Composition Evidence

- Work Package: WP06-03B — concrete RevenueCat Android adapter, authenticated identity lifecycle and app composition
- 기준 commit: base `a85f262`; implementation은 2026-08-08 현재 연속 workspace
- 검증일: 2026-08-08
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Android min API 24 / target API 36
- 결과: **WP06-03B LOCAL AUTOMATED PASS / PAYWALL·PRODUCT·REVENUECAT/PLAY ACCOUNT·SANDBOX·REAL DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP06-03 / FR-SUB-001 | PASS FOR CONCRETE ANDROID CATALOG ADAPTER / OVERALL PARTIAL | RevenueCat current offering을 provider-neutral immutable catalog로 변환하고 Store-localized price와 ISO subscription period만 전달한다. SDK object, receipt, transaction/customer reference는 adapter 밖으로 나가지 않는다. |
| WP06-03 / D-024 / FR-SUB-002 | PASS FOR LOCAL AUTHENTICATED IDENTITY / OVERALL PARTIAL | 첫 configure에 exact KinFlow auth UUID를 custom App User ID로 전달한다. 이후 custom identity switch는 `logIn` 결과와 current identity를 재검증하며 anonymous/mismatch는 Store operation 전에 fail closed한다. 실제 provider customer는 아직 만들지 않았다. |
| WP06-03 / FR-SUB-002 / FR-SUB-003 | PASS FOR LOCAL PURCHASE/RESTORE MAPPING / OVERALL PARTIAL | exact cached package만 구매하고 cancel/pending/network/store/not-allowed/configuration/unknown과 restore empty/found/conflict를 stable result로 매핑한다. 실제 Play purchase·restore·reinstall은 남았다. |
| WP06-03 / D-025 / FR-SUB-005 | PASS FOR SERVER-AUTHORITY COMPOSITION / OVERALL PARTIAL | Store success, restore와 CustomerInfo update는 invalidation signal일 뿐이다. WP06-03A controller가 current household의 server entitlement를 다시 확인해야 Plus가 확정된다. |
| WP06-03 / D-049 / NFR-SEC-01 | PASS FOR ACCOUNT-SWITCH BOUNDARY | logout/account/household detach는 local user/catalog/package binding을 즉시 제거한다. anonymous ID를 만드는 SDK `logOut()`은 호출하지 않고 다음 authenticated bind에서 exact custom ID로 교체한다. |
| WP06-03 / D-047 / NFR-PLAT-001 | PASS FOR SDK BOUNDARY AND FALLBACK | `purchases_flutter` import는 provider-private driver 한 파일에만 있다. Android key가 없거나 non-Android이면 compile-safe unavailable port가 주입된다. |
| WP06-03 / NFR-PRIV-01 | PASS FOR NEW CLIENT SURFACE | client config는 Android/Test Store public key 형식만 허용하고 secret prefix와 production Test Store key를 거부한다. SDK diagnostics와 automatic device identifier collection을 끄고 email/name/household/customer attribute를 설정하지 않는다. |
| WP06-03 / NFR-REL-01 | PASS FOR LOCAL ADAPTER SURFACE | configure-once state, strict catalog mapping, stale/tampered package denial, listener detach, lifecycle generation과 unavailable boot를 deterministic tests로 검증했다. |

## Implemented Contract

- `RevenueCatSdk` facade가 identity, offering/package, restore 여부와 stable provider failure만 노출한다. 실제 `purchases_flutter` type은 `purchases_flutter_revenuecat_sdk.dart` 안에 닫힌다.
- SDK configure는 Android public key와 exact authenticated UUID를 함께 사용하고 log level을 error로 제한한다. diagnostics와 automatic device identifier collection은 명시적으로 비활성화한다.
- preconfigured anonymous SDK는 기존 anonymous purchase를 KinFlow account에 자동 merge하지 않고 identity conflict로 닫힌다. preconfigured custom identity만 exact `logIn(newUserId)` 전환을 허용한다.
- `clearIdentity()`는 process SDK를 anonymous 상태로 바꾸지 않고 local binding과 catalog cache만 제거한다. clear 이후 catalog/purchase/restore는 새 authenticated bind 전까지 거부된다.
- current offering의 exact offering/package/product tuple만 SDK package cache에서 구매할 수 있다. catalog reload 전 package, tampered localized price와 malformed/duplicate identifier 또는 period는 거부한다.
- purchase/restore 성공과 CustomerInfo listener는 bound user와 UTC observation만 담은 invalidation을 발생시킨다. client entitlement나 CustomerInfo 내용은 권한 상태로 사용하지 않는다.
- `BillingLifecycleHost`는 완전한 auth session과 active household가 모두 있을 때만 controller context를 만든다. auth lifecycle 변경은 generation으로 합쳐져 이전 microtask가 새 scope를 덮어쓰지 않는다.
- runtime composition은 Supabase server entitlement repository와 concrete Android adapter를 주입한다. public key가 비어 있거나 unsupported platform이면 billing port만 unavailable로 닫고 server entitlement read는 유지한다. 전체 dependency boot가 실패한 shell에서는 port와 repository 모두 unavailable fallback을 사용한다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| provider driver/adapter/composition focused tests | PASS — 17/17 |
| final selected adapter/config/app-shell regression | PASS — 41/41 |
| full Flutter regression on `purchases_flutter 10.8.0` | PASS — 599 tests; local-connectivity opt-in 1 skip; all remaining tests passed |
| Flutter analyzer | PASS — `analyze --no-pub --fatal-infos --fatal-warnings`; issue 0 |
| formatter | PASS — 358 Dart files checked; 0 changed |
| public configuration validation | PASS — dev/prod examples exact allowlist; secret-shaped key and production Test Store key rejected |
| repository secret scan | PASS — high-confidence secret 0 |
| repository code generation check | PASS — build_runner wrote 8 outputs in isolated verification; generated-code drift 0 |
| repository JavaScript contract suite | PASS — 97/97 |
| dependency license audit | PASS — 167 Pub + 15 npm; `purchases_flutter 10.8.0` and transitive `equatable 2.1.0` are MIT |
| offline OSV lockfile scan | PASS — OSV Scanner 2.3.8 checksum verified; 172 Pub + 15 npm; vulnerability 0 |
| Android dev native build/merged manifest | PASS — package `me.newlines.kinflow.dev`, min API 24, target/compile API 36, Play Billing permission allowlisted |

Android dev APK evidence:

- artifact: `apps/kinflow_app/build/app/outputs/flutter-apk/app-dev-debug.apk`
- bytes: `218446568`
- SHA-256: `dcb3601d269f0f9727cd7ca5d59a7e290d372784f438aa4acd1dc03a1973bc2a`
- report: `ci-reports/android/dev/android-dev.txt`
- dependency reports: `ci-reports/dependency/wp06-03b-license.json`, `ci-reports/dependency/wp06-03b/osv-report.json`

The tests use synthetic UUIDs, deterministic timestamps, fake SDK responses and a mocked Flutter MethodChannel. No RevenueCat/Google account, Store product, purchase, receipt, customer, family content or production credential was used.

## Files, Migration and Dependency

- Provider-private SDK boundary and concrete adapter:
  - `apps/kinflow_app/lib/infrastructure/revenuecat/revenuecat_sdk.dart`
  - `apps/kinflow_app/lib/infrastructure/revenuecat/purchases_flutter_revenuecat_sdk.dart`
  - `apps/kinflow_app/lib/infrastructure/revenuecat/revenuecat_billing_port.dart`
  - `apps/kinflow_app/lib/infrastructure/revenuecat/revenuecat_billing_composition.dart`
- App composition and fallback:
  - `apps/kinflow_app/lib/features/billing/application/unavailable_billing_port.dart`
  - `apps/kinflow_app/lib/features/billing/application/unavailable_entitlement_repository.dart`
  - `apps/kinflow_app/lib/features/billing/presentation/providers/billing_providers.dart`
  - `apps/kinflow_app/lib/features/billing/presentation/widgets/billing_lifecycle_host.dart`
  - `apps/kinflow_app/lib/app/app.dart`
  - `apps/kinflow_app/lib/app/bootstrap.dart`
  - `apps/kinflow_app/lib/app/providers/auth_dependencies.dart`
- Config/native/dependency:
  - `apps/kinflow_app/pubspec.yaml`, `apps/kinflow_app/pubspec.lock`
  - `apps/kinflow_app/lib/app/config/app_public_configuration.dart`
  - `contracts/client-public-config.schema.json`
  - `apps/kinflow_app/android/app/src/main/AndroidManifest.xml`
  - `scripts/ci/android-build.sh`
- New focused tests:
  - `apps/kinflow_app/test/infrastructure/purchases_flutter_revenuecat_sdk_test.dart`
  - `apps/kinflow_app/test/infrastructure/revenuecat_billing_port_test.dart`
  - `apps/kinflow_app/test/infrastructure/revenuecat_billing_composition_test.dart`
  - `apps/kinflow_app/test/features/billing/billing_lifecycle_host_test.dart`
  - config, auth dependency, SDK import-boundary and Android manifest contracts were extended.
- Runtime dependency: exact `purchases_flutter: 10.8.0`, locked in `pubspec.lock`; transitive addition `equatable 2.1.0`.
- Native permission: `com.android.vending.BILLING` normal permission added and enforced by the APK permission allowlist.
- Database migration, RLS, RPC, Edge/OpenAPI contract: **none** for WP06-03B. It consumes the WP06-01 entitlement RPC.

## Dependency, Platform, Security and Privacy Impact

- The package is the maintained RevenueCat Flutter bridge and passed the repository MIT allowlist and offline vulnerability scan. A major upgrade still requires an ADR and a new dependency/platform audit.
- The app's min API 24, target/compile API 36 and `singleTop` activity produced a successful native APK. RevenueCat paywall UI is not used, so `FlutterFragmentActivity` was not introduced.
- The SDK communicates with RevenueCat and Google Play and may process custom App User ID plus purchase/device/app metadata. KinFlow sends only the authenticated UUID as custom identity and sets no customer attributes, email, display name or household/family content.
- No receipt, transaction ID, CustomerInfo body, provider message or SDK exception body enters domain state, UI or logs. Server entitlement remains the sole grant authority.
- `REVENUECAT_ANDROID_PUBLIC_SDK_KEY` is client-embeddable configuration, not a server secret. Repository examples remain empty; `sk_` and malformed values fail validation, and `test_` is disallowed for production.
- The generated APK reports additional plugin permissions already introduced by notifications plus Play Billing. The exact merged permission set is checked in `android-build.sh` to catch future native drift.

## Manual and Deferred Validation

- 사용자 지시에 따라 RevenueCat project/customer, Google Play Console/license tester/internal track, actual product/offering/API key와 hosted Supabase account는 **NOT USED**다.
- 실제 Android 기기에서 purchase, pending payment, cancel, restore, reinstall, refund/revoke, offline recovery와 account/household switching은 **NOT RUN**이다.
- localized Store price/period와 CustomerInfo callback의 실제 provider semantics는 **NOT RUN**이다.
- paywall/settings 화면, benefit/terms/privacy/restore copy와 accessibility/localization은 WP06-02 및 D-027 이후 범위다.
- webhook signature/HTTP ingress, provider reconciliation, dead letter/alert와 assignment remediation은 WP06-04/05 범위다.

## Remaining Risks and Completion Boundary

1. D-027 product IDs, price, trial/annual policy, benefit copy와 Free/Plus numeric limits가 OPEN이다. adapter에는 이를 추정하거나 하드코딩하지 않았다.
2. 실제 RevenueCat/Google identity aliasing, Store pending/cancel/error code와 restore ownership semantics는 synthetic boundary에서만 검증됐다.
3. `restorePurchases()`의 local `hasStoreRecords` 판단은 server refresh를 시작하기 위한 힌트일 뿐 current entitlement 증명이 아니다. 서버가 found/empty/conflict를 최종 확정해야 한다.
4. local detach 뒤 RevenueCat process identity는 이전 custom user로 남을 수 있지만 모든 operation은 binding이 없으면 차단된다. 다음 authenticated bind가 exact identity를 교체하고 검증한다. 실제 SDK account-switch soak는 마지막 Gate다.
5. `purchases_flutter`와 기존 `sentry_flutter`가 Kotlin Gradle Plugin을 직접 적용한다는 Flutter future-migration warning, 그리고 plugin Java 8 source/target warning이 남아 있다. 현재 Flutter 3.44.7 Android build는 통과했다.
6. 이번 slice에는 사용자가 구매를 시작할 paywall UI가 없다. concrete adapter가 compose됐다는 사실을 production billing readiness로 간주하지 않는다.
7. WP06-03 상위 Gate와 Phase 06 Exit Gate는 actual Store/server/real-account/device 결과 전까지 `PARTIAL`이다.

WP06-03B 자체는 concrete Android adapter와 keyless app composition의 local automated slice로 완료했다. 이는 RevenueCat project, Google Play billing, paywall 또는 production subscription 완료가 아니다.

## Rollback

- `purchases_flutter` dependency/lock entry, RevenueCat infrastructure files, billing providers/lifecycle host, app dependency composition, public-key validation, Billing permission와 관련 tests/docs를 함께 revert한다.
- 빠른 기능 차단은 actual public SDK key를 빈 값으로 유지해 unavailable `BillingPort`를 주입한다. 이 경우 SDK configure와 Store operation은 실행되지 않고 WP06-01 server entitlement read는 유지된다.
- database/API migration이 없으므로 data rollback은 없다. provider account/customer/product도 생성하지 않아 외부 rollback 대상이 없다.

## Next Entry Condition

- 기능 우선순위상 다음 독립 slice는 **WP06-04 provider webhook HTTP ingress + reconciliation/dead-letter local contract**다. WP06-02 paywall은 D-027 product/copy 결정 없이 가격이나 혜택을 추정하지 않도록 뒤에 둔다.
- WP06-04 시작 전 current RevenueCat webhook authentication/event documentation을 확인하고 signature/authentication, payload retention, replay/idempotency, ordering, retry/dead-letter와 rollback을 workplan에 고정한다.
- provider account/secret이 없어도 ingress disabled-by-default, normalized synthetic fixtures와 local service-role boundary로 검증 가능해야 한다. 실제 webhook delivery, RevenueCat/Play account와 device testing은 사용자 지시대로 마지막 Billing Gate에 남긴다.

## Official References

- RevenueCat Flutter installation: <https://www.revenuecat.com/docs/getting-started/installation/flutter>
- RevenueCat customer identity: <https://www.revenuecat.com/docs/customers/identifying-customers>
- RevenueCat SDK configuration: <https://www.revenuecat.com/docs/getting-started/configuring-sdk>
- RevenueCat purchases/restores: <https://www.revenuecat.com/docs/getting-started/making-purchases>, <https://www.revenuecat.com/docs/getting-started/restoring-purchases>
- RevenueCat public versus secret API keys: <https://www.revenuecat.com/docs/projects/authentication>
- Official Flutter package and changelog: <https://pub.dev/packages/purchases_flutter>, <https://pub.dev/packages/purchases_flutter/changelog>
