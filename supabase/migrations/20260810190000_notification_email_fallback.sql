-- KinFlow WP05-14 generic notification email fallback.
--
-- Email delivery reuses the existing content-free notification source and
-- latest-state/quiet-hours authority. Recipient addresses are never persisted
-- in queue or audit tables; a confirmed Auth address is returned only by the
-- service-only claim RPC immediately before provider submission.

create table app_private.notification_email_evaluations (
  source_event_id uuid primary key
    references app_private.chore_notification_outbox(event_id)
    on delete cascade,
  processing_status text not null default 'pending' check (
    processing_status in (
      'pending',
      'materialized',
      'disabled',
      'stale',
      'no_address',
      'expired'
    )
  ),
  next_evaluation_at timestamptz,
  reason_code text check (
    reason_code is null
    or reason_code in (
      'EMAIL_DISABLED',
      'LATEST_STATE_SUPPRESSED',
      'NO_CONFIRMED_EMAIL',
      'STALE_DELIVERY_WINDOW'
    )
  ),
  created_at timestamptz not null,
  evaluated_at timestamptz,
  constraint notification_email_evaluation_state_ck check (
    case processing_status
      when 'pending' then
        next_evaluation_at is not null
        and reason_code is null
        and evaluated_at is null
      when 'materialized' then
        next_evaluation_at is null
        and reason_code is null
        and evaluated_at is not null
      when 'disabled' then
        next_evaluation_at is null
        and reason_code = 'EMAIL_DISABLED'
        and evaluated_at is not null
      when 'stale' then
        next_evaluation_at is null
        and reason_code = 'LATEST_STATE_SUPPRESSED'
        and evaluated_at is not null
      when 'no_address' then
        next_evaluation_at is null
        and reason_code = 'NO_CONFIRMED_EMAIL'
        and evaluated_at is not null
      when 'expired' then
        next_evaluation_at is null
        and reason_code = 'STALE_DELIVERY_WINDOW'
        and evaluated_at is not null
      else false
    end
  )
);

create index notification_email_evaluations_ready_idx
  on app_private.notification_email_evaluations(
    processing_status,
    next_evaluation_at,
    source_event_id
  )
  where processing_status = 'pending';

create table app_private.notification_email_deliveries (
  id uuid primary key default extensions.gen_random_uuid(),
  source_event_id uuid not null unique
    references app_private.notification_email_evaluations(source_event_id)
    on delete cascade,
  inbox_item_id uuid
    references public.notification_inbox_items(id)
    on delete set null,
  recipient_user_id uuid not null
    references auth.users(id) on delete cascade,
  recipient_member_id uuid not null,
  household_id uuid not null
    references public.households(id) on delete cascade,
  category text not null check (
    category in ('chore_due', 'chore_assignment', 'calendar_event')
  ),
  subject_type text not null,
  subject_id uuid not null,
  processing_status text not null default 'pending' check (
    processing_status in (
      'pending',
      'leased',
      'retry_wait',
      'succeeded',
      'failed',
      'cancelled'
    )
  ),
  attempts integer not null default 0 check (attempts between 0 and 5),
  max_attempts integer not null default 5 check (
    max_attempts between 1 and 5 and attempts <= max_attempts
  ),
  next_attempt_at timestamptz,
  lease_owner uuid,
  lease_token uuid,
  lease_expires_at timestamptz,
  submission_started_at timestamptz,
  submission_lease_token uuid,
  last_result_code text check (
    last_result_code is null
    or last_result_code in (
      'EMAIL_ACCEPTED',
      'EMAIL_RATE_LIMITED',
      'EMAIL_PROVIDER_UNAVAILABLE',
      'EMAIL_PROVIDER_INTERNAL',
      'EMAIL_REQUEST_REJECTED',
      'EMAIL_AUTH_REJECTED',
      'EMAIL_PAYLOAD_REJECTED',
      'EMAIL_SUBMISSION_AMBIGUOUS',
      'ATTEMPTS_EXHAUSTED',
      'LEASE_EXPIRED',
      'EMAIL_DISABLED',
      'LATEST_STATE_SUPPRESSED',
      'NO_CONFIRMED_EMAIL',
      'STALE_DELIVERY_WINDOW',
      'ROLLBACK_DISABLED'
    )
  ),
  provider_message_id_hash bytea check (
    provider_message_id_hash is null
    or pg_catalog.octet_length(provider_message_id_hash) = 32
  ),
  completed_lease_token uuid,
  completion_outcome text check (
    completion_outcome is null
    or completion_outcome in (
      'accepted', 'retryable', 'permanent', 'ambiguous'
    )
  ),
  completed_retry_after_seconds integer check (
    completed_retry_after_seconds is null
    or completed_retry_after_seconds between 5 and 7200
  ),
  scheduled_at timestamptz not null,
  expires_at timestamptz not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  completed_at timestamptz,
  constraint notification_email_delivery_recipient_fk
    foreign key (household_id, recipient_member_id, recipient_user_id)
    references public.household_members(household_id, id, auth_user_id),
  constraint notification_email_delivery_subject_type_ck check (
    category in ('chore_due', 'chore_assignment')
      and subject_type = 'chore_occurrence'
    or category = 'calendar_event'
      and subject_type = 'calendar_occurrence'
  ),
  constraint notification_email_delivery_window_ck check (
    expires_at > scheduled_at
    and expires_at <= scheduled_at + interval '1 hour'
  ),
  constraint notification_email_delivery_timestamps_ck check (
    updated_at >= created_at
    and (completed_at is null or completed_at >= created_at)
  ),
  constraint notification_email_delivery_submission_marker_ck check (
    submission_started_at is null and submission_lease_token is null
    or submission_started_at is not null
      and submission_lease_token is not null
      and attempts > 0
  ),
  constraint notification_email_delivery_state_ck check (
    case processing_status
      when 'pending' then
        attempts = 0
        and next_attempt_at is not null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and submission_started_at is null
        and completed_at is null
        and last_result_code is null
        and provider_message_id_hash is null
        and completed_lease_token is null
        and completion_outcome is null
        and completed_retry_after_seconds is null
      when 'leased' then
        attempts between 1 and max_attempts
        and next_attempt_at is null
        and lease_owner is not null
        and lease_token is not null
        and lease_expires_at is not null
        and completed_at is null
        and last_result_code is null
        and provider_message_id_hash is null
        and completed_lease_token is null
        and completion_outcome is null
        and completed_retry_after_seconds is null
        and (
          submission_started_at is null
          or submission_lease_token = lease_token
        )
      when 'retry_wait' then
        attempts between 1 and max_attempts - 1
        and next_attempt_at is not null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and submission_started_at is null
        and completed_at is null
        and last_result_code in (
          'EMAIL_RATE_LIMITED',
          'EMAIL_PROVIDER_UNAVAILABLE',
          'EMAIL_PROVIDER_INTERNAL',
          'LEASE_EXPIRED'
        )
        and provider_message_id_hash is null
        and completed_lease_token is not null
        and completion_outcome = 'retryable'
        and completed_retry_after_seconds is not null
      when 'succeeded' then
        attempts between 1 and max_attempts
        and next_attempt_at is null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and submission_started_at is not null
        and submission_lease_token = completed_lease_token
        and completed_at is not null
        and last_result_code = 'EMAIL_ACCEPTED'
        and completed_lease_token is not null
        and completion_outcome = 'accepted'
        and completed_retry_after_seconds is null
      when 'failed' then
        attempts between 1 and max_attempts
        and next_attempt_at is null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and completed_at is not null
        and last_result_code is not null
        and provider_message_id_hash is null
        and completed_lease_token is not null
        and completion_outcome in ('retryable', 'permanent', 'ambiguous')
        and (
          completion_outcome = 'retryable'
          or completed_retry_after_seconds is null
        )
        and (
          submission_started_at is null
          or submission_lease_token = completed_lease_token
        )
      when 'cancelled' then
        next_attempt_at is null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and submission_started_at is null
        and completed_at is not null
        and last_result_code in (
          'EMAIL_DISABLED',
          'LATEST_STATE_SUPPRESSED',
          'NO_CONFIRMED_EMAIL',
          'STALE_DELIVERY_WINDOW',
          'ROLLBACK_DISABLED'
        )
        and provider_message_id_hash is null
        and completed_lease_token is null
        and completion_outcome is null
        and completed_retry_after_seconds is null
      else false
    end
  )
);

