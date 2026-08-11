# 원본 파일 문서화: `contracts/household-privacy.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/household-privacy.yaml`
- 원본 형식: `yaml`
- 범위: WP07-02B Owner 전용 shared-household export와 background deletion

```yaml
version: "2026-08-08-wp07-02b"
requirements: [FR-AUTH-006, FR-HH-009, FR-SET-003]
decisions: [D-017, D-041, D-048, D-049]
scope:
  implemented:
    - current-Owner preflight and status
    - recent-authenticated full shared-household JSON and readable-text export
    - private hash-only one-time download, revoke, expiry, and purge
    - exact-name and impact-confirmed household deletion request
    - cancellation window, service retention hold, leased deletion, access revocation, redaction, and billing unlink
  deferred:
    - final legal retention duration, hold taxonomy, and operator policy
    - member notification and consent policy
    - public privacy request site
    - hosted Storage lifecycle, scheduler, real account, browser, Store, multi-device, and physical-device evidence
authority:
  bearerIdentity: Supabase Auth user returned by /auth/v1/user
  recentAuthentication: separately authenticated OAuth AMR proof for the same user
  ownerAuthorization: current active owner membership and households.owner_member_id rechecked in PostgreSQL
  requestState: public.privacy_requests
  artifactProjection: public.household_exports
  commandIdempotency: app_private.household_privacy_command_requests
  generationJobs: app_private.household_export_jobs
  downloadGrants: app_private.household_export_download_grants
  artifactPurgeJobs: app_private.household_export_purge_jobs
  deletionJobs: app_private.household_deletion_jobs
  retentionHolds: app_private.household_deletion_retention_holds
  lifecycleAudit: app_private.household_privacy_events
  runtimeAudit: app_private.household_privacy_runtime_events
  runtimeConfiguration: app_private.privacy_runtime_config
  objectStore: private privacy-exports bucket
requestTypes:
  export: export_household
  deletion: delete_household
  onePendingAcrossTypesPerUser: true
  onePendingAcrossTypesPerHousehold: true
  requestStatuses: [queued, verifying, processing, completed, failed, cancelled]
  cancellableStatuses: [queued, verifying]
runtime:
  defaultExportRequestsEnabled: true
  defaultDeletionRequestsEnabled: true
  defaultDownloadsEnabled: true
  defaultArtifactTtlSeconds: 86400
  artifactTtlRangeSeconds: {minimum: 3600, maximum: 604800}
  defaultDownloadGrantTtlSeconds: 300
  downloadGrantTtlRangeSeconds: {minimum: 60, maximum: 900}
  defaultDeletionCancellationWindowSeconds: 86400
  deletionCancellationRangeSeconds: {minimum: 3600, maximum: 604800}
  configurationAuthority: service_role only
  updateConcurrency: expected version plus row lock
edge:
  commandFunction: household-privacy
  method: POST
  maximumBodyBytes: 12288
  contentType: application/json
  responseCache: no-store
  contractVersion: "2026-08-08-wp07-02b"
  operations:
    preflight:
      exactBody: {operation: preflight, householdId: uuid}
    status:
      exactBody: {operation: status, requestId: uuid}
    requestExport:
      exactBody: {operation: requestExport, householdId: uuid}
      requiredHeaders: [Idempotency-Key, X-KinFlow-Recent-Auth]
      httpStatus: 202
    cancelExport:
      exactBody: {operation: cancelExport, requestId: uuid, expectedVersion: positive integer}
      requiredHeaders: [Idempotency-Key]
    downloadExport:
      exactBody: {operation: downloadExport, requestId: uuid, format: json or text}
      requiredHeaders: [X-KinFlow-Recent-Auth]
    revokeExport:
      exactBody: {operation: revokeExport, requestId: uuid, expectedArtifactVersion: positive integer}
      requiredHeaders: [Idempotency-Key, X-KinFlow-Recent-Auth]
    requestDeletion:
      exactBody:
        operation: requestDeletion
        householdId: uuid
        expectedHouseholdVersion: positive integer
        confirmationName: exact current household name
        acknowledgeMemberAccessLoss: true
        acknowledgeSharedDataRedaction: true
        acknowledgeSubscriptionNotCancelled: boolean
      requiredHeaders: [Idempotency-Key, X-KinFlow-Recent-Auth]
      httpStatus: 202
    cancelDeletion:
      exactBody: {operation: cancelDeletion, requestId: uuid, expectedVersion: positive integer}
      requiredHeaders: [Idempotency-Key]
  recentAuth:
    operations: [requestExport, downloadExport, revokeExport, requestDeletion]
    method: oauth
    maximumAgeSeconds: 600
    sameAuthenticatedUserRequired: true
    proofForwardedToDatabase: false
  forbiddenResponseData:
    - auth user identifier, email, provider identity, or personal profile
    - endpoint credential, object key, grant identifier, token hash, checksum, or worker lease
    - billing customer, transaction, receipt, product, or provider identifier
download:
  publicFunction: household-export-download
  method: GET
  exactQuery: one token parameter containing 43 base64url characters
  rawTokenBytes: 32
  storedTokenMaterial: SHA-256 hash only
  consumeRule: atomically consume once before object read
  allowedCommandDownloadUrl:
    production: HTTPS only
    localDevelopment: HTTP only for localhost or 127.0.0.1
  maximumArtifactBytes: 20971520
  responseHeaders:
    Cache-Control: private, no-store, max-age=0
    Content-Disposition: attachment
    Content-Security-Policy: default-src none plus sandbox
    Referrer-Policy: no-referrer
    X-Content-Type-Options: nosniff
generation:
  workerFunction: household-privacy-worker
  generationBatchMaximum: 2
  generationLeaseSeconds: 300
  artifactPurgeBatchMaximum: 10
  artifactPurgeLeaseSeconds: 120
  deletionBatchMaximum: 5
  deletionLeaseSeconds: 180
  claimConcurrency: FOR UPDATE SKIP LOCKED
  maximumAttempts: 5
  expiredLeaseRecovery: retry when attempts remain, otherwise dead-letter
  output:
    schemaVersion: "2026-08-08-wp07-02b"
    formats: {json: pretty UTF-8 application/json, text: deterministic readable UTF-8 text/plain}
    maximumBytesPerFile: 20971520
    privateBucket: privacy-exports
    objectKeys:
      json: household-exports/{artifactPrefix}/kinflow-household.json
      text: household-exports/{artifactPrefix}/kinflow-household.txt
householdPackage:
  exactTopLevelKeys:
    - schemaVersion
    - generatedAt
    - scope
    - household
    - members
    - choreSeries
    - choreRevisions
    - choreOccurrences
    - choreActions
    - calendarSeries
    - calendarRevisions
    - calendarOccurrences
    - calendarExceptions
    - calendarParticipation
    - notificationSummary
    - billingSummary
    - privacyRequests
  includes:
    - current household metadata and active adult member roster
    - complete shared chore and calendar definitions, materialized occurrences, and action references
    - provider-ID-free aggregate notification, billing, and privacy metadata
  excludes:
    - member email, OAuth identity, auth user ID, personal profile, and removed-member display identity
    - personal notification inbox, read state, and per-user private preference detail
    - endpoint credential or installation identity
    - billing customer, transaction, receipt, product, entitlement provider, and Store identifier
    - other household data
deletion:
  requestPreconditions:
    - current Owner pointer and active owner membership
    - optimistic household version
    - exact current household name
    - member access loss and shared data redaction acknowledgment
    - active subscription not-cancelled acknowledgment when applicable
  coolingOff:
    defaultSeconds: 86400
    cancelRequiresExpectedRequestVersion: true
  retentionHold:
    authority: service_role only
    publicProjection: blocked boolean plus review timestamp only
    reasonAndOperatorPublic: false
    claimBehavior: skip while active
  completionTransaction:
    - recheck requester remains current active Owner
    - mark household deleted and revoke every active membership and active-household selector
    - tombstone household/member display identity and chore/calendar content
    - erase and revoke household notification endpoint credential material
    - revoke invitations and deactivate notification state
    - unlink entitlement and end active billing assignment without cancelling Store subscription
    - preserve other Auth accounts, profiles, other-household memberships, immutable audit, and provider billing history
  oldJwtAuthorization: deleted household plus removed membership fails closed
audit:
  immutable: true
  safeMetadataMaximumBytes: 1024
  forbiddenMetadata:
    - bearer, recent-auth proof, idempotency key, raw download token, token hash, or endpoint material
    - household name, member display name, email, title, description, notification content, or artifact body/key
    - billing customer, transaction, receipt, product, or provider identifier
client:
  layers: provider-independent domain, repository, controller, and existing download-launch port
  tokenHandling: one-time URL is passed directly to launcher and never retained in Riverpod state or local storage
  authorizationPresentation: settings row is an Owner hint only; server preflight remains authoritative
  localization: EN, KO, and EN-XA through ARB-generated resources
  accessibility: semantic live status, explicit impact labels, and compact 200-percent pseudo-locale test
rollback:
  pauseNewExports: service-only runtime flag
  pauseNewDeletions: service-only runtime flag
  pauseDownloadGrantCreation: service-only runtime flag
  invalidateLinks: revoke artifact grants and drain purge queue
  stopProcessing: retention hold or worker scheduler/secret disable
  preserveRequestsTombstonesAndImmutableAudit: true
  completedDeletionRestoration: forbidden
  migration: forward-only
```
