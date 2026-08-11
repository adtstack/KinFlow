# Phase 03 WP03-13 One-time Chore Trash and Undo Workplan

## Status

- 상태: **LOCAL AUTOMATED COMPLETE (2026-08-09)** — WP03/G3/출시 완료는 아님
- 수직 조각: existing soft-delete receipt → immediate undo → exact trash read → versioned restore → authoritative list reconciliation
- 요구사항: `FR-CHORE-001`, `FR-CHORE-003`, `NFR-SEC-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-017`, `D-048`
- 계약: `docs/contracts/one-time-chore-trash.yaml.md`
- 완료 증거: `docs/evidence/phase-03/WP03_13_EVIDENCE.md`

## Product boundary

- 기존 WP03-09가 보존한 scheduled one-time series/revision/occurrence만 복구한다. repeating cancellation, completed item, archive, bulk와 영구 삭제는 섞지 않는다.
- 삭제 성공 뒤 post-delete dual version과 원래 표시 occurrence를 process memory receipt로 유지해 Snackbar에서 즉시 되돌릴 수 있게 한다.
- Undo 기회를 놓쳐도 `/chores/trash`에서 삭제 시각 역순으로 확인하고 개별 복구할 수 있다.
- restore는 기존 content/revision/due/assignee를 그대로 재활성화한다. 원래 assignee가 제거된 경우 자동 재할당하지 않고 stable invalid-transition으로 거부한다.
- trash는 online authoritative read다. 삭제 content를 새 local persistent cache, analytics 또는 notification payload에 복제하지 않는다.

## Server design

1. additive migration으로 existing one-time change event/command operation에 `restored`를 허용하되 immutable/content-free shape를 유지한다.
2. `get_deleted_one_time_chores`는 active exact-household member에게 exact 18-key rows와 bounded opaque cursor만 반환한다.
3. read projection은 `deleted_at is not null`, active revision `type=once`, exact occurrence `cancelled`인 row만 포함한다.
4. `restore_one_time_chore`는 active caller, original active assignee, dual expected version, deleted/cancelled/once 상태를 같은 transaction에서 검증한다.
5. restore는 series `deleted_at`을 비우고 occurrence를 scheduled로 전환하며 두 version을 각각 1 증가시키고 `restored` audit를 기록한다.
6. 기존 command table의 caller+key namespace를 공유해 update/delete/restore 교차 key 재사용을 거부하고 exact replay만 `changed=false`로 반환한다.
7. 기존 chores runtime-policy trigger, RLS, notification hook과 cache invalidation authority를 유지한다.

## Flutter design

- domain: deleted item/page/cursor와 restore draft/request/snapshot strict immutable types.
- data: exact trash row parser와 exact restore response parser; UTC, cursor, sort, scope, version과 nullable time pair를 fail closed 검증.
- repository: list/restore results를 stable `ChoreFailure`로 매핑하고 response를 request와 expected+1 dual version에 대조.
- application: trash initial/retry/refresh/load-more/restore controller와 Today process-memory deletion receipt/undo orchestration.
- presentation: Today trash route action, deletion Snackbar Undo, adaptive trash list/empty/error/pagination/restore, EN/KO/EN-XA와 200% layout.
- capability: Today undo와 trash restore notifier 모두 exact `AppRuntimeFeature.chores` guard를 provider/ID I/O 전에 적용.

## Automated evidence plan

1. migration clean apply, exact grants/private access, restored audit constraints and content-free columns
2. exact trash projection, empty metadata row, deterministic ordering/cursor, cross-household and removed-member denial
3. restore success, preserved content/revision/due/assignee, dual version increment, Today/list reappearance and trash disappearance
4. exact replay, changed/cross-operation key conflict, stale version, wrong state/type, inactive assignee and direct table denial
5. chores runtime-policy denial with trash reads preserved
6. strict Flutter domain/parser/repository invalid payload matrix
7. controller initial/refresh/pagination, single-flight restore, authoritative reconcile and failure preservation
8. deletion receipt immediate undo, dismissal persistence in trash and new-action/scope cleanup
9. route, empty/list/restore/conflict/retry, EN/KO/EN-XA, compact 320×568 200% and 48dp actions
10. focused/full DB and Flutter, analyzer, format, codegen, lint, contract/matrix, secret/workflow and whitespace gates

## Manual and deferred evidence

- real account, hosted policy/project, two-device Realtime, process restart, TalkBack/VoiceOver와 physical device는 마지막 통합 Gate로 미룬다.
- production data, Store, provider 또는 remote policy를 변경하지 않는다.

## Rollback

- UI route/Snackbar/controller/repository를 제거해도 WP03-09 soft-delete는 유지된다.
- emergency server rollback은 restore execute를 revoke하고 trash read-only projection을 유지한다.
- schema rollback은 forward migration으로 client retirement 뒤 restored constraint/functions를 제거하며 적용 migration을 수정하지 않는다.

## Non-scope

- permanent purge, retention policy, archive, bulk selection
- repeating-series cancellation restore와 completed-item delete
- removed assignee를 restore 과정에서 변경하는 editor
- managed-child acting context/approval
- hosted/real-account/multi-device/physical-device evidence
