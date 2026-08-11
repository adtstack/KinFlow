begin;

select plan(28);

select has_function(
  'app_private',
  'resolve_calendar_zoned_datetime',
  array['date', 'time without time zone', 'text', 'text'],
  'private calendar zoned local-time resolver exists'
);
select ok(
  (
    select not pg_proc.prosecdef
      and pg_proc.provolatile = 's'
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'app_private'
      and pg_proc.proname = 'resolve_calendar_zoned_datetime'
  ),
  'resolver is stable invoker-rights with an empty search path'
);
select is(
  (
    select string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'app_private'
      and specific_name like 'resolve_calendar_zoned_datetime_%'
      and parameter_mode = 'OUT'
  ),
  'resolved_at,utc_offset_seconds,resolution,candidate_count',
  'resolver return fields are exact'
);
select ok(
  not has_function_privilege(
    'public',
    'app_private.resolve_calendar_zoned_datetime(date,time without time zone,text,text)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'app_private.resolve_calendar_zoned_datetime(date,time without time zone,text,text)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'app_private.resolve_calendar_zoned_datetime(date,time without time zone,text,text)',
    'execute'
  )
  and not has_function_privilege(
    'service_role',
    'app_private.resolve_calendar_zoned_datetime(date,time without time zone,text,text)',
    'execute'
  ),
  'no API role can execute the private resolver directly'
);

