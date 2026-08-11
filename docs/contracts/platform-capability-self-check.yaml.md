# 원본 파일 문서화: `contracts/platform-capability-self-check.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/platform-capability-self-check.yaml`
- 원본 형식: `yaml`
- 범위: WP01-09 Android capability 자체 점검, 우선순위 복구 계획, 로컬 알림 권한 재확인

```yaml
version: "2026-08-09-wp01-09"
requirements: [FR-NOTIF-001, FR-PLAT-008, FR-PLAT-014, NFR-PLAT-001, NFR-PLAT-002]
decisions: [D-002, D-021, D-023, D-024, D-031, D-034, D-037]
dependsOn:
  contract: platform-capability-registry@2026-08-09-wp01-08
  snapshotExactOrder:
    - notification_delivery
    - store_billing
    - secure_local_storage
    - external_links
    - background_delivery
scope:
  primary: android
  deferred: [ios, web, live_provider_health]
purpose:
  orderedRecoveryPlan: true
  notificationPermissionAndBindingRecheck: true
  providerConnectivityProbe: false
  permissionPrompt: false
  storeProbe: false
plan:
  excludesAvailableEntries: true
  stablePriority:
    - temporary_issue
    - action_required
    - fallback_only
    - limited
  tieBreaker: registry_exact_order
  summaryCounts:
    ready: available
    attention: [temporary_issue, action_required]
    alternative: [fallback_only, limited]
  entriesAreImmutable: true
  actionAndFallbackSource: registry_snapshot_only
selfCheck:
  trigger: explicit_user_action
  singleFlight: true
  operation: notification_push_coordinator.refresh_permission
  allowedSideEffects:
    - read_current_android_notification_permission
    - existing_coordinator_endpoint_safety_reconciliation
    - existing_authorized_binding_reconciliation
  sideEffectOwner: existing_notification_push_coordinator_only
  forbiddenSideEffects:
    - request_notification_permission
    - open_system_settings
    - store_sdk_request
    - provider_connectivity_probe
  resultCopy:
    success: stable_local_state_rechecked
    failure: stable_local_recheck_unavailable
    rawFailureExposed: false
screen:
  route: /settings/device-capabilities
  authRequired: true
  recoveryPlanBeforeDetails: true
  display:
    - ready attention and alternative counts
    - ordered non-ready capability steps
    - existing safe route action for each step
    - explicit coordinator-owned recheck boundary
  actionsAreExistingRoutesOnly: true
privacy:
  accountHouseholdDevicePaymentIdentifiers: forbidden
  configurationAndCredentialValues: forbidden
  rawProviderErrors: forbidden
  telemetryAdded: false
accessibility:
  localized: [EN, KO, EN-XA]
  stateNotColorOnly: true
  liveRegionForSelfCheckResult: true
  minimumActionTargetDp: 48
  compactTextScale: 200%
  scrollableParent: true
verification:
  - every non-ready state appears once in stable recovery order
  - available entries are counted but excluded from recovery steps
  - summary counts exactly partition the five capabilities
  - repeated taps while checking invoke one refresh only
  - refresh reads permission without requesting it or opening system settings
  - endpoint cleanup or authorized rebinding stays inside the existing coordinator
  - refreshed NotificationPushState immediately recomputes the plan
  - unavailable and thrown refreshes expose only stable localized copy
  - EN KO and EN-XA 200 percent render without overflow
rollback:
  removeRecoveryPlanEntityAndSelfCheckSection: true
  registryAndExistingCapabilityDetailsRemain: true
  databaseOrStoredDataMigrationRequired: false
deferred:
  - actual Android permission change after returning from system settings
  - Firebase RevenueCat Google Play Keystore browser and hosted health probes
  - real account multi-device and physical-device validation
  - iOS and Web recovery plans
```
