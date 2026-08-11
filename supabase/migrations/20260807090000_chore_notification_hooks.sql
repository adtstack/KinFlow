-- KinFlow WP03-07 chore notification event hooks.
-- Store MVP scope: content-free due/assignment outbox producers only.

create table app_private.chore_notification_outbox (
  event_id uuid primary key default extensions.gen_random_uuid(),
  event_type text not null,
  constraint chore_notification_outbox_event_type_ck check (
    event_type in (
      'chore.occurrence_due_changed',
      'chore.occurrence_assigned'
    )
  ),
  event_version integer not null default 1,
  household_id uuid not null
    references public.households(id) on delete cascade,
  actor_user_id uuid
    references auth.users(id) on delete set null,
  actor_member_id uuid,
  acting_member_id uuid,
  aggregate_type text not null default 'chore_occurrence',
  constraint chore_notification_outbox_event_version_ck check (
    event_version = 1
  ),
  constraint chore_notification_outbox_aggregate_type_ck check (
    aggregate_type = 'chore_occurrence'
  ),
  aggregate_id uuid not null,
  aggregate_version bigint not null,
  constraint chore_notification_outbox_aggregate_version_ck check (
    aggregate_version > 0
  ),
  correlation_id uuid not null default extensions.gen_random_uuid(),
  causation_id uuid,
  payload jsonb not null,
  constraint chore_notification_outbox_payload_ck check (
    jsonb_typeof(payload) = 'object'
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
      and jsonb_typeof(payload->'dueLocalDate') = 'string'
      and payload->>'dueLocalDate' ~ '^\d{4}-\d{2}-\d{2}$'
      and jsonb_typeof(payload->'dueAt') in ('null', 'string')
      and jsonb_typeof(payload->'timezone') = 'string'
      and app_private.is_valid_iana_timezone(payload->>'timezone')
      and jsonb_typeof(payload->'status') = 'string'
      and payload->>'status' in (
        'scheduled',
        'completed',
        'skipped',
        'cancelled'
      )
      or event_type = 'chore.occurrence_assigned'
      and payload ?& array['assigneeMemberId', 'status']
      and payload - array['assigneeMemberId', 'status'] = '{}'::jsonb
      and jsonb_typeof(payload->'assigneeMemberId') = 'string'
      and payload->>'assigneeMemberId' ~
        '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      and jsonb_typeof(payload->'status') = 'string'
      and payload->>'status' in (
        'scheduled',
        'completed',
        'skipped',
        'cancelled'
      )
    )
  ),
  occurred_at timestamptz not null default statement_timestamp(),
  dispatched_at timestamptz,
  attempts integer not null default 0,
  next_attempt_at timestamptz,
  last_error_code text,
  constraint chore_notification_outbox_attempts_ck check (attempts >= 0),
  constraint chore_notification_outbox_error_code_ck check (
    last_error_code is null
    or last_error_code ~ '^[A-Z0-9_]{1,64}$'
  ),
  unique (
    household_id,
    event_type,
    aggregate_id,
    aggregate_version
  ),
  constraint chore_notification_outbox_actor_fk
    foreign key (household_id, actor_member_id)
    references public.household_members(household_id, id),
  constraint chore_notification_outbox_acting_fk
    foreign key (household_id, acting_member_id)
    references public.household_members(household_id, id),
  constraint chore_notification_outbox_occurrence_fk
    foreign key (household_id, aggregate_id)
    references public.chore_occurrences(household_id, id)
    on delete cascade,
  constraint chore_notification_outbox_dispatch_state_ck check (
    dispatched_at is null
    or next_attempt_at is null
  )
);

create index chore_notification_outbox_pending_idx
  on app_private.chore_notification_outbox(
    next_attempt_at,
    occurred_at,
    event_id
  )
  where dispatched_at is null;

revoke all on table app_private.chore_notification_outbox
  from public, anon, authenticated, service_role;

create or replace function app_private.protect_chore_notification_outbox()
returns trigger
language plpgsql
set search_path = ''
as $$
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
    or new.correlation_id is distinct from old.correlation_id
    or new.causation_id is distinct from old.causation_id
    or new.payload is distinct from old.payload
    or new.occurred_at is distinct from old.occurred_at
    or new.attempts < old.attempts
    or old.dispatched_at is not null
       and new.dispatched_at is distinct from old.dispatched_at then
    raise exception using
      errcode = '55000',
      message = 'chore notification outbox envelope is immutable';
  end if;

  return new;
