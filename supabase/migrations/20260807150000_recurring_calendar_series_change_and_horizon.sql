-- KinFlow WP04-04C whole recurring Calendar series change/termination and
-- exception-aware rolling horizon repair.

create extension if not exists pg_cron;

alter table public.event_series
  add column ended_at timestamptz,
  add column ended_effective_local_date date,
  add constraint event_series_end_shape_ck check (
    (ended_at is null and ended_effective_local_date is null)
    or (ended_at is not null and ended_effective_local_date is not null)
  );

create index event_series_calendar_horizon_idx
  on public.event_series(household_id, active_revision_id, id)
  where deleted_at is null and ended_at is null;

alter table app_private.calendar_audit_events
  drop constraint calendar_audit_events_action_check;

alter table app_private.calendar_audit_events
  add constraint calendar_audit_events_action_check check (
    action in (
      'calendar.created',
      'calendar.updated',
      'calendar.deleted',
      'calendar.occurrence_updated',
      'calendar.occurrence_cancelled',
      'calendar.series_updated',
      'calendar.series_cancelled'
    )
  );

-- Candidate generation remains anchored to the immutable revision start date,
-- but rolling callers may request later bounded windows.
create or replace function app_private.calendar_revision_candidate_dates(
  p_household_id uuid,
  p_series_id uuid,
  p_revision_id uuid,
  p_window_start date,
  p_window_end date
)
returns table (recurrence_local_start_date date)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_start_date date;
  v_rule jsonb;
  v_frequency text;
  v_interval integer;
  v_weekdays text[];
  v_month_day integer;
  v_end_type text;
  v_end_count integer;
  v_end_until date;
  v_effective_end date;
begin
  if p_household_id is null
    or p_series_id is null
    or p_revision_id is null
    or p_window_start is null
    or p_window_end is null
    or p_window_end < p_window_start
    or p_window_end - p_window_start > 396 then
    raise exception using
      errcode = 'KFE07',
      message = 'invalid calendar recurrence rule';
  end if;

  select revision.local_start_date, revision.recurrence_rule
  into v_start_date, v_rule
  from public.event_series as series
  join public.event_series_revisions as revision
    on revision.household_id = series.household_id
   and revision.series_id = series.id
   and revision.id = p_revision_id
  where series.household_id = p_household_id
    and series.id = p_series_id
    and series.active_revision_id = p_revision_id
    and series.deleted_at is null
    and series.ended_at is null;

  if not found
    or v_rule is null
    or not app_private.is_valid_calendar_recurrence_rule(v_rule) then
    raise exception using
      errcode = 'KFE07',
      message = 'invalid calendar recurrence rule';
  end if;

  v_frequency := v_rule->>'frequency';
  v_interval := (v_rule->>'interval')::integer;
  v_month_day := nullif(v_rule->>'monthDay', '')::integer;
  v_end_type := v_rule->'end'->>'type';
  v_end_count := nullif(v_rule->'end'->>'count', '')::integer;
  v_end_until := nullif(v_rule->'end'->>'localDate', '')::date;
  if v_frequency = 'weekly' then
    select pg_catalog.array_agg(weekday.value order by weekday.ordinality)
    into v_weekdays
    from pg_catalog.jsonb_array_elements_text(v_rule->'weekdays')
      with ordinality as weekday(value, ordinality);
  end if;

  v_effective_end := p_window_end;
  if v_end_type = 'until' then
    v_effective_end := least(v_effective_end, v_end_until);
  end if;
  if v_effective_end < v_start_date then
    return;
  end if;

  return query
  with candidate_dates as materialized (
    select generated.local_date::date as local_date
    from pg_catalog.generate_series(
      v_start_date::timestamp without time zone,
      v_effective_end::timestamp without time zone,
      interval '1 day'
    ) as generated(local_date)
  ),
  matched_dates as materialized (
    select candidate.local_date
    from candidate_dates as candidate
    where case v_frequency
      when 'daily' then
        (candidate.local_date - v_start_date) % v_interval = 0
      when 'weekly' then
        (
          (
            candidate.local_date
            - (
              v_start_date
              - (extract(isodow from v_start_date)::integer - 1)
            )
          ) / 7
        ) % v_interval = 0
        and (
          array['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU']
        )[extract(isodow from candidate.local_date)::integer] = any(v_weekdays)
      when 'monthly' then
        extract(day from candidate.local_date)::integer = v_month_day
        and (
          (
            extract(year from candidate.local_date)::integer
            - extract(year from v_start_date)::integer
          ) * 12
          + extract(month from candidate.local_date)::integer
          - extract(month from v_start_date)::integer
        ) % v_interval = 0
      else false
    end
  ),
  numbered_dates as materialized (
    select
      matched.local_date,
      pg_catalog.row_number() over (order by matched.local_date)
        as occurrence_number
    from matched_dates as matched
  )
  select numbered.local_date
  from numbered_dates as numbered
  where numbered.local_date >= greatest(p_window_start, v_start_date)
    and (
      v_end_type <> 'count'
      or numbered.occurrence_number <= v_end_count
    )
  order by numbered.local_date;
