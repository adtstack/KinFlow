begin;
set constraints all deferred;

select plan(36);

-- 01-06: additive read contract and least privilege.
select has_function(
  'public',
  'preview_calendar_event_overlaps',
  array[
    'uuid', 'boolean', 'date', 'time without time zone', 'integer',
    'date', 'text', 'text', 'jsonb', 'date', 'uuid[]', 'uuid', 'uuid',
    'integer'
  ],
  'same-member Calendar overlap preview RPC exists'
);
select has_function(
  'app_private',
  'calendar_overlap_candidate_dates',
  array['date', 'jsonb', 'date', 'date'],
  'private bounded overlap recurrence helper exists'
);
select ok(
  (
    select pg_proc.prosecdef
      and pg_proc.provolatile = 's'
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_catalog.pg_proc
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'preview_calendar_event_overlaps'
  ),
  'overlap preview is stable security-definer with an empty search path'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.preview_calendar_event_overlaps(uuid,boolean,date,time without time zone,integer,date,text,text,jsonb,date,uuid[],uuid,uuid,integer)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.preview_calendar_event_overlaps(uuid,boolean,date,time without time zone,integer,date,text,text,jsonb,date,uuid[],uuid,uuid,integer)',
    'execute'
  ),
  'only authenticated clients execute the overlap preview'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.calendar_overlap_candidate_dates(date,jsonb,date,date)',
    'execute'
  )
  and not has_function_privilege(
    'service_role',
    'app_private.calendar_overlap_candidate_dates(date,jsonb,date,date)',
    'execute'
  ),
  'API roles cannot execute the private candidate helper'
);
select ok(
  not exists (
    select 1
    from pg_catalog.pg_proc
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    cross join lateral pg_catalog.unnest(pg_proc.proargnames) as argument(name)
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'preview_calendar_event_overlaps'
      and argument.name in (
        'description', 'actor_user_id', 'authenticated_user_id',
        'idempotency_key', 'correlation_id'
      )
  ),
  'preview input and output omit descriptions, actors, and command identity'
);

-- 07-12: stable authentication, validation, membership, and DST errors.
select throws_ok(
  $$select * from public.preview_calendar_event_overlaps(
    '20000000-0000-4000-8000-000000000101', false,
    date '2026-08-10', time '09:00', 60, null,
    'Asia/Seoul', 'earlier', null, date '2026-08-10',
    array['30000000-0000-4000-8000-000000000101'::uuid],
    null, null, 10
  )$$,
  'KFE01',
  'authentication required',
  'preview derives the caller from JWT'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);

select throws_ok(
  $$select * from public.preview_calendar_event_overlaps(
    null, false, date '2026-08-10', time '09:00', 60, null,
    'Asia/Seoul', 'earlier', null, date '2026-08-10',
    array['30000000-0000-4000-8000-000000000101'::uuid],
    null, null, 10
  )$$,
  'KFE02',
  'invalid calendar overlap preview input',
  'preview rejects missing household input'
);
select throws_ok(
  $$select * from public.preview_calendar_event_overlaps(
    '20000000-0000-4000-8000-000000000101', false,
    date '2026-08-10', time '09:00', 60, null,
    'Asia/Seoul', 'earlier', null, date '2026-08-10',
    array[
      '30000000-0000-4000-8000-000000000101'::uuid,
      '30000000-0000-4000-8000-000000000101'::uuid
    ], null, null, 10
  )$$,
  'KFE02',
  'invalid calendar overlap preview input',
  'preview rejects duplicate participant identities'
);
select throws_ok(
  $$select * from public.preview_calendar_event_overlaps(
    '20000000-0000-4000-8000-000000000101', false,
    date '2026-08-10', time '09:00', 60, null,
    'Asia/Seoul', 'earlier', null, date '2026-08-10',
    array['30000000-0000-4000-8000-000000000201'::uuid],
    null, null, 10
  )$$,
  'KFE02',
  'invalid calendar overlap preview input',
  'preview rejects a participant from another household'
);
select throws_ok(
  $$select * from public.preview_calendar_event_overlaps(
    '20000000-0000-4000-8000-000000000101', false,
    date '2026-08-10', time '09:00', 60, null,
    'Asia/Seoul', 'earlier', null, date '2026-08-10',
    array['30000000-0000-4000-8000-000000000101'::uuid],
    '40000000-0000-4000-8000-000000000001',
    '50000000-0000-4000-8000-000000000001', 10
  )$$,
  'KFE02',
  'invalid calendar overlap preview input',
  'preview accepts at most one self-exclusion scope'
);
select throws_ok(
  $$select * from public.preview_calendar_event_overlaps(
    '20000000-0000-4000-8000-000000000101', false,
    date '2026-03-08', time '02:30', 60, null,
    'America/New_York', 'earlier', null, date '2026-03-08',
    array['30000000-0000-4000-8000-000000000101'::uuid],
    null, null, 10
  )$$,
  'KFE06',
  'nonexistent calendar local time',
  'preview preserves the server DST gap failure contract'
);

