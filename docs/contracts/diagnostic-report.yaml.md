# 원본 파일 문서화: `contracts/diagnostic-report.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/diagnostic-report.yaml`
- 원본 형식: `yaml`
- 범위: WP07-08 local PII-safe diagnostic report and explicit clipboard copy

```yaml
version: "2026-08-08-wp07-08"
requirements: [FR-SET-007, NFR-PRIV-01, NFR-OBS-01, NFR-SEC-02, FR-PLAT-001, FR-PLAT-002]
authority:
  installedApplicationMetadata: package_info_plus
  configuredApplicationMetadata: AppPublicConfiguration
  platformCategory: Flutter runtime target
  incidentId: cryptographically random local UUID v4
transport:
  reportBody:
    network: none
    database: none
    backgroundUpload: none
  incidentIdCorrelation:
    channel: existing PII-filtered structured observability when configured
    reportBodyAttached: false
  clipboard:
    mode: explicit write only
    readExistingContent: forbidden
    automaticSupportAttachment: forbidden
report:
  format: pretty JSON UTF-8 text
  schemaVersion: 1
  exactOrderedFields:
    - schemaVersion
    - applicationId
    - appVersion
    - buildNumber
    - environment
    - contractVersion
    - devicePlatform
    - incidentId
    - generatedAtUtc
  devicePlatformValues: [android, ios, web, macos, windows, linux, fuchsia, unknown]
  incidentId:
    format: lowercase UUID v4
    persistence: none
    lifecycle: one per generated report
  generatedAtUtc: ISO-8601 UTC
validation:
  applicationId: safe package identifier
  appVersion: safe semantic package version without build suffix
  buildNumber: positive decimal string
  configuredApplicationIdMustMatchRuntime: true
  configuredAppVersionMustEqualRuntimeVersionPlusBuild: true
  contractVersion: YYYY-MM-DD
  invalidOrMismatchedMetadata: fail closed without partial report
privacy:
  allowed:
    - application/package identifier
    - application version and build number
    - dev or prod environment
    - API contract date
    - coarse platform category
    - random incident UUID
    - UTC generation timestamp
  forbidden:
    - user, account, household, or member identifier
    - email, name, profile, or household content
    - chore, calendar, notification, or billing content
    - authentication credential, token, URL, or query
    - IP, network, locale, or timezone
    - device name, model, serial, or advertising identifier
    - signing hash, installer store, or install/update timestamp
observability:
  event: application.diagnostics.generated
  allowedAttributes: [capability, operation, result, request_id]
  reportBodyLogging: forbidden
  userNotice: random incident ID may be recorded for support correlation
  loggerFailureBlocksGeneration: false
states: [initial, loading, loadFailed, ready, refreshing, copying]
concurrency:
  generation: single flight
  clipboardWrite: single flight
  duplicateTap: ignored while busy
  refreshFailurePreservesCurrentReport: true
client:
  route: /settings/diagnostics
  localization: [EN, KO, EN-XA]
  compactTextScale: 200 percent scrollable
  minimumActionTarget: 48 dp
  statusAnnouncement: accessibility live region
rollback:
  routeCanBeRemoved: true
  unavailableRepositoryFailsClosed: true
  remoteOrPersistedDataRollback: none
deferred:
  - physical Android and iOS clipboard behavior
  - TalkBack and VoiceOver announcement
  - real installed package metadata on signed artifacts
  - remote Sentry and support incident correlation
```
