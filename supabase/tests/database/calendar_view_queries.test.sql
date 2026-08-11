begin;
set constraints all deferred;

select plan(68);

-- 01-12: additive function, index, signature, and least-privilege contracts.
select has_function(
  'public',
  'get_calendar_event_page',
  array['uuid', 'text', 'date', 'date', 'integer', 'text'],
  'Calendar event page RPC exists'
);
select has_function(
  'public',
  'get_calendar_month_summary',
  array['uuid', 'date'],
  'Calendar month summary RPC exists'
);
select has_index(
  'public',
  'event_occurrences',
  'event_occurrences_timed_overlap_idx',
  'timed overlap index exists'
);
select has_index(
  'public',
  'event_occurrences',
  'event_occurrences_all_day_overlap_idx',
  'all-day overlap index exists'
);
select ok(
  (
    select pg_catalog.bool_and(pg_proc.prosecdef)
      and pg_catalog.bool_and(
        pg_proc.proconfig @> array['search_path=""']::text[]
      )
    from pg_catalog.pg_proc
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname in (
        'get_calendar_event_page',
        'get_calendar_month_summary'
      )
  ),
  'Calendar view RPCs are security-definer with empty search paths'
);
select ok(
  (
    select pg_catalog.bool_and(pg_proc.provolatile = 's')
    from pg_catalog.pg_proc
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname in (
        'get_calendar_event_page',
        'get_calendar_month_summary'
      )
  ),
  'Calendar view RPCs are stable reads'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.get_calendar_event_page(uuid,text,date,date,integer,text)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.get_calendar_month_summary(uuid,date)',
    'execute'
  ),
  'authenticated clients can execute mediated Calendar view RPCs'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.get_calendar_event_page(uuid,text,date,date,integer,text)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.get_calendar_month_summary(uuid,date)',
    'execute'
  ),
  'anonymous clients cannot execute Calendar view RPCs'
);
select ok(
  not has_function_privilege(
    'service_role',
    'public.get_calendar_event_page(uuid,text,date,date,integer,text)',
    'execute'
  )
  and not has_function_privilege(
    'service_role',
    'public.get_calendar_month_summary(uuid,date)',
    'execute'
  ),
  'service role receives no broad Calendar view execute grant'
);
select has_function(
  'public',
  'list_one_time_events',
  array['uuid', 'integer'],
  'legacy one-time list signature remains available'
);
select is(
  (
    select pg_catalog.string_agg(
      parameter_name,
      ',' order by ordinal_position
    )
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name = 'get_calendar_event_page_' || (
        'public.get_calendar_event_page(uuid,text,date,date,integer,text)'
          ::regprocedure::oid::text
      )
      and parameter_mode = 'OUT'
  ),
  'household_id,household_timezone,household_local_date,generated_at,view_mode,range_start_date,range_end_date_exclusive,page_limit,has_more,page_cursor,view_local_date,view_local_time,series_id,occurrence_id,title,description,is_all_day,local_start_date,local_start_time,duration_minutes,all_day_end_date_exclusive,timezone,overlap_policy,starts_at,ends_at,dst_resolution,utc_offset_seconds,participant_member_ids,participant_display_names,version,occurrence_version',
  'event page returns the exact query envelope projection and event fields'
);
select is(
  (
    select pg_catalog.string_agg(
      parameter_name,
      ',' order by ordinal_position
    )
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name = 'get_calendar_month_summary_' || (
        'public.get_calendar_month_summary(uuid,date)'
          ::regprocedure::oid::text
      )
      and parameter_mode = 'OUT'
  ),
  'household_id,household_timezone,household_local_date,generated_at,month_start_date,month_end_date_exclusive,day_date,event_count,all_day_count,timed_count',
  'month summary returns only context dates and counts'
);

