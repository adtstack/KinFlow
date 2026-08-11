-- KinFlow WP03-11 adult household activation progress.
-- This is a privacy-minimized read projection; it does not persist visits.

create index chore_completion_events_activation_progress_idx
  on public.chore_completion_events(
    household_id,
    actor_member_id
  )
  where event_type = 'completed';

create or replace function public.get_household_activation_progress(
  p_household_id uuid
)
returns table (
  household_id uuid,
  adult_participant_progress smallint,
  chore_creation_progress smallint,
  distinct_adult_completer_progress smallint,
  return_after_first_day_reached boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_evaluated_at timestamptz := pg_catalog.clock_timestamp();
  v_household_timezone text;
  v_household_created_at timestamptz;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFC01',
      message = 'authentication required';
  end if;

  if p_household_id is null then
    raise exception using
      errcode = 'KFC02',
      message = 'invalid chore input';
  end if;

  select household.timezone, household.created_at
  into v_household_timezone, v_household_created_at
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
    p_household_id,
    least(
      (
        select pg_catalog.count(distinct member.auth_user_id)
        from public.household_members as member
        where member.household_id = p_household_id
      ),
      2::bigint
    )::smallint,
    least(
      (
        select pg_catalog.count(distinct event.aggregate_id)
        from app_private.chore_domain_events as event
        where event.household_id = p_household_id
          and event.event_name = 'chore.series_created'
      ),
      3::bigint
    )::smallint,
    least(
      (
        select pg_catalog.count(distinct actor.auth_user_id)
        from public.chore_completion_events as event
        join public.household_members as actor
          on actor.household_id = event.household_id
         and actor.id = event.actor_member_id
        where event.household_id = p_household_id
          and event.event_type = 'completed'
      ),
      2::bigint
    )::smallint,
    (
      v_evaluated_at at time zone v_household_timezone
    )::date > (
      v_household_created_at at time zone v_household_timezone
    )::date;
end;
$$;

comment on function public.get_household_activation_progress(uuid) is
  'Returns capped, content-free historical activation milestones for an active household member; no visit row is persisted.';

revoke all on function public.get_household_activation_progress(uuid)
  from public, anon;
grant execute on function public.get_household_activation_progress(uuid)
  to authenticated;
