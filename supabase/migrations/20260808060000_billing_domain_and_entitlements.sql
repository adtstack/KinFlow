-- KinFlow WP06-01 provider-independent billing and household entitlement.
--
-- Provider clients never grant Plus directly. A verified normalized event is
-- applied by a service-only command, materialized into one household
-- entitlement, and projected to active household members without receipts or
-- provider identifiers. Runtime ingestion and numeric plan limits ship closed.

create type public.entitlement_status as enum (
  'none',
  'trialing',
  'active',
  'grace',
  'billing_issue',
  'expired',
  'revoked'
);

create table app_private.billing_runtime_config (
  singleton boolean primary key default true check (singleton),
  provider text not null default 'revenuecat' check (
    provider = 'revenuecat'
  ),
  accepted_environment text not null default 'disabled' check (
    accepted_environment in ('disabled', 'sandbox', 'production')
  ),
  ingestion_enabled boolean not null default false,
  updated_at timestamptz not null default pg_catalog.now(),
  version bigint not null default 1 check (version > 0),
  constraint billing_runtime_enabled_environment_ck check (
    not ingestion_enabled or accepted_environment <> 'disabled'
  )
);

insert into app_private.billing_runtime_config(singleton)
values (true);

create table public.billing_customers (
  id uuid primary key default extensions.gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete restrict,
  provider text not null check (provider in ('revenuecat', 'web')),
  environment text not null check (environment in ('sandbox', 'production')),
  provider_customer_ref text not null check (
    pg_catalog.char_length(provider_customer_ref) between 1 and 255
    and provider_customer_ref = pg_catalog.btrim(provider_customer_ref)
  ),
  provider_customer_ref_hash bytea not null check (
    pg_catalog.octet_length(provider_customer_ref_hash) = 32
  ),
  last_verified_at timestamptz,
  provider_updated_at timestamptz,
  last_receipt_id uuid,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  version bigint not null default 1 check (version > 0),
  unique (id, auth_user_id),
  unique (id, provider, environment),
  unique (provider, environment, auth_user_id),
  unique (provider, environment, provider_customer_ref_hash),
  constraint billing_customer_ref_hash_ck check (
    provider_customer_ref_hash = extensions.digest(
      pg_catalog.convert_to(provider_customer_ref, 'UTF8'),
      'sha256'
    )
  ),
  constraint revenuecat_customer_is_auth_user_ck check (
    provider <> 'revenuecat'
    or provider_customer_ref = auth_user_id::text
  )
);

create table public.billing_webhook_receipts (
  id uuid primary key default extensions.gen_random_uuid(),
  provider text not null check (provider in ('revenuecat', 'web')),
  environment text not null check (environment in ('sandbox', 'production')),
  provider_event_id text not null check (
    pg_catalog.char_length(provider_event_id) between 1 and 255
    and provider_event_id = pg_catalog.btrim(provider_event_id)
  ),
  event_type text not null check (
    event_type in (
      'initial_purchase',
      'renewal',
      'cancellation',
      'uncancellation',
      'grace',
      'billing_issue',
      'expiration',
      'refund',
      'revoke',
      'reconciliation'
    )
  ),
  request_hash bytea not null check (
    pg_catalog.octet_length(request_hash) = 32
  ),
  payload_version text check (
    payload_version is null
    or pg_catalog.char_length(payload_version) between 1 and 80
  ),
  payload_ciphertext bytea check (
    payload_ciphertext is null
    or pg_catalog.octet_length(payload_ciphertext) <= 1048576
  ),
  provider_occurred_at timestamptz not null,
  received_at timestamptz not null default pg_catalog.now(),
  last_received_at timestamptz not null default pg_catalog.now(),
  processed_at timestamptz,
  processing_status text not null default 'received' check (
    processing_status in ('received', 'applied', 'stale', 'quarantined')
  ),
  last_error_code text check (
    last_error_code is null
    or last_error_code in (
      'BILLING_DISABLED',
      'ENVIRONMENT_MISMATCH',
      'IDENTITY_MISMATCH',
      'UNKNOWN_USER',
      'UNKNOWN_HOUSEHOLD',
      'CUSTOMER_MAPPING_CONFLICT',
      'TRANSACTION_CUSTOMER_CONFLICT',
      'ASSIGNMENT_CUSTOMER_CONFLICT',
      'ASSIGNMENT_HOUSEHOLD_CONFLICT',
      'INITIAL_ASSIGNMENT_FORBIDDEN',
      'PLAN_UNAVAILABLE',
      'OLDER_THAN_CUSTOMER_STATE',
      'AMBIGUOUS_EVENT_ORDER'
    )
  ),
  replay_count integer not null default 0 check (replay_count >= 0),
  billing_customer_id uuid,
  billing_transaction_id uuid,
  assignment_id uuid,
  household_id uuid,
  correlation_id uuid not null,
  unique (provider, environment, provider_event_id),
  constraint billing_receipt_processing_state_ck check (
    (processing_status = 'received'
      and processed_at is null
      and last_error_code is null)
    or (processing_status = 'applied'
      and processed_at is not null
      and last_error_code is null)
    or (processing_status in ('stale', 'quarantined')
      and processed_at is not null
      and last_error_code is not null)
  ),
  constraint billing_receipt_receive_order_ck check (
    last_received_at >= received_at
    and (processed_at is null or processed_at >= received_at)
  )
);

create table public.billing_transactions (
  id uuid primary key default extensions.gen_random_uuid(),
  billing_customer_id uuid not null
    references public.billing_customers(id) on delete restrict,
  provider text not null check (provider in ('revenuecat', 'web')),
  environment text not null check (environment in ('sandbox', 'production')),
  source text not null check (
    source in ('app_store', 'play_store', 'web', 'manual_support')
  ),
  product_id text not null check (
    pg_catalog.char_length(product_id) between 1 and 255
    and product_id = pg_catalog.btrim(product_id)
  ),
  transaction_ref_hash bytea not null check (
    pg_catalog.octet_length(transaction_ref_hash) = 32
  ),
  original_transaction_ref_hash bytea check (
    original_transaction_ref_hash is null
    or pg_catalog.octet_length(original_transaction_ref_hash) = 32
  ),
  status public.entitlement_status not null check (status <> 'none'),
  purchased_at timestamptz,
  current_period_start timestamptz,
  current_period_end timestamptz,
  will_renew boolean not null,
  provider_updated_at timestamptz not null,
  verified_at timestamptz not null default pg_catalog.now(),
  last_receipt_id uuid not null
    references public.billing_webhook_receipts(id) on delete restrict,
  raw_snapshot_ciphertext bytea check (
    raw_snapshot_ciphertext is null
    or pg_catalog.octet_length(raw_snapshot_ciphertext) <= 1048576
  ),
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  version bigint not null default 1 check (version > 0),
  unique (id, provider, environment),
  unique (provider, environment, transaction_ref_hash),
  constraint billing_transaction_customer_provider_fk
    foreign key (billing_customer_id, provider, environment)
    references public.billing_customers(id, provider, environment)
    on delete restrict,
  constraint billing_transaction_period_ck check (
    (current_period_start is null and current_period_end is null)
    or (
      current_period_start is not null
      and current_period_end is not null
      and current_period_end > current_period_start
    )
  ),
  constraint billing_transaction_terminal_renewal_ck check (
    status not in ('expired', 'revoked') or not will_renew
  )
);

