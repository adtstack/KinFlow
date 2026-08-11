begin;
set constraints all deferred;

select plan(56);

-- Bounded scheduler, least privilege, immutable aggregate runs, and
-- privacy-minimal operational state.
select ok(
  exists (
    select 1 from pg_catalog.pg_extension where extname = 'pg_cron'
  ),
  'pg_cron is installed for Calendar horizon scheduling'
);
select has_function(
  'public', 'run_calendar_horizon_worker',
  array['timestamp with time zone', 'integer', 'integer', 'integer', 'uuid'],
  'bounded Calendar horizon worker exists'
);
select has_function(
  'app_private', 'materialize_calendar_revision_window',
  array['uuid', 'uuid', 'uuid', 'date', 'date'],
  'bounded exception-aware Calendar materializer exists'
);
select has_function(
  'app_private', 'calendar_revision_candidate_dates',
  array['uuid', 'uuid', 'uuid', 'date', 'date'],
  'worker and series edit share canonical candidate generation'
);
select has_table(
  'app_private', 'calendar_materialization_states',
  'private per-series Calendar horizon state exists'
);
select has_table(
  'app_private', 'calendar_materialization_runs',
  'private aggregate Calendar worker run audit exists'
);
select has_trigger(
  'app_private', 'calendar_materialization_runs',
  'calendar_materialization_runs_immutable',
  'Calendar worker run audit is immutable'
);
select ok(
  (
    select pg_proc.prosecdef
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_catalog.pg_proc
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'run_calendar_horizon_worker'
  ),
  'Calendar worker is security-definer with an empty search path'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.run_calendar_horizon_worker(timestamptz,integer,integer,integer,uuid)',
    'execute'
  ),
  'service role can execute only the mediated Calendar worker'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.run_calendar_horizon_worker(timestamptz,integer,integer,integer,uuid)',
    'execute'
  ),
  'authenticated clients cannot execute the Calendar worker'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.run_calendar_horizon_worker(timestamptz,integer,integer,integer,uuid)',
    'execute'
  ),
  'anonymous clients cannot execute the Calendar worker'
);
select ok(
  not has_function_privilege(
    'service_role',
    'app_private.materialize_calendar_revision_window(uuid,uuid,uuid,date,date)',
    'execute'
  ),
  'service role cannot bypass the worker through the private materializer'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.calendar_revision_candidate_dates(uuid,uuid,uuid,date,date)',
    'execute'
  ),
  'authenticated clients cannot invoke private candidate generation'
);
select ok(
  not has_table_privilege(
    'authenticated', 'app_private.calendar_materialization_states', 'select'
  )
  and not has_table_privilege(
    'service_role', 'app_private.calendar_materialization_states', 'select'
  ),
  'API roles cannot inspect private Calendar horizon state'
);
select ok(
  not has_table_privilege(
    'authenticated', 'app_private.calendar_materialization_runs', 'select'
  )
  and not has_table_privilege(
    'service_role', 'app_private.calendar_materialization_runs', 'select'
  ),
  'API roles cannot inspect private Calendar worker runs'
);
select is(
  (
    select pg_catalog.count(*)
    from cron.job
    where jobname = 'kinflow-calendar-horizon-v1'
  ),
  1::bigint,
  'exactly one named Calendar horizon job is scheduled'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', schedule, username, database, active::text
    )
    from cron.job
    where jobname = 'kinflow-calendar-horizon-v1'
  ),
  '29 * * * *:postgres:postgres:true',
  'Calendar horizon cron has the exact hourly schedule and owner'
);
select ok(
  (
    select pg_catalog.regexp_replace(command, '[[:space:]]+', '', 'g') =
      'select*frompublic.run_calendar_horizon_worker(pg_catalog.statement_timestamp(),365,7,100,null);'
    from cron.job
    where jobname = 'kinflow-calendar-horizon-v1'
  ),
  'cron invokes the exact bounded default Calendar worker command'
);
select ok(
  not has_schema_privilege('authenticated', 'cron', 'usage'),
  'authenticated clients have no cron schema usage'
);
select ok(
  not has_schema_privilege('anon', 'cron', 'usage'),
  'anonymous clients have no cron schema usage'
);
select ok(
  not has_schema_privilege('service_role', 'cron', 'usage'),
  'service role cannot mutate the cron schedule'
);
select is(
  (
    select pg_catalog.string_agg(
      column_name, ',' order by ordinal_position
    )
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'calendar_materialization_states'
  ),
  'household_id,series_id,revision_id,covered_through,last_window_start,last_target_date,next_repair_at,last_attempted_at,last_succeeded_at,last_result,last_error_code,last_changed_count,attempt_count,updated_at',
  'Calendar horizon state contains only IDs, dates, counts, and result codes'
);
select is(
  (
    select pg_catalog.string_agg(
      column_name, ',' order by ordinal_position
    )
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'calendar_materialization_runs'
  ),
  'id,invoked_at,as_of,horizon_days,repair_lookback_days,batch_size,target_series_id,claimed_count,succeeded_count,failed_count,changed_count,batch_exhausted,completed_at',
  'Calendar run audit contains only controls and aggregate counts'
);
select hasnt_column(
  'app_private', 'calendar_materialization_states', 'title',
  'Calendar horizon state does not store event titles'
);
select hasnt_column(
  'app_private', 'calendar_materialization_runs', 'household_id',
  'aggregate Calendar run audit does not identify a household'
);
select ok(
  pg_catalog.pg_get_functiondef(
    'public.run_calendar_horizon_worker(timestamptz,integer,integer,integer,uuid)'
      ::regprocedure
  ) ilike '%for update of series skip locked%',
  'worker claims series with row locks and SKIP LOCKED'
);
select ok(
  pg_catalog.pg_get_functiondef(
    'public.run_calendar_horizon_worker(timestamptz,integer,integer,integer,uuid)'
      ::regprocedure
  ) ilike '%nonexistent_local_time%'
  and pg_catalog.pg_get_functiondef(
    'public.run_calendar_horizon_worker(timestamptz,integer,integer,integer,uuid)'
      ::regprocedure
  ) ilike '%materialization_failed%',
  'worker persists only stable content-free failure codes'
);

