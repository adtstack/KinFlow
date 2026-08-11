# 원본 파일 문서화: `contracts/web-companion-baseline.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/web-companion-baseline.yaml`
- 원본 형식: `yaml`
- 범위: WP01-12 Flutter Web Companion build, runtime identity, email-first auth and safe capability fallback baseline

```yaml
version: "2026-08-10-wp01-12"
requirements:
  - FR-AUTH-010
  - FR-AUTH-011
  - FR-NOTIF-008
  - FR-SUB-011
  - FR-SET-008
  - FR-PLAT-007
  - FR-PLAT-008
  - FR-PLAT-009
  - FR-PLAT-011
  - FR-PLAT-012
  - FR-PLAT-013
  - FR-PLAT-014
  - FR-PLAT-015
  - FR-PLAT-016
  - NFR-PLAT-001
  - NFR-PLAT-002
  - NFR-PLAT-003
  - NFR-WEB-001
  - NFR-WEB-002
  - NFR-WEB-003
  - NFR-WEB-004
  - NFR-REL-001
  - NFR-REL-002
decisions: [D-001, D-003, D-006, D-030, D-031, D-043, D-044, D-047, D-049, D-069, D-070]
scope:
  platform: Flutter Web Companion
  environments: [dev, prod]
  releaseGate: independent from Android Store MVP
  productionReadiness: partial
  realAccountAndHostedValidation: deferred
entrypoints:
  dev: lib/main_dev.dart
  prod: lib/main_prod.dart
  sharedBootstrap: true
runtimeIdentity:
  packageName: kinflow_app
  platformHeader: web
  environments: [dev, prod]
  exactHeaders:
    - X-KinFlow-Client-Version
    - X-KinFlow-Client-Build
    - X-KinFlow-Contract-Version
    - X-KinFlow-Platform
    - X-KinFlow-Environment
  clientVersionAuthority: build/web/version.json generated from exact APP_VERSION
  timestampInput:
    acceptedUtcSuffixes: [Z, "+00:00"]
    nonUtc: rejected
auth:
  primaryWebMethod: email OTP
  supabaseSessionAuthority: true
  nativeGoogleLauncher: unavailable
  oauthPkceCallback: deferred until hosted redirect origin is approved
  otpRequestAndVerification: provider-neutral existing ports
  sessionPersistence:
    allowed: provider-owned authentication session only
    purgeOnLogoutAccountSwitchRemoval: required
  realMailboxAndAccountTest: deferred
serverCapabilities:
  householdAndCoreRepositories: shared authenticated Supabase APIs
  runtimePolicy:
    platforms: [android, web]
    environments: [dev, prod]
    exactFeatures: [household, chores, calendar, notifications, profile, billing]
    configurationAuthority: service role only
    mutationEnforcement: database authoritative
  entitlement:
    read: server household snapshot
    purchase: unavailable on Web baseline
platformRegistry:
  exactOrder:
    - notifications
    - billingPurchase
    - secureLocalStorage
    - externalLinks
    - backgroundExecution
  web:
    notifications:
      provider: deferredWebPush
      fallback: inAppInboxAndConfiguredEmail
    billingPurchase:
      provider: unavailable
      fallback: serverEntitlementReadOnly
    secureLocalStorage:
      provider: unavailableForApplicationCache
      fallback: reauthenticateWithoutPersistentCache
    externalLinks:
      provider: browserExternalUriLauncher
      fallback: explicitCopyOrRetry
    backgroundExecution:
      provider: foregroundOnly
      fallback: serverNotificationAndInbox
localDurability:
  persistentReadCache: disabled
  guidedChoreResume: disabled
  choreCompletionOutbox: disabled
  notificationEndpointBinding: disabled
  authenticationSession: purgeable
  offlineMutation: forbidden
webShell:
  urlStrategy: path
  baseHref: /
  referrerPolicy: no-referrer
  robots: noindex nofollow noarchive
  pwaInstallManifest: absent
  flutterServiceWorker: disabled
  persistentApiCache: disabled
  directRouteHostingRewrite: required but not selected
  contentSecurityPolicy: required at hosted Gate
releaseBuild:
  sdk:
    flutter: 3.44.7
    dart: 3.12.2
  mode: release
  publicConfiguration: exact allowlist and environment binding
  buildNameAndNumber: exact APP_VERSION split
  flavors: [dev, prod]
  reports:
    - source commit and dirty state
    - runtime version
    - service-worker and persistent-cache state
    - main.dart.js bytes and SHA-256
  ciJob: independent web dev/prod matrix
accessibilityAndLocalization:
  localization: [EN, KO, EN-XA]
  signInSemantics:
    - localized heading
    - disabled unavailable Google action
    - enabled email field and OTP request action
  authenticatedCoreResponsiveContract: shared with core-primary-navigation.yaml
securityAndPrivacy:
  clientServerSecrets: forbidden
  familyContentInRuntimeHeaders: forbidden
  providerIdentifiersInCapabilityState: forbidden
  broadBrowserCache: forbidden
  serviceWorkerUserDataCache: forbidden
  webPushPermissionPrompt: forbidden in this baseline
automatedEvidence:
  - exact Web composition and purge tests
  - exact capability registry snapshot
  - runtime identity and PostgREST UTC timestamp mapping
  - Web scaffold architecture test
  - public config and workflow contract tests
  - dev and prod release build audits
  - Web runtime policy pgTAP
localBrowserEvidence:
  rootNavigationToSignIn: required
  runtimePolicyReadWithoutBanner: required
  emailOtpControlEnabled: required
  googleControlDisabled: required
  directSignInReloadOnGenericStaticServer: known404
deferred:
  - approved hosted origin, HTTPS, CSP and SPA fallback rewrite
  - OAuth PKCE callback and redirect URL scrubbing
  - real email OTP, account switch and removal residue checks
  - authenticated core keyboard-only, screen-reader and browser matrix
  - hosted runtime policy propagation and rollback drill
  - cross-platform entitlement journey
  - atomic deployment, stale-tab recovery and rollback
  - Web Push and Web purchase provider
rollback:
  removeWebPlatformScaffoldAndIndependentCiJob: true
  removeWebRuntimePolicyRowsWithForwardMigrationOnly: true
  preserveAndroidRuntimePolicyAndNativeComposition: true
```
