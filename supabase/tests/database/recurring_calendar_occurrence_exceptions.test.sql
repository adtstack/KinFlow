begin;
set constraints all deferred;

select plan(65);

-- Schema, least privilege, immutable identity, and stable envelopes.
select has_table(
  'public',
  'event_occurrence_exceptions',
  'single-occurrence exception storage exists'
);
select has_table(
  'app_private',
  'calendar_occurrence_exception_command_requests',
  'private occurrence command replay state exists'
);
select has_function(
  'public',
  'update_recurring_calendar_occurrence',
  array[
    'uuid', 'uuid', 'uuid', 'uuid', 'bigint', 'text', 'text',
    'boolean', 'date', 'time without time zone', 'integer', 'date',
    'text', 'text', 'uuid[]'
  ],
  'single recurring occurrence update command exists'
);
select has_function(
  'public',
  'cancel_recurring_calendar_occurrence',
  array['uuid', 'uuid', 'uuid', 'uuid', 'bigint'],
  'single recurring occurrence cancel command exists'
);
select has_column(
  'public',
  'event_occurrence_exceptions',
  'exception_revision_id',
  'exception points to a normalized immutable revision'
);
select has_column(
  'public',
  'event_occurrence_exceptions',
  'override_payload',
  'baseline-compatible override payload column remains present'
);
select has_trigger(
  'public',
  'event_occurrence_exceptions',
  'event_occurrence_exception_identity_immutable',
  'exception identity is immutable'
);
select has_trigger(
  'public',
  'event_occurrence_exceptions',
  'event_occurrence_exceptions_set_updated_at_and_version',
  'exception updates advance timestamp and version'
);
select ok(
  (
    select pg_class.relrowsecurity and pg_class.relforcerowsecurity
    from pg_catalog.pg_class
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'event_occurrence_exceptions'
  ),
  'occurrence exceptions enable and force RLS'
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
        'update_recurring_calendar_occurrence',
        'cancel_recurring_calendar_occurrence'
      )
  ),
  'occurrence commands are security-definer with empty search paths'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.update_recurring_calendar_occurrence(uuid,uuid,uuid,uuid,bigint,text,text,boolean,date,time without time zone,integer,date,text,text,uuid[])',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.cancel_recurring_calendar_occurrence(uuid,uuid,uuid,uuid,bigint)',
    'execute'
  ),
  'authenticated clients can execute mediated occurrence commands'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.update_recurring_calendar_occurrence(uuid,uuid,uuid,uuid,bigint,text,text,boolean,date,time without time zone,integer,date,text,text,uuid[])',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.cancel_recurring_calendar_occurrence(uuid,uuid,uuid,uuid,bigint)',
    'execute'
  ),
  'anonymous clients cannot execute occurrence commands'
);
select ok(
  has_table_privilege(
    'authenticated',
    'public.event_occurrence_exceptions',
    'select'
  )
  and not has_table_privilege(
    'authenticated',
    'public.event_occurrence_exceptions',
    'insert,update,delete'
  ),
  'authenticated clients have read-only authorized exception access'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.calendar_occurrence_exception_command_requests',
    'select'
  )
  and not has_table_privilege(
    'service_role',
    'app_private.calendar_occurrence_exception_command_requests',
    'select'
  ),
  'API roles cannot inspect private occurrence command state'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'calendar_occurrence_exception_command_requests'
      and column_name in (
        'title',
        'description',
        'display_name',
        'participant_member_ids',
        'override_payload'
      )
  ),
  'private occurrence command state contains no content or participant list'
);
select is(
  (
    select pg_catalog.string_agg(
      parameter_name,
      ',' order by ordinal_position
    )
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name =
        'update_recurring_calendar_occurrence_' || (
          'public.update_recurring_calendar_occurrence(uuid,uuid,uuid,uuid,bigint,text,text,boolean,date,time without time zone,integer,date,text,text,uuid[])'
            ::regprocedure::oid::text
        )
      and parameter_mode = 'OUT'
  ),
  'household_id,series_id,occurrence_id,revision_id,occurrence_version,exception_version,cancelled,changed',
  'update returns the exact content-free occurrence command envelope'
);
select is(
  (
    select pg_catalog.string_agg(
      parameter_name,
      ',' order by ordinal_position
    )
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name =
        'cancel_recurring_calendar_occurrence_' || (
          'public.cancel_recurring_calendar_occurrence(uuid,uuid,uuid,uuid,bigint)'
            ::regprocedure::oid::text
        )
      and parameter_mode = 'OUT'
  ),
  'household_id,series_id,occurrence_id,revision_id,occurrence_version,exception_version,cancelled,changed',
  'cancel returns the exact content-free occurrence command envelope'
);

