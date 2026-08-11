-- KinFlow WP07-02A personal data export lifecycle.
--
-- A recent-authenticated adult requests a private export. A leased worker
-- builds a bounded personal-data JSON snapshot plus a safe text rendering,
-- uploads both to the private privacy-exports bucket, and records only object
-- metadata. Downloads use short-lived hash-only one-time grants. Full shared
-- household export and household deletion remain separate Owner workflows.

alter table app_private.privacy_runtime_config
  add column data_export_requests_enabled boolean not null default true,
  add column data_export_downloads_enabled boolean not null default true,
  add column data_export_artifact_ttl_seconds integer not null default 86400
    check (data_export_artifact_ttl_seconds between 3600 and 604800),
  add column data_export_download_grant_ttl_seconds integer not null default 300
    check (data_export_download_grant_ttl_seconds between 60 and 900);

alter table public.privacy_requests
  drop constraint privacy_requests_failure_code_check;
alter table public.privacy_requests
  add constraint privacy_requests_failure_code_check check (
    failure_code is null
    or failure_code in (
      'OWNER_TRANSFER_REQUIRED',
      'AUTH_DELETE_REJECTED',
      'AUTH_DELETE_UNAVAILABLE',
      'AUTH_DELETE_ATTEMPTS_EXHAUSTED',
      'PROCESSING_PRECONDITION_FAILED',
      'EXPORT_BUILD_UNAVAILABLE',
      'EXPORT_UPLOAD_UNAVAILABLE',
      'EXPORT_SIZE_LIMIT_EXCEEDED',
      'EXPORT_ATTEMPTS_EXHAUSTED'
    )
  );

alter table public.privacy_requests
  drop constraint privacy_request_account_shape_ck;
alter table public.privacy_requests
  add constraint privacy_request_account_shape_ck check (
    request_type not in ('delete_account', 'export')
    or household_id is null
  );

create or replace function app_private.guard_pending_privacy_request_type()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in ('queued', 'verifying', 'processing')
    and exists (
      select 1
      from public.privacy_requests as request
      where request.auth_user_id = new.auth_user_id
        and request.request_type <> new.request_type
        and request.status in ('queued', 'verifying', 'processing')
        and request.id <> new.id
    ) then
    raise exception using
      errcode = 'KFP05',
      message = 'another privacy request is already pending';
  end if;
  return new;
end;
$$;

revoke all on function app_private.guard_pending_privacy_request_type()
  from public, anon, authenticated, service_role;

create trigger privacy_requests_guard_cross_type_pending
before insert or update of auth_user_id, request_type, status
on public.privacy_requests
for each row execute function app_private.guard_pending_privacy_request_type();

create table public.data_exports (
  id uuid primary key default extensions.gen_random_uuid(),
  privacy_request_id uuid not null unique
    references public.privacy_requests(id) on delete restrict,
  schema_version text not null default '2026-08-08-wp07-02a' check (
    schema_version = '2026-08-08-wp07-02a'
  ),
  machine_object_key text,
  human_object_key text,
  machine_checksum_sha256 text check (
    machine_checksum_sha256 is null
    or machine_checksum_sha256 ~ '^[0-9a-f]{64}$'
  ),
  human_checksum_sha256 text check (
    human_checksum_sha256 is null
    or human_checksum_sha256 ~ '^[0-9a-f]{64}$'
  ),
  machine_size_bytes bigint check (
    machine_size_bytes is null
    or machine_size_bytes between 1 and 10485760
  ),
  human_size_bytes bigint check (
    human_size_bytes is null
    or human_size_bytes between 1 and 10485760
  ),
  artifact_expires_at timestamptz,
  revoked_at timestamptz,
  purged_at timestamptz,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  version bigint not null default 1 check (version > 0),
  constraint data_export_artifact_shape_ck check (
    (
      machine_object_key is null
      and human_object_key is null
      and machine_checksum_sha256 is null
      and human_checksum_sha256 is null
      and machine_size_bytes is null
      and human_size_bytes is null
      and artifact_expires_at is null
      and purged_at is null
    )
    or (
      machine_object_key is not null
      and human_object_key is not null
      and machine_checksum_sha256 is not null
      and human_checksum_sha256 is not null
      and machine_size_bytes is not null
      and human_size_bytes is not null
      and artifact_expires_at is not null
      and purged_at is null
    )
    or (
      machine_object_key is null
      and human_object_key is null
      and machine_checksum_sha256 is not null
      and human_checksum_sha256 is not null
      and machine_size_bytes is not null
      and human_size_bytes is not null
      and artifact_expires_at is not null
      and purged_at is not null
    )
  ),
  constraint data_export_artifact_time_ck check (
    updated_at >= created_at
    and (artifact_expires_at is null or artifact_expires_at > created_at)
    and (revoked_at is null or revoked_at >= created_at)
    and (purged_at is null or purged_at >= created_at)
  ),
  constraint data_export_object_key_ck check (
    machine_object_key is null
    or (
      machine_object_key ~ '^exports/[0-9a-f-]{36}/kinflow-data\.json$'
      and human_object_key ~ '^exports/[0-9a-f-]{36}/kinflow-data\.txt$'
    )
  )
);

create trigger data_exports_set_updated_at_and_version
before update on public.data_exports
for each row execute function app_private.set_updated_at_and_version();

create table app_private.data_export_command_requests (
  auth_user_id uuid not null references auth.users(id) on delete restrict,
  idempotency_key text not null check (
    pg_catalog.char_length(idempotency_key) between 16 and 200
    and idempotency_key = pg_catalog.btrim(idempotency_key)
    and idempotency_key !~ '[[:cntrl:]]'
  ),
  operation text not null check (operation in ('request', 'cancel', 'revoke')),
  request_hash bytea not null check (pg_catalog.octet_length(request_hash) = 32),
  privacy_request_id uuid not null
    references public.privacy_requests(id) on delete restrict,
  result_request_version bigint not null check (result_request_version > 0),
  result_artifact_version bigint check (result_artifact_version > 0),
  created_at timestamptz not null default pg_catalog.now(),
  primary key (auth_user_id, idempotency_key)
);

