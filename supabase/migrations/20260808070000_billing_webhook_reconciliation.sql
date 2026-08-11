-- KinFlow WP06-04 signed RevenueCat webhook inbox and reconciliation worker.
--
-- Raw provider payloads never enter the database. Authenticated ingress stores
-- a SHA-256 request digest plus bounded routing metadata, and a leased worker
-- refreshes the authoritative subscriber snapshot before invoking the WP06-01
-- normalized-event command. Missing household assignment always fails closed.

create table app_private.billing_reconciliation_jobs (
  id uuid primary key default extensions.gen_random_uuid(),
  provider text not null default 'revenuecat' check (
    provider = 'revenuecat'
  ),
  source text not null check (source in ('webhook', 'periodic')),
  provider_event_id text not null check (
    pg_catalog.char_length(provider_event_id) between 1 and 255
    and provider_event_id = pg_catalog.btrim(provider_event_id)
  ),
  request_hash bytea not null check (
    pg_catalog.octet_length(request_hash) = 32
  ),
  api_version text not null check (
    pg_catalog.char_length(api_version) between 1 and 32
    and api_version = pg_catalog.btrim(api_version)
  ),
  event_type text not null check (
    pg_catalog.char_length(event_type) between 1 and 80
    and event_type ~ '^[A-Z][A-Z0-9_]{0,79}$'
  ),
  auth_user_id uuid,
  environment text check (environment in ('sandbox', 'production')),
  provider_occurred_at timestamptz not null,
  processing_status text not null check (
    processing_status in (
      'queued',
      'leased',
      'retry_wait',
      'succeeded',
      'ignored',
      'dead_letter'
    )
  ),
  delivery_count integer not null default 1 check (delivery_count >= 1),
  attempts integer not null default 0 check (attempts between 0 and 5),
  max_attempts integer not null default 5 check (max_attempts = 5),
  next_attempt_at timestamptz,
  lease_owner uuid,
  lease_token uuid,
  lease_expires_at timestamptz,
  completed_lease_token uuid,
  last_error_code text check (
    last_error_code is null
    or last_error_code in (
      'ENVIRONMENT_MISMATCH',
      'MANUAL_REVIEW_REQUIRED',
      'ASSIGNMENT_REQUIRED',
      'PROVIDER_NETWORK',
      'PROVIDER_RATE_LIMITED',
      'PROVIDER_UNAVAILABLE',
      'PROVIDER_AUTH_REJECTED',
      'PROVIDER_NOT_FOUND',
      'PROVIDER_RESPONSE_INVALID',
      'PROVIDER_IDENTITY_MISMATCH',
      'PROVIDER_ENVIRONMENT_MISMATCH',
      'ENTITLEMENT_UNMAPPED',
      'SUBSCRIPTION_UNMAPPED',
      'UNSUPPORTED_STORE',
      'RPC_UNAVAILABLE',
      'NORMALIZED_EVENT_QUARANTINED',
      'LEASE_EXPIRED',
      'ATTEMPTS_EXHAUSTED'
    )
  ),
  received_at timestamptz not null default pg_catalog.now(),
  last_received_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  completed_at timestamptz,
  correlation_id uuid not null,
  unique (provider, provider_event_id),
  constraint billing_reconciliation_identity_state_ck check (
    processing_status in ('ignored', 'dead_letter')
    or (auth_user_id is not null and environment is not null)
  ),
  constraint billing_reconciliation_time_ck check (
    last_received_at >= received_at
    and updated_at >= received_at
    and (completed_at is null or completed_at >= received_at)
  ),
  constraint billing_reconciliation_processing_state_ck check (
    case processing_status
      when 'queued' then
        next_attempt_at is not null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and completed_lease_token is null
        and completed_at is null
        and last_error_code is null
      when 'leased' then
        next_attempt_at is null
        and lease_owner is not null
        and lease_token is not null
        and lease_expires_at is not null
        and completed_lease_token is null
        and completed_at is null
        and last_error_code is null
      when 'retry_wait' then
        next_attempt_at is not null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and completed_lease_token is not null
        and completed_at is null
        and last_error_code in (
          'PROVIDER_NETWORK',
          'PROVIDER_RATE_LIMITED',
          'PROVIDER_UNAVAILABLE',
          'RPC_UNAVAILABLE',
          'LEASE_EXPIRED'
        )
      when 'succeeded' then
        next_attempt_at is null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and completed_lease_token is not null
        and completed_at is not null
        and last_error_code is null
      when 'ignored' then
        next_attempt_at is null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and completed_lease_token is null
        and completed_at is not null
        and last_error_code is null
      when 'dead_letter' then
        next_attempt_at is null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and completed_at is not null
        and last_error_code is not null
      else false
    end
  )
);