-- Role boundary and strict bounded inputs.
set local role authenticated;
select throws_ok(
  $$
    select * from public.run_calendar_horizon_worker(
      statement_timestamp(), 365, 7, 100, null
    )
  $$,
  '42501', 'permission denied for function run_calendar_horizon_worker',
  'authenticated role is denied before worker execution'
);
reset role;
set local role service_role;
select throws_ok(
  $$select * from public.run_calendar_horizon_worker(null, 365, 7, 100, null)$$,
  'KFW01', 'invalid calendar horizon worker input',
  'worker requires a deterministic as-of instant'
);
select throws_ok(
  $$
    select * from public.run_calendar_horizon_worker(
      statement_timestamp(), 29, 7, 100, null
    )
  $$,
  'KFW01', 'invalid calendar horizon worker input',
  'worker rejects a horizon below 30 days'
);
select throws_ok(
  $$
    select * from public.run_calendar_horizon_worker(
      statement_timestamp(), 366, 7, 100, null
    )
  $$,
  'KFW01', 'invalid calendar horizon worker input',
  'worker rejects a horizon above 365 days'
);
select throws_ok(
  $$
    select * from public.run_calendar_horizon_worker(
      statement_timestamp(), 365, 32, 100, null
    )
  $$,
  'KFW01', 'invalid calendar horizon worker input',
  'worker rejects a repair lookback above 31 days'
);
select throws_ok(
  $$
    select * from public.run_calendar_horizon_worker(
      statement_timestamp(), 365, 7, 501, null
    )
  $$,
  'KFW01', 'invalid calendar horizon worker input',
  'worker rejects a batch above 500 series'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.claimed_count, result.succeeded_count,
      result.failed_count, result.changed_count, result.batch_exhausted
    )
    from public.run_calendar_horizon_worker(
      statement_timestamp(), 365, 7, 100,
      '46000000-0000-4000-8000-000000000001'
    ) as result
  ),
  '0:0:0:0:f',
  'unknown targeted series reveals no household information'
);
reset role;
select ok(
  exists (
    select 1
    from app_private.calendar_materialization_runs as run
    where run.target_series_id =
      '46000000-0000-4000-8000-000000000001'
      and run.claimed_count = 0
      and run.changed_count = 0
  ),
  'zero-result targeting keeps only a privacy-minimal aggregate run'
);
select throws_ok(
  $$
    select app_private.materialize_calendar_revision_window(
      '20000000-0000-4000-8000-000000000101',
      '46000000-0000-4000-8000-000000000002',
      '46000000-0000-4000-8000-000000000003',
      date '2026-01-01', date '2027-02-03'
    )
  $$,
  'KFE07', 'invalid calendar recurrence rule',
  'private materializer rejects a window above 397 inclusive days'
);

