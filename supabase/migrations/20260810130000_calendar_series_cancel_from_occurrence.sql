-- KinFlow WP04-15 selected-occurrence recurring Calendar cancellation.
-- The selected immutable recurrence slot is the exclusive end boundary. A
-- bounded terminal revision keeps any earlier actionable prefix available.

alter table public.event_series_change_events
  drop constraint event_series_change_event_revision_shape_ck,
  add constraint event_series_change_event_revision_shape_ck check (
    (
      operation = 'updated'
      and new_revision_id is not null
      and materialized_through is not null
    )
    or (
      operation = 'cancelled'
      and (
        new_revision_id is null and materialized_through is null
        or new_revision_id is not null and materialized_through is not null
      )
    )
  );

alter table app_private.calendar_series_change_command_requests
  drop constraint calendar_series_change_request_revision_shape_ck,
  add constraint calendar_series_change_request_revision_shape_ck check (
    (
      operation = 'updated'
      and result_revision_id is not null
      and result_revision_number is not null
      and result_revision_number > 0
      and result_materialized_through is not null
    )
    or (
      operation = 'cancelled'
      and (
        result_revision_id is null
        and result_revision_number is null
        and result_materialized_through is null
        or result_revision_id is not null
        and result_revision_number is not null
        and result_revision_number > 0
        and result_materialized_through is not null
      )
    )
  );