-- Create a five-occurrence source and a one-time negative-control event.
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
      '44000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Exception source', 'Source description', false,
      date '2026-08-10', time '09:00', 60, null,
      'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":5}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  ),
  5,
  'fixture recurring source materializes five local dates'
);
select is(
  (
    select created
    from public.create_one_time_event(
      '44000000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      'One-time negative control', null, false,
      date '2026-09-01', time '09:00', 30, null,
      'Asia/Seoul', 'earlier',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  ),
  true,
  'one-time negative-control event is created'
);
select set_config(
  'kinflow.test.exception_series',
  (
    select series.id::text
    from public.event_series as series
    where series.title = 'Exception source'
  ),
  true
);
select set_config(
  'kinflow.test.exception_source_revision',
  (
    select series.active_revision_id::text
    from public.event_series as series
    where series.id = current_setting(
      'kinflow.test.exception_series'
    )::uuid
  ),
  true
);
select set_config(
  'kinflow.test.exception_edit_occurrence',
  (
    select occurrence.id::text
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.exception_series'
    )::uuid
      and occurrence.recurrence_local_start_date = date '2026-08-11'
  ),
  true
);
select set_config(
  'kinflow.test.exception_cancel_occurrence',
  (
    select occurrence.id::text
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.exception_series'
    )::uuid
      and occurrence.recurrence_local_start_date = date '2026-08-12'
  ),
  true
);
select set_config(
  'kinflow.test.exception_gap_occurrence',
  (
    select occurrence.id::text
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.exception_series'
    )::uuid
      and occurrence.recurrence_local_start_date = date '2026-08-14'
  ),
  true
);
select set_config(
  'kinflow.test.exception_one_time_series',
  (
    select series.id::text
    from public.event_series as series
    where series.title = 'One-time negative control'
  ),
  true
);
select set_config(
  'kinflow.test.exception_one_time_occurrence',
  (
    select occurrence.id::text
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.exception_one_time_series'
    )::uuid
  ),
  true
);
reset role;

select is(
  (
    select pg_catalog.count(*)
    from public.event_occurrence_exceptions
  ),
  0::bigint,
  'materialized recurring source starts without exception rows'
);

