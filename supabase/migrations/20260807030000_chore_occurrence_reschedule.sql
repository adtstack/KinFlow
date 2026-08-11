-- KinFlow WP03-05D single-occurrence reschedule.
-- Store MVP scope: online-only, versioned date/time override for one
-- scheduled repeating occurrence.

create table public.chore_reschedule_events (
  id uuid primary key default extensions.gen_random_uuid(),
  household_id uuid not null,
  occurrence_id uuid not null,
  actor_user_id uuid
    references auth.users(id) on delete set null,
  actor_member_id uuid not null,
  previous_due_local_date date not null,
  previous_due_local_time time without time zone,
  previous_due_at timestamptz,
  new_due_local_date date not null,
  new_due_local_time time without time zone,
  new_due_at timestamptz,
  occurred_at timestamptz not null default now(),
  occurrence_version bigint not null check (occurrence_version > 0),
  correlation_id uuid not null,
  unique (household_id, id),
  unique (actor_user_id, correlation_id),
  constraint reschedule_event_occurrence_fk
    foreign key (household_id, occurrence_id)
    references public.chore_occurrences(household_id, id)
    on delete cascade,
  constraint reschedule_event_actor_fk
    foreign key (household_id, actor_member_id)
    references public.household_members(household_id, id),
  constraint reschedule_event_previous_time_ck check (
    (previous_due_local_time is null) = (previous_due_at is null)
  ),
  constraint reschedule_event_new_time_ck check (
    (new_due_local_time is null) = (new_due_at is null)
  ),
  constraint reschedule_event_changed_ck check (
    previous_due_local_date is distinct from new_due_local_date
    or previous_due_local_time is distinct from new_due_local_time
  )
);

create index chore_reschedule_events_occurrence_time_idx
  on public.chore_reschedule_events(
    household_id,
    occurrence_id,
    occurred_at desc
  );

create or replace function app_private.reject_chore_reschedule_event_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'chore reschedule events are immutable';
end;
$$;

revoke all on function app_private.reject_chore_reschedule_event_mutation()
  from public;

create trigger chore_reschedule_events_immutable
before update or delete on public.chore_reschedule_events
for each row
execute function app_private.reject_chore_reschedule_event_mutation();

alter table public.chore_reschedule_events enable row level security;
alter table public.chore_reschedule_events force row level security;

create policy chore_reschedule_events_select_member
on public.chore_reschedule_events
for select
to authenticated
using (app_private.is_active_household_member(household_id));

revoke all on table public.chore_reschedule_events
  from anon, authenticated;
grant select on table public.chore_reschedule_events
  to authenticated;

create table app_private.chore_reschedule_command_requests (
  authenticated_user_id uuid not null
    references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  household_id uuid not null,
  occurrence_id uuid not null,
  result_due_local_date date not null,
  result_due_local_time time without time zone,
  result_due_at timestamptz,
  result_version bigint not null check (result_version > 0),
  result_event_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (authenticated_user_id, idempotency_key),
  constraint reschedule_request_result_time_ck check (
    (result_due_local_time is null) = (result_due_at is null)
  ),
  constraint reschedule_request_occurrence_fk
    foreign key (household_id, occurrence_id)
    references public.chore_occurrences(household_id, id)
    on delete cascade,
  constraint reschedule_request_event_fk
    foreign key (household_id, result_event_id)
    references public.chore_reschedule_events(household_id, id)
    on delete cascade
);

revoke all on table app_private.chore_reschedule_command_requests
  from public, anon, authenticated;

