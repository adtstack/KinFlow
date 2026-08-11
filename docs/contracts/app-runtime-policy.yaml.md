# 원본 파일 문서화: `contracts/app-runtime-policy.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/app-runtime-policy.yaml`
- 원본 형식: `yaml`
- 범위: WP08-04A Android server-authoritative runtime policy, emergency read-only mode, minimum supported build/contract, client advisory UX와 database mutation enforcement

```yaml
version: "2026-08-09-wp08-04a"
requirements:
  - FR-PLAT-004
  - FR-PLAT-005
  - NFR-COMP-01
  - D-030
  - D-031
  - D-042
scope:
  approvedRuntime: android
  environments: [dev, prod]
  webAndIos: deferred
authority:
  policyTable: app_private.app_runtime_policies
  policyMutation: public.configure_app_runtime_policy
  policyRead: public.get_app_runtime_policy
  mutationDecision: app_private.enforce_app_runtime_policy trigger
  clientBanner: advisory only
relatedPolicy:
  capabilityContract: app-runtime-feature-policy.yaml
  precedence: this global update/read-only decision is evaluated before an exact capability mutation switch
policy:
  key: [environment, platform]
  platformValues: [android]
  fields:
    minimumSupportedVersion: bounded semantic display version
    minimumSupportedBuild: monotonic Android build number, zero disables build gating
    minimumContractVersion: optional ISO date lower bound
    maximumContractVersion: optional ISO date upper bound
    mutationsEnabled: global non-privacy mutation kill switch
    policyVersion: positive optimistic concurrency version
    updatedAt: server timestamp
  seededDefault:
    minimumSupportedVersion: 0.0.0
    minimumSupportedBuild: 0
    minimumContractVersion: null
    maximumContractVersion: null
    mutationsEnabled: true
  precedence:
    - updateRequired when build or contract is outside the supported range
    - readOnly when mutationsEnabled is false
    - allowed otherwise
  forcedUpdateRule: emergency only; lowering the minimum is allowed as an audited rollback
publicReadRpc:
  function: public.get_app_runtime_policy
  arguments: [p_environment, p_platform]
  executeGrant: [anon, authenticated]
  exactResultKeys:
    - environment
    - platform
    - minimum_supported_version
    - minimum_supported_build
    - minimum_contract_version
    - maximum_contract_version
    - mutations_enabled
    - policy_version
    - updated_at
    - evaluated_at
  directTableRead: denied
  privacy: no identity, household, content, provider, token, arbitrary copy, or URL
operatorMutationRpc:
  function: public.configure_app_runtime_policy
  executeGrant: service_role
  arguments:
    - p_environment
    - p_platform
    - p_minimum_supported_version
    - p_minimum_supported_build
    - p_minimum_contract_version
    - p_maximum_contract_version
    - p_mutations_enabled
    - p_expected_version
    - p_correlation_id
  concurrency: exact row FOR UPDATE plus expected policy version
  idempotency: correlation ID replay returns the original exact result; mismatched reuse fails
  audit:
    table: app_private.app_runtime_policy_events
    immutable: true
    contentFree: true
mutationEnforcement:
  requestHeaders:
    X-KinFlow-Client-Version: configured full version
    X-KinFlow-Client-Build: numeric Android build
    X-KinFlow-Contract-Version: ISO date contract
    X-KinFlow-Platform: android
    X-KinFlow-Environment: dev or prod
  edgeForwarding:
    clientHeaderAllowlist:
      - X-KinFlow-Client-Version
      - X-KinFlow-Client-Build
      - X-KinFlow-Contract-Version
      - X-KinFlow-Platform
      - X-KinFlow-Environment
    runtimeOwnedMarker: X-KinFlow-Forwarded-User-Operation = 1
    clientSuppliedMarker: discarded; never forwarded
    malformedPresentHeader: fail closed with the stable policy-unavailable error
  directUserOperation: auth.uid is present and the trigger evaluates the request headers
  edgeUserOperation: service-role RPC carries the runtime-owned marker and remains policy-enforced
  serviceBypass: service and worker writes without the runtime-owned user-operation marker remain available
  missingLegacyHeaders:
    environment: prod
    platform: android
    build: 0
    contract: null
  stableErrors:
    updateRequired: {sqlState: KFR01, clientCode: CLIENT_UPDATE_REQUIRED}
    mutationsDisabled: {sqlState: KFR02, clientCode: CLIENT_MUTATIONS_DISABLED}
    policyUnavailable: {sqlState: KFR03, clientCode: RUNTIME_POLICY_UNAVAILABLE}
  protectedData:
    - profiles and active-household selection
    - household, member, and invite aggregates
    - chore and calendar aggregates/events
    - notification preference, inbox, and endpoint state
    - billing customer, assignment, transaction, and entitlement state
  preservedOperations:
    - authenticated reads and bounded offline read cache
    - sign-in, sign-out, and session recovery
    - personal data export and download grant access
    - account deletion request and cancellation
    - Owner household export/deletion request and cancellation
    - legal, support, and PII-safe diagnostics
  performance: one successful evaluation is cached only for the current database transaction
client:
  parser: exact ten-field DTO; unknown, missing, mistyped, non-UTC, mismatch, and invalid range fail closed to unavailable state
  installedIdentity:
    applicationId: exact configured flavor ID
    versionAndBuild: package metadata must match APP_VERSION
    contractVersion: exact configured ISO date
    environmentAndPlatform: exact policy correlation
  lifecycle: initial load, explicit retry, and foreground-resume refresh
  policyFetchFailure:
    localBehavior: do not block cached reads or privacy routes
    mutationAuthority: database trigger remains authoritative when the backend is reachable
  knownRestriction:
    localBehavior: common mutation notifiers stop before provider or network I/O
    updateAction: fixed Play Store HTTPS URL derived only from the validated application ID
    arbitraryServerUrl: forbidden
  localization: [en, ko, en-XA]
security:
  compatibilityHeadersAreAuthorization: false
  note: headers can be spoofed by a modified client; RLS and domain authorization remain independent
  privilegedForwardingMarker: owned by Edge runtime composition and excluded from client CORS/header forwarding
  privateHelpers: revoked from public, anon, authenticated, and service_role
  rawProviderErrorsToUi: forbidden
rollback:
  emergency: configure mutationsEnabled=true or lower the supported build/contract with a new correlation ID
  client: remove lifecycle/banner/provider advisory wiring while server enforcement continues
  schema: forward-only removal of triggers before policy tables/functions; never rewrite applied migration
deferred:
  - Store-console staged rollout and physical-device Play update handoff
  - hosted dev/prod policy propagation drill
  - N-1 signed binary rehearsal
  - iOS App Store and Web Companion policy adapters
```