create table app_private.data_export_jobs (
  privacy_request_id uuid primary key
    references public.privacy_requests(id) on delete restrict,
  data_export_id uuid not null unique
    references public.data_exports(id) on delete restrict,
  artifact_prefix uuid not null unique default extensions.gen_random_uuid(),
  processing_status text not null default 'queued' check (
    processing_status in (
      'queued', 'leased', 'retry_wait', 'succeeded', 'dead_letter', 'cancelled'
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
  last_error_code text check (
    last_error_code is null
    or last_error_code in (
      'EXPORT_BUILD_UNAVAILABLE',
      'EXPORT_UPLOAD_UNAVAILABLE',
      'EXPORT_SIZE_LIMIT_EXCEEDED',
      'EXPORT_ATTEMPTS_EXHAUSTED',
      'PROCESSING_PRECONDITION_FAILED'
    )
  ),
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint data_export_job_state_ck check (
    case processing_status
      when 'queued' then
        attempts = 0 and next_attempt_at is not null
        and lease_owner is null and lease_token is null
        and lease_expires_at is null and last_error_code is null
      when 'leased' then
        attempts between 1 and max_attempts and next_attempt_at is null
        and lease_owner is not null and lease_token is not null
        and lease_expires_at is not null
      when 'retry_wait' then
        attempts between 1 and max_attempts - 1 and next_attempt_at is not null
        and lease_owner is null and lease_token is null
        and lease_expires_at is null and last_error_code is not null
      when 'succeeded' then
        attempts between 1 and max_attempts and next_attempt_at is null
        and lease_owner is null and lease_token is null
        and lease_expires_at is null and last_error_code is null
      when 'dead_letter' then
        attempts between 1 and max_attempts and next_attempt_at is null
        and lease_owner is null and lease_token is null
        and lease_expires_at is null and last_error_code is not null
      when 'cancelled' then
        attempts = 0 and next_attempt_at is null
        and lease_owner is null and lease_token is null
        and lease_expires_at is null and last_error_code is null
    end
  ),
  constraint data_export_job_time_ck check (
    updated_at >= created_at
    and (lease_expires_at is null or lease_expires_at > updated_at)
  )
);

create index data_export_jobs_ready_idx
  on app_private.data_export_jobs(
    processing_status,
    next_attempt_at,
    privacy_request_id
  ) where processing_status in ('queued', 'retry_wait');

create table app_private.data_export_download_grants (
  id uuid primary key default extensions.gen_random_uuid(),
  data_export_id uuid not null
    references public.data_exports(id) on delete restrict,
  token_hash bytea not null unique check (
    pg_catalog.octet_length(token_hash) = 32
  ),
  export_format text not null check (export_format in ('json', 'text')),
  correlation_id uuid not null,
  issued_at timestamptz not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  revoked_at timestamptz,
  constraint data_export_download_grant_time_ck check (
    expires_at > issued_at
    and (consumed_at is null or consumed_at >= issued_at)
    and (revoked_at is null or revoked_at >= issued_at)
  )
);

create unique index data_export_download_grant_active_uq
  on app_private.data_export_download_grants(data_export_id, export_format)
  where consumed_at is null and revoked_at is null;

create index data_export_download_grants_expiry_idx
  on app_private.data_export_download_grants(expires_at)
  where consumed_at is null and revoked_at is null;

create table app_private.data_export_purge_jobs (
  data_export_id uuid primary key
    references public.data_exports(id) on delete restrict,
  processing_status text not null default 'queued' check (
    processing_status in ('queued', 'leased', 'retry_wait', 'succeeded', 'dead_letter')
  ),
  attempts integer not null default 0 check (attempts between 0 and 5),
  max_attempts integer not null default 5 check (
    max_attempts between 1 and 5 and attempts <= max_attempts
  ),
  next_attempt_at timestamptz not null,
  lease_owner uuid,
  lease_token uuid,
  lease_expires_at timestamptz,
  last_error_code text check (
    last_error_code is null or last_error_code in (
      'EXPORT_PURGE_UNAVAILABLE',
      'EXPORT_PURGE_ATTEMPTS_EXHAUSTED',
      'PROCESSING_PRECONDITION_FAILED'
    )
  ),
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint data_export_purge_job_state_ck check (
    case processing_status
      when 'queued' then
        attempts = 0 and lease_owner is null and lease_token is null
        and lease_expires_at is null and last_error_code is null
      when 'leased' then
        attempts between 1 and max_attempts
        and lease_owner is not null and lease_token is not null
        and lease_expires_at is not null
      when 'retry_wait' then
        attempts between 1 and max_attempts - 1
        and lease_owner is null and lease_token is null
        and lease_expires_at is null and last_error_code is not null
      when 'succeeded' then
        attempts between 1 and max_attempts
        and lease_owner is null and lease_token is null
        and lease_expires_at is null and last_error_code is null
      when 'dead_letter' then
        attempts between 1 and max_attempts
        and lease_owner is null and lease_token is null
        and lease_expires_at is null and last_error_code is not null
    end
  ),
  constraint data_export_purge_job_time_ck check (
    updated_at >= created_at
    and (lease_expires_at is null or lease_expires_at > updated_at)
  )
);

create index data_export_purge_jobs_ready_idx
  on app_private.data_export_purge_jobs(
    processing_status,
    next_attempt_at,
    data_export_id
  ) where processing_status in ('queued', 'retry_wait');

create table app_private.data_export_events (
  id bigint generated always as identity primary key,
  privacy_request_id uuid not null
    references public.privacy_requests(id) on delete restrict,
  data_export_id uuid not null
    references public.data_exports(id) on delete restrict,
  transition text not null check (
    transition in (
      'requested', 'cancelled', 'claimed', 'retry_scheduled', 'completed',
      'failed', 'download_grant_issued', 'download_consumed', 'revoked',
      'purge_claimed', 'purge_retry_scheduled', 'purged', 'purge_failed'
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

create index data_export_events_request_idx
  on app_private.data_export_events(
    privacy_request_id,
    occurred_at,
    id
  );

create table app_private.data_export_runtime_events (
  id bigint generated always as identity primary key,
  previous_requests_enabled boolean not null,
  next_requests_enabled boolean not null,
  previous_downloads_enabled boolean not null,
  next_downloads_enabled boolean not null,
  previous_artifact_ttl_seconds integer not null,
  next_artifact_ttl_seconds integer not null,
  previous_grant_ttl_seconds integer not null,
  next_grant_ttl_seconds integer not null,
  previous_version bigint not null check (previous_version > 0),
  next_version bigint not null check (next_version = previous_version + 1),
  correlation_id uuid not null,
  occurred_at timestamptz not null default pg_catalog.now()
);

revoke all on table public.data_exports
  from public, anon, authenticated, service_role;
revoke all on table app_private.data_export_command_requests
  from public, anon, authenticated, service_role;
revoke all on table app_private.data_export_jobs
  from public, anon, authenticated, service_role;
revoke all on table app_private.data_export_download_grants
  from public, anon, authenticated, service_role;
revoke all on table app_private.data_export_purge_jobs
  from public, anon, authenticated, service_role;
revoke all on table app_private.data_export_events
  from public, anon, authenticated, service_role;
revoke all on table app_private.data_export_runtime_events
  from public, anon, authenticated, service_role;

create or replace function app_private.reject_data_export_audit_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'KFX30',
    message = 'data export audit is immutable';
end;
$$;

revoke all on function app_private.reject_data_export_audit_mutation()
  from public, anon, authenticated, service_role;

create trigger data_export_events_immutable
before update or delete on app_private.data_export_events
for each row execute function app_private.reject_data_export_audit_mutation();

create trigger data_export_runtime_events_immutable
before update or delete on app_private.data_export_runtime_events
for each row execute function app_private.reject_data_export_audit_mutation();

create or replace function app_private.touch_data_export_job()
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

revoke all on function app_private.touch_data_export_job()
  from public, anon, authenticated, service_role;

create trigger data_export_jobs_touch
before update on app_private.data_export_jobs
for each row execute function app_private.touch_data_export_job();

create trigger data_export_purge_jobs_touch
before update on app_private.data_export_purge_jobs
for each row execute function app_private.touch_data_export_job();

alter table public.data_exports enable row level security;
alter table public.data_exports force row level security;

create or replace function app_private.is_own_data_export(
  p_privacy_request_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.privacy_requests as request
    where request.id = p_privacy_request_id
      and request.auth_user_id = (select auth.uid())
  )
$$;

revoke all on function app_private.is_own_data_export(uuid)
  from public, anon, authenticated, service_role;
grant execute on function app_private.is_own_data_export(uuid)
  to authenticated;

create policy data_exports_select_self
on public.data_exports
for select
to authenticated
using (app_private.is_own_data_export(privacy_request_id));

grant select (
  id,
  privacy_request_id,
  schema_version,
  machine_checksum_sha256,
  human_checksum_sha256,
  machine_size_bytes,
  human_size_bytes,
  artifact_expires_at,
  revoked_at,
  purged_at,
  created_at,
  updated_at,
  version
) on public.data_exports to authenticated;

create or replace function app_private.data_export_request_lock(
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
      p_auth_user_id::text || ':data_export',
      0
    )
  )
$$;

create or replace function app_private.data_export_request_row(
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
    and request.request_type = 'export'
    and (p_request_id is null or request.id = p_request_id)
  order by request.requested_at desc, request.id desc
  limit 1
$$;

revoke all on function app_private.data_export_request_lock(uuid)
  from public, anon, authenticated, service_role;
revoke all on function app_private.data_export_request_row(uuid, uuid)
  from public, anon, authenticated, service_role;

create or replace function public.configure_data_export_runtime(
  p_requests_enabled boolean,
  p_downloads_enabled boolean,
  p_artifact_ttl_seconds integer,
  p_download_grant_ttl_seconds integer,
  p_expected_version bigint,
  p_correlation_id uuid
)
returns table (
  requests_enabled boolean,
  downloads_enabled boolean,
  artifact_ttl_seconds integer,
  download_grant_ttl_seconds integer,
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
  if p_requests_enabled is null
    or p_downloads_enabled is null
    or p_artifact_ttl_seconds not between 3600 and 604800
    or p_download_grant_ttl_seconds not between 60 and 900
    or p_expected_version is null
    or p_correlation_id is null then
    raise exception using
      errcode = 'KFX02',
      message = 'invalid data export runtime configuration';
  end if;

  select config.* into v_config
  from app_private.privacy_runtime_config as config
  where config.singleton
  for update;
  if v_config.version <> p_expected_version then
    raise exception using
      errcode = 'KFX07',
      message = 'data export runtime version conflict';
  end if;
  v_previous := v_config;

  update app_private.privacy_runtime_config as config
  set data_export_requests_enabled = p_requests_enabled,
      data_export_downloads_enabled = p_downloads_enabled,
      data_export_artifact_ttl_seconds = p_artifact_ttl_seconds,
      data_export_download_grant_ttl_seconds = p_download_grant_ttl_seconds,
      updated_at = pg_catalog.clock_timestamp(),
      version = config.version + 1
  where config.singleton
  returning config.* into v_config;

  insert into app_private.data_export_runtime_events (
    previous_requests_enabled,
    next_requests_enabled,
    previous_downloads_enabled,
    next_downloads_enabled,
    previous_artifact_ttl_seconds,
    next_artifact_ttl_seconds,
    previous_grant_ttl_seconds,
    next_grant_ttl_seconds,
    previous_version,
    next_version,
    correlation_id
  ) values (
    v_previous.data_export_requests_enabled,
    v_config.data_export_requests_enabled,
    v_previous.data_export_downloads_enabled,
    v_config.data_export_downloads_enabled,
    v_previous.data_export_artifact_ttl_seconds,
    v_config.data_export_artifact_ttl_seconds,
    v_previous.data_export_download_grant_ttl_seconds,
    v_config.data_export_download_grant_ttl_seconds,
    v_previous.version,
    v_config.version,
    p_correlation_id
  );

  return query select
    v_config.data_export_requests_enabled,
    v_config.data_export_downloads_enabled,
    v_config.data_export_artifact_ttl_seconds,
    v_config.data_export_download_grant_ttl_seconds,
    v_config.version;
end;
$$;

create or replace function public.get_data_export_preflight(
  p_authenticated_user_id uuid
)
returns table (
  can_request boolean,
  pending_request_id uuid,
  pending_status text,
  pending_request_version bigint,
  conflicting_request_pending boolean,
  requests_enabled boolean,
  downloads_enabled boolean,
  artifact_ttl_seconds integer,
  download_grant_ttl_seconds integer,
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
  v_conflicting boolean;
  v_evaluated_at timestamptz := pg_catalog.statement_timestamp();
begin
  if p_authenticated_user_id is null or not exists (
    select 1
    from public.profiles as profile
    where profile.auth_user_id = p_authenticated_user_id
      and profile.deleted_at is null
  ) then
    raise exception using
      errcode = 'KFX01',
      message = 'active account required';
  end if;

  select config.* into v_config
  from app_private.privacy_runtime_config as config
  where config.singleton;

  select request.* into v_request
  from public.privacy_requests as request
  where request.auth_user_id = p_authenticated_user_id
    and request.request_type = 'export'
    and request.status in ('queued', 'verifying', 'processing')
  order by request.requested_at desc, request.id desc
  limit 1;

  select exists (
    select 1
    from public.privacy_requests as request
    where request.auth_user_id = p_authenticated_user_id
      and request.request_type <> 'export'
      and request.status in ('queued', 'verifying', 'processing')
  ) into v_conflicting;

  return query select
    v_config.data_export_requests_enabled
      and v_request.id is null
      and not v_conflicting,
    v_request.id,
    case when v_request.id is null then null else v_request.status::text end,
    v_request.version,
    v_conflicting,
    v_config.data_export_requests_enabled,
    v_config.data_export_downloads_enabled,
    v_config.data_export_artifact_ttl_seconds,
    v_config.data_export_download_grant_ttl_seconds,
    v_evaluated_at;
end;
$$;

create or replace function public.get_data_export_request(
  p_authenticated_user_id uuid,
  p_request_id uuid default null
)
returns table (
  request_id uuid,
  status text,
  requested_at timestamptz,
  processing_started_at timestamptz,
  completed_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  failure_code text,
  cancellable boolean,
  request_version bigint,
  artifact_id uuid,
  artifact_version bigint,
  schema_version text,
  artifact_expires_at timestamptz,
  revoked_at timestamptz,
  purged_at timestamptz,
  machine_size_bytes bigint,
  human_size_bytes bigint,
  available boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    request.id,
    request.status::text,
    request.requested_at,
    request.processing_started_at,
    request.completed_at,
    request.failed_at,
    request.cancelled_at,
    request.failure_code,
    request.status in ('queued', 'verifying'),
    request.version,
    export.id,
    export.version,
    export.schema_version,
    export.artifact_expires_at,
    export.revoked_at,
    export.purged_at,
    export.machine_size_bytes,
    export.human_size_bytes,
    request.status = 'completed'
      and export.machine_object_key is not null
      and export.human_object_key is not null
      and export.artifact_expires_at > pg_catalog.statement_timestamp()
      and export.revoked_at is null
      and export.purged_at is null
  from app_private.data_export_request_row(
    p_authenticated_user_id,
    p_request_id
  ) as request
  left join public.data_exports as export
    on export.privacy_request_id = request.id
$$;

create or replace function public.request_data_export(
  p_authenticated_user_id uuid,
  p_idempotency_key text,
  p_correlation_id uuid
)
returns table (
  request_id uuid,
  status text,
  requested_at timestamptz,
  processing_started_at timestamptz,
  completed_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  failure_code text,
  cancellable boolean,
  request_version bigint,
  artifact_id uuid,
  artifact_version bigint,
  schema_version text,
  artifact_expires_at timestamptz,
  revoked_at timestamptz,
  purged_at timestamptz,
  machine_size_bytes bigint,
  human_size_bytes bigint,
  available boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_config app_private.privacy_runtime_config%rowtype;
  v_existing app_private.data_export_command_requests%rowtype;
  v_request public.privacy_requests%rowtype;
  v_export public.data_exports%rowtype;
  v_hash bytea;
  v_now timestamptz := pg_catalog.clock_timestamp();
begin
  if p_authenticated_user_id is null
    or p_idempotency_key is null
    or pg_catalog.char_length(pg_catalog.btrim(p_idempotency_key))
      not between 16 and 200
    or p_idempotency_key <> pg_catalog.btrim(p_idempotency_key)
    or p_idempotency_key ~ '[[:cntrl:]]'
    or p_correlation_id is null then
    raise exception using
      errcode = 'KFX02',
      message = 'invalid data export request';
  end if;

  perform app_private.data_export_request_lock(p_authenticated_user_id);
  v_hash := extensions.digest(
    pg_catalog.convert_to('request|personal-v1', 'UTF8'),
    'sha256'
  );

  select command.* into v_existing
  from app_private.data_export_command_requests as command
  where command.auth_user_id = p_authenticated_user_id
    and command.idempotency_key = p_idempotency_key;
  if found then
    if v_existing.operation <> 'request'
      or v_existing.request_hash <> v_hash then
      raise exception using
        errcode = 'KFX04',
        message = 'data export idempotency key reused';
    end if;
    return query select *
    from public.get_data_export_request(
      p_authenticated_user_id,
      v_existing.privacy_request_id
    );
    return;
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.auth_user_id = p_authenticated_user_id
      and profile.deleted_at is null
  ) then
    raise exception using
      errcode = 'KFX01',
      message = 'active account required';
  end if;

  select config.* into v_config
  from app_private.privacy_runtime_config as config
  where config.singleton
  for share;
  if not v_config.data_export_requests_enabled then
    raise exception using
      errcode = 'KFX03',
      message = 'data export requests are paused';
  end if;
  if exists (
    select 1
    from public.privacy_requests as request
    where request.auth_user_id = p_authenticated_user_id
      and request.status in ('queued', 'verifying', 'processing')
  ) then
    raise exception using
      errcode = 'KFX05',
      message = 'privacy request already pending';
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
    'export',
    'queued',
    v_now,
    v_now,
    v_now,
    false,
    false,
    p_correlation_id
  ) returning * into v_request;

  insert into public.data_exports (privacy_request_id)
  values (v_request.id)
  returning * into v_export;

  insert into app_private.data_export_jobs (
    privacy_request_id,
    data_export_id,
    processing_status,
    next_attempt_at,
    created_at,
    updated_at
  ) values (
    v_request.id,
    v_export.id,
    'queued',
    v_now,
    v_now,
    v_now
  );

  insert into app_private.data_export_command_requests (
    auth_user_id,
    idempotency_key,
    operation,
    request_hash,
    privacy_request_id,
    result_request_version,
    result_artifact_version,
    created_at
  ) values (
    p_authenticated_user_id,
    p_idempotency_key,
    'request',
    v_hash,
    v_request.id,
    v_request.version,
    v_export.version,
    v_now
  );

  insert into app_private.data_export_events (
    privacy_request_id,
    data_export_id,
    transition,
    request_status,
    request_version,
    correlation_id,
    safe_metadata,
    occurred_at
  ) values (
    v_request.id,
    v_export.id,
    'requested',
    v_request.status,
    v_request.version,
    p_correlation_id,
    pg_catalog.jsonb_build_object(
      'scope', 'personal',
      'formats', pg_catalog.jsonb_build_array('json', 'text')
    ),
    v_now
  );

  return query select *
  from public.get_data_export_request(
    p_authenticated_user_id,
    v_request.id
  );
end;
$$;

create or replace function public.cancel_data_export(
  p_authenticated_user_id uuid,
  p_request_id uuid,
  p_expected_version bigint,
  p_idempotency_key text,
  p_correlation_id uuid
)
returns table (
  request_id uuid,
  status text,
  requested_at timestamptz,
  processing_started_at timestamptz,
  completed_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  failure_code text,
  cancellable boolean,
  request_version bigint,
  artifact_id uuid,
  artifact_version bigint,
  schema_version text,
  artifact_expires_at timestamptz,
  revoked_at timestamptz,
  purged_at timestamptz,
  machine_size_bytes bigint,
  human_size_bytes bigint,
  available boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing app_private.data_export_command_requests%rowtype;
  v_request public.privacy_requests%rowtype;
  v_export public.data_exports%rowtype;
  v_hash bytea;
  v_now timestamptz := pg_catalog.clock_timestamp();
begin
  if p_authenticated_user_id is null or p_request_id is null
    or p_expected_version is null or p_expected_version < 1
    or p_idempotency_key is null
    or pg_catalog.char_length(pg_catalog.btrim(p_idempotency_key))
      not between 16 and 200
    or p_idempotency_key <> pg_catalog.btrim(p_idempotency_key)
    or p_idempotency_key ~ '[[:cntrl:]]'
    or p_correlation_id is null then
    raise exception using
      errcode = 'KFX02',
      message = 'invalid data export cancellation';
  end if;

  perform app_private.data_export_request_lock(p_authenticated_user_id);
  v_hash := extensions.digest(
    pg_catalog.convert_to(
      'cancel|' || p_request_id::text || '|' || p_expected_version::text,
      'UTF8'
    ),
    'sha256'
  );
  select command.* into v_existing
  from app_private.data_export_command_requests as command
  where command.auth_user_id = p_authenticated_user_id
    and command.idempotency_key = p_idempotency_key;
  if found then
    if v_existing.operation <> 'cancel'
      or v_existing.request_hash <> v_hash then
      raise exception using
        errcode = 'KFX04',
        message = 'data export idempotency key reused';
    end if;
    return query select *
    from public.get_data_export_request(
      p_authenticated_user_id,
      v_existing.privacy_request_id
    );
    return;
  end if;

  select request.* into v_request
  from public.privacy_requests as request
  where request.id = p_request_id
    and request.auth_user_id = p_authenticated_user_id
    and request.request_type = 'export'
  for update;
  if not found then
    raise exception using errcode = 'KFX06', message = 'data export not found';
  end if;
  if v_request.version <> p_expected_version then
    raise exception using errcode = 'KFX07', message = 'data export version conflict';
  end if;
  if v_request.status not in ('queued', 'verifying') then
    raise exception using errcode = 'KFX08', message = 'data export not cancellable';
  end if;

  update public.privacy_requests as request
  set status = 'cancelled', cancelled_at = v_now
  where request.id = p_request_id
  returning request.* into v_request;
  update app_private.data_export_jobs as job
  set processing_status = 'cancelled', next_attempt_at = null
  where job.privacy_request_id = p_request_id;
  select export.* into v_export
  from public.data_exports as export
  where export.privacy_request_id = p_request_id;

  insert into app_private.data_export_command_requests (
    auth_user_id, idempotency_key, operation, request_hash,
    privacy_request_id, result_request_version, result_artifact_version,
    created_at
  ) values (
    p_authenticated_user_id, p_idempotency_key, 'cancel', v_hash,
    p_request_id, v_request.version, v_export.version, v_now
  );
  insert into app_private.data_export_events (
    privacy_request_id, data_export_id, transition, request_status,
    request_version, correlation_id, occurred_at
  ) values (
    p_request_id, v_export.id, 'cancelled', v_request.status,
    v_request.version, p_correlation_id, v_now
  );

  return query select *
  from public.get_data_export_request(p_authenticated_user_id, p_request_id);
end;
$$;

create or replace function public.revoke_data_export(
  p_authenticated_user_id uuid,
  p_request_id uuid,
  p_expected_artifact_version bigint,
  p_idempotency_key text,
  p_correlation_id uuid
)
returns table (
  request_id uuid,
  status text,
  requested_at timestamptz,
  processing_started_at timestamptz,
  completed_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  failure_code text,
  cancellable boolean,
  request_version bigint,
  artifact_id uuid,
  artifact_version bigint,
  schema_version text,
  artifact_expires_at timestamptz,
  revoked_at timestamptz,
  purged_at timestamptz,
  machine_size_bytes bigint,
  human_size_bytes bigint,
  available boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing app_private.data_export_command_requests%rowtype;
  v_request public.privacy_requests%rowtype;
  v_export public.data_exports%rowtype;
  v_hash bytea;
  v_now timestamptz := pg_catalog.clock_timestamp();
begin
  if p_authenticated_user_id is null or p_request_id is null
    or p_expected_artifact_version is null or p_expected_artifact_version < 1
    or p_idempotency_key is null
    or pg_catalog.char_length(pg_catalog.btrim(p_idempotency_key))
      not between 16 and 200
    or p_idempotency_key <> pg_catalog.btrim(p_idempotency_key)
    or p_idempotency_key ~ '[[:cntrl:]]'
    or p_correlation_id is null then
    raise exception using errcode = 'KFX02', message = 'invalid export revocation';
  end if;

  perform app_private.data_export_request_lock(p_authenticated_user_id);
  v_hash := extensions.digest(
    pg_catalog.convert_to(
      'revoke|' || p_request_id::text || '|' ||
        p_expected_artifact_version::text,
      'UTF8'
    ),
    'sha256'
  );
  select command.* into v_existing
  from app_private.data_export_command_requests as command
  where command.auth_user_id = p_authenticated_user_id
    and command.idempotency_key = p_idempotency_key;
  if found then
    if v_existing.operation <> 'revoke'
      or v_existing.request_hash <> v_hash then
      raise exception using errcode = 'KFX04', message = 'idempotency key reused';
    end if;
    return query select *
    from public.get_data_export_request(
      p_authenticated_user_id,
      v_existing.privacy_request_id
    );
    return;
  end if;

  select request.* into v_request
  from public.privacy_requests as request
  where request.id = p_request_id
    and request.auth_user_id = p_authenticated_user_id
    and request.request_type = 'export'
  for update;
  if not found or v_request.status <> 'completed' then
    raise exception using errcode = 'KFX11', message = 'export artifact unavailable';
  end if;
  select export.* into v_export
  from public.data_exports as export
  where export.privacy_request_id = p_request_id
  for update;
  if not found or v_export.version <> p_expected_artifact_version then
    raise exception using errcode = 'KFX07', message = 'artifact version conflict';
  end if;
  if v_export.purged_at is not null then
    raise exception using errcode = 'KFX11', message = 'export artifact unavailable';
  end if;

  if v_export.revoked_at is null then
    update public.data_exports as export
    set revoked_at = v_now
    where export.id = v_export.id
    returning export.* into v_export;
    update app_private.data_export_download_grants as download_grant
    set revoked_at = v_now
    where download_grant.data_export_id = v_export.id
      and download_grant.consumed_at is null
      and download_grant.revoked_at is null;
    update app_private.data_export_purge_jobs as job
    set processing_status = case
          when job.processing_status in ('queued', 'retry_wait') then 'queued'
          else job.processing_status
        end,
        attempts = case
          when job.processing_status = 'retry_wait' then 0
          else job.attempts
        end,
        next_attempt_at = case
          when job.processing_status in ('queued', 'retry_wait') then v_now
          else job.next_attempt_at
        end,
        last_error_code = case
          when job.processing_status in ('queued', 'retry_wait') then null
          else job.last_error_code
        end
    where job.data_export_id = v_export.id;
    insert into app_private.data_export_events (
      privacy_request_id, data_export_id, transition, request_status,
      request_version, correlation_id, occurred_at
    ) values (
      v_request.id, v_export.id, 'revoked', v_request.status,
      v_request.version, p_correlation_id, v_now
    );
  end if;

  insert into app_private.data_export_command_requests (
    auth_user_id, idempotency_key, operation, request_hash,
    privacy_request_id, result_request_version, result_artifact_version,
    created_at
  ) values (
    p_authenticated_user_id, p_idempotency_key, 'revoke', v_hash,
    p_request_id, v_request.version, v_export.version, v_now
  );

  return query select *
  from public.get_data_export_request(p_authenticated_user_id, p_request_id);
end;
$$;

create or replace function public.create_data_export_download_grant(
  p_authenticated_user_id uuid,
  p_request_id uuid,
  p_export_format text,
  p_token_hash_base64 text,
  p_correlation_id uuid
)
returns table (
  grant_id uuid,
  export_format text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_config app_private.privacy_runtime_config%rowtype;
  v_request public.privacy_requests%rowtype;
  v_export public.data_exports%rowtype;
  v_grant app_private.data_export_download_grants%rowtype;
  v_hash bytea;
  v_now timestamptz := pg_catalog.clock_timestamp();
begin
  if p_authenticated_user_id is null or p_request_id is null
    or p_export_format not in ('json', 'text')
    or p_token_hash_base64 is null
    or p_token_hash_base64 !~ '^[A-Za-z0-9+/]{43}=$'
    or p_correlation_id is null then
    raise exception using errcode = 'KFX02', message = 'invalid download grant';
  end if;
  v_hash := pg_catalog.decode(p_token_hash_base64, 'base64');
  if pg_catalog.octet_length(v_hash) <> 32 then
    raise exception using errcode = 'KFX02', message = 'invalid download grant hash';
  end if;

  perform app_private.data_export_request_lock(p_authenticated_user_id);
  if not exists (
    select 1 from public.profiles as profile
    where profile.auth_user_id = p_authenticated_user_id
      and profile.deleted_at is null
  ) then
    raise exception using errcode = 'KFX01', message = 'active account required';
  end if;
  select config.* into v_config
  from app_private.privacy_runtime_config as config
  where config.singleton
  for share;
  if not v_config.data_export_downloads_enabled then
    raise exception using errcode = 'KFX10', message = 'export downloads paused';
  end if;

  select request.* into v_request
  from public.privacy_requests as request
  where request.id = p_request_id
    and request.auth_user_id = p_authenticated_user_id
    and request.request_type = 'export'
    and request.status = 'completed'
  for update;
  if not found then
    raise exception using errcode = 'KFX11', message = 'export artifact unavailable';
  end if;
  select export.* into v_export
  from public.data_exports as export
  where export.privacy_request_id = p_request_id
  for update;
  if not found
    or v_export.machine_object_key is null
    or v_export.human_object_key is null
    or v_export.artifact_expires_at <= v_now
    or v_export.revoked_at is not null
    or v_export.purged_at is not null then
    raise exception using errcode = 'KFX11', message = 'export artifact unavailable';
  end if;

  update app_private.data_export_download_grants as download_grant
  set revoked_at = v_now
  where download_grant.data_export_id = v_export.id
    and download_grant.export_format = p_export_format
    and download_grant.consumed_at is null
    and download_grant.revoked_at is null;
  insert into app_private.data_export_download_grants (
    data_export_id,
    token_hash,
    export_format,
    correlation_id,
    issued_at,
    expires_at
  ) values (
    v_export.id,
    v_hash,
    p_export_format,
    p_correlation_id,
    v_now,
    v_now + pg_catalog.make_interval(
      secs => v_config.data_export_download_grant_ttl_seconds
    )
  ) returning * into v_grant;

  insert into app_private.data_export_events (
    privacy_request_id, data_export_id, transition, request_status,
    request_version, correlation_id, safe_metadata, occurred_at
  ) values (
    v_request.id, v_export.id, 'download_grant_issued', v_request.status,
    v_request.version, p_correlation_id,
    pg_catalog.jsonb_build_object(
      'format', p_export_format,
      'grantTtlSeconds', v_config.data_export_download_grant_ttl_seconds
    ),
    v_now
  );

  return query select
    v_grant.id,
    p_export_format,
    v_grant.expires_at;
end;
$$;

create or replace function public.consume_data_export_download_grant(
  p_token_hash_base64 text,
  p_as_of timestamptz
)
returns table (
  export_format text,
  object_key text,
  file_name text,
  content_type text,
  checksum_sha256 text,
  size_bytes bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_config app_private.privacy_runtime_config%rowtype;
  v_grant app_private.data_export_download_grants%rowtype;
  v_export public.data_exports%rowtype;
  v_request public.privacy_requests%rowtype;
  v_hash bytea;
begin
  if p_token_hash_base64 is null
    or p_token_hash_base64 !~ '^[A-Za-z0-9+/]{43}=$'
    or p_as_of is null then
    raise exception using errcode = 'KFX12', message = 'download grant invalid';
  end if;
  v_hash := pg_catalog.decode(p_token_hash_base64, 'base64');
  if pg_catalog.octet_length(v_hash) <> 32 then
    raise exception using errcode = 'KFX12', message = 'download grant invalid';
  end if;

  select config.* into v_config
  from app_private.privacy_runtime_config as config
  where config.singleton;
  if not v_config.data_export_downloads_enabled then
    raise exception using errcode = 'KFX10', message = 'export downloads paused';
  end if;
  select download_grant.* into v_grant
  from app_private.data_export_download_grants as download_grant
  where download_grant.token_hash = v_hash
  for update;
  if not found
    or v_grant.consumed_at is not null
    or v_grant.revoked_at is not null
    or v_grant.expires_at <= p_as_of then
    raise exception using errcode = 'KFX12', message = 'download grant invalid';
  end if;

  select export.* into v_export
  from public.data_exports as export
  where export.id = v_grant.data_export_id
  for update;
  select request.* into v_request
  from public.privacy_requests as request
  where request.id = v_export.privacy_request_id;
  if v_request.status <> 'completed'
    or v_export.artifact_expires_at <= p_as_of
    or v_export.revoked_at is not null
    or v_export.purged_at is not null
    or not exists (
      select 1 from public.profiles as profile
      where profile.auth_user_id = v_request.auth_user_id
        and profile.deleted_at is null
    ) then
    raise exception using errcode = 'KFX12', message = 'download grant invalid';
  end if;

  update app_private.data_export_download_grants as download_grant
  set consumed_at = p_as_of
  where download_grant.id = v_grant.id;
  insert into app_private.data_export_events (
    privacy_request_id, data_export_id, transition, request_status,
    request_version, correlation_id, safe_metadata, occurred_at
  ) values (
    v_request.id, v_export.id, 'download_consumed', v_request.status,
    v_request.version, v_grant.correlation_id,
    pg_catalog.jsonb_build_object('format', v_grant.export_format),
    p_as_of
  );

  return query select
    v_grant.export_format,
    case when v_grant.export_format = 'json'
      then v_export.machine_object_key else v_export.human_object_key end,
    case when v_grant.export_format = 'json'
      then 'kinflow-data.json' else 'kinflow-data.txt' end,
    case when v_grant.export_format = 'json'
      then 'application/json; charset=utf-8'
      else 'text/plain; charset=utf-8' end,
    case when v_grant.export_format = 'json'
      then v_export.machine_checksum_sha256
      else v_export.human_checksum_sha256 end,
    case when v_grant.export_format = 'json'
      then v_export.machine_size_bytes else v_export.human_size_bytes end;
end;
$$;

create or replace function app_private.personal_data_export_payload(
  p_auth_user_id uuid,
  p_as_of timestamptz
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'schemaVersion', '2026-08-08-wp07-02a',
    'generatedAt', p_as_of,
    'scope', pg_catalog.jsonb_build_object(
      'type', 'personal',
      'sharedHouseholdExportIncluded', false,
      'otherMemberProfilesIncluded', false,
      'providerIdentifiersIncluded', false
    ),
    'profile', (
      select pg_catalog.jsonb_build_object(
        'id', profile.id,
        'authUserId', profile.auth_user_id,
        'displayName', profile.display_name,
        'locale', profile.locale,
        'timezone', profile.timezone,
        'avatarKey', profile.avatar_key,
        'createdAt', profile.created_at,
        'updatedAt', profile.updated_at,
        'version', profile.version
      )
      from public.profiles as profile
      where profile.auth_user_id = p_auth_user_id
        and profile.deleted_at is null
    ),
    'memberships', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', member.id,
          'householdId', member.household_id,
          'householdName', household.name,
          'householdTimezone', household.timezone,
          'displayName', member.display_name,
          'role', member.role,
          'avatarKey', member.avatar_key,
          'joinedAt', member.joined_at,
          'createdAt', member.created_at,
          'updatedAt', member.updated_at,
          'version', member.version
        ) order by member.joined_at, member.id
      )
      from public.household_members as member
      join public.households as household
        on household.id = member.household_id
       and household.deleted_at is null
      where member.auth_user_id = p_auth_user_id
        and member.removed_at is null
    ), '[]'::jsonb),
    'authoredChores', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', series.id,
          'householdId', series.household_id,
          'title', series.title,
          'description', series.description,
          'timezone', series.timezone,
          'effectiveLocalDate', revision.effective_local_date,
          'dueLocalTime', revision.due_local_time,
          'recurrenceRule', revision.recurrence_rule,
          'createdAt', series.created_at,
          'updatedAt', series.updated_at,
          'version', series.version,
          'deletedAt', series.deleted_at
        ) order by series.created_at, series.id
      )
      from public.chore_series as series
      join public.chore_series_revisions as revision
        on revision.household_id = series.household_id
       and revision.id = series.active_revision_id
      where series.created_by_user_id = p_auth_user_id
    ), '[]'::jsonb),
    'choreActions', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', action.id,
          'householdId', action.household_id,
          'occurrenceId', action.occurrence_id,
          'seriesId', occurrence.series_id,
          'seriesTitle', series.title,
          'eventType', action.event_type,
          'occurredAt', action.occurred_at,
          'occurrenceVersion', action.occurrence_version,
          'dueLocalDate', occurrence.due_local_date,
          'dueAt', occurrence.due_at,
          'timezone', occurrence.timezone
        ) order by action.occurred_at, action.id
      )
      from public.chore_completion_events as action
      join public.chore_occurrences as occurrence
        on occurrence.household_id = action.household_id
       and occurrence.id = action.occurrence_id
      join public.chore_series as series
        on series.household_id = occurrence.household_id
       and series.id = occurrence.series_id
      where action.actor_user_id = p_auth_user_id
    ), '[]'::jsonb),
    'authoredCalendarEvents', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', series.id,
          'householdId', series.household_id,
          'title', series.title,
          'description', series.description,
          'timezone', series.timezone,
          'isAllDay', series.is_all_day,
          'localStartDate', revision.local_start_date,
          'localStartTime', revision.local_start_time,
          'durationMinutes', revision.duration_minutes,
          'allDayEndDateExclusive', revision.all_day_end_date_exclusive,
          'recurrenceRule', revision.recurrence_rule,
          'createdAt', series.created_at,
          'updatedAt', series.updated_at,
          'version', series.version,
          'deletedAt', series.deleted_at
        ) order by series.created_at, series.id
      )
      from public.event_series as series
      join public.event_series_revisions as revision
        on revision.household_id = series.household_id
       and revision.series_id = series.id
       and revision.id = series.active_revision_id
      where series.created_by_user_id = p_auth_user_id
    ), '[]'::jsonb),
    'calendarParticipation', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'seriesId', participant.series_id,
          'householdId', participant.household_id,
          'title', series.title,
          'description', series.description,
          'timezone', series.timezone,
          'isAllDay', series.is_all_day,
          'localStartDate', revision.local_start_date,
          'localStartTime', revision.local_start_time,
          'durationMinutes', revision.duration_minutes,
          'allDayEndDateExclusive', revision.all_day_end_date_exclusive,
          'recurrenceRule', revision.recurrence_rule,
          'participationRecordedAt', participant.created_at
        ) order by participant.created_at, participant.series_id
      )
      from public.event_participants as participant
      join public.household_members as member
        on member.household_id = participant.household_id
       and member.id = participant.member_id
       and member.auth_user_id = p_auth_user_id
       and member.removed_at is null
      join public.households as household
        on household.id = participant.household_id
       and household.deleted_at is null
      join public.event_series as series
        on series.household_id = participant.household_id
       and series.id = participant.series_id
       and series.deleted_at is null
      join public.event_series_revisions as revision
        on revision.household_id = series.household_id
       and revision.series_id = series.id
       and revision.id = series.active_revision_id
    ), '[]'::jsonb),
    'notificationPreferences', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'householdId', preference.household_id,
          'category', preference.category,
          'nativePush', preference.native_push,
          'webPush', preference.web_push,
          'email', preference.email,
          'inApp', preference.in_app,
          'quietStart', preference.quiet_start,
          'quietEnd', preference.quiet_end,
          'timezone', preference.timezone,
          'updatedAt', preference.updated_at,
          'version', preference.version
        ) order by preference.household_id, preference.category
      )
      from public.notification_preferences as preference
      where preference.auth_user_id = p_auth_user_id
    ), '[]'::jsonb),
    'notificationInbox', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', inbox.id,
          'householdId', inbox.household_id,
          'category', inbox.category,
          'subjectType', inbox.subject_type,
          'subjectId', inbox.subject_id,
          'scheduledAt', inbox.scheduled_at,
          'createdAt', inbox.created_at,
          'updatedAt', inbox.updated_at,
          'readAt', inbox.read_at,
          'cancelledAt', inbox.cancelled_at,
          'cancellationReason', inbox.cancellation_reason,
          'version', inbox.item_version
        ) order by inbox.created_at, inbox.id
      )
      from public.notification_inbox_items as inbox
      where inbox.recipient_user_id = p_auth_user_id
    ), '[]'::jsonb),
    'billingSummary', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'assignmentId', assignment.id,
          'householdId', assignment.household_id,
          'householdName', household.name,
          'assignmentStatus', assignment.status,
          'assignedAt', assignment.assigned_at,
          'endedAt', assignment.ended_at,
          'planCode', entitlement.plan_code,
          'entitlementStatus', entitlement.status,
          'source', entitlement.source,
          'currentPeriodStart', entitlement.current_period_start,
          'currentPeriodEnd', entitlement.current_period_end,
          'willRenew', entitlement.will_renew,
          'features', entitlement.features,
          'verifiedAt', entitlement.verified_at
        ) order by assignment.assigned_at, assignment.id
      )
      from public.billing_household_assignments as assignment
      join public.households as household
        on household.id = assignment.household_id
      left join public.household_entitlements as entitlement
        on entitlement.household_id = assignment.household_id
      where assignment.billing_owner_user_id = p_auth_user_id
    ), '[]'::jsonb),
    'privacyRequests', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', request.id,
          'type', request.request_type,
          'status', request.status,
          'requestedAt', request.requested_at,
          'verifiedAt', request.verified_at,
          'scheduledFor', request.scheduled_for,
          'processingStartedAt', request.processing_started_at,
          'completedAt', request.completed_at,
          'failedAt', request.failed_at,
          'cancelledAt', request.cancelled_at,
          'failureCode', request.failure_code,
          'activeSubscriptionAtRequest',
            request.active_subscription_at_request,
          'subscriptionAcknowledged', request.subscription_acknowledged,
          'version', request.version
        ) order by request.requested_at, request.id
      )
      from public.privacy_requests as request
      where request.auth_user_id = p_auth_user_id
    ), '[]'::jsonb)
  )
