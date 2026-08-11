-- KinFlow WP05-12 Calendar notification snooze.
--
-- A snooze command supersedes the currently visible Calendar inbox item and
-- emits a new content-free source event. The existing resolution, durable
-- inbox, quiet-hours, endpoint, and reliable Android push workers therefore
-- remain the single delivery path.

alter table app_private.chore_notification_outbox
  drop constraint notification_source_event_audience_key,
  drop constraint notification_source_event_type_ck,
  drop constraint notification_source_aggregate_type_ck,
  drop constraint notification_source_payload_ck;

alter table app_private.chore_notification_outbox
  add constraint notification_source_event_type_ck check (
    event_type in (
      'chore.occurrence_due_changed',
      'chore.occurrence_assigned',
      'calendar.occurrence_start_changed',
      'calendar.occurrence_reminder_snoozed'
    )
  ),
  add constraint notification_source_aggregate_type_ck check (
    aggregate_type in ('chore_occurrence', 'calendar_occurrence')
    and (
      aggregate_type = 'chore_occurrence'
        and event_type like 'chore.%'
      or aggregate_type = 'calendar_occurrence'
        and event_type in (
          'calendar.occurrence_start_changed',
          'calendar.occurrence_reminder_snoozed'
        )
    )
  ),
  add constraint notification_source_event_audience_key
    unique nulls not distinct (
      household_id,
      event_type,
      aggregate_id,
      aggregate_version,
      audience_member_id,
      causation_id
    ),
  add constraint notification_source_payload_ck check (
    pg_catalog.jsonb_typeof(payload) = 'object'
    and (
      event_type = 'chore.occurrence_due_changed'
      and payload ?& array[
        'dueLocalDate',
        'dueAt',
        'timezone',
        'status'
      ]
      and payload - array[
        'dueLocalDate',
        'dueAt',
        'timezone',
        'status'
      ] = '{}'::jsonb
      and pg_catalog.jsonb_typeof(payload->'dueLocalDate') = 'string'
      and payload->>'dueLocalDate' ~ '^\d{4}-\d{2}-\d{2}$'
      and pg_catalog.jsonb_typeof(payload->'dueAt') in ('null', 'string')
      and pg_catalog.jsonb_typeof(payload->'timezone') = 'string'
      and app_private.is_valid_iana_timezone(payload->>'timezone')
      and pg_catalog.jsonb_typeof(payload->'status') = 'string'
      and payload->>'status' in (
        'scheduled', 'completed', 'skipped', 'cancelled'
      )
      or event_type = 'chore.occurrence_assigned'
      and payload ?& array['assigneeMemberId', 'status']
      and payload - array['assigneeMemberId', 'status'] = '{}'::jsonb
      and pg_catalog.jsonb_typeof(payload->'assigneeMemberId') = 'string'
      and payload->>'assigneeMemberId' ~
        '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      and pg_catalog.jsonb_typeof(payload->'status') = 'string'
      and payload->>'status' in (
        'scheduled', 'completed', 'skipped', 'cancelled'
      )
      or event_type = 'calendar.occurrence_start_changed'
      and payload ?& array[
        'recipientMemberId',
        'localStartDate',
        'scheduledAt',
        'timezone',
        'status'
      ]
      and payload - array[
        'recipientMemberId',
        'localStartDate',
        'scheduledAt',
        'timezone',
        'status'
      ] = '{}'::jsonb
      and pg_catalog.jsonb_typeof(payload->'recipientMemberId') = 'string'
      and payload->>'recipientMemberId' = audience_member_id::text
      and payload->>'recipientMemberId' ~
        '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      and pg_catalog.jsonb_typeof(payload->'localStartDate') = 'string'
      and payload->>'localStartDate' ~ '^\d{4}-\d{2}-\d{2}$'
      and pg_catalog.jsonb_typeof(payload->'scheduledAt') = 'string'
      and app_private.is_valid_notification_timestamp_text(
        payload->>'scheduledAt'
      )
      and pg_catalog.jsonb_typeof(payload->'timezone') = 'string'
      and app_private.is_valid_iana_timezone(payload->>'timezone')
      and pg_catalog.jsonb_typeof(payload->'status') = 'string'
      and payload->>'status' in (
        'scheduled', 'completed', 'skipped', 'cancelled'
      )
      or event_type = 'calendar.occurrence_reminder_snoozed'
      and causation_id is not null
      and payload ?& array[
        'recipientMemberId',
        'originalInboxItemId',
        'localStartDate',
        'occurrenceScheduledAt',
        'scheduledAt',
        'snoozeMinutes',
        'snoozeCount',
        'timezone',
        'status'
      ]
      and payload - array[
        'recipientMemberId',
        'originalInboxItemId',
        'localStartDate',
        'occurrenceScheduledAt',
        'scheduledAt',
        'snoozeMinutes',
        'snoozeCount',
        'timezone',
        'status'
      ] = '{}'::jsonb
      and pg_catalog.jsonb_typeof(payload->'recipientMemberId') = 'string'
      and payload->>'recipientMemberId' = audience_member_id::text
      and payload->>'recipientMemberId' ~
        '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      and pg_catalog.jsonb_typeof(payload->'originalInboxItemId') = 'string'
      and payload->>'originalInboxItemId' ~
        '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      and pg_catalog.jsonb_typeof(payload->'localStartDate') = 'string'
      and payload->>'localStartDate' ~ '^\d{4}-\d{2}-\d{2}$'
      and pg_catalog.jsonb_typeof(payload->'occurrenceScheduledAt') = 'string'
      and app_private.is_valid_notification_timestamp_text(
        payload->>'occurrenceScheduledAt'
      )
      and pg_catalog.jsonb_typeof(payload->'scheduledAt') = 'string'
      and app_private.is_valid_notification_timestamp_text(
        payload->>'scheduledAt'
      )
      and (payload->>'scheduledAt')::timestamptz > occurred_at
      and pg_catalog.jsonb_typeof(payload->'snoozeMinutes') = 'number'
      and payload->>'snoozeMinutes' in ('5', '10', '30')
      and pg_catalog.jsonb_typeof(payload->'snoozeCount') = 'number'
      and payload->>'snoozeCount' in ('1', '2', '3')
      and pg_catalog.jsonb_typeof(payload->'timezone') = 'string'
      and app_private.is_valid_iana_timezone(payload->>'timezone')
      and pg_catalog.jsonb_typeof(payload->'status') = 'string'
      and payload->>'status' = 'scheduled'
    )
  );

