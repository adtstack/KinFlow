# 원본 파일 문서화: `contracts/account-deletion.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/account-deletion.yaml`
- 원본 형식: `yaml`
- 범위: WP07-01 앱 내 account deletion 요청·상태·취소, 최근 인증, delayed worker, identity tombstone, Auth soft-delete와 local purge

```yaml
version: "2026-08-08-wp07-01"
requirements: [FR-AUTH-006, FR-AUTH-008, FR-SET-004]
decisions: [D-017, D-040, D-041, D-049]
scope:
  implemented:
    - authenticated in-app preflight, request, status, and cancel
    - recent OAuth proof for request creation
    - 24-hour default cancellation window
    - leased background identity tombstone and Supabase Auth soft-delete
    - shared household data preservation
    - local sign-out, endpoint revoke, provider identity reset, and encrypted cache purge handoff
  deferred:
    - public web deletion request path
    - household deletion and data export
    - legal copy and retention approval
    - hosted scheduler, real account, Store, multi-device, and physical-device evidence
authority:
  bearerIdentity: Supabase Auth user returned by /auth/v1/user
  recentAuthentication: separately authenticated OAuth AMR proof for the same user
  requestState: public.privacy_requests
  commandIdempotency: app_private.account_deletion_command_requests
  jobState: app_private.account_deletion_jobs
  lifecycleAudit: app_private.account_deletion_events
  runtimeConfiguration: app_private.privacy_runtime_config
  authDeletion: Supabase Auth Admin soft-delete after database tombstone
stateMachine:
  requestStatuses: [queued, verifying, processing, completed, failed, cancelled]
  pendingStatuses: [queued, verifying, processing]
  cancellableStatuses: [queued, verifying]
  terminalStatuses: [completed, failed, cancelled]
  onePendingRequestPerUserAndType: true
  optimisticCancellationVersionRequired: true
runtime:
  defaultRequestsEnabled: true
  defaultCancellationWindowSeconds: 86400
  allowedCancellationWindowSeconds: {minimum: 3600, maximum: 604800}
  configurationAuthority: service_role only
  updateConcurrency: expected version plus row lock
  audit: immutable previous/next enabled, cancellation window, version, correlation ID
edge:
  function: account-deletion
  method: POST
  maximumBodyBytes: 8192
  contentType: application/json
  responseCache: no-store
  contractVersion: "2026-08-08-wp07-01"
  commonHeaders:
    required: [Authorization]
    optional: [X-Request-Id]
  operations:
    preflight:
      exactBody: {operation: preflight}
      httpStatus: 200
      exactDataKeys:
        - canRequest
        - ownerHouseholdCount
        - hasActiveSubscription
        - pendingRequestId
        - pendingStatus
        - pendingRequestVersion
        - requestsEnabled
        - cancellationWindowSeconds
        - evaluatedAt
    status:
      exactBodies:
        - {operation: status}
        - {operation: status, requestId: uuid}
      httpStatus: 200
      data: accountDeletionRequest or null
    request:
      exactBody:
        operation: request
        subscriptionAcknowledged: boolean
      requiredHeaders: [Idempotency-Key, X-KinFlow-Recent-Auth]
      httpStatus: 202
      recentAuth:
        method: oauth
        maximumAgeSeconds: 600
        sameAuthenticatedUserRequired: true
        proofForwardedToDatabase: false
      data: accountDeletionRequest
    cancel:
      exactBody:
        operation: cancel
        requestId: uuid
        expectedVersion: positive integer
      requiredHeaders: [Idempotency-Key]
      httpStatus: 200
      data: accountDeletionRequest
  requestProjection:
    exactKeys:
      - id
      - type
      - status
      - requestedAt
      - scheduledFor
      - processingStartedAt
      - completedAt
      - failedAt
      - cancelledAt
      - failureCode
      - activeSubscriptionAtRequest
      - subscriptionAcknowledged
      - cancellable
      - version
    type: deleteAccount
  successEnvelope:
    exactKeys: [data, meta]
    metaExactKeys: [requestId, contractVersion]
  errorEnvelope:
    exactKeys: [error]
    errorExactKeys: [code, messageKey, retryable, requestId]
  exactShapeRule: unknown request, response, or RPC fields fail closed
  forbiddenResponseData:
    - auth user identifier
    - household or member identifier
    - provider or billing customer identifier
    - transaction or receipt identifier
    - endpoint token, fingerprint, ciphertext, or revocation proof
    - email, display name, avatar, or family content
databaseCommands:
  executeAuthority: service_role only through Edge and worker
  clientTableMutation: none
  userSerialization: transaction advisory lock by auth user and operation
  requestIdempotency:
    keyLength: {minimum: 16, maximum: 200}
    storedMaterial: operation plus SHA-256 request hash
    replayRule: same key and same request returns prior result
    collisionRule: same key with another operation or payload is rejected
  lastOwnerRule:
    preflight: count active owner memberships across non-deleted households
    request: reject when count is greater than zero
    processing: recheck immediately before tombstone
  subscriptionRule:
    detection: active customer or active household billing assignment owned by the user
    automaticStoreCancellation: false
    acknowledgementRequiredWhenActive: true
    billingAssignmentDeleted: false
worker:
  function: account-deletion-worker
  method: POST
  requestBody: empty
  authentication: dedicated constant-time Bearer secret
  maximumClaimBatch: 10
  claimConcurrency: FOR UPDATE SKIP LOCKED
  leaseSeconds: 120
  leaseRangeSeconds: {minimum: 30, maximum: 300}
  maximumAttempts: 5
  retryBackoffSeconds: exponential from 60 capped at 3600
  expiredLeaseRecovery: retry when attempts remain; otherwise dead-letter
  order:
    - recover expired leases
    - claim due requests
    - recheck lease, request state, and last-owner invariant
    - tombstone personal database state transactionally
    - call Supabase Auth Admin soft-delete
    - complete request or schedule retry/dead-letter
  authDelete:
    endpoint: DELETE /auth/v1/admin/users/{userId}?should_soft_delete=true
    status404: idempotent success
    retryableStatuses: [408, 425, 429, 5xx]
    otherNonSuccess: terminal AUTH_DELETE_REJECTED
  response:
    aggregateOnly: true
    exactCounters:
      - recoveredRetryScheduled
      - recoveredDeadLetter
      - claimed
      - succeeded
      - retryScheduled
      - deadLetter
dataPolicy:
  tombstonedOrDeleted:
    profile: display name, avatar, locale, timezone, deleted timestamp
    memberships: display name, avatar, removed timestamp, identity-deleted timestamp
    notificationEndpoints: encrypted token material, fingerprint, proof hash, permission, revocation reason
    notificationInbox: delete personal rows
    notificationPreferences: delete personal rows
    activeHouseholdSelection: delete personal row
    activeInvitesCreatedByUser: revoke
    localState: secure auth, Google identity, RevenueCat identity, pending invites, endpoint binding, encrypted read cache
  preserved:
    - household rows
    - chore and calendar shared history
    - other members and their identity
    - billing assignments and entitlement/audit history
    - privacy request, job, command, and immutable lifecycle/runtime audit
  authorizationAfterTombstone:
    profileReadWrite: denied
    membershipAccess: denied
    billingOwnerAccess: denied
    activeMembershipCreation: denied for a tombstoned profile
    oldJwtRule: fail closed even before token expiry
audit:
  lifecycleTransitions: [requested, cancelled, claimed, tombstoned, retry_scheduled, completed, failed]
  immutable: true
  safeMetadataMaximumBytes: 1024
  allowedMetadata:
    - aggregate affected membership count
    - aggregate erased endpoint count
    - aggregate revoked invite count
    - attempt count
    - allowlisted reason code
    - cancellation window and active-subscription booleans
  forbiddenMetadata:
    - email, display name, avatar, or family content
    - raw bearer, recent-auth proof, idempotency key, or provider token
    - provider customer, transaction, or receipt reference
client:
  layers: provider-independent domain/repository/controller with Supabase adapter only in infrastructure
  parser: exact response shape, UTC timestamps, status shape, and version invariants
  retry: reuse command ID only for the same unfinished request or cancel fingerprint
  ownerResolution: route to household member management and keep deletion blocked
  activeSubscriptionUx: explain Store subscription is not automatically cancelled and require checkbox acknowledgement
  acceptanceHandoff: schedule logout outside the controller emission stack and purge all composed auth participants
  localization: EN, KO, and EN-XA only through ARB-generated resources
  accessibility: semantic live status and compact 200-percent pseudo-locale layout test
stableErrors:
  AUTH_REQUIRED: {httpStatus: 401, retryable: false}
  IDEMPOTENCY_KEY_REQUIRED: {httpStatus: 400, retryable: false}
  IDEMPOTENCY_KEY_REUSED: {httpStatus: 409, retryable: false}
  NOT_FOUND: {httpStatus: 404, retryable: false}
  OWNER_TRANSFER_REQUIRED: {httpStatus: 409, retryable: false}
  PERMISSION_DENIED: {httpStatus: 403, retryable: false}
  PRIVACY_REQUEST_ALREADY_PENDING: {httpStatus: 409, retryable: false}
  RECENT_AUTH_REQUIRED: {httpStatus: 403, retryable: false}
  REQUEST_NOT_CANCELLABLE: {httpStatus: 409, retryable: false}
  REQUESTS_PAUSED: {httpStatus: 503, retryable: true}
  SUBSCRIPTION_ACKNOWLEDGEMENT_REQUIRED: {httpStatus: 409, retryable: false}
  TEMPORARILY_UNAVAILABLE: {httpStatus: 503, retryable: true}
  VALIDATION_FAILED: {httpStatus: 400, retryable: false}
  VERSION_CONFLICT: {httpStatus: 409, retryable: false}
rollback:
  pauseNewRequests: service-only runtime flag
  pauseProcessing: disable worker scheduler or rotate worker secret
  preserveQueuedLegalRequestsAndAudit: true
  migration: forward-only
  identityRestoreAfterTombstoneOrAuthSoftDelete: prohibited
  clientAndEdgeRemoval: independently reversible before hosted rollout
```
