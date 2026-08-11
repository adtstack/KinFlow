-- KinFlow WP03-09 scheduled one-time chore update and soft-delete lifecycle.
-- Existing chore revisions and occurrences remain immutable history; commands
-- expose only mediated, expected-version mutations.

create table public.one_time_chore_change_events (
  id uuid primary key default extensions.gen_random_uuid(),
  household_id uuid not null,
  series_id uuid not null,
  occurrence_id uuid not null,
  operation text not null check (operation in ('updated', 'deleted')),
  previous_revision_id uuid not null,
  new_revision_id uuid,
  previous_due_local_date date not null,
  previous_due_local_time time without time zone,
  previous_due_at timestamptz,
  previous_assignee_member_id uuid not null,
  new_due_local_date date,
  new_due_local_time time without time zone,
  new_due_at timestamptz,
  new_assignee_member_id uuid,
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_member_id uuid not null,
  series_version bigint not null check (series_version > 0),
  occurrence_version bigint not null check (occurrence_version > 0),
  correlation_id uuid not null,
  occurred_at timestamptz not null default statement_timestamp(),
  unique (household_id, id),
  unique (actor_user_id, correlation_id),
  constraint one_time_chore_change_event_shape_ck check (
    (
      operation = 'updated'
      and new_revision_id is not null
      and new_due_local_date is not null
      and new_assignee_member_id is not null
    )
    or (
      operation = 'deleted'
      and new_revision_id is null
      and new_due_local_date is null
      and new_due_local_time is null
      and new_due_at is null
      and new_assignee_member_id is null
    )
  ),
  constraint one_time_chore_change_previous_time_ck check (
    (previous_due_local_time is null) = (previous_due_at is null)
  ),
  constraint one_time_chore_change_new_time_ck check (
    operation = 'deleted'
    or (new_due_local_time is null) = (new_due_at is null)
  ),
  constraint one_time_chore_change_series_fk
    foreign key (household_id, series_id)
    references public.chore_series(household_id, id)
    on delete cascade,
  constraint one_time_chore_change_occurrence_fk
    foreign key (household_id, occurrence_id)
    references public.chore_occurrences(household_id, id)
    on delete cascade,
  constraint one_time_chore_change_previous_revision_fk
    foreign key (household_id, previous_revision_id)
    references public.chore_series_revisions(household_id, id),
  constraint one_time_chore_change_new_revision_fk
    foreign key (household_id, new_revision_id)
    references public.chore_series_revisions(household_id, id),
  constraint one_time_chore_change_previous_assignee_fk
    foreign key (household_id, previous_assignee_member_id)
    references public.household_members(household_id, id),
  constraint one_time_chore_change_new_assignee_fk
    foreign key (household_id, new_assignee_member_id)
    references public.household_members(household_id, id),
  constraint one_time_chore_change_actor_fk
    foreign key (household_id, actor_member_id)
    references public.household_members(household_id, id)
);

create index one_time_chore_change_events_occurrence_time_idx
  on public.one_time_chore_change_events(
    household_id,
    occurrence_id,
    occurred_at desc,
    id desc
  );

create or replace function app_private.reject_one_time_chore_change_event_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'one-time chore change events are immutable';
end;
$$;

revoke all on function app_private.reject_one_time_chore_change_event_mutation()
  from public, anon, authenticated, service_role;

create trigger one_time_chore_change_events_immutable
before update or delete on public.one_time_chore_change_events
for each row
execute function app_private.reject_one_time_chore_change_event_mutation();

alter table public.one_time_chore_change_events enable row level security;
alter table public.one_time_chore_change_events force row level security;

create policy one_time_chore_change_events_select_member
on public.one_time_chore_change_events
for select
to authenticated
using (app_private.is_active_household_member(household_id));

revoke all on table public.one_time_chore_change_events
  from public, anon, authenticated, service_role;
grant select on table public.one_time_chore_change_events to authenticated;

