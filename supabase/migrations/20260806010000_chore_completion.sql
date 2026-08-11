-- KinFlow WP03-04 adult chore completion.
-- Store MVP scope: online-only adult complete/reopen with versioned audit.

create table public.chore_completion_events (
  id uuid primary key default extensions.gen_random_uuid(),
  household_id uuid not null,
  occurrence_id uuid not null,
  event_type text not null check (
    event_type in ('completed', 'reopened')
  ),
  actor_user_id uuid
    references auth.users(id) on delete set null,
  actor_member_id uuid not null,
  acting_member_id uuid,
  occurred_at timestamptz not null default now(),
  occurrence_version bigint not null check (occurrence_version > 0),
  correlation_id uuid not null,
  unique (household_id, id),
  unique (actor_user_id, correlation_id),
  constraint completion_occurrence_fk
    foreign key (household_id, occurrence_id)
    references public.chore_occurrences(household_id, id)
    on delete cascade,
  constraint completion_actor_fk
    foreign key (household_id, actor_member_id)
    references public.household_members(household_id, id),
  constraint completion_acting_fk
    foreign key (household_id, acting_member_id)
    references public.household_members(household_id, id)
);

create index chore_completion_events_occurrence_time_idx
  on public.chore_completion_events(
    household_id,
    occurrence_id,
    occurred_at desc
  );

create table app_private.chore_completion_command_requests (
  authenticated_user_id uuid not null
    references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  household_id uuid not null,
  occurrence_id uuid not null,
  result_status public.occurrence_status not null check (
    result_status in ('scheduled', 'completed')
  ),
  result_version bigint not null check (result_version > 0),
  result_completed_by_member_id uuid,
  result_completed_at timestamptz,
  result_event_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (authenticated_user_id, idempotency_key),
  constraint completion_request_result_ck check (
    (
      result_status = 'completed'
      and result_completed_by_member_id is not null
      and result_completed_at is not null
    )
    or (
      result_status = 'scheduled'
      and result_completed_by_member_id is null
      and result_completed_at is null
    )
  ),
  constraint completion_request_occurrence_fk
    foreign key (household_id, occurrence_id)
    references public.chore_occurrences(household_id, id)
    on delete cascade,
  constraint completion_request_member_fk
    foreign key (household_id, result_completed_by_member_id)
    references public.household_members(household_id, id),
  constraint completion_request_event_fk
    foreign key (household_id, result_event_id)
    references public.chore_completion_events(household_id, id)
    on delete cascade
);

revoke all on table app_private.chore_completion_command_requests
  from public, anon, authenticated;

create or replace function app_private.reject_chore_completion_event_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'chore completion events are immutable';
end;
$$;

revoke all on function app_private.reject_chore_completion_event_mutation()
  from public;

create trigger chore_completion_events_immutable
before update or delete on public.chore_completion_events
for each row
execute function app_private.reject_chore_completion_event_mutation();

alter table public.chore_completion_events enable row level security;
alter table public.chore_completion_events force row level security;

create policy chore_completion_events_select_member
on public.chore_completion_events
for select
to authenticated
using (app_private.is_active_household_member(household_id));

revoke all on table public.chore_completion_events
  from anon, authenticated;
grant select on table public.chore_completion_events
  to authenticated;