alter table public.notification_inbox_items
  drop constraint notification_inbox_items_cancellation_reason_check,
  add constraint notification_inbox_items_cancellation_reason_check check (
    cancellation_reason is null
    or cancellation_reason in ('superseded', 'state_inactive', 'snoozed')
  );

create table app_private.calendar_notification_snooze_commands (
  command_id uuid primary key,
  source_event_id uuid not null unique
    references app_private.chore_notification_outbox(event_id)
    on delete cascade,
  source_inbox_item_id uuid not null
    references public.notification_inbox_items(id)
    on delete cascade,
  source_item_version bigint not null check (source_item_version > 1),
  actor_user_id uuid not null
    references auth.users(id) on delete cascade,
  actor_member_id uuid not null,
  household_id uuid not null
    references public.households(id) on delete cascade,
  occurrence_id uuid not null,
  snooze_minutes integer not null check (
    snooze_minutes in (5, 10, 30)
  ),
  snooze_count integer not null check (snooze_count between 1 and 3),
  snoozed_until timestamptz not null,
  unread_count integer not null check (unread_count >= 0),
  recorded_at timestamptz not null,
  constraint calendar_notification_snooze_actor_fk
    foreign key (household_id, actor_member_id, actor_user_id)
    references public.household_members(household_id, id, auth_user_id),
  constraint calendar_notification_snooze_occurrence_fk
    foreign key (household_id, occurrence_id)
    references public.event_occurrences(household_id, id)
    on delete cascade,
  constraint calendar_notification_snooze_schedule_ck check (
    snoozed_until = recorded_at
      + pg_catalog.make_interval(mins => snooze_minutes)
  )
);

create index calendar_notification_snooze_occurrence_idx
  on app_private.calendar_notification_snooze_commands(
    actor_user_id,
    household_id,
    occurrence_id,
    recorded_at desc
  );

revoke all on table app_private.calendar_notification_snooze_commands
  from public, anon, authenticated, service_role;

create or replace function
  app_private.reject_calendar_notification_snooze_command_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'calendar notification snooze commands are immutable';
end;
$$;

revoke all on function
  app_private.reject_calendar_notification_snooze_command_mutation()
  from public, anon, authenticated, service_role;

