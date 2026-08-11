begin;
set constraints all deferred;

select plan(81);

-- Schema, compatibility, least privilege, and immutable identity.
select has_function(
  'public',
  'create_recurring_calendar_event',
  array[
    'uuid', 'uuid', 'text', 'text', 'boolean', 'date',
    'time without time zone', 'integer', 'date', 'text', 'text',
    'jsonb', 'uuid[]'
  ],
  'recurring Calendar create command exists'
);
select has_function(
  'app_private',
  'calendar_revision_candidate_dates',
  array['uuid', 'uuid', 'uuid', 'date', 'date'],
  'canonical Calendar recurrence candidate helper exists'
);
select has_function(
  'app_private',
  'materialize_calendar_revision_window',
  array['uuid', 'uuid', 'uuid', 'date', 'date'],
  'bounded Calendar materializer exists'
);
select has_function(
  'app_private',
  'calendar_occurrence_snapshot',
  array['uuid', 'uuid'],
  'mixed occurrence snapshot helper exists'
);
select has_function(
  'public',
  'get_calendar_event_page_v2',
  array['uuid', 'text', 'date', 'date', 'integer', 'text'],
  'mixed Calendar event page v2 exists'
);
select has_function(
  'public',
  'get_calendar_month_summary_v2',
  array['uuid', 'date'],
  'mixed Calendar month summary v2 exists'
);
select has_table(
  'public',
  'event_revision_participants',
  'revision participant snapshots exist'
);
select has_table(
  'app_private',
  'calendar_recurring_command_requests',
  'private recurring command state exists'
);
select has_column(
  'public',
  'event_occurrences',
  'recurrence_local_start_date',
  'occurrences retain a recurrence slot date'
);
select col_not_null(
  'public',
  'event_occurrences',
  'recurrence_local_start_date',
  'the recurrence slot date is required'
);
select has_trigger(
  'public',
  'event_series_revisions',
  'event_revisions_immutable',
  'Calendar revisions reject in-place updates'
);
select has_trigger(
  'public',
  'event_occurrences',
  'event_occurrence_recurrence_identity_immutable',
  'Calendar occurrence recurrence identity is immutable'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where pg_constraint.conname = 'event_recurring_revision_snapshot_ck'
      and pg_constraint.convalidated
  ),
  'recurring revision validation is installed and validated'
);
select ok(
  (
    select pg_class.relrowsecurity and pg_class.relforcerowsecurity
    from pg_catalog.pg_class
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'event_revision_participants'
  ),
  'revision participants enable and force RLS'
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
        'create_recurring_calendar_event',
        'get_calendar_event_page_v2',
        'get_calendar_month_summary_v2'
      )
  ),
  'public recurring Calendar functions are security-definer with empty paths'
);
select ok(
  (
    select pg_catalog.bool_and(pg_proc.provolatile = 's')
    from pg_catalog.pg_proc
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname in (
        'get_calendar_event_page_v2',
        'get_calendar_month_summary_v2'
      )
  ),
  'mixed Calendar v2 reads are stable'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.create_recurring_calendar_event(uuid,uuid,text,text,boolean,date,time without time zone,integer,date,text,text,jsonb,uuid[])',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.get_calendar_event_page_v2(uuid,text,date,date,integer,text)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.get_calendar_month_summary_v2(uuid,date)',
    'execute'
  ),
  'authenticated clients can execute mediated recurring functions'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.create_recurring_calendar_event(uuid,uuid,text,text,boolean,date,time without time zone,integer,date,text,text,jsonb,uuid[])',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.get_calendar_event_page_v2(uuid,text,date,date,integer,text)',
    'execute'
  ),
  'anonymous clients cannot execute recurring Calendar functions'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.calendar_revision_candidate_dates(uuid,uuid,uuid,date,date)',
    'execute'
  )
  and not has_function_privilege(
    'service_role',
    'app_private.materialize_calendar_revision_window(uuid,uuid,uuid,date,date)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'app_private.calendar_occurrence_snapshot(uuid,uuid)',
    'execute'
  ),
  'API roles cannot execute private recurrence helpers'
);
select ok(
  has_table_privilege(
    'authenticated',
    'public.event_revision_participants',
    'select'
  )
  and not has_table_privilege(
    'authenticated',
    'public.event_revision_participants',
    'insert,update,delete'
  ),
  'clients have read-only access to authorized revision participants'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.calendar_recurring_command_requests',
    'select'
  )
  and not has_table_privilege(
    'service_role',
    'app_private.calendar_recurring_command_requests',
    'select'
  ),
  'API roles cannot inspect recurring command state'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'calendar_recurring_command_requests'
      and column_name in (
        'title', 'description', 'display_name', 'participant_member_ids'
      )
  ),
  'recurring command state does not duplicate content or participant lists'
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
  'N-1 one-time Calendar view signatures remain available'
);

