-- KinFlow WP03-05H occurrence history read projection.
-- Existing immutable audit relations remain the source of truth; this function
-- exposes only the bounded household-member view needed by the client.

create or replace function public.get_chore_occurrence_history(
  p_household_id uuid,
  p_occurrence_id uuid,
  p_limit integer default 20,
  p_before_occurred_at timestamptz default null,
  p_before_entry_id text default null
)
returns table (
  household_id uuid,
  occurrence_id uuid,
  history_entry_id text,
  event_type text,
  actor_member_id uuid,
  actor_display_name text,
  acting_member_id uuid,
  acting_display_name text,
  occurred_at timestamptz,
  occurrence_version bigint,
  previous_due_local_date date,
  previous_due_local_time time without time zone,
  new_due_local_date date,
  new_due_local_time time without time zone,
  previous_assignee_member_id uuid,
  previous_assignee_display_name text,
  new_assignee_member_id uuid,
  new_assignee_display_name text,
  has_more boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFC01',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or p_occurrence_id is null
    or p_limit is null
    or p_limit not between 1 and 100
    or ((p_before_occurred_at is null) <>
      (p_before_entry_id is null))
    or (
      p_before_entry_id is not null
      and p_before_entry_id !~
        '^(completion|reschedule|assignment):[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
    ) then
    raise exception using
      errcode = 'KFC02',
      message = 'invalid chore input';
  end if;

  perform 1
  from public.households as household
  join public.household_members as caller
    on caller.household_id = household.id
   and caller.auth_user_id = v_authenticated_user_id
   and caller.removed_at is null
  join public.chore_occurrences as occurrence
    on occurrence.household_id = household.id
   and occurrence.id = p_occurrence_id
  where household.id = p_household_id
    and household.deleted_at is null;

  if not found then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  return query
  with all_history as (
    select
      event.household_id,
      event.occurrence_id,
      'completion:' || event.id::text as history_entry_id,
      case
        when event.event_type = 'reopened'
          and exists (
            select 1
            from app_private.chore_restore_command_requests as request
            where request.household_id = event.household_id
              and request.occurrence_id = event.occurrence_id
              and request.result_event_id = event.id
          ) then 'restored'
        else event.event_type
      end as event_type,
      event.actor_member_id,
      actor.display_name as actor_display_name,
      event.acting_member_id,
      acting.display_name as acting_display_name,
      event.occurred_at,
      event.occurrence_version,
      null::date as previous_due_local_date,
      null::time without time zone as previous_due_local_time,
      null::date as new_due_local_date,
      null::time without time zone as new_due_local_time,
      null::uuid as previous_assignee_member_id,
      null::text as previous_assignee_display_name,
      null::uuid as new_assignee_member_id,
      null::text as new_assignee_display_name
    from public.chore_completion_events as event
    join public.household_members as actor
      on actor.household_id = event.household_id
     and actor.id = event.actor_member_id
    left join public.household_members as acting
      on acting.household_id = event.household_id
     and acting.id = event.acting_member_id
    where event.household_id = p_household_id
      and event.occurrence_id = p_occurrence_id

    union all

    select
      event.household_id,
      event.occurrence_id,
      'reschedule:' || event.id::text,
      'rescheduled'::text,
      event.actor_member_id,
      actor.display_name,
      null::uuid,
      null::text,
      event.occurred_at,
      event.occurrence_version,
      event.previous_due_local_date,
      event.previous_due_local_time,
      event.new_due_local_date,
      event.new_due_local_time,
      null::uuid,
      null::text,
      null::uuid,
      null::text
    from public.chore_reschedule_events as event
    join public.household_members as actor
      on actor.household_id = event.household_id
     and actor.id = event.actor_member_id
    where event.household_id = p_household_id
      and event.occurrence_id = p_occurrence_id

    union all

    select
      event.household_id,
      event.occurrence_id,
      'assignment:' || event.id::text,
      'reassigned'::text,
      event.actor_member_id,
      actor.display_name,
      null::uuid,
      null::text,
      event.occurred_at,
      event.occurrence_version,
      null::date,
      null::time without time zone,
      null::date,
      null::time without time zone,
      event.previous_assignee_member_id,
      previous_assignee.display_name,
      event.new_assignee_member_id,
      new_assignee.display_name
    from public.chore_assignment_events as event
    join public.household_members as actor
      on actor.household_id = event.household_id
     and actor.id = event.actor_member_id
    join public.household_members as previous_assignee
      on previous_assignee.household_id = event.household_id
     and previous_assignee.id = event.previous_assignee_member_id
    join public.household_members as new_assignee
      on new_assignee.household_id = event.household_id
     and new_assignee.id = event.new_assignee_member_id
    where event.household_id = p_household_id
      and event.occurrence_id = p_occurrence_id
  ),
  filtered_history as (
    select history.*
    from all_history as history
    where p_before_occurred_at is null
      or (history.occurred_at, history.history_entry_id) <
        (p_before_occurred_at, p_before_entry_id)
  ),
  bounded_history as (
    select history.*
    from filtered_history as history
    order by history.occurred_at desc, history.history_entry_id desc
    limit (p_limit + 1)
  ),
  page_history as (
    select history.*
    from bounded_history as history
    order by history.occurred_at desc, history.history_entry_id desc
    limit p_limit
  ),
  page_metadata as (
    select count(*) > p_limit as has_more
    from bounded_history
  )
  select
    history.household_id,
    history.occurrence_id,
    history.history_entry_id,
    history.event_type,
    history.actor_member_id,
    history.actor_display_name,
    history.acting_member_id,
    history.acting_display_name,
    history.occurred_at,
    history.occurrence_version,
    history.previous_due_local_date,
    history.previous_due_local_time,
    history.new_due_local_date,
    history.new_due_local_time,
    history.previous_assignee_member_id,
    history.previous_assignee_display_name,
    history.new_assignee_member_id,
    history.new_assignee_display_name,
    metadata.has_more
  from page_history as history
  cross join page_metadata as metadata
  order by history.occurred_at desc, history.history_entry_id desc;
end;
$$;

revoke all on function public.get_chore_occurrence_history(
  uuid,
  uuid,
  integer,
  timestamptz,
  text
) from public, anon, authenticated;

grant execute on function public.get_chore_occurrence_history(
  uuid,
  uuid,
  integer,
  timestamptz,
  text
) to authenticated;
