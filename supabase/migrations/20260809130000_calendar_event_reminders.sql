-- KinFlow WP05-07 Calendar occurrence start reminders.
-- The legacy Chore-named queue and worker RPCs remain the compatibility
-- surface while their strict envelopes are generalized to Calendar events.

create or replace function app_private.is_valid_notification_timestamp_text(
  p_value text
)
returns boolean
language plpgsql
stable
strict
set search_path = ''
as $$
begin
  if p_value !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$' then
    return false;
  end if;
  perform p_value::timestamptz;
  return true;
exception
  when invalid_datetime_format
    or datetime_field_overflow
    or invalid_text_representation then
    return false;
end;
$$;

revoke all on function
  app_private.is_valid_notification_timestamp_text(text)
  from public, anon, authenticated, service_role;

alter table app_private.chore_notification_outbox
  add column audience_member_id uuid;

update app_private.chore_notification_outbox as event
set audience_member_id = case
  when event.event_type = 'chore.occurrence_assigned'
    then (event.payload->>'assigneeMemberId')::uuid
  else occurrence.assignee_member_id
end
from public.chore_occurrences as occurrence
where occurrence.household_id = event.household_id
  and occurrence.id = event.aggregate_id;

alter table app_private.chore_notification_outbox
  alter column audience_member_id set not null,
  drop constraint chore_notification_outbox_household_id_event_type_aggregate_key,
  drop constraint chore_notification_outbox_occurrence_fk,
  drop constraint chore_notification_outbox_event_type_ck,
  drop constraint chore_notification_outbox_aggregate_type_ck,
  drop constraint chore_notification_outbox_payload_ck,
  add constraint notification_source_event_type_ck check (
    event_type in (
      'chore.occurrence_due_changed',
      'chore.occurrence_assigned',
      'calendar.occurrence_start_changed'
    )
  ),
  add constraint notification_source_aggregate_type_ck check (
    aggregate_type in ('chore_occurrence', 'calendar_occurrence')
    and (
      aggregate_type = 'chore_occurrence'
        and event_type like 'chore.%'
      or aggregate_type = 'calendar_occurrence'
        and event_type = 'calendar.occurrence_start_changed'
    )
  ),
  add constraint notification_source_audience_fk
    foreign key (household_id, audience_member_id)
    references public.household_members(household_id, id),
  add constraint notification_source_event_audience_key unique (
    household_id,
    event_type,
    aggregate_id,
    aggregate_version,
    audience_member_id
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
    )
  );

create index notification_source_calendar_horizon_idx
  on app_private.chore_notification_outbox(
    aggregate_type,
    household_id,
    aggregate_id,
    audience_member_id,
    aggregate_version desc
  )
  where aggregate_type = 'calendar_occurrence';

alter table app_private.notification_event_resolutions
  add column audience_member_id uuid;

update app_private.notification_event_resolutions as resolution
set audience_member_id = event.audience_member_id
from app_private.chore_notification_outbox as event
where event.event_id = resolution.source_event_id;

alter table app_private.notification_event_resolutions
  alter column audience_member_id set not null,
  drop constraint notification_event_resolution_subject_fk,
  drop constraint notification_event_resolutions_notification_category_check,
  drop constraint notification_event_resolutions_subject_type_check,
  add constraint notification_event_resolution_audience_fk
    foreign key (household_id, audience_member_id)
    references public.household_members(household_id, id),
  add constraint notification_event_resolution_category_ck check (
    notification_category in (
      'chore_due', 'chore_assignment', 'calendar_event'
    )
  ),
  add constraint notification_event_resolution_subject_type_ck check (
    notification_category in ('chore_due', 'chore_assignment')
      and subject_type = 'chore_occurrence'
    or notification_category = 'calendar_event'
      and subject_type = 'calendar_occurrence'
  );

alter table public.notification_preferences
  drop constraint notification_preferences_category_check,
  add constraint notification_preferences_category_ck check (
    category in ('chore_due', 'chore_assignment', 'calendar_event')
  );

alter table public.notification_inbox_items
  drop constraint notification_inbox_subject_fk,
  drop constraint notification_inbox_items_category_check,
  drop constraint notification_inbox_items_subject_type_check,
  add constraint notification_inbox_category_ck check (
    category in ('chore_due', 'chore_assignment', 'calendar_event')
  ),
  add constraint notification_inbox_subject_type_ck check (
    category in ('chore_due', 'chore_assignment')
      and subject_type = 'chore_occurrence'
    or category = 'calendar_event'
      and subject_type = 'calendar_occurrence'
  );

alter table app_private.notification_push_deliveries
  drop constraint notification_push_delivery_subject_fk,
  drop constraint notification_push_deliveries_category_check,
  drop constraint notification_push_deliveries_subject_type_check,
  add constraint notification_push_delivery_category_ck check (
    category in ('chore_due', 'chore_assignment', 'calendar_event')
  ),
  add constraint notification_push_delivery_subject_type_ck check (
    category in ('chore_due', 'chore_assignment')
      and subject_type = 'chore_occurrence'
    or category = 'calendar_event'
      and subject_type = 'calendar_occurrence'
  );

create or replace function app_private.validate_notification_source_subject()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.aggregate_type = 'chore_occurrence' then
    perform 1
    from public.chore_occurrences as occurrence
    where occurrence.household_id = new.household_id
      and occurrence.id = new.aggregate_id;
  elsif new.aggregate_type = 'calendar_occurrence' then
    perform 1
    from public.event_occurrences as occurrence
    where occurrence.household_id = new.household_id
      and occurrence.id = new.aggregate_id;
  else
    raise foreign_key_violation using
      message = 'notification source subject type is invalid';
  end if;

  if not found then
    raise foreign_key_violation using
      message = 'notification source subject is unavailable';
  end if;
  return new;
end;
$$;

revoke all on function app_private.validate_notification_source_subject()
  from public, anon, authenticated, service_role;

create trigger notification_source_validate_subject
before insert or update of household_id, aggregate_type, aggregate_id
on app_private.chore_notification_outbox
for each row execute function
  app_private.validate_notification_source_subject();

create or replace function app_private.validate_notification_subject()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.subject_type = 'chore_occurrence' then
    perform 1
    from public.chore_occurrences as occurrence
    where occurrence.household_id = new.household_id
      and occurrence.id = new.subject_id;
  elsif new.subject_type = 'calendar_occurrence' then
    perform 1
    from public.event_occurrences as occurrence
    where occurrence.household_id = new.household_id
      and occurrence.id = new.subject_id;
  else
    raise foreign_key_violation using
      message = 'notification subject type is invalid';
  end if;

  if not found then
    raise foreign_key_violation using
      message = 'notification subject is unavailable';
  end if;
  return new;
