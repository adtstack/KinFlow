-- KinFlow WP07-01 account deletion lifecycle.
--
-- Requests are recent-auth mediated by Edge, delayed for a bounded cancellation
-- window, and processed by a leased worker. Shared household content remains;
-- the adult identity, memberships, personal notification rows and provider
-- endpoint material are tombstoned before Supabase Auth is irreversibly
-- soft-deleted by the worker.

create type public.privacy_request_type as enum (
  'export',
  'delete_account',
  'delete_household'
);

create type public.privacy_request_status as enum (
  'queued',
  'verifying',
  'processing',
  'completed',
  'failed',
  'cancelled'
);

create table app_private.privacy_runtime_config (
  singleton boolean primary key default true check (singleton),
  account_deletion_requests_enabled boolean not null default true,
  account_deletion_cancellation_window_seconds integer not null default 86400
    check (
      account_deletion_cancellation_window_seconds between 3600 and 604800
    ),
  updated_at timestamptz not null default pg_catalog.now(),
  version bigint not null default 1 check (version > 0)
);

insert into app_private.privacy_runtime_config(singleton)
values (true);

create table public.privacy_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete restrict,
  household_id uuid references public.households(id) on delete set null,
  request_type public.privacy_request_type not null,
  status public.privacy_request_status not null default 'queued',
  requested_at timestamptz not null default pg_catalog.now(),
  verified_at timestamptz not null,
  scheduled_for timestamptz not null,
  processing_started_at timestamptz,
  completed_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  failure_code text check (
    failure_code is null
    or failure_code in (
      'OWNER_TRANSFER_REQUIRED',
      'AUTH_DELETE_REJECTED',
      'AUTH_DELETE_UNAVAILABLE',
      'AUTH_DELETE_ATTEMPTS_EXHAUSTED',
      'PROCESSING_PRECONDITION_FAILED'
    )
  ),
  active_subscription_at_request boolean not null,
  subscription_acknowledged boolean not null,
  correlation_id uuid not null,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  version bigint not null default 1 check (version > 0),
  constraint privacy_request_account_shape_ck check (
    request_type <> 'delete_account'
    or household_id is null
  ),
  constraint privacy_request_subscription_ack_ck check (
    not active_subscription_at_request or subscription_acknowledged
  ),
  constraint privacy_request_time_order_ck check (
    verified_at >= requested_at
    and scheduled_for >= verified_at
    and updated_at >= created_at
    and (processing_started_at is null
      or processing_started_at >= requested_at)
    and (completed_at is null
      or processing_started_at is not null
      and completed_at >= processing_started_at)
    and (failed_at is null
      or processing_started_at is not null
      and failed_at >= processing_started_at)
    and (cancelled_at is null or cancelled_at >= requested_at)
  ),
  constraint privacy_request_status_shape_ck check (
    case status
      when 'queued' then
        processing_started_at is null
        and completed_at is null
        and failed_at is null
        and cancelled_at is null
        and failure_code is null
      when 'verifying' then
        processing_started_at is null
        and completed_at is null
        and failed_at is null
        and cancelled_at is null
        and failure_code is null
      when 'processing' then
        processing_started_at is not null
        and completed_at is null
        and failed_at is null
        and cancelled_at is null
      when 'completed' then
        processing_started_at is not null
        and completed_at is not null
        and failed_at is null
        and cancelled_at is null
        and failure_code is null
      when 'failed' then
        processing_started_at is not null
        and completed_at is null
        and failed_at is not null
        and cancelled_at is null
        and failure_code is not null
      when 'cancelled' then
        processing_started_at is null
        and completed_at is null
        and failed_at is null
        and cancelled_at is not null
        and failure_code is null
    end
  )
);

create unique index privacy_pending_request_uq
  on public.privacy_requests(auth_user_id, request_type)
  where status in ('queued', 'verifying', 'processing');

create index privacy_requests_user_time_idx
  on public.privacy_requests(auth_user_id, requested_at desc, id desc);

create trigger privacy_requests_set_updated_at_and_version
before update on public.privacy_requests
for each row execute function app_private.set_updated_at_and_version();

create table app_private.account_deletion_command_requests (
  auth_user_id uuid not null references auth.users(id) on delete restrict,
  idempotency_key text not null check (
    pg_catalog.char_length(idempotency_key) between 16 and 200
    and idempotency_key = pg_catalog.btrim(idempotency_key)
    and idempotency_key !~ '[[:cntrl:]]'
  ),
  operation text not null check (operation in ('request', 'cancel')),
  request_hash bytea not null check (pg_catalog.octet_length(request_hash) = 32),
  privacy_request_id uuid not null
    references public.privacy_requests(id) on delete restrict,
  result_version bigint not null check (result_version > 0),
  created_at timestamptz not null default pg_catalog.now(),
  primary key (auth_user_id, idempotency_key)
);

