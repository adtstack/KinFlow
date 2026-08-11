-- KinFlow WP05-13 per-user Calendar multiple reminders.
--
-- The existing reminder_lead_minutes remains the N-1 compatible primary
-- reminder. Calendar users may add at most two distinct fixed leads through
-- the additive v3 preference contract. Each additional reminder keeps the
-- existing content-free Calendar source payload and receives an internal
-- lead identity so the current worker, inbox, quiet-hours, Snooze, and Android
-- delivery pipeline can process it independently.

alter table public.notification_preferences
  add column additional_reminder_lead_minutes integer[]
    not null default '{}'::integer[];

create or replace function
  app_private.is_valid_notification_additional_reminder_leads(
    p_category text,
    p_primary_lead_minutes integer,
    p_additional_lead_minutes integer[]
  )
returns boolean
language sql
immutable
set search_path = ''
as $$
  select
    p_additional_lead_minutes is not null
    and coalesce(pg_catalog.array_ndims(p_additional_lead_minutes), 1) = 1
    and coalesce(
      pg_catalog.array_lower(p_additional_lead_minutes, 1),
      1
    ) = 1
    and pg_catalog.cardinality(p_additional_lead_minutes) between 0 and 2
    and pg_catalog.array_position(
      p_additional_lead_minutes,
      null::integer
    ) is null
    and p_additional_lead_minutes
      <@ array[0, 5, 10, 15, 30, 60]::integer[]
    and not (
      p_primary_lead_minutes = any(p_additional_lead_minutes)
    )
    and (
      pg_catalog.cardinality(p_additional_lead_minutes) < 2
      or p_additional_lead_minutes[1]
        < p_additional_lead_minutes[2]
    )
    and (
      p_category = 'calendar_event'
      or pg_catalog.cardinality(p_additional_lead_minutes) = 0
    )
$$;

revoke all on function
  app_private.is_valid_notification_additional_reminder_leads(
    text,
    integer,
    integer[]
  ) from public, anon, authenticated, service_role;

alter table public.notification_preferences
  add constraint notification_preferences_additional_reminder_leads_ck
  check (
    app_private.is_valid_notification_additional_reminder_leads(
      category,
      reminder_lead_minutes,
      additional_reminder_lead_minutes
    )
  );

alter table app_private.chore_notification_outbox
  add column reminder_lead_minutes integer,
  drop constraint notification_source_event_audience_key;

alter table app_private.chore_notification_outbox
  add constraint notification_source_reminder_lead_minutes_ck check (
    reminder_lead_minutes is null
    or event_type = 'calendar.occurrence_start_changed'
      and reminder_lead_minutes in (0, 5, 10, 15, 30, 60)
  ),
  add constraint notification_source_event_audience_key
    unique nulls not distinct (
      household_id,
      event_type,
      aggregate_id,
      aggregate_version,
      audience_member_id,
      causation_id,
      reminder_lead_minutes
    );

create index notification_source_calendar_reminder_lead_idx
  on app_private.chore_notification_outbox(
    household_id,
    audience_member_id,
    reminder_lead_minutes,
    aggregate_id,
    aggregate_version desc
  )
  where event_type = 'calendar.occurrence_start_changed';

create or replace function app_private.protect_chore_notification_outbox()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_is_replay boolean :=
    old.processing_status = 'dead_letter'
    and new.processing_status = 'pending'
    and new.attempts = 0
    and new.replay_count = old.replay_count + 1;
begin
  if new.event_id is distinct from old.event_id
    or new.event_type is distinct from old.event_type
    or new.event_version is distinct from old.event_version
    or new.household_id is distinct from old.household_id
    or new.actor_user_id is distinct from old.actor_user_id
    or new.actor_member_id is distinct from old.actor_member_id
    or new.acting_member_id is distinct from old.acting_member_id
    or new.aggregate_type is distinct from old.aggregate_type
    or new.aggregate_id is distinct from old.aggregate_id
    or new.aggregate_version is distinct from old.aggregate_version
    or new.audience_member_id is distinct from old.audience_member_id
    or new.correlation_id is distinct from old.correlation_id
    or new.causation_id is distinct from old.causation_id
    or new.reminder_lead_minutes is distinct from old.reminder_lead_minutes
    or new.payload is distinct from old.payload
    or new.occurred_at is distinct from old.occurred_at
    or new.max_attempts is distinct from old.max_attempts
    or new.replay_count < old.replay_count
    or new.replay_count > old.replay_count + 1
    or new.attempts > old.attempts + 1
    or new.attempts < old.attempts and not v_is_replay
    or old.processing_status = 'succeeded'
    or new.replay_count = old.replay_count + 1 and not v_is_replay
    or not (
      new.processing_status = old.processing_status
      or old.processing_status = 'pending'
        and new.processing_status = 'leased'
      or old.processing_status = 'retry_wait'
        and new.processing_status = 'leased'
      or old.processing_status = 'leased'
        and new.processing_status in (
          'leased', 'retry_wait', 'succeeded', 'dead_letter'
        )
      or v_is_replay
    ) then
    raise exception using
      errcode = '55000',
      message = 'notification source transition is invalid';
  end if;

  return new;