-- 13-26: authentication, query shape, cursor shape, and membership denial.
select throws_ok(
  $$select * from public.get_calendar_event_page(
    '20000000-0000-4000-8000-000000000101',
    'agenda', null, null, 30, null
  )$$,
  'KFE01',
  'authentication required',
  'event page requires authentication'
);
select throws_ok(
  $$select * from public.get_calendar_month_summary(
    '20000000-0000-4000-8000-000000000101', date '2026-08-01'
  )$$,
  'KFE01',
  'authentication required',
  'month summary requires authentication'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$select * from public.get_calendar_event_page(
    '20000000-0000-4000-8000-000000000101',
    'week', date '2026-08-07', date '2026-08-08', 30, null
  )$$,
  'KFE02',
  'invalid calendar event input',
  'unknown Calendar view is rejected'
);
select throws_ok(
  $$select * from public.get_calendar_event_page(
    '20000000-0000-4000-8000-000000000101',
    'day', null, null, 30, null
  )$$,
  'KFE02',
  'invalid calendar event input',
  'day view requires an explicit range'
);
select throws_ok(
  $$select * from public.get_calendar_event_page(
    '20000000-0000-4000-8000-000000000101',
    'agenda', date '2026-08-07', null, 30, null
  )$$,
  'KFE02',
  'invalid calendar event input',
  'partial agenda range is rejected'
);
select throws_ok(
  $$select * from public.get_calendar_event_page(
    '20000000-0000-4000-8000-000000000101',
    'day', date '2026-08-07', date '2026-08-09', 30, null
  )$$,
  'KFE02',
  'invalid calendar event input',
  'day view must contain exactly one date'
);
select throws_ok(
  $$select * from public.get_calendar_event_page(
    '20000000-0000-4000-8000-000000000101',
    'agenda', date '2026-01-01', date '2027-01-03', 30, null
  )$$,
  'KFE02',
  'invalid calendar event input',
  'agenda range is bounded to 366 days'
);
select throws_ok(
  $$select * from public.get_calendar_event_page(
    '20000000-0000-4000-8000-000000000101',
    'agenda', date '2026-08-07', date '2026-08-08', 101, null
  )$$,
  'KFE02',
  'invalid calendar event input',
  'page size is bounded to 100'
);
select throws_ok(
  $$select * from public.get_calendar_event_page(
    '20000000-0000-4000-8000-000000000101',
    'agenda', date '2026-08-07', date '2026-08-08', 30, 'not-hex'
  )$$,
  'KFE02',
  'invalid calendar event input',
  'malformed opaque cursor is rejected'
);
select throws_ok(
  $$select * from public.get_calendar_month_summary(
    '20000000-0000-4000-8000-000000000101', date '2026-08-02'
  )$$,
  'KFE02',
  'invalid calendar event input',
  'month summary requires the first date of a month'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$select * from public.get_calendar_event_page(
    '20000000-0000-4000-8000-000000000101',
    'agenda', date '2026-08-07', date '2026-08-08', 30, null
  )$$,
  'KFE03',
  'calendar event not found or forbidden',
  'outsider cannot read another household event page'
);
select throws_ok(
  $$select * from public.get_calendar_month_summary(
    '20000000-0000-4000-8000-000000000101', date '2026-08-01'
  )$$,
  'KFE03',
  'calendar event not found or forbidden',
  'outsider cannot read another household month summary'
);
reset role;
update public.household_members
set removed_at = pg_catalog.statement_timestamp()
where id = '30000000-0000-4000-8000-000000000102';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select throws_ok(
  $$select * from public.get_calendar_event_page(
    '20000000-0000-4000-8000-000000000101',
    'day', date '2026-08-07', date '2026-08-08', 30, null
  )$$,
  'KFE03',
  'calendar event not found or forbidden',
  'removed member cannot read an event page'
);
select throws_ok(
  $$select * from public.get_calendar_month_summary(
    '20000000-0000-4000-8000-000000000101', date '2026-08-01'
  )$$,
  'KFE03',
  'calendar event not found or forbidden',
  'removed member cannot read a month summary'
);
reset role;
update public.household_members
set removed_at = null
where id = '30000000-0000-4000-8000-000000000102';