create table app_private.one_time_chore_change_command_requests (
  authenticated_user_id uuid not null
    references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  operation text not null check (operation in ('updated', 'deleted')),
  household_id uuid not null,
  series_id uuid not null,
  occurrence_id uuid not null,
  result_event_id uuid not null,
  created_at timestamptz not null default statement_timestamp(),
  primary key (authenticated_user_id, idempotency_key),
  constraint one_time_chore_change_request_series_fk
    foreign key (household_id, series_id)
    references public.chore_series(household_id, id)
    on delete cascade,
  constraint one_time_chore_change_request_occurrence_fk
    foreign key (household_id, occurrence_id)
    references public.chore_occurrences(household_id, id)
    on delete cascade,
  constraint one_time_chore_change_request_event_fk
    foreign key (household_id, result_event_id)
    references public.one_time_chore_change_events(household_id, id)
    on delete cascade
);

revoke all on table app_private.one_time_chore_change_command_requests
  from public, anon, authenticated, service_role;

create or replace function public.update_one_time_chore(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_occurrence_id uuid,
  p_expected_series_version bigint,
  p_expected_occurrence_version bigint,
  p_title text,
  p_description text,
  p_assignee_member_id uuid,
  p_due_local_date date,
  p_due_local_time time without time zone
)
returns table (
  household_id uuid,
  series_id uuid,
  occurrence_id uuid,
  revision_id uuid,
  revision_number integer,
  due_local_date date,
  due_local_time time without time zone,
  due_at timestamptz,
  assignee_member_id uuid,
  series_version bigint,
  occurrence_version bigint,
  changed boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_actor_member_id uuid;
  v_title text := btrim(p_title);
  v_description text := nullif(btrim(p_description), '');
  v_timezone text;
  v_previous_title text;
  v_previous_description text;
  v_previous_revision_id uuid;
  v_previous_revision_number integer;
  v_previous_recurrence_rule jsonb;
  v_previous_due_local_date date;
  v_previous_due_local_time time without time zone;
  v_previous_due_at timestamptz;
  v_previous_assignee_member_id uuid;
  v_current_series_version bigint;
  v_current_occurrence_version bigint;
  v_current_status public.occurrence_status;
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_result_event_id uuid;
  v_revision_id uuid;
  v_revision_number integer;
  v_due_at timestamptz;
  v_result_series_version bigint;
  v_result_occurrence_version bigint;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFC01',
      message = 'authentication required';
  end if;

  if p_idempotency_key is null
    or p_household_id is null
    or p_series_id is null
    or p_occurrence_id is null
    or p_expected_series_version is null
    or p_expected_series_version < 1
    or p_expected_occurrence_version is null
    or p_expected_occurrence_version < 1
    or p_assignee_member_id is null
    or p_due_local_date is null
    or (
      p_due_local_time is not null
      and extract(second from p_due_local_time) <> 0
    )
    or v_title is null
    or char_length(v_title) not between 1 and 160
    or v_title ~ '[[:cntrl:]]'
    or (v_description is not null and char_length(v_description) > 4000) then
    raise exception using
      errcode = 'KFC02',
      message = 'invalid chore input';
  end if;

  select actor.id
  into v_actor_member_id
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

  v_request_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'operation', 'update_one_time_chore',
        'household_id', p_household_id,
        'series_id', p_series_id,
        'occurrence_id', p_occurrence_id,
        'expected_series_version', p_expected_series_version,
        'expected_occurrence_version', p_expected_occurrence_version,
        'title', v_title,
        'description', v_description,
        'assignee_member_id', p_assignee_member_id,
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
        || ':one-time-chore-change:'
        || p_idempotency_key::text,
      0
    )
  );

  select request.request_hash, request.result_event_id
  into v_existing_request_hash, v_result_event_id
  from app_private.one_time_chore_change_command_requests as request
  where request.authenticated_user_id = v_authenticated_user_id
    and request.idempotency_key = p_idempotency_key
    and request.operation = 'updated';

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFC04',
        message = 'idempotency key reused with different chore input';
    end if;

    return query
    select
      event.household_id,
      event.series_id,
      event.occurrence_id,
      event.new_revision_id,
      revision.revision_number,
      event.new_due_local_date,
      event.new_due_local_time,
      event.new_due_at,
      event.new_assignee_member_id,
      event.series_version,
      event.occurrence_version,
      false
    from public.one_time_chore_change_events as event
    join public.chore_series_revisions as revision
      on revision.household_id = event.household_id
     and revision.id = event.new_revision_id
    where event.household_id = p_household_id
      and event.id = v_result_event_id;
    return;
  end if;

  if exists (
    select 1
    from app_private.one_time_chore_change_command_requests as request
    where request.authenticated_user_id = v_authenticated_user_id
      and request.idempotency_key = p_idempotency_key
  ) then
    raise exception using
      errcode = 'KFC04',
      message = 'idempotency key reused with different chore input';
  end if;

  select
    series.timezone,
    series.version,
    revision.id,
    revision.revision_number,
    revision.title,
    revision.description,
    revision.due_local_time,
    revision.recurrence_rule,
    occurrence.due_local_date,
    occurrence.due_at,
    occurrence.assignee_member_id,
    occurrence.version,
    occurrence.status
  into
    v_timezone,
    v_current_series_version,
    v_previous_revision_id,
    v_previous_revision_number,
    v_previous_title,
    v_previous_description,
    v_previous_due_local_time,
    v_previous_recurrence_rule,
    v_previous_due_local_date,
    v_previous_due_at,
    v_previous_assignee_member_id,
    v_current_occurrence_version,
    v_current_status
  from public.chore_series as series
  join public.chore_series_revisions as revision
    on revision.household_id = series.household_id
   and revision.series_id = series.id
   and revision.id = series.active_revision_id
  join public.chore_occurrences as occurrence
    on occurrence.household_id = series.household_id
   and occurrence.series_id = series.id
   and occurrence.revision_id = revision.id
  where series.household_id = p_household_id
    and series.id = p_series_id
    and series.deleted_at is null
    and occurrence.id = p_occurrence_id
  for update of series, occurrence;

  if not found
    or v_previous_recurrence_rule <> '{"type":"once"}'::jsonb then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  if v_current_status <> 'scheduled' then
    raise exception using
      errcode = 'KFC06',
      message = 'chore transition not allowed';
  end if;

  if v_current_series_version <> p_expected_series_version
    or v_current_occurrence_version <> p_expected_occurrence_version then
    raise exception using
      errcode = 'KFC05',
      message = 'chore version conflict';
  end if;

  perform 1
  from public.household_members as assignee
  where assignee.household_id = p_household_id
    and assignee.id = p_assignee_member_id
    and assignee.removed_at is null
  for update of assignee;

  if not found then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  if v_previous_title = v_title
    and v_previous_description is not distinct from v_description
    and v_previous_assignee_member_id = p_assignee_member_id
    and v_previous_due_local_date = p_due_local_date
    and v_previous_due_local_time is not distinct from p_due_local_time then
    raise exception using
      errcode = 'KFC06',
      message = 'chore transition not allowed';
  end if;

  v_revision_id := extensions.gen_random_uuid();
  v_revision_number := v_previous_revision_number + 1;
  v_due_at := case
    when p_due_local_time is null then null
    else (p_due_local_date + p_due_local_time) at time zone v_timezone
  end;

  insert into public.chore_series_revisions (
    id,
    household_id,
    series_id,
    revision_number,
    effective_local_date,
    due_local_time,
    recurrence_rule,
    default_assignee_member_id,
    created_by_user_id,
    title,
    description
  )
  values (
    v_revision_id,
    p_household_id,
    p_series_id,
    v_revision_number,
    p_due_local_date,
    p_due_local_time,
    '{"type":"once"}'::jsonb,
    p_assignee_member_id,
    v_authenticated_user_id,
    v_title,
    v_description
  );

  update public.chore_series as series
  set
    title = v_title,
    description = v_description,
    active_revision_id = v_revision_id
  where series.household_id = p_household_id
    and series.id = p_series_id
  returning series.version into v_result_series_version;

  update public.chore_occurrences as occurrence
  set
    revision_id = v_revision_id,
    due_local_date = p_due_local_date,
    due_at = v_due_at,
    timezone = v_timezone,
    assignee_member_id = p_assignee_member_id
  where occurrence.household_id = p_household_id
    and occurrence.id = p_occurrence_id
  returning occurrence.version into v_result_occurrence_version;

  insert into public.one_time_chore_change_events (
    household_id,
    series_id,
    occurrence_id,
    operation,
    previous_revision_id,
    new_revision_id,
    previous_due_local_date,
    previous_due_local_time,
    previous_due_at,
    previous_assignee_member_id,
    new_due_local_date,
    new_due_local_time,
    new_due_at,
    new_assignee_member_id,
    actor_user_id,
    actor_member_id,
    series_version,
    occurrence_version,
    correlation_id
  )
  values (
    p_household_id,
    p_series_id,
    p_occurrence_id,
    'updated',
    v_previous_revision_id,
    v_revision_id,
    v_previous_due_local_date,
    v_previous_due_local_time,
    v_previous_due_at,
    v_previous_assignee_member_id,
    p_due_local_date,
    p_due_local_time,
    v_due_at,
    p_assignee_member_id,
    v_authenticated_user_id,
    v_actor_member_id,
    v_result_series_version,
    v_result_occurrence_version,
    p_idempotency_key
  )
  returning id into v_result_event_id;

  insert into app_private.one_time_chore_change_command_requests (
    authenticated_user_id,
    idempotency_key,
    request_hash,
    operation,
    household_id,
    series_id,
    occurrence_id,
    result_event_id
  )
  values (
    v_authenticated_user_id,
    p_idempotency_key,
    v_request_hash,
    'updated',
    p_household_id,
    p_series_id,
    p_occurrence_id,
    v_result_event_id
  );

  return query select
    p_household_id,
    p_series_id,
    p_occurrence_id,
    v_revision_id,
    v_revision_number,
    p_due_local_date,
    p_due_local_time,
    v_due_at,
    p_assignee_member_id,
    v_result_series_version,
    v_result_occurrence_version,
    true;
