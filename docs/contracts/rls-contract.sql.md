# 원본 파일 문서화: `contracts/rls-contract.sql`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/rls-contract.sql`
- 원본 형식: `sql`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.
- 범위 주의: Managed Child·guardian·acting context policy는 P1 참조 전용이며 Store MVP RLS migration/test Gate에서 제외한다(D-013).

```sql
-- KinFlow RLS contract v1.0
-- Apply after the core schema. This file defines minimum authorization semantics.
-- D-013: child/guardian/acting-context policies are P1 reference only.

create or replace function app_private.current_user_member_id(p_household_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select hm.id
  from public.household_members hm
  where hm.household_id = p_household_id
    and hm.auth_user_id = auth.uid()
    and hm.removed_at is null
  limit 1
$$;

create or replace function app_private.is_active_household_member(p_household_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.household_members hm
    where hm.household_id = p_household_id
      and hm.auth_user_id = auth.uid()
      and hm.removed_at is null
  )
$$;

create or replace function app_private.has_household_role(
  p_household_id uuid,
  p_roles public.household_role[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.household_members hm
    where hm.household_id = p_household_id
      and hm.auth_user_id = auth.uid()
      and hm.removed_at is null
      and hm.role = any(p_roles)
  )
$$;

create or replace function app_private.can_act_as_member(
  p_household_id uuid,
  p_acting_member_id uuid,
  p_context_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.acting_contexts ac
    join public.household_members child
      on child.household_id = ac.household_id
     and child.id = ac.acting_member_id
     and child.role = 'managed_child'
     and child.removed_at is null
    where ac.id = p_context_id
      and ac.household_id = p_household_id
      and ac.authenticated_user_id = auth.uid()
      and ac.acting_member_id = p_acting_member_id
      and ac.revoked_at is null
      and ac.expires_at > now()
  )
$$;

revoke all on function app_private.current_user_member_id(uuid) from public;
revoke all on function app_private.is_active_household_member(uuid) from public;
revoke all on function app_private.has_household_role(uuid, public.household_role[]) from public;
revoke all on function app_private.can_act_as_member(uuid, uuid, uuid) from public;

grant execute on function app_private.current_user_member_id(uuid) to authenticated;
grant execute on function app_private.is_active_household_member(uuid) to authenticated;
grant execute on function app_private.has_household_role(uuid, public.household_role[]) to authenticated;
grant execute on function app_private.can_act_as_member(uuid, uuid, uuid) to authenticated;

-- Enable and force RLS on all user/provider-facing tables.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles', 'households', 'household_members', 'user_active_households',
    'member_guardians', 'acting_contexts', 'household_invites',
    'chore_series', 'chore_series_revisions', 'chore_occurrences', 'chore_completion_events',
    'chore_sync_watermarks',
    'event_series', 'event_series_revisions', 'event_participants',
    'event_occurrences', 'event_occurrence_exceptions',
    'event_series_change_events', 'calendar_sync_watermarks',
    'notification_endpoints', 'notification_preferences',
    'notification_sync_watermarks',
    'notification_inbox_items', 'notification_intents',
    'notification_deliveries', 'background_jobs', 'outbox_events', 'idempotency_keys',
    'billing_customers', 'billing_webhook_receipts', 'billing_transactions',
    'billing_household_assignments', 'plan_catalog', 'household_entitlements',
    'privacy_requests', 'data_exports', 'consent_records', 'audit_events',
    'feature_flags', 'kill_switches'
  ]
  loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('alter table public.%I force row level security', table_name);
  end loop;
end $$;

-- Profiles: users can read only their own profile. Insert is performed by the
-- trusted bootstrap RPC and WP07-06A mutations use the atomic preferences RPC.
create policy profiles_select_self on public.profiles
for select to authenticated
using (auth_user_id = auth.uid());

drop policy if exists profiles_update_self on public.profiles;

-- Households and members: active same-household read only.
create policy households_select_member on public.households
for select to authenticated
using (app_private.is_active_household_member(id));

create policy household_members_select_member on public.household_members
for select to authenticated
using (app_private.is_active_household_member(household_id));

-- Direct role/member writes are intentionally absent. Use transactional RPC/Edge functions.

create policy active_household_select_self on public.user_active_households
for select to authenticated
using (auth_user_id = auth.uid());

-- WP02-08 intentionally exposes no direct update policy or update grant.
-- list_my_households() returns an exact self-only projection and
-- switch_active_household(uuid,bigint) derives the caller/member from auth.uid(),
-- locks the selection, requires the optimistic version for a different target,
-- and writes a private content-free audit event.

create policy member_guardians_select_household on public.member_guardians
for select to authenticated
using (app_private.is_active_household_member(household_id));

create policy acting_contexts_select_owner on public.acting_contexts
for select to authenticated
using (authenticated_user_id = auth.uid());

-- Invite metadata is visible only to household admins; public preview uses an Edge function with minimal fields.
create policy household_invites_select_admin on public.household_invites
for select to authenticated
using (app_private.has_household_role(household_id, array['owner','admin']::public.household_role[]));

-- Chore read access.
create policy chore_series_select_member on public.chore_series
for select to authenticated
using (app_private.is_active_household_member(household_id));

create policy chore_revisions_select_member on public.chore_series_revisions
for select to authenticated
using (app_private.is_active_household_member(household_id));

create policy chore_occurrences_select_member on public.chore_occurrences
for select to authenticated
using (app_private.is_active_household_member(household_id));

create policy chore_completion_events_select_member on public.chore_completion_events
for select to authenticated
using (app_private.is_active_household_member(household_id));

-- Chore series create/update and occurrence completion are RPC/Edge-only in baseline.

-- Calendar read access.
create policy event_series_select_member on public.event_series
for select to authenticated
using (app_private.is_active_household_member(household_id));

create policy event_revisions_select_member on public.event_series_revisions
for select to authenticated
using (app_private.is_active_household_member(household_id));

create policy event_participants_select_member on public.event_participants
for select to authenticated
using (app_private.is_active_household_member(household_id));

create policy event_occurrences_select_member on public.event_occurrences
for select to authenticated
using (app_private.is_active_household_member(household_id));

create policy calendar_sync_watermarks_select_member
on public.calendar_sync_watermarks
for select to authenticated
using (app_private.is_active_household_member(household_id));

create policy chore_sync_watermarks_select_member
on public.chore_sync_watermarks
for select to authenticated
using (app_private.is_active_household_member(household_id));

create policy notification_sync_watermarks_select_self
on public.notification_sync_watermarks
for select to authenticated
using (auth_user_id = (select auth.uid()));

create policy event_occurrence_exceptions_select_member on public.event_occurrence_exceptions
for select to authenticated
using (
  app_private.is_active_household_member(household_id)
  and exists (
    select 1
    from public.event_series as series
    where series.household_id = event_occurrence_exceptions.household_id
      and series.id = event_occurrence_exceptions.series_id
      and series.deleted_at is null
  )
);

create policy event_series_change_events_select_member
on public.event_series_change_events
for select to authenticated
using (app_private.is_active_household_member(household_id));

-- Calendar create/update/cancel commands are authenticated SECURITY DEFINER
-- RPCs with empty search_path and server-side actor/household/participant checks.
-- Rolling materialization is executable only by service_role. API roles have no
-- cron schema or private command/state/run table privileges.

-- Notification endpoints are user-owned but their token-bearing table has no
-- direct authenticated or service-role grant. WP05-03 exposes metadata only
-- through get_notification_endpoint_status; registration/revoke/invalidation
-- use bounded SECURITY DEFINER RPCs from the Edge/service boundary. WP05-02
-- preference writes and inbox read transitions are likewise mediated. WP05-04/05
-- push evaluation/delivery/control/provider-health/transition tables stay in
-- app_private with no direct client or service-role grants. Claim, submission
-- marker, finalize, bounded replay, backoff reset, aggregate health and pause are
-- service-role-only mediated calls. Transition rows are immutable.
-- resolve_notification_push_target returns an authenticated recipient only an
-- allowlisted safe destination after latest-state recheck.
create policy notification_endpoints_select_self on public.notification_endpoints
for select to authenticated
using (
  auth_user_id = auth.uid()
  and app_private.is_active_household_member(household_id)
);

create policy notification_preferences_select_self on public.notification_preferences
for select to authenticated
using (auth_user_id = auth.uid() and app_private.is_active_household_member(household_id));

create policy notification_inbox_select_recipient on public.notification_inbox_items
for select to authenticated
using (
  recipient_user_id = auth.uid()
  and app_private.is_active_household_member(household_id)
);

-- Authenticated preference updates, inbox pagination, unread count, and
-- individual/all read commands are exposed only through the exact WP05-02
-- functions in contracts/notification-inbox.yaml. Inbox insertion and
-- evaluation are service-role-only mediated materializer operations. Native
-- push delivery remains an independent private pipeline specified by
-- contracts/notification-push.yaml.

create policy notification_intents_select_recipient on public.notification_intents
for select to authenticated
using (recipient_user_id = auth.uid());

create policy notification_deliveries_select_recipient on public.notification_deliveries
for select to authenticated
using (
  exists (
    select 1
    from public.notification_intents ni
    where ni.id = notification_deliveries.intent_id
      and ni.recipient_user_id = auth.uid()
  )
);

-- Internal queue/outbox/idempotency tables intentionally have no client policies.
-- Billing receipts and normalized transactions also have no client policy or grant.
-- They contain encrypted provider material or hashed transaction references and are
-- reachable only through the service-only verified-event command.

-- Billing users can read their own customer mapping and active-household projection;
-- every mutation and policy/limit assertion remains server-only.
create policy billing_customers_select_self on public.billing_customers
for select to authenticated
using (auth_user_id = (select auth.uid()));

create policy billing_assignments_select_member on public.billing_household_assignments
for select to authenticated
using (
  billing_owner_user_id = (select auth.uid())
  or app_private.is_active_household_member(household_id)
);

create policy household_entitlements_select_member on public.household_entitlements
for select to authenticated
using (app_private.is_active_household_member(household_id));

create policy plan_catalog_select_authenticated on public.plan_catalog
for select to authenticated
using (active = true);

-- WP07-01 tombstoning makes profile/member/billing-owner authorization fail
-- closed even while an old access token remains unexpired. Privacy request
-- status itself is a minimal self-only projection until Auth soft-delete.
create policy privacy_requests_select_self on public.privacy_requests
for select to authenticated
using (auth_user_id = auth.uid());

create policy data_exports_select_self on public.data_exports
for select to authenticated
using (app_private.is_own_data_export(privacy_request_id));

create policy consent_records_select_self on public.consent_records
for select to authenticated
using (auth_user_id = auth.uid());

-- Audit is not exposed directly to general clients in MVP. Feature flags and kill switches are served via a sanitized view/API.

create or replace view public.current_household_entitlement
with (security_invoker = true)
as
select
  entitlement.household_id,
  entitlement.plan_code,
  entitlement.status,
  entitlement.source,
  case
    when catalog.limits_finalized then catalog.feature_limits
    else '{}'::jsonb
  end as feature_limits,
  catalog.limits_finalized,
  entitlement.current_period_end,
  entitlement.will_renew,
  entitlement.verified_at,
  entitlement.version
from public.household_entitlements as entitlement
join public.plan_catalog as catalog
  on catalog.plan_code = entitlement.plan_code
where catalog.active;

grant select on public.current_household_entitlement to authenticated;

-- Explicit table grants must remain minimal. RLS does not replace GRANT discipline.
revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;

grant select on public.profiles to authenticated;
grant select on public.households, public.household_members, public.member_guardians,
  public.acting_contexts, public.household_invites to authenticated;
grant select on public.user_active_households to authenticated;
grant execute on function public.list_my_households() to authenticated;
grant execute on function public.switch_active_household(uuid, bigint)
  to authenticated;
grant select on public.chore_series, public.chore_series_revisions,
  public.chore_occurrences, public.chore_completion_events,
  public.chore_sync_watermarks to authenticated;
grant select on public.event_series, public.event_series_revisions,
  public.event_participants, public.event_occurrences,
  public.event_occurrence_exceptions, public.event_series_change_events,
  public.calendar_sync_watermarks
  to authenticated;
grant select on public.notification_intents,
  public.notification_deliveries to authenticated;
grant select on public.notification_preferences,
  public.notification_inbox_items,
  public.notification_sync_watermarks to authenticated;
grant select on public.billing_customers, public.billing_household_assignments,
  public.household_entitlements, public.plan_catalog to authenticated;
grant select on public.privacy_requests, public.consent_records to authenticated;
grant select (
  id, privacy_request_id, schema_version,
  machine_checksum_sha256, human_checksum_sha256,
  machine_size_bytes, human_size_bytes,
  artifact_expires_at, revoked_at, purged_at,
  created_at, updated_at, version
) on public.data_exports to authenticated;

-- Account-deletion tables and helpers are not direct client surfaces. Edge and
-- worker identities use only the reviewed service-role RPCs below; private job,
-- idempotency, runtime and audit tables remain revoked even from service_role.
revoke all on function public.configure_account_deletion_runtime(boolean, integer, bigint, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.get_account_deletion_preflight(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.get_account_deletion_request(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.request_account_deletion(uuid, text, boolean, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.cancel_account_deletion(uuid, uuid, bigint, text, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.recover_expired_account_deletion_leases(timestamptz)
  from public, anon, authenticated, service_role;
revoke all on function public.claim_account_deletion_requests(uuid, integer, integer, timestamptz)
  from public, anon, authenticated, service_role;
revoke all on function public.prepare_account_deletion_request(uuid, uuid, timestamptz)
  from public, anon, authenticated, service_role;
revoke all on function public.complete_account_deletion_request(uuid, uuid, timestamptz)
  from public, anon, authenticated, service_role;
revoke all on function public.fail_account_deletion_request(uuid, uuid, text, boolean, timestamptz)
  from public, anon, authenticated, service_role;

grant execute on function public.configure_account_deletion_runtime(boolean, integer, bigint, uuid)
  to service_role;
grant execute on function public.get_account_deletion_preflight(uuid)
  to service_role;
grant execute on function public.get_account_deletion_request(uuid, uuid)
  to service_role;
grant execute on function public.request_account_deletion(uuid, text, boolean, uuid)
  to service_role;
grant execute on function public.cancel_account_deletion(uuid, uuid, bigint, text, uuid)
  to service_role;
grant execute on function public.recover_expired_account_deletion_leases(timestamptz)
  to service_role;
grant execute on function public.claim_account_deletion_requests(uuid, integer, integer, timestamptz)
  to service_role;
grant execute on function public.prepare_account_deletion_request(uuid, uuid, timestamptz)
  to service_role;
grant execute on function public.complete_account_deletion_request(uuid, uuid, timestamptz)
  to service_role;
grant execute on function public.fail_account_deletion_request(uuid, uuid, text, boolean, timestamptz)
  to service_role;

-- WP07-02A export object keys, commands, jobs, grants and audit are not client
-- surfaces. The self-read policy above exposes only safe artifact metadata;
-- every command/generation/download-consume/purge entry point is a reviewed
-- SECURITY DEFINER function granted only to service_role.
revoke all on table app_private.data_export_command_requests,
  app_private.data_export_jobs,
  app_private.data_export_download_grants,
  app_private.data_export_purge_jobs,
  app_private.data_export_events,
  app_private.data_export_runtime_events
from public, anon, authenticated, service_role;

revoke all on function public.configure_data_export_runtime(
  boolean, boolean, integer, integer, bigint, uuid
) from public, anon, authenticated, service_role;
revoke all on function public.get_data_export_preflight(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.get_data_export_request(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.request_data_export(uuid, text, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.cancel_data_export(uuid, uuid, bigint, text, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.revoke_data_export(uuid, uuid, bigint, text, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.create_data_export_download_grant(uuid, uuid, text, text, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.consume_data_export_download_grant(text, timestamptz)
  from public, anon, authenticated, service_role;

grant execute on function public.configure_data_export_runtime(
  boolean, boolean, integer, integer, bigint, uuid
) to service_role;
grant execute on function public.get_data_export_preflight(uuid) to service_role;
grant execute on function public.get_data_export_request(uuid, uuid) to service_role;
grant execute on function public.request_data_export(uuid, text, uuid) to service_role;
grant execute on function public.cancel_data_export(uuid, uuid, bigint, text, uuid)
  to service_role;
grant execute on function public.revoke_data_export(uuid, uuid, bigint, text, uuid)
  to service_role;
grant execute on function public.create_data_export_download_grant(uuid, uuid, text, text, uuid)
  to service_role;
grant execute on function public.consume_data_export_download_grant(text, timestamptz)
  to service_role;

-- Generation and purge claim/build/complete/fail/recovery functions follow the
-- same revoke-all then service-role-only execute rule. They are enumerated in
-- data-export.yaml and the normative migration to keep this skeleton concise.

-- Exact billing command grants. SECURITY DEFINER functions use search_path=''.
-- Direct mutation grants on all billing tables remain revoked from authenticated
-- and service_role; only these command entry points may mutate state.
revoke all on function public.configure_billing_runtime(text, boolean, bigint, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.configure_plan_feature_limits(text, jsonb, boolean, bigint, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.apply_verified_billing_event(
  text, text, text, text, timestamptz, uuid, text, text, text, text,
  text, uuid, public.entitlement_status, text, timestamptz, timestamptz,
  boolean, text, bytea, uuid
) from public, anon, authenticated, service_role;
revoke all on function public.get_household_entitlement(uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.configure_billing_runtime(text, boolean, bigint, uuid)
  to service_role;
grant execute on function public.configure_plan_feature_limits(text, jsonb, boolean, bigint, uuid)
  to service_role;
grant execute on function public.apply_verified_billing_event(
  text, text, text, text, timestamptz, uuid, text, text, text, text,
  text, uuid, public.entitlement_status, text, timestamptz, timestamptz,
  boolean, text, bytea, uuid
) to service_role;
grant execute on function public.get_household_entitlement(uuid)
  to authenticated;

revoke all on function public.configure_billing_feature_enforcement(
  boolean, bigint, uuid
) from public, anon, authenticated, service_role;
revoke all on function public.get_household_feature_gate(uuid, text, integer)
  from public, anon, authenticated, service_role;

grant execute on function public.configure_billing_feature_enforcement(
  boolean, bigint, uuid
) to service_role;
grant execute on function public.get_household_feature_gate(uuid, text, integer)
  to authenticated;

-- WP07-06A profile and regional settings. Caller identity, active household,
-- role, and expected versions are derived or rechecked inside the
-- empty-search-path SECURITY DEFINER commands. Direct profile/household/member
-- writes and private timezone-audit reads remain unavailable.
revoke all on function public.get_profile_preferences()
  from public, anon, authenticated;
revoke all on function public.update_profile_preferences(
  text, text, text, text, bigint, text, bigint
) from public, anon, authenticated;

grant execute on function public.get_profile_preferences()
  to authenticated;
grant execute on function public.update_profile_preferences(
  text, text, text, text, bigint, text, bigint
) to authenticated;

-- app_private.current_household_feature_usage and
-- app_private.evaluate_household_feature_gate,
-- app_private.enforce_household_feature_capacity and its trigger functions have
-- no authenticated/service_role execute grant. The authenticated gate verifies
-- active household membership and returns only aggregate capacity metadata;
-- reviewed server-authoritative triggers own actual mutation enforcement.

-- WP03-11 historical activation progress. The empty-search-path SECURITY
-- DEFINER function derives caller identity from auth.uid(), requires a current
-- active membership in the requested non-deleted household and returns only a
-- capped content-free aggregate. No private source table receives a client grant.
revoke all on function public.get_household_activation_progress(uuid)
  from public, anon;
grant execute on function public.get_household_activation_progress(uuid)
  to authenticated;

-- WP03-18 closed-week report. The empty-search-path SECURITY DEFINER function
-- derives auth.uid(), revalidates active membership and owns week boundaries.
-- It exposes no chore content, occurrence identity or removed-member identity.
revoke all on function public.get_household_weekly_report(uuid, integer)
  from public, anon;
grant execute on function public.get_household_weekly_report(uuid, integer)
  to authenticated;

-- WP03-20 selected-occurrence series edits remain fully mediated. The public
-- SECURITY DEFINER wrapper derives auth.uid(), rechecks active Owner/Admin,
-- locks the series and exact active scheduled target, and exposes only the
-- existing aggregate series-update result. The shared engine is never callable
-- by a client role and no new table policy or direct write grant is introduced.
revoke all on function app_private.update_repeating_chore_series_at_boundary(
  uuid, uuid, uuid, uuid, bigint, text, text, uuid,
  time without time zone, jsonb
) from public, anon, authenticated, service_role;
revoke all on function public.update_repeating_chore_series_from_occurrence(
  uuid, uuid, uuid, uuid, bigint, text, text, uuid,
  time without time zone, jsonb
) from public, anon, authenticated;
grant execute on function public.update_repeating_chore_series_from_occurrence(
  uuid, uuid, uuid, uuid, bigint, text, text, uuid,
  time without time zone, jsonb
) to authenticated;

-- WP03-21 selected-occurrence series cancellation is also fully mediated. The
-- empty-search-path SECURITY DEFINER function derives auth.uid(), rechecks an
-- active Owner/Admin, locks the series and exact active scheduled target, and
-- exposes only aggregate counts plus an optional terminal revision identity.
-- No client receives a new table grant or direct write policy.
revoke all on function public.cancel_repeating_chore_series_from_occurrence(
  uuid, uuid, uuid, uuid, bigint
) from public, anon, authenticated, service_role;
grant execute on function public.cancel_repeating_chore_series_from_occurrence(
  uuid, uuid, uuid, uuid, bigint
) to authenticated;

-- WP03-22 keeps the cancellation wrapper signature and result compatible while
-- its private engine and immutable pre-state ledger have no public, anon,
-- authenticated or service-role grants. The additive empty-search-path resume
-- function derives auth.uid(), binds the original cancellation actor, rechecks
-- current active Owner/Admin membership and locks the exact series/version.
revoke all on function public.resume_repeating_chore_series_cancellation(
  uuid, uuid, uuid, uuid, bigint
) from public, anon, authenticated, service_role;
grant execute on function public.resume_repeating_chore_series_cancellation(
  uuid, uuid, uuid, uuid, bigint
) to authenticated;

-- WP04-14 selected-occurrence Calendar series editing is fully mediated. The
-- authenticated SECURITY DEFINER wrapper sends the selected UUID to a private
-- empty-search-path boundary engine, which rechecks active membership and locks
-- the active scheduled non-exception target. No table grant or RLS policy is
-- added, and the legacy whole-series wrapper retains authenticated execute.
revoke all on function app_private.update_recurring_calendar_series_at_boundary(
  uuid, uuid, uuid, uuid, bigint, text, text, boolean, date,
  time without time zone, integer, date, text, text, jsonb, uuid[]
) from public, anon, authenticated, service_role;
revoke all on function public.update_recurring_calendar_series_from_occurrence(
  uuid, uuid, uuid, uuid, bigint, text, text, boolean, date,
  time without time zone, integer, date, text, text, jsonb, uuid[]
) from public, anon, authenticated;
grant execute on function public.update_recurring_calendar_series_from_occurrence(
  uuid, uuid, uuid, uuid, bigint, text, text, boolean, date,
  time without time zone, integer, date, text, text, jsonb, uuid[]
) to authenticated;

-- WP04-15 selected-occurrence Calendar cancellation is fully mediated. The
-- authenticated SECURITY DEFINER wrapper sends only the selected UUID and exact
-- series version to a private empty-search-path engine, which rechecks active
-- membership and locks the active scheduled non-exception target. No table grant
-- or RLS policy is added, and the legacy whole-series wrapper retains execute.
revoke all on function app_private.cancel_recurring_calendar_series_at_boundary(
  uuid, uuid, uuid, uuid, bigint
) from public, anon, authenticated, service_role;
revoke all on function public.cancel_recurring_calendar_series_from_occurrence(
  uuid, uuid, uuid, uuid, bigint
) from public, anon, authenticated;
grant execute on function public.cancel_recurring_calendar_series_from_occurrence(
  uuid, uuid, uuid, uuid, bigint
) to authenticated;

-- WP04-16 keeps that public cancellation signature/result compatible while the
-- renamed WP04-15 engine and immutable metadata-only pre-state ledger have no
-- public, anon, authenticated or service-role grants. The additive
-- empty-search-path resume function derives auth.uid(), binds the exact original
-- cancellation actor, rechecks current active household membership and locks the
-- exact series/version before restoring ledger-bound occurrence state.
revoke all on table app_private.calendar_series_cancellation_undo_items
  from public, anon, authenticated, service_role;
revoke all on function app_private.cancel_recurring_calendar_series_from_occurrence_wp04_15(
  uuid, uuid, uuid, uuid, bigint
) from public, anon, authenticated, service_role;
revoke all on function public.resume_recurring_calendar_series_cancellation(
  uuid, uuid, uuid, uuid, bigint
) from public, anon, authenticated, service_role;
grant execute on function public.resume_recurring_calendar_series_cancellation(
  uuid, uuid, uuid, uuid, bigint
) to authenticated;

-- WP05-14 generic email evaluation, delivery, transition and worker-control
-- tables are grant-free even to service_role. They contain no email/content;
-- the confirmed auth.users email is joined only inside one service-only claim
-- response and must remain ephemeral through exactly one provider call.
revoke all on table app_private.notification_email_evaluations,
  app_private.notification_email_deliveries,
  app_private.notification_email_delivery_transitions,
  app_private.notification_email_worker_control
from public, anon, authenticated, service_role;
revoke all on sequence app_private.notification_email_delivery_transitions_id_seq
  from public, anon, authenticated, service_role;

revoke all on function public.claim_notification_email_deliveries(
  uuid, integer, integer, timestamptz
) from public, anon, authenticated;
revoke all on function public.mark_notification_email_submission_started(
  uuid, uuid, timestamptz
) from public, anon, authenticated;
revoke all on function public.complete_notification_email_delivery(
  uuid, uuid, text, text, text, integer, timestamptz
) from public, anon, authenticated;
revoke all on function public.set_notification_email_worker_paused(
  boolean, timestamptz
) from public, anon, authenticated;

grant execute on function public.claim_notification_email_deliveries(
  uuid, integer, integer, timestamptz
) to service_role;
grant execute on function public.mark_notification_email_submission_started(
  uuid, uuid, timestamptz
) to service_role;
grant execute on function public.complete_notification_email_delivery(
  uuid, uuid, text, text, text, integer, timestamptz
) to service_role;
grant execute on function public.set_notification_email_worker_paused(
  boolean, timestamptz
) to service_role;

-- No anon table grants. Public invite preview and privacy request entry use rate-limited Edge endpoints.

comment on view public.current_household_entitlement is
  'RLS-aware entitlement projection without customer, transaction, receipt, or billing-owner identifiers.';
```