-- Repair a missing slot, extend beyond the initial year, and preserve an
-- explicit moved occurrence exception.
select set_config(
  'kinflow.test.calendar_worker_as_of',
  pg_catalog.statement_timestamp()::text,
  true
);
select set_config(
  'kinflow.test.calendar_worker_today',
  (
    pg_catalog.statement_timestamp() at time zone 'Asia/Seoul'
  )::date::text,
  true
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101', true
);
select is(
  (
    select materialized_count
    from public.create_recurring_calendar_event(
      '46000000-0000-4000-8000-000000000010',
      '20000000-0000-4000-8000-000000000101',
      'Calendar horizon daily', null, false,
      current_setting('kinflow.test.calendar_worker_today')::date - 5,
      time '09:30', 30, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  ),
  366,
  'daily Calendar fixture starts with an inclusive one-year window'
);
select set_config(
  'kinflow.test.calendar_worker_series',
  (
    select series.id::text
    from public.event_series as series
    where series.title = 'Calendar horizon daily'
  ),
  true
);
select set_config(
  'kinflow.test.calendar_worker_revision',
  (
    select series.active_revision_id::text
    from public.event_series as series
    where series.id = current_setting(
      'kinflow.test.calendar_worker_series'
    )::uuid
  ),
  true
);
select set_config(
  'kinflow.test.calendar_worker_exception_occurrence',
  (
    select occurrence.id::text
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
        'kinflow.test.calendar_worker_series'
      )::uuid
      and occurrence.recurrence_local_start_date =
        current_setting('kinflow.test.calendar_worker_today')::date + 2
  ),
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.occurrence_version, result.exception_version, result.changed
    )
    from public.update_recurring_calendar_occurrence(
      '46000000-0000-4000-8000-000000000011',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_worker_series')::uuid,
      current_setting(
        'kinflow.test.calendar_worker_exception_occurrence'
      )::uuid,
      1, 'Worker exception', null, false,
      current_setting('kinflow.test.calendar_worker_today')::date + 20,
      time '16:45', 75, null, 'Asia/Seoul', 'later',
      array['30000000-0000-4000-8000-000000000102'::uuid]
    ) as result
  ),
  '2:1:t',
  'future Calendar slot becomes a moved exception before repair'
);
reset role;
select lives_ok(
  $$
    delete from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
        'kinflow.test.calendar_worker_series'
      )::uuid
      and occurrence.recurrence_local_start_date =
        current_setting('kinflow.test.calendar_worker_today')::date + 10
  $$,
  'fixture removes one source slot inside the repair lookback window'
);
set local role service_role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.claimed_count, result.succeeded_count,
      result.failed_count, result.changed_count, result.batch_exhausted
    )
    from public.run_calendar_horizon_worker(
      current_setting('kinflow.test.calendar_worker_as_of')::timestamptz,
      365, 31, 100,
      current_setting('kinflow.test.calendar_worker_series')::uuid
    ) as result
  ),
  '1:1:0:6:f',
  'targeted worker repairs one gap and extends five dates beyond year one'
);
reset role;
select ok(
  exists (
    select 1
    from app_private.calendar_materialization_states as state
    where state.series_id = current_setting(
        'kinflow.test.calendar_worker_series'
      )::uuid
      and state.revision_id = current_setting(
        'kinflow.test.calendar_worker_revision'
      )::uuid
      and state.covered_through =
        current_setting('kinflow.test.calendar_worker_today')::date + 365
      and state.last_changed_count = 6
      and state.attempt_count = 1
      and state.last_result = 'succeeded'
  ),
  'worker records exact successful coverage and aggregate change count'
);
select ok(
  exists (
    select 1
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
        'kinflow.test.calendar_worker_series'
      )::uuid
      and occurrence.recurrence_local_start_date =
        current_setting('kinflow.test.calendar_worker_today')::date + 10
      and occurrence.revision_id = current_setting(
        'kinflow.test.calendar_worker_revision'
      )::uuid
      and occurrence.status = 'scheduled'
      and occurrence.version = 1
  ),
  'repair recreates the missing canonical source slot'
);
select is(
  (
    select pg_catalog.count(*)
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
        'kinflow.test.calendar_worker_series'
      )::uuid
      and occurrence.recurrence_local_start_date between
        current_setting('kinflow.test.calendar_worker_today')::date + 361
        and current_setting('kinflow.test.calendar_worker_today')::date + 365
      and occurrence.status = 'scheduled'
  ),
  5::bigint,
  'worker extends the exact five dates beyond initial materialization'
);
select ok(
  exists (
    select 1
    from public.event_occurrences as occurrence
    join public.event_occurrence_exceptions as exception
      on exception.occurrence_id = occurrence.id
    join public.event_series_revisions as revision
      on revision.id = occurrence.revision_id
    where occurrence.id = current_setting(
        'kinflow.test.calendar_worker_exception_occurrence'
      )::uuid
      and occurrence.recurrence_local_start_date =
        current_setting('kinflow.test.calendar_worker_today')::date + 2
      and occurrence.local_start_date =
        current_setting('kinflow.test.calendar_worker_today')::date + 20
      and (occurrence.starts_at at time zone occurrence.timezone)::time =
        time '16:45'
      and occurrence.version = 2
      and exception.version = 1
      and not exception.cancelled
      and revision.snapshot_title = 'Worker exception'
  ),
  'repair does not overwrite or version-bump an explicit exception'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', pg_catalog.count(*),
      pg_catalog.count(distinct occurrence.occurrence_key)
    )
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.calendar_worker_series'
    )::uuid
  ),
  '371:371',
  'repair and extension retain globally unique canonical occurrence keys'
);