end;
$$;

revoke all on function public.update_one_time_chore(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint,
  bigint,
  text,
  text,
  uuid,
  date,
  time without time zone
) from public, anon, authenticated, service_role;

grant execute on function public.update_one_time_chore(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint,
  bigint,
  text,
  text,
  uuid,
  date,
  time without time zone
) to authenticated;

create or replace function public.delete_one_time_chore(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_occurrence_id uuid,
  p_expected_series_version bigint,
  p_expected_occurrence_version bigint
)
returns table (
  household_id uuid,
  series_id uuid,
  occurrence_id uuid,
  status text,
  series_version bigint,
  occurrence_version bigint,
  changed boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_actor_member_id uuid;
  v_previous_revision_id uuid;
  v_previous_recurrence_rule jsonb;
  v_previous_due_local_date date;
  v_previous_due_local_time time without time zone;
  v_previous_due_at timestamptz;
  v_previous_assignee_member_id uuid;
  v_current_series_version bigint;
  v_current_occurrence_version bigint;
  v_current_status public.occurrence_status;
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_result_event_id uuid;
  v_result_series_version bigint;
  v_result_occurrence_version bigint;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFC01',
      message = 'authentication required';
  end if;

  if p_idempotency_key is null
    or p_household_id is null
    or p_series_id is null
    or p_occurrence_id is null
    or p_expected_series_version is null
    or p_expected_series_version < 1
    or p_expected_occurrence_version is null
    or p_expected_occurrence_version < 1 then
    raise exception using
      errcode = 'KFC02',
      message = 'invalid chore input';
  end if;

  select actor.id
  into v_actor_member_id
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

  v_request_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'operation', 'delete_one_time_chore',
        'household_id', p_household_id,
        'series_id', p_series_id,
        'occurrence_id', p_occurrence_id,
        'expected_series_version', p_expected_series_version,
        'expected_occurrence_version', p_expected_occurrence_version
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_authenticated_user_id::text
        || ':one-time-chore-change:'
        || p_idempotency_key::text,
      0
    )
  );

  select request.request_hash, request.result_event_id
  into v_existing_request_hash, v_result_event_id
  from app_private.one_time_chore_change_command_requests as request
  where request.authenticated_user_id = v_authenticated_user_id
    and request.idempotency_key = p_idempotency_key
    and request.operation = 'deleted';

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFC04',
        message = 'idempotency key reused with different chore input';
    end if;

    return query
    select
      event.household_id,
      event.series_id,
      event.occurrence_id,
      'cancelled'::text,
      event.series_version,
      event.occurrence_version,
      false
    from public.one_time_chore_change_events as event
    where event.household_id = p_household_id
      and event.id = v_result_event_id;
    return;
  end if;

  if exists (
    select 1
    from app_private.one_time_chore_change_command_requests as request
    where request.authenticated_user_id = v_authenticated_user_id
      and request.idempotency_key = p_idempotency_key
  ) then
    raise exception using
      errcode = 'KFC04',
      message = 'idempotency key reused with different chore input';
  end if;

  select
    series.version,
    revision.id,
    revision.due_local_time,
    revision.recurrence_rule,
    occurrence.due_local_date,
    occurrence.due_at,
    occurrence.assignee_member_id,
    occurrence.version,
    occurrence.status
  into
    v_current_series_version,
    v_previous_revision_id,
    v_previous_due_local_time,
    v_previous_recurrence_rule,
    v_previous_due_local_date,
    v_previous_due_at,
    v_previous_assignee_member_id,
    v_current_occurrence_version,
    v_current_status
  from public.chore_series as series
  join public.chore_series_revisions as revision
    on revision.household_id = series.household_id
   and revision.series_id = series.id
   and revision.id = series.active_revision_id
  join public.chore_occurrences as occurrence
    on occurrence.household_id = series.household_id
   and occurrence.series_id = series.id
   and occurrence.revision_id = revision.id
  where series.household_id = p_household_id
    and series.id = p_series_id
    and series.deleted_at is null
    and occurrence.id = p_occurrence_id
  for update of series, occurrence;

  if not found
    or v_previous_recurrence_rule <> '{"type":"once"}'::jsonb then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  if v_current_status <> 'scheduled' then
    raise exception using
      errcode = 'KFC06',
      message = 'chore transition not allowed';
  end if;

  if v_current_series_version <> p_expected_series_version
    or v_current_occurrence_version <> p_expected_occurrence_version then
    raise exception using
      errcode = 'KFC05',
      message = 'chore version conflict';
  end if;

  update public.chore_occurrences as occurrence
  set status = 'cancelled'
  where occurrence.household_id = p_household_id
    and occurrence.id = p_occurrence_id
  returning occurrence.version into v_result_occurrence_version;

  update public.chore_series as series
  set deleted_at = statement_timestamp()
  where series.household_id = p_household_id
    and series.id = p_series_id
  returning series.version into v_result_series_version;

  insert into public.one_time_chore_change_events (
    household_id,
    series_id,
    occurrence_id,
    operation,
    previous_revision_id,
    new_revision_id,
    previous_due_local_date,
    previous_due_local_time,
    previous_due_at,
    previous_assignee_member_id,
    new_due_local_date,
    new_due_local_time,
    new_due_at,
    new_assignee_member_id,
    actor_user_id,
    actor_member_id,
    series_version,
    occurrence_version,
    correlation_id
  )
  values (
    p_household_id,
    p_series_id,
    p_occurrence_id,
    'deleted',
    v_previous_revision_id,
    null,
    v_previous_due_local_date,
    v_previous_due_local_time,
    v_previous_due_at,
    v_previous_assignee_member_id,
    null,
    null,
    null,
    null,
    v_authenticated_user_id,
    v_actor_member_id,
    v_result_series_version,
    v_result_occurrence_version,
    p_idempotency_key
  )
  returning id into v_result_event_id;

  insert into app_private.one_time_chore_change_command_requests (
    authenticated_user_id,
    idempotency_key,
    request_hash,
    operation,
    household_id,
    series_id,
    occurrence_id,
    result_event_id
  )
  values (
    v_authenticated_user_id,
    p_idempotency_key,
    v_request_hash,
    'deleted',
    p_household_id,
    p_series_id,
    p_occurrence_id,
    v_result_event_id
  );

  return query select
    p_household_id,
    p_series_id,
    p_occurrence_id,
    'cancelled'::text,
    v_result_series_version,
    v_result_occurrence_version,
    true;
end;
$$;

revoke all on function public.delete_one_time_chore(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint,
  bigint
) from public, anon, authenticated, service_role;

grant execute on function public.delete_one_time_chore(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint,
  bigint
) to authenticated;

comment on table public.one_time_chore_change_events is
  'WP03-09 immutable metadata-only audit for scheduled one-time chore updates and soft deletion.';
comment on function public.update_one_time_chore(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint,
  bigint,
  text,
  text,
  uuid,
  date,
  time without time zone
) is 'WP03-09 active-member one-time chore edit with immutable revision and dual expected versions.';
comment on function public.delete_one_time_chore(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint,
  bigint
) is 'WP03-09 active-member one-time chore soft deletion with dual expected versions.';
