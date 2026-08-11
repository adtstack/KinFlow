# 원본 파일 문서화: `contracts/household-departure-handoff.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/household-departure-handoff.yaml`
- 원본 형식: `yaml`
- 범위: WP02-09 non-Owner household departure, authoritative fallback, and local household-bound state isolation

```yaml
version: "2026-08-09-wp02-09"
requirements: [D-017, D-048, D-049, FR-HH-007, NFR-SEC-01, NFR-PRIV-01, NFR-REL-01]
scope:
  accountType: authenticated active adult
  supportedActorRoles: [admin, member]
  ownerDeparture: forbidden until the existing atomic owner-transfer command succeeds
  managedChild: forbidden by D-013
authority:
  identity: verified bearer session and server-derived authenticated user
  membership: current non-removed household_members row
  mutation: existing manage-household-members leaveHousehold operation and public.leave_household service-only RPC
  fallback: existing leave response generated in the same database transaction
serverResult:
  exactKeys: [householdId, memberId, version, removedAt, activeHouseholdId, activeMemberId]
  departedMembership: tombstoned with next member version
  activeInvitesCreatedByActor: revoked in the same transaction
  fallbackPair:
    present: both activeHouseholdId and activeMemberId are valid UUIDs
    absent: both fields are null
    partial: invalid payload
  replay: same idempotency key and input returns the original fallback pair
clientMapping:
  dto: strict exact-key parsing remains mandatory
  domainSuccess: HouseholdLeaveCompleted with zero-or-one ActiveHousehold fallback
  partialOrMalformedFallback: fail closed as invalid payload
  genericCommandSuccessForLeave: invalid internal contract state
localTransition:
  serverFirst: true
  secondHouseholdRefresh: forbidden for the success handoff
  participants:
    - bounded encrypted read cache
    - submitted guided-setup resume state
    - pending invite continuation state
  fallbackPresent:
    - purge every household-bound participant in order
    - write the authoritative fallback active-household snapshot
    - emit authenticated active-household auth state
  fallbackAbsent:
    - purge every household-bound participant in order
    - clear the active-household snapshot
    - emit authenticated no-household auth state
  failure:
    - emit localPurgeFailed auth lock
    - expose neither the departed roster nor fallback household content
    - require safe recovery before protected content
  preservedAccountState:
    - auth credential
    - notification installation identity
    - RevenueCat authenticated user identity
ui:
  entry: existing family members screen
  confirmation: destructive confirmation required
  owner: explanatory transfer-first state and no leave action
  success: route to home and let the auth route guard choose Today or onboarding
  pending: retain no actionable duplicate leave control
  localFailure: content-free transition failure surface until auth lock redirects
security:
  rawError: forbidden
  staleFormerRosterAfterServerSuccess: forbidden
  clientChosenFallback: forbidden
  householdContentInLogs: forbidden
rollback:
  client: restore refresh-based handoff only if persistent household caches are also disabled
  server: no schema or RPC rollback is required for this client-only contract consumption
deferred:
  - hosted Google account with two memberships and real leave fallback
  - simultaneous leave and active-household switch on two devices
  - Android encrypted-storage process-death and forensic validation
```
