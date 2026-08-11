-- KinFlow WP03-20 selected-occurrence repeating chore series edit.
-- The client supplies only an occurrence identity. The database derives the
-- effective boundary from its immutable recurrence slot while preserving the
-- legacy household-local-today command signature and request hash.

create or replace function app_private.update_repeating_chore_series_at_boundary(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_effective_occurrence_id uuid,
  p_expected_version bigint,
  p_title text,
  p_description text,
  p_assignee_member_id uuid,
  p_due_local_time time without time zone,
  p_recurrence_rule jsonb
)
returns table (
  household_id uuid,
  series_id uuid,
  revision_id uuid,
  revision_number integer,
  effective_local_date date,
  version bigint,
  rebuilt_count integer,
  cancelled_count integer,
  preserved_completed_count integer,
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
  v_title text := btrim(p_title);
  v_description text := nullif(btrim(p_description), '');
  v_timezone text;
  v_current_title text;
  v_current_description text;
  v_current_version bigint;
  v_previous_revision_id uuid;
  v_previous_assignee_member_id uuid;
  v_previous_due_local_time time without time zone;
  v_previous_recurrence_rule jsonb;
  v_revision_id uuid;
  v_revision_number integer;
  v_effective_local_date date;
  v_household_local_today date;
  v_horizon_end date;
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_result_revision_id uuid;
  v_result_revision_number integer;
  v_result_effective_local_date date;
  v_result_version bigint;
  v_result_rebuilt_count integer;
  v_result_cancelled_count integer;
  v_result_preserved_completed_count integer;
  v_result_event_id uuid;
  v_reused_count integer;
  v_inserted_count integer;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFC01',
      message = 'authentication required';
  end if;

  if p_idempotency_key is null
    or p_household_id is null
    or p_series_id is null
    or p_expected_version is null
    or p_expected_version < 1
    or p_assignee_member_id is null
    or v_title is null
    or char_length(v_title) not between 1 and 160
    or v_title ~ '[[:cntrl:]]'
    or (v_description is not null and char_length(v_description) > 4000)
    or (
      p_due_local_time is not null
      and extract(second from p_due_local_time) <> 0
    )
    or not app_private.is_valid_chore_recurrence_rule(p_recurrence_rule)
    or p_recurrence_rule = '{"type":"once"}'::jsonb then
    raise exception using
      errcode = 'KFC07',
      message = 'invalid chore recurrence rule';
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

  if not found or v_actor_role not in ('owner', 'admin') then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  v_request_hash := extensions.digest(
    convert_to(
      (
        case
          when p_effective_occurrence_id is null then
            jsonb_build_object(
              'operation', 'update_repeating_chore_series',
              'household_id', p_household_id,
              'series_id', p_series_id,
              'expected_version', p_expected_version,
              'title', v_title,
              'description', v_description,
              'assignee_member_id', p_assignee_member_id,
              'due_local_time', p_due_local_time,
              'recurrence_rule', p_recurrence_rule
            )
          else
            jsonb_build_object(
              'operation', 'update_repeating_chore_series_from_occurrence',
              'household_id', p_household_id,
              'series_id', p_series_id,
              'effective_occurrence_id', p_effective_occurrence_id,
              'expected_version', p_expected_version,
              'title', v_title,
              'description', v_description,
              'assignee_member_id', p_assignee_member_id,
              'due_local_time', p_due_local_time,
              'recurrence_rule', p_recurrence_rule
            )
        end
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_authenticated_user_id::text
        || ':chore-series-change:'
        || p_idempotency_key::text,
      0
    )
  );

  select
    request.request_hash,
    request.result_revision_id,
    revision.revision_number,
    request.result_effective_local_date,
    request.result_version,
    request.result_rebuilt_count,
    request.result_cancelled_count,
    request.result_preserved_completed_count
  into
    v_existing_request_hash,
    v_result_revision_id,
    v_result_revision_number,
    v_result_effective_local_date,
    v_result_version,
    v_result_rebuilt_count,
    v_result_cancelled_count,
    v_result_preserved_completed_count
  from app_private.chore_series_change_command_requests as request
  join public.chore_series_revisions as revision
    on revision.household_id = request.household_id
   and revision.id = request.result_revision_id
  where request.authenticated_user_id = v_authenticated_user_id
    and request.idempotency_key = p_idempotency_key
    and request.operation = 'updated';

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFC04',
        message = 'idempotency key reused with different chore input';
    end if;

    return query select
      p_household_id,
      p_series_id,
      v_result_revision_id,
      v_result_revision_number,
      v_result_effective_local_date,
      v_result_version,
      v_result_rebuilt_count,
      v_result_cancelled_count,
      v_result_preserved_completed_count,
      false;
    return;
  end if;

  if exists (
    select 1
    from app_private.chore_series_change_command_requests as request
    where request.authenticated_user_id = v_authenticated_user_id
      and request.idempotency_key = p_idempotency_key
  ) then
    raise exception using
      errcode = 'KFC04',
      message = 'idempotency key reused with different chore input';
  end if;

  select
    series.timezone,
    series.title,
    series.description,
    series.version,
    revision.id,
    revision.default_assignee_member_id,
    revision.due_local_time,
    revision.recurrence_rule
  into
    v_timezone,
    v_current_title,
    v_current_description,
    v_current_version,
    v_previous_revision_id,
    v_previous_assignee_member_id,
    v_previous_due_local_time,
    v_previous_recurrence_rule
  from public.chore_series as series
  join public.chore_series_revisions as revision
    on revision.household_id = series.household_id
   and revision.series_id = series.id
   and revision.id = series.active_revision_id
  where series.household_id = p_household_id
    and series.id = p_series_id
    and series.deleted_at is null
  for update of series;

  if not found
    or v_previous_recurrence_rule = '{"type":"once"}'::jsonb then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  if v_current_version <> p_expected_version then
    raise exception using
      errcode = 'KFC05',
      message = 'chore series version conflict';
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

  v_household_local_today :=
    (statement_timestamp() at time zone v_timezone)::date;

  if p_effective_occurrence_id is null then
    v_effective_local_date := v_household_local_today;
  else
    select occurrence.recurrence_local_date
    into v_effective_local_date
    from public.chore_occurrences as occurrence
    where occurrence.household_id = p_household_id
      and occurrence.series_id = p_series_id
      and occurrence.id = p_effective_occurrence_id
      and occurrence.revision_id = v_previous_revision_id
      and occurrence.status = 'scheduled'
      and occurrence.recurrence_local_date >= v_household_local_today
    for update of occurrence;

    if not found then
      raise exception using
        errcode = 'KFC03',
        message = 'chore not found or forbidden';
    end if;
  end if;

  if p_recurrence_rule->'end'->>'type' = 'until'
    and (p_recurrence_rule->'end'->>'localDate')::date
      < v_effective_local_date then
    raise exception using
      errcode = 'KFC07',
      message = 'invalid chore recurrence rule';
  end if;

  if v_current_title is not distinct from v_title
    and v_current_description is not distinct from v_description
    and v_previous_assignee_member_id = p_assignee_member_id
    and v_previous_due_local_time is not distinct from p_due_local_time
    and v_previous_recurrence_rule = p_recurrence_rule then
    raise exception using
      errcode = 'KFC06',
      message = 'chore series transition not allowed';
  end if;

  v_revision_id := extensions.gen_random_uuid();
  select coalesce(max(revision.revision_number), 0) + 1
  into v_revision_number
  from public.chore_series_revisions as revision
  where revision.series_id = p_series_id;

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
    v_effective_local_date,
    p_due_local_time,
    p_recurrence_rule,
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
  returning series.version into v_result_version;

  v_horizon_end := v_effective_local_date + 365;
  if p_recurrence_rule->'end'->>'type' = 'until' then
    v_horizon_end := least(
      v_horizon_end,
      (p_recurrence_rule->'end'->>'localDate')::date
    );
  end if;

  with candidates as materialized (
    select candidate.recurrence_local_date, candidate.due_at
    from app_private.chore_revision_candidate_dates(
      p_household_id,
      p_series_id,
      v_revision_id,
      v_effective_local_date,
      v_horizon_end
    ) as candidate
  )
  update public.chore_occurrences as occurrence
  set
    revision_id = v_revision_id,
    due_local_date = occurrence.recurrence_local_date,
    due_at = candidate.due_at,
    timezone = v_timezone,
    status = 'scheduled',
    assignee_member_id = p_assignee_member_id,
    completed_by_member_id = null,
    completed_by_user_id = null,
    completed_at = null
  from candidates as candidate
  where occurrence.household_id = p_household_id
    and occurrence.series_id = p_series_id
    and occurrence.revision_id = v_previous_revision_id
    and occurrence.recurrence_local_date >= v_effective_local_date
    and occurrence.status <> 'completed'
    and occurrence.recurrence_local_date = candidate.recurrence_local_date;

  get diagnostics v_reused_count = row_count;

  update public.chore_occurrences as occurrence
  set status = 'cancelled'
  where occurrence.household_id = p_household_id
    and occurrence.series_id = p_series_id
    and occurrence.revision_id = v_previous_revision_id
    and occurrence.recurrence_local_date >= v_effective_local_date
    and occurrence.status not in ('completed', 'cancelled')
    and not exists (
      select 1
      from app_private.chore_revision_candidate_dates(
        p_household_id,
        p_series_id,
        v_revision_id,
        v_effective_local_date,
        v_horizon_end
      ) as candidate
      where candidate.recurrence_local_date =
        occurrence.recurrence_local_date
    );

  get diagnostics v_result_cancelled_count = row_count;

  v_inserted_count := app_private.materialize_chore_revision_window(
    p_household_id,
    p_series_id,
    v_revision_id,
    v_effective_local_date,
    v_horizon_end
  );
  v_result_rebuilt_count := v_reused_count + v_inserted_count;

  select count(*)::integer
  into v_result_preserved_completed_count
  from public.chore_occurrences as occurrence
  where occurrence.household_id = p_household_id
    and occurrence.series_id = p_series_id
    and occurrence.recurrence_local_date >= v_effective_local_date
    and occurrence.status = 'completed';

  delete from app_private.chore_materialization_states as state
  where state.household_id = p_household_id
    and state.series_id = p_series_id;

  insert into public.chore_series_change_events (
    household_id,
    series_id,
    operation,
    previous_revision_id,
    new_revision_id,
    effective_local_date,
    actor_user_id,
    actor_member_id,
    rebuilt_count,
    cancelled_count,
    preserved_completed_count,
    series_version,
    correlation_id
  )
  values (
    p_household_id,
    p_series_id,
    'updated',
    v_previous_revision_id,
    v_revision_id,
    v_effective_local_date,
    v_authenticated_user_id,
    v_actor_member_id,
    v_result_rebuilt_count,
    v_result_cancelled_count,
    v_result_preserved_completed_count,
    v_result_version,
    p_idempotency_key
  )
  returning id into v_result_event_id;

  insert into app_private.chore_series_change_command_requests (
    authenticated_user_id,
    idempotency_key,
    request_hash,
    operation,
    household_id,
    series_id,
    result_revision_id,
    result_effective_local_date,
    result_version,
    result_rebuilt_count,
    result_cancelled_count,
    result_preserved_completed_count,
    result_event_id
  )
  values (
    v_authenticated_user_id,
    p_idempotency_key,
    v_request_hash,
    'updated',
    p_household_id,
    p_series_id,
    v_revision_id,
    v_effective_local_date,
    v_result_version,
    v_result_rebuilt_count,
    v_result_cancelled_count,
    v_result_preserved_completed_count,
    v_result_event_id
  );

  return query select
    p_household_id,
    p_series_id,
    v_revision_id,
    v_revision_number,
    v_effective_local_date,
    v_result_version,
    v_result_rebuilt_count,
    v_result_cancelled_count,
    v_result_preserved_completed_count,
    true;
end;
$$;

revoke all on function app_private.update_repeating_chore_series_at_boundary(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint,
  text,
  text,
  uuid,
  time without time zone,
  jsonb
) from public, anon, authenticated, service_role;

create or replace function public.update_repeating_chore_series(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_expected_version bigint,
  p_title text,
  p_description text,
  p_assignee_member_id uuid,
  p_due_local_time time without time zone,
  p_recurrence_rule jsonb
)
returns table (
  household_id uuid,
  series_id uuid,
  revision_id uuid,
  revision_number integer,
  effective_local_date date,
  version bigint,
  rebuilt_count integer,
  cancelled_count integer,
  preserved_completed_count integer,
  changed boolean
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  select *
  from app_private.update_repeating_chore_series_at_boundary(
    p_idempotency_key,
    p_household_id,
    p_series_id,
    null,
    p_expected_version,
    p_title,
    p_description,
    p_assignee_member_id,
    p_due_local_time,
    p_recurrence_rule
  );
end;
$$;

create function public.update_repeating_chore_series_from_occurrence(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_effective_occurrence_id uuid,
  p_expected_version bigint,
  p_title text,
  p_description text,
  p_assignee_member_id uuid,
  p_due_local_time time without time zone,
  p_recurrence_rule jsonb
)
returns table (
  household_id uuid,
  series_id uuid,
  revision_id uuid,
  revision_number integer,
  effective_local_date date,
  version bigint,
  rebuilt_count integer,
  cancelled_count integer,
  preserved_completed_count integer,
  changed boolean
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_effective_occurrence_id is null then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  return query
  select *
  from app_private.update_repeating_chore_series_at_boundary(
    p_idempotency_key,
    p_household_id,
    p_series_id,
    p_effective_occurrence_id,
    p_expected_version,
    p_title,
    p_description,
    p_assignee_member_id,
    p_due_local_time,
    p_recurrence_rule
  );
end;
$$;

revoke all on function public.update_repeating_chore_series(
  uuid,
  uuid,
  uuid,
  bigint,
  text,
  text,
  uuid,
  time without time zone,
  jsonb
) from public, anon, authenticated;

grant execute on function public.update_repeating_chore_series(
  uuid,
  uuid,
  uuid,
  bigint,
  text,
  text,
  uuid,
  time without time zone,
  jsonb
) to authenticated;

revoke all on function public.update_repeating_chore_series_from_occurrence(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint,
  text,
  text,
  uuid,
  time without time zone,
  jsonb
) from public, anon, authenticated;

grant execute on function public.update_repeating_chore_series_from_occurrence(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint,
  text,
  text,
  uuid,
  time without time zone,
  jsonb
) to authenticated;