create or replace function public.reschedule_chore_occurrence(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_occurrence_id uuid,
  p_expected_version bigint,
  p_due_local_date date,
  p_due_local_time time without time zone
)
returns table (
  household_id uuid,
  occurrence_id uuid,
  due_local_date date,
  due_local_time time without time zone,
  due_at timestamptz,
  status text,
  version bigint,
  changed boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_actor_member_id uuid;
  v_actor_role public.household_role;
  v_assignee_member_id uuid;
  v_current_status public.occurrence_status;
  v_current_version bigint;
  v_current_due_local_date date;
  v_current_due_local_time time without time zone;
  v_current_due_at timestamptz;
  v_timezone text;
  v_recurrence_rule jsonb;
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_result_due_local_date date;
  v_result_due_local_time time without time zone;
  v_result_due_at timestamptz;
  v_result_version bigint;
  v_result_event_id uuid;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFC01',
      message = 'authentication required';
  end if;

  if p_idempotency_key is null
    or p_household_id is null
    or p_occurrence_id is null
    or p_expected_version is null
    or p_expected_version < 1
    or p_due_local_date is null
    or (
      p_due_local_time is not null
      and extract(second from p_due_local_time) <> 0
    ) then
    raise exception using
      errcode = 'KFC02',
      message = 'invalid chore input';
  end if;

  select actor.id, actor.role
  into v_actor_member_id, v_actor_role
  from public.household_members as actor
  join public.households as household
    on household.id = actor.household_id
   and household.deleted_at is null
  where actor.household_id = p_household_id
    and actor.auth_user_id = v_authenticated_user_id
    and actor.removed_at is null
  for update of actor;

  if not found then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  select
    occurrence.assignee_member_id,
    occurrence.status,
    occurrence.version,
    occurrence.due_local_date,
    occurrence.due_at,
    occurrence.timezone,
    revision.recurrence_rule
  into
    v_assignee_member_id,
    v_current_status,
    v_current_version,
    v_current_due_local_date,
    v_current_due_at,
    v_timezone,
    v_recurrence_rule
  from public.chore_occurrences as occurrence
  join public.chore_series as series
    on series.household_id = occurrence.household_id
   and series.id = occurrence.series_id
   and series.deleted_at is null
  join public.chore_series_revisions as revision
    on revision.household_id = occurrence.household_id
   and revision.id = occurrence.revision_id
  where occurrence.household_id = p_household_id
    and occurrence.id = p_occurrence_id
  for update of occurrence;

  if not found
    or (
      v_actor_role = 'member'
      and v_assignee_member_id is distinct from v_actor_member_id
    ) then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  v_current_due_local_time := case
    when v_current_due_at is null then null
    else (v_current_due_at at time zone v_timezone)::time without time zone
  end;

  v_request_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'operation', 'reschedule_occurrence',
        'household_id', p_household_id,
        'occurrence_id', p_occurrence_id,
        'expected_version', p_expected_version,
        'due_local_date', p_due_local_date,
        'due_local_time', p_due_local_time
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_authenticated_user_id::text
        || ':chore-reschedule:'
        || p_idempotency_key::text,
      0
    )
  );

  select
    request.request_hash,
    request.result_due_local_date,
    request.result_due_local_time,
    request.result_due_at,
    request.result_version
  into
    v_existing_request_hash,
    v_result_due_local_date,
    v_result_due_local_time,
    v_result_due_at,
    v_result_version
  from app_private.chore_reschedule_command_requests as request
  where request.authenticated_user_id = v_authenticated_user_id
    and request.idempotency_key = p_idempotency_key;

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFC04',
        message = 'idempotency key reused with different chore input';
    end if;

    return query select
      p_household_id,
      p_occurrence_id,
      v_result_due_local_date,
      v_result_due_local_time,
      v_result_due_at,
      'scheduled'::text,
      v_result_version,
      false;
    return;
  end if;

  if v_current_version <> p_expected_version then
    raise exception using
      errcode = 'KFC05',
      message = 'chore occurrence version conflict';
  end if;

  if v_current_status <> 'scheduled'
    or v_recurrence_rule = '{"type":"once"}'::jsonb
    or (
      v_current_due_local_date is not distinct from p_due_local_date
      and v_current_due_local_time is not distinct from p_due_local_time
    ) then
    raise exception using
      errcode = 'KFC06',
      message = 'chore occurrence transition not allowed';
  end if;

  v_result_due_local_date := p_due_local_date;
  v_result_due_local_time := p_due_local_time;
  v_result_due_at := case
    when p_due_local_time is null then null
    else (p_due_local_date + p_due_local_time) at time zone v_timezone
  end;

  update public.chore_occurrences as occurrence
  set
    due_local_date = v_result_due_local_date,
    due_at = v_result_due_at
  where occurrence.household_id = p_household_id
    and occurrence.id = p_occurrence_id
  returning occurrence.version into v_result_version;

  insert into public.chore_reschedule_events (
    household_id,
    occurrence_id,
    actor_user_id,
    actor_member_id,
    previous_due_local_date,
    previous_due_local_time,
    previous_due_at,
    new_due_local_date,
    new_due_local_time,
    new_due_at,
    occurrence_version,
    correlation_id
  )
  values (
    p_household_id,
    p_occurrence_id,
    v_authenticated_user_id,
    v_actor_member_id,
    v_current_due_local_date,
    v_current_due_local_time,
    v_current_due_at,
    v_result_due_local_date,
    v_result_due_local_time,
    v_result_due_at,
    v_result_version,
    p_idempotency_key
  )
  returning id into v_result_event_id;

  insert into app_private.chore_reschedule_command_requests (
    authenticated_user_id,
    idempotency_key,
    request_hash,
    household_id,
    occurrence_id,
    result_due_local_date,
    result_due_local_time,
    result_due_at,
    result_version,
    result_event_id
  )
  values (
    v_authenticated_user_id,
    p_idempotency_key,
    v_request_hash,
    p_household_id,
    p_occurrence_id,
    v_result_due_local_date,
    v_result_due_local_time,
    v_result_due_at,
    v_result_version,
    v_result_event_id
  );

  return query select
    p_household_id,
    p_occurrence_id,
    v_result_due_local_date,
    v_result_due_local_time,
    v_result_due_at,
    'scheduled'::text,
    v_result_version,
    true;
