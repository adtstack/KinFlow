-- KinFlow WP03-05C skipped-occurrence restore.
-- Store MVP scope: online-only, immediate versioned Undo for one skipped
-- repeating occurrence.

create table app_private.chore_restore_command_requests (
  authenticated_user_id uuid not null
    references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  household_id uuid not null,
  occurrence_id uuid not null,
  result_version bigint not null check (result_version > 0),
  result_event_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (authenticated_user_id, idempotency_key),
  constraint restore_request_occurrence_fk
    foreign key (household_id, occurrence_id)
    references public.chore_occurrences(household_id, id)
    on delete cascade,
  constraint restore_request_event_fk
    foreign key (household_id, result_event_id)
    references public.chore_completion_events(household_id, id)
    on delete cascade
);

revoke all on table app_private.chore_restore_command_requests
  from public, anon, authenticated;

create or replace function public.restore_skipped_chore_occurrence(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_occurrence_id uuid,
  p_expected_version bigint
)
returns table (
  household_id uuid,
  occurrence_id uuid,
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
  v_recurrence_rule jsonb;
  v_request_hash bytea;
  v_existing_request_hash bytea;
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
    or p_expected_version < 1 then
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
    v_assignee_member_id,
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

  if not found
    or (
      v_actor_role = 'member'
      and v_assignee_member_id is distinct from v_actor_member_id
    ) then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  v_request_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'operation', 'restore_skipped_occurrence',
        'household_id', p_household_id,
        'occurrence_id', p_occurrence_id,
        'expected_version', p_expected_version
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_authenticated_user_id::text
        || ':chore-restore:'
        || p_idempotency_key::text,
      0
    )
  );

  select request.request_hash, request.result_version
  into v_existing_request_hash, v_result_version
  from app_private.chore_restore_command_requests as request
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

  if v_current_status <> 'skipped'
    or v_recurrence_rule = '{"type":"once"}'::jsonb then
    raise exception using
      errcode = 'KFC06',
      message = 'chore occurrence transition not allowed';
  end if;

  update public.chore_occurrences as occurrence
  set
    status = 'scheduled',
    completed_by_member_id = null,
    completed_by_user_id = null,
    completed_at = null
  where occurrence.household_id = p_household_id
    and occurrence.id = p_occurrence_id
  returning occurrence.version into v_result_version;

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
    'reopened',
    v_authenticated_user_id,
    v_actor_member_id,
    null,
    v_result_version,
    p_idempotency_key
  )
  returning id into v_result_event_id;

  insert into app_private.chore_restore_command_requests (
    authenticated_user_id,
    idempotency_key,
    request_hash,
    household_id,
    occurrence_id,
    result_version,
    result_event_id
  )
  values (
    v_authenticated_user_id,
    p_idempotency_key,
    v_request_hash,
    p_household_id,
    p_occurrence_id,
    v_result_version,
    v_result_event_id
  );

  return query select
    p_household_id,
    p_occurrence_id,
    'scheduled'::text,
    v_result_version,
    true;
end;
$$;

revoke all on function public.restore_skipped_chore_occurrence(
  uuid,
  uuid,
  uuid,
  bigint
) from public, anon, authenticated;

grant execute on function public.restore_skipped_chore_occurrence(
  uuid,
  uuid,
  uuid,
  bigint
) to authenticated;
