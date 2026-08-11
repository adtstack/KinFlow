-- KinFlow WP04-01 calendar time primitives.
-- Canonical persistence instants are resolved by PostgreSQL tzdata.

create or replace function app_private.resolve_calendar_zoned_datetime(
  p_local_date date,
  p_local_time time without time zone,
  p_timezone text,
  p_overlap_policy text default 'earlier'
)
returns table (
  resolved_at timestamptz,
  utc_offset_seconds integer,
  resolution text,
  candidate_count integer
)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_local_timestamp timestamp without time zone;
  v_candidate_count integer;
  v_earlier_at timestamptz;
  v_later_at timestamptz;
  v_resolved_at timestamptz;
begin
  if p_local_date is null
    or p_local_time is null
    or p_timezone is null
    or p_overlap_policy is null
    or p_overlap_policy not in ('earlier', 'later')
    or pg_catalog.char_length(p_timezone) > 100
    or not (
      p_timezone = 'UTC'
      or p_timezone ~
        '^[A-Za-z][A-Za-z0-9._+-]*(/[A-Za-z0-9][A-Za-z0-9._+-]*)+$'
    )
    or extract(hour from p_local_time) not between 0 and 23
    or extract(second from p_local_time) <> 0 then
    raise exception using
      errcode = 'KFT01',
      message = 'invalid calendar time input';
  end if;

  if not app_private.is_valid_iana_timezone(p_timezone) then
    raise exception using
      errcode = 'KFT01',
      message = 'invalid calendar time input';
  end if;

  v_local_timestamp := p_local_date + p_local_time;

  select
    pg_catalog.count(*)::integer,
    pg_catalog.min(candidate.instant),
    pg_catalog.max(candidate.instant)
  into
    v_candidate_count,
    v_earlier_at,
    v_later_at
  from pg_catalog.generate_series(
    v_local_timestamp at time zone 'UTC' - interval '16 hours',
    v_local_timestamp at time zone 'UTC' + interval '16 hours',
    interval '1 minute'
  ) as candidate(instant)
  where candidate.instant at time zone p_timezone = v_local_timestamp;

  if v_candidate_count = 0 then
    raise exception using
      errcode = 'KFT02',
      message = 'nonexistent calendar local time';
  end if;

  v_resolved_at := case
    when p_overlap_policy = 'later' then v_later_at
    else v_earlier_at
  end;

  return query
  select
    v_resolved_at,
    pg_catalog.round(
      extract(
        epoch from (
          (v_resolved_at at time zone p_timezone)
          - (v_resolved_at at time zone 'UTC')
        )
      )
    )::integer,
    case
      when v_candidate_count = 1 then 'normal'
      when p_overlap_policy = 'later' then 'overlap_later'
      else 'overlap_earlier'
    end,
    v_candidate_count;
end;
$$;

revoke all on function app_private.resolve_calendar_zoned_datetime(
  date,
  time without time zone,
  text,
  text
) from public, anon, authenticated, service_role;

comment on function app_private.resolve_calendar_zoned_datetime(
  date,
  time without time zone,
  text,
  text
) is
  'WP04-01 private gap-rejecting, overlap-explicit IANA local-time resolver.';