set local role service_role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.claimed_count, result.succeeded_count,
      result.failed_count, result.changed_count
    )
    from public.run_calendar_horizon_worker(
      current_setting('kinflow.test.calendar_worker_as_of')::timestamptz,
      365, 31, 100,
      current_setting('kinflow.test.calendar_worker_series')::uuid
    ) as result
  ),
  '1:1:0:0',
  'targeted exact replay claims the series but produces no row changes'
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', state.attempt_count, state.last_changed_count,
      state.covered_through::text
    )
    from app_private.calendar_materialization_states as state
    where state.series_id = current_setting(
      'kinflow.test.calendar_worker_series'
    )::uuid
  ),
  '2:0:'
    || (current_setting('kinflow.test.calendar_worker_today')::date + 365)::text,
  'targeted replay advances only aggregate attempt metadata'
);
set local role service_role;
select is(
  (
    select result.claimed_count
    from public.run_calendar_horizon_worker(
      current_setting('kinflow.test.calendar_worker_as_of')::timestamptz,
      365, 31, 100, null
    ) as result
  ),
  0,
  'untargeted worker skips a covered series before its repair time'
);
reset role;

-- An until-bounded series becomes permanently complete, while an ended series
-- is excluded even from targeted repair.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101', true
);
select is(
  (
    select materialized_count
    from public.create_recurring_calendar_event(
      '46000000-0000-4000-8000-000000000020',
      '20000000-0000-4000-8000-000000000101',
      'Calendar horizon until', null, false,
      current_setting('kinflow.test.calendar_worker_today')::date - 2,
      time '11:00', 20, null, 'Asia/Seoul', 'earlier',
      jsonb_build_object(
        'frequency', 'daily', 'interval', 1,
        'end', jsonb_build_object(
          'type', 'until',
          'localDate',
          (current_setting('kinflow.test.calendar_worker_today')::date + 5)::text
        )
      ),
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  ),
  8,
  'until-bounded fixture materializes its exact finite date set'
);
select set_config(
  'kinflow.test.calendar_worker_until_series',
  (
    select series.id::text
    from public.event_series as series
    where series.title = 'Calendar horizon until'
  ),
  true
);
reset role;
set local role service_role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.claimed_count, result.succeeded_count,
      result.failed_count, result.changed_count
    )
    from public.run_calendar_horizon_worker(
      current_setting('kinflow.test.calendar_worker_as_of')::timestamptz,
      365, 7, 100,
      current_setting('kinflow.test.calendar_worker_until_series')::uuid
    ) as result
  ),
  '1:1:0:0',
  'finite series is checked without duplicating its already complete window'
);
reset role;
select ok(
  exists (
    select 1
    from app_private.calendar_materialization_states as state
    where state.series_id = current_setting(
        'kinflow.test.calendar_worker_until_series'
      )::uuid
      and state.covered_through =
        current_setting('kinflow.test.calendar_worker_today')::date + 5
      and state.next_repair_at = 'infinity'::timestamptz
      and state.last_changed_count = 0
  ),
  'until-complete series records infinity and needs no periodic repair'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101', true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.cancelled_count, result.preserved_past_count, result.changed
    )
    from public.cancel_recurring_calendar_series(
      '46000000-0000-4000-8000-000000000030',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_worker_series')::uuid, 1
    ) as result
  ),
  '366:5:t',
  'ending the rolling fixture cancels only today and future occurrences'
);
reset role;
set local role service_role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.claimed_count, result.succeeded_count,
      result.failed_count, result.changed_count
    )
    from public.run_calendar_horizon_worker(
      current_setting('kinflow.test.calendar_worker_as_of')::timestamptz,
      365, 31, 100,
      current_setting('kinflow.test.calendar_worker_series')::uuid
    ) as result
  ),
  '0:0:0:0',
  'targeted worker excludes an ended Calendar series'
);
reset role;
select ok(
  not exists (
    select 1
    from app_private.calendar_materialization_states as state
    where state.series_id = current_setting(
      'kinflow.test.calendar_worker_series'
    )::uuid
  ),
  'series end removes its rolling state while preserving occurrence history'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', pg_catalog.count(*),
      pg_catalog.sum(run.claimed_count),
      pg_catalog.sum(run.failed_count),
      pg_catalog.sum(run.changed_count)
    )
    from app_private.calendar_materialization_runs as run
    where run.target_series_id in (
      '46000000-0000-4000-8000-000000000001',
      current_setting('kinflow.test.calendar_worker_series')::uuid,
      current_setting('kinflow.test.calendar_worker_until_series')::uuid
    )
    or (
      run.target_series_id is null
      and run.as_of = current_setting(
        'kinflow.test.calendar_worker_as_of'
      )::timestamptz
    )
  ),
  '6:3:0:6',
  'aggregate run audit reflects all targeted and untargeted invocations'
);
select throws_ok(
  $$
    update app_private.calendar_materialization_runs
    set changed_count = 0
    where changed_count > 0
  $$,
  '55000', 'calendar materialization runs are immutable',
  'Calendar worker run audit rejects in-place mutation'
);

select * from finish();
rollback;