-- 13-15: authoritative existing fixtures.
select lives_ok(
  $$select * from public.create_one_time_event(
    '49000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000101',
    'Timed A', 'private timed description', false,
    date '2026-08-10', time '09:00', 60, null,
    'Asia/Seoul', 'earlier',
    array['30000000-0000-4000-8000-000000000101'::uuid]
  )$$,
  'first same-member timed event is created'
);
select lives_ok(
  $$select * from public.create_one_time_event(
    '49000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000101',
    'Timed A next week', null, false,
    date '2026-08-17', time '09:15', 30, null,
    'Asia/Seoul', 'earlier',
    array['30000000-0000-4000-8000-000000000101'::uuid]
  )$$,
  'second weekly same-member timed event is created'
);
select lives_ok(
  $$select * from public.create_one_time_event(
    '49000000-0000-4000-8000-000000000003',
    '20000000-0000-4000-8000-000000000101',
    'All-day A', null, true,
    date '2026-08-11', null, null, date '2026-08-12',
    null, null,
    array['30000000-0000-4000-8000-000000000101'::uuid]
  )$$,
  'same-member all-day event is created'
);

reset role;
select set_config(
  'kinflow_test.overlap_series_id',
  (select id::text from public.event_series where title = 'Timed A'),
  true
);
select set_config(
  'kinflow_test.overlap_occurrence_id',
  (
    select occurrence.id::text
    from public.event_occurrences as occurrence
    join public.event_series as series on series.id = occurrence.series_id
    where series.title = 'Timed A'
  ),
  true
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);

-- 16-24: half-open time modes, member intersection, and self-exclusion.
select is(
  (
    select total_conflict_count
    from public.preview_calendar_event_overlaps(
      '20000000-0000-4000-8000-000000000101', false,
      date '2026-08-10', time '09:30', 30, null,
      'Asia/Seoul', 'earlier', null, date '2026-08-10',
      array['30000000-0000-4000-8000-000000000101'::uuid],
      null, null, 10
    ) limit 1
  ),
  1,
  'timed canonical instant ranges overlap for the same member'
);
select is(
  (
    select total_conflict_count
    from public.preview_calendar_event_overlaps(
      '20000000-0000-4000-8000-000000000101', false,
      date '2026-08-10', time '10:00', 30, null,
      'Asia/Seoul', 'earlier', null, date '2026-08-10',
      array['30000000-0000-4000-8000-000000000101'::uuid],
      null, null, 10
    ) limit 1
  ),
  0,
  'touching timed half-open boundaries do not overlap'
);
select is(
  (
    select total_conflict_count
    from public.preview_calendar_event_overlaps(
      '20000000-0000-4000-8000-000000000101', false,
      date '2026-08-10', time '09:30', 30, null,
      'Asia/Seoul', 'earlier', null, date '2026-08-10',
      array['30000000-0000-4000-8000-000000000102'::uuid],
      null, null, 10
    ) limit 1
  ),
  0,
  'time overlap without a shared member is not a conflict hint'
);
select is(
  (
    select total_conflict_count
    from public.preview_calendar_event_overlaps(
      '20000000-0000-4000-8000-000000000101', true,
      date '2026-08-11', null, null, date '2026-08-12',
      null, null, null, date '2026-08-11',
      array['30000000-0000-4000-8000-000000000101'::uuid],
      null, null, 10
    ) limit 1
  ),
  1,
  'all-day date ranges overlap for the same member'
);
select is(
  (
    select total_conflict_count
    from public.preview_calendar_event_overlaps(
      '20000000-0000-4000-8000-000000000101', true,
      date '2026-08-10', null, null, date '2026-08-11',
      null, null, null, date '2026-08-10',
      array['30000000-0000-4000-8000-000000000101'::uuid],
      null, null, 10
    ) limit 1
  ),
  1,
  'candidate all-day boundaries cross-check existing timed instants'
);
select is(
  (
    select total_conflict_count
    from public.preview_calendar_event_overlaps(
      '20000000-0000-4000-8000-000000000101', false,
      date '2026-08-11', time '12:00', 60, null,
      'Asia/Seoul', 'earlier', null, date '2026-08-11',
      array['30000000-0000-4000-8000-000000000101'::uuid],
      null, null, 10
    ) limit 1
  ),
  1,
  'candidate timed instants cross-check existing all-day boundaries'
);
select is(
  (
    select conflicting_title || ':'
      || pg_catalog.array_to_string(
        conflicting_participant_display_names,
        ','
      )
    from public.preview_calendar_event_overlaps(
      '20000000-0000-4000-8000-000000000101', false,
      date '2026-08-10', time '09:30', 30, null,
      'Asia/Seoul', 'earlier', null, date '2026-08-10',
      array['30000000-0000-4000-8000-000000000101'::uuid],
      null, null, 10
    )
    where conflicting_occurrence_id is not null
  ),
  'Timed A:Adult A',
  'detail returns only the authorized event title and intersecting members'
);
select is(
  (
    select total_conflict_count
    from public.preview_calendar_event_overlaps(
      '20000000-0000-4000-8000-000000000101', false,
      date '2026-08-10', time '09:30', 30, null,
      'Asia/Seoul', 'earlier', null, date '2026-08-10',
      array['30000000-0000-4000-8000-000000000101'::uuid],
      current_setting('kinflow_test.overlap_series_id')::uuid,
      null, 10
    ) limit 1
  ),
  0,
  'one-time edit can exclude its own series without hiding other events'
);
select is(
  (
    select total_conflict_count
    from public.preview_calendar_event_overlaps(
      '20000000-0000-4000-8000-000000000101', false,
      date '2026-08-10', time '09:30', 30, null,
      'Asia/Seoul', 'earlier', null, date '2026-08-10',
      array['30000000-0000-4000-8000-000000000101'::uuid],
      null, current_setting('kinflow_test.overlap_occurrence_id')::uuid, 10
    ) limit 1
  ),
  0,
  'single-occurrence edit can exclude only its own occurrence'
);

