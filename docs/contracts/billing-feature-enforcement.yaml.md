# 원본 파일 문서화: `contracts/billing-feature-enforcement.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/billing-feature-enforcement.yaml`
- 원본 형식: `yaml`
- 범위: WP06-06 entitlement lifecycle, policy-neutral activation, household feature gate, member/recurring-series server enforcement와 downgrade data preservation

```yaml
version: "2026-08-08-wp06-06"
policyStatus:
  decision: D-027 remains OPEN
  numericLimitsInContract: false
  defaultEnforcementEnabled: false
  activationAuthority: service_role only
  rolloutRule: both Free and Plus policies must be finalized before activation
authority:
  entitlement: public.household_entitlements
  planPolicy: public.plan_catalog
  runtimeSwitch: app_private.billing_runtime_config.feature_enforcement_enabled
  clientGate: advisory UX projection only
  mutationDecision: serialized database trigger enforcement
lifecycle:
  statuses: [none, trialing, active, grace, billing_issue, expired, revoked]
  effectivePlanRules:
    trialing: plus
    active: plus
    grace: plus
    none: free
    expired: free
    revoked: free
    billing_issue: free or plus as materialized by the server policy
  terminalDataRule: expiration, revoke, refund, or downgrade never deletes existing household data
features:
  members:
    usage: household_members where removed_at is null
    expansionPoints: [member insert, removed member reactivation]
  activeSeries:
    usage:
      - active non-deleted chore series whose active revision is recurring
      - active non-deleted calendar series whose active revision is recurring
    excludes: [one-time chore series, one-time calendar series, deleted series]
    expansionPoints:
      - first recurring chore revision
      - first recurring calendar revision
      - recurring chore series reactivation
      - recurring calendar series reactivation
activationRpc:
  function: public.configure_billing_feature_enforcement
  arguments: [p_enabled, p_expected_version, p_correlation_id]
  executeGrant: service_role
  exactResultKeys: [feature_enforcement_enabled, version]
  enablePreconditions:
    - active Free and Plus catalog rows exist
    - both policies have limits_finalized=true
    - both policies contain members and activeSeries
    - members capacity is at least one for both plans
    - every Free feature capacity is present in Plus and Plus is not lower
  concurrency: billing runtime row FOR UPDATE plus expected version
  audit:
    table: app_private.billing_policy_events
    exactPolicyIdentity: [runtime, feature_enforcement]
    correlationIdRequired: true
    immutable: true
  enabledPolicyProtection:
    - required policies cannot be deactivated
    - required policies cannot be made unfinalized
    - members or activeSeries cannot be removed
    - emergency disable remains allowed
authenticatedGateRpc:
  function: public.get_household_feature_gate
  arguments: [p_household_id, p_feature_key, p_requested_delta]
  executeGrant: authenticated
  authorization: active member of the exact household
  featureKeys: [members, activeSeries]
  requestedDelta: {minimum: 1, maximum: 1000, default: 1}
  decisions: [allowed, policy_unavailable, feature_unconfigured, limit_reached]
  exactResultKeys:
    - decision
    - household_id
    - feature_key
    - requested_delta
    - current_usage
    - limit_value
    - remaining_after_delta
    - plan_code
    - entitlement_status
    - enforcement_enabled
    - limits_finalized
    - entitlement_version
    - policy_version
    - runtime_version
    - evaluated_at
  failClosedRules:
    policy_unavailable: limit_value and remaining_after_delta are null
    feature_unconfigured: limit_value and remaining_after_delta are null
    allowed: remaining_after_delta exactly equals limit minus usage minus requested delta
    limit_reached: remaining_after_delta equals zero
mutationEnforcement:
  disabledBehavior: mutation triggers return without imposing an unapproved numeric policy
  enabledBehavior:
    lock: transaction advisory lock by household and feature
    lockedRows: household entitlement and plan catalog are read FOR SHARE
    errors:
      policyUnavailable: {sqlState: KFB10, clientCode: FEATURE_POLICY_UNAVAILABLE}
      featureUnconfigured: {sqlState: KFB11, clientCode: FEATURE_POLICY_UNAVAILABLE}
      limitReached: {sqlState: KFB12, clientCode: FEATURE_LIMIT_REACHED}
  preservedOperations:
    - read existing household data
    - update existing series or occurrences without capacity expansion
    - cancel or delete existing series
    - create one-time chores and calendar events
    - remove members
  downgradeRule: over-limit existing data is preserved; only new or reactivated expansion is denied
privacy:
  allowedClientData: aggregate usage, aggregate limit, plan/status, versions, decision, timestamp
  forbiddenClientData:
    - provider or customer identifier
    - transaction or receipt identifier
    - billing-owner user identifier
    - member identifiers
    - another household identifier
    - chore, calendar, or family content
directAccess:
  privateHelpers: revoked from public, anon, authenticated, and service_role
  planAndRuntimeMutation: mediated service RPCs only
clientContract:
  mapper: exact 15-field projection with UTC and decision-arithmetic validation
  staleClientEntitlementIsAuthority: false
  featurePolicyUnavailableUx: localized retryable policy message
  featureLimitReachedUx: localized plan-limit message
  inviteAcceptTransport:
    KFB10: FEATURE_POLICY_UNAVAILABLE
    KFB11: FEATURE_POLICY_UNAVAILABLE
    KFB12: FEATURE_LIMIT_REACHED
```
