-- KinFlow WP07-02B Owner household export and deletion lifecycle.
--
-- Household export is a distinct Owner-authorized archive and never widens
-- the personal export projection. Household deletion is a delayed background
-- redaction/access-revocation workflow; it does not delete member Auth accounts
-- or cancel a provider subscription. All client commands are mediated by Edge.

alter table app_private.privacy_runtime_config
  add column household_export_requests_enabled boolean not null default true,
  add column household_deletion_requests_enabled boolean not null default true,
  add column household_export_downloads_enabled boolean not null default true,
  add column household_export_artifact_ttl_seconds integer not null default 86400
    check (household_export_artifact_ttl_seconds between 3600 and 604800),
  add column household_export_download_grant_ttl_seconds integer not null default 300
    check (
      household_export_download_grant_ttl_seconds between 60 and 900
    ),
  add column household_deletion_cancellation_window_seconds integer not null default 86400
    check (
      household_deletion_cancellation_window_seconds between 3600 and 604800
    );

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
      'EXPORT_ATTEMPTS_EXHAUSTED',
      'OWNER_AUTHORIZATION_CHANGED',
      'HOUSEHOLD_ALREADY_DELETED',
      'HOUSEHOLD_REDACTION_UNAVAILABLE',
      'HOUSEHOLD_REDACTION_ATTEMPTS_EXHAUSTED'
    )
  );

alter table public.privacy_requests
  drop constraint privacy_request_account_shape_ck;
alter table public.privacy_requests
  add constraint privacy_request_scope_shape_ck check (
    (
      request_type in ('export', 'delete_account')
      and household_id is null
    )
    or (
      request_type in ('export_household', 'delete_household')
      and household_id is not null
    )
  );

create unique index privacy_pending_household_request_uq
  on public.privacy_requests(household_id)
  where household_id is not null
    and request_type in ('export_household', 'delete_household')
    and status in ('queued', 'verifying', 'processing');

create unique index privacy_pending_user_any_type_uq
  on public.privacy_requests(auth_user_id)
  where status in ('queued', 'verifying', 'processing');

create table public.household_exports (
  id uuid primary key default extensions.gen_random_uuid(),
  privacy_request_id uuid not null unique
    references public.privacy_requests(id) on delete restrict,
  household_id uuid not null references public.households(id) on delete restrict,
  schema_version text not null default '2026-08-08-wp07-02b' check (
    schema_version = '2026-08-08-wp07-02b'
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
    or machine_size_bytes between 1 and 20971520
  ),
  human_size_bytes bigint check (
    human_size_bytes is null
    or human_size_bytes between 1 and 20971520
  ),
  artifact_expires_at timestamptz,
  revoked_at timestamptz,
  purged_at timestamptz,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  version bigint not null default 1 check (version > 0),
  constraint household_export_artifact_shape_ck check (
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
  constraint household_export_artifact_time_ck check (
    updated_at >= created_at
    and (artifact_expires_at is null or artifact_expires_at > created_at)
    and (revoked_at is null or revoked_at >= created_at)
    and (purged_at is null or purged_at >= created_at)
  ),
  constraint household_export_object_key_ck check (
    machine_object_key is null
    or (
      machine_object_key ~
        '^household-exports/[0-9a-f-]{36}/kinflow-household\.json$'
      and human_object_key ~
        '^household-exports/[0-9a-f-]{36}/kinflow-household\.txt$'
    )
  )
);

create table app_private.household_privacy_command_requests (
  auth_user_id uuid not null references auth.users(id) on delete restrict,
  idempotency_key text not null check (
    pg_catalog.char_length(idempotency_key) between 16 and 200
    and idempotency_key = pg_catalog.btrim(idempotency_key)
    and idempotency_key !~ '[[:cntrl:]]'
  ),
  operation text not null check (
    operation in (
      'request_export', 'cancel_export', 'revoke_export',
      'request_deletion', 'cancel_deletion'
    )
  ),
  request_hash bytea not null check (pg_catalog.octet_length(request_hash) = 32),
  privacy_request_id uuid not null
    references public.privacy_requests(id) on delete restrict,
  result_request_version bigint not null check (result_request_version > 0),
  result_artifact_version bigint check (result_artifact_version > 0),
  created_at timestamptz not null default pg_catalog.now(),
  primary key (auth_user_id, idempotency_key)
);

create table app_private.household_export_jobs (
  privacy_request_id uuid primary key
    references public.privacy_requests(id) on delete restrict,
  household_export_id uuid not null unique
    references public.household_exports(id) on delete restrict,
  household_id uuid not null references public.households(id) on delete restrict,
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
      'OWNER_AUTHORIZATION_CHANGED', 'HOUSEHOLD_ALREADY_DELETED',
      'EXPORT_BUILD_UNAVAILABLE', 'EXPORT_UPLOAD_UNAVAILABLE',
      'EXPORT_SIZE_LIMIT_EXCEEDED', 'EXPORT_ATTEMPTS_EXHAUSTED',
      'PROCESSING_PRECONDITION_FAILED'
    )
  ),
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint household_export_job_state_ck check (
    case processing_status
      when 'queued' then
        attempts = 0 and next_attempt_at is not null
        and lease_owner is null and lease_token is null
        and lease_expires_at is null and last_error_code is null
      when 'leased' then
        attempts between 1 and max_attempts and next_attempt_at is null
        and lease_owner is not null and lease_token is not null
        and lease_expires_at is not null and last_error_code is null
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
    and (lease_expires_at is null or lease_expires_at > updated_at)
  )
);

create index household_export_jobs_ready_idx
  on app_private.household_export_jobs(
    processing_status, next_attempt_at, privacy_request_id
  ) where processing_status in ('queued', 'retry_wait');

create table app_private.household_export_download_grants (
  id uuid primary key default extensions.gen_random_uuid(),
  household_export_id uuid not null
    references public.household_exports(id) on delete restrict,
  token_hash bytea not null unique check (pg_catalog.octet_length(token_hash) = 32),
  export_format text not null check (export_format in ('json', 'text')),
  correlation_id uuid not null,
  issued_at timestamptz not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  revoked_at timestamptz,
  constraint household_export_grant_time_ck check (
    expires_at > issued_at
    and (consumed_at is null or consumed_at >= issued_at)
    and (revoked_at is null or revoked_at >= issued_at)
    and not (consumed_at is not null and revoked_at is not null)
  )
);

create index household_export_grants_expiry_idx
  on app_private.household_export_download_grants(expires_at)
  where consumed_at is null and revoked_at is null;

create table app_private.household_export_purge_jobs (
  household_export_id uuid primary key
    references public.household_exports(id) on delete restrict,
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
    last_error_code is null
    or last_error_code in (
      'EXPORT_PURGE_UNAVAILABLE', 'EXPORT_PURGE_ATTEMPTS_EXHAUSTED',
      'PROCESSING_PRECONDITION_FAILED'
    )
  ),
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint household_export_purge_job_state_ck check (
    case processing_status
      when 'queued' then
        attempts = 0 and lease_owner is null and lease_token is null
        and lease_expires_at is null and last_error_code is null
      when 'leased' then
        attempts between 1 and max_attempts
        and lease_owner is not null and lease_token is not null
        and lease_expires_at is not null and last_error_code is null
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
    and (lease_expires_at is null or lease_expires_at > updated_at)
  )
);

create index household_export_purge_jobs_ready_idx
  on app_private.household_export_purge_jobs(
    processing_status, next_attempt_at, household_export_id
  ) where processing_status in ('queued', 'retry_wait');

