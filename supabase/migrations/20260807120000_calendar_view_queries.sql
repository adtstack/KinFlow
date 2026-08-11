-- KinFlow WP04-03 Calendar agenda/day/month read projections.
-- Store MVP scope: active adult household members and authoritative online reads.

create index event_occurrences_timed_overlap_idx
  on public.event_occurrences(household_id, ends_at, starts_at, id)
  where starts_at is not null and status = 'scheduled';

create index event_occurrences_all_day_overlap_idx
  on public.event_occurrences(
    household_id,
    all_day_end_date_exclusive,
    local_start_date,
    id
  )
  where starts_at is null and status = 'scheduled';

create function public.get_calendar_event_page(
  p_household_id uuid,
  p_view text default 'agenda',
  p_range_start_date date default null,
  p_range_end_date_exclusive date default null,
  p_limit integer default 30,
  p_after_cursor text default null
)
returns table (
  household_id uuid,
  household_timezone text,
  household_local_date date,
  generated_at timestamptz,
  view_mode text,
  range_start_date date,
  range_end_date_exclusive date,
  page_limit integer,
  has_more boolean,
  page_cursor text,
  view_local_date date,
  view_local_time time without time zone,
  series_id uuid,
  occurrence_id uuid,
  title text,
  description text,
  is_all_day boolean,
  local_start_date date,
  local_start_time time without time zone,
  duration_minutes integer,
  all_day_end_date_exclusive date,
  timezone text,
  overlap_policy text,
  starts_at timestamptz,
  ends_at timestamptz,
  dst_resolution text,
  utc_offset_seconds integer,
  participant_member_ids uuid[],
  participant_display_names text[],
  version bigint,
  occurrence_version bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_generated_at timestamptz := pg_catalog.statement_timestamp();
  v_view text := pg_catalog.lower(pg_catalog.btrim(coalesce(p_view, '')));
  v_household_timezone text;
  v_household_local_date date;
  v_range_start_date date;
  v_range_end_date_exclusive date;
  v_range_starts_at timestamptz;
  v_range_ends_at timestamptz;
  v_cursor_json jsonb;
  v_cursor_date date;
  v_cursor_kind integer;
  v_cursor_minute integer;
  v_cursor_occurrence_id uuid;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFE01',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or v_view not in ('agenda', 'day')
    or p_limit is null
    or p_limit not between 1 and 100
    or (p_range_start_date is null) <> (p_range_end_date_exclusive is null)
    or p_range_start_date is null and v_view <> 'agenda'
    or p_range_start_date is not null and (
      p_range_end_date_exclusive <= p_range_start_date
      or p_range_end_date_exclusive - p_range_start_date > 366
      or v_view = 'day'
         and p_range_end_date_exclusive - p_range_start_date <> 1
    )
    or p_after_cursor is not null and (
      p_range_start_date is null
      or pg_catalog.char_length(p_after_cursor) not between 2 and 1000
      or pg_catalog.char_length(p_after_cursor) % 2 <> 0
      or p_after_cursor !~ '^[0-9a-f]+$'
    ) then
    raise exception using
      errcode = 'KFE02',
      message = 'invalid calendar event input';
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

  v_household_local_date :=
    (v_generated_at at time zone v_household_timezone)::date;
  v_range_start_date := coalesce(
    p_range_start_date,
    v_household_local_date
  );
  v_range_end_date_exclusive := coalesce(
    p_range_end_date_exclusive,
    v_range_start_date + 90
  );
  v_range_starts_at :=
    (v_range_start_date::timestamp without time zone)
      at time zone v_household_timezone;
  v_range_ends_at :=
    (v_range_end_date_exclusive::timestamp without time zone)
      at time zone v_household_timezone;

  if p_after_cursor is not null then
    begin
      v_cursor_json := pg_catalog.convert_from(
        pg_catalog.decode(p_after_cursor, 'hex'),
        'UTF8'
      )::jsonb;

      if pg_catalog.jsonb_typeof(v_cursor_json) <> 'object'
        or (
          select pg_catalog.count(*)
          from pg_catalog.jsonb_object_keys(v_cursor_json)
        ) <> 9
        or not v_cursor_json ?& array[
          'v',
          'household',
          'view',
          'rangeStart',
          'rangeEndExclusive',
          'date',
          'kind',
          'minute',
          'id'
        ]
        or pg_catalog.jsonb_typeof(v_cursor_json->'v') <> 'number'
        or (v_cursor_json->>'v')::integer <> 1
        or pg_catalog.jsonb_typeof(v_cursor_json->'household') <> 'string'
        or v_cursor_json->>'household' <> p_household_id::text
        or pg_catalog.jsonb_typeof(v_cursor_json->'view') <> 'string'
        or v_cursor_json->>'view' <> v_view
        or pg_catalog.jsonb_typeof(v_cursor_json->'rangeStart') <> 'string'
        or (v_cursor_json->>'rangeStart')::date <> v_range_start_date
        or pg_catalog.jsonb_typeof(
          v_cursor_json->'rangeEndExclusive'
        ) <> 'string'
        or (v_cursor_json->>'rangeEndExclusive')::date <>
           v_range_end_date_exclusive
        or pg_catalog.jsonb_typeof(v_cursor_json->'date') <> 'string'
        or pg_catalog.jsonb_typeof(v_cursor_json->'kind') <> 'number'
        or pg_catalog.jsonb_typeof(v_cursor_json->'minute') <> 'number'
        or pg_catalog.jsonb_typeof(v_cursor_json->'id') <> 'string' then
        raise exception using
          errcode = 'KFE02',
          message = 'invalid calendar event input';
      end if;

      v_cursor_date := (v_cursor_json->>'date')::date;
      v_cursor_kind := (v_cursor_json->>'kind')::integer;
      v_cursor_minute := (v_cursor_json->>'minute')::integer;
      v_cursor_occurrence_id := (v_cursor_json->>'id')::uuid;

      if v_cursor_date < v_range_start_date
        or v_cursor_date >= v_range_end_date_exclusive
        or v_cursor_kind not in (0, 1)
        or v_cursor_kind = 0 and v_cursor_minute <> -1
        or v_cursor_kind = 1 and v_cursor_minute not between 0 and 1439 then
        raise exception using
          errcode = 'KFE02',
          message = 'invalid calendar event input';
      end if;
    exception
      when sqlstate 'KFE02' then
        raise;
      when others then
        raise exception using
          errcode = 'KFE02',
          message = 'invalid calendar event input';
    end;
  end if;

  return query
  with base as materialized (
    select
      snapshot.*,
      greatest(
        case
          when snapshot.is_all_day then snapshot.local_start_date
          else (snapshot.starts_at at time zone v_household_timezone)::date
        end,
        v_range_start_date
      ) as sort_date,
      case when snapshot.is_all_day then 0 else 1 end as sort_kind,
      case
        when snapshot.is_all_day then -1
        when snapshot.starts_at <= v_range_starts_at then 0
        else
          extract(
            hour from snapshot.starts_at at time zone v_household_timezone
          )::integer * 60
          + extract(
            minute from snapshot.starts_at at time zone v_household_timezone
          )::integer
      end as sort_minute
    from public.event_occurrences as occurrence
    join public.event_series as series
      on series.household_id = occurrence.household_id
     and series.id = occurrence.series_id
    join public.event_series_revisions as revision
      on revision.household_id = occurrence.household_id
     and revision.series_id = occurrence.series_id
     and revision.id = occurrence.revision_id
    cross join lateral app_private.one_time_event_snapshot(
      series.household_id,
      series.id
    ) as snapshot
    where occurrence.household_id = p_household_id
      and occurrence.status = 'scheduled'
      and series.deleted_at is null
      and revision.recurrence_rule is null
      and (
        series.is_all_day
        and occurrence.local_start_date < v_range_end_date_exclusive
        and occurrence.all_day_end_date_exclusive > v_range_start_date
        or not series.is_all_day
        and occurrence.starts_at < v_range_ends_at
        and occurrence.ends_at > v_range_starts_at
      )
  ),
  candidate as materialized (
    select base.*
    from base
    where p_after_cursor is null
      or (
        base.sort_date,
        base.sort_kind,
        base.sort_minute,
        base.occurrence_id
      ) > (
        v_cursor_date,
        v_cursor_kind,
        v_cursor_minute,
        v_cursor_occurrence_id
      )
  ),
  page_plus as materialized (
    select candidate.*
    from candidate
    order by
      candidate.sort_date,
      candidate.sort_kind,
      candidate.sort_minute,
      candidate.occurrence_id
    limit p_limit + 1
  ),
  ranked_page as materialized (
    select
      page_plus.*,
      pg_catalog.row_number() over (
        order by
          page_plus.sort_date,
          page_plus.sort_kind,
          page_plus.sort_minute,
          page_plus.occurrence_id
      ) as page_rank
    from page_plus
  ),
  metadata as (
    select
      pg_catalog.count(*) > p_limit as has_more,
      case
        when pg_catalog.count(*) > p_limit then (
          select pg_catalog.encode(
            pg_catalog.convert_to(
              pg_catalog.jsonb_build_object(
                'v', 1,
                'household', p_household_id,
                'view', v_view,
                'rangeStart', v_range_start_date,
                'rangeEndExclusive', v_range_end_date_exclusive,
                'date', cursor_item.sort_date,
                'kind', cursor_item.sort_kind,
                'minute', cursor_item.sort_minute,
                'id', cursor_item.occurrence_id
              )::text,
              'UTF8'
            ),
            'hex'
          )
          from ranked_page as cursor_item
          where cursor_item.page_rank = p_limit
        )
        else null
      end as page_cursor
    from ranked_page
  )
  select
    p_household_id,
    v_household_timezone,
    v_household_local_date,
    v_generated_at,
    v_view,
    v_range_start_date,
    v_range_end_date_exclusive,
    p_limit,
    metadata.has_more,
    metadata.page_cursor,
    item.sort_date,
    case
      when item.sort_kind = 0 then null
      else pg_catalog.make_time(
        item.sort_minute / 60,
        item.sort_minute % 60,
        0
      )
    end,
    item.series_id,
    item.occurrence_id,
    item.title,
    item.description,
    item.is_all_day,
    item.local_start_date,
    item.local_start_time,
    item.duration_minutes,
    item.all_day_end_date_exclusive,
    item.timezone,
    item.overlap_policy,
    item.starts_at,
    item.ends_at,
    item.dst_resolution,
    item.utc_offset_seconds,
    item.participant_member_ids,
    item.participant_display_names,
    item.series_version,
    item.occurrence_version
  from metadata
  left join ranked_page as item
    on item.page_rank <= p_limit
  order by item.page_rank nulls first;
end;
$$;

create function public.get_calendar_month_summary(
  p_household_id uuid,
  p_month_start_date date
)
returns table (
  household_id uuid,
  household_timezone text,
  household_local_date date,
  generated_at timestamptz,
  month_start_date date,
  month_end_date_exclusive date,
  day_date date,
  event_count integer,
  all_day_count integer,
  timed_count integer
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
  v_month_end_date_exclusive date;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFE01',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or p_month_start_date is null
    or pg_catalog.date_trunc(
      'month',
      p_month_start_date::timestamp without time zone
    )::date <> p_month_start_date then
    raise exception using
      errcode = 'KFE02',
      message = 'invalid calendar event input';
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

  v_household_local_date :=
    (v_generated_at at time zone v_household_timezone)::date;
  v_month_end_date_exclusive := (
    p_month_start_date::timestamp without time zone
      + interval '1 month'
  )::date;

  return query
  with month_days as materialized (
    select day_value::date as day_date
    from pg_catalog.generate_series(
      p_month_start_date::timestamp without time zone,
      (v_month_end_date_exclusive - 1)::timestamp without time zone,
      interval '1 day'
    ) as day_value
  )
  select
    p_household_id,
    v_household_timezone,
    v_household_local_date,
    v_generated_at,
    p_month_start_date,
    v_month_end_date_exclusive,
    month_day.day_date,
    pg_catalog.count(item.occurrence_id)::integer,
    pg_catalog.count(item.occurrence_id) filter (
      where item.is_all_day
    )::integer,
    pg_catalog.count(item.occurrence_id) filter (
      where not item.is_all_day
    )::integer
  from month_days as month_day
  left join lateral (
    select
      occurrence.id as occurrence_id,
      series.is_all_day
    from public.event_occurrences as occurrence
    join public.event_series as series
      on series.household_id = occurrence.household_id
     and series.id = occurrence.series_id
    where occurrence.household_id = p_household_id
      and occurrence.status = 'scheduled'
      and series.deleted_at is null
      and (
        series.is_all_day
        and occurrence.local_start_date < month_day.day_date + 1
        and occurrence.all_day_end_date_exclusive > month_day.day_date
        or not series.is_all_day
        and occurrence.starts_at < (
          (month_day.day_date + 1)::timestamp without time zone
            at time zone v_household_timezone
        )
        and occurrence.ends_at > (
          month_day.day_date::timestamp without time zone
            at time zone v_household_timezone
        )
      )
  ) as item on true
  group by month_day.day_date
  order by month_day.day_date;
end;
$$;

revoke all on function public.get_calendar_event_page(
  uuid,
  text,
  date,
  date,
  integer,
  text
) from public, anon, authenticated;

revoke all on function public.get_calendar_month_summary(uuid, date)
  from public, anon, authenticated;

grant execute on function public.get_calendar_event_page(
  uuid,
  text,
  date,
  date,
  integer,
  text
) to authenticated;

grant execute on function public.get_calendar_month_summary(uuid, date)
  to authenticated;

comment on function public.get_calendar_event_page(
  uuid,
  text,
  date,
  date,
  integer,
  text
) is 'WP04-03 household-authorized agenda/day overlap page with query-bound opaque keyset cursor.';

comment on function public.get_calendar_month_summary(uuid, date)
  is 'WP04-03 content-free household-local daily event counts for one calendar month.';
