-- KinFlow WP03-21 selected-occurrence repeating chore series cancellation.
-- The selected immutable recurrence slot is the exclusive end boundary. A
-- bounded terminal revision keeps any earlier scheduled prefix queryable.

alter table public.chore_series_change_events
  drop constraint chore_series_change_event_revision_shape_ck,
  add constraint chore_series_change_event_revision_shape_ck check (
    (operation = 'updated' and new_revision_id is not null)
    or operation = 'cancelled'
  );

alter table app_private.chore_series_change_command_requests
  drop constraint chore_series_change_request_revision_shape_ck,
  add constraint chore_series_change_request_revision_shape_ck check (
    (operation = 'updated' and result_revision_id is not null)
    or operation = 'cancelled'
  );

create function public.cancel_repeating_chore_series_from_occurrence(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_effective_occurrence_id uuid,
  p_expected_version bigint
)
returns table (
  household_id uuid,
  series_id uuid,
  effective_local_date date,
  version bigint,
  cancelled_count integer,
  preserved_completed_count integer,
  terminal_revision_id uuid,
  terminal_revision_number integer,
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
  v_timezone text;
  v_current_version bigint;
  v_previous_revision_id uuid;
  v_previous_recurrence_rule jsonb;
  v_household_local_today date;
  v_effective_local_date date;
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_result_effective_local_date date;
  v_result_version bigint;
  v_result_cancelled_count integer;
  v_result_preserved_completed_count integer;
  v_result_terminal_revision_id uuid;
  v_result_terminal_revision_number integer;
  v_result_event_id uuid;
  v_terminal_source_revision_id uuid;
  v_terminal_source_title text;
  v_terminal_source_description text;
  v_terminal_source_effective_local_date date;
  v_terminal_source_due_local_time time without time zone;
  v_terminal_source_recurrence_rule jsonb;
  v_terminal_source_assignee_member_id uuid;
  v_terminal_recurrence_rule jsonb;
  v_terminal_slot_count integer;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFC01',
      message = 'authentication required';
  end if;

  if p_idempotency_key is null
    or p_household_id is null
    or p_series_id is null
    or p_effective_occurrence_id is null
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

  if not found or v_actor_role not in ('owner', 'admin') then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  v_request_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'operation', 'cancel_repeating_chore_series_from_occurrence',
        'household_id', p_household_id,
        'series_id', p_series_id,
        'effective_occurrence_id', p_effective_occurrence_id,
        'expected_version', p_expected_version
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
    request.result_effective_local_date,
    request.result_version,
    request.result_cancelled_count,
    request.result_preserved_completed_count,
    request.result_revision_id,
    revision.revision_number
  into
    v_existing_request_hash,
    v_result_effective_local_date,
    v_result_version,
    v_result_cancelled_count,
    v_result_preserved_completed_count,
    v_result_terminal_revision_id,
    v_result_terminal_revision_number
  from app_private.chore_series_change_command_requests as request
  left join public.chore_series_revisions as revision
    on revision.household_id = request.household_id
   and revision.id = request.result_revision_id
  where request.authenticated_user_id = v_authenticated_user_id
    and request.idempotency_key = p_idempotency_key
    and request.operation = 'cancelled';

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFC04',
        message = 'idempotency key reused with different chore input';
    end if;

    return query select
      p_household_id,
      p_series_id,
      v_result_effective_local_date,
      v_result_version,
      v_result_cancelled_count,
      v_result_preserved_completed_count,
      v_result_terminal_revision_id,
      v_result_terminal_revision_number,
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
    series.version,
    revision.id,
    revision.recurrence_rule
  into
    v_timezone,
    v_current_version,
    v_previous_revision_id,
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

  v_household_local_today :=
    (statement_timestamp() at time zone v_timezone)::date;

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

  select count(*)::integer
  into v_result_preserved_completed_count
  from public.chore_occurrences as occurrence
  where occurrence.household_id = p_household_id
    and occurrence.series_id = p_series_id
    and occurrence.recurrence_local_date >= v_effective_local_date
    and occurrence.status = 'completed';

  update public.chore_occurrences as occurrence
  set status = 'cancelled'
  where occurrence.household_id = p_household_id
    and occurrence.series_id = p_series_id
    and occurrence.recurrence_local_date >= v_effective_local_date
    and occurrence.status not in ('completed', 'cancelled');

  get diagnostics v_result_cancelled_count = row_count;

  select occurrence.revision_id
  into v_terminal_source_revision_id
  from public.chore_occurrences as occurrence
  where occurrence.household_id = p_household_id
    and occurrence.series_id = p_series_id
    and occurrence.recurrence_local_date < v_effective_local_date
    and occurrence.status = 'scheduled'
  order by occurrence.recurrence_local_date desc, occurrence.id
  limit 1
  for update of occurrence;

  if found then
    select
      revision.title,
      revision.description,
      revision.effective_local_date,
      revision.due_local_time,
      revision.recurrence_rule,
      revision.default_assignee_member_id
    into
      v_terminal_source_title,
      v_terminal_source_description,
      v_terminal_source_effective_local_date,
      v_terminal_source_due_local_time,
      v_terminal_source_recurrence_rule,
      v_terminal_source_assignee_member_id
    from public.chore_series_revisions as revision
    where revision.household_id = p_household_id
      and revision.series_id = p_series_id
      and revision.id = v_terminal_source_revision_id;

    if not found
      or v_terminal_source_recurrence_rule = '{"type":"once"}'::jsonb then
      raise exception using
        errcode = 'KFC06',
        message = 'chore series transition not allowed';
    end if;

    v_terminal_recurrence_rule := case
      when v_terminal_source_recurrence_rule->'end'->>'type' = 'count' then
        v_terminal_source_recurrence_rule
      when v_terminal_source_recurrence_rule->'end'->>'type' = 'until'
        and (
          v_terminal_source_recurrence_rule->'end'->>'localDate'
        )::date < v_effective_local_date then
        v_terminal_source_recurrence_rule
      else
        jsonb_set(
          v_terminal_source_recurrence_rule,
          '{end}',
          jsonb_build_object(
            'type', 'until',
            'localDate', (v_effective_local_date - 1)::text
          ),
          false
        )
    end;

    if v_terminal_source_recurrence_rule->'end'->>'type' = 'count' then
      select count(*)::integer
      into v_terminal_slot_count
      from public.chore_occurrences as occurrence
      where occurrence.household_id = p_household_id
        and occurrence.series_id = p_series_id
        and occurrence.revision_id = v_terminal_source_revision_id
        and occurrence.recurrence_local_date < v_effective_local_date;

      v_terminal_slot_count := least(
        v_terminal_slot_count,
        (v_terminal_source_recurrence_rule->'end'->>'count')::integer
      );
      if v_terminal_slot_count < 1 then
        raise exception using
          errcode = 'KFC06',
          message = 'chore series transition not allowed';
      end if;
      v_terminal_recurrence_rule := jsonb_set(
        v_terminal_source_recurrence_rule,
        '{end}',
        jsonb_build_object('type', 'count', 'count', v_terminal_slot_count),
        false
      );
    end if;

    if not app_private.is_valid_chore_recurrence_rule(
      v_terminal_recurrence_rule
    ) or (
      v_terminal_recurrence_rule->'end'->>'type' = 'until'
      and (
        v_terminal_recurrence_rule->'end'->>'localDate'
      )::date < v_terminal_source_effective_local_date
    ) then
      raise exception using
        errcode = 'KFC06',
        message = 'chore series transition not allowed';
    end if;

    v_result_terminal_revision_id := extensions.gen_random_uuid();
    select coalesce(max(revision.revision_number), 0) + 1
    into v_result_terminal_revision_number
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
      v_result_terminal_revision_id,
      p_household_id,
      p_series_id,
      v_result_terminal_revision_number,
      v_terminal_source_effective_local_date,
      v_terminal_source_due_local_time,
      v_terminal_recurrence_rule,
      v_terminal_source_assignee_member_id,
      v_authenticated_user_id,
      v_terminal_source_title,
      v_terminal_source_description
    );

    update public.chore_occurrences as occurrence
    set revision_id = v_result_terminal_revision_id
    where occurrence.household_id = p_household_id
      and occurrence.series_id = p_series_id
      and occurrence.revision_id = v_terminal_source_revision_id
      and occurrence.recurrence_local_date < v_effective_local_date
      and occurrence.status = 'scheduled';

    update public.chore_series as series
    set
      title = v_terminal_source_title,
      description = v_terminal_source_description,
      active_revision_id = v_result_terminal_revision_id
    where series.household_id = p_household_id
      and series.id = p_series_id
    returning series.version into v_result_version;
  else
    v_result_terminal_revision_id := null;
    v_result_terminal_revision_number := null;

    update public.chore_series as series
    set deleted_at = statement_timestamp()
    where series.household_id = p_household_id
      and series.id = p_series_id
    returning series.version into v_result_version;
  end if;

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
    'cancelled',
    v_previous_revision_id,
    v_result_terminal_revision_id,
    v_effective_local_date,
    v_authenticated_user_id,
    v_actor_member_id,
    0,
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
    'cancelled',
    p_household_id,
    p_series_id,
    v_result_terminal_revision_id,
    v_effective_local_date,
    v_result_version,
    0,
    v_result_cancelled_count,
    v_result_preserved_completed_count,
    v_result_event_id
  );

  return query select
    p_household_id,
    p_series_id,
    v_effective_local_date,
    v_result_version,
    v_result_cancelled_count,
    v_result_preserved_completed_count,
    v_result_terminal_revision_id,
    v_result_terminal_revision_number,
    true;
end;
$$;

revoke all on function public.cancel_repeating_chore_series_from_occurrence(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) from public, anon, authenticated, service_role;

grant execute on function public.cancel_repeating_chore_series_from_occurrence(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) to authenticated;