end;
$$;

revoke all on function app_private.validate_notification_subject()
  from public, anon, authenticated, service_role;

create trigger notification_resolution_validate_subject
before insert or update of household_id, subject_type, subject_id
on app_private.notification_event_resolutions
for each row execute function app_private.validate_notification_subject();

create trigger notification_inbox_validate_subject
before insert or update of household_id, subject_type, subject_id
on public.notification_inbox_items
for each row execute function app_private.validate_notification_subject();

create trigger notification_push_delivery_validate_subject
before insert or update of household_id, subject_type, subject_id
on app_private.notification_push_deliveries
for each row execute function app_private.validate_notification_subject();

create or replace function app_private.protect_notification_inbox_item()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id is distinct from old.id
    or new.source_event_id is distinct from old.source_event_id
    or new.source_aggregate_version is distinct from old.source_aggregate_version
    or new.recipient_user_id is distinct from old.recipient_user_id
    or new.recipient_member_id is distinct from old.recipient_member_id
    or new.household_id is distinct from old.household_id
    or new.category is distinct from old.category
    or new.subject_type is distinct from old.subject_type
    or new.subject_id is distinct from old.subject_id
    or new.scheduled_at is distinct from old.scheduled_at
    or new.created_at is distinct from old.created_at
    or new.payload is distinct from old.payload
    or old.read_at is not null and new.read_at is distinct from old.read_at
    or old.cancelled_at is not null
      and new.cancelled_at is distinct from old.cancelled_at
    or old.cancellation_reason is not null
      and new.cancellation_reason is distinct from old.cancellation_reason
    or old.cancelled_at is null and new.cancelled_at is null
      and new.cancellation_reason is not null then
    raise exception using
      errcode = '55000',
      message = 'notification inbox envelope or transition is invalid';
  end if;

  new.item_version := old.item_version + 1;
  new.updated_at := greatest(
    pg_catalog.statement_timestamp(),
    old.updated_at,
    coalesce(new.read_at, '-infinity'::timestamptz),
    coalesce(new.cancelled_at, '-infinity'::timestamptz)
  );
  return new;
end;
$$;

revoke all on function app_private.protect_notification_inbox_item()
  from public, anon, authenticated, service_role;

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

create or replace function app_private.capture_chore_notification_events()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_user_id uuid := (select auth.uid());
  v_actor_member_id uuid;
  v_correlation_id uuid := extensions.gen_random_uuid();
begin
  if v_actor_user_id is not null then
    select member.id
    into v_actor_member_id
    from public.household_members as member
    where member.household_id = new.household_id
      and member.auth_user_id = v_actor_user_id
      and member.removed_at is null
    limit 1;

    if v_actor_member_id is null then
      v_actor_user_id := null;
    end if;
  end if;

  if tg_op = 'INSERT'
    or new.due_local_date is distinct from old.due_local_date
    or new.due_at is distinct from old.due_at
    or new.timezone is distinct from old.timezone
    or new.status is distinct from old.status
    or new.assignee_member_id is distinct from old.assignee_member_id then
    insert into app_private.chore_notification_outbox (
      event_type,
      household_id,
      actor_user_id,
      actor_member_id,
      aggregate_id,
      aggregate_version,
      audience_member_id,
      correlation_id,
      payload
    ) values (
      'chore.occurrence_due_changed',
      new.household_id,
      v_actor_user_id,
      v_actor_member_id,
      new.id,
      new.version,
      new.assignee_member_id,
      v_correlation_id,
      pg_catalog.jsonb_build_object(
        'dueLocalDate', new.due_local_date,
        'dueAt', new.due_at,
        'timezone', new.timezone,
        'status', new.status::text
      )
    ) on conflict on constraint notification_source_event_audience_key
      do nothing;
  end if;

  if tg_op = 'INSERT'
    or new.assignee_member_id is distinct from old.assignee_member_id then
    insert into app_private.chore_notification_outbox (
      event_type,
      household_id,
      actor_user_id,
      actor_member_id,
      aggregate_id,
      aggregate_version,
      audience_member_id,
      correlation_id,
      payload
    ) values (
      'chore.occurrence_assigned',
      new.household_id,
      v_actor_user_id,
      v_actor_member_id,
      new.id,
      new.version,
      new.assignee_member_id,
      v_correlation_id,
      pg_catalog.jsonb_build_object(
        'assigneeMemberId', new.assignee_member_id,
        'status', new.status::text
      )
    ) on conflict on constraint notification_source_event_audience_key
      do nothing;
  end if;

  return new;
end;
$$;

revoke all on function app_private.capture_chore_notification_events()
  from public, anon, authenticated, service_role;

create or replace function app_private.calendar_notification_participants(
  p_household_id uuid,
  p_series_id uuid,
  p_revision_id uuid
)
returns table (member_id uuid)
language sql
stable
set search_path = ''
as $$
  with revision_participants as (
    select participant.member_id
    from public.event_revision_participants as participant
    where participant.household_id = p_household_id
      and participant.series_id = p_series_id
      and participant.revision_id = p_revision_id
  )
  select participant.member_id
  from revision_participants as participant
  union all
  select participant.member_id
  from public.event_participants as participant
  where participant.household_id = p_household_id
    and participant.series_id = p_series_id
    and not exists (select 1 from revision_participants)
$$;

revoke all on function app_private.calendar_notification_participants(
  uuid,
  uuid,
  uuid
) from public, anon, authenticated, service_role;

create or replace function app_private.calendar_notification_schedule(
  p_household_id uuid,
  p_occurrence_id uuid
)
returns table (scheduled_at timestamptz, timezone text)
language sql
stable
set search_path = ''
as $$
  select
    coalesce(
      occurrence.starts_at,
      pg_catalog.timezone(
        household.timezone,
        occurrence.local_start_date + time '09:00'
      )
    ),
    coalesce(occurrence.timezone, household.timezone)
  from public.event_occurrences as occurrence
  join public.households as household
    on household.id = occurrence.household_id
  where occurrence.household_id = p_household_id
    and occurrence.id = p_occurrence_id
$$;

revoke all on function app_private.calendar_notification_schedule(uuid, uuid)
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
  v_inserted_count integer;
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
  if v_inserted_count > 0 then
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
  return v_inserted_count > 0;
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

create or replace function app_private.capture_calendar_notification_events()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_user_id uuid := (select auth.uid());
  v_actor_member_id uuid;
  v_correlation_id uuid := extensions.gen_random_uuid();
  v_member_id uuid;
  v_schedule record;
