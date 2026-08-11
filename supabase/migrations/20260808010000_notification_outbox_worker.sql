-- KinFlow WP05-01 leased notification outbox worker.
-- The worker resolves content-free Chore events into durable routing
-- candidates or allowlisted suppressions. Inbox and provider delivery follow
-- in later Phase 05 work packages.

alter table app_private.chore_notification_outbox
  add column processing_status text not null default 'pending',
  add column max_attempts integer not null default 5,
  add column lease_owner uuid,
  add column lease_token uuid,
  add column lease_expires_at timestamptz,
  add column dead_lettered_at timestamptz,
  add column replay_count integer not null default 0;

-- Preserve any pre-worker dispatcher state while making the new lifecycle
-- explicit. The WP03 producer never wrote these fields, but the mapping keeps
-- the migration forward-compatible with a partially operated environment.
update app_private.chore_notification_outbox
set processing_status = 'succeeded',
    attempts = least(max_attempts, greatest(attempts, 1)),
    next_attempt_at = null,
    last_error_code = null
where dispatched_at is not null;

update app_private.chore_notification_outbox
set processing_status = 'dead_letter',
    attempts = max_attempts,
    next_attempt_at = null,
    last_error_code = coalesce(last_error_code, 'LEGACY_RETRY_EXHAUSTED'),
    dead_lettered_at = pg_catalog.statement_timestamp()
where dispatched_at is null
  and attempts >= max_attempts;

update app_private.chore_notification_outbox
set processing_status = 'retry_wait',
    attempts = greatest(attempts, 1),
    next_attempt_at = coalesce(next_attempt_at, pg_catalog.statement_timestamp())
where dispatched_at is null
  and processing_status <> 'dead_letter'
  and (
    next_attempt_at is not null
    or attempts > 0
    or last_error_code is not null
  );

alter table app_private.chore_notification_outbox
  add constraint chore_notification_outbox_processing_status_ck check (
    processing_status in (
      'pending',
      'leased',
      'retry_wait',
      'succeeded',
      'dead_letter'
    )
  ),
  add constraint chore_notification_outbox_max_attempts_ck check (
    max_attempts between 1 and 10
  ),
  add constraint chore_notification_outbox_replay_count_ck check (
    replay_count >= 0
  ),
  add constraint chore_notification_outbox_worker_state_ck check (
    case processing_status
      when 'pending' then
        dispatched_at is null
        and dead_lettered_at is null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and attempts = 0
        and last_error_code is null
      when 'leased' then
        dispatched_at is null
        and dead_lettered_at is null
        and lease_owner is not null
        and lease_token is not null
        and lease_expires_at is not null
        and next_attempt_at is null
        and attempts between 1 and max_attempts
        and last_error_code is null
      when 'retry_wait' then
        dispatched_at is null
        and dead_lettered_at is null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and next_attempt_at is not null
        and attempts between 1 and max_attempts - 1
        and last_error_code is not null
      when 'succeeded' then
        dispatched_at is not null
        and dead_lettered_at is null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and next_attempt_at is null
        and attempts between 1 and max_attempts
        and last_error_code is null
      when 'dead_letter' then
        dispatched_at is null
        and dead_lettered_at is not null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and next_attempt_at is null
        and attempts = max_attempts
        and last_error_code is not null
      else false
    end
  );

create index chore_notification_outbox_worker_ready_idx
  on app_private.chore_notification_outbox(
    processing_status,
    next_attempt_at,
    lease_expires_at,
    occurred_at,
    event_id
  )
  where processing_status in ('pending', 'retry_wait', 'leased');

create table app_private.notification_event_resolutions (
  source_event_id uuid primary key
    references app_private.chore_notification_outbox(event_id)
    on delete cascade,
  outcome text not null check (outcome in ('candidate', 'suppressed')),
  household_id uuid not null
    references public.households(id) on delete cascade,
  notification_category text not null check (
    notification_category in ('chore_due', 'chore_assignment')
  ),
  subject_type text not null check (subject_type = 'chore_occurrence'),
  subject_id uuid not null,
  recipient_member_id uuid,
  recipient_user_id uuid references auth.users(id) on delete set null,
  scheduled_at timestamptz,
  timezone text not null check (
    app_private.is_valid_iana_timezone(timezone)
  ),
  suppression_reason text check (
    suppression_reason is null
    or suppression_reason in (
      'stale_event',
      'inactive_series',
      'occurrence_not_scheduled',
      'inactive_recipient',
      'schedule_unresolved'
    )
  ),
  resolved_at timestamptz not null,
  constraint notification_event_resolution_subject_fk
    foreign key (household_id, subject_id)
    references public.chore_occurrences(household_id, id)
    on delete cascade,
  constraint notification_event_resolution_recipient_fk
    foreign key (household_id, recipient_member_id)
    references public.household_members(household_id, id),
  constraint notification_event_resolution_outcome_ck check (
    (
      outcome = 'candidate'
      and recipient_member_id is not null
      and recipient_user_id is not null
      and scheduled_at is not null
      and suppression_reason is null
    )
    or (
      outcome = 'suppressed'
      and recipient_member_id is null
      and recipient_user_id is null
      and scheduled_at is null
      and suppression_reason is not null
    )
  )
);

