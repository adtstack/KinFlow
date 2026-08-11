-- KinFlow WP05-05 notification delivery reliability.
--
-- Native push is best effort while the durable inbox remains authoritative.
-- A provider submission is therefore guarded with an at-most-once marker:
-- explicit HTTP rejections may retry, but an outcome that can no longer be
-- proven is quarantined instead of risking a duplicate family notification.

alter table app_private.notification_push_deliveries
  add column scheduled_at timestamptz,
  add column expires_at timestamptz,
  add column replay_count integer not null default 0,
  add column submission_started_at timestamptz,
  add column submission_lease_token uuid;

update app_private.notification_push_deliveries as delivery
set scheduled_at = delivery.created_at,
    expires_at = delivery.created_at + interval '1 hour';

alter table app_private.notification_push_deliveries
  alter column scheduled_at set not null,
  alter column expires_at set not null,
  add constraint notification_push_delivery_window_ck check (
    scheduled_at = created_at
    and expires_at = scheduled_at + interval '1 hour'
  ),
  add constraint notification_push_delivery_replay_count_ck check (
    replay_count >= 0
  ),
  add constraint notification_push_delivery_submission_marker_ck check (
    submission_started_at is null and submission_lease_token is null
    or submission_started_at is not null
      and submission_lease_token is not null
      and attempts > 0
      and submission_started_at >= scheduled_at
      and submission_started_at <= coalesce(completed_at, updated_at)
  );

alter table app_private.notification_push_deliveries
  drop constraint notification_push_deliveries_last_result_code_check,
  add constraint notification_push_deliveries_last_result_code_check check (
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
      'FCM_REQUEST_REJECTED',
      'TOKEN_DECRYPTION_FAILED',
      'FCM_SUBMISSION_AMBIGUOUS',
      'ENDPOINT_MATERIAL_CHANGED',
      'ATTEMPTS_EXHAUSTED',
      'LEASE_EXPIRED',
      'NATIVE_PUSH_DISABLED',
      'LATEST_STATE_SUPPRESSED',
      'ENDPOINT_INACTIVE',
      'STALE_DELIVERY_WINDOW',
      'ROLLBACK_DISABLED'
    )
  ),
  drop constraint notification_push_deliveries_completion_outcome_check,
  add constraint notification_push_deliveries_completion_outcome_check check (
    completion_outcome is null
    or completion_outcome in (
      'accepted',
      'retryable',
      'invalid_token',
      'permanent',
      'ambiguous'
    )
  ),
  drop constraint notification_push_delivery_state_ck,
  add constraint notification_push_delivery_state_ck check (
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
          'permanent',
          'ambiguous'
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
          'STALE_DELIVERY_WINDOW',
          'ROLLBACK_DISABLED'
        )
        and provider_receipt_hash is null
        and not endpoint_invalidated
      else false
    end
  );

create index notification_push_deliveries_slo_idx
  on app_private.notification_push_deliveries(
    scheduled_at,
    processing_status,
    completed_at
  );

create table app_private.notification_push_provider_health (
  provider_key text primary key check (provider_key = 'fcm_android'),
  backoff_until timestamptz,
  backoff_reason_code text check (
    backoff_reason_code is null
    or backoff_reason_code in (
      'FCM_UNAVAILABLE',
      'FCM_INTERNAL',
      'FCM_QUOTA_EXCEEDED',
      'FCM_UNKNOWN',
      'FCM_SUBMISSION_AMBIGUOUS'
    )
  ),
  consecutive_retryable_failures integer not null default 0 check (
    consecutive_retryable_failures >= 0
  ),
  last_attempt_at timestamptz,
  last_success_at timestamptz,
  last_retryable_failure_at timestamptz,
  last_ambiguous_at timestamptz,
  last_permanent_failure_at timestamptz,
  updated_at timestamptz not null,
  constraint notification_push_provider_backoff_state_ck check (
    (backoff_until is null) = (backoff_reason_code is null)
  )
);