create index billing_reconciliation_due_idx
  on app_private.billing_reconciliation_jobs(
    processing_status,
    next_attempt_at,
    received_at,
    id
  );

create index billing_reconciliation_lease_idx
  on app_private.billing_reconciliation_jobs(lease_expires_at)
  where processing_status = 'leased';

create index billing_reconciliation_customer_idx
  on app_private.billing_reconciliation_jobs(
    auth_user_id,
    environment,
    processing_status,
    provider_occurred_at desc
  )
  where auth_user_id is not null;

create table app_private.billing_reconciliation_transitions (
  id bigint generated always as identity primary key,
  job_id uuid not null
    references app_private.billing_reconciliation_jobs(id) on delete restrict,
  transition text not null check (
    transition in (
      'queued',
      'ignored',
      'dead_lettered',
      'replayed',
      'claimed',
      'retry_scheduled',
      'succeeded'
    )
  ),
  attempt integer not null check (attempt between 0 and 5),
  result_code text,
  occurred_at timestamptz not null
);

create index billing_reconciliation_transitions_job_idx
  on app_private.billing_reconciliation_transitions(job_id, occurred_at, id);

create or replace function app_private.guard_billing_reconciliation_job()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if row(
    new.provider,
    new.source,
    new.provider_event_id,
    new.request_hash,
    new.api_version,
    new.event_type,
    new.auth_user_id,
    new.environment,
    new.provider_occurred_at,
    new.received_at,
    new.correlation_id,
    new.max_attempts
  ) is distinct from row(
    old.provider,
    old.source,
    old.provider_event_id,
    old.request_hash,
    old.api_version,
    old.event_type,
    old.auth_user_id,
    old.environment,
    old.provider_occurred_at,
    old.received_at,
    old.correlation_id,
    old.max_attempts
  ) then
    raise exception using
      errcode = 'KFB44',
      message = 'billing reconciliation provider metadata is immutable';
  end if;

  if new.delivery_count < old.delivery_count
    or new.last_received_at < old.last_received_at
    or new.attempts < old.attempts
    or new.attempts > old.attempts + 1 then
    raise exception using
      errcode = 'KFB44',
      message = 'billing reconciliation counters are monotonic';
  end if;

  return new;
end;
$$;

revoke all on function app_private.guard_billing_reconciliation_job()
  from public, anon, authenticated, service_role;

create trigger billing_reconciliation_jobs_guard
before update on app_private.billing_reconciliation_jobs
for each row execute function app_private.guard_billing_reconciliation_job();

create or replace function app_private.audit_billing_reconciliation_job()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_transition text;
begin
  if tg_op = 'INSERT' then
    v_transition := case new.processing_status
      when 'queued' then 'queued'
      when 'ignored' then 'ignored'
      when 'dead_letter' then 'dead_lettered'
      else null
    end;
  elsif new.delivery_count > old.delivery_count then
    v_transition := 'replayed';
  elsif new.processing_status is distinct from old.processing_status then
    v_transition := case new.processing_status
      when 'leased' then 'claimed'
      when 'retry_wait' then 'retry_scheduled'
      when 'succeeded' then 'succeeded'
      when 'dead_letter' then 'dead_lettered'
      else null
    end;
  end if;

  if v_transition is not null then
    insert into app_private.billing_reconciliation_transitions(
      job_id,
      transition,
      attempt,
      result_code,
      occurred_at
    ) values (
      new.id,
      v_transition,
      new.attempts,
      new.last_error_code,
      new.updated_at
    );
  end if;
  return null;