-- TIME-001 and fixed-offset baseline.
select is(
  (
    select concat_ws(
      ':',
      to_char(result.resolved_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      result.utc_offset_seconds,
      result.resolution,
      result.candidate_count
    )
    from app_private.resolve_calendar_zoned_datetime(
      date '2026-07-14',
      time '09:00',
      'Asia/Seoul',
      'earlier'
    ) as result
  ),
  '2026-07-14T00:00:00Z:32400:normal:1',
  'TIME-001 Seoul local time resolves to its exact UTC instant'
);
select is(
  (
    select concat_ws(
      ':',
      to_char(result.resolved_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      result.utc_offset_seconds,
      result.resolution,
      result.candidate_count
    )
    from app_private.resolve_calendar_zoned_datetime(
      date '2026-07-14',
      time '09:00',
      'UTC',
      'earlier'
    ) as result
  ),
  '2026-07-14T09:00:00Z:0:normal:1',
  'UTC local intent remains the same instant'
);

-- TIME-003/004 preserve 08:00 while the canonical offset changes.
select is(
  (
    select concat_ws(
      ':',
      to_char(result.resolved_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      result.utc_offset_seconds
    )
    from app_private.resolve_calendar_zoned_datetime(
      date '2026-03-01', time '08:00', 'America/Los_Angeles', 'earlier'
    ) as result
  ),
  '2026-03-01T16:00:00Z:-28800',
  'TIME-003 pre-spring weekly local time uses PST'
);
select is(
  (
    select concat_ws(
      ':',
      to_char(result.resolved_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      result.utc_offset_seconds
    )
    from app_private.resolve_calendar_zoned_datetime(
      date '2026-03-08', time '08:00', 'America/Los_Angeles', 'earlier'
    ) as result
  ),
  '2026-03-08T15:00:00Z:-25200',
  'TIME-003 post-spring weekly local time remains 08:00 PDT'
);
select is(
  (
    select concat_ws(
      ':',
      to_char(result.resolved_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      result.utc_offset_seconds
    )
    from app_private.resolve_calendar_zoned_datetime(
      date '2026-10-25', time '08:00', 'America/Los_Angeles', 'earlier'
    ) as result
  ),
  '2026-10-25T15:00:00Z:-25200',
  'TIME-004 pre-fall weekly local time uses PDT'
);
select is(
  (
    select concat_ws(
      ':',
      to_char(result.resolved_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      result.utc_offset_seconds
    )
    from app_private.resolve_calendar_zoned_datetime(
      date '2026-11-01', time '08:00', 'America/Los_Angeles', 'earlier'
    ) as result
  ),
  '2026-11-01T16:00:00Z:-28800',
  'TIME-004 post-fall weekly local time remains 08:00 PST'
);

-- TIME-005/007/008 gap policy rejects instead of normalizing forward.
select throws_ok(
  $$
    select * from app_private.resolve_calendar_zoned_datetime(
      date '2026-03-08', time '02:30', 'America/Los_Angeles', 'earlier'
    )
  $$,
  'KFT02',
  'nonexistent calendar local time',
  'TIME-005 Los Angeles spring gap is rejected'
);
select throws_ok(
  $$
    select * from app_private.resolve_calendar_zoned_datetime(
      date '2026-03-29', time '02:30', 'Europe/Berlin', 'earlier'
    )
  $$,
  'KFT02',
  'nonexistent calendar local time',
  'TIME-007 Berlin spring gap is rejected'
);
select throws_ok(
  $$
    select * from app_private.resolve_calendar_zoned_datetime(
      date '2026-10-04', time '02:15', 'Australia/Lord_Howe', 'earlier'
    )
  $$,
  'KFT02',
  'nonexistent calendar local time',
  'TIME-008 Lord Howe thirty-minute spring gap is rejected'
);

-- TIME-006 retains the explicit earlier/later fold choice.
select is(
  (
    select concat_ws(
      ':',
      to_char(result.resolved_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      result.utc_offset_seconds,
      result.resolution,
      result.candidate_count
    )
    from app_private.resolve_calendar_zoned_datetime(
      date '2026-11-01', time '01:30', 'America/Los_Angeles', 'earlier'
    ) as result
  ),
  '2026-11-01T08:30:00Z:-25200:overlap_earlier:2',
  'TIME-006 earlier Los Angeles fold chooses the first instant'
);
select is(
  (
    select concat_ws(
      ':',
      to_char(result.resolved_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      result.utc_offset_seconds,
      result.resolution,
      result.candidate_count
    )
    from app_private.resolve_calendar_zoned_datetime(
      date '2026-11-01', time '01:30', 'America/Los_Angeles', 'later'
    ) as result
  ),
  '2026-11-01T09:30:00Z:-28800:overlap_later:2',
  'TIME-006 later Los Angeles fold chooses the second instant'
);
select is(
  (
    select extract(
      epoch from max(result.resolved_at) - min(result.resolved_at)
    )::integer
    from (
      select resolved.resolved_at
      from app_private.resolve_calendar_zoned_datetime(
        date '2026-11-01', time '01:30', 'America/Los_Angeles', 'earlier'
      ) as resolved
      union all
      select resolved.resolved_at
      from app_private.resolve_calendar_zoned_datetime(
        date '2026-11-01', time '01:30', 'America/Los_Angeles', 'later'
      ) as resolved
    ) as result
  ),
  3600,
  'Los Angeles overlap candidates are exactly one hour apart'
);
select is(
  (
    select concat_ws(
      ':',
      to_char(result.resolved_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      result.utc_offset_seconds,
      result.resolution,
      result.candidate_count
    )
    from app_private.resolve_calendar_zoned_datetime(
      date '2026-04-05', time '01:45', 'Australia/Lord_Howe', 'earlier'
    ) as result
  ),
  '2026-04-04T14:45:00Z:39600:overlap_earlier:2',
  'Lord Howe earlier fold preserves the daylight offset'
);
select is(
  (
    select concat_ws(
      ':',
      to_char(result.resolved_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      result.utc_offset_seconds,
      result.resolution,
      result.candidate_count
    )
    from app_private.resolve_calendar_zoned_datetime(
      date '2026-04-05', time '01:45', 'Australia/Lord_Howe', 'later'
    ) as result
  ),
  '2026-04-04T15:15:00Z:37800:overlap_later:2',
  'Lord Howe later fold is thirty minutes after the first instant'
);

-- Fail closed before any public Calendar RPC exists.
select throws_ok(
  $$
    select * from app_private.resolve_calendar_zoned_datetime(
      date '2026-07-14', time '09:00', 'PST', 'earlier'
    )
  $$,
  'KFT01',
  'invalid calendar time input',
  'timezone abbreviations are not accepted as IANA identity'
);
select throws_ok(
  $$
    select * from app_private.resolve_calendar_zoned_datetime(
      date '2026-07-14', time '09:00', 'America/Not_A_Zone', 'earlier'
    )
  $$,
  'KFT01',
  'invalid calendar time input',
  'unknown canonical-shaped zone fails closed'
);
select throws_ok(
  $$
    select * from app_private.resolve_calendar_zoned_datetime(
      date '2026-07-14', time '09:00', 'Asia/Seoul', 'default'
    )
  $$,
  'KFT01',
  'invalid calendar time input',
  'unknown overlap policy fails closed'
);
select throws_ok(
  $$
    select * from app_private.resolve_calendar_zoned_datetime(
      date '2026-07-14', time '09:00:01', 'Asia/Seoul', 'earlier'
    )
  $$,
  'KFT01',
  'invalid calendar time input',
  'non-minute precision fails closed'
);
select throws_ok(
  $$
    select * from app_private.resolve_calendar_zoned_datetime(
      null, time '09:00', 'Asia/Seoul', 'earlier'
    )
  $$,
  'KFT01',
  'invalid calendar time input',
  'null date fails closed'
);
select throws_ok(
  $$
    select * from app_private.resolve_calendar_zoned_datetime(
      date '2026-07-14', null, 'Asia/Seoul', 'earlier'
    )
  $$,
  'KFT01',
  'invalid calendar time input',
  'null time fails closed'
);
select throws_ok(
  $$
    select * from app_private.resolve_calendar_zoned_datetime(
      date '2026-07-14', time '09:00', null, 'earlier'
    )
  $$,
  'KFT01',
  'invalid calendar time input',
  'null timezone fails closed'
);
select throws_ok(
  $$
    select * from app_private.resolve_calendar_zoned_datetime(
      date '2026-07-14', time '09:00', 'Asia/Seoul', null
    )
  $$,
  'KFT01',
  'invalid calendar time input',
  'null overlap policy fails closed'
);

set local role authenticated;
select throws_ok(
  $$
    select * from app_private.resolve_calendar_zoned_datetime(
      date '2026-07-14', time '09:00', 'Asia/Seoul', 'earlier'
    )
  $$,
  '42501',
  'permission denied for function resolve_calendar_zoned_datetime',
  'authenticated client cannot execute the private time resolver'
);
reset role;
set local role service_role;
select throws_ok(
  $$
    select * from app_private.resolve_calendar_zoned_datetime(
      date '2026-07-14', time '09:00', 'Asia/Seoul', 'earlier'
    )
  $$,
  '42501',
  'permission denied for schema app_private',
  'service role cannot bypass future mediated Calendar RPCs'
);
reset role;

select * from finish();
rollback;