$$;

revoke all on function app_private.personal_data_export_payload(uuid, timestamptz)
  from public, anon, authenticated, service_role;

create or replace function public.recover_expired_data_export_generation_leases(
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
  v_job app_private.data_export_jobs%rowtype;
  v_request public.privacy_requests%rowtype;
  v_retry_count integer := 0;
  v_dead_count integer := 0;
begin
  if p_as_of is null then
    raise exception using errcode = 'KFX02', message = 'invalid export recovery time';
  end if;
  for v_job in
    select job.*
    from app_private.data_export_jobs as job
    where job.processing_status = 'leased'
      and job.lease_expires_at <= p_as_of
    order by job.lease_expires_at, job.privacy_request_id
    for update skip locked
  loop
    if v_job.attempts < v_job.max_attempts then
      update app_private.data_export_jobs as job
      set processing_status = 'retry_wait',
          next_attempt_at = p_as_of,
          lease_owner = null,
          lease_token = null,
          lease_expires_at = null,
          last_error_code = 'EXPORT_BUILD_UNAVAILABLE'
      where job.privacy_request_id = v_job.privacy_request_id;
      update public.privacy_requests as request
      set failure_code = 'EXPORT_BUILD_UNAVAILABLE'
      where request.id = v_job.privacy_request_id
      returning request.* into v_request;
      insert into app_private.data_export_events (
        privacy_request_id, data_export_id, transition, request_status,
        request_version, correlation_id, safe_metadata, occurred_at
      ) values (
        v_request.id, v_job.data_export_id, 'retry_scheduled',
        v_request.status, v_request.version, v_job.lease_token,
        pg_catalog.jsonb_build_object(
          'reasonCode', 'LEASE_EXPIRED', 'attempts', v_job.attempts
        ), p_as_of
      );
      v_retry_count := v_retry_count + 1;
    else
      update app_private.data_export_jobs as job
      set processing_status = 'dead_letter',
          next_attempt_at = null,
          lease_owner = null,
          lease_token = null,
          lease_expires_at = null,
          last_error_code = 'EXPORT_ATTEMPTS_EXHAUSTED'
      where job.privacy_request_id = v_job.privacy_request_id;
      update public.privacy_requests as request
      set status = 'failed', failed_at = p_as_of,
          failure_code = 'EXPORT_ATTEMPTS_EXHAUSTED'
      where request.id = v_job.privacy_request_id
      returning request.* into v_request;
      insert into app_private.data_export_events (
        privacy_request_id, data_export_id, transition, request_status,
        request_version, correlation_id, safe_metadata, occurred_at
      ) values (
        v_request.id, v_job.data_export_id, 'failed', v_request.status,
        v_request.version, v_job.lease_token,
        pg_catalog.jsonb_build_object(
          'reasonCode', 'EXPORT_ATTEMPTS_EXHAUSTED',
          'attempts', v_job.attempts
        ), p_as_of
      );
      v_dead_count := v_dead_count + 1;
    end if;
  end loop;
  return query select v_retry_count, v_dead_count;
end;
$$;

create or replace function public.claim_data_export_requests(
  p_worker_id uuid,
  p_limit integer,
  p_lease_seconds integer,
  p_as_of timestamptz
)
returns table (
  privacy_request_id uuid,
  data_export_id uuid,
  auth_user_id uuid,
  artifact_prefix uuid,
  lease_token uuid,
  request_version bigint,
  attempts integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.data_export_jobs%rowtype;
  v_request public.privacy_requests%rowtype;
  v_token uuid;
begin
  if p_worker_id is null or p_limit not between 1 and 25
    or p_lease_seconds not between 30 and 300 or p_as_of is null then
    raise exception using errcode = 'KFX02', message = 'invalid export claim request';
  end if;
  for v_job in
    select job.*
    from app_private.data_export_jobs as job
    join public.privacy_requests as request
      on request.id = job.privacy_request_id
    where job.processing_status in ('queued', 'retry_wait')
      and job.next_attempt_at <= p_as_of
      and request.status in ('queued', 'processing')
    order by job.next_attempt_at, job.privacy_request_id
    limit p_limit
    for update of job skip locked
  loop
    v_token := extensions.gen_random_uuid();
    update app_private.data_export_jobs as job
    set processing_status = 'leased', attempts = job.attempts + 1,
        next_attempt_at = null, lease_owner = p_worker_id,
        lease_token = v_token,
        lease_expires_at = p_as_of + pg_catalog.make_interval(
          secs => p_lease_seconds
        ), last_error_code = null
    where job.privacy_request_id = v_job.privacy_request_id
    returning job.* into v_job;
    update public.privacy_requests as request
    set status = 'processing',
        processing_started_at = coalesce(request.processing_started_at, p_as_of),
        failure_code = null
    where request.id = v_job.privacy_request_id
    returning request.* into v_request;
    insert into app_private.data_export_events (
      privacy_request_id, data_export_id, transition, request_status,
      request_version, correlation_id, safe_metadata, occurred_at
    ) values (
      v_request.id, v_job.data_export_id, 'claimed', v_request.status,
      v_request.version, v_token,
      pg_catalog.jsonb_build_object('attempts', v_job.attempts), p_as_of
    );
    privacy_request_id := v_request.id;
    data_export_id := v_job.data_export_id;
    auth_user_id := v_request.auth_user_id;
    artifact_prefix := v_job.artifact_prefix;
    lease_token := v_token;
    request_version := v_request.version;
    attempts := v_job.attempts;
    return next;
  end loop;
end;
$$;

create or replace function public.build_personal_data_export_package(
  p_request_id uuid,
  p_lease_token uuid,
  p_as_of timestamptz
)
returns table (
  auth_user_id uuid,
  artifact_prefix uuid,
  schema_version text,
  payload jsonb
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.data_export_jobs%rowtype;
  v_request public.privacy_requests%rowtype;
  v_payload jsonb;
begin
  if p_request_id is null or p_lease_token is null or p_as_of is null then
    raise exception using errcode = 'KFX02', message = 'invalid export build request';
  end if;
  select job.* into v_job
  from app_private.data_export_jobs as job
  where job.privacy_request_id = p_request_id
  for update;
  if not found or v_job.processing_status <> 'leased'
    or v_job.lease_token <> p_lease_token
    or v_job.lease_expires_at <= p_as_of then
    raise exception using errcode = 'KFX13', message = 'export lease conflict';
  end if;
  select request.* into v_request
  from public.privacy_requests as request
  where request.id = p_request_id and request.request_type = 'export'
    and request.status = 'processing'
  for update;
  if not found or not exists (
    select 1 from public.profiles as profile
    where profile.auth_user_id = v_request.auth_user_id
      and profile.deleted_at is null
  ) then
    raise exception using
      errcode = 'KFX15', message = 'export processing precondition failed';
  end if;
  v_payload := app_private.personal_data_export_payload(
    v_request.auth_user_id, p_as_of
  );
  if v_payload->'profile' is null
    or pg_catalog.octet_length(
      pg_catalog.convert_to(v_payload::text, 'UTF8')
    ) > 8388608 then
    raise exception using errcode = 'KFX14', message = 'export size limit exceeded';
  end if;
  return query select
    v_request.auth_user_id, v_job.artifact_prefix,
    '2026-08-08-wp07-02a'::text, v_payload;
end;
$$;

create or replace function public.complete_data_export_request(
  p_request_id uuid,
  p_lease_token uuid,
  p_machine_object_key text,
  p_machine_checksum_sha256 text,
  p_machine_size_bytes bigint,
  p_human_object_key text,
  p_human_checksum_sha256 text,
  p_human_size_bytes bigint,
  p_as_of timestamptz
)
returns table (
  request_id uuid,
  status text,
  artifact_expires_at timestamptz,
  request_version bigint,
  artifact_version bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_config app_private.privacy_runtime_config%rowtype;
  v_job app_private.data_export_jobs%rowtype;
  v_request public.privacy_requests%rowtype;
  v_export public.data_exports%rowtype;
  v_expected_prefix text;
begin
  if p_request_id is null or p_lease_token is null or p_as_of is null
    or p_machine_checksum_sha256 !~ '^[0-9a-f]{64}$'
    or p_human_checksum_sha256 !~ '^[0-9a-f]{64}$'
    or p_machine_size_bytes not between 1 and 10485760
    or p_human_size_bytes not between 1 and 10485760 then
    raise exception using errcode = 'KFX02', message = 'invalid export completion';
  end if;
  select job.* into v_job
  from app_private.data_export_jobs as job
  where job.privacy_request_id = p_request_id
  for update;
  if not found or v_job.processing_status <> 'leased'
    or v_job.lease_token <> p_lease_token
    or v_job.lease_expires_at <= p_as_of then
    raise exception using errcode = 'KFX13', message = 'export lease conflict';
  end if;
  v_expected_prefix := 'exports/' || v_job.artifact_prefix::text || '/';
  if p_machine_object_key <> v_expected_prefix || 'kinflow-data.json'
    or p_human_object_key <> v_expected_prefix || 'kinflow-data.txt' then
    raise exception using errcode = 'KFX02', message = 'invalid export object key';
  end if;
  select config.* into v_config
  from app_private.privacy_runtime_config as config
  where config.singleton;
  update public.data_exports as export
  set machine_object_key = p_machine_object_key,
      human_object_key = p_human_object_key,
      machine_checksum_sha256 = p_machine_checksum_sha256,
      human_checksum_sha256 = p_human_checksum_sha256,
      machine_size_bytes = p_machine_size_bytes,
      human_size_bytes = p_human_size_bytes,
      artifact_expires_at = p_as_of + pg_catalog.make_interval(
        secs => v_config.data_export_artifact_ttl_seconds
      )
  where export.id = v_job.data_export_id
    and export.machine_object_key is null
  returning export.* into v_export;
  if not found then
    raise exception using
      errcode = 'KFX15', message = 'export completion precondition failed';
  end if;
  update public.privacy_requests as request
  set status = 'completed', completed_at = p_as_of, failure_code = null
  where request.id = p_request_id
    and request.request_type = 'export' and request.status = 'processing'
  returning request.* into v_request;
  if not found then
    raise exception using
      errcode = 'KFX15', message = 'export completion precondition failed';
  end if;
  update app_private.data_export_jobs as job
  set processing_status = 'succeeded', next_attempt_at = null,
      lease_owner = null, lease_token = null, lease_expires_at = null,
      last_error_code = null
  where job.privacy_request_id = p_request_id;
  insert into app_private.data_export_purge_jobs (
    data_export_id, processing_status, next_attempt_at, created_at, updated_at
  ) values (
    v_export.id, 'queued', v_export.artifact_expires_at, p_as_of, p_as_of
  );
  insert into app_private.data_export_events (
    privacy_request_id, data_export_id, transition, request_status,
    request_version, correlation_id, safe_metadata, occurred_at
  ) values (
    v_request.id, v_export.id, 'completed', v_request.status,
    v_request.version, p_lease_token,
    pg_catalog.jsonb_build_object(
      'artifactTtlSeconds', v_config.data_export_artifact_ttl_seconds,
      'machineSizeBytes', p_machine_size_bytes,
      'humanSizeBytes', p_human_size_bytes
    ), p_as_of
  );
  return query select v_request.id, v_request.status::text,
    v_export.artifact_expires_at, v_request.version, v_export.version;
end;
$$;

create or replace function public.fail_data_export_request(
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
  v_job app_private.data_export_jobs%rowtype;
  v_request public.privacy_requests%rowtype;
  v_code text;
  v_next timestamptz;
begin
  if p_request_id is null or p_lease_token is null
    or p_error_code not in (
      'EXPORT_BUILD_UNAVAILABLE', 'EXPORT_UPLOAD_UNAVAILABLE',
      'EXPORT_SIZE_LIMIT_EXCEEDED', 'PROCESSING_PRECONDITION_FAILED'
    ) or p_retryable is null or p_as_of is null then
    raise exception using errcode = 'KFX02', message = 'invalid export failure';
  end if;
  select job.* into v_job
  from app_private.data_export_jobs as job
  where job.privacy_request_id = p_request_id
  for update;
  if not found or v_job.processing_status <> 'leased'
    or v_job.lease_token <> p_lease_token
    or v_job.lease_expires_at <= p_as_of then
    raise exception using errcode = 'KFX13', message = 'export lease conflict';
  end if;
  if p_retryable and v_job.attempts < v_job.max_attempts then
    v_code := p_error_code;
    v_next := p_as_of + pg_catalog.make_interval(
      secs => least(3600, 60 * (2 ^ (v_job.attempts - 1))::integer)
    );
    update app_private.data_export_jobs as job
    set processing_status = 'retry_wait', next_attempt_at = v_next,
        lease_owner = null, lease_token = null, lease_expires_at = null,
        last_error_code = v_code
    where job.privacy_request_id = p_request_id;
    update public.privacy_requests as request
    set failure_code = v_code
    where request.id = p_request_id
    returning request.* into v_request;
    insert into app_private.data_export_events (
      privacy_request_id, data_export_id, transition, request_status,
      request_version, correlation_id, safe_metadata, occurred_at
    ) values (
      v_request.id, v_job.data_export_id, 'retry_scheduled',
      v_request.status, v_request.version, p_lease_token,
      pg_catalog.jsonb_build_object(
        'reasonCode', v_code, 'attempts', v_job.attempts
      ), p_as_of
    );
  else
    v_code := case when p_retryable
      then 'EXPORT_ATTEMPTS_EXHAUSTED' else p_error_code end;
    v_next := null;
    update app_private.data_export_jobs as job
    set processing_status = 'dead_letter', next_attempt_at = null,
        lease_owner = null, lease_token = null, lease_expires_at = null,
        last_error_code = v_code
    where job.privacy_request_id = p_request_id;
    update public.privacy_requests as request
    set status = 'failed', failed_at = p_as_of, failure_code = v_code
    where request.id = p_request_id
    returning request.* into v_request;
    insert into app_private.data_export_events (
      privacy_request_id, data_export_id, transition, request_status,
      request_version, correlation_id, safe_metadata, occurred_at
    ) values (
      v_request.id, v_job.data_export_id, 'failed', v_request.status,
      v_request.version, p_lease_token,
      pg_catalog.jsonb_build_object(
        'reasonCode', v_code, 'attempts', v_job.attempts
      ), p_as_of
    );
  end if;
  return query select v_request.id, v_request.status::text,
    v_request.failure_code, v_next, v_request.version;
end;
$$;

create or replace function public.recover_expired_data_export_purge_leases(
  p_as_of timestamptz
)
returns table (retry_scheduled integer, dead_letter integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.data_export_purge_jobs%rowtype;
  v_export public.data_exports%rowtype;
  v_request public.privacy_requests%rowtype;
  v_retry_count integer := 0;
  v_dead_count integer := 0;
begin
  if p_as_of is null then
    raise exception using errcode = 'KFX02', message = 'invalid purge recovery time';
  end if;
  for v_job in
    select job.* from app_private.data_export_purge_jobs as job
    where job.processing_status = 'leased' and job.lease_expires_at <= p_as_of
    order by job.lease_expires_at, job.data_export_id
    for update skip locked
  loop
    select export.* into v_export from public.data_exports as export
    where export.id = v_job.data_export_id;
    select request.* into v_request from public.privacy_requests as request
    where request.id = v_export.privacy_request_id;
    if v_job.attempts < v_job.max_attempts then
      update app_private.data_export_purge_jobs as job
      set processing_status = 'retry_wait', next_attempt_at = p_as_of,
          lease_owner = null, lease_token = null, lease_expires_at = null,
          last_error_code = 'EXPORT_PURGE_UNAVAILABLE'
      where job.data_export_id = v_job.data_export_id;
      insert into app_private.data_export_events (
        privacy_request_id, data_export_id, transition, request_status,
        request_version, correlation_id, safe_metadata, occurred_at
      ) values (
        v_request.id, v_export.id, 'purge_retry_scheduled', v_request.status,
        v_request.version, v_job.lease_token,
        pg_catalog.jsonb_build_object(
          'reasonCode', 'LEASE_EXPIRED', 'attempts', v_job.attempts
        ), p_as_of
      );
      v_retry_count := v_retry_count + 1;
    else
      update app_private.data_export_purge_jobs as job
      set processing_status = 'dead_letter',
          lease_owner = null, lease_token = null, lease_expires_at = null,
          last_error_code = 'EXPORT_PURGE_ATTEMPTS_EXHAUSTED'
      where job.data_export_id = v_job.data_export_id;
      insert into app_private.data_export_events (
        privacy_request_id, data_export_id, transition, request_status,
        request_version, correlation_id, safe_metadata, occurred_at
      ) values (
        v_request.id, v_export.id, 'purge_failed', v_request.status,
        v_request.version, v_job.lease_token,
        pg_catalog.jsonb_build_object(
          'reasonCode', 'EXPORT_PURGE_ATTEMPTS_EXHAUSTED',
          'attempts', v_job.attempts
        ), p_as_of
      );
      v_dead_count := v_dead_count + 1;
    end if;
  end loop;
  return query select v_retry_count, v_dead_count;
end;
$$;

create or replace function public.claim_data_export_purges(
  p_worker_id uuid,
  p_limit integer,
  p_lease_seconds integer,
  p_as_of timestamptz
)
returns table (
  data_export_id uuid,
  privacy_request_id uuid,
  machine_object_key text,
  human_object_key text,
  lease_token uuid,
  attempts integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.data_export_purge_jobs%rowtype;
  v_export public.data_exports%rowtype;
  v_request public.privacy_requests%rowtype;
  v_token uuid;
begin
  if p_worker_id is null or p_limit not between 1 and 25
    or p_lease_seconds not between 30 and 300 or p_as_of is null then
    raise exception using errcode = 'KFX02', message = 'invalid purge claim request';
  end if;
  for v_job in
    select job.* from app_private.data_export_purge_jobs as job
    join public.data_exports as export on export.id = job.data_export_id
    where job.processing_status in ('queued', 'retry_wait')
      and job.next_attempt_at <= p_as_of
      and export.purged_at is null
    order by job.next_attempt_at, job.data_export_id
    limit p_limit for update of job skip locked
  loop
    v_token := extensions.gen_random_uuid();
    update app_private.data_export_purge_jobs as job
    set processing_status = 'leased', attempts = job.attempts + 1,
        lease_owner = p_worker_id, lease_token = v_token,
        lease_expires_at = p_as_of + pg_catalog.make_interval(
          secs => p_lease_seconds
        ), last_error_code = null
    where job.data_export_id = v_job.data_export_id
    returning job.* into v_job;
    select export.* into v_export from public.data_exports as export
    where export.id = v_job.data_export_id for update;
    select request.* into v_request from public.privacy_requests as request
    where request.id = v_export.privacy_request_id;
    update app_private.data_export_download_grants as download_grant
    set revoked_at = p_as_of
    where download_grant.data_export_id = v_export.id
      and download_grant.consumed_at is null
      and download_grant.revoked_at is null;
    insert into app_private.data_export_events (
      privacy_request_id, data_export_id, transition, request_status,
      request_version, correlation_id, safe_metadata, occurred_at
    ) values (
      v_request.id, v_export.id, 'purge_claimed', v_request.status,
      v_request.version, v_token,
      pg_catalog.jsonb_build_object('attempts', v_job.attempts), p_as_of
    );
    data_export_id := v_export.id;
    privacy_request_id := v_request.id;
    machine_object_key := v_export.machine_object_key;
    human_object_key := v_export.human_object_key;
    lease_token := v_token;
    attempts := v_job.attempts;
    return next;
  end loop;
end;
$$;

create or replace function public.complete_data_export_purge(
  p_data_export_id uuid,
  p_lease_token uuid,
  p_as_of timestamptz
)
returns table (data_export_id uuid, purged_at timestamptz, artifact_version bigint)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.data_export_purge_jobs%rowtype;
  v_export public.data_exports%rowtype;
  v_request public.privacy_requests%rowtype;
begin
  if p_data_export_id is null or p_lease_token is null or p_as_of is null then
    raise exception using errcode = 'KFX02', message = 'invalid purge completion';
  end if;
  select job.* into v_job from app_private.data_export_purge_jobs as job
  where job.data_export_id = p_data_export_id for update;
  if not found or v_job.processing_status <> 'leased'
    or v_job.lease_token <> p_lease_token
    or v_job.lease_expires_at <= p_as_of then
    raise exception using errcode = 'KFX13', message = 'purge lease conflict';
  end if;
  update public.data_exports as export
  set machine_object_key = null, human_object_key = null, purged_at = p_as_of
  where export.id = p_data_export_id and export.purged_at is null
  returning export.* into v_export;
  if not found then
    raise exception using
      errcode = 'KFX15', message = 'purge completion precondition failed';
  end if;
  select request.* into v_request from public.privacy_requests as request
  where request.id = v_export.privacy_request_id;
  update app_private.data_export_purge_jobs as job
  set processing_status = 'succeeded', lease_owner = null,
      lease_token = null, lease_expires_at = null, last_error_code = null
  where job.data_export_id = p_data_export_id;
  insert into app_private.data_export_events (
    privacy_request_id, data_export_id, transition, request_status,
    request_version, correlation_id, occurred_at
  ) values (
    v_request.id, v_export.id, 'purged', v_request.status,
    v_request.version, p_lease_token, p_as_of
  );
  return query select v_export.id, v_export.purged_at, v_export.version;
end;
$$;

create or replace function public.fail_data_export_purge(
  p_data_export_id uuid,
  p_lease_token uuid,
  p_error_code text,
  p_retryable boolean,
  p_as_of timestamptz
)
returns table (
  data_export_id uuid,
  status text,
  failure_code text,
  next_attempt_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.data_export_purge_jobs%rowtype;
  v_export public.data_exports%rowtype;
  v_request public.privacy_requests%rowtype;
  v_code text;
  v_next timestamptz;
begin
  if p_data_export_id is null or p_lease_token is null
    or p_error_code not in (
      'EXPORT_PURGE_UNAVAILABLE', 'PROCESSING_PRECONDITION_FAILED'
    ) or p_retryable is null or p_as_of is null then
    raise exception using errcode = 'KFX02', message = 'invalid purge failure';
  end if;
  select job.* into v_job from app_private.data_export_purge_jobs as job
  where job.data_export_id = p_data_export_id for update;
  if not found or v_job.processing_status <> 'leased'
    or v_job.lease_token <> p_lease_token
    or v_job.lease_expires_at <= p_as_of then
    raise exception using errcode = 'KFX13', message = 'purge lease conflict';
  end if;
  select export.* into v_export from public.data_exports as export
  where export.id = p_data_export_id;
  select request.* into v_request from public.privacy_requests as request
  where request.id = v_export.privacy_request_id;
  if p_retryable and v_job.attempts < v_job.max_attempts then
    v_code := p_error_code;
    v_next := p_as_of + pg_catalog.make_interval(
      secs => least(3600, 60 * (2 ^ (v_job.attempts - 1))::integer)
    );
    update app_private.data_export_purge_jobs as job
    set processing_status = 'retry_wait', next_attempt_at = v_next,
        lease_owner = null, lease_token = null, lease_expires_at = null,
        last_error_code = v_code
    where job.data_export_id = p_data_export_id;
    insert into app_private.data_export_events (
      privacy_request_id, data_export_id, transition, request_status,
      request_version, correlation_id, safe_metadata, occurred_at
    ) values (
      v_request.id, v_export.id, 'purge_retry_scheduled', v_request.status,
      v_request.version, p_lease_token,
      pg_catalog.jsonb_build_object(
        'reasonCode', v_code, 'attempts', v_job.attempts
      ), p_as_of
    );
    return query select p_data_export_id, 'retry_wait', v_code, v_next;
  else
    v_code := case when p_retryable
      then 'EXPORT_PURGE_ATTEMPTS_EXHAUSTED' else p_error_code end;
    update app_private.data_export_purge_jobs as job
    set processing_status = 'dead_letter', lease_owner = null,
        lease_token = null, lease_expires_at = null,
        last_error_code = v_code
    where job.data_export_id = p_data_export_id;
    insert into app_private.data_export_events (
      privacy_request_id, data_export_id, transition, request_status,
      request_version, correlation_id, safe_metadata, occurred_at
    ) values (
      v_request.id, v_export.id, 'purge_failed', v_request.status,
      v_request.version, p_lease_token,
      pg_catalog.jsonb_build_object(
        'reasonCode', v_code, 'attempts', v_job.attempts
      ), p_as_of
    );
    return query select p_data_export_id, 'dead_letter', v_code, null::timestamptz;
  end if;
end;
$$;

create or replace function app_private.revoke_exports_for_deleted_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.deleted_at is null and new.deleted_at is not null then
    update public.data_exports as export
    set revoked_at = coalesce(export.revoked_at, new.deleted_at)
    from public.privacy_requests as request
    where request.id = export.privacy_request_id
      and request.auth_user_id = new.auth_user_id
      and export.machine_object_key is not null
      and export.purged_at is null;
    update app_private.data_export_download_grants as download_grant
    set revoked_at = coalesce(download_grant.revoked_at, new.deleted_at)
    where download_grant.data_export_id in (
      select export.id
      from public.data_exports as export
      join public.privacy_requests as request
        on request.id = export.privacy_request_id
      where request.auth_user_id = new.auth_user_id
    ) and download_grant.consumed_at is null;
    update app_private.data_export_purge_jobs as job
    set processing_status = 'queued', attempts = 0,
        next_attempt_at = new.deleted_at, lease_owner = null,
        lease_token = null, lease_expires_at = null, last_error_code = null
    where job.data_export_id in (
      select export.id
      from public.data_exports as export
      join public.privacy_requests as request
        on request.id = export.privacy_request_id
      where request.auth_user_id = new.auth_user_id
        and export.machine_object_key is not null
        and export.purged_at is null
    ) and job.processing_status in ('queued', 'retry_wait');
  end if;
  return new;
end;
$$;

revoke all on function app_private.revoke_exports_for_deleted_profile()
  from public, anon, authenticated, service_role;

create trigger profiles_revoke_data_exports_after_delete
after update of deleted_at on public.profiles
for each row execute function app_private.revoke_exports_for_deleted_profile();

revoke all on function public.configure_data_export_runtime(
  boolean, boolean, integer, integer, bigint, uuid
) from public, anon, authenticated, service_role;
revoke all on function public.get_data_export_preflight(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.get_data_export_request(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.request_data_export(uuid, text, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.cancel_data_export(
  uuid, uuid, bigint, text, uuid
) from public, anon, authenticated, service_role;
revoke all on function public.revoke_data_export(
  uuid, uuid, bigint, text, uuid
) from public, anon, authenticated, service_role;
revoke all on function public.create_data_export_download_grant(
  uuid, uuid, text, text, uuid
) from public, anon, authenticated, service_role;
revoke all on function public.consume_data_export_download_grant(
  text, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.recover_expired_data_export_generation_leases(
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.claim_data_export_requests(
  uuid, integer, integer, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.build_personal_data_export_package(
  uuid, uuid, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.complete_data_export_request(
  uuid, uuid, text, text, bigint, text, text, bigint, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.fail_data_export_request(
  uuid, uuid, text, boolean, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.recover_expired_data_export_purge_leases(
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.claim_data_export_purges(
  uuid, integer, integer, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.complete_data_export_purge(
  uuid, uuid, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.fail_data_export_purge(
  uuid, uuid, text, boolean, timestamptz
) from public, anon, authenticated, service_role;

grant execute on function public.configure_data_export_runtime(
  boolean, boolean, integer, integer, bigint, uuid
) to service_role;
grant execute on function public.get_data_export_preflight(uuid)
  to service_role;
grant execute on function public.get_data_export_request(uuid, uuid)
  to service_role;
grant execute on function public.request_data_export(uuid, text, uuid)
  to service_role;
grant execute on function public.cancel_data_export(
  uuid, uuid, bigint, text, uuid
) to service_role;
grant execute on function public.revoke_data_export(
  uuid, uuid, bigint, text, uuid
) to service_role;
grant execute on function public.create_data_export_download_grant(
  uuid, uuid, text, text, uuid
) to service_role;
grant execute on function public.consume_data_export_download_grant(
  text, timestamptz
) to service_role;
grant execute on function public.recover_expired_data_export_generation_leases(
  timestamptz
) to service_role;
grant execute on function public.claim_data_export_requests(
  uuid, integer, integer, timestamptz
) to service_role;
grant execute on function public.build_personal_data_export_package(
  uuid, uuid, timestamptz
) to service_role;
grant execute on function public.complete_data_export_request(
  uuid, uuid, text, text, bigint, text, text, bigint, timestamptz
) to service_role;
grant execute on function public.fail_data_export_request(
  uuid, uuid, text, boolean, timestamptz
) to service_role;
grant execute on function public.recover_expired_data_export_purge_leases(
  timestamptz
) to service_role;
grant execute on function public.claim_data_export_purges(
  uuid, integer, integer, timestamptz
) to service_role;
grant execute on function public.complete_data_export_purge(
  uuid, uuid, timestamptz
) to service_role;
grant execute on function public.fail_data_export_purge(
  uuid, uuid, text, boolean, timestamptz
) to service_role;
