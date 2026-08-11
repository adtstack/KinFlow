# 원본 파일 문서화: `contracts/timezone-catalog.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/timezone-catalog.yaml`
- 원본 형식: `yaml`
- 범위: WP07-06B bundled IANA timezone search and selection

```yaml
version: "2026-08-09-wp07-06b"
requirements: [FR-SET-002, FR-HH-002]
decisions: [D-013]
source:
  kind: bundled IANA timezone database
  package: timezone
  packageVersion: 0.11.1
  databaseVersion: 2025c
  networkRequired: false
  accountDataRequired: false
catalog:
  initialization: once per app process
  refreshOffsetAt: each catalog load
  identifiers:
    include:
      - UTC
      - bundled names containing a slash
    excludePrefixes: ["posix/", "right/"]
    uniqueness: exact identifier
    ordering: ASCII identifier ascending after search rank
  displayMetadata:
    - identifier
    - currentUtcOffsetMinutes
    - currentDaylightSavingFlag
  metadataAuthority: display-only snapshot at catalog load
  persistenceAuthority: exact identifier only
search:
  execution: in-memory
  maximumQueryCharacters: 80
  normalization:
    - trim
    - lowercase
    - treat slash and underscore as spaces
    - collapse whitespace
  matching: every query token must occur in the normalized identifier
  ranking:
    - exact normalized identifier
    - final city segment prefix
    - full normalized identifier prefix
    - remaining token matches
  maximumVisibleResults: 100
  emptyQuery:
    - pin selected identifier when present in catalog
    - pin UTC
    - append identifier-ascending entries up to the visible limit
selection:
  personalTimezone: authenticated adult may select
  householdTimezone: active Owner or Admin may select
  memberHouseholdTimezone: read-only
  authoritativeCurrentValue:
    alwaysVisible: true
    retainedWhenMissingFromBundle: true
  mutation: no persistence until the existing profile save action
  householdImpactConfirmation: preserve existing confirmation when changed
saveBoundary:
  clientCatalogIsNotAuthorization: true
  serverRevalidation: app_private.is_valid_iana_timezone
  rpc: update_profile_preferences
  optimisticVersions: unchanged
failure:
  catalogLoad:
    preserveExistingSelection: true
    allowRetry: true
    allowFreeTextFallback: false
  invalidBundledEntry: omit entry and continue
privacy:
  collectedData: none
  telemetry: none
  remoteRequest: none
accessibility:
  localization: [EN, KO, EN-XA]
  minimumTargetDp: 48
  searchFieldLabelled: true
  selectedStateExposed: true
  keyboardSearchSupported: true
  textScale: 200%
rollback:
  pickerCanRevertToReadOnlyField: true
  profileSaveContractUnchanged: true
deferred:
  - hosted PostgreSQL catalog parity validation
  - real-account and cross-device save validation
  - physical keyboard and screen-reader validation
  - physical-device DST and travel validation
```