end;
$$;

revoke all on function app_private.calendar_revision_candidate_dates(
  uuid,
  uuid,
  uuid,
  date,
  date
) from public, anon, authenticated, service_role;

-- Replays are no-ops when the projection already matches. Conflict updates are
-- restricted to non-exception rows so user overrides and cancellations survive
-- series regeneration and worker repair.
create or replace function app_private.materialize_calendar_revision_window(
  p_household_id uuid,
  p_series_id uuid,
  p_revision_id uuid,
  p_window_start date,
  p_window_end date
)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_is_all_day boolean;
  v_timezone text;
  v_local_start_time time without time zone;
  v_duration_minutes integer;
  v_overlap_policy text;
  v_all_day_span integer;
  v_changed_count integer := 0;
begin
  select
    revision.snapshot_is_all_day,
    revision.snapshot_timezone,
    revision.local_start_time,
    revision.duration_minutes,
    revision.overlap_policy,
    revision.all_day_end_date_exclusive - revision.local_start_date
  into
    v_is_all_day,
    v_timezone,
    v_local_start_time,
    v_duration_minutes,
    v_overlap_policy,
    v_all_day_span
  from public.event_series as series
  join public.event_series_revisions as revision
    on revision.household_id = series.household_id
   and revision.series_id = series.id
   and revision.id = p_revision_id
  where series.household_id = p_household_id
    and series.id = p_series_id
    and series.active_revision_id = p_revision_id
    and series.deleted_at is null
    and series.ended_at is null
    and revision.recurrence_rule is not null;

  if not found then
    raise exception using
      errcode = 'KFE07',
      message = 'invalid calendar recurrence rule';
  end if;

  if v_is_all_day then
    insert into public.event_occurrences as existing (
      id,
      household_id,
      series_id,
      revision_id,
      occurrence_key,
      recurrence_local_start_date,
      local_start_date,
      starts_at,
      ends_at,
      all_day_end_date_exclusive,
      timezone,
      status,
      dst_adjustment
    )
    select
      extensions.gen_random_uuid(),
      p_household_id,
      p_series_id,
      p_revision_id,
      p_series_id::text || ':' || candidate.recurrence_local_start_date::text,
      candidate.recurrence_local_start_date,
      candidate.recurrence_local_start_date,
      null,
      null,
      candidate.recurrence_local_start_date + v_all_day_span,
      null,
      'scheduled'::public.occurrence_status,
      null
    from app_private.calendar_revision_candidate_dates(
      p_household_id,
      p_series_id,
      p_revision_id,
      p_window_start,
      p_window_end
    ) as candidate
    on conflict (household_id, occurrence_key) do update
    set
      revision_id = excluded.revision_id,
      local_start_date = excluded.local_start_date,
      starts_at = null,
      ends_at = null,
      all_day_end_date_exclusive = excluded.all_day_end_date_exclusive,
      timezone = null,
      status = 'scheduled'::public.occurrence_status,
      dst_adjustment = null
    where existing.series_id = excluded.series_id
      and existing.recurrence_local_start_date =
        excluded.recurrence_local_start_date
      and not exists (
        select 1
        from public.event_occurrence_exceptions as exception
        where exception.household_id = existing.household_id
          and exception.series_id = existing.series_id
          and exception.occurrence_id = existing.id
      )
      and (
        existing.revision_id,
        existing.local_start_date,
        existing.starts_at,
        existing.ends_at,
        existing.all_day_end_date_exclusive,
        existing.timezone,
        existing.status,
        existing.dst_adjustment
      ) is distinct from (
        excluded.revision_id,
        excluded.local_start_date,
        null::timestamptz,
        null::timestamptz,
        excluded.all_day_end_date_exclusive,
        null::text,
        'scheduled'::public.occurrence_status,
        null::jsonb
      );

    get diagnostics v_changed_count = row_count;
    return v_changed_count;
  end if;

  insert into public.event_occurrences as existing (
    id,
    household_id,
    series_id,
    revision_id,
    occurrence_key,
    recurrence_local_start_date,
    local_start_date,
    starts_at,
    ends_at,
    all_day_end_date_exclusive,
    timezone,
    status,
    dst_adjustment
  )
  select
    extensions.gen_random_uuid(),
    p_household_id,
    p_series_id,
    p_revision_id,
    p_series_id::text || ':' || candidate.recurrence_local_start_date::text,
    candidate.recurrence_local_start_date,
    candidate.recurrence_local_start_date,
    resolved.resolved_at,
    resolved.resolved_at
      + pg_catalog.make_interval(mins => v_duration_minutes),
    null,
    v_timezone,
    'scheduled'::public.occurrence_status,
    pg_catalog.jsonb_build_object(
      'candidateCount', resolved.candidate_count,
      'gapPolicy', 'reject',
      'overlapPolicy', v_overlap_policy,
      'resolution', resolved.resolution,
      'utcOffsetSeconds', resolved.utc_offset_seconds
    )
  from app_private.calendar_revision_candidate_dates(
    p_household_id,
    p_series_id,
    p_revision_id,
    p_window_start,
    p_window_end
  ) as candidate
  cross join lateral app_private.resolve_calendar_zoned_datetime(
    candidate.recurrence_local_start_date,
    v_local_start_time,
    v_timezone,
    v_overlap_policy
  ) as resolved
  on conflict (household_id, occurrence_key) do update
  set
    revision_id = excluded.revision_id,
    local_start_date = excluded.local_start_date,
    starts_at = excluded.starts_at,
    ends_at = excluded.ends_at,
    all_day_end_date_exclusive = null,
    timezone = excluded.timezone,
    status = 'scheduled'::public.occurrence_status,
    dst_adjustment = excluded.dst_adjustment
  where existing.series_id = excluded.series_id
    and existing.recurrence_local_start_date =
      excluded.recurrence_local_start_date
    and not exists (
      select 1
      from public.event_occurrence_exceptions as exception
      where exception.household_id = existing.household_id
        and exception.series_id = existing.series_id
        and exception.occurrence_id = existing.id
    )
    and (
      existing.revision_id,
      existing.local_start_date,
      existing.starts_at,
      existing.ends_at,
      existing.all_day_end_date_exclusive,
      existing.timezone,
      existing.status,
      existing.dst_adjustment
    ) is distinct from (
      excluded.revision_id,
      excluded.local_start_date,
      excluded.starts_at,
      excluded.ends_at,
      null::date,
      excluded.timezone,
      'scheduled'::public.occurrence_status,
      excluded.dst_adjustment
    );

  get diagnostics v_changed_count = row_count;
  return v_changed_count;