-- 27-31: deterministic timed, all-day, multi-day, and out-of-range fixtures.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$select * from public.create_one_time_event(
    '42000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000101',
    'All-day span', null, true,
    date '2026-08-07', null, null, date '2026-08-10',
    null, null,
    array['30000000-0000-4000-8000-000000000101'::uuid]
  )$$,
  'three-day all-day event is created'
);
select lives_ok(
  $$select * from public.create_one_time_event(
    '42000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000101',
    'Morning timed', null, false,
    date '2026-08-07', time '09:00', 60, null,
    'Asia/Seoul', 'earlier',
    array['30000000-0000-4000-8000-000000000101'::uuid]
  )$$,
  'same-day timed event is created'
);
select lives_ok(
  $$select * from public.create_one_time_event(
    '42000000-0000-4000-8000-000000000003',
    '20000000-0000-4000-8000-000000000101',
    'Late spanning timed', null, false,
    date '2026-08-07', time '23:30', 120, null,
    'Asia/Seoul', 'earlier',
    array['30000000-0000-4000-8000-000000000101'::uuid]
  )$$,
  'timed event crossing household midnight is created'
);
select lives_ok(
  $$select * from public.create_one_time_event(
    '42000000-0000-4000-8000-000000000004',
    '20000000-0000-4000-8000-000000000101',
    'Tomorrow timed', null, false,
    date '2026-08-08', time '10:00', 60, null,
    'Asia/Seoul', 'earlier',
    array['30000000-0000-4000-8000-000000000101'::uuid]
  )$$,
  'next-day timed event is created'
);
select lives_ok(
  $$select * from public.create_one_time_event(
    '42000000-0000-4000-8000-000000000005',
    '20000000-0000-4000-8000-000000000101',
    'Far timed', null, false,
    date '2026-11-15', time '12:00', 30, null,
    'Asia/Seoul', 'earlier',
    array['30000000-0000-4000-8000-000000000101'::uuid]
  )$$,
  'out-of-range timed event is created'
);