create table app_private.notification_worker_transitions (
  id uuid primary key default extensions.gen_random_uuid(),
  source_event_id uuid not null
    references app_private.chore_notification_outbox(event_id)
    on delete cascade,
  transition text not null check (
    transition in (
      'claimed',
      'retry_scheduled',
      'succeeded',
      'dead_lettered',
      'replayed'
    )
  ),
  worker_id uuid,
  attempt integer not null check (attempt >= 0),
  error_code text check (
    error_code is null
    or error_code ~ '^[A-Z][A-Z0-9_]{0,63}$'
  ),
  occurred_at timestamptz not null,
  constraint notification_worker_transition_error_ck check (
    (
      transition in ('claimed', 'succeeded')
      and error_code is null
    )
    or (
      transition in ('retry_scheduled', 'dead_lettered', 'replayed')
      and error_code is not null
    )
  )
);

create index notification_worker_transitions_event_time_idx
  on app_private.notification_worker_transitions(
    source_event_id,
    occurred_at,
    id
  );

create table app_private.notification_worker_control (
  worker_key text primary key check (
    worker_key = 'chore_notification_outbox'
  ),
  paused boolean not null default false,
  reason_code text check (
    reason_code is null
    or reason_code ~ '^[A-Z][A-Z0-9_]{0,63}$'
  ),
  updated_at timestamptz not null,
  constraint notification_worker_control_reason_ck check (
    paused = (reason_code is not null)
  )
);

insert into app_private.notification_worker_control (
  worker_key,
  paused,
  reason_code,
  updated_at
)
values (
  'chore_notification_outbox',
  false,
  null,
  pg_catalog.statement_timestamp()
);

revoke all on table app_private.notification_event_resolutions
  from public, anon, authenticated, service_role;
revoke all on table app_private.notification_worker_transitions
  from public, anon, authenticated, service_role;
revoke all on table app_private.notification_worker_control
  from public, anon, authenticated, service_role;

create or replace function app_private.reject_notification_worker_transition_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'notification worker transitions are immutable';
end;
$$;

revoke all on function app_private.reject_notification_worker_transition_mutation()
  from public, anon, authenticated, service_role;

create trigger notification_worker_transitions_immutable
before update or delete on app_private.notification_worker_transitions
for each row execute function
  app_private.reject_notification_worker_transition_mutation();

create or replace function app_private.notification_retry_delay(
  p_event_id uuid,
  p_attempt integer
)
returns interval
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.make_interval(
    secs => least(
      3600,
      30 * pg_catalog.power(2, least(greatest(p_attempt - 1, 0), 7))::integer
    ) + (
      pg_catalog.get_byte(
        pg_catalog.decode(
          pg_catalog.md5(p_event_id::text || ':' || p_attempt::text),
          'hex'
        ),
        0
      ) % 16
    )
  )
$$;

revoke all on function app_private.notification_retry_delay(uuid, integer)
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
          'leased',
          'retry_wait',
          'succeeded',
          'dead_letter'
        )
      or v_is_replay
    ) then
    raise exception using
      errcode = '55000',
      message = 'chore notification outbox transition is invalid';
  end if;

  return new;
end;
$$;