-- Strict locale-independent supported recurrence subset.
select is(
  app_private.is_valid_calendar_recurrence_rule(
    '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
  ),
  true,
  'daily recurrence is valid'
);
select is(
  app_private.is_valid_calendar_recurrence_rule(
    '{"frequency":"weekly","interval":2,"weekdays":["MO","WE"],"end":{"type":"count","count":8}}'
  ),
  true,
  'weekly multi-day recurrence is valid'
);
select is(
  app_private.is_valid_calendar_recurrence_rule(
    '{"frequency":"monthly","interval":1,"monthDay":31,"end":{"type":"until","localDate":"2027-12-31"}}'
  ),
  true,
  'monthly recurrence with an until boundary is valid'
);
select is(
  app_private.is_valid_calendar_recurrence_rule(
    '{"frequency":"daily","interval":1,"end":{"type":"never"},"extra":true}'
  ),
  false,
  'unknown recurrence fields are rejected'
);
select is(
  app_private.is_valid_calendar_recurrence_rule(
    '{"frequency":"daily","interval":1.5,"end":{"type":"never"}}'
  ),
  false,
  'fractional recurrence intervals are rejected'
);
select is(
  app_private.is_valid_calendar_recurrence_rule(
    '{"frequency":"weekly","interval":1,"weekdays":["MO","MO"],"end":{"type":"never"}}'
  ),
  false,
  'duplicate weekdays are rejected'
);
select is(
  app_private.is_valid_calendar_recurrence_rule(
    '{"frequency":"weekly","interval":1,"weekdays":["월"],"end":{"type":"never"}}'
  ),
  false,
  'locale-dependent weekday strings are rejected'
);
select is(
  app_private.is_valid_calendar_recurrence_rule(
    '{"frequency":"monthly","interval":1,"monthDay":32,"end":{"type":"never"}}'
  ),
  false,
  'out-of-range month days are rejected'
);
select is(
  app_private.is_valid_calendar_recurrence_rule(
    '{"frequency":"daily","interval":1,"end":{"type":"until","localDate":"2027-02-30"}}'
  ),
  false,
  'invalid calendar end dates are rejected'
);
select is(
  app_private.is_valid_calendar_recurrence_rule(
    '{"frequency":"daily","interval":1,"end":{"type":"never","extra":true}}'
  ),
  false,
  'unknown recurrence end fields are rejected'
);

