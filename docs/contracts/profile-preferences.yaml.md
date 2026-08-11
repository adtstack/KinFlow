# 원본 파일 문서화: `contracts/profile-preferences.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/profile-preferences.yaml`
- 원본 형식: `yaml`
- 범위: WP07-06A adult profile, locale, personal timezone, household default timezone
- 후속 선택 UX 계약: `docs/contracts/timezone-catalog.yaml.md` (WP07-06B)
- 후속 지역 표시 계약: `docs/contracts/timezone-date-time-preview.yaml.md` (WP07-06D)

```yaml
version: "2026-08-08-wp07-06a"
requirements: [FR-SET-001, FR-SET-002, FR-HH-002]
decisions: [D-013]
scope:
  actor: authenticated adult self
  managedChild: forbidden
  uploadedAvatar: deferred
profile:
  displayName:
    normalization: trim
    minimumCharacters: 1
    maximumCharacters: 80
    controlCharacters: forbidden
  avatar:
    nullable: true
    allowedPresetKeys: ["preset:sun", "preset:heart", "preset:leaf", "preset:star"]
  locale:
    allowed: [en, ko]
    application: immediately after authoritative load or successful save
  timezone:
    format: valid PostgreSQL IANA timezone
    role: personal default and recipient preference seed
householdTimezone:
  authority: active Owner or Admin, server derived
  format: valid PostgreSQL IANA timezone
  impact:
    changes:
      - household-local Today date boundary
      - default timezone for newly created items
      - notification preferences that still inherit the household default
    doesNotChange:
      - existing chore series stored timezone
      - existing calendar series stored timezone
      - materialized occurrence canonical instants
  confirmationRequiredWhenChanged: true
read:
  rpc: get_profile_preferences
  authentication: required
  projection:
    - profileId
    - displayName
    - avatarKey
    - locale
    - profileTimezone
    - profileVersion
    - householdId
    - householdName
    - householdTimezone
    - householdVersion
    - householdRole
    - canManageHouseholdTimezone
update:
  rpc: update_profile_preferences
  authentication: required
  profileExpectedVersion: required
  householdExpectedVersion: required only when household timezone changes
  transaction:
    - validate caller and inputs
    - lock and version-check self profile
    - resolve and lock active membership and household
    - authorize optional household timezone mutation
    - update profile
    - synchronize active membership display name and avatar
    - update optional household timezone
    - append private timezone audit only when changed
    - return authoritative projection
  noOp: does not increment profile or household version
  failureAtomicity: no partial profile, membership, household, or audit mutation
errors:
  KFS01: unauthenticated
  KFS02: invalid input
  KFS03: profile or active household unavailable
  KFS04: household timezone forbidden
  KFS05: profile version conflict
  KFS06: household version conflict
client:
  payloadValidation: exact record then mapper then domain
  doubleSubmit: forbidden
  conflictRecovery: preserve error and offer authoritative reload
  authLifecycle:
    signedInActiveHousehold: load and apply locale
    signedOut: clear profile state and restore system locale
  localization: [EN, KO, EN-XA]
rollback:
  clientRouteCanBeRemoved: true
  rpcExecuteCanBeRevoked: true
  migration: forward-only
deferred:
  - uploaded avatar media lifecycle
  - real-account cross-device validation
  - hosted timezone-catalog validation
  - Android process-restart and device accessibility validation
```
