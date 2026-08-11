-- KinFlow WP03-05F recurrence horizon extension and repair worker.
-- Store MVP scope: bounded server-side windows, service-role execution,
-- and an hourly pg_cron trigger with per-series daily eligibility.

create extension if not exists pg_cron;

revoke all privileges on schema cron
  from public, anon, authenticated, service_role;
revoke all privileges on all tables in schema cron
  from public, anon, authenticated, service_role;
revoke all privileges on all functions in schema cron
  from public, anon, authenticated, service_role;

create table app_private.chore_materialization_states (
  household_id uuid not null,
  series_id uuid not null,
  revision_id uuid not null,
  covered_through date,
  last_window_start date not null,
  last_target_date date not null,
  next_repair_at timestamptz not null,
  last_attempted_at timestamptz not null,
  last_succeeded_at timestamptz,
  last_result text not null check (
    last_result in ('succeeded', 'failed')
  ),
  last_error_code text,
  last_inserted_count integer not null check (
    last_inserted_count >= 0
  ),
  attempt_count bigint not null default 1 check (attempt_count > 0),
  updated_at timestamptz not null default now(),
  primary key (household_id, series_id),
  constraint chore_materialization_state_series_fk
    foreign key (household_id, series_id)
    references public.chore_series(household_id, id)
    on delete cascade,
  constraint chore_materialization_state_revision_fk
    foreign key (household_id, revision_id)
    references public.chore_series_revisions(household_id, id),
  constraint chore_materialization_state_window_ck check (
    last_target_date >= last_window_start
  ),
  constraint chore_materialization_state_result_ck check (
    (
      last_result = 'succeeded'
      and last_error_code is null
      and covered_through is not null
      and last_succeeded_at is not null
    )
    or (
      last_result = 'failed'
      and last_error_code in (
        'assignee_unavailable',
        'invalid_recurrence',
        'materialization_failed'
      )
    )
  )
);

create index chore_materialization_states_due_idx
  on app_private.chore_materialization_states(
    next_repair_at,
    covered_through,
    series_id
  );

create table app_private.chore_materialization_runs (
  id uuid primary key default extensions.gen_random_uuid(),
  invoked_at timestamptz not null default now(),
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
  inserted_count integer not null check (inserted_count >= 0),
  batch_exhausted boolean not null,
  completed_at timestamptz not null,
  constraint chore_materialization_run_counts_ck check (
    claimed_count = succeeded_count + failed_count
    and claimed_count <= batch_size
  )
);

revoke all on table app_private.chore_materialization_states
  from public, anon, authenticated, service_role;
revoke all on table app_private.chore_materialization_runs
  from public, anon, authenticated, service_role;

create or replace function app_private.reject_chore_materialization_run_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'chore materialization runs are immutable';
end;
$$;

revoke all on function app_private.reject_chore_materialization_run_mutation()
  from public, anon, authenticated, service_role;

create trigger chore_materialization_runs_immutable
before update or delete on app_private.chore_materialization_runs
for each row
execute function app_private.reject_chore_materialization_run_mutation();