end;
$$;

revoke all on function app_private.materialize_calendar_revision_window(
  uuid,
  uuid,
  uuid,
  date,
  date
) from public, anon, authenticated, service_role;

create table public.event_series_change_events (
  id uuid primary key default extensions.gen_random_uuid(),
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
  preserved_exception_count integer not null check (
    preserved_exception_count >= 0
  ),
  preserved_past_count integer not null check (preserved_past_count >= 0),
  series_version bigint not null check (series_version > 0),
  correlation_id uuid not null,
  occurred_at timestamptz not null default pg_catalog.now(),
  unique (household_id, id),
  unique (actor_user_id, correlation_id),
  constraint event_series_change_event_revision_shape_ck check (
    (
      operation = 'updated'
      and new_revision_id is not null
      and materialized_through is not null
    )
    or (
      operation = 'cancelled'
      and new_revision_id is null
      and materialized_through is null
    )
  ),
  constraint event_series_change_event_series_fk
    foreign key (household_id, series_id)
    references public.event_series(household_id, id)
    on delete cascade,
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

create index event_series_change_events_series_time_idx
  on public.event_series_change_events(
    household_id,
    series_id,
    occurred_at desc
  );

create or replace function app_private.reject_event_series_change_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'calendar series change events are immutable';
end;
$$;

revoke all on function app_private.reject_event_series_change_mutation()
  from public, anon, authenticated, service_role;

create trigger event_series_change_events_immutable
before update or delete on public.event_series_change_events
for each row execute function
  app_private.reject_event_series_change_mutation();

alter table public.event_series_change_events enable row level security;
alter table public.event_series_change_events force row level security;

create policy event_series_change_events_select_member
on public.event_series_change_events
for select
to authenticated
using (app_private.is_active_household_member(household_id));

revoke all on table public.event_series_change_events
  from anon, authenticated;
grant select on table public.event_series_change_events to authenticated;

create table app_private.calendar_series_change_command_requests (
  authenticated_user_id uuid not null
    references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  request_hash bytea not null check (pg_catalog.octet_length(request_hash) = 32),
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
  result_preserved_exception_count integer not null check (
    result_preserved_exception_count >= 0
  ),
  result_preserved_past_count integer not null check (
    result_preserved_past_count >= 0
  ),
  result_event_id uuid not null,
  created_at timestamptz not null default pg_catalog.now(),
  primary key (authenticated_user_id, idempotency_key),
  constraint calendar_series_change_request_revision_shape_ck check (
    (
      operation = 'updated'
      and result_revision_id is not null
      and result_revision_number is not null
      and result_revision_number > 0
      and result_materialized_through is not null
    )
    or (
      operation = 'cancelled'
      and result_revision_id is null
      and result_revision_number is null
      and result_materialized_through is null
    )
  ),
  constraint calendar_series_change_request_series_fk
    foreign key (household_id, series_id)
    references public.event_series(household_id, id)
    on delete cascade,
  constraint calendar_series_change_request_revision_fk
    foreign key (household_id, series_id, result_revision_id)
    references public.event_series_revisions(household_id, series_id, id),
  constraint calendar_series_change_request_event_fk
    foreign key (household_id, result_event_id)
    references public.event_series_change_events(household_id, id)
    on delete cascade
);

revoke all on table app_private.calendar_series_change_command_requests
  from public, anon, authenticated, service_role;

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
  updated_at timestamptz not null default pg_catalog.now(),
  primary key (household_id, series_id),
  constraint calendar_materialization_state_series_fk
    foreign key (household_id, series_id)
    references public.event_series(household_id, id)
    on delete cascade,
  constraint calendar_materialization_state_revision_fk
    foreign key (household_id, series_id, revision_id)
    references public.event_series_revisions(household_id, series_id, id),
  constraint calendar_materialization_state_window_ck check (
    last_target_date >= last_window_start
  ),
  constraint calendar_materialization_state_result_ck check (
    (
      last_result = 'succeeded'
      and last_error_code is null
      and covered_through is not null
      and last_succeeded_at is not null
    )
    or (
      last_result = 'failed'
      and last_error_code in (
        'invalid_recurrence',
        'nonexistent_local_time',
        'materialization_failed'
      )
    )
  )
);

