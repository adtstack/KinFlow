-- KinFlow WP05-04 Android FCM delivery lifecycle.
-- Provider delivery is independently materialized from the content-free
-- latest-state resolution so native_push remains functional when in_app is
-- disabled. An inbox item is linked when present, but is never required.

create table app_private.notification_push_evaluations (
  source_event_id uuid primary key
    references app_private.notification_event_resolutions(source_event_id)
    on delete cascade,
  processing_status text not null check (
    processing_status in (
      'pending',
      'materialized',
      'disabled',
      'stale',
      'no_endpoint'
    )
  ),
  next_evaluation_at timestamptz,
  reason_code text check (
    reason_code is null
    or reason_code in (
      'NATIVE_PUSH_DISABLED',
      'LATEST_STATE_SUPPRESSED',
      'NO_ACTIVE_ANDROID_ENDPOINT'
    )
  ),
  created_at timestamptz not null,
  evaluated_at timestamptz,
  constraint notification_push_evaluation_state_ck check (
    (
      processing_status = 'pending'
      and next_evaluation_at is not null
      and reason_code is null
      and evaluated_at is null
    )
    or (
      processing_status = 'materialized'
      and next_evaluation_at is null
      and reason_code is null
      and evaluated_at is not null
    )
    or (
      processing_status = 'disabled'
      and next_evaluation_at is null
      and reason_code = 'NATIVE_PUSH_DISABLED'
      and evaluated_at is not null
    )
    or (
      processing_status = 'stale'
      and next_evaluation_at is null
      and reason_code = 'LATEST_STATE_SUPPRESSED'
      and evaluated_at is not null
    )
    or (
      processing_status = 'no_endpoint'
      and next_evaluation_at is null
      and reason_code = 'NO_ACTIVE_ANDROID_ENDPOINT'
      and evaluated_at is not null
    )
  )
);

create index notification_push_evaluations_ready_idx
  on app_private.notification_push_evaluations(
    processing_status,
    next_evaluation_at,
    source_event_id
  )
  where processing_status = 'pending';