-- Authentication, authorization, transition, participant, stale, and DST errors.
select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  format(
    $sql$
      select * from public.update_recurring_calendar_occurrence(
        '44000000-0000-4000-8000-000000000010',
        '20000000-0000-4000-8000-000000000101',
        %L, %L, 1, 'No auth', null, false,
        date '2026-08-11', time '10:00', 60, null,
        'Asia/Seoul', 'earlier',
        array['30000000-0000-4000-8000-000000000101'::uuid]
      )
    $sql$,
    current_setting('kinflow.test.exception_series'),
    current_setting('kinflow.test.exception_edit_occurrence')
  ),
  'KFE01',
  'authentication required',
  'occurrence update derives actor from JWT'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  format(
    $sql$
      select * from public.update_recurring_calendar_occurrence(
        '44000000-0000-4000-8000-000000000011',
        '20000000-0000-4000-8000-000000000101',
        %L, %L, 1, 'Duplicate people', null, false,
        date '2026-08-11', time '10:00', 60, null,
        'Asia/Seoul', 'earlier',
        array[
          '30000000-0000-4000-8000-000000000101'::uuid,
          '30000000-0000-4000-8000-000000000101'::uuid
        ]
      )
    $sql$,
    current_setting('kinflow.test.exception_series'),
    current_setting('kinflow.test.exception_edit_occurrence')
  ),
  'KFE02',
  'invalid calendar occurrence input',
  'duplicate participant IDs fail closed'
);
select throws_ok(
  format(
    $sql$
      select * from public.update_recurring_calendar_occurrence(
        '44000000-0000-4000-8000-000000000012',
        '20000000-0000-4000-8000-000000000101',
        %L, %L, 1, 'Foreign person', null, false,
        date '2026-08-11', time '10:00', 60, null,
        'Asia/Seoul', 'earlier',
        array['30000000-0000-4000-8000-000000000201'::uuid]
      )
    $sql$,
    current_setting('kinflow.test.exception_series'),
    current_setting('kinflow.test.exception_edit_occurrence')
  ),
  'KFE03',
  'calendar occurrence not found or forbidden',
  'cross-household participants are rejected'
);
select throws_ok(
  format(
    $sql$
      select * from public.update_recurring_calendar_occurrence(
        '44000000-0000-4000-8000-000000000013',
        '20000000-0000-4000-8000-000000000101',
        %L, %L, 99, 'Stale edit', null, false,
        date '2026-08-11', time '10:00', 60, null,
        'Asia/Seoul', 'earlier',
        array['30000000-0000-4000-8000-000000000101'::uuid]
      )
    $sql$,
    current_setting('kinflow.test.exception_series'),
    current_setting('kinflow.test.exception_edit_occurrence')
  ),
  'KFE05',
  'stale calendar occurrence version',
  'occurrence update rejects a stale occurrence version'
);
select throws_ok(
  format(
    $sql$
      select * from public.update_recurring_calendar_occurrence(
        '44000000-0000-4000-8000-000000000014',
        '20000000-0000-4000-8000-000000000101',
        %L, %L, 1, 'One-time edit', null, false,
        date '2026-09-01', time '10:00', 60, null,
        'Asia/Seoul', 'earlier',
        array['30000000-0000-4000-8000-000000000101'::uuid]
      )
    $sql$,
    current_setting('kinflow.test.exception_one_time_series'),
    current_setting('kinflow.test.exception_one_time_occurrence')
  ),
  'KFE08',
  'calendar occurrence transition not allowed',
  'one-time occurrence cannot use the recurring exception command'
);
select throws_ok(
  format(
    $sql$
      select * from public.update_recurring_calendar_occurrence(
        '44000000-0000-4000-8000-000000000015',
        '20000000-0000-4000-8000-000000000101',
        %L, %L, 1, 'Gap edit', null, false,
        date '2026-03-08', time '02:30', 60, null,
        'America/Los_Angeles', 'earlier',
        array['30000000-0000-4000-8000-000000000101'::uuid]
      )
    $sql$,
    current_setting('kinflow.test.exception_series'),
    current_setting('kinflow.test.exception_gap_occurrence')
  ),
  'KFE06',
  'nonexistent calendar local time',
  'a DST gap rejects the occurrence edit atomically'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  format(
    $sql$
      select * from public.cancel_recurring_calendar_occurrence(
        '44000000-0000-4000-8000-000000000016',
        '20000000-0000-4000-8000-000000000101',
        %L, %L, 1
      )
    $sql$,
    current_setting('kinflow.test.exception_series'),
    current_setting('kinflow.test.exception_cancel_occurrence')
  ),
  'KFE03',
  'calendar occurrence not found or forbidden',
  'an outsider cannot cancel a household occurrence'
);
reset role;
select is(
  (
    select pg_catalog.count(*)
    from public.event_series_revisions as revision
    where revision.series_id = current_setting(
      'kinflow.test.exception_series'
    )::uuid
  ),
  1::bigint,
  'failed commands leave revision history unchanged'
);
select is(
  (
    select pg_catalog.count(*)
    from public.event_occurrence_exceptions
  ),
  0::bigint,
  'failed commands leave exception storage unchanged'
);

-- Edit one occurrence and verify normalized history, source/sibling isolation,
-- moved projection, month counts, and idempotency.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      result.occurrence_version,
      result.exception_version,
      result.cancelled,
      result.changed,
      result.revision_id is not null
    )
    from public.update_recurring_calendar_occurrence(
      '44000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.exception_series')::uuid,
      current_setting('kinflow.test.exception_edit_occurrence')::uuid,
      1,
      '  Moved occurrence  ',
      '  Only this date  ',
      false,
      date '2026-08-15',
      time '15:30',
      90,
      null,
      'Asia/Seoul',
      'later',
      array[
        '30000000-0000-4000-8000-000000000102'::uuid,
        '30000000-0000-4000-8000-000000000101'::uuid
      ]
    ) as result
  ),
  '2:1:f:t:t',
  'single-occurrence edit advances occurrence and exception versions'
);
select set_config(
  'kinflow.test.exception_first_revision',
  (
    select occurrence.revision_id::text
    from public.event_occurrences as occurrence
    where occurrence.id = current_setting(
      'kinflow.test.exception_edit_occurrence'
    )::uuid
  ),
  true
);
reset role;