-- Authentication, input shape, anchor, participant, and future gap checks.
select throws_ok(
  $$
    select * from public.create_recurring_calendar_event(
      '43000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'No auth', null, false, date '2026-03-01', time '08:00', 60,
      null, 'America/Los_Angeles', 'earlier',
      '{"frequency":"weekly","interval":1,"weekdays":["SU"],"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE01',
  'authentication required',
  'recurring create derives actor identity from JWT'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.create_recurring_calendar_event(
      '43000000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      'Bad anchor', null, false, date '2026-03-01', time '08:00', 60,
      null, 'America/Los_Angeles', 'earlier',
      '{"frequency":"weekly","interval":1,"weekdays":["MO"],"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE07',
  'invalid calendar recurrence rule',
  'weekly recurrence must include the anchor weekday'
);
select throws_ok(
  $$
    select * from public.create_recurring_calendar_event(
      '43000000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      'Polluted all day', null, true, date '2026-03-01', null, null,
      date '2026-03-02', 'Asia/Seoul', null,
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE07',
  'invalid calendar recurrence rule',
  'all-day recurrence rejects timezone pollution'
);
select throws_ok(
  $$
    select * from public.create_recurring_calendar_event(
      '43000000-0000-4000-8000-000000000004',
      '20000000-0000-4000-8000-000000000101',
      'Duplicate people', null, true, date '2026-03-01', null, null,
      date '2026-03-02', null, null,
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array[
        '30000000-0000-4000-8000-000000000101'::uuid,
        '30000000-0000-4000-8000-000000000101'::uuid
      ]
    )
  $$,
  'KFE07',
  'invalid calendar recurrence rule',
  'duplicate participant IDs are rejected'
);
select throws_ok(
  $$
    select * from public.create_recurring_calendar_event(
      '43000000-0000-4000-8000-000000000005',
      '20000000-0000-4000-8000-000000000101',
      'Foreign participant', null, true, date '2026-03-01', null, null,
      date '2026-03-02', null, null,
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000201'::uuid]
    )
  $$,
  'KFE03',
  'calendar event not found or forbidden',
  'cross-household participants are rejected'
);
select throws_ok(
  $$
    select * from public.create_recurring_calendar_event(
      '43000000-0000-4000-8000-000000000006',
      '20000000-0000-4000-8000-000000000101',
      'Future gap', null, false, date '2026-03-01', time '02:30', 60,
      null, 'America/Los_Angeles', 'earlier',
      '{"frequency":"weekly","interval":1,"weekdays":["SU"],"end":{"type":"count","count":3}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE06',
  'nonexistent calendar local time',
  'a future DST gap fails the recurring command atomically'
);
select throws_ok(
  $$
    select * from public.create_recurring_calendar_event(
      '43000000-0000-4000-8000-000000000007',
      '20000000-0000-4000-8000-000000000101',
      'Unknown zone', null, false, date '2026-03-01', time '08:00', 60,
      null, 'America/Not_A_Zone', 'earlier',
      '{"frequency":"weekly","interval":1,"weekdays":["SU"],"end":{"type":"count","count":3}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE07',
  'invalid calendar recurrence rule',
  'unknown timezones fail closed before persistence'
);

-- Weekly timed series spans both DST transitions with local wall time intact.
select is(
  (
    select created
    from public.create_recurring_calendar_event(
      '43000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      '  Weekly family call  ', '  Weekly notes  ', false,
      date '2026-03-01', time '08:00', 60, null,
      'America/Los_Angeles', 'earlier',
      '{"frequency":"weekly","interval":1,"weekdays":["SU"],"end":{"type":"count","count":40}}',
      array[
        '30000000-0000-4000-8000-000000000102'::uuid,
        '30000000-0000-4000-8000-000000000101'::uuid
      ]
    )
  ),
  true,
  'an active member can create a weekly timed series'
);
select set_config(
  'kinflow.test.calendar_recurring_series',
  (
    select series.id::text
    from public.event_series as series
    where series.title = 'Weekly family call'
  ),
  true
);
select set_config(
  'kinflow.test.calendar_recurring_revision',
  (
    select series.active_revision_id::text
    from public.event_series as series
    where series.id = current_setting(
      'kinflow.test.calendar_recurring_series'
    )::uuid
  ),
  true
);
reset role;

select is(
  (
    select pg_catalog.count(*)
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.calendar_recurring_series'
    )::uuid
  ),
  40::bigint,
  'count-bounded weekly materialization creates exactly 40 occurrences'
);
select ok(
  exists (
    select 1
    from public.event_series_revisions as revision
    where revision.id = current_setting(
      'kinflow.test.calendar_recurring_revision'
    )::uuid
      and revision.snapshot_title = 'Weekly family call'
      and revision.snapshot_description = 'Weekly notes'
      and revision.snapshot_timezone = 'America/Los_Angeles'
      and not revision.snapshot_is_all_day
      and revision.recurrence_rule->>'frequency' = 'weekly'
  ),
  'immutable revision stores normalized content timezone and recurrence intent'
);
select is(
  (
    select pg_catalog.count(*)
    from public.event_participants as participant
    where participant.series_id = current_setting(
      'kinflow.test.calendar_recurring_series'
    )::uuid
  ),
  2::bigint,
  'active series participant projection keeps the exact set'
);
select is(
  (
    select pg_catalog.count(*)
    from public.event_revision_participants as participant
    where participant.revision_id = current_setting(
      'kinflow.test.calendar_recurring_revision'
    )::uuid
  ),
  2::bigint,
  'revision participant history keeps the exact set'
);
select is(
  (
    select pg_catalog.count(distinct occurrence.occurrence_key)
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.calendar_recurring_series'
    )::uuid
  ),
  40::bigint,
  'every materialized occurrence key is unique'
);
select ok(
  not exists (
    select 1
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.calendar_recurring_series'
    )::uuid
      and (occurrence.starts_at at time zone occurrence.timezone)::time
        <> time '08:00'
  ),
  'each occurrence preserves the 08:00 local wall-time intent'
);
select is(
  (
    select pg_catalog.count(distinct (
      occurrence.dst_adjustment->>'utcOffsetSeconds'
    )::integer)
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.calendar_recurring_series'
    )::uuid
  ),
  2::bigint,
  'server materialization records both DST offsets across the series'
);
select ok(
  not exists (
    select 1
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.calendar_recurring_series'
    )::uuid
      and occurrence.ends_at - occurrence.starts_at <> interval '60 minutes'
  ),
  'every timed occurrence retains the requested duration'
);
select ok(
  exists (
    select 1
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.calendar_recurring_series'
    )::uuid
      and occurrence.recurrence_local_start_date = date '2026-03-01'
      and occurrence.local_start_date = date '2026-03-01'
      and occurrence.occurrence_key = occurrence.series_id::text || ':2026-03-01'
  ),
  'the first occurrence retains its canonical recurrence slot identity'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select created
    from public.create_recurring_calendar_event(
      '43000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'Weekly family call', 'Weekly notes', false,
      date '2026-03-01', time '08:00', 60, null,
      'America/Los_Angeles', 'earlier',
      '{"frequency":"weekly","interval":1,"weekdays":["SU"],"end":{"type":"count","count":40}}',
      array[
        '30000000-0000-4000-8000-000000000101'::uuid,
        '30000000-0000-4000-8000-000000000102'::uuid
      ]
    )
  ),
  false,
  'exact idempotent replay returns the original recurring result'
);
reset role;
select is(
  (
    select pg_catalog.count(*)
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.calendar_recurring_series'
    )::uuid
  ),
  40::bigint,
  'idempotent replay does not duplicate occurrences'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.create_recurring_calendar_event(
      '43000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'Changed replay', null, false,
      date '2026-03-01', time '08:00', 60, null,
      'America/Los_Angeles', 'earlier',
      '{"frequency":"weekly","interval":1,"weekdays":["SU"],"end":{"type":"count","count":40}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE04',
  'idempotency key reused with different calendar input',
  'idempotency keys cannot be reused with changed input'
);
reset role;
select is(
  app_private.materialize_calendar_revision_window(
    '20000000-0000-4000-8000-000000000101',
    current_setting('kinflow.test.calendar_recurring_series')::uuid,
    current_setting('kinflow.test.calendar_recurring_revision')::uuid,
    date '2026-03-01',
    date '2027-03-01'
  ),
  0,
  'materialization replay is idempotent'
);
select throws_ok(
  format(
    'update public.event_series_revisions set snapshot_title = %L where id = %L',
    'mutated',
    current_setting('kinflow.test.calendar_recurring_revision')
  ),
  '55000',
  'calendar event revisions are immutable',
  'revision content cannot be changed in place'
);
select throws_ok(
  format(
    'update public.event_occurrences set recurrence_local_start_date = recurrence_local_start_date + 1 where series_id = %L',
    current_setting('kinflow.test.calendar_recurring_series')
  ),
  '55000',
  'calendar occurrence recurrence identity is immutable',
  'occurrence recurrence slot identity cannot be changed'
);