create table app_private.notification_push_deliveries (
  id uuid primary key default extensions.gen_random_uuid(),
  source_event_id uuid not null
    references app_private.notification_push_evaluations(source_event_id)
    on delete cascade,
  inbox_item_id uuid
    references public.notification_inbox_items(id)
    on delete set null,
  endpoint_id uuid not null
    references public.notification_endpoints(id)
    on delete cascade,
  recipient_user_id uuid not null
    references auth.users(id) on delete cascade,
  recipient_member_id uuid not null,
  household_id uuid not null
    references public.households(id) on delete cascade,
  category text not null check (
    category in ('chore_due', 'chore_assignment')
  ),
  subject_type text not null check (subject_type = 'chore_occurrence'),
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
  last_result_code text check (
    last_result_code is null
    or last_result_code in (
      'FCM_ACCEPTED',
      'FCM_UNAVAILABLE',
      'FCM_INTERNAL',
      'FCM_QUOTA_EXCEEDED',
      'FCM_TIMEOUT',
      'FCM_UNKNOWN',
      'FCM_UNREGISTERED',
      'FCM_INVALID_ARGUMENT',
      'FCM_SENDER_ID_MISMATCH',
      'FCM_THIRD_PARTY_AUTH_ERROR',
      'TOKEN_DECRYPTION_FAILED',
      'ENDPOINT_MATERIAL_CHANGED',
      'ATTEMPTS_EXHAUSTED',
      'LEASE_EXPIRED',
      'NATIVE_PUSH_DISABLED',
      'LATEST_STATE_SUPPRESSED',
      'ENDPOINT_INACTIVE',
      'ROLLBACK_DISABLED'
    )
  ),
  provider_receipt_hash bytea check (
    provider_receipt_hash is null
    or octet_length(provider_receipt_hash) = 32
  ),
  completed_lease_token uuid,
  completed_token_fingerprint bytea check (
    completed_token_fingerprint is null
    or octet_length(completed_token_fingerprint) = 32
  ),
  completion_outcome text check (
    completion_outcome is null
    or completion_outcome in (
      'accepted',
      'retryable',
      'invalid_token',
      'permanent'
    )
  ),
  completed_retry_after_seconds integer check (
    completed_retry_after_seconds is null
    or completed_retry_after_seconds between 5 and 3600
  ),
  endpoint_invalidated boolean not null default false,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  completed_at timestamptz,
  unique (source_event_id, endpoint_id),
  constraint notification_push_delivery_recipient_fk
    foreign key (household_id, recipient_member_id, recipient_user_id)
    references public.household_members(household_id, id, auth_user_id),
  constraint notification_push_delivery_subject_fk
    foreign key (household_id, subject_id)
    references public.chore_occurrences(household_id, id)
    on delete cascade,
  constraint notification_push_delivery_timestamps_ck check (
    updated_at >= created_at
    and (completed_at is null or completed_at >= created_at)
  ),
  constraint notification_push_delivery_state_ck check (
    case processing_status
      when 'pending' then
        attempts = 0
        and next_attempt_at is not null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and completed_at is null
        and last_result_code is null
        and provider_receipt_hash is null
      when 'leased' then
        attempts between 1 and max_attempts
        and next_attempt_at is null
        and lease_owner is not null
        and lease_token is not null
        and lease_expires_at is not null
        and completed_at is null
        and last_result_code is null
        and provider_receipt_hash is null
        and completed_lease_token is null
        and completed_token_fingerprint is null
        and completion_outcome is null
        and completed_retry_after_seconds is null
        and not endpoint_invalidated
      when 'retry_wait' then
        attempts between 1 and max_attempts - 1
        and next_attempt_at is not null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and completed_at is null
        and last_result_code is not null
        and provider_receipt_hash is null
        and completed_lease_token is not null
        and completed_token_fingerprint is not null
        and completion_outcome in ('retryable', 'invalid_token')
        and not endpoint_invalidated
      when 'succeeded' then
        attempts between 1 and max_attempts
        and next_attempt_at is null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and completed_at is not null
        and last_result_code = 'FCM_ACCEPTED'
        and provider_receipt_hash is not null
        and completed_lease_token is not null
        and completed_token_fingerprint is not null
        and completion_outcome = 'accepted'
        and completed_retry_after_seconds is null
        and not endpoint_invalidated
      when 'failed' then
        attempts between 1 and max_attempts
        and next_attempt_at is null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and completed_at is not null
        and last_result_code is not null
        and provider_receipt_hash is null
        and completed_lease_token is not null
        and completed_token_fingerprint is not null
        and completion_outcome in (
          'retryable',
          'invalid_token',
          'permanent'
        )
      when 'cancelled' then
        next_attempt_at is null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and completed_at is not null
        and last_result_code in (
          'NATIVE_PUSH_DISABLED',
          'LATEST_STATE_SUPPRESSED',
          'ENDPOINT_INACTIVE',
          'ROLLBACK_DISABLED'
        )
        and provider_receipt_hash is null
        and not endpoint_invalidated
      else false
    end
  )
);

create index notification_push_deliveries_ready_idx
  on app_private.notification_push_deliveries(
    processing_status,
    next_attempt_at,
    lease_expires_at,
    created_at,
    id
  )
  where processing_status in ('pending', 'retry_wait', 'leased');

create index notification_push_deliveries_recipient_idx
  on app_private.notification_push_deliveries(
    recipient_user_id,
    household_id,
    created_at desc,
    id
  );

create table app_private.notification_push_worker_control (
  worker_key text primary key check (worker_key = 'android_fcm_push'),
  paused boolean not null default false,
  reason_code text check (
    reason_code is null or reason_code = 'ROLLBACK_DISABLED'
  ),
  updated_at timestamptz not null,
  constraint notification_push_worker_control_state_ck check (
    paused = (reason_code is not null)
  )
);

insert into app_private.notification_push_worker_control (
  worker_key,
  paused,
  reason_code,
  updated_at
) values (
  'android_fcm_push',
  false,
  null,
  pg_catalog.statement_timestamp()
);

revoke all on table app_private.notification_push_evaluations
  from public, anon, authenticated, service_role;
revoke all on table app_private.notification_push_deliveries
  from public, anon, authenticated, service_role;
revoke all on table app_private.notification_push_worker_control
  from public, anon, authenticated, service_role;

create or replace function app_private.wake_notification_push_evaluations()
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

  update app_private.notification_push_evaluations as evaluation
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
  return null;
end;
$$;