create or replace function app_private.materialize_chore_revision_window(
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
  v_timezone text;
  v_start_date date;
  v_due_local_time time without time zone;
  v_assignee_member_id uuid;
  v_rule jsonb;
  v_frequency text;
  v_interval integer;
  v_weekday_numbers integer[];
  v_weekday_count integer;
  v_start_iso_dow integer;
  v_first_week_count integer;
  v_month_day integer;
  v_end_type text;
  v_end_count integer;
  v_end_until date;
  v_effective_window_start date;
  v_effective_window_end date;
  v_inserted_count integer;
begin
  if p_household_id is null
    or p_series_id is null
    or p_revision_id is null
    or p_window_start is null
    or p_window_end is null
    or p_window_end < p_window_start
    or p_window_end - p_window_start > 396 then
    raise exception using
      errcode = 'KFW01',
      message = 'invalid chore materialization window';
  end if;

  select
    series.timezone,
    revision.effective_local_date,
    revision.due_local_time,
    revision.default_assignee_member_id,
    revision.recurrence_rule
  into
    v_timezone,
    v_start_date,
    v_due_local_time,
    v_assignee_member_id,
    v_rule
  from public.chore_series as series
  join public.chore_series_revisions as revision
    on revision.household_id = series.household_id
   and revision.series_id = series.id
   and revision.id = p_revision_id
  where series.household_id = p_household_id
    and series.id = p_series_id
    and series.active_revision_id = p_revision_id
    and series.deleted_at is null;

  if not found
    or not app_private.is_valid_chore_recurrence_rule(v_rule)
    or v_rule = '{"type":"once"}'::jsonb then
    raise exception using
      errcode = 'KFW02',
      message = 'invalid chore recurrence';
  end if;

  perform 1
  from public.household_members as assignee
  where assignee.household_id = p_household_id
    and assignee.id = v_assignee_member_id
    and assignee.removed_at is null;

  if not found then
    raise exception using
      errcode = 'KFW03',
      message = 'chore assignee unavailable';
  end if;

  v_frequency := v_rule->>'frequency';
  v_interval := (v_rule->>'interval')::integer;
  v_month_day := nullif(v_rule->>'monthDay', '')::integer;
  v_end_type := v_rule->'end'->>'type';
  v_end_count := nullif(v_rule->'end'->>'count', '')::integer;
  v_end_until := nullif(v_rule->'end'->>'localDate', '')::date;
  v_start_iso_dow := extract(isodow from v_start_date)::integer;

  if v_frequency = 'weekly' then
    select
      array_agg(
        case weekday.value
          when 'MO' then 1
          when 'TU' then 2
          when 'WE' then 3
          when 'TH' then 4
          when 'FR' then 5
          when 'SA' then 6
          when 'SU' then 7
        end
        order by weekday.ordinality
      ),
      count(*)::integer
    into v_weekday_numbers, v_weekday_count
    from jsonb_array_elements_text(v_rule->'weekdays')
      with ordinality as weekday(value, ordinality);

    select count(*)::integer
    into v_first_week_count
    from unnest(v_weekday_numbers) as weekday_number(value)
    where weekday_number.value >= v_start_iso_dow;
  end if;

  v_effective_window_start := greatest(p_window_start, v_start_date);
  v_effective_window_end := p_window_end;
  if v_end_type = 'until' then
    v_effective_window_end := least(v_effective_window_end, v_end_until);
  end if;

  if v_effective_window_end < v_effective_window_start then
    return 0;
  end if;

  with candidate_dates as (
    select generated.due_date::date as due_date
    from generate_series(
      v_effective_window_start::timestamp,
      v_effective_window_end::timestamp,
      interval '1 day'
    ) as generated(due_date)
  ),
  date_offsets as (
    select
      candidate.due_date,
      candidate.due_date - v_start_date as day_offset,
      (
        (
          extract(year from candidate.due_date)::integer
          - extract(year from v_start_date)::integer
        ) * 12
        + extract(month from candidate.due_date)::integer
        - extract(month from v_start_date)::integer
      ) as month_offset,
      (
        candidate.due_date
        - (v_start_date - (v_start_iso_dow - 1))
      ) / 7 as week_offset,
      extract(isodow from candidate.due_date)::integer as iso_dow
    from candidate_dates as candidate
  ),
  matched_dates as (
    select
      candidate.due_date,
      case v_frequency
        when 'daily' then
          (candidate.day_offset / v_interval + 1)::bigint
        when 'monthly' then
          (candidate.month_offset / v_interval + 1)::bigint
        when 'weekly' then
          case
            when candidate.week_offset = 0 then (
              select count(*)::bigint
              from unnest(v_weekday_numbers) as weekday_number(value)
              where weekday_number.value between v_start_iso_dow
                and candidate.iso_dow
            )
            else
              v_first_week_count::bigint
              + (
                candidate.week_offset / v_interval - 1
              )::bigint * v_weekday_count::bigint
              + (
                select count(*)::bigint
                from unnest(v_weekday_numbers) as weekday_number(value)
                where weekday_number.value <= candidate.iso_dow
              )
          end
      end as occurrence_number
    from date_offsets as candidate
    where case v_frequency
      when 'daily' then
        candidate.day_offset % v_interval = 0
      when 'weekly' then
        candidate.week_offset % v_interval = 0
        and candidate.iso_dow = any(v_weekday_numbers)
      when 'monthly' then
        extract(day from candidate.due_date)::integer = v_month_day
        and candidate.month_offset % v_interval = 0
      else false
    end
  ),
  bounded_dates as (
    select matched.due_date
    from matched_dates as matched
    where v_end_type <> 'count'
      or matched.occurrence_number <= v_end_count
  )
  insert into public.chore_occurrences (
    id,
    household_id,
    series_id,
    revision_id,
    occurrence_key,
    due_local_date,
    due_at,
    timezone,
    assignee_member_id
  )
  select
    extensions.gen_random_uuid(),
    p_household_id,
    p_series_id,
    p_revision_id,
    p_series_id::text || ':' || bounded.due_date::text,
    bounded.due_date,
    case
      when v_due_local_time is null then null
      else (bounded.due_date + v_due_local_time) at time zone v_timezone
    end,
    v_timezone,
    v_assignee_member_id
  from bounded_dates as bounded
  on conflict (household_id, occurrence_key) do nothing;

  get diagnostics v_inserted_count = row_count;
  return v_inserted_count;
end;
$$;

revoke all on function app_private.materialize_chore_revision_window(
  uuid,
  uuid,
  uuid,
  date,
  date
) from public, anon, authenticated, service_role;

create or replace function app_private.materialize_chore_revision(
  p_household_id uuid,
  p_series_id uuid,
  p_revision_id uuid,
  p_horizon_end date
)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_start_date date;
begin
  if p_household_id is null
    or p_series_id is null
    or p_revision_id is null
    or p_horizon_end is null then
    raise exception using
      errcode = 'KFC07',
      message = 'invalid chore recurrence rule';
  end if;

  select revision.effective_local_date
  into v_start_date
  from public.chore_series as series
  join public.chore_series_revisions as revision
    on revision.household_id = series.household_id
   and revision.series_id = series.id
   and revision.id = p_revision_id
  where series.household_id = p_household_id
    and series.id = p_series_id
    and series.active_revision_id = p_revision_id
    and series.deleted_at is null;

  if not found
    or p_horizon_end < v_start_date
    or p_horizon_end > v_start_date + 365 then
    raise exception using
      errcode = 'KFC07',
      message = 'invalid chore recurrence rule';
  end if;

  return app_private.materialize_chore_revision_window(
    p_household_id,
    p_series_id,
    p_revision_id,
    v_start_date,
    p_horizon_end
  );
exception
  when sqlstate 'KFW02' or sqlstate 'KFW03' then
    raise exception using
      errcode = 'KFC07',
      message = 'invalid chore recurrence rule';
end;
$$;

revoke all on function app_private.materialize_chore_revision(
  uuid,
  uuid,
  uuid,
  date
) from public, anon, authenticated, service_role;

create or replace function public.run_chore_horizon_worker(
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
  inserted_count integer,
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
  v_inserted_count integer := 0;
  v_item_inserted_count integer;
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
      message = 'invalid chore horizon worker input';
  end if;

  for v_item in
    select
      series.household_id,
      series.id as series_id,
      revision.id as revision_id,
      revision.effective_local_date,
      revision.default_assignee_member_id,
      revision.recurrence_rule,
      state.revision_id as state_revision_id,
      state.covered_through as state_covered_through,
      state.next_repair_at as state_next_repair_at,
      local_clock.local_date,
      greatest(
        revision.effective_local_date,
        local_clock.local_date - p_repair_lookback_days
      ) as window_start,
      horizon.target_date
    from public.chore_series as series
    join public.chore_series_revisions as revision
      on revision.household_id = series.household_id
     and revision.series_id = series.id
     and revision.id = series.active_revision_id
    left join app_private.chore_materialization_states as state
      on state.household_id = series.household_id
     and state.series_id = series.id
    cross join lateral (
      select (p_as_of at time zone series.timezone)::date as local_date
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
      and revision.recurrence_rule <> '{"type":"once"}'::jsonb
      and revision.effective_local_date
        <= local_clock.local_date + p_horizon_days
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
    v_item_inserted_count := 0;
    v_error_code := null;
    v_series_complete := false;

    begin
      if not exists (
        select 1
        from public.household_members as assignee
        where assignee.household_id = v_item.household_id
          and assignee.id = v_item.default_assignee_member_id
          and assignee.removed_at is null
      ) then
        raise exception using
          errcode = 'KFW03',
          message = 'chore assignee unavailable';
      end if;

      if v_item.target_date >= v_item.window_start then
        v_item_inserted_count :=
          app_private.materialize_chore_revision_window(
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
      elsif v_item.recurrence_rule->'end'->>'type' = 'count' then
        select count(*) >= (
          v_item.recurrence_rule->'end'->>'count'
        )::integer
        into v_series_complete
        from public.chore_occurrences as occurrence
        where occurrence.household_id = v_item.household_id
          and occurrence.series_id = v_item.series_id
          and occurrence.revision_id = v_item.revision_id;
      end if;
    exception
      when sqlstate 'KFW03' then
        v_error_code := 'assignee_unavailable';
      when sqlstate 'KFW02' then
        v_error_code := 'invalid_recurrence';
      when others then
        v_error_code := 'materialization_failed';
    end;

    if v_error_code is null then
      v_succeeded_count := v_succeeded_count + 1;
      v_inserted_count := v_inserted_count + v_item_inserted_count;
      v_next_repair_at := case
        when v_series_complete then 'infinity'::timestamptz
        else p_as_of + interval '1 day'
      end;

      insert into app_private.chore_materialization_states (
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
        last_inserted_count,
        attempt_count,
        updated_at
      )
      values (
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
        v_item_inserted_count,
        1,
        p_as_of
      )
      on conflict (household_id, series_id) do update
      set revision_id = excluded.revision_id,
          covered_through = case
            when chore_materialization_states.revision_id
              = excluded.revision_id then greatest(
                chore_materialization_states.covered_through,
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
          last_inserted_count = excluded.last_inserted_count,
          attempt_count = chore_materialization_states.attempt_count + 1,
          updated_at = excluded.updated_at;
    else
      v_failed_count := v_failed_count + 1;

      insert into app_private.chore_materialization_states (
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
        last_inserted_count,
        attempt_count,
        updated_at
      )
      values (
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
      on conflict (household_id, series_id) do update
      set revision_id = excluded.revision_id,
          covered_through = case
            when chore_materialization_states.revision_id
              = excluded.revision_id
              then chore_materialization_states.covered_through
            else null
          end,
          last_window_start = excluded.last_window_start,
          last_target_date = excluded.last_target_date,
          next_repair_at = excluded.next_repair_at,
          last_attempted_at = excluded.last_attempted_at,
          last_result = excluded.last_result,
          last_error_code = excluded.last_error_code,
          last_inserted_count = excluded.last_inserted_count,
          attempt_count = chore_materialization_states.attempt_count + 1,
          updated_at = excluded.updated_at;
    end if;
  end loop;

  v_batch_exhausted := p_target_series_id is null
    and v_claimed_count = p_batch_size;

  insert into app_private.chore_materialization_runs (
    id,
    as_of,
    horizon_days,
    repair_lookback_days,
    batch_size,
    target_series_id,
    claimed_count,
    succeeded_count,
    failed_count,
    inserted_count,
    batch_exhausted,
    completed_at
  )
  values (
    v_run_id,
    p_as_of,
    p_horizon_days,
    p_repair_lookback_days,
    p_batch_size,
    p_target_series_id,
    v_claimed_count,
    v_succeeded_count,
    v_failed_count,
    v_inserted_count,
    v_batch_exhausted,
    statement_timestamp()
  );

  return query select
    v_run_id,
    v_claimed_count,
    v_succeeded_count,
    v_failed_count,
    v_inserted_count,
    v_batch_exhausted;
end;
$$;

revoke all on function public.run_chore_horizon_worker(
  timestamptz,
  integer,
  integer,
  integer,
  uuid
) from public, anon, authenticated, service_role;
grant execute on function public.run_chore_horizon_worker(
  timestamptz,
  integer,
  integer,
  integer,
  uuid
) to service_role;

select cron.schedule(
  'kinflow-chore-horizon-v1',
  '17 * * * *',
  $cron$
    select *
    from public.run_chore_horizon_worker(
      statement_timestamp(),
      365,
      7,
      100,
      null
    );
  $cron$
);