end;
$$;

revoke all on function app_private.audit_billing_reconciliation_job()
  from public, anon, authenticated, service_role;

create trigger billing_reconciliation_jobs_audit
after insert or update on app_private.billing_reconciliation_jobs
for each row execute function app_private.audit_billing_reconciliation_job();

create or replace function app_private.reject_billing_reconciliation_audit_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'KFB45',
    message = 'billing reconciliation audit is immutable';
end;
$$;

revoke all on function
  app_private.reject_billing_reconciliation_audit_mutation()
  from public, anon, authenticated, service_role;

create trigger billing_reconciliation_transitions_immutable
before update or delete on app_private.billing_reconciliation_transitions
for each row execute function
  app_private.reject_billing_reconciliation_audit_mutation();

create or replace function public.enqueue_revenuecat_webhook(
  p_provider_event_id text,
  p_request_hash_base64 text,
  p_api_version text,
  p_event_type text,
  p_auth_user_id uuid,
  p_environment text,
  p_provider_occurred_at timestamptz,
  p_routing_action text,
  p_received_at timestamptz,
  p_correlation_id uuid
)
returns table (
  job_id uuid,
  processing_status text,
  duplicate boolean,
  delivery_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_hash bytea;
  v_job app_private.billing_reconciliation_jobs%rowtype;
  v_status text;
  v_error_code text;
  v_runtime app_private.billing_runtime_config%rowtype;
begin
  begin
    v_hash := pg_catalog.decode(p_request_hash_base64, 'base64');
  exception when others then
    raise exception using
      errcode = '22023',
      message = 'invalid RevenueCat webhook input';
  end;

  if p_provider_event_id is null
    or p_provider_event_id <> pg_catalog.btrim(p_provider_event_id)
    or pg_catalog.char_length(p_provider_event_id) not between 1 and 255
    or p_provider_event_id ~ '[[:cntrl:]]'
    or p_request_hash_base64 is null
    or pg_catalog.encode(v_hash, 'base64') <> p_request_hash_base64
    or pg_catalog.octet_length(v_hash) <> 32
    or p_api_version is null
    or p_api_version <> pg_catalog.btrim(p_api_version)
    or pg_catalog.char_length(p_api_version) not between 1 and 32
    or p_api_version ~ '[[:cntrl:]]'
    or p_event_type is null
    or p_event_type !~ '^[A-Z][A-Z0-9_]{0,79}$'
    or p_environment is not null
      and p_environment not in ('sandbox', 'production')
    or p_provider_occurred_at is null
    or p_provider_occurred_at > p_received_at + interval '1 day'
    or p_provider_occurred_at < '2000-01-01 00:00:00+00'::timestamptz
    or p_routing_action not in ('reconcile', 'ignore', 'manual_review')
    or p_routing_action = 'reconcile'
      and (p_auth_user_id is null or p_environment is null)
    or p_received_at is null
    or p_received_at > pg_catalog.statement_timestamp() + interval '5 minutes'
    or p_correlation_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid RevenueCat webhook input';
  end if;

  -- A row lock cannot protect a key that does not exist yet. Serialize only
  -- identical provider event IDs so concurrent at-least-once deliveries still
  -- converge on the exact replay/collision path below.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('revenuecat:' || p_provider_event_id, 0)
  );

  select job.*
  into v_job
  from app_private.billing_reconciliation_jobs as job
  where job.provider = 'revenuecat'
    and job.provider_event_id = p_provider_event_id
  for update;

  if found then
    if v_job.request_hash <> v_hash then
      raise exception using
        errcode = 'KFB40',
        message = 'RevenueCat event ID collision';
    end if;

    update app_private.billing_reconciliation_jobs as job
    set delivery_count = job.delivery_count + 1,
        last_received_at = case
          when job.last_received_at >= p_received_at then job.last_received_at
          else p_received_at
        end,
        updated_at = case
          when job.updated_at >= p_received_at then job.updated_at
          else p_received_at
        end
    where job.id = v_job.id
    returning job.* into v_job;

    return query select
      v_job.id,
      v_job.processing_status,
      true,
      v_job.delivery_count;
    return;
  end if;

  select config.*
  into v_runtime
  from app_private.billing_runtime_config as config
  where config.singleton;

  if p_routing_action = 'ignore' then
    v_status := 'ignored';
  elsif p_routing_action = 'manual_review' then
    v_status := 'dead_letter';
    v_error_code := 'MANUAL_REVIEW_REQUIRED';
  elsif v_runtime.ingestion_enabled
    and v_runtime.accepted_environment <> p_environment then
    v_status := 'dead_letter';
    v_error_code := 'ENVIRONMENT_MISMATCH';
  else
    v_status := 'queued';
  end if;

  insert into app_private.billing_reconciliation_jobs(
    source,
    provider_event_id,
    request_hash,
    api_version,
    event_type,
    auth_user_id,
    environment,
    provider_occurred_at,
    processing_status,
    next_attempt_at,
    last_error_code,
    received_at,
    last_received_at,
    updated_at,
    completed_at,
    correlation_id
  ) values (
    'webhook',
    p_provider_event_id,
    v_hash,
    p_api_version,
    p_event_type,
    p_auth_user_id,
    p_environment,
    p_provider_occurred_at,
    v_status,
    case when v_status = 'queued' then p_received_at else null end,
    v_error_code,
    p_received_at,
    p_received_at,
    p_received_at,
    case when v_status in ('ignored', 'dead_letter') then p_received_at else null end,
    p_correlation_id
  ) returning * into v_job;

  return query select
    v_job.id,
    v_job.processing_status,
    false,
    v_job.delivery_count;
