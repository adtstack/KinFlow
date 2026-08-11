# Phase 03 WP03-09 One-time Chore Lifecycle Work Plan

## Status

- 상태: **LOCAL AUTOMATED COMPLETE (2026-08-09)** — WP03/G3/출시 완료는 아님
- 수직 조각: Today/list의 scheduled one-time chore → edit/delete UI → idempotent expected-version RPC → immutable revision/audit → authoritative list refresh
- 요구사항: `FR-CHORE-001`, `FR-CHORE-003`, `NFR-SEC-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-017`, `D-048`
- 실제 계정, remote Supabase, Realtime two-device, 실제 Android/iOS 기기 검증은 사용자 지시에 따라 마지막 Gate로 유지한다.
- 완료 증거: `docs/evidence/phase-03/WP03_09_EVIDENCE.md`

## Product boundary

- active household adult는 scheduled one-time chore의 title, optional description, assignee, due local date와 optional due local time을 한 번에 수정할 수 있다.
- active household adult는 scheduled one-time chore를 삭제할 수 있다. 삭제는 확인 후 수행하며 목록에서 사라진다.
- completed one-time chore는 history 보존을 위해 직접 수정·삭제하지 않는다. 먼저 기존 reopen 흐름으로 scheduled 상태로 되돌려야 한다.
- repeating chore는 기존 occurrence action과 Owner/Admin series edit/cancel 흐름을 그대로 사용한다.
- read-only offline cache에서는 수정·삭제를 제공하지 않고 기존 localized offline failure를 사용한다.
- managed-child 권한, approval, bulk edit/delete, undo-delete, archive/trash UI, content change history UI는 이번 slice에 없다.

## Database and API impact

- additive migration `20260808160000_one_time_chore_lifecycle.sql`을 추가한다.
- `public.one_time_chore_change_events`는 update/delete의 content-free immutable audit metadata만 보존한다. title과 description을 audit/log/command row에 복제하지 않는다.
- `app_private.one_time_chore_change_command_requests`는 caller + idempotency key의 request hash와 exact result metadata를 보존한다. authenticated client는 table을 직접 읽거나 쓸 수 없다.
- `public.update_one_time_chore(...)`는 active member, exact household/series/occurrence, one-time active revision, scheduled status, active assignee와 series/occurrence expected version을 server-authoritatively 검증한다.
- update는 기존 revision을 변경하지 않고 revision number를 증가시킨 새 immutable revision을 만든 뒤 series active revision과 stable occurrence를 atomic하게 갱신한다.
- `public.delete_one_time_chore(...)`는 occurrence를 `cancelled`로 전환하고 series에 `deleted_at`을 기록한다. occurrence/revision/audit는 물리 삭제하지 않는다.
- 같은 caller/idempotency/request는 `changed=false`로 exact replay하고, 다른 payload 또는 update/delete 교차 재사용은 `KFC04`로 거부한다.
- stale series 또는 occurrence version은 `KFC05`, no-op/completed/cancelled 전이는 `KFC06`, auth/input/scope 오류는 기존 `KFC01`/`KFC02`/`KFC03`을 사용한다.
- direct table mutation privilege는 추가하지 않는다. public audit select는 active household member RLS만 허용한다.

## Client impact

- pure Dart domain에 validated update/delete draft, request와 strict result snapshot을 추가한다.
- data source DTO → provider mapper → domain 경계를 유지하고 unknown/malformed RPC payload는 `invalidPayload`로 fail closed한다.
- repository, Supabase adapter, unavailable adapter, encrypted-cache invalidating wrapper와 test fakes에 두 mutation을 추가한다.
- Today controller는 duplicate action을 coalesce하고 command UUID를 같은 draft retry에 재사용하며, 성공과 stale/invalid-transition 뒤 authoritative current-query reload로 reconciliation한다.
- Today action menu는 scheduled one-time row에만 edit/delete를 노출한다. edit dialog는 title/description/assignee/date/time을 prefill하고 delete dialog는 destructive intent를 명확히 확인한다.
- 모든 표시 문자열은 EN/KO/EN-XA ARB를 사용하고 raw provider/exception text를 표시하지 않는다.

## Automated evidence plan

1. pgTAP: update all fields, new immutable revision, stable occurrence, version increments, audit, Today/list movement
2. pgTAP: delete soft-delete/cancel, preserved revision/audit, list exclusion, no direct table write
3. pgTAP: idempotent replay, changed flag, payload collision, update/delete cross-operation collision
4. pgTAP: unauthenticated, outsider, removed member, cross-household, inactive assignee, recurring target, completed target, stale series/occurrence versions, invalid/no-op input
5. domain/repository/adapter: valid request and strict DTO mapping, malformed/extra/missing fields, provider error mapping
6. controller: pending/coalescing, success reload, stale reconciliation, offline read-only rejection and delete removal
7. widget: one-time-only actions, prefilled edit submit, delete confirmation/cancel/success/failure, compact 200% text scroll and 48dp actions
8. full Flutter tests, analyzer warning 0, formatter drift 0, codegen drift 0, localization/config/secret/contract/matrix/whitespace checks

## Rollback

- UI/controller/repository methods can be removed independently and old clients remain compatible because the migration is additive.
- RPC execute grants can be revoked immediately to disable new mutations.
- audit and command tables plus functions may be dropped only after confirming no released client calls them; soft-deleted data must be restored with an explicit repair migration, never by deleting audit rows.
- no rollback physically deletes revisions, occurrences or audit evidence.

## Stop conditions

- update rewrites an existing revision, delete physically removes series/occurrence/revision, or audit duplicates title/description: do not ship.
- caller scope, active assignee, one-time type, scheduled status, both expected versions or idempotency are not server-enforced: do not ship.
- direct authenticated table write is possible, malformed DTO is accepted, offline cache can mutate, raw error leaks, localization/a11y regression or analyzer warning exists: do not ship.
