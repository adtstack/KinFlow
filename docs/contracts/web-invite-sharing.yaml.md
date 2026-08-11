# 원본 파일 문서화: `contracts/web-invite-sharing.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/web-invite-sharing.yaml`
- 원본 형식: `yaml`
- 범위: WP10-01A Web Companion privacy-safe adult invite sharing

```yaml
version: "2026-08-10-wp10-01a"
requirements: [FR-HH-003, FR-HH-004, NFR-PRIV-01, NFR-WEB-001]
capabilities: [CAP-016]
decisions: [D-002, D-006, D-015, D-017, D-047, D-070]
tests: [T-LINK-03]
platform:
  target: Web Companion
  api: navigator.share
  implementation: dart:js_interop
  newRuntimeDependency: false
activation:
  trigger: explicit user action only
  supportDetection: navigator has own or inherited share property
  preShareAsyncBoundary: none
payload:
  fields: [title, url]
  title:
    source: localized application copy
    trimmedEmpty: rejected
    maximumCodeUnits: 120
  url:
    source: validated HouseholdInviteLink
    scheme: https
    path: /invite/{rawToken}
    query: forbidden
    fragment: forbidden
    userInfo: forbidden
    explicitPort: forbidden
  forbiddenFields: [text, files, recipient, email, subject, provider metadata]
resultSemantics:
  resolved: share-sheet handoff only; delivery and acceptance are not claimed
  unsupported: unavailable
  rejectedOrProviderFailure: failed without browser exception detail
  cancellation: failed without browser exception detail
fallback:
  mechanism: existing write-only clipboard
  trigger: separate explicit user action only
  automaticCopyAfterShareFailure: forbidden
  readExistingClipboard: forbidden
  retryable: true
privacy:
  rawInviteCredentialPersistence: forbidden
  logOrAnalyticsEmission: forbidden
  browserExceptionExposure: forbidden
  applicationStorageChange: none
  databaseOrApiChange: none
testing:
  browserClientInjectable: true
  assertions:
    - only the validated URL and localized title reach the client
    - unsupported clients are not invoked
    - invalid title is rejected before browser invocation
    - browser rejection maps to a credential-free stable result
    - Web composition selects the JS interop adapter
    - production Web compilation succeeds
deferred:
  - hosted Permissions-Policy web-share verification
  - actual Chrome Edge Firefox and Safari support and cancellation behavior
  - real-account recipient delivery revocation acceptance and App Link opening
  - browser clipboard and history forensic inspection
  - iOS native share implementation
rollback:
  selectUnavailableWebShareGateway: true
  preserveAndroidMethodChannel: true
  preserveExplicitClipboardFallback: true
  dataRollbackRequired: false
```