create index calendar_materialization_states_due_idx
  on app_private.calendar_materialization_states(
    next_repair_at,
    covered_through,
    series_id
  );

create table app_private.calendar_materialization_runs (
  id uuid primary key default extensions.gen_random_uuid(),
  invoked_at timestamptz not null default pg_catalog.now(),
  as_of timestamptz not null,
  horizon_days integer not null check (horizon_days between 30 and 365),
  repair_lookback_days integer not null check (
    repair_lookback_days between 0 and 31
  ),
  batch_size integer not null check (batch_size between 1 and 500),
  target_series_id uuid,
  claimed_count integer not null check (claimed_count >= 0),
  succeeded_count integer not null check (succeeded_count >= 0),
  failed_count integer not null check (failed_count >= 0),
  changed_count integer not null check (changed_count >= 0),
  batch_exhausted boolean not null,
  completed_at timestamptz not null,
  constraint calendar_materialization_run_counts_ck check (
    claimed_count = succeeded_count + failed_count
    and claimed_count <= batch_size
  )
);

revoke all on table app_private.calendar_materialization_states
  from public, anon, authenticated, service_role;
revoke all on table app_private.calendar_materialization_runs
  from public, anon, authenticated, service_role;

create or replace function app_private.reject_calendar_materialization_run_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'calendar materialization runs are immutable';
end;
$$;

