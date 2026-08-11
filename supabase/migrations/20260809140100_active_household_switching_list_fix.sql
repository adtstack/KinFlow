-- WP02-08 forward correction: COALESCE is SQL syntax and cannot be
-- schema-qualified as a pg_catalog function.

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
    coalesce(active_household.version, 0::bigint)
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

comment on function public.list_my_households() is
  'WP02-08 privacy-minimized current-adult household membership projection.';
