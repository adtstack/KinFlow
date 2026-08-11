-- KinFlow WP06-05 explicit paid-household assignment and remediation.
--
-- A client-selected household is persisted before a Store operation as a
-- bounded provisional binding. It is not an entitlement: only a verified
-- provider transaction confirms the binding. Conflicts never move an active
-- customer implicitly, and support resolution requires an immutable audit.

alter table public.billing_household_assignments
  add column binding_state text not null default 'confirmed' check (
    binding_state in ('provisional', 'confirmed')
  ),
  add column confirmed_at timestamptz default pg_catalog.statement_timestamp(),
  add column intent_expires_at timestamptz,
  add constraint billing_assignment_binding_state_ck check (
    (
      binding_state = 'confirmed'
      and confirmed_at is not null
      and intent_expires_at is null
    )
    or (
      binding_state = 'provisional'
      and confirmed_at is null
      and intent_expires_at is not null
      and intent_expires_at > assigned_at
    )
  ),
  add constraint billing_assignment_confirmation_order_ck check (
    confirmed_at is null or confirmed_at >= assigned_at
  );

update public.billing_household_assignments as assignment
set confirmed_at = assignment.assigned_at
where assignment.binding_state = 'confirmed';

create table app_private.billing_assignment_intents (
  id uuid primary key default extensions.gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete restrict,
  household_id uuid not null
    references public.households(id) on delete restrict,
  billing_customer_id uuid
    references public.billing_customers(id) on delete restrict,
  assignment_id uuid
    references public.billing_household_assignments(id) on delete restrict,
  idempotency_key uuid not null,
  request_hash bytea not null check (
    pg_catalog.octet_length(request_hash) = 32
  ),
  outcome text not null check (
    outcome in (
      'ready',
      'already_ready',
      'customer_conflict',
      'household_conflict'
    )
  ),
  lifecycle_state text not null check (
    lifecycle_state in (
      'prepared',
      'consumed',
      'released',
      'expired',
      'superseded',
      'conflict'
    )
  ),
  result_assignment_version bigint check (result_assignment_version > 0),
  intent_expires_at timestamptz,
  requeued_job_count integer not null default 0 check (
    requeued_job_count between 0 and 1000
  ),
  created_at timestamptz not null default pg_catalog.now(),
  resolved_at timestamptz,
  unique (auth_user_id, idempotency_key),
  constraint billing_assignment_intent_result_ck check (
    (
      outcome in ('ready', 'already_ready')
      and billing_customer_id is not null
      and assignment_id is not null
      and result_assignment_version is not null
      and lifecycle_state <> 'conflict'
    )
    or (
      outcome in ('customer_conflict', 'household_conflict')
      and assignment_id is null
      and result_assignment_version is null
      and intent_expires_at is null
      and lifecycle_state = 'conflict'
    )
  ),
  constraint billing_assignment_intent_resolution_ck check (
    (lifecycle_state in ('prepared', 'conflict') and resolved_at is null)
    or (lifecycle_state in (
      'consumed', 'released', 'expired', 'superseded'
    ) and resolved_at is not null)
  ),
  constraint billing_assignment_intent_expiry_ck check (
    intent_expires_at is null or intent_expires_at > created_at
  )
);

create index billing_assignment_intents_assignment_idx
  on app_private.billing_assignment_intents(
    assignment_id,
    lifecycle_state,
    created_at
  )
  where assignment_id is not null;

create table app_private.billing_assignment_release_results (
  auth_user_id uuid not null references auth.users(id) on delete restrict,
  idempotency_key uuid not null,
  request_hash bytea not null check (
    pg_catalog.octet_length(request_hash) = 32
  ),
  household_id uuid not null
    references public.households(id) on delete restrict,
  outcome text not null check (
    outcome in ('released', 'already_released', 'support_required')
  ),
  result_assignment_version bigint check (result_assignment_version > 0),
  created_at timestamptz not null default pg_catalog.now(),
  primary key (auth_user_id, idempotency_key)
);

create table app_private.billing_assignment_remediation_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  requester_user_id uuid not null references auth.users(id) on delete restrict,
  household_id uuid not null
    references public.households(id) on delete restrict,
  provider text not null check (provider = 'revenuecat'),
  environment text not null check (environment in ('sandbox', 'production')),
  issue_kind text not null check (
    issue_kind in (
      'customer_conflict',
      'household_conflict',
      'owner_membership_changed',
      'restore_conflict'
    )
  ),
  status text not null default 'open' check (
    status in ('open', 'resolved', 'rejected')
  ),
  subject_assignment_id uuid
    references public.billing_household_assignments(id) on delete restrict,
  idempotency_key uuid not null,
  request_hash bytea not null check (
    pg_catalog.octet_length(request_hash) = 32
  ),
  created_at timestamptz not null default pg_catalog.now(),
  resolved_at timestamptz,
  unique (requester_user_id, idempotency_key),
  constraint billing_assignment_remediation_resolution_ck check (
    (status = 'open' and resolved_at is null)
    or (status in ('resolved', 'rejected') and resolved_at is not null)
  )
);

create unique index billing_assignment_remediation_open_uq
  on app_private.billing_assignment_remediation_requests(
    requester_user_id,
    household_id,
    issue_kind
  )
  where status = 'open';

create table app_private.billing_assignment_remediation_command_results (
  requester_user_id uuid not null references auth.users(id) on delete restrict,
  idempotency_key uuid not null,
  request_hash bytea not null check (
    pg_catalog.octet_length(request_hash) = 32
  ),
  request_id uuid not null
    references app_private.billing_assignment_remediation_requests(id)
    on delete restrict,
  created_at timestamptz not null default pg_catalog.now(),
  primary key (requester_user_id, idempotency_key)
);