create index notification_email_deliveries_ready_idx
  on app_private.notification_email_deliveries(
    processing_status,
    next_attempt_at,
    lease_expires_at,
    id
  )
  where processing_status in ('pending', 'retry_wait', 'leased');

create index notification_email_deliveries_slo_idx
  on app_private.notification_email_deliveries(
    scheduled_at,
    processing_status,
    completed_at
  );

create table app_private.notification_email_delivery_transitions (
  id bigint generated always as identity primary key,
  delivery_id uuid not null
    references app_private.notification_email_deliveries(id)
    on delete cascade,
  transition text not null check (
    transition in (
      'claimed',
      'submission_started',
      'retry_scheduled',
      'succeeded',
      'failed',
      'cancelled'
    )
  ),
  attempt integer not null check (attempt between 0 and 5),
  result_code text,
  occurred_at timestamptz not null
);

create index notification_email_delivery_transitions_delivery_idx
  on app_private.notification_email_delivery_transitions(
    delivery_id,
    occurred_at,
    id
  );

create table app_private.notification_email_worker_control (
  worker_key text primary key check (worker_key = 'sendgrid_transactional'),
  paused boolean not null default false,
  reason_code text check (
    reason_code is null or reason_code = 'ROLLBACK_DISABLED'
  ),
  updated_at timestamptz not null,
  constraint notification_email_worker_control_state_ck check (
    paused = (reason_code is not null)
  )
);

insert into app_private.notification_email_worker_control (
  worker_key,
  paused,
  reason_code,
  updated_at
) values (
  'sendgrid_transactional',
  false,
  null,
  pg_catalog.statement_timestamp()
);

revoke all on table app_private.notification_email_evaluations
  from public, anon, authenticated, service_role;
revoke all on table app_private.notification_email_deliveries
  from public, anon, authenticated, service_role;
revoke all on table app_private.notification_email_delivery_transitions
  from public, anon, authenticated, service_role;
revoke all on sequence
  app_private.notification_email_delivery_transitions_id_seq
  from public, anon, authenticated, service_role;
revoke all on table app_private.notification_email_worker_control
  from public, anon, authenticated, service_role;

create trigger notification_email_delivery_validate_subject
before insert or update of household_id, subject_type, subject_id
on app_private.notification_email_deliveries
for each row execute function app_private.validate_notification_subject();

create or replace function app_private.reject_notification_email_transition_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'notification email transition history is immutable';
end;
$$;

revoke all on function
  app_private.reject_notification_email_transition_mutation()
  from public, anon, authenticated, service_role;

