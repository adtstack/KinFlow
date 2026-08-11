# 원본 파일 문서화: `contracts/web-route-recovery.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/web-route-recovery.yaml`
- 원본 형식: `yaml`
- 범위: WP10-03B Web direct URL, 인증 continuation, session recovery와 safe unavailable route

```yaml
version: "2026-08-10-wp10-03b"
requirements:
  - FR-AUTH-004
  - FR-PLAT-011
  - NFR-WEB-001
  - NFR-WEB-004
decisions: [D-032, D-038, D-070]
scope:
  platform: Flutter Web Companion
  implementationReadiness: local
  productionReadiness: partial
  realAccountValidation: deferred
urlAuthority:
  strategy: path
  router: go_router
  browserHistorySuppression: false
  hostedSpaRewrite: deferred
routeIntent:
  storage: process-memory only
  maximumSerializedLocationBytes: 768
  externalSchemeOrAuthority: rejected
  fragment: discarded
  unknownPath: /route-recovery/not-found
  authenticatedDirectRoute:
    arbitraryQueryOrFragment: discarded before render
    calendarImportWithTrustedStateExtra: preserve route
  browserVisibleContinuation:
    queryKey: continue
    exactValueCount: 1
    valueType: fixed marker
    rawPathAllowed: false
    rawResourceIdentifierAllowed: false
    rawQueryOrFragmentAllowed: false
    markers:
      today: /today
      chores: /chores
      calendar: /calendar
      family: /family
      settings: /settings
      notifications: /notifications
      not-found: /route-recovery/not-found
      invite: /invite
  sameRuntimeRecovery:
    validStaticPath: exact path
    choreCreation: only canonical due YYYY-MM-DD query
    calendarOccurrence: exact validated UUID path
    choreOccurrence: exact validated UUID path
    calendarImport: /calendar
  refreshedSignInRecovery: marker destination only
authTransitions:
  sessionExpired:
    retainSameRuntimeIntent: true
  sessionRevoked:
    retainSameRuntimeIntent: true
  explicitLogout:
    retainIntent: false
    signInContinuation: absent
  providerOrPurgeFailure:
    retainIntent: false
  authenticatedUserChange:
    retainIntent: false
    safeDestination: /today
  activeHouseholdChange:
    retainIntent: false
    safeDestination: /today
  plainSignInNavigation:
    clearsStaleIntent: true
  unauthenticatedOnboardingRoute:
    destination: /sign-in
unavailableRoutes:
  unknownPath:
    screen: route.notFound
    recovery: /
  invalidCalendarOccurrenceId:
    screen: route.notFound
  invalidChoreOccurrenceId:
    screen: route.notFound
  invalidChoreDueDate:
    screen: route.notFound
  authoritativeResourceFailure:
    kinds: [not-found, forbidden]
    distinguishToClient: false
    choreState: chore.target.unavailable
    calendarState: calendar.targetUnavailable
testing:
  authentication: synthetic session events
  network: not required
  database: not required
  assertions:
    - exact resource route is restored after same-runtime expiry and re-authentication
    - sign-in URL contains only a fixed continuation marker
    - sign-in refresh reconstructs only a coarse destination
    - arbitrary query and fragment values are discarded
    - an authenticated direct URL is canonicalized before the destination renders
    - Calendar import retains trusted process-memory route state
    - duplicate or unknown continuation markers are rejected
    - explicit logout does not restore the prior resource route
    - household switch forces a safe primary destination
    - invalid dynamic parameters and unknown routes share a safe 404 surface
securityAndPrivacy:
  persistedRouteIntent: false
  analyticsEvent: false
  identityOrHouseholdDataInContinuation: false
  resourceIdentifierInContinuation: false
  notFoundVersusForbiddenDisclosure: false
  newPermissionOrSecret: false
  databaseOrApiChange: false
deferred:
  - hosted HTTPS SPA rewrite and direct non-root refresh
  - actual Chrome Edge Firefox and Safari back forward history
  - browser BFCache and stale-tab lifecycle
  - real account expiry revocation logout account switch and household switch
  - hosted forbidden and membership-removal races
rollback:
  restorePathOnlyInMemoryGuard: true
  removeFixedContinuationPolicyAndInternalNotFoundRoute: true
  databaseRollbackRequired: false
```