create table app_private.billing_assignment_transitions (
  id bigint generated always as identity primary key,
  assignment_id uuid not null
    references public.billing_household_assignments(id) on delete restrict,
  previous_assignment_id uuid
    references public.billing_household_assignments(id) on delete restrict,
  action text not null check (
    action in (
      'prepared',
      'renewed',
      'confirmed',
      'released',
      'expired',
      'transferred'
    )
  ),
  actor_kind text not null check (
    actor_kind in ('client', 'provider', 'system', 'support')
  ),
  actor_user_id uuid references auth.users(id) on delete restrict,
  source_household_id uuid
    references public.households(id) on delete restrict,
  target_household_id uuid not null
    references public.households(id) on delete restrict,
  previous_binding_state text check (
    previous_binding_state in ('provisional', 'confirmed')
  ),
  next_binding_state text not null check (
    next_binding_state in ('provisional', 'confirmed')
  ),
  reason_code text,
  correlation_id uuid not null,
  occurred_at timestamptz not null,
  constraint billing_assignment_transition_actor_ck check (
    (actor_kind = 'client' and actor_user_id is not null)
    or actor_kind <> 'client'
  )
);

create index billing_assignment_transitions_assignment_idx
  on app_private.billing_assignment_transitions(
    assignment_id,
    occurred_at,
    id
  );

create table app_private.billing_assignment_remediation_actions (
  id bigint generated always as identity primary key,
  request_id uuid not null unique
    references app_private.billing_assignment_remediation_requests(id)
    on delete restrict,
  action text not null check (
    action in ('transfer_customer', 'release_expired_provisional', 'reject')
  ),
  reason_code text not null check (
    reason_code in (
      'ownership_verified',
      'account_recovery',
      'duplicate_assignment',
      'policy_denied'
    )
  ),
  case_reference_hash bytea not null check (
    pg_catalog.octet_length(case_reference_hash) = 32
  ),
  previous_assignment_id uuid
    references public.billing_household_assignments(id) on delete restrict,
  result_assignment_id uuid
    references public.billing_household_assignments(id) on delete restrict,
  correlation_id uuid not null,
  resolved_at timestamptz not null
);

create or replace function app_private.reject_billing_assignment_audit_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'KFB59',
    message = 'billing assignment audit is immutable';
end;
$$;

revoke all on function
  app_private.reject_billing_assignment_audit_mutation()
  from public, anon, authenticated, service_role;

create trigger billing_assignment_transitions_immutable
before update or delete on app_private.billing_assignment_transitions
for each row execute function
  app_private.reject_billing_assignment_audit_mutation();

create trigger billing_assignment_remediation_actions_immutable
before update or delete on app_private.billing_assignment_remediation_actions
for each row execute function
  app_private.reject_billing_assignment_audit_mutation();

alter table app_private.billing_reconciliation_transitions
  drop constraint billing_reconciliation_transitions_transition_check;

alter table app_private.billing_reconciliation_transitions
  add constraint billing_reconciliation_transitions_transition_check check (
    transition in (
      'queued',
      'ignored',
      'dead_lettered',
      'replayed',
      'claimed',
      'retry_scheduled',
      'requeued',
      'succeeded'
    )
  );

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
  elsif old.processing_status = 'dead_letter'
    and old.last_error_code = 'ASSIGNMENT_REQUIRED'
    and new.processing_status = 'queued' then
    v_transition := 'requeued';
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