end;
$$;

revoke all on function app_private.protect_chore_notification_outbox()
  from public, anon, authenticated, service_role;

create trigger chore_notification_outbox_protect_envelope
before update on app_private.chore_notification_outbox
for each row
execute function app_private.protect_chore_notification_outbox();

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
    or new.status is distinct from old.status then
    insert into app_private.chore_notification_outbox (
      event_type,
      household_id,
      actor_user_id,
      actor_member_id,
      aggregate_id,
      aggregate_version,
      correlation_id,
      payload
    )
    values (
      'chore.occurrence_due_changed',
      new.household_id,
      v_actor_user_id,
      v_actor_member_id,
      new.id,
      new.version,
      v_correlation_id,
      jsonb_build_object(
        'dueLocalDate', new.due_local_date,
        'dueAt', new.due_at,
        'timezone', new.timezone,
        'status', new.status::text
      )
    );
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
      correlation_id,
      payload
    )
    values (
      'chore.occurrence_assigned',
      new.household_id,
      v_actor_user_id,
      v_actor_member_id,
      new.id,
      new.version,
      v_correlation_id,
      jsonb_build_object(
        'assigneeMemberId', new.assignee_member_id,
        'status', new.status::text
      )
    );
  end if;

  return new;
end;
$$;

revoke all on function app_private.capture_chore_notification_events()
  from public, anon, authenticated, service_role;

create trigger chore_occurrences_capture_notification_events
after insert or update on public.chore_occurrences
for each row
execute function app_private.capture_chore_notification_events();

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
  with resolved as (
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
      case
        when event.event_type = 'chore.occurrence_assigned'
          then (event.payload->>'assigneeMemberId')::uuid
        else occurrence.assignee_member_id
      end as recipient_member_id,
      occurrence.due_local_date,
      occurrence.due_at,
      occurrence.timezone,
      occurrence.status,
      series.deleted_at as series_deleted_at,
      event.payload,
      (
        event.aggregate_version = (
          select max(candidate.aggregate_version)
          from app_private.chore_notification_outbox as candidate
          where candidate.household_id = event.household_id
            and candidate.event_type = event.event_type
            and candidate.aggregate_id = event.aggregate_id
        )
        and occurrence.version >= event.aggregate_version
        and (
          event.event_type = 'chore.occurrence_due_changed'
          and occurrence.due_local_date =
            (event.payload->>'dueLocalDate')::date
          and occurrence.due_at is not distinct from case
            when jsonb_typeof(event.payload->'dueAt') = 'null' then null
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
    from app_private.chore_notification_outbox as event
    join public.chore_occurrences as occurrence
      on occurrence.household_id = event.household_id
     and occurrence.id = event.aggregate_id
    join public.chore_series as series
      on series.household_id = occurrence.household_id
     and series.id = occurrence.series_id
    where event.event_id = p_event_id
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
        when with_recipient.series_deleted_at is not null
          then 'inactive_series'
        when with_recipient.status <> 'scheduled'
          then 'occurrence_not_scheduled'
        when with_recipient.recipient_user_id is null
          or with_recipient.recipient_removed_at is not null
          then 'inactive_recipient'
        when with_recipient.event_type = 'chore.occurrence_due_changed'
          and with_recipient.due_at is null
          then 'schedule_unresolved'
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
    'chore_occurrence'::text,
    evaluated.recipient_member_id,
    evaluated.recipient_user_id,
    evaluated.due_local_date,
    evaluated.due_at,
    evaluated.timezone,
    evaluated.status::text,
    evaluated.is_current,
    evaluated.suppression_reason is null,
    evaluated.suppression_reason
  from evaluated
$$;

revoke all on function app_private.resolve_chore_notification_event(uuid)
  from public, anon, authenticated, service_role;

comment on table app_private.chore_notification_outbox is
  'WP03-07 content-free chore due/assignment events for a future notification worker.';
comment on function app_private.resolve_chore_notification_event(uuid) is
  'Internal latest-state resolver; Phase 05 must expose a separately mediated worker API.';
