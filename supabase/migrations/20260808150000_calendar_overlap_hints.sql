-- KinFlow WP04-07 same-member Calendar overlap preview.
-- Read-only hints are bounded and never participate in mutation validation.

create or replace function app_private.calendar_overlap_candidate_dates(
  p_local_start_date date,
  p_recurrence_rule jsonb,
  p_window_start date,
  p_window_end date
)
returns table (candidate_local_start_date date)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_frequency text;
  v_interval integer;
  v_weekdays text[];
  v_month_day integer;
  v_end_type text;
  v_end_count integer;
  v_end_until date;
  v_effective_end date;
  v_start_weekday text;
begin
  if p_recurrence_rule is null then
    return;
  end if;

  if p_local_start_date is null
    or not app_private.is_valid_calendar_recurrence_rule(p_recurrence_rule)
    or p_window_start is null
    or p_window_end is null
    or p_window_end < p_window_start
    or p_window_end - p_window_start > 365
    or p_window_start >= p_local_start_date
      and p_window_start - p_local_start_date > 3660 then
    raise exception using
      errcode = 'KFE07',
      message = 'invalid calendar recurrence rule';
  end if;

  v_frequency := p_recurrence_rule->>'frequency';
  v_interval := (p_recurrence_rule->>'interval')::integer;
  v_month_day := nullif(p_recurrence_rule->>'monthDay', '')::integer;
  v_end_type := p_recurrence_rule->'end'->>'type';
  v_end_count := nullif(
    p_recurrence_rule->'end'->>'count',
    ''
  )::integer;
  v_end_until := nullif(
    p_recurrence_rule->'end'->>'localDate',
    ''
  )::date;
  v_start_weekday := (
    array['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU']
  )[extract(isodow from p_local_start_date)::integer];

  if v_frequency = 'weekly' then
    select pg_catalog.array_agg(weekday.value order by weekday.ordinality)
    into v_weekdays
    from pg_catalog.jsonb_array_elements_text(
      p_recurrence_rule->'weekdays'
    ) with ordinality as weekday(value, ordinality);
  end if;

  if v_frequency = 'weekly'
      and not (p_recurrence_rule->'weekdays' ? v_start_weekday)
    or v_frequency = 'monthly'
      and v_month_day <> extract(day from p_local_start_date)::integer
    or v_end_type = 'until' and v_end_until < p_local_start_date then
    raise exception using
      errcode = 'KFE07',
      message = 'invalid calendar recurrence rule';
  end if;

  v_effective_end := p_window_end;
  if v_end_type = 'until' then
    v_effective_end := least(v_effective_end, v_end_until);
  end if;
  if v_effective_end < p_local_start_date then
    return;
  end if;

  return query
  with candidate_dates as materialized (
    select generated.local_date::date as local_date
    from pg_catalog.generate_series(
      p_local_start_date::timestamp without time zone,
      v_effective_end::timestamp without time zone,
      interval '1 day'
    ) as generated(local_date)
  ),
  matched_dates as materialized (
    select candidate.local_date
    from candidate_dates as candidate
    where case v_frequency
      when 'daily' then
        (candidate.local_date - p_local_start_date) % v_interval = 0
      when 'weekly' then
        (
          (
            candidate.local_date
            - (
              p_local_start_date
              - (extract(isodow from p_local_start_date)::integer - 1)
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
            - extract(year from p_local_start_date)::integer
          ) * 12
          + extract(month from candidate.local_date)::integer
          - extract(month from p_local_start_date)::integer
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
  where numbered.local_date >= greatest(p_window_start, p_local_start_date)
    and (
      v_end_type <> 'count'
      or numbered.occurrence_number <= v_end_count
    )
  order by numbered.local_date;
end;
$$;

revoke all on function app_private.calendar_overlap_candidate_dates(
  date,
  jsonb,
  date,
  date
) from public, anon, authenticated, service_role;

create or replace function public.preview_calendar_event_overlaps(
  p_household_id uuid,
  p_is_all_day boolean,
  p_local_start_date date,
  p_local_start_time time without time zone,
  p_duration_minutes integer,
  p_all_day_end_date_exclusive date,
  p_timezone text,
  p_overlap_policy text,
  p_recurrence_rule jsonb,
  p_window_start_date date,
  p_participant_member_ids uuid[],
  p_excluded_series_id uuid,
  p_excluded_occurrence_id uuid,
  p_limit integer
)
returns table (
  household_id uuid,
  household_timezone text,
  household_local_date date,
  generated_at timestamptz,
  checked_from_local_date date,
  checked_through_local_date date,
  candidate_occurrence_count integer,
  total_conflict_count integer,
  truncated boolean,
  candidate_local_start_date date,
  conflicting_series_id uuid,
  conflicting_occurrence_id uuid,
  conflicting_title text,
  conflicting_is_all_day boolean,
  conflicting_view_local_start_date date,
  conflicting_view_local_start_time time without time zone,
  conflicting_duration_minutes integer,
  conflicting_all_day_end_date_exclusive date,
  conflicting_participant_member_ids uuid[],
  conflicting_participant_display_names text[]
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_generated_at timestamptz := pg_catalog.statement_timestamp();
  v_household_timezone text;
  v_household_local_date date;
  v_window_end_date date;
  v_participant_member_ids uuid[];
  v_participant_count integer;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFE01',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or p_is_all_day is null
    or p_local_start_date is null
    or p_window_start_date is null
    or p_participant_member_ids is null
    or pg_catalog.cardinality(p_participant_member_ids) not between 1 and 50
    or pg_catalog.array_position(p_participant_member_ids, null) is not null
    or (
      select pg_catalog.count(distinct participant_id)
      from pg_catalog.unnest(p_participant_member_ids) as participant_id
    ) <> pg_catalog.cardinality(p_participant_member_ids)
    or p_excluded_series_id is not null
      and p_excluded_occurrence_id is not null
    or p_limit is null
    or p_limit not between 1 and 10
    or (
      p_recurrence_rule is null
      and p_window_start_date <> p_local_start_date
    )
    or (
      p_recurrence_rule is not null
      and (
        not app_private.is_valid_calendar_recurrence_rule(p_recurrence_rule)
        or p_window_start_date >= p_local_start_date
          and p_window_start_date - p_local_start_date > 3660
      )
    )
    or p_is_all_day and (
      p_local_start_time is not null
      or p_duration_minutes is not null
      or p_all_day_end_date_exclusive is null
      or p_all_day_end_date_exclusive <= p_local_start_date
      or p_timezone is not null
      or p_overlap_policy is not null
    )
    or not p_is_all_day and (
      p_local_start_time is null
      or extract(second from p_local_start_time) <> 0
      or p_duration_minutes is null
      or p_duration_minutes not between 1 and 10080
      or p_all_day_end_date_exclusive is not null
      or p_timezone is null
      or not app_private.is_valid_iana_timezone(p_timezone)
      or p_overlap_policy is null
      or p_overlap_policy not in ('earlier', 'later')
    ) then
    raise exception using
      errcode = 'KFE02',
      message = 'invalid calendar overlap preview input';
  end if;

  select household.timezone
  into v_household_timezone
  from public.households as household
  join public.household_members as caller
    on caller.household_id = household.id
   and caller.auth_user_id = v_authenticated_user_id
   and caller.removed_at is null
  where household.id = p_household_id
    and household.deleted_at is null;

  if not found then
    raise exception using
      errcode = 'KFE03',
      message = 'calendar event not found or forbidden';
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
      errcode = 'KFE02',
      message = 'invalid calendar overlap preview input';
  end if;

  v_household_local_date :=
    (v_generated_at at time zone v_household_timezone)::date;
  v_window_end_date := case
    when p_recurrence_rule is null then p_window_start_date
    else p_window_start_date + 365
  end;

  begin
    return query
    with candidate_dates as materialized (
      select p_local_start_date as candidate_date
      where p_recurrence_rule is null
      union all
      select candidate.candidate_local_start_date
      from app_private.calendar_overlap_candidate_dates(
        p_local_start_date,
        p_recurrence_rule,
        p_window_start_date,
        v_window_end_date
      ) as candidate
      where p_recurrence_rule is not null
    ),
    candidate_starts as materialized (
      select
        candidate.candidate_date,
        p_is_all_day as is_all_day,
        candidate.candidate_date as local_start_date,
        case
          when p_is_all_day then
            candidate.candidate_date
              + (p_all_day_end_date_exclusive - p_local_start_date)
          else null::date
        end as all_day_end_date_exclusive,
        case
          when p_is_all_day then null::timestamptz
          else (
            select resolved.resolved_at
            from app_private.resolve_calendar_zoned_datetime(
              candidate.candidate_date,
              p_local_start_time,
              p_timezone,
              p_overlap_policy
            ) as resolved
          )
        end as starts_at
      from candidate_dates as candidate
    ),
    candidate_occurrences as materialized (
      select
        candidate.candidate_date,
        candidate.is_all_day,
        candidate.local_start_date,
        candidate.all_day_end_date_exclusive,
        candidate.starts_at,
        case
          when candidate.is_all_day then null::timestamptz
          else candidate.starts_at
            + pg_catalog.make_interval(mins => p_duration_minutes)
        end as ends_at
      from candidate_starts as candidate
    ),
    raw_pairs as materialized (
      select
        candidate.candidate_date,
        candidate.is_all_day as candidate_is_all_day,
        candidate.local_start_date as candidate_start_date,
        candidate.all_day_end_date_exclusive as candidate_end_date,
        candidate.starts_at as candidate_starts_at,
        candidate.ends_at as candidate_ends_at,
        occurrence.id as occurrence_id
      from candidate_occurrences as candidate
      join public.event_occurrences as occurrence
        on occurrence.household_id = p_household_id
       and occurrence.status = 'scheduled'
      join public.event_series as series
        on series.household_id = occurrence.household_id
       and series.id = occurrence.series_id
       and series.deleted_at is null
      where (p_excluded_series_id is null
          or occurrence.series_id <> p_excluded_series_id)
        and (p_excluded_occurrence_id is null
          or occurrence.id <> p_excluded_occurrence_id)
        and (
          candidate.is_all_day
          and occurrence.starts_at is null
          and candidate.local_start_date
            < occurrence.all_day_end_date_exclusive
          and occurrence.local_start_date
            < candidate.all_day_end_date_exclusive
          or not candidate.is_all_day
          and occurrence.starts_at is not null
          and candidate.starts_at < occurrence.ends_at
          and occurrence.starts_at < candidate.ends_at
          or candidate.is_all_day
          and occurrence.starts_at is not null
          and occurrence.starts_at < (
            candidate.all_day_end_date_exclusive::timestamp without time zone
              at time zone v_household_timezone
          )
          and occurrence.ends_at > (
            candidate.local_start_date::timestamp without time zone
              at time zone v_household_timezone
          )
          or not candidate.is_all_day
          and occurrence.starts_at is null
          and candidate.starts_at < (
            occurrence.all_day_end_date_exclusive::timestamp
              without time zone at time zone v_household_timezone
          )
          and candidate.ends_at > (
            occurrence.local_start_date::timestamp without time zone
              at time zone v_household_timezone
          )
        )
    ),
    conflict_pairs as materialized (
      select
        pair.candidate_date,
        snapshot.series_id,
        snapshot.occurrence_id,
        snapshot.title,
        snapshot.is_all_day,
        case
          when snapshot.is_all_day then snapshot.local_start_date
          else (snapshot.starts_at at time zone v_household_timezone)::date
        end as view_local_start_date,
        case
          when snapshot.is_all_day then null::time without time zone
          else pg_catalog.date_trunc(
            'minute',
            snapshot.starts_at at time zone v_household_timezone
          )::time without time zone
        end as view_local_start_time,
        snapshot.duration_minutes,
        snapshot.all_day_end_date_exclusive,
        overlapping_members.member_ids,
        overlapping_members.display_names
      from raw_pairs as pair
      cross join lateral app_private.calendar_occurrence_snapshot(
        p_household_id,
        pair.occurrence_id
      ) as snapshot
      cross join lateral (
        select
          pg_catalog.array_agg(member.id order by member.id) as member_ids,
          pg_catalog.array_agg(member.display_name order by member.id)
            as display_names
        from public.household_members as member
        where member.household_id = p_household_id
          and member.removed_at is null
          and member.id = any(v_participant_member_ids)
          and member.id = any(snapshot.participant_member_ids)
      ) as overlapping_members
      where not snapshot.deleted
        and overlapping_members.member_ids is not null
    ),
    ranked_conflicts as materialized (
      select
        conflict.*,
        pg_catalog.row_number() over (
          order by
            conflict.candidate_date,
            conflict.view_local_start_date,
            conflict.view_local_start_time nulls first,
            conflict.occurrence_id
        ) as conflict_rank
      from conflict_pairs as conflict
    ),
    metadata as (
      select
        (select pg_catalog.count(*)::integer from candidate_occurrences)
          as candidate_count,
        (select pg_catalog.count(*)::integer from conflict_pairs)
          as conflict_count
    )
    select
      p_household_id,
      v_household_timezone,
      v_household_local_date,
      v_generated_at,
      p_window_start_date,
      v_window_end_date,
      metadata.candidate_count,
      metadata.conflict_count,
      metadata.conflict_count > p_limit,
      conflict.candidate_date,
      conflict.series_id,
      conflict.occurrence_id,
      conflict.title,
      conflict.is_all_day,
      conflict.view_local_start_date,
      conflict.view_local_start_time,
      conflict.duration_minutes,
      conflict.all_day_end_date_exclusive,
      conflict.member_ids,
      conflict.display_names
    from metadata
    left join ranked_conflicts as conflict
      on conflict.conflict_rank <= p_limit
    order by conflict.conflict_rank nulls first;
  exception
    when sqlstate 'KFT01' or sqlstate 'KFE07' then
      raise exception using
        errcode = 'KFE02',
        message = 'invalid calendar overlap preview input';
    when sqlstate 'KFT02' then
      raise exception using
        errcode = 'KFE06',
        message = 'nonexistent calendar local time';
  end;
end;
$$;

revoke all on function public.preview_calendar_event_overlaps(
  uuid,
  boolean,
  date,
  time without time zone,
  integer,
  date,
  text,
  text,
  jsonb,
  date,
  uuid[],
  uuid,
  uuid,
  integer
) from public, anon, authenticated;

grant execute on function public.preview_calendar_event_overlaps(
  uuid,
  boolean,
  date,
  time without time zone,
  integer,
  date,
  text,
  text,
  jsonb,
  date,
  uuid[],
  uuid,
  uuid,
  integer
) to authenticated;

comment on function public.preview_calendar_event_overlaps(
  uuid,
  boolean,
  date,
  time without time zone,
  integer,
  date,
  text,
  text,
  jsonb,
  date,
  uuid[],
  uuid,
  uuid,
  integer
) is 'WP04-07 bounded same-member Calendar overlap hint; never blocks writes.';