create or replace function app_private.requeue_assignment_required_jobs(
  p_auth_user_id uuid,
  p_environment text,
  p_as_of timestamptz
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  update app_private.billing_reconciliation_jobs as job
  set processing_status = 'queued',
      next_attempt_at = p_as_of,
      lease_owner = null,
      lease_token = null,
      lease_expires_at = null,
      completed_lease_token = null,
      last_error_code = null,
      updated_at = p_as_of,
      completed_at = null
  where job.auth_user_id = p_auth_user_id
    and job.environment = p_environment
    and job.processing_status = 'dead_letter'
    and job.last_error_code = 'ASSIGNMENT_REQUIRED'
    and job.attempts < job.max_attempts;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function app_private.requeue_assignment_required_jobs(
  uuid,
  text,
  timestamptz
) from public, anon, authenticated, service_role;

create or replace function app_private.confirm_provisional_billing_assignment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := pg_catalog.statement_timestamp();
  v_assignment public.billing_household_assignments%rowtype;
  v_correlation_id uuid;
begin
  select assignment.*
  into v_assignment
  from public.billing_household_assignments as assignment
  where assignment.billing_customer_id = new.billing_customer_id
    and assignment.status = 'active'
    and assignment.binding_state = 'provisional'
  for update;

  if not found then
    return null;
  end if;

  select receipt.correlation_id
  into v_correlation_id
  from public.billing_webhook_receipts as receipt
  where receipt.id = new.last_receipt_id;

  update public.billing_household_assignments as assignment
  set binding_state = 'confirmed',
      confirmed_at = v_now,
      intent_expires_at = null
  where assignment.id = v_assignment.id
  returning assignment.* into v_assignment;

  update app_private.billing_assignment_intents as intent
  set lifecycle_state = 'consumed',
      resolved_at = v_now
  where intent.assignment_id = v_assignment.id
    and intent.lifecycle_state = 'prepared';

  insert into app_private.billing_assignment_transitions(
    assignment_id,
    action,
    actor_kind,
    target_household_id,
    previous_binding_state,
    next_binding_state,
    reason_code,
    correlation_id,
    occurred_at
  ) values (
    v_assignment.id,
    'confirmed',
    'provider',
    v_assignment.household_id,
    'provisional',
    'confirmed',
    'verified_transaction',
    coalesce(v_correlation_id, extensions.gen_random_uuid()),
    v_now
  );

  return null;
end;
$$;

revoke all on function
  app_private.confirm_provisional_billing_assignment()
  from public, anon, authenticated, service_role;

create trigger billing_transactions_confirm_provisional_assignment
after insert or update of last_receipt_id on public.billing_transactions
for each row execute function
  app_private.confirm_provisional_billing_assignment();

create or replace function public.prepare_billing_household_assignment(
  p_household_id uuid,
  p_idempotency_key uuid
)
returns table (
  intent_id uuid,
  outcome text,
  binding_state text,
  assignment_version bigint,
  intent_expires_at timestamptz,
  requeued_job_count integer,
  duplicate boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := pg_catalog.statement_timestamp();
  v_expires_at timestamptz := v_now + interval '30 minutes';
  v_auth_user_id uuid := (select auth.uid());
  v_runtime app_private.billing_runtime_config%rowtype;
  v_request_hash bytea;
  v_existing app_private.billing_assignment_intents%rowtype;
  v_customer public.billing_customers%rowtype;
  v_customer_assignment public.billing_household_assignments%rowtype;
  v_household_assignment public.billing_household_assignments%rowtype;
  v_assignment public.billing_household_assignments%rowtype;
  v_intent app_private.billing_assignment_intents%rowtype;
  v_outcome text;
  v_requeued integer := 0;
begin
  if v_auth_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'authentication required';
  end if;
  if p_household_id is null or p_idempotency_key is null then
    raise exception using
      errcode = '22023',
      message = 'invalid billing assignment request';
  end if;

  v_request_hash := extensions.digest(
    pg_catalog.convert_to(
      pg_catalog.jsonb_build_object(
        'command', 'prepare',
        'authUserId', v_auth_user_id,
        'householdId', p_household_id
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  select intent.*
  into v_existing
  from app_private.billing_assignment_intents as intent
  where intent.auth_user_id = v_auth_user_id
    and intent.idempotency_key = p_idempotency_key;

  if found then
    if v_existing.request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFB50',
        message = 'billing assignment idempotency key reused';
    end if;

    select assignment.*
    into v_assignment
    from public.billing_household_assignments as assignment
    where assignment.id = v_existing.assignment_id;

    return query select
      v_existing.id,
      v_existing.outcome,
      case
        when v_assignment.id is null then null::text
        else v_assignment.binding_state
      end,
      case
        when v_assignment.id is null then null::bigint
        else v_assignment.version
      end,
      case
        when v_assignment.binding_state = 'provisional'
          and v_assignment.status = 'active'
          then v_assignment.intent_expires_at
        else null::timestamptz
      end,
      v_existing.requeued_job_count,
      true;
    return;
  end if;

  if not exists (
    select 1
    from public.household_members as member
    where member.household_id = p_household_id
      and member.auth_user_id = v_auth_user_id
      and member.removed_at is null
      and member.role in ('owner', 'admin')
  ) then
    raise exception using
      errcode = '42501',
      message = 'billing assignment requires active Owner or Admin';
  end if;

  select config.*
  into v_runtime
  from app_private.billing_runtime_config as config
  where config.singleton
  for share;

  if not v_runtime.ingestion_enabled
    or v_runtime.accepted_environment = 'disabled' then
    raise exception using
      errcode = 'KFB51',
      message = 'billing assignment is unavailable';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'billing-assignment-user:' || v_auth_user_id::text,
      0
    )
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'billing-assignment-household:' || p_household_id::text,
      0
    )
  );

  select customer.*
  into v_customer
  from public.billing_customers as customer
  where customer.provider = v_runtime.provider
    and customer.environment = v_runtime.accepted_environment
    and customer.auth_user_id = v_auth_user_id
  for update;

  if not found then
    insert into public.billing_customers(
      auth_user_id,
      provider,
      environment,
      provider_customer_ref,
      provider_customer_ref_hash
    ) values (
      v_auth_user_id,
      v_runtime.provider,
      v_runtime.accepted_environment,
      v_auth_user_id::text,
      extensions.digest(
        pg_catalog.convert_to(v_auth_user_id::text, 'UTF8'),
        'sha256'
      )
    )
    returning * into v_customer;
  end if;

  select assignment.*
  into v_customer_assignment
  from public.billing_household_assignments as assignment
  where assignment.billing_customer_id = v_customer.id
    and assignment.status = 'active'
  for update;

  if found
    and v_customer_assignment.binding_state = 'provisional'
    and v_customer_assignment.intent_expires_at <= v_now
    and not exists (
      select 1
      from public.billing_transactions as transaction
      where transaction.billing_customer_id = v_customer.id
    ) then
    update public.billing_household_assignments as assignment
    set status = 'ended',
        ended_at = v_now
    where assignment.id = v_customer_assignment.id;
    update app_private.billing_assignment_intents as intent
    set lifecycle_state = 'expired',
        resolved_at = v_now
    where intent.assignment_id = v_customer_assignment.id
      and intent.lifecycle_state = 'prepared';
    insert into app_private.billing_assignment_transitions(
      assignment_id,
      action,
      actor_kind,
      actor_user_id,
      source_household_id,
      target_household_id,
      previous_binding_state,
      next_binding_state,
      reason_code,
      correlation_id,
      occurred_at
    ) values (
      v_customer_assignment.id,
      'expired',
      'system',
      null,
      v_customer_assignment.household_id,
      v_customer_assignment.household_id,
      'provisional',
      'provisional',
      'intent_expired',
      p_idempotency_key,
      v_now
    );
    v_customer_assignment := null;
  end if;

  if v_customer_assignment.id is not null
    and v_customer_assignment.household_id <> p_household_id then
    if v_customer_assignment.binding_state = 'provisional'
      and not exists (
        select 1
        from public.billing_transactions as transaction
        where transaction.billing_customer_id = v_customer.id
      ) then
      update public.billing_household_assignments as assignment
      set status = 'ended',
          ended_at = v_now
      where assignment.id = v_customer_assignment.id;
      update app_private.billing_assignment_intents as intent
      set lifecycle_state = 'superseded',
          resolved_at = v_now
      where intent.assignment_id = v_customer_assignment.id
        and intent.lifecycle_state = 'prepared';
      insert into app_private.billing_assignment_transitions(
        assignment_id,
        action,
        actor_kind,
        actor_user_id,
        source_household_id,
        target_household_id,
        previous_binding_state,
        next_binding_state,
        reason_code,
        correlation_id,
        occurred_at
      ) values (
        v_customer_assignment.id,
        'released',
        'client',
        v_auth_user_id,
        v_customer_assignment.household_id,
        p_household_id,
        'provisional',
        'provisional',
        'household_reselected',
        p_idempotency_key,
        v_now
      );
      v_customer_assignment := null;
    else
      v_outcome := 'customer_conflict';
    end if;
  end if;

  if v_outcome is null then
    select assignment.*
    into v_household_assignment
    from public.billing_household_assignments as assignment
    where assignment.household_id = p_household_id
      and assignment.status = 'active'
    for update;

    if found
      and v_household_assignment.billing_customer_id <> v_customer.id
      and v_household_assignment.binding_state = 'provisional'
      and v_household_assignment.intent_expires_at <= v_now
      and not exists (
        select 1
        from public.billing_transactions as transaction
        where transaction.billing_customer_id =
          v_household_assignment.billing_customer_id
      ) then
      update public.billing_household_assignments as assignment
      set status = 'ended',
          ended_at = v_now
      where assignment.id = v_household_assignment.id;
      update app_private.billing_assignment_intents as intent
      set lifecycle_state = 'expired',
          resolved_at = v_now
      where intent.assignment_id = v_household_assignment.id
        and intent.lifecycle_state = 'prepared';
      insert into app_private.billing_assignment_transitions(
        assignment_id,
        action,
        actor_kind,
        source_household_id,
        target_household_id,
        previous_binding_state,
        next_binding_state,
        reason_code,
        correlation_id,
        occurred_at
      ) values (
        v_household_assignment.id,
        'expired',
        'system',
        v_household_assignment.household_id,
        v_household_assignment.household_id,
        'provisional',
        'provisional',
        'intent_expired_during_prepare',
        p_idempotency_key,
        v_now
      );
      v_household_assignment := null;
    end if;

    if v_household_assignment.id is not null
      and v_household_assignment.billing_customer_id <> v_customer.id then
      v_outcome := 'household_conflict';
    elsif v_household_assignment.id is not null then
      v_assignment := v_household_assignment;
    end if;
  end if;

  if v_outcome is null and v_assignment.id is null
    and v_customer_assignment.id is not null then
    v_assignment := v_customer_assignment;
  end if;

  if v_outcome is null and v_assignment.id is null then
    insert into public.billing_household_assignments(
      billing_customer_id,
      billing_owner_user_id,
      household_id,
      status,
      assigned_at,
      binding_state,
      confirmed_at,
      intent_expires_at
    ) values (
      v_customer.id,
      v_auth_user_id,
      p_household_id,
      'active',
      v_now,
      'provisional',
      null,
      v_expires_at
    )
    returning * into v_assignment;
    v_outcome := 'ready';

    insert into app_private.billing_assignment_transitions(
      assignment_id,
      action,
      actor_kind,
      actor_user_id,
      target_household_id,
      previous_binding_state,
      next_binding_state,
      reason_code,
      correlation_id,
      occurred_at
    ) values (
      v_assignment.id,
      'prepared',
      'client',
      v_auth_user_id,
      p_household_id,
      null,
      'provisional',
      'purchase_intent',
      p_idempotency_key,
      v_now
    );
  elsif v_outcome is null and v_assignment.binding_state = 'provisional' then
    update public.billing_household_assignments as assignment
    set intent_expires_at = v_expires_at
    where assignment.id = v_assignment.id
    returning assignment.* into v_assignment;
    v_outcome := 'ready';

    update app_private.billing_assignment_intents as intent
    set lifecycle_state = 'superseded',
        resolved_at = v_now
    where intent.assignment_id = v_assignment.id
      and intent.lifecycle_state = 'prepared';

    insert into app_private.billing_assignment_transitions(
      assignment_id,
      action,
      actor_kind,
      actor_user_id,
      target_household_id,
      previous_binding_state,
      next_binding_state,
      reason_code,
      correlation_id,
      occurred_at
    ) values (
      v_assignment.id,
      'renewed',
      'client',
      v_auth_user_id,
      p_household_id,
      'provisional',
      'provisional',
      'purchase_intent_renewed',
      p_idempotency_key,
      v_now
    );
  elsif v_outcome is null then
    v_outcome := 'already_ready';
  end if;

  if v_outcome in ('ready', 'already_ready') then
    v_requeued := app_private.requeue_assignment_required_jobs(
      v_auth_user_id,
      v_runtime.accepted_environment,
      v_now
    );
  end if;

  insert into app_private.billing_assignment_intents(
    auth_user_id,
    household_id,
    billing_customer_id,
    assignment_id,
    idempotency_key,
    request_hash,
    outcome,
    lifecycle_state,
    result_assignment_version,
    intent_expires_at,
    requeued_job_count,
    created_at,
    resolved_at
  ) values (
    v_auth_user_id,
    p_household_id,
    v_customer.id,
    case when v_outcome in ('ready', 'already_ready')
      then v_assignment.id else null end,
    p_idempotency_key,
    v_request_hash,
    v_outcome,
    case
      when v_outcome = 'ready' then 'prepared'
      when v_outcome = 'already_ready' then 'consumed'
      else 'conflict'
    end,
    case when v_outcome in ('ready', 'already_ready')
      then v_assignment.version else null end,
    case when v_assignment.binding_state = 'provisional'
      then v_assignment.intent_expires_at else null end,
    v_requeued,
    v_now,
    case when v_outcome = 'already_ready' then v_now else null end
  ) returning * into v_intent;

  return query select
    v_intent.id,
    v_intent.outcome,
    case when v_assignment.id is null
      then null::text else v_assignment.binding_state end,
    case when v_assignment.id is null
      then null::bigint else v_assignment.version end,
    case when v_assignment.binding_state = 'provisional'
      then v_assignment.intent_expires_at else null::timestamptz end,
    v_requeued,
    false;
end;
$$;

create or replace function public.release_billing_household_assignment(
  p_household_id uuid,
  p_expected_assignment_version bigint,
  p_idempotency_key uuid
)
returns table (
  outcome text,
  assignment_version bigint,
  duplicate boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := pg_catalog.statement_timestamp();
  v_auth_user_id uuid := (select auth.uid());
  v_request_hash bytea;
  v_existing app_private.billing_assignment_release_results%rowtype;
  v_assignment public.billing_household_assignments%rowtype;
  v_outcome text;
begin
  if v_auth_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'authentication required';
  end if;
  if p_household_id is null
    or p_expected_assignment_version is null
    or p_expected_assignment_version < 1
    or p_idempotency_key is null then
    raise exception using
      errcode = '22023',
      message = 'invalid billing assignment release';
  end if;

  v_request_hash := extensions.digest(
    pg_catalog.convert_to(
      pg_catalog.jsonb_build_object(
        'command', 'release',
        'householdId', p_household_id,
        'expectedVersion', p_expected_assignment_version
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  select result.*
  into v_existing
  from app_private.billing_assignment_release_results as result
  where result.auth_user_id = v_auth_user_id
    and result.idempotency_key = p_idempotency_key;

  if found then
    if v_existing.request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFB50',
        message = 'billing assignment idempotency key reused';
    end if;
    return query select
      v_existing.outcome,
      v_existing.result_assignment_version,
      true;
    return;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'billing-assignment-user:' || v_auth_user_id::text,
      0
    )
  );

  select assignment.*
  into v_assignment
  from public.billing_household_assignments as assignment
  where assignment.household_id = p_household_id
    and assignment.billing_owner_user_id = v_auth_user_id
    and assignment.status = 'active'
  for update;

  if not found then
    v_outcome := 'already_released';
  elsif v_assignment.version <> p_expected_assignment_version then
    raise exception using
      errcode = 'KFB52',
      message = 'billing assignment version conflict';
  elsif v_assignment.binding_state = 'confirmed' then
    v_outcome := 'support_required';
  else
    update public.billing_household_assignments as assignment
    set status = 'ended',
        ended_at = v_now
    where assignment.id = v_assignment.id
    returning assignment.* into v_assignment;

    update app_private.billing_assignment_intents as intent
    set lifecycle_state = 'released',
        resolved_at = v_now
    where intent.assignment_id = v_assignment.id
      and intent.lifecycle_state = 'prepared';

    insert into app_private.billing_assignment_transitions(
      assignment_id,
      action,
      actor_kind,
      actor_user_id,
      source_household_id,
      target_household_id,
      previous_binding_state,
      next_binding_state,
      reason_code,
      correlation_id,
      occurred_at
    ) values (
      v_assignment.id,
      'released',
      'client',
      v_auth_user_id,
      p_household_id,
      p_household_id,
      'provisional',
      'provisional',
      'client_release',
      p_idempotency_key,
      v_now
    );
    v_outcome := 'released';
  end if;

  insert into app_private.billing_assignment_release_results(
    auth_user_id,
    idempotency_key,
    request_hash,
    household_id,
    outcome,
    result_assignment_version,
    created_at
  ) values (
    v_auth_user_id,
    p_idempotency_key,
    v_request_hash,
    p_household_id,
    v_outcome,
    case when v_assignment.id is null then null else v_assignment.version end,
    v_now
  );

  return query select
    v_outcome,
    case when v_assignment.id is null then null else v_assignment.version end,
    false;
end;
$$;

create or replace function public.get_billing_household_assignment_status(
  p_household_id uuid
)
returns table (
  household_id uuid,
  assignment_state text,
  ownership_state text,
  owner_membership_state text,
  can_prepare boolean,
  requires_support boolean,
  assignment_version bigint,
  intent_expires_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_auth_user_id uuid := (select auth.uid());
begin
  if v_auth_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'authentication required';
  end if;
  if not app_private.is_active_household_member(p_household_id) then
    raise exception using
      errcode = '42501',
      message = 'active household membership required';
  end if;

  return query
  select
    p_household_id,
    coalesce(assignment.binding_state, 'none'),
    case
      when assignment.id is null then 'unassigned'
      when assignment.billing_owner_user_id = v_auth_user_id
        then 'current_user'
      else 'another_user'
    end,
    case
      when assignment.id is null then 'none'
      when exists (
        select 1
        from public.household_members as owner_member
        where owner_member.household_id = p_household_id
          and owner_member.auth_user_id = assignment.billing_owner_user_id
          and owner_member.removed_at is null
      ) then 'active'
      else 'removed'
    end,
    exists (
      select 1
      from public.household_members as caller_member
      where caller_member.household_id = p_household_id
        and caller_member.auth_user_id = v_auth_user_id
        and caller_member.removed_at is null
        and caller_member.role in ('owner', 'admin')
    ) and (
      assignment.id is null
      or assignment.billing_owner_user_id = v_auth_user_id
    ),
    coalesce(
      assignment.id is not null and not exists (
        select 1
        from public.household_members as owner_member
        where owner_member.household_id = p_household_id
          and owner_member.auth_user_id = assignment.billing_owner_user_id
          and owner_member.removed_at is null
      ),
      false
    ),
    assignment.version,
    case when assignment.binding_state = 'provisional'
      then assignment.intent_expires_at else null end
  from (select 1) as singleton
  left join public.billing_household_assignments as assignment
    on assignment.household_id = p_household_id
   and assignment.status = 'active';
end;
$$;

create or replace function public.request_billing_assignment_remediation(
  p_household_id uuid,
  p_issue_kind text,
  p_idempotency_key uuid
)
returns table (
  request_id uuid,
  status text,
  issue_kind text,
  duplicate boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := pg_catalog.statement_timestamp();
  v_auth_user_id uuid := (select auth.uid());
  v_runtime app_private.billing_runtime_config%rowtype;
  v_request_hash bytea;
  v_command_result
    app_private.billing_assignment_remediation_command_results%rowtype;
  v_request app_private.billing_assignment_remediation_requests%rowtype;
  v_assignment public.billing_household_assignments%rowtype;
begin
  if v_auth_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'authentication required';
  end if;
  if p_household_id is null
    or p_idempotency_key is null
    or p_issue_kind not in (
      'customer_conflict',
      'household_conflict',
      'owner_membership_changed',
      'restore_conflict'
    ) then
    raise exception using
      errcode = '22023',
      message = 'invalid billing remediation request';
  end if;
  if not exists (
    select 1
    from public.household_members as member
    where member.household_id = p_household_id
      and member.auth_user_id = v_auth_user_id
      and member.removed_at is null
      and member.role in ('owner', 'admin')
  ) then
    raise exception using
      errcode = '42501',
      message = 'billing remediation requires active Owner or Admin';
  end if;

  select config.*
  into v_runtime
  from app_private.billing_runtime_config as config
  where config.singleton;

  if not v_runtime.ingestion_enabled
    or v_runtime.accepted_environment = 'disabled' then
    raise exception using
      errcode = 'KFB51',
      message = 'billing assignment is unavailable';
  end if;

  v_request_hash := extensions.digest(
    pg_catalog.convert_to(
      pg_catalog.jsonb_build_object(
        'householdId', p_household_id,
        'issueKind', p_issue_kind
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  select command_result.*
  into v_command_result
  from app_private.billing_assignment_remediation_command_results
    as command_result
  where command_result.requester_user_id = v_auth_user_id
    and command_result.idempotency_key = p_idempotency_key;

  if found then
    if v_command_result.request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFB50',
        message = 'billing assignment idempotency key reused';
    end if;
    select request.*
    into v_request
    from app_private.billing_assignment_remediation_requests as request
    where request.id = v_command_result.request_id;
    return query select
      v_request.id,
      v_request.status,
      v_request.issue_kind,
      true;
    return;
  end if;

  select request.*
  into v_request
  from app_private.billing_assignment_remediation_requests as request
  where request.requester_user_id = v_auth_user_id
    and request.household_id = p_household_id
    and request.issue_kind = p_issue_kind
    and request.status = 'open'
  for update;

  if found then
    insert into app_private.billing_assignment_remediation_command_results(
      requester_user_id,
      idempotency_key,
      request_hash,
      request_id,
      created_at
    ) values (
      v_auth_user_id,
      p_idempotency_key,
      v_request_hash,
      v_request.id,
      v_now
    );
    return query select
      v_request.id,
      v_request.status,
      v_request.issue_kind,
      true;
    return;
  end if;

  select assignment.*
  into v_assignment
  from public.billing_household_assignments as assignment
  join public.billing_customers as customer
    on customer.id = assignment.billing_customer_id
  where assignment.status = 'active'
    and customer.provider = v_runtime.provider
    and customer.environment = v_runtime.accepted_environment
    and (
      assignment.household_id = p_household_id
      or customer.auth_user_id = v_auth_user_id
    )
  order by (customer.auth_user_id = v_auth_user_id) desc
  limit 1;

  insert into app_private.billing_assignment_remediation_requests(
    requester_user_id,
    household_id,
    provider,
    environment,
    issue_kind,
    status,
    subject_assignment_id,
    idempotency_key,
    request_hash,
    created_at
  ) values (
    v_auth_user_id,
    p_household_id,
    v_runtime.provider,
    v_runtime.accepted_environment,
    p_issue_kind,
    'open',
    v_assignment.id,
    p_idempotency_key,
    v_request_hash,
    v_now
  ) returning * into v_request;

  insert into app_private.billing_assignment_remediation_command_results(
    requester_user_id,
    idempotency_key,
    request_hash,
    request_id,
    created_at
  ) values (
    v_auth_user_id,
    p_idempotency_key,
    v_request_hash,
    v_request.id,
    v_now
  );

  return query select
    v_request.id,
    v_request.status,
    v_request.issue_kind,
    false;
end;
$$;

create or replace function public.expire_billing_household_assignments(
  p_as_of timestamptz,
  p_limit integer,
  p_correlation_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer := 0;
  v_assignment public.billing_household_assignments%rowtype;
begin
  if p_as_of is null
    or p_limit not between 1 and 100
    or p_correlation_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid billing assignment expiry request';
  end if;

  for v_assignment in
    select assignment.*
    from public.billing_household_assignments as assignment
    where assignment.status = 'active'
      and assignment.binding_state = 'provisional'
      and assignment.intent_expires_at <= p_as_of
      and not exists (
        select 1
        from public.billing_transactions as transaction
        where transaction.billing_customer_id = assignment.billing_customer_id
      )
    order by assignment.intent_expires_at, assignment.id
    for update skip locked
    limit p_limit
  loop
    update public.billing_household_assignments as assignment
    set status = 'ended',
        ended_at = p_as_of
    where assignment.id = v_assignment.id;

    update app_private.billing_assignment_intents as intent
    set lifecycle_state = 'expired',
        resolved_at = p_as_of
    where intent.assignment_id = v_assignment.id
      and intent.lifecycle_state = 'prepared';

    insert into app_private.billing_assignment_transitions(
      assignment_id,
      action,
      actor_kind,
      source_household_id,
      target_household_id,
      previous_binding_state,
      next_binding_state,
      reason_code,
      correlation_id,
      occurred_at
    ) values (
      v_assignment.id,
      'expired',
      'system',
      v_assignment.household_id,
      v_assignment.household_id,
      'provisional',
      'provisional',
      'intent_expired',
      p_correlation_id,
      p_as_of
    );
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

create or replace function public.resolve_billing_assignment_remediation(
  p_request_id uuid,
  p_action text,
  p_expected_assignment_version bigint,
  p_reason_code text,
  p_case_reference_hash_base64 text,
  p_as_of timestamptz,
  p_correlation_id uuid
)
returns table (
  request_id uuid,
  request_status text,
  resolution text,
  assignment_id uuid,
  assignment_version bigint,
  requeued_job_count integer,
  duplicate boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_case_hash bytea;
  v_request app_private.billing_assignment_remediation_requests%rowtype;
  v_existing_action app_private.billing_assignment_remediation_actions%rowtype;
  v_source_assignment public.billing_household_assignments%rowtype;
  v_target_assignment public.billing_household_assignments%rowtype;
  v_new_assignment public.billing_household_assignments%rowtype;
  v_customer public.billing_customers%rowtype;
  v_source_entitlement public.household_entitlements%rowtype;
  v_target_entitlement public.household_entitlements%rowtype;
  v_requeued integer := 0;
  v_resolution text;
begin
  begin
    v_case_hash := pg_catalog.decode(p_case_reference_hash_base64, 'base64');
  exception when others then
    raise exception using
      errcode = '22023',
      message = 'invalid billing remediation resolution';
  end;

  if p_request_id is null
    or p_action not in (
      'transfer_customer',
      'release_expired_provisional',
      'reject'
    )
    or p_reason_code not in (
      'ownership_verified',
      'account_recovery',
      'duplicate_assignment',
      'policy_denied'
    )
    or pg_catalog.octet_length(v_case_hash) <> 32
    or pg_catalog.encode(v_case_hash, 'base64')
      <> p_case_reference_hash_base64
    or p_as_of is null
    or p_correlation_id is null
    or p_action <> 'reject' and (
      p_expected_assignment_version is null
      or p_expected_assignment_version < 1
    ) then
    raise exception using
      errcode = '22023',
      message = 'invalid billing remediation resolution';
  end if;

  select request.*
  into v_request
  from app_private.billing_assignment_remediation_requests as request
  where request.id = p_request_id
  for update;

  if not found then
    raise exception using
      errcode = 'KFB53',
      message = 'billing remediation request unavailable';
  end if;

  if v_request.status <> 'open' then
    select action.*
    into v_existing_action
    from app_private.billing_assignment_remediation_actions as action
    where action.request_id = v_request.id;

    if not found
      or v_existing_action.action <> p_action
      or v_existing_action.reason_code <> p_reason_code
      or v_existing_action.case_reference_hash <> v_case_hash then
      raise exception using
        errcode = 'KFB55',
        message = 'billing remediation resolution conflict';
    end if;

    select assignment.*
    into v_new_assignment
    from public.billing_household_assignments as assignment
    where assignment.id = v_existing_action.result_assignment_id;

    return query select
      v_request.id,
      v_request.status,
      v_existing_action.action,
      v_existing_action.result_assignment_id,
      v_new_assignment.version,
      0,
      true;
    return;
  end if;

  if p_action = 'reject' then
    update app_private.billing_assignment_remediation_requests as request
    set status = 'rejected',
        resolved_at = p_as_of
    where request.id = v_request.id
    returning request.* into v_request;
    v_resolution := 'reject';

    insert into app_private.billing_assignment_remediation_actions(
      request_id,
      action,
      reason_code,
      case_reference_hash,
      previous_assignment_id,
      result_assignment_id,
      correlation_id,
      resolved_at
    ) values (
      v_request.id,
      p_action,
      p_reason_code,
      v_case_hash,
      v_request.subject_assignment_id,
      null,
      p_correlation_id,
      p_as_of
    );

    return query select
      v_request.id,
      v_request.status,
      v_resolution,
      null::uuid,
      null::bigint,
      0,
      false;
    return;
  end if;

  select assignment.*
  into v_source_assignment
  from public.billing_household_assignments as assignment
  where assignment.id = v_request.subject_assignment_id
  for update;

  if not found
    or v_source_assignment.status <> 'active'
    or v_source_assignment.version <> p_expected_assignment_version then
    raise exception using
      errcode = 'KFB52',
      message = 'billing assignment version conflict';
  end if;

  select customer.*
  into v_customer
  from public.billing_customers as customer
  where customer.id = v_source_assignment.billing_customer_id
  for update;

  if p_action = 'release_expired_provisional' then
    if v_source_assignment.household_id <> v_request.household_id
      or v_source_assignment.binding_state <> 'provisional'
      or v_source_assignment.intent_expires_at > p_as_of
      or exists (
        select 1
        from public.billing_transactions as transaction
        where transaction.billing_customer_id = v_customer.id
      ) then
      raise exception using
        errcode = 'KFB54',
        message = 'billing remediation policy denied';
    end if;

    update public.billing_household_assignments as assignment
    set status = 'ended',
        ended_at = p_as_of
    where assignment.id = v_source_assignment.id
    returning assignment.* into v_source_assignment;

    update app_private.billing_assignment_intents as intent
    set lifecycle_state = 'expired',
        resolved_at = p_as_of
    where intent.assignment_id = v_source_assignment.id
      and intent.lifecycle_state = 'prepared';

    insert into app_private.billing_assignment_transitions(
      assignment_id,
      action,
      actor_kind,
      source_household_id,
      target_household_id,
      previous_binding_state,
      next_binding_state,
      reason_code,
      correlation_id,
      occurred_at
    ) values (
      v_source_assignment.id,
      'released',
      'support',
      v_source_assignment.household_id,
      v_source_assignment.household_id,
      'provisional',
      'provisional',
      p_reason_code,
      p_correlation_id,
      p_as_of
    );
    v_resolution := 'release_expired_provisional';
  else
    if v_customer.auth_user_id <> v_request.requester_user_id
      or v_source_assignment.binding_state <> 'confirmed'
      or not exists (
        select 1
        from public.household_members as member
        where member.household_id = v_request.household_id
          and member.auth_user_id = v_request.requester_user_id
          and member.removed_at is null
          and member.role in ('owner', 'admin')
      ) then
      raise exception using
        errcode = 'KFB54',
        message = 'billing remediation policy denied';
    end if;

    select assignment.*
    into v_target_assignment
    from public.billing_household_assignments as assignment
    where assignment.household_id = v_request.household_id
      and assignment.status = 'active'
    for update;

    if found and v_target_assignment.id <> v_source_assignment.id then
      raise exception using
        errcode = 'KFB54',
        message = 'billing remediation policy denied';
    end if;

    if v_source_assignment.household_id = v_request.household_id then
      v_new_assignment := v_source_assignment;
    else
      select entitlement.*
      into v_source_entitlement
      from public.household_entitlements as entitlement
      where entitlement.household_id = v_source_assignment.household_id
      for update;

      select entitlement.*
      into v_target_entitlement
      from public.household_entitlements as entitlement
      where entitlement.household_id = v_request.household_id
      for update;

      if v_target_entitlement.assignment_id is not null
        or v_target_entitlement.status <> 'none' then
        raise exception using
          errcode = 'KFB54',
          message = 'billing remediation policy denied';
      end if;

      update public.household_entitlements as entitlement
      set assignment_id = null,
          billing_owner_user_id = null,
          plan_code = 'free',
          status = 'none',
          source = 'none',
          product_id = null,
          current_period_start = null,
          current_period_end = null,
          will_renew = false,
          features = case
            when free_plan.limits_finalized then free_plan.feature_limits
            else '{}'::jsonb
          end,
          provider_updated_at = null,
          verified_at = p_as_of
      from public.plan_catalog as free_plan
      where entitlement.household_id = v_source_assignment.household_id
        and free_plan.plan_code = 'free';

      update public.billing_household_assignments as assignment
      set status = 'ended',
          ended_at = p_as_of
      where assignment.id = v_source_assignment.id
      returning assignment.* into v_source_assignment;

      insert into public.billing_household_assignments(
        billing_customer_id,
        billing_owner_user_id,
        household_id,
        status,
        assigned_at,
        binding_state,
        confirmed_at,
        intent_expires_at
      ) values (
        v_customer.id,
        v_customer.auth_user_id,
        v_request.household_id,
        'active',
        p_as_of,
        'confirmed',
        p_as_of,
        null
      ) returning * into v_new_assignment;

      update public.household_entitlements as entitlement
      set assignment_id = v_new_assignment.id,
          billing_owner_user_id = v_customer.auth_user_id,
          plan_code = v_source_entitlement.plan_code,
          status = v_source_entitlement.status,
          source = v_source_entitlement.source,
          product_id = v_source_entitlement.product_id,
          current_period_start = v_source_entitlement.current_period_start,
          current_period_end = v_source_entitlement.current_period_end,
          will_renew = v_source_entitlement.will_renew,
          features = v_source_entitlement.features,
          provider_updated_at = v_source_entitlement.provider_updated_at,
          verified_at = p_as_of
      where entitlement.household_id = v_request.household_id;

      insert into app_private.billing_assignment_transitions(
        assignment_id,
        previous_assignment_id,
        action,
        actor_kind,
        source_household_id,
        target_household_id,
        previous_binding_state,
        next_binding_state,
        reason_code,
        correlation_id,
        occurred_at
      ) values (
        v_new_assignment.id,
        v_source_assignment.id,
        'transferred',
        'support',
        v_source_assignment.household_id,
        v_request.household_id,
        'confirmed',
        'confirmed',
        p_reason_code,
        p_correlation_id,
        p_as_of
      );
    end if;

    v_requeued := app_private.requeue_assignment_required_jobs(
      v_customer.auth_user_id,
      v_customer.environment,
      p_as_of
    );
    v_resolution := 'transfer_customer';
  end if;

  update app_private.billing_assignment_remediation_requests as request
  set status = 'resolved',
      resolved_at = p_as_of
  where request.id = v_request.id
  returning request.* into v_request;

  insert into app_private.billing_assignment_remediation_actions(
    request_id,
    action,
    reason_code,
    case_reference_hash,
    previous_assignment_id,
    result_assignment_id,
    correlation_id,
    resolved_at
  ) values (
    v_request.id,
    p_action,
    p_reason_code,
    v_case_hash,
    v_source_assignment.id,
    v_new_assignment.id,
    p_correlation_id,
    p_as_of
  );

  return query select
    v_request.id,
    v_request.status,
    v_resolution,
    v_new_assignment.id,
    v_new_assignment.version,
    v_requeued,
    false;
end;
$$;

-- Periodic work only applies to provider-confirmed assignments. The same
-- scheduler also retires expired provisional choices before selecting work.
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

  perform public.expire_billing_household_assignments(
    p_as_of,
    p_limit,
    p_correlation_id
  );

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
     and assignment.binding_state = 'confirmed'
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

-- Webhook-triggered work accepts either a confirmed binding or a still-valid
-- explicit provisional choice. An expired intent resolves to a null household
-- and the worker preserves the existing ASSIGNMENT_REQUIRED fail-closed path.
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
   and (
     assignment.binding_state = 'confirmed'
     or assignment.intent_expires_at > p_as_of
   )
  order by claimed.next_attempt_at nulls first, claimed.received_at, claimed.id;
end;
$$;

revoke all on table app_private.billing_assignment_intents
  from public, anon, authenticated, service_role;
revoke all on table app_private.billing_assignment_release_results
  from public, anon, authenticated, service_role;
revoke all on table app_private.billing_assignment_remediation_requests
  from public, anon, authenticated, service_role;
revoke all on table
  app_private.billing_assignment_remediation_command_results
  from public, anon, authenticated, service_role;
revoke all on table app_private.billing_assignment_transitions
  from public, anon, authenticated, service_role;
revoke all on sequence app_private.billing_assignment_transitions_id_seq
  from public, anon, authenticated, service_role;
revoke all on table app_private.billing_assignment_remediation_actions
  from public, anon, authenticated, service_role;
revoke all on sequence
  app_private.billing_assignment_remediation_actions_id_seq
  from public, anon, authenticated, service_role;

revoke all on function public.prepare_billing_household_assignment(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.release_billing_household_assignment(
  uuid,
  bigint,
  uuid
) from public, anon, authenticated, service_role;
revoke all on function public.get_billing_household_assignment_status(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.request_billing_assignment_remediation(
  uuid,
  text,
  uuid
) from public, anon, authenticated, service_role;
revoke all on function public.expire_billing_household_assignments(
  timestamptz,
  integer,
  uuid
) from public, anon, authenticated, service_role;
revoke all on function public.resolve_billing_assignment_remediation(
  uuid,
  text,
  bigint,
  text,
  text,
  timestamptz,
  uuid
) from public, anon, authenticated, service_role;

grant execute on function public.prepare_billing_household_assignment(
  uuid,
  uuid
) to authenticated;
grant execute on function public.release_billing_household_assignment(
  uuid,
  bigint,
  uuid
) to authenticated;
grant execute on function public.get_billing_household_assignment_status(uuid)
  to authenticated;
grant execute on function public.request_billing_assignment_remediation(
  uuid,
  text,
  uuid
) to authenticated;
grant execute on function public.expire_billing_household_assignments(
  timestamptz,
  integer,
  uuid
) to service_role;
grant execute on function public.resolve_billing_assignment_remediation(
  uuid,
  text,
  bigint,
  text,
  text,
  timestamptz,
  uuid
) to service_role;

comment on table app_private.billing_assignment_intents is
  'Private idempotent explicit household selection results without provider transaction data.';
comment on table app_private.billing_assignment_release_results is
  'Private idempotent provisional assignment release results.';
comment on table app_private.billing_assignment_remediation_requests is
  'Private aggregate support requests without free-form ticket or provider identifiers.';
comment on table
  app_private.billing_assignment_remediation_command_results is
  'Private idempotency aliases for aggregate remediation request results.';
comment on table app_private.billing_assignment_transitions is
  'Immutable assignment lifecycle audit for client provider system and support actions.';
comment on table app_private.billing_assignment_remediation_actions is
  'Immutable support resolution audit with only a SHA-256 external case reference.';
comment on function public.prepare_billing_household_assignment(uuid, uuid) is
  'Authenticated Owner/Admin purchase preflight that creates a bounded explicit assignment and requeues missing-assignment work.';
comment on function public.resolve_billing_assignment_remediation(
  uuid,
  text,
  bigint,
  text,
  text,
  timestamptz,
  uuid
) is
  'Service-only versioned support resolution; never performs an implicit customer or household transfer.';
