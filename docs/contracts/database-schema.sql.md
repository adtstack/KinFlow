# 원본 파일 문서화: `contracts/database-schema.sql`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/database-schema.sql`
- 원본 형식: `sql`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.

```sql
-- KinFlow core PostgreSQL schema contract v1.0
-- This is a normative implementation skeleton, not a substitute for ordered migrations.
-- Production changes MUST be split into forward-only Supabase migrations.

create extension if not exists pgcrypto;
create schema if not exists app_private;

create type public.household_role as enum ('owner', 'admin', 'member', 'managed_child');
create type public.invite_status as enum ('active', 'accepted', 'revoked', 'expired');
create type public.occurrence_status as enum ('scheduled', 'completed', 'skipped', 'cancelled');
create type public.job_status as enum ('queued', 'claimed', 'running', 'retry_wait', 'succeeded', 'dead_letter', 'cancelled');
create type public.delivery_status as enum ('pending', 'sending', 'succeeded', 'failed', 'dead_letter', 'cancelled');
create type public.entitlement_status as enum ('none', 'trialing', 'active', 'grace', 'billing_issue', 'expired', 'revoked');
create type public.privacy_request_type as enum ('export', 'delete_account', 'delete_household');
create type public.privacy_request_status as enum ('queued', 'verifying', 'processing', 'completed', 'failed', 'cancelled');

create or replace function app_private.set_updated_at_and_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  if tg_op = 'UPDATE' then
    new.version := old.version + 1;
  end if;
  return new;
end;
$$;

revoke all on function app_private.set_updated_at_and_version() from public;

create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  locale text not null default 'en' check (char_length(locale) between 2 and 20),
  timezone text not null default 'UTC' check (char_length(timezone) between 1 and 100),
  avatar_key text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  deleted_at timestamptz
);

create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  timezone text not null check (char_length(timezone) between 1 and 100),
  owner_member_id uuid not null,
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  deleted_at timestamptz,
  unique (id, owner_member_id)
);

create table public.household_members (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  auth_user_id uuid references auth.users(id) on delete set null,
  display_name text not null check (char_length(display_name) between 1 and 80),
  role public.household_role not null,
  avatar_key text,
  joined_at timestamptz not null default now(),
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  removed_at timestamptz,
  unique (household_id, id),
  constraint managed_child_identity_ck check (
    (role = 'managed_child' and auth_user_id is null)
    or (role <> 'managed_child' and auth_user_id is not null)
  )
);

create unique index household_members_active_auth_uq
  on public.household_members(household_id, auth_user_id)
  where auth_user_id is not null and removed_at is null;

create unique index household_members_single_owner_uq
  on public.household_members(household_id)
  where role = 'owner' and removed_at is null;

alter table public.households
  add constraint households_owner_same_household_fk
  foreign key (id, owner_member_id)
  references public.household_members(household_id, id)
  deferrable initially deferred;

create table public.user_active_households (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  member_id uuid not null,
  updated_at timestamptz not null default now(),
  constraint active_household_member_fk foreign key (household_id, member_id)
    references public.household_members(household_id, id) on delete cascade
);

create table public.member_guardians (
  household_id uuid not null references public.households(id) on delete cascade,
  guardian_member_id uuid not null,
  managed_child_member_id uuid not null,
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (household_id, guardian_member_id, managed_child_member_id),
  constraint guardian_member_fk foreign key (household_id, guardian_member_id)
    references public.household_members(household_id, id) on delete cascade,
  constraint guardian_child_fk foreign key (household_id, managed_child_member_id)
    references public.household_members(household_id, id) on delete cascade,
  constraint different_guardian_child_ck check (guardian_member_id <> managed_child_member_id)
);

create table public.acting_contexts (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  authenticated_user_id uuid not null references auth.users(id) on delete cascade,
  actor_member_id uuid not null,
  acting_member_id uuid not null,
  device_binding_hash bytea,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint acting_actor_member_fk foreign key (household_id, actor_member_id)
    references public.household_members(household_id, id) on delete cascade,
  constraint acting_child_member_fk foreign key (household_id, acting_member_id)
    references public.household_members(household_id, id) on delete cascade,
  constraint acting_different_member_ck check (actor_member_id <> acting_member_id)
);

create index acting_contexts_lookup_idx
  on public.acting_contexts(authenticated_user_id, household_id, expires_at)
  where revoked_at is null;

create table public.household_invites (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  role public.household_role not null check (role in ('admin', 'member')),
  token_hash bytea not null unique,
  short_code_hash bytea unique,
  target_email_hash bytea,
  status public.invite_status not null default 'active',
  expires_at timestamptz not null,
  max_uses integer not null default 1 check (max_uses between 1 and 50),
  used_count integer not null default 0 check (used_count >= 0 and used_count <= max_uses),
  created_by_member_id uuid not null,
  accepted_by_member_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revoked_at timestamptz,
  version bigint not null default 1 check (version > 0),
  constraint invite_creator_fk foreign key (household_id, created_by_member_id)
    references public.household_members(household_id, id),
  constraint invite_acceptor_fk foreign key (household_id, accepted_by_member_id)
    references public.household_members(household_id, id)
);

create index household_invites_active_idx
  on public.household_invites(household_id, expires_at)
  where status = 'active';

create table public.chore_series (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 160),
  description text check (char_length(description) <= 4000),
  timezone text not null check (char_length(timezone) between 1 and 100),
  active_revision_id uuid,
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  deleted_at timestamptz,
  unique (household_id, id)
);

create table public.chore_series_revisions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null,
  series_id uuid not null,
  revision_number integer not null check (revision_number > 0),
  effective_local_date date not null,
  due_local_time time,
  recurrence_rule jsonb not null check (jsonb_typeof(recurrence_rule) = 'object'),
  default_assignee_member_id uuid,
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (household_id, id),
  unique (series_id, revision_number),
  constraint chore_revision_series_fk foreign key (household_id, series_id)
    references public.chore_series(household_id, id) on delete cascade,
  constraint chore_revision_assignee_fk foreign key (household_id, default_assignee_member_id)
    references public.household_members(household_id, id)
);

alter table public.chore_series
  add constraint chore_active_revision_fk
  foreign key (household_id, active_revision_id)
  references public.chore_series_revisions(household_id, id)
  deferrable initially deferred;

create table public.chore_occurrences (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null,
  series_id uuid not null,
  revision_id uuid not null,
  occurrence_key text not null,
  due_local_date date not null,
  due_at timestamptz,
  timezone text not null,
  status public.occurrence_status not null default 'scheduled',
  assignee_member_id uuid,
  completed_by_member_id uuid,
  completed_by_user_id uuid references auth.users(id) on delete set null,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  unique (household_id, id),
  unique (household_id, occurrence_key),
  constraint chore_occurrence_series_fk foreign key (household_id, series_id)
    references public.chore_series(household_id, id) on delete cascade,
  constraint chore_occurrence_revision_fk foreign key (household_id, revision_id)
    references public.chore_series_revisions(household_id, id),
  constraint chore_occurrence_assignee_fk foreign key (household_id, assignee_member_id)
    references public.household_members(household_id, id),
  constraint chore_occurrence_completer_fk foreign key (household_id, completed_by_member_id)
    references public.household_members(household_id, id),
  constraint chore_completion_fields_ck check (
    (status = 'completed' and completed_at is not null and completed_by_member_id is not null)
    or (status <> 'completed')
  )
);

create index chore_occurrences_today_idx
  on public.chore_occurrences(household_id, due_local_date, status);
create index chore_occurrences_assignee_idx
  on public.chore_occurrences(household_id, assignee_member_id, due_local_date);

create table public.chore_completion_events (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null,
  occurrence_id uuid not null,
  event_type text not null check (event_type in ('completed', 'reopened', 'skipped')),
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_member_id uuid not null,
  acting_member_id uuid,
  occurred_at timestamptz not null default now(),
  occurrence_version bigint not null,
  correlation_id uuid not null,
  constraint completion_occurrence_fk foreign key (household_id, occurrence_id)
    references public.chore_occurrences(household_id, id) on delete cascade,
  constraint completion_actor_fk foreign key (household_id, actor_member_id)
    references public.household_members(household_id, id),
  constraint completion_acting_fk foreign key (household_id, acting_member_id)
    references public.household_members(household_id, id)
);

create table public.event_series (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 200),
  description text check (char_length(description) <= 8000),
  timezone text not null check (char_length(timezone) between 1 and 100),
  is_all_day boolean not null default false,
  active_revision_id uuid,
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  deleted_at timestamptz,
  unique (household_id, id)
);

create table public.event_series_revisions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null,
  series_id uuid not null,
  revision_number integer not null check (revision_number > 0),
  local_start_date date not null,
  local_start_time time,
  duration_minutes integer check (duration_minutes is null or duration_minutes between 1 and 10080),
  all_day_end_date_exclusive date,
  recurrence_rule jsonb check (recurrence_rule is null or jsonb_typeof(recurrence_rule) = 'object'),
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (household_id, id),
  unique (series_id, revision_number),
  constraint event_revision_series_fk foreign key (household_id, series_id)
    references public.event_series(household_id, id) on delete cascade,
  constraint event_revision_time_ck check (
    (local_start_time is null and all_day_end_date_exclusive is not null and all_day_end_date_exclusive > local_start_date)
    or (local_start_time is not null and duration_minutes is not null and all_day_end_date_exclusive is null)
  )
);

alter table public.event_series
  add constraint event_active_revision_fk
  foreign key (household_id, active_revision_id)
  references public.event_series_revisions(household_id, id)
  deferrable initially deferred;

create table public.event_participants (
  household_id uuid not null,
  series_id uuid not null,
  member_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (household_id, series_id, member_id),
  constraint event_participant_series_fk foreign key (household_id, series_id)
    references public.event_series(household_id, id) on delete cascade,
  constraint event_participant_member_fk foreign key (household_id, member_id)
    references public.household_members(household_id, id) on delete cascade
);

create table public.event_occurrences (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null,
  series_id uuid not null,
  revision_id uuid not null,
  occurrence_key text not null,
  local_start_date date not null,
  starts_at timestamptz,
  ends_at timestamptz,
  all_day_end_date_exclusive date,
  timezone text not null,
  status public.occurrence_status not null default 'scheduled',
  dst_adjustment jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  unique (household_id, id),
  unique (household_id, occurrence_key),
  constraint event_occurrence_series_fk foreign key (household_id, series_id)
    references public.event_series(household_id, id) on delete cascade,
  constraint event_occurrence_revision_fk foreign key (household_id, revision_id)
    references public.event_series_revisions(household_id, id),
  constraint event_occurrence_time_ck check (
    (starts_at is null and ends_at is null and all_day_end_date_exclusive > local_start_date)
    or (starts_at is not null and ends_at is not null and ends_at > starts_at and all_day_end_date_exclusive is null)
  )
);

create index event_occurrences_range_idx
  on public.event_occurrences(household_id, local_start_date, status);
create index event_occurrences_instant_idx
  on public.event_occurrences(household_id, starts_at)
  where starts_at is not null;

create table public.event_occurrence_exceptions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null,
  occurrence_id uuid not null,
  override_payload jsonb not null default '{}'::jsonb,
  cancelled boolean not null default false,
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  unique (household_id, occurrence_id),
  constraint event_exception_occurrence_fk foreign key (household_id, occurrence_id)
    references public.event_occurrences(household_id, id) on delete cascade
);

create table public.notification_endpoints (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  household_id uuid references public.households(id) on delete cascade,
  member_id uuid,
  installation_id text not null,
  channel text not null check (channel in ('native_push', 'web_push')),
  platform text not null check (platform in ('ios', 'android', 'web')),
  token_ciphertext bytea not null,
  token_fingerprint bytea not null,
  permission_state text not null check (permission_state in ('granted', 'denied', 'prompt', 'unsupported')),
  locale text,
  timezone text,
  app_version text,
  runtime_version text,
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  unique (auth_user_id, installation_id, channel),
  constraint endpoint_member_fk foreign key (household_id, member_id)
    references public.household_members(household_id, id)
);

create table public.notification_preferences (
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  category text not null,
  native_push boolean not null default true,
  web_push boolean not null default false,
  email boolean not null default false,
  in_app boolean not null default true,
  quiet_start time,
  quiet_end time,
  timezone text not null default 'UTC',
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  primary key (auth_user_id, household_id, category)
);

create table public.notification_intents (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  category text not null,
  subject_type text not null,
  subject_id uuid not null,
  scheduled_at timestamptz not null,
  dedupe_key text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  cancelled_at timestamptz,
  unique (recipient_user_id, dedupe_key)
);

create table public.notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  intent_id uuid not null references public.notification_intents(id) on delete cascade,
  endpoint_id uuid references public.notification_endpoints(id) on delete set null,
  channel text not null,
  status public.delivery_status not null default 'pending',
  attempts integer not null default 0,
  provider_message_ref text,
  last_error_code text,
  next_attempt_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (intent_id, endpoint_id, channel)
);

create table public.background_jobs (
  id uuid primary key default gen_random_uuid(),
  job_type text not null,
  payload jsonb not null,
  payload_version integer not null default 1,
  status public.job_status not null default 'queued',
  scheduled_at timestamptz not null default now(),
  attempts integer not null default 0,
  max_attempts integer not null default 8,
  lease_owner text,
  lease_expires_at timestamptz,
  dedupe_key text,
  correlation_id uuid not null default gen_random_uuid(),
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index background_jobs_dedupe_uq
  on public.background_jobs(job_type, dedupe_key)
  where dedupe_key is not null and status not in ('succeeded', 'cancelled');
create index background_jobs_claim_idx
  on public.background_jobs(status, scheduled_at, lease_expires_at);

create table public.outbox_events (
  event_id uuid primary key default gen_random_uuid(),
  event_type text not null,
  event_version integer not null default 1,
  household_id uuid references public.households(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_member_id uuid,
  acting_member_id uuid,
  aggregate_type text not null,
  aggregate_id uuid not null,
  aggregate_version bigint,
  correlation_id uuid not null,
  causation_id uuid,
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  dispatched_at timestamptz,
  attempts integer not null default 0,
  next_attempt_at timestamptz,
  last_error_code text,
  constraint outbox_actor_member_fk foreign key (household_id, actor_member_id)
    references public.household_members(household_id, id),
  constraint outbox_acting_member_fk foreign key (household_id, acting_member_id)
    references public.household_members(household_id, id)
);

create index outbox_undispatched_idx
  on public.outbox_events(next_attempt_at, occurred_at)
  where dispatched_at is null;

create table public.idempotency_keys (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  operation text not null,
  idempotency_key text not null,
  request_hash bytea not null,
  status text not null check (status in ('processing', 'succeeded', 'failed')),
  response_status integer,
  response_body jsonb,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  unique (auth_user_id, operation, idempotency_key)
);

create table public.billing_customers (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique references auth.users(id) on delete cascade,
  provider text not null check (provider in ('revenuecat', 'web')),
  provider_customer_ref text not null,
  provider_customer_ref_hash bytea not null,
  last_verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  unique (provider, provider_customer_ref_hash)
);

create table public.billing_webhook_receipts (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  provider_event_id text not null,
  payload_version text,
  payload_ciphertext bytea,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  processing_status text not null default 'received',
  last_error_code text,
  unique (provider, provider_event_id)
);

create table public.billing_transactions (
  id uuid primary key default gen_random_uuid(),
  billing_customer_id uuid not null references public.billing_customers(id) on delete cascade,
  provider text not null,
  product_id text not null,
  transaction_ref_hash bytea not null,
  original_transaction_ref_hash bytea,
  status text not null,
  purchased_at timestamptz,
  current_period_start timestamptz,
  current_period_end timestamptz,
  will_renew boolean,
  provider_updated_at timestamptz,
  verified_at timestamptz not null default now(),
  raw_snapshot_ciphertext bytea,
  unique (provider, transaction_ref_hash)
);

create table public.billing_household_assignments (
  id uuid primary key default gen_random_uuid(),
  billing_customer_id uuid not null references public.billing_customers(id) on delete cascade,
  billing_owner_user_id uuid not null references auth.users(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  status text not null check (status in ('active', 'ended', 'revoked')),
  assigned_at timestamptz not null default now(),
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1
);

create unique index billing_assignment_customer_active_uq
  on public.billing_household_assignments(billing_customer_id)
  where status = 'active';
create unique index billing_assignment_household_active_uq
  on public.billing_household_assignments(household_id)
  where status = 'active';

create table public.plan_catalog (
  plan_code text primary key,
  version integer not null,
  feature_limits jsonb not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.household_entitlements (
  household_id uuid primary key references public.households(id) on delete cascade,
  assignment_id uuid references public.billing_household_assignments(id) on delete set null,
  billing_owner_user_id uuid references auth.users(id) on delete set null,
  plan_code text not null references public.plan_catalog(plan_code),
  status public.entitlement_status not null default 'none',
  source text not null check (source in ('app_store', 'play_store', 'web', 'manual_support', 'none')),
  product_id text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  will_renew boolean,
  features jsonb not null default '{}'::jsonb,
  provider_updated_at timestamptz,
  verified_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1
);

create table public.privacy_requests (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  household_id uuid references public.households(id) on delete set null,
  request_type public.privacy_request_type not null,
  status public.privacy_request_status not null default 'queued',
  requested_at timestamptz not null default now(),
  verified_at timestamptz,
  processing_started_at timestamptz,
  completed_at timestamptz,
  failure_code text,
  correlation_id uuid not null default gen_random_uuid(),
  version bigint not null default 1
);

create unique index privacy_pending_request_uq
  on public.privacy_requests(auth_user_id, request_type)
  where status in ('queued', 'verifying', 'processing');

create table public.data_exports (
  id uuid primary key default gen_random_uuid(),
  privacy_request_id uuid not null unique references public.privacy_requests(id) on delete cascade,
  storage_object_key text,
  checksum_sha256 text,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  downloaded_at timestamptz
);

create table public.consent_records (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid references auth.users(id) on delete set null,
  household_id uuid references public.households(id) on delete set null,
  consent_type text not null,
  policy_version text not null,
  status text not null check (status in ('granted', 'withdrawn', 'not_required')),
  recorded_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  household_id uuid references public.households(id) on delete set null,
  authenticated_user_id uuid references auth.users(id) on delete set null,
  actor_member_id uuid,
  acting_member_id uuid,
  action text not null,
  target_type text not null,
  target_id uuid,
  result text not null check (result in ('succeeded', 'denied', 'failed')),
  error_code text,
  correlation_id uuid not null,
  safe_metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  constraint audit_actor_member_fk foreign key (household_id, actor_member_id)
    references public.household_members(household_id, id),
  constraint audit_acting_member_fk foreign key (household_id, acting_member_id)
    references public.household_members(household_id, id)
);

create index audit_events_household_time_idx
  on public.audit_events(household_id, occurred_at desc);

create table public.feature_flags (
  key text primary key,
  enabled boolean not null default false,
  rules jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by_user_id uuid references auth.users(id) on delete set null
);

create table public.kill_switches (
  key text primary key,
  enabled boolean not null default false,
  reason text,
  updated_at timestamptz not null default now(),
  updated_by_user_id uuid references auth.users(id) on delete set null
);

-- Version/update triggers for mutable user-facing aggregates.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles', 'households', 'household_members', 'household_invites',
    'chore_series', 'chore_occurrences', 'event_series',
    'event_occurrences', 'event_occurrence_exceptions',
    'notification_endpoints', 'notification_deliveries', 'background_jobs',
    'billing_customers', 'billing_household_assignments', 'household_entitlements'
  ]
  loop
    execute format(
      'create trigger %I_set_updated before update on public.%I for each row execute function app_private.set_updated_at_and_version()',
      table_name, table_name
    );
  end loop;
end $$;

-- Baseline plan rows are additive. Product limits remain provisional until D-023 is accepted.
insert into public.plan_catalog(plan_code, version, feature_limits)
values
  ('free', 1, '{"provisional": true}'::jsonb),
  ('plus', 1, '{"provisional": true}'::jsonb)
on conflict (plan_code) do nothing;
```
