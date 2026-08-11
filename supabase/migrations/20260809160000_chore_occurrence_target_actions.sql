-- KinFlow WP05-09 actionable Chore occurrence target.
-- Keep the WP05-08 target RPC unchanged for strict N-1 clients.

create function public.get_chore_occurrence_action_target(
  p_household_id uuid,
  p_occurrence_id uuid
)
returns table (
  household_id uuid,
  series_id uuid,
  occurrence_id uuid,
  title text,
  description text,
  assignee_member_id uuid,
  assignee_display_name text,
  due_local_date date,
  due_local_time time without time zone,
  due_at timestamptz,
  status text,
  version bigint,
  recurrence_frequency text,
  series_version bigint,
  series_default_assignee_member_id uuid,
  series_due_local_time time without time zone,
  recurrence_rule jsonb,
  can_manage_series boolean,
  can_set_completion boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_actor_member_id uuid;
  v_actor_role public.household_role;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFC01',
      message = 'authentication required';
  end if;

  if p_household_id is null or p_occurrence_id is null then
    raise exception using
      errcode = 'KFC02',
      message = 'invalid chore input';
  end if;

  select caller.id, caller.role
  into v_actor_member_id, v_actor_role
  from public.households as household
  join public.household_members as caller
    on caller.household_id = household.id
   and caller.auth_user_id = v_authenticated_user_id
   and caller.removed_at is null
  where household.id = p_household_id
    and household.deleted_at is null;

  if not found then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  return query
  select
    target.household_id,
    target.series_id,
    target.occurrence_id,
    target.title,
    target.description,
    target.assignee_member_id,
    target.assignee_display_name,
    target.due_local_date,
    target.due_local_time,
    target.due_at,
    target.status,
    target.version,
    target.recurrence_frequency,
    target.series_version,
    target.series_default_assignee_member_id,
    target.series_due_local_time,
    target.recurrence_rule,
    target.can_manage_series,
    (
      series.deleted_at is null
      and (
        v_actor_role in ('owner', 'admin')
        or target.assignee_member_id = v_actor_member_id
      )
    )
  from public.get_chore_occurrence_target(
    p_household_id,
    p_occurrence_id
  ) as target
  join public.chore_series as series
    on series.household_id = target.household_id
   and series.id = target.series_id;

  if not found then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;
end;
$$;

revoke all on function public.get_chore_occurrence_action_target(
  uuid,
  uuid
) from public, anon, authenticated, service_role;
grant execute on function public.get_chore_occurrence_action_target(
  uuid,
  uuid
) to authenticated;

comment on function public.get_chore_occurrence_action_target(uuid, uuid) is
  'WP05-09 N-1-safe target projection with server-derived completion actionability.';
