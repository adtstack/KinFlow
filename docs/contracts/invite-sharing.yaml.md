# 원본 파일 문서화: `contracts/invite-sharing.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/invite-sharing.yaml`
- 원본 형식: `yaml`
- 범위: WP02-11 privacy-safe adult household invite sharing and clipboard recovery

```yaml
version: "2026-08-09-wp02-11"
requirements: [FR-HH-003, FR-HH-004]
capabilities: [CAP-002, CAP-016]
decisions: [D-002, D-006, D-015, D-017, D-047]
tests: [T-LINK-02, T-LINK-03, T-I18N-01, T-A11Y-03]
platform:
  storeMvp: Android
  shareMechanism: android.intent.action.SEND
  mimeType: text/plain
  chooserRequired: true
  newRuntimeDependency: forbidden
link:
  scheme: https
  host: exact configured AUTH_REDIRECT_HOST
  pathSegments: [invite, rawToken]
  query: forbidden
  fragment: forbidden
  userInfo: forbidden
  explicitPort: forbidden
  tokenPattern: "^[A-Za-z0-9_-]{20,512}$"
  toStringRedaction: required
  lifetime: process memory and visible creation screen only
share:
  trigger: explicit user action only
  nativeValidation:
    - exact configured Android string-resource host
    - exact HTTPS scheme
    - exact two path segments with first segment invite
    - existing token pattern
    - no query, fragment, user info, or explicit port
  resultSemantics:
    opened: native chooser was handed off successfully; delivery is not claimed
    unavailable: no native handler or platform implementation is available
    failed: provider invocation failed without exposing provider detail
  singleFlight: required
clipboardFallback:
  trigger: separate explicit user action only
  automaticCopyAfterShareFailure: forbidden
  readExistingClipboard: forbidden
  supportedValues: [validated invite link, validated formatted short code]
  singleFlight: shared with native share action
  retentionWarning: required
privacy:
  forbiddenDestinations:
    - database
    - persistent storage
    - route query
    - analytics
    - logs
    - error text
    - semantics labels beyond the already visible link or code
  rawProviderErrors: forbidden
  managedChildAccess: forbidden by existing adult invite route and authorization
localization: [EN, KO, EN-XA]
accessibility:
  resultAnnouncement: live region
  minimumActionTargetDp: 48
  compactTextScale: 200 percent scrollable
dbApiStorageImpact: none
rollback:
  removeNativeChannelAndShareAction: true
  preserveExistingInviteCreationAndRevocation: true
  preserveExplicitClipboardFallback: true
deferred:
  - physical Android share-sheet application inventory and back-resume behavior
  - real-account recipient delivery and verified App Link opening
  - Android clipboard and keyboard forensic verification
  - iOS native share implementation
```