-- 32-53: default range, half-open overlap, total order, and keyset pages.
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      result.view_mode,
      result.range_start_date = result.household_local_date,
      result.range_end_date_exclusive - result.range_start_date,
      result.page_limit
    )
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'agenda', null, null, 30, null
    ) as result
    limit 1
  ),
  'agenda:t:90:30',
  'default agenda resolves from authoritative household today for 90 days'
);
select ok(
  (
    select pg_catalog.bool_and(
      result.household_timezone = 'Asia/Seoul'
      and result.household_local_date =
        (result.generated_at at time zone 'Asia/Seoul')::date
    )
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'agenda', null, null, 30, null
    ) as result
  ),
  'default page returns authoritative timezone date and generation context'
);
select ok(
  (
    select pg_catalog.bool_and(
      result.view_mode = 'agenda'
      and result.range_start_date = date '2026-08-07'
      and result.range_end_date_exclusive = date '2026-08-10'
      and result.page_limit = 2
    )
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'agenda', date '2026-08-07', date '2026-08-10', 2, null
    ) as result
  ),
  'explicit agenda page echoes the resolved bounded query'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      pg_catalog.count(*) filter (where result.series_id is not null),
      pg_catalog.bool_and(result.has_more),
      pg_catalog.bool_and(result.page_cursor is not null)
    )
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'agenda', date '2026-08-07', date '2026-08-10', 2, null
    ) as result
  ),
  '2:t:t',
  'first agenda page uses limit plus one to advertise continuation'
);
select is(
  (
    select pg_catalog.string_agg(
      result.title,
      ',' order by
        result.view_local_date,
        result.view_local_time nulls first,
        result.occurrence_id
    )
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'agenda', date '2026-08-07', date '2026-08-10', 2, null
    ) as result
    where result.series_id is not null
  ),
  'All-day span,Morning timed',
  'first page sorts all-day before timed then by household projection time'
);
select set_config(
  'kinflow_test.calendar_page_cursor',
  (
    select result.page_cursor
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'agenda', date '2026-08-07', date '2026-08-10', 2, null
    ) as result
    where result.page_cursor is not null
    limit 1
  ),
  true
);
select ok(
  pg_catalog.convert_from(
    pg_catalog.decode(
      current_setting('kinflow_test.calendar_page_cursor'),
      'hex'
    ),
    'UTF8'
  ) !~* '(title|description|participant|All-day|Morning)',
  'opaque cursor contains no event content or participant data'
);
select is(
  (
    select pg_catalog.count(*)
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'agenda', date '2026-08-07', date '2026-08-10', 2,
      current_setting('kinflow_test.calendar_page_cursor')
    ) as result
    where result.series_id is not null
  ),
  2::bigint,
  'continuation returns the remaining two events'
);
select is(
  (
    select pg_catalog.string_agg(
      result.title,
      ',' order by
        result.view_local_date,
        result.view_local_time nulls first,
        result.occurrence_id
    )
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'agenda', date '2026-08-07', date '2026-08-10', 2,
      current_setting('kinflow_test.calendar_page_cursor')
    ) as result
    where result.series_id is not null
  ),
  'Late spanning timed,Tomorrow timed',
  'continuation preserves total order without replaying page one'
);
select ok(
  (
    select pg_catalog.bool_and(
      not result.has_more and result.page_cursor is null
    )
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'agenda', date '2026-08-07', date '2026-08-10', 2,
      current_setting('kinflow_test.calendar_page_cursor')
    ) as result
  ),
  'last page closes pagination metadata'
);
select is(
  (
    with all_pages as (
      select result.occurrence_id
      from public.get_calendar_event_page(
        '20000000-0000-4000-8000-000000000101',
        'agenda', date '2026-08-07', date '2026-08-10', 2, null
      ) as result
      where result.occurrence_id is not null
      union all
      select result.occurrence_id
      from public.get_calendar_event_page(
        '20000000-0000-4000-8000-000000000101',
        'agenda', date '2026-08-07', date '2026-08-10', 2,
        current_setting('kinflow_test.calendar_page_cursor')
      ) as result
      where result.occurrence_id is not null
    )
    select pg_catalog.concat_ws(
      ':',
      pg_catalog.count(*),
      pg_catalog.count(distinct occurrence_id)
    )
    from all_pages
  ),
  '4:4',
  'two pages contain no gap or duplicate occurrence'
);
select throws_ok(
  $$select * from public.get_calendar_event_page(
    '20000000-0000-4000-8000-000000000101',
    'agenda', date '2026-08-08', date '2026-08-11', 2,
    current_setting('kinflow_test.calendar_page_cursor')
  )$$,
  'KFE02',
  'invalid calendar event input',
  'cursor cannot be reused with another range'
);
select throws_ok(
  $$select * from public.get_calendar_event_page(
    '20000000-0000-4000-8000-000000000101',
    'day', date '2026-08-07', date '2026-08-08', 2,
    current_setting('kinflow_test.calendar_page_cursor')
  )$$,
  'KFE02',
  'invalid calendar event input',
  'cursor cannot be reused with another view'
);
select throws_ok(
  $$select * from public.get_calendar_event_page(
    '20000000-0000-4000-8000-000000000101',
    'agenda', date '2026-08-07', date '2026-08-10', 2,
    pg_catalog.encode(
      pg_catalog.convert_to(
        (
          pg_catalog.convert_from(
            pg_catalog.decode(
              current_setting('kinflow_test.calendar_page_cursor'),
              'hex'
            ),
            'UTF8'
          )::jsonb || '{"extra":true}'::jsonb
        )::text,
        'UTF8'
      ),
      'hex'
    )
  )$$,
  'KFE02',
  'invalid calendar event input',
  'cursor exact-key allowlist rejects an extra field'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      pg_catalog.count(*),
      pg_catalog.count(*) filter (where result.series_id is null),
      pg_catalog.bool_and(not result.has_more),
      pg_catalog.bool_and(result.page_cursor is null)
    )
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'agenda', date '2027-02-01', date '2027-02-10', 30, null
    ) as result
  ),
  '1:1:t:t',
  'empty agenda still returns one exact metadata row'
);
select ok(
  exists (
    select 1
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'day', date '2026-08-07', date '2026-08-08', 30, null
    ) as result
    where result.title = 'All-day span'
      and result.view_local_date = date '2026-08-07'
      and result.view_local_time is null
  ),
  'all-day projection remains date-only'
);
select ok(
  exists (
    select 1
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'day', date '2026-08-07', date '2026-08-08', 30, null
    ) as result
    where result.title = 'Morning timed'
      and result.view_local_date = date '2026-08-07'
      and result.view_local_time = time '09:00'
  ),
  'timed projection exposes household-local first visible time'
);
select is(
  (
    select pg_catalog.count(*)
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'day', date '2026-08-08', date '2026-08-09', 30, null
    ) as result
    where result.series_id is not null
  ),
  3::bigint,
  'next day includes all-day span ongoing timed and next-day event'
);
select is(
  (
    select pg_catalog.string_agg(
      result.title,
      ',' order by
        result.view_local_time nulls first,
        result.occurrence_id
    )
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'day', date '2026-08-08', date '2026-08-09', 30, null
    ) as result
    where result.series_id is not null
  ),
  'All-day span,Late spanning timed,Tomorrow timed',
  'ongoing timed event is projected at day start after all-day items'
);
select is(
  (
    select pg_catalog.string_agg(result.title, ',')
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'day', date '2026-08-09', date '2026-08-10', 30, null
    ) as result
    where result.series_id is not null
  ),
  'All-day span',
  'third day retains only the all-day span'
);
select is(
  (
    select pg_catalog.count(*)
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'day', date '2026-08-10', date '2026-08-11', 30, null
    ) as result
    where result.series_id is not null
  ),
  0::bigint,
  'exclusive all-day end and timed ends do not leak into a later day'
);
select is(
  (
    select pg_catalog.count(distinct result.generated_at)
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'agenda', date '2026-08-07', date '2026-08-10', 30, null
    ) as result
  ),
  1::bigint,
  'one page shares one generated-at snapshot marker'
);
select is(
  (
    select pg_catalog.string_agg(result.title, ',')
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'agenda', date '2026-11-15', date '2026-11-16', 30, null
    ) as result
    where result.series_id is not null
  ),
  'Far timed',
  'explicit ranges include an otherwise distant event only when overlapping'
);