select ok(
  exists (
    select 1
    from public.event_occurrence_exceptions as exception
    where exception.household_id =
      '20000000-0000-4000-8000-000000000101'
      and exception.series_id = current_setting(
        'kinflow.test.exception_series'
      )::uuid
      and exception.occurrence_id = current_setting(
        'kinflow.test.exception_edit_occurrence'
      )::uuid
      and exception.exception_revision_id = current_setting(
        'kinflow.test.exception_first_revision'
      )::uuid
      and exception.override_payload = '{}'::jsonb
      and not exception.cancelled
      and exception.version = 1
  ),
  'edited occurrence stores one content-free normalized exception pointer'
);
select ok(
  exists (
    select 1
    from public.event_occurrences as occurrence
    where occurrence.id = current_setting(
      'kinflow.test.exception_edit_occurrence'
    )::uuid
      and occurrence.recurrence_local_start_date = date '2026-08-11'
      and occurrence.occurrence_key =
        occurrence.series_id::text || ':2026-08-11'
      and occurrence.local_start_date = date '2026-08-15'
      and occurrence.revision_id = current_setting(
        'kinflow.test.exception_first_revision'
      )::uuid
      and occurrence.version = 2
      and occurrence.status = 'scheduled'
  ),
  'edit preserves immutable slot/key while moving only concrete occurrence time'
);
select ok(
  exists (
    select 1
    from public.event_series as series
    where series.id = current_setting(
      'kinflow.test.exception_series'
    )::uuid
      and series.active_revision_id = current_setting(
        'kinflow.test.exception_source_revision'
      )::uuid
      and series.title = 'Exception source'
      and series.description = 'Source description'
      and series.version = 1
  ),
  'edit leaves source series projection and active revision unchanged'
);
select is(
  (
    select pg_catalog.count(*)
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.exception_series'
    )::uuid
      and occurrence.id <> current_setting(
        'kinflow.test.exception_edit_occurrence'
      )::uuid
      and (
        occurrence.version <> 1
        or occurrence.revision_id <> current_setting(
          'kinflow.test.exception_source_revision'
        )::uuid
        or occurrence.local_start_date <>
          occurrence.recurrence_local_start_date
      )
  ),
  0::bigint,
  'edit leaves every sibling occurrence unchanged'
);
select ok(
  exists (
    select 1
    from public.event_series_revisions as revision
    where revision.id = current_setting(
      'kinflow.test.exception_first_revision'
    )::uuid
      and revision.revision_number = 2
      and revision.snapshot_title = 'Moved occurrence'
      and revision.snapshot_description = 'Only this date'
      and revision.snapshot_timezone = 'Asia/Seoul'
      and not revision.snapshot_is_all_day
      and revision.local_start_date = date '2026-08-15'
      and revision.local_start_time = time '15:30'
      and revision.duration_minutes = 90
      and revision.overlap_policy = 'later'
      and revision.recurrence_rule =
        '{"frequency":"daily","interval":1,"end":{"type":"count","count":5}}'
          ::jsonb
  ),
  'edited content and time intent live in a new immutable recurring revision'
);
select is(
  (
    select pg_catalog.count(*)
    from public.event_revision_participants as participant
    where participant.revision_id = current_setting(
      'kinflow.test.exception_first_revision'
    )::uuid
  ),
  2::bigint,
  'exception revision snapshots the exact participant set'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select pg_catalog.count(page.occurrence_id)
    from public.get_calendar_event_page_v2(
      '20000000-0000-4000-8000-000000000101',
      'day',
      date '2026-08-11',
      date '2026-08-12',
      30,
      null
    ) as page
    where page.occurrence_id = current_setting(
      'kinflow.test.exception_edit_occurrence'
    )::uuid
  ),
  0::bigint,
  'moved occurrence disappears from its original v2 day'
);
select ok(
  exists (
    select 1
    from public.get_calendar_event_page_v2(
      '20000000-0000-4000-8000-000000000101',
      'day',
      date '2026-08-15',
      date '2026-08-16',
      30,
      null
    ) as page
    where page.occurrence_id = current_setting(
      'kinflow.test.exception_edit_occurrence'
    )::uuid
      and page.title = 'Moved occurrence'
      and page.view_local_time = time '15:30'
      and page.recurrence_local_start_date = date '2026-08-11'
      and page.revision_number = 2
      and page.is_exception
  ),
  'moved occurrence appears exactly once with exception metadata'
);
select is(
  (
    select summary.event_count
    from public.get_calendar_month_summary_v2(
      '20000000-0000-4000-8000-000000000101',
      date '2026-08-01'
    ) as summary
    where summary.day_date = date '2026-08-11'
  ),
  0,
  'month summary removes the moved occurrence from its original date'
);
select is(
  (
    select summary.event_count
    from public.get_calendar_month_summary_v2(
      '20000000-0000-4000-8000-000000000101',
      date '2026-08-01'
    ) as summary
    where summary.day_date = date '2026-08-15'
  ),
  1,
  'month summary counts the moved occurrence on its concrete date'
);
reset role;
select is(
  app_private.materialize_calendar_revision_window(
    '20000000-0000-4000-8000-000000000101',
    current_setting('kinflow.test.exception_series')::uuid,
    current_setting('kinflow.test.exception_source_revision')::uuid,
    date '2026-08-10',
    date '2026-08-14'
  ),
  0,
  'source materializer replay does not overwrite an edited occurrence'
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
      ':',
      result.occurrence_version,
      result.exception_version,
      result.changed,
      result.revision_id = current_setting(
        'kinflow.test.exception_first_revision'
      )::uuid
    )
    from public.update_recurring_calendar_occurrence(
      '44000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.exception_series')::uuid,
      current_setting('kinflow.test.exception_edit_occurrence')::uuid,
      1,
      'Moved occurrence',
      'Only this date',
      false,
      date '2026-08-15',
      time '15:30',
      90,
      null,
      'Asia/Seoul',
      'later',
      array[
        '30000000-0000-4000-8000-000000000101'::uuid,
        '30000000-0000-4000-8000-000000000102'::uuid
      ]
    ) as result
  ),
  '2:1:f:t',
  'exact update replay returns the original versioned result'
);
select throws_ok(
  format(
    $sql$
      select * from public.update_recurring_calendar_occurrence(
        '44000000-0000-4000-8000-000000000101',
        '20000000-0000-4000-8000-000000000101',
        %L, %L, 2, 'Changed replay', null, false,
        date '2026-08-15', time '15:30', 90, null,
        'Asia/Seoul', 'later',
        array['30000000-0000-4000-8000-000000000101'::uuid]
      )
    $sql$,
    current_setting('kinflow.test.exception_series'),
    current_setting('kinflow.test.exception_edit_occurrence')
  ),
  'KFE04',
  'idempotency key reused with different calendar input',
  'update command key cannot be reused with changed input'
);
reset role;
select is(
  (
    select pg_catalog.count(*)
    from public.event_series_revisions as revision
    where revision.series_id = current_setting(
      'kinflow.test.exception_series'
    )::uuid
  ),
  2::bigint,
  'update replay does not append another revision'
);

