# 원본 파일 문서화: `contracts/rls-contract.sql`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/rls-contract.sql`
- 원본 형식: `sql`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.

```sql
-- KinFlow RLS contract v1.0
-- Apply after the core schema. This file defines minimum authorization semantics.

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
    'event_series', 'event_series_revisions', 'event_participants',
    'event_occurrences', 'event_occurrence_exceptions',
    'notification_endpoints', 'notification_preferences', 'notification_intents',
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

-- Profiles: users can read/update only their own profile. Insert is performed by trusted bootstrap/RPC.
create policy profiles_select_self on public.profiles
for select to authenticated
using (auth_user_id = auth.uid());

create policy profiles_update_self on public.profiles
for update to authenticated
using (auth_user_id = auth.uid())
with check (auth_user_id = auth.uid());

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

-- Update is allowed only to a membership belonging to the same authenticated user.
create policy active_household_update_self on public.user_active_households
for update to authenticated
using (auth_user_id = auth.uid())
with check (
  auth_user_id = auth.uid()
  and exists (
    select 1 from public.household_members hm
    where hm.household_id = user_active_households.household_id
      and hm.id = user_active_households.member_id
      and hm.auth_user_id = auth.uid()
      and hm.removed_at is null
  )
);

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

create policy event_exceptions_select_member on public.event_occurrence_exceptions
for select to authenticated
using (app_private.is_active_household_member(household_id));

-- Notification endpoints and preferences are user-owned. Server workers use service role in a restricted environment.
create policy notification_endpoints_select_self on public.notification_endpoints
for select to authenticated
using (auth_user_id = auth.uid());

create policy notification_preferences_select_self on public.notification_preferences
for select to authenticated
using (auth_user_id = auth.uid() and app_private.is_active_household_member(household_id));

create policy notification_preferences_update_self on public.notification_preferences
for update to authenticated
using (auth_user_id = auth.uid() and app_private.is_active_household_member(household_id))
with check (auth_user_id = auth.uid() and app_private.is_active_household_member(household_id));

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

-- Billing users can read their customer and active household entitlement; all mutations are server-only.
create policy billing_customers_select_self on public.billing_customers
for select to authenticated
using (auth_user_id = auth.uid());

create policy billing_assignments_select_member on public.billing_household_assignments
for select to authenticated
using (
  billing_owner_user_id = auth.uid()
  or app_private.is_active_household_member(household_id)
);

create policy household_entitlements_select_member on public.household_entitlements
for select to authenticated
using (app_private.is_active_household_member(household_id));

create policy plan_catalog_select_authenticated on public.plan_catalog
for select to authenticated
using (active = true);

-- Privacy records are visible only to the requesting user; export object download uses signed server URL.
create policy privacy_requests_select_self on public.privacy_requests
for select to authenticated
using (auth_user_id = auth.uid());

create policy data_exports_select_self on public.data_exports
for select to authenticated
using (
  exists (
    select 1 from public.privacy_requests pr
    where pr.id = data_exports.privacy_request_id
      and pr.auth_user_id = auth.uid()
  )
);

create policy consent_records_select_self on public.consent_records
for select to authenticated
using (auth_user_id = auth.uid());

-- Audit is not exposed directly to general clients in MVP. Feature flags and kill switches are served via a sanitized view/API.

create or replace view public.current_household_entitlement
with (security_invoker = true)
as
select
  he.household_id,
  he.plan_code,
  he.status,
  he.features,
  he.current_period_end,
  he.will_renew,
  he.verified_at,
  he.version
from public.household_entitlements he;

grant select on public.current_household_entitlement to authenticated;

-- Explicit table grants must remain minimal. RLS does not replace GRANT discipline.
revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;

grant select, update on public.profiles to authenticated;
grant select on public.households, public.household_members, public.member_guardians,
  public.acting_contexts, public.household_invites to authenticated;
grant select, update on public.user_active_households to authenticated;
grant select on public.chore_series, public.chore_series_revisions,
  public.chore_occurrences, public.chore_completion_events to authenticated;
grant select on public.event_series, public.event_series_revisions,
  public.event_participants, public.event_occurrences, public.event_occurrence_exceptions to authenticated;
grant select on public.notification_endpoints, public.notification_intents,
  public.notification_deliveries to authenticated;
grant select, update on public.notification_preferences to authenticated;
grant select on public.billing_customers, public.billing_household_assignments,
  public.household_entitlements, public.plan_catalog to authenticated;
grant select on public.privacy_requests, public.data_exports, public.consent_records to authenticated;

-- No anon table grants. Public invite preview and privacy request entry use rate-limited Edge endpoints.

comment on view public.current_household_entitlement is
  'RLS-aware entitlement projection for authenticated household members.';
```
