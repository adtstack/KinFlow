# 원본 파일 문서화: `contracts/analytics-governance.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/analytics-governance.yaml`
- 원본 형식: `yaml`
- 범위: WP01-10 Android privacy-safe analytics governance와 device-local preference

```yaml
version: "2026-08-09-wp01-10"
requirements: [FR-PLAT-001, FR-PLAT-002, FR-PLAT-003, NFR-PRIV-01, NFR-OBS-01]
decisions: [D-002, D-013, D-014, D-033, D-034, D-035, D-047]
scope:
  platform: android
  accountAudience: adult_only_store_mvp
  externalBehavioralAnalyticsSink: unavailable
  operationalErrorReporter: sentry_privacy_filtered
  deferred: [approved_remote_analytics_sink, legal_consent_review, managed_child_runtime, ios, web]
preference:
  purpose: optional_usage_analytics_only
  default: withdrawn
  legalConsentRecord: false
  scope: device_and_environment
  policyVersion: analytics-usage-v1
  storedValues: [analytics-usage-v1|granted, analytics-usage-v1|withdrawn]
  missingStaleMalformedOrReadFailure: withdrawn
  policyOrProviderExpansionResetsTo: withdrawn
  persistsAcrossLogout: true
  identifiersStored: false
storage:
  adapter: flutter_secure_storage
  namespace: kinflow_analytics_<environment>_v1
  key: analytics_usage_preference_v1
  backupMigration: false
  databaseMigration: none
  apiMutation: none
eventAllowlist:
  eventVersion: 1
  exactNames:
    - application.session.started
    - household.activation.progressed
    - invite.accept.succeeded
    - chore.complete.succeeded
    - calendar.occurrence.opened
    - billing.purchase.pending_server_confirmation
  arbitraryEventName: forbidden
  arbitraryAttributes: forbidden
envelope:
  exactFields: [event_name, event_version, platform, app_release, environment]
  platform: android
  publicBuildMetadataOnly: true
  identifiers: forbidden
  content: forbidden
dispatchGate:
  order: [managed_child_block, granted_preference, sink_available, best_effort_emit]
  managedChildResult: blocked_child_mode
  unsetOrWithdrawnResult: blocked_preference
  unavailableSinkResult: unavailable
  sinkFailureResult: failed_without_throw
  applicationMutationMayFailFromAnalytics: false
  activeIntegration: application_session_started_once_per_authenticated_entry
sdkInventory:
  directRuntimeDependencies:
    - firebase_core
    - firebase_messaging
    - flutter
    - flutter_local_notifications
    - flutter_localizations
    - flutter_web_plugins
    - flutter_riverpod
    - flutter_secure_storage
    - freezed_annotation
    - go_router
    - google_sign_in
    - intl
    - json_annotation
    - package_info_plus
    - purchases_flutter
    - sentry_flutter
    - supabase_flutter
    - timezone
    - url_launcher
  externalBehavioralAnalyticsPackages: []
  serviceDataPackages:
    authentication: [google_sign_in, supabase_flutter]
    notifications: [firebase_core, firebase_messaging, flutter_local_notifications]
    billing: [purchases_flutter]
    operationalErrors: [sentry_flutter]
  forbiddenUnreviewedPackages:
    - firebase_analytics
    - google_mobile_ads
    - app_tracking_transparency
    - appsflyer_sdk
    - adjust_sdk
    - amplitude_flutter
    - mixpanel_flutter
    - facebook_app_events
  anyDependencyChangeRequiresInventoryUpdate: true
privacy:
  forbiddenData:
    - user_account_household_member_or_child_identifier
    - email_name_profile_or_family_content
    - chore_calendar_notification_or_billing_content
    - token_receipt_url_query_or_raw_error
    - location_contacts_advertising_id_or_device_fingerprint
    - locale_timezone_request_id_or_pseudonymous_identifier_in_wp01_10
  sentryOperationalEventsRemainSeparate: true
  logAttributesAdded: false
screen:
  route: /settings/analytics-privacy
  authenticated: true
  shows: [optional_preference, collection_status, event_boundary, child_policy, sdk_inventory, never_collected]
  mutationSingleFlight: true
  rawErrorExposed: false
accessibility:
  localized: [EN, KO, EN-XA]
  minimumActionTargetDp: 48
  compactTextScale: 200%
  scrollableParent: true
verification:
  - direct dependency inventory exactly matches pubspec runtime dependencies
  - no forbidden unreviewed analytics advertising or tracking package is present
  - only typed allowlisted event names can reach the sink
  - envelope has exactly five public content-free fields
  - managed child blocks before preference read and sink access
  - missing withdrawn stale malformed and read failure never emit
  - sink unavailable and sink failure never fail an application operation
  - preference load and save are single-flight with stable localized recovery
  - Sentry is never composed as the optional behavioral analytics sink
rollback:
  removeSettingsRouteAndLifecycleHost: true
  removeDedicatedSecurePreferenceNamespace: true
  restoreNoAnalyticsPortComposition: true
  databaseOrRemoteCleanupRequired: false
deferred:
  - approved analytics provider contract retention region access and deletion
  - final legal basis consent copy policy version and server consent record
  - actual managed child runtime and parental policy validation
  - hosted dashboard real account multi-device and physical-device validation
  - iOS and Web sink composition
```