create trigger notification_email_delivery_transitions_immutable
before update or delete on app_private.notification_email_delivery_transitions
for each row execute function
  app_private.reject_notification_email_transition_mutation();

create or replace function app_private.protect_notification_email_delivery()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id is distinct from old.id
    or new.source_event_id is distinct from old.source_event_id
    or new.inbox_item_id is distinct from old.inbox_item_id
    or new.recipient_user_id is distinct from old.recipient_user_id
    or new.recipient_member_id is distinct from old.recipient_member_id
    or new.household_id is distinct from old.household_id
    or new.category is distinct from old.category
    or new.subject_type is distinct from old.subject_type
    or new.subject_id is distinct from old.subject_id
    or new.max_attempts is distinct from old.max_attempts
    or new.created_at is distinct from old.created_at
    or old.attempts > 0 and (
      new.scheduled_at is distinct from old.scheduled_at
      or new.expires_at is distinct from old.expires_at
    ) then
    raise exception using
      errcode = '55000',
      message = 'notification email delivery identity is immutable';
  end if;
  return new;
end;
$$;

revoke all on function app_private.protect_notification_email_delivery()
  from public, anon, authenticated, service_role;

create trigger notification_email_delivery_protect_identity
before update on app_private.notification_email_deliveries
for each row execute function app_private.protect_notification_email_delivery();

