-- KinFlow WP03-05E single-occurrence reassignment.
-- Store MVP scope: online-only, versioned assignee override for one
-- scheduled repeating occurrence.

create table public.chore_assignment_events (
  id uuid primary key default extensions.gen_random_uuid(),
  household_id uuid not null,
  occurrence_id uuid not null,
  actor_user_id uuid
    references auth.users(id) on delete set null,
  actor_member_id uuid not null,
  previous_assignee_member_id uuid not null,
  new_assignee_member_id uuid not null,
  occurred_at timestamptz not null default now(),
  occurrence_version bigint not null check (occurrence_version > 0),
  correlation_id uuid not null,
  unique (household_id, id),
  unique (actor_user_id, correlation_id),
  constraint chore_assignment_event_occurrence_fk
    foreign key (household_id, occurrence_id)
    references public.chore_occurrences(household_id, id)
    on delete cascade,
  constraint chore_assignment_event_actor_fk
    foreign key (household_id, actor_member_id)
    references public.household_members(household_id, id),
  constraint chore_assignment_event_previous_assignee_fk
    foreign key (household_id, previous_assignee_member_id)
    references public.household_members(household_id, id),
  constraint chore_assignment_event_new_assignee_fk
    foreign key (household_id, new_assignee_member_id)
    references public.household_members(household_id, id),
  constraint chore_assignment_event_changed_ck check (
    previous_assignee_member_id <> new_assignee_member_id
  )
);

create index chore_assignment_events_occurrence_time_idx
  on public.chore_assignment_events(
    household_id,
    occurrence_id,
    occurred_at desc
  );

create or replace function app_private.reject_chore_assignment_event_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'chore assignment events are immutable';
end;
$$;

revoke all on function app_private.reject_chore_assignment_event_mutation()
  from public;

create trigger chore_assignment_events_immutable
before update or delete on public.chore_assignment_events
for each row
execute function app_private.reject_chore_assignment_event_mutation();

alter table public.chore_assignment_events enable row level security;
alter table public.chore_assignment_events force row level security;

create policy chore_assignment_events_select_member
on public.chore_assignment_events
for select
to authenticated
using (app_private.is_active_household_member(household_id));

revoke all on table public.chore_assignment_events
  from anon, authenticated;
grant select on table public.chore_assignment_events
  to authenticated;

create table app_private.chore_assignment_command_requests (
  authenticated_user_id uuid not null
    references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  household_id uuid not null,
  occurrence_id uuid not null,
  result_assignee_member_id uuid not null,
  result_version bigint not null check (result_version > 0),
  result_event_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (authenticated_user_id, idempotency_key),
  constraint chore_assignment_request_occurrence_fk
    foreign key (household_id, occurrence_id)
    references public.chore_occurrences(household_id, id)
    on delete cascade,
  constraint chore_assignment_request_assignee_fk
    foreign key (household_id, result_assignee_member_id)
    references public.household_members(household_id, id),
  constraint chore_assignment_request_event_fk
    foreign key (household_id, result_event_id)
    references public.chore_assignment_events(household_id, id)
    on delete cascade
);

revoke all on table app_private.chore_assignment_command_requests
  from public, anon, authenticated;

create or replace function public.reassign_chore_occurrence(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_occurrence_id uuid,
  p_expected_version bigint,
  p_assignee_member_id uuid
)
returns table (
  household_id uuid,
  occurrence_id uuid,
  assignee_member_id uuid,
  assignee_display_name text,
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
  v_current_assignee_member_id uuid;
  v_current_status public.occurrence_status;
  v_current_version bigint;
  v_recurrence_rule jsonb;
  v_target_display_name text;
  v_target_removed_at timestamptz;
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_result_assignee_member_id uuid;
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
    or p_assignee_member_id is null then
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
    revision.recurrence_rule
  into
    v_current_assignee_member_id,
    v_current_status,
    v_current_version,
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

  if not found then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  select target.display_name, target.removed_at
  into v_target_display_name, v_target_removed_at
  from public.household_members as target
  where target.household_id = p_household_id
    and target.id = p_assignee_member_id
  for update of target;

  if not found then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  v_request_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'operation', 'reassign_occurrence',
        'household_id', p_household_id,
        'occurrence_id', p_occurrence_id,
        'expected_version', p_expected_version,
        'assignee_member_id', p_assignee_member_id
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_authenticated_user_id::text
        || ':chore-reassign:'
        || p_idempotency_key::text,
      0
    )
  );

  select
    request.request_hash,
    request.result_assignee_member_id,
    request.result_version
  into
    v_existing_request_hash,
    v_result_assignee_member_id,
    v_result_version
  from app_private.chore_assignment_command_requests as request
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
      v_result_assignee_member_id,
      v_target_display_name,
      'scheduled'::text,
      v_result_version,
      false;
    return;
  end if;

  if v_target_removed_at is not null
    or (
      v_actor_role = 'member'
      and v_current_assignee_member_id is distinct from v_actor_member_id
    ) then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  if v_current_version <> p_expected_version then
    raise exception using
      errcode = 'KFC05',
      message = 'chore occurrence version conflict';
  end if;

  if v_current_status <> 'scheduled'
    or v_recurrence_rule = '{"type":"once"}'::jsonb
    or v_current_assignee_member_id = p_assignee_member_id then
    raise exception using
      errcode = 'KFC06',
      message = 'chore occurrence transition not allowed';
  end if;

  v_result_assignee_member_id := p_assignee_member_id;

  update public.chore_occurrences as occurrence
  set assignee_member_id = v_result_assignee_member_id
  where occurrence.household_id = p_household_id
    and occurrence.id = p_occurrence_id
  returning occurrence.version into v_result_version;

  insert into public.chore_assignment_events (
    household_id,
    occurrence_id,
    actor_user_id,
    actor_member_id,
    previous_assignee_member_id,
    new_assignee_member_id,
    occurrence_version,
    correlation_id
  )
  values (
    p_household_id,
    p_occurrence_id,
    v_authenticated_user_id,
    v_actor_member_id,
    v_current_assignee_member_id,
    v_result_assignee_member_id,
    v_result_version,
    p_idempotency_key
  )
  returning id into v_result_event_id;

  insert into app_private.chore_assignment_command_requests (
    authenticated_user_id,
    idempotency_key,
    request_hash,
    household_id,
    occurrence_id,
    result_assignee_member_id,
    result_version,
    result_event_id
  )
  values (
    v_authenticated_user_id,
    p_idempotency_key,
    v_request_hash,
    p_household_id,
    p_occurrence_id,
    v_result_assignee_member_id,
    v_result_version,
    v_result_event_id
  );

  return query select
    p_household_id,
    p_occurrence_id,
    v_result_assignee_member_id,
    v_target_display_name,
    'scheduled'::text,
    v_result_version,
    true;
end;
$$;

revoke all on function public.reassign_chore_occurrence(
  uuid,
  uuid,
  uuid,
  bigint,
  uuid
) from public, anon, authenticated;

grant execute on function public.reassign_chore_occurrence(
  uuid,
  uuid,
  uuid,
  bigint,
  uuid
) to authenticated;