create table public.billing_household_assignments (
  id uuid primary key default extensions.gen_random_uuid(),
  billing_customer_id uuid not null,
  billing_owner_user_id uuid not null,
  household_id uuid not null
    references public.households(id) on delete restrict,
  status text not null check (status in ('active', 'ended', 'revoked')),
  assigned_at timestamptz not null default pg_catalog.now(),
  ended_at timestamptz,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  version bigint not null default 1 check (version > 0),
  unique (id, household_id),
  unique (id, household_id, billing_owner_user_id),
  constraint billing_assignment_customer_owner_fk
    foreign key (billing_customer_id, billing_owner_user_id)
    references public.billing_customers(id, auth_user_id)
    on delete restrict,
  constraint billing_assignment_status_time_ck check (
    (status = 'active' and ended_at is null)
    or (status in ('ended', 'revoked') and ended_at is not null)
  ),
  constraint billing_assignment_time_order_ck check (
    ended_at is null or ended_at >= assigned_at
  )
);

create unique index billing_assignment_customer_active_uq
  on public.billing_household_assignments(billing_customer_id)
  where status = 'active';

create unique index billing_assignment_household_active_uq
  on public.billing_household_assignments(household_id)
  where status = 'active';

create table public.plan_catalog (
  plan_code text primary key check (plan_code in ('free', 'plus')),
  feature_limits jsonb not null default '{}'::jsonb,
  limits_finalized boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  version bigint not null default 1 check (version > 0)
);

create table public.household_entitlements (
  household_id uuid primary key
    references public.households(id) on delete cascade,
  assignment_id uuid,
  billing_owner_user_id uuid references auth.users(id) on delete restrict,
  plan_code text not null references public.plan_catalog(plan_code),
  status public.entitlement_status not null default 'none',
  source text not null check (
    source in ('app_store', 'play_store', 'web', 'manual_support', 'none')
  ),
  product_id text check (
    product_id is null
    or pg_catalog.char_length(product_id) between 1 and 255
      and product_id = pg_catalog.btrim(product_id)
  ),
  current_period_start timestamptz,
  current_period_end timestamptz,
  will_renew boolean not null default false,
  features jsonb not null default '{}'::jsonb check (
    pg_catalog.jsonb_typeof(features) = 'object'
    and pg_catalog.octet_length(
      pg_catalog.convert_to(features::text, 'UTF8')
    ) <= 4096
  ),
  provider_updated_at timestamptz,
  verified_at timestamptz not null default pg_catalog.now(),
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  version bigint not null default 1 check (version > 0),
  constraint household_entitlement_assignment_household_fk
    foreign key (assignment_id, household_id, billing_owner_user_id)
    references public.billing_household_assignments(
      id,
      household_id,
      billing_owner_user_id
    )
    on delete restrict,
  constraint household_entitlement_period_ck check (
    (current_period_start is null and current_period_end is null)
    or (
      current_period_start is not null
      and current_period_end is not null
      and current_period_end > current_period_start
    )
  ),
  constraint household_entitlement_lifecycle_plan_ck check (
    (status in ('trialing', 'active', 'grace') and plan_code = 'plus')
    or (status in ('none', 'expired', 'revoked') and plan_code = 'free')
    or status = 'billing_issue'
  ),
  constraint household_entitlement_identity_ck check (
    (
      status = 'none'
      and assignment_id is null
      and billing_owner_user_id is null
      and source = 'none'
      and product_id is null
      and current_period_start is null
      and current_period_end is null
      and not will_renew
      and provider_updated_at is null
    )
    or (
      status <> 'none'
      and assignment_id is not null
      and billing_owner_user_id is not null
      and source <> 'none'
      and product_id is not null
      and provider_updated_at is not null
    )
  ),
  constraint household_entitlement_terminal_renewal_ck check (
    status not in ('expired', 'revoked') or not will_renew
  )
);

alter table public.billing_customers
  add constraint billing_customer_last_receipt_fk
  foreign key (last_receipt_id)
  references public.billing_webhook_receipts(id)
  on delete restrict;

alter table public.billing_webhook_receipts
  add constraint billing_receipt_customer_fk
    foreign key (billing_customer_id, provider, environment)
    references public.billing_customers(id, provider, environment)
    on delete restrict,
  add constraint billing_receipt_transaction_fk
    foreign key (billing_transaction_id, provider, environment)
    references public.billing_transactions(id, provider, environment)
    on delete restrict,
  add constraint billing_receipt_assignment_fk
    foreign key (assignment_id, household_id)
    references public.billing_household_assignments(id, household_id)
    on delete restrict,
  add constraint billing_receipt_household_fk
    foreign key (household_id)
    references public.households(id) on delete restrict,
  add constraint billing_receipt_linkage_ck check (
    processing_status <> 'applied'
    or billing_customer_id is not null
      and billing_transaction_id is not null
      and assignment_id is not null
      and household_id is not null
  );

create table app_private.billing_entitlement_transitions (
  id bigint generated always as identity primary key,
  receipt_id uuid not null unique,
  household_id uuid not null,
  assignment_id uuid not null,
  billing_transaction_id uuid not null,
  event_type text not null,
  previous_plan_code text not null check (
    previous_plan_code in ('free', 'plus')
  ),
  next_plan_code text not null check (next_plan_code in ('free', 'plus')),
  previous_status public.entitlement_status not null,
  next_status public.entitlement_status not null,
  provider_occurred_at timestamptz not null,
  correlation_id uuid not null,
  applied_at timestamptz not null default pg_catalog.now()
);