insert into app_private.notification_push_provider_health (
  provider_key,
  updated_at
) values (
  'fcm_android',
  pg_catalog.statement_timestamp()
);

create table app_private.notification_push_delivery_transitions (
  id bigint generated always as identity primary key,
  delivery_id uuid not null
    references app_private.notification_push_deliveries(id)
    on delete cascade,
  transition text not null check (
    transition in (
      'claimed',
      'submission_started',
      'retry_scheduled',
      'succeeded',
      'failed',
      'cancelled',
      'replayed'
    )
  ),
  attempt integer not null check (attempt between 0 and 5),
  result_code text,
  occurred_at timestamptz not null
);

create index notification_push_delivery_transitions_delivery_idx
  on app_private.notification_push_delivery_transitions(
    delivery_id,
    occurred_at,
    id
  );

revoke all on table app_private.notification_push_provider_health
  from public, anon, authenticated, service_role;
revoke all on table app_private.notification_push_delivery_transitions
  from public, anon, authenticated, service_role;
revoke all on sequence
  app_private.notification_push_delivery_transitions_id_seq
  from public, anon, authenticated, service_role;

create or replace function app_private.set_notification_push_delivery_window()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.scheduled_at := new.created_at;
  new.expires_at := new.created_at + interval '1 hour';
  return new;
end;
$$;

revoke all on function app_private.set_notification_push_delivery_window()
  from public, anon, authenticated, service_role;

create trigger notification_push_deliveries_set_window
before insert on app_private.notification_push_deliveries
for each row execute function
  app_private.set_notification_push_delivery_window();

create or replace function app_private.guard_notification_push_reliability_transition()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.processing_status = 'leased'
    and (
      old.processing_status <> 'leased'
      or old.lease_token is distinct from new.lease_token
    ) then
    new.submission_started_at := null;
    new.submission_lease_token := null;
  end if;

  if old.processing_status = 'leased'
    and old.submission_started_at is not null
    and new.processing_status in ('retry_wait', 'failed')
    and new.last_result_code in ('LEASE_EXPIRED', 'ATTEMPTS_EXHAUSTED') then
    new.processing_status := 'failed';
    new.next_attempt_at := null;
    new.last_result_code := 'FCM_SUBMISSION_AMBIGUOUS';
    new.completion_outcome := 'ambiguous';
    new.completed_retry_after_seconds := null;
    new.completed_at := new.updated_at;
  end if;

  return new;
end;
$$;

revoke all on function
  app_private.guard_notification_push_reliability_transition()
  from public, anon, authenticated, service_role;

create trigger notification_push_deliveries_guard_reliability
before update on app_private.notification_push_deliveries
for each row execute function
  app_private.guard_notification_push_reliability_transition();

create or replace function app_private.audit_notification_push_delivery_transition()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_transition text;
begin
  if old.submission_started_at is null
    and new.submission_started_at is not null then
    v_transition := 'submission_started';
  elsif old.processing_status <> 'leased'
    and new.processing_status = 'leased' then
    v_transition := 'claimed';
  elsif old.replay_count < new.replay_count then
    v_transition := 'replayed';
  elsif old.processing_status is distinct from new.processing_status then
    v_transition := case new.processing_status
      when 'retry_wait' then 'retry_scheduled'
      when 'succeeded' then 'succeeded'
      when 'failed' then 'failed'
      when 'cancelled' then 'cancelled'
      else null
    end;
  end if;

  if v_transition is not null then
    insert into app_private.notification_push_delivery_transitions (
      delivery_id,
      transition,
      attempt,
      result_code,
      occurred_at
    ) values (
      new.id,
      v_transition,
      new.attempts,
      new.last_result_code,
      new.updated_at
    );
  end if;
  return null;
end;
$$;

revoke all on function
  app_private.audit_notification_push_delivery_transition()
  from public, anon, authenticated, service_role;

