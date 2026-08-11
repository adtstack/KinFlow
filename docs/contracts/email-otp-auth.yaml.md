# 원본 파일 문서화: `contracts/email-otp-auth.yaml`

> 이 파일은 Android Store MVP의 이메일 OTP 가입·로그인 WP02-12 normative 계약을 Markdown 코드 블록으로 보존합니다.

- 구현 시 생성할 원본 경로: `contracts/email-otp-auth.yaml`
- 원본 형식: `yaml`
- 적용 SDK: pinned `supabase_flutter 2.16.0` / `gotrue 2.26.0`
- 범위: provider-neutral Flutter flow와 local Supabase Auth 설정·자동 검증. hosted SMTP/dashboard, 실제 메일 계정·다중기기·실기기는 마지막 Gate다.

```yaml
contract: email-otp-auth
version: 1
workPackage: WP02-12
requirements:
  - FR-AUTH-001
  - FR-AUTH-004
testIds:
  - T-AUTH-04
  - T-PRIV-03
  - T-A11Y-03
  - T-I18N-01
platform:
  storeMvp: Android
  iosAndWeb: deferredByDecision
challenge:
  email:
    normalization: trimThenLowercase
    maximumLength: 254
    validation: exactlyOneAtNoWhitespaceNonemptyLocalAndDomain
  code:
    alphabet: ASCII_DIGITS
    length: 6
  resendCooldownSeconds: 60
  expirySeconds: 600
  persistence: processMemoryOnly
  secretHandling:
    appEchoOutsideExplicitInput: never
    emailTemplateTokenRendering: required
request:
  sdkOperation: signInWithOtp
  shouldCreateUser: true
  duplicateTap: sameInFlightFuture
  acceptedPresentation: genericWhetherAccountExists
  exactConflictCodesTreatedAsGenericAccepted:
    - email_exists
    - identity_already_exists
    - user_already_exists
  rateLimitCodes:
    - over_email_send_rate_limit
    - over_request_rate_limit
  unavailableCodes:
    - email_provider_disabled
    - otp_disabled
    - signup_disabled
    - provider_disabled
resend:
  beforeCooldown: rejectLocallyWithoutProviderCall
  afterCooldown: requestNewChallengeAndReplaceLocalWindow
  duplicateTap: sameInFlightFuture
verification:
  sdkOperation: verifyOTP
  otpType: email
  duplicateTap: sameInFlightFuture
  malformedCode: rejectLocallyWithoutProviderCall
  locallyExpiredChallenge: expiredWithoutProviderCall
  locallyConsumedChallenge: alreadyUsedWithoutProviderCall
  providerOtpExpiredWithinCurrentUnconsumedWindow: invalidCode
  providerRateLimitCodes:
    - over_request_rate_limit
  successPayload:
    requireSession: true
    requireUser: true
    requireMatchingValidUuid: true
  sessionHandoff: existingSupabaseAuthStateStream
privacy:
  persistEmail: false
  persistCode: false
  persistChallenge: false
  logEmail: false
  logCode: false
  logRawProviderError: false
  analyticsPayload: none
  maskedDestinationOnlyAfterRequest: true
identitySafety:
  accountExistencePreflight: forbidden
  clientIdentityLinkOrMergeMutation: forbidden
  conflictRequestPresentation: genericAccepted
  hostedAutomaticLinkingPolicy: deferredGate
runtimeConfiguration:
  local:
    mailCatcherEnabled: true
    projectSignupEnabled: true
    emailSignupEnabled: true
    confirmationAndMagicLinkTemplatesUseTokenOnly: true
    otpLength: 6
    otpExpirySeconds: 600
    maxFrequencySeconds: 60
  hosted:
    smtpAndTemplate: manualFinalGate
    identityPolicyAudit: manualFinalGate
failurePresentation:
  stableLocalizedOnly: true
  distinguish:
    - invalidEmail
    - invalidCode
    - expired
    - alreadyUsed
    - rateLimited
    - temporarilyUnavailable
    - providerUnavailable
    - internal
accessibility:
  scrollAtCompactPseudo200Percent: true
  minimumActionTargetDp: 48
  emailAutofill: true
  oneTimeCodeAutofill: true
  liveRegionForStatusAndFailure: true
rollback:
  removeEmailOtpProviderAndPresentation: true
  restoreEmailSignupDisabledInLocalConfig: true
  removeLocalMagicLinkOtpTemplate: true
  databaseMigrationRequired: false
deferred:
  - hosted SMTP sender domain rate limits abuse controls and email template deployment
  - Supabase hosted automatic identity-linking policy and duplicate-identity recovery
  - real mailbox delivery spam and prefetch behavior
  - real account multi-device and physical Android device autofill keyboard and TalkBack
```