-- A recurring occurrence keeps the explicit earlier/later fold choice.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select created
    from public.create_recurring_calendar_event(
      '43000000-0000-4000-8000-000000000151',
      '20000000-0000-4000-8000-000000000101',
      'Fold earlier', null, false,
      date '2026-11-01', time '01:30', 60, null,
      'America/Los_Angeles', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  ),
  true,
  'recurring create accepts the explicit earlier fold policy'
);
select is(
  (
    select created
    from public.create_recurring_calendar_event(
      '43000000-0000-4000-8000-000000000152',
      '20000000-0000-4000-8000-000000000101',
      'Fold later', null, false,
      date '2026-11-01', time '01:30', 60, null,
      'America/Los_Angeles', 'later',
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  ),
  true,
  'recurring create accepts the explicit later fold policy'
);
reset role;
select is(
  (
    select pg_catalog.string_agg(
      pg_catalog.concat_ws(
        ':',
        series.title,
        pg_catalog.to_char(
          occurrence.starts_at at time zone 'UTC',
          'YYYY-MM-DD"T"HH24:MI:SS"Z"'
        ),
        occurrence.dst_adjustment->>'utcOffsetSeconds',
        occurrence.dst_adjustment->>'resolution',
        pg_catalog.to_char(
          occurrence.starts_at at time zone occurrence.timezone,
          'HH24:MI'
        )
      ),
      ',' order by series.title
    )
    from public.event_series as series
    join public.event_occurrences as occurrence
      on occurrence.household_id = series.household_id
     and occurrence.series_id = series.id
    where series.title in ('Fold earlier', 'Fold later')
  ),
  'Fold earlier:2026-11-01T08:30:00Z:-25200:overlap_earlier:01:30,Fold later:2026-11-01T09:30:00Z:-28800:overlap_later:01:30',
  'materialized fold occurrences preserve policy, exact instant, offset, and wall time'
);

-- Mixed v2 views expose recurring metadata while v1 remains one-time-only.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select pg_catalog.count(occurrence_id)
    from public.get_calendar_event_page_v2(
      '20000000-0000-4000-8000-000000000101',
      'day', date '2026-03-02', date '2026-03-03', 30, null
    )
  ),
  1::bigint,
  'v2 day view returns a recurring occurrence'
);
select is(
  (
    select pg_catalog.count(occurrence_id)
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'day', date '2026-03-02', date '2026-03-03', 30, null
    )
  ),
  0::bigint,
  'legacy v1 day view retains one-time-only behavior'
);
select ok(
  exists (
    select 1
    from public.get_calendar_event_page_v2(
      '20000000-0000-4000-8000-000000000101',
      'day', date '2026-03-02', date '2026-03-03', 30, null
    ) as page
    where page.recurrence_rule->>'frequency' = 'weekly'
      and page.recurrence_local_start_date = date '2026-03-01'
      and page.revision_number = 1
      and not page.is_exception
  ),
  'v2 projection exposes strict recurrence source metadata'
);
select is(
  (
    select summary.event_count
    from public.get_calendar_month_summary_v2(
      '20000000-0000-4000-8000-000000000101',
      date '2026-03-01'
    ) as summary
    where summary.day_date = date '2026-03-02'
  ),
  1,
  'v2 month summary counts the recurring occurrence'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$
    select * from public.get_calendar_event_page_v2(
      '20000000-0000-4000-8000-000000000101',
      'day', date '2026-03-02', date '2026-03-03', 30, null
    )
  $$,
  'KFE03',
  'calendar event not found or forbidden',
  'outsiders cannot read mixed Calendar views'
);

