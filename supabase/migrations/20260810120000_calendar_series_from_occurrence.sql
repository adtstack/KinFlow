-- KinFlow WP04-14 selected-occurrence recurring Calendar series edit.
-- The database derives the effective boundary from the selected active
-- occurrence's immutable recurrence slot. Earlier occurrences and every
-- explicit occurrence exception remain untouched.

create or replace function app_private.update_recurring_calendar_series_at_boundary(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_effective_occurrence_id uuid,
  p_expected_version bigint,
  p_title text,
  p_description text,
  p_is_all_day boolean,
  p_local_start_date date,
  p_local_start_time time without time zone,
  p_duration_minutes integer,
  p_all_day_end_date_exclusive date,
  p_timezone text,
  p_overlap_policy text,
  p_recurrence_rule jsonb,
  p_participant_member_ids uuid[]
)
returns table (
  household_id uuid,
  household_timezone text,
  household_local_date date,
  series_id uuid,
  revision_id uuid,
  revision_number integer,
  effective_local_date date,
  materialized_through date,
  version bigint,
  rebuilt_count integer,
  cancelled_count integer,
  preserved_exception_count integer,
  changed boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_actor_member_id uuid;
  v_title text := pg_catalog.btrim(p_title);
  v_description text := nullif(pg_catalog.btrim(p_description), '');
  v_household_timezone text;
  v_household_local_date date;
  v_effective_local_date date;
  v_replay_effective_local_date date;
  v_participant_member_ids uuid[];
  v_participant_count integer;
  v_start_weekday text;
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_current_title text;
  v_current_description text;
  v_current_is_all_day boolean;
  v_current_timezone text;
  v_current_version bigint;
  v_previous_revision_id uuid;
  v_previous_local_start_date date;
  v_previous_local_start_time time without time zone;
  v_previous_duration_minutes integer;
  v_previous_all_day_end_date_exclusive date;
  v_previous_overlap_policy text;
  v_previous_recurrence_rule jsonb;
  v_current_participant_member_ids uuid[];
  v_revision_id uuid;
  v_revision_number integer;
  v_materialized_through date;
  v_result_version bigint;
  v_rebuilt_count integer;
  v_cancelled_count integer;
  v_preserved_exception_count integer;
  v_preserved_past_count integer;
  v_result_event_id uuid;
  v_audit_occurrence_id uuid;
  v_audit_occurrence_version bigint;
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
    or p_expected_version < 1
    or p_is_all_day is null
    or p_local_start_date is null
    or p_participant_member_ids is null
    or pg_catalog.cardinality(p_participant_member_ids) not between 1 and 50
    or (
      select pg_catalog.count(distinct participant_id)
      from pg_catalog.unnest(p_participant_member_ids) as participant_id
    ) <> pg_catalog.cardinality(p_participant_member_ids)
    or v_title is null
    or pg_catalog.char_length(v_title) not between 1 and 200
    or v_title ~ '[[:cntrl:]]'
    or (
      v_description is not null
      and pg_catalog.char_length(v_description) > 8000
    )
    or p_recurrence_rule is null
    or not app_private.is_valid_calendar_recurrence_rule(p_recurrence_rule)
    or (
      p_is_all_day
      and (
        p_local_start_time is not null
        or p_duration_minutes is not null
        or p_all_day_end_date_exclusive is null
        or p_all_day_end_date_exclusive <= p_local_start_date
        or p_timezone is not null
        or p_overlap_policy is not null
      )
    )
    or (
      not p_is_all_day
      and (
        p_local_start_time is null
        or extract(second from p_local_start_time) <> 0
        or p_duration_minutes is null
        or p_duration_minutes not between 1 and 10080
        or p_all_day_end_date_exclusive is not null
        or p_timezone is null
        or not app_private.is_valid_iana_timezone(p_timezone)
        or p_overlap_policy not in ('earlier', 'later')
      )
    ) then
    raise exception using
      errcode = 'KFE07',
      message = 'invalid calendar recurrence rule';
  end if;

  v_start_weekday := (
    array['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU']
  )[extract(isodow from p_local_start_date)::integer];
  if (
    p_recurrence_rule->>'frequency' = 'weekly'
    and not (p_recurrence_rule->'weekdays' ? v_start_weekday)
  ) or (
    p_recurrence_rule->>'frequency' = 'monthly'
    and (p_recurrence_rule->>'monthDay')::integer
      <> extract(day from p_local_start_date)::integer
  ) or (
    p_recurrence_rule->'end'->>'type' = 'until'
    and (p_recurrence_rule->'end'->>'localDate')::date < p_local_start_date
  ) then
    raise exception using
      errcode = 'KFE07',
      message = 'invalid calendar recurrence rule';
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
  select pg_catalog.array_agg(participant_id order by participant_id)
  into v_participant_member_ids
  from pg_catalog.unnest(p_participant_member_ids) as participant_id;

  select pg_catalog.count(*)::integer
  into v_participant_count
  from public.household_members as participant
  where participant.household_id = p_household_id
    and participant.id = any(v_participant_member_ids)
    and participant.removed_at is null;

  if v_participant_count <> pg_catalog.cardinality(
    v_participant_member_ids
  ) then
    raise exception using
      errcode = 'KFE03',
      message = 'calendar event not found or forbidden';
  end if;

  v_request_hash := extensions.digest(
    pg_catalog.convert_to(
      (
        case
          when p_effective_occurrence_id is null then
            pg_catalog.jsonb_build_object(
              'command', 'update_recurring_calendar_series',
              'household_id', p_household_id,
              'series_id', p_series_id,
              'expected_version', p_expected_version,
              'title', v_title,
              'description', v_description,
              'is_all_day', p_is_all_day,
              'local_start_date', p_local_start_date,
              'local_start_time', p_local_start_time,
              'duration_minutes', p_duration_minutes,
              'all_day_end_date_exclusive', p_all_day_end_date_exclusive,
              'timezone', p_timezone,
              'overlap_policy', p_overlap_policy,
              'recurrence_rule', p_recurrence_rule,
              'participant_member_ids', v_participant_member_ids
            )
          else
            pg_catalog.jsonb_build_object(
              'command', 'update_recurring_calendar_series_from_occurrence',
              'household_id', p_household_id,
              'series_id', p_series_id,
              'effective_occurrence_id', p_effective_occurrence_id,
              'expected_version', p_expected_version,
              'title', v_title,
              'description', v_description,
              'is_all_day', p_is_all_day,
              'local_start_date', p_local_start_date,
              'local_start_time', p_local_start_time,
              'duration_minutes', p_duration_minutes,
              'all_day_end_date_exclusive', p_all_day_end_date_exclusive,
              'timezone', p_timezone,
              'overlap_policy', p_overlap_policy,
              'recurrence_rule', p_recurrence_rule,
              'participant_member_ids', v_participant_member_ids
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
    request.result_revision_id,
    request.result_revision_number,
    request.result_effective_local_date,
    request.result_materialized_through,
    request.result_version,
    request.result_rebuilt_count,
    request.result_cancelled_count,
    request.result_preserved_exception_count
  into
    v_existing_request_hash,
    v_revision_id,
    v_revision_number,
    v_replay_effective_local_date,
    v_materialized_through,
    v_result_version,
    v_rebuilt_count,
    v_cancelled_count,
    v_preserved_exception_count
  from app_private.calendar_series_change_command_requests as request
  where request.authenticated_user_id = v_authenticated_user_id
    and request.idempotency_key = p_idempotency_key
    and request.operation = 'updated';

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFE04',
        message = 'idempotency key reused with different calendar input';
    end if;

    return query select
      p_household_id,
      v_household_timezone,
      v_household_local_date,
      p_series_id,
      v_revision_id,
      v_revision_number,
      v_replay_effective_local_date,
      v_materialized_through,
      v_result_version,
      v_rebuilt_count,
      v_cancelled_count,
      v_preserved_exception_count,
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

  select
    series.title,
    series.description,
    series.is_all_day,
    series.timezone,
    series.version,
    revision.id,
    revision.local_start_date,
    revision.local_start_time,
    revision.duration_minutes,
    revision.all_day_end_date_exclusive,
    revision.overlap_policy,
    revision.recurrence_rule
  into
    v_current_title,
    v_current_description,
    v_current_is_all_day,
    v_current_timezone,
    v_current_version,
    v_previous_revision_id,
    v_previous_local_start_date,
    v_previous_local_start_time,
    v_previous_duration_minutes,
    v_previous_all_day_end_date_exclusive,
    v_previous_overlap_policy,
    v_previous_recurrence_rule
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

  if (
      p_effective_occurrence_id is not null
      and p_local_start_date < v_effective_local_date
    )
    or (
      p_recurrence_rule->'end'->>'type' = 'until'
      and (p_recurrence_rule->'end'->>'localDate')::date
        < v_effective_local_date
    ) then
    raise exception using
      errcode = 'KFE07',
      message = 'invalid calendar recurrence rule';
  end if;

  select pg_catalog.array_agg(participant.member_id order by participant.member_id)
  into v_current_participant_member_ids
  from public.event_revision_participants as participant
  where participant.household_id = p_household_id
    and participant.series_id = p_series_id
    and participant.revision_id = v_previous_revision_id;

  if v_current_title is not distinct from v_title
    and v_current_description is not distinct from v_description
    and v_current_is_all_day = p_is_all_day
    and v_current_timezone is not distinct from p_timezone
    and v_previous_local_start_date = p_local_start_date
    and v_previous_local_start_time is not distinct from p_local_start_time
    and v_previous_duration_minutes is not distinct from p_duration_minutes
    and v_previous_all_day_end_date_exclusive is not distinct from
      p_all_day_end_date_exclusive
    and v_previous_overlap_policy is not distinct from p_overlap_policy
    and v_previous_recurrence_rule = p_recurrence_rule
    and v_current_participant_member_ids = v_participant_member_ids then
    raise exception using
      errcode = 'KFE08',
      message = 'calendar series transition not allowed';
  end if;

  v_revision_id := extensions.gen_random_uuid();
  select coalesce(pg_catalog.max(revision.revision_number), 0) + 1
  into v_revision_number
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
    v_revision_id,
    p_household_id,
    p_series_id,
    v_revision_number,
    p_local_start_date,
    p_local_start_time,
    p_duration_minutes,
    p_all_day_end_date_exclusive,
    case when p_is_all_day then null else 'reject' end,
    p_overlap_policy,
    p_recurrence_rule,
    v_authenticated_user_id,
    v_title,
    v_description,
    p_timezone,
    p_is_all_day
  );

  insert into public.event_revision_participants (
    household_id,
    series_id,
    revision_id,
    member_id
  )
  select p_household_id, p_series_id, v_revision_id, participant_id
  from pg_catalog.unnest(v_participant_member_ids) as participant_id;

  delete from public.event_participants as participant
  where participant.household_id = p_household_id
    and participant.series_id = p_series_id;

  insert into public.event_participants (
    household_id,
    series_id,
    member_id
  )
  select p_household_id, p_series_id, participant_id
  from pg_catalog.unnest(v_participant_member_ids) as participant_id;

  update public.event_series as series
  set
    title = v_title,
    description = v_description,
    timezone = p_timezone,
    is_all_day = p_is_all_day,
    active_revision_id = v_revision_id
  where series.household_id = p_household_id
    and series.id = p_series_id
  returning series.version into v_result_version;

  v_materialized_through := v_effective_local_date + 365;
  if p_recurrence_rule->'end'->>'type' = 'until' then
    v_materialized_through := least(
      v_materialized_through,
      (p_recurrence_rule->'end'->>'localDate')::date
    );
  end if;

  perform 1
  from app_private.calendar_revision_candidate_dates(
    p_household_id,
    p_series_id,
    v_revision_id,
    v_effective_local_date,
    v_materialized_through
  ) as candidate
  limit 1;

  if not found then
    raise exception using
      errcode = 'KFE07',
      message = 'invalid calendar recurrence rule';
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

  begin
    v_rebuilt_count := app_private.materialize_calendar_revision_window(
      p_household_id,
      p_series_id,
      v_revision_id,
      v_effective_local_date,
      v_materialized_through
    );
  exception
    when sqlstate 'KFT01' then
      raise exception using
        errcode = 'KFE07',
        message = 'invalid calendar recurrence rule';
    when sqlstate 'KFT02' then
      raise exception using
        errcode = 'KFE06',
        message = 'nonexistent calendar local time';
  end;

  update public.event_occurrences as occurrence
  set status = 'cancelled'::public.occurrence_status
  where occurrence.household_id = p_household_id
    and occurrence.series_id = p_series_id
    and occurrence.recurrence_local_start_date >= v_effective_local_date
    and occurrence.recurrence_local_start_date <= v_materialized_through
    and occurrence.status <> 'cancelled'::public.occurrence_status
    and not exists (
      select 1
      from public.event_occurrence_exceptions as exception
      where exception.household_id = occurrence.household_id
        and exception.series_id = occurrence.series_id
        and exception.occurrence_id = occurrence.id
    )
    and not exists (
      select 1
      from app_private.calendar_revision_candidate_dates(
        p_household_id,
        p_series_id,
        v_revision_id,
        v_effective_local_date,
        v_materialized_through
      ) as candidate
      where candidate.recurrence_local_start_date =
        occurrence.recurrence_local_start_date
    );

  get diagnostics v_cancelled_count = row_count;

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
    v_revision_id,
    v_materialized_through,
    v_effective_local_date,
    v_materialized_through,
    pg_catalog.statement_timestamp() + interval '1 day',
    pg_catalog.statement_timestamp(),
    pg_catalog.statement_timestamp(),
    'succeeded',
    null,
    v_rebuilt_count,
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

  select occurrence.id, occurrence.version
  into v_audit_occurrence_id, v_audit_occurrence_version
  from public.event_occurrences as occurrence
  where occurrence.household_id = p_household_id
    and occurrence.series_id = p_series_id
  order by occurrence.recurrence_local_start_date, occurrence.id
  limit 1;

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
    'updated',
    v_previous_revision_id,
    v_revision_id,
    v_effective_local_date,
    v_materialized_through,
    v_authenticated_user_id,
    v_actor_member_id,
    v_rebuilt_count,
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
    'updated',
    p_household_id,
    p_series_id,
    v_revision_id,
    v_revision_number,
    v_effective_local_date,
    v_materialized_through,
    v_result_version,
    v_rebuilt_count,
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
    'calendar.series_updated',
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
    v_revision_id,
    v_revision_number,
    v_effective_local_date,
    v_materialized_through,
    v_result_version,
    v_rebuilt_count,
    v_cancelled_count,
    v_preserved_exception_count,
    true;
end;
$$;

revoke all on function app_private.update_recurring_calendar_series_at_boundary(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint,
  text,
  text,
  boolean,
  date,
  time without time zone,
  integer,
  date,
  text,
  text,
  jsonb,
  uuid[]
) from public, anon, authenticated, service_role;

create or replace function public.update_recurring_calendar_series(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_expected_version bigint,
  p_title text,
  p_description text,
  p_is_all_day boolean,
  p_local_start_date date,
  p_local_start_time time without time zone,
  p_duration_minutes integer,
  p_all_day_end_date_exclusive date,
  p_timezone text,
  p_overlap_policy text,
  p_recurrence_rule jsonb,
  p_participant_member_ids uuid[]
)
returns table (
  household_id uuid,
  household_timezone text,
  household_local_date date,
  series_id uuid,
  revision_id uuid,
  revision_number integer,
  effective_local_date date,
  materialized_through date,
  version bigint,
  rebuilt_count integer,
  cancelled_count integer,
  preserved_exception_count integer,
  changed boolean
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  select *
  from app_private.update_recurring_calendar_series_at_boundary(
      p_idempotency_key,
    p_household_id,
    p_series_id,
    null,
    p_expected_version,
    p_title,
    p_description,
    p_is_all_day,
    p_local_start_date,
    p_local_start_time,
    p_duration_minutes,
    p_all_day_end_date_exclusive,
    p_timezone,
    p_overlap_policy,
    p_recurrence_rule,
    p_participant_member_ids
  );
end;
$$;

create function public.update_recurring_calendar_series_from_occurrence(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_effective_occurrence_id uuid,
  p_expected_version bigint,
  p_title text,
  p_description text,
  p_is_all_day boolean,
  p_local_start_date date,
  p_local_start_time time without time zone,
  p_duration_minutes integer,
  p_all_day_end_date_exclusive date,
  p_timezone text,
  p_overlap_policy text,
  p_recurrence_rule jsonb,
  p_participant_member_ids uuid[]
)
returns table (
  household_id uuid,
  household_timezone text,
  household_local_date date,
  series_id uuid,
  revision_id uuid,
  revision_number integer,
  effective_local_date date,
  materialized_through date,
  version bigint,
  rebuilt_count integer,
  cancelled_count integer,
  preserved_exception_count integer,
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
  from app_private.update_recurring_calendar_series_at_boundary(
      p_idempotency_key,
    p_household_id,
    p_series_id,
    p_effective_occurrence_id,
    p_expected_version,
    p_title,
    p_description,
    p_is_all_day,
    p_local_start_date,
    p_local_start_time,
    p_duration_minutes,
    p_all_day_end_date_exclusive,
    p_timezone,
    p_overlap_policy,
    p_recurrence_rule,
    p_participant_member_ids
  );
end;
$$;

revoke all on function public.update_recurring_calendar_series(
  uuid,
  uuid,
  uuid,
  bigint,
  text,
  text,
  boolean,
  date,
  time without time zone,
  integer,
  date,
  text,
  text,
  jsonb,
  uuid[]
) from public, anon, authenticated;

grant execute on function public.update_recurring_calendar_series(
  uuid,
  uuid,
  uuid,
  bigint,
  text,
  text,
  boolean,
  date,
  time without time zone,
  integer,
  date,
  text,
  text,
  jsonb,
  uuid[]
) to authenticated;
revoke all on function public.update_recurring_calendar_series_from_occurrence(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint,
  text,
  text,
  boolean,
  date,
  time without time zone,
  integer,
  date,
  text,
  text,
  jsonb,
  uuid[]
) from public, anon, authenticated;

grant execute on function public.update_recurring_calendar_series_from_occurrence(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint,
  text,
  text,
  boolean,
  date,
  time without time zone,
  integer,
  date,
  text,
  text,
  jsonb,
  uuid[]
) to authenticated;