end;
$$;

revoke all on function app_private.protect_chore_notification_outbox()
  from public, anon, authenticated, service_role;

create or replace function
  app_private.calendar_notification_additional_lead_is_selected(
    p_household_id uuid,
    p_audience_member_id uuid,
    p_reminder_lead_minutes integer
  )
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
    from public.household_members as member
    join public.notification_preferences as preference
      on preference.auth_user_id = member.auth_user_id
     and preference.household_id = member.household_id
     and preference.category = 'calendar_event'
    where member.household_id = p_household_id
      and member.id = p_audience_member_id
      and member.removed_at is null
      and p_reminder_lead_minutes = any(
        preference.additional_reminder_lead_minutes
      )
  )
$$;

revoke all on function
  app_private.calendar_notification_additional_lead_is_selected(
    uuid,
    uuid,
    integer
  ) from public, anon, authenticated, service_role;

create or replace function app_private.calendar_notification_reminder_at(
  p_household_id uuid,
  p_occurrence_id uuid,
  p_audience_member_id uuid,
  p_source_event_id uuid
)
returns timestamptz
language sql
stable
set search_path = ''
as $$
  with base_schedule as (
    select schedule.scheduled_at
    from app_private.calendar_notification_schedule(
      p_household_id,
      p_occurrence_id
    ) as schedule
  ),
  source as (
    select
      event.event_type,
      event.reminder_lead_minutes,
      event.payload
    from app_private.chore_notification_outbox as event
    where event.event_id = p_source_event_id
      and event.household_id = p_household_id
      and event.aggregate_id = p_occurrence_id
      and event.audience_member_id = p_audience_member_id
  ),
  existing_resolution as (
    select
      resolution.scheduled_at,
      (
        exists (
          select 1
          from app_private.notification_inbox_evaluations as evaluation
          where evaluation.source_event_id = resolution.source_event_id
        )
        or exists (
          select 1
          from app_private.notification_push_evaluations as evaluation
          where evaluation.source_event_id = resolution.source_event_id
            and evaluation.processing_status <> 'pending'
        )
      ) as schedule_is_frozen
    from app_private.notification_event_resolutions as resolution
    where resolution.source_event_id = p_source_event_id
      and resolution.household_id = p_household_id
      and resolution.subject_type = 'calendar_occurrence'
      and resolution.subject_id = p_occurrence_id
  )
  select case
    when source.event_type = 'calendar.occurrence_reminder_snoozed'
      then (source.payload->>'scheduledAt')::timestamptz
    when coalesce(existing_resolution.schedule_is_frozen, false)
      then existing_resolution.scheduled_at
    else base_schedule.scheduled_at - pg_catalog.make_interval(
      mins => coalesce(
        source.reminder_lead_minutes,
        app_private.calendar_notification_lead_minutes(
          p_household_id,
          p_audience_member_id
        )
      )
    )
  end
  from base_schedule
  cross join source
  left join existing_resolution on true
$$;

revoke all on function app_private.calendar_notification_reminder_at(
  uuid,
  uuid,
  uuid,
  uuid
) from public, anon, authenticated, service_role;