create table app_private.household_deletion_jobs (
  privacy_request_id uuid primary key
    references public.privacy_requests(id) on delete restrict,
  household_id uuid not null references public.households(id) on delete restrict,
  processing_status text not null default 'queued' check (
    processing_status in (
      'queued', 'retention_hold', 'leased', 'retry_wait',
      'succeeded', 'dead_letter', 'cancelled'
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
  access_revoked_at timestamptz,
  redacted_at timestamptz,
  billing_unlinked_at timestamptz,
  last_error_code text check (
    last_error_code is null
    or last_error_code in (
      'OWNER_AUTHORIZATION_CHANGED', 'HOUSEHOLD_ALREADY_DELETED',
      'HOUSEHOLD_REDACTION_UNAVAILABLE',
      'HOUSEHOLD_REDACTION_ATTEMPTS_EXHAUSTED',
      'PROCESSING_PRECONDITION_FAILED'
    )
  ),
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint household_deletion_job_state_ck check (
    case processing_status
      when 'queued' then
        attempts = 0 and next_attempt_at is not null
        and lease_owner is null and lease_token is null
        and lease_expires_at is null and last_error_code is null
      when 'retention_hold' then
        attempts = 0 and next_attempt_at is null
        and lease_owner is null and lease_token is null
        and lease_expires_at is null and last_error_code is null
      when 'leased' then
        attempts between 1 and max_attempts and next_attempt_at is null
        and lease_owner is not null and lease_token is not null
        and lease_expires_at is not null and last_error_code is null
      when 'retry_wait' then
        attempts between 1 and max_attempts - 1 and next_attempt_at is not null
        and lease_owner is null and lease_token is null
        and lease_expires_at is null and last_error_code is not null
      when 'succeeded' then
        attempts between 1 and max_attempts and next_attempt_at is null
        and lease_owner is null and lease_token is null
        and lease_expires_at is null and last_error_code is null
        and access_revoked_at is not null and redacted_at is not null
        and billing_unlinked_at is not null
      when 'dead_letter' then
        attempts between 1 and max_attempts and next_attempt_at is null
        and lease_owner is null and lease_token is null
        and lease_expires_at is null and last_error_code is not null
      when 'cancelled' then
        attempts = 0 and next_attempt_at is null
        and lease_owner is null and lease_token is null
        and lease_expires_at is null and last_error_code is null
    end
    and (
      processing_status = 'succeeded'
      or access_revoked_at is null and redacted_at is null
        and billing_unlinked_at is null
    )
    and (lease_expires_at is null or lease_expires_at > updated_at)
  )
);

create index household_deletion_jobs_ready_idx
  on app_private.household_deletion_jobs(
    processing_status, next_attempt_at, privacy_request_id
  ) where processing_status in ('queued', 'retry_wait');

create table app_private.household_deletion_retention_holds (
  household_id uuid primary key references public.households(id) on delete restrict,
  active boolean not null,
  review_at timestamptz,
  reference_hash bytea check (
    reference_hash is null or pg_catalog.octet_length(reference_hash) = 32
  ),
  correlation_id uuid not null,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  version bigint not null default 1 check (version > 0),
  constraint household_deletion_retention_hold_shape_ck check (
    (active and review_at is not null and reference_hash is not null)
    or (not active and review_at is null and reference_hash is null)
  )
);

create table app_private.household_privacy_events (
  id bigint generated always as identity primary key,
  privacy_request_id uuid not null
    references public.privacy_requests(id) on delete restrict,
  household_id uuid not null,
  household_export_id uuid references public.household_exports(id) on delete restrict,
  transition text not null check (
    transition in (
      'export_requested', 'export_cancelled', 'export_claimed',
      'export_retry_scheduled', 'export_completed', 'export_failed',
      'download_grant_issued', 'download_consumed', 'export_revoked',
      'purge_claimed', 'purge_retry_scheduled', 'purged', 'purge_failed',
      'deletion_requested', 'deletion_cancelled', 'retention_hold_applied',
      'retention_hold_released', 'deletion_claimed',
      'deletion_retry_scheduled', 'deletion_completed', 'deletion_failed'
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

create index household_privacy_events_request_idx
  on app_private.household_privacy_events(
    privacy_request_id, occurred_at, id
  );

create table app_private.household_privacy_runtime_events (
  id bigint generated always as identity primary key,
  previous_export_requests_enabled boolean not null,
  next_export_requests_enabled boolean not null,
  previous_deletion_requests_enabled boolean not null,
  next_deletion_requests_enabled boolean not null,
  previous_downloads_enabled boolean not null,
  next_downloads_enabled boolean not null,
  previous_artifact_ttl_seconds integer not null,
  next_artifact_ttl_seconds integer not null,
  previous_grant_ttl_seconds integer not null,
  next_grant_ttl_seconds integer not null,
  previous_cancellation_window_seconds integer not null,
  next_cancellation_window_seconds integer not null,
  previous_version bigint not null check (previous_version > 0),
  next_version bigint not null check (next_version = previous_version + 1),
  correlation_id uuid not null,
  occurred_at timestamptz not null default pg_catalog.now()
);

revoke all on table public.household_exports
  from public, anon, authenticated, service_role;
revoke all on table app_private.household_privacy_command_requests
  from public, anon, authenticated, service_role;
revoke all on table app_private.household_export_jobs
  from public, anon, authenticated, service_role;
revoke all on table app_private.household_export_download_grants
  from public, anon, authenticated, service_role;
revoke all on table app_private.household_export_purge_jobs
  from public, anon, authenticated, service_role;
revoke all on table app_private.household_deletion_jobs
  from public, anon, authenticated, service_role;
revoke all on table app_private.household_deletion_retention_holds
  from public, anon, authenticated, service_role;
revoke all on table app_private.household_privacy_events
  from public, anon, authenticated, service_role;
revoke all on table app_private.household_privacy_runtime_events
  from public, anon, authenticated, service_role;

create or replace function app_private.reject_household_privacy_audit_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'KHP30',
    message = 'household privacy audit is immutable';
end;
$$;

create or replace function app_private.household_privacy_request_lock(
  p_auth_user_id uuid,
  p_household_id uuid
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if p_auth_user_id is null or p_household_id is null then
    raise exception using errcode = 'KHP02', message = 'invalid household privacy input';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('privacy-user:' || p_auth_user_id::text, 0)
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('privacy-household:' || p_household_id::text, 0)
  );
end;
$$;

revoke all on function app_private.household_privacy_request_lock(uuid, uuid)
  from public, anon, authenticated, service_role;

create or replace function app_private.household_privacy_active_owner(
  p_auth_user_id uuid,
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
    from public.households as household
    join public.household_members as member
      on member.household_id = household.id
     and member.id = household.owner_member_id
    join public.profiles as profile
      on profile.auth_user_id = member.auth_user_id
     and profile.deleted_at is null
    where household.id = p_household_id
      and household.deleted_at is null
      and member.auth_user_id = p_auth_user_id
      and member.role = 'owner'
      and member.removed_at is null
  )
$$;

revoke all on function app_private.household_privacy_active_owner(uuid, uuid)
  from public, anon, authenticated, service_role;

create or replace function app_private.household_privacy_status_payload(
  p_auth_user_id uuid,
  p_request_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'requestId', request.id,
    'kind', case request.request_type
      when 'export_household' then 'export' else 'deletion' end,
    'householdId', request.household_id,
    'status', request.status::text,
    'requestedAt', request.requested_at,
    'scheduledFor', request.scheduled_for,
    'processingStartedAt', request.processing_started_at,
    'completedAt', request.completed_at,
    'failedAt', request.failed_at,
    'cancelledAt', request.cancelled_at,
    'failureCode', request.failure_code,
    'cancellable', request.status in ('queued', 'verifying'),
    'version', request.version,
    'activeSubscriptionAtRequest', request.active_subscription_at_request,
    'artifact', case when request.request_type = 'export_household' then
      pg_catalog.jsonb_build_object(
        'id', export.id,
        'version', export.version,
        'schemaVersion', export.schema_version,
        'expiresAt', export.artifact_expires_at,
        'revokedAt', export.revoked_at,
        'purgedAt', export.purged_at,
        'machineSizeBytes', export.machine_size_bytes,
        'humanSizeBytes', export.human_size_bytes,
        'available', request.status = 'completed'
          and export.machine_object_key is not null
          and export.human_object_key is not null
          and export.artifact_expires_at > pg_catalog.statement_timestamp()
          and export.revoked_at is null
          and export.purged_at is null
      ) else null end,
    'deletion', case when request.request_type = 'delete_household' then
      pg_catalog.jsonb_build_object(
        'retentionBlocked', coalesce(hold.active, false),
        'retentionReviewAt', case when hold.active then hold.review_at else null end,
        'accessRevokedAt', deletion_job.access_revoked_at,
        'redactedAt', deletion_job.redacted_at,
        'billingUnlinkedAt', deletion_job.billing_unlinked_at
      ) else null end
  )
  from public.privacy_requests as request
  left join public.household_exports as export
    on export.privacy_request_id = request.id
  left join app_private.household_deletion_jobs as deletion_job
    on deletion_job.privacy_request_id = request.id
  left join app_private.household_deletion_retention_holds as hold
    on hold.household_id = request.household_id
  where request.id = p_request_id
    and request.auth_user_id = p_auth_user_id
    and request.request_type in ('export_household', 'delete_household')
$$;

revoke all on function app_private.household_privacy_status_payload(uuid, uuid)
  from public, anon, authenticated, service_role;

create or replace function public.get_household_privacy_preflight(
  p_authenticated_user_id uuid,
  p_household_id uuid
)
returns table (result jsonb)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_config app_private.privacy_runtime_config%rowtype;
  v_household public.households%rowtype;
  v_member_count bigint;
  v_active_subscription boolean;
  v_pending public.privacy_requests%rowtype;
  v_conflicting boolean;
  v_hold app_private.household_deletion_retention_holds%rowtype;
begin
  if p_authenticated_user_id is null or p_household_id is null
    or not exists (
      select 1 from public.profiles as profile
      where profile.auth_user_id = p_authenticated_user_id
        and profile.deleted_at is null
    ) then
    raise exception using errcode = 'KHP01', message = 'active account required';
  end if;

  select household.* into v_household
  from public.households as household
  where household.id = p_household_id
    and household.deleted_at is null;
  if not found or not app_private.household_privacy_active_owner(
    p_authenticated_user_id, p_household_id
  ) then
    raise exception using errcode = 'KHP03', message = 'current Owner required';
  end if;

  select pg_catalog.count(*) into v_member_count
  from public.household_members as member
  where member.household_id = p_household_id
    and member.removed_at is null;

  select exists (
    select 1
    from public.billing_household_assignments as assignment
    where assignment.household_id = p_household_id
      and assignment.status = 'active'
  ) into v_active_subscription;

  select request.* into v_pending
  from public.privacy_requests as request
  where request.household_id = p_household_id
    and request.request_type in ('export_household', 'delete_household')
    and request.status in ('queued', 'verifying', 'processing')
  order by request.requested_at desc, request.id desc
  limit 1;

  select exists (
    select 1 from public.privacy_requests as request
    where request.auth_user_id = p_authenticated_user_id
      and request.status in ('queued', 'verifying', 'processing')
      and request.household_id is distinct from p_household_id
  ) into v_conflicting;

  select config.* into v_config
  from app_private.privacy_runtime_config as config
  where config.singleton;
  select hold.* into v_hold
  from app_private.household_deletion_retention_holds as hold
  where hold.household_id = p_household_id;

  return query select pg_catalog.jsonb_build_object(
    'household', pg_catalog.jsonb_build_object(
      'id', v_household.id,
      'name', v_household.name,
      'version', v_household.version
    ),
    'memberCount', v_member_count,
    'activeSubscription', v_active_subscription,
    'canExport', v_config.household_export_requests_enabled
      and v_pending.id is null and not v_conflicting,
    'canDelete', v_config.household_deletion_requests_enabled
      and v_pending.id is null and not v_conflicting,
    'conflictingRequestPending', v_conflicting,
    'pendingRequest', case when v_pending.id is null then null else
      app_private.household_privacy_status_payload(
        p_authenticated_user_id, v_pending.id
      ) end,
    'exportRequestsEnabled', v_config.household_export_requests_enabled,
    'deletionRequestsEnabled', v_config.household_deletion_requests_enabled,
    'downloadsEnabled', v_config.household_export_downloads_enabled,
    'artifactTtlSeconds', v_config.household_export_artifact_ttl_seconds,
    'downloadGrantTtlSeconds',
      v_config.household_export_download_grant_ttl_seconds,
    'deletionCancellationWindowSeconds',
      v_config.household_deletion_cancellation_window_seconds,
    'retentionBlocked', coalesce(v_hold.active, false),
    'retentionReviewAt', case when v_hold.active then v_hold.review_at else null end,
    'evaluatedAt', pg_catalog.statement_timestamp()
  );
end;
$$;

create or replace function public.get_household_privacy_request(
  p_authenticated_user_id uuid,
  p_request_id uuid
)
returns table (result jsonb)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if p_authenticated_user_id is null or p_request_id is null then
    raise exception using errcode = 'KHP02', message = 'invalid household privacy status';
  end if;
  select app_private.household_privacy_status_payload(
    p_authenticated_user_id, p_request_id
  ) into v_result;
  if v_result is null then
    raise exception using errcode = 'KHP06', message = 'household privacy request not found';
  end if;
  return query select v_result;
end;
$$;

create or replace function public.configure_household_privacy_runtime(
  p_export_requests_enabled boolean,
  p_deletion_requests_enabled boolean,
  p_downloads_enabled boolean,
  p_artifact_ttl_seconds integer,
  p_download_grant_ttl_seconds integer,
  p_deletion_cancellation_window_seconds integer,
  p_expected_version bigint,
  p_correlation_id uuid
)
returns table (result jsonb)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_previous app_private.privacy_runtime_config%rowtype;
  v_next app_private.privacy_runtime_config%rowtype;
begin
  if p_export_requests_enabled is null
    or p_deletion_requests_enabled is null
    or p_downloads_enabled is null
    or p_artifact_ttl_seconds not between 3600 and 604800
    or p_download_grant_ttl_seconds not between 60 and 900
    or p_deletion_cancellation_window_seconds not between 3600 and 604800
    or p_expected_version is null or p_correlation_id is null then
    raise exception using errcode = 'KHP02', message = 'invalid household privacy runtime';
  end if;
  select config.* into v_previous
  from app_private.privacy_runtime_config as config
  where config.singleton for update;
  if v_previous.version <> p_expected_version then
    raise exception using errcode = 'KHP07', message = 'runtime version conflict';
  end if;

  update app_private.privacy_runtime_config as config
  set household_export_requests_enabled = p_export_requests_enabled,
      household_deletion_requests_enabled = p_deletion_requests_enabled,
      household_export_downloads_enabled = p_downloads_enabled,
      household_export_artifact_ttl_seconds = p_artifact_ttl_seconds,
      household_export_download_grant_ttl_seconds = p_download_grant_ttl_seconds,
      household_deletion_cancellation_window_seconds =
        p_deletion_cancellation_window_seconds,
      updated_at = pg_catalog.clock_timestamp(),
      version = config.version + 1
  where config.singleton
  returning config.* into v_next;

  insert into app_private.household_privacy_runtime_events (
    previous_export_requests_enabled, next_export_requests_enabled,
    previous_deletion_requests_enabled, next_deletion_requests_enabled,
    previous_downloads_enabled, next_downloads_enabled,
    previous_artifact_ttl_seconds, next_artifact_ttl_seconds,
    previous_grant_ttl_seconds, next_grant_ttl_seconds,
    previous_cancellation_window_seconds, next_cancellation_window_seconds,
    previous_version, next_version, correlation_id
  ) values (
    v_previous.household_export_requests_enabled,
    v_next.household_export_requests_enabled,
    v_previous.household_deletion_requests_enabled,
    v_next.household_deletion_requests_enabled,
    v_previous.household_export_downloads_enabled,
    v_next.household_export_downloads_enabled,
    v_previous.household_export_artifact_ttl_seconds,
    v_next.household_export_artifact_ttl_seconds,
    v_previous.household_export_download_grant_ttl_seconds,
    v_next.household_export_download_grant_ttl_seconds,
    v_previous.household_deletion_cancellation_window_seconds,
    v_next.household_deletion_cancellation_window_seconds,
    v_previous.version, v_next.version, p_correlation_id
  );

  return query select pg_catalog.jsonb_build_object(
    'exportRequestsEnabled', v_next.household_export_requests_enabled,
    'deletionRequestsEnabled', v_next.household_deletion_requests_enabled,
    'downloadsEnabled', v_next.household_export_downloads_enabled,
    'artifactTtlSeconds', v_next.household_export_artifact_ttl_seconds,
    'downloadGrantTtlSeconds',
      v_next.household_export_download_grant_ttl_seconds,
    'deletionCancellationWindowSeconds',
      v_next.household_deletion_cancellation_window_seconds,
    'version', v_next.version
  );
end;
$$;

create or replace function public.request_household_export(
  p_authenticated_user_id uuid,
  p_household_id uuid,
  p_idempotency_key text,
  p_correlation_id uuid
)
returns table (result jsonb)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_config app_private.privacy_runtime_config%rowtype;
  v_command app_private.household_privacy_command_requests%rowtype;
  v_request public.privacy_requests%rowtype;
  v_export public.household_exports%rowtype;
  v_hash bytea;
  v_now timestamptz := pg_catalog.clock_timestamp();
begin
  if p_authenticated_user_id is null or p_household_id is null
    or p_idempotency_key is null
    or pg_catalog.char_length(p_idempotency_key) not between 16 and 200
    or p_idempotency_key <> pg_catalog.btrim(p_idempotency_key)
    or p_idempotency_key ~ '[[:cntrl:]]'
    or p_correlation_id is null then
    raise exception using errcode = 'KHP02', message = 'invalid household export request';
  end if;
  perform app_private.household_privacy_request_lock(
    p_authenticated_user_id, p_household_id
  );
  v_hash := extensions.digest(
    pg_catalog.convert_to(
      'request_export|' || p_household_id::text || '|household-v1', 'UTF8'
    ), 'sha256'
  );
  select command.* into v_command
  from app_private.household_privacy_command_requests as command
  where command.auth_user_id = p_authenticated_user_id
    and command.idempotency_key = p_idempotency_key;
  if found then
    if v_command.operation <> 'request_export'
      or v_command.request_hash <> v_hash then
      raise exception using errcode = 'KHP04', message = 'idempotency key reused';
    end if;
    return query select app_private.household_privacy_status_payload(
      p_authenticated_user_id, v_command.privacy_request_id
    );
    return;
  end if;
  if not app_private.household_privacy_active_owner(
    p_authenticated_user_id, p_household_id
  ) then
    raise exception using errcode = 'KHP03', message = 'current Owner required';
  end if;
  select config.* into v_config
  from app_private.privacy_runtime_config as config
  where config.singleton for share;
  if not v_config.household_export_requests_enabled then
    raise exception using errcode = 'KHP09', message = 'household exports paused';
  end if;
  if exists (
    select 1 from public.privacy_requests as request
    where request.auth_user_id = p_authenticated_user_id
      and request.status in ('queued', 'verifying', 'processing')
  ) or exists (
    select 1 from public.privacy_requests as request
    where request.household_id = p_household_id
      and request.status in ('queued', 'verifying', 'processing')
  ) then
    raise exception using errcode = 'KHP05', message = 'privacy request already pending';
  end if;

  begin
    insert into public.privacy_requests (
      auth_user_id, household_id, request_type, status,
      requested_at, verified_at, scheduled_for,
      active_subscription_at_request, subscription_acknowledged,
      correlation_id
    ) values (
      p_authenticated_user_id, p_household_id, 'export_household', 'queued',
      v_now, v_now, v_now, false, false, p_correlation_id
    ) returning * into v_request;
  exception when unique_violation then
    raise exception using errcode = 'KHP05', message = 'privacy request already pending';
  end;
  insert into public.household_exports(privacy_request_id, household_id)
  values (v_request.id, p_household_id)
  returning * into v_export;
  insert into app_private.household_export_jobs (
    privacy_request_id, household_export_id, household_id,
    processing_status, next_attempt_at, created_at, updated_at
  ) values (
    v_request.id, v_export.id, p_household_id,
    'queued', v_now, v_now, v_now
  );
  insert into app_private.household_privacy_command_requests (
    auth_user_id, idempotency_key, operation, request_hash,
    privacy_request_id, result_request_version,
    result_artifact_version, created_at
  ) values (
    p_authenticated_user_id, p_idempotency_key, 'request_export', v_hash,
    v_request.id, v_request.version, v_export.version, v_now
  );
  insert into app_private.household_privacy_events (
    privacy_request_id, household_id, household_export_id,
    transition, request_status, request_version,
    correlation_id, safe_metadata, occurred_at
  ) values (
    v_request.id, p_household_id, v_export.id,
    'export_requested', v_request.status, v_request.version,
    p_correlation_id,
    pg_catalog.jsonb_build_object(
      'scope', 'household',
      'formats', pg_catalog.jsonb_build_array('json', 'text')
    ),
    v_now
  );
  return query select app_private.household_privacy_status_payload(
    p_authenticated_user_id, v_request.id
  );
end;
$$;

create or replace function public.request_household_deletion(
  p_authenticated_user_id uuid,
  p_household_id uuid,
  p_expected_household_version bigint,
  p_confirmation_name text,
  p_acknowledge_member_access_loss boolean,
  p_acknowledge_shared_data_redaction boolean,
  p_acknowledge_subscription_not_cancelled boolean,
  p_idempotency_key text,
  p_correlation_id uuid
)
returns table (result jsonb)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_config app_private.privacy_runtime_config%rowtype;
  v_command app_private.household_privacy_command_requests%rowtype;
  v_request public.privacy_requests%rowtype;
  v_household public.households%rowtype;
  v_hash bytea;
  v_member_count bigint;
  v_active_subscription boolean;
  v_now timestamptz := pg_catalog.clock_timestamp();
begin
  if p_authenticated_user_id is null or p_household_id is null
    or p_expected_household_version is null or p_expected_household_version < 1
    or p_confirmation_name is null
    or pg_catalog.char_length(p_confirmation_name) not between 1 and 80
    or p_acknowledge_member_access_loss is not true
    or p_acknowledge_shared_data_redaction is not true
    or p_acknowledge_subscription_not_cancelled is null
    or p_idempotency_key is null
    or pg_catalog.char_length(p_idempotency_key) not between 16 and 200
    or p_idempotency_key <> pg_catalog.btrim(p_idempotency_key)
    or p_idempotency_key ~ '[[:cntrl:]]'
    or p_correlation_id is null then
    raise exception using errcode = 'KHP02', message = 'invalid household deletion request';
  end if;
  perform app_private.household_privacy_request_lock(
    p_authenticated_user_id, p_household_id
  );
  v_hash := extensions.digest(
    pg_catalog.convert_to(
      pg_catalog.jsonb_build_object(
        'operation', 'request_deletion',
        'householdId', p_household_id,
        'expectedVersion', p_expected_household_version,
        'confirmationName', p_confirmation_name,
        'memberAccessLoss', p_acknowledge_member_access_loss,
        'sharedDataRedaction', p_acknowledge_shared_data_redaction,
        'subscriptionNotCancelled', p_acknowledge_subscription_not_cancelled
      )::text, 'UTF8'
    ), 'sha256'
  );
  select command.* into v_command
  from app_private.household_privacy_command_requests as command
  where command.auth_user_id = p_authenticated_user_id
    and command.idempotency_key = p_idempotency_key;
  if found then
    if v_command.operation <> 'request_deletion'
      or v_command.request_hash <> v_hash then
      raise exception using errcode = 'KHP04', message = 'idempotency key reused';
    end if;
    return query select app_private.household_privacy_status_payload(
      p_authenticated_user_id, v_command.privacy_request_id
    );
    return;
  end if;

  select household.* into v_household
  from public.households as household
  where household.id = p_household_id
    and household.deleted_at is null
  for update;
  if not found or not app_private.household_privacy_active_owner(
    p_authenticated_user_id, p_household_id
  ) then
    raise exception using errcode = 'KHP03', message = 'current Owner required';
  end if;
  if v_household.version <> p_expected_household_version then
    raise exception using errcode = 'KHP07', message = 'household version conflict';
  end if;
  if v_household.name <> p_confirmation_name then
    raise exception using errcode = 'KHP10', message = 'household name confirmation mismatch';
  end if;
  select exists (
    select 1 from public.billing_household_assignments as assignment
    where assignment.household_id = p_household_id
      and assignment.status = 'active'
  ) into v_active_subscription;
  if v_active_subscription and not p_acknowledge_subscription_not_cancelled then
    raise exception using errcode = 'KHP11', message = 'subscription acknowledgment required';
  end if;
  select pg_catalog.count(*) into v_member_count
  from public.household_members as member
  where member.household_id = p_household_id and member.removed_at is null;
  select config.* into v_config
  from app_private.privacy_runtime_config as config
  where config.singleton for share;
  if not v_config.household_deletion_requests_enabled then
    raise exception using errcode = 'KHP12', message = 'household deletion paused';
  end if;
  if exists (
    select 1 from public.privacy_requests as request
    where request.auth_user_id = p_authenticated_user_id
      and request.status in ('queued', 'verifying', 'processing')
  ) or exists (
    select 1 from public.privacy_requests as request
    where request.household_id = p_household_id
      and request.status in ('queued', 'verifying', 'processing')
  ) then
    raise exception using errcode = 'KHP05', message = 'privacy request already pending';
  end if;

  begin
    insert into public.privacy_requests (
      auth_user_id, household_id, request_type, status,
      requested_at, verified_at, scheduled_for,
      active_subscription_at_request, subscription_acknowledged,
      correlation_id
    ) values (
      p_authenticated_user_id, p_household_id, 'delete_household', 'queued',
      v_now, v_now,
      v_now + pg_catalog.make_interval(
        secs => v_config.household_deletion_cancellation_window_seconds
      ),
      v_active_subscription,
      not v_active_subscription or p_acknowledge_subscription_not_cancelled,
      p_correlation_id
    ) returning * into v_request;
  exception when unique_violation then
    raise exception using errcode = 'KHP05', message = 'privacy request already pending';
  end;
  insert into app_private.household_deletion_jobs (
    privacy_request_id, household_id, processing_status,
    next_attempt_at, created_at, updated_at
  ) values (
    v_request.id, p_household_id, 'queued',
    v_request.scheduled_for, v_now, v_now
  );
  insert into app_private.household_privacy_command_requests (
    auth_user_id, idempotency_key, operation, request_hash,
    privacy_request_id, result_request_version, created_at
  ) values (
    p_authenticated_user_id, p_idempotency_key, 'request_deletion', v_hash,
    v_request.id, v_request.version, v_now
  );
  insert into app_private.household_privacy_events (
    privacy_request_id, household_id, transition, request_status,
    request_version, correlation_id, safe_metadata, occurred_at
  ) values (
    v_request.id, p_household_id, 'deletion_requested', v_request.status,
    v_request.version, p_correlation_id,
    pg_catalog.jsonb_build_object(
      'memberCount', v_member_count,
      'activeSubscription', v_active_subscription,
      'cancellationWindowSeconds',
        v_config.household_deletion_cancellation_window_seconds
    ),
    v_now
  );
  return query select app_private.household_privacy_status_payload(
    p_authenticated_user_id, v_request.id
  );
end;
$$;

revoke all on function app_private.reject_household_privacy_audit_mutation()
  from public, anon, authenticated, service_role;

create trigger household_privacy_events_immutable
before update or delete on app_private.household_privacy_events
for each row execute function app_private.reject_household_privacy_audit_mutation();

create trigger household_privacy_runtime_events_immutable
before update or delete on app_private.household_privacy_runtime_events
for each row execute function app_private.reject_household_privacy_audit_mutation();

create or replace function app_private.touch_household_privacy_row()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := greatest(
    pg_catalog.clock_timestamp(), old.updated_at
  );
  return new;
end;
$$;

revoke all on function app_private.touch_household_privacy_row()
  from public, anon, authenticated, service_role;

create trigger household_export_jobs_touch
before update on app_private.household_export_jobs
for each row execute function app_private.touch_household_privacy_row();
create trigger household_export_purge_jobs_touch
before update on app_private.household_export_purge_jobs
for each row execute function app_private.touch_household_privacy_row();
create trigger household_deletion_jobs_touch
before update on app_private.household_deletion_jobs
for each row execute function app_private.touch_household_privacy_row();
create trigger household_deletion_retention_holds_touch
before update on app_private.household_deletion_retention_holds
for each row execute function app_private.touch_household_privacy_row();

create trigger household_exports_set_updated_at_and_version
before update on public.household_exports
for each row execute function app_private.set_updated_at_and_version();

alter table public.household_exports enable row level security;
alter table public.household_exports force row level security;

create or replace function app_private.is_own_household_export(
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
      and request.request_type = 'export_household'
      and request.auth_user_id = (select auth.uid())
  )
$$;

revoke all on function app_private.is_own_household_export(uuid)
  from public, anon, authenticated, service_role;
grant execute on function app_private.is_own_household_export(uuid)
  to authenticated;

create policy household_exports_select_requester
on public.household_exports
for select
to authenticated
using (app_private.is_own_household_export(privacy_request_id));

grant select (
  id, privacy_request_id, household_id, schema_version,
  machine_size_bytes, human_size_bytes, artifact_expires_at,
  revoked_at, purged_at, created_at, updated_at, version
) on public.household_exports to authenticated;

-- Deleted households must fail closed even while a pre-deletion JWT remains.
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
  join public.households as household
    on household.id = member.household_id
   and household.deleted_at is null
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
    join public.households as household
      on household.id = member.household_id
     and household.deleted_at is null
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
    join public.households as household
      on household.id = member.household_id
     and household.deleted_at is null
    join public.profiles as profile
      on profile.auth_user_id = member.auth_user_id
     and profile.deleted_at is null
    where member.household_id = p_household_id
      and member.auth_user_id = (select auth.uid())
      and member.removed_at is null
      and member.role = any(p_roles)
  )
$$;

create or replace function app_private.assert_household_owner_integrity(
  p_household_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner_member_id uuid;
  v_deleted_at timestamptz;
  v_owner_count bigint;
  v_pointer_matches boolean;
begin
  select household.owner_member_id, household.deleted_at
  into v_owner_member_id, v_deleted_at
  from public.households as household
  where household.id = p_household_id;
  if not found or v_deleted_at is not null then
    return;
  end if;

  select
    pg_catalog.count(*),
    coalesce(pg_catalog.bool_or(member.id = v_owner_member_id), false)
  into v_owner_count, v_pointer_matches
  from public.household_members as member
  where member.household_id = p_household_id
    and member.role = 'owner'
    and member.removed_at is null;

  if v_owner_count <> 1 then
    raise exception using
      errcode = '23514',
      message = 'household must have exactly one active owner',
      constraint = 'households_exactly_one_active_owner_ck';
  end if;
  if not v_pointer_matches then
    raise exception using
      errcode = '23514',
      message = 'household owner pointer must reference its active owner',
      constraint = 'households_owner_pointer_active_ck';
  end if;
end;
$$;

create or replace function public.cancel_household_privacy_request(
  p_authenticated_user_id uuid,
  p_request_id uuid,
  p_request_kind text,
  p_expected_version bigint,
  p_idempotency_key text,
  p_correlation_id uuid
)
returns table (result jsonb)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.privacy_requests%rowtype;
  v_command app_private.household_privacy_command_requests%rowtype;
  v_export public.household_exports%rowtype;
  v_operation text;
  v_expected_type public.privacy_request_type;
  v_hash bytea;
  v_now timestamptz := pg_catalog.clock_timestamp();
begin
  if p_authenticated_user_id is null or p_request_id is null
    or p_request_kind not in ('export', 'deletion')
    or p_expected_version is null or p_expected_version < 1
    or p_idempotency_key is null
    or pg_catalog.char_length(p_idempotency_key) not between 16 and 200
    or p_idempotency_key <> pg_catalog.btrim(p_idempotency_key)
    or p_idempotency_key ~ '[[:cntrl:]]'
    or p_correlation_id is null then
    raise exception using errcode = 'KHP02', message = 'invalid cancellation request';
  end if;
  v_operation := case p_request_kind
    when 'export' then 'cancel_export' else 'cancel_deletion' end;
  v_expected_type := case p_request_kind
    when 'export' then 'export_household'::public.privacy_request_type
    else 'delete_household'::public.privacy_request_type end;
  v_hash := extensions.digest(
    pg_catalog.convert_to(
      v_operation || '|' || p_request_id::text || '|' || p_expected_version::text,
      'UTF8'
    ), 'sha256'
  );

  select request.* into v_request
  from public.privacy_requests as request
  where request.id = p_request_id
    and request.auth_user_id = p_authenticated_user_id
    and request.request_type = v_expected_type;
  if not found then
    raise exception using errcode = 'KHP06', message = 'household privacy request not found';
  end if;
  perform app_private.household_privacy_request_lock(
    p_authenticated_user_id, v_request.household_id
  );
  select command.* into v_command
  from app_private.household_privacy_command_requests as command
  where command.auth_user_id = p_authenticated_user_id
    and command.idempotency_key = p_idempotency_key;
  if found then
    if v_command.operation <> v_operation
      or v_command.request_hash <> v_hash
      or v_command.privacy_request_id <> p_request_id then
      raise exception using errcode = 'KHP04', message = 'idempotency key reused';
    end if;
    return query select app_private.household_privacy_status_payload(
      p_authenticated_user_id, p_request_id
    );
    return;
  end if;

  select request.* into v_request
  from public.privacy_requests as request
  where request.id = p_request_id
    and request.auth_user_id = p_authenticated_user_id
    and request.request_type = v_expected_type
  for update;
  if v_request.version <> p_expected_version then
    raise exception using errcode = 'KHP07', message = 'request version conflict';
  end if;
  if v_request.status not in ('queued', 'verifying') then
    raise exception using errcode = 'KHP08', message = 'request not cancellable';
  end if;

  update public.privacy_requests as request
  set status = 'cancelled', cancelled_at = v_now
  where request.id = p_request_id
  returning request.* into v_request;
  if p_request_kind = 'export' then
    update app_private.household_export_jobs as job
    set processing_status = 'cancelled', next_attempt_at = null
    where job.privacy_request_id = p_request_id;
    select export.* into v_export
    from public.household_exports as export
    where export.privacy_request_id = p_request_id;
  else
    update app_private.household_deletion_jobs as job
    set processing_status = 'cancelled', next_attempt_at = null
    where job.privacy_request_id = p_request_id;
  end if;

  insert into app_private.household_privacy_command_requests (
    auth_user_id, idempotency_key, operation, request_hash,
    privacy_request_id, result_request_version,
    result_artifact_version, created_at
  ) values (
    p_authenticated_user_id, p_idempotency_key, v_operation, v_hash,
    p_request_id, v_request.version,
    case when p_request_kind = 'export' then v_export.version else null end,
    v_now
  );
  insert into app_private.household_privacy_events (
    privacy_request_id, household_id, household_export_id,
    transition, request_status, request_version,
    correlation_id, occurred_at
  ) values (
    p_request_id, v_request.household_id,
    case when p_request_kind = 'export' then v_export.id else null end,
    case when p_request_kind = 'export'
      then 'export_cancelled' else 'deletion_cancelled' end,
    v_request.status, v_request.version, p_correlation_id, v_now
  );
  return query select app_private.household_privacy_status_payload(
    p_authenticated_user_id, p_request_id
  );
end;
$$;

create or replace function public.revoke_household_export(
  p_authenticated_user_id uuid,
  p_request_id uuid,
  p_expected_artifact_version bigint,
  p_idempotency_key text,
  p_correlation_id uuid
)
returns table (result jsonb)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.privacy_requests%rowtype;
  v_export public.household_exports%rowtype;
  v_command app_private.household_privacy_command_requests%rowtype;
  v_hash bytea;
  v_now timestamptz := pg_catalog.clock_timestamp();
begin
  if p_authenticated_user_id is null or p_request_id is null
    or p_expected_artifact_version is null or p_expected_artifact_version < 1
    or p_idempotency_key is null
    or pg_catalog.char_length(p_idempotency_key) not between 16 and 200
    or p_idempotency_key <> pg_catalog.btrim(p_idempotency_key)
    or p_idempotency_key ~ '[[:cntrl:]]'
    or p_correlation_id is null then
    raise exception using errcode = 'KHP02', message = 'invalid export revoke';
  end if;
  select request.* into v_request
  from public.privacy_requests as request
  where request.id = p_request_id
    and request.auth_user_id = p_authenticated_user_id
    and request.request_type = 'export_household';
  if not found then
    raise exception using errcode = 'KHP06', message = 'household export not found';
  end if;
  perform app_private.household_privacy_request_lock(
    p_authenticated_user_id, v_request.household_id
  );
  v_hash := extensions.digest(
    pg_catalog.convert_to(
      'revoke_export|' || p_request_id::text || '|' ||
        p_expected_artifact_version::text,
      'UTF8'
    ), 'sha256'
  );
  select command.* into v_command
  from app_private.household_privacy_command_requests as command
  where command.auth_user_id = p_authenticated_user_id
    and command.idempotency_key = p_idempotency_key;
  if found then
    if v_command.operation <> 'revoke_export'
      or v_command.request_hash <> v_hash
      or v_command.privacy_request_id <> p_request_id then
      raise exception using errcode = 'KHP04', message = 'idempotency key reused';
    end if;
    return query select app_private.household_privacy_status_payload(
      p_authenticated_user_id, p_request_id
    );
    return;
  end if;

  select request.* into v_request
  from public.privacy_requests as request
  where request.id = p_request_id and request.status = 'completed'
  for update;
  select export.* into v_export
  from public.household_exports as export
  where export.privacy_request_id = p_request_id
  for update;
  if not found or v_export.artifact_expires_at is null
    or v_export.purged_at is not null then
    raise exception using errcode = 'KHP13', message = 'artifact unavailable';
  end if;
  if v_export.version <> p_expected_artifact_version then
    raise exception using errcode = 'KHP07', message = 'artifact version conflict';
  end if;
  if v_export.revoked_at is null then
    update public.household_exports as export
    set revoked_at = v_now
    where export.id = v_export.id
    returning export.* into v_export;
    update app_private.household_export_download_grants as download_grant
    set revoked_at = v_now
    where download_grant.household_export_id = v_export.id
      and download_grant.consumed_at is null and download_grant.revoked_at is null;
    update app_private.household_export_purge_jobs as job
    set processing_status = case
          when job.processing_status in ('queued', 'retry_wait') then 'queued'
          else job.processing_status end,
        attempts = case when job.processing_status = 'retry_wait' then 0
          else job.attempts end,
        next_attempt_at = case
          when job.processing_status in ('queued', 'retry_wait') then v_now
          else job.next_attempt_at end,
        last_error_code = case
          when job.processing_status in ('queued', 'retry_wait') then null
          else job.last_error_code end
    where job.household_export_id = v_export.id;
    insert into app_private.household_privacy_events (
      privacy_request_id, household_id, household_export_id,
      transition, request_status, request_version,
      correlation_id, occurred_at
    ) values (
      v_request.id, v_request.household_id, v_export.id,
      'export_revoked', v_request.status, v_request.version,
      p_correlation_id, v_now
    );
  end if;
  insert into app_private.household_privacy_command_requests (
    auth_user_id, idempotency_key, operation, request_hash,
    privacy_request_id, result_request_version,
    result_artifact_version, created_at
  ) values (
    p_authenticated_user_id, p_idempotency_key, 'revoke_export', v_hash,
    p_request_id, v_request.version, v_export.version, v_now
  );
  return query select app_private.household_privacy_status_payload(
    p_authenticated_user_id, p_request_id
  );
end;
$$;

create or replace function public.create_household_export_download_grant(
  p_authenticated_user_id uuid,
  p_request_id uuid,
  p_export_format text,
  p_token_hash_base64 text,
  p_correlation_id uuid
)
returns table (result jsonb)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_config app_private.privacy_runtime_config%rowtype;
  v_request public.privacy_requests%rowtype;
  v_export public.household_exports%rowtype;
  v_grant app_private.household_export_download_grants%rowtype;
  v_hash bytea;
  v_now timestamptz := pg_catalog.clock_timestamp();
begin
  if p_authenticated_user_id is null or p_request_id is null
    or p_export_format not in ('json', 'text')
    or p_token_hash_base64 is null
    or p_token_hash_base64 !~ '^[A-Za-z0-9+/]{43}=$'
    or p_correlation_id is null then
    raise exception using errcode = 'KHP02', message = 'invalid download grant';
  end if;
  v_hash := pg_catalog.decode(p_token_hash_base64, 'base64');
  if pg_catalog.octet_length(v_hash) <> 32 then
    raise exception using errcode = 'KHP02', message = 'invalid download hash';
  end if;
  select request.* into v_request
  from public.privacy_requests as request
  where request.id = p_request_id
    and request.auth_user_id = p_authenticated_user_id
    and request.request_type = 'export_household'
    and request.status = 'completed';
  if not found then
    raise exception using errcode = 'KHP13', message = 'artifact unavailable';
  end if;
  perform app_private.household_privacy_request_lock(
    p_authenticated_user_id, v_request.household_id
  );
  if not app_private.household_privacy_active_owner(
    p_authenticated_user_id, v_request.household_id
  ) then
    raise exception using errcode = 'KHP03', message = 'current Owner required';
  end if;
  select config.* into v_config
  from app_private.privacy_runtime_config as config
  where config.singleton for share;
  if not v_config.household_export_downloads_enabled then
    raise exception using errcode = 'KHP14', message = 'downloads paused';
  end if;
  select export.* into v_export
  from public.household_exports as export
  where export.privacy_request_id = p_request_id
  for update;
  if not found or v_export.machine_object_key is null
    or v_export.human_object_key is null
    or v_export.artifact_expires_at <= v_now
    or v_export.revoked_at is not null or v_export.purged_at is not null then
    raise exception using errcode = 'KHP13', message = 'artifact unavailable';
  end if;

  update app_private.household_export_download_grants as download_grant
  set revoked_at = v_now
  where download_grant.household_export_id = v_export.id
    and download_grant.export_format = p_export_format
    and download_grant.consumed_at is null and download_grant.revoked_at is null;
  insert into app_private.household_export_download_grants (
    household_export_id, token_hash, export_format,
    correlation_id, issued_at, expires_at
  ) values (
    v_export.id, v_hash, p_export_format, p_correlation_id, v_now,
    v_now + pg_catalog.make_interval(
      secs => v_config.household_export_download_grant_ttl_seconds
    )
  ) returning * into v_grant;
  insert into app_private.household_privacy_events (
    privacy_request_id, household_id, household_export_id,
    transition, request_status, request_version,
    correlation_id, safe_metadata, occurred_at
  ) values (
    v_request.id, v_request.household_id, v_export.id,
    'download_grant_issued', v_request.status, v_request.version,
    p_correlation_id,
    pg_catalog.jsonb_build_object(
      'format', p_export_format,
      'grantTtlSeconds', v_config.household_export_download_grant_ttl_seconds
    ),
    v_now
  );
  return query select pg_catalog.jsonb_build_object(
    'format', p_export_format,
    'expiresAt', v_grant.expires_at
  );
end;
$$;

create or replace function public.consume_household_export_download_grant(
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
  v_grant app_private.household_export_download_grants%rowtype;
  v_export public.household_exports%rowtype;
  v_request public.privacy_requests%rowtype;
  v_hash bytea;
begin
  if p_token_hash_base64 is null
    or p_token_hash_base64 !~ '^[A-Za-z0-9+/]{43}=$'
    or p_as_of is null then
    raise exception using errcode = 'KHP15', message = 'download grant invalid';
  end if;
  v_hash := pg_catalog.decode(p_token_hash_base64, 'base64');
  if pg_catalog.octet_length(v_hash) <> 32 then
    raise exception using errcode = 'KHP15', message = 'download grant invalid';
  end if;
  select config.* into v_config
  from app_private.privacy_runtime_config as config
  where config.singleton;
  if not v_config.household_export_downloads_enabled then
    raise exception using errcode = 'KHP14', message = 'downloads paused';
  end if;
  select download_grant.* into v_grant
  from app_private.household_export_download_grants as download_grant
  where download_grant.token_hash = v_hash for update;
  if not found or v_grant.consumed_at is not null
    or v_grant.revoked_at is not null or v_grant.expires_at <= p_as_of then
    raise exception using errcode = 'KHP15', message = 'download grant invalid';
  end if;
  select export.* into v_export
  from public.household_exports as export
  where export.id = v_grant.household_export_id for update;
  select request.* into v_request
  from public.privacy_requests as request
  where request.id = v_export.privacy_request_id;
  if v_request.status <> 'completed'
    or v_export.artifact_expires_at <= p_as_of
    or v_export.revoked_at is not null or v_export.purged_at is not null
    or not exists (
      select 1 from public.profiles as profile
      where profile.auth_user_id = v_request.auth_user_id
        and profile.deleted_at is null
    ) then
    raise exception using errcode = 'KHP15', message = 'download grant invalid';
  end if;
  update app_private.household_export_download_grants as download_grant
  set consumed_at = p_as_of where download_grant.id = v_grant.id;
  insert into app_private.household_privacy_events (
    privacy_request_id, household_id, household_export_id,
    transition, request_status, request_version,
    correlation_id, safe_metadata, occurred_at
  ) values (
    v_request.id, v_request.household_id, v_export.id,
    'download_consumed', v_request.status, v_request.version,
    v_grant.correlation_id,
    pg_catalog.jsonb_build_object('format', v_grant.export_format),
    p_as_of
  );
  return query select
    v_grant.export_format,
    case when v_grant.export_format = 'json'
      then v_export.machine_object_key else v_export.human_object_key end,
    case when v_grant.export_format = 'json'
      then 'kinflow-household.json' else 'kinflow-household.txt' end,
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

create or replace function public.configure_household_deletion_retention_hold(
  p_household_id uuid,
  p_active boolean,
  p_review_at timestamptz,
  p_reference_hash_base64 text,
  p_expected_version bigint,
  p_correlation_id uuid
)
returns table (result jsonb)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_hold app_private.household_deletion_retention_holds%rowtype;
  v_request public.privacy_requests%rowtype;
  v_job app_private.household_deletion_jobs%rowtype;
  v_hash bytea;
  v_now timestamptz := pg_catalog.clock_timestamp();
begin
  if p_household_id is null or p_active is null
    or p_expected_version is null or p_expected_version < 0
    or p_correlation_id is null
    or (
      p_active and (
        p_review_at is null or p_review_at <= v_now
        or p_reference_hash_base64 is null
        or p_reference_hash_base64 !~ '^[A-Za-z0-9+/]{43}=$'
      )
    )
    or (not p_active and (p_review_at is not null
      or p_reference_hash_base64 is not null)) then
    raise exception using errcode = 'KHP02', message = 'invalid retention hold';
  end if;
  if p_active then
    v_hash := pg_catalog.decode(p_reference_hash_base64, 'base64');
    if pg_catalog.octet_length(v_hash) <> 32 then
      raise exception using errcode = 'KHP02', message = 'invalid retention reference';
    end if;
  end if;
  select request.* into v_request
  from public.privacy_requests as request
  where request.household_id = p_household_id
    and request.request_type = 'delete_household'
    and request.status in ('queued', 'verifying')
  order by request.requested_at desc limit 1 for update;
  if not found then
    raise exception using errcode = 'KHP06', message = 'pending deletion not found';
  end if;
  select job.* into v_job
  from app_private.household_deletion_jobs as job
  where job.privacy_request_id = v_request.id for update;
  if v_job.processing_status not in ('queued', 'retention_hold')
    or v_job.attempts <> 0 then
    raise exception using errcode = 'KHP08', message = 'retention hold no longer mutable';
  end if;
  select hold.* into v_hold
  from app_private.household_deletion_retention_holds as hold
  where hold.household_id = p_household_id for update;
  if not found and p_expected_version <> 0 then
    raise exception using errcode = 'KHP07', message = 'retention version conflict';
  elsif found and v_hold.version <> p_expected_version then
    raise exception using errcode = 'KHP07', message = 'retention version conflict';
  end if;

  insert into app_private.household_deletion_retention_holds (
    household_id, active, review_at, reference_hash,
    correlation_id, created_at, updated_at, version
  ) values (
    p_household_id, p_active,
    case when p_active then p_review_at else null end,
    case when p_active then v_hash else null end,
    p_correlation_id, v_now, v_now, 1
  ) on conflict (household_id) do update
  set active = excluded.active,
      review_at = excluded.review_at,
      reference_hash = excluded.reference_hash,
      correlation_id = excluded.correlation_id,
      version = app_private.household_deletion_retention_holds.version + 1
  returning * into v_hold;

  update app_private.household_deletion_jobs as job
  set processing_status = case when p_active then 'retention_hold' else 'queued' end,
      next_attempt_at = case when p_active then null
        else greatest(v_now, v_request.scheduled_for) end
  where job.privacy_request_id = v_request.id;
  insert into app_private.household_privacy_events (
    privacy_request_id, household_id, transition, request_status,
    request_version, correlation_id, safe_metadata, occurred_at
  ) values (
    v_request.id, p_household_id,
    case when p_active then 'retention_hold_applied'
      else 'retention_hold_released' end,
    v_request.status, v_request.version, p_correlation_id,
    pg_catalog.jsonb_build_object(
      'reviewAt', case when p_active then p_review_at else null end,
      'holdVersion', v_hold.version
    ),
    v_now
  );
  return query select pg_catalog.jsonb_build_object(
    'active', v_hold.active,
    'reviewAt', v_hold.review_at,
    'version', v_hold.version
  );
end;
$$;

create or replace function app_private.household_export_payload(
  p_household_id uuid,
  p_as_of timestamptz
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'schemaVersion', '2026-08-08-wp07-02b',
    'generatedAt', p_as_of,
    'scope', pg_catalog.jsonb_build_object(
      'kind', 'sharedHousehold',
      'memberAuthIdentitiesIncluded', false,
      'personalNotificationInboxIncluded', false,
      'providerIdentifiersIncluded', false,
      'removedMemberDisplayIdentityIncluded', false
    ),
    'household', (
      select pg_catalog.jsonb_build_object(
        'id', household.id,
        'name', household.name,
        'timezone', household.timezone,
        'createdAt', household.created_at,
        'updatedAt', household.updated_at,
        'version', household.version
      )
      from public.households as household
      where household.id = p_household_id
        and household.deleted_at is null
    ),
    'members', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', member.id,
          'displayName', member.display_name,
          'role', member.role::text,
          'joinedAt', member.joined_at,
          'createdAt', member.created_at,
          'version', member.version
        ) order by member.joined_at, member.id
      )
      from public.household_members as member
      where member.household_id = p_household_id
        and member.removed_at is null
    ), '[]'::jsonb),
    'choreSeries', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', series.id,
          'title', series.title,
          'description', series.description,
          'timezone', series.timezone,
          'activeRevisionId', series.active_revision_id,
          'createdAt', series.created_at,
          'updatedAt', series.updated_at,
          'version', series.version,
          'deletedAt', series.deleted_at
        ) order by series.created_at, series.id
      )
      from public.chore_series as series
      where series.household_id = p_household_id
    ), '[]'::jsonb),
    'choreRevisions', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', revision.id,
          'seriesId', revision.series_id,
          'revisionNumber', revision.revision_number,
          'title', revision.title,
          'description', revision.description,
          'effectiveLocalDate', revision.effective_local_date,
          'dueLocalTime', revision.due_local_time,
          'recurrenceRule', revision.recurrence_rule,
          'defaultAssigneeMemberId', revision.default_assignee_member_id,
          'createdAt', revision.created_at
        ) order by revision.series_id, revision.revision_number, revision.id
      )
      from public.chore_series_revisions as revision
      where revision.household_id = p_household_id
    ), '[]'::jsonb),
    'choreOccurrences', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', occurrence.id,
          'seriesId', occurrence.series_id,
          'revisionId', occurrence.revision_id,
          'occurrenceKey', occurrence.occurrence_key,
          'recurrenceLocalDate', occurrence.recurrence_local_date,
          'dueLocalDate', occurrence.due_local_date,
          'dueAt', occurrence.due_at,
          'timezone', occurrence.timezone,
          'status', occurrence.status::text,
          'assigneeMemberId', occurrence.assignee_member_id,
          'completedByMemberId', occurrence.completed_by_member_id,
          'completedAt', occurrence.completed_at,
          'createdAt', occurrence.created_at,
          'updatedAt', occurrence.updated_at,
          'version', occurrence.version
        ) order by occurrence.due_local_date, occurrence.id
      )
      from public.chore_occurrences as occurrence
      where occurrence.household_id = p_household_id
    ), '[]'::jsonb),
    'choreActions', coalesce((
      select pg_catalog.jsonb_agg(
        action.entry order by action.occurred_at, action.sort_id
      )
      from (
        select event.occurred_at, event.id as sort_id,
          pg_catalog.jsonb_build_object(
            'id', event.id,
            'action', event.event_type,
            'occurrenceId', event.occurrence_id,
            'actorMemberId', event.actor_member_id,
            'actingMemberId', event.acting_member_id,
            'occurredAt', event.occurred_at,
            'resultVersion', event.occurrence_version
          ) as entry
        from public.chore_completion_events as event
        where event.household_id = p_household_id
        union all
        select event.occurred_at, event.id,
          pg_catalog.jsonb_build_object(
            'id', event.id,
            'action', 'rescheduled',
            'occurrenceId', event.occurrence_id,
            'actorMemberId', event.actor_member_id,
            'previousDueLocalDate', event.previous_due_local_date,
            'previousDueLocalTime', event.previous_due_local_time,
            'previousDueAt', event.previous_due_at,
            'newDueLocalDate', event.new_due_local_date,
            'newDueLocalTime', event.new_due_local_time,
            'newDueAt', event.new_due_at,
            'occurredAt', event.occurred_at,
            'resultVersion', event.occurrence_version
          )
        from public.chore_reschedule_events as event
        where event.household_id = p_household_id
        union all
        select event.occurred_at, event.id,
          pg_catalog.jsonb_build_object(
            'id', event.id,
            'action', 'reassigned',
            'occurrenceId', event.occurrence_id,
            'actorMemberId', event.actor_member_id,
            'previousAssigneeMemberId', event.previous_assignee_member_id,
            'newAssigneeMemberId', event.new_assignee_member_id,
            'occurredAt', event.occurred_at,
            'resultVersion', event.occurrence_version
          )
        from public.chore_assignment_events as event
        where event.household_id = p_household_id
        union all
        select event.occurred_at, event.id,
          pg_catalog.jsonb_build_object(
            'id', event.id,
            'action', 'series_' || event.operation,
            'seriesId', event.series_id,
            'actorMemberId', event.actor_member_id,
            'previousRevisionId', event.previous_revision_id,
            'newRevisionId', event.new_revision_id,
            'effectiveLocalDate', event.effective_local_date,
            'occurredAt', event.occurred_at,
            'resultVersion', event.series_version
          )
        from public.chore_series_change_events as event
        where event.household_id = p_household_id
      ) as action
    ), '[]'::jsonb),
    'calendarSeries', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', series.id,
          'title', series.title,
          'description', series.description,
          'timezone', series.timezone,
          'isAllDay', series.is_all_day,
          'activeRevisionId', series.active_revision_id,
          'createdAt', series.created_at,
          'updatedAt', series.updated_at,
          'version', series.version,
          'deletedAt', series.deleted_at,
          'endedAt', series.ended_at,
          'endedEffectiveLocalDate', series.ended_effective_local_date
        ) order by series.created_at, series.id
      )
      from public.event_series as series
      where series.household_id = p_household_id
    ), '[]'::jsonb),
    'calendarRevisions', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', revision.id,
          'seriesId', revision.series_id,
          'revisionNumber', revision.revision_number,
          'snapshotTitle', revision.snapshot_title,
          'snapshotDescription', revision.snapshot_description,
          'snapshotTimezone', revision.snapshot_timezone,
          'snapshotIsAllDay', revision.snapshot_is_all_day,
          'localStartDate', revision.local_start_date,
          'localStartTime', revision.local_start_time,
          'durationMinutes', revision.duration_minutes,
          'allDayEndDateExclusive', revision.all_day_end_date_exclusive,
          'gapPolicy', revision.gap_policy,
          'overlapPolicy', revision.overlap_policy,
          'recurrenceRule', revision.recurrence_rule,
          'createdAt', revision.created_at
        ) order by revision.series_id, revision.revision_number, revision.id
      )
      from public.event_series_revisions as revision
      where revision.household_id = p_household_id
    ), '[]'::jsonb),
    'calendarOccurrences', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', occurrence.id,
          'seriesId', occurrence.series_id,
          'revisionId', occurrence.revision_id,
          'occurrenceKey', occurrence.occurrence_key,
          'recurrenceLocalStartDate', occurrence.recurrence_local_start_date,
          'localStartDate', occurrence.local_start_date,
          'startsAt', occurrence.starts_at,
          'endsAt', occurrence.ends_at,
          'allDayEndDateExclusive', occurrence.all_day_end_date_exclusive,
          'timezone', occurrence.timezone,
          'status', occurrence.status::text,
          'createdAt', occurrence.created_at,
          'updatedAt', occurrence.updated_at,
          'version', occurrence.version
        ) order by occurrence.local_start_date, occurrence.id
      )
      from public.event_occurrences as occurrence
      where occurrence.household_id = p_household_id
    ), '[]'::jsonb),
    'calendarExceptions', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', exception.id,
          'seriesId', exception.series_id,
          'occurrenceId', exception.occurrence_id,
          'exceptionRevisionId', exception.exception_revision_id,
          'cancelled', exception.cancelled,
          'createdAt', exception.created_at,
          'updatedAt', exception.updated_at,
          'version', exception.version
        ) order by exception.created_at, exception.id
      )
      from public.event_occurrence_exceptions as exception
      where exception.household_id = p_household_id
    ), '[]'::jsonb),
    'calendarParticipation', coalesce((
      select pg_catalog.jsonb_agg(
        participation.entry order by participation.series_id,
          participation.scope, participation.member_id
      )
      from (
        select participant.series_id, 'series'::text as scope,
          participant.member_id,
          pg_catalog.jsonb_build_object(
            'scope', 'series',
            'seriesId', participant.series_id,
            'revisionId', null,
            'memberId', participant.member_id,
            'createdAt', participant.created_at
          ) as entry
        from public.event_participants as participant
        where participant.household_id = p_household_id
        union all
        select participant.series_id, 'revision', participant.member_id,
          pg_catalog.jsonb_build_object(
            'scope', 'revision',
            'seriesId', participant.series_id,
            'revisionId', participant.revision_id,
            'memberId', participant.member_id,
            'createdAt', participant.created_at
          )
        from public.event_revision_participants as participant
        where participant.household_id = p_household_id
      ) as participation
    ), '[]'::jsonb),
    'notificationSummary', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'category', summary.category,
          'preferenceCount', summary.preference_count,
          'nativePushEnabledCount', summary.native_push_enabled_count,
          'inAppEnabledCount', summary.in_app_enabled_count
        ) order by summary.category
      )
      from (
        select preference.category,
          pg_catalog.count(*) as preference_count,
          pg_catalog.count(*) filter (where preference.native_push)
            as native_push_enabled_count,
          pg_catalog.count(*) filter (where preference.in_app)
            as in_app_enabled_count
        from public.notification_preferences as preference
        where preference.household_id = p_household_id
        group by preference.category
      ) as summary
    ), '[]'::jsonb),
    'billingSummary', (
      select pg_catalog.jsonb_build_object(
        'activeAssignment', assignment.id is not null,
        'planCode', coalesce(entitlement.plan_code, 'free'),
        'status', coalesce(entitlement.status::text, 'none'),
        'currentPeriodEnd', entitlement.current_period_end,
        'willRenew', coalesce(entitlement.will_renew, false)
      )
      from (select 1) as singleton
      left join public.billing_household_assignments as assignment
        on assignment.household_id = p_household_id
       and assignment.status = 'active'
      left join public.household_entitlements as entitlement
        on entitlement.household_id = p_household_id
      limit 1
    ),
    'privacyRequests', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', request.id,
          'type', request.request_type::text,
          'status', request.status::text,
          'requestedAt', request.requested_at,
          'scheduledFor', request.scheduled_for,
          'completedAt', request.completed_at,
          'failedAt', request.failed_at,
          'cancelledAt', request.cancelled_at
        ) order by request.requested_at, request.id
      )
      from public.privacy_requests as request
      where request.household_id = p_household_id
    ), '[]'::jsonb)
  )
