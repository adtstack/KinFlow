# 원본 파일 문서화: `contracts/platform-capability-registry.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/platform-capability-registry.yaml`
- 원본 형식: `yaml`
- 범위: WP01-08 Android-first platform capability registry와 Settings 상태 화면

```yaml
version: "2026-08-09-wp01-08"
requirements: [FR-PLAT-008, FR-PLAT-014, NFR-PLAT-001, NFR-PLAT-002]
decisions: [D-002, D-003, D-021, D-023, D-024, D-031, D-034, D-037]
platformScope:
  primary: android
  deferred: [ios, web]
purpose:
  providerSelectionSnapshot: true
  explicitSupportAndFallbackState: true
  runtimeHealthMonitor: false
  remoteFeaturePolicy: false
registry:
  exactOrder:
    - notification_delivery
    - store_billing
    - secure_local_storage
    - external_links
    - background_delivery
  rejectUnknownOrDuplicateEntries: true
  entries:
    notification_delivery:
      primaryProvider: firebase_messaging_android | unavailable
      fallback: in_app_inbox
    store_billing:
      primaryProvider: revenuecat_google_play | unavailable
      fallback: server_entitlement_read_only
    secure_local_storage:
      primaryProvider: android_keystore | unavailable
      fallback: reauthenticate_without_persistent_cache
    external_links:
      primaryProvider: android_system_uri_launcher | unavailable
      fallback: on_screen_guidance_and_diagnostics
    background_delivery:
      primaryProvider: firebase_background_message_handler | unavailable
      fallback: server_notification_pipeline_and_in_app_inbox
compositionInputs:
  notificationAdapterComposed: boolean
  billingPortAvailable: boolean
  encryptedReadCacheComposed: boolean
  externalUriLauncherComposed: boolean
  secretOrPublicConfigurationValuesExposed: false
runtimeInput:
  notificationSignal:
    - unavailable
    - not_determined
    - denied
    - authorized
    - temporary_failure
  source: existing in-process NotificationPushState
  providerCallFromRegistryScreen: false
states:
  - available
  - action_required
  - limited
  - fallback_only
  - temporary_issue
notificationResolution:
  adapterMissing: [fallback_only, provider_not_configured, open_notification_center]
  unavailable: [fallback_only, runtime_unavailable, open_notification_center]
  notDetermined: [action_required, permission_not_determined, open_notification_center]
  denied: [action_required, permission_denied, open_notification_center]
  authorizedWithFailure: [temporary_issue, provider_temporarily_unavailable, open_notification_center]
  authorized: [available, provider_ready, none]
fixedResolution:
  storeBilling:
    adapterComposed: [available, provider_ready, none]
    adapterMissing: [fallback_only, provider_not_configured, open_subscription_settings]
  secureLocalStorage:
    encryptedCacheComposed: [available, provider_ready, none]
    encryptedCacheMissing: [fallback_only, provider_not_configured, open_diagnostics]
  externalLinks:
    launcherComposed: [available, provider_ready, none]
    launcherMissing: [fallback_only, provider_not_configured, open_diagnostics]
  backgroundDelivery:
    pushAdapterComposed: [limited, server_authoritative, open_notification_center]
    pushAdapterMissing: [fallback_only, provider_not_configured, open_notification_center]
screen:
  route: /settings/device-capabilities
  authRequired: true
  activeHouseholdRequiredForRead: false
  source: registry snapshot plus notification in-process state
  display:
    - localized capability name
    - text-and-icon state label
    - selected provider label
    - stable reason
    - concrete fallback or alternative
  actionsAreExistingRoutesOnly: true
  mutation: false
  networkRequest: false
  storeSdkRequest: false
  permissionRequest: false
failureAndPrivacy:
  unavailableBootstrapUsesFailClosedRegistry: true
  rawProviderExceptionExposed: false
  configurationKeyOrValueExposed: false
  accountHouseholdDeviceOrPaymentIdentifierExposed: false
  telemetryAdded: false
accessibility:
  localized: [EN, KO, EN-XA]
  statusNotColorOnly: true
  semanticCardSummary: true
  minimumActionTargetDp: 48
  compactTextScale: 200%
  scrollableParent: true
verification:
  - exact five-entry order and no duplicate identifiers
  - every notification permission and temporary state maps deterministically
  - unavailable providers retain a named fallback and safe route action
  - bootstrap injects the same registry snapshot used by Settings
  - screen renders EN KO and EN-XA 200 percent without overflow
  - screen does not invoke provider network Store permission or persistence APIs
rollback:
  removeRegistryProviderAndSettingsRoute: true
  existingProviderCompositionUnchanged: true
  databaseOrStoredDataMigrationRequired: false
deferred:
  - real Firebase RevenueCat Play Keystore and browser health checks
  - actual Android permission and system-settings transitions
  - hosted server fallback and cross-device delivery validation
  - iOS and Web provider selection
  - remote runtime mutation policy changes
```