create or replace function app_private.resolve_notification_event(
  p_event_id uuid
)
returns table (
  event_id uuid,
  event_type text,
  event_version integer,
  event_occurred_at timestamptz,
  household_id uuid,
  actor_member_id uuid,
  occurrence_id uuid,
  event_occurrence_version bigint,
  current_occurrence_version bigint,
  notification_category text,
  subject_type text,
  recipient_member_id uuid,
  recipient_user_id uuid,
  due_local_date date,
  due_at timestamptz,
  timezone text,
  occurrence_status text,
  is_current boolean,
  should_create_intent boolean,
  suppression_reason text
)
language sql
stable
set search_path = ''
as $$
  with source as (
    select event.*
    from app_private.chore_notification_outbox as event
    where event.event_id = p_event_id
  ),
  resolved as (
    select
      event.event_id,
      event.event_type,
      event.event_version,
      event.occurred_at,
      event.household_id,
      event.actor_member_id,
      occurrence.id as occurrence_id,
      event.aggregate_version as event_occurrence_version,
      occurrence.version as current_occurrence_version,
      case
        when event.event_type = 'chore.occurrence_due_changed'
          then 'chore_due'
        else 'chore_assignment'
      end as notification_category,
      'chore_occurrence'::text as subject_type,
      event.audience_member_id as recipient_member_id,
      occurrence.due_local_date,
      occurrence.due_at,
      occurrence.timezone,
      occurrence.status::text as occurrence_status,
      series.deleted_at is not null as series_inactive,
      event.event_type = 'chore.occurrence_due_changed'
        and occurrence.due_at is null as schedule_unresolved,
      (
        event.aggregate_version = (
          select pg_catalog.max(candidate.aggregate_version)
          from app_private.chore_notification_outbox as candidate
          where candidate.household_id = event.household_id
            and candidate.event_type = event.event_type
            and candidate.aggregate_id = event.aggregate_id
            and candidate.audience_member_id = event.audience_member_id
        )
        and occurrence.version >= event.aggregate_version
        and occurrence.assignee_member_id = event.audience_member_id
        and (
          event.event_type = 'chore.occurrence_due_changed'
          and occurrence.due_local_date =
            (event.payload->>'dueLocalDate')::date
          and occurrence.due_at is not distinct from case
            when pg_catalog.jsonb_typeof(event.payload->'dueAt') = 'null'
              then null
            else (event.payload->>'dueAt')::timestamptz
          end
          and occurrence.timezone = event.payload->>'timezone'
          and occurrence.status::text = event.payload->>'status'
          or event.event_type = 'chore.occurrence_assigned'
          and occurrence.assignee_member_id =
            (event.payload->>'assigneeMemberId')::uuid
          and occurrence.status::text = event.payload->>'status'
        )
      ) as is_current
    from source as event
    join public.chore_occurrences as occurrence
      on occurrence.household_id = event.household_id
     and occurrence.id = event.aggregate_id
    join public.chore_series as series
      on series.household_id = occurrence.household_id
     and series.id = occurrence.series_id
    where event.aggregate_type = 'chore_occurrence'

    union all

    select
      event.event_id,
      event.event_type,
      event.event_version,
      event.occurred_at,
      event.household_id,
      event.actor_member_id,
      occurrence.id as occurrence_id,
      event.aggregate_version as event_occurrence_version,
      occurrence.version as current_occurrence_version,
      'calendar_event'::text as notification_category,
      'calendar_occurrence'::text as subject_type,
      event.audience_member_id as recipient_member_id,
      occurrence.local_start_date as due_local_date,
      app_private.calendar_notification_reminder_at(
        occurrence.household_id,
        occurrence.id,
        event.audience_member_id,
        event.event_id
      ) as due_at,
      schedule.timezone,
      occurrence.status::text as occurrence_status,
      series.deleted_at is not null
        or series.ended_at is not null as series_inactive,
      schedule.scheduled_at is null as schedule_unresolved,
      (
        case
          when event.event_type =
            'calendar.occurrence_reminder_snoozed' then
            not exists (
              select 1
              from app_private.chore_notification_outbox as candidate
              where candidate.household_id = event.household_id
                and candidate.event_type = event.event_type
                and candidate.aggregate_id = event.aggregate_id
                and candidate.audience_member_id = event.audience_member_id
                and (candidate.occurred_at, candidate.event_id)
                  > (event.occurred_at, event.event_id)
            )
          else event.aggregate_version = (
            select pg_catalog.max(candidate.aggregate_version)
            from app_private.chore_notification_outbox as candidate
            where candidate.household_id = event.household_id
              and candidate.event_type = event.event_type
              and candidate.aggregate_id = event.aggregate_id
              and candidate.audience_member_id = event.audience_member_id
          )
            and (
              event.reminder_lead_minutes is null
              or app_private
                .calendar_notification_additional_lead_is_selected(
                  event.household_id,
                  event.audience_member_id,
                  event.reminder_lead_minutes
                )
            )
        end
        and occurrence.version >= event.aggregate_version
        and occurrence.local_start_date =
          (event.payload->>'localStartDate')::date
        and schedule.scheduled_at = case
          when event.event_type =
            'calendar.occurrence_reminder_snoozed'
            then (event.payload->>'occurrenceScheduledAt')::timestamptz
          else (event.payload->>'scheduledAt')::timestamptz
        end
        and schedule.timezone = event.payload->>'timezone'
        and occurrence.status::text = event.payload->>'status'
        and event.audience_member_id =
          (event.payload->>'recipientMemberId')::uuid
        and exists (
          select 1
          from app_private.calendar_notification_participants(
            occurrence.household_id,
            occurrence.series_id,
            occurrence.revision_id
          ) as participant
          where participant.member_id = event.audience_member_id
        )
      ) as is_current
    from source as event
    join public.event_occurrences as occurrence
      on occurrence.household_id = event.household_id
     and occurrence.id = event.aggregate_id
    join public.event_series as series
      on series.household_id = occurrence.household_id
     and series.id = occurrence.series_id
    left join lateral app_private.calendar_notification_schedule(
      occurrence.household_id,
      occurrence.id
    ) as schedule on true
    where event.aggregate_type = 'calendar_occurrence'
  ),
  with_recipient as (
    select
      resolved.*,
      recipient.auth_user_id as recipient_user_id,
      recipient.removed_at as recipient_removed_at
    from resolved
    left join public.household_members as recipient
      on recipient.household_id = resolved.household_id
     and recipient.id = resolved.recipient_member_id
  ),
  evaluated as (
    select
      with_recipient.*,
      case
        when not with_recipient.is_current then 'stale_event'
        when with_recipient.series_inactive then 'inactive_series'
        when with_recipient.occurrence_status <> 'scheduled'
          then 'occurrence_not_scheduled'
        when with_recipient.recipient_user_id is null
          or with_recipient.recipient_removed_at is not null
          then 'inactive_recipient'
        when with_recipient.schedule_unresolved then 'schedule_unresolved'
        else null
      end as suppression_reason
    from with_recipient
  )
  select
    evaluated.event_id,
    evaluated.event_type,
    evaluated.event_version,
    evaluated.occurred_at,
    evaluated.household_id,
    evaluated.actor_member_id,
    evaluated.occurrence_id,
    evaluated.event_occurrence_version,
    evaluated.current_occurrence_version,
    evaluated.notification_category,
    evaluated.subject_type,
    evaluated.recipient_member_id,
    evaluated.recipient_user_id,
    evaluated.due_local_date,
    evaluated.due_at,
    evaluated.timezone,
    evaluated.occurrence_status,
    evaluated.is_current,
    evaluated.suppression_reason is null,
    evaluated.suppression_reason
  from evaluated