-- 25-29: bounded recurrence expansion uses the canonical local anchor.
select is(
  (
    select candidate_occurrence_count
    from public.preview_calendar_event_overlaps(
      '20000000-0000-4000-8000-000000000101', false,
      date '2026-08-10', time '09:00', 60, null,
      'Asia/Seoul', 'earlier',
      '{"frequency":"weekly","interval":1,"weekdays":["MO"],"end":{"type":"never"}}',
      date '2026-08-10',
      array['30000000-0000-4000-8000-000000000101'::uuid],
      null, null, 10
    ) limit 1
  ),
  53,
  'weekly preview expands at most the same inclusive 366-day horizon'
);
select is(
  (
    select total_conflict_count
    from public.preview_calendar_event_overlaps(
      '20000000-0000-4000-8000-000000000101', false,
      date '2026-08-10', time '09:00', 60, null,
      'Asia/Seoul', 'earlier',
      '{"frequency":"weekly","interval":1,"weekdays":["MO"],"end":{"type":"never"}}',
      date '2026-08-10',
      array['30000000-0000-4000-8000-000000000101'::uuid],
      null, null, 10
    ) limit 1
  ),
  2,
  'weekly candidate occurrences find each existing same-member pair'
);
select is(
  (
    select pg_catalog.string_agg(
      candidate_local_start_date::text,
      ',' order by candidate_local_start_date
    )
    from public.preview_calendar_event_overlaps(
      '20000000-0000-4000-8000-000000000101', false,
      date '2026-08-10', time '09:00', 60, null,
      'Asia/Seoul', 'earlier',
      '{"frequency":"weekly","interval":1,"weekdays":["MO"],"end":{"type":"never"}}',
      date '2026-08-10',
      array['30000000-0000-4000-8000-000000000101'::uuid],
      null, null, 10
    )
    where conflicting_occurrence_id is not null
  ),
  '2026-08-10,2026-08-17',
  'recurring conflict details retain deterministic candidate local dates'
);
select is(
  (
    select candidate_occurrence_count
    from public.preview_calendar_event_overlaps(
      '20000000-0000-4000-8000-000000000101', false,
      date '2026-08-10', time '09:00', 60, null,
      'Asia/Seoul', 'earlier',
      '{"frequency":"weekly","interval":1,"weekdays":["MO"],"end":{"type":"count","count":1}}',
      date '2026-08-10',
      array['30000000-0000-4000-8000-000000000101'::uuid],
      null, null, 10
    ) limit 1
  ),
  1,
  'recurrence count end bounds candidate occurrences'
);
select is(
  (
    select total_conflict_count
    from public.preview_calendar_event_overlaps(
      '20000000-0000-4000-8000-000000000101', false,
      date '2026-08-10', time '09:00', 60, null,
      'Asia/Seoul', 'earlier',
      '{"frequency":"weekly","interval":1,"weekdays":["MO"],"end":{"type":"count","count":1}}',
      date '2026-08-10',
      array['30000000-0000-4000-8000-000000000101'::uuid],
      null, null, 10
    ) limit 1
  ),
  1,
  'recurrence count end excludes later overlaps'
);

