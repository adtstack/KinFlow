# 원본 파일 문서화: `contracts/data-export.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/data-export.yaml`
- 원본 형식: `yaml`
- 범위: WP07-02A 개인 데이터 export 요청·생성·JSON/TXT·일회성 다운로드·revoke·expiry purge

```yaml
version: "2026-08-08-wp07-02a"
requirements: [FR-AUTH-006, FR-SET-003]
decisions: [D-017, D-041]
scope:
  implemented:
    - authenticated personal export preflight, request, status, cancel, download, and revoke
    - recent same-user OAuth proof for request, download, and revoke
    - leased private JSON and readable-text generation
    - hash-only one-time download grants
    - artifact expiry, immediate revoke, private-object purge, retry, and immutable audit
  deferred:
    - Owner-authorized full household export
    - household deletion and public privacy request site
    - final legal retention and SLA copy
    - hosted Storage lifecycle, scheduler, real account, browser, multi-device, and physical-device evidence
authority:
  bearerIdentity: Supabase Auth user returned by /auth/v1/user
  recentAuthentication: separately authenticated OAuth AMR proof for the same user
  requestState: public.privacy_requests
  artifactProjection: public.data_exports
  commandIdempotency: app_private.data_export_command_requests
  generationJobs: app_private.data_export_jobs
  downloadGrants: app_private.data_export_download_grants
  purgeJobs: app_private.data_export_purge_jobs
  lifecycleAudit: app_private.data_export_events
  runtimeAudit: app_private.data_export_runtime_events
  runtimeConfiguration: app_private.privacy_runtime_config
  objectStore: private privacy-exports bucket
stateMachine:
  requestStatuses: [queued, verifying, processing, completed, failed, cancelled]
  pendingStatuses: [queued, verifying, processing]
  cancellableStatuses: [queued, verifying]
  terminalStatuses: [completed, failed, cancelled]
  onePendingPrivacyRequestAcrossTypesPerUser: true
  optimisticCancelAndRevokeVersionRequired: true
runtime:
  defaultRequestsEnabled: true
  defaultDownloadsEnabled: true
  defaultArtifactTtlSeconds: 86400
  artifactTtlRangeSeconds: {minimum: 3600, maximum: 604800}
  defaultDownloadGrantTtlSeconds: 300
  downloadGrantTtlRangeSeconds: {minimum: 60, maximum: 900}
  configurationAuthority: service_role only
  updateConcurrency: expected version plus row lock
  audit: immutable previous and next values with correlation ID
edge:
  commandFunction: data-export
  method: POST
  maximumBodyBytes: 8192
  contentType: application/json
  responseCache: no-store
  contractVersion: "2026-08-08-wp07-02a"
  commonHeaders:
    required: [Authorization]
    optional: [X-Request-Id]
  operations:
    preflight:
      exactBody: {operation: preflight}
      httpStatus: 200
      exactDataKeys:
        - canRequest
        - pendingRequestId
        - pendingStatus
        - pendingRequestVersion
        - conflictingRequestPending
        - requestsEnabled
        - downloadsEnabled
        - artifactTtlSeconds
        - downloadGrantTtlSeconds
        - evaluatedAt
    status:
      exactBodies:
        - {operation: status}
        - {operation: status, requestId: uuid}
      httpStatus: 200
      data: dataExportRequest or null
    request:
      exactBody: {operation: request}
      requiredHeaders: [Idempotency-Key, X-KinFlow-Recent-Auth]
      httpStatus: 202
    cancel:
      exactBody:
        operation: cancel
        requestId: uuid
        expectedVersion: positive integer
      requiredHeaders: [Idempotency-Key]
      httpStatus: 200
    download:
      exactBody:
        operation: download
        requestId: uuid
        format: json or text
      requiredHeaders: [X-KinFlow-Recent-Auth]
      httpStatus: 200
      exactDataKeys: [format, expiresAt, downloadUrl]
    revoke:
      exactBody:
        operation: revoke
        requestId: uuid
        expectedArtifactVersion: positive integer
      requiredHeaders: [Idempotency-Key, X-KinFlow-Recent-Auth]
      httpStatus: 200
  recentAuth:
    method: oauth
    maximumAgeSeconds: 600
    sameAuthenticatedUserRequired: true
    proofForwardedToDatabase: false
  requestProjection:
    exactKeys:
      - id
      - status
      - requestedAt
      - processingStartedAt
      - completedAt
      - failedAt
      - cancelledAt
      - failureCode
      - cancellable
      - version
      - artifact
    artifactExactKeys:
      - id
      - version
      - schemaVersion
      - expiresAt
      - revokedAt
      - purgedAt
      - machineSizeBytes
      - humanSizeBytes
      - available
  successEnvelope:
    exactKeys: [data, meta]
    metaExactKeys: [requestId, contractVersion]
  errorEnvelope:
    exactKeys: [error]
    errorExactKeys: [code, messageKey, retryable, requestId]
  exactShapeRule: unknown request, response, RPC, or provider fields fail closed
  forbiddenResponseData:
    - auth user identifier, email, or provider identity
    - household or member identifier outside the exported file
    - object key, grant identifier, token hash, checksum, or worker lease
    - billing customer, transaction, receipt, or entitlement provider identifier
download:
  publicFunction: data-export-download
  method: GET
  exactQuery: one token parameter containing 43 base64url characters
  rawTokenBytes: 32
  storedTokenMaterial: SHA-256 hash only
  consumeRule: atomically consume once before object read
  invalidOrExpiredStatus: 410
  allowedCommandDownloadUrl:
    production: HTTPS only
    localDevelopment: HTTP only for localhost or 127.0.0.1
  maximumArtifactBytes: 10485760
  objectValidation:
    keyPattern: exports/{artifactPrefix}/kinflow-data.json or kinflow-data.txt
    sizeMatchesDatabase: true
    sha256MatchesDatabase: true
  responseHeaders:
    Cache-Control: private, no-store, max-age=0
    Content-Disposition: attachment
    Content-Security-Policy: default-src none plus sandbox
    Referrer-Policy: no-referrer
    X-Content-Type-Options: nosniff
generation:
  workerFunction: data-export-worker
  method: POST
  requestBody: empty
  authentication: dedicated constant-time Bearer secret
  generationBatchMaximum: 3
  generationLeaseSeconds: 240
  purgeBatchMaximum: 10
  purgeLeaseSeconds: 120
  claimConcurrency: FOR UPDATE SKIP LOCKED
  maximumAttempts: 5
  retryBackoff: bounded exponential
  expiredLeaseRecovery: retry when attempts remain, otherwise dead-letter
  output:
    schemaVersion: "2026-08-08-wp07-02a"
    formats:
      json: pretty UTF-8 application/json
      text: deterministic readable UTF-8 text/plain
    maximumBytesPerFile: 10485760
    privateBucket: privacy-exports
    objectKeys:
      json: exports/{artifactPrefix}/kinflow-data.json
      text: exports/{artifactPrefix}/kinflow-data.txt
  response:
    aggregateOnly: true
    exactCounters:
      - generationRecoveredRetryScheduled
      - generationRecoveredDeadLetter
      - generationClaimed
      - generationSucceeded
      - generationRetryScheduled
      - generationDeadLetter
      - purgeRecoveredRetryScheduled
      - purgeRecoveredDeadLetter
      - purgeClaimed
      - purgeSucceeded
      - purgeRetryScheduled
      - purgeDeadLetter
personalPackage:
  exactTopLevelKeys:
    - schemaVersion
    - generatedAt
    - scope
    - profile
    - memberships
    - authoredChores
    - choreActions
    - authoredCalendarEvents
    - calendarParticipation
    - notificationPreferences
    - notificationInbox
    - billingSummary
    - privacyRequests
  includes:
    - the requesting adult profile
    - the requesting adult active membership projections
    - chores and calendar events authored by the requesting adult
    - the requesting adult completion and calendar participation records
    - the requesting adult notification preferences and inbox metadata
    - provider-ID-free aggregate billing summary
    - the requesting adult privacy request history
  excludes:
    - other member profiles, email, avatar, and identity
    - unrelated chores or events authored by another user
    - a complete shared-household archive
    - provider customer, transaction, receipt, entitlement, and device identifiers
    - endpoint token, ciphertext, fingerprint, proof, download token, hash, and object key
  scopeFlags:
    otherMemberProfilesIncluded: false
    providerIdentifiersIncluded: false
purge:
  scheduledAt: artifact expiry when generation completes
  revokeBehavior:
    invalidateOutstandingGrants: immediate
    markArtifactUnavailable: immediate
    acceleratePurge: immediate queue eligibility
  expiryBehavior:
    grantsBecomeInvalid: true
    privateObjectsRemovedByWorker: true
  terminalMetadata:
    retainRequestAndAudit: true
    clearObjectKeysAfterPurge: true
    retainChecksumsAndSizesForAudit: true
databaseCommands:
  executeAuthority: service_role only through Edge and worker
  clientTableMutation: none
  userSerialization: transaction advisory lock across privacy request types
  requestIdempotency:
    keyLength: {minimum: 16, maximum: 200}
    storedMaterial: operation plus SHA-256 request fingerprint
    replayRule: same key and same operation or payload returns prior result
    collisionRule: same key with another operation or payload is rejected
  rowLevelRead:
    table: public.data_exports
    role: authenticated
    rule: own privacy request only through security-definer identity helper
audit:
  lifecycleTransitions:
    - requested
    - cancelled
    - claimed
    - retry_scheduled
    - completed
    - failed
    - download_grant_issued
    - download_consumed
    - revoked
    - purge_claimed
    - purge_retry_scheduled
    - purged
    - purge_failed
  immutable: true
  forbiddenMetadata:
    - raw bearer, recent-auth proof, idempotency key, download token, or token hash
    - email, display name, avatar, notification content, or family content
    - object body, provider identifier, customer reference, transaction, or receipt
client:
  layers: provider-independent domain, repository, controller, and download-launch port
  parser: exact response shape, pinned schema, UTC timestamps, status shape, sizes, and URL invariants
  tokenHandling: download URL is passed directly to the launcher and is never retained in Riverpod state or local storage
  retry: reuse command ID only for the same unfinished request, cancel, or revoke fingerprint
  localization: EN, KO, and EN-XA only through ARB-generated resources
  accessibility: semantic live status and compact 200-percent pseudo-locale widget test
  runtimeDependency:
    package: url_launcher 6.3.2
    purpose: delegate the one-time HTTPS URL to the platform browser or download handler
    alternativesConsidered: embedded WebView and direct in-app byte persistence
    rationale: avoids WebView cookies and avoids persisting export bodies in app storage
    platforms: Android, iOS, and supported Flutter desktop or web implementations
    nativePermissionDelta: none
    privacyDataSentByPackage: only the already-authorized one-time URL to the selected platform handler
    license: BSD-3-Clause package in the Flutter ecosystem
    rollback: replace infrastructure launcher with fail-closed unavailable implementation and remove direct dependency
stableErrors:
  ARTIFACT_UNAVAILABLE: {httpStatus: 410, retryable: false}
  AUTH_REQUIRED: {httpStatus: 401, retryable: false}
  DOWNLOADS_PAUSED: {httpStatus: 503, retryable: true}
  DOWNLOAD_GRANT_INVALID: {httpStatus: 410, retryable: false}
  EXPORT_TOO_LARGE: {httpStatus: 413, retryable: false}
  IDEMPOTENCY_KEY_REQUIRED: {httpStatus: 400, retryable: false}
  IDEMPOTENCY_KEY_REUSED: {httpStatus: 409, retryable: false}
  NOT_FOUND: {httpStatus: 404, retryable: false}
  PERMISSION_DENIED: {httpStatus: 403, retryable: false}
  PRIVACY_REQUEST_ALREADY_PENDING: {httpStatus: 409, retryable: false}
  RECENT_AUTH_REQUIRED: {httpStatus: 403, retryable: false}
  REQUEST_NOT_CANCELLABLE: {httpStatus: 409, retryable: false}
  REQUESTS_PAUSED: {httpStatus: 503, retryable: true}
  TEMPORARILY_UNAVAILABLE: {httpStatus: 503, retryable: true}
  VALIDATION_FAILED: {httpStatus: 400, retryable: false}
  VERSION_CONFLICT: {httpStatus: 409, retryable: false}
rollback:
  pauseNewRequests: service-only requests-enabled runtime flag
  pauseDownloadGrantCreation: service-only downloads-enabled runtime flag
  invalidateExistingLinks: revoke artifact grants or consume expiry
  removePrivateObjects: retain purge worker until queue drains
  pauseProcessingAfterDrain: disable worker scheduler or rotate worker secret
  preserveRequestsAndImmutableAudit: true
  migration: forward-only
  clientAndEdgeRemoval: independently reversible before hosted rollout
```
