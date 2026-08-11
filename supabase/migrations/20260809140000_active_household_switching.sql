-- KinFlow WP02-08 active-household switching.
-- Authenticated adults can list only their own memberships and change the
-- single active pointer through an optimistic, server-authoritative command.

alter table public.user_active_households
  add column version bigint not null default 1 check (version > 0);

drop trigger if exists user_active_households_set_updated_at
  on public.user_active_households;

create trigger user_active_households_set_updated_at_and_version
before update on public.user_active_households
for each row execute function app_private.set_updated_at_and_version();

create table app_private.active_household_switch_audit_events (
  id uuid primary key default extensions.gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  previous_household_id uuid references public.households(id) on delete cascade,
  next_household_id uuid not null references public.households(id) on delete cascade,
  previous_selection_version bigint not null check (
    previous_selection_version >= 0
  ),
  next_selection_version bigint not null check (
    next_selection_version > previous_selection_version
  ),
  occurred_at timestamptz not null default pg_catalog.statement_timestamp()
);

alter table app_private.active_household_switch_audit_events
  enable row level security;
alter table app_private.active_household_switch_audit_events
  force row level security;

revoke all on table app_private.active_household_switch_audit_events
  from public, anon, authenticated, service_role;

create or replace function public.list_my_households()
returns table (
  household_id uuid,
  member_id uuid,
  household_name text,
  member_role public.household_role,
  membership_version bigint,
  is_active boolean,
  selection_version bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
begin
  if v_authenticated_user_id is null
    or not app_private.is_current_user_active() then
    raise exception using
      errcode = 'KFH01',
      message = 'authentication required';
  end if;

  return query
  select
    household.id,
    member.id,
    household.name,
    member.role,
    member.version,
    active_household.household_id = household.id
      and active_household.member_id = member.id,
    pg_catalog.coalesce(active_household.version, 0::bigint)
  from public.household_members as member
  join public.households as household
    on household.id = member.household_id
   and household.deleted_at is null
  left join public.user_active_households as active_household
    on active_household.auth_user_id = v_authenticated_user_id
  where member.auth_user_id = v_authenticated_user_id
    and member.removed_at is null
    and member.identity_deleted_at is null
  order by
    (
      active_household.household_id = household.id
      and active_household.member_id = member.id
    ) desc,
    pg_catalog.lower(household.name),
    household.id;
end;
$$;

create or replace function public.switch_active_household(
  p_target_household_id uuid,
  p_expected_selection_version bigint
)
returns table (
  household_id uuid,
  member_id uuid,
  selection_version bigint,
  changed boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_target_member_id uuid;
  v_current_household_id uuid;
  v_current_member_id uuid;
  v_current_version bigint;
  v_next_version bigint;
begin
  if v_authenticated_user_id is null
    or not app_private.is_current_user_active() then
    raise exception using
      errcode = 'KFH01',
      message = 'authentication required';
  end if;
  if p_target_household_id is null
    or p_expected_selection_version is null
    or p_expected_selection_version < 0 then
    raise exception using
      errcode = 'KFH02',
      message = 'invalid household selection input';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_authenticated_user_id::text, 0)
  );

  select
    active_household.household_id,
    active_household.member_id,
    active_household.version
  into
    v_current_household_id,
    v_current_member_id,
    v_current_version
  from public.user_active_households as active_household
  where active_household.auth_user_id = v_authenticated_user_id
  for update;

  select member.id
  into v_target_member_id
  from public.household_members as member
  join public.households as household
    on household.id = member.household_id
   and household.deleted_at is null
  where member.household_id = p_target_household_id
    and member.auth_user_id = v_authenticated_user_id
    and member.removed_at is null
    and member.identity_deleted_at is null
  for update of member;

  if not found then
    raise exception using
      errcode = 'KFH06',
      message = 'household selection target unavailable';
  end if;

  if v_current_version is null then
    if p_expected_selection_version <> 0 then
      raise exception using
        errcode = 'KFH07',
        message = 'household selection version conflict';
    end if;

    insert into public.user_active_households (
      auth_user_id,
      household_id,
      member_id
    )
    values (
      v_authenticated_user_id,
      p_target_household_id,
      v_target_member_id
    )
    returning version into v_next_version;

    insert into app_private.active_household_switch_audit_events (
      auth_user_id,
      previous_household_id,
      next_household_id,
      previous_selection_version,
      next_selection_version
    )
    values (
      v_authenticated_user_id,
      null,
      p_target_household_id,
      0,
      v_next_version
    );

    return query select
      p_target_household_id,
      v_target_member_id,
      v_next_version,
      true;
    return;
  end if;

  if v_current_household_id = p_target_household_id
    and v_current_member_id = v_target_member_id then
    return query select
      v_current_household_id,
      v_current_member_id,
      v_current_version,
      false;
    return;
  end if;

  if v_current_version <> p_expected_selection_version then
    raise exception using
      errcode = 'KFH07',
      message = 'household selection version conflict';
  end if;

  update public.user_active_households as active_household
  set
    household_id = p_target_household_id,
    member_id = v_target_member_id
  where active_household.auth_user_id = v_authenticated_user_id
  returning active_household.version into v_next_version;

  insert into app_private.active_household_switch_audit_events (
    auth_user_id,
    previous_household_id,
    next_household_id,
    previous_selection_version,
    next_selection_version
  )
  values (
    v_authenticated_user_id,
    v_current_household_id,
    p_target_household_id,
    v_current_version,
    v_next_version
  );

  return query select
    p_target_household_id,
    v_target_member_id,
    v_next_version,
    true;
end;
$$;

revoke update on table public.user_active_households from authenticated;
revoke update (household_id, member_id)
  on table public.user_active_households from authenticated;

revoke all on function public.list_my_households()
  from public, anon, authenticated, service_role;
grant execute on function public.list_my_households() to authenticated;

revoke all on function public.switch_active_household(uuid, bigint)
  from public, anon, authenticated, service_role;
grant execute on function public.switch_active_household(uuid, bigint)
  to authenticated;

comment on column public.user_active_households.version is
  'WP02-08 optimistic version for the single active-household selection.';
comment on table app_private.active_household_switch_audit_events is
  'WP02-08 private content-free active-household transition audit.';
comment on function public.list_my_households() is
  'WP02-08 privacy-minimized current-adult household membership projection.';
comment on function public.switch_active_household(uuid, bigint) is
  'WP02-08 versioned active-household switch deriving the target member server-side.';
