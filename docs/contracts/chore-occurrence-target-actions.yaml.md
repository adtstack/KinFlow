# 원본 파일 문서화: `contracts/chore-occurrence-target-actions.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/chore-occurrence-target-actions.yaml`
- 원본 형식: `yaml`
- 범위: WP05-09 Android authenticated adult Chore target complete/reopen actions

```yaml
version: "2026-08-09-wp05-09"
requirements: [FR-NOTIF-005, FR-CHORE-004, FR-TODAY-003, NFR-SEC-01, NFR-PRIV-01, NFR-REL-01, NFR-A11Y-01, NFR-I18N-01]
decisions: [D-002, D-006, D-013, D-017, D-018, D-022, D-048, D-051]
dependsOn:
  targetRead: chore-occurrence-target-recovery@2026-08-09-wp05-08
  completionMutation: public.set_chore_occurrence_completion
scope:
  platform: Android Store MVP phone and tablet
  principal: authenticated adult with an active household
  entryRoute: /chores/occurrence/:occurrenceId
  actions: [scheduled_to_completed, completed_to_scheduled]
  excludedActions: [skip, reschedule, reassign, edit_one_time, edit_series, cancel_series]
actionTargetRead:
  rpc: get_chore_occurrence_action_target
  arguments: [active household UUID, occurrence UUID]
  compatibility:
    existingRpcPreserved: get_chore_occurrence_target
    existingResponseShapePreserved: true
    reason: strict N-1 clients reject additive response keys
  projection:
    base: exact WP05-08 occurrence target fields
    additiveExactField: canSetCompletion
  canSetCompletion:
    trueWhen:
      - series is not deleted
      - caller is Owner or Admin, or caller is the current occurrence assignee
    falseWhen:
      - completed historical occurrence belongs to a deleted series
      - regular adult caller is not the current assignee
    authorityNote: presentation hint only; the mutation revalidates session, membership, role, assignee, series state, occurrence state, and expected version
mutation:
  rpc: set_chore_occurrence_completion
  request:
    - generated UUID idempotency key
    - active household UUID
    - exact occurrence UUID
    - authoritative expected occurrence version
    - requested completed boolean
  retry:
    sameFingerprintSameKey: true
    fingerprintFields: [householdId, occurrenceId, expectedVersion, completed]
    duplicateTap: coalesced while in flight
  optimisticPresentation: current detail remains visible with a disabled progress action
  success:
    - validate the exact household, occurrence, requested status, and next version result
    - apply the returned status and version locally
    - refetch the authoritative action target without cache
    - rebuild the existing activity history for the new occurrence version
  staleOrInvalidTransition:
    - refetch the authoritative action target
    - show a localized typed conflict without replaying against a new version
  responseLoss:
    - retain the same idempotency key while the same version and requested status remain visible
    - a user retry may safely recover the prior committed result
  postCommitRefreshFailure:
    - preserve the reconciled mutation result
    - show a localized refresh warning and explicit authoritative retry
client:
  scheduledActionLabel: existing choreMarkCompleteAction
  completedActionLabel: existing choreReopenAction
  mutationPolicy: chores runtime feature policy disables the action before repository I/O
  actionUnavailable: omit the action while preserving readable details and history
  actionFailure: typed localized Chore failure only; no provider text
  lifecycle:
    resume: authoritative target refetch
    activeHouseholdChange: supersede pending reads and ignore late action results
offline:
  targetCache: forbidden
  mutationOutbox: forbidden
  behavior: online-only existing completion RPC
privacy:
  newStoredData: none
  newPayloadContent: one authorization-derived boolean only
  forbidden: [title in logs, description in logs, member display name in logs, email, auth subject, raw provider error]
dbApiImpact:
  migration: additive function only
  tables: none
  indexes: none
  rls: unchanged
  oldRpc: preserved
  newRpcGrant: authenticated only
rollback:
  client: hide the target action and call the WP05-08 read RPC again
  server: revoke execute on get_chore_occurrence_action_target in a forward migration
  dataMigrationRequired: false
deferred:
  - real-account role and assignment validation
  - two-device completion and stale-version race
  - physical Android notification-to-completion journey
  - Managed Child acting-member and approval actions
```