-- 30-33: deterministic detail cap preserves the full hint count.
select lives_ok(
  $$select * from public.create_one_time_event(
    '49000000-0000-4000-8000-000000000004',
    '20000000-0000-4000-8000-000000000101',
    'Timed A second', null, false,
    date '2026-08-10', time '09:10', 20, null,
    'Asia/Seoul', 'earlier',
    array['30000000-0000-4000-8000-000000000101'::uuid]
  )$$,
  'second overlapping detail is created'
);
select lives_ok(
  $$select * from public.create_one_time_event(
    '49000000-0000-4000-8000-000000000005',
    '20000000-0000-4000-8000-000000000101',
    'Timed A third', null, false,
    date '2026-08-10', time '09:20', 20, null,
    'Asia/Seoul', 'earlier',
    array['30000000-0000-4000-8000-000000000101'::uuid]
  )$$,
  'third overlapping detail is created'
);
select ok(
  (
    select total_conflict_count = 3
      and truncated
      and pg_catalog.count(*) over () = 1
    from public.preview_calendar_event_overlaps(
      '20000000-0000-4000-8000-000000000101', false,
      date '2026-08-10', time '09:00', 60, null,
      'Asia/Seoul', 'earlier', null, date '2026-08-10',
      array['30000000-0000-4000-8000-000000000101'::uuid],
      null, null, 1
    )
  ),
  'detail limit truncates rows while preserving the full conflict count'
);
select is(
  (
    select conflicting_title
    from public.preview_calendar_event_overlaps(
      '20000000-0000-4000-8000-000000000101', false,
      date '2026-08-10', time '09:00', 60, null,
      'Asia/Seoul', 'earlier', null, date '2026-08-10',
      array['30000000-0000-4000-8000-000000000101'::uuid],
      null, null, 1
    )
  ),
  'Timed A',
  'bounded details retain deterministic earliest-start ordering'
);

-- 34-36: household isolation and removal lifecycle fail closed.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$select * from public.preview_calendar_event_overlaps(
    '20000000-0000-4000-8000-000000000101', false,
    date '2026-08-10', time '09:00', 60, null,
    'Asia/Seoul', 'earlier', null, date '2026-08-10',
    array['30000000-0000-4000-8000-000000000101'::uuid],
    null, null, 10
  )$$,
  'KFE03',
  'calendar event not found or forbidden',
  'another household cannot probe overlap hints'
);

reset role;
update public.household_members
set removed_at = pg_catalog.now()
where id = '30000000-0000-4000-8000-000000000102';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$select * from public.preview_calendar_event_overlaps(
    '20000000-0000-4000-8000-000000000101', false,
    date '2026-08-10', time '09:00', 60, null,
    'Asia/Seoul', 'earlier', null, date '2026-08-10',
    array['30000000-0000-4000-8000-000000000102'::uuid],
    null, null, 10
  )$$,
  'KFE02',
  'invalid calendar overlap preview input',
  'removed members cannot remain candidate participants'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select throws_ok(
  $$select * from public.preview_calendar_event_overlaps(
    '20000000-0000-4000-8000-000000000101', false,
    date '2026-08-10', time '09:00', 60, null,
    'Asia/Seoul', 'earlier', null, date '2026-08-10',
    array['30000000-0000-4000-8000-000000000101'::uuid],
    null, null, 10
  )$$,
  'KFE03',
  'calendar event not found or forbidden',
  'removed callers cannot execute overlap previews'
);

select * from finish();
rollback;