create index billing_entitlement_transitions_household_idx
  on app_private.billing_entitlement_transitions(
    household_id,
    applied_at,
    id
  );

create table app_private.billing_policy_events (
  id bigint generated always as identity primary key,
  policy_kind text not null check (policy_kind in ('runtime', 'plan')),
  policy_key text not null check (
    pg_catalog.char_length(policy_key) between 1 and 80
  ),
  previous_version bigint not null check (previous_version > 0),
  next_version bigint not null check (next_version = previous_version + 1),
  correlation_id uuid not null,
  changed_at timestamptz not null default pg_catalog.now()
);

revoke all on table app_private.billing_runtime_config
  from public, anon, authenticated, service_role;
revoke all on table app_private.billing_entitlement_transitions
  from public, anon, authenticated, service_role;
revoke all on table app_private.billing_policy_events
  from public, anon, authenticated, service_role;
revoke all on sequence app_private.billing_entitlement_transitions_id_seq
  from public, anon, authenticated, service_role;
revoke all on sequence app_private.billing_policy_events_id_seq
  from public, anon, authenticated, service_role;

create or replace function app_private.reject_billing_audit_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = '42501',
    message = 'billing audit records are immutable';
end;
$$;

revoke all on function app_private.reject_billing_audit_mutation()
  from public, anon, authenticated, service_role;

create trigger billing_entitlement_transitions_immutable
before update or delete on app_private.billing_entitlement_transitions
for each row execute function app_private.reject_billing_audit_mutation();

create trigger billing_policy_events_immutable
before update or delete on app_private.billing_policy_events
for each row execute function app_private.reject_billing_audit_mutation();

create or replace function app_private.guard_billing_webhook_receipt()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.id is distinct from old.id
    or new.provider is distinct from old.provider
    or new.environment is distinct from old.environment
    or new.provider_event_id is distinct from old.provider_event_id
    or new.event_type is distinct from old.event_type
    or new.request_hash is distinct from old.request_hash
    or new.payload_version is distinct from old.payload_version
    or new.payload_ciphertext is distinct from old.payload_ciphertext
    or new.provider_occurred_at is distinct from old.provider_occurred_at
    or new.received_at is distinct from old.received_at
    or new.correlation_id is distinct from old.correlation_id then
    raise exception using
      errcode = '42501',
      message = 'billing receipt envelope is immutable';
  end if;

  if old.processing_status <> 'received'
    and new.processing_status is distinct from old.processing_status then
    raise exception using
      errcode = '42501',
      message = 'billing receipt terminal state is immutable';
  end if;

  if new.replay_count < old.replay_count
    or new.last_received_at < old.last_received_at then
    raise exception using
      errcode = '42501',
      message = 'billing receipt replay metadata cannot regress';
  end if;

  return new;
end;
$$;

revoke all on function app_private.guard_billing_webhook_receipt()
  from public, anon, authenticated, service_role;

create trigger billing_webhook_receipts_guard
before update on public.billing_webhook_receipts
for each row execute function app_private.guard_billing_webhook_receipt();

create trigger billing_customers_set_updated_at_and_version
before update on public.billing_customers
for each row execute function app_private.set_updated_at_and_version();

create trigger billing_transactions_set_updated_at_and_version
before update on public.billing_transactions
for each row execute function app_private.set_updated_at_and_version();

create trigger billing_assignments_set_updated_at_and_version
before update on public.billing_household_assignments
for each row execute function app_private.set_updated_at_and_version();

create trigger plan_catalog_set_updated_at_and_version
before update on public.plan_catalog
for each row execute function app_private.set_updated_at_and_version();

create trigger household_entitlements_set_updated_at_and_version
before update on public.household_entitlements
for each row execute function app_private.set_updated_at_and_version();

create trigger billing_runtime_config_set_updated_at_and_version
before update on app_private.billing_runtime_config
for each row execute function app_private.set_updated_at_and_version();

