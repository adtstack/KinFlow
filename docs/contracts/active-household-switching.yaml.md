# 원본 파일 문서화: `contracts/active-household-switching.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/active-household-switching.yaml`
- 원본 형식: `yaml`
- 범위: WP02-08 adult active-household listing, optimistic switching, and local household-bound state isolation

```yaml
version: "2026-08-09-wp02-08"
requirements: [D-016, D-017, D-048, D-049, FR-HH-005, NFR-SEC-01, NFR-PRIV-01, NFR-REL-01, NFR-A11Y-01, NFR-I18N-01]
scope:
  accountType: authenticated active adult only
  selectionCardinality: exactly zero or one active household per auth user
  supportedMemberships: [owner, admin, member]
  managedChild: forbidden by D-013
authority:
  identity: auth.uid from the verified Supabase session
  membership: current non-removed household_members row bound to auth.uid
  targetHousehold: active non-deleted households row
  mutation: public.switch_active_household security-definer RPC
  optimisticConcurrency: public.user_active_households.version
list:
  rpc: public.list_my_households
  directRosterScan: forbidden
  exactRowKeys: [householdId, memberId, householdName, memberRole, membershipVersion, isActive, selectionVersion]
  includes: every current adult membership owned by auth.uid
  excludes: [otherMemberNames, otherMemberIds, ownerId, memberCount, inviteData, billingData, profileData, deletedHouseholds, removedMemberships]
  order: active first then case-folded household name then household ID
switch:
  rpc: public.switch_active_household
  input: [targetHouseholdId, expectedSelectionVersion]
  targetMemberId: derived by server and never accepted from the client
  noSelectionExpectedVersion: 0
  existingSelectionExpectedVersion: positive current version
  sameTarget: idempotent no-op returning the current authoritative version
  differentTarget: exact version match required and version increments once
  responseExactKeys: [householdId, memberId, selectionVersion, changed]
  directTableUpdate: revoked from authenticated clients
  audit: private content-free old/new household and selection versions
errors:
  KFH01: unauthenticated
  KFH02: invalid input
  KFH06: target unavailable
  KFH07: selection version conflict
  KFR06: household mutations disabled by runtime feature policy
localTransition:
  serverFirst: true
  beforeNewHouseholdDisplay:
    - clear bounded encrypted read-cache namespace
    - clear submitted guided-setup resume state
    - clear pending invite continuation state
    - write the new active-household cache envelope
  failure: lock authenticated content with local purge failure and require recovery
  notificationEndpoint: existing push coordinator observes the new active-household state and rebinds the installation
  providerIdentity: unchanged because RevenueCat identity remains the auth user ID
client:
  entry: authenticated Settings
  screen: dedicated household switcher
  currentRow: selected and disabled
  confirmation: required before changing household
  success: replace auth active-household state then route to Today for authoritative reload
  conflict: retain list and require refresh
  localization: [EN, KO, EN-XA]
security:
  searchPath: empty
  rawError: forbidden
  crossAccountOrRemovedTarget: generic unavailable
  householdContentInLogs: forbidden
  directAuditAccess: forbidden for anon, authenticated, and service_role
rollback:
  client: hide the Settings entry and retain invite-time active-household selection
  server: revoke authenticated execute on switch_active_household while keeping list read-only
  schema: keep additive version and audit data; use a forward corrective migration
deferred:
  - hosted Supabase migration and two-account multi-device propagation
  - actual Android encrypted-storage forensic and process-death switching
  - cross-platform Web/iOS household switching
```