-- A second edit advances only the exception pointer and preserves prior history.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      result.occurrence_version,
      result.exception_version,
      result.cancelled,
      result.changed
    )
    from public.update_recurring_calendar_occurrence(
      '44000000-0000-4000-8000-000000000102',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.exception_series')::uuid,
      current_setting('kinflow.test.exception_edit_occurrence')::uuid,
      2,
      'All-day exception',
      '',
      true,
      date '2026-08-16',
      null,
      null,
      date '2026-08-18',
      null,
      null,
      array['30000000-0000-4000-8000-000000000101'::uuid]
    ) as result
  ),
  '3:2:f:t',
  're-edit advances occurrence and existing exception versions'
);
select set_config(
  'kinflow.test.exception_second_revision',
  (
    select occurrence.revision_id::text
    from public.event_occurrences as occurrence
    where occurrence.id = current_setting(
      'kinflow.test.exception_edit_occurrence'
    )::uuid
  ),
  true
);
reset role;
select ok(
  exists (
    select 1
    from public.event_series_revisions as revision
    where revision.id = current_setting(
      'kinflow.test.exception_first_revision'
    )::uuid
      and revision.snapshot_title = 'Moved occurrence'
      and not revision.snapshot_is_all_day
  )
  and exists (
    select 1
    from public.event_series_revisions as revision
    where revision.id = current_setting(
      'kinflow.test.exception_second_revision'
    )::uuid
      and revision.revision_number = 3
      and revision.snapshot_title = 'All-day exception'
      and revision.snapshot_is_all_day
      and revision.local_start_date = date '2026-08-16'
      and revision.all_day_end_date_exclusive = date '2026-08-18'
  ),
  're-edit preserves the prior revision and appends an all-day revision'
);
select ok(
  exists (
    select 1
    from public.event_occurrence_exceptions as exception
    where exception.occurrence_id = current_setting(
      'kinflow.test.exception_edit_occurrence'
    )::uuid
      and exception.exception_revision_id = current_setting(
        'kinflow.test.exception_second_revision'
      )::uuid
      and exception.version = 2
      and not exception.cancelled
  ),
  'the unique exception row points at the newest immutable revision'
);
select is(
  (
    select pg_catalog.count(*)
    from public.event_occurrence_exceptions as exception
    where exception.occurrence_id = current_setting(
      'kinflow.test.exception_edit_occurrence'
    )::uuid
  ),
  1::bigint,
  're-edit never duplicates the occurrence exception row'
);

