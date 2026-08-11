# 원본 파일 문서화: `contracts/notification-endpoint.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/notification-endpoint.yaml`
- 원본 형식: `yaml`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.
- 범위 주의: WP05-03의 설치·계정 binding과 해지 계약이다. WP05-04에서 Android FCM token source, permission, provider send/receipt hash, 앱 lifecycle/tap을 로컬 자동화로 연결했다. 실제 Firebase project·실기기 전달은 마지막 Gate이며 iOS/APNs는 별도 ADR 전까지 제외한다.

```yaml
version: "2026-08-08-wp05-03"
channel: native_push
platforms: [ios, android]
installation:
  id: secure random UUIDv4
  lifetime: app installation
  accountScoped: false
  environmentScoped: true
  secureNamespaces:
    android: kinflow_notification_<environment>_v1
    iosKeychainAccount: kinflow_notification_<environment>_v1
binding:
  key: [authUserId, installationId, channel]
  recipientKey: [householdId, memberId, authUserId]
  optimisticVersion: true
  activeTokenUniqueBy: [channel, tokenFingerprint]
  permissionStateForActiveBinding: granted
  revocationReasons:
    - client_revoked
    - token_reassigned
    - provider_unregistered
    - provider_invalid_argument
    - membership_removed
    - permission_revoked
    - rollback_disabled
tokenProtection:
  rawTokenBoundary: notification-endpoint Edge memory only
  cipher: AES-256-GCM
  nonceBytes: 12
  aad: kinflow:notification-token:v<keyVersion>
  fingerprint: SHA-256 standard base64
  databaseFields: [tokenCiphertext, tokenFingerprint, tokenKeyVersion]
  clientReadable: false
  directServiceRoleReadable: false
revocationProof:
  clientSecretBytes: 32
  clientEncoding: unpadded base64url
  databaseValue: SHA-256 standard base64 decoded to 32 bytes
  worksAfterSignOut: true
  endpointExistenceDisclosure: false
registration:
  function: notification-endpoint
  method: POST
  gatewayJwtVerification: false
  inFunctionAuthentication: GoTrue /auth/v1/user
  queryParameters: forbidden
  contentType: application/json
  maximumBodyBytes: 16384
  idempotencyHeader: idempotency-key UUID
  exactRequiredBodyKeys:
    - householdId
    - installationId
    - platform
    - token
    - revocationSecret
    - permissionState
    - timezone
    - appVersion
    - runtimeVersion
    - expectedVersion
  optionalBodyKeys: [locale]
  permissionState: granted
  databaseRpc: upsert_notification_endpoint
  response:
    metadataOnly: true
    exactDataKeys:
      - endpointId
      - householdId
      - memberId
      - installationId
      - channel
      - platform
      - permissionState
      - locale
      - timezone
      - appVersion
      - runtimeVersion
      - lastRegistrationId
      - lastSeenAt
      - revokedAt
      - revocationReason
      - version
revocation:
  function: notification-endpoint
  method: DELETE
  liveJwtRequired: false
  queryParameters: forbidden
  exactBodyKeys:
    - installationId
    - channel
    - registrationId
    - revocationSecret
  databaseRpc: revoke_notification_endpoint_by_secret
  response: {revoked: true}
status:
  databaseRpc: get_notification_endpoint_status
  authentication: auth.uid
  directTableRead: forbidden
  response: zero or one metadata-only row
providerInvalidation:
  databaseRpc: invalidate_notification_endpoint
  authorization: service role only
  matchRequired: [endpointId, currentTokenFingerprint]
  staleFingerprintEffect: none
audit:
  table: app_private.notification_endpoint_events
  immutable: true
  transitions: [registered, refreshed, rotated, revoked]
  fields: [endpointId, transition, reasonCode, endpointVersion, occurredAt]
  forbiddenFields:
    - authUserId
    - householdId
    - memberId
    - token
    - tokenCiphertext
    - tokenFingerprint
    - revocationSecretHash
    - displayName
    - email
    - payload
    - rawError
flutterLifecycle:
  pendingWrittenBeforeNetwork: true
  pendingContainsRawToken: false
  responseLossRecovery:
    statusMatch: status.lastRegistrationId equals pending.registrationId
    exactReplayWithCurrentToken: true
    sameTokenEffect: promote without version or audit advance
    changedTokenEffect: rotate registration and proof once
  conflictRetryLimit: 1
  logoutOrder:
    - attempt proof revoke for active and uncertain pending registrations
    - clear account-bound active and pending proof
    - preserve installation UUID
  remoteRevokeFailure: preserve proof and fail local purge closed
errorCodes:
  AUTH_REQUIRED: {httpStatus: 401, retryable: false}
  VALIDATION_FAILED: {httpStatus: 400, retryable: false}
  IDEMPOTENCY_KEY_REQUIRED: {httpStatus: 400, retryable: false}
  PERMISSION_DENIED: {httpStatus: 403, retryable: false}
  NOT_FOUND_OR_FORBIDDEN: {httpStatus: 404, retryable: false}
  IDEMPOTENCY_KEY_REUSED: {httpStatus: 409, retryable: false}
  VERSION_CONFLICT: {httpStatus: 409, retryable: false}
  TEMPORARILY_UNAVAILABLE: {httpStatus: 503, retryable: true}
rules:
  - Registration MUST bind the GoTrue-verified user to an active member of the requested household in the database.
  - A registration UUID replay with identical fingerprint, metadata, key version, and secret hash MUST return the original response without advancing version or audit.
  - Reusing a registration UUID with different material MUST fail with IDEMPOTENCY_KEY_REUSED.
  - Registering one active token fingerprint for another account MUST revoke the previous binding before activating the new owner.
  - A member removal MUST revoke that member's active household endpoint in the same database transaction.
  - A late provider failure for an old fingerprint MUST NOT revoke a rotated token.
  - Response-loss recovery MUST exact-replay the current callback token before promotion so a concurrent provider token rotation is not dropped.
  - Raw token, ciphertext, fingerprint, proof, service role, and encryption key MUST NOT enter Flutter logs, client responses, lifecycle audit, or public configuration.
  - Actual provider acquisition and delivery MUST remain behind replaceable token-source/provider adapters and fail closed when Android Firebase public options are absent.
```
