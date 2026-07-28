-- KinFlow WP02-02 household authorization boundary.
-- Store MVP scope: authenticated adults only; no Managed Child surfaces.

create or replace function app_private.is_valid_iana_timezone(
  p_timezone text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_timezone is not null
    and (
      p_timezone = 'UTC'
      or (
        p_timezone like '%/%'
        and p_timezone !~ '^(posix|right)/'
        and exists (
          select 1
          from pg_catalog.pg_timezone_names as timezone_name
          where timezone_name.name = p_timezone
        )
      )
    )
$$;

revoke all on function app_private.is_valid_iana_timezone(text) from public;
grant execute on function app_private.is_valid_iana_timezone(text)
  to authenticated, service_role;

alter table public.profiles
  add constraint profiles_timezone_iana_ck
  check (app_private.is_valid_iana_timezone(timezone))
  not valid;

alter table public.profiles
  validate constraint profiles_timezone_iana_ck;

alter table public.households
  add constraint households_timezone_iana_ck
  check (app_private.is_valid_iana_timezone(timezone))
  not valid;

alter table public.households
  validate constraint households_timezone_iana_ck;

create or replace function app_private.current_user_member_id(
  p_household_id uuid
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select member.id
  from public.household_members as member
  where member.household_id = p_household_id
    and member.auth_user_id = (select auth.uid())
    and member.removed_at is null
  limit 1
$$;

create or replace function app_private.is_active_household_member(
  p_household_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.household_members as member
    where member.household_id = p_household_id
      and member.auth_user_id = (select auth.uid())
      and member.removed_at is null
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
    from public.household_members as member
    where member.household_id = p_household_id
      and member.auth_user_id = (select auth.uid())
      and member.removed_at is null
      and member.role = any(p_roles)
  )
$$;

revoke all on function app_private.current_user_member_id(uuid) from public;
revoke all on function app_private.is_active_household_member(uuid) from public;
revoke all on function app_private.has_household_role(
  uuid,
  public.household_role[]
) from public;

grant usage on schema app_private to authenticated;
grant execute on function app_private.current_user_member_id(uuid)
  to authenticated;
grant execute on function app_private.is_active_household_member(uuid)
  to authenticated;
grant execute on function app_private.has_household_role(
  uuid,
  public.household_role[]
) to authenticated;

create or replace function app_private.assert_household_owner_integrity(
  p_household_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  household_owner_member_id uuid;
  active_owner_count bigint;
  owner_pointer_matches boolean;
begin
  select household.owner_member_id
  into household_owner_member_id
  from public.households as household
  where household.id = p_household_id;

  if not found then
    return;
  end if;

  select
    count(*),
    coalesce(bool_or(member.id = household_owner_member_id), false)
  into active_owner_count, owner_pointer_matches
  from public.household_members as member
  where member.household_id = p_household_id
    and member.role = 'owner'
    and member.removed_at is null;

  if active_owner_count <> 1 then
    raise exception using
      errcode = '23514',
      message = 'household must have exactly one active owner',
      constraint = 'households_exactly_one_active_owner_ck';
  end if;

  if not owner_pointer_matches then
    raise exception using
      errcode = '23514',
      message = 'household owner pointer must reference its active owner',
      constraint = 'households_owner_pointer_active_ck';
  end if;
end;
$$;

create or replace function app_private.enforce_household_owner_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'households' then
    if tg_op <> 'DELETE' then
      perform app_private.assert_household_owner_integrity(new.id);
    end if;
    return null;
  end if;

  if tg_op <> 'INSERT' then
    perform app_private.assert_household_owner_integrity(old.household_id);
  end if;

  if tg_op <> 'DELETE'
    and (
      tg_op <> 'UPDATE'
      or new.household_id is distinct from old.household_id
    ) then
    perform app_private.assert_household_owner_integrity(new.household_id);
  end if;

  return null;
end;
$$;

revoke all on function app_private.assert_household_owner_integrity(uuid)
  from public;
revoke all on function app_private.enforce_household_owner_integrity()
  from public;

create constraint trigger households_owner_integrity
after insert or update on public.households
deferrable initially deferred
for each row
execute function app_private.enforce_household_owner_integrity();

create constraint trigger household_members_owner_integrity
after insert or update or delete on public.household_members
deferrable initially deferred
for each row
execute function app_private.enforce_household_owner_integrity();

drop policy active_household_select_self
on public.user_active_households;

create policy active_household_select_self
on public.user_active_households
for select
to authenticated
using (
  auth_user_id = (select auth.uid())
  and member_id = app_private.current_user_member_id(household_id)
);

drop policy active_household_update_self
on public.user_active_households;

create policy active_household_update_self
on public.user_active_households
for update
to authenticated
using (
  auth_user_id = (select auth.uid())
  and member_id = app_private.current_user_member_id(household_id)
)
with check (
  auth_user_id = (select auth.uid())
  and member_id = app_private.current_user_member_id(household_id)
);

do $$
declare
  household_record record;
begin
  for household_record in
    select household.id
    from public.households as household
  loop
    perform app_private.assert_household_owner_integrity(
      household_record.id
    );
  end loop;
end;
$$;