-- Monthly day 31 skips absent dates and preserves a multi-day all-day span.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select created
    from public.create_recurring_calendar_event(
      '43000000-0000-4000-8000-000000000201',
      '20000000-0000-4000-8000-000000000101',
      'Month end trip', null, true,
      date '2026-01-31', null, null, date '2026-02-03', null, null,
      '{"frequency":"monthly","interval":1,"monthDay":31,"end":{"type":"count","count":4}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  ),
  true,
  'an all-day month-end series is created'
);
select set_config(
  'kinflow.test.calendar_monthly_series',
  (
    select series.id::text
    from public.event_series as series
    where series.title = 'Month end trip'
  ),
  true
);
reset role;
select is(
  (
    select pg_catalog.count(*)
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.calendar_monthly_series'
    )::uuid
  ),
  4::bigint,
  'monthly count means four actual materialized dates'
);
select is(
  (
    select pg_catalog.array_agg(
      occurrence.recurrence_local_start_date
      order by occurrence.recurrence_local_start_date
    )
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.calendar_monthly_series'
    )::uuid
  ),
  array[
    date '2026-01-31', date '2026-03-31',
    date '2026-05-31', date '2026-07-31'
  ],
  'monthly day 31 skips months without that local date'
);
select ok(
  not exists (
    select 1
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.calendar_monthly_series'
    )::uuid
      and occurrence.all_day_end_date_exclusive
        - occurrence.local_start_date <> 3
  ),
  'every all-day occurrence preserves its three-day half-open span'
);
select ok(
  not exists (
    select 1
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.calendar_monthly_series'
    )::uuid
      and (
        occurrence.starts_at is not null
        or occurrence.ends_at is not null
        or occurrence.timezone is not null
        or occurrence.dst_adjustment is not null
      )
  ),
  'all-day recurrence remains date-only without timezone or instant fields'
);

