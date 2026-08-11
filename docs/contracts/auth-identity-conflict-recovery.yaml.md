# 원본 파일 문서화: `contracts/auth-identity-conflict-recovery.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/auth-identity-conflict-recovery.yaml`
- 원본 형식: `yaml`
- 범위: WP02-10 Android Google 로그인 identity 충돌 분류와 안전 복구

```yaml
version: "2026-08-09-wp02-10"
requirements: [FR-AUTH-003, FR-AUTH-007, FR-SET-005, NFR-PRIV-01]
decisions: [D-002, D-014, D-033, D-047, D-054, D-055]
scope:
  platform: android
  initialProvider: google
  sessionAuthority: supabase_auth
  deferred: [email_otp, apple, identity_link_mutation, live_provider_accounts]
conflictDetection:
  source: supabase_auth_exception_code
  exactCodes:
    - email_exists
    - identity_already_exists
    - user_already_exists
  messageSubstringInference: forbidden
  statusOnlyInference: forbidden
  allOtherAuthExceptions: provider_unavailable
clientFailure:
  dataKind: identity_conflict
  domainKind: identityConflict
  stableCode: IDENTITY_CONFLICT
  retryableAutomatically: false
  rawProviderMessageExposed: false
recovery:
  automaticAccountMerge: forbidden
  automaticIdentityLink: forbidden
  supabaseSessionMutationAfterConflict: forbidden
  localActionAfterConflict:
    operation: clear_google_provider_account_selection
    bestEffort: true
    failureMustNotMaskConflict: true
  userActions:
    - explicitly_retry_google_account_selection
    - open_fixed_configured_support_resource
  retrySingleFlightOwner: existing_auth_lifecycle_controller
  supportSingleFlight: true
  supportUriSource: configured_enum_only_legal_support_launcher
privacy:
  exposedAccountExistence: current_proven_google_identity_conflict_only
  forbiddenFields:
    - email
    - provider_user_id
    - other_identity_provider
    - auth_token
    - raw_exception
    - support_uri_query_identity
  logAttributesAdded: false
screen:
  route: /sign-in
  authRequired: false
  conflictExplanation: no_automatic_merge_and_choose_another_account
  supportResult: stable_localized_live_region
accessibility:
  localized: [EN, KO, EN-XA]
  minimumActionTargetDp: 48
  compactTextScale: 200%
  scrollableParent: true
verification:
  - only the three exact provider codes map to identity conflict
  - provider messages and email-like details never influence or reach UI
  - identity conflict clears Google selection exactly once before returning
  - Google selection clear failure preserves the identity conflict result
  - other provider failures do not clear Google selection
  - explicit retry remains auth-controller single-flight
  - support launch is single-flight and exposes stable localized results only
  - OTP Apple and automatic linking controls remain absent
rollback:
  removeConflictMappingAndRecoveryPresentation: true
  restoreGenericProviderUnavailableBehavior: true
  databaseOrStoredDataMigrationRequired: false
deferred:
  - hosted Supabase identity policy and provider configuration audit
  - actual duplicate identities and account-link support procedure
  - real account multi-device and physical-device validation
  - email OTP Apple and additional providers
```
