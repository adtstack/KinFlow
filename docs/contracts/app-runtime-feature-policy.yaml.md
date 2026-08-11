# 원본 파일 문서화: `contracts/app-runtime-feature-policy.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/app-runtime-feature-policy.yaml`
- 원본 형식: `yaml`
- 범위: WP08-04B Android capability별 server-authoritative mutation policy, exact public projection, operator audit, DB enforcement와 client advisory UX

```yaml
version: "2026-08-09-wp08-04b"
requirements:
  - FR-PLAT-004
  - NFR-COMP-01
  - D-031
  - D-042
scope:
  approvedRuntime: android
  environments: [dev, prod]
  features:
    - household
    - chores
    - calendar
    - notifications
    - profile
    - billing
  webIosCohortPercentageRules: deferred
authority:
  policyTable: app_private.app_runtime_feature_policies
  auditTable: app_private.app_runtime_feature_policy_events
  policyRead: public.get_app_runtime_feature_policies
  policyMutation: public.configure_app_runtime_feature_policy
  mutationDecision: app_private.enforce_app_runtime_policy trigger with exact feature argument
  clientBannerAndGuards: advisory only
policy:
  key: [environment, platform, feature]
  fields:
    mutationsEnabled: existing capability mutation availability
    policyVersion: positive optimistic concurrency version
    updatedAt: server timestamp
  seededDefault:
    mutationsEnabled: true
    reason: explicit compatibility-open seed for already-shipped capabilities
  safeDefault:
    missingUnknownDuplicateOrMalformed: fail closed as runtime policy unavailable
    newFeature: requires explicit server seed, client enum, table classification, tests, and review
  precedence:
    - updateRequired from the global runtime policy
    - globalReadOnly from the global runtime policy
    - featureDisabled from the table-classified feature policy
    - allowed otherwise
publicReadRpc:
  function: public.get_app_runtime_feature_policies
  arguments: [p_environment, p_platform]
  executeGrant: [anon, authenticated]
  rowCount: 6
  sort: feature ascending
  exactResultKeys:
    - environment
    - platform
    - feature
    - mutations_enabled
    - policy_version
    - updated_at
    - evaluated_at
  directTableRead: denied
  privacy: no identity, household, content, provider, token, reason, cohort, arbitrary copy, or URL
operatorMutationRpc:
  function: public.configure_app_runtime_feature_policy
  executeGrant: service_role
  arguments:
    - p_environment
    - p_platform
    - p_feature
    - p_mutations_enabled
    - p_expected_version
    - p_correlation_id
  concurrency: exact row FOR UPDATE plus expected policy version
  idempotency: correlation ID replay returns the original exact result; mismatched reuse fails
  audit:
    immutable: true
    contentFree: true
databaseEnforcement:
  tableClassification:
    profile:
      - profiles
    household:
      - households
      - household_members
      - user_active_households
      - household_invites
    chores:
      - chore_series
      - chore_series_revisions
      - chore_occurrences
      - chore_completion_events
      - chore_reschedule_events
      - chore_assignment_events
      - chore_series_change_events
      - one_time_chore_change_events
    calendar:
      - event_series
      - event_series_revisions
      - event_participants
      - event_occurrences
      - event_revision_participants
      - event_occurrence_exceptions
      - event_series_change_events
      - calendar_sync_watermarks
    notifications:
      - notification_preferences
      - notification_inbox_items
      - notification_endpoints
    billing:
      - billing_customers
      - billing_webhook_receipts
      - billing_transactions
      - billing_household_assignments
      - plan_catalog
      - household_entitlements
  triggerCount: 30
  stableError:
    featureDisabled: {sqlState: KFR06, clientCode: CLIENT_FEATURE_DISABLED, httpStatus: 503, retryable: true}
  directAndEdgeUserOperations: enforced
  markerlessServiceAndWorkerOperations: preserved
  privacyExportDeleteOperations: preserved
  transactionCache: global decision once plus successful decision once per exact feature
client:
  repositoryLoad: global policy and exact six feature rows form one advisory snapshot
  parser: exact seven-field rows; exact six unique features; strict type, UTC, scope, version, and timestamp invariants
  fetchFailure: no feature is guessed enabled; app reads remain and online DB authority handles attempted mutations
  featureGuardProvider: family keyed by exact feature enum
  mutationMapping:
    household: household/member/invite/onboarding mutations
    chores: chore/guided-setup mutations
    calendar: calendar event/series/occurrence mutations
    notifications: permission/endpoint/preference/inbox mutations
    profile: profile and locale/timezone mutation
    billing: purchase/restore/remediation mutations
  presentation:
    globalRestrictionPrecedence: update/read-only/unavailable banner remains stronger
    featureRestriction: deterministic localized feature list with retry; app and unrelated features remain usable
    compactLayout: bounded scrollable panel, wrapped actions, 200 percent pseudo text
  localization: [en, ko, en-XA]
security:
  featurePolicyIsAuthorization: false
  independentBoundaries: [RLS, role, domain invariant, expected version, idempotency]
  privateHelpers: revoked from public, anon, authenticated, and service_role
  rawProviderErrorsToUi: forbidden
rollback:
  emergency: re-enable an exact feature with expected version and a new correlation ID
  client: remove feature banner/family guards while retaining server enforcement
  schema: forward-only restore globally classified triggers before removing feature tables/RPC; never rewrite applied migration
deferred:
  - percentage rollout, cohort targeting, per-household or per-user overrides
  - hosted dev/prod propagation, monitoring, operator runbook and rollback drill
  - N-1 signed binary, Play staged rollout, real accounts, multi-device and physical-device validation
  - iOS App Store and Web Companion adapters
```