revoke all on function app_private.protect_chore_notification_outbox()
  from public, anon, authenticated, service_role;

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
declare
  v_paused boolean;
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

  select control.paused
  into v_paused
  from app_private.notification_worker_control as control
  where control.worker_key = 'chore_notification_outbox';

  if coalesce(v_paused, true) then
    return;
  end if;

  with expired_final as (
    select event.event_id
    from app_private.chore_notification_outbox as event
    where event.processing_status = 'leased'
      and event.lease_expires_at <= p_as_of
      and event.attempts = event.max_attempts
    order by event.lease_expires_at, event.occurred_at, event.event_id
    for update skip locked
    limit p_batch_size
  ), dead_lettered as (
    update app_private.chore_notification_outbox as event
    set processing_status = 'dead_letter',
        lease_owner = null,
        lease_token = null,
        lease_expires_at = null,
        next_attempt_at = null,
        last_error_code = 'LEASE_EXPIRED',
        dead_lettered_at = p_as_of
    from expired_final
    where event.event_id = expired_final.event_id
    returning event.event_id, event.attempts
  )
  insert into app_private.notification_worker_transitions (
    source_event_id,
    transition,
    worker_id,
    attempt,
    error_code,
    occurred_at
  )
  select
    dead_lettered.event_id,
    'dead_lettered',
    null,
    dead_lettered.attempts,
    'LEASE_EXPIRED',
    p_as_of
  from dead_lettered;

  return query
  with candidates as (
    select event.event_id
    from app_private.chore_notification_outbox as event
    where event.attempts < event.max_attempts
      and (
        event.processing_status = 'pending'
        and coalesce(event.next_attempt_at, event.occurred_at) <= p_as_of
        or event.processing_status = 'retry_wait'
        and event.next_attempt_at <= p_as_of
        or event.processing_status = 'leased'
        and event.lease_expires_at <= p_as_of
      )
    order by
      case event.processing_status
        when 'leased' then event.lease_expires_at
        else coalesce(event.next_attempt_at, event.occurred_at)
      end,
      event.occurred_at,
      event.event_id
    for update skip locked
    limit p_batch_size
  ), claimed as (
    update app_private.chore_notification_outbox as event
    set processing_status = 'leased',
        attempts = event.attempts + 1,
        next_attempt_at = null,
        last_error_code = null,
        lease_owner = p_worker_id,
        lease_token = extensions.gen_random_uuid(),
        lease_expires_at = p_as_of
          + pg_catalog.make_interval(secs => p_lease_seconds),
        dead_lettered_at = null
    from candidates
    where event.event_id = candidates.event_id
    returning
      event.event_id,
      event.lease_token,
      event.attempts,
      event.max_attempts,
      event.lease_expires_at
  ), audited as (
    insert into app_private.notification_worker_transitions (
      source_event_id,
      transition,
      worker_id,
      attempt,
      error_code,
      occurred_at
    )
    select
      claimed.event_id,
      'claimed',
      p_worker_id,
      claimed.attempts,
      null,
      p_as_of
    from claimed
    returning source_event_id
  )
  select
    claimed.event_id,
    claimed.lease_token,
    claimed.attempts,
    claimed.max_attempts,
    claimed.lease_expires_at
  from claimed
  join audited on audited.source_event_id = claimed.event_id
  order by claimed.event_id;
end;
$$;