-- Cancel another occurrence, then cancel the edited occurrence, and verify
-- projection removal, replay, transition guards, and revision preservation.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      result.revision_id is null,
      result.occurrence_version,
      result.exception_version,
      result.cancelled,
      result.changed
    )
    from public.cancel_recurring_calendar_occurrence(
      '44000000-0000-4000-8000-000000000201',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.exception_series')::uuid,
      current_setting('kinflow.test.exception_cancel_occurrence')::uuid,
      1
    ) as result
  ),
  't:2:1:t:t',
  'cancel creates a cancellation-only exception and advances occurrence'
);
select is(
  (
    select pg_catalog.count(page.occurrence_id)
    from public.get_calendar_event_page_v2(
      '20000000-0000-4000-8000-000000000101',
      'day',
      date '2026-08-12',
      date '2026-08-13',
      30,
      null
    ) as page
    where page.occurrence_id = current_setting(
      'kinflow.test.exception_cancel_occurrence'
    )::uuid
  ),
  0::bigint,
  'cancelled occurrence disappears from v2 day projection'
);
select is(
  (
    select summary.event_count
    from public.get_calendar_month_summary_v2(
      '20000000-0000-4000-8000-000000000101',
      date '2026-08-01'
    ) as summary
    where summary.day_date = date '2026-08-12'
  ),
  0,
  'cancelled occurrence is removed from month counts'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      result.occurrence_version,
      result.exception_version,
      result.changed
    )
    from public.cancel_recurring_calendar_occurrence(
      '44000000-0000-4000-8000-000000000201',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.exception_series')::uuid,
      current_setting('kinflow.test.exception_cancel_occurrence')::uuid,
      1
    ) as result
  ),
  '2:1:f',
  'exact cancel replay returns the original result'
);
select throws_ok(
  format(
    $sql$
      select * from public.cancel_recurring_calendar_occurrence(
        '44000000-0000-4000-8000-000000000202',
        '20000000-0000-4000-8000-000000000101',
        %L, %L, 2
      )
    $sql$,
    current_setting('kinflow.test.exception_series'),
    current_setting('kinflow.test.exception_cancel_occurrence')
  ),
  'KFE08',
  'calendar occurrence transition not allowed',
  'a new command cannot cancel an already-cancelled occurrence'
);
select throws_ok(
  format(
    $sql$
      select * from public.update_recurring_calendar_occurrence(
        '44000000-0000-4000-8000-000000000203',
        '20000000-0000-4000-8000-000000000101',
        %L, %L, 2, 'Cancelled edit', null, false,
        date '2026-08-12', time '11:00', 60, null,
        'Asia/Seoul', 'earlier',
        array['30000000-0000-4000-8000-000000000101'::uuid]
      )
    $sql$,
    current_setting('kinflow.test.exception_series'),
    current_setting('kinflow.test.exception_cancel_occurrence')
  ),
  'KFE08',
  'calendar occurrence transition not allowed',
  'an already-cancelled occurrence cannot be edited'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      result.revision_id = current_setting(
        'kinflow.test.exception_second_revision'
      )::uuid,
      result.occurrence_version,
      result.exception_version,
      result.cancelled,
      result.changed
    )
    from public.cancel_recurring_calendar_occurrence(
      '44000000-0000-4000-8000-000000000204',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.exception_series')::uuid,
      current_setting('kinflow.test.exception_edit_occurrence')::uuid,
      3
    ) as result
  ),
  't:4:3:t:t',
  'cancelling an edited occurrence preserves its exception revision pointer'
);
reset role;