create table app_private.account_deletion_jobs (
  privacy_request_id uuid primary key
    references public.privacy_requests(id) on delete restrict,
  processing_status text not null default 'queued' check (
    processing_status in (
      'queued',
      'leased',
      'retry_wait',
      'succeeded',
      'dead_letter',
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
  tombstoned_at timestamptz,
  auth_soft_deleted_at timestamptz,
  last_error_code text check (
    last_error_code is null
    or last_error_code in (
      'OWNER_TRANSFER_REQUIRED',
      'AUTH_DELETE_REJECTED',
      'AUTH_DELETE_UNAVAILABLE',
      'AUTH_DELETE_ATTEMPTS_EXHAUSTED',
      'PROCESSING_PRECONDITION_FAILED'
    )
  ),
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint account_deletion_job_state_ck check (
    case processing_status
      when 'queued' then
        attempts = 0
        and next_attempt_at is not null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and tombstoned_at is null
        and auth_soft_deleted_at is null
        and last_error_code is null
      when 'leased' then
        attempts between 1 and max_attempts
        and next_attempt_at is null
        and lease_owner is not null
        and lease_token is not null
        and lease_expires_at is not null
        and auth_soft_deleted_at is null
      when 'retry_wait' then
        attempts between 1 and max_attempts - 1
        and next_attempt_at is not null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and auth_soft_deleted_at is null
        and last_error_code = 'AUTH_DELETE_UNAVAILABLE'
      when 'succeeded' then
        attempts between 1 and max_attempts
        and next_attempt_at is null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and tombstoned_at is not null
        and auth_soft_deleted_at is not null
        and last_error_code is null
      when 'dead_letter' then
        attempts between 1 and max_attempts
        and next_attempt_at is null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and auth_soft_deleted_at is null
        and last_error_code is not null
      when 'cancelled' then
        attempts = 0
        and next_attempt_at is null
        and lease_owner is null
        and lease_token is null
        and lease_expires_at is null
        and tombstoned_at is null
        and auth_soft_deleted_at is null
        and last_error_code is null
    end
  ),
  constraint account_deletion_job_time_order_ck check (
    updated_at >= created_at
    and (lease_expires_at is null or lease_expires_at > updated_at)
    and (tombstoned_at is null or tombstoned_at >= created_at)
    and (auth_soft_deleted_at is null
      or tombstoned_at is not null
      and auth_soft_deleted_at >= tombstoned_at)
  )
);

create index account_deletion_jobs_ready_idx
  on app_private.account_deletion_jobs(
    processing_status,
    next_attempt_at,
    privacy_request_id
  )
  where processing_status in ('queued', 'retry_wait');

create table app_private.account_deletion_events (
  id bigint generated always as identity primary key,
  privacy_request_id uuid not null
    references public.privacy_requests(id) on delete restrict,
  transition text not null check (
    transition in (
      'requested',
      'cancelled',
      'claimed',
      'tombstoned',
      'retry_scheduled',
      'completed',
      'failed'
    )
  ),
  request_status public.privacy_request_status not null,
  request_version bigint not null check (request_version > 0),
  correlation_id uuid not null,
  safe_metadata jsonb not null default '{}'::jsonb check (
    pg_catalog.jsonb_typeof(safe_metadata) = 'object'
    and pg_catalog.octet_length(
      pg_catalog.convert_to(safe_metadata::text, 'UTF8')
    ) <= 1024
  ),
  occurred_at timestamptz not null default pg_catalog.now()
);

create index account_deletion_events_request_idx
  on app_private.account_deletion_events(
    privacy_request_id,
    occurred_at,
    id
  );

create table app_private.privacy_runtime_events (
  id bigint generated always as identity primary key,
  previous_enabled boolean not null,
  next_enabled boolean not null,
  previous_cancellation_window_seconds integer not null,
  next_cancellation_window_seconds integer not null,
  previous_version bigint not null check (previous_version > 0),
  next_version bigint not null check (next_version = previous_version + 1),
  correlation_id uuid not null,
  occurred_at timestamptz not null default pg_catalog.now()
);

revoke all on table app_private.privacy_runtime_config
  from public, anon, authenticated, service_role;
revoke all on table app_private.account_deletion_command_requests
  from public, anon, authenticated, service_role;
revoke all on table app_private.account_deletion_jobs
  from public, anon, authenticated, service_role;
revoke all on table app_private.account_deletion_events
  from public, anon, authenticated, service_role;
revoke all on table app_private.privacy_runtime_events
  from public, anon, authenticated, service_role;

create or replace function app_private.reject_account_deletion_audit_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'KFP30',
    message = 'account deletion audit is immutable';
end;
$$;

revoke all on function
  app_private.reject_account_deletion_audit_mutation()
  from public, anon, authenticated, service_role;

create trigger account_deletion_events_immutable
before update or delete on app_private.account_deletion_events
for each row execute function
  app_private.reject_account_deletion_audit_mutation();

create trigger privacy_runtime_events_immutable
before update or delete on app_private.privacy_runtime_events
for each row execute function
  app_private.reject_account_deletion_audit_mutation();

create or replace function app_private.touch_account_deletion_job()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := greatest(
    pg_catalog.clock_timestamp(),
    old.updated_at
  );
  return new;
end;
$$;

revoke all on function app_private.touch_account_deletion_job()
  from public, anon, authenticated, service_role;

create trigger account_deletion_jobs_touch
before update on app_private.account_deletion_jobs
for each row execute function app_private.touch_account_deletion_job();

-- A deleted profile closes authorization even while a short-lived JWT remains.
create or replace function app_private.is_current_user_active()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles as profile
    where profile.auth_user_id = (select auth.uid())
      and profile.deleted_at is null
  )
$$;

create or replace function app_private.current_user_member_id(
  p_household_id uuid
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select member.id
  from public.household_members as member
  join public.profiles as profile
    on profile.auth_user_id = member.auth_user_id
   and profile.deleted_at is null
  where member.household_id = p_household_id
    and member.auth_user_id = (select auth.uid())
    and member.removed_at is null
  limit 1
$$;

create or replace function app_private.is_active_household_member(
  p_household_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.household_members as member
    join public.profiles as profile
      on profile.auth_user_id = member.auth_user_id
     and profile.deleted_at is null
    where member.household_id = p_household_id
      and member.auth_user_id = (select auth.uid())
      and member.removed_at is null
  )
$$;

create or replace function app_private.has_household_role(
  p_household_id uuid,
  p_roles public.household_role[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.household_members as member
    join public.profiles as profile
      on profile.auth_user_id = member.auth_user_id
     and profile.deleted_at is null
    where member.household_id = p_household_id
      and member.auth_user_id = (select auth.uid())
      and member.removed_at is null
      and member.role = any(p_roles)
  )
$$;

revoke all on function app_private.is_current_user_active()
  from public, anon, authenticated, service_role;
grant execute on function app_private.is_current_user_active()
  to authenticated;

drop policy profiles_select_self on public.profiles;
create policy profiles_select_self
on public.profiles
for select
to authenticated
using (
  auth_user_id = (select auth.uid())
  and app_private.is_current_user_active()
);

drop policy profiles_update_self on public.profiles;
create policy profiles_update_self
on public.profiles
for update
to authenticated
using (
  auth_user_id = (select auth.uid())
  and app_private.is_current_user_active()
)
with check (
  auth_user_id = (select auth.uid())
  and deleted_at is null
  and app_private.is_current_user_active()
);

drop policy billing_customers_select_self on public.billing_customers;
create policy billing_customers_select_self
on public.billing_customers
for select
to authenticated
using (
  auth_user_id = (select auth.uid())
  and app_private.is_current_user_active()
);

drop policy billing_assignments_select_member
  on public.billing_household_assignments;
create policy billing_assignments_select_member
on public.billing_household_assignments
for select
to authenticated
using (
  (
    billing_owner_user_id = (select auth.uid())
    and app_private.is_current_user_active()
  )
  or app_private.is_active_household_member(household_id)
);

alter table public.household_members
  add column identity_deleted_at timestamptz,
  add constraint household_member_identity_deleted_ck check (
    identity_deleted_at is null or removed_at is not null
  );

create or replace function app_private.prevent_deleted_account_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.removed_at is null and exists (
    select 1
    from public.profiles as profile
    where profile.auth_user_id = new.auth_user_id
      and profile.deleted_at is not null
  ) then
    raise exception using
      errcode = 'KFP13',
      message = 'deleted account cannot hold an active membership';
  end if;
  return new;
end;
$$;

revoke all on function app_private.prevent_deleted_account_membership()
  from public, anon, authenticated, service_role;

create trigger household_members_require_active_account
before insert or update of auth_user_id, removed_at
on public.household_members
for each row execute function app_private.prevent_deleted_account_membership();

-- Account deletion is a distinct endpoint lifecycle reason and erases the
-- encrypted material even when an endpoint had already been revoked.
alter table public.notification_endpoints
  drop constraint notification_endpoints_revocation_reason_check;
alter table public.notification_endpoints
  add constraint notification_endpoints_revocation_reason_check check (
    revocation_reason is null
    or revocation_reason in (
      'client_revoked',
      'token_reassigned',
      'provider_unregistered',
      'provider_invalid_argument',
      'membership_removed',
      'permission_revoked',
      'rollback_disabled',
      'account_deleted'
    )
  );

alter table app_private.notification_endpoint_events
  drop constraint notification_endpoint_events_reason_code_check;
alter table app_private.notification_endpoint_events
  add constraint notification_endpoint_events_reason_code_check check (
    reason_code is null
    or reason_code in (
      'client_revoked',
      'token_reassigned',
      'provider_unregistered',
      'provider_invalid_argument',
      'membership_removed',
      'permission_revoked',
      'rollback_disabled',
      'account_deleted'
    )
  );

create or replace function app_private.audit_notification_endpoint_transition()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_transition text;
  v_reason_code text;
begin
  if tg_op = 'INSERT' then
    v_transition := 'registered';
  elsif old.revoked_at is null and new.revoked_at is not null then
    v_transition := 'revoked';
    v_reason_code := new.revocation_reason;
  elsif old.revoked_at is not null
    and new.revocation_reason = 'account_deleted' then
    return new;
  elsif old.revoked_at is not null and new.revoked_at is null then
    v_transition := 'registered';
  elsif old.token_fingerprint is distinct from new.token_fingerprint then
    v_transition := 'rotated';
  elsif old.last_registration_id is distinct from new.last_registration_id then
    v_transition := 'refreshed';
  else
    return new;
  end if;

  insert into app_private.notification_endpoint_events (
    endpoint_id,
    transition,
    reason_code,
    endpoint_version,
    occurred_at
  ) values (
    new.id,
    v_transition,
    v_reason_code,
    new.version,
    new.updated_at
  );
  return new;
end;
$$;

alter table public.privacy_requests enable row level security;
alter table public.privacy_requests force row level security;

create policy privacy_requests_select_self
on public.privacy_requests
for select
to authenticated
using (auth_user_id = (select auth.uid()));

revoke all on table public.privacy_requests
  from public, anon, authenticated, service_role;
grant select (
  id,
  request_type,
  status,
  requested_at,
  verified_at,
  scheduled_for,
  processing_started_at,
  completed_at,
  failed_at,
  cancelled_at,
  failure_code,
  active_subscription_at_request,
  subscription_acknowledged,
  version
) on public.privacy_requests to authenticated;

create or replace function app_private.account_deletion_request_lock(
  p_auth_user_id uuid
)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  select pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      p_auth_user_id::text || ':account_deletion',
      0
    )
  )
$$;

create or replace function app_private.account_deletion_owner_count(
  p_auth_user_id uuid
)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select pg_catalog.count(*)::integer
  from public.household_members as member
  join public.households as household
    on household.id = member.household_id
   and household.deleted_at is null
  where member.auth_user_id = p_auth_user_id
    and member.role = 'owner'
    and member.removed_at is null
$$;

create or replace function app_private.account_deletion_has_subscription(
  p_auth_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.billing_household_assignments as assignment
    join public.household_entitlements as entitlement
      on entitlement.assignment_id = assignment.id
     and entitlement.household_id = assignment.household_id
    where assignment.billing_owner_user_id = p_auth_user_id
      and assignment.status = 'active'
      and assignment.binding_state = 'confirmed'
      and entitlement.status in (
        'trialing',
        'active',
        'grace',
        'billing_issue'
      )
  )
$$;

create or replace function app_private.account_deletion_request_row(
  p_auth_user_id uuid,
  p_request_id uuid default null
)
returns setof public.privacy_requests
language sql
stable
security definer
set search_path = ''
as $$
  select request.*
  from public.privacy_requests as request
  where request.auth_user_id = p_auth_user_id
    and request.request_type = 'delete_account'
    and (p_request_id is null or request.id = p_request_id)
  order by request.requested_at desc, request.id desc
  limit 1
$$;

revoke all on function app_private.account_deletion_request_lock(uuid)
  from public, anon, authenticated, service_role;
revoke all on function app_private.account_deletion_owner_count(uuid)
  from public, anon, authenticated, service_role;
revoke all on function app_private.account_deletion_has_subscription(uuid)
  from public, anon, authenticated, service_role;
revoke all on function app_private.account_deletion_request_row(uuid, uuid)
  from public, anon, authenticated, service_role;

create or replace function public.configure_account_deletion_runtime(
  p_enabled boolean,
  p_cancellation_window_seconds integer,
  p_expected_version bigint,
  p_correlation_id uuid
)
returns table (
  account_deletion_requests_enabled boolean,
  cancellation_window_seconds integer,
  version bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_config app_private.privacy_runtime_config%rowtype;
  v_previous app_private.privacy_runtime_config%rowtype;
begin
  if p_enabled is null
    or p_cancellation_window_seconds not between 3600 and 604800
    or p_expected_version is null
    or p_correlation_id is null then
    raise exception using
      errcode = 'KFP02',
      message = 'invalid account deletion runtime configuration';
  end if;

  select config.*
  into v_config
  from app_private.privacy_runtime_config as config
  where config.singleton
  for update;

  if v_config.version <> p_expected_version then
    raise exception using
      errcode = 'KFP07',
      message = 'account deletion runtime version conflict';
  end if;
  v_previous := v_config;

  update app_private.privacy_runtime_config as config
  set account_deletion_requests_enabled = p_enabled,
      account_deletion_cancellation_window_seconds =
        p_cancellation_window_seconds,
      updated_at = pg_catalog.clock_timestamp(),
      version = config.version + 1
  where config.singleton
  returning config.* into v_config;

  insert into app_private.privacy_runtime_events (
    previous_enabled,
    next_enabled,
    previous_cancellation_window_seconds,
    next_cancellation_window_seconds,
    previous_version,
    next_version,
    correlation_id
  ) values (
    v_previous.account_deletion_requests_enabled,
    v_config.account_deletion_requests_enabled,
    v_previous.account_deletion_cancellation_window_seconds,
    v_config.account_deletion_cancellation_window_seconds,
    v_previous.version,
    v_config.version,
    p_correlation_id
  );

  return query select
    v_config.account_deletion_requests_enabled,
    v_config.account_deletion_cancellation_window_seconds,
    v_config.version;
end;
$$;

create or replace function public.get_account_deletion_preflight(
  p_authenticated_user_id uuid
)
returns table (
  can_request boolean,
  owner_household_count integer,
  has_active_subscription boolean,
  pending_request_id uuid,
  pending_status text,
  pending_request_version bigint,
  requests_enabled boolean,
  cancellation_window_seconds integer,
  evaluated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_config app_private.privacy_runtime_config%rowtype;
  v_request public.privacy_requests%rowtype;
  v_owner_count integer;
  v_has_subscription boolean;
  v_evaluated_at timestamptz := pg_catalog.statement_timestamp();
begin
  if p_authenticated_user_id is null or not exists (
    select 1
    from public.profiles as profile
    where profile.auth_user_id = p_authenticated_user_id
      and profile.deleted_at is null
  ) then
    raise exception using
      errcode = 'KFP01',
      message = 'active account required';
  end if;

  select config.* into v_config
  from app_private.privacy_runtime_config as config
  where config.singleton;
  v_owner_count := app_private.account_deletion_owner_count(
    p_authenticated_user_id
  );
  v_has_subscription := app_private.account_deletion_has_subscription(
    p_authenticated_user_id
  );

  select request.* into v_request
  from public.privacy_requests as request
  where request.auth_user_id = p_authenticated_user_id
    and request.request_type = 'delete_account'
    and request.status in ('queued', 'verifying', 'processing')
  order by request.requested_at desc, request.id desc
  limit 1;

  return query select
    v_config.account_deletion_requests_enabled
      and v_owner_count = 0
      and v_request.id is null,
    v_owner_count,
    v_has_subscription,
    v_request.id,
    case when v_request.id is null then null else v_request.status::text end,
    v_request.version,
    v_config.account_deletion_requests_enabled,
    v_config.account_deletion_cancellation_window_seconds,
    v_evaluated_at;
end;
$$;

create or replace function public.get_account_deletion_request(
  p_authenticated_user_id uuid,
  p_request_id uuid default null
)
returns table (
  request_id uuid,
  request_type text,
  status text,
  requested_at timestamptz,
  scheduled_for timestamptz,
  processing_started_at timestamptz,
  completed_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  failure_code text,
  active_subscription_at_request boolean,
  subscription_acknowledged boolean,
  cancellable boolean,
  version bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    request.id,
    request.request_type::text,
    request.status::text,
    request.requested_at,
    request.scheduled_for,
    request.processing_started_at,
    request.completed_at,
    request.failed_at,
    request.cancelled_at,
    request.failure_code,
    request.active_subscription_at_request,
    request.subscription_acknowledged,
    request.status in ('queued', 'verifying'),
    request.version
  from app_private.account_deletion_request_row(
    p_authenticated_user_id,
    p_request_id
  ) as request
$$;

create or replace function public.request_account_deletion(
  p_authenticated_user_id uuid,
  p_idempotency_key text,
  p_subscription_acknowledged boolean,
  p_correlation_id uuid
)
returns table (
  request_id uuid,
  request_type text,
  status text,
  requested_at timestamptz,
  scheduled_for timestamptz,
  processing_started_at timestamptz,
  completed_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  failure_code text,
  active_subscription_at_request boolean,
  subscription_acknowledged boolean,
  cancellable boolean,
  version bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_config app_private.privacy_runtime_config%rowtype;
  v_existing app_private.account_deletion_command_requests%rowtype;
  v_request public.privacy_requests%rowtype;
  v_hash bytea;
  v_has_subscription boolean;
  v_now timestamptz := pg_catalog.clock_timestamp();
begin
  if p_authenticated_user_id is null
    or p_idempotency_key is null
    or pg_catalog.char_length(pg_catalog.btrim(p_idempotency_key))
      not between 16 and 200
    or p_idempotency_key <> pg_catalog.btrim(p_idempotency_key)
    or p_idempotency_key ~ '[[:cntrl:]]'
    or p_subscription_acknowledged is null
    or p_correlation_id is null then
    raise exception using
      errcode = 'KFP02',
      message = 'invalid account deletion request';
  end if;

  perform app_private.account_deletion_request_lock(p_authenticated_user_id);
  v_hash := extensions.digest(
    pg_catalog.convert_to(
      'request|subscriptionAcknowledged=' ||
        p_subscription_acknowledged::text,
      'UTF8'
    ),
    'sha256'
  );

  select command.* into v_existing
  from app_private.account_deletion_command_requests as command
  where command.auth_user_id = p_authenticated_user_id
    and command.idempotency_key = p_idempotency_key;

  if found then
    if v_existing.operation <> 'request'
      or v_existing.request_hash <> v_hash then
      raise exception using
        errcode = 'KFP04',
        message = 'account deletion idempotency key reused';
    end if;
    return query select *
    from public.get_account_deletion_request(
      p_authenticated_user_id,
      v_existing.privacy_request_id
    );
    return;
  end if;

  if not exists (
    select 1 from public.profiles as profile
    where profile.auth_user_id = p_authenticated_user_id
      and profile.deleted_at is null
  ) then
    raise exception using
      errcode = 'KFP01',
      message = 'active account required';
  end if;

  select config.* into v_config
  from app_private.privacy_runtime_config as config
  where config.singleton
  for share;
  if not v_config.account_deletion_requests_enabled then
    raise exception using
      errcode = 'KFP03',
      message = 'account deletion requests are paused';
  end if;
  if app_private.account_deletion_owner_count(p_authenticated_user_id) > 0 then
    raise exception using
      errcode = 'KFP08',
      message = 'owner transfer required before account deletion';
  end if;
  if exists (
    select 1 from public.privacy_requests as request
    where request.auth_user_id = p_authenticated_user_id
      and request.request_type = 'delete_account'
      and request.status in ('queued', 'verifying', 'processing')
  ) then
    raise exception using
      errcode = 'KFP05',
      message = 'account deletion request already pending';
  end if;

  v_has_subscription := app_private.account_deletion_has_subscription(
    p_authenticated_user_id
  );
  if v_has_subscription and not p_subscription_acknowledged then
    raise exception using
      errcode = 'KFP09',
      message = 'active subscription acknowledgement required';
  end if;

  insert into public.privacy_requests (
    auth_user_id,
    request_type,
    status,
    requested_at,
    verified_at,
    scheduled_for,
    active_subscription_at_request,
    subscription_acknowledged,
    correlation_id
  ) values (
    p_authenticated_user_id,
    'delete_account',
    'queued',
    v_now,
    v_now,
    v_now + pg_catalog.make_interval(
      secs => v_config.account_deletion_cancellation_window_seconds
    ),
    v_has_subscription,
    p_subscription_acknowledged,
    p_correlation_id
  ) returning * into v_request;

  insert into app_private.account_deletion_jobs (
    privacy_request_id,
    processing_status,
    next_attempt_at,
    created_at,
    updated_at
  ) values (
    v_request.id,
    'queued',
    v_request.scheduled_for,
    v_now,
    v_now
  );

  insert into app_private.account_deletion_command_requests (
    auth_user_id,
    idempotency_key,
    operation,
    request_hash,
    privacy_request_id,
    result_version,
    created_at
  ) values (
    p_authenticated_user_id,
    p_idempotency_key,
    'request',
    v_hash,
    v_request.id,
    v_request.version,
    v_now
  );

  insert into app_private.account_deletion_events (
    privacy_request_id,
    transition,
    request_status,
    request_version,
    correlation_id,
    safe_metadata,
    occurred_at
  ) values (
    v_request.id,
    'requested',
    v_request.status,
    v_request.version,
    p_correlation_id,
    pg_catalog.jsonb_build_object(
      'activeSubscription', v_has_subscription,
      'cancellationWindowSeconds',
        v_config.account_deletion_cancellation_window_seconds
    ),
    v_now
  );

  return query select *
  from public.get_account_deletion_request(
    p_authenticated_user_id,
    v_request.id
  );
end;
$$;

create or replace function public.cancel_account_deletion(
  p_authenticated_user_id uuid,
  p_request_id uuid,
  p_expected_version bigint,
  p_idempotency_key text,
  p_correlation_id uuid
)
returns table (
  request_id uuid,
  request_type text,
  status text,
  requested_at timestamptz,
  scheduled_for timestamptz,
  processing_started_at timestamptz,
  completed_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  failure_code text,
  active_subscription_at_request boolean,
  subscription_acknowledged boolean,
  cancellable boolean,
  version bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing app_private.account_deletion_command_requests%rowtype;
  v_request public.privacy_requests%rowtype;
  v_hash bytea;
  v_now timestamptz := pg_catalog.clock_timestamp();
begin
  if p_authenticated_user_id is null
    or p_request_id is null
    or p_expected_version is null
    or p_expected_version < 1
    or p_idempotency_key is null
    or pg_catalog.char_length(pg_catalog.btrim(p_idempotency_key))
      not between 16 and 200
    or p_idempotency_key <> pg_catalog.btrim(p_idempotency_key)
    or p_idempotency_key ~ '[[:cntrl:]]'
    or p_correlation_id is null then
    raise exception using
      errcode = 'KFP02',
      message = 'invalid account deletion cancellation';
  end if;

  perform app_private.account_deletion_request_lock(p_authenticated_user_id);
  v_hash := extensions.digest(
    pg_catalog.convert_to(
      'cancel|' || p_request_id::text || '|version=' ||
        p_expected_version::text,
      'UTF8'
    ),
    'sha256'
  );

  select command.* into v_existing
  from app_private.account_deletion_command_requests as command
  where command.auth_user_id = p_authenticated_user_id
    and command.idempotency_key = p_idempotency_key;
  if found then
    if v_existing.operation <> 'cancel'
      or v_existing.request_hash <> v_hash then
      raise exception using
        errcode = 'KFP04',
        message = 'account deletion idempotency key reused';
    end if;
    return query select *
    from public.get_account_deletion_request(
      p_authenticated_user_id,
      v_existing.privacy_request_id
    );
    return;
  end if;

  select request.* into v_request
  from public.privacy_requests as request
  where request.id = p_request_id
    and request.auth_user_id = p_authenticated_user_id
    and request.request_type = 'delete_account'
  for update;
  if not found then
    raise exception using
      errcode = 'KFP06',
      message = 'account deletion request not found';
  end if;
  if v_request.version <> p_expected_version then
    raise exception using
      errcode = 'KFP07',
      message = 'account deletion request version conflict';
  end if;
  if v_request.status not in ('queued', 'verifying') then
    raise exception using
      errcode = 'KFP10',
      message = 'account deletion request is not cancellable';
  end if;

  update public.privacy_requests as request
  set status = 'cancelled',
      cancelled_at = v_now
  where request.id = p_request_id
  returning request.* into v_request;

  update app_private.account_deletion_jobs as job
  set processing_status = 'cancelled',
      next_attempt_at = null
  where job.privacy_request_id = p_request_id
    and job.processing_status = 'queued';
  if not found then
    raise exception using
      errcode = 'KFP10',
      message = 'account deletion request is not cancellable';
  end if;

  insert into app_private.account_deletion_command_requests (
    auth_user_id,
    idempotency_key,
    operation,
    request_hash,
    privacy_request_id,
    result_version,
    created_at
  ) values (
    p_authenticated_user_id,
    p_idempotency_key,
    'cancel',
    v_hash,
    p_request_id,
    v_request.version,
    v_now
  );

  insert into app_private.account_deletion_events (
    privacy_request_id,
    transition,
    request_status,
    request_version,
    correlation_id,
    occurred_at
  ) values (
    p_request_id,
    'cancelled',
    v_request.status,
    v_request.version,
    p_correlation_id,
    v_now
  );

  return query select *
  from public.get_account_deletion_request(
    p_authenticated_user_id,
    p_request_id
  );
end;
$$;

create or replace function public.recover_expired_account_deletion_leases(
  p_as_of timestamptz
)
returns table (
  retry_scheduled integer,
  dead_letter integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.account_deletion_jobs%rowtype;
  v_request public.privacy_requests%rowtype;
  v_retry_count integer := 0;
  v_dead_letter_count integer := 0;
begin
  if p_as_of is null then
    raise exception using
      errcode = 'KFP02',
      message = 'invalid account deletion lease recovery time';
  end if;

  for v_job in
    select job.*
    from app_private.account_deletion_jobs as job
    where job.processing_status = 'leased'
      and job.lease_expires_at <= p_as_of
    order by job.lease_expires_at, job.privacy_request_id
    for update skip locked
  loop
    if v_job.attempts < v_job.max_attempts then
      update app_private.account_deletion_jobs as job
      set processing_status = 'retry_wait',
          next_attempt_at = p_as_of,
          lease_owner = null,
          lease_token = null,
          lease_expires_at = null,
          last_error_code = 'AUTH_DELETE_UNAVAILABLE'
      where job.privacy_request_id = v_job.privacy_request_id;

      update public.privacy_requests as request
      set failure_code = 'AUTH_DELETE_UNAVAILABLE'
      where request.id = v_job.privacy_request_id
      returning request.* into v_request;

      insert into app_private.account_deletion_events (
        privacy_request_id,
        transition,
        request_status,
        request_version,
        correlation_id,
        safe_metadata,
        occurred_at
      ) values (
        v_request.id,
        'retry_scheduled',
        v_request.status,
        v_request.version,
        v_job.lease_token,
        pg_catalog.jsonb_build_object(
          'reasonCode', 'LEASE_EXPIRED',
          'attempts', v_job.attempts
        ),
        p_as_of
      );
      v_retry_count := v_retry_count + 1;
    else
      update app_private.account_deletion_jobs as job
      set processing_status = 'dead_letter',
          next_attempt_at = null,
          lease_owner = null,
          lease_token = null,
          lease_expires_at = null,
          last_error_code = 'AUTH_DELETE_ATTEMPTS_EXHAUSTED'
      where job.privacy_request_id = v_job.privacy_request_id;

      update public.privacy_requests as request
      set status = 'failed',
          failed_at = p_as_of,
          failure_code = 'AUTH_DELETE_ATTEMPTS_EXHAUSTED'
      where request.id = v_job.privacy_request_id
      returning request.* into v_request;

      insert into app_private.account_deletion_events (
        privacy_request_id,
        transition,
        request_status,
        request_version,
        correlation_id,
        safe_metadata,
        occurred_at
      ) values (
        v_request.id,
        'failed',
        v_request.status,
        v_request.version,
        v_job.lease_token,
        pg_catalog.jsonb_build_object(
          'reasonCode', 'AUTH_DELETE_ATTEMPTS_EXHAUSTED',
          'attempts', v_job.attempts
        ),
        p_as_of
      );
      v_dead_letter_count := v_dead_letter_count + 1;
    end if;
  end loop;

  return query select v_retry_count, v_dead_letter_count;
end;
$$;

create or replace function public.claim_account_deletion_requests(
  p_worker_id uuid,
  p_limit integer,
  p_lease_seconds integer,
  p_as_of timestamptz
)
returns table (
  privacy_request_id uuid,
  auth_user_id uuid,
  lease_token uuid,
  request_version bigint,
  active_subscription_at_request boolean,
  attempts integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.account_deletion_jobs%rowtype;
  v_request public.privacy_requests%rowtype;
  v_lease_token uuid;
begin
  if p_worker_id is null
    or p_limit not between 1 and 25
    or p_lease_seconds not between 30 and 300
    or p_as_of is null then
    raise exception using
      errcode = 'KFP02',
      message = 'invalid account deletion claim request';
  end if;

  for v_job in
    select job.*
    from app_private.account_deletion_jobs as job
    join public.privacy_requests as request
      on request.id = job.privacy_request_id
    where job.processing_status in ('queued', 'retry_wait')
      and job.next_attempt_at <= p_as_of
      and request.status in ('queued', 'processing')
    order by job.next_attempt_at, job.privacy_request_id
    limit p_limit
    for update of job skip locked
  loop
    v_lease_token := extensions.gen_random_uuid();
    update app_private.account_deletion_jobs as job
    set processing_status = 'leased',
        attempts = job.attempts + 1,
        next_attempt_at = null,
        lease_owner = p_worker_id,
        lease_token = v_lease_token,
        lease_expires_at = p_as_of + pg_catalog.make_interval(
          secs => p_lease_seconds
        ),
        last_error_code = null
    where job.privacy_request_id = v_job.privacy_request_id
    returning job.* into v_job;

    update public.privacy_requests as request
    set status = 'processing',
        processing_started_at = coalesce(
          request.processing_started_at,
          p_as_of
        ),
        failure_code = null
    where request.id = v_job.privacy_request_id
    returning request.* into v_request;

    insert into app_private.account_deletion_events (
      privacy_request_id,
      transition,
      request_status,
      request_version,
      correlation_id,
      safe_metadata,
      occurred_at
    ) values (
      v_request.id,
      'claimed',
      v_request.status,
      v_request.version,
      v_lease_token,
      pg_catalog.jsonb_build_object('attempts', v_job.attempts),
      p_as_of
    );

    privacy_request_id := v_request.id;
    auth_user_id := v_request.auth_user_id;
    lease_token := v_lease_token;
    request_version := v_request.version;
    active_subscription_at_request :=
      v_request.active_subscription_at_request;
    attempts := v_job.attempts;
    return next;
  end loop;
end;
$$;

create or replace function public.prepare_account_deletion_request(
  p_request_id uuid,
  p_lease_token uuid,
  p_as_of timestamptz
)
returns table (
  auth_user_id uuid,
  affected_membership_count integer,
  erased_endpoint_count integer,
  revoked_invite_count integer,
  already_tombstoned boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.account_deletion_jobs%rowtype;
  v_request public.privacy_requests%rowtype;
  v_member_count integer;
  v_endpoint_count integer;
  v_invite_count integer;
  v_profile_count integer;
  v_already_tombstoned boolean;
begin
  if p_request_id is null
    or p_lease_token is null
    or p_as_of is null then
    raise exception using
      errcode = 'KFP02',
      message = 'invalid account deletion prepare request';
  end if;

  select job.* into v_job
  from app_private.account_deletion_jobs as job
  where job.privacy_request_id = p_request_id
  for update;
  if not found
    or v_job.processing_status <> 'leased'
    or v_job.lease_token <> p_lease_token
    or v_job.lease_expires_at <= p_as_of then
    raise exception using
      errcode = 'KFP11',
      message = 'account deletion lease conflict';
  end if;

  select request.* into v_request
  from public.privacy_requests as request
  where request.id = p_request_id
    and request.request_type = 'delete_account'
    and request.status = 'processing'
  for update;
  if not found then
    raise exception using
      errcode = 'KFP12',
      message = 'account deletion processing precondition failed';
  end if;

  perform app_private.account_deletion_request_lock(v_request.auth_user_id);
  v_already_tombstoned := v_job.tombstoned_at is not null;
  if v_already_tombstoned then
    return query select
      v_request.auth_user_id,
      0,
      0,
      0,
      true;
    return;
  end if;

  if app_private.account_deletion_owner_count(v_request.auth_user_id) > 0 then
    raise exception using
      errcode = 'KFP08',
      message = 'owner transfer required before account deletion';
  end if;

  update public.notification_endpoints as endpoint
  set token_ciphertext = pg_catalog.decode(pg_catalog.repeat('00', 29), 'hex'),
      token_fingerprint = extensions.digest(
        pg_catalog.convert_to(endpoint.id::text || ':account-deleted', 'UTF8'),
        'sha256'
      ),
      revocation_secret_hash = extensions.digest(
        pg_catalog.convert_to(endpoint.id::text || ':proof-erased', 'UTF8'),
        'sha256'
      ),
      permission_state = 'denied',
      revoked_at = coalesce(
        endpoint.revoked_at,
        greatest(
          p_as_of,
          endpoint.created_at,
          endpoint.last_seen_at
        )
      ),
      revocation_reason = 'account_deleted'
  where endpoint.auth_user_id = v_request.auth_user_id;
  get diagnostics v_endpoint_count = row_count;

  update public.household_invites as invite
  set status = 'revoked',
      revoked_at = p_as_of
  where invite.status = 'active'
    and invite.created_by_member_id in (
      select member.id
      from public.household_members as member
      where member.auth_user_id = v_request.auth_user_id
    );
  get diagnostics v_invite_count = row_count;

  delete from public.notification_inbox_items as inbox
  where inbox.recipient_user_id = v_request.auth_user_id;
  delete from public.notification_preferences as preference
  where preference.auth_user_id = v_request.auth_user_id;
  delete from public.user_active_households as active_household
  where active_household.auth_user_id = v_request.auth_user_id;

  update public.household_members as member
  set display_name = 'Deleted member',
      avatar_key = null,
      removed_at = coalesce(member.removed_at, p_as_of),
      identity_deleted_at = coalesce(
        member.identity_deleted_at,
        p_as_of
      )
  where member.auth_user_id = v_request.auth_user_id;
  get diagnostics v_member_count = row_count;

  update public.profiles as profile
  set display_name = 'Deleted account',
      locale = 'en',
      timezone = 'UTC',
      avatar_key = null,
      deleted_at = coalesce(profile.deleted_at, p_as_of)
  where profile.auth_user_id = v_request.auth_user_id;
  get diagnostics v_profile_count = row_count;
  if v_profile_count <> 1 then
    raise exception using
      errcode = 'KFP12',
      message = 'account deletion profile precondition failed';
  end if;

  update app_private.account_deletion_jobs as job
  set tombstoned_at = p_as_of
  where job.privacy_request_id = p_request_id;

  insert into app_private.account_deletion_events (
    privacy_request_id,
    transition,
    request_status,
    request_version,
    correlation_id,
    safe_metadata,
    occurred_at
  ) values (
    p_request_id,
    'tombstoned',
    v_request.status,
    v_request.version,
    p_lease_token,
    pg_catalog.jsonb_build_object(
      'affectedMembershipCount', v_member_count,
      'erasedEndpointCount', v_endpoint_count,
      'revokedInviteCount', v_invite_count
    ),
    p_as_of
  );

  return query select
    v_request.auth_user_id,
    v_member_count,
    v_endpoint_count,
    v_invite_count,
    false;
end;
$$;

create or replace function public.complete_account_deletion_request(
  p_request_id uuid,
  p_lease_token uuid,
  p_as_of timestamptz
)
returns table (
  request_id uuid,
  status text,
  completed_at timestamptz,
  version bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.account_deletion_jobs%rowtype;
  v_request public.privacy_requests%rowtype;
begin
  if p_request_id is null
    or p_lease_token is null
    or p_as_of is null then
    raise exception using
      errcode = 'KFP02',
      message = 'invalid account deletion completion';
  end if;

  select job.* into v_job
  from app_private.account_deletion_jobs as job
  where job.privacy_request_id = p_request_id
  for update;
  if not found
    or v_job.processing_status <> 'leased'
    or v_job.lease_token <> p_lease_token
    or v_job.lease_expires_at <= p_as_of
    or v_job.tombstoned_at is null then
    raise exception using
      errcode = 'KFP11',
      message = 'account deletion lease conflict';
  end if;

  update app_private.account_deletion_jobs as job
  set processing_status = 'succeeded',
      next_attempt_at = null,
      lease_owner = null,
      lease_token = null,
      lease_expires_at = null,
      auth_soft_deleted_at = p_as_of,
      last_error_code = null
  where job.privacy_request_id = p_request_id;

  update public.privacy_requests as request
  set status = 'completed',
      completed_at = p_as_of,
      failure_code = null
  where request.id = p_request_id
    and request.status = 'processing'
  returning request.* into v_request;
  if not found then
    raise exception using
      errcode = 'KFP12',
      message = 'account deletion completion precondition failed';
  end if;

  insert into app_private.account_deletion_events (
    privacy_request_id,
    transition,
    request_status,
    request_version,
    correlation_id,
    occurred_at
  ) values (
    p_request_id,
    'completed',
    v_request.status,
    v_request.version,
    p_lease_token,
    p_as_of
  );

  return query select
    v_request.id,
    v_request.status::text,
    v_request.completed_at,
    v_request.version;
end;
$$;

create or replace function public.fail_account_deletion_request(
  p_request_id uuid,
  p_lease_token uuid,
  p_error_code text,
  p_retryable boolean,
  p_as_of timestamptz
)
returns table (
  request_id uuid,
  status text,
  failure_code text,
  next_attempt_at timestamptz,
  version bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.account_deletion_jobs%rowtype;
  v_request public.privacy_requests%rowtype;
  v_failure_code text;
  v_next_attempt_at timestamptz;
begin
  if p_request_id is null
    or p_lease_token is null
    or p_error_code not in (
      'OWNER_TRANSFER_REQUIRED',
      'AUTH_DELETE_REJECTED',
      'AUTH_DELETE_UNAVAILABLE',
      'PROCESSING_PRECONDITION_FAILED'
    )
    or p_retryable is null
    or p_as_of is null then
    raise exception using
      errcode = 'KFP02',
      message = 'invalid account deletion failure completion';
  end if;

  select job.* into v_job
  from app_private.account_deletion_jobs as job
  where job.privacy_request_id = p_request_id
  for update;
  if not found
    or v_job.processing_status <> 'leased'
    or v_job.lease_token <> p_lease_token
    or v_job.lease_expires_at <= p_as_of then
    raise exception using
      errcode = 'KFP11',
      message = 'account deletion lease conflict';
  end if;

  if p_retryable and v_job.attempts < v_job.max_attempts then
    v_failure_code := 'AUTH_DELETE_UNAVAILABLE';
    v_next_attempt_at := p_as_of + pg_catalog.make_interval(
      secs => least(
        3600,
        (60 * pg_catalog.power(2, v_job.attempts - 1))::integer
      )
    );
    update app_private.account_deletion_jobs as job
    set processing_status = 'retry_wait',
        next_attempt_at = v_next_attempt_at,
        lease_owner = null,
        lease_token = null,
        lease_expires_at = null,
        last_error_code = v_failure_code
    where job.privacy_request_id = p_request_id;

    update public.privacy_requests as request
    set failure_code = v_failure_code
    where request.id = p_request_id
      and request.status = 'processing'
    returning request.* into v_request;

    insert into app_private.account_deletion_events (
      privacy_request_id,
      transition,
      request_status,
      request_version,
      correlation_id,
      safe_metadata,
      occurred_at
    ) values (
      p_request_id,
      'retry_scheduled',
      v_request.status,
      v_request.version,
      p_lease_token,
      pg_catalog.jsonb_build_object(
        'reasonCode', v_failure_code,
        'attempts', v_job.attempts
      ),
      p_as_of
    );
  else
    v_failure_code := case
      when p_retryable then 'AUTH_DELETE_ATTEMPTS_EXHAUSTED'
      else p_error_code
    end;
    update app_private.account_deletion_jobs as job
    set processing_status = 'dead_letter',
        next_attempt_at = null,
        lease_owner = null,
        lease_token = null,
        lease_expires_at = null,
        last_error_code = v_failure_code
    where job.privacy_request_id = p_request_id;

    update public.privacy_requests as request
    set status = 'failed',
        failed_at = p_as_of,
        failure_code = v_failure_code
    where request.id = p_request_id
      and request.status = 'processing'
    returning request.* into v_request;

    insert into app_private.account_deletion_events (
      privacy_request_id,
      transition,
      request_status,
      request_version,
      correlation_id,
      safe_metadata,
      occurred_at
    ) values (
      p_request_id,
      'failed',
      v_request.status,
      v_request.version,
      p_lease_token,
      pg_catalog.jsonb_build_object(
        'reasonCode', v_failure_code,
        'attempts', v_job.attempts
      ),
      p_as_of
    );
  end if;

  if v_request.id is null then
    raise exception using
      errcode = 'KFP12',
      message = 'account deletion failure precondition failed';
  end if;

  return query select
    v_request.id,
    v_request.status::text,
    v_request.failure_code,
    v_next_attempt_at,
    v_request.version;
end;
$$;

revoke all on function public.configure_account_deletion_runtime(
  boolean,
  integer,
  bigint,
  uuid
) from public, anon, authenticated, service_role;
revoke all on function public.get_account_deletion_preflight(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.get_account_deletion_request(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.request_account_deletion(
  uuid,
  text,
  boolean,
  uuid
) from public, anon, authenticated, service_role;
revoke all on function public.cancel_account_deletion(
  uuid,
  uuid,
  bigint,
  text,
  uuid
) from public, anon, authenticated, service_role;
revoke all on function public.recover_expired_account_deletion_leases(
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.claim_account_deletion_requests(
  uuid,
  integer,
  integer,
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.prepare_account_deletion_request(
  uuid,
  uuid,
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.complete_account_deletion_request(
  uuid,
  uuid,
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.fail_account_deletion_request(
  uuid,
  uuid,
  text,
  boolean,
  timestamptz
) from public, anon, authenticated, service_role;

grant execute on function public.configure_account_deletion_runtime(
  boolean,
  integer,
  bigint,
  uuid
) to service_role;
grant execute on function public.get_account_deletion_preflight(uuid)
  to service_role;
grant execute on function public.get_account_deletion_request(uuid, uuid)
  to service_role;
grant execute on function public.request_account_deletion(
  uuid,
  text,
  boolean,
  uuid
) to service_role;
grant execute on function public.cancel_account_deletion(
  uuid,
  uuid,
  bigint,
  text,
  uuid
) to service_role;
grant execute on function public.recover_expired_account_deletion_leases(
  timestamptz
) to service_role;
grant execute on function public.claim_account_deletion_requests(
  uuid,
  integer,
  integer,
  timestamptz
) to service_role;
grant execute on function public.prepare_account_deletion_request(
  uuid,
  uuid,
  timestamptz
) to service_role;
grant execute on function public.complete_account_deletion_request(
  uuid,
  uuid,
  timestamptz
) to service_role;
grant execute on function public.fail_account_deletion_request(
  uuid,
  uuid,
  text,
  boolean,
  timestamptz
) to service_role;