-- 54-63: content-free per-day month projections including multi-day counts.
select is(
  (
    select pg_catalog.count(*)
    from public.get_calendar_month_summary(
      '20000000-0000-4000-8000-000000000101',
      date '2026-08-01'
    )
  ),
  31::bigint,
  'August month summary returns exactly one row per date'
);
select is(
  (
    select pg_catalog.sum(result.event_count)
    from public.get_calendar_month_summary(
      '20000000-0000-4000-8000-000000000101',
      date '2026-08-01'
    ) as result
  ),
  7::bigint,
  'month summary counts each multi-day overlap on every visible date'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      result.event_count,
      result.all_day_count,
      result.timed_count
    )
    from public.get_calendar_month_summary(
      '20000000-0000-4000-8000-000000000101',
      date '2026-08-01'
    ) as result
    where result.day_date = date '2026-08-07'
  ),
  '3:1:2',
  'first fixture date counts one all-day and two timed events'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      result.event_count,
      result.all_day_count,
      result.timed_count
    )
    from public.get_calendar_month_summary(
      '20000000-0000-4000-8000-000000000101',
      date '2026-08-01'
    ) as result
    where result.day_date = date '2026-08-08'
  ),
  '3:1:2',
  'second fixture date counts the ongoing timed overlap once'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      result.event_count,
      result.all_day_count,
      result.timed_count
    )
    from public.get_calendar_month_summary(
      '20000000-0000-4000-8000-000000000101',
      date '2026-08-01'
    ) as result
    where result.day_date = date '2026-08-09'
  ),
  '1:1:0',
  'third fixture date retains only the all-day overlap'
);
select is(
  (
    select pg_catalog.count(*)
    from public.get_calendar_month_summary(
      '20000000-0000-4000-8000-000000000101',
      date '2026-08-01'
    ) as result
    where result.event_count = 0
  ),
  28::bigint,
  'dates without events remain explicit zero-count rows'
);
select ok(
  (
    select pg_catalog.bool_and(
      result.household_timezone = 'Asia/Seoul'
      and result.month_start_date = date '2026-08-01'
      and result.month_end_date_exclusive = date '2026-09-01'
      and result.household_local_date =
        (result.generated_at at time zone 'Asia/Seoul')::date
    )
    from public.get_calendar_month_summary(
      '20000000-0000-4000-8000-000000000101',
      date '2026-08-01'
    ) as result
  ),
  'month rows share exact authoritative context metadata'
);
select is(
  (
    select pg_catalog.count(*)
    from public.get_calendar_month_summary(
      '20000000-0000-4000-8000-000000000101',
      date '2028-02-01'
    )
  ),
  29::bigint,
  'leap February returns 29 exact date rows'
);
select ok(
  (
    select pg_catalog.bool_and(
      result.event_count = result.all_day_count + result.timed_count
      and result.event_count >= 0
      and result.all_day_count >= 0
      and result.timed_count >= 0
    )
    from public.get_calendar_month_summary(
      '20000000-0000-4000-8000-000000000101',
      date '2026-08-01'
    ) as result
  ),
  'every month count has an exact non-negative mode partition'
);
select is(
  (
    select pg_catalog.count(distinct result.generated_at)
    from public.get_calendar_month_summary(
      '20000000-0000-4000-8000-000000000101',
      date '2026-08-01'
    ) as result
  ),
  1::bigint,
  'one month response shares one generated-at marker'
);