create or replace function public.set_chore_occurrence_completion(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_occurrence_id uuid,
  p_expected_version bigint,
  p_completed boolean
)
returns table (
  household_id uuid,
  occurrence_id uuid,
  status text,
  version bigint,
  completed_by_member_id uuid,
  completed_at timestamptz,
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
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_result_status public.occurrence_status;
  v_result_version bigint;
  v_result_completed_by_member_id uuid;
  v_result_completed_at timestamptz;
  v_result_event_id uuid;
  v_event_type text;
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
    or p_completed is null then
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
    occurrence.version
  into
    v_assignee_member_id,
    v_current_status,
    v_current_version
  from public.chore_occurrences as occurrence
  join public.chore_series as series
    on series.household_id = occurrence.household_id
   and series.id = occurrence.series_id
   and series.deleted_at is null
  where occurrence.household_id = p_household_id
    and occurrence.id = p_occurrence_id
  for update of occurrence;

  if not found
    or (
      v_actor_role = 'member'
      and v_assignee_member_id <> v_actor_member_id
    ) then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  v_request_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'operation', 'set_completion',
        'household_id', p_household_id,
        'occurrence_id', p_occurrence_id,
        'expected_version', p_expected_version,
        'completed', p_completed
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_authenticated_user_id::text
        || ':chore-completion:'
        || p_idempotency_key::text,
      0
    )
  );

  select
    request.request_hash,
    request.result_status,
    request.result_version,
    request.result_completed_by_member_id,
    request.result_completed_at
  into
    v_existing_request_hash,
    v_result_status,
    v_result_version,
    v_result_completed_by_member_id,
    v_result_completed_at
  from app_private.chore_completion_command_requests as request
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
      v_result_status::text,
      v_result_version,
      v_result_completed_by_member_id,
      v_result_completed_at,
      false;
    return;
  end if;

  if v_current_version <> p_expected_version then
    raise exception using
      errcode = 'KFC05',
      message = 'chore occurrence version conflict';
  end if;

  if (
    p_completed
    and v_current_status <> 'scheduled'
  ) or (
    not p_completed
    and v_current_status <> 'completed'
  ) then
    raise exception using
      errcode = 'KFC06',
      message = 'chore occurrence transition not allowed';
  end if;

  if p_completed then
    update public.chore_occurrences as occurrence
    set
      status = 'completed',
      completed_by_member_id = v_actor_member_id,
      completed_by_user_id = v_authenticated_user_id,
      completed_at = statement_timestamp()
    where occurrence.household_id = p_household_id
      and occurrence.id = p_occurrence_id
    returning
      occurrence.status,
      occurrence.version,
      occurrence.completed_by_member_id,
      occurrence.completed_at
    into
      v_result_status,
      v_result_version,
      v_result_completed_by_member_id,
      v_result_completed_at;
    v_event_type := 'completed';
  else
    update public.chore_occurrences as occurrence
    set
      status = 'scheduled',
      completed_by_member_id = null,
      completed_by_user_id = null,
      completed_at = null
    where occurrence.household_id = p_household_id
      and occurrence.id = p_occurrence_id
    returning
      occurrence.status,
      occurrence.version,
      occurrence.completed_by_member_id,
      occurrence.completed_at
    into
      v_result_status,
      v_result_version,
      v_result_completed_by_member_id,
      v_result_completed_at;
    v_event_type := 'reopened';
  end if;

  insert into public.chore_completion_events (
    household_id,
    occurrence_id,
    event_type,
    actor_user_id,
    actor_member_id,
    acting_member_id,
    occurrence_version,
    correlation_id
  )
  values (
    p_household_id,
    p_occurrence_id,
    v_event_type,
    v_authenticated_user_id,
    v_actor_member_id,
    null,
    v_result_version,
    p_idempotency_key
  )
  returning id into v_result_event_id;

  insert into app_private.chore_completion_command_requests (
    authenticated_user_id,
    idempotency_key,
    request_hash,
    household_id,
    occurrence_id,
    result_status,
    result_version,
    result_completed_by_member_id,
    result_completed_at,
    result_event_id
  )
  values (
    v_authenticated_user_id,
    p_idempotency_key,
    v_request_hash,
    p_household_id,
    p_occurrence_id,
    v_result_status,
    v_result_version,
    v_result_completed_by_member_id,
    v_result_completed_at,
    v_result_event_id
  );

  return query select
    p_household_id,
    p_occurrence_id,
    v_result_status::text,
    v_result_version,
    v_result_completed_by_member_id,
    v_result_completed_at,
    true;
end;
$$;

revoke all on function public.set_chore_occurrence_completion(
  uuid,
  uuid,
  uuid,
  bigint,
  boolean
) from public, anon, authenticated;

grant execute on function public.set_chore_occurrence_completion(
  uuid,
  uuid,
  uuid,
  bigint,
  boolean
) to authenticated;
