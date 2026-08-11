# 원본 파일 문서화: `contracts/web-keyboard-focus.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/web-keyboard-focus.yaml`
- 원본 형식: `yaml`
- 범위: WP10-03A Web 핵심 키보드 탐색, visible focus, app-owned modal focus containment and return

```yaml
version: "2026-08-10-wp10-03a"
requirements:
  - FR-PLAT-010
  - NFR-A11Y-01
  - NFR-WEB-002
decisions: [D-028, D-036, D-070]
scope:
  platform: Flutter Web Companion
  implementationReadiness: local
  productionReadiness: partial
  realAccountValidation: deferred
keyboard:
  requiredInputs: [Tab, Shift+Tab, Enter, Escape]
  customShortcutRequired: false
  primaryNavigation:
    exactOrder: [today, calendar, family, settings]
    activation: Enter
    routeAuthority: app router
  choresSecondaryFlow:
    owner: today
    route: /chores
    activation: Enter
    return: Back or selected Today reactivation
  topLevelTraversal:
    edgeBehavior: parentScope
    rationale: browser chrome and embedding context remain reachable
focusAppearance:
  webHighlightStrategy: alwaysTraditional
  nativeHighlightStrategy: automatic
  materialThemeFocusColor:
    source: colorScheme.primary
    alpha: 0.24
  hiddenKeyboardOnlyState: forbidden
modalRoutes:
  ownership: application-owned dialogs and modal bottom sheets
  requestFocusOnOpen: true
  traversalEdgeBehavior: closedLoop
  closeInputs:
    Escape: allowed when the route is dismissible
    actionButton: always allowed
  focusReturn:
    target: opening control
    timing: first frame after route completion
    eligibility: target remains attached and can request focus
    disposedOrDisabledTarget: no-op
  rawFlutterCallsOutsideSharedWrapper: forbidden
adoption:
  sharedWrapper: lib/app/presentation/widgets/app_modal_route.dart
  dialogCallsites: 26
  modalBottomSheetCallsites: 4
  featureFamilies:
    - billing
    - calendar
    - chores
    - household
    - notifications
    - settings
  sharedTimezonePicker: included
testing:
  authentication: synthetic authenticated session
  network: not required
  database: not required
  assertions:
    - exact-four expanded navigation is reachable and activatable by keyboard
    - the Today-owned Chores secondary flow is reachable and returns predictably
    - dialog Tab and Shift+Tab remain in a closed loop
    - modal sheet Tab and Shift+Tab remain in a closed loop
    - Enter activates the focused action
    - Escape closes a dismissible modal
    - closing a modal returns focus to its opening control
    - Web highlight policy resolves to traditional mode
    - application source contains no raw modal route calls outside the wrapper
securityAndPrivacy:
  persistedFocusState: false
  analyticsEvent: false
  identityOrHouseholdData: false
  newPermissionOrSecret: false
  databaseOrApiChange: false
deferred:
  - real Chrome Edge Firefox and Safari keyboard journeys
  - browser-native 200 percent zoom and reflow
  - screen reader combinations and spoken order
  - manual focus appearance and contrast review in light and dark themes
  - hosted authenticated and real-account journeys
  - physical keyboard and assistive-technology device checks
rollback:
  removeWebFocusHighlightBootstrap: true
  restoreDirectFlutterModalCalls: true
  removeSharedWrapperAndArchitectureGuard: true
  databaseRollbackRequired: false
```