$$;

revoke all on function app_private.resolve_notification_event(uuid)
  from public, anon, authenticated, service_role;

create or replace function app_private.insert_calendar_notification_event(
  p_household_id uuid,
  p_occurrence_id uuid,
  p_audience_member_id uuid,
  p_actor_user_id uuid,
  p_actor_member_id uuid,
  p_correlation_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_occurrence record;
  v_schedule record;
  v_additional_lead_minutes integer[] := '{}'::integer[];
  v_reminder_lead_minutes integer;
  v_inserted_count integer;
  v_total_inserted_count integer := 0;
begin
  select occurrence.*
  into v_occurrence
  from public.event_occurrences as occurrence
  where occurrence.household_id = p_household_id
    and occurrence.id = p_occurrence_id;

  if not found then
    return false;
  end if;

  select schedule.*
  into v_schedule
  from app_private.calendar_notification_schedule(
    p_household_id,
    p_occurrence_id
  ) as schedule;

  if not found or v_schedule.scheduled_at is null then
    return false;
  end if;

  select preference.additional_reminder_lead_minutes
  into v_additional_lead_minutes
  from public.household_members as member
  join public.notification_preferences as preference
    on preference.auth_user_id = member.auth_user_id
   and preference.household_id = member.household_id
   and preference.category = 'calendar_event'
  where member.household_id = p_household_id
    and member.id = p_audience_member_id
    and member.removed_at is null;

  v_additional_lead_minutes := coalesce(
    v_additional_lead_minutes,
    '{}'::integer[]
  );

  for v_reminder_lead_minutes in
    select desired.reminder_lead_minutes
    from (
      select null::integer as reminder_lead_minutes, 0 as sort_order
      union all
      select additional.lead_minutes, 1
      from pg_catalog.unnest(
        v_additional_lead_minutes
      ) as additional(lead_minutes)
    ) as desired
    order by desired.sort_order, desired.reminder_lead_minutes
  loop
    insert into app_private.chore_notification_outbox (
      event_type,
      household_id,
      actor_user_id,
      actor_member_id,
      aggregate_type,
      aggregate_id,
      aggregate_version,
      audience_member_id,
      correlation_id,
      reminder_lead_minutes,
      payload
    ) values (
      'calendar.occurrence_start_changed',
      p_household_id,
      p_actor_user_id,
      p_actor_member_id,
      'calendar_occurrence',
      p_occurrence_id,
      v_occurrence.version,
      p_audience_member_id,
      coalesce(p_correlation_id, extensions.gen_random_uuid()),
      v_reminder_lead_minutes,
      pg_catalog.jsonb_build_object(
        'recipientMemberId', p_audience_member_id,
        'localStartDate', v_occurrence.local_start_date,
        'scheduledAt', v_schedule.scheduled_at,
        'timezone', v_schedule.timezone,
        'status', v_occurrence.status::text
      )
    ) on conflict on constraint notification_source_event_audience_key
      do nothing;

    get diagnostics v_inserted_count = row_count;
    v_total_inserted_count := v_total_inserted_count + v_inserted_count;
  end loop;

  if v_total_inserted_count > 0 then
    update public.notification_inbox_items as item
    set cancelled_at = greatest(
          pg_catalog.statement_timestamp(),
          item.created_at
        ),
        cancellation_reason = case
          when v_occurrence.status = 'scheduled' then 'superseded'
          else 'state_inactive'
        end
    where item.household_id = p_household_id
      and item.recipient_member_id = p_audience_member_id
      and item.category = 'calendar_event'
      and item.subject_type = 'calendar_occurrence'
      and item.subject_id = p_occurrence_id
      and item.source_aggregate_version <= v_occurrence.version
      and item.cancelled_at is null;
  end if;

  return v_total_inserted_count > 0;
end;
$$;

revoke all on function app_private.insert_calendar_notification_event(
  uuid,
  uuid,
  uuid,
  uuid,
  uuid,
  uuid
) from public, anon, authenticated, service_role;

create or replace function
  app_private.reconcile_calendar_notification_reminders(
    p_household_id uuid,
    p_authenticated_user_id uuid,
    p_primary_lead_minutes integer,
    p_additional_lead_minutes integer[],
    p_as_of timestamptz
  )
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member_id uuid;
  v_correlation_id uuid := extensions.gen_random_uuid();
begin
  select member.id
  into v_member_id
  from public.household_members as member
  where member.household_id = p_household_id
    and member.auth_user_id = p_authenticated_user_id
    and member.removed_at is null;

  if not found then
    return;
  end if;

  -- Add only reminder instants that are still in the future. Existing
  -- evaluated history is never backfilled or duplicated by a setting change.
  with desired_leads as (
    select null::integer as reminder_lead_minutes
    union all
    select additional.lead_minutes
    from pg_catalog.unnest(
      p_additional_lead_minutes
    ) as additional(lead_minutes)
  )
  insert into app_private.chore_notification_outbox (
    event_type,
    household_id,
    actor_user_id,
    actor_member_id,
    aggregate_type,
    aggregate_id,
    aggregate_version,
    audience_member_id,
    correlation_id,
    reminder_lead_minutes,
    payload
  )
  select
    'calendar.occurrence_start_changed',
    occurrence.household_id,
    p_authenticated_user_id,
    v_member_id,
    'calendar_occurrence',
    occurrence.id,
    occurrence.version,
    v_member_id,
    v_correlation_id,
    desired.reminder_lead_minutes,
    pg_catalog.jsonb_build_object(
      'recipientMemberId', v_member_id,
      'localStartDate', occurrence.local_start_date,
      'scheduledAt', schedule.scheduled_at,
      'timezone', schedule.timezone,
      'status', occurrence.status::text
    )
  from public.event_occurrences as occurrence
  join public.event_series as series
    on series.household_id = occurrence.household_id
   and series.id = occurrence.series_id
   and series.deleted_at is null
   and series.ended_at is null
  join lateral app_private.calendar_notification_schedule(
    occurrence.household_id,
    occurrence.id
  ) as schedule on true
  cross join desired_leads as desired
  where occurrence.household_id = p_household_id
    and occurrence.status = 'scheduled'
    and schedule.scheduled_at <= p_as_of + interval '32 days'
    and schedule.scheduled_at - pg_catalog.make_interval(
      mins => coalesce(
        desired.reminder_lead_minutes,
        p_primary_lead_minutes
      )
    ) > p_as_of
    and exists (
      select 1
      from app_private.calendar_notification_participants(
        occurrence.household_id,
        occurrence.series_id,
        occurrence.revision_id
      ) as participant
      where participant.member_id = v_member_id
    )
  on conflict on constraint notification_source_event_audience_key
    do nothing;

  -- Pending resolutions follow their selected lead. Inbox history and any
  -- terminal push evaluation remain frozen by the same WP05-11 boundary.
  with eligible_resolution as (
    select
      resolution.source_event_id,
      app_private.calendar_notification_reminder_at(
        resolution.household_id,
        resolution.subject_id,
        resolution.audience_member_id,
        resolution.source_event_id
      ) as reminder_at
    from app_private.notification_event_resolutions as resolution
    join app_private.chore_notification_outbox as event
      on event.event_id = resolution.source_event_id
     and event.event_type = 'calendar.occurrence_start_changed'
    join lateral app_private.calendar_notification_schedule(
      resolution.household_id,
      resolution.subject_id
    ) as schedule on true
    where resolution.outcome = 'candidate'
      and resolution.notification_category = 'calendar_event'
      and resolution.subject_type = 'calendar_occurrence'
      and resolution.household_id = p_household_id
      and resolution.recipient_user_id = p_authenticated_user_id
      and (
        event.reminder_lead_minutes is null
        or event.reminder_lead_minutes = any(p_additional_lead_minutes)
      )
      and schedule.scheduled_at > p_as_of
      and not exists (
        select 1
        from app_private.notification_inbox_evaluations as inbox_evaluation
        where inbox_evaluation.source_event_id = resolution.source_event_id
      )
      and not exists (
        select 1
        from app_private.notification_push_evaluations as push_evaluation
        where push_evaluation.source_event_id = resolution.source_event_id
          and push_evaluation.processing_status <> 'pending'
      )
    for update of resolution
  ),
  updated_resolution as (
    update app_private.notification_event_resolutions as resolution
    set scheduled_at = eligible.reminder_at
    from eligible_resolution as eligible
    where resolution.source_event_id = eligible.source_event_id
    returning resolution.source_event_id, resolution.scheduled_at
  )
  update app_private.notification_push_evaluations as evaluation
  set next_evaluation_at = updated.scheduled_at
  from updated_resolution as updated
  where evaluation.source_event_id = updated.source_event_id
    and evaluation.processing_status = 'pending';
end;
$$;

revoke all on function
  app_private.reconcile_calendar_notification_reminders(
    uuid,
    uuid,
    integer,
    integer[],
    timestamptz
  ) from public, anon, authenticated, service_role;

create or replace function public.get_notification_preferences_v3(
  p_household_id uuid
)
returns table (
  household_id uuid,
  category text,
  native_push boolean,
  web_push boolean,
  email boolean,
  in_app boolean,
  quiet_start time without time zone,
  quiet_end time without time zone,
  timezone text,
  reminder_lead_minutes integer,
  additional_reminder_lead_minutes integer[],
  updated_at timestamptz,
  version bigint,
  is_default boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_household_timezone text;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KNP02',
      message = 'authentication required';
  end if;

  if p_household_id is null then
    raise exception using
      errcode = 'KNP01',
      message = 'invalid notification preference input';
  end if;

  select household.timezone
  into v_household_timezone
  from public.households as household
  join public.household_members as member
    on member.household_id = household.id
   and member.auth_user_id = v_authenticated_user_id
   and member.removed_at is null
  where household.id = p_household_id
    and household.deleted_at is null;

  if not found then
    raise exception using
      errcode = 'KNP03',
      message = 'notification household not found or forbidden';
  end if;

  return query
  with categories(category) as (
    values
      ('calendar_event'::text),
      ('chore_assignment'::text),
      ('chore_due'::text)
  )
  select
    p_household_id,
    categories.category,
    coalesce(preference.native_push, true),
    coalesce(preference.web_push, false),
    coalesce(preference.email, false),
    coalesce(preference.in_app, true),
    preference.quiet_start,
    preference.quiet_end,
    coalesce(preference.timezone, v_household_timezone),
    coalesce(preference.reminder_lead_minutes, 0),
    coalesce(
      preference.additional_reminder_lead_minutes,
      '{}'::integer[]
    ),
    preference.updated_at,
    coalesce(preference.version, 0),
    preference.auth_user_id is null
  from categories
  left join public.notification_preferences as preference
    on preference.auth_user_id = v_authenticated_user_id
   and preference.household_id = p_household_id
   and preference.category = categories.category
  order by categories.category;
end;
$$;

create or replace function public.update_notification_preference_v3(
  p_household_id uuid,
  p_category text,
  p_native_push boolean,
  p_web_push boolean,
  p_email boolean,
  p_in_app boolean,
  p_quiet_start time without time zone,
  p_quiet_end time without time zone,
  p_timezone text,
  p_reminder_lead_minutes integer,
  p_additional_reminder_lead_minutes integer[],
  p_expected_version bigint
)
returns table (
  household_id uuid,
  category text,
  native_push boolean,
  web_push boolean,
  email boolean,
  in_app boolean,
  quiet_start time without time zone,
  quiet_end time without time zone,
  timezone text,
  reminder_lead_minutes integer,
  additional_reminder_lead_minutes integer[],
  updated_at timestamptz,
  version bigint,
  is_default boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_existing public.notification_preferences%rowtype;
  v_result public.notification_preferences%rowtype;
  v_changed boolean := false;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KNP02',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or p_category is null
    or p_category not in (
      'chore_due', 'chore_assignment', 'calendar_event'
    )
    or p_native_push is null
    or p_web_push is null
    or p_email is null
    or p_in_app is null
    or p_timezone is null
    or not app_private.is_valid_iana_timezone(p_timezone)
    or p_reminder_lead_minutes is null
    or p_reminder_lead_minutes not in (0, 5, 10, 15, 30, 60)
    or p_category <> 'calendar_event' and p_reminder_lead_minutes <> 0
    or not app_private.is_valid_notification_additional_reminder_leads(
      p_category,
      p_reminder_lead_minutes,
      p_additional_reminder_lead_minutes
    )
    or p_expected_version is null
    or p_expected_version < 0
    or (p_quiet_start is null) <> (p_quiet_end is null)
    or p_quiet_start is not null and (
      p_quiet_start = p_quiet_end
      or extract(second from p_quiet_start) <> 0
      or extract(second from p_quiet_end) <> 0
    ) then
    raise exception using
      errcode = 'KNP01',
      message = 'invalid notification preference input';
  end if;

  perform 1
  from public.households as household
  join public.household_members as member
    on member.household_id = household.id
   and member.auth_user_id = v_authenticated_user_id
   and member.removed_at is null
  where household.id = p_household_id
    and household.deleted_at is null;

  if not found then
    raise exception using
      errcode = 'KNP03',
      message = 'notification household not found or forbidden';
  end if;

  select preference.*
  into v_existing
  from public.notification_preferences as preference
  where preference.auth_user_id = v_authenticated_user_id
    and preference.household_id = p_household_id
    and preference.category = p_category
  for update;

  if not found then
    if p_expected_version <> 0 then
      raise exception using
        errcode = 'KNP06',
        message = 'notification preference version conflict';
    end if;

    insert into public.notification_preferences (
      auth_user_id,
      household_id,
      category,
      native_push,
      web_push,
      email,
      in_app,
      quiet_start,
      quiet_end,
      timezone,
      reminder_lead_minutes,
      additional_reminder_lead_minutes
    ) values (
      v_authenticated_user_id,
      p_household_id,
      p_category,
      p_native_push,
      p_web_push,
      p_email,
      p_in_app,
      p_quiet_start,
      p_quiet_end,
      p_timezone,
      p_reminder_lead_minutes,
      p_additional_reminder_lead_minutes
    ) returning * into v_result;
    v_changed := true;
  elsif v_existing.native_push = p_native_push
    and v_existing.web_push = p_web_push
    and v_existing.email = p_email
    and v_existing.in_app = p_in_app
    and v_existing.quiet_start is not distinct from p_quiet_start
    and v_existing.quiet_end is not distinct from p_quiet_end
    and v_existing.timezone = p_timezone
    and v_existing.reminder_lead_minutes = p_reminder_lead_minutes
    and v_existing.additional_reminder_lead_minutes =
      p_additional_reminder_lead_minutes then
    v_result := v_existing;
  else
    if v_existing.version <> p_expected_version then
      raise exception using
        errcode = 'KNP06',
        message = 'notification preference version conflict';
    end if;

    update public.notification_preferences as preference
    set native_push = p_native_push,
        web_push = p_web_push,
        email = p_email,
        in_app = p_in_app,
        quiet_start = p_quiet_start,
        quiet_end = p_quiet_end,
        timezone = p_timezone,
        reminder_lead_minutes = p_reminder_lead_minutes,
        additional_reminder_lead_minutes =
          p_additional_reminder_lead_minutes
    where preference.auth_user_id = v_authenticated_user_id
      and preference.household_id = p_household_id
      and preference.category = p_category
    returning * into v_result;
    v_changed := true;
  end if;

  if v_changed and p_category = 'calendar_event' then
    perform app_private.reconcile_calendar_notification_reminders(
      p_household_id,
      v_authenticated_user_id,
      v_result.reminder_lead_minutes,
      v_result.additional_reminder_lead_minutes,
      pg_catalog.statement_timestamp()
    );
  end if;

  return query
  select
    v_result.household_id,
    v_result.category,
    v_result.native_push,
    v_result.web_push,
    v_result.email,
    v_result.in_app,
    v_result.quiet_start,
    v_result.quiet_end,
    v_result.timezone,
    v_result.reminder_lead_minutes,
    v_result.additional_reminder_lead_minutes,
    v_result.updated_at,
    v_result.version,
    false;
end;
$$;

-- v2 remains exact and can only replace the primary reminder. It preserves
-- all additional v3 reminders except a value promoted to the new primary.
create or replace function public.update_notification_preference_v2(
  p_household_id uuid,
  p_category text,
  p_native_push boolean,
  p_web_push boolean,
  p_email boolean,
  p_in_app boolean,
  p_quiet_start time without time zone,
  p_quiet_end time without time zone,
  p_timezone text,
  p_reminder_lead_minutes integer,
  p_expected_version bigint
)
returns table (
  household_id uuid,
  category text,
  native_push boolean,
  web_push boolean,
  email boolean,
  in_app boolean,
  quiet_start time without time zone,
  quiet_end time without time zone,
  timezone text,
  reminder_lead_minutes integer,
  updated_at timestamptz,
  version bigint,
  is_default boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_additional_reminder_lead_minutes integer[] := '{}'::integer[];
begin
  select preference.additional_reminder_lead_minutes
  into v_additional_reminder_lead_minutes
  from public.notification_preferences as preference
  where preference.auth_user_id = v_authenticated_user_id
    and preference.household_id = p_household_id
    and preference.category = p_category;

  v_additional_reminder_lead_minutes := pg_catalog.array_remove(
    coalesce(v_additional_reminder_lead_minutes, '{}'::integer[]),
    p_reminder_lead_minutes
  );

  return query
  select
    preference.household_id,
    preference.category,
    preference.native_push,
    preference.web_push,
    preference.email,
    preference.in_app,
    preference.quiet_start,
    preference.quiet_end,
    preference.timezone,
    preference.reminder_lead_minutes,
    preference.updated_at,
    preference.version,
    preference.is_default
  from public.update_notification_preference_v3(
    p_household_id,
    p_category,
    p_native_push,
    p_web_push,
    p_email,
    p_in_app,
    p_quiet_start,
    p_quiet_end,
    p_timezone,
    p_reminder_lead_minutes,
    v_additional_reminder_lead_minutes,
    p_expected_version
  ) as preference;
end;
$$;

revoke all on function public.get_notification_preferences_v3(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.update_notification_preference_v3(
  uuid,
  text,
  boolean,
  boolean,
  boolean,
  boolean,
  time without time zone,
  time without time zone,
  text,
  integer,
  integer[],
  bigint
) from public, anon, authenticated, service_role;
grant execute on function public.get_notification_preferences_v3(uuid)
  to authenticated;
grant execute on function public.update_notification_preference_v3(
  uuid,
  text,
  boolean,
  boolean,
  boolean,
  boolean,
  time without time zone,
  time without time zone,
  text,
  integer,
  integer[],
  bigint
) to authenticated;

-- Reassert the established v2 privilege boundary after replacement.
revoke all on function public.update_notification_preference_v2(
  uuid,
  text,
  boolean,
  boolean,
  boolean,
  boolean,
  time without time zone,
  time without time zone,
  text,
  integer,
  bigint
) from public, anon, authenticated, service_role;
grant execute on function public.update_notification_preference_v2(
  uuid,
  text,
  boolean,
  boolean,
  boolean,
  boolean,
  time without time zone,
  time without time zone,
  text,
  integer,
  bigint
) to authenticated;

comment on column
  public.notification_preferences.additional_reminder_lead_minutes is
  'WP05-13 sorted Calendar-only additional lead set; at most two values distinct from the primary lead.';
comment on column
  app_private.chore_notification_outbox.reminder_lead_minutes is
  'Internal identity for an additional content-free Calendar reminder; null denotes the N-1 primary or a non-Calendar source.';
comment on function public.get_notification_preferences_v3(uuid) is
  'Returns exact self-scoped notification preferences with the primary and up to two additional Calendar reminder leads.';
comment on function public.update_notification_preference_v3(
  uuid,
  text,
  boolean,
  boolean,
  boolean,
  boolean,
  time without time zone,
  time without time zone,
  text,
  integer,
  integer[],
  bigint
) is
  'Updates the exact v3 preference and reconciles only future or unevaluated Calendar reminders.';
comment on function public.update_notification_preference_v2(
  uuid,
  text,
  boolean,
  boolean,
  boolean,
  boolean,
  time without time zone,
  time without time zone,
  text,
  integer,
  bigint
) is
  'Preserves the exact v2 response while replacing only the primary Calendar reminder and retaining additional v3 reminders.';