create or replace function app_private.is_valid_feature_limits(
  p_feature_limits jsonb,
  p_limits_finalized boolean
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select
    p_feature_limits is not null
    and pg_catalog.jsonb_typeof(p_feature_limits) = 'object'
    and pg_catalog.octet_length(
      pg_catalog.convert_to(p_feature_limits::text, 'UTF8')
    ) <= 4096
    and (not p_limits_finalized or p_feature_limits <> '{}'::jsonb)
    and not exists (
      select 1
      from pg_catalog.jsonb_each(p_feature_limits) as entry(key, value)
      where entry.key !~ '^[a-z][A-Za-z0-9]{0,63}$'
        or pg_catalog.jsonb_typeof(entry.value) <> 'number'
        or entry.value::text !~ '^[0-9]+$'
        or (entry.value::text)::numeric > 1000000
    )
$$;

revoke all on function app_private.is_valid_feature_limits(jsonb, boolean)
  from public, anon, authenticated, service_role;

alter table public.plan_catalog
  add constraint plan_catalog_feature_limits_ck check (
    app_private.is_valid_feature_limits(feature_limits, limits_finalized)
  );

insert into public.plan_catalog(
  plan_code,
  feature_limits,
  limits_finalized
) values
  ('free', '{}'::jsonb, false),
  ('plus', '{}'::jsonb, false);

insert into public.household_entitlements(
  household_id,
  plan_code,
  status,
  source,
  features
)
select
  household.id,
  'free',
  'none',
  'none',
  '{}'::jsonb
from public.households as household
on conflict (household_id) do nothing;

create or replace function app_private.create_default_household_entitlement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.household_entitlements(
    household_id,
    plan_code,
    status,
    source,
    features
  ) values (
    new.id,
    'free',
    'none',
    'none',
    '{}'::jsonb
  );
  return new;
end;
$$;

revoke all on function app_private.create_default_household_entitlement()
  from public, anon, authenticated, service_role;

create trigger households_create_default_entitlement
after insert on public.households
for each row execute function app_private.create_default_household_entitlement();

create or replace function app_private.billing_event_request_hash(
  p_provider text,
  p_environment text,
  p_provider_event_id text,
  p_event_type text,
  p_provider_occurred_at timestamptz,
  p_auth_user_id uuid,
  p_provider_customer_ref text,
  p_transaction_ref text,
  p_original_transaction_ref text,
  p_product_id text,
  p_source text,
  p_household_id uuid,
  p_status public.entitlement_status,
  p_effective_plan_code text,
  p_current_period_start timestamptz,
  p_current_period_end timestamptz,
  p_will_renew boolean,
  p_payload_version text
)
returns bytea
language sql
immutable
set search_path = ''
as $$
  select extensions.digest(
    pg_catalog.convert_to(
      pg_catalog.jsonb_build_object(
        'provider', p_provider,
        'environment', p_environment,
        'providerEventId', p_provider_event_id,
        'eventType', p_event_type,
        'providerOccurredAt', p_provider_occurred_at,
        'authUserId', p_auth_user_id,
        'providerCustomerRef', p_provider_customer_ref,
        'transactionRef', p_transaction_ref,
        'originalTransactionRef', p_original_transaction_ref,
        'productId', p_product_id,
        'source', p_source,
        'householdId', p_household_id,
        'status', p_status,
        'effectivePlanCode', p_effective_plan_code,
        'currentPeriodStart', p_current_period_start,
        'currentPeriodEnd', p_current_period_end,
        'willRenew', p_will_renew,
        'payloadVersion', p_payload_version
      )::text,
      'UTF8'
    ),
    'sha256'
  )
$$;

revoke all on function app_private.billing_event_request_hash(
  text,
  text,
  text,
  text,
  timestamptz,
  uuid,
  text,
  text,
  text,
  text,
  text,
  uuid,
  public.entitlement_status,
  text,
  timestamptz,
  timestamptz,
  boolean,
  text
) from public, anon, authenticated, service_role;

create or replace function public.configure_billing_runtime(
  p_accepted_environment text,
  p_ingestion_enabled boolean,
  p_expected_version bigint,
  p_correlation_id uuid
)
returns table (
  accepted_environment text,
  ingestion_enabled boolean,
  version bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_previous_version bigint;
  v_next app_private.billing_runtime_config%rowtype;
begin
  if p_accepted_environment not in ('disabled', 'sandbox', 'production')
    or p_ingestion_enabled and p_accepted_environment = 'disabled'
    or p_expected_version is null
    or p_correlation_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid billing runtime configuration';
  end if;

  select config.version
  into v_previous_version
  from app_private.billing_runtime_config as config
  where config.singleton
  for update;

  if v_previous_version <> p_expected_version then
    raise exception using
      errcode = 'KFB30',
      message = 'billing runtime version conflict';
  end if;

  update app_private.billing_runtime_config as config
  set accepted_environment = p_accepted_environment,
      ingestion_enabled = p_ingestion_enabled
  where config.singleton
  returning config.* into v_next;

  insert into app_private.billing_policy_events(
    policy_kind,
    policy_key,
    previous_version,
    next_version,
    correlation_id
  ) values (
    'runtime',
    'revenuecat',
    v_previous_version,
    v_next.version,
    p_correlation_id
  );

  return query select
    v_next.accepted_environment,
    v_next.ingestion_enabled,
    v_next.version;
end;
$$;

create or replace function public.configure_plan_feature_limits(
  p_plan_code text,
  p_feature_limits jsonb,
  p_limits_finalized boolean,
  p_expected_version bigint,
  p_correlation_id uuid
)
returns table (
  plan_code text,
  feature_limits jsonb,
  limits_finalized boolean,
  version bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_previous_version bigint;
  v_other public.plan_catalog%rowtype;
  v_next public.plan_catalog%rowtype;
begin
  if p_plan_code not in ('free', 'plus')
    or not app_private.is_valid_feature_limits(
      p_feature_limits,
      p_limits_finalized
    )
    or p_expected_version is null
    or p_correlation_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid billing plan policy';
  end if;

  select catalog.version
  into v_previous_version
  from public.plan_catalog as catalog
  where catalog.plan_code = p_plan_code
  for update;

  if v_previous_version <> p_expected_version then
    raise exception using
      errcode = 'KFB31',
      message = 'billing plan version conflict';
  end if;

  select catalog.*
  into v_other
  from public.plan_catalog as catalog
  where catalog.plan_code = case p_plan_code
    when 'free' then 'plus'
    else 'free'
  end
  for update;

  if p_limits_finalized and v_other.limits_finalized then
    if p_plan_code = 'plus' and exists (
      select 1
      from pg_catalog.jsonb_each_text(v_other.feature_limits) as free_limit
      where not p_feature_limits ? free_limit.key
        or (p_feature_limits ->> free_limit.key)::bigint
          < free_limit.value::bigint
    ) then
      raise exception using
        errcode = 'KFB32',
        message = 'Plus limits cannot be lower than Free limits';
    end if;

    if p_plan_code = 'free' and exists (
      select 1
      from pg_catalog.jsonb_each_text(p_feature_limits) as free_limit
      where not v_other.feature_limits ? free_limit.key
        or (v_other.feature_limits ->> free_limit.key)::bigint
          < free_limit.value::bigint
    ) then
      raise exception using
        errcode = 'KFB32',
        message = 'Plus limits cannot be lower than Free limits';
    end if;
  end if;

  update public.plan_catalog as catalog
  set feature_limits = p_feature_limits,
      limits_finalized = p_limits_finalized
  where catalog.plan_code = p_plan_code
  returning catalog.* into v_next;

  update public.household_entitlements as entitlement
  set features = case
        when p_limits_finalized then p_feature_limits
        else '{}'::jsonb
      end
  where entitlement.plan_code = p_plan_code;

  insert into app_private.billing_policy_events(
    policy_kind,
    policy_key,
    previous_version,
    next_version,
    correlation_id
  ) values (
    'plan',
    p_plan_code,
    v_previous_version,
    v_next.version,
    p_correlation_id
  );

  return query select
    v_next.plan_code,
    v_next.feature_limits,
    v_next.limits_finalized,
    v_next.version;
end;
$$;

create or replace function app_private.current_household_feature_usage(
  p_household_id uuid,
  p_feature_key text
)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_usage bigint;
begin
  if p_feature_key = 'members' then
    select pg_catalog.count(*)
    into v_usage
    from public.household_members as member
    where member.household_id = p_household_id
      and member.removed_at is null;
  elsif p_feature_key = 'activeSeries' then
    select
      (
        select pg_catalog.count(*)
        from public.chore_series as series
        where series.household_id = p_household_id
          and series.deleted_at is null
      ) + (
        select pg_catalog.count(*)
        from public.event_series as series
        where series.household_id = p_household_id
          and series.deleted_at is null
      )
    into v_usage;
  else
    raise exception using
      errcode = 'KFB11',
      message = 'unknown household feature key';
  end if;

  return v_usage;
end;
$$;

create or replace function app_private.assert_household_feature_capacity(
  p_household_id uuid,
  p_feature_key text,
  p_requested_delta integer default 1
)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limits jsonb;
  v_finalized boolean;
  v_limit bigint;
  v_usage bigint;
begin
  if p_household_id is null
    or p_feature_key is null
    or p_requested_delta is null
    or p_requested_delta < 1
    or p_requested_delta > 1000 then
    raise exception using
      errcode = '22023',
      message = 'invalid household feature-capacity request';
  end if;

  select catalog.feature_limits, catalog.limits_finalized
  into v_limits, v_finalized
  from public.household_entitlements as entitlement
  join public.plan_catalog as catalog
    on catalog.plan_code = entitlement.plan_code
  where entitlement.household_id = p_household_id
    and catalog.active;

  if not found or not v_finalized then
    raise exception using
      errcode = 'KFB10',
      message = 'household feature limits are not finalized';
  end if;

  if not v_limits ? p_feature_key then
    raise exception using
      errcode = 'KFB11',
      message = 'household feature limit is not configured';
  end if;

  v_limit := (v_limits ->> p_feature_key)::bigint;
  v_usage := app_private.current_household_feature_usage(
    p_household_id,
    p_feature_key
  );

  if v_usage + p_requested_delta > v_limit then
    raise exception using
      errcode = 'KFB12',
      message = 'household feature limit reached';
  end if;

  return v_limit - v_usage - p_requested_delta;
end;
$$;

revoke all on function app_private.current_household_feature_usage(uuid, text)
  from public, anon, authenticated, service_role;
revoke all on function app_private.assert_household_feature_capacity(
  uuid,
  text,
  integer
) from public, anon, authenticated, service_role;

create or replace function public.apply_verified_billing_event(
  p_provider text,
  p_environment text,
  p_provider_event_id text,
  p_event_type text,
  p_provider_occurred_at timestamptz,
  p_auth_user_id uuid,
  p_provider_customer_ref text,
  p_transaction_ref text,
  p_original_transaction_ref text,
  p_product_id text,
  p_source text,
  p_household_id uuid,
  p_status public.entitlement_status,
  p_effective_plan_code text,
  p_current_period_start timestamptz,
  p_current_period_end timestamptz,
  p_will_renew boolean,
  p_payload_version text,
  p_payload_ciphertext bytea,
  p_correlation_id uuid
)
returns table (
  receipt_id uuid,
  processing_status text,
  duplicate boolean,
  billing_customer_id uuid,
  billing_transaction_id uuid,
  assignment_id uuid,
  household_id uuid,
  plan_code text,
  entitlement_status public.entitlement_status,
  entitlement_version bigint,
  provider_updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := pg_catalog.statement_timestamp();
  v_request_hash bytea;
  v_customer_hash bytea;
  v_transaction_hash bytea;
  v_original_transaction_hash bytea;
  v_receipt public.billing_webhook_receipts%rowtype;
  v_customer public.billing_customers%rowtype;
  v_conflicting_customer public.billing_customers%rowtype;
  v_transaction public.billing_transactions%rowtype;
  v_assignment public.billing_household_assignments%rowtype;
  v_conflicting_assignment public.billing_household_assignments%rowtype;
  v_entitlement public.household_entitlements%rowtype;
  v_previous_entitlement public.household_entitlements%rowtype;
  v_catalog public.plan_catalog%rowtype;
  v_runtime app_private.billing_runtime_config%rowtype;
  v_error_code text;
begin
  if p_provider not in ('revenuecat', 'web')
    or p_environment not in ('sandbox', 'production')
    or p_provider_event_id is null
    or p_provider_event_id <> pg_catalog.btrim(p_provider_event_id)
    or pg_catalog.char_length(p_provider_event_id) not between 1 and 255
    or p_event_type not in (
      'initial_purchase',
      'renewal',
      'cancellation',
      'uncancellation',
      'grace',
      'billing_issue',
      'expiration',
      'refund',
      'revoke',
      'reconciliation'
    )
    or p_provider_occurred_at is null
    or p_provider_occurred_at > v_now + interval '1 day'
    or p_auth_user_id is null
    or p_provider_customer_ref is null
    or p_transaction_ref is null
    or p_transaction_ref <> pg_catalog.btrim(p_transaction_ref)
    or pg_catalog.char_length(p_transaction_ref) not between 1 and 512
    or p_original_transaction_ref is not null and (
      p_original_transaction_ref <> pg_catalog.btrim(
        p_original_transaction_ref
      )
      or pg_catalog.char_length(p_original_transaction_ref) not between 1 and 512
    )
    or p_product_id is null
    or p_product_id <> pg_catalog.btrim(p_product_id)
    or pg_catalog.char_length(p_product_id) not between 1 and 255
    or p_source not in ('app_store', 'play_store', 'web', 'manual_support')
    or p_household_id is null
    or p_status is null
    or p_status = 'none'
    or p_effective_plan_code not in ('free', 'plus')
    or p_will_renew is null
    or p_correlation_id is null
    or p_payload_version is not null and (
      pg_catalog.char_length(p_payload_version) not between 1 and 80
    )
    or p_payload_ciphertext is not null
      and pg_catalog.octet_length(p_payload_ciphertext) > 1048576
    or (p_current_period_start is null) <> (p_current_period_end is null)
    or p_current_period_start is not null
      and p_current_period_end <= p_current_period_start
    or p_status in ('trialing', 'active', 'grace')
      and p_effective_plan_code <> 'plus'
    or p_status in ('expired', 'revoked')
      and p_effective_plan_code <> 'free'
    or p_status in ('expired', 'revoked') and p_will_renew then
    raise exception using
      errcode = '22023',
      message = 'invalid verified billing event';
  end if;

  v_request_hash := app_private.billing_event_request_hash(
    p_provider,
    p_environment,
    p_provider_event_id,
    p_event_type,
    p_provider_occurred_at,
    p_auth_user_id,
    p_provider_customer_ref,
    p_transaction_ref,
    p_original_transaction_ref,
    p_product_id,
    p_source,
    p_household_id,
    p_status,
    p_effective_plan_code,
    p_current_period_start,
    p_current_period_end,
    p_will_renew,
    p_payload_version
  );
  v_customer_hash := extensions.digest(
    pg_catalog.convert_to(p_provider_customer_ref, 'UTF8'),
    'sha256'
  );
  v_transaction_hash := extensions.digest(
    pg_catalog.convert_to(p_transaction_ref, 'UTF8'),
    'sha256'
  );
  if p_original_transaction_ref is not null then
    v_original_transaction_hash := extensions.digest(
      pg_catalog.convert_to(p_original_transaction_ref, 'UTF8'),
      'sha256'
    );
  end if;

  select receipt.*
  into v_receipt
  from public.billing_webhook_receipts as receipt
  where receipt.provider = p_provider
    and receipt.environment = p_environment
    and receipt.provider_event_id = p_provider_event_id
  for update;

  if found then
    if v_receipt.request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFB20',
        message = 'billing event ID was reused with different normalized data';
    end if;

    update public.billing_webhook_receipts as receipt
    set replay_count = receipt.replay_count + 1,
        last_received_at = v_now
    where receipt.id = v_receipt.id
    returning receipt.* into v_receipt;

    select entitlement.*
    into v_entitlement
    from public.household_entitlements as entitlement
    where entitlement.household_id = v_receipt.household_id;

    return query select
      v_receipt.id,
      v_receipt.processing_status,
      true,
      v_receipt.billing_customer_id,
      v_receipt.billing_transaction_id,
      v_receipt.assignment_id,
      v_receipt.household_id,
      v_entitlement.plan_code,
      v_entitlement.status,
      v_entitlement.version,
      v_entitlement.provider_updated_at;
    return;
  end if;

  insert into public.billing_webhook_receipts(
    provider,
    environment,
    provider_event_id,
    event_type,
    request_hash,
    payload_version,
    payload_ciphertext,
    provider_occurred_at,
    received_at,
    last_received_at,
    correlation_id
  ) values (
    p_provider,
    p_environment,
    p_provider_event_id,
    p_event_type,
    v_request_hash,
    p_payload_version,
    p_payload_ciphertext,
    p_provider_occurred_at,
    v_now,
    v_now,
    p_correlation_id
  ) returning * into v_receipt;

  select config.*
  into v_runtime
  from app_private.billing_runtime_config as config
  where config.singleton
  for share;

  if not v_runtime.ingestion_enabled then
    v_error_code := 'BILLING_DISABLED';
  elsif v_runtime.provider <> p_provider
    or v_runtime.accepted_environment <> p_environment then
    v_error_code := 'ENVIRONMENT_MISMATCH';
  elsif p_provider = 'revenuecat'
    and p_provider_customer_ref <> p_auth_user_id::text then
    v_error_code := 'IDENTITY_MISMATCH';
  elsif not exists (
    select 1
    from auth.users as auth_user
    where auth_user.id = p_auth_user_id
  ) then
    v_error_code := 'UNKNOWN_USER';
  elsif not exists (
    select 1
    from public.households as household
    where household.id = p_household_id
  ) then
    v_error_code := 'UNKNOWN_HOUSEHOLD';
  end if;

  if v_error_code is not null then
    update public.billing_webhook_receipts as receipt
    set processing_status = 'quarantined',
        processed_at = v_now,
        last_error_code = v_error_code,
        household_id = case
          when exists (
            select 1
            from public.households as household
            where household.id = p_household_id
          ) then p_household_id
          else null
        end
    where receipt.id = v_receipt.id
    returning receipt.* into v_receipt;

    return query select
      v_receipt.id,
      v_receipt.processing_status,
      false,
      null::uuid,
      null::uuid,
      null::uuid,
      v_receipt.household_id,
      null::text,
      null::public.entitlement_status,
      null::bigint,
      null::timestamptz;
    return;
  end if;

  select customer.*
  into v_customer
  from public.billing_customers as customer
  where customer.provider = p_provider
    and customer.environment = p_environment
    and customer.auth_user_id = p_auth_user_id
  for update;

  if found then
    if v_customer.provider_customer_ref_hash <> v_customer_hash then
      v_error_code := 'CUSTOMER_MAPPING_CONFLICT';
    end if;
  else
    select customer.*
    into v_conflicting_customer
    from public.billing_customers as customer
    where customer.provider = p_provider
      and customer.environment = p_environment
      and customer.provider_customer_ref_hash = v_customer_hash
    for update;

    if found and v_conflicting_customer.auth_user_id <> p_auth_user_id then
      v_error_code := 'CUSTOMER_MAPPING_CONFLICT';
    else
      insert into public.billing_customers(
        auth_user_id,
        provider,
        environment,
        provider_customer_ref,
        provider_customer_ref_hash
      ) values (
        p_auth_user_id,
        p_provider,
        p_environment,
        p_provider_customer_ref,
        v_customer_hash
      ) returning * into v_customer;
    end if;
  end if;

  if v_error_code is null and v_customer.provider_updated_at is not null then
    if p_provider_occurred_at < v_customer.provider_updated_at then
      v_error_code := 'OLDER_THAN_CUSTOMER_STATE';
    elsif p_provider_occurred_at = v_customer.provider_updated_at then
      v_error_code := 'AMBIGUOUS_EVENT_ORDER';
    end if;
  end if;

  if v_error_code = 'OLDER_THAN_CUSTOMER_STATE' then
    update public.billing_webhook_receipts as receipt
    set processing_status = 'stale',
        processed_at = v_now,
        last_error_code = v_error_code,
        billing_customer_id = v_customer.id,
        household_id = p_household_id
    where receipt.id = v_receipt.id
    returning receipt.* into v_receipt;

    select entitlement.*
    into v_entitlement
    from public.household_entitlements as entitlement
    where entitlement.household_id = p_household_id;

    return query select
      v_receipt.id,
      v_receipt.processing_status,
      false,
      v_customer.id,
      null::uuid,
      null::uuid,
      p_household_id,
      v_entitlement.plan_code,
      v_entitlement.status,
      v_entitlement.version,
      v_entitlement.provider_updated_at;
    return;
  end if;

  if v_error_code is null then
    select transaction.*
    into v_transaction
    from public.billing_transactions as transaction
    where transaction.provider = p_provider
      and transaction.environment = p_environment
      and transaction.transaction_ref_hash = v_transaction_hash
    for update;

    if found and v_transaction.billing_customer_id <> v_customer.id then
      v_error_code := 'TRANSACTION_CUSTOMER_CONFLICT';
    end if;
  end if;

  if v_error_code is null then
    select assignment.*
    into v_assignment
    from public.billing_household_assignments as assignment
    where assignment.billing_customer_id = v_customer.id
      and assignment.status = 'active'
    for update;

    if found and v_assignment.household_id <> p_household_id then
      v_error_code := 'ASSIGNMENT_CUSTOMER_CONFLICT';
    end if;
  end if;

  if v_error_code is null then
    select assignment.*
    into v_conflicting_assignment
    from public.billing_household_assignments as assignment
    where assignment.household_id = p_household_id
      and assignment.status = 'active'
    for update;

    if found and v_conflicting_assignment.billing_customer_id <> v_customer.id then
      v_error_code := 'ASSIGNMENT_HOUSEHOLD_CONFLICT';
    elsif v_assignment.id is null and found then
      v_assignment := v_conflicting_assignment;
    end if;
  end if;

  if v_error_code is null and v_assignment.id is null then
    if not exists (
      select 1
      from public.household_members as member
      where member.household_id = p_household_id
        and member.auth_user_id = p_auth_user_id
        and member.removed_at is null
        and member.role in ('owner', 'admin')
    ) then
      v_error_code := 'INITIAL_ASSIGNMENT_FORBIDDEN';
    end if;
  end if;

  if v_error_code is null then
    select catalog.*
    into v_catalog
    from public.plan_catalog as catalog
    where catalog.plan_code = p_effective_plan_code
      and catalog.active
    for share;

    if not found then
      v_error_code := 'PLAN_UNAVAILABLE';
    end if;
  end if;

  if v_error_code is not null then
    update public.billing_webhook_receipts as receipt
    set processing_status = 'quarantined',
        processed_at = v_now,
        last_error_code = v_error_code,
        billing_customer_id = v_customer.id,
        household_id = p_household_id
    where receipt.id = v_receipt.id
    returning receipt.* into v_receipt;

    select entitlement.*
    into v_entitlement
    from public.household_entitlements as entitlement
    where entitlement.household_id = p_household_id;

    return query select
      v_receipt.id,
      v_receipt.processing_status,
      false,
      v_receipt.billing_customer_id,
      null::uuid,
      null::uuid,
      p_household_id,
      v_entitlement.plan_code,
      v_entitlement.status,
      v_entitlement.version,
      v_entitlement.provider_updated_at;
    return;
  end if;

  if v_transaction.id is null then
    insert into public.billing_transactions(
      billing_customer_id,
      provider,
      environment,
      source,
      product_id,
      transaction_ref_hash,
      original_transaction_ref_hash,
      status,
      purchased_at,
      current_period_start,
      current_period_end,
      will_renew,
      provider_updated_at,
      verified_at,
      last_receipt_id
    ) values (
      v_customer.id,
      p_provider,
      p_environment,
      p_source,
      p_product_id,
      v_transaction_hash,
      v_original_transaction_hash,
      p_status,
      case p_event_type
        when 'initial_purchase' then p_provider_occurred_at
        else null
      end,
      p_current_period_start,
      p_current_period_end,
      p_will_renew,
      p_provider_occurred_at,
      v_now,
      v_receipt.id
    ) returning * into v_transaction;
  else
    update public.billing_transactions as transaction
    set source = p_source,
        product_id = p_product_id,
        original_transaction_ref_hash = coalesce(
          v_original_transaction_hash,
          transaction.original_transaction_ref_hash
        ),
        status = p_status,
        purchased_at = coalesce(
          transaction.purchased_at,
          case p_event_type
            when 'initial_purchase' then p_provider_occurred_at
            else null
          end
        ),
        current_period_start = p_current_period_start,
        current_period_end = p_current_period_end,
        will_renew = p_will_renew,
        provider_updated_at = p_provider_occurred_at,
        verified_at = v_now,
        last_receipt_id = v_receipt.id
    where transaction.id = v_transaction.id
    returning transaction.* into v_transaction;
  end if;

  if v_assignment.id is null then
    insert into public.billing_household_assignments(
      billing_customer_id,
      billing_owner_user_id,
      household_id,
      status,
      assigned_at
    ) values (
      v_customer.id,
      p_auth_user_id,
      p_household_id,
      'active',
      v_now
    ) returning * into v_assignment;
  end if;

  select entitlement.*
  into v_previous_entitlement
  from public.household_entitlements as entitlement
  where entitlement.household_id = p_household_id
  for update;

  update public.household_entitlements as entitlement
  set assignment_id = v_assignment.id,
      billing_owner_user_id = p_auth_user_id,
      plan_code = p_effective_plan_code,
      status = p_status,
      source = p_source,
      product_id = p_product_id,
      current_period_start = p_current_period_start,
      current_period_end = p_current_period_end,
      will_renew = p_will_renew,
      features = case
        when v_catalog.limits_finalized then v_catalog.feature_limits
        else '{}'::jsonb
      end,
      provider_updated_at = p_provider_occurred_at,
      verified_at = v_now
  where entitlement.household_id = p_household_id
  returning entitlement.* into v_entitlement;

  update public.billing_customers as customer
  set last_verified_at = v_now,
      provider_updated_at = p_provider_occurred_at,
      last_receipt_id = v_receipt.id
  where customer.id = v_customer.id
  returning customer.* into v_customer;

  update public.billing_webhook_receipts as receipt
  set processing_status = 'applied',
      processed_at = v_now,
      billing_customer_id = v_customer.id,
      billing_transaction_id = v_transaction.id,
      assignment_id = v_assignment.id,
      household_id = p_household_id
  where receipt.id = v_receipt.id
  returning receipt.* into v_receipt;

  insert into app_private.billing_entitlement_transitions(
    receipt_id,
    household_id,
    assignment_id,
    billing_transaction_id,
    event_type,
    previous_plan_code,
    next_plan_code,
    previous_status,
    next_status,
    provider_occurred_at,
    correlation_id,
    applied_at
  ) values (
    v_receipt.id,
    p_household_id,
    v_assignment.id,
    v_transaction.id,
    p_event_type,
    v_previous_entitlement.plan_code,
    v_entitlement.plan_code,
    v_previous_entitlement.status,
    v_entitlement.status,
    p_provider_occurred_at,
    p_correlation_id,
    v_now
  );

  return query select
    v_receipt.id,
    v_receipt.processing_status,
    false,
    v_customer.id,
    v_transaction.id,
    v_assignment.id,
    p_household_id,
    v_entitlement.plan_code,
    v_entitlement.status,
    v_entitlement.version,
    v_entitlement.provider_updated_at;
end;
$$;

create or replace function public.get_household_entitlement(
  p_household_id uuid
)
returns table (
  household_id uuid,
  entitlement_key text,
  plan_code text,
  status public.entitlement_status,
  source text,
  current_period_end timestamptz,
  will_renew boolean,
  feature_limits jsonb,
  limits_finalized boolean,
  verified_at timestamptz,
  version bigint,
  is_billing_owner boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
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
    entitlement.household_id,
    'plus'::text,
    entitlement.plan_code,
    entitlement.status,
    entitlement.source,
    entitlement.current_period_end,
    entitlement.will_renew,
    case
      when catalog.limits_finalized then catalog.feature_limits
      else '{}'::jsonb
    end,
    catalog.limits_finalized,
    entitlement.verified_at,
    entitlement.version,
    coalesce(
      entitlement.billing_owner_user_id = (select auth.uid()),
      false
    )
  from public.household_entitlements as entitlement
  join public.plan_catalog as catalog
    on catalog.plan_code = entitlement.plan_code
  where entitlement.household_id = p_household_id
    and catalog.active;
end;
$$;

alter table public.billing_customers enable row level security;
alter table public.billing_customers force row level security;
alter table public.billing_webhook_receipts enable row level security;
alter table public.billing_webhook_receipts force row level security;
alter table public.billing_transactions enable row level security;
alter table public.billing_transactions force row level security;
alter table public.billing_household_assignments enable row level security;
alter table public.billing_household_assignments force row level security;
alter table public.plan_catalog enable row level security;
alter table public.plan_catalog force row level security;
alter table public.household_entitlements enable row level security;
alter table public.household_entitlements force row level security;

create policy billing_customers_select_self
on public.billing_customers
for select
to authenticated
using (auth_user_id = (select auth.uid()));

create policy billing_assignments_select_member
on public.billing_household_assignments
for select
to authenticated
using (
  billing_owner_user_id = (select auth.uid())
  or app_private.is_active_household_member(household_id)
);

create policy plan_catalog_select_authenticated
on public.plan_catalog
for select
to authenticated
using (active);

create policy household_entitlements_select_member
on public.household_entitlements
for select
to authenticated
using (app_private.is_active_household_member(household_id));

create or replace view public.current_household_entitlement
with (security_invoker = true)
as
select
  entitlement.household_id,
  entitlement.plan_code,
  entitlement.status,
  entitlement.source,
  case
    when catalog.limits_finalized then catalog.feature_limits
    else '{}'::jsonb
  end as feature_limits,
  catalog.limits_finalized,
  entitlement.current_period_end,
  entitlement.will_renew,
  entitlement.verified_at,
  entitlement.version
from public.household_entitlements as entitlement
join public.plan_catalog as catalog
  on catalog.plan_code = entitlement.plan_code
where catalog.active;

revoke all on table public.billing_customers
  from public, anon, authenticated, service_role;
revoke all on table public.billing_webhook_receipts
  from public, anon, authenticated, service_role;
revoke all on table public.billing_transactions
  from public, anon, authenticated, service_role;
revoke all on table public.billing_household_assignments
  from public, anon, authenticated, service_role;
revoke all on table public.plan_catalog
  from public, anon, authenticated, service_role;
revoke all on table public.household_entitlements
  from public, anon, authenticated, service_role;
revoke all on table public.current_household_entitlement
  from public, anon, authenticated, service_role;

grant select on table public.billing_customers to authenticated;
grant select on table public.billing_household_assignments to authenticated;
grant select on table public.plan_catalog to authenticated;
grant select on table public.household_entitlements to authenticated;
grant select on table public.current_household_entitlement to authenticated;

revoke all on function public.configure_billing_runtime(
  text,
  boolean,
  bigint,
  uuid
) from public, anon, authenticated, service_role;
revoke all on function public.configure_plan_feature_limits(
  text,
  jsonb,
  boolean,
  bigint,
  uuid
) from public, anon, authenticated, service_role;
revoke all on function public.apply_verified_billing_event(
  text,
  text,
  text,
  text,
  timestamptz,
  uuid,
  text,
  text,
  text,
  text,
  text,
  uuid,
  public.entitlement_status,
  text,
  timestamptz,
  timestamptz,
  boolean,
  text,
  bytea,
  uuid
) from public, anon, authenticated, service_role;
revoke all on function public.get_household_entitlement(uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.configure_billing_runtime(
  text,
  boolean,
  bigint,
  uuid
) to service_role;
grant execute on function public.configure_plan_feature_limits(
  text,
  jsonb,
  boolean,
  bigint,
  uuid
) to service_role;
grant execute on function public.apply_verified_billing_event(
  text,
  text,
  text,
  text,
  timestamptz,
  uuid,
  text,
  text,
  text,
  text,
  text,
  uuid,
  public.entitlement_status,
  text,
  timestamptz,
  timestamptz,
  boolean,
  text,
  bytea,
  uuid
) to service_role;
grant execute on function public.get_household_entitlement(uuid)
  to authenticated;

comment on table public.billing_customers is
  'Provider customer identity mapped to one KinFlow auth user per environment.';
comment on table public.billing_webhook_receipts is
  'Service-only encrypted verified-event receipt and idempotency boundary.';
comment on table public.billing_transactions is
  'Service-only normalized transaction snapshots keyed by hashed provider references.';
comment on table public.billing_household_assignments is
  'One active billing customer to one paid household ownership binding.';
comment on table public.household_entitlements is
  'Server-authoritative materialized household access state; family data is not deleted on downgrade.';
comment on view public.current_household_entitlement is
  'RLS-aware entitlement projection without customer transaction receipt or billing-owner identifiers.';
comment on function public.apply_verified_billing_event(
  text,
  text,
  text,
  text,
  timestamptz,
  uuid,
  text,
  text,
  text,
  text,
  text,
  uuid,
  public.entitlement_status,
  text,
  timestamptz,
  timestamptz,
  boolean,
  text,
  bytea,
  uuid
) is
  'Service-only normalized provider event application. HTTP signature and provider mapping belong to WP06-04.';