-- 64-68: current-state suppression, same-household access, and legacy compatibility.
select lives_ok(
  $$select * from public.delete_one_time_event(
    '42000000-0000-4000-8000-000000000006',
    '20000000-0000-4000-8000-000000000101',
    (select id from public.event_series where title = 'Morning timed'),
    1
  )$$,
  'deleting a visible event succeeds through the existing command RPC'
);
select is(
  (
    select pg_catalog.count(*)
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'day', date '2026-08-07', date '2026-08-08', 30, null
    ) as result
    where result.series_id is not null
  ),
  2::bigint,
  'event page immediately suppresses a newly soft-deleted event'
);
select is(
  (
    select pg_catalog.sum(result.event_count)
    from public.get_calendar_month_summary(
      '20000000-0000-4000-8000-000000000101',
      date '2026-08-01'
    ) as result
  ),
  6::bigint,
  'month counts immediately suppress a newly deleted event'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select pg_catalog.count(*)
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'day', date '2026-08-08', date '2026-08-09', 30, null
    ) as result
    where result.series_id is not null
  ),
  3::bigint,
  'another active adult in the same household sees the same day projection'
);
select is(
  (
    select pg_catalog.count(*)
    from public.list_one_time_events(
      '20000000-0000-4000-8000-000000000101',
      100
    ) as result
    where result.series_id is not null
  ),
  4::bigint,
  'legacy one-time list remains compatible after adding view projections'
);

reset role;
select * from finish();
rollback;
