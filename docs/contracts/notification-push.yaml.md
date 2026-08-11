# 원본 파일 문서화: `contracts/notification-push.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/notification-push.yaml`
- 원본 형식: `yaml`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.
- 범위 주의: WP05-04/05는 Android FCM 전송과 reliability의 로컬 자동화 vertical slice다. 실제 Firebase project/service account, hosted scheduler/alert, 실계정·실기기 foreground/background/terminated 전달과 OEM별 동작은 마지막 Gate에 남긴다. iOS/APNs는 D-021에 따라 별도 ADR 전까지 제외한다.

```yaml
version: "2026-08-09-wp05-08"
platform: android
provider: fcm_http_v1
sourceEvaluation:
  table: app_private.notification_push_evaluations
  uniqueBy: sourceEventId
  statuses: [pending, materialized, disabled, stale, no_endpoint]
  reevaluates:
    - latest occurrence and recipient state
    - current native_push preference
    - quiet hours with authoritative IANA timezone
    - active Android endpoint binding
  independentFromInAppInbox: true
  inboxItemReference: optional
delivery:
  table: app_private.notification_push_deliveries
  uniqueBy: [sourceEventId, endpointId]
  statuses: [pending, leased, retry_wait, succeeded, failed, cancelled]
  maximumAttempts: 5
  batchSize: {minimum: 1, maximum: 100}
  leaseSeconds: {minimum: 5, maximum: 300}
  concurrency: FOR UPDATE SKIP LOCKED
  usefulnessWindow:
    startsAt: materialized provider eligibility after quiet hours
    durationSeconds: 3600
    expiryResult: STALE_DELIVERY_WINDOW
  providerSubmissionBoundary:
    function: mark_notification_push_submission_started
    timing: immediately before FCM network I/O
    completionLossPolicy: terminal FCM_SUBMISSION_AMBIGUOUS
    automaticReplay: forbidden
  completionReplay:
    key: [deliveryId, completedLeaseToken, completedTokenFingerprint]
    exactOutcomeRequired: true
  receiptStorage:
    providerReceiptPlaintext: forbidden
    sha256DigestBytes: 32
  cancellationCodes:
    - NATIVE_PUSH_DISABLED
    - LATEST_STATE_SUPPRESSED
    - ENDPOINT_INACTIVE
    - STALE_DELIVERY_WINDOW
    - ROLLBACK_DISABLED
serviceRoleApis:
  claim:
    function: claim_notification_push_deliveries
    returns:
      - deliveryId
      - sourceEventId
      - optional inboxItemId
      - endpointId
      - householdId
      - category
      - subjectType
      - subjectId
      - tokenCiphertextBase64
      - tokenFingerprintBase64
      - tokenKeyVersion
      - locale
      - attempt
      - maxAttempts
      - leaseToken
      - leaseExpiresAt
      - scheduledAt
      - expiresAt
  markSubmission:
    function: mark_notification_push_submission_started
    exactLeaseAndFingerprintRequired: true
    idempotentBy: [deliveryId, leaseToken]
  complete:
    function: complete_notification_push_delivery
    outcomes: [accepted, retryable, invalid_token, permanent, ambiguous]
    tokenInvalidation:
      resultCodes: [FCM_UNREGISTERED, FCM_INVALID_ARGUMENT]
      exactCurrentFingerprintRequired: true
      staleFingerprintEffect: retry_with_endpoint_material_changed
    ambiguity:
      resultCode: FCM_SUBMISSION_AMBIGUOUS
      effect: terminal_failed_without_automatic_replay
  replay:
    function: replay_notification_push_delivery
    allowedOnlyWhen: failed_with_ATTEMPTS_EXHAUSTED_and_not_expired
    ambiguityReplay: forbidden
  health:
    function: get_notification_push_reliability_health
    aggregateOnly: true
    windowHours: 24
    submitSlo: 95_percent_within_5_minutes
    lowVolumeAbsoluteMissThreshold: 3
  resetProviderBackoff:
    function: reset_notification_push_provider_backoff
  pause:
    function: set_notification_push_worker_paused
    reasonCode: ROLLBACK_DISABLED
    pendingDeliveryEffect: cancel
authenticatedTapAuthorization:
  function: resolve_notification_push_target
  inputs: [deliveryId, householdId, subjectId]
  requires:
    - auth.uid is the exact recipient
    - active household membership
    - delivery routing fields match
    - latest source event remains eligible
    - linked inbox item remains uncancelled when present
  response:
    zeroOrOneRow: true
    exactEchoFields:
      - deliveryId
      - householdId
      - category
      - subjectType
      - subjectId
      - optional inboxItemId
    safeDestinationBySubjectType:
      chore_occurrence: chore_occurrence
      calendar_occurrence: calendar_event
edgeWorker:
  function: notification-push-worker
  method: POST
  requestBody: forbidden
  queryParameters: forbidden
  gatewayJwtVerification: false
  authorization: dedicated server-only exact Bearer secret
  response:
    aggregateOnly: true
    fields:
      - claimedCount
      - acceptedCount
      - ambiguousCount
      - retryScheduledCount
      - failedCount
      - endpointInvalidatedCount
      - submissionStartedCount
      - unrecordedCompletionCount
  tokenOpening:
    cipher: AES-256-GCM
    aad: kinflow:notification-token:v<keyVersion>
    keyringEnvironment: KINFLOW_NOTIFICATION_TOKEN_DECRYPTION_KEYS
    keyringMaximumVersions: 10
    plaintextLifetime: one delivery send in worker memory
  firebaseAuthentication:
    environment: KINFLOW_FIREBASE_SERVICE_ACCOUNT_JSON
    oauthGrant: service-account JWT bearer
    scope: https://www.googleapis.com/auth/firebase.messaging
    cachedAccessTokenSafetyWindowSeconds: 60
  fcmRequest:
    endpoint: /v1/projects/<projectId>/messages:send
    restrictedPackageEnvironment: KINFLOW_ANDROID_PACKAGE_NAME
    priority: high
    timeoutMinimumSeconds: 10
    ttlSeconds: remaining_usefulness_window_1_to_3600
    notificationTag: deliveryId
    channelId: kinflow_reminders
    titleLocalizationKey: notification_push_title
    bodyLocalizationKey: notification_push_body
payload:
  contractVersion: "2026-08-08-wp05-04"
  additiveCompatibility: WP05-08 changes only the authenticated target response destination; the existing Android envelope remains valid
  exactRequiredDataKeys:
    - contractVersion
    - deliveryId
    - sourceEventId
    - householdId
    - category
    - subjectType
    - subjectId
  optionalDataKeys: [inboxItemId]
  categorySubjectPairs:
    - [chore_due, chore_occurrence]
    - [chore_assignment, chore_occurrence]
    - [calendar_event, calendar_occurrence]
  forbiddenContent:
    - household or member display name
    - chore title or description
    - email or account identifier
    - provider credential or token material
    - raw provider response or receipt
providerResultMapping:
  accepted: [FCM_ACCEPTED]
  retryable:
    - FCM_UNAVAILABLE
    - FCM_INTERNAL
    - FCM_QUOTA_EXCEEDED
    - FCM_UNKNOWN
  retryPolicy:
    retryAfterHeader: honored
    quotaFallbackMinimumSeconds: 60
    exponentialBaseSeconds: 30
    deterministicJitterSeconds: 0_to_30
    providerWideBackoff: true
  ambiguous:
    - FCM_SUBMISSION_AMBIGUOUS
  invalidToken: [FCM_UNREGISTERED, FCM_INVALID_ARGUMENT]
  permanent:
    - FCM_REQUEST_REJECTED
    - FCM_SENDER_ID_MISMATCH
    - FCM_THIRD_PARTY_AUTH_ERROR
    - TOKEN_DECRYPTION_FAILED
flutter:
  firebaseInitialization:
    androidOnly: true
    publicOptionsAllOrNone: true
    unavailableOnMissingOrInvalidConfiguration: true
    analyticsCrashlyticsAppCheckIncluded: false
  permission:
    startupSystemPrompt: forbidden
    requestTrigger: explicit notification-center action
    deniedFallbacks: [system settings, durable inbox]
    activeEndpointRequiresAuthorized: true
    deniedEndpointEffect: proof-based purge
  tokenLifecycle:
    source: FirebaseMessaging token and onTokenRefresh
    registration: existing NotificationEndpointLifecycle
    rawTokenPersistentStorage: forbidden
  foreground:
    presenter: flutter_local_notifications
    deliveryDedupeCapacity: 64
    copy: generic localized application resources
  backgroundHandler:
    topLevelEntryPoint: true
    registeredBeforeRunApp: true
    duties: exact envelope parsing only
    authoritativeSchedulingOrStateMutation: forbidden
  tap:
    sources: [foreground_local, background_remote, terminated_remote, terminated_local]
    waitsFor: [authenticated session, active household]
    serverAuthorizationRequired: true
    authorizedDestinations:
      chore_occurrence: /chores/occurrence/:occurrenceId
      calendar_event: /calendar/event/:occurrenceId
    mismatchOrUnavailableFallback: notification_center
rules:
  - Native push evaluation MUST remain independent from durable inbox creation so in_app=false and native_push=true remains deliverable.
  - Every claim and tap authorization MUST re-evaluate latest source state, current recipient membership, and exact household routing.
  - An authorized tap MUST use only the category-matched Chore or Calendar occurrence destination; any unknown or mismatched destination MUST open the notification center.
  - Delivery completion MUST be replay-safe and MUST reject a stale lease or changed endpoint fingerprint.
  - The worker MUST durably mark the exact lease immediately before provider I/O. A timeout, malformed success, or lost completion after that boundary MUST become terminal ambiguity and MUST NOT be automatically replayed.
  - Only an explicit retryable provider response or a failure before the submission marker MAY retry. Retry-After, exponential delay, deterministic jitter, provider-wide backoff, and the one-hour usefulness window MUST all be enforced.
  - Android notification tag MUST equal deliveryId and TTL MUST be the remaining usefulness window so duplicate/out-of-order presentation is bounded even when provider transport is delayed.
  - A permanent invalid-token response MUST revoke only the endpoint whose current fingerprint exactly matches the sent token.
  - Provider receipt plaintext, raw token, ciphertext, fingerprint, credential, family content, and raw error body MUST NOT enter client state, public configuration, aggregate response, logs, or evidence.
  - Client background execution MUST NOT be the source of notification timing or correctness.
  - Missing Firebase public options or non-Android runtime MUST fail closed to the durable inbox without starting provider registration.
  - Queue/provider health MUST expose counts, timestamps, stable alert codes and the 24-hour submit SLO only; it MUST NOT return delivery, household, member, subject, token, or provider-body identifiers.
```
