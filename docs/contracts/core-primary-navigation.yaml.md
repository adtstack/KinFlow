# 원본 파일 문서화: `contracts/core-primary-navigation.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/core-primary-navigation.yaml`
- 원본 형식: `yaml`
- 범위: WP01-11 Android phone/tablet authenticated adult core primary navigation and Today-owned Chores hub

```yaml
version: "2026-08-09-wp05-08"
requirements: [FR-CHORE-009, FR-PLAT-009, NFR-A11Y-01, NFR-I18N-01]
decisions: [D-001, D-002, D-006, D-013, D-036, D-051]
scope:
  platform: Android Store MVP phone and tablet
  principal: authenticated adult with active household
  webAndIos: deferred to their independent platform gates
destinations:
  exactOrder: [today, calendar, family, settings]
  routes:
    today: /today
    calendar: /calendar
    family: /family
    settings: /settings
  selectedStateAuthority: current top-level route, with /chores mapped to today
  navigationOperation: go-router replacement without mutation or network I/O
responsive:
  compact:
    maximumWidthExclusive: 600
    control: bottom NavigationBar
  medium:
    minimumWidthInclusive: 600
    maximumWidthExclusive: 840
    control: non-extended NavigationRail
  expanded:
    minimumWidthInclusive: 840
    control: extended NavigationRail
  hiddenOnSubflows: true
choresHub:
  route: /chores
  owner: today
  navigationExposure: secondary Today action only
  navigationOperation: push with back return
  selectedPrimaryDestination: today
  selectedTodayReactivation: return to /today
  initialView: upcoming
  exactViews: [upcoming, overdue, completed]
  assigneeFilters: [everyone, me]
  calendarComposition: forbidden
  existingAuthority: ChoreRepository.loadChores
  existingMutationAndOfflineRules: unchanged
supplementaryRoutes:
  choreOccurrence:
    template: /chores/occurrence/:occurrenceId
    identifier: canonical occurrence UUID only
    primaryNavigationVisible: false
    authorityContract: chore-occurrence-target-recovery.yaml
    actionAuthorityContract: chore-occurrence-target-actions.yaml
familyCompatibility:
  primaryRoute: /family
  existingMembersAlias: /family/members
  sameScreenAndAuthorization: true
accessibility:
  semanticContainerLabel: localized primary navigation
  destinationLabels: localized and non-color-only
  minimumTouchTargetDp: 48
  compactTextScale: 200 percent
  keyboardFocusTraversal: navigation before content on rail layouts
localization: [EN, KO, EN-XA]
stateAndPrivacy:
  newProviderState: none
  persistedNavigationState: none
  telemetry: none
  familyContentInRoute: forbidden
  primaryRouteIdentifiers: forbidden
  supplementaryRouteIdentifiers: occurrence UUID only
dbApiImpact:
  migration: none
  RLS: none
  RPC: none
  Edge: none
  remoteDTO: none
  runtimeDependency: none
  nativePermission: none
rollback:
  removeCoreDestinationConfigurationAndAliases: true
  restoreExistingTopBarRoutes: true
  dataMigrationRequired: false
deferred:
  - indexed-stack scroll and form-draft preservation across destinations
  - Managed Child destination reduction and guardian gate
  - Web browser history, keyboard-only end-to-end and service-worker behavior
  - real-account, physical-device TalkBack and tablet validation
```
