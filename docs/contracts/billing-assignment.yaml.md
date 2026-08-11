# 원본 파일 문서화: `contracts/billing-assignment.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/billing-assignment.yaml`
- 원본 형식: `yaml`
- 범위: WP06-05 명시적 paid-household 선택, provisional binding, 충돌 projection, missing-assignment 복구와 audited support remediation

```yaml
version: "2026-08-08-wp06-05"
authority:
  callerIdentity: Supabase auth.uid()
  provider: app_private.billing_runtime_config.provider
  environment: app_private.billing_runtime_config.accepted_environment
  customerIdentity: exact authenticated UUID
  householdSelection: explicit authenticated Owner/Admin command only
  entitlementGrant: verified provider transaction only
  transfer: service-only audited remediation; never implicit
invariants:
  activeCustomerAssignment: at most one household per billing customer
  activeHouseholdAssignment: at most one billing customer per household
  provisionalIsEntitlement: false
  confirmedBy: insert or verified update of public.billing_transactions
  purchaserMembershipDrift: never deletes or transfers entitlement automatically
bindingLifecycle:
  states: [provisional, confirmed]
  provisionalLifetimeSeconds: 1800
  transitions:
    prepare: none -> provisional
    renewIntent: provisional -> provisional
    verifiedTransaction: provisional -> confirmed
    clientRelease: provisional -> ended
    expiry: provisional -> ended
    supportTransfer: confirmed -> ended plus new confirmed assignment
  confirmedClientRelease: forbidden; support_required
clientProjection:
  assignmentState: [none, provisional, confirmed]
  ownershipState: [unassigned, current_user, another_user]
  ownerMembershipState: [none, active, removed]
  fields:
    - household_id
    - assignment_state
    - ownership_state
    - owner_membership_state
    - can_prepare
    - requires_support
    - assignment_version
    - intent_expires_at
  forbidden:
    - provider customer reference or identifier
    - transaction or receipt identifier
    - another household identifier
    - billing-owner user identifier
    - support case text or external reference
authenticatedRpc:
  prepare:
    function: public.prepare_billing_household_assignment
    arguments: [p_household_id, p_idempotency_key]
    authorization: active Owner/Admin of selected household
    outcomes: [ready, already_ready, customer_conflict, household_conflict]
    exactResultKeys:
      - intent_id
      - outcome
      - binding_state
      - assignment_version
      - intent_expires_at
      - requeued_job_count
      - duplicate
    idempotency: authenticated user plus UUID key plus SHA-256 request hash
    concurrency: advisory locks on authenticated user and selected household
  release:
    function: public.release_billing_household_assignment
    arguments:
      - p_household_id
      - p_expected_assignment_version
      - p_idempotency_key
    authorization: current authenticated billing owner
    outcomes: [released, already_released, support_required]
    exactResultKeys: [outcome, assignment_version, duplicate]
  status:
    function: public.get_billing_household_assignment_status
    arguments: [p_household_id]
    authorization: active household member
    result: clientProjection
  requestRemediation:
    function: public.request_billing_assignment_remediation
    arguments: [p_household_id, p_issue_kind, p_idempotency_key]
    authorization: active Owner/Admin of requested household
    issueKinds:
      - customer_conflict
      - household_conflict
      - owner_membership_changed
      - restore_conflict
    exactResultKeys: [request_id, status, issue_kind, duplicate]
    persistedFreeFormText: false
serviceRpc:
  expire:
    function: public.expire_billing_household_assignments
    maximumBatch: 100
    rule: only expired active provisional assignment without a transaction
  resolveRemediation:
    function: public.resolve_billing_assignment_remediation
    actions: [transfer_customer, release_expired_provisional, reject]
    reasonCodes:
      - ownership_verified
      - account_recovery
      - duplicate_assignment
      - policy_denied
    requiredProof:
      - expected assignment version for non-reject actions
      - exact 32-byte SHA-256 case-reference digest encoded as base64
      - correlation UUID
    transferRequirements:
      - requester owns the provider customer
      - requester is active Owner/Admin of target household
      - source binding is confirmed
      - target has no active assignment or paid entitlement
    atomicEffects:
      - end source assignment
      - reset source entitlement without deleting household data
      - create confirmed target assignment
      - move authoritative entitlement projection
      - requeue eligible missing-assignment work
reconciliation:
  claimEligibleBinding: confirmed or unexpired provisional
  periodicEligibleBinding: confirmed only
  prepareRecovery:
    errorCode: ASSIGNMENT_REQUIRED
    sameIdentityAndEnvironmentOnly: true
    transition: requeued
    idempotent: true
storage:
  privateTables:
    - app_private.billing_assignment_intents
    - app_private.billing_assignment_release_results
    - app_private.billing_assignment_remediation_requests
    - app_private.billing_assignment_remediation_command_results
    - app_private.billing_assignment_transitions
    - app_private.billing_assignment_remediation_actions
  directAccess: revoked from public, anon, authenticated and service_role
  immutableAudit:
    - app_private.billing_assignment_transitions
    - app_private.billing_assignment_remediation_actions
errors:
  idempotencyCollision: KFB50
  unavailable: KFB51
  versionConflict: KFB52
  remediationUnavailable: KFB53
  remediationPolicyDenied: KFB54
  remediationResolutionConflict: KFB55
  immutableAuditMutation: KFB59
flutter:
  preflightOrder: assignment prepare before Store purchase or restore
  conflictBehavior: no Store call and stable conflict state
  releaseOn:
    - purchase cancelled
    - restore empty
    - final provider failure before a verified transaction
  retainOn: [pending, Store success awaiting server confirmation]
  scopeSwitch: account or household generation invalidates late results
deferredLiveGate:
  - RevenueCat alias and transfer ownership verification
  - support operator UI and ticket-system integration
  - hosted cleanup scheduler and operational replay UI
  - Apple and Google Store sandbox accounts, reinstall and physical devices
```