create trigger notification_push_deliveries_audit_reliability
after update on app_private.notification_push_deliveries
for each row execute function
  app_private.audit_notification_push_delivery_transition();

create or replace function app_private.prevent_notification_push_transition_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'KPS04',
    message = 'notification push transition is immutable';
end;
$$;

revoke all on function
  app_private.prevent_notification_push_transition_mutation()
  from public, anon, authenticated, service_role;

create trigger notification_push_delivery_transitions_immutable
before update or delete on app_private.notification_push_delivery_transitions
for each row execute function
  app_private.prevent_notification_push_transition_mutation();

create or replace function app_private.update_notification_push_provider_health()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_backoff_until timestamptz;
begin
  if old.processing_status <> 'leased'
    or new.processing_status = 'leased' then
    return null;
  end if;

  if new.last_result_code = 'FCM_ACCEPTED' then
    update app_private.notification_push_provider_health as health
    set consecutive_retryable_failures = 0,
        last_success_at = new.completed_at,
        updated_at = new.updated_at
    where health.provider_key = 'fcm_android';
  elsif new.last_result_code in (
    'FCM_UNAVAILABLE',
    'FCM_INTERNAL',
    'FCM_QUOTA_EXCEEDED',
    'FCM_UNKNOWN'
  ) then
    v_backoff_until := coalesce(
      new.next_attempt_at,
      new.updated_at + interval '1 minute'
    );
    update app_private.notification_push_provider_health as health
    set backoff_reason_code = case
          when health.backoff_until is null
            or v_backoff_until >= health.backoff_until
            then new.last_result_code
          else health.backoff_reason_code
        end,
        backoff_until = greatest(
          coalesce(health.backoff_until, '-infinity'::timestamptz),
          v_backoff_until
        ),
        consecutive_retryable_failures =
          health.consecutive_retryable_failures + 1,
        last_retryable_failure_at = new.updated_at,
        updated_at = new.updated_at
    where health.provider_key = 'fcm_android';
  elsif new.last_result_code = 'FCM_SUBMISSION_AMBIGUOUS' then
    update app_private.notification_push_provider_health as health
    set backoff_reason_code = case
          when health.backoff_until is null
            or new.updated_at + interval '1 minute'
              >= health.backoff_until
            then 'FCM_SUBMISSION_AMBIGUOUS'
          else health.backoff_reason_code
        end,
        backoff_until = greatest(
          coalesce(health.backoff_until, '-infinity'::timestamptz),
          new.updated_at + interval '1 minute'
        ),
        consecutive_retryable_failures =
          health.consecutive_retryable_failures + 1,
        last_ambiguous_at = new.updated_at,
        updated_at = new.updated_at
    where health.provider_key = 'fcm_android';
  elsif new.last_result_code in (
    'FCM_SENDER_ID_MISMATCH',
    'FCM_THIRD_PARTY_AUTH_ERROR',
    'FCM_REQUEST_REJECTED',
    'TOKEN_DECRYPTION_FAILED'
  ) then
    update app_private.notification_push_provider_health as health
    set last_permanent_failure_at = new.updated_at,
        updated_at = new.updated_at
    where health.provider_key = 'fcm_android';
  end if;
  return null;
end;
$$;

revoke all on function
  app_private.update_notification_push_provider_health()
  from public, anon, authenticated, service_role;

create trigger notification_push_deliveries_update_provider_health
after update on app_private.notification_push_deliveries
for each row execute function
  app_private.update_notification_push_provider_health();

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
      'STALE_DELIVERY_WINDOW',
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

alter function public.claim_notification_push_deliveries(
  uuid,
  integer,
  integer,
  timestamptz
) rename to claim_notification_push_deliveries_wp05_04;

alter function public.claim_notification_push_deliveries_wp05_04(
  uuid,
  integer,
  integer,
  timestamptz
) set schema app_private;

