# 원본 파일 문서화: `contracts/error-catalog.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/error-catalog.yaml`
- 원본 형식: `yaml`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.

```yaml
version: "2026-08-10-wp05-12"
envelope:
  code: stable machine code
  messageKey: client localization key
  retryable: boolean
  requestId: correlation UUID
  details: allowlisted structured data only
providerMappings:
  googleIdentitySignIn:
    email_exists: IDENTITY_CONFLICT
    identity_already_exists: IDENTITY_CONFLICT
    user_already_exists: IDENTITY_CONFLICT
  runtimePolicy:
    KFR01: CLIENT_UPDATE_REQUIRED
    KFR02: CLIENT_MUTATIONS_DISABLED
    KFR03: RUNTIME_POLICY_UNAVAILABLE
    KFR06: CLIENT_FEATURE_DISABLED
  profilePreferences:
    KFS01: AUTH_REQUIRED
    KFS02: VALIDATION_FAILED
    KFS03: NOT_FOUND_OR_FORBIDDEN
    KFS04: PERMISSION_DENIED
    KFS05: VERSION_CONFLICT
    KFS06: VERSION_CONFLICT
  choreSeriesChange:
    KFC01: AUTH_REQUIRED
    KFC02: VALIDATION_FAILED
    KFC03: NOT_FOUND_OR_FORBIDDEN
    KFC04: IDEMPOTENCY_KEY_REUSED
    KFC05: VERSION_CONFLICT
    KFC06: INVALID_STATE_TRANSITION
    KFC07: RECURRENCE_RULE_INVALID
  notificationSnooze:
    KNP01: VALIDATION_FAILED
    KNP02: AUTH_REQUIRED
    KNP03: NOT_FOUND_OR_FORBIDDEN
    KNP06: VERSION_CONFLICT
    KNS04: NOTIFICATION_SNOOZE_UNAVAILABLE
errors:
  - code: VALIDATION_FAILED
    httpStatus: 400
    retryable: false
    messageKey: errors.validationFailed
  - code: CONTRACT_MISMATCH
    httpStatus: 502
    retryable: false
    messageKey: errors.contractMismatch
  - code: AUTH_REQUIRED
    httpStatus: 401
    retryable: false
    messageKey: errors.authRequired
  - code: SESSION_EXPIRED
    httpStatus: 401
    retryable: true
    messageKey: errors.sessionExpired
  - code: RECENT_AUTH_REQUIRED
    httpStatus: 403
    retryable: false
    messageKey: errors.recentAuthRequired
  - code: IDENTITY_CONFLICT
    httpStatus: 409
    retryable: false
    messageKey: errors.identityConflict
  - code: PERMISSION_DENIED
    httpStatus: 403
    retryable: false
    messageKey: errors.permissionDenied
  - code: NOT_FOUND_OR_FORBIDDEN
    httpStatus: 404
    retryable: false
    messageKey: errors.notFound
  - code: NOT_FOUND
    httpStatus: 404
    retryable: false
    messageKey: errors.notFound
  - code: HOUSEHOLD_NOT_FOUND
    httpStatus: 404
    retryable: false
    messageKey: errors.householdNotFound
  - code: NOT_HOUSEHOLD_MEMBER
    httpStatus: 403
    retryable: false
    messageKey: errors.notHouseholdMember
  - code: ROLE_NOT_ALLOWED
    httpStatus: 403
    retryable: false
    messageKey: errors.roleNotAllowed
  - code: LAST_OWNER_REQUIRED
    httpStatus: 409
    retryable: false
    messageKey: errors.lastOwnerRequired
  - code: OWNER_TRANSFER_REQUIRED
    httpStatus: 409
    retryable: false
    messageKey: errors.ownerTransferRequired
  - code: INVITE_INVALID
    httpStatus: 404
    retryable: false
    messageKey: errors.inviteInvalid
  - code: INVITE_EXPIRED
    httpStatus: 410
    retryable: false
    messageKey: errors.inviteExpired
  - code: INVITE_REVOKED
    httpStatus: 410
    retryable: false
    messageKey: errors.inviteRevoked
  - code: INVITE_ALREADY_USED
    httpStatus: 409
    retryable: false
    messageKey: errors.inviteAlreadyUsed
  - code: INVITE_EMAIL_MISMATCH
    httpStatus: 403
    retryable: false
    messageKey: errors.inviteEmailMismatch
  - code: INVITE_LIMIT_REACHED
    httpStatus: 409
    retryable: false
    messageKey: errors.inviteLimitReached
  - code: ACTING_CONTEXT_INVALID
    httpStatus: 403
    retryable: false
    messageKey: errors.actingContextInvalid
  - code: ACTING_CONTEXT_EXPIRED
    httpStatus: 403
    retryable: false
    messageKey: errors.actingContextExpired
  - code: PARENTAL_GATE_REQUIRED
    httpStatus: 403
    retryable: false
    messageKey: errors.parentalGateRequired
  - code: VERSION_CONFLICT
    httpStatus: 409
    retryable: false
    messageKey: errors.versionConflict
  - code: IDEMPOTENCY_KEY_REQUIRED
    httpStatus: 400
    retryable: false
    messageKey: errors.idempotencyKeyRequired
  - code: IDEMPOTENCY_KEY_REUSED
    httpStatus: 409
    retryable: false
    messageKey: errors.idempotencyKeyReused
  - code: OPERATION_IN_PROGRESS
    httpStatus: 409
    retryable: true
    messageKey: errors.operationInProgress
  - code: INVALID_STATE_TRANSITION
    httpStatus: 409
    retryable: false
    messageKey: errors.invalidStateTransition
  - code: RECURRENCE_RULE_INVALID
    httpStatus: 400
    retryable: false
    messageKey: errors.recurrenceRuleInvalid
  - code: RECURRENCE_LIMIT_EXCEEDED
    httpStatus: 422
    retryable: false
    messageKey: errors.recurrenceLimitExceeded
  - code: RESOURCE_LIMIT_EXCEEDED
    httpStatus: 422
    retryable: false
    messageKey: errors.resourceLimitExceeded
  - code: FEATURE_DISABLED
    httpStatus: 403
    retryable: false
    messageKey: errors.featureDisabled
  - code: FEATURE_POLICY_UNAVAILABLE
    httpStatus: 503
    retryable: true
    messageKey: errors.featurePolicyUnavailable
  - code: CLIENT_UPDATE_REQUIRED
    httpStatus: 426
    retryable: false
    messageKey: errors.clientUpdateRequired
  - code: CLIENT_MUTATIONS_DISABLED
    httpStatus: 503
    retryable: true
    messageKey: errors.clientMutationsDisabled
  - code: CLIENT_FEATURE_DISABLED
    httpStatus: 503
    retryable: true
    messageKey: errors.clientFeatureDisabled
  - code: RUNTIME_POLICY_UNAVAILABLE
    httpStatus: 503
    retryable: true
    messageKey: errors.runtimePolicyUnavailable
  - code: FEATURE_LIMIT_REACHED
    httpStatus: 409
    retryable: false
    messageKey: errors.featureLimitReached
  - code: PLAN_LIMIT_REACHED
    httpStatus: 402
    retryable: false
    messageKey: errors.planLimitReached
  - code: ENTITLEMENT_REQUIRED
    httpStatus: 402
    retryable: false
    messageKey: errors.entitlementRequired
  - code: ENTITLEMENT_PENDING
    httpStatus: 409
    retryable: true
    messageKey: errors.entitlementPending
  - code: BILLING_ASSIGNMENT_CONFLICT
    httpStatus: 409
    retryable: false
    messageKey: errors.billingAssignmentConflict
  - code: PURCHASE_CANCELLED
    httpStatus: 409
    retryable: false
    messageKey: errors.purchaseCancelled
  - code: PROVIDER_UNAVAILABLE
    httpStatus: 503
    retryable: true
    messageKey: errors.providerUnavailable
  - code: NOTIFICATION_PERMISSION_REQUIRED
    httpStatus: 409
    retryable: false
    messageKey: errors.notificationPermissionRequired
  - code: NOTIFICATION_SNOOZE_UNAVAILABLE
    httpStatus: 409
    retryable: false
    messageKey: notifications.snoozeUnavailable
  - code: CAPABILITY_UNSUPPORTED
    httpStatus: 501
    retryable: false
    messageKey: errors.capabilityUnsupported
  - code: PRIVACY_REQUEST_ALREADY_PENDING
    httpStatus: 409
    retryable: false
    messageKey: errors.privacyRequestAlreadyPending
  - code: REQUESTS_PAUSED
    httpStatus: 503
    retryable: true
    messageKey: errors.temporarilyUnavailable
  - code: SUBSCRIPTION_ACKNOWLEDGEMENT_REQUIRED
    httpStatus: 409
    retryable: false
    messageKey: errors.subscriptionAcknowledgementRequired
  - code: REQUEST_NOT_CANCELLABLE
    httpStatus: 409
    retryable: false
    messageKey: errors.privacyRequestNotCancellable
  - code: ARTIFACT_UNAVAILABLE
    httpStatus: 410
    retryable: false
    messageKey: errors.dataExportUnavailable
  - code: DOWNLOAD_GRANT_INVALID
    httpStatus: 410
    retryable: false
    messageKey: errors.dataExportUnavailable
  - code: DOWNLOADS_PAUSED
    httpStatus: 503
    retryable: true
    messageKey: errors.temporarilyUnavailable
  - code: EXPORT_TOO_LARGE
    httpStatus: 413
    retryable: false
    messageKey: errors.dataExportTooLarge
  - code: OWNER_REQUIRED
    httpStatus: 403
    retryable: false
    messageKey: errors.householdOwnerRequired
  - code: CONFIRMATION_MISMATCH
    httpStatus: 409
    retryable: false
    messageKey: errors.householdNameConfirmationMismatch
  - code: EXPORT_REQUESTS_PAUSED
    httpStatus: 503
    retryable: true
    messageKey: errors.temporarilyUnavailable
  - code: DELETION_REQUESTS_PAUSED
    httpStatus: 503
    retryable: true
    messageKey: errors.temporarilyUnavailable
  - code: REQUEST_NOT_MUTABLE
    httpStatus: 409
    retryable: false
    messageKey: errors.householdPrivacyRequestNotMutable
  - code: SUBSCRIPTION_ACK_REQUIRED
    httpStatus: 409
    retryable: false
    messageKey: errors.subscriptionAcknowledgmentRequired
  - code: HOUSEHOLD_ALREADY_DELETED
    httpStatus: 410
    retryable: false
    messageKey: errors.householdAlreadyDeleted
  - code: RATE_LIMITED
    httpStatus: 429
    retryable: true
    messageKey: errors.rateLimited
  - code: TEMPORARILY_UNAVAILABLE
    httpStatus: 503
    retryable: true
    messageKey: errors.temporarilyUnavailable
  - code: INTERNAL_ERROR
    httpStatus: 500
    retryable: true
    messageKey: errors.internal
```