begin
  if tg_op = 'UPDATE'
    and new.revision_id is not distinct from old.revision_id
    and new.local_start_date is not distinct from old.local_start_date
    and new.starts_at is not distinct from old.starts_at
    and new.timezone is not distinct from old.timezone
    and new.status is not distinct from old.status then
    return new;
  end if;

  if tg_op = 'INSERT' then
    select schedule.*
    into v_schedule
    from app_private.calendar_notification_schedule(
      new.household_id,
      new.id
    ) as schedule;
    if not found
      or v_schedule.scheduled_at
        > pg_catalog.statement_timestamp() + interval '32 days' then
      return new;
    end if;
  end if;

  if v_actor_user_id is not null then
    select member.id
    into v_actor_member_id
    from public.household_members as member
    where member.household_id = new.household_id
      and member.auth_user_id = v_actor_user_id
      and member.removed_at is null
    limit 1;
    if v_actor_member_id is null then
      v_actor_user_id := null;
    end if;
  end if;

  for v_member_id in
    select participant.member_id
    from app_private.calendar_notification_participants(
      new.household_id,
      new.series_id,
      new.revision_id
    ) as participant
    union
    select participant.member_id
    from app_private.calendar_notification_participants(
      new.household_id,
      new.series_id,
      case when tg_op = 'UPDATE' then old.revision_id else new.revision_id end
    ) as participant
  loop
    perform app_private.insert_calendar_notification_event(
      new.household_id,
      new.id,
      v_member_id,
      v_actor_user_id,
      v_actor_member_id,
      v_correlation_id
    );
  end loop;

  return new;
end;
$$;

revoke all on function app_private.capture_calendar_notification_events()
  from public, anon, authenticated, service_role;

create trigger event_occurrences_capture_notification_events
after insert or update on public.event_occurrences
for each row execute function
  app_private.capture_calendar_notification_events();

create or replace function
  app_private.delete_notification_sources_for_occurrence()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_aggregate_type text := tg_argv[0];
begin
  if v_aggregate_type not in ('chore_occurrence', 'calendar_occurrence') then
    raise exception using
      errcode = '22023',
      message = 'notification source aggregate type is invalid';
  end if;

  delete from app_private.chore_notification_outbox as event
  where event.household_id = old.household_id
    and event.aggregate_type = v_aggregate_type
    and event.aggregate_id = old.id;

  return old;
end;
$$;

revoke all on function
  app_private.delete_notification_sources_for_occurrence()
  from public, anon, authenticated, service_role;

create trigger chore_occurrences_delete_notification_sources
after delete on public.chore_occurrences
for each row execute function
  app_private.delete_notification_sources_for_occurrence('chore_occurrence');

create trigger event_occurrences_delete_notification_sources
after delete on public.event_occurrences
for each row execute function
  app_private.delete_notification_sources_for_occurrence('calendar_occurrence');

create or replace function
  app_private.capture_one_time_calendar_participant_notifications()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_household_id uuid;
  v_series_id uuid;
  v_participant_member_id uuid;
  v_occurrence record;
  v_schedule record;
  v_actor_user_id uuid := (select auth.uid());
  v_actor_member_id uuid;
begin
  if tg_op = 'DELETE' then
    v_household_id := old.household_id;
    v_series_id := old.series_id;
    v_participant_member_id := old.member_id;
  else
    v_household_id := new.household_id;
    v_series_id := new.series_id;
    v_participant_member_id := new.member_id;
  end if;

  if v_actor_user_id is not null then
    select member.id
    into v_actor_member_id
    from public.household_members as member
    where member.household_id = v_household_id
      and member.auth_user_id = v_actor_user_id
      and member.removed_at is null
    limit 1;
    if v_actor_member_id is null then
      v_actor_user_id := null;
    end if;
  end if;

  for v_occurrence in
    select occurrence.*
    from public.event_occurrences as occurrence
    join public.event_series_revisions as revision
      on revision.household_id = occurrence.household_id
     and revision.series_id = occurrence.series_id
     and revision.id = occurrence.revision_id
     and revision.recurrence_rule is null
    where occurrence.household_id = v_household_id
      and occurrence.series_id = v_series_id
  loop
    select schedule.*
    into v_schedule
    from app_private.calendar_notification_schedule(
      v_occurrence.household_id,
      v_occurrence.id
    ) as schedule;

    if tg_op = 'DELETE'
      or v_schedule.scheduled_at
        <= pg_catalog.statement_timestamp() + interval '32 days' then
      perform app_private.insert_calendar_notification_event(
        v_occurrence.household_id,
        v_occurrence.id,
        v_participant_member_id,
        v_actor_user_id,
        v_actor_member_id,
        extensions.gen_random_uuid()
      );
    end if;
  end loop;

  return null;
end;
$$;

revoke all on function
  app_private.capture_one_time_calendar_participant_notifications()
  from public, anon, authenticated, service_role;

create trigger event_participants_capture_notification_events
after insert or delete on public.event_participants
for each row execute function
  app_private.capture_one_time_calendar_participant_notifications();

