begin;
set constraints all deferred;

select plan(35);

select has_function(
  'public',
  'update_recurring_calendar_series_from_occurrence',
  array[
    'uuid', 'uuid', 'uuid', 'uuid', 'bigint', 'text', 'text', 'boolean',
    'date', 'time without time zone', 'integer', 'date', 'text', 'text',
    'jsonb', 'uuid[]'
  ],
  'selected-occurrence Calendar series update command exists'
);
select has_function(
  'app_private',
  'update_recurring_calendar_series_at_boundary',
  array[
    'uuid', 'uuid', 'uuid', 'uuid', 'bigint', 'text', 'text', 'boolean',
    'date', 'time without time zone', 'integer', 'date', 'text', 'text',
    'jsonb', 'uuid[]'
  ],
  'legacy and selected commands share one Calendar boundary engine'
);
select ok(
  (
    select pg_catalog.bool_and(procedure.prosecdef)
      and pg_catalog.bool_and(
        procedure.proconfig @> array['search_path=""']::text[]
      )
    from pg_catalog.pg_proc as procedure
    join pg_catalog.pg_namespace as namespace
      on namespace.oid = procedure.pronamespace
    where namespace.nspname in ('public', 'app_private')
      and procedure.proname in (
        'update_recurring_calendar_series',
        'update_recurring_calendar_series_from_occurrence',
        'update_recurring_calendar_series_at_boundary'
      )
  ),
  'all Calendar boundary functions are security-definer with empty paths'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.update_recurring_calendar_series_from_occurrence(uuid,uuid,uuid,uuid,bigint,text,text,boolean,date,time without time zone,integer,date,text,text,jsonb,uuid[])',
    'execute'
  ),
  'authenticated clients can execute the selected-boundary command'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.update_recurring_calendar_series_from_occurrence(uuid,uuid,uuid,uuid,bigint,text,text,boolean,date,time without time zone,integer,date,text,text,jsonb,uuid[])',
    'execute'
  ),
  'anonymous clients cannot execute the selected-boundary command'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.update_recurring_calendar_series_at_boundary(uuid,uuid,uuid,uuid,bigint,text,text,boolean,date,time without time zone,integer,date,text,text,jsonb,uuid[])',
    'execute'
  ),
  'clients cannot bypass the private Calendar boundary engine'
);
select is(
  (
    select pg_catalog.string_agg(
      parameter_name, ',' order by ordinal_position
    )
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name =
        'update_recurring_calendar_series_from_occurrence_' || (
          'public.update_recurring_calendar_series_from_occurrence(uuid,uuid,uuid,uuid,bigint,text,text,boolean,date,time without time zone,integer,date,text,text,jsonb,uuid[])'
            ::regprocedure::oid::text
        )
      and parameter_mode = 'OUT'
  ),
  'household_id,household_timezone,household_local_date,series_id,revision_id,revision_number,effective_local_date,materialized_through,version,rebuilt_count,cancelled_count,preserved_exception_count,changed',
  'selected-boundary update returns the exact compact result envelope'
);
select hasnt_column(
  'app_private',
  'calendar_series_change_command_requests',
  'effective_occurrence_id',
  'private replay state stores no selected occurrence identity'
);
select throws_ok(
  $$
    select *
    from public.update_recurring_calendar_series_from_occurrence(
      '4a000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      '4a100000-0000-4000-8000-000000000001',
      '4a200000-0000-4000-8000-000000000001',
      1, 'No auth', null, false, current_date, time '09:00', 30, null,
      'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE01',
  'authentication required',
  'the selected-boundary command derives identity from JWT'
);

select set_config(
  'kinflow.test.calendar_from_here_today',
  (pg_catalog.statement_timestamp() at time zone 'Asia/Seoul')::date::text,
  true
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select result.materialized_count
    from public.create_recurring_calendar_event(
      '4a010000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Calendar from-here old', 'Old series notes', false,
      current_setting('kinflow.test.calendar_from_here_today')::date - 2,
      time '08:00', 60, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    ) as result
  ),
  366,
  'daily Calendar fixture materializes its initial bounded window'
);
select set_config(
  'kinflow.test.calendar_from_here_series',
  (
    select series.id::text
    from public.event_series as series
    where series.title = 'Calendar from-here old'
  ),
  true
);
select set_config(
  'kinflow.test.calendar_from_here_revision_1',
  (
    select series.active_revision_id::text
    from public.event_series as series
    where series.id =
      current_setting('kinflow.test.calendar_from_here_series')::uuid
  ),
  true
);
select set_config(
  'kinflow.test.calendar_from_here_boundary',
  (current_setting('kinflow.test.calendar_from_here_today')::date + 5)::text,
  true
);
select set_config(
  'kinflow.test.calendar_from_here_target',
  (
    select occurrence.id::text
    from public.event_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.calendar_from_here_series')::uuid
      and occurrence.recurrence_local_start_date =
        current_setting('kinflow.test.calendar_from_here_boundary')::date
  ),
  true
);
select set_config(
  'kinflow.test.calendar_from_here_exception',
  (
    select occurrence.id::text
    from public.event_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.calendar_from_here_series')::uuid
      and occurrence.recurrence_local_start_date =
        current_setting('kinflow.test.calendar_from_here_boundary')::date + 8
  ),
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.occurrence_version, result.exception_version,
      result.cancelled, result.changed
    )
    from public.update_recurring_calendar_occurrence(
      '4a010000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_from_here_series')::uuid,
      current_setting('kinflow.test.calendar_from_here_exception')::uuid,
      1, 'Calendar exception', 'Preserved notes', false,
      current_setting('kinflow.test.calendar_from_here_boundary')::date + 20,
      time '15:30', 90, null, 'Asia/Seoul', 'later',
      array[
        '30000000-0000-4000-8000-000000000101'::uuid,
        '30000000-0000-4000-8000-000000000102'::uuid
      ]
    ) as result
  ),
  '2:1:f:t',
  'a later explicit occurrence exception exists before the series edit'
);
select set_config(
  'kinflow.test.calendar_from_here_exception_revision',
  (
    select occurrence.revision_id::text
    from public.event_occurrences as occurrence
    where occurrence.id =
      current_setting('kinflow.test.calendar_from_here_exception')::uuid
  ),
  true
);