create or replace function app_private.cancel_notification_email_delivery(
  p_delivery_id uuid,
  p_result_code text,
  p_as_of timestamptz
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_delivery_id uuid;
  v_attempt integer;
begin
  if p_delivery_id is null
    or p_result_code not in (
      'EMAIL_DISABLED',
      'LATEST_STATE_SUPPRESSED',
      'NO_CONFIRMED_EMAIL',
      'STALE_DELIVERY_WINDOW',
      'ROLLBACK_DISABLED'
    )
    or p_as_of is null then
    raise exception using
      errcode = 'KEM01',
      message = 'invalid notification email input';
  end if;

  update app_private.notification_email_deliveries as delivery
  set processing_status = 'cancelled',
      next_attempt_at = null,
      lease_owner = null,
      lease_token = null,
      lease_expires_at = null,
      submission_started_at = null,
      submission_lease_token = null,
      last_result_code = p_result_code,
      provider_message_id_hash = null,
      completed_lease_token = null,
      completion_outcome = null,
      completed_retry_after_seconds = null,
      updated_at = greatest(p_as_of, delivery.created_at),
      completed_at = greatest(p_as_of, delivery.created_at)
  where delivery.id = p_delivery_id
    and delivery.processing_status in ('pending', 'retry_wait', 'leased')
    and delivery.submission_started_at is null
  returning delivery.id, delivery.attempts
  into v_delivery_id, v_attempt;

  if v_delivery_id is not null then
    insert into app_private.notification_email_delivery_transitions (
      delivery_id,
      transition,
      attempt,
      result_code,
      occurred_at
    ) values (
      v_delivery_id,
      'cancelled',
      v_attempt,
      p_result_code,
      p_as_of
    );
  end if;
end;
$$;

revoke all on function app_private.cancel_notification_email_delivery(
  uuid,
  text,
  timestamptz
) from public, anon, authenticated, service_role;

create or replace function app_private.wake_notification_email_evaluations()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_household_id uuid;
  v_category text;
begin
  if tg_op = 'DELETE' then
    v_user_id := old.auth_user_id;
    v_household_id := old.household_id;
    v_category := old.category;
  else
    v_user_id := new.auth_user_id;
    v_household_id := new.household_id;
    v_category := new.category;
  end if;

  update app_private.notification_email_evaluations as evaluation
  set next_evaluation_at = least(
    evaluation.next_evaluation_at,
    pg_catalog.statement_timestamp()
  )
  from app_private.notification_event_resolutions as resolution
  where evaluation.source_event_id = resolution.source_event_id
    and evaluation.processing_status = 'pending'
    and resolution.recipient_user_id = v_user_id
    and resolution.household_id = v_household_id
    and resolution.notification_category = v_category;

  update app_private.notification_email_deliveries as delivery
  set next_attempt_at = least(
        delivery.next_attempt_at,
        pg_catalog.statement_timestamp()
      ),
      updated_at = greatest(
        delivery.updated_at,
        pg_catalog.statement_timestamp()
      )
  where delivery.recipient_user_id = v_user_id
    and delivery.household_id = v_household_id
    and delivery.category = v_category
    and delivery.processing_status = 'pending'
    and delivery.attempts = 0;
  return null;
end;
$$;

revoke all on function app_private.wake_notification_email_evaluations()
  from public, anon, authenticated, service_role;

create trigger notification_preferences_wake_email_evaluations
after insert or update or delete on public.notification_preferences
for each row execute function
  app_private.wake_notification_email_evaluations();

create or replace function
  app_private.sync_notification_email_resolution_schedule()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update app_private.notification_email_evaluations as evaluation
  set next_evaluation_at = new.scheduled_at
  where evaluation.source_event_id = new.source_event_id
    and evaluation.processing_status = 'pending';

  update app_private.notification_email_deliveries as delivery
  set scheduled_at = new.scheduled_at,
      expires_at = new.scheduled_at + interval '1 hour',
      next_attempt_at = new.scheduled_at,
      updated_at = greatest(
        delivery.updated_at,
        pg_catalog.statement_timestamp()
      )
  where delivery.source_event_id = new.source_event_id
    and delivery.processing_status = 'pending'
    and delivery.attempts = 0;
  return null;
end;
$$;

revoke all on function
  app_private.sync_notification_email_resolution_schedule()
  from public, anon, authenticated, service_role;

create trigger notification_resolution_sync_email_schedule
after update of scheduled_at on app_private.notification_event_resolutions
for each row
when (old.scheduled_at is distinct from new.scheduled_at)
execute function app_private.sync_notification_email_resolution_schedule();

-- Once a provider attempt has started, Calendar lead changes must not rewrite
-- the source schedule used by immutable email delivery history.
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
        or exists (
          select 1
          from app_private.notification_email_deliveries as delivery
          where delivery.source_event_id = resolution.source_event_id
            and delivery.attempts > 0
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

create or replace function public.claim_notification_email_deliveries(
  p_worker_id uuid,
  p_batch_size integer,
  p_lease_seconds integer,
  p_as_of timestamptz
)
returns table (
  delivery_id uuid,
  source_event_id uuid,
  inbox_item_id uuid,
  household_id uuid,
  category text,
  subject_type text,
  subject_id uuid,
  recipient_email text,
  locale text,
  attempt integer,
  max_attempts integer,
  lease_token uuid,
  lease_expires_at timestamptz,
  scheduled_at timestamptz,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_paused boolean;
  v_evaluation record;
  v_latest record;
  v_delivery app_private.notification_email_deliveries%rowtype;
  v_email_enabled boolean;
  v_quiet_start time without time zone;
  v_quiet_end time without time zone;
  v_preference_timezone text;
  v_source_scheduled_at timestamptz;
  v_source_expires_at timestamptz;
  v_delivery_window record;
  v_inbox_item_id uuid;
  v_recipient_email text;
  v_locale text;
  v_claimed_count integer := 0;
begin
  if p_worker_id is null
    or p_batch_size is null
    or p_batch_size not between 1 and 100
    or p_lease_seconds is null
    or p_lease_seconds not between 5 and 300
    or p_as_of is null then
    raise exception using
      errcode = 'KEM01',
      message = 'invalid notification email input';
  end if;

  select control.paused
  into v_paused
  from app_private.notification_email_worker_control as control
  where control.worker_key = 'sendgrid_transactional';

  if coalesce(v_paused, true) then
    return;
  end if;

  insert into app_private.notification_email_evaluations (
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
  left join app_private.notification_email_evaluations as evaluation
    on evaluation.source_event_id = resolution.source_event_id
  where evaluation.source_event_id is null
    and resolution.outcome = 'candidate'
  order by resolution.scheduled_at, resolution.source_event_id
  limit p_batch_size * 4;

  for v_evaluation in
    select evaluation.source_event_id
    from app_private.notification_email_evaluations as evaluation
    where evaluation.processing_status = 'pending'
      and evaluation.next_evaluation_at <= p_as_of
    order by evaluation.next_evaluation_at, evaluation.source_event_id
    for update skip locked
    limit p_batch_size * 4
  loop
    select latest.*
    into v_latest
    from app_private.resolve_chore_notification_event(
      v_evaluation.source_event_id
    ) as latest;

    if not found or not v_latest.should_create_intent then
      update app_private.notification_email_evaluations as evaluation
      set processing_status = 'stale',
          next_evaluation_at = null,
          reason_code = 'LATEST_STATE_SUPPRESSED',
          evaluated_at = p_as_of
      where evaluation.source_event_id = v_evaluation.source_event_id;
      continue;
    end if;

    select
      resolution.scheduled_at
    into v_source_scheduled_at
    from app_private.notification_event_resolutions as resolution
    where resolution.source_event_id = v_evaluation.source_event_id
      and resolution.outcome = 'candidate';

    if not found then
      update app_private.notification_email_evaluations as evaluation
      set processing_status = 'stale',
          next_evaluation_at = null,
          reason_code = 'LATEST_STATE_SUPPRESSED',
          evaluated_at = p_as_of
      where evaluation.source_event_id = v_evaluation.source_event_id;
      continue;
    end if;

    v_source_expires_at := v_source_scheduled_at + interval '1 hour';
    if v_source_expires_at <= p_as_of then
      update app_private.notification_email_evaluations as evaluation
      set processing_status = 'expired',
          next_evaluation_at = null,
          reason_code = 'STALE_DELIVERY_WINDOW',
          evaluated_at = p_as_of
      where evaluation.source_event_id = v_evaluation.source_event_id;
      continue;
    end if;

    select
      preference.email,
      preference.quiet_start,
      preference.quiet_end,
      preference.timezone
    into
      v_email_enabled,
      v_quiet_start,
      v_quiet_end,
      v_preference_timezone
    from public.notification_preferences as preference
    where preference.auth_user_id = v_latest.recipient_user_id
      and preference.household_id = v_latest.household_id
      and preference.category = v_latest.notification_category;

    if not found then
      v_email_enabled := false;
      v_quiet_start := null;
      v_quiet_end := null;
      v_preference_timezone := v_latest.timezone;
    end if;

    if not v_email_enabled then
      update app_private.notification_email_evaluations as evaluation
      set processing_status = 'disabled',
          next_evaluation_at = null,
          reason_code = 'EMAIL_DISABLED',
          evaluated_at = p_as_of
      where evaluation.source_event_id = v_evaluation.source_event_id;
      continue;
    end if;

    select pg_catalog.lower(pg_catalog.btrim(authenticated.email))
    into v_recipient_email
    from auth.users as authenticated
    where authenticated.id = v_latest.recipient_user_id
      and authenticated.email is not null
      and authenticated.email_confirmed_at is not null
      and pg_catalog.char_length(pg_catalog.btrim(authenticated.email))
        between 3 and 320;

    if not found then
      update app_private.notification_email_evaluations as evaluation
      set processing_status = 'no_address',
          next_evaluation_at = null,
          reason_code = 'NO_CONFIRMED_EMAIL',
          evaluated_at = p_as_of
      where evaluation.source_event_id = v_evaluation.source_event_id;
      continue;
    end if;

    select delivery_window.*
    into v_delivery_window
    from app_private.resolve_notification_delivery_not_before(
      greatest(v_source_scheduled_at, p_as_of),
      v_quiet_start,
      v_quiet_end,
      v_preference_timezone
    ) as delivery_window;

    if v_delivery_window.delivery_not_before >= v_source_expires_at then
      update app_private.notification_email_evaluations as evaluation
      set processing_status = 'expired',
          next_evaluation_at = null,
          reason_code = 'STALE_DELIVERY_WINDOW',
          evaluated_at = p_as_of
      where evaluation.source_event_id = v_evaluation.source_event_id;
      continue;
    end if;

    if v_delivery_window.delivery_not_before > p_as_of then
      update app_private.notification_email_evaluations as evaluation
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
      and item.subject_id = v_latest.occurrence_id
      and item.cancelled_at is null
    limit 1;

    insert into app_private.notification_email_deliveries (
      source_event_id,
      inbox_item_id,
      recipient_user_id,
      recipient_member_id,
      household_id,
      category,
      subject_type,
      subject_id,
      processing_status,
      attempts,
      max_attempts,
      next_attempt_at,
      scheduled_at,
      expires_at,
      created_at,
      updated_at
    ) values (
      v_evaluation.source_event_id,
      v_inbox_item_id,
      v_latest.recipient_user_id,
      v_latest.recipient_member_id,
      v_latest.household_id,
      v_latest.notification_category,
      v_latest.subject_type,
      v_latest.occurrence_id,
      'pending',
      0,
      5,
      p_as_of,
      v_delivery_window.delivery_not_before,
      v_source_expires_at,
      p_as_of,
      p_as_of
    ) on conflict on constraint notification_email_deliveries_source_event_id_key
      do nothing;

    update app_private.notification_email_evaluations as evaluation
    set processing_status = 'materialized',
        next_evaluation_at = null,
        reason_code = null,
        evaluated_at = p_as_of
    where evaluation.source_event_id = v_evaluation.source_event_id;
  end loop;

  with changed as (
    update app_private.notification_email_deliveries as delivery
    set processing_status = 'failed',
        next_attempt_at = null,
        lease_owner = null,
        completed_lease_token = delivery.lease_token,
        lease_token = null,
        lease_expires_at = null,
        last_result_code = 'EMAIL_SUBMISSION_AMBIGUOUS',
        provider_message_id_hash = null,
        completion_outcome = 'ambiguous',
        completed_retry_after_seconds = null,
        updated_at = p_as_of,
        completed_at = p_as_of
    where delivery.processing_status = 'leased'
      and delivery.lease_expires_at <= p_as_of
      and delivery.submission_started_at is not null
    returning delivery.id, delivery.attempts
  )
  insert into app_private.notification_email_delivery_transitions (
    delivery_id,
    transition,
    attempt,
    result_code,
    occurred_at
  )
  select
    changed.id,
    'failed',
    changed.attempts,
    'EMAIL_SUBMISSION_AMBIGUOUS',
    p_as_of
  from changed;

  with changed as (
    update app_private.notification_email_deliveries as delivery
    set processing_status = 'failed',
        next_attempt_at = null,
        lease_owner = null,
        completed_lease_token = delivery.lease_token,
        lease_token = null,
        lease_expires_at = null,
        last_result_code = 'ATTEMPTS_EXHAUSTED',
        provider_message_id_hash = null,
        completion_outcome = 'retryable',
        completed_retry_after_seconds = 30,
        updated_at = p_as_of,
        completed_at = p_as_of
    where delivery.processing_status = 'leased'
      and delivery.lease_expires_at <= p_as_of
      and delivery.submission_started_at is null
      and delivery.attempts >= delivery.max_attempts
    returning delivery.id, delivery.attempts
  )
  insert into app_private.notification_email_delivery_transitions (
    delivery_id,
    transition,
    attempt,
    result_code,
    occurred_at
  )
  select changed.id, 'failed', changed.attempts, 'ATTEMPTS_EXHAUSTED', p_as_of
  from changed;

  for v_delivery in
    select delivery.*
    from app_private.notification_email_deliveries as delivery
    where delivery.processing_status = 'leased'
      and delivery.lease_expires_at <= p_as_of
      and delivery.submission_started_at is null
      and delivery.attempts < delivery.max_attempts
      and p_as_of + interval '30 seconds' >= delivery.expires_at
    order by delivery.lease_expires_at, delivery.created_at, delivery.id
    for update skip locked
  loop
    perform app_private.cancel_notification_email_delivery(
      v_delivery.id,
      'STALE_DELIVERY_WINDOW',
      p_as_of
    );
  end loop;

  with changed as (
    update app_private.notification_email_deliveries as delivery
    set processing_status = 'retry_wait',
        next_attempt_at = p_as_of + interval '30 seconds',
        lease_owner = null,
        completed_lease_token = delivery.lease_token,
        lease_token = null,
        lease_expires_at = null,
        submission_started_at = null,
        submission_lease_token = null,
        last_result_code = 'LEASE_EXPIRED',
        provider_message_id_hash = null,
        completion_outcome = 'retryable',
        completed_retry_after_seconds = 30,
        updated_at = p_as_of
    where delivery.processing_status = 'leased'
      and delivery.lease_expires_at <= p_as_of
      and delivery.submission_started_at is null
      and delivery.attempts < delivery.max_attempts
      and p_as_of + interval '30 seconds' < delivery.expires_at
    returning delivery.id, delivery.attempts
  )
  insert into app_private.notification_email_delivery_transitions (
    delivery_id,
    transition,
    attempt,
    result_code,
    occurred_at
  )
  select changed.id, 'retry_scheduled', changed.attempts, 'LEASE_EXPIRED', p_as_of
  from changed;

  for v_delivery in
    select delivery.*
    from app_private.notification_email_deliveries as delivery
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

    if v_delivery.expires_at <= p_as_of then
      perform app_private.cancel_notification_email_delivery(
        v_delivery.id,
        'STALE_DELIVERY_WINDOW',
        p_as_of
      );
      continue;
    end if;

    select latest.*
    into v_latest
    from app_private.resolve_chore_notification_event(
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
      perform app_private.cancel_notification_email_delivery(
        v_delivery.id,
        'LATEST_STATE_SUPPRESSED',
        p_as_of
      );
      continue;
    end if;

    select
      preference.email,
      preference.quiet_start,
      preference.quiet_end,
      preference.timezone
    into
      v_email_enabled,
      v_quiet_start,
      v_quiet_end,
      v_preference_timezone
    from public.notification_preferences as preference
    where preference.auth_user_id = v_delivery.recipient_user_id
      and preference.household_id = v_delivery.household_id
      and preference.category = v_delivery.category;

    if not found then
      v_email_enabled := false;
      v_quiet_start := null;
      v_quiet_end := null;
      v_preference_timezone := v_latest.timezone;
    end if;

    if not v_email_enabled then
      perform app_private.cancel_notification_email_delivery(
        v_delivery.id,
        'EMAIL_DISABLED',
        p_as_of
      );
      continue;
    end if;

    select
      pg_catalog.lower(pg_catalog.btrim(authenticated.email)),
      case when profile.locale in ('en', 'ko') then profile.locale else 'en' end
    into v_recipient_email, v_locale
    from auth.users as authenticated
    left join public.profiles as profile
      on profile.auth_user_id = authenticated.id
    where authenticated.id = v_delivery.recipient_user_id
      and authenticated.email is not null
      and authenticated.email_confirmed_at is not null
      and pg_catalog.char_length(pg_catalog.btrim(authenticated.email))
        between 3 and 320;

    if not found then
      perform app_private.cancel_notification_email_delivery(
        v_delivery.id,
        'NO_CONFIRMED_EMAIL',
        p_as_of
      );
      continue;
    end if;

    select resolution.scheduled_at
    into v_source_scheduled_at
    from app_private.notification_event_resolutions as resolution
    where resolution.source_event_id = v_delivery.source_event_id
      and resolution.outcome = 'candidate';

    if not found then
      perform app_private.cancel_notification_email_delivery(
        v_delivery.id,
        'LATEST_STATE_SUPPRESSED',
        p_as_of
      );
      continue;
    end if;

    v_source_expires_at := case
      when v_delivery.attempts = 0
        then v_source_scheduled_at + interval '1 hour'
      else v_delivery.expires_at
    end;

    select delivery_window.*
    into v_delivery_window
    from app_private.resolve_notification_delivery_not_before(
      greatest(v_source_scheduled_at, p_as_of),
      v_quiet_start,
      v_quiet_end,
      v_preference_timezone
    ) as delivery_window;

    if v_delivery_window.delivery_not_before >= v_source_expires_at then
      perform app_private.cancel_notification_email_delivery(
        v_delivery.id,
        'STALE_DELIVERY_WINDOW',
        p_as_of
      );
      continue;
    end if;

    if v_delivery_window.delivery_not_before > p_as_of then
      update app_private.notification_email_deliveries as delivery
      set scheduled_at = case
            when delivery.attempts = 0
              then v_delivery_window.delivery_not_before
            else delivery.scheduled_at
          end,
          expires_at = case
            when delivery.attempts = 0 then v_source_expires_at
            else delivery.expires_at
          end,
          next_attempt_at = v_delivery_window.delivery_not_before,
          updated_at = p_as_of
      where delivery.id = v_delivery.id;
      continue;
    end if;

    update app_private.notification_email_deliveries as delivery
    set processing_status = 'leased',
        attempts = delivery.attempts + 1,
        next_attempt_at = null,
        lease_owner = p_worker_id,
        lease_token = extensions.gen_random_uuid(),
        lease_expires_at = p_as_of
          + pg_catalog.make_interval(secs => p_lease_seconds),
        submission_started_at = null,
        submission_lease_token = null,
        last_result_code = null,
        provider_message_id_hash = null,
        completed_lease_token = null,
        completion_outcome = null,
        completed_retry_after_seconds = null,
        scheduled_at = case
          when delivery.attempts = 0
            then v_delivery_window.delivery_not_before
          else delivery.scheduled_at
        end,
        expires_at = case
          when delivery.attempts = 0 then v_source_expires_at
          else delivery.expires_at
        end,
        updated_at = p_as_of,
        completed_at = null
    where delivery.id = v_delivery.id
    returning delivery.* into v_delivery;

    insert into app_private.notification_email_delivery_transitions (
      delivery_id,
      transition,
      attempt,
      result_code,
      occurred_at
    ) values (
      v_delivery.id,
      'claimed',
      v_delivery.attempts,
      null,
      p_as_of
    );

    return query select
      v_delivery.id,
      v_delivery.source_event_id,
      v_delivery.inbox_item_id,
      v_delivery.household_id,
      v_delivery.category,
      v_delivery.subject_type,
      v_delivery.subject_id,
      v_recipient_email,
      coalesce(v_locale, 'en'),
      v_delivery.attempts,
      v_delivery.max_attempts,
      v_delivery.lease_token,
      v_delivery.lease_expires_at,
      v_delivery.scheduled_at,
      v_delivery.expires_at;
    v_claimed_count := v_claimed_count + 1;
  end loop;
end;
$$;

create or replace function public.mark_notification_email_submission_started(
  p_delivery_id uuid,
  p_lease_token uuid,
  p_as_of timestamptz
)
returns table (
  delivery_id uuid,
  submission_started_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_delivery app_private.notification_email_deliveries%rowtype;
begin
  if p_delivery_id is null
    or p_lease_token is null
    or p_as_of is null then
    raise exception using
      errcode = 'KEM01',
      message = 'invalid notification email input';
  end if;

  select delivery.*
  into v_delivery
  from app_private.notification_email_deliveries as delivery
  where delivery.id = p_delivery_id
  for update;

  if not found
    or v_delivery.processing_status <> 'leased'
    or v_delivery.lease_token <> p_lease_token
    or v_delivery.lease_expires_at <= p_as_of
    or v_delivery.expires_at <= p_as_of then
    raise exception using
      errcode = 'KEM03',
      message = 'notification email lease unavailable';
  end if;

  if v_delivery.submission_lease_token is not null
    and v_delivery.submission_lease_token <> p_lease_token then
    raise exception using
      errcode = 'KEM03',
      message = 'notification email lease unavailable';
  end if;

  if v_delivery.submission_started_at is null then
    update app_private.notification_email_deliveries as delivery
    set submission_started_at = p_as_of,
        submission_lease_token = p_lease_token,
        updated_at = greatest(delivery.updated_at, p_as_of)
    where delivery.id = v_delivery.id
    returning delivery.* into v_delivery;

    insert into app_private.notification_email_delivery_transitions (
      delivery_id,
      transition,
      attempt,
      result_code,
      occurred_at
    ) values (
      v_delivery.id,
      'submission_started',
      v_delivery.attempts,
      null,
      p_as_of
    );
  end if;

  return query select v_delivery.id, v_delivery.submission_started_at;
end;
$$;

create or replace function public.complete_notification_email_delivery(
  p_delivery_id uuid,
  p_lease_token uuid,
  p_outcome text,
  p_result_code text,
  p_provider_message_id_hash_base64 text,
  p_retry_after_seconds integer,
  p_as_of timestamptz
)
returns table (
  delivery_id uuid,
  processing_status text,
  attempts integer,
  max_attempts integer,
  next_attempt_at timestamptz,
  completed_at timestamptz,
  result_code text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_delivery app_private.notification_email_deliveries%rowtype;
  v_message_id_hash bytea;
  v_processing_status text;
  v_next_attempt_at timestamptz;
  v_completed_at timestamptz;
  v_transition text;
begin
  if p_delivery_id is null
    or p_lease_token is null
    or p_outcome not in ('accepted', 'retryable', 'permanent', 'ambiguous')
    or p_as_of is null
    or p_outcome = 'accepted' and (
      p_result_code <> 'EMAIL_ACCEPTED'
      or p_retry_after_seconds is not null
    )
    or p_outcome = 'retryable' and (
      p_result_code not in (
        'EMAIL_RATE_LIMITED',
        'EMAIL_PROVIDER_UNAVAILABLE',
        'EMAIL_PROVIDER_INTERNAL'
      )
      or p_provider_message_id_hash_base64 is not null
      or p_retry_after_seconds is null
      or p_retry_after_seconds not between 5 and 7200
    )
    or p_outcome = 'permanent' and (
      p_result_code not in (
        'EMAIL_REQUEST_REJECTED',
        'EMAIL_AUTH_REJECTED',
        'EMAIL_PAYLOAD_REJECTED'
      )
      or p_provider_message_id_hash_base64 is not null
      or p_retry_after_seconds is not null
    )
    or p_outcome = 'ambiguous' and (
      p_result_code <> 'EMAIL_SUBMISSION_AMBIGUOUS'
      or p_provider_message_id_hash_base64 is not null
      or p_retry_after_seconds is not null
    ) then
    raise exception using
      errcode = 'KEM01',
      message = 'invalid notification email input';
  end if;

  if p_provider_message_id_hash_base64 is not null then
    begin
      v_message_id_hash := pg_catalog.decode(
        p_provider_message_id_hash_base64,
        'base64'
      );
    exception when others then
      raise exception using
        errcode = 'KEM01',
        message = 'invalid notification email input';
    end;
    if pg_catalog.octet_length(v_message_id_hash) <> 32
      or pg_catalog.encode(v_message_id_hash, 'base64')
        <> p_provider_message_id_hash_base64 then
      raise exception using
        errcode = 'KEM01',
        message = 'invalid notification email input';
    end if;
  end if;

  select delivery.*
  into v_delivery
  from app_private.notification_email_deliveries as delivery
  where delivery.id = p_delivery_id
  for update;

  if not found then
    raise exception using
      errcode = 'KEM03',
      message = 'notification email lease unavailable';
  end if;

  if v_delivery.processing_status in ('retry_wait', 'succeeded', 'failed')
    and v_delivery.completed_lease_token = p_lease_token
    and v_delivery.completion_outcome = p_outcome
    and v_delivery.last_result_code = p_result_code
    and v_delivery.provider_message_id_hash
      is not distinct from v_message_id_hash
    and v_delivery.completed_retry_after_seconds
      is not distinct from p_retry_after_seconds then
    return query select
      v_delivery.id,
      v_delivery.processing_status,
      v_delivery.attempts,
      v_delivery.max_attempts,
      v_delivery.next_attempt_at,
      v_delivery.completed_at,
      v_delivery.last_result_code;
    return;
  end if;

  if v_delivery.processing_status <> 'leased'
    or v_delivery.lease_token <> p_lease_token
    or v_delivery.submission_started_at is not null
      and v_delivery.submission_lease_token <> p_lease_token
    or p_outcome <> 'retryable'
      and (
        v_delivery.submission_lease_token <> p_lease_token
        or v_delivery.submission_started_at is null
      ) then
    raise exception using
      errcode = 'KEM03',
      message = 'notification email lease unavailable';
  end if;

  if p_outcome = 'accepted' then
    v_processing_status := 'succeeded';
    v_next_attempt_at := null;
    v_completed_at := p_as_of;
    v_transition := 'succeeded';
  elsif p_outcome = 'retryable'
    and v_delivery.attempts < v_delivery.max_attempts
    and p_as_of + pg_catalog.make_interval(secs => p_retry_after_seconds)
      < v_delivery.expires_at then
    v_processing_status := 'retry_wait';
    v_next_attempt_at := p_as_of
      + pg_catalog.make_interval(secs => p_retry_after_seconds);
    v_completed_at := null;
    v_transition := 'retry_scheduled';
  else
    v_processing_status := 'failed';
    v_next_attempt_at := null;
    v_completed_at := p_as_of;
    v_transition := 'failed';
  end if;

  update app_private.notification_email_deliveries as delivery
  set processing_status = v_processing_status,
      next_attempt_at = v_next_attempt_at,
      lease_owner = null,
      completed_lease_token = p_lease_token,
      lease_token = null,
      lease_expires_at = null,
      submission_started_at = case
        when v_processing_status = 'retry_wait' then null
        else delivery.submission_started_at
      end,
      submission_lease_token = case
        when v_processing_status = 'retry_wait' then null
        else delivery.submission_lease_token
      end,
      last_result_code = p_result_code,
      provider_message_id_hash = v_message_id_hash,
      completion_outcome = p_outcome,
      completed_retry_after_seconds = p_retry_after_seconds,
      updated_at = greatest(p_as_of, delivery.created_at),
      completed_at = v_completed_at
  where delivery.id = v_delivery.id
  returning delivery.* into v_delivery;

  insert into app_private.notification_email_delivery_transitions (
    delivery_id,
    transition,
    attempt,
    result_code,
    occurred_at
  ) values (
    v_delivery.id,
    v_transition,
    v_delivery.attempts,
    p_result_code,
    p_as_of
  );

  return query select
    v_delivery.id,
    v_delivery.processing_status,
    v_delivery.attempts,
    v_delivery.max_attempts,
    v_delivery.next_attempt_at,
    v_delivery.completed_at,
    v_delivery.last_result_code;
end;
$$;

create or replace function public.set_notification_email_worker_paused(
  p_paused boolean,
  p_as_of timestamptz
)
returns table (
  paused boolean,
  reason_code text,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_paused is null or p_as_of is null then
    raise exception using
      errcode = 'KEM01',
      message = 'invalid notification email input';
  end if;

  update app_private.notification_email_worker_control as control
  set paused = p_paused,
      reason_code = case when p_paused then 'ROLLBACK_DISABLED' else null end,
      updated_at = greatest(control.updated_at, p_as_of)
  where control.worker_key = 'sendgrid_transactional';

  return query
  select control.paused, control.reason_code, control.updated_at
  from app_private.notification_email_worker_control as control
  where control.worker_key = 'sendgrid_transactional';
end;
$$;

revoke all on function public.claim_notification_email_deliveries(
  uuid,
  integer,
  integer,
  timestamptz
) from public, anon, authenticated;
revoke all on function public.mark_notification_email_submission_started(
  uuid,
  uuid,
  timestamptz
) from public, anon, authenticated;
revoke all on function public.complete_notification_email_delivery(
  uuid,
  uuid,
  text,
  text,
  text,
  integer,
  timestamptz
) from public, anon, authenticated;
revoke all on function public.set_notification_email_worker_paused(
  boolean,
  timestamptz
) from public, anon, authenticated;

grant execute on function public.claim_notification_email_deliveries(
  uuid,
  integer,
  integer,
  timestamptz
) to service_role;
grant execute on function public.mark_notification_email_submission_started(
  uuid,
  uuid,
  timestamptz
) to service_role;
grant execute on function public.complete_notification_email_delivery(
  uuid,
  uuid,
  text,
  text,
  text,
  integer,
  timestamptz
) to service_role;
grant execute on function public.set_notification_email_worker_paused(
  boolean,
  timestamptz
) to service_role;

comment on table app_private.notification_email_evaluations is
  'Content-free source evaluation for optional transactional email.';
comment on table app_private.notification_email_deliveries is
  'Address-free at-most-once transactional email queue.';
comment on function public.claim_notification_email_deliveries(
  uuid,
  integer,
  integer,
  timestamptz
) is
  'Service-only claim returning the confirmed email ephemerally for one send.';