create or replace function public.enqueue_calendar_event_reminder_events(
  p_as_of timestamptz,
  p_through timestamptz
)
returns table (
  captured_at timestamptz,
  candidate_count integer,
  enqueued_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_candidate record;
  v_candidate_count integer := 0;
  v_enqueued_count integer := 0;
begin
  if p_as_of is null
    or p_through is null
    or p_through < p_as_of
    or p_through > p_as_of + interval '32 days' then
    raise exception using
      errcode = 'KFN01',
      message = 'invalid calendar reminder horizon input';
  end if;

  for v_candidate in
    select
      occurrence.household_id,
      occurrence.id as occurrence_id,
      participant.member_id
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
    join lateral app_private.calendar_notification_participants(
      occurrence.household_id,
      occurrence.series_id,
      occurrence.revision_id
    ) as participant on true
    where occurrence.status = 'scheduled'
      and schedule.scheduled_at > p_as_of - interval '1 hour'
      and schedule.scheduled_at <= p_through
    order by schedule.scheduled_at, occurrence.id, participant.member_id
  loop
    v_candidate_count := v_candidate_count + 1;
    if app_private.insert_calendar_notification_event(
      v_candidate.household_id,
      v_candidate.occurrence_id,
      v_candidate.member_id,
      null,
      null,
      extensions.gen_random_uuid()
    ) then
      v_enqueued_count := v_enqueued_count + 1;
    end if;
  end loop;

  return query select p_as_of, v_candidate_count, v_enqueued_count;
end;
$$;

revoke all on function public.enqueue_calendar_event_reminder_events(
  timestamptz,
  timestamptz
) from public, anon, authenticated, service_role;
grant execute on function public.enqueue_calendar_event_reminder_events(
  timestamptz,
  timestamptz
) to service_role;

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
      schedule.scheduled_at as due_at,
      schedule.timezone,
      occurrence.status::text as occurrence_status,
      series.deleted_at is not null
        or series.ended_at is not null as series_inactive,
      schedule.scheduled_at is null as schedule_unresolved,
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
        and occurrence.local_start_date =
          (event.payload->>'localStartDate')::date
        and schedule.scheduled_at =
          (event.payload->>'scheduledAt')::timestamptz
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

create or replace function app_private.resolve_chore_notification_event(
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
  select resolved.*
  from app_private.resolve_notification_event(p_event_id) as resolved
$$;

revoke all on function app_private.resolve_chore_notification_event(uuid)
  from public, anon, authenticated, service_role;

create or replace function public.process_chore_notification_event(
  p_event_id uuid,
  p_lease_token uuid,
  p_as_of timestamptz
)
returns table (
  source_event_id uuid,
  outcome text,
  notification_category text,
  subject_type text,
  subject_id uuid,
  recipient_member_id uuid,
  recipient_user_id uuid,
  scheduled_at timestamptz,
  timezone text,
  suppression_reason text,
  resolved_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event app_private.chore_notification_outbox%rowtype;
  v_resolution record;
begin
  if p_event_id is null or p_lease_token is null or p_as_of is null then
    raise exception using
      errcode = 'KFN01',
      message = 'invalid notification worker input';
  end if;

  select event.*
  into v_event
  from app_private.chore_notification_outbox as event
  where event.event_id = p_event_id
  for update;

  if not found then
    raise exception using
      errcode = 'KFN04',
      message = 'notification event unavailable';
  end if;

  if v_event.processing_status = 'succeeded' then
    return query
    select
      resolution.source_event_id,
      resolution.outcome,
      resolution.notification_category,
      resolution.subject_type,
      resolution.subject_id,
      resolution.recipient_member_id,
      resolution.recipient_user_id,
      resolution.scheduled_at,
      resolution.timezone,
      resolution.suppression_reason,
      resolution.resolved_at
    from app_private.notification_event_resolutions as resolution
    where resolution.source_event_id = p_event_id;

    if not found then
      raise exception using
        errcode = 'KFN04',
        message = 'notification event resolution unavailable';
    end if;
    return;
  end if;

  if v_event.processing_status <> 'leased'
    or v_event.lease_token <> p_lease_token
    or v_event.lease_expires_at <= p_as_of then
    raise exception using
      errcode = 'KFN03',
      message = 'notification lease not found or expired';
  end if;

  select resolved.*
  into v_resolution
  from app_private.resolve_notification_event(p_event_id) as resolved;

  if not found then
    raise exception using
      errcode = 'KFN04',
      message = 'notification event resolution unavailable';
  end if;

  insert into app_private.notification_event_resolutions (
    source_event_id,
    outcome,
    household_id,
    notification_category,
    subject_type,
    subject_id,
    audience_member_id,
    recipient_member_id,
    recipient_user_id,
    scheduled_at,
    timezone,
    suppression_reason,
    resolved_at
  ) values (
    p_event_id,
    case
      when v_resolution.should_create_intent then 'candidate'
      else 'suppressed'
    end,
    v_resolution.household_id,
    v_resolution.notification_category,
    v_resolution.subject_type,
    v_resolution.occurrence_id,
    v_resolution.recipient_member_id,
    case
      when v_resolution.should_create_intent
        then v_resolution.recipient_member_id
      else null
    end,
    case
      when v_resolution.should_create_intent
        then v_resolution.recipient_user_id
      else null
    end,
    case
      when not v_resolution.should_create_intent then null
      when v_resolution.notification_category = 'chore_assignment'
        then v_resolution.event_occurred_at
      else v_resolution.due_at
    end,
    v_resolution.timezone,
    case
      when v_resolution.should_create_intent then null
      else v_resolution.suppression_reason
    end,
    p_as_of
  ) on conflict on constraint notification_event_resolutions_pkey
    do nothing;

  update app_private.chore_notification_outbox as event
  set processing_status = 'succeeded',
      dispatched_at = p_as_of,
      next_attempt_at = null,
      last_error_code = null,
      lease_owner = null,
      lease_token = null,
      lease_expires_at = null,
      dead_lettered_at = null
  where event.event_id = p_event_id;

  insert into app_private.notification_worker_transitions (
    source_event_id,
    transition,
    worker_id,
    attempt,
    error_code,
    occurred_at
  ) values (
    p_event_id,
    'succeeded',
    v_event.lease_owner,
    v_event.attempts,
    null,
    p_as_of
  );

  return query
  select
    resolution.source_event_id,
    resolution.outcome,
    resolution.notification_category,
    resolution.subject_type,
    resolution.subject_id,
    resolution.recipient_member_id,
    resolution.recipient_user_id,
    resolution.scheduled_at,
    resolution.timezone,
    resolution.suppression_reason,
    resolution.resolved_at
  from app_private.notification_event_resolutions as resolution
  where resolution.source_event_id = p_event_id;
end;
$$;

revoke all on function public.process_chore_notification_event(
  uuid,
  uuid,
  timestamptz
) from public, anon, authenticated, service_role;
grant execute on function public.process_chore_notification_event(
  uuid,
  uuid,
  timestamptz
) to service_role;

alter function public.claim_chore_notification_events(
  uuid,
  integer,
  integer,
  timestamptz
) rename to claim_notification_events_wp05_07_legacy;

alter function public.claim_notification_events_wp05_07_legacy(
  uuid,
  integer,
  integer,
  timestamptz
) set schema app_private;

revoke all on function app_private.claim_notification_events_wp05_07_legacy(
  uuid,
  integer,
  integer,
  timestamptz
) from public, anon, authenticated, service_role;

create or replace function public.claim_chore_notification_events(
  p_worker_id uuid,
  p_batch_size integer,
  p_lease_seconds integer,
  p_as_of timestamptz
)
returns table (
  event_id uuid,
  lease_token uuid,
  attempt integer,
  max_attempts integer,
  lease_expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_worker_id is null
    or p_batch_size is null
    or p_batch_size not between 1 and 100
    or p_lease_seconds is null
    or p_lease_seconds not between 5 and 300
    or p_as_of is null then
    raise exception using
      errcode = 'KFN01',
      message = 'invalid notification worker input';
  end if;

  if exists (
    select 1
    from app_private.notification_worker_control as control
    where control.worker_key = 'chore_notification_outbox'
      and not control.paused
  ) then
    perform *
    from public.enqueue_calendar_event_reminder_events(
      p_as_of,
      p_as_of + interval '32 days'
    );
  end if;

  return query
  select legacy.*
  from app_private.claim_notification_events_wp05_07_legacy(
    p_worker_id,
    p_batch_size,
    p_lease_seconds,
    p_as_of
  ) as legacy;
end;
$$;

revoke all on function public.claim_chore_notification_events(
  uuid,
  integer,
  integer,
  timestamptz
) from public, anon, authenticated, service_role;
grant execute on function public.claim_chore_notification_events(
  uuid,
  integer,
  integer,
  timestamptz
) to service_role;

create or replace function public.get_notification_preferences(
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

create or replace function public.update_notification_preference(
  p_household_id uuid,
  p_category text,
  p_native_push boolean,
  p_web_push boolean,
  p_email boolean,
  p_in_app boolean,
  p_quiet_start time without time zone,
  p_quiet_end time without time zone,
  p_timezone text,
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
      timezone
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
      p_timezone
    ) returning * into v_result;
  elsif v_existing.native_push = p_native_push
    and v_existing.web_push = p_web_push
    and v_existing.email = p_email
    and v_existing.in_app = p_in_app
    and v_existing.quiet_start is not distinct from p_quiet_start
    and v_existing.quiet_end is not distinct from p_quiet_end
    and v_existing.timezone = p_timezone then
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
        timezone = p_timezone
    where preference.auth_user_id = v_authenticated_user_id
      and preference.household_id = p_household_id
      and preference.category = p_category
    returning * into v_result;
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
    v_result.updated_at,
    v_result.version,
    false;
end;
$$;

revoke all on function public.get_notification_preferences(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.update_notification_preference(
  uuid,
  text,
  boolean,
  boolean,
  boolean,
  boolean,
  time without time zone,
  time without time zone,
  text,
  bigint
) from public, anon, authenticated, service_role;
grant execute on function public.get_notification_preferences(uuid)
  to authenticated;
grant execute on function public.update_notification_preference(
  uuid,
  text,
  boolean,
  boolean,
  boolean,
  boolean,
  time without time zone,
  time without time zone,
  text,
  bigint
) to authenticated;

create or replace function public.materialize_chore_notification_inbox(
  p_batch_size integer,
  p_as_of timestamptz
)
returns table (
  captured_at timestamptz,
  claimed_count integer,
  created_count integer,
  disabled_count integer,
  stale_count integer,
  suppressed_count integer,
  cancelled_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_resolution record;
  v_latest record;
  v_inbox_item_id uuid;
  v_preference_version bigint;
  v_in_app boolean;
  v_quiet_start time without time zone;
  v_quiet_end time without time zone;
  v_preference_timezone text;
  v_delivery record;
  v_latest_found boolean;
  v_scheduled_at timestamptz;
  v_row_count integer;
  v_claimed_count integer := 0;
  v_created_count integer := 0;
  v_disabled_count integer := 0;
  v_stale_count integer := 0;
  v_suppressed_count integer := 0;
  v_cancelled_count integer := 0;
  v_paused boolean;
begin
  if p_batch_size is null
    or p_batch_size not between 1 and 100
    or p_as_of is null then
    raise exception using
      errcode = 'KNP01',
      message = 'invalid notification materializer input';
  end if;

  select control.paused
  into v_paused
  from app_private.notification_worker_control as control
  where control.worker_key = 'chore_notification_outbox';

  if coalesce(v_paused, true) then
    return query select p_as_of, 0, 0, 0, 0, 0, 0;
    return;
  end if;

  for v_resolution in
    select
      resolution.*,
      event.aggregate_version as source_aggregate_version,
      event.occurred_at as source_occurred_at
    from app_private.notification_event_resolutions as resolution
    join app_private.chore_notification_outbox as event
      on event.event_id = resolution.source_event_id
    left join app_private.notification_inbox_evaluations as evaluation
      on evaluation.source_event_id = resolution.source_event_id
    where evaluation.source_event_id is null
      and (
        event.aggregate_type <> 'calendar_occurrence'
        or resolution.outcome = 'suppressed'
        or resolution.scheduled_at <= p_as_of
      )
    order by event.occurred_at, event.event_id
    for update of resolution skip locked
    limit p_batch_size
  loop
    v_claimed_count := v_claimed_count + 1;

    select latest.*
    into v_latest
    from app_private.resolve_notification_event(
      v_resolution.source_event_id
    ) as latest;
    v_latest_found := found;

    update public.notification_inbox_items as item
    set cancelled_at = p_as_of,
        cancellation_reason = case
          when v_resolution.outcome = 'candidate' then 'superseded'
          else 'state_inactive'
        end
    where item.household_id = v_resolution.household_id
      and item.recipient_member_id = v_resolution.audience_member_id
      and item.category = v_resolution.notification_category
      and item.subject_type = v_resolution.subject_type
      and item.subject_id = v_resolution.subject_id
      and item.source_event_id <> v_resolution.source_event_id
      and item.source_aggregate_version
        <= v_resolution.source_aggregate_version
      and item.cancelled_at is null;
    get diagnostics v_row_count = row_count;
    v_cancelled_count := v_cancelled_count + v_row_count;

    if v_resolution.outcome = 'suppressed' then
      insert into app_private.notification_inbox_evaluations (
        source_event_id,
        outcome,
        reason_code,
        evaluated_at
      ) values (
        v_resolution.source_event_id,
        'suppressed',
        'SOURCE_SUPPRESSED',
        p_as_of
      );
      v_suppressed_count := v_suppressed_count + 1;
      continue;
    end if;

    if not v_latest_found
      or not v_latest.should_create_intent
      or v_latest.household_id <> v_resolution.household_id
      or v_latest.notification_category
        <> v_resolution.notification_category
      or v_latest.subject_type <> v_resolution.subject_type
      or v_latest.occurrence_id <> v_resolution.subject_id
      or v_latest.recipient_member_id
        is distinct from v_resolution.audience_member_id
      or v_latest.recipient_user_id
        is distinct from v_resolution.recipient_user_id then
      insert into app_private.notification_inbox_evaluations (
        source_event_id,
        outcome,
        reason_code,
        evaluated_at
      ) values (
        v_resolution.source_event_id,
        'stale',
        'LATEST_STATE_SUPPRESSED',
        p_as_of
      );
      v_stale_count := v_stale_count + 1;
      continue;
    end if;

    select
      preference.in_app,
      preference.quiet_start,
      preference.quiet_end,
      preference.timezone,
      preference.version
    into
      v_in_app,
      v_quiet_start,
      v_quiet_end,
      v_preference_timezone,
      v_preference_version
    from public.notification_preferences as preference
    where preference.auth_user_id = v_latest.recipient_user_id
      and preference.household_id = v_latest.household_id
      and preference.category = v_latest.notification_category;

    if not found then
      v_in_app := true;
      v_quiet_start := null;
      v_quiet_end := null;
      v_preference_timezone := v_latest.timezone;
      v_preference_version := 0;
    end if;

    if not v_in_app then
      insert into app_private.notification_inbox_evaluations (
        source_event_id,
        outcome,
        preference_version,
        reason_code,
        evaluated_at
      ) values (
        v_resolution.source_event_id,
        'disabled',
        v_preference_version,
        'CATEGORY_DISABLED',
        p_as_of
      );
      v_disabled_count := v_disabled_count + 1;
      continue;
    end if;

    v_scheduled_at := case
      when v_latest.notification_category = 'chore_assignment'
        then v_latest.event_occurred_at
      else v_latest.due_at
    end;

    select delivery.*
    into v_delivery
    from app_private.resolve_notification_delivery_not_before(
      greatest(v_scheduled_at, p_as_of),
      v_quiet_start,
      v_quiet_end,
      v_preference_timezone
    ) as delivery;

    insert into public.notification_inbox_items (
      source_event_id,
      source_aggregate_version,
      recipient_user_id,
      recipient_member_id,
      household_id,
      category,
      subject_type,
      subject_id,
      scheduled_at,
      created_at,
      updated_at,
      payload
    ) values (
      v_resolution.source_event_id,
      v_resolution.source_aggregate_version,
      v_latest.recipient_user_id,
      v_latest.recipient_member_id,
      v_latest.household_id,
      v_latest.notification_category,
      v_latest.subject_type,
      v_latest.occurrence_id,
      v_scheduled_at,
      p_as_of,
      p_as_of,
      pg_catalog.jsonb_build_object(
        'householdId', v_latest.household_id,
        'occurrenceId', v_latest.occurrence_id
      )
    ) returning id into v_inbox_item_id;

    insert into app_private.notification_inbox_evaluations (
      source_event_id,
      outcome,
      inbox_item_id,
      preference_version,
      delivery_not_before,
      quiet_applied,
      evaluated_at
    ) values (
      v_resolution.source_event_id,
      'created',
      v_inbox_item_id,
      v_preference_version,
      v_delivery.delivery_not_before,
      v_delivery.quiet_applied,
      p_as_of
    );
    v_created_count := v_created_count + 1;
  end loop;

  return query select
    p_as_of,
    v_claimed_count,
    v_created_count,
    v_disabled_count,
    v_stale_count,
    v_suppressed_count,
    v_cancelled_count;
end;
$$;

revoke all on function public.materialize_chore_notification_inbox(
  integer,
  timestamptz
) from public, anon, authenticated, service_role;
grant execute on function public.materialize_chore_notification_inbox(
  integer,
  timestamptz
) to service_role;

create or replace function
  app_private.claim_notification_push_deliveries_wp05_04(
  p_worker_id uuid,
  p_batch_size integer,
  p_lease_seconds integer,
  p_as_of timestamptz
)
returns table (
  delivery_id uuid,
  source_event_id uuid,
  inbox_item_id uuid,
  endpoint_id uuid,
  household_id uuid,
  category text,
  subject_type text,
  subject_id uuid,
  token_ciphertext_base64 text,
  token_fingerprint_base64 text,
  token_key_version integer,
  locale text,
  attempt integer,
  max_attempts integer,
  lease_token uuid,
  lease_expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_paused boolean;
  v_evaluation record;
  v_latest record;
  v_delivery record;
  v_endpoint record;
  v_native_push boolean;
  v_quiet_start time without time zone;
  v_quiet_end time without time zone;
  v_preference_timezone text;
  v_delivery_window record;
  v_scheduled_at timestamptz;
  v_inbox_item_id uuid;
  v_endpoint_count integer;
  v_claimed_count integer := 0;
begin
  if p_worker_id is null
    or p_batch_size is null
    or p_batch_size not between 1 and 100
    or p_lease_seconds is null
    or p_lease_seconds not between 5 and 300
    or p_as_of is null then
    raise exception using
      errcode = 'KPS01',
      message = 'invalid notification push input';
  end if;

  select control.paused
  into v_paused
  from app_private.notification_push_worker_control as control
  where control.worker_key = 'android_fcm_push';

  if coalesce(v_paused, true) then
    return;
  end if;

  insert into app_private.notification_push_evaluations (
    source_event_id,
    processing_status,
    next_evaluation_at,
    created_at
  )
  select
    resolution.source_event_id,
    'pending',
    resolution.scheduled_at,
    p_as_of
  from app_private.notification_event_resolutions as resolution
  left join app_private.notification_push_evaluations as evaluation
    on evaluation.source_event_id = resolution.source_event_id
  where evaluation.source_event_id is null
    and resolution.outcome = 'candidate'
  order by resolution.resolved_at, resolution.source_event_id
  limit p_batch_size;

  for v_evaluation in
    select evaluation.source_event_id
    from app_private.notification_push_evaluations as evaluation
    where evaluation.processing_status = 'pending'
      and evaluation.next_evaluation_at <= p_as_of
    order by evaluation.next_evaluation_at, evaluation.source_event_id
    for update skip locked
    limit p_batch_size
  loop
    select latest.*
    into v_latest
    from app_private.resolve_notification_event(
      v_evaluation.source_event_id
    ) as latest;

    if not found or not v_latest.should_create_intent then
      update app_private.notification_push_evaluations as evaluation
      set processing_status = 'stale',
          next_evaluation_at = null,
          reason_code = 'LATEST_STATE_SUPPRESSED',
          evaluated_at = p_as_of
      where evaluation.source_event_id = v_evaluation.source_event_id;
      continue;
    end if;

    select
      preference.native_push,
      preference.quiet_start,
      preference.quiet_end,
      preference.timezone
    into
      v_native_push,
      v_quiet_start,
      v_quiet_end,
      v_preference_timezone
    from public.notification_preferences as preference
    where preference.auth_user_id = v_latest.recipient_user_id
      and preference.household_id = v_latest.household_id
      and preference.category = v_latest.notification_category;

    if not found then
      v_native_push := true;
      v_quiet_start := null;
      v_quiet_end := null;
      v_preference_timezone := v_latest.timezone;
    end if;

    if not v_native_push then
      update app_private.notification_push_evaluations as evaluation
      set processing_status = 'disabled',
          next_evaluation_at = null,
          reason_code = 'NATIVE_PUSH_DISABLED',
          evaluated_at = p_as_of
      where evaluation.source_event_id = v_evaluation.source_event_id;
      continue;
    end if;

    v_scheduled_at := case
      when v_latest.notification_category = 'chore_assignment'
        then v_latest.event_occurred_at
      else v_latest.due_at
    end;

    select delivery_window.*
    into v_delivery_window
    from app_private.resolve_notification_delivery_not_before(
      greatest(v_scheduled_at, p_as_of),
      v_quiet_start,
      v_quiet_end,
      v_preference_timezone
    ) as delivery_window;

    if v_delivery_window.delivery_not_before > p_as_of then
      update app_private.notification_push_evaluations as evaluation
      set next_evaluation_at = v_delivery_window.delivery_not_before
      where evaluation.source_event_id = v_evaluation.source_event_id;
      continue;
    end if;

    select item.id
    into v_inbox_item_id
    from public.notification_inbox_items as item
    where item.source_event_id = v_evaluation.source_event_id
      and item.recipient_user_id = v_latest.recipient_user_id
      and item.household_id = v_latest.household_id
      and item.category = v_latest.notification_category
      and item.subject_type = v_latest.subject_type
      and item.subject_id = v_latest.occurrence_id
      and item.cancelled_at is null
    limit 1;

    insert into app_private.notification_push_deliveries (
      source_event_id,
      inbox_item_id,
      endpoint_id,
      recipient_user_id,
      recipient_member_id,
      household_id,
      category,
      subject_type,
      subject_id,
      processing_status,
      next_attempt_at,
      created_at,
      updated_at
    )
    select
      v_evaluation.source_event_id,
      v_inbox_item_id,
      endpoint.id,
      v_latest.recipient_user_id,
      v_latest.recipient_member_id,
      v_latest.household_id,
      v_latest.notification_category,
      v_latest.subject_type,
      v_latest.occurrence_id,
      'pending',
      p_as_of,
      p_as_of,
      p_as_of
    from public.notification_endpoints as endpoint
    where endpoint.auth_user_id = v_latest.recipient_user_id
      and endpoint.household_id = v_latest.household_id
      and endpoint.member_id = v_latest.recipient_member_id
      and endpoint.channel = 'native_push'
      and endpoint.platform = 'android'
      and endpoint.permission_state = 'granted'
      and endpoint.revoked_at is null
    on conflict on constraint
      notification_push_deliveries_source_event_id_endpoint_id_key
    do nothing;
    get diagnostics v_endpoint_count = row_count;

    update app_private.notification_push_evaluations as evaluation
    set processing_status = case
          when v_endpoint_count > 0 then 'materialized'
          else 'no_endpoint'
        end,
        next_evaluation_at = null,
        reason_code = case
          when v_endpoint_count > 0 then null
          else 'NO_ACTIVE_ANDROID_ENDPOINT'
        end,
        evaluated_at = p_as_of
    where evaluation.source_event_id = v_evaluation.source_event_id;
  end loop;

  update app_private.notification_push_deliveries as delivery
  set processing_status = 'failed',
      next_attempt_at = null,
      lease_owner = null,
      completed_lease_token = delivery.lease_token,
      lease_token = null,
      lease_expires_at = null,
      completed_token_fingerprint = endpoint.token_fingerprint,
      completion_outcome = 'retryable',
      completed_retry_after_seconds = null,
      last_result_code = 'ATTEMPTS_EXHAUSTED',
      endpoint_invalidated = false,
      updated_at = p_as_of,
      completed_at = p_as_of
  from public.notification_endpoints as endpoint
  where delivery.endpoint_id = endpoint.id
    and delivery.processing_status = 'leased'
    and delivery.lease_expires_at <= p_as_of
    and delivery.attempts >= delivery.max_attempts;

  update app_private.notification_push_deliveries as delivery
  set processing_status = 'retry_wait',
      next_attempt_at = p_as_of + interval '30 seconds',
      lease_owner = null,
      completed_lease_token = delivery.lease_token,
      lease_token = null,
      lease_expires_at = null,
      completed_token_fingerprint = endpoint.token_fingerprint,
      completion_outcome = 'retryable',
      completed_retry_after_seconds = 30,
      last_result_code = 'LEASE_EXPIRED',
      endpoint_invalidated = false,
      updated_at = p_as_of
  from public.notification_endpoints as endpoint
  where delivery.endpoint_id = endpoint.id
    and delivery.processing_status = 'leased'
    and delivery.lease_expires_at <= p_as_of
    and delivery.attempts < delivery.max_attempts;

  for v_delivery in
    select delivery.*
    from app_private.notification_push_deliveries as delivery
    where (
      delivery.processing_status = 'pending'
      and delivery.next_attempt_at <= p_as_of
      or delivery.processing_status = 'retry_wait'
      and delivery.next_attempt_at <= p_as_of
    )
    order by delivery.next_attempt_at, delivery.created_at, delivery.id
    for update skip locked
    limit p_batch_size * 4
  loop
    exit when v_claimed_count >= p_batch_size;

    select endpoint.*
    into v_endpoint
    from public.notification_endpoints as endpoint
    where endpoint.id = v_delivery.endpoint_id;

    if not found
      or v_endpoint.revoked_at is not null
      or v_endpoint.permission_state <> 'granted'
      or v_endpoint.platform <> 'android'
      or v_endpoint.auth_user_id <> v_delivery.recipient_user_id
      or v_endpoint.household_id <> v_delivery.household_id
      or v_endpoint.member_id <> v_delivery.recipient_member_id then
      perform app_private.cancel_notification_push_delivery(
        v_delivery.id,
        'ENDPOINT_INACTIVE',
        p_as_of
      );
      continue;
    end if;

    select latest.*
    into v_latest
    from app_private.resolve_notification_event(
      v_delivery.source_event_id
    ) as latest;

    if not found
      or not v_latest.should_create_intent
      or v_latest.recipient_user_id <> v_delivery.recipient_user_id
      or v_latest.recipient_member_id <> v_delivery.recipient_member_id
      or v_latest.household_id <> v_delivery.household_id
      or v_latest.notification_category <> v_delivery.category
      or v_latest.subject_type <> v_delivery.subject_type
      or v_latest.occurrence_id <> v_delivery.subject_id then
      perform app_private.cancel_notification_push_delivery(
        v_delivery.id,
        'LATEST_STATE_SUPPRESSED',
        p_as_of
      );
      continue;
    end if;

    select
      preference.native_push,
      preference.quiet_start,
      preference.quiet_end,
      preference.timezone
    into
      v_native_push,
      v_quiet_start,
      v_quiet_end,
      v_preference_timezone
    from public.notification_preferences as preference
    where preference.auth_user_id = v_delivery.recipient_user_id
      and preference.household_id = v_delivery.household_id
      and preference.category = v_delivery.category;

    if not found then
      v_native_push := true;
      v_quiet_start := null;
      v_quiet_end := null;
      v_preference_timezone := v_latest.timezone;
    end if;

    if not v_native_push then
      perform app_private.cancel_notification_push_delivery(
        v_delivery.id,
        'NATIVE_PUSH_DISABLED',
        p_as_of
      );
      continue;
    end if;

    v_scheduled_at := case
      when v_latest.notification_category = 'chore_assignment'
        then v_latest.event_occurred_at
      else v_latest.due_at
    end;
    select delivery_window.*
    into v_delivery_window
    from app_private.resolve_notification_delivery_not_before(
      greatest(v_scheduled_at, p_as_of),
      v_quiet_start,
      v_quiet_end,
      v_preference_timezone
    ) as delivery_window;

    if v_delivery_window.delivery_not_before > p_as_of then
      update app_private.notification_push_deliveries as delivery
      set next_attempt_at = v_delivery_window.delivery_not_before,
          updated_at = p_as_of
      where delivery.id = v_delivery.id;
      continue;
    end if;

    update app_private.notification_push_deliveries as delivery
    set processing_status = 'leased',
        attempts = delivery.attempts + 1,
        next_attempt_at = null,
        lease_owner = p_worker_id,
        lease_token = extensions.gen_random_uuid(),
        lease_expires_at = p_as_of
          + pg_catalog.make_interval(secs => p_lease_seconds),
        last_result_code = null,
        provider_receipt_hash = null,
        completed_lease_token = null,
        completed_token_fingerprint = null,
        completion_outcome = null,
        completed_retry_after_seconds = null,
        endpoint_invalidated = false,
        updated_at = p_as_of,
        completed_at = null
    where delivery.id = v_delivery.id
    returning delivery.* into v_delivery;

    return query select
      v_delivery.id,
      v_delivery.source_event_id,
      v_delivery.inbox_item_id,
      v_delivery.endpoint_id,
      v_delivery.household_id,
      v_delivery.category,
      v_delivery.subject_type,
      v_delivery.subject_id,
      pg_catalog.replace(
        pg_catalog.encode(v_endpoint.token_ciphertext, 'base64'),
        pg_catalog.chr(10),
        ''
      ),
      pg_catalog.replace(
        pg_catalog.encode(v_endpoint.token_fingerprint, 'base64'),
        pg_catalog.chr(10),
        ''
      ),
      v_endpoint.token_key_version,
      v_endpoint.locale,
      v_delivery.attempts,
      v_delivery.max_attempts,
      v_delivery.lease_token,
      v_delivery.lease_expires_at;
    v_claimed_count := v_claimed_count + 1;
  end loop;
end;
$$;

revoke all on function
  app_private.claim_notification_push_deliveries_wp05_04(
    uuid,
    integer,
    integer,
    timestamptz
  ) from public, anon, authenticated, service_role;

create or replace function public.resolve_notification_push_target(
  p_delivery_id uuid,
  p_household_id uuid,
  p_subject_id uuid
)
returns table (
  delivery_id uuid,
  household_id uuid,
  category text,
  subject_type text,
  subject_id uuid,
  inbox_item_id uuid,
  safe_destination text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_delivery app_private.notification_push_deliveries%rowtype;
  v_latest record;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KPS02',
      message = 'authentication required';
  end if;
  if p_delivery_id is null
    or p_household_id is null
    or p_subject_id is null then
    raise exception using
      errcode = 'KPS01',
      message = 'invalid notification push input';
  end if;

  select delivery.*
  into v_delivery
  from app_private.notification_push_deliveries as delivery
  where delivery.id = p_delivery_id
    and delivery.recipient_user_id = v_authenticated_user_id
    and delivery.household_id = p_household_id
    and delivery.subject_id = p_subject_id
    and delivery.processing_status in ('leased', 'retry_wait', 'succeeded')
    and app_private.is_active_household_member(delivery.household_id);

  if not found then
    return;
  end if;

  select latest.*
  into v_latest
  from app_private.resolve_notification_event(
    v_delivery.source_event_id
  ) as latest;

  if not found
    or not v_latest.should_create_intent
    or v_latest.recipient_user_id <> v_authenticated_user_id
    or v_latest.household_id <> v_delivery.household_id
    or v_latest.notification_category <> v_delivery.category
    or v_latest.subject_type <> v_delivery.subject_type
    or v_latest.occurrence_id <> v_delivery.subject_id
    or v_delivery.inbox_item_id is not null and not exists (
      select 1
      from public.notification_inbox_items as item
      where item.id = v_delivery.inbox_item_id
        and item.recipient_user_id = v_authenticated_user_id
        and item.household_id = v_delivery.household_id
        and item.category = v_delivery.category
        and item.subject_type = v_delivery.subject_type
        and item.subject_id = v_delivery.subject_id
        and item.cancelled_at is null
    ) then
    return;
  end if;

  return query select
    v_delivery.id,
    v_delivery.household_id,
    v_delivery.category,
    v_delivery.subject_type,
    v_delivery.subject_id,
    v_delivery.inbox_item_id,
    'today'::text;
end;
$$;

revoke all on function public.resolve_notification_push_target(
  uuid,
  uuid,
  uuid
) from public, anon, authenticated, service_role;
grant execute on function public.resolve_notification_push_target(
  uuid,
  uuid,
  uuid
) to authenticated;

comment on function public.enqueue_calendar_event_reminder_events(
  timestamptz,
  timestamptz
) is
  'WP05-07 bounded content-free Calendar reminder horizon producer.';
comment on function app_private.resolve_notification_event(uuid) is
  'WP05-07 generic Chore and Calendar latest-state notification resolver.';
comment on function app_private.delete_notification_sources_for_occurrence() is
  'WP05-07 polymorphic Chore and Calendar occurrence source-event delete cascade.';
comment on function public.claim_chore_notification_events(
  uuid,
  integer,
  integer,
  timestamptz
) is
  'WP05-07 backward-compatible source worker claim with Calendar horizon enqueue.';