-- Until bounds, mixed one-time ordering/counts, cursor v2, and private records.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select materialized_count
    from public.create_recurring_calendar_event(
      '43000000-0000-4000-8000-000000000301',
      '20000000-0000-4000-8000-000000000101',
      'Three day routine', null, true,
      date '2026-08-01', null, null, date '2026-08-02', null, null,
      '{"frequency":"daily","interval":1,"end":{"type":"until","localDate":"2026-08-03"}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  ),
  3,
  'inclusive until boundary materializes exactly three dates'
);
select is(
  (
    select created
    from public.create_one_time_event(
      '43000000-0000-4000-8000-000000000302',
      '20000000-0000-4000-8000-000000000101',
      'One-time on recurring day', null, false,
      date '2026-03-01', time '09:00', 30, null,
      'America/Los_Angeles', 'earlier',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  ),
  true,
  'one-time event remains creatable after recurrence migration'
);
select is(
  (
    select pg_catalog.count(occurrence_id)
    from public.get_calendar_event_page_v2(
      '20000000-0000-4000-8000-000000000101',
      'day', date '2026-03-02', date '2026-03-03', 30, null
    )
  ),
  2::bigint,
  'v2 day view mixes one-time and recurring occurrences'
);
select is(
  (
    select pg_catalog.count(occurrence_id)
    from public.get_calendar_event_page(
      '20000000-0000-4000-8000-000000000101',
      'day', date '2026-03-02', date '2026-03-03', 30, null
    )
  ),
  1::bigint,
  'v1 day view still exposes the one-time occurrence'
);
select is(
  (
    select pg_catalog.array_agg(page.title order by page.view_local_time)
    from public.get_calendar_event_page_v2(
      '20000000-0000-4000-8000-000000000101',
      'day', date '2026-03-02', date '2026-03-03', 30, null
    ) as page
    where page.occurrence_id is not null
  ),
  array['Weekly family call', 'One-time on recurring day']::text[],
  'mixed timed occurrences use deterministic local-time ordering'
);
select is(
  (
    select summary.event_count
    from public.get_calendar_month_summary_v2(
      '20000000-0000-4000-8000-000000000101', date '2026-03-01'
    ) as summary
    where summary.day_date = date '2026-03-02'
  ),
  2,
  'mixed month summary counts both occurrence sources'
);
select ok(
  (
    select page.has_more and page.page_cursor is not null
    from public.get_calendar_event_page_v2(
      '20000000-0000-4000-8000-000000000101',
      'day', date '2026-03-02', date '2026-03-03', 1, null
    ) as page
    limit 1
  ),
  'v2 keyset first page emits a continuation cursor'
);
select set_config(
  'kinflow.test.calendar_v2_cursor',
  (
    select page.page_cursor
    from public.get_calendar_event_page_v2(
      '20000000-0000-4000-8000-000000000101',
      'day', date '2026-03-02', date '2026-03-03', 1, null
    ) as page
    limit 1
  ),
  true
);
select is(
  (
    select pg_catalog.count(occurrence_id)
    from public.get_calendar_event_page_v2(
      '20000000-0000-4000-8000-000000000101',
      'day', date '2026-03-02', date '2026-03-03', 1,
      current_setting('kinflow.test.calendar_v2_cursor')
    )
  ),
  1::bigint,
  'v2 cursor returns the next distinct occurrence'
);
reset role;
select is(
  (
    select pg_catalog.count(*)
    from app_private.calendar_recurring_command_requests
  ),
  5::bigint,
  'only successful logical recurring commands persist private idempotency rows'
);
select is(
  (
    select pg_catalog.count(*)
    from app_private.calendar_audit_events as audit
    join public.event_series as series on series.id = audit.series_id
    where series.active_revision_id in (
      select revision.id
      from public.event_series_revisions as revision
      where revision.recurrence_rule is not null
    )
      and audit.action = 'calendar.created'
  ),
  5::bigint,
  'each recurring series writes one content-free creation audit record'
);
select is(
  (
    select pg_catalog.string_agg(
      parameter_name,
      ',' order by ordinal_position
    )
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name = 'get_calendar_event_page_v2_' || (
        'public.get_calendar_event_page_v2(uuid,text,date,date,integer,text)'
          ::regprocedure::oid::text
      )
      and parameter_mode = 'OUT'
  ),
  'household_id,household_timezone,household_local_date,generated_at,view_mode,range_start_date,range_end_date_exclusive,page_limit,has_more,page_cursor,view_local_date,view_local_time,series_id,occurrence_id,title,description,is_all_day,local_start_date,local_start_time,duration_minutes,all_day_end_date_exclusive,timezone,overlap_policy,starts_at,ends_at,dst_resolution,utc_offset_seconds,participant_member_ids,participant_display_names,version,occurrence_version,recurrence_rule,recurrence_local_start_date,revision_number,is_exception',
  'v2 event page exposes the exact recurrence-aware projection envelope'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select pg_catalog.count(occurrence_id)
    from public.get_calendar_event_page_v2(
      '20000000-0000-4000-8000-000000000101',
      'day', date '2099-01-01', date '2099-01-02', 30, null
    )
  ),
  0::bigint,
  'empty v2 day view returns a valid metadata-only envelope'
);

select * from finish();
rollback;