$$;

revoke all on function app_private.household_export_payload(uuid, timestamptz)
  from public, anon, authenticated, service_role;

-- Revision history is immutable during normal product mutations. A completed
-- household deletion may redact only human-authored content after the parent
-- household has already been marked deleted; recurrence identity stays fixed.
create or replace function app_private.reject_chore_revision_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.households as household
    where household.id = old.household_id and household.deleted_at is not null
  ) and new.title = 'Deleted chore'
    and new.description is null
    and (pg_catalog.to_jsonb(new) - array['title', 'description'])
      = (pg_catalog.to_jsonb(old) - array['title', 'description']) then
    return new;
  end if;
  raise exception using
    errcode = '55000', message = 'chore series revisions are immutable';
end;
$$;

create or replace function app_private.reject_event_revision_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.households as household
    where household.id = old.household_id and household.deleted_at is not null
  ) and new.snapshot_title is not distinct from (
      case when old.snapshot_title is null
        then null else 'Deleted event' end
    )
    and new.snapshot_description is null
    and (pg_catalog.to_jsonb(new)
      - array['snapshot_title', 'snapshot_description'])
      = (pg_catalog.to_jsonb(old)
        - array['snapshot_title', 'snapshot_description']) then
    return new;
  end if;
  raise exception using
    errcode = '55000', message = 'calendar event revisions are immutable';