select ok(
  exists (
    select 1
    from public.event_occurrence_exceptions as exception
    join public.event_occurrences as occurrence
      on occurrence.household_id = exception.household_id
     and occurrence.id = exception.occurrence_id
    where exception.occurrence_id = current_setting(
      'kinflow.test.exception_edit_occurrence'
    )::uuid
      and exception.exception_revision_id = current_setting(
        'kinflow.test.exception_second_revision'
      )::uuid
      and exception.cancelled
      and exception.version = 3
      and occurrence.status = 'cancelled'
      and occurrence.version = 4
  ),
  'edited cancellation keeps history and synchronizes exception/occurrence state'
);
select ok(
  exists (
    select 1
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.exception_series'
    )::uuid
      and occurrence.recurrence_local_start_date = date '2026-08-13'
      and occurrence.status = 'scheduled'
      and occurrence.version = 1
      and occurrence.revision_id = current_setting(
        'kinflow.test.exception_source_revision'
      )::uuid
  ),
  'sibling occurrence remains scheduled on the original source revision'
);
select throws_ok(
  format(
    'update public.event_occurrence_exceptions set occurrence_id = %L where occurrence_id = %L',
    current_setting('kinflow.test.exception_gap_occurrence'),
    current_setting('kinflow.test.exception_edit_occurrence')
  ),
  '55000',
  'calendar occurrence exception identity is immutable',
  'exception occurrence identity cannot be changed in place'
);
select throws_ok(
  format(
    'update public.event_series_revisions set snapshot_title = %L where id = %L',
    'mutated',
    current_setting('kinflow.test.exception_first_revision')
  ),
  '55000',
  'calendar event revisions are immutable',
  'prior exception revision content remains immutable'
);
select is(
  (
    select pg_catalog.count(*)
    from app_private.calendar_occurrence_exception_command_requests
  ),
  4::bigint,
  'only four successful logical occurrence commands persist replay rows'
);
select ok(
  not exists (
    select 1
    from app_private.calendar_occurrence_exception_command_requests as request
    where request.request_hash is null
      or pg_catalog.octet_length(request.request_hash) <> 32
  ),
  'every private command stores only a fixed-size request hash'
);
select is(
  (
    select pg_catalog.count(*)
    from app_private.calendar_audit_events as audit
    where audit.series_id = current_setting(
      'kinflow.test.exception_series'
    )::uuid
      and audit.action in (
        'calendar.occurrence_updated',
        'calendar.occurrence_cancelled'
      )
  ),
  4::bigint,
  'each logical update/cancel writes one content-free audit event'
);
select is(
  (
    select pg_catalog.count(*)
    from public.event_occurrence_exceptions as exception
    where exception.series_id = current_setting(
      'kinflow.test.exception_series'
    )::uuid
  ),
  2::bigint,
  'one edited and one cancelled occurrence produce two unique exceptions'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select is(
  (
    select pg_catalog.count(*)
    from public.event_occurrence_exceptions
  ),
  0::bigint,
  'RLS hides occurrence exceptions from an outsider'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select pg_catalog.count(*)
    from public.event_occurrence_exceptions
  ),
  2::bigint,
  'an active household member can read authorized exception metadata'
);

select * from finish();
rollback;