end;
$$;

revoke all on function public.reschedule_chore_occurrence(
  uuid,
  uuid,
  uuid,
  bigint,
  date,
  time without time zone
) from public, anon, authenticated;

grant execute on function public.reschedule_chore_occurrence(
  uuid,
  uuid,
  uuid,
  bigint,
  date,
  time without time zone
) to authenticated;

-- Effective occurrence time must come from the materialized occurrence, not
-- its immutable recurrence revision, so one-off overrides render correctly.
create or replace function public.get_today_chores_v2(
  p_household_id uuid
)
returns table (
  household_id uuid,
  household_timezone text,
  household_local_date date,
  occurrence_id uuid,
  series_id uuid,
  title text,
  description text,
  assignee_member_id uuid,
  assignee_display_name text,
  due_local_time time without time zone,
  due_at timestamptz,
  status text,
  version bigint,
  recurrence_frequency text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_timezone text;
  v_local_date date;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFC01',
      message = 'authentication required';
  end if;

  if p_household_id is null then
    raise exception using
      errcode = 'KFC02',
      message = 'invalid chore input';
  end if;

  select household.timezone
  into v_timezone
  from public.households as household
  join public.household_members as caller
    on caller.household_id = household.id
   and caller.auth_user_id = v_authenticated_user_id
   and caller.removed_at is null
  where household.id = p_household_id
    and household.deleted_at is null;

  if not found then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  v_local_date := (statement_timestamp() at time zone v_timezone)::date;

  return query
  select
    household.id,
    household.timezone,
    v_local_date,
    item.occurrence_id,
    item.series_id,
    item.title,
    item.description,
    item.assignee_member_id,
    item.assignee_display_name,
    item.due_local_time,
    item.due_at,
    item.status,
    item.version,
    item.recurrence_frequency
  from public.households as household
  left join lateral (
    select
      occurrence.id as occurrence_id,
      series.id as series_id,
      series.title,
      series.description,
      occurrence.assignee_member_id,
      assignee.display_name as assignee_display_name,
      case
        when occurrence.due_at is null then null
        else (occurrence.due_at at time zone occurrence.timezone)::time
      end as due_local_time,
      occurrence.due_at,
      occurrence.status::text as status,
      occurrence.version,
      case
        when revision.recurrence_rule->>'frequency' in (
          'daily', 'weekly', 'monthly'
        ) then revision.recurrence_rule->>'frequency'
        else null
      end as recurrence_frequency
    from public.chore_occurrences as occurrence
    join public.chore_series as series
      on series.household_id = occurrence.household_id
     and series.id = occurrence.series_id
     and series.deleted_at is null
    join public.chore_series_revisions as revision
      on revision.household_id = occurrence.household_id
     and revision.id = occurrence.revision_id
    join public.household_members as assignee
      on assignee.household_id = occurrence.household_id
     and assignee.id = occurrence.assignee_member_id
    where occurrence.household_id = household.id
      and occurrence.due_local_date = v_local_date
      and occurrence.status in ('scheduled', 'completed')
    order by
      occurrence.due_at nulls last,
      lower(series.title),
      occurrence.id
  ) as item on true
  where household.id = p_household_id
  order by
    item.due_at nulls last,
    lower(item.title),
    item.occurrence_id;
end;
$$;

revoke all on function public.get_today_chores_v2(uuid)
  from public, anon, authenticated;
grant execute on function public.get_today_chores_v2(uuid)
  to authenticated;