select is(
  (
    select pg_catalog.concat_ws(
      ':', result.revision_number, result.version,
      result.household_local_date::text, result.effective_local_date::text,
      result.preserved_exception_count, result.changed
    )
    from public.update_recurring_calendar_series_from_occurrence(
      '4a020000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_from_here_series')::uuid,
      current_setting('kinflow.test.calendar_from_here_target')::uuid,
      1, 'Calendar from-here new', 'New series notes', false,
      current_setting('kinflow.test.calendar_from_here_boundary')::date,
      time '10:30', 45, null, 'Asia/Seoul', 'later',
      pg_catalog.jsonb_build_object(
        'frequency', 'weekly',
        'interval', 1,
        'weekdays', pg_catalog.jsonb_build_array(
          (array['MO','TU','WE','TH','FR','SA','SU'])[
            extract(
              isodow from current_setting(
                'kinflow.test.calendar_from_here_boundary'
              )::date
            )::integer
          ]
        ),
        'end', pg_catalog.jsonb_build_object('type', 'never')
      ),
      array['30000000-0000-4000-8000-000000000102'::uuid]
    ) as result
  ),
  '3:2:' || current_setting('kinflow.test.calendar_from_here_today') || ':'
    || current_setting('kinflow.test.calendar_from_here_boundary') || ':1:t',
  'the database derives the exact selected immutable recurrence-slot boundary'
);
select set_config(
  'kinflow.test.calendar_from_here_revision_3',
  (
    select series.active_revision_id::text
    from public.event_series as series
    where series.id =
      current_setting('kinflow.test.calendar_from_here_series')::uuid
  ),
  true
);
select ok(
  exists (
    select 1
    from public.event_series as series
    join public.event_series_revisions as revision
      on revision.id = series.active_revision_id
    where series.id =
      current_setting('kinflow.test.calendar_from_here_series')::uuid
      and series.version = 2
      and revision.revision_number = 3
      and revision.local_start_date =
        current_setting('kinflow.test.calendar_from_here_boundary')::date
      and revision.local_start_time = time '10:30'
      and revision.duration_minutes = 45
      and revision.recurrence_rule->>'frequency' = 'weekly'
  ),
  'the active series points to a new immutable selected-boundary revision'
);
select ok(
  exists (
    select 1
    from public.event_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.calendar_from_here_series')::uuid
      and occurrence.recurrence_local_start_date =
        current_setting('kinflow.test.calendar_from_here_boundary')::date - 1
      and occurrence.revision_id =
        current_setting('kinflow.test.calendar_from_here_revision_1')::uuid
      and occurrence.status = 'scheduled'
      and (occurrence.starts_at at time zone occurrence.timezone)::time =
        time '08:00'
      and occurrence.version = 1
  ),
  'the occurrence immediately before the boundary stays unchanged'
);
select ok(
  exists (
    select 1
    from public.event_occurrences as occurrence
    where occurrence.id =
      current_setting('kinflow.test.calendar_from_here_target')::uuid
      and occurrence.revision_id =
        current_setting('kinflow.test.calendar_from_here_revision_3')::uuid
      and occurrence.status = 'scheduled'
      and (occurrence.starts_at at time zone occurrence.timezone)::time =
        time '10:30'
      and occurrence.ends_at - occurrence.starts_at = interval '45 minutes'
      and occurrence.version = 2
  ),
  'the selected occurrence keeps identity and adopts the new revision'
);
select ok(
  exists (
    select 1
    from public.event_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.calendar_from_here_series')::uuid
      and occurrence.recurrence_local_start_date =
        current_setting('kinflow.test.calendar_from_here_boundary')::date + 1
      and occurrence.revision_id =
        current_setting('kinflow.test.calendar_from_here_revision_1')::uuid
      and occurrence.status = 'cancelled'
      and occurrence.version = 2
  ),
  'an obsolete later source slot becomes cancelled history'
);
select ok(
  exists (
    select 1
    from public.event_occurrences as occurrence
    join public.event_occurrence_exceptions as exception
      on exception.occurrence_id = occurrence.id
    join public.event_series_revisions as revision
      on revision.id = occurrence.revision_id
    where occurrence.id =
      current_setting('kinflow.test.calendar_from_here_exception')::uuid
      and occurrence.revision_id = current_setting(
        'kinflow.test.calendar_from_here_exception_revision'
      )::uuid
      and occurrence.local_start_date =
        current_setting('kinflow.test.calendar_from_here_boundary')::date + 20
      and (occurrence.starts_at at time zone occurrence.timezone)::time =
        time '15:30'
      and occurrence.status = 'scheduled'
      and occurrence.version = 2
      and exception.version = 1
      and not exception.cancelled
      and revision.snapshot_title = 'Calendar exception'
  ),
  'a later explicit exception survives selected-boundary regeneration exactly'
);
select is(
  (
    select pg_catalog.concat_ws(':', page.title, page.local_start_time::text)
    from public.get_calendar_event_page_v2(
      '20000000-0000-4000-8000-000000000101', 'day',
      current_setting('kinflow.test.calendar_from_here_boundary')::date - 1,
      current_setting('kinflow.test.calendar_from_here_boundary')::date,
      30, null
    ) as page
    where page.series_id =
      current_setting('kinflow.test.calendar_from_here_series')::uuid
  ),
  'Calendar from-here old:08:00:00',
  'Calendar reads retain old revision content before the boundary'
);
select is(
  (
    select pg_catalog.concat_ws(':', page.title, page.local_start_time::text)
    from public.get_calendar_event_page_v2(
      '20000000-0000-4000-8000-000000000101', 'day',
      current_setting('kinflow.test.calendar_from_here_boundary')::date,
      current_setting('kinflow.test.calendar_from_here_boundary')::date + 1,
      30, null
    ) as page
    where page.series_id =
      current_setting('kinflow.test.calendar_from_here_series')::uuid
  ),
  'Calendar from-here new:10:30:00',
  'Calendar reads switch to new revision content at the boundary'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', event.operation, event.effective_local_date::text,
      event.preserved_exception_count, event.preserved_past_count,
      event.series_version
    )
    from public.event_series_change_events as event
    where event.series_id =
      current_setting('kinflow.test.calendar_from_here_series')::uuid
      and event.operation = 'updated'
  ),
  'updated:' || current_setting('kinflow.test.calendar_from_here_boundary')
    || ':1:7:2',
  'series history records the selected boundary and aggregate preservation'
);
reset role;
select ok(
  exists (
    select 1
    from app_private.calendar_materialization_states as state
    where state.series_id =
      current_setting('kinflow.test.calendar_from_here_series')::uuid
      and state.revision_id =
        current_setting('kinflow.test.calendar_from_here_revision_3')::uuid
      and state.last_window_start =
        current_setting('kinflow.test.calendar_from_here_boundary')::date
      and state.covered_through =
        current_setting('kinflow.test.calendar_from_here_boundary')::date + 365
      and state.last_result = 'succeeded'
  ),
  'rolling materialization continues from the selected-boundary revision'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', pg_catalog.count(distinct event.id),
      pg_catalog.count(distinct request.idempotency_key)
    )
    from public.event_series_change_events as event
    join app_private.calendar_series_change_command_requests as request
      on request.series_id = event.series_id
    where event.series_id =
      current_setting('kinflow.test.calendar_from_here_series')::uuid
  ),
  '1:1',
  'the first selected-boundary edit stores one history and replay record'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.revision_number, result.version,
      result.effective_local_date::text, result.preserved_exception_count,
      result.changed
    )
    from public.update_recurring_calendar_series_from_occurrence(
      '4a020000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_from_here_series')::uuid,
      current_setting('kinflow.test.calendar_from_here_target')::uuid,
      1, 'Calendar from-here new', 'New series notes', false,
      current_setting('kinflow.test.calendar_from_here_boundary')::date,
      time '10:30', 45, null, 'Asia/Seoul', 'later',
      pg_catalog.jsonb_build_object(
        'frequency', 'weekly', 'interval', 1,
        'weekdays', pg_catalog.jsonb_build_array(
          (array['MO','TU','WE','TH','FR','SA','SU'])[
            extract(
              isodow from current_setting(
                'kinflow.test.calendar_from_here_boundary'
              )::date
            )::integer
          ]
        ),
        'end', pg_catalog.jsonb_build_object('type', 'never')
      ),
      array['30000000-0000-4000-8000-000000000102'::uuid]
    ) as result
  ),
  '3:2:' || current_setting('kinflow.test.calendar_from_here_boundary')
    || ':1:f',
  'the same selected-boundary key replays its original aggregate result'
);
select throws_ok(
  $$
    select *
    from public.update_recurring_calendar_series_from_occurrence(
      '4a020000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_from_here_series')::uuid,
      current_setting('kinflow.test.calendar_from_here_target')::uuid,
      2, 'Different replay', null, false,
      current_setting('kinflow.test.calendar_from_here_boundary')::date,
      time '11:00', 30, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000102'::uuid]
    )
  $$,
  'KFE04',
  'idempotency key reused with different calendar input',
  'same key with different selected-boundary input fails closed'
);
select throws_ok(
  $$
    select *
    from public.update_recurring_calendar_series_from_occurrence(
      '4a020000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_from_here_series')::uuid,
      current_setting('kinflow.test.calendar_from_here_target')::uuid,
      1, 'Stale edit', null, false,
      current_setting('kinflow.test.calendar_from_here_boundary')::date,
      time '11:00', 30, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000102'::uuid]
    )
  $$,
  'KFE05',
  'stale calendar event version',
  'a new selected-boundary key rejects a stale series version'
);
select throws_ok(
  $$
    select *
    from public.update_recurring_calendar_series_from_occurrence(
      '4a020000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_from_here_series')::uuid,
      (
        select occurrence.id
        from public.event_occurrences as occurrence
        where occurrence.series_id =
          current_setting('kinflow.test.calendar_from_here_series')::uuid
          and occurrence.recurrence_local_start_date =
            current_setting('kinflow.test.calendar_from_here_boundary')::date - 1
      ),
      2, 'Old revision target', null, false,
      current_setting('kinflow.test.calendar_from_here_boundary')::date,
      time '11:00', 30, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000102'::uuid]
    )
  $$,
  'KFE03',
  'calendar event not found or forbidden',
  'an occurrence from an old revision cannot become a new boundary'
);
select throws_ok(
  $$
    select *
    from public.update_recurring_calendar_series_from_occurrence(
      '4a020000-0000-4000-8000-000000000004',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_from_here_series')::uuid,
      current_setting('kinflow.test.calendar_from_here_exception')::uuid,
      2, 'Exception target', null, false,
      current_setting('kinflow.test.calendar_from_here_boundary')::date + 20,
      time '11:00', 30, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000102'::uuid]
    )
  $$,
  'KFE03',
  'calendar event not found or forbidden',
  'an explicit occurrence exception cannot become the series boundary'
);
select throws_ok(
  $$
    select *
    from public.update_recurring_calendar_series_from_occurrence(
      '4a020000-0000-4000-8000-000000000005',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_from_here_series')::uuid,
      (
        select occurrence.id
        from public.event_occurrences as occurrence
        where occurrence.series_id =
          current_setting('kinflow.test.calendar_from_here_series')::uuid
          and occurrence.recurrence_local_start_date =
            current_setting('kinflow.test.calendar_from_here_boundary')::date + 7
      ),
      2, 'Bad anchor', null, false,
      current_setting('kinflow.test.calendar_from_here_boundary')::date,
      time '11:00', 30, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000102'::uuid]
    )
  $$,
  'KFE07',
  'invalid calendar recurrence rule',
  'the new series anchor cannot precede the selected recurrence boundary'
);
select throws_ok(
  $$
    select *
    from public.update_recurring_calendar_series_from_occurrence(
      '4a020000-0000-4000-8000-000000000006',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_from_here_series')::uuid,
      (
        select occurrence.id
        from public.event_occurrences as occurrence
        where occurrence.series_id =
          current_setting('kinflow.test.calendar_from_here_series')::uuid
          and occurrence.recurrence_local_start_date =
            current_setting('kinflow.test.calendar_from_here_boundary')::date + 7
      ),
      2, 'Bad until', null, false,
      current_setting('kinflow.test.calendar_from_here_boundary')::date + 7,
      time '11:00', 30, null, 'Asia/Seoul', 'earlier',
      pg_catalog.jsonb_build_object(
        'frequency', 'daily', 'interval', 1,
        'end', pg_catalog.jsonb_build_object(
          'type', 'until',
          'localDate',
          current_setting('kinflow.test.calendar_from_here_boundary')::date + 6
        )
      ),
      array['30000000-0000-4000-8000-000000000102'::uuid]
    )
  $$,
  'KFE07',
  'invalid calendar recurrence rule',
  'recurrence end cannot precede the selected recurrence boundary'
);
select throws_ok(
  $$
    select *
    from public.update_recurring_calendar_series_from_occurrence(
      '4a020000-0000-4000-8000-000000000007',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_from_here_series')::uuid,
      '4affffff-0000-4000-8000-000000000001',
      2, 'Missing target', null, false,
      current_setting('kinflow.test.calendar_from_here_boundary')::date + 7,
      time '11:00', 30, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000102'::uuid]
    )
  $$,
  'KFE03',
  'calendar event not found or forbidden',
  'a missing target uses the same generic unavailable failure'
);
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$
    select *
    from public.update_recurring_calendar_series_from_occurrence(
      '4a020000-0000-4000-8000-000000000008',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_from_here_series')::uuid,
      current_setting('kinflow.test.calendar_from_here_target')::uuid,
      2, 'Outsider edit', null, false,
      current_setting('kinflow.test.calendar_from_here_boundary')::date,
      time '11:00', 30, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000102'::uuid]
    )
  $$,
  'KFE03',
  'calendar event not found or forbidden',
  'an outsider cannot use a selected occurrence from another household'
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', pg_catalog.count(*) filter (
        where occurrence.recurrence_local_start_date <
          current_setting('kinflow.test.calendar_from_here_boundary')::date
          and occurrence.status = 'scheduled'
      ),
      pg_catalog.count(*) filter (
        where occurrence.recurrence_local_start_date >=
          current_setting('kinflow.test.calendar_from_here_boundary')::date
          and occurrence.status = 'scheduled'
      ),
      pg_catalog.count(distinct occurrence.occurrence_key)
    )
    from public.event_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.calendar_from_here_series')::uuid
  ),
  '7:54:367',
  'the final series has one unique preserved prefix and bounded future set'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', pg_catalog.count(distinct revision.id),
      pg_catalog.count(distinct event.id),
      pg_catalog.count(distinct request.idempotency_key)
    )
    from public.event_series_revisions as revision
    left join public.event_series_change_events as event
      on event.series_id = revision.series_id
    left join app_private.calendar_series_change_command_requests as request
      on request.series_id = revision.series_id
    where revision.series_id =
      current_setting('kinflow.test.calendar_from_here_series')::uuid
  ),
  '3:1:1',
  'replay and rejected commands create no duplicate revisions or history'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select *
    from public.create_recurring_calendar_event(
      '4a030000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Calendar legacy wrapper', null, false,
      current_setting('kinflow.test.calendar_from_here_today')::date,
      time '09:00', 30, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'a second series fixture is available for legacy wrapper compatibility'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.effective_local_date::text, result.version, result.changed
    )
    from public.update_recurring_calendar_series(
      '4a030000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      (
        select series.id
        from public.event_series as series
        where series.title = 'Calendar legacy wrapper'
      ),
      1, 'Calendar legacy updated', null, false,
      current_setting('kinflow.test.calendar_from_here_today')::date,
      time '09:30', 30, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    ) as result
  ),
  current_setting('kinflow.test.calendar_from_here_today') || ':2:t',
  'the legacy command still uses household-local today through the shared engine'
);

select * from finish();
rollback;