create trigger calendar_notification_snooze_commands_immutable
before update or delete
on app_private.calendar_notification_snooze_commands
for each row execute function
  app_private.reject_calendar_notification_snooze_command_mutation();

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
    select event.event_type, event.payload
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
      mins => app_private.calendar_notification_lead_minutes(
        p_household_id,
        p_audience_member_id
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

create or replace function
  app_private.calendar_notification_snooze_max_minutes(
    p_household_id uuid,
    p_occurrence_id uuid,
    p_audience_member_id uuid,
    p_snooze_count integer,
    p_as_of timestamptz
  )
returns integer
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (
      select case
        when p_snooze_count >= 3 then 0
        when schedule.scheduled_at + interval '1 hour'
          >= p_as_of + interval '30 minutes' then 30
        when schedule.scheduled_at + interval '1 hour'
          >= p_as_of + interval '10 minutes' then 10
        when schedule.scheduled_at + interval '1 hour'
          >= p_as_of + interval '5 minutes' then 5
        else 0
      end
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
      where occurrence.household_id = p_household_id
        and occurrence.id = p_occurrence_id
        and occurrence.status = 'scheduled'
        and exists (
          select 1
          from app_private.calendar_notification_participants(
            occurrence.household_id,
            occurrence.series_id,
            occurrence.revision_id
          ) as participant
          where participant.member_id = p_audience_member_id
        )
    ),
    0
  )
$$;

revoke all on function
  app_private.calendar_notification_snooze_max_minutes(
    uuid,
    uuid,
    uuid,
    integer,
    timestamptz
  ) from public, anon, authenticated, service_role;