revoke all on function app_private.claim_notification_push_deliveries_wp05_04(
  uuid,
  integer,
  integer,
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
  lease_expires_at timestamptz,
  scheduled_at timestamptz,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_claim record;
  v_scheduled_at timestamptz;
  v_expires_at timestamptz;
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

  if exists (
    select 1
    from app_private.notification_push_provider_health as health
    where health.provider_key = 'fcm_android'
      and health.backoff_until > p_as_of
  ) then
    return;
  end if;

  for v_claim in
    select legacy.*
    from app_private.claim_notification_push_deliveries_wp05_04(
      p_worker_id,
      p_batch_size,
      p_lease_seconds,
      p_as_of
    ) as legacy
  loop
    select delivery.scheduled_at, delivery.expires_at
    into v_scheduled_at, v_expires_at
    from app_private.notification_push_deliveries as delivery
    where delivery.id = v_claim.delivery_id;

    if v_expires_at <= p_as_of then
      perform app_private.cancel_notification_push_delivery(
        v_claim.delivery_id,
        'STALE_DELIVERY_WINDOW',
        p_as_of
      );
      continue;
    end if;

    return query select
      v_claim.delivery_id,
      v_claim.source_event_id,
      v_claim.inbox_item_id,
      v_claim.endpoint_id,
      v_claim.household_id,
      v_claim.category,
      v_claim.subject_type,
      v_claim.subject_id,
      v_claim.token_ciphertext_base64,
      v_claim.token_fingerprint_base64,
      v_claim.token_key_version,
      v_claim.locale,
      v_claim.attempt,
      v_claim.max_attempts,
      v_claim.lease_token,
      v_claim.lease_expires_at,
      v_scheduled_at,
      v_expires_at;
  end loop;
end;
$$;

alter function public.complete_notification_push_delivery(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  integer,
  timestamptz
) rename to complete_notification_push_delivery_wp05_04;

alter function public.complete_notification_push_delivery_wp05_04(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  integer,
  timestamptz
) set schema app_private;

revoke all on function app_private.complete_notification_push_delivery_wp05_04(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  integer,
  timestamptz
) from public, anon, authenticated, service_role;

create or replace function public.mark_notification_push_submission_started(
  p_delivery_id uuid,
  p_lease_token uuid,
  p_token_fingerprint_base64 text,
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
  v_delivery app_private.notification_push_deliveries%rowtype;
  v_token_fingerprint bytea;
  v_endpoint_fingerprint bytea;
begin
  if p_delivery_id is null
    or p_lease_token is null
    or p_as_of is null then
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

  select delivery.*
  into v_delivery
  from app_private.notification_push_deliveries as delivery
  where delivery.id = p_delivery_id
  for update;

  if found then
    select endpoint.token_fingerprint
    into v_endpoint_fingerprint
    from public.notification_endpoints as endpoint
    where endpoint.id = v_delivery.endpoint_id;
  end if;

  if not found
    or v_delivery.processing_status <> 'leased'
    or v_delivery.lease_token <> p_lease_token
    or v_delivery.lease_expires_at <= p_as_of
    or v_delivery.expires_at <= p_as_of
    or v_endpoint_fingerprint is distinct from v_token_fingerprint then
    raise exception using
      errcode = 'KPS03',
      message = 'notification push lease unavailable';
  end if;

  if v_delivery.submission_lease_token is not null
    and v_delivery.submission_lease_token <> p_lease_token then
    raise exception using
      errcode = 'KPS03',
      message = 'notification push lease unavailable';
  end if;

  if v_delivery.submission_started_at is null then
    update app_private.notification_push_deliveries as delivery
    set submission_started_at = p_as_of,
        submission_lease_token = p_lease_token,
        updated_at = greatest(delivery.updated_at, p_as_of)
    where delivery.id = v_delivery.id
    returning delivery.* into v_delivery;

    update app_private.notification_push_provider_health as health
    set last_attempt_at = p_as_of,
        updated_at = greatest(health.updated_at, p_as_of)
    where health.provider_key = 'fcm_android';
  end if;

  return query select v_delivery.id, v_delivery.submission_started_at;
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
begin
  if p_outcome <> 'ambiguous'
    and not (
      p_outcome = 'permanent'
      and p_result_code = 'FCM_REQUEST_REJECTED'
    ) then
    return query
    select completion.*
    from app_private.complete_notification_push_delivery_wp05_04(
      p_delivery_id,
      p_lease_token,
      p_token_fingerprint_base64,
      p_outcome,
      p_result_code,
      p_provider_receipt_hash_base64,
      p_retry_after_seconds,
      p_as_of
    ) as completion;
    return;
  end if;

  if p_delivery_id is null
    or p_lease_token is null
    or (
      p_outcome = 'ambiguous'
      and p_result_code <> 'FCM_SUBMISSION_AMBIGUOUS'
    )
    or (
      p_outcome = 'permanent'
      and p_result_code <> 'FCM_REQUEST_REJECTED'
    )
    or p_outcome not in ('ambiguous', 'permanent')
    or p_provider_receipt_hash_base64 is not null
    or p_retry_after_seconds is not null
    or p_as_of is null then
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

  if v_delivery.processing_status = 'failed'
    and v_delivery.completed_lease_token = p_lease_token
    and v_delivery.completed_token_fingerprint = v_token_fingerprint
    and v_delivery.completion_outcome = p_outcome
    and v_delivery.last_result_code = p_result_code then
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

  if v_delivery.processing_status <> 'leased'
    or v_delivery.lease_token <> p_lease_token
    or v_delivery.submission_lease_token <> p_lease_token
    or v_delivery.submission_started_at is null then
    raise exception using
      errcode = 'KPS03',
      message = 'notification push lease unavailable';
  end if;

  update app_private.notification_push_deliveries as delivery
  set processing_status = 'failed',
      next_attempt_at = null,
      lease_owner = null,
      completed_lease_token = p_lease_token,
      lease_token = null,
      lease_expires_at = null,
      last_result_code = p_result_code,
      provider_receipt_hash = null,
      completed_token_fingerprint = v_token_fingerprint,
      completion_outcome = p_outcome,
      completed_retry_after_seconds = null,
      endpoint_invalidated = false,
      updated_at = p_as_of,
      completed_at = p_as_of
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

create or replace function public.replay_notification_push_delivery(
  p_delivery_id uuid,
  p_as_of timestamptz
)
returns table (
  delivery_id uuid,
  processing_status text,
  replay_count integer,
  next_attempt_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_delivery app_private.notification_push_deliveries%rowtype;
begin
  if p_delivery_id is null or p_as_of is null then
    raise exception using
      errcode = 'KPS01',
      message = 'invalid notification push input';
  end if;

  select delivery.*
  into v_delivery
  from app_private.notification_push_deliveries as delivery
  where delivery.id = p_delivery_id
  for update;

  if not found
    or v_delivery.processing_status <> 'failed'
    or v_delivery.last_result_code <> 'ATTEMPTS_EXHAUSTED'
    or v_delivery.expires_at <= p_as_of then
    raise exception using
      errcode = 'KPS05',
      message = 'notification push delivery is not replayable';
  end if;

  update app_private.notification_push_deliveries as delivery
  set processing_status = 'pending',
      attempts = 0,
      next_attempt_at = p_as_of,
      lease_owner = null,
      lease_token = null,
      lease_expires_at = null,
      last_result_code = null,
      provider_receipt_hash = null,
      completed_lease_token = null,
      completed_token_fingerprint = null,
      completion_outcome = null,
      completed_retry_after_seconds = null,
      endpoint_invalidated = false,
      submission_started_at = null,
      submission_lease_token = null,
      replay_count = delivery.replay_count + 1,
      updated_at = p_as_of,
      completed_at = null
  where delivery.id = v_delivery.id
  returning delivery.* into v_delivery;

  return query select
    v_delivery.id,
    v_delivery.processing_status,
    v_delivery.replay_count,
    v_delivery.next_attempt_at;
end;
$$;

create or replace function public.reset_notification_push_provider_backoff(
  p_as_of timestamptz
)
returns table (
  backoff_until timestamptz,
  backoff_reason_code text,
  consecutive_retryable_failures integer,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_as_of is null then
    raise exception using
      errcode = 'KPS01',
      message = 'invalid notification push input';
  end if;

  update app_private.notification_push_provider_health as health
  set backoff_until = null,
      backoff_reason_code = null,
      consecutive_retryable_failures = 0,
      updated_at = greatest(health.updated_at, p_as_of)
  where health.provider_key = 'fcm_android';

  return query select
    health.backoff_until,
    health.backoff_reason_code,
    health.consecutive_retryable_failures,
    health.updated_at
  from app_private.notification_push_provider_health as health
  where health.provider_key = 'fcm_android';
end;
$$;

create or replace function public.get_notification_push_reliability_health(
  p_as_of timestamptz
)
returns table (
  captured_at timestamptz,
  health_status text,
  alert_code text,
  worker_paused boolean,
  pause_reason_code text,
  provider_backoff_active boolean,
  provider_backoff_until timestamptz,
  provider_backoff_reason_code text,
  consecutive_retryable_failures integer,
  pending_evaluation_count bigint,
  no_endpoint_count bigint,
  pending_delivery_count bigint,
  leased_count bigint,
  retry_wait_count bigint,
  succeeded_count bigint,
  failed_count bigint,
  cancelled_count bigint,
  ready_count bigint,
  expired_lease_count bigint,
  ambiguous_count_24h bigint,
  permanent_failure_count_24h bigint,
  stale_suppressed_count_24h bigint,
  slo_eligible_count_24h bigint,
  slo_within_5m_count_24h bigint,
  oldest_ready_at timestamptz,
  next_retry_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_health record;
  v_status text;
  v_alert text;
begin
  if p_as_of is null then
    raise exception using
      errcode = 'KPS01',
      message = 'invalid notification push input';
  end if;

  select
    control.paused as worker_paused,
    control.reason_code as pause_reason_code,
    coalesce(provider.backoff_until > p_as_of, false)
      as provider_backoff_active,
    provider.backoff_until,
    provider.backoff_reason_code,
    provider.consecutive_retryable_failures,
    count(distinct evaluation.source_event_id) filter (
      where evaluation.processing_status = 'pending'
    ) as pending_evaluation_count,
    count(distinct evaluation.source_event_id) filter (
      where evaluation.processing_status = 'no_endpoint'
    ) as no_endpoint_count,
    count(distinct delivery.id) filter (
      where delivery.processing_status = 'pending'
    ) as pending_delivery_count,
    count(distinct delivery.id) filter (
      where delivery.processing_status = 'leased'
    ) as leased_count,
    count(distinct delivery.id) filter (
      where delivery.processing_status = 'retry_wait'
    ) as retry_wait_count,
    count(distinct delivery.id) filter (
      where delivery.processing_status = 'succeeded'
    ) as succeeded_count,
    count(distinct delivery.id) filter (
      where delivery.processing_status = 'failed'
    ) as failed_count,
    count(distinct delivery.id) filter (
      where delivery.processing_status = 'cancelled'
    ) as cancelled_count,
    count(distinct delivery.id) filter (
      where delivery.expires_at > p_as_of
        and (
          delivery.processing_status in ('pending', 'retry_wait')
            and delivery.next_attempt_at <= p_as_of
          or delivery.processing_status = 'leased'
            and delivery.lease_expires_at <= p_as_of
        )
    ) as ready_count,
    count(distinct delivery.id) filter (
      where delivery.processing_status = 'leased'
        and delivery.lease_expires_at <= p_as_of
    ) as expired_lease_count,
    count(distinct delivery.id) filter (
      where delivery.completed_at > p_as_of - interval '24 hours'
        and delivery.last_result_code = 'FCM_SUBMISSION_AMBIGUOUS'
    ) as ambiguous_count_24h,
    count(distinct delivery.id) filter (
      where delivery.completed_at > p_as_of - interval '24 hours'
        and delivery.last_result_code in (
          'FCM_SENDER_ID_MISMATCH',
          'FCM_THIRD_PARTY_AUTH_ERROR',
          'FCM_REQUEST_REJECTED',
          'TOKEN_DECRYPTION_FAILED'
        )
    ) as permanent_failure_count_24h,
    count(distinct delivery.id) filter (
      where delivery.completed_at > p_as_of - interval '24 hours'
        and delivery.last_result_code = 'STALE_DELIVERY_WINDOW'
    ) as stale_suppressed_count_24h,
    count(distinct delivery.id) filter (
      where delivery.scheduled_at > p_as_of - interval '24 hours'
        and delivery.scheduled_at <= p_as_of - interval '5 minutes'
        and (
          delivery.processing_status <> 'cancelled'
          or delivery.last_result_code = 'STALE_DELIVERY_WINDOW'
        )
    ) as slo_eligible_count_24h,
    count(distinct delivery.id) filter (
      where delivery.scheduled_at > p_as_of - interval '24 hours'
        and delivery.scheduled_at <= p_as_of - interval '5 minutes'
        and delivery.processing_status = 'succeeded'
        and delivery.completed_at <= delivery.scheduled_at + interval '5 minutes'
    ) as slo_within_5m_count_24h,
    min(
      case
        when delivery.expires_at > p_as_of
          and delivery.processing_status in ('pending', 'retry_wait')
          and delivery.next_attempt_at <= p_as_of
          then delivery.next_attempt_at
        when delivery.expires_at > p_as_of
          and delivery.processing_status = 'leased'
          and delivery.lease_expires_at <= p_as_of
          then delivery.lease_expires_at
        else null
      end
    ) as oldest_ready_at,
    min(delivery.next_attempt_at) filter (
      where delivery.processing_status = 'retry_wait'
        and delivery.next_attempt_at > p_as_of
    ) as next_retry_at,
    provider.last_permanent_failure_at
  into v_health
  from app_private.notification_push_worker_control as control
  cross join app_private.notification_push_provider_health as provider
  left join app_private.notification_push_evaluations as evaluation on true
  left join app_private.notification_push_deliveries as delivery
    on delivery.source_event_id = evaluation.source_event_id
  where control.worker_key = 'android_fcm_push'
    and provider.provider_key = 'fcm_android'
  group by
    control.paused,
    control.reason_code,
    provider.backoff_until,
    provider.backoff_reason_code,
    provider.consecutive_retryable_failures,
    provider.last_permanent_failure_at;

  if v_health.worker_paused then
    v_status := 'critical';
    v_alert := 'WORKER_PAUSED';
  elsif v_health.last_permanent_failure_at
      > p_as_of - interval '15 minutes' then
    v_status := 'critical';
    v_alert := 'PROVIDER_CONFIGURATION_FAILURE';
  elsif v_health.oldest_ready_at <= p_as_of - interval '5 minutes'
    or v_health.stale_suppressed_count_24h > 0
    or v_health.slo_eligible_count_24h >= 20
      and v_health.slo_within_5m_count_24h::numeric
        / v_health.slo_eligible_count_24h < 0.95
    or v_health.slo_eligible_count_24h
      - v_health.slo_within_5m_count_24h >= 3 then
    v_status := 'critical';
    v_alert := 'PROVIDER_SUBMIT_SLO_BREACH';
  elsif v_health.ambiguous_count_24h > 0 then
    v_status := 'degraded';
    v_alert := 'AMBIGUOUS_SUBMISSION';
  elsif v_health.provider_backoff_active then
    v_status := 'degraded';
    v_alert := 'PROVIDER_BACKOFF_ACTIVE';
  elsif v_health.expired_lease_count > 0 then
    v_status := 'degraded';
    v_alert := 'EXPIRED_LEASE';
  else
    v_status := 'healthy';
    v_alert := 'OK';
  end if;

  return query select
    p_as_of,
    v_status,
    v_alert,
    v_health.worker_paused,
    v_health.pause_reason_code,
    v_health.provider_backoff_active,
    v_health.backoff_until,
    v_health.backoff_reason_code,
    v_health.consecutive_retryable_failures,
    v_health.pending_evaluation_count,
    v_health.no_endpoint_count,
    v_health.pending_delivery_count,
    v_health.leased_count,
    v_health.retry_wait_count,
    v_health.succeeded_count,
    v_health.failed_count,
    v_health.cancelled_count,
    v_health.ready_count,
    v_health.expired_lease_count,
    v_health.ambiguous_count_24h,
    v_health.permanent_failure_count_24h,
    v_health.stale_suppressed_count_24h,
    v_health.slo_eligible_count_24h,
    v_health.slo_within_5m_count_24h,
    v_health.oldest_ready_at,
    v_health.next_retry_at;
end;
$$;

create or replace function app_private.wake_no_endpoint_push_evaluations()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.channel = 'native_push'
    and new.platform = 'android'
    and new.permission_state = 'granted'
    and new.revoked_at is null then
    update app_private.notification_push_evaluations as evaluation
    set processing_status = 'pending',
        next_evaluation_at = pg_catalog.statement_timestamp(),
        reason_code = null,
        evaluated_at = null
    from app_private.notification_event_resolutions as resolution
    where evaluation.source_event_id = resolution.source_event_id
      and evaluation.processing_status = 'no_endpoint'
      and evaluation.evaluated_at
        > pg_catalog.statement_timestamp() - interval '1 hour'
      and resolution.recipient_user_id = new.auth_user_id
      and resolution.recipient_member_id = new.member_id
      and resolution.household_id = new.household_id;
  end if;
  return null;
end;
$$;

revoke all on function app_private.wake_no_endpoint_push_evaluations()
  from public, anon, authenticated, service_role;

create trigger notification_endpoints_wake_no_endpoint_push
after insert or update on public.notification_endpoints
for each row execute function
  app_private.wake_no_endpoint_push_evaluations();

revoke all on function public.claim_notification_push_deliveries(
  uuid,
  integer,
  integer,
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.mark_notification_push_submission_started(
  uuid,
  uuid,
  text,
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
revoke all on function public.replay_notification_push_delivery(
  uuid,
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.reset_notification_push_provider_backoff(
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.get_notification_push_reliability_health(
  timestamptz
) from public, anon, authenticated, service_role;

grant execute on function public.claim_notification_push_deliveries(
  uuid,
  integer,
  integer,
  timestamptz
) to service_role;
grant execute on function public.mark_notification_push_submission_started(
  uuid,
  uuid,
  text,
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
grant execute on function public.replay_notification_push_delivery(
  uuid,
  timestamptz
) to service_role;
grant execute on function public.reset_notification_push_provider_backoff(
  timestamptz
) to service_role;
grant execute on function public.get_notification_push_reliability_health(
  timestamptz
) to service_role;

comment on table app_private.notification_push_provider_health is
  'WP05-05 content-free FCM backoff and last-outcome aggregate.';
comment on table app_private.notification_push_delivery_transitions is
  'WP05-05 immutable content-free push delivery transition audit.';
comment on function public.mark_notification_push_submission_started(
  uuid,
  uuid,
  text,
  timestamptz
) is
  'Durably marks the provider ambiguity boundary immediately before FCM I/O.';
comment on function public.get_notification_push_reliability_health(
  timestamptz
) is
  'Returns aggregate queue/provider health and the 24-hour provider-submit SLO.';
