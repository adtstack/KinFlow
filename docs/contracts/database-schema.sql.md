# 원본 파일 문서화: `contracts/database-schema.sql`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/database-schema.sql`
- 원본 형식: `sql`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.
- 범위 주의: 이 골격의 Managed Child·guardian·acting context 부분은 P1 참조 전용이다. Store MVP migration에는 포함하지 않는다(D-013).

```sql
-- KinFlow core PostgreSQL schema contract v1.0
-- This is a normative implementation skeleton, not a substitute for ordered migrations.
-- Production changes MUST be split into forward-only Supabase migrations.
-- D-013: managed_child, member_guardians, and acting_contexts are P1 reference only.
-- Do not include those surfaces in Store MVP migrations without a separate P1 approval.

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

-- Shared IANA validation is defined by the household authorization migration
-- before any Calendar table references it.
create or replace function app_private.is_valid_iana_timezone(
  p_timezone text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_timezone is not null
    and (
      p_timezone = 'UTC'
      or (
        p_timezone like '%/%'
        and p_timezone !~ '^(posix|right)/'
        and exists (
          select 1
          from pg_catalog.pg_timezone_names as timezone_name
          where timezone_name.name = p_timezone
        )
      )
    )
$$;

revoke all on function app_private.is_valid_iana_timezone(text) from public;
grant execute on function app_private.is_valid_iana_timezone(text)
  to authenticated, service_role;

-- WP04-02 accepts only the exact server-produced DST metadata envelope.
create or replace function app_private.is_valid_calendar_dst_adjustment(
  p_adjustment jsonb
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select
    p_adjustment is not null
    and pg_catalog.jsonb_typeof(p_adjustment) = 'object'
    and (
      select pg_catalog.count(*)
      from pg_catalog.jsonb_object_keys(p_adjustment)
    ) = 5
    and p_adjustment ?& array[
      'candidateCount',
      'gapPolicy',
      'overlapPolicy',
      'resolution',
      'utcOffsetSeconds'
    ]
    and p_adjustment->>'gapPolicy' = 'reject'
    and p_adjustment->>'overlapPolicy' in ('earlier', 'later')
    and p_adjustment->>'resolution' in (
      'normal',
      'overlap_earlier',
      'overlap_later'
    )
    and p_adjustment->>'candidateCount' ~ '^[1-9][0-9]*$'
    and p_adjustment->>'utcOffsetSeconds' ~ '^-?[0-9]+$'
    and (p_adjustment->>'utcOffsetSeconds')::integer
      between -57600 and 57600
    and (
      (
        p_adjustment->>'resolution' = 'normal'
        and (p_adjustment->>'candidateCount')::integer = 1
      )
      or (
        p_adjustment->>'resolution' = 'overlap_earlier'
        and p_adjustment->>'overlapPolicy' = 'earlier'
        and (p_adjustment->>'candidateCount')::integer >= 2
      )
      or (
        p_adjustment->>'resolution' = 'overlap_later'
        and p_adjustment->>'overlapPolicy' = 'later'
        and (p_adjustment->>'candidateCount')::integer >= 2
      )
    )
$$;

revoke all on function app_private.is_valid_calendar_dst_adjustment(jsonb)
  from public, anon, authenticated, service_role;

-- WP04-04A strict locale-independent recurrence subset.
create or replace function app_private.is_valid_calendar_recurrence_end(
  p_end jsonb
)
returns boolean
language plpgsql
immutable
strict
set search_path = ''
as $$
declare
  v_count integer;
  v_until date;
begin
  if jsonb_typeof(p_end) <> 'object' then
    return false;
  end if;
  if p_end = '{"type":"never"}'::jsonb then
    return true;
  end if;
  if p_end->>'type' = 'count'
    and (select count(*) from jsonb_object_keys(p_end)) = 2
    and jsonb_typeof(p_end->'count') = 'number'
    and p_end->>'count' ~ '^[0-9]+$' then
    v_count := (p_end->>'count')::integer;
    return v_count between 1 and 1000;
  end if;
  if p_end->>'type' = 'until'
    and (select count(*) from jsonb_object_keys(p_end)) = 2
    and jsonb_typeof(p_end->'localDate') = 'string'
    and p_end->>'localDate' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    v_until := make_date(
      substr(p_end->>'localDate', 1, 4)::integer,
      substr(p_end->>'localDate', 6, 2)::integer,
      substr(p_end->>'localDate', 9, 2)::integer
    );
    return v_until is not null;
  end if;
  return false;
exception
  when invalid_text_representation
    or datetime_field_overflow
    or numeric_value_out_of_range then
    return false;
end;
$$;

create or replace function app_private.is_valid_calendar_recurrence_rule(
  p_rule jsonb
)
returns boolean
language plpgsql
immutable
strict
set search_path = ''
as $$
declare
  v_frequency text;
  v_interval integer;
  v_month_day integer;
  v_weekday_count integer;
  v_distinct_weekday_count integer;
begin
  if jsonb_typeof(p_rule) <> 'object'
    or not p_rule ?& array['frequency', 'interval', 'end']
    or jsonb_typeof(p_rule->'frequency') <> 'string'
    or jsonb_typeof(p_rule->'interval') <> 'number'
    or p_rule->>'interval' !~ '^[0-9]+$'
    or not app_private.is_valid_calendar_recurrence_end(p_rule->'end') then
    return false;
  end if;
  v_frequency := p_rule->>'frequency';
  v_interval := (p_rule->>'interval')::integer;
  if v_interval not between 1 and 30 then
    return false;
  end if;
  if v_frequency = 'daily' then
    return (select count(*) from jsonb_object_keys(p_rule)) = 3;
  end if;
  if v_frequency = 'weekly' then
    if (select count(*) from jsonb_object_keys(p_rule)) <> 4
      or not p_rule ? 'weekdays'
      or jsonb_typeof(p_rule->'weekdays') <> 'array'
      or jsonb_array_length(p_rule->'weekdays') not between 1 and 7
      or exists (
        select 1
        from jsonb_array_elements(p_rule->'weekdays') as weekday(value)
        where jsonb_typeof(weekday.value) <> 'string'
          or weekday.value #>> '{}' not in (
            'MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'
          )
      ) then
      return false;
    end if;
    select count(*), count(distinct weekday.value)
    into v_weekday_count, v_distinct_weekday_count
    from jsonb_array_elements_text(p_rule->'weekdays') as weekday(value);
    return v_weekday_count = v_distinct_weekday_count;
  end if;
  if v_frequency = 'monthly' then
    if (select count(*) from jsonb_object_keys(p_rule)) <> 4
      or not p_rule ? 'monthDay'
      or jsonb_typeof(p_rule->'monthDay') <> 'number'
      or p_rule->>'monthDay' !~ '^[0-9]+$' then
      return false;
    end if;
    v_month_day := (p_rule->>'monthDay')::integer;
    return v_month_day between 1 and 31;
  end if;
  return false;
exception
  when invalid_text_representation or numeric_value_out_of_range then
    return false;
end;
$$;

revoke all on function app_private.is_valid_calendar_recurrence_end(jsonb)
  from public, anon, authenticated, service_role;
revoke all on function app_private.is_valid_calendar_recurrence_rule(jsonb)
  from public, anon, authenticated, service_role;

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

-- WP07-06A records only household default-timezone changes. This private
-- append-only audit deliberately survives client access revocation and carries
-- no profile display name, locale, or other household content.
create table app_private.household_timezone_audit_events (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null,
  authenticated_user_id uuid not null,
  actor_member_id uuid not null,
  previous_timezone text not null check (
    app_private.is_valid_iana_timezone(previous_timezone)
  ),
  next_timezone text not null check (
    app_private.is_valid_iana_timezone(next_timezone)
  ),
  aggregate_version bigint not null check (aggregate_version > 0),
  occurred_at timestamptz not null default clock_timestamp(),
  check (previous_timezone <> next_timezone)
);

create index household_timezone_audit_events_household_time_idx
  on app_private.household_timezone_audit_events(
    household_id,
    occurred_at desc
  );

revoke all on table app_private.household_timezone_audit_events
  from public, anon, authenticated, service_role;

-- The ordered WP07-06A migration installs the existing private immutable-audit
-- trigger and defines empty-search-path get_profile_preferences and
-- update_profile_preferences RPCs. The update command locks and version-checks
-- self profile, active membership, and optional Owner/Admin household timezone
-- in one transaction; it also keeps active membership display/avatar in sync.

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
  version bigint not null default 1 check (version > 0),
  updated_at timestamptz not null default now(),
  constraint active_household_member_fk foreign key (household_id, member_id)
    references public.household_members(household_id, id) on delete cascade
);

create table app_private.active_household_switch_audit_events (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  previous_household_id uuid references public.households(id) on delete cascade,
  next_household_id uuid not null references public.households(id) on delete cascade,
  previous_selection_version bigint not null check (previous_selection_version >= 0),
  next_selection_version bigint not null check (next_selection_version > previous_selection_version),
  occurred_at timestamptz not null default statement_timestamp()
);

-- WP02-08 installs an update timestamp/version trigger, forced RLS and no
-- client grants on the private audit table, plus empty-search-path
-- list_my_households() and switch_active_household(uuid,bigint) functions.
-- The switch derives member_id from auth.uid(); clients never submit it.

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
  short_code_expires_at timestamptz,
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
    references public.household_members(household_id, id),
  constraint household_invites_short_code_shape_ck check (
    (short_code_hash is null and short_code_expires_at is null)
    or (
      short_code_hash is not null
      and short_code_expires_at is not null
      and short_code_expires_at > created_at
      and short_code_expires_at <= expires_at
      and short_code_expires_at <= created_at + interval '24 hours 1 minute'
    )
  )
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
  timezone text,
  is_all_day boolean not null,
  active_revision_id uuid not null,
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  deleted_at timestamptz,
  ended_at timestamptz,
  ended_effective_local_date date,
  unique (household_id, id),
  constraint event_series_end_shape_ck check (
    (ended_at is null and ended_effective_local_date is null)
    or (ended_at is not null and ended_effective_local_date is not null)
  ),
  constraint event_series_time_mode_ck check (
    (is_all_day and timezone is null)
    or (not is_all_day and app_private.is_valid_iana_timezone(timezone))
  )
);

create table public.event_series_revisions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null,
  series_id uuid not null,
  revision_number integer not null check (revision_number > 0),
  local_start_date date not null,
  local_start_time time,
  duration_minutes integer,
  all_day_end_date_exclusive date,
  gap_policy text,
  overlap_policy text,
  recurrence_rule jsonb check (recurrence_rule is null or jsonb_typeof(recurrence_rule) = 'object'),
  snapshot_title text,
  snapshot_description text,
  snapshot_timezone text,
  snapshot_is_all_day boolean,
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (household_id, id),
  unique (series_id, revision_number),
  unique (household_id, series_id, id),
  constraint event_revision_series_fk foreign key (household_id, series_id)
    references public.event_series(household_id, id) on delete cascade,
  constraint event_revision_time_ck check (
    (
      local_start_time is null and duration_minutes is null
      and all_day_end_date_exclusive > local_start_date
      and gap_policy is null and overlap_policy is null
    )
    or (
      local_start_time is not null and extract(second from local_start_time) = 0
      and duration_minutes between 1 and 10080
      and all_day_end_date_exclusive is null
      and gap_policy = 'reject' and overlap_policy in ('earlier', 'later')
    )
  ),
  constraint event_recurring_revision_snapshot_ck check (
    recurrence_rule is null
    or (
      app_private.is_valid_calendar_recurrence_rule(recurrence_rule)
      and snapshot_title is not null
      and char_length(snapshot_title) between 1 and 200
      and snapshot_is_all_day is not null
      and (
        snapshot_is_all_day and snapshot_timezone is null
        or not snapshot_is_all_day
          and app_private.is_valid_iana_timezone(snapshot_timezone)
      )
    )
  )
);

alter table public.event_series
  add constraint event_active_revision_fk
  foreign key (household_id, id, active_revision_id)
  references public.event_series_revisions(household_id, series_id, id)
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
    references public.household_members(household_id, id)
);

-- Recurring revisions retain the participant set that produced each immutable
-- occurrence snapshot. Authenticated clients receive read-only RLS access.
create table public.event_revision_participants (
  household_id uuid not null,
  series_id uuid not null,
  revision_id uuid not null,
  member_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (household_id, revision_id, member_id),
  constraint event_revision_participant_revision_fk
    foreign key (household_id, series_id, revision_id)
    references public.event_series_revisions(household_id, series_id, id)
    on delete cascade,
  constraint event_revision_participant_member_fk
    foreign key (household_id, member_id)
    references public.household_members(household_id, id)
);

create table public.event_occurrences (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null,
  series_id uuid not null,
  revision_id uuid not null,
  occurrence_key text not null check (char_length(occurrence_key) between 1 and 240),
  recurrence_local_start_date date not null,
  local_start_date date not null,
  starts_at timestamptz,
  ends_at timestamptz,
  all_day_end_date_exclusive date,
  timezone text,
  status public.occurrence_status not null default 'scheduled',
  dst_adjustment jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  unique (household_id, id),
  unique (household_id, series_id, id),
  unique (household_id, occurrence_key),
  constraint event_occurrence_series_fk foreign key (household_id, series_id)
    references public.event_series(household_id, id) on delete cascade,
  constraint event_occurrence_revision_fk foreign key (household_id, series_id, revision_id)
    references public.event_series_revisions(household_id, series_id, id),
  constraint event_occurrence_time_ck check (
    (
      starts_at is null and ends_at is null
      and all_day_end_date_exclusive > local_start_date
      and timezone is null and dst_adjustment is null
    )
    or (
      starts_at is not null and ends_at > starts_at
      and all_day_end_date_exclusive is null
      and app_private.is_valid_iana_timezone(timezone)
      and app_private.is_valid_calendar_dst_adjustment(dst_adjustment)
    )
  )
);

create index event_occurrences_range_idx
  on public.event_occurrences(household_id, local_start_date, status, starts_at);
create index event_occurrences_instant_idx
  on public.event_occurrences(household_id, starts_at)
  where starts_at is not null;
create index event_occurrences_timed_overlap_idx
  on public.event_occurrences(household_id, ends_at, starts_at, id)
  where starts_at is not null and status = 'scheduled';
create index event_occurrences_all_day_overlap_idx
  on public.event_occurrences(
    household_id,
    all_day_end_date_exclusive,
    local_start_date,
    id
  )
  where starts_at is null and status = 'scheduled';
create index event_occurrences_recurrence_slot_idx
  on public.event_occurrences(
    household_id,
    series_id,
    recurrence_local_start_date,
    status
  );
create index event_participants_member_idx
  on public.event_participants(household_id, member_id, series_id);
create index event_revision_participants_member_idx
  on public.event_revision_participants(household_id, member_id, revision_id);

-- WP04-02 command deduplication and content-free audit records are private.
create table app_private.calendar_command_requests (
  authenticated_user_id uuid not null references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  command_name text not null check (
    command_name in ('create_one_time', 'update_one_time', 'delete_one_time')
  ),
  request_hash bytea not null check (octet_length(request_hash) = 32),
  household_id uuid not null references public.households(id) on delete cascade,
  series_id uuid not null,
  occurrence_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (authenticated_user_id, idempotency_key)
);

-- Recurring create replay state contains identifiers, a request digest, and
-- bounded result metadata only. It never duplicates title/description/member
-- lists and is not granted to API roles.
create table app_private.calendar_recurring_command_requests (
  authenticated_user_id uuid not null references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  household_id uuid not null,
  series_id uuid not null,
  revision_id uuid not null,
  first_occurrence_id uuid not null,
  result_materialized_through date not null,
  result_materialized_count integer not null
    check (result_materialized_count between 1 and 366),
  created_at timestamptz not null default now(),
  primary key (authenticated_user_id, idempotency_key)
);

create table app_private.calendar_audit_events (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  action text not null check (
    action in (
      'calendar.created',
      'calendar.updated',
      'calendar.deleted',
      'calendar.occurrence_updated',
      'calendar.occurrence_cancelled',
      'calendar.series_updated',
      'calendar.series_cancelled'
    )
  ),
  series_id uuid not null,
  occurrence_id uuid not null,
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_member_id uuid not null,
  correlation_id uuid not null,
  series_version bigint not null check (series_version > 0),
  occurrence_version bigint not null check (occurrence_version > 0),
  occurred_at timestamptz not null default now(),
  unique (household_id, action, correlation_id),
  constraint calendar_audit_actor_fk foreign key (household_id, actor_member_id)
    references public.household_members(household_id, id)
);

-- WP04-06 Realtime transports invalidation only. The row deliberately carries
-- no event, participant, actor, command, or correlation content.
create table public.calendar_sync_watermarks (
  household_id uuid primary key
    references public.households(id) on delete cascade,
  generation bigint not null default 1 check (generation > 0),
  changed_at timestamptz not null default now()
);

-- app_private.advance_calendar_sync_watermark(...) is callable only from
-- trusted triggers. Interactive calendar_audit_events inserts and statement-
-- level event_occurrences inserts/updates advance generation atomically.
-- Active household members receive SELECT-only RLS access, and the table is
-- the sole Calendar table added to the supabase_realtime publication.

-- WP05-15 gives Chores/Today the same content-free invalidation boundary. It
-- deliberately carries no title, description, member, assignee, actor,
-- series, occurrence, command, or correlation data.
create table public.chore_sync_watermarks (
  household_id uuid primary key
    references public.households(id) on delete cascade,
  generation bigint not null default 1 check (generation > 0),
  changed_at timestamptz not null default now()
);

-- Trusted statement-level triggers on occurrence insert/update, series update,
-- member update, and household update advance each affected household at most
-- once per statement. Active members receive SELECT-only forced-RLS access;
-- only this Chore metadata table is added to supabase_realtime.

-- WP05-16 Notification Center invalidation is scoped to the authenticated
-- recipient and deliberately carries no household, member, inbox item,
-- source, subject, category, read-state, content, command, or correlation data.
create table public.notification_sync_watermarks (
  auth_user_id uuid primary key
    references auth.users(id) on delete cascade,
  generation bigint not null default 1 check (generation > 0),
  changed_at timestamptz not null default now()
);

-- Trusted statement-level triggers on notification inbox insert/update,
-- preference insert/update, member update, and household update advance each
-- affected user at most once per statement. The row owner receives SELECT-only
-- forced-RLS access, including after membership revocation so the client can
-- receive a purge signal; only this notification metadata table is published.

-- Exact implementations live in the forward migrations. Public command and
-- read functions are
-- SECURITY DEFINER with an empty search_path and authenticated-only EXECUTE.
-- create_one_time_event(...), update_one_time_event(...), and
-- delete_one_time_event(...) use UUID idempotency keys; update/delete also use
-- an expected series version. list_one_time_events(...) returns a household
-- timezone/local-date envelope and at most 100 deterministic one-time rows.
-- WP04-03 get_calendar_event_page(...) returns a bounded agenda/day overlap
-- projection with a query-bound content-free opaque keyset cursor; an initial
-- null agenda range resolves server-side to household-local today plus 90 days.
-- get_calendar_month_summary(...) returns exactly one content-free date/count
-- row per day. Both additive read functions recheck active household membership.
-- WP04-04A create_recurring_calendar_event(...) accepts the strict
-- daily/weekly/monthly recurrence JSON subset and materializes at most the first
-- 366 local dates. Every timed slot is resolved independently from its local
-- date/time and pinned IANA zone; all-day slots remain date-only.
-- get_calendar_event_page_v2(...) adds recurrence rule/slot/revision/exception
-- metadata while mixing one-time and recurring occurrences under a v2 cursor.
-- get_calendar_month_summary_v2(...) counts both sources without content.
-- WP04-04B update_recurring_calendar_occurrence(...) creates an immutable
-- exception revision and updates only the target occurrence projection.
-- cancel_recurring_calendar_occurrence(...) cancels only that target. Both
-- commands use occurrence-version optimistic concurrency and UUID idempotency;
-- moved/cancelled targets are reflected by the unchanged v2 read signatures.
-- Source series intent, its active revision, recurrence slot/key, and sibling
-- occurrences remain unchanged.
-- WP04-04C get_recurring_calendar_series(...) returns the active immutable
-- recurring revision rather than an occurrence exception snapshot.
-- update_recurring_calendar_series(...) creates a new active revision and
-- rebuilds only non-exception source slots from server-derived household-local
-- today; cancel_recurring_calendar_series(...) ends the series and cancels
-- scheduled source slots from that boundary. Both preserve past rows and use
-- expected series version plus UUID idempotency. run_calendar_horizon_worker(...)
-- is service-role only, uses bounded skip-locked claims, and repairs/extends
-- active series without overwriting explicit exceptions.
-- WP04-14 update_recurring_calendar_series_from_occurrence(...) accepts an
-- active scheduled non-exception occurrence UUID and derives the boundary from
-- its immutable recurrence_local_start_date. The shared private engine keeps
-- the legacy today-boundary signature/hash/result unchanged, preserves every
-- earlier row and explicit exception, and rebuilds only selected-and-later
-- non-exception source slots. No target identity column is added to replay or
-- audit state; the normalized request hash binds the selected UUID.
-- WP04-15 cancel_recurring_calendar_series_from_occurrence(...) uses the same
-- immutable recurrence-slot authority and cancels every selected-and-later row,
-- including explicit exceptions whose displayed date moved across the boundary.
-- If an actionable non-exception prefix remains, the private engine clones its
-- source snapshot and participants into an immutable revision bounded by
-- until=boundary-1, repoints only actionable matching prefix rows, and marks
-- terminal materialization complete. Otherwise the series ends at the selected
-- boundary. Cancellation event/replay constraints allow only an all-null or a
-- complete terminal revision/materialized-through pair. The legacy whole-series
-- cancellation keeps its exact signature, normalized hash and nine-key result;
-- no cutoff or selected-target column is added.
-- WP04-16 keeps the selected-cancellation five-input/eleven-key public contract
-- compatible behind a private legacy engine. The wrapper captures only exact
-- metadata pre-state in app_private.calendar_series_cancellation_undo_items.
-- public.resume_recurring_calendar_series_cancellation(uuid, uuid, uuid, uuid,
-- bigint) binds the original actor and cancellation-result version, clones the
-- source snapshot/participants as a new immutable active revision, restores
-- ledger-bound status and revision semantics, and clears materialization state.
-- WP04-06 get_calendar_occurrence_locator(...) returns only household/date,
-- series/occurrence identifiers and current versions for a scheduled readable
-- target. Missing, deleted, cancelled and unauthorized targets share the same
-- not-found-or-forbidden boundary. No event content is returned.
-- WP04-07 preview_calendar_event_overlaps(...) accepts no candidate title or
-- description and returns a bounded, deterministic same-member overlap hint.
-- Timed and all-day ranges are half-open, mixed ranges use household-timezone
-- midnight, self-exclusion is explicit, and every result remains advisory.
-- app_private.calendar_overlap_candidate_dates(...) is private and expands at
-- most the inclusive 366-date preview window without persisting occurrences.
-- The v1 page/month functions remain executable for N-1 clients.

create table public.event_occurrence_exceptions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null,
  series_id uuid not null,
  occurrence_id uuid not null,
  override_payload jsonb not null default '{}'::jsonb
    check (override_payload = '{}'::jsonb),
  exception_revision_id uuid,
  cancelled boolean not null default false,
  created_by_user_id uuid references auth.users(id) on delete set null,
  updated_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  unique (household_id, id),
  unique (household_id, occurrence_id),
  constraint event_occurrence_exception_occurrence_fk
    foreign key (household_id, series_id, occurrence_id)
    references public.event_occurrences(household_id, series_id, id)
    on delete cascade,
  constraint event_occurrence_exception_revision_fk
    foreign key (household_id, series_id, exception_revision_id)
    references public.event_series_revisions(household_id, series_id, id),
  constraint event_occurrence_exception_meaningful_ck check (
    cancelled or exception_revision_id is not null
  )
);

create index event_occurrence_exceptions_revision_idx
  on public.event_occurrence_exceptions(
    household_id,
    series_id,
    exception_revision_id
  )
  where exception_revision_id is not null;

-- Single-occurrence command replay state is private and content-free.
create table app_private.calendar_occurrence_exception_command_requests (
  authenticated_user_id uuid not null references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  command_name text not null check (
    command_name in ('update_occurrence', 'cancel_occurrence')
  ),
  request_hash bytea not null check (octet_length(request_hash) = 32),
  household_id uuid not null,
  series_id uuid not null,
  occurrence_id uuid not null,
  exception_id uuid not null,
  result_revision_id uuid,
  result_occurrence_version bigint not null check (result_occurrence_version > 0),
  result_exception_version bigint not null check (result_exception_version > 0),
  result_cancelled boolean not null,
  created_at timestamptz not null default now(),
  primary key (authenticated_user_id, idempotency_key),
  constraint calendar_occurrence_exception_command_occurrence_fk
    foreign key (household_id, series_id, occurrence_id)
    references public.event_occurrences(household_id, series_id, id)
    on delete cascade,
  constraint calendar_occurrence_exception_command_exception_fk
    foreign key (household_id, exception_id)
    references public.event_occurrence_exceptions(household_id, id)
    on delete cascade,
  constraint calendar_occurrence_exception_command_revision_fk
    foreign key (household_id, series_id, result_revision_id)
    references public.event_series_revisions(household_id, series_id, id),
  constraint calendar_occurrence_exception_command_result_ck check (
    (
      command_name = 'update_occurrence'
      and result_revision_id is not null
      and not result_cancelled
    )
    or (
      command_name = 'cancel_occurrence'
      and result_cancelled
    )
  )
);

-- Whole-series edits and cancellations expose immutable, content-free history
-- to authorized household members. Event content stays in immutable revisions.
create table public.event_series_change_events (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null,
  series_id uuid not null,
  operation text not null check (operation in ('updated', 'cancelled')),
  previous_revision_id uuid not null,
  new_revision_id uuid,
  effective_local_date date not null,
  materialized_through date,
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_member_id uuid not null,
  rebuilt_count integer not null check (rebuilt_count >= 0),
  cancelled_count integer not null check (cancelled_count >= 0),
  preserved_exception_count integer not null check (preserved_exception_count >= 0),
  preserved_past_count integer not null check (preserved_past_count >= 0),
  series_version bigint not null check (series_version > 0),
  correlation_id uuid not null,
  occurred_at timestamptz not null default now(),
  unique (household_id, id),
  unique (actor_user_id, correlation_id),
  constraint event_series_change_event_series_fk
    foreign key (household_id, series_id)
    references public.event_series(household_id, id) on delete cascade,
  constraint event_series_change_event_previous_revision_fk
    foreign key (household_id, series_id, previous_revision_id)
    references public.event_series_revisions(household_id, series_id, id),
  constraint event_series_change_event_new_revision_fk
    foreign key (household_id, series_id, new_revision_id)
    references public.event_series_revisions(household_id, series_id, id),
  constraint event_series_change_event_actor_fk
    foreign key (household_id, actor_member_id)
    references public.household_members(household_id, id)
);

-- Command replay, rolling coverage, failure code, and run aggregates are
-- private and content-free. API roles receive no direct table access.
create table app_private.calendar_series_change_command_requests (
  authenticated_user_id uuid not null references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  operation text not null check (operation in ('updated', 'cancelled')),
  household_id uuid not null,
  series_id uuid not null,
  result_revision_id uuid,
  result_revision_number integer,
  result_effective_local_date date not null,
  result_materialized_through date,
  result_version bigint not null check (result_version > 0),
  result_rebuilt_count integer not null check (result_rebuilt_count >= 0),
  result_cancelled_count integer not null check (result_cancelled_count >= 0),
  result_preserved_exception_count integer not null
    check (result_preserved_exception_count >= 0),
  result_preserved_past_count integer not null
    check (result_preserved_past_count >= 0),
  result_event_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (authenticated_user_id, idempotency_key)
);

create table app_private.calendar_materialization_states (
  household_id uuid not null,
  series_id uuid not null,
  revision_id uuid not null,
  covered_through date,
  last_window_start date not null,
  last_target_date date not null,
  next_repair_at timestamptz not null,
  last_attempted_at timestamptz not null,
  last_succeeded_at timestamptz,
  last_result text not null check (last_result in ('succeeded', 'failed')),
  last_error_code text,
  last_changed_count integer not null check (last_changed_count >= 0),
  attempt_count bigint not null default 1 check (attempt_count > 0),
  updated_at timestamptz not null default now(),
  primary key (household_id, series_id)
);

create table app_private.calendar_materialization_runs (
  id uuid primary key default gen_random_uuid(),
  invoked_at timestamptz not null default now(),
  as_of timestamptz not null,
  horizon_days integer not null check (horizon_days between 30 and 365),
  repair_lookback_days integer not null check (repair_lookback_days between 0 and 31),
  batch_size integer not null check (batch_size between 1 and 500),
  target_series_id uuid,
  claimed_count integer not null check (claimed_count >= 0),
  succeeded_count integer not null check (succeeded_count >= 0),
  failed_count integer not null check (failed_count >= 0),
  changed_count integer not null check (changed_count >= 0),
  batch_exhausted boolean not null,
  completed_at timestamptz not null
);

create table public.notification_endpoints (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  member_id uuid not null,
  installation_id uuid not null,
  channel text not null check (channel = 'native_push'),
  platform text not null check (platform in ('ios', 'android')),
  token_ciphertext bytea not null check (
    octet_length(token_ciphertext) between 29 and 8192
  ),
  token_fingerprint bytea not null check (
    octet_length(token_fingerprint) = 32
  ),
  token_key_version integer not null check (
    token_key_version between 1 and 1000000
  ),
  revocation_secret_hash bytea not null check (
    octet_length(revocation_secret_hash) = 32
  ),
  permission_state text not null check (
    permission_state in ('granted', 'denied', 'prompt', 'unsupported')
  ),
  locale text check (
    locale is null
    or (
      char_length(locale) between 2 and 35
      and locale = btrim(locale)
      and locale ~ '^[A-Za-z]{2,3}([_-][A-Za-z0-9]{2,8})*$'
    )
  ),
  timezone text not null check (app_private.is_valid_iana_timezone(timezone)),
  app_version text not null check (char_length(app_version) between 1 and 64),
  runtime_version text not null check (char_length(runtime_version) between 1 and 64),
  last_registration_id uuid not null,
  last_seen_at timestamptz not null,
  revoked_at timestamptz,
  revocation_reason text check (
    revocation_reason is null
    or revocation_reason in (
      'client_revoked', 'token_reassigned', 'provider_unregistered',
      'provider_invalid_argument', 'membership_removed',
      'permission_revoked', 'rollback_disabled'
    )
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  unique (auth_user_id, installation_id, channel),
  unique (auth_user_id, last_registration_id),
  constraint notification_endpoint_member_fk
    foreign key (household_id, member_id, auth_user_id)
    references public.household_members(household_id, id, auth_user_id)
    on delete cascade,
  constraint notification_endpoint_lifecycle_ck check (
    (
      revoked_at is null
      and revocation_reason is null
      and permission_state = 'granted'
    )
    or (
      revoked_at is not null
      and revocation_reason is not null
      and revoked_at >= created_at
    )
  ),
  constraint notification_endpoint_timestamps_ck check (
    updated_at >= created_at and last_seen_at >= created_at
  )
);

create unique index notification_endpoints_active_token_uq
  on public.notification_endpoints(channel, token_fingerprint)
  where revoked_at is null;

create index notification_endpoints_active_recipient_idx
  on public.notification_endpoints(auth_user_id, household_id, last_seen_at desc)
  where revoked_at is null and permission_state = 'granted';

create table app_private.notification_endpoint_events (
  id uuid primary key default gen_random_uuid(),
  endpoint_id uuid not null,
  transition text not null check (
    transition in ('registered', 'refreshed', 'rotated', 'revoked')
  ),
  reason_code text,
  endpoint_version bigint not null check (endpoint_version > 0),
  occurred_at timestamptz not null,
  constraint notification_endpoint_event_reason_ck check (
    (transition = 'revoked') = (reason_code is not null)
  )
);

-- Exact WP05-03 mediated APIs are get_notification_endpoint_status for the
-- authenticated metadata projection and service-role-only
-- upsert_notification_endpoint, revoke_notification_endpoint_by_secret, and
-- invalidate_notification_endpoint. Client and direct service-role table
-- grants are absent; lifecycle audit is immutable and private.

create table public.notification_preferences (
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  category text not null check (
    category in ('chore_due', 'chore_assignment', 'calendar_event')
  ),
  native_push boolean not null default true,
  web_push boolean not null default false,
  email boolean not null default false,
  in_app boolean not null default true,
  quiet_start time,
  quiet_end time,
  timezone text not null check (app_private.is_valid_iana_timezone(timezone)),
  reminder_lead_minutes integer not null default 0,
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  primary key (auth_user_id, household_id, category),
  constraint notification_preferences_quiet_hours_ck check (
    (quiet_start is null and quiet_end is null)
    or (
      quiet_start is not null and quiet_end is not null
      and quiet_start <> quiet_end
      and extract(second from quiet_start) = 0
      and extract(second from quiet_end) = 0
    )
  ),
  constraint notification_preferences_reminder_lead_minutes_ck check (
    reminder_lead_minutes in (0, 5, 10, 15, 30, 60)
    and (
      category = 'calendar_event'
      or reminder_lead_minutes = 0
    )
  )
);

create trigger notification_preferences_set_updated_at_and_version
before update on public.notification_preferences
for each row execute function app_private.set_updated_at_and_version();

-- The ordered WP05-02 migration also binds source_event_id to the private
-- WP05-01 notification_event_resolutions table defined by the worker contract.
create table public.notification_inbox_items (
  id uuid primary key default gen_random_uuid(),
  item_version bigint not null default 1 check (item_version > 0),
  source_event_id uuid not null,
  source_aggregate_version bigint not null check (source_aggregate_version > 0),
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  recipient_member_id uuid not null,
  household_id uuid not null references public.households(id) on delete cascade,
  category text not null check (category in ('chore_due', 'chore_assignment')),
  subject_type text not null check (subject_type = 'chore_occurrence'),
  subject_id uuid not null,
  scheduled_at timestamptz not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  read_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text check (
    cancellation_reason is null
    or cancellation_reason in ('superseded', 'state_inactive')
  ),
  payload jsonb not null,
  unique (recipient_user_id, source_event_id, category),
  constraint notification_inbox_recipient_fk
    foreign key (household_id, recipient_member_id, recipient_user_id)
    references public.household_members(household_id, id, auth_user_id),
  constraint notification_inbox_subject_fk
    foreign key (household_id, subject_id)
    references public.chore_occurrences(household_id, id) on delete cascade,
  constraint notification_inbox_payload_ck check (
    jsonb_typeof(payload) = 'object'
    and payload ?& array['householdId', 'occurrenceId']
    and payload - array['householdId', 'occurrenceId'] = '{}'::jsonb
    and payload->>'householdId' = household_id::text
    and payload->>'occurrenceId' = subject_id::text
  )
);

create index notification_inbox_recipient_page_idx
  on public.notification_inbox_items(
    recipient_user_id, household_id, created_at desc, id desc
  ) where cancelled_at is null;

create index notification_inbox_recipient_unread_idx
  on public.notification_inbox_items(recipient_user_id, household_id)
  where read_at is null and cancelled_at is null;

create table app_private.notification_inbox_evaluations (
  source_event_id uuid primary key,
  outcome text not null check (
    outcome in ('created', 'disabled', 'stale', 'suppressed')
  ),
  inbox_item_id uuid references public.notification_inbox_items(id),
  preference_version bigint check (preference_version >= 0),
  delivery_not_before timestamptz,
  quiet_applied boolean,
  reason_code text check (
    reason_code is null
    or reason_code in (
      'CATEGORY_DISABLED', 'LATEST_STATE_SUPPRESSED', 'SOURCE_SUPPRESSED'
    )
  ),
  evaluated_at timestamptz not null
);

-- WP05-04 evaluates native push independently from in-app materialization.
-- A source event can therefore produce Android push delivery rows when
-- in_app=false and native_push=true; inbox_item_id remains an optional link.
create table app_private.notification_push_evaluations (
  source_event_id uuid primary key,
  processing_status text not null check (
    processing_status in (
      'pending', 'materialized', 'disabled', 'stale', 'no_endpoint'
    )
  ),
  next_evaluation_at timestamptz,
  reason_code text check (
    reason_code is null
    or reason_code in (
      'NATIVE_PUSH_DISABLED', 'LATEST_STATE_SUPPRESSED',
      'NO_ACTIVE_ANDROID_ENDPOINT'
    )
  ),
  created_at timestamptz not null,
  evaluated_at timestamptz
);

create table app_private.notification_push_deliveries (
  id uuid primary key default gen_random_uuid(),
  source_event_id uuid not null,
  inbox_item_id uuid references public.notification_inbox_items(id)
    on delete set null,
  endpoint_id uuid not null references public.notification_endpoints(id)
    on delete cascade,
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  recipient_member_id uuid not null,
  household_id uuid not null references public.households(id) on delete cascade,
  category text not null check (category in ('chore_due', 'chore_assignment')),
  subject_type text not null check (subject_type = 'chore_occurrence'),
  subject_id uuid not null,
  processing_status text not null check (
    processing_status in (
      'pending', 'leased', 'retry_wait', 'succeeded', 'failed', 'cancelled'
    )
  ),
  attempts integer not null check (attempts between 0 and 5),
  max_attempts integer not null check (max_attempts between 1 and 5),
  next_attempt_at timestamptz,
  lease_owner uuid,
  lease_token uuid,
  lease_expires_at timestamptz,
  last_result_code text,
  provider_receipt_hash bytea check (
    provider_receipt_hash is null or octet_length(provider_receipt_hash) = 32
  ),
  completed_lease_token uuid,
  completed_token_fingerprint bytea check (
    completed_token_fingerprint is null
    or octet_length(completed_token_fingerprint) = 32
  ),
  completion_outcome text check (
    completion_outcome is null
    or completion_outcome in (
      'accepted', 'retryable', 'invalid_token', 'permanent', 'ambiguous'
    )
  ),
  completed_retry_after_seconds integer,
  endpoint_invalidated boolean not null default false,
  scheduled_at timestamptz not null,
  expires_at timestamptz not null,
  replay_count integer not null default 0 check (replay_count >= 0),
  submission_started_at timestamptz,
  submission_lease_token uuid,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  completed_at timestamptz,
  unique (source_event_id, endpoint_id),
  check (scheduled_at = created_at),
  check (expires_at = scheduled_at + interval '1 hour'),
  check (
    (submission_started_at is null) = (submission_lease_token is null)
  ),
  foreign key (household_id, recipient_member_id, recipient_user_id)
    references public.household_members(household_id, id, auth_user_id),
  foreign key (household_id, subject_id)
    references public.chore_occurrences(household_id, id) on delete cascade
);

create table app_private.notification_push_worker_control (
  worker_key text primary key check (worker_key = 'android_fcm_push'),
  paused boolean not null,
  reason_code text check (reason_code is null or reason_code = 'ROLLBACK_DISABLED'),
  updated_at timestamptz not null,
  check (paused = (reason_code is not null))
);

create table app_private.notification_push_provider_health (
  provider_key text primary key check (provider_key = 'fcm_android'),
  backoff_until timestamptz,
  backoff_reason_code text,
  consecutive_retryable_failures integer not null default 0,
  last_attempt_at timestamptz,
  last_success_at timestamptz,
  last_retryable_failure_at timestamptz,
  last_ambiguous_at timestamptz,
  last_permanent_failure_at timestamptz,
  updated_at timestamptz not null,
  check ((backoff_until is null) = (backoff_reason_code is null))
);

create table app_private.notification_push_delivery_transitions (
  id bigint generated always as identity primary key,
  delivery_id uuid not null
    references app_private.notification_push_deliveries(id) on delete cascade,
  transition text not null,
  attempt integer not null check (attempt between 0 and 5),
  result_code text,
  occurred_at timestamptz not null
);

-- Exact WP05-04/05 mediated APIs are service-role-only:
-- claim_notification_push_deliveries,
-- mark_notification_push_submission_started,
-- complete_notification_push_delivery,
-- replay_notification_push_delivery,
-- reset_notification_push_provider_backoff,
-- get_notification_push_reliability_health and
-- set_notification_push_worker_paused, plus authenticated
-- resolve_notification_push_target. Private evaluation/delivery/control tables
-- have no anon, authenticated, or direct service-role privileges. Transition
-- history is immutable. Health is aggregate-only. Provider receipt plaintext is
-- never stored; only its 32-byte SHA-256 digest is retained.

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

-- Store MVP specialization is app_private.chore_notification_outbox plus
-- app_private.notification_event_resolutions/notification_worker_transitions.
-- Its exact lease/retry/dead-letter API is contracts/notification-worker.yaml;
-- the generic cross-domain table below remains a later-phase reference and is
-- not a client or direct service-role surface.
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

-- Billing ingestion ships closed. Only service-role commands can change this row.
create table app_private.billing_runtime_config (
  singleton boolean primary key default true check (singleton),
  provider text not null default 'revenuecat' check (provider = 'revenuecat'),
  accepted_environment text not null default 'disabled'
    check (accepted_environment in ('disabled', 'sandbox', 'production')),
  ingestion_enabled boolean not null default false,
  feature_enforcement_enabled boolean not null default false,
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  check (not ingestion_enabled or accepted_environment <> 'disabled')
);

create table public.billing_customers (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete restrict,
  provider text not null check (provider in ('revenuecat', 'web')),
  environment text not null check (environment in ('sandbox', 'production')),
  provider_customer_ref text not null,
  provider_customer_ref_hash bytea not null check (octet_length(provider_customer_ref_hash) = 32),
  last_verified_at timestamptz,
  provider_updated_at timestamptz,
  last_receipt_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  unique (id, auth_user_id),
  unique (id, provider, environment),
  unique (provider, environment, auth_user_id),
  unique (provider, environment, provider_customer_ref_hash),
  check (provider_customer_ref_hash = digest(convert_to(provider_customer_ref, 'UTF8'), 'sha256')),
  check (provider <> 'revenuecat' or provider_customer_ref = auth_user_id::text)
);

create table public.billing_webhook_receipts (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (provider in ('revenuecat', 'web')),
  environment text not null check (environment in ('sandbox', 'production')),
  provider_event_id text not null,
  event_type text not null check (event_type in (
    'initial_purchase', 'renewal', 'cancellation', 'uncancellation',
    'grace', 'billing_issue', 'expiration', 'refund', 'revoke', 'reconciliation'
  )),
  request_hash bytea not null check (octet_length(request_hash) = 32),
  payload_version text,
  payload_ciphertext bytea check (payload_ciphertext is null or octet_length(payload_ciphertext) <= 1048576),
  provider_occurred_at timestamptz not null,
  received_at timestamptz not null default now(),
  last_received_at timestamptz not null default now(),
  processed_at timestamptz,
  processing_status text not null default 'received'
    check (processing_status in ('received', 'applied', 'stale', 'quarantined')),
  last_error_code text,
  replay_count integer not null default 0 check (replay_count >= 0),
  billing_customer_id uuid,
  billing_transaction_id uuid,
  assignment_id uuid,
  household_id uuid,
  correlation_id uuid not null,
  unique (provider, environment, provider_event_id)
);

create table public.billing_transactions (
  id uuid primary key default gen_random_uuid(),
  billing_customer_id uuid not null,
  provider text not null check (provider in ('revenuecat', 'web')),
  environment text not null check (environment in ('sandbox', 'production')),
  source text not null check (source in ('app_store', 'play_store', 'web', 'manual_support')),
  product_id text not null,
  transaction_ref_hash bytea not null check (octet_length(transaction_ref_hash) = 32),
  original_transaction_ref_hash bytea check (
    original_transaction_ref_hash is null or octet_length(original_transaction_ref_hash) = 32
  ),
  status public.entitlement_status not null check (status <> 'none'),
  purchased_at timestamptz,
  current_period_start timestamptz,
  current_period_end timestamptz,
  will_renew boolean not null,
  provider_updated_at timestamptz not null,
  verified_at timestamptz not null default now(),
  last_receipt_id uuid not null references public.billing_webhook_receipts(id) on delete restrict,
  raw_snapshot_ciphertext bytea check (
    raw_snapshot_ciphertext is null or octet_length(raw_snapshot_ciphertext) <= 1048576
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  unique (id, provider, environment),
  unique (provider, environment, transaction_ref_hash),
  foreign key (billing_customer_id, provider, environment)
    references public.billing_customers(id, provider, environment) on delete restrict
);

create table public.billing_household_assignments (
  id uuid primary key default gen_random_uuid(),
  billing_customer_id uuid not null,
  billing_owner_user_id uuid not null,
  household_id uuid not null references public.households(id) on delete restrict,
  status text not null check (status in ('active', 'ended', 'revoked')),
  binding_state text not null default 'confirmed'
    check (binding_state in ('provisional', 'confirmed')),
  assigned_at timestamptz not null default now(),
  confirmed_at timestamptz default statement_timestamp(),
  intent_expires_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  unique (id, household_id),
  unique (id, household_id, billing_owner_user_id),
  foreign key (billing_customer_id, billing_owner_user_id)
    references public.billing_customers(id, auth_user_id) on delete restrict,
  check ((status = 'active' and ended_at is null) or (status in ('ended', 'revoked') and ended_at is not null)),
  check (
    (binding_state = 'confirmed' and confirmed_at is not null and intent_expires_at is null)
    or
    (binding_state = 'provisional' and confirmed_at is null and intent_expires_at > assigned_at)
  ),
  check (confirmed_at is null or confirmed_at >= assigned_at)
);

create unique index billing_assignment_customer_active_uq
  on public.billing_household_assignments(billing_customer_id)
  where status = 'active';
create unique index billing_assignment_household_active_uq
  on public.billing_household_assignments(household_id)
  where status = 'active';

-- WP06-05 client choices and support workflow remain private. Provider,
-- environment and billing customer identity are derived by the server.
create table app_private.billing_assignment_intents (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete restrict,
  household_id uuid not null references public.households(id) on delete restrict,
  billing_customer_id uuid references public.billing_customers(id) on delete restrict,
  assignment_id uuid references public.billing_household_assignments(id) on delete restrict,
  idempotency_key uuid not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  outcome text not null check (outcome in (
    'ready', 'already_ready', 'customer_conflict', 'household_conflict'
  )),
  lifecycle_state text not null check (lifecycle_state in (
    'prepared', 'consumed', 'released', 'expired', 'superseded', 'conflict'
  )),
  result_assignment_version bigint,
  intent_expires_at timestamptz,
  requeued_job_count integer not null default 0 check (requeued_job_count between 0 and 1000),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  unique (auth_user_id, idempotency_key)
);

create table app_private.billing_assignment_release_results (
  auth_user_id uuid not null references auth.users(id) on delete restrict,
  idempotency_key uuid not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  household_id uuid not null references public.households(id) on delete restrict,
  outcome text not null check (outcome in (
    'released', 'already_released', 'support_required'
  )),
  result_assignment_version bigint,
  created_at timestamptz not null default now(),
  primary key (auth_user_id, idempotency_key)
);

create table app_private.billing_assignment_remediation_requests (
  id uuid primary key default gen_random_uuid(),
  requester_user_id uuid not null references auth.users(id) on delete restrict,
  household_id uuid not null references public.households(id) on delete restrict,
  provider text not null check (provider = 'revenuecat'),
  environment text not null check (environment in ('sandbox', 'production')),
  issue_kind text not null check (issue_kind in (
    'customer_conflict', 'household_conflict',
    'owner_membership_changed', 'restore_conflict'
  )),
  status text not null check (status in ('open', 'resolved', 'rejected')),
  subject_assignment_id uuid references public.billing_household_assignments(id) on delete restrict,
  idempotency_key uuid not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  unique (requester_user_id, idempotency_key)
);

create unique index billing_assignment_remediation_open_uq
  on app_private.billing_assignment_remediation_requests(
    requester_user_id, household_id, issue_kind
  ) where status = 'open';

create table app_private.billing_assignment_remediation_command_results (
  requester_user_id uuid not null references auth.users(id) on delete restrict,
  idempotency_key uuid not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  request_id uuid not null references app_private.billing_assignment_remediation_requests(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (requester_user_id, idempotency_key)
);

create table app_private.billing_assignment_transitions (
  id bigint generated always as identity primary key,
  assignment_id uuid not null references public.billing_household_assignments(id) on delete restrict,
  previous_assignment_id uuid references public.billing_household_assignments(id) on delete restrict,
  action text not null check (action in (
    'prepared', 'renewed', 'confirmed', 'released', 'expired', 'transferred'
  )),
  actor_kind text not null check (actor_kind in ('client', 'provider', 'system', 'support')),
  actor_user_id uuid references auth.users(id) on delete restrict,
  source_household_id uuid references public.households(id) on delete restrict,
  target_household_id uuid not null references public.households(id) on delete restrict,
  previous_binding_state text check (previous_binding_state in ('provisional', 'confirmed')),
  next_binding_state text not null check (next_binding_state in ('provisional', 'confirmed')),
  reason_code text,
  correlation_id uuid not null,
  occurred_at timestamptz not null
);

create table app_private.billing_assignment_remediation_actions (
  id bigint generated always as identity primary key,
  request_id uuid not null unique references app_private.billing_assignment_remediation_requests(id) on delete restrict,
  action text not null check (action in (
    'transfer_customer', 'release_expired_provisional', 'reject'
  )),
  reason_code text not null check (reason_code in (
    'ownership_verified', 'account_recovery', 'duplicate_assignment', 'policy_denied'
  )),
  case_reference_hash bytea not null check (octet_length(case_reference_hash) = 32),
  previous_assignment_id uuid references public.billing_household_assignments(id) on delete restrict,
  result_assignment_id uuid references public.billing_household_assignments(id) on delete restrict,
  correlation_id uuid not null,
  resolved_at timestamptz not null
);

create table public.plan_catalog (
  plan_code text primary key check (plan_code in ('free', 'plus')),
  feature_limits jsonb not null default '{}'::jsonb,
  limits_finalized boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0)
);

create table public.household_entitlements (
  household_id uuid primary key references public.households(id) on delete cascade,
  assignment_id uuid,
  billing_owner_user_id uuid references auth.users(id) on delete restrict,
  plan_code text not null references public.plan_catalog(plan_code),
  status public.entitlement_status not null default 'none',
  source text not null check (source in ('app_store', 'play_store', 'web', 'manual_support', 'none')),
  product_id text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  will_renew boolean not null default false,
  features jsonb not null default '{}'::jsonb,
  provider_updated_at timestamptz,
  verified_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  foreign key (assignment_id, household_id, billing_owner_user_id)
    references public.billing_household_assignments(id, household_id, billing_owner_user_id)
    on delete restrict,
  check (
    (status in ('trialing', 'active', 'grace') and plan_code = 'plus')
    or (status in ('none', 'expired', 'revoked') and plan_code = 'free')
    or status = 'billing_issue'
  ),
  check (status not in ('expired', 'revoked') or not will_renew)
);

alter table public.billing_customers
  add foreign key (last_receipt_id)
  references public.billing_webhook_receipts(id) on delete restrict;

alter table public.billing_webhook_receipts
  add foreign key (billing_customer_id, provider, environment)
    references public.billing_customers(id, provider, environment) on delete restrict,
  add foreign key (billing_transaction_id, provider, environment)
    references public.billing_transactions(id, provider, environment) on delete restrict,
  add foreign key (assignment_id, household_id)
    references public.billing_household_assignments(id, household_id) on delete restrict,
  add foreign key (household_id)
    references public.households(id) on delete restrict;

-- Private immutable append-only audit. Direct table access is revoked even from service_role.
create table app_private.billing_entitlement_transitions (
  id bigint generated always as identity primary key,
  receipt_id uuid not null unique,
  household_id uuid not null,
  assignment_id uuid not null,
  billing_transaction_id uuid not null,
  event_type text not null,
  previous_plan_code text not null,
  next_plan_code text not null,
  previous_status public.entitlement_status not null,
  next_status public.entitlement_status not null,
  provider_occurred_at timestamptz not null,
  correlation_id uuid not null,
  applied_at timestamptz not null default now()
);

create table app_private.billing_policy_events (
  id bigint generated always as identity primary key,
  policy_kind text not null check (policy_kind in ('runtime', 'plan')),
  policy_key text not null,
  previous_version bigint not null,
  next_version bigint not null check (next_version = previous_version + 1),
  correlation_id uuid not null,
  changed_at timestamptz not null default now()
);

-- Service-only commands use SECURITY DEFINER with an empty search_path:
-- configure_billing_runtime, configure_plan_feature_limits,
-- configure_billing_feature_enforcement,
-- apply_verified_billing_event, expire_billing_household_assignments and
-- resolve_billing_assignment_remediation. Authenticated active members may
-- execute get_household_entitlement and assignment status; active Owner/Admin
-- may prepare an explicit household, release only their provisional binding,
-- and request aggregate remediation. These projections omit customer, provider
-- event, transaction, receipt, other-household, billing-owner and case text.
-- Every private assignment table is revoked from public, anon, authenticated
-- and service_role; assignment, remediation and policy action audit rows are immutable.

create table public.privacy_requests (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete restrict,
  household_id uuid references public.households(id) on delete set null,
  request_type public.privacy_request_type not null,
  status public.privacy_request_status not null default 'queued',
  requested_at timestamptz not null default now(),
  verified_at timestamptz not null,
  scheduled_for timestamptz not null,
  processing_started_at timestamptz,
  completed_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  failure_code text,
  active_subscription_at_request boolean not null,
  subscription_acknowledged boolean not null,
  correlation_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  check (request_type <> 'delete_account' or household_id is null),
  check (not active_subscription_at_request or subscription_acknowledged),
  check (verified_at >= requested_at and scheduled_for >= verified_at)
);

create unique index privacy_pending_request_uq
  on public.privacy_requests(auth_user_id, request_type)
  where status in ('queued', 'verifying', 'processing');

-- WP07-01 account deletion private authority. Exact state/check constraints,
-- execute grants, tombstone fields and transition rules are normative in
-- account-deletion.yaml and migration 20260808100000_account_deletion_lifecycle.sql.
create table app_private.privacy_runtime_config (
  singleton boolean primary key default true check (singleton),
  account_deletion_requests_enabled boolean not null default true,
  account_deletion_cancellation_window_seconds integer not null default 86400
    check (account_deletion_cancellation_window_seconds between 3600 and 604800),
  data_export_requests_enabled boolean not null default true,
  data_export_downloads_enabled boolean not null default true,
  data_export_artifact_ttl_seconds integer not null default 86400
    check (data_export_artifact_ttl_seconds between 3600 and 604800),
  data_export_download_grant_ttl_seconds integer not null default 300
    check (data_export_download_grant_ttl_seconds between 60 and 900),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0)
);

create table app_private.account_deletion_command_requests (
  auth_user_id uuid not null references auth.users(id) on delete restrict,
  idempotency_key text not null,
  operation text not null check (operation in ('request', 'cancel')),
  request_hash bytea not null check (octet_length(request_hash) = 32),
  privacy_request_id uuid not null references public.privacy_requests(id) on delete restrict,
  result_version bigint not null check (result_version > 0),
  created_at timestamptz not null default now(),
  primary key (auth_user_id, idempotency_key)
);

create table app_private.account_deletion_jobs (
  privacy_request_id uuid primary key references public.privacy_requests(id) on delete restrict,
  processing_status text not null,
  attempts integer not null default 0 check (attempts between 0 and 5),
  max_attempts integer not null default 5 check (max_attempts between 1 and 5),
  next_attempt_at timestamptz,
  lease_owner uuid,
  lease_token uuid,
  lease_expires_at timestamptz,
  tombstoned_at timestamptz,
  auth_soft_deleted_at timestamptz,
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table app_private.account_deletion_events (
  id bigint generated always as identity primary key,
  privacy_request_id uuid not null references public.privacy_requests(id) on delete restrict,
  transition text not null,
  request_status public.privacy_request_status not null,
  request_version bigint not null check (request_version > 0),
  correlation_id uuid not null,
  safe_metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

-- Account deletion changes these existing identity-bearing rows additively.
-- A deleted identity cannot regain an active membership, and the endpoint
-- reason allowlist includes account_deleted.
alter table public.household_members add column identity_deleted_at timestamptz;

create table public.data_exports (
  id uuid primary key default extensions.gen_random_uuid(),
  privacy_request_id uuid not null unique references public.privacy_requests(id) on delete restrict,
  schema_version text not null default '2026-08-08-wp07-02a'
    check (schema_version = '2026-08-08-wp07-02a'),
  machine_object_key text,
  human_object_key text,
  machine_checksum_sha256 text,
  human_checksum_sha256 text,
  machine_size_bytes bigint check (machine_size_bytes between 1 and 10485760),
  human_size_bytes bigint check (human_size_bytes between 1 and 10485760),
  artifact_expires_at timestamptz,
  revoked_at timestamptz,
  purged_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0)
);

-- WP07-02A private export authority. Exact state/check constraints, function
-- signatures, safe metadata, grants and transitions are normative in
-- data-export.yaml and migration 20260808110000_personal_data_export_lifecycle.sql.
create table app_private.data_export_command_requests (
  auth_user_id uuid not null references auth.users(id) on delete restrict,
  idempotency_key text not null,
  operation text not null check (operation in ('request', 'cancel', 'revoke')),
  request_hash bytea not null check (octet_length(request_hash) = 32),
  privacy_request_id uuid not null references public.privacy_requests(id) on delete restrict,
  result_request_version bigint not null check (result_request_version > 0),
  result_artifact_version bigint check (result_artifact_version > 0),
  created_at timestamptz not null default now(),
  primary key (auth_user_id, idempotency_key)
);

create table app_private.data_export_jobs (
  privacy_request_id uuid primary key references public.privacy_requests(id) on delete restrict,
  data_export_id uuid not null unique references public.data_exports(id) on delete restrict,
  artifact_prefix uuid not null unique default extensions.gen_random_uuid(),
  processing_status text not null,
  attempts integer not null default 0 check (attempts between 0 and 5),
  max_attempts integer not null default 5 check (max_attempts between 1 and 5),
  next_attempt_at timestamptz,
  lease_owner uuid,
  lease_token uuid,
  lease_expires_at timestamptz,
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table app_private.data_export_download_grants (
  id uuid primary key default extensions.gen_random_uuid(),
  data_export_id uuid not null references public.data_exports(id) on delete restrict,
  token_hash bytea not null unique check (octet_length(token_hash) = 32),
  export_format text not null check (export_format in ('json', 'text')),
  correlation_id uuid not null,
  issued_at timestamptz not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  revoked_at timestamptz
);

create table app_private.data_export_purge_jobs (
  data_export_id uuid primary key references public.data_exports(id) on delete restrict,
  processing_status text not null,
  attempts integer not null default 0 check (attempts between 0 and 5),
  max_attempts integer not null default 5 check (max_attempts between 1 and 5),
  next_attempt_at timestamptz not null,
  lease_owner uuid,
  lease_token uuid,
  lease_expires_at timestamptz,
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table app_private.data_export_events (
  id bigint generated always as identity primary key,
  privacy_request_id uuid not null references public.privacy_requests(id) on delete restrict,
  data_export_id uuid not null references public.data_exports(id) on delete restrict,
  transition text not null,
  request_status public.privacy_request_status not null,
  request_version bigint not null check (request_version > 0),
  correlation_id uuid not null,
  safe_metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
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

-- WP06-04 metadata-only provider ingress and authoritative refresh queue.
-- Raw webhook JSON and RevenueCat subscriber responses are never persisted.
create table app_private.billing_reconciliation_jobs (
  id uuid primary key default gen_random_uuid(),
  provider text not null default 'revenuecat' check (provider = 'revenuecat'),
  source text not null check (source in ('webhook', 'periodic')),
  provider_event_id text not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  api_version text not null,
  event_type text not null,
  auth_user_id uuid,
  environment text check (environment in ('sandbox', 'production')),
  provider_occurred_at timestamptz not null,
  processing_status text not null check (
    processing_status in (
      'queued', 'leased', 'retry_wait', 'succeeded', 'ignored', 'dead_letter'
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
  last_error_code text,
  received_at timestamptz not null default now(),
  last_received_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  correlation_id uuid not null,
  unique (provider, provider_event_id),
  check (
    processing_status in ('ignored', 'dead_letter')
    or (auth_user_id is not null and environment is not null)
  )
);

create index billing_reconciliation_due_idx
  on app_private.billing_reconciliation_jobs(
    processing_status, next_attempt_at, received_at, id
  );
create index billing_reconciliation_lease_idx
  on app_private.billing_reconciliation_jobs(lease_expires_at)
  where processing_status = 'leased';

create table app_private.billing_reconciliation_transitions (
  id bigint generated always as identity primary key,
  job_id uuid not null
    references app_private.billing_reconciliation_jobs(id) on delete restrict,
  transition text not null check (
    transition in (
      'queued', 'ignored', 'dead_lettered', 'replayed', 'claimed',
      'retry_scheduled', 'succeeded', 'requeued'
    )
  ),
  attempt integer not null check (attempt between 0 and 5),
  result_code text,
  occurred_at timestamptz not null
);

revoke all on table app_private.billing_reconciliation_jobs
  from public, anon, authenticated, service_role;
revoke all on table app_private.billing_reconciliation_transitions
  from public, anon, authenticated, service_role;

-- The ordered migration defines empty-search-path SECURITY DEFINER RPCs:
-- enqueue_revenuecat_webhook, schedule_due_billing_reconciliations,
-- claim_billing_reconciliation_jobs, complete_billing_reconciliation_job,
-- and get_billing_reconciliation_health. Execute is granted only to service_role.
-- Provider event ID ingress is serialized with a transaction advisory lock;
-- claims use FOR UPDATE SKIP LOCKED and completion is lease-token idempotent.

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
    'billing_customers', 'billing_transactions', 'billing_household_assignments',
    'plan_catalog', 'household_entitlements'
  ]
  loop
    execute format(
      'create trigger %I_set_updated before update on public.%I for each row execute function app_private.set_updated_at_and_version()',
      table_name, table_name
    );
  end loop;
end $$;

-- WP06-06 feature capacity is enforced only after the versioned service command
-- configure_billing_feature_enforcement verifies both active finalized policies.
-- Authenticated active members may call get_household_feature_gate for an exact
-- aggregate-only projection. Server triggers serialize active member and first/
-- reactivated recurring chore/calendar series expansion by household+feature.
-- One-time series, existing reads/updates/cancel/delete and downgrade data are
-- preserved. KFB10/KFB11 indicate unavailable policy and KFB12 limit reached.

-- Baseline plan rows are additive. Product limits remain unfinalized until D-027 is accepted.
insert into public.plan_catalog(plan_code, feature_limits, limits_finalized)
values
  ('free', '{}'::jsonb, false),
  ('plus', '{}'::jsonb, false)
on conflict (plan_code) do nothing;

-- WP03-11 adds no activation/visit table or event. The projection is derived
-- at read time from historical memberships, content-free series-created events,
-- completed audit rows and the database household-local date boundary.
create index chore_completion_events_activation_progress_idx
  on public.chore_completion_events(household_id, actor_member_id)
  where event_type = 'completed';

-- The ordered migration defines public.get_household_activation_progress(uuid)
-- as an exact five-field capped aggregate. It returns no member, user, chore,
-- occurrence, content or event timestamp identifiers.

-- WP03-18 reads exactly one selected closed household-local week. No report,
-- analytics or cache table is added; this partial covering index bounds the
-- occurrence scan to report-relevant states and avoids reading chore content.
create index chore_occurrences_weekly_report_idx
  on public.chore_occurrences(household_id, due_local_date, status)
  include (completed_by_member_id, completed_at)
  where status in ('scheduled', 'completed', 'skipped');

-- The ordered migration defines public.get_household_weekly_report(uuid,
-- integer) as a server-clock, current-household-timezone SECURITY DEFINER read.
-- It returns exact aggregate fields plus at most 20 active contributor rows;
-- removed, deleted and overflow contributions are count-only.

-- WP03-20 adds no table or column. The ordered migration defines the additive
-- public.update_repeating_chore_series_from_occurrence(uuid, uuid, uuid, uuid,
-- bigint, text, text, uuid, time without time zone, jsonb) command. Its private
-- shared engine derives effective_local_date only from the locked active
-- scheduled target occurrence recurrence_local_date, preserves earlier and
-- completed historical revisions, rebuilds later incomplete rows through the
-- canonical materializer and leaves the legacy household-local-today RPC and
-- its request hash compatible.

-- WP03-21 adds no table or column. The ordered migration defines the additive
-- public.cancel_repeating_chore_series_from_occurrence(uuid, uuid, uuid, uuid,
-- bigint) command. The locked active scheduled occurrence recurrence_local_date
-- is the exclusive end boundary: later incomplete rows are cancelled, later
-- completed rows stay historical, and an earlier scheduled prefix receives an
-- immutable bounded terminal revision. If no prefix remains, the existing
-- whole-series soft-delete behavior applies. The existing cancellation event
-- and command-request revision-shape checks are widened only to permit that
-- optional terminal revision identity.

-- WP03-22 adds app_private.chore_series_cancellation_restore_items as an
-- immutable, grant-free metadata-only ledger keyed by authenticated actor,
-- cancellation command and occurrence. It stores only household/series IDs,
-- mutation kind and previous/post status, revision and version. The ordered
-- migration moves the WP03-21 engine private behind its compatible public
-- wrapper, widens immutable aggregate/request operation checks with `resumed`,
-- and adds public.resume_repeating_chore_series_cancellation(uuid, uuid, uuid,
-- uuid, bigint). Resume clones the pre-cancellation source into a new immutable
-- revision, restores exact ledger-bound scheduled/skipped state, preserves
-- completed or later-edited prefix rows and clears materialization coverage.

-- WP04-16 adds app_private.calendar_series_cancellation_undo_items as an
-- immutable, grant-free metadata-only ledger keyed by authenticated actor,
-- cancellation command and occurrence. It stores only household/series/
-- occurrence IDs, mutation kind and previous/post status, revision and version.
-- The ordered migration moves the WP04-15 selected-cancellation engine private
-- behind its exact compatible wrapper, widens immutable aggregate/request/audit
-- operation checks with `resumed`, and adds
-- public.resume_recurring_calendar_series_cancellation(uuid, uuid, uuid, uuid,
-- bigint). Resume rechecks current active membership and exact version/post-state,
-- clones source content and active participants into a new immutable revision,
-- restores scheduled/completed/skipped suffix and unchanged terminal-prefix
-- rows, preserves later-edited prefix rows and clears materialization coverage.

-- WP05-12 adds app_private.calendar_notification_snooze_commands as an
-- immutable, grant-free metadata-only receipt ledger keyed by caller UUID.
-- It stores source/item/household/member/occurrence identifiers, optimistic
-- item version, fixed 5/10/30-minute choice, count 1..3, authoritative unread
-- count and exact recorded/snoozed timestamps; it stores no Calendar content,
-- email, push token, provider response or free-form error.
--
-- The ordered migration widens the existing source-event constraint with
-- calendar.occurrence_reminder_snoozed and a strict content-free nine-key
-- payload, makes causation_id part of the NULLS-NOT-DISTINCT source identity,
-- and permits inbox cancellation_reason `snoozed`. It adds authenticated
-- public.list_notification_inbox_items_v2(uuid, integer, timestamptz, uuid)
-- with an exact 16-field projection and
-- public.snooze_calendar_notification(uuid, uuid, integer, uuid, bigint)
-- with an exact nine-field receipt. The command atomically supersedes the
-- original inbox/pending delivery and emits a replacement source while
-- retaining terminal evaluation/provider history. Existing inbox v1 remains.

-- WP05-14 generic notification email fallback is private and address-free.
-- The ordered migration owns the full state-machine checks and indexes; this
-- skeleton records the persistence boundary. There is deliberately no email,
-- sender, subject copy, body, deep link, provider body or raw-error column.
create table app_private.notification_email_evaluations (
  source_event_id uuid primary key
    references app_private.chore_notification_outbox(event_id) on delete cascade,
  processing_status text not null,
  next_evaluation_at timestamptz,
  reason_code text,
  created_at timestamptz not null,
  evaluated_at timestamptz
);

create table app_private.notification_email_deliveries (
  id uuid primary key default gen_random_uuid(),
  source_event_id uuid not null unique
    references app_private.notification_email_evaluations(source_event_id)
    on delete cascade,
  inbox_item_id uuid references public.notification_inbox_items(id) on delete set null,
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  recipient_member_id uuid not null,
  household_id uuid not null references public.households(id) on delete cascade,
  category text not null,
  subject_type text not null,
  subject_id uuid not null,
  processing_status text not null,
  attempts integer not null default 0,
  max_attempts integer not null default 5,
  next_attempt_at timestamptz,
  lease_owner uuid,
  lease_token uuid,
  lease_expires_at timestamptz,
  submission_started_at timestamptz,
  submission_lease_token uuid,
  last_result_code text,
  provider_message_id_hash bytea,
  completed_lease_token uuid,
  completion_outcome text,
  completed_retry_after_seconds integer,
  scheduled_at timestamptz not null,
  expires_at timestamptz not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  completed_at timestamptz,
  foreign key (household_id, recipient_member_id, recipient_user_id)
    references public.household_members(household_id, id, auth_user_id)
);

create table app_private.notification_email_delivery_transitions (
  id bigint generated always as identity primary key,
  delivery_id uuid not null
    references app_private.notification_email_deliveries(id) on delete cascade,
  transition text not null,
  attempt integer not null,
  result_code text,
  occurred_at timestamptz not null
);

create table app_private.notification_email_worker_control (
  worker_key text primary key,
  paused boolean not null default false,
  reason_code text,
  updated_at timestamptz not null
);

-- All four tables and the transition identity sequence are revoked from
-- public, anon, authenticated and service_role. The empty-search-path,
-- service-role-only API is exactly:
--   claim_notification_email_deliveries(uuid, integer, integer, timestamptz)
--   mark_notification_email_submission_started(uuid, uuid, timestamptz)
--   complete_notification_email_delivery(
--     uuid, uuid, text, text, text, integer, timestamptz
--   )
--   set_notification_email_worker_paused(boolean, timestamptz)
-- The claim alone joins auth.users and returns one confirmed address
-- ephemerally; completion accepts only a base64 SHA-256 provider receipt.
```