create function app_private.cancel_recurring_calendar_series_at_boundary(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_effective_occurrence_id uuid,
  p_expected_version bigint
)
returns table (
  household_id uuid,
  household_timezone text,
  household_local_date date,
  series_id uuid,
  effective_local_date date,
  version bigint,
  cancelled_count integer,
  preserved_past_count integer,
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
  v_household_timezone text;
  v_household_local_date date;
  v_effective_local_date date;
  v_replay_effective_local_date date;
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_current_version bigint;
  v_previous_revision_id uuid;
  v_previous_recurrence_rule jsonb;
  v_result_version bigint;
  v_cancelled_count integer;
  v_preserved_exception_count integer;
  v_preserved_past_count integer;
  v_result_event_id uuid;
  v_audit_occurrence_id uuid;
  v_audit_occurrence_version bigint;
  v_terminal_source_revision_id uuid;
  v_terminal_local_start_date date;
  v_terminal_local_start_time time without time zone;
  v_terminal_duration_minutes integer;
  v_terminal_all_day_end_date_exclusive date;
  v_terminal_gap_policy text;
  v_terminal_overlap_policy text;
  v_terminal_recurrence_rule jsonb;
  v_terminal_title text;
  v_terminal_description text;
  v_terminal_timezone text;
  v_terminal_is_all_day boolean;
  v_terminal_revision_id uuid;
  v_terminal_revision_number integer;
  v_terminal_materialized_through date;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFE01',
      message = 'authentication required';
  end if;

  if p_idempotency_key is null
    or p_household_id is null
    or p_series_id is null
    or p_expected_version is null
    or p_expected_version < 1 then
    raise exception using
      errcode = 'KFE02',
      message = 'invalid calendar event input';
  end if;

  select household.timezone, caller.id
  into v_household_timezone, v_actor_member_id
  from public.households as household
  join public.household_members as caller
    on caller.household_id = household.id
   and caller.auth_user_id = v_authenticated_user_id
   and caller.removed_at is null
  where household.id = p_household_id
    and household.deleted_at is null
  for update of caller;

  if not found then
    raise exception using
      errcode = 'KFE03',
      message = 'calendar event not found or forbidden';
  end if;

  v_household_local_date :=
    (pg_catalog.statement_timestamp() at time zone v_household_timezone)::date;
  v_request_hash := extensions.digest(
    pg_catalog.convert_to(
      (
        case
          when p_effective_occurrence_id is null then
            pg_catalog.jsonb_build_object(
              'command', 'cancel_recurring_calendar_series',
              'household_id', p_household_id,
              'series_id', p_series_id,
              'expected_version', p_expected_version
            )
          else
            pg_catalog.jsonb_build_object(
              'command', 'cancel_recurring_calendar_series_from_occurrence',
              'household_id', p_household_id,
              'series_id', p_series_id,
              'effective_occurrence_id', p_effective_occurrence_id,
              'expected_version', p_expected_version
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
        || ':calendar-series-change:'
        || p_idempotency_key::text,
      0
    )
  );

  select
    request.request_hash,
    request.result_effective_local_date,
    request.result_version,
    request.result_cancelled_count,
    request.result_preserved_past_count,
    request.result_revision_id,
    request.result_revision_number
  into
    v_existing_request_hash,
    v_replay_effective_local_date,
    v_result_version,
    v_cancelled_count,
    v_preserved_past_count,
    v_terminal_revision_id,
    v_terminal_revision_number
  from app_private.calendar_series_change_command_requests as request
  where request.authenticated_user_id = v_authenticated_user_id
    and request.idempotency_key = p_idempotency_key
    and request.operation = 'cancelled';

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFE04',
        message = 'idempotency key reused with different calendar input';
    end if;

    return query select
      p_household_id,
      v_household_timezone,
      case
        when p_effective_occurrence_id is null
          then v_replay_effective_local_date
        else v_household_local_date
      end,
      p_series_id,
      v_replay_effective_local_date,
      v_result_version,
      v_cancelled_count,
      v_preserved_past_count,
      v_terminal_revision_id,
      v_terminal_revision_number,
      false;
    return;
  end if;

  if exists (
      select 1
      from app_private.calendar_series_change_command_requests as request
      where request.authenticated_user_id = v_authenticated_user_id
        and request.idempotency_key = p_idempotency_key
    )
    or exists (
      select 1
      from app_private.calendar_command_requests as request
      where request.authenticated_user_id = v_authenticated_user_id
        and request.idempotency_key = p_idempotency_key
    )
    or exists (
      select 1
      from app_private.calendar_recurring_command_requests as request
      where request.authenticated_user_id = v_authenticated_user_id
        and request.idempotency_key = p_idempotency_key
    )
    or exists (
      select 1
      from app_private.calendar_occurrence_exception_command_requests
        as request
      where request.authenticated_user_id = v_authenticated_user_id
        and request.idempotency_key = p_idempotency_key
    ) then
    raise exception using
      errcode = 'KFE04',
      message = 'idempotency key reused with different calendar input';
  end if;

  select series.version, revision.id, revision.recurrence_rule
  into v_current_version, v_previous_revision_id, v_previous_recurrence_rule
  from public.event_series as series
  join public.event_series_revisions as revision
    on revision.household_id = series.household_id
   and revision.series_id = series.id
   and revision.id = series.active_revision_id
  where series.household_id = p_household_id
    and series.id = p_series_id
    and series.deleted_at is null
    and series.ended_at is null
  for update of series;

  if not found or v_previous_recurrence_rule is null then
    raise exception using
      errcode = 'KFE03',
      message = 'calendar event not found or forbidden';
  end if;

  if v_current_version <> p_expected_version then
    raise exception using
      errcode = 'KFE05',
      message = 'stale calendar event version';
  end if;

  if p_effective_occurrence_id is null then
    v_effective_local_date := v_household_local_date;
  else
    select occurrence.recurrence_local_start_date
    into v_effective_local_date
    from public.event_occurrences as occurrence
    where occurrence.household_id = p_household_id
      and occurrence.series_id = p_series_id
      and occurrence.id = p_effective_occurrence_id
      and occurrence.revision_id = v_previous_revision_id
      and occurrence.status = 'scheduled'::public.occurrence_status
      and occurrence.recurrence_local_start_date >= v_household_local_date
      and not exists (
        select 1
        from public.event_occurrence_exceptions as exception
        where exception.household_id = occurrence.household_id
          and exception.series_id = occurrence.series_id
          and exception.occurrence_id = occurrence.id
      )
    for update of occurrence;

    if not found then
      raise exception using
        errcode = 'KFE03',
        message = 'calendar event not found or forbidden';
    end if;
  end if;

  select pg_catalog.count(*)::integer
  into v_preserved_past_count
  from public.event_occurrences as occurrence
  where occurrence.household_id = p_household_id
    and occurrence.series_id = p_series_id
    and occurrence.recurrence_local_start_date < v_effective_local_date;

  select pg_catalog.count(*)::integer
  into v_preserved_exception_count
  from public.event_occurrence_exceptions as exception
  join public.event_occurrences as occurrence
    on occurrence.household_id = exception.household_id
   and occurrence.series_id = exception.series_id
   and occurrence.id = exception.occurrence_id
  where exception.household_id = p_household_id
    and exception.series_id = p_series_id
    and occurrence.recurrence_local_start_date >= v_effective_local_date;

  update public.event_occurrences as occurrence
  set status = 'cancelled'::public.occurrence_status
  where occurrence.household_id = p_household_id
    and occurrence.series_id = p_series_id
    and occurrence.recurrence_local_start_date >= v_effective_local_date
    and occurrence.status <> 'cancelled'::public.occurrence_status;

  get diagnostics v_cancelled_count = row_count;

  if p_effective_occurrence_id is not null then
    select occurrence.revision_id
    into v_terminal_source_revision_id
    from public.event_occurrences as occurrence
    join public.event_series_revisions as revision
      on revision.household_id = occurrence.household_id
     and revision.series_id = occurrence.series_id
     and revision.id = occurrence.revision_id
     and revision.recurrence_rule is not null
    where occurrence.household_id = p_household_id
      and occurrence.series_id = p_series_id
      and occurrence.status = 'scheduled'::public.occurrence_status
      and occurrence.recurrence_local_start_date >= v_household_local_date
      and occurrence.recurrence_local_start_date < v_effective_local_date
      and not exists (
        select 1
        from public.event_occurrence_exceptions as exception
        where exception.household_id = occurrence.household_id
          and exception.series_id = occurrence.series_id
          and exception.occurrence_id = occurrence.id
      )
    order by occurrence.recurrence_local_start_date desc, occurrence.id
    limit 1
    for update of occurrence;
  end if;

  if v_terminal_source_revision_id is not null then
    select
      revision.local_start_date,
      revision.local_start_time,
      revision.duration_minutes,
      revision.all_day_end_date_exclusive,
      revision.gap_policy,
      revision.overlap_policy,
      revision.recurrence_rule,
      revision.snapshot_title,
      revision.snapshot_description,
      revision.snapshot_timezone,
      revision.snapshot_is_all_day
    into
      v_terminal_local_start_date,
      v_terminal_local_start_time,
      v_terminal_duration_minutes,
      v_terminal_all_day_end_date_exclusive,
      v_terminal_gap_policy,
      v_terminal_overlap_policy,
      v_terminal_recurrence_rule,
      v_terminal_title,
      v_terminal_description,
      v_terminal_timezone,
      v_terminal_is_all_day
    from public.event_series_revisions as revision
    where revision.household_id = p_household_id
      and revision.series_id = p_series_id
      and revision.id = v_terminal_source_revision_id;

    if not found or v_terminal_recurrence_rule is null then
      raise exception using
        errcode = 'KFE08',
        message = 'calendar series transition not allowed';
    end if;

    v_terminal_materialized_through := v_effective_local_date - 1;
    v_terminal_recurrence_rule := pg_catalog.jsonb_set(
      v_terminal_recurrence_rule,
      '{end}',
      pg_catalog.jsonb_build_object(
        'type', 'until',
        'localDate', v_terminal_materialized_through::text
      ),
      false
    );

    if v_terminal_materialized_through < v_terminal_local_start_date
      or not app_private.is_valid_calendar_recurrence_rule(
        v_terminal_recurrence_rule
      ) then
      raise exception using
        errcode = 'KFE08',
        message = 'calendar series transition not allowed';
    end if;

    v_terminal_revision_id := extensions.gen_random_uuid();
    select coalesce(pg_catalog.max(revision.revision_number), 0) + 1
    into v_terminal_revision_number
    from public.event_series_revisions as revision
    where revision.household_id = p_household_id
      and revision.series_id = p_series_id;

    insert into public.event_series_revisions (
      id,
      household_id,
      series_id,
      revision_number,
      local_start_date,
      local_start_time,
      duration_minutes,
      all_day_end_date_exclusive,
      gap_policy,
      overlap_policy,
      recurrence_rule,
      created_by_user_id,
      snapshot_title,
      snapshot_description,
      snapshot_timezone,
      snapshot_is_all_day
    ) values (
      v_terminal_revision_id,
      p_household_id,
      p_series_id,
      v_terminal_revision_number,
      v_terminal_local_start_date,
      v_terminal_local_start_time,
      v_terminal_duration_minutes,
      v_terminal_all_day_end_date_exclusive,
      v_terminal_gap_policy,
      v_terminal_overlap_policy,
      v_terminal_recurrence_rule,
      v_authenticated_user_id,
      v_terminal_title,
      v_terminal_description,
      v_terminal_timezone,
      v_terminal_is_all_day
    );

    insert into public.event_revision_participants (
      household_id,
      series_id,
      revision_id,
      member_id
    )
    select
      participant.household_id,
      participant.series_id,
      v_terminal_revision_id,
      participant.member_id
    from public.event_revision_participants as participant
    where participant.household_id = p_household_id
      and participant.series_id = p_series_id
      and participant.revision_id = v_terminal_source_revision_id;

    update public.event_occurrences as occurrence
    set revision_id = v_terminal_revision_id
    where occurrence.household_id = p_household_id
      and occurrence.series_id = p_series_id
      and occurrence.revision_id = v_terminal_source_revision_id
      and occurrence.status = 'scheduled'::public.occurrence_status
      and occurrence.recurrence_local_start_date >= v_household_local_date
      and occurrence.recurrence_local_start_date < v_effective_local_date
      and not exists (
        select 1
        from public.event_occurrence_exceptions as exception
        where exception.household_id = occurrence.household_id
          and exception.series_id = occurrence.series_id
          and exception.occurrence_id = occurrence.id
      );

    delete from public.event_participants as participant
    where participant.household_id = p_household_id
      and participant.series_id = p_series_id;

    insert into public.event_participants (
      household_id,
      series_id,
      member_id
    )
    select
      p_household_id,
      p_series_id,
      participant.member_id
    from public.event_revision_participants as participant
    where participant.household_id = p_household_id
      and participant.series_id = p_series_id
      and participant.revision_id = v_terminal_revision_id;

    update public.event_series as series
    set
      title = v_terminal_title,
      description = v_terminal_description,
      timezone = v_terminal_timezone,
      is_all_day = v_terminal_is_all_day,
      active_revision_id = v_terminal_revision_id
    where series.household_id = p_household_id
      and series.id = p_series_id
    returning series.version into v_result_version;

    insert into app_private.calendar_materialization_states (
      household_id,
      series_id,
      revision_id,
      covered_through,
      last_window_start,
      last_target_date,
      next_repair_at,
      last_attempted_at,
      last_succeeded_at,
      last_result,
      last_error_code,
      last_changed_count,
      attempt_count,
      updated_at
    ) values (
      p_household_id,
      p_series_id,
      v_terminal_revision_id,
      v_terminal_materialized_through,
      greatest(v_terminal_local_start_date, v_household_local_date),
      v_terminal_materialized_through,
      'infinity'::timestamptz,
      pg_catalog.statement_timestamp(),
      pg_catalog.statement_timestamp(),
      'succeeded',
      null,
      0,
      1,
      pg_catalog.statement_timestamp()
    )
    on conflict on constraint calendar_materialization_states_pkey do update
    set
      revision_id = excluded.revision_id,
      covered_through = excluded.covered_through,
      last_window_start = excluded.last_window_start,
      last_target_date = excluded.last_target_date,
      next_repair_at = excluded.next_repair_at,
      last_attempted_at = excluded.last_attempted_at,
      last_succeeded_at = excluded.last_succeeded_at,
      last_result = excluded.last_result,
      last_error_code = excluded.last_error_code,
      last_changed_count = excluded.last_changed_count,
      attempt_count = calendar_materialization_states.attempt_count + 1,
      updated_at = excluded.updated_at;
  else
    v_terminal_revision_id := null;
    v_terminal_revision_number := null;
    v_terminal_materialized_through := null;

    update public.event_series as series
    set
      ended_at = pg_catalog.statement_timestamp(),
      ended_effective_local_date = v_effective_local_date
    where series.household_id = p_household_id
      and series.id = p_series_id
    returning series.version into v_result_version;

    delete from app_private.calendar_materialization_states as state
    where state.household_id = p_household_id
      and state.series_id = p_series_id;
  end if;

  if p_effective_occurrence_id is null then
    select occurrence.id, occurrence.version
    into v_audit_occurrence_id, v_audit_occurrence_version
    from public.event_occurrences as occurrence
    where occurrence.household_id = p_household_id
      and occurrence.series_id = p_series_id
    order by occurrence.recurrence_local_start_date, occurrence.id
    limit 1;
  else
    select occurrence.id, occurrence.version
    into v_audit_occurrence_id, v_audit_occurrence_version
    from public.event_occurrences as occurrence
    where occurrence.household_id = p_household_id
      and occurrence.series_id = p_series_id
      and occurrence.id = p_effective_occurrence_id;
  end if;

  insert into public.event_series_change_events (
    household_id,
    series_id,
    operation,
    previous_revision_id,
    new_revision_id,
    effective_local_date,
    materialized_through,
    actor_user_id,
    actor_member_id,
    rebuilt_count,
    cancelled_count,
    preserved_exception_count,
    preserved_past_count,
    series_version,
    correlation_id
  ) values (
    p_household_id,
    p_series_id,
    'cancelled',
    v_previous_revision_id,
    v_terminal_revision_id,
    v_effective_local_date,
    v_terminal_materialized_through,
    v_authenticated_user_id,
    v_actor_member_id,
    0,
    v_cancelled_count,
    v_preserved_exception_count,
    v_preserved_past_count,
    v_result_version,
    p_idempotency_key
  )
  returning id into v_result_event_id;

  insert into app_private.calendar_series_change_command_requests (
    authenticated_user_id,
    idempotency_key,
    request_hash,
    operation,
    household_id,
    series_id,
    result_revision_id,
    result_revision_number,
    result_effective_local_date,
    result_materialized_through,
    result_version,
    result_rebuilt_count,
    result_cancelled_count,
    result_preserved_exception_count,
    result_preserved_past_count,
    result_event_id
  ) values (
    v_authenticated_user_id,
    p_idempotency_key,
    v_request_hash,
    'cancelled',
    p_household_id,
    p_series_id,
    v_terminal_revision_id,
    v_terminal_revision_number,
    v_effective_local_date,
    v_terminal_materialized_through,
    v_result_version,
    0,
    v_cancelled_count,
    v_preserved_exception_count,
    v_preserved_past_count,
    v_result_event_id
  );

  insert into app_private.calendar_audit_events (
    household_id,
    action,
    series_id,
    occurrence_id,
    actor_user_id,
    actor_member_id,
    correlation_id,
    series_version,
    occurrence_version
  ) values (
    p_household_id,
    'calendar.series_cancelled',
    p_series_id,
    v_audit_occurrence_id,
    v_authenticated_user_id,
    v_actor_member_id,
    p_idempotency_key,
    v_result_version,
    v_audit_occurrence_version
  );

  return query select
    p_household_id,
    v_household_timezone,
    v_household_local_date,
    p_series_id,
    v_effective_local_date,
    v_result_version,
    v_cancelled_count,
    v_preserved_past_count,
    v_terminal_revision_id,
    v_terminal_revision_number,
    true;
end;
$$;

revoke all on function app_private.cancel_recurring_calendar_series_at_boundary(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) from public, anon, authenticated, service_role;

create or replace function public.cancel_recurring_calendar_series(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_expected_version bigint
)
returns table (
  household_id uuid,
  household_timezone text,
  household_local_date date,
  series_id uuid,
  effective_local_date date,
  version bigint,
  cancelled_count integer,
  preserved_past_count integer,
  changed boolean
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  select
    result.household_id,
    result.household_timezone,
    result.household_local_date,
    result.series_id,
    result.effective_local_date,
    result.version,
    result.cancelled_count,
    result.preserved_past_count,
    result.changed
  from app_private.cancel_recurring_calendar_series_at_boundary(
    p_idempotency_key,
    p_household_id,
    p_series_id,
    null,
    p_expected_version
  ) as result;
end;
$$;

create function public.cancel_recurring_calendar_series_from_occurrence(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_effective_occurrence_id uuid,
  p_expected_version bigint
)
returns table (
  household_id uuid,
  household_timezone text,
  household_local_date date,
  series_id uuid,
  effective_local_date date,
  version bigint,
  cancelled_count integer,
  preserved_past_count integer,
  terminal_revision_id uuid,
  terminal_revision_number integer,
  changed boolean
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_effective_occurrence_id is null then
    raise exception using
      errcode = 'KFE03',
      message = 'calendar event not found or forbidden';
  end if;

  return query
  select *
  from app_private.cancel_recurring_calendar_series_at_boundary(
    p_idempotency_key,
    p_household_id,
    p_series_id,
    p_effective_occurrence_id,
    p_expected_version
  );
end;
$$;

revoke all on function public.cancel_recurring_calendar_series(
  uuid,
  uuid,
  uuid,
  bigint
) from public, anon, authenticated;

grant execute on function public.cancel_recurring_calendar_series(
  uuid,
  uuid,
  uuid,
  bigint
) to authenticated;

revoke all on function public.cancel_recurring_calendar_series_from_occurrence(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) from public, anon, authenticated;

grant execute on function public.cancel_recurring_calendar_series_from_occurrence(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) to authenticated;