end;
$$;

create or replace function app_private.household_privacy_retry_at(
  p_as_of timestamptz,
  p_attempts integer
)
returns timestamptz
language sql
immutable
set search_path = ''
as $$
  select p_as_of + pg_catalog.make_interval(
    secs => least(
      3600,
      (60 * pg_catalog.power(2::numeric,
        greatest(0, p_attempts - 1)))::integer
    )
  )
$$;

revoke all on function app_private.household_privacy_retry_at(
  timestamptz, integer
) from public, anon, authenticated, service_role;

create or replace function public.recover_expired_household_export_leases(
  p_as_of timestamptz
)
returns table (retry_scheduled integer, dead_letter integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.household_export_jobs%rowtype;
  v_request public.privacy_requests%rowtype;
  v_retry integer := 0;
  v_dead integer := 0;
begin
  if p_as_of is null then
    raise exception using errcode = 'KHP02', message = 'invalid recovery time';
  end if;
  for v_job in
    select job.*
    from app_private.household_export_jobs as job
    where job.processing_status = 'leased'
      and job.lease_expires_at <= p_as_of
    order by job.lease_expires_at, job.privacy_request_id
    for update skip locked
  loop
    select request.* into v_request
    from public.privacy_requests as request
    where request.id = v_job.privacy_request_id for update;
    if v_job.attempts < v_job.max_attempts then
      update app_private.household_export_jobs as job
      set processing_status = 'retry_wait',
          next_attempt_at = p_as_of,
          lease_owner = null, lease_token = null, lease_expires_at = null,
          last_error_code = 'EXPORT_UPLOAD_UNAVAILABLE'
      where job.privacy_request_id = v_job.privacy_request_id;
      v_retry := v_retry + 1;
      insert into app_private.household_privacy_events (
        privacy_request_id, household_id, household_export_id,
        transition, request_status, request_version,
        correlation_id, safe_metadata, occurred_at
      ) values (
        v_request.id, v_request.household_id, v_job.household_export_id,
        'export_retry_scheduled', v_request.status, v_request.version,
        v_request.correlation_id,
        pg_catalog.jsonb_build_object(
          'reasonCode', 'LEASE_EXPIRED', 'attempts', v_job.attempts
        ), p_as_of
      );
    else
      update app_private.household_export_jobs as job
      set processing_status = 'dead_letter', next_attempt_at = null,
          lease_owner = null, lease_token = null, lease_expires_at = null,
          last_error_code = 'EXPORT_ATTEMPTS_EXHAUSTED'
      where job.privacy_request_id = v_job.privacy_request_id;
      update public.privacy_requests as request
      set status = 'failed', failed_at = p_as_of,
          failure_code = 'EXPORT_ATTEMPTS_EXHAUSTED'
      where request.id = v_job.privacy_request_id
      returning request.* into v_request;
      v_dead := v_dead + 1;
      insert into app_private.household_privacy_events (
        privacy_request_id, household_id, household_export_id,
        transition, request_status, request_version,
        correlation_id, safe_metadata, occurred_at
      ) values (
        v_request.id, v_request.household_id, v_job.household_export_id,
        'export_failed', v_request.status, v_request.version,
        v_request.correlation_id,
        pg_catalog.jsonb_build_object(
          'reasonCode', 'LEASE_EXPIRED', 'attempts', v_job.attempts
        ), p_as_of
      );
    end if;
  end loop;
  return query select v_retry, v_dead;
end;
$$;

create or replace function public.claim_household_export_requests(
  p_worker_id uuid,
  p_limit integer,
  p_lease_seconds integer,
  p_as_of timestamptz
)
returns table (
  privacy_request_id uuid,
  household_export_id uuid,
  household_id uuid,
  lease_token uuid,
  lease_expires_at timestamptz,
  attempts integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.household_export_jobs%rowtype;
  v_request public.privacy_requests%rowtype;
  v_token uuid;
begin
  if p_worker_id is null or p_limit not between 1 and 2
    or p_lease_seconds not between 30 and 300 or p_as_of is null then
    raise exception using errcode = 'KHP02', message = 'invalid export claim';
  end if;
  for v_job in
    select job.*
    from app_private.household_export_jobs as job
    join public.privacy_requests as request
      on request.id = job.privacy_request_id
    where job.processing_status in ('queued', 'retry_wait')
      and job.next_attempt_at <= p_as_of
      and request.status in ('queued', 'verifying', 'processing')
    order by job.next_attempt_at, job.privacy_request_id
    for update of job skip locked
    limit p_limit
  loop
    v_token := extensions.gen_random_uuid();
    update app_private.household_export_jobs as job
    set processing_status = 'leased', attempts = job.attempts + 1,
        next_attempt_at = null, lease_owner = p_worker_id,
        lease_token = v_token,
        lease_expires_at = p_as_of + pg_catalog.make_interval(
          secs => p_lease_seconds
        ),
        last_error_code = null
    where job.privacy_request_id = v_job.privacy_request_id
    returning job.* into v_job;
    update public.privacy_requests as request
    set status = 'processing',
        processing_started_at = coalesce(
          request.processing_started_at, p_as_of
        ),
        failure_code = null
    where request.id = v_job.privacy_request_id
    returning request.* into v_request;
    insert into app_private.household_privacy_events (
      privacy_request_id, household_id, household_export_id,
      transition, request_status, request_version,
      correlation_id, safe_metadata, occurred_at
    ) values (
      v_request.id, v_request.household_id, v_job.household_export_id,
      'export_claimed', v_request.status, v_request.version,
      v_request.correlation_id,
      pg_catalog.jsonb_build_object('attempts', v_job.attempts), p_as_of
    );
    return query select
      v_job.privacy_request_id, v_job.household_export_id,
      v_job.household_id, v_job.lease_token,
      v_job.lease_expires_at, v_job.attempts;
  end loop;
end;
$$;

create or replace function public.load_household_export_package(
  p_request_id uuid,
  p_lease_token uuid,
  p_as_of timestamptz
)
returns table (result jsonb)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_request public.privacy_requests%rowtype;
  v_payload jsonb;
begin
  if p_request_id is null or p_lease_token is null or p_as_of is null then
    raise exception using errcode = 'KHP02', message = 'invalid package load';
  end if;
  perform 1
  from app_private.household_export_jobs as job
  where job.privacy_request_id = p_request_id
    and job.processing_status = 'leased'
    and job.lease_token = p_lease_token
    and job.lease_expires_at > p_as_of;
  if not found then
    raise exception using errcode = 'KHP16', message = 'export lease invalid';
  end if;
  select request.* into v_request
  from public.privacy_requests as request
  where request.id = p_request_id
    and request.request_type = 'export_household'
    and request.status = 'processing';
  if not found then
    raise exception using errcode = 'KHP16', message = 'export precondition failed';
  end if;
  if not app_private.household_privacy_active_owner(
    v_request.auth_user_id, v_request.household_id
  ) then
    raise exception using errcode = 'KHP03', message = 'Owner authorization changed';
  end if;
  select app_private.household_export_payload(
    v_request.household_id, p_as_of
  ) into v_payload;
  if v_payload->'household' is null or v_payload->'household' = 'null'::jsonb then
    raise exception using errcode = 'KHP17', message = 'household already deleted';
  end if;
  return query select v_payload;
end;
$$;

create or replace function public.complete_household_export_request(
  p_request_id uuid,
  p_lease_token uuid,
  p_machine_object_key text,
  p_human_object_key text,
  p_machine_checksum_sha256 text,
  p_human_checksum_sha256 text,
  p_machine_size_bytes bigint,
  p_human_size_bytes bigint,
  p_as_of timestamptz
)
returns table (result jsonb)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.household_export_jobs%rowtype;
  v_request public.privacy_requests%rowtype;
  v_export public.household_exports%rowtype;
  v_config app_private.privacy_runtime_config%rowtype;
  v_expiry timestamptz;
begin
  if p_request_id is null or p_lease_token is null or p_as_of is null
    or p_machine_object_key !~
      '^household-exports/[0-9a-f-]{36}/kinflow-household\.json$'
    or p_human_object_key !~
      '^household-exports/[0-9a-f-]{36}/kinflow-household\.txt$'
    or pg_catalog.split_part(p_machine_object_key, '/', 2)
      <> pg_catalog.split_part(p_human_object_key, '/', 2)
    or p_machine_checksum_sha256 !~ '^[0-9a-f]{64}$'
    or p_human_checksum_sha256 !~ '^[0-9a-f]{64}$'
    or p_machine_size_bytes not between 1 and 20971520
    or p_human_size_bytes not between 1 and 20971520 then
    raise exception using errcode = 'KHP02', message = 'invalid export completion';
  end if;
  select job.* into v_job
  from app_private.household_export_jobs as job
  where job.privacy_request_id = p_request_id for update;
  if not found or v_job.processing_status <> 'leased'
    or v_job.lease_token <> p_lease_token
    or v_job.lease_expires_at <= p_as_of then
    raise exception using errcode = 'KHP16', message = 'export lease invalid';
  end if;
  select request.* into v_request
  from public.privacy_requests as request
  where request.id = p_request_id and request.status = 'processing'
  for update;
  if not found then
    raise exception using errcode = 'KHP16', message = 'export precondition failed';
  end if;
  if not app_private.household_privacy_active_owner(
    v_request.auth_user_id, v_request.household_id
  ) then
    raise exception using errcode = 'KHP03', message = 'Owner authorization changed';
  end if;
  select config.* into v_config
  from app_private.privacy_runtime_config as config
  where config.singleton for share;
  v_expiry := p_as_of + pg_catalog.make_interval(
    secs => v_config.household_export_artifact_ttl_seconds
  );
  update public.household_exports as export
  set machine_object_key = p_machine_object_key,
      human_object_key = p_human_object_key,
      machine_checksum_sha256 = p_machine_checksum_sha256,
      human_checksum_sha256 = p_human_checksum_sha256,
      machine_size_bytes = p_machine_size_bytes,
      human_size_bytes = p_human_size_bytes,
      artifact_expires_at = v_expiry
  where export.id = v_job.household_export_id
  returning export.* into v_export;
  update app_private.household_export_jobs as job
  set processing_status = 'succeeded', next_attempt_at = null,
      lease_owner = null, lease_token = null, lease_expires_at = null,
      last_error_code = null
  where job.privacy_request_id = p_request_id;
  update public.privacy_requests as request
  set status = 'completed', completed_at = p_as_of, failure_code = null
  where request.id = p_request_id
  returning request.* into v_request;
  insert into app_private.household_export_purge_jobs (
    household_export_id, processing_status, attempts,
    next_attempt_at, created_at, updated_at
  ) values (
    v_export.id, 'queued', 0, v_expiry, p_as_of, p_as_of
  );
  insert into app_private.household_privacy_events (
    privacy_request_id, household_id, household_export_id,
    transition, request_status, request_version,
    correlation_id, safe_metadata, occurred_at
  ) values (
    v_request.id, v_request.household_id, v_export.id,
    'export_completed', v_request.status, v_request.version,
    v_request.correlation_id,
    pg_catalog.jsonb_build_object(
      'machineSizeBytes', p_machine_size_bytes,
      'humanSizeBytes', p_human_size_bytes,
      'artifactTtlSeconds', v_config.household_export_artifact_ttl_seconds
    ),
    p_as_of
  );
  return query select app_private.household_privacy_status_payload(
    v_request.auth_user_id, p_request_id
  );
end;
$$;

create or replace function public.fail_household_export_request(
  p_request_id uuid,
  p_lease_token uuid,
  p_error_code text,
  p_retryable boolean,
  p_as_of timestamptz
)
returns table (result jsonb)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.household_export_jobs%rowtype;
  v_request public.privacy_requests%rowtype;
  v_terminal_code text;
begin
  if p_request_id is null or p_lease_token is null or p_retryable is null
    or p_as_of is null
    or p_error_code not in (
      'OWNER_AUTHORIZATION_CHANGED', 'HOUSEHOLD_ALREADY_DELETED',
      'EXPORT_BUILD_UNAVAILABLE', 'EXPORT_UPLOAD_UNAVAILABLE',
      'EXPORT_SIZE_LIMIT_EXCEEDED', 'PROCESSING_PRECONDITION_FAILED'
    ) then
    raise exception using errcode = 'KHP02', message = 'invalid export failure';
  end if;
  select job.* into v_job
  from app_private.household_export_jobs as job
  where job.privacy_request_id = p_request_id for update;
  if not found or v_job.processing_status <> 'leased'
    or v_job.lease_token <> p_lease_token then
    raise exception using errcode = 'KHP16', message = 'export lease invalid';
  end if;
  select request.* into v_request
  from public.privacy_requests as request
  where request.id = p_request_id and request.status = 'processing'
  for update;
  if not found then
    raise exception using errcode = 'KHP16', message = 'export precondition failed';
  end if;

  if p_retryable and v_job.attempts < v_job.max_attempts then
    update app_private.household_export_jobs as job
    set processing_status = 'retry_wait',
        next_attempt_at = app_private.household_privacy_retry_at(
          p_as_of, job.attempts
        ),
        lease_owner = null, lease_token = null, lease_expires_at = null,
        last_error_code = p_error_code
    where job.privacy_request_id = p_request_id;
    insert into app_private.household_privacy_events (
      privacy_request_id, household_id, household_export_id,
      transition, request_status, request_version,
      correlation_id, safe_metadata, occurred_at
    ) values (
      v_request.id, v_request.household_id, v_job.household_export_id,
      'export_retry_scheduled', v_request.status, v_request.version,
      v_request.correlation_id,
      pg_catalog.jsonb_build_object(
        'reasonCode', p_error_code, 'attempts', v_job.attempts
      ), p_as_of
    );
  else
    v_terminal_code := case
      when p_retryable and v_job.attempts >= v_job.max_attempts
        then 'EXPORT_ATTEMPTS_EXHAUSTED'
      else p_error_code end;
    update app_private.household_export_jobs as job
    set processing_status = 'dead_letter', next_attempt_at = null,
        lease_owner = null, lease_token = null, lease_expires_at = null,
        last_error_code = v_terminal_code
    where job.privacy_request_id = p_request_id;
    update public.privacy_requests as request
    set status = 'failed', failed_at = p_as_of,
        failure_code = v_terminal_code
    where request.id = p_request_id
    returning request.* into v_request;
    insert into app_private.household_privacy_events (
      privacy_request_id, household_id, household_export_id,
      transition, request_status, request_version,
      correlation_id, safe_metadata, occurred_at
    ) values (
      v_request.id, v_request.household_id, v_job.household_export_id,
      'export_failed', v_request.status, v_request.version,
      v_request.correlation_id,
      pg_catalog.jsonb_build_object(
        'reasonCode', v_terminal_code, 'attempts', v_job.attempts
      ), p_as_of
    );
  end if;
  return query select app_private.household_privacy_status_payload(
    v_request.auth_user_id, p_request_id
  );
end;
$$;

create or replace function public.recover_expired_household_export_purge_leases(
  p_as_of timestamptz
)
returns table (retry_scheduled integer, dead_letter integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.household_export_purge_jobs%rowtype;
  v_export public.household_exports%rowtype;
  v_request public.privacy_requests%rowtype;
  v_retry integer := 0;
  v_dead integer := 0;
begin
  if p_as_of is null then
    raise exception using errcode = 'KHP02', message = 'invalid purge recovery time';
  end if;
  for v_job in
    select job.*
    from app_private.household_export_purge_jobs as job
    where job.processing_status = 'leased'
      and job.lease_expires_at <= p_as_of
    order by job.lease_expires_at, job.household_export_id
    for update skip locked
  loop
    select export.* into v_export
    from public.household_exports as export
    where export.id = v_job.household_export_id;
    select request.* into v_request
    from public.privacy_requests as request
    where request.id = v_export.privacy_request_id;
    if v_job.attempts < v_job.max_attempts then
      update app_private.household_export_purge_jobs as job
      set processing_status = 'retry_wait', next_attempt_at = p_as_of,
          lease_owner = null, lease_token = null, lease_expires_at = null,
          last_error_code = 'EXPORT_PURGE_UNAVAILABLE'
      where job.household_export_id = v_job.household_export_id;
      v_retry := v_retry + 1;
      insert into app_private.household_privacy_events (
        privacy_request_id, household_id, household_export_id,
        transition, request_status, request_version,
        correlation_id, safe_metadata, occurred_at
      ) values (
        v_request.id, v_request.household_id, v_export.id,
        'purge_retry_scheduled', v_request.status, v_request.version,
        v_request.correlation_id,
        pg_catalog.jsonb_build_object(
          'reasonCode', 'LEASE_EXPIRED', 'attempts', v_job.attempts
        ), p_as_of
      );
    else
      update app_private.household_export_purge_jobs as job
      set processing_status = 'dead_letter',
          lease_owner = null, lease_token = null, lease_expires_at = null,
          last_error_code = 'EXPORT_PURGE_ATTEMPTS_EXHAUSTED'
      where job.household_export_id = v_job.household_export_id;
      v_dead := v_dead + 1;
      insert into app_private.household_privacy_events (
        privacy_request_id, household_id, household_export_id,
        transition, request_status, request_version,
        correlation_id, safe_metadata, occurred_at
      ) values (
        v_request.id, v_request.household_id, v_export.id,
        'purge_failed', v_request.status, v_request.version,
        v_request.correlation_id,
        pg_catalog.jsonb_build_object(
          'reasonCode', 'EXPORT_PURGE_ATTEMPTS_EXHAUSTED',
          'attempts', v_job.attempts
        ), p_as_of
      );
    end if;
  end loop;
  return query select v_retry, v_dead;
end;
$$;

create or replace function public.claim_household_export_purge_jobs(
  p_worker_id uuid,
  p_limit integer,
  p_lease_seconds integer,
  p_as_of timestamptz
)
returns table (
  household_export_id uuid,
  privacy_request_id uuid,
  machine_object_key text,
  human_object_key text,
  lease_token uuid,
  lease_expires_at timestamptz,
  attempts integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.household_export_purge_jobs%rowtype;
  v_export public.household_exports%rowtype;
  v_request public.privacy_requests%rowtype;
  v_token uuid;
begin
  if p_worker_id is null or p_limit not between 1 and 10
    or p_lease_seconds not between 30 and 120 or p_as_of is null then
    raise exception using errcode = 'KHP02', message = 'invalid purge claim';
  end if;
  for v_job in
    select job.*
    from app_private.household_export_purge_jobs as job
    join public.household_exports as export
      on export.id = job.household_export_id
    where job.processing_status in ('queued', 'retry_wait')
      and job.next_attempt_at <= p_as_of
      and export.machine_object_key is not null
      and export.human_object_key is not null
      and export.purged_at is null
    order by job.next_attempt_at, job.household_export_id
    for update of job skip locked
    limit p_limit
  loop
    v_token := extensions.gen_random_uuid();
    update app_private.household_export_purge_jobs as job
    set processing_status = 'leased', attempts = job.attempts + 1,
        lease_owner = p_worker_id, lease_token = v_token,
        lease_expires_at = p_as_of + pg_catalog.make_interval(
          secs => p_lease_seconds
        ), last_error_code = null
    where job.household_export_id = v_job.household_export_id
    returning job.* into v_job;
    select export.* into v_export
    from public.household_exports as export
    where export.id = v_job.household_export_id;
    select request.* into v_request
    from public.privacy_requests as request
    where request.id = v_export.privacy_request_id;
    insert into app_private.household_privacy_events (
      privacy_request_id, household_id, household_export_id,
      transition, request_status, request_version,
      correlation_id, safe_metadata, occurred_at
    ) values (
      v_request.id, v_request.household_id, v_export.id,
      'purge_claimed', v_request.status, v_request.version,
      v_request.correlation_id,
      pg_catalog.jsonb_build_object('attempts', v_job.attempts), p_as_of
    );
    return query select
      v_export.id, v_request.id, v_export.machine_object_key,
      v_export.human_object_key, v_job.lease_token,
      v_job.lease_expires_at, v_job.attempts;
  end loop;
end;
$$;

create or replace function public.complete_household_export_purge_job(
  p_household_export_id uuid,
  p_lease_token uuid,
  p_as_of timestamptz
)
returns table (result jsonb)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.household_export_purge_jobs%rowtype;
  v_export public.household_exports%rowtype;
  v_request public.privacy_requests%rowtype;
begin
  if p_household_export_id is null or p_lease_token is null or p_as_of is null then
    raise exception using errcode = 'KHP02', message = 'invalid purge completion';
  end if;
  select job.* into v_job
  from app_private.household_export_purge_jobs as job
  where job.household_export_id = p_household_export_id for update;
  if not found or v_job.processing_status <> 'leased'
    or v_job.lease_token <> p_lease_token
    or v_job.lease_expires_at <= p_as_of then
    raise exception using errcode = 'KHP16', message = 'purge lease invalid';
  end if;
  select export.* into v_export
  from public.household_exports as export
  where export.id = p_household_export_id for update;
  if not found or v_export.machine_object_key is null
    or v_export.human_object_key is null or v_export.purged_at is not null then
    raise exception using errcode = 'KHP16', message = 'purge precondition failed';
  end if;
  select request.* into v_request
  from public.privacy_requests as request
  where request.id = v_export.privacy_request_id;
  update app_private.household_export_download_grants as download_grant
  set revoked_at = p_as_of
  where download_grant.household_export_id = v_export.id
    and download_grant.consumed_at is null and download_grant.revoked_at is null;
  update public.household_exports as export
  set machine_object_key = null, human_object_key = null,
      purged_at = greatest(p_as_of, export.created_at)
  where export.id = p_household_export_id
  returning export.* into v_export;
  update app_private.household_export_purge_jobs as job
  set processing_status = 'succeeded',
      lease_owner = null, lease_token = null, lease_expires_at = null,
      last_error_code = null
  where job.household_export_id = p_household_export_id;
  insert into app_private.household_privacy_events (
    privacy_request_id, household_id, household_export_id,
    transition, request_status, request_version,
    correlation_id, safe_metadata, occurred_at
  ) values (
    v_request.id, v_request.household_id, v_export.id,
    'purged', v_request.status, v_request.version,
    v_request.correlation_id,
    pg_catalog.jsonb_build_object('attempts', v_job.attempts), p_as_of
  );
  return query select app_private.household_privacy_status_payload(
    v_request.auth_user_id, v_request.id
  );
end;
$$;

create or replace function public.fail_household_export_purge_job(
  p_household_export_id uuid,
  p_lease_token uuid,
  p_error_code text,
  p_retryable boolean,
  p_as_of timestamptz
)
returns table (result jsonb)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.household_export_purge_jobs%rowtype;
  v_export public.household_exports%rowtype;
  v_request public.privacy_requests%rowtype;
  v_terminal_code text;
begin
  if p_household_export_id is null or p_lease_token is null
    or p_retryable is null or p_as_of is null
    or p_error_code not in (
      'EXPORT_PURGE_UNAVAILABLE', 'PROCESSING_PRECONDITION_FAILED'
    ) then
    raise exception using errcode = 'KHP02', message = 'invalid purge failure';
  end if;
  select job.* into v_job
  from app_private.household_export_purge_jobs as job
  where job.household_export_id = p_household_export_id for update;
  if not found or v_job.processing_status <> 'leased'
    or v_job.lease_token <> p_lease_token then
    raise exception using errcode = 'KHP16', message = 'purge lease invalid';
  end if;
  select export.* into v_export
  from public.household_exports as export
  where export.id = p_household_export_id;
  select request.* into v_request
  from public.privacy_requests as request
  where request.id = v_export.privacy_request_id;
  if p_retryable and v_job.attempts < v_job.max_attempts then
    update app_private.household_export_purge_jobs as job
    set processing_status = 'retry_wait',
        next_attempt_at = app_private.household_privacy_retry_at(
          p_as_of, job.attempts
        ), lease_owner = null, lease_token = null, lease_expires_at = null,
        last_error_code = p_error_code
    where job.household_export_id = p_household_export_id;
    insert into app_private.household_privacy_events (
      privacy_request_id, household_id, household_export_id,
      transition, request_status, request_version,
      correlation_id, safe_metadata, occurred_at
    ) values (
      v_request.id, v_request.household_id, v_export.id,
      'purge_retry_scheduled', v_request.status, v_request.version,
      v_request.correlation_id,
      pg_catalog.jsonb_build_object(
        'reasonCode', p_error_code, 'attempts', v_job.attempts
      ), p_as_of
    );
  else
    v_terminal_code := case
      when p_retryable and v_job.attempts >= v_job.max_attempts
        then 'EXPORT_PURGE_ATTEMPTS_EXHAUSTED'
      else p_error_code end;
    update app_private.household_export_purge_jobs as job
    set processing_status = 'dead_letter',
        lease_owner = null, lease_token = null, lease_expires_at = null,
        last_error_code = v_terminal_code
    where job.household_export_id = p_household_export_id;
    insert into app_private.household_privacy_events (
      privacy_request_id, household_id, household_export_id,
      transition, request_status, request_version,
      correlation_id, safe_metadata, occurred_at
    ) values (
      v_request.id, v_request.household_id, v_export.id,
      'purge_failed', v_request.status, v_request.version,
      v_request.correlation_id,
      pg_catalog.jsonb_build_object(
        'reasonCode', v_terminal_code, 'attempts', v_job.attempts
      ), p_as_of
    );
  end if;
  return query select app_private.household_privacy_status_payload(
    v_request.auth_user_id, v_request.id
  );
end;
$$;

-- Household deletion erases endpoint material even when a device was already
-- revoked for another reason. The second rewrite is deliberately audit-silent;
-- an active endpoint still produces the normal immutable revoked transition.
alter table public.notification_endpoints
  drop constraint notification_endpoints_revocation_reason_check;
alter table public.notification_endpoints
  add constraint notification_endpoints_revocation_reason_check check (
    revocation_reason is null
    or revocation_reason in (
      'client_revoked', 'token_reassigned', 'provider_unregistered',
      'provider_invalid_argument', 'membership_removed',
      'permission_revoked', 'rollback_disabled', 'account_deleted',
      'household_deleted'
    )
  );

alter table app_private.notification_endpoint_events
  drop constraint notification_endpoint_events_reason_code_check;
alter table app_private.notification_endpoint_events
  add constraint notification_endpoint_events_reason_code_check check (
    reason_code is null
    or reason_code in (
      'client_revoked', 'token_reassigned', 'provider_unregistered',
      'provider_invalid_argument', 'membership_removed',
      'permission_revoked', 'rollback_disabled', 'account_deleted',
      'household_deleted'
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
    and new.revocation_reason in ('account_deleted', 'household_deleted') then
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
    endpoint_id, transition, reason_code, endpoint_version, occurred_at
  ) values (
    new.id, v_transition, v_reason_code, new.version, new.updated_at
  );
  return new;
end;
$$;

create or replace function public.recover_expired_household_deletion_leases(
  p_as_of timestamptz
)
returns table (retry_scheduled integer, dead_letter integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.household_deletion_jobs%rowtype;
  v_request public.privacy_requests%rowtype;
  v_retry integer := 0;
  v_dead integer := 0;
begin
  if p_as_of is null then
    raise exception using errcode = 'KHP02', message = 'invalid deletion recovery time';
  end if;
  for v_job in
    select job.*
    from app_private.household_deletion_jobs as job
    where job.processing_status = 'leased'
      and job.lease_expires_at <= p_as_of
    order by job.lease_expires_at, job.privacy_request_id
    for update skip locked
  loop
    select request.* into v_request
    from public.privacy_requests as request
    where request.id = v_job.privacy_request_id for update;
    if v_job.attempts < v_job.max_attempts then
      update app_private.household_deletion_jobs as job
      set processing_status = 'retry_wait', next_attempt_at = p_as_of,
          lease_owner = null, lease_token = null, lease_expires_at = null,
          last_error_code = 'HOUSEHOLD_REDACTION_UNAVAILABLE'
      where job.privacy_request_id = v_job.privacy_request_id;
      update public.privacy_requests as request
      set failure_code = 'HOUSEHOLD_REDACTION_UNAVAILABLE'
      where request.id = v_job.privacy_request_id
      returning request.* into v_request;
      v_retry := v_retry + 1;
      insert into app_private.household_privacy_events (
        privacy_request_id, household_id, transition, request_status,
        request_version, correlation_id, safe_metadata, occurred_at
      ) values (
        v_request.id, v_request.household_id, 'deletion_retry_scheduled',
        v_request.status, v_request.version, v_request.correlation_id,
        pg_catalog.jsonb_build_object(
          'reasonCode', 'LEASE_EXPIRED', 'attempts', v_job.attempts
        ), p_as_of
      );
    else
      update app_private.household_deletion_jobs as job
      set processing_status = 'dead_letter', next_attempt_at = null,
          lease_owner = null, lease_token = null, lease_expires_at = null,
          last_error_code = 'HOUSEHOLD_REDACTION_ATTEMPTS_EXHAUSTED'
      where job.privacy_request_id = v_job.privacy_request_id;
      update public.privacy_requests as request
      set status = 'failed', failed_at = p_as_of,
          failure_code = 'HOUSEHOLD_REDACTION_ATTEMPTS_EXHAUSTED'
      where request.id = v_job.privacy_request_id
      returning request.* into v_request;
      v_dead := v_dead + 1;
      insert into app_private.household_privacy_events (
        privacy_request_id, household_id, transition, request_status,
        request_version, correlation_id, safe_metadata, occurred_at
      ) values (
        v_request.id, v_request.household_id, 'deletion_failed',
        v_request.status, v_request.version, v_request.correlation_id,
        pg_catalog.jsonb_build_object(
          'reasonCode', 'HOUSEHOLD_REDACTION_ATTEMPTS_EXHAUSTED',
          'attempts', v_job.attempts
        ), p_as_of
      );
    end if;
  end loop;
  return query select v_retry, v_dead;
end;
$$;

create or replace function public.claim_household_deletion_requests(
  p_worker_id uuid,
  p_limit integer,
  p_lease_seconds integer,
  p_as_of timestamptz
)
returns table (
  privacy_request_id uuid,
  household_id uuid,
  lease_token uuid,
  lease_expires_at timestamptz,
  attempts integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.household_deletion_jobs%rowtype;
  v_request public.privacy_requests%rowtype;
  v_household public.households%rowtype;
  v_hold_active boolean;
  v_token uuid;
  v_terminal_code text;
begin
  if p_worker_id is null or p_limit not between 1 and 5
    or p_lease_seconds not between 30 and 180 or p_as_of is null then
    raise exception using errcode = 'KHP02', message = 'invalid deletion claim';
  end if;
  for v_job in
    select job.*
    from app_private.household_deletion_jobs as job
    join public.privacy_requests as request
      on request.id = job.privacy_request_id
    where job.processing_status in ('queued', 'retry_wait')
      and job.next_attempt_at <= p_as_of
      and request.status in ('queued', 'processing')
    order by job.next_attempt_at, job.privacy_request_id
    for update of job skip locked
    limit p_limit
  loop
    select request.* into v_request
    from public.privacy_requests as request
    where request.id = v_job.privacy_request_id for update;
    select household.* into v_household
    from public.households as household
    where household.id = v_job.household_id for update;
    select coalesce(pg_catalog.bool_or(hold.active), false)
    into v_hold_active
    from app_private.household_deletion_retention_holds as hold
    where hold.household_id = v_job.household_id;

    if v_hold_active and v_job.attempts = 0 then
      update app_private.household_deletion_jobs as job
      set processing_status = 'retention_hold', next_attempt_at = null
      where job.privacy_request_id = v_job.privacy_request_id;
      continue;
    end if;

    v_terminal_code := case
      when v_household.deleted_at is not null then 'HOUSEHOLD_ALREADY_DELETED'
      when not app_private.household_privacy_active_owner(
        v_request.auth_user_id, v_request.household_id
      ) then 'OWNER_AUTHORIZATION_CHANGED'
      else null end;
    if v_terminal_code is not null then
      update app_private.household_deletion_jobs as job
      set processing_status = 'dead_letter', attempts = job.attempts + 1,
          next_attempt_at = null, lease_owner = null, lease_token = null,
          lease_expires_at = null, last_error_code = v_terminal_code
      where job.privacy_request_id = v_job.privacy_request_id;
      update public.privacy_requests as request
      set status = 'failed',
          processing_started_at = coalesce(
            request.processing_started_at, p_as_of
          ), failed_at = p_as_of, failure_code = v_terminal_code
      where request.id = v_job.privacy_request_id
      returning request.* into v_request;
      insert into app_private.household_privacy_events (
        privacy_request_id, household_id, transition, request_status,
        request_version, correlation_id, safe_metadata, occurred_at
      ) values (
        v_request.id, v_request.household_id, 'deletion_failed',
        v_request.status, v_request.version, v_request.correlation_id,
        pg_catalog.jsonb_build_object(
          'reasonCode', v_terminal_code, 'attempts', v_job.attempts + 1
        ), p_as_of
      );
      continue;
    end if;

    v_token := extensions.gen_random_uuid();
    update app_private.household_deletion_jobs as job
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
        processing_started_at = coalesce(
          request.processing_started_at, p_as_of
        ), failure_code = null
    where request.id = v_job.privacy_request_id
    returning request.* into v_request;
    insert into app_private.household_privacy_events (
      privacy_request_id, household_id, transition, request_status,
      request_version, correlation_id, safe_metadata, occurred_at
    ) values (
      v_request.id, v_request.household_id, 'deletion_claimed',
      v_request.status, v_request.version, v_request.correlation_id,
      pg_catalog.jsonb_build_object('attempts', v_job.attempts), p_as_of
    );
    return query select
      v_request.id, v_request.household_id, v_job.lease_token,
      v_job.lease_expires_at, v_job.attempts;
  end loop;
end;
$$;

create or replace function public.complete_household_deletion_request(
  p_request_id uuid,
  p_lease_token uuid,
  p_as_of timestamptz
)
returns table (result jsonb)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.household_deletion_jobs%rowtype;
  v_request public.privacy_requests%rowtype;
  v_household public.households%rowtype;
  v_member public.household_members%rowtype;
  v_assignment public.billing_household_assignments%rowtype;
  v_hold_active boolean;
  v_member_count integer := 0;
  v_endpoint_count integer := 0;
  v_invite_count integer := 0;
  v_preference_count integer := 0;
  v_inbox_count integer := 0;
  v_chore_series_count integer := 0;
  v_chore_revision_count integer := 0;
  v_event_series_count integer := 0;
  v_event_revision_count integer := 0;
  v_billing_assignment_count integer := 0;
  v_export_count integer := 0;
begin
  if p_request_id is null or p_lease_token is null or p_as_of is null then
    raise exception using errcode = 'KHP02', message = 'invalid deletion completion';
  end if;
  select job.* into v_job
  from app_private.household_deletion_jobs as job
  where job.privacy_request_id = p_request_id for update;
  if not found or v_job.processing_status <> 'leased'
    or v_job.lease_token <> p_lease_token
    or v_job.lease_expires_at <= p_as_of then
    raise exception using errcode = 'KHP16', message = 'deletion lease invalid';
  end if;
  select request.* into v_request
  from public.privacy_requests as request
  where request.id = p_request_id
    and request.request_type = 'delete_household'
    and request.status = 'processing'
  for update;
  if not found then
    raise exception using errcode = 'KHP16', message = 'deletion precondition failed';
  end if;
  select household.* into v_household
  from public.households as household
  where household.id = v_request.household_id for update;
  if not found or v_household.deleted_at is not null then
    raise exception using errcode = 'KHP17', message = 'household already deleted';
  end if;
  perform 1
  from public.household_members as owner_member
  where owner_member.household_id = v_household.id
    and owner_member.id = v_household.owner_member_id
  for update;
  if not app_private.household_privacy_active_owner(
    v_request.auth_user_id, v_request.household_id
  ) then
    raise exception using errcode = 'KHP03', message = 'Owner authorization changed';
  end if;
  select coalesce(pg_catalog.bool_or(hold.active), false)
  into v_hold_active
  from app_private.household_deletion_retention_holds as hold
  where hold.household_id = v_request.household_id;
  if v_hold_active then
    raise exception using errcode = 'KHP16', message = 'retention hold active';
  end if;

  -- Marking the aggregate deleted first closes every RLS helper to stale JWTs.
  update public.households as household
  set name = 'Deleted household', created_by_user_id = null,
      deleted_at = greatest(p_as_of, household.created_at)
  where household.id = v_request.household_id;

  -- Move each user's active selector to another still-active membership before
  -- tombstoning this household's membership row.
  for v_member in
    select member.*
    from public.household_members as member
    where member.household_id = v_request.household_id
      and member.removed_at is null
    order by member.joined_at, member.id
    for update
  loop
    perform app_private.reassign_active_household_after_removal(
      v_member.auth_user_id, v_member.household_id, v_member.id
    );
  end loop;
  delete from public.user_active_households as active_household
  where active_household.household_id = v_request.household_id;

  update public.notification_endpoints as endpoint
  set token_ciphertext = pg_catalog.decode(pg_catalog.repeat('00', 29), 'hex'),
      token_fingerprint = extensions.digest(
        pg_catalog.convert_to(endpoint.id::text || ':household-deleted', 'UTF8'),
        'sha256'
      ),
      revocation_secret_hash = extensions.digest(
        pg_catalog.convert_to(endpoint.id::text || ':proof-erased', 'UTF8'),
        'sha256'
      ),
      permission_state = 'denied',
      revoked_at = coalesce(
        endpoint.revoked_at,
        greatest(p_as_of, endpoint.created_at, endpoint.last_seen_at)
      ),
      revocation_reason = 'household_deleted'
  where endpoint.household_id = v_request.household_id;
  get diagnostics v_endpoint_count = row_count;

  update public.household_invites as invite
  set status = 'revoked',
      revoked_at = greatest(p_as_of, invite.created_at)
  where invite.household_id = v_request.household_id
    and invite.status = 'active';
  get diagnostics v_invite_count = row_count;

  update public.notification_preferences as preference
  set native_push = false, web_push = false, email = false, in_app = false,
      quiet_start = null, quiet_end = null
  where preference.household_id = v_request.household_id;
  get diagnostics v_preference_count = row_count;

  update public.notification_inbox_items as inbox
  set cancelled_at = greatest(
        p_as_of, inbox.created_at, inbox.updated_at
      ),
      cancellation_reason = 'state_inactive',
      updated_at = greatest(
        p_as_of, inbox.created_at, inbox.updated_at
      )
  where inbox.household_id = v_request.household_id
    and inbox.cancelled_at is null;
  get diagnostics v_inbox_count = row_count;

  -- Previously completed shared archives cannot outlive household access.
  update public.household_exports as export
  set revoked_at = coalesce(
    export.revoked_at, greatest(p_as_of, export.created_at)
  )
  where export.household_id = v_request.household_id
    and export.purged_at is null;
  get diagnostics v_export_count = row_count;
  update app_private.household_export_download_grants as download_grant
  set revoked_at = p_as_of
  where download_grant.household_export_id in (
      select export.id from public.household_exports as export
      where export.household_id = v_request.household_id
    )
    and download_grant.consumed_at is null and download_grant.revoked_at is null;
  update app_private.household_export_purge_jobs as purge_job
  set processing_status = case
        when purge_job.processing_status in ('queued', 'retry_wait')
          then 'queued'
        else purge_job.processing_status end,
      attempts = case when purge_job.processing_status = 'retry_wait'
        then 0 else purge_job.attempts end,
      next_attempt_at = case
        when purge_job.processing_status in ('queued', 'retry_wait')
          then p_as_of
        else purge_job.next_attempt_at end,
      last_error_code = case
        when purge_job.processing_status in ('queued', 'retry_wait')
          then null
        else purge_job.last_error_code end
  where purge_job.household_export_id in (
    select export.id from public.household_exports as export
    where export.household_id = v_request.household_id
  );

  update public.chore_series as series
  set title = 'Deleted chore', description = null,
      created_by_user_id = null,
      deleted_at = coalesce(
        series.deleted_at, greatest(p_as_of, series.created_at)
      )
  where series.household_id = v_request.household_id;
  get diagnostics v_chore_series_count = row_count;
  update public.chore_series_revisions as revision
  set title = 'Deleted chore', description = null
  where revision.household_id = v_request.household_id;
  get diagnostics v_chore_revision_count = row_count;

  update public.event_series as series
  set title = 'Deleted event', description = null,
      created_by_user_id = null,
      deleted_at = coalesce(
        series.deleted_at, greatest(p_as_of, series.created_at)
      )
  where series.household_id = v_request.household_id;
  get diagnostics v_event_series_count = row_count;
  update public.event_series_revisions as revision
  set snapshot_title = case when revision.snapshot_title is null
        then null else 'Deleted event' end,
      snapshot_description = null
  where revision.household_id = v_request.household_id;
  get diagnostics v_event_revision_count = row_count;

  update public.household_members as member
  set display_name = 'Deleted member', avatar_key = null,
      created_by_user_id = null,
      removed_at = coalesce(
        member.removed_at,
        greatest(p_as_of, member.joined_at, member.created_at)
      )
  where member.household_id = v_request.household_id;
  get diagnostics v_member_count = row_count;

  update public.household_entitlements as entitlement
  set assignment_id = null, billing_owner_user_id = null,
      plan_code = 'free', status = 'none', source = 'none',
      product_id = null, current_period_start = null,
      current_period_end = null, will_renew = false,
      features = coalesce((
        select catalog.feature_limits
        from public.plan_catalog as catalog
        where catalog.plan_code = 'free'
      ), '{}'::jsonb),
      provider_updated_at = null, verified_at = p_as_of
  where entitlement.household_id = v_request.household_id;

  select assignment.* into v_assignment
  from public.billing_household_assignments as assignment
  where assignment.household_id = v_request.household_id
    and assignment.status = 'active'
  for update;
  if found then
    update app_private.billing_assignment_intents as intent
    set lifecycle_state = 'released',
        resolved_at = greatest(p_as_of, intent.created_at)
    where intent.assignment_id = v_assignment.id
      and intent.lifecycle_state = 'prepared';
    update public.billing_household_assignments as assignment
    set status = 'ended',
        ended_at = greatest(p_as_of, assignment.assigned_at)
    where assignment.id = v_assignment.id;
    get diagnostics v_billing_assignment_count = row_count;
    insert into app_private.billing_assignment_transitions (
      assignment_id, action, actor_kind, actor_user_id,
      source_household_id, target_household_id,
      previous_binding_state, next_binding_state,
      reason_code, correlation_id, occurred_at
    ) values (
      v_assignment.id, 'released', 'system', null,
      v_assignment.household_id, v_assignment.household_id,
      v_assignment.binding_state, v_assignment.binding_state,
      'household_deleted', v_request.correlation_id, p_as_of
    );
  end if;

  update app_private.household_deletion_jobs as job
  set processing_status = 'succeeded', next_attempt_at = null,
      lease_owner = null, lease_token = null, lease_expires_at = null,
      access_revoked_at = p_as_of, redacted_at = p_as_of,
      billing_unlinked_at = p_as_of, last_error_code = null
  where job.privacy_request_id = p_request_id;
  update public.privacy_requests as request
  set status = 'completed', completed_at = p_as_of, failure_code = null
  where request.id = p_request_id and request.status = 'processing'
  returning request.* into v_request;
  if not found then
    raise exception using errcode = 'KHP16', message = 'deletion completion failed';
  end if;
  insert into app_private.household_privacy_events (
    privacy_request_id, household_id, transition, request_status,
    request_version, correlation_id, safe_metadata, occurred_at
  ) values (
    v_request.id, v_request.household_id, 'deletion_completed',
    v_request.status, v_request.version, v_request.correlation_id,
    pg_catalog.jsonb_build_object(
      'memberCount', v_member_count,
      'endpointCount', v_endpoint_count,
      'inviteCount', v_invite_count,
      'preferenceCount', v_preference_count,
      'inboxCount', v_inbox_count,
      'choreSeriesCount', v_chore_series_count,
      'choreRevisionCount', v_chore_revision_count,
      'eventSeriesCount', v_event_series_count,
      'eventRevisionCount', v_event_revision_count,
      'billingAssignmentCount', v_billing_assignment_count,
      'revokedExportCount', v_export_count
    ), p_as_of
  );
  return query select app_private.household_privacy_status_payload(
    v_request.auth_user_id, v_request.id
  );
end;
$$;

create or replace function public.fail_household_deletion_request(
  p_request_id uuid,
  p_lease_token uuid,
  p_error_code text,
  p_retryable boolean,
  p_as_of timestamptz
)
returns table (result jsonb)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job app_private.household_deletion_jobs%rowtype;
  v_request public.privacy_requests%rowtype;
  v_terminal_code text;
begin
  if p_request_id is null or p_lease_token is null
    or p_retryable is null or p_as_of is null
    or p_error_code not in (
      'OWNER_AUTHORIZATION_CHANGED', 'HOUSEHOLD_ALREADY_DELETED',
      'HOUSEHOLD_REDACTION_UNAVAILABLE',
      'PROCESSING_PRECONDITION_FAILED'
    ) then
    raise exception using errcode = 'KHP02', message = 'invalid deletion failure';
  end if;
  select job.* into v_job
  from app_private.household_deletion_jobs as job
  where job.privacy_request_id = p_request_id for update;
  if not found or v_job.processing_status <> 'leased'
    or v_job.lease_token <> p_lease_token then
    raise exception using errcode = 'KHP16', message = 'deletion lease invalid';
  end if;
  select request.* into v_request
  from public.privacy_requests as request
  where request.id = p_request_id and request.status = 'processing'
  for update;
  if not found then
    raise exception using errcode = 'KHP16', message = 'deletion precondition failed';
  end if;
  if p_retryable and v_job.attempts < v_job.max_attempts then
    update app_private.household_deletion_jobs as job
    set processing_status = 'retry_wait',
        next_attempt_at = app_private.household_privacy_retry_at(
          p_as_of, job.attempts
        ), lease_owner = null, lease_token = null, lease_expires_at = null,
        last_error_code = p_error_code
    where job.privacy_request_id = p_request_id;
    update public.privacy_requests as request
    set failure_code = p_error_code
    where request.id = p_request_id
    returning request.* into v_request;
    insert into app_private.household_privacy_events (
      privacy_request_id, household_id, transition, request_status,
      request_version, correlation_id, safe_metadata, occurred_at
    ) values (
      v_request.id, v_request.household_id, 'deletion_retry_scheduled',
      v_request.status, v_request.version, v_request.correlation_id,
      pg_catalog.jsonb_build_object(
        'reasonCode', p_error_code, 'attempts', v_job.attempts
      ), p_as_of
    );
  else
    v_terminal_code := case
      when p_retryable and v_job.attempts >= v_job.max_attempts
        then 'HOUSEHOLD_REDACTION_ATTEMPTS_EXHAUSTED'
      else p_error_code end;
    update app_private.household_deletion_jobs as job
    set processing_status = 'dead_letter', next_attempt_at = null,
        lease_owner = null, lease_token = null, lease_expires_at = null,
        last_error_code = v_terminal_code
    where job.privacy_request_id = p_request_id;
    update public.privacy_requests as request
    set status = 'failed', failed_at = p_as_of,
        failure_code = v_terminal_code
    where request.id = p_request_id
    returning request.* into v_request;
    insert into app_private.household_privacy_events (
      privacy_request_id, household_id, transition, request_status,
      request_version, correlation_id, safe_metadata, occurred_at
    ) values (
      v_request.id, v_request.household_id, 'deletion_failed',
      v_request.status, v_request.version, v_request.correlation_id,
      pg_catalog.jsonb_build_object(
        'reasonCode', v_terminal_code, 'attempts', v_job.attempts
      ), p_as_of
    );
  end if;
  return query select app_private.household_privacy_status_payload(
    v_request.auth_user_id, v_request.id
  );
end;
$$;

-- Every command remains Edge/service mediated. Authenticated clients may read
-- only the safe household_exports projection granted above.
revoke all on function public.get_household_privacy_preflight(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.get_household_privacy_request(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.configure_household_privacy_runtime(
  boolean, boolean, boolean, integer, integer, integer, bigint, uuid
) from public, anon, authenticated, service_role;
revoke all on function public.request_household_export(uuid, uuid, text, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.request_household_deletion(
  uuid, uuid, bigint, text, boolean, boolean, boolean, text, uuid
) from public, anon, authenticated, service_role;
revoke all on function public.cancel_household_privacy_request(
  uuid, uuid, text, bigint, text, uuid
) from public, anon, authenticated, service_role;
revoke all on function public.revoke_household_export(
  uuid, uuid, bigint, text, uuid
) from public, anon, authenticated, service_role;
revoke all on function public.create_household_export_download_grant(
  uuid, uuid, text, text, uuid
) from public, anon, authenticated, service_role;
revoke all on function public.consume_household_export_download_grant(
  text, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.configure_household_deletion_retention_hold(
  uuid, boolean, timestamptz, text, bigint, uuid
) from public, anon, authenticated, service_role;
revoke all on function public.recover_expired_household_export_leases(timestamptz)
  from public, anon, authenticated, service_role;
revoke all on function public.claim_household_export_requests(
  uuid, integer, integer, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.load_household_export_package(
  uuid, uuid, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.complete_household_export_request(
  uuid, uuid, text, text, text, text, bigint, bigint, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.fail_household_export_request(
  uuid, uuid, text, boolean, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.recover_expired_household_export_purge_leases(
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.claim_household_export_purge_jobs(
  uuid, integer, integer, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.complete_household_export_purge_job(
  uuid, uuid, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.fail_household_export_purge_job(
  uuid, uuid, text, boolean, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.recover_expired_household_deletion_leases(
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.claim_household_deletion_requests(
  uuid, integer, integer, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.complete_household_deletion_request(
  uuid, uuid, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.fail_household_deletion_request(
  uuid, uuid, text, boolean, timestamptz
) from public, anon, authenticated, service_role;

grant execute on function public.get_household_privacy_preflight(uuid, uuid)
  to service_role;
grant execute on function public.get_household_privacy_request(uuid, uuid)
  to service_role;
grant execute on function public.configure_household_privacy_runtime(
  boolean, boolean, boolean, integer, integer, integer, bigint, uuid
) to service_role;
grant execute on function public.request_household_export(uuid, uuid, text, uuid)
  to service_role;
grant execute on function public.request_household_deletion(
  uuid, uuid, bigint, text, boolean, boolean, boolean, text, uuid
) to service_role;
grant execute on function public.cancel_household_privacy_request(
  uuid, uuid, text, bigint, text, uuid
) to service_role;
grant execute on function public.revoke_household_export(
  uuid, uuid, bigint, text, uuid
) to service_role;
grant execute on function public.create_household_export_download_grant(
  uuid, uuid, text, text, uuid
) to service_role;
grant execute on function public.consume_household_export_download_grant(
  text, timestamptz
) to service_role;
grant execute on function public.configure_household_deletion_retention_hold(
  uuid, boolean, timestamptz, text, bigint, uuid
) to service_role;
grant execute on function public.recover_expired_household_export_leases(timestamptz)
  to service_role;
grant execute on function public.claim_household_export_requests(
  uuid, integer, integer, timestamptz
) to service_role;
grant execute on function public.load_household_export_package(
  uuid, uuid, timestamptz
) to service_role;
grant execute on function public.complete_household_export_request(
  uuid, uuid, text, text, text, text, bigint, bigint, timestamptz
) to service_role;
grant execute on function public.fail_household_export_request(
  uuid, uuid, text, boolean, timestamptz
) to service_role;
grant execute on function public.recover_expired_household_export_purge_leases(
  timestamptz
) to service_role;
grant execute on function public.claim_household_export_purge_jobs(
  uuid, integer, integer, timestamptz
) to service_role;
grant execute on function public.complete_household_export_purge_job(
  uuid, uuid, timestamptz
) to service_role;
grant execute on function public.fail_household_export_purge_job(
  uuid, uuid, text, boolean, timestamptz
) to service_role;
grant execute on function public.recover_expired_household_deletion_leases(
  timestamptz
) to service_role;
grant execute on function public.claim_household_deletion_requests(
  uuid, integer, integer, timestamptz
) to service_role;
grant execute on function public.complete_household_deletion_request(
  uuid, uuid, timestamptz
) to service_role;
grant execute on function public.fail_household_deletion_request(
  uuid, uuid, text, boolean, timestamptz
) to service_role;