revoke all on function app_private.wake_notification_push_evaluations()
  from public, anon, authenticated, service_role;

create trigger notification_preferences_wake_push_evaluations
after insert or update or delete on public.notification_preferences
for each row execute function
  app_private.wake_notification_push_evaluations();

create or replace function app_private.cancel_notification_push_delivery(
  p_delivery_id uuid,
  p_result_code text,
  p_as_of timestamptz
)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if p_delivery_id is null
    or p_result_code not in (
      'NATIVE_PUSH_DISABLED',
      'LATEST_STATE_SUPPRESSED',
      'ENDPOINT_INACTIVE',
      'ROLLBACK_DISABLED'
    )
    or p_as_of is null then
    raise exception using
      errcode = 'KPS01',
      message = 'invalid notification push input';
  end if;

  update app_private.notification_push_deliveries as delivery
  set processing_status = 'cancelled',
      next_attempt_at = null,
      lease_owner = null,
      lease_token = null,
      lease_expires_at = null,
      last_result_code = p_result_code,
      provider_receipt_hash = null,
      completed_retry_after_seconds = null,
      endpoint_invalidated = false,
      updated_at = p_as_of,
      completed_at = p_as_of
  where delivery.id = p_delivery_id
    and delivery.processing_status in ('pending', 'retry_wait', 'leased');
end;
$$;

revoke all on function app_private.cancel_notification_push_delivery(
  uuid,
  text,
  timestamptz
) from public, anon, authenticated, service_role;