create or replace function public.list_notification_inbox_items_v2(
  p_household_id uuid,
  p_limit integer default 30,
  p_before_created_at timestamptz default null,
  p_before_id uuid default null
)
returns table (
  inbox_item_id uuid,
  item_version bigint,
  source_event_id uuid,
  household_id uuid,
  category text,
  subject_type text,
  subject_id uuid,
  scheduled_at timestamptz,
  created_at timestamptz,
  read_at timestamptz,
  payload jsonb,
  snooze_count integer,
  snooze_max_minutes integer,
  has_more boolean,
  next_before_created_at timestamptz,
  next_before_id uuid
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
      errcode = 'KNP02',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or p_limit is null
    or p_limit not between 1 and 100
    or (p_before_created_at is null) <> (p_before_id is null) then
    raise exception using
      errcode = 'KNP01',
      message = 'invalid notification inbox query';
  end if;

  if not app_private.is_active_household_member(p_household_id) then
    raise exception using
      errcode = 'KNP03',
      message = 'notification household not found or forbidden';
  end if;

  return query
  with fetched as (
    select
      item.*,
      case
        when source.event_type =
          'calendar.occurrence_reminder_snoozed'
          then (source.payload->>'snoozeCount')::integer
        else 0
      end as source_snooze_count
    from public.notification_inbox_items as item
    join app_private.chore_notification_outbox as source
      on source.event_id = item.source_event_id
    where item.household_id = p_household_id
      and item.recipient_user_id = v_authenticated_user_id
      and item.cancelled_at is null
      and (
        p_before_created_at is null
        or (item.created_at, item.id) < (p_before_created_at, p_before_id)
      )
    order by item.created_at desc, item.id desc
    limit p_limit + 1
  ), page as (
    select fetched.*
    from fetched
    order by fetched.created_at desc, fetched.id desc
    limit p_limit
  ), metadata as (
    select count(*) > p_limit as has_more
    from fetched
  )
  select
    page.id,
    page.item_version,
    page.source_event_id,
    page.household_id,
    page.category,
    page.subject_type,
    page.subject_id,
    page.scheduled_at,
    page.created_at,
    page.read_at,
    page.payload,
    page.source_snooze_count,
    case
      when page.category = 'calendar_event'
        then app_private.calendar_notification_snooze_max_minutes(
          page.household_id,
          page.subject_id,
          page.recipient_member_id,
          page.source_snooze_count,
          pg_catalog.statement_timestamp()
        )
      else 0
    end,
    metadata.has_more,
    case when metadata.has_more then last_value.created_at else null end,
    case when metadata.has_more then last_value.id else null end
  from page
  cross join metadata
  cross join lateral (
    select tail.created_at, tail.id
    from page as tail
    order by tail.created_at, tail.id
    limit 1
  ) as last_value
  order by page.created_at desc, page.id desc;
end;
$$;

revoke all on function public.list_notification_inbox_items_v2(
  uuid,
  integer,
  timestamptz,
  uuid
) from public, anon, authenticated, service_role;
grant execute on function public.list_notification_inbox_items_v2(
  uuid,
  integer,
  timestamptz,
  uuid
) to authenticated;

create or replace function public.snooze_calendar_notification(
  p_household_id uuid,
  p_inbox_item_id uuid,
  p_snooze_minutes integer,
  p_command_id uuid,
  p_expected_item_version bigint
)
returns table (
  command_id uuid,
  source_event_id uuid,
  inbox_item_id uuid,
  item_version bigint,
  snoozed_until timestamptz,
  snooze_minutes integer,
  snooze_count integer,
  unread_count integer,
  recorded_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_recorded_at timestamptz := pg_catalog.statement_timestamp();
  v_existing app_private.calendar_notification_snooze_commands%rowtype;
  v_item public.notification_inbox_items%rowtype;
  v_source app_private.chore_notification_outbox%rowtype;
  v_occurrence record;
  v_source_event_id uuid;
  v_source_item_version bigint;
  v_snooze_count integer;
  v_snoozed_until timestamptz;
  v_unread_count integer;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KNP02',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or p_inbox_item_id is null
    or p_snooze_minutes is null
    or p_snooze_minutes not in (5, 10, 30)
    or p_command_id is null
    or p_expected_item_version is null
    or p_expected_item_version < 1 then
    raise exception using
      errcode = 'KNP01',
      message = 'invalid notification snooze command';
  end if;

  if not app_private.is_active_household_member(p_household_id) then
    raise exception using
      errcode = 'KNP03',
      message = 'notification household not found or forbidden';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_command_id::text, 0)
  );

  select command.*
  into v_existing
  from app_private.calendar_notification_snooze_commands as command
  where command.command_id = p_command_id;

  if found then
    if v_existing.actor_user_id <> v_authenticated_user_id
      or v_existing.household_id <> p_household_id
      or v_existing.source_inbox_item_id <> p_inbox_item_id
      or v_existing.snooze_minutes <> p_snooze_minutes then
      raise exception using
        errcode = 'KNP06',
        message = 'notification snooze command conflict';
    end if;

    return query select
      v_existing.command_id,
      v_existing.source_event_id,
      v_existing.source_inbox_item_id,
      v_existing.source_item_version,
      v_existing.snoozed_until,
      v_existing.snooze_minutes,
      v_existing.snooze_count,
      v_existing.unread_count,
      v_existing.recorded_at;
    return;
  end if;

  select item.*
  into v_item
  from public.notification_inbox_items as item
  where item.id = p_inbox_item_id
    and item.household_id = p_household_id
    and item.recipient_user_id = v_authenticated_user_id
  for update;

  if not found
    or v_item.cancelled_at is not null
    or v_item.category <> 'calendar_event'
    or v_item.subject_type <> 'calendar_occurrence' then
    raise exception using
      errcode = 'KNS04',
      message = 'calendar notification snooze unavailable';
  end if;

  if v_item.item_version <> p_expected_item_version then
    raise exception using
      errcode = 'KNP06',
      message = 'notification item version conflict';
  end if;

  select source.*
  into v_source
  from app_private.chore_notification_outbox as source
  where source.event_id = v_item.source_event_id;

  if not found then
    raise exception using
      errcode = 'KNS04',
      message = 'calendar notification snooze unavailable';
  end if;

  v_snooze_count := case
    when v_source.event_type = 'calendar.occurrence_reminder_snoozed'
      then (v_source.payload->>'snoozeCount')::integer + 1
    else 1
  end;

  select
    occurrence.id,
    occurrence.version,
    occurrence.local_start_date,
    occurrence.status,
    schedule.scheduled_at,
    schedule.timezone
  into v_occurrence
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
  where occurrence.household_id = p_household_id
    and occurrence.id = v_item.subject_id
    and occurrence.status = 'scheduled'
    and exists (
      select 1
      from app_private.calendar_notification_participants(
        occurrence.household_id,
        occurrence.series_id,
        occurrence.revision_id
      ) as participant
      where participant.member_id = v_item.recipient_member_id
    );

  v_snoozed_until := v_recorded_at
    + pg_catalog.make_interval(mins => p_snooze_minutes);

  if not found
    or v_snooze_count > 3
    or v_snoozed_until > v_occurrence.scheduled_at + interval '1 hour' then
    raise exception using
      errcode = 'KNS04',
      message = 'calendar notification snooze unavailable';
  end if;

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
    causation_id,
    payload,
    occurred_at
  ) values (
    'calendar.occurrence_reminder_snoozed',
    p_household_id,
    v_authenticated_user_id,
    v_item.recipient_member_id,
    'calendar_occurrence',
    v_item.subject_id,
    v_occurrence.version,
    v_item.recipient_member_id,
    p_command_id,
    p_command_id,
    pg_catalog.jsonb_build_object(
      'recipientMemberId', v_item.recipient_member_id,
      'originalInboxItemId', v_item.id,
      'localStartDate', v_occurrence.local_start_date,
      'occurrenceScheduledAt', v_occurrence.scheduled_at,
      'scheduledAt', v_snoozed_until,
      'snoozeMinutes', p_snooze_minutes,
      'snoozeCount', v_snooze_count,
      'timezone', v_occurrence.timezone,
      'status', v_occurrence.status::text
    ),
    v_recorded_at
  ) returning event_id into v_source_event_id;

  insert into app_private.notification_push_evaluations (
    source_event_id,
    processing_status,
    next_evaluation_at,
    reason_code,
    created_at,
    evaluated_at
  )
  select
    v_item.source_event_id,
    'stale',
    null,
    'LATEST_STATE_SUPPRESSED',
    v_recorded_at,
    v_recorded_at
  from app_private.notification_event_resolutions as resolution
  where resolution.source_event_id = v_item.source_event_id
  on conflict on constraint notification_push_evaluations_pkey do update
  set processing_status = 'stale',
      next_evaluation_at = null,
      reason_code = 'LATEST_STATE_SUPPRESSED',
      evaluated_at = v_recorded_at
  where notification_push_evaluations.processing_status = 'pending';

  perform app_private.cancel_notification_push_delivery(
    delivery.id,
    'LATEST_STATE_SUPPRESSED',
    v_recorded_at
  )
  from app_private.notification_push_deliveries as delivery
  where delivery.source_event_id = v_item.source_event_id
    and delivery.processing_status in ('pending', 'retry_wait', 'leased');

  update public.notification_inbox_items as item
  set read_at = coalesce(item.read_at, v_recorded_at),
      cancelled_at = v_recorded_at,
      cancellation_reason = 'snoozed'
  where item.id = v_item.id
  returning item.item_version into v_source_item_version;

  select count(*)::integer
  into v_unread_count
  from public.notification_inbox_items as item
  where item.household_id = p_household_id
    and item.recipient_user_id = v_authenticated_user_id
    and item.read_at is null
    and item.cancelled_at is null;

  insert into app_private.calendar_notification_snooze_commands (
    command_id,
    source_event_id,
    source_inbox_item_id,
    source_item_version,
    actor_user_id,
    actor_member_id,
    household_id,
    occurrence_id,
    snooze_minutes,
    snooze_count,
    snoozed_until,
    unread_count,
    recorded_at
  ) values (
    p_command_id,
    v_source_event_id,
    v_item.id,
    v_source_item_version,
    v_authenticated_user_id,
    v_item.recipient_member_id,
    p_household_id,
    v_item.subject_id,
    p_snooze_minutes,
    v_snooze_count,
    v_snoozed_until,
    v_unread_count,
    v_recorded_at
  );

  return query select
    p_command_id,
    v_source_event_id,
    v_item.id,
    v_source_item_version,
    v_snoozed_until,
    p_snooze_minutes,
    v_snooze_count,
    v_unread_count,
    v_recorded_at;
end;
$$;

revoke all on function public.snooze_calendar_notification(
  uuid,
  uuid,
  integer,
  uuid,
  bigint
) from public, anon, authenticated, service_role;
grant execute on function public.snooze_calendar_notification(
  uuid,
  uuid,
  integer,
  uuid,
  bigint
) to authenticated;

comment on function public.list_notification_inbox_items_v2(
  uuid,
  integer,
  timestamptz,
  uuid
) is
  'Lists the caller durable inbox with bounded Calendar snooze metadata.';

comment on function public.snooze_calendar_notification(
  uuid,
  uuid,
  integer,
  uuid,
  bigint
) is
  'Atomically supersedes one Calendar inbox item and schedules a content-free reminder replay.';