revoke all on function
  app_private.reject_calendar_materialization_run_mutation()
  from public, anon, authenticated, service_role;

create trigger calendar_materialization_runs_immutable
before update or delete on app_private.calendar_materialization_runs
for each row execute function
  app_private.reject_calendar_materialization_run_mutation();

create or replace function public.get_recurring_calendar_series(
  p_household_id uuid,
  p_series_id uuid
)
returns table (
  household_id uuid,
  household_timezone text,
  household_local_date date,
  series_id uuid,
  revision_id uuid,
  revision_number integer,
  title text,
  description text,
  is_all_day boolean,
  local_start_date date,
  local_start_time time without time zone,
  duration_minutes integer,
  all_day_end_date_exclusive date,
  timezone text,
  overlap_policy text,
  recurrence_rule jsonb,
  participant_member_ids uuid[],
  participant_display_names text[],
  version bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFE01',
      message = 'authentication required';
  end if;

  if p_household_id is null or p_series_id is null then
    raise exception using
      errcode = 'KFE02',
      message = 'invalid calendar event input';
  end if;

  return query
  select
    household.id,
    household.timezone,
    (pg_catalog.statement_timestamp() at time zone household.timezone)::date,
    series.id,
    revision.id,
    revision.revision_number,
    revision.snapshot_title,
    revision.snapshot_description,
    revision.snapshot_is_all_day,
    revision.local_start_date,
    revision.local_start_time,
    revision.duration_minutes,
    revision.all_day_end_date_exclusive,
    revision.snapshot_timezone,
    revision.overlap_policy,
    revision.recurrence_rule,
    participants.member_ids,
    participants.display_names,
    series.version
  from public.households as household
  join public.household_members as caller
    on caller.household_id = household.id
   and caller.auth_user_id = v_authenticated_user_id
   and caller.removed_at is null
  join public.event_series as series
    on series.household_id = household.id
   and series.id = p_series_id
   and series.deleted_at is null
   and series.ended_at is null
  join public.event_series_revisions as revision
    on revision.household_id = series.household_id
   and revision.series_id = series.id
   and revision.id = series.active_revision_id
   and revision.recurrence_rule is not null
  cross join lateral (
    select
      pg_catalog.array_agg(participant.member_id order by participant.member_id)
        as member_ids,
      pg_catalog.array_agg(member.display_name order by participant.member_id)
        as display_names
    from public.event_revision_participants as participant
    join public.household_members as member
      on member.household_id = participant.household_id
     and member.id = participant.member_id
    where participant.household_id = revision.household_id
      and participant.series_id = revision.series_id
      and participant.revision_id = revision.id
  ) as participants
  where household.id = p_household_id
    and household.deleted_at is null;

  if not found then
    raise exception using
      errcode = 'KFE03',
      message = 'calendar event not found or forbidden';
  end if;
end;
$$;

revoke all on function public.get_recurring_calendar_series(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.get_recurring_calendar_series(uuid, uuid)
  to authenticated;

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
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_actor_member_id uuid;
  v_title text := pg_catalog.btrim(p_title);
  v_description text := nullif(pg_catalog.btrim(p_description), '');
  v_household_timezone text;
  v_household_local_date date;
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
  if p_recurrence_rule->'end'->>'type' = 'until'
    and (p_recurrence_rule->'end'->>'localDate')::date
      < v_household_local_date then
    raise exception using
      errcode = 'KFE07',
      message = 'invalid calendar recurrence rule';
  end if;

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
      v_replay_effective_local_date,
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

  v_materialized_through := v_household_local_date + 365;
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
    v_household_local_date,
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
    and occurrence.recurrence_local_start_date < v_household_local_date;

  select pg_catalog.count(*)::integer
  into v_preserved_exception_count
  from public.event_occurrence_exceptions as exception
  join public.event_occurrences as occurrence
    on occurrence.household_id = exception.household_id
   and occurrence.series_id = exception.series_id
   and occurrence.id = exception.occurrence_id
  where exception.household_id = p_household_id
    and exception.series_id = p_series_id
    and occurrence.recurrence_local_start_date >= v_household_local_date;

  begin
    v_rebuilt_count := app_private.materialize_calendar_revision_window(
      p_household_id,
      p_series_id,
      v_revision_id,
      v_household_local_date,
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
    and occurrence.recurrence_local_start_date >= v_household_local_date
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
        v_household_local_date,
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
    v_household_local_date,
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
    v_household_local_date,
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
    v_household_local_date,
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
    v_household_local_date,
    v_materialized_through,
    v_result_version,
    v_rebuilt_count,
    v_cancelled_count,
    v_preserved_exception_count,
    true;
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
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_actor_member_id uuid;
  v_household_timezone text;
  v_household_local_date date;
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
      pg_catalog.jsonb_build_object(
        'command', 'cancel_recurring_calendar_series',
        'household_id', p_household_id,
        'series_id', p_series_id,
        'expected_version', p_expected_version
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
    request.result_preserved_past_count
  into
    v_existing_request_hash,
    v_replay_effective_local_date,
    v_result_version,
    v_cancelled_count,
    v_preserved_past_count
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
      v_replay_effective_local_date,
      p_series_id,
      v_replay_effective_local_date,
      v_result_version,
      v_cancelled_count,
      v_preserved_past_count,
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

  select pg_catalog.count(*)::integer
  into v_preserved_past_count
  from public.event_occurrences as occurrence
  where occurrence.household_id = p_household_id
    and occurrence.series_id = p_series_id
    and occurrence.recurrence_local_start_date < v_household_local_date;

  select pg_catalog.count(*)::integer
  into v_preserved_exception_count
  from public.event_occurrence_exceptions as exception
  join public.event_occurrences as occurrence
    on occurrence.household_id = exception.household_id
   and occurrence.series_id = exception.series_id
   and occurrence.id = exception.occurrence_id
  where exception.household_id = p_household_id
    and exception.series_id = p_series_id
    and occurrence.recurrence_local_start_date >= v_household_local_date;

  update public.event_occurrences as occurrence
  set status = 'cancelled'::public.occurrence_status
  where occurrence.household_id = p_household_id
    and occurrence.series_id = p_series_id
    and occurrence.recurrence_local_start_date >= v_household_local_date
    and occurrence.status <> 'cancelled'::public.occurrence_status;

  get diagnostics v_cancelled_count = row_count;

  update public.event_series as series
  set
    ended_at = pg_catalog.statement_timestamp(),
    ended_effective_local_date = v_household_local_date
  where series.household_id = p_household_id
    and series.id = p_series_id
  returning series.version into v_result_version;

  delete from app_private.calendar_materialization_states as state
  where state.household_id = p_household_id
    and state.series_id = p_series_id;

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
    'cancelled',
    v_previous_revision_id,
    null,
    v_household_local_date,
    null,
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
    null,
    null,
    v_household_local_date,
    null,
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
    v_household_local_date,
    v_result_version,
    v_cancelled_count,
    v_preserved_past_count,
    true;
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

create or replace function public.run_calendar_horizon_worker(
  p_as_of timestamptz,
  p_horizon_days integer,
  p_repair_lookback_days integer,
  p_batch_size integer,
  p_target_series_id uuid
)
returns table (
  run_id uuid,
  claimed_count integer,
  succeeded_count integer,
  failed_count integer,
  changed_count integer,
  batch_exhausted boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item record;
  v_run_id uuid := extensions.gen_random_uuid();
  v_claimed_count integer := 0;
  v_succeeded_count integer := 0;
  v_failed_count integer := 0;
  v_changed_count integer := 0;
  v_item_changed_count integer;
  v_error_code text;
  v_series_complete boolean;
  v_next_repair_at timestamptz;
  v_batch_exhausted boolean;
begin
  if p_as_of is null
    or p_horizon_days is null
    or p_horizon_days not between 30 and 365
    or p_repair_lookback_days is null
    or p_repair_lookback_days not between 0 and 31
    or p_batch_size is null
    or p_batch_size not between 1 and 500 then
    raise exception using
      errcode = 'KFW01',
      message = 'invalid calendar horizon worker input';
  end if;

  for v_item in
    select
      series.household_id,
      series.id as series_id,
      revision.id as revision_id,
      revision.local_start_date,
      revision.recurrence_rule,
      state.revision_id as state_revision_id,
      state.covered_through as state_covered_through,
      state.next_repair_at as state_next_repair_at,
      local_clock.local_date,
      greatest(
        revision.local_start_date,
        local_clock.local_date - p_repair_lookback_days
      ) as window_start,
      horizon.target_date
    from public.event_series as series
    join public.households as household
      on household.id = series.household_id
     and household.deleted_at is null
    join public.event_series_revisions as revision
      on revision.household_id = series.household_id
     and revision.series_id = series.id
     and revision.id = series.active_revision_id
    left join app_private.calendar_materialization_states as state
      on state.household_id = series.household_id
     and state.series_id = series.id
    cross join lateral (
      select (
        p_as_of at time zone case
          when revision.snapshot_is_all_day then household.timezone
          else revision.snapshot_timezone
        end
      )::date as local_date
    ) as local_clock
    cross join lateral (
      select case
        when revision.recurrence_rule->'end'->>'type' = 'until' then least(
          local_clock.local_date + p_horizon_days,
          (revision.recurrence_rule->'end'->>'localDate')::date
        )
        else local_clock.local_date + p_horizon_days
      end as target_date
    ) as horizon
    where series.deleted_at is null
      and series.ended_at is null
      and revision.recurrence_rule is not null
      and revision.local_start_date <= horizon.target_date
      and (
        (
          p_target_series_id is not null
          and series.id = p_target_series_id
        )
        or (
          p_target_series_id is null
          and (
            state.series_id is null
            or state.revision_id is distinct from revision.id
            or (
              state.next_repair_at <> 'infinity'::timestamptz
              and (
                state.covered_through is null
                or state.covered_through < horizon.target_date
                or state.next_repair_at <= p_as_of
              )
            )
          )
        )
      )
    order by
      case
        when state.series_id is null
          or state.revision_id is distinct from revision.id then 0
        when state.covered_through is null
          or state.covered_through < horizon.target_date then 1
        else 2
      end,
      state.next_repair_at nulls first,
      series.id
    for update of series skip locked
    limit case
      when p_target_series_id is null then p_batch_size
      else 1
    end
  loop
    v_claimed_count := v_claimed_count + 1;
    v_item_changed_count := 0;
    v_error_code := null;
    v_series_complete := false;

    begin
      if v_item.target_date >= v_item.window_start then
        v_item_changed_count :=
          app_private.materialize_calendar_revision_window(
            v_item.household_id,
            v_item.series_id,
            v_item.revision_id,
            v_item.window_start,
            v_item.target_date
          );
      end if;

      if v_item.recurrence_rule->'end'->>'type' = 'until'
        and v_item.target_date = (
          v_item.recurrence_rule->'end'->>'localDate'
        )::date then
        v_series_complete := true;
      end if;
    exception
      when sqlstate 'KFE07' or sqlstate 'KFT01' then
        v_error_code := 'invalid_recurrence';
      when sqlstate 'KFT02' then
        v_error_code := 'nonexistent_local_time';
      when others then
        v_error_code := 'materialization_failed';
    end;

    if v_error_code is null then
      v_succeeded_count := v_succeeded_count + 1;
      v_changed_count := v_changed_count + v_item_changed_count;
      v_next_repair_at := case
        when v_series_complete then 'infinity'::timestamptz
        else p_as_of + interval '1 day'
      end;

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
        v_item.household_id,
        v_item.series_id,
        v_item.revision_id,
        v_item.target_date,
        least(v_item.window_start, v_item.target_date),
        v_item.target_date,
        v_next_repair_at,
        p_as_of,
        p_as_of,
        'succeeded',
        null,
        v_item_changed_count,
        1,
        p_as_of
      )
      on conflict on constraint calendar_materialization_states_pkey do update
      set
        revision_id = excluded.revision_id,
        covered_through = case
          when calendar_materialization_states.revision_id =
            excluded.revision_id then greatest(
              calendar_materialization_states.covered_through,
              excluded.covered_through
            )
          else excluded.covered_through
        end,
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
      v_failed_count := v_failed_count + 1;

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
        v_item.household_id,
        v_item.series_id,
        v_item.revision_id,
        null,
        least(v_item.window_start, v_item.target_date),
        v_item.target_date,
        p_as_of + interval '1 hour',
        p_as_of,
        null,
        'failed',
        v_error_code,
        0,
        1,
        p_as_of
      )
      on conflict on constraint calendar_materialization_states_pkey do update
      set
        revision_id = excluded.revision_id,
        covered_through = case
          when calendar_materialization_states.revision_id =
            excluded.revision_id
            then calendar_materialization_states.covered_through
          else null
        end,
        last_window_start = excluded.last_window_start,
        last_target_date = excluded.last_target_date,
        next_repair_at = excluded.next_repair_at,
        last_attempted_at = excluded.last_attempted_at,
        last_result = excluded.last_result,
        last_error_code = excluded.last_error_code,
        last_changed_count = excluded.last_changed_count,
        attempt_count = calendar_materialization_states.attempt_count + 1,
        updated_at = excluded.updated_at;
    end if;
  end loop;

  v_batch_exhausted := p_target_series_id is null
    and v_claimed_count = p_batch_size;

  insert into app_private.calendar_materialization_runs (
    id,
    as_of,
    horizon_days,
    repair_lookback_days,
    batch_size,
    target_series_id,
    claimed_count,
    succeeded_count,
    failed_count,
    changed_count,
    batch_exhausted,
    completed_at
  ) values (
    v_run_id,
    p_as_of,
    p_horizon_days,
    p_repair_lookback_days,
    p_batch_size,
    p_target_series_id,
    v_claimed_count,
    v_succeeded_count,
    v_failed_count,
    v_changed_count,
    v_batch_exhausted,
    pg_catalog.statement_timestamp()
  );

  return query select
    v_run_id,
    v_claimed_count,
    v_succeeded_count,
    v_failed_count,
    v_changed_count,
    v_batch_exhausted;
end;
$$;

revoke all on function public.run_calendar_horizon_worker(
  timestamptz,
  integer,
  integer,
  integer,
  uuid
) from public, anon, authenticated, service_role;

grant execute on function public.run_calendar_horizon_worker(
  timestamptz,
  integer,
  integer,
  integer,
  uuid
) to service_role;

revoke all privileges on schema cron
  from public, anon, authenticated, service_role;
revoke all privileges on all tables in schema cron
  from public, anon, authenticated, service_role;
revoke all privileges on all functions in schema cron
  from public, anon, authenticated, service_role;

select cron.schedule(
  'kinflow-calendar-horizon-v1',
  '29 * * * *',
  $cron$
    select *
    from public.run_calendar_horizon_worker(
      pg_catalog.statement_timestamp(),
      365,
      7,
      100,
      null
    );
  $cron$
);