create or replace function public.claim_notification_push_deliveries(
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
    from app_private.resolve_chore_notification_event(
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
      when v_latest.notification_category = 'chore_due'
        then v_latest.due_at
      else v_latest.event_occurred_at
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
      'chore_occurrence',
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
    from app_private.resolve_chore_notification_event(
      v_delivery.source_event_id
    ) as latest;

    if not found
      or not v_latest.should_create_intent
      or v_latest.recipient_user_id <> v_delivery.recipient_user_id
      or v_latest.recipient_member_id <> v_delivery.recipient_member_id
      or v_latest.household_id <> v_delivery.household_id
      or v_latest.notification_category <> v_delivery.category
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
      when v_latest.notification_category = 'chore_due'
        then v_latest.due_at
      else v_latest.event_occurred_at
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

create or replace function public.complete_notification_push_delivery(
  p_delivery_id uuid,
  p_lease_token uuid,
  p_token_fingerprint_base64 text,
  p_outcome text,
  p_result_code text,
  p_provider_receipt_hash_base64 text,
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
  result_code text,
  endpoint_invalidated boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_delivery app_private.notification_push_deliveries%rowtype;
  v_token_fingerprint bytea;
  v_receipt_hash bytea;
  v_endpoint_fingerprint bytea;
  v_endpoint_invalidated boolean := false;
  v_invalidation_count integer := 0;
  v_status text;
  v_result_code text;
  v_next_attempt_at timestamptz;
  v_completed_at timestamptz;
begin
  if p_delivery_id is null
    or p_lease_token is null
    or p_outcome not in (
      'accepted',
      'retryable',
      'invalid_token',
      'permanent'
    )
    or p_as_of is null
    or p_outcome = 'accepted' and (
      p_result_code <> 'FCM_ACCEPTED'
      or p_provider_receipt_hash_base64 is null
      or p_retry_after_seconds is not null
    )
    or p_outcome = 'retryable' and (
      p_result_code not in (
        'FCM_UNAVAILABLE',
        'FCM_INTERNAL',
        'FCM_QUOTA_EXCEEDED',
        'FCM_TIMEOUT',
        'FCM_UNKNOWN'
      )
      or p_provider_receipt_hash_base64 is not null
      or p_retry_after_seconds not between 5 and 3600
    )
    or p_outcome = 'invalid_token' and (
      p_result_code not in ('FCM_UNREGISTERED', 'FCM_INVALID_ARGUMENT')
      or p_provider_receipt_hash_base64 is not null
      or p_retry_after_seconds is not null
    )
    or p_outcome = 'permanent' and (
      p_result_code not in (
        'FCM_SENDER_ID_MISMATCH',
        'FCM_THIRD_PARTY_AUTH_ERROR',
        'TOKEN_DECRYPTION_FAILED'
      )
      or p_provider_receipt_hash_base64 is not null
      or p_retry_after_seconds is not null
    ) then
    raise exception using
      errcode = 'KPS01',
      message = 'invalid notification push input';
  end if;

  v_token_fingerprint := app_private.decode_notification_endpoint_material(
    p_token_fingerprint_base64,
    32,
    null,
    null
  );
  if p_provider_receipt_hash_base64 is not null then
    v_receipt_hash := app_private.decode_notification_endpoint_material(
      p_provider_receipt_hash_base64,
      32,
      null,
      null
    );
  end if;

  select delivery.*
  into v_delivery
  from app_private.notification_push_deliveries as delivery
  where delivery.id = p_delivery_id
  for update;

  if not found then
    raise exception using
      errcode = 'KPS03',
      message = 'notification push lease unavailable';
  end if;

  if v_delivery.processing_status <> 'leased'
    and not (
      v_delivery.last_result_code in ('LEASE_EXPIRED', 'ATTEMPTS_EXHAUSTED')
      and v_delivery.completed_lease_token = p_lease_token
    ) then
    if v_delivery.completed_lease_token = p_lease_token
      and v_delivery.completed_token_fingerprint = v_token_fingerprint
      and v_delivery.completion_outcome = p_outcome
      and (
        v_delivery.last_result_code = p_result_code
        or v_delivery.last_result_code = 'ENDPOINT_MATERIAL_CHANGED'
          and p_outcome = 'invalid_token'
        or v_delivery.last_result_code = 'ATTEMPTS_EXHAUSTED'
          and p_outcome in ('retryable', 'invalid_token')
      )
      and v_delivery.provider_receipt_hash is not distinct from v_receipt_hash
      and v_delivery.completed_retry_after_seconds
        is not distinct from p_retry_after_seconds then
      return query select
        v_delivery.id,
        v_delivery.processing_status,
        v_delivery.attempts,
        v_delivery.max_attempts,
        v_delivery.next_attempt_at,
        v_delivery.completed_at,
        v_delivery.last_result_code,
        v_delivery.endpoint_invalidated;
      return;
    end if;
    raise exception using
      errcode = 'KPS03',
      message = 'notification push lease unavailable';
  end if;

  if v_delivery.processing_status = 'leased'
    and v_delivery.lease_token <> p_lease_token
    or v_delivery.processing_status <> 'leased'
    and v_delivery.completed_lease_token <> p_lease_token then
    raise exception using
      errcode = 'KPS03',
      message = 'notification push lease unavailable';
  end if;

  select endpoint.token_fingerprint
  into v_endpoint_fingerprint
  from public.notification_endpoints as endpoint
  where endpoint.id = v_delivery.endpoint_id;

  if p_outcome = 'accepted' then
    v_status := 'succeeded';
    v_result_code := p_result_code;
    v_completed_at := p_as_of;
  elsif p_outcome = 'retryable' then
    if v_delivery.attempts >= v_delivery.max_attempts then
      v_status := 'failed';
      v_result_code := 'ATTEMPTS_EXHAUSTED';
      v_completed_at := p_as_of;
    else
      v_status := 'retry_wait';
      v_result_code := p_result_code;
      v_next_attempt_at := p_as_of
        + pg_catalog.make_interval(secs => p_retry_after_seconds);
    end if;
  elsif p_outcome = 'invalid_token'
    and v_endpoint_fingerprint is distinct from v_token_fingerprint then
    if v_delivery.attempts >= v_delivery.max_attempts then
      v_status := 'failed';
      v_result_code := 'ATTEMPTS_EXHAUSTED';
      v_completed_at := p_as_of;
    else
      v_status := 'retry_wait';
      v_result_code := 'ENDPOINT_MATERIAL_CHANGED';
      v_next_attempt_at := p_as_of + interval '5 seconds';
    end if;
  else
    v_status := 'failed';
    v_result_code := p_result_code;
    v_completed_at := p_as_of;
    if p_outcome = 'invalid_token' then
      select public.invalidate_notification_endpoint(
        v_delivery.endpoint_id,
        p_token_fingerprint_base64,
        case p_result_code
          when 'FCM_UNREGISTERED' then 'provider_unregistered'
          else 'provider_invalid_argument'
        end,
        p_as_of
      ) into v_invalidation_count;
      v_endpoint_invalidated := v_invalidation_count = 1;
    end if;
  end if;

  update app_private.notification_push_deliveries as delivery
  set processing_status = v_status,
      next_attempt_at = v_next_attempt_at,
      lease_owner = null,
      completed_lease_token = p_lease_token,
      lease_token = null,
      lease_expires_at = null,
      last_result_code = v_result_code,
      provider_receipt_hash = case
        when v_status = 'succeeded' then v_receipt_hash
        else null
      end,
      completed_token_fingerprint = v_token_fingerprint,
      completion_outcome = p_outcome,
      completed_retry_after_seconds = p_retry_after_seconds,
      endpoint_invalidated = v_endpoint_invalidated,
      updated_at = p_as_of,
      completed_at = v_completed_at
  where delivery.id = v_delivery.id
  returning delivery.* into v_delivery;

  return query select
    v_delivery.id,
    v_delivery.processing_status,
    v_delivery.attempts,
    v_delivery.max_attempts,
    v_delivery.next_attempt_at,
    v_delivery.completed_at,
    v_delivery.last_result_code,
    v_delivery.endpoint_invalidated;
end;
$$;

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
  from app_private.resolve_chore_notification_event(
    v_delivery.source_event_id
  ) as latest;

  if not found
    or not v_latest.should_create_intent
    or v_latest.recipient_user_id <> v_authenticated_user_id
    or v_latest.household_id <> v_delivery.household_id
    or v_latest.notification_category <> v_delivery.category
    or v_latest.occurrence_id <> v_delivery.subject_id
    or v_delivery.inbox_item_id is not null and not exists (
      select 1
      from public.notification_inbox_items as item
      where item.id = v_delivery.inbox_item_id
        and item.recipient_user_id = v_authenticated_user_id
        and item.household_id = v_delivery.household_id
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

create or replace function public.set_notification_push_worker_paused(
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
    or p_paused and p_reason_code <> 'ROLLBACK_DISABLED'
    or not p_paused and p_reason_code is not null then
    raise exception using
      errcode = 'KPS01',
      message = 'invalid notification push input';
  end if;

  update app_private.notification_push_worker_control as control
  set paused = p_paused,
      reason_code = p_reason_code,
      updated_at = p_as_of
  where control.worker_key = 'android_fcm_push';

  if p_paused then
    update app_private.notification_push_deliveries as delivery
    set processing_status = 'cancelled',
        next_attempt_at = null,
        lease_owner = null,
        lease_token = null,
        lease_expires_at = null,
        last_result_code = 'ROLLBACK_DISABLED',
        provider_receipt_hash = null,
        completed_retry_after_seconds = null,
        endpoint_invalidated = false,
        updated_at = p_as_of,
        completed_at = p_as_of
    where delivery.processing_status in ('pending', 'retry_wait', 'leased');
  end if;

  return query
  select control.paused, control.reason_code, control.updated_at
  from app_private.notification_push_worker_control as control
  where control.worker_key = 'android_fcm_push';
end;
$$;

revoke all on function public.claim_notification_push_deliveries(
  uuid,
  integer,
  integer,
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.complete_notification_push_delivery(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  integer,
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.resolve_notification_push_target(
  uuid,
  uuid,
  uuid
) from public, anon, authenticated, service_role;
revoke all on function public.set_notification_push_worker_paused(
  boolean,
  text,
  timestamptz
) from public, anon, authenticated, service_role;

grant execute on function public.claim_notification_push_deliveries(
  uuid,
  integer,
  integer,
  timestamptz
) to service_role;
grant execute on function public.complete_notification_push_delivery(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  integer,
  timestamptz
) to service_role;
grant execute on function public.resolve_notification_push_target(
  uuid,
  uuid,
  uuid
) to authenticated;
grant execute on function public.set_notification_push_worker_paused(
  boolean,
  text,
  timestamptz
) to service_role;

comment on table app_private.notification_push_evaluations is
  'WP05-04 content-free native-push materialization outcome independent from in-app visibility.';
comment on table app_private.notification_push_deliveries is
  'WP05-04 per-endpoint Android FCM lease, bounded attempt, hashed receipt, and exact completion replay.';
comment on function public.resolve_notification_push_target(uuid, uuid, uuid) is
  'WP05-04 authenticated notification tap authorization; returns only a safe destination after latest-state revalidation.';