end;
$$;

create or replace function public.schedule_due_billing_reconciliations(
  p_as_of timestamptz,
  p_stale_after_seconds integer,
  p_limit integer,
  p_correlation_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_runtime app_private.billing_runtime_config%rowtype;
  v_inserted integer;
begin
  if p_as_of is null
    or p_stale_after_seconds not between 300 and 86400
    or p_limit not between 1 and 100
    or p_correlation_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid billing reconciliation schedule request';
  end if;

  select config.*
  into v_runtime
  from app_private.billing_runtime_config as config
  where config.singleton;

  if not v_runtime.ingestion_enabled then
    return 0;
  end if;

  with candidates as (
    select
      customer.id as customer_id,
      customer.auth_user_id,
      customer.environment
    from public.billing_customers as customer
    join public.billing_household_assignments as assignment
      on assignment.billing_customer_id = customer.id
     and assignment.status = 'active'
    where customer.provider = 'revenuecat'
      and customer.environment = v_runtime.accepted_environment
      and (
        customer.last_verified_at is null
        or customer.last_verified_at
          <= p_as_of - p_stale_after_seconds * interval '1 second'
      )
      and not exists (
        select 1
        from app_private.billing_reconciliation_jobs as active_job
        where active_job.auth_user_id = customer.auth_user_id
          and active_job.environment = customer.environment
          and active_job.processing_status in (
            'queued',
            'leased',
            'retry_wait'
          )
      )
    order by customer.last_verified_at nulls first, customer.id
    limit p_limit
  ), inserted as (
    insert into app_private.billing_reconciliation_jobs(
      source,
      provider_event_id,
      request_hash,
      api_version,
      event_type,
      auth_user_id,
      environment,
      provider_occurred_at,
      processing_status,
      next_attempt_at,
      received_at,
      last_received_at,
      updated_at,
      correlation_id
    )
    select
      'periodic',
      'periodic:' || candidate.customer_id::text || ':' ||
        pg_catalog.floor(
          pg_catalog.date_part('epoch', p_as_of) / p_stale_after_seconds
        )::bigint::text,
      extensions.digest(
        pg_catalog.convert_to(
          'periodic:' || candidate.customer_id::text || ':' ||
          pg_catalog.floor(
            pg_catalog.date_part('epoch', p_as_of) / p_stale_after_seconds
          )::bigint::text,
          'UTF8'
        ),
        'sha256'
      ),
      'server-v1',
      'PERIODIC_RECONCILIATION',
      candidate.auth_user_id,
      candidate.environment,
      p_as_of,
      'queued',
      p_as_of,
      p_as_of,
      p_as_of,
      p_as_of,
      p_correlation_id
    from candidates as candidate
    on conflict (provider, provider_event_id) do nothing
    returning 1
  )
  select pg_catalog.count(*)::integer into v_inserted from inserted;

  return v_inserted;
end;
$$;

create or replace function public.claim_billing_reconciliation_jobs(
  p_worker_id uuid,
  p_limit integer,
  p_lease_seconds integer,
  p_as_of timestamptz
)
returns table (
  job_id uuid,
  lease_token uuid,
  auth_user_id uuid,
  environment text,
  provider_occurred_at timestamptz,
  household_id uuid,
  attempt_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_runtime app_private.billing_runtime_config%rowtype;
begin
  if p_worker_id is null
    or p_limit not between 1 and 100
    or p_lease_seconds not between 5 and 300
    or p_as_of is null then
    raise exception using
      errcode = '22023',
      message = 'invalid billing reconciliation claim request';
  end if;

  select config.*
  into v_runtime
  from app_private.billing_runtime_config as config
  where config.singleton;

  update app_private.billing_reconciliation_jobs as job
  set processing_status = 'dead_letter',
      next_attempt_at = null,
      lease_owner = null,
      completed_lease_token = job.lease_token,
      lease_token = null,
      lease_expires_at = null,
      last_error_code = 'ATTEMPTS_EXHAUSTED',
      updated_at = p_as_of,
      completed_at = p_as_of
  where job.processing_status = 'leased'
    and job.lease_expires_at <= p_as_of
    and job.attempts >= job.max_attempts;

  update app_private.billing_reconciliation_jobs as job
  set processing_status = 'retry_wait',
      next_attempt_at = p_as_of,
      lease_owner = null,
      completed_lease_token = job.lease_token,
      lease_token = null,
      lease_expires_at = null,
      last_error_code = 'LEASE_EXPIRED',
      updated_at = p_as_of
  where job.processing_status = 'leased'
    and job.lease_expires_at <= p_as_of
    and job.attempts < job.max_attempts;

  if not v_runtime.ingestion_enabled then
    return;
  end if;

  update app_private.billing_reconciliation_jobs as job
  set processing_status = 'dead_letter',
      next_attempt_at = null,
      last_error_code = 'ENVIRONMENT_MISMATCH',
      updated_at = p_as_of,
      completed_at = p_as_of
  where job.processing_status in ('queued', 'retry_wait')
    and job.environment is distinct from v_runtime.accepted_environment;

  return query
  with due as (
    select job.id
    from app_private.billing_reconciliation_jobs as job
    where job.processing_status in ('queued', 'retry_wait')
      and job.next_attempt_at <= p_as_of
      and job.attempts < job.max_attempts
      and job.environment = v_runtime.accepted_environment
    order by job.next_attempt_at, job.received_at, job.id
    for update skip locked
    limit p_limit
  ), claimed as (
    update app_private.billing_reconciliation_jobs as job
    set processing_status = 'leased',
        attempts = job.attempts + 1,
        next_attempt_at = null,
        lease_owner = p_worker_id,
        lease_token = extensions.gen_random_uuid(),
        lease_expires_at = p_as_of + p_lease_seconds * interval '1 second',
        completed_lease_token = null,
        last_error_code = null,
        updated_at = p_as_of
    from due
    where job.id = due.id
    returning job.*
  )
  select
    claimed.id,
    claimed.lease_token,
    claimed.auth_user_id,
    claimed.environment,
    claimed.provider_occurred_at,
    assignment.household_id,
    claimed.attempts
  from claimed
  left join public.billing_customers as customer
    on customer.provider = 'revenuecat'
   and customer.environment = claimed.environment
   and customer.auth_user_id = claimed.auth_user_id
  left join public.billing_household_assignments as assignment
    on assignment.billing_customer_id = customer.id
   and assignment.status = 'active'
  order by claimed.next_attempt_at nulls first, claimed.received_at, claimed.id;
end;
$$;

create or replace function public.complete_billing_reconciliation_job(
  p_job_id uuid,
  p_lease_token uuid,
  p_outcome text,
  p_error_code text,
  p_as_of timestamptz
)
returns table (
  job_id uuid,
  processing_status text,
  attempt_count integer,
  next_attempt_at timestamptz,
  last_error_code text,
  completed_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.billing_reconciliation_jobs%rowtype;
  v_status text;
  v_error text;
  v_next_attempt timestamptz;
  v_completed timestamptz;
begin
  if p_job_id is null
    or p_lease_token is null
    or p_outcome not in ('succeeded', 'retryable', 'dead_letter')
    or p_as_of is null
    or p_outcome = 'succeeded' and p_error_code is not null
    or p_outcome = 'retryable' and p_error_code not in (
      'PROVIDER_NETWORK',
      'PROVIDER_RATE_LIMITED',
      'PROVIDER_UNAVAILABLE',
      'RPC_UNAVAILABLE'
    )
    or p_outcome = 'dead_letter' and p_error_code not in (
      'ASSIGNMENT_REQUIRED',
      'PROVIDER_AUTH_REJECTED',
      'PROVIDER_NOT_FOUND',
      'PROVIDER_RESPONSE_INVALID',
      'PROVIDER_IDENTITY_MISMATCH',
      'PROVIDER_ENVIRONMENT_MISMATCH',
      'ENTITLEMENT_UNMAPPED',
      'SUBSCRIPTION_UNMAPPED',
      'UNSUPPORTED_STORE',
      'NORMALIZED_EVENT_QUARANTINED'
    ) then
    raise exception using
      errcode = '22023',
      message = 'invalid billing reconciliation completion';
  end if;

  select job.*
  into v_job
  from app_private.billing_reconciliation_jobs as job
  where job.id = p_job_id
  for update;

  if not found then
    raise exception using
      errcode = 'KFB43',
      message = 'billing reconciliation lease unavailable';
  end if;

  if v_job.completed_lease_token = p_lease_token
    and v_job.processing_status in (
      'retry_wait',
      'succeeded',
      'dead_letter'
    ) then
    return query select
      v_job.id,
      v_job.processing_status,
      v_job.attempts,
      v_job.next_attempt_at,
      v_job.last_error_code,
      v_job.completed_at;
    return;
  end if;

  if v_job.processing_status <> 'leased'
    or v_job.lease_token <> p_lease_token
    or v_job.lease_expires_at <= p_as_of then
    raise exception using
      errcode = 'KFB43',
      message = 'billing reconciliation lease unavailable';
  end if;

  if p_outcome = 'succeeded' then
    v_status := 'succeeded';
    v_completed := p_as_of;
  elsif p_outcome = 'dead_letter' then
    v_status := 'dead_letter';
    v_error := p_error_code;
    v_completed := p_as_of;
  elsif v_job.attempts >= v_job.max_attempts then
    v_status := 'dead_letter';
    v_error := 'ATTEMPTS_EXHAUSTED';
    v_completed := p_as_of;
  else
    v_status := 'retry_wait';
    v_error := p_error_code;
    v_next_attempt := p_as_of + case v_job.attempts
      when 1 then interval '1 minute'
      when 2 then interval '5 minutes'
      when 3 then interval '30 minutes'
      when 4 then interval '2 hours'
    end;
  end if;

  update app_private.billing_reconciliation_jobs as job
  set processing_status = v_status,
      next_attempt_at = v_next_attempt,
      lease_owner = null,
      completed_lease_token = p_lease_token,
      lease_token = null,
      lease_expires_at = null,
      last_error_code = v_error,
      updated_at = p_as_of,
      completed_at = v_completed
  where job.id = v_job.id
  returning job.* into v_job;

  return query select
    v_job.id,
    v_job.processing_status,
    v_job.attempts,
    v_job.next_attempt_at,
    v_job.last_error_code,
    v_job.completed_at;
end;
$$;

create or replace function public.get_billing_reconciliation_health(
  p_as_of timestamptz
)
returns table (
  queued_count bigint,
  leased_count bigint,
  retry_wait_count bigint,
  dead_letter_count bigint,
  succeeded_24h_count bigint,
  dead_letter_24h_count bigint,
  expired_lease_count bigint,
  oldest_due_at timestamptz,
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
      errcode = '22023',
      message = 'invalid billing reconciliation health request';
  end if;

  return query
  select
    pg_catalog.count(*) filter (
      where job.processing_status = 'queued'
    ),
    pg_catalog.count(*) filter (
      where job.processing_status = 'leased'
    ),
    pg_catalog.count(*) filter (
      where job.processing_status = 'retry_wait'
    ),
    pg_catalog.count(*) filter (
      where job.processing_status = 'dead_letter'
    ),
    pg_catalog.count(*) filter (
      where job.processing_status = 'succeeded'
        and job.completed_at > p_as_of - interval '24 hours'
    ),
    pg_catalog.count(*) filter (
      where job.processing_status = 'dead_letter'
        and job.completed_at > p_as_of - interval '24 hours'
    ),
    pg_catalog.count(*) filter (
      where job.processing_status = 'leased'
        and job.lease_expires_at <= p_as_of
    ),
    pg_catalog.min(job.next_attempt_at) filter (
      where job.processing_status in ('queued', 'retry_wait')
        and job.next_attempt_at <= p_as_of
    ),
    pg_catalog.min(job.next_attempt_at) filter (
      where job.processing_status = 'retry_wait'
    )
  from app_private.billing_reconciliation_jobs as job;
end;
$$;

revoke all on table app_private.billing_reconciliation_jobs
  from public, anon, authenticated, service_role;
revoke all on table app_private.billing_reconciliation_transitions
  from public, anon, authenticated, service_role;
revoke all on sequence app_private.billing_reconciliation_transitions_id_seq
  from public, anon, authenticated, service_role;

revoke all on function public.enqueue_revenuecat_webhook(
  text,
  text,
  text,
  text,
  uuid,
  text,
  timestamptz,
  text,
  timestamptz,
  uuid
) from public, anon, authenticated, service_role;
revoke all on function public.schedule_due_billing_reconciliations(
  timestamptz,
  integer,
  integer,
  uuid
) from public, anon, authenticated, service_role;
revoke all on function public.claim_billing_reconciliation_jobs(
  uuid,
  integer,
  integer,
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.complete_billing_reconciliation_job(
  uuid,
  uuid,
  text,
  text,
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.get_billing_reconciliation_health(timestamptz)
  from public, anon, authenticated, service_role;

grant execute on function public.enqueue_revenuecat_webhook(
  text,
  text,
  text,
  text,
  uuid,
  text,
  timestamptz,
  text,
  timestamptz,
  uuid
) to service_role;
grant execute on function public.schedule_due_billing_reconciliations(
  timestamptz,
  integer,
  integer,
  uuid
) to service_role;
grant execute on function public.claim_billing_reconciliation_jobs(
  uuid,
  integer,
  integer,
  timestamptz
) to service_role;
grant execute on function public.complete_billing_reconciliation_job(
  uuid,
  uuid,
  text,
  text,
  timestamptz
) to service_role;
grant execute on function public.get_billing_reconciliation_health(timestamptz)
  to service_role;

comment on table app_private.billing_reconciliation_jobs is
  'Private metadata-only RevenueCat webhook inbox and subscriber refresh queue.';
comment on table app_private.billing_reconciliation_transitions is
  'Immutable aggregate-only audit for billing reconciliation queue state.';