create or replace function public.heartbeat_chore_notification_event(
  p_event_id uuid,
  p_lease_token uuid,
  p_extend_seconds integer,
  p_as_of timestamptz
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lease_expires_at timestamptz;
begin
  if p_event_id is null
    or p_lease_token is null
    or p_extend_seconds is null
    or p_extend_seconds not between 5 and 300
    or p_as_of is null then
    raise exception using
      errcode = 'KFN01',
      message = 'invalid notification worker input';
  end if;

  update app_private.chore_notification_outbox as event
  set lease_expires_at = least(
    greatest(event.lease_expires_at, p_as_of)
      + pg_catalog.make_interval(secs => p_extend_seconds),
    p_as_of + interval '5 minutes'
  )
  where event.event_id = p_event_id
    and event.processing_status = 'leased'
    and event.lease_token = p_lease_token
    and event.lease_expires_at > p_as_of
  returning event.lease_expires_at into v_lease_expires_at;

  if not found then
    raise exception using
      errcode = 'KFN03',
      message = 'notification lease not found or expired';
  end if;

  return v_lease_expires_at;
end;
$$;

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
  from app_private.resolve_chore_notification_event(p_event_id) as resolved;

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
    recipient_member_id,
    recipient_user_id,
    scheduled_at,
    timezone,
    suppression_reason,
    resolved_at
  )
  values (
    p_event_id,
    case
      when v_resolution.should_create_intent then 'candidate'
      else 'suppressed'
    end,
    v_resolution.household_id,
    v_resolution.notification_category,
    v_resolution.subject_type,
    v_resolution.occurrence_id,
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
      when v_resolution.notification_category = 'chore_due'
        then v_resolution.due_at
      else v_resolution.event_occurred_at
    end,
    v_resolution.timezone,
    case
      when v_resolution.should_create_intent then null
      else v_resolution.suppression_reason
    end,
    p_as_of
  )
  on conflict on constraint notification_event_resolutions_pkey do nothing;

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
  )
  values (
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

create or replace function public.fail_chore_notification_event(
  p_event_id uuid,
  p_lease_token uuid,
  p_error_code text,
  p_as_of timestamptz
)
returns table (
  event_id uuid,
  processing_status text,
  attempts integer,
  max_attempts integer,
  next_attempt_at timestamptz,
  dead_lettered_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event app_private.chore_notification_outbox%rowtype;
  v_next_attempt_at timestamptz;
  v_dead_lettered_at timestamptz;
  v_status text;
begin
  if p_event_id is null
    or p_lease_token is null
    or p_error_code is null
    or p_error_code !~ '^[A-Z][A-Z0-9_]{0,63}$'
    or p_as_of is null then
    raise exception using
      errcode = 'KFN01',
      message = 'invalid notification worker input';
  end if;

  select event.*
  into v_event
  from app_private.chore_notification_outbox as event
  where event.event_id = p_event_id
  for update;

  if not found
    or v_event.processing_status <> 'leased'
    or v_event.lease_token <> p_lease_token
    or v_event.lease_expires_at <= p_as_of then
    raise exception using
      errcode = 'KFN03',
      message = 'notification lease not found or expired';
  end if;

  if v_event.attempts >= v_event.max_attempts then
    v_status := 'dead_letter';
    v_next_attempt_at := null;
    v_dead_lettered_at := p_as_of;
  else
    v_status := 'retry_wait';
    v_next_attempt_at := p_as_of
      + app_private.notification_retry_delay(
        v_event.event_id,
        v_event.attempts
      );
    v_dead_lettered_at := null;
  end if;

  update app_private.chore_notification_outbox as event
  set processing_status = v_status,
      next_attempt_at = v_next_attempt_at,
      last_error_code = p_error_code,
      lease_owner = null,
      lease_token = null,
      lease_expires_at = null,
      dead_lettered_at = v_dead_lettered_at
  where event.event_id = p_event_id;

  insert into app_private.notification_worker_transitions (
    source_event_id,
    transition,
    worker_id,
    attempt,
    error_code,
    occurred_at
  )
  values (
    p_event_id,
    case
      when v_status = 'dead_letter' then 'dead_lettered'
      else 'retry_scheduled'
    end,
    v_event.lease_owner,
    v_event.attempts,
    p_error_code,
    p_as_of
  );

  return query
  select
    outbox.event_id,
    outbox.processing_status,
    outbox.attempts,
    outbox.max_attempts,
    outbox.next_attempt_at,
    outbox.dead_lettered_at
  from app_private.chore_notification_outbox as outbox
  where outbox.event_id = p_event_id;
end;
$$;

create or replace function public.replay_chore_notification_dead_letter(
  p_event_id uuid,
  p_reason_code text,
  p_as_of timestamptz
)
returns table (
  event_id uuid,
  processing_status text,
  replay_count integer,
  next_attempt_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempt integer;
begin
  if p_event_id is null
    or p_reason_code is null
    or p_reason_code !~ '^[A-Z][A-Z0-9_]{0,63}$'
    or p_as_of is null then
    raise exception using
      errcode = 'KFN01',
      message = 'invalid notification worker input';
  end if;

  select event.attempts
  into v_attempt
  from app_private.chore_notification_outbox as event
  where event.event_id = p_event_id
    and event.processing_status = 'dead_letter'
  for update;

  if not found then
    raise exception using
      errcode = 'KFN05',
      message = 'notification event is not replayable';
  end if;

  update app_private.chore_notification_outbox as event
  set processing_status = 'pending',
      attempts = 0,
      next_attempt_at = p_as_of,
      last_error_code = null,
      lease_owner = null,
      lease_token = null,
      lease_expires_at = null,
      dead_lettered_at = null,
      replay_count = event.replay_count + 1
  where event.event_id = p_event_id;

  insert into app_private.notification_worker_transitions (
    source_event_id,
    transition,
    worker_id,
    attempt,
    error_code,
    occurred_at
  )
  values (
    p_event_id,
    'replayed',
    null,
    v_attempt,
    p_reason_code,
    p_as_of
  );

  return query
  select
    outbox.event_id,
    outbox.processing_status,
    outbox.replay_count,
    outbox.next_attempt_at
  from app_private.chore_notification_outbox as outbox
  where outbox.event_id = p_event_id;
end;
$$;

create or replace function public.set_chore_notification_worker_paused(
  p_paused boolean,
  p_reason_code text,
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
  if p_paused is null
    or p_as_of is null
    or p_paused and (
      p_reason_code is null
      or p_reason_code !~ '^[A-Z][A-Z0-9_]{0,63}$'
    )
    or not p_paused and p_reason_code is not null then
    raise exception using
      errcode = 'KFN01',
      message = 'invalid notification worker input';
  end if;

  update app_private.notification_worker_control as control
  set paused = p_paused,
      reason_code = p_reason_code,
      updated_at = p_as_of
  where control.worker_key = 'chore_notification_outbox';

  return query
  select control.paused, control.reason_code, control.updated_at
  from app_private.notification_worker_control as control
  where control.worker_key = 'chore_notification_outbox';
end;
$$;

create or replace function public.get_chore_notification_queue_health(
  p_as_of timestamptz
)
returns table (
  captured_at timestamptz,
  paused boolean,
  pause_reason_code text,
  pending_count bigint,
  leased_count bigint,
  retry_wait_count bigint,
  succeeded_count bigint,
  dead_letter_count bigint,
  ready_count bigint,
  expired_lease_count bigint,
  oldest_ready_at timestamptz,
  next_retry_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_as_of is null then
    raise exception using
      errcode = 'KFN01',
      message = 'invalid notification worker input';
  end if;

  return query
  select
    p_as_of,
    control.paused,
    control.reason_code,
    count(*) filter (where event.processing_status = 'pending'),
    count(*) filter (where event.processing_status = 'leased'),
    count(*) filter (where event.processing_status = 'retry_wait'),
    count(*) filter (where event.processing_status = 'succeeded'),
    count(*) filter (where event.processing_status = 'dead_letter'),
    count(*) filter (
      where event.attempts < event.max_attempts
        and (
          event.processing_status = 'pending'
          and coalesce(event.next_attempt_at, event.occurred_at) <= p_as_of
          or event.processing_status = 'retry_wait'
          and event.next_attempt_at <= p_as_of
          or event.processing_status = 'leased'
          and event.lease_expires_at <= p_as_of
        )
    ),
    count(*) filter (
      where event.processing_status = 'leased'
        and event.lease_expires_at <= p_as_of
    ),
    min(
      case
        when event.attempts < event.max_attempts
          and event.processing_status = 'pending'
          and coalesce(event.next_attempt_at, event.occurred_at) <= p_as_of
          then coalesce(event.next_attempt_at, event.occurred_at)
        when event.attempts < event.max_attempts
          and event.processing_status = 'retry_wait'
          and event.next_attempt_at <= p_as_of
          then event.next_attempt_at
        when event.attempts < event.max_attempts
          and event.processing_status = 'leased'
          and event.lease_expires_at <= p_as_of
          then event.lease_expires_at
        else null
      end
    ),
    min(event.next_attempt_at) filter (
      where event.processing_status = 'retry_wait'
        and event.next_attempt_at > p_as_of
    )
  from app_private.notification_worker_control as control
  left join app_private.chore_notification_outbox as event on true
  where control.worker_key = 'chore_notification_outbox'
  group by control.paused, control.reason_code;
end;
$$;

revoke all on function public.claim_chore_notification_events(
  uuid,
  integer,
  integer,
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.heartbeat_chore_notification_event(
  uuid,
  uuid,
  integer,
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.process_chore_notification_event(
  uuid,
  uuid,
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.fail_chore_notification_event(
  uuid,
  uuid,
  text,
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.replay_chore_notification_dead_letter(
  uuid,
  text,
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.set_chore_notification_worker_paused(
  boolean,
  text,
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.get_chore_notification_queue_health(
  timestamptz
) from public, anon, authenticated, service_role;

grant execute on function public.claim_chore_notification_events(
  uuid,
  integer,
  integer,
  timestamptz
) to service_role;
grant execute on function public.heartbeat_chore_notification_event(
  uuid,
  uuid,
  integer,
  timestamptz
) to service_role;
grant execute on function public.process_chore_notification_event(
  uuid,
  uuid,
  timestamptz
) to service_role;
grant execute on function public.fail_chore_notification_event(
  uuid,
  uuid,
  text,
  timestamptz
) to service_role;
grant execute on function public.replay_chore_notification_dead_letter(
  uuid,
  text,
  timestamptz
) to service_role;
grant execute on function public.set_chore_notification_worker_paused(
  boolean,
  text,
  timestamptz
) to service_role;
grant execute on function public.get_chore_notification_queue_health(
  timestamptz
) to service_role;

comment on table app_private.notification_event_resolutions is
  'WP05-01 durable content-free candidate or suppression per source event.';
comment on table app_private.notification_worker_transitions is
  'WP05-01 immutable content-free lease/retry/dead-letter transition audit.';
comment on table app_private.notification_worker_control is
  'WP05-01 server worker pause control; no client or direct service-role access.';
