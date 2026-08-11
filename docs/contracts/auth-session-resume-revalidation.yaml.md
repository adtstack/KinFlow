# 원본 파일 문서화: `contracts/auth-session-resume-revalidation.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/auth-session-resume-revalidation.yaml`
- 원본 형식: `yaml`
- 범위: WP02-13 앱 셸 foreground 세션 재검증과 authoritative household drift 격리

```yaml
version: "2026-08-10-wp02-13"
requirements:
  - FR-AUTH-004
  - FR-AUTH-005
  - FR-AUTH-011
  - NFR-SEC-01
  - NFR-PRIV-01
  - NFR-REL-01
decisions: [D-006, D-008, D-017, D-043, D-047, D-049, D-070]
scope:
  owner: authenticated_app_shell_root
  platforms: [android, web]
  trigger: foreground_resume
  initialMountRefresh: false
  databaseMigration: false
  apiChange: false
sessionAuthority:
  repositoryOperation: refreshSession
  clientTokenInspection: forbidden
  eligibleStates:
    - authenticated_no_household
    - authenticated_active_household
  ineligibleStates:
    - bootstrapping
    - unauthenticated
    - authenticating
    - resolving_household
    - household_resolution_failed
    - refreshing
    - locked
    - deleting
concurrency:
  rootOwnerCount: 1
  singleFlight: true
  duplicateResumeDuringFlight: coalesce_to_one_trailing_refresh
  navigationDoesNotRefresh: true
  disposedHostStartsNoNewRefresh: true
success:
  sameUser:
    action: re_resolve_active_household_authoritatively
    sameHouseholdAndCacheProvenance: preserve_household_bound_local_state_without_transient_auth_event
    changedCacheProvenance: publish_updated_protected_context
    changedHousehold: purge_then_replace_before_exposure
    noHouseholdAfterActive: purge_then_clear_before_exposure
    activeAfterNoHousehold: purge_then_replace_before_exposure
  changedUser:
    action: existing_full_sensitive_local_purge_before_resolution
failure:
  absentExpiredOrRevoked:
    action: existing_full_sensitive_local_purge_then_unauthenticated
  providerOrInternal:
    action: existing_full_sensitive_local_purge_then_locked
  householdResolutionFailure:
    action: block_protected_routes_and_retain_private_previous_context_only_for_safe_retry
  householdTransitionPurgeFailure:
    action: locked_local_purge_failed
    exposeNewHousehold: false
privacy:
  persistedDataAdded: false
  logAttributesAdded: false
  analyticsAdded: false
  forbiddenOutput:
    - access_token
    - refresh_token
    - email
    - household_name
    - member_name
    - raw_provider_error
verification:
  - mount performs restore only and does not add a redundant refresh
  - one resume refreshes an authenticated session and re-resolves household state
  - unchanged user household and cache provenance publish no transient auth state or duplicate feature reload
  - unauthenticated and locked states never invoke refresh
  - duplicate resume events during one request produce at most one trailing refresh
  - expiration or revocation purges local state before protected routes close
  - same-user household change and departure purge household-bound local state before exposure
  - failed household transition remains locked and never exposes the new context
  - a household load retry still compares against the last private resolved context
rollback:
  removeRootLifecycleHost: true
  revertPrivateHouseholdContextTracking: true
  databaseOrStoredDataMigrationRequired: false
deferred:
  - hosted Supabase refresh and token revocation propagation
  - real account multi-tab and multi-device session lifecycle
  - Android process background and termination timing
  - physical-device and browser BFCache validation
```
