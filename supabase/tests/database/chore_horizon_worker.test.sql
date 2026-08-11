begin;
set constraints all deferred;

select plan(101);

-- Schema, schedule, grants, and privacy-minimal operational state.
select ok(
  exists (
    select 1
    from pg_extension
    where extname = 'pg_cron'
  ),
  'pg_cron is installed for the recurrence horizon schedule'
);
select has_function(
  'public',
  'run_chore_horizon_worker',
  array['timestamp with time zone', 'integer', 'integer', 'integer', 'uuid'],
  'bounded service worker entry point exists'
);
select has_function(
  'app_private',
  'materialize_chore_revision_window',
  array['uuid', 'uuid', 'uuid', 'date', 'date'],
  'bounded recurrence window materializer exists'
);
select has_table(
  'app_private',
  'chore_materialization_states',
  'private per-series horizon state exists'
);
select has_table(
  'app_private',
  'chore_materialization_runs',
  'private aggregate worker run audit exists'
);
select ok(
  (
    select pg_proc.prosecdef
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'run_chore_horizon_worker'
  ),
  'worker is security-definer with an empty search path'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.run_chore_horizon_worker(timestamptz,integer,integer,integer,uuid)',
    'execute'
  ),
  'service role can execute the worker'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.run_chore_horizon_worker(timestamptz,integer,integer,integer,uuid)',
    'execute'
  ),
  'authenticated clients cannot execute the worker'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.run_chore_horizon_worker(timestamptz,integer,integer,integer,uuid)',
    'execute'
  ),
  'anonymous clients cannot execute the worker'
);
select ok(
  not has_function_privilege(
    'service_role',
    'app_private.materialize_chore_revision_window(uuid,uuid,uuid,date,date)',
    'execute'
  ),
  'service role cannot bypass the worker through the private materializer'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.materialize_chore_revision_window(uuid,uuid,uuid,date,date)',
    'execute'
  ),
  'authenticated clients cannot execute the private materializer'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.chore_materialization_states',
    'select'
  ),
  'authenticated clients cannot inspect horizon state'
);
select ok(
  not has_table_privilege(
    'service_role',
    'app_private.chore_materialization_states',
    'select'
  ),
  'service role receives only the mediated aggregate result'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.chore_materialization_runs',
    'select'
  ),
  'authenticated clients cannot inspect worker runs'
);
select ok(
  not has_table_privilege(
    'service_role',
    'app_private.chore_materialization_runs',
    'select'
  ),
  'service role cannot directly read worker run audit'
);
select is(
  (
    select count(*)
    from cron.job
    where jobname = 'kinflow-chore-horizon-v1'
  ),
  1::bigint,
  'exactly one named recurrence horizon job is scheduled'
);
select is(
  (
    select concat_ws(':', schedule, username, database, active::text)
    from cron.job
    where jobname = 'kinflow-chore-horizon-v1'
  ),
  '17 * * * *:postgres:postgres:true',
  'cron job has the exact hourly schedule, owner, database, and active state'
);
select ok(
  (
    select regexp_replace(command, '[[:space:]]+', '', 'g') =
      'select*frompublic.run_chore_horizon_worker(statement_timestamp(),365,7,100,null);'
    from cron.job
    where jobname = 'kinflow-chore-horizon-v1'
  ),
  'cron job invokes the exact bounded default worker command'
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
set local role authenticated;
select throws_ok(
  $$select cron.schedule('client-job', '* * * * *', 'select 1')$$,
  '42501',
  'permission denied for schema cron',
  'authenticated clients cannot schedule jobs'
);
reset role;
set local role service_role;
select throws_ok(
  $$select cron.schedule('service-job', '* * * * *', 'select 1')$$,
  '42501',
  'permission denied for schema cron',
  'service role cannot schedule jobs'
);
reset role;
select is(
  (
    select string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'chore_materialization_states'
  ),
  'household_id,series_id,revision_id,covered_through,last_window_start,last_target_date,next_repair_at,last_attempted_at,last_succeeded_at,last_result,last_error_code,last_inserted_count,attempt_count,updated_at',
  'horizon state contains only IDs, dates, counts, and stable result codes'
);
select is(
  (
    select string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'chore_materialization_runs'
  ),
  'id,invoked_at,as_of,horizon_days,repair_lookback_days,batch_size,target_series_id,claimed_count,succeeded_count,failed_count,inserted_count,batch_exhausted,completed_at',
  'worker run audit contains only invocation controls and aggregate counts'
);
select hasnt_column(
  'app_private',
  'chore_materialization_states',
  'title',
  'horizon state does not store chore titles'
);
select hasnt_column(
  'app_private',
  'chore_materialization_runs',
  'household_id',
  'aggregate run audit does not identify a household'
);
select has_trigger(
  'app_private',
  'chore_materialization_runs',
  'chore_materialization_runs_immutable',
  'worker run audit is protected by an immutable trigger'
);

-- Role boundary and strict worker/window input validation.
set local role authenticated;
select throws_ok(
  $$
    select * from public.run_chore_horizon_worker(
      '2028-12-25 00:00:00+00', 365, 7, 100, null
    )
  $$,
  '42501',
  'permission denied for function run_chore_horizon_worker',
  'authenticated role is denied before worker execution'
);

reset role;
set local role service_role;
select throws_ok(
  $$select * from public.run_chore_horizon_worker(
    null, 365, 7, 100, null
  )$$,
  'KFW01',
  'invalid chore horizon worker input',
  'worker requires a deterministic as-of instant'
);
select throws_ok(
  $$select * from public.run_chore_horizon_worker(
    '2028-12-25 00:00:00+00', 29, 7, 100, null
  )$$,
  'KFW01',
  'invalid chore horizon worker input',
  'worker rejects a horizon below 30 days'
);
select throws_ok(
  $$select * from public.run_chore_horizon_worker(
    '2028-12-25 00:00:00+00', 366, 7, 100, null
  )$$,
  'KFW01',
  'invalid chore horizon worker input',
  'worker rejects a horizon above 365 days'
);
select throws_ok(
  $$select * from public.run_chore_horizon_worker(
    '2028-12-25 00:00:00+00', 365, 32, 100, null
  )$$,
  'KFW01',
  'invalid chore horizon worker input',
  'worker rejects a repair lookback above 31 days'
);
select throws_ok(
  $$select * from public.run_chore_horizon_worker(
    '2028-12-25 00:00:00+00', 365, 7, 0, null
  )$$,
  'KFW01',
  'invalid chore horizon worker input',
  'worker rejects an empty batch'
);
select throws_ok(
  $$select * from public.run_chore_horizon_worker(
    '2028-12-25 00:00:00+00', 365, 7, 501, null
  )$$,
  'KFW01',
  'invalid chore horizon worker input',
  'worker rejects a batch above 500 series'
);
select is(
  (
    select concat_ws(
      ':',
      result.claimed_count,
      result.succeeded_count,
      result.failed_count,
      result.inserted_count,
      result.batch_exhausted
    )
    from public.run_chore_horizon_worker(
      '2028-12-24 16:00:00+00',
      365,
      7,
      100,
      '4f000000-0000-4000-8000-000000000001'
    ) as result
  ),
  '0:0:0:0:f',
  'targeted repair reveals no information for an unknown series ID'
);
reset role;
select ok(
  exists (
    select 1
    from app_private.chore_materialization_runs as run
    where run.target_series_id =
      '4f000000-0000-4000-8000-000000000001'
      and run.claimed_count = 0
      and run.succeeded_count = 0
      and run.failed_count = 0
      and run.inserted_count = 0
  ),
  'zero-result targeted invocation keeps a privacy-minimal aggregate audit'
);

reset role;
select throws_ok(
  $$
    select app_private.materialize_chore_revision_window(
      '20000000-0000-4000-8000-000000000101',
      '4f000000-0000-4000-8000-000000000002',
      '4f000000-0000-4000-8000-000000000003',
      '2028-01-01',
      '2029-02-01'
    )
  $$,
  'KFW01',
  'invalid chore materialization window',
  'private materializer rejects a window above 397 inclusive days'
);

-- Daily extension beyond the original year and exception preservation.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '4f100000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Horizon daily timed',
      null,
      '30000000-0000-4000-8000-000000000101',
      '2028-01-01',
      '09:30',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    )
  $$,
  'daily horizon fixture is created with the original first-year window'
);
select set_config(
  'kinflow.test.horizon_daily_series_id',
  (
    select series.id::text
    from public.chore_series as series
    where series.title = 'Horizon daily timed'
  ),
  true
);
select lives_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '4f100000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        where occurrence.series_id = current_setting(
          'kinflow.test.horizon_daily_series_id'
        )::uuid
          and occurrence.due_local_date = '2028-12-20'
      ),
      1,
      true
    )
  $$,
  'one existing daily occurrence is completed before horizon extension'
);
select lives_ok(
  $$
    select * from public.skip_chore_occurrence(
      '4f100000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        where occurrence.series_id = current_setting(
          'kinflow.test.horizon_daily_series_id'
        )::uuid
          and occurrence.due_local_date = '2028-12-21'
      ),
      1
    )
  $$,
  'one existing daily occurrence is skipped before horizon extension'
);
select lives_ok(
  $$
    select * from public.reassign_chore_occurrence(
      '4f100000-0000-4000-8000-000000000004',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        where occurrence.series_id = current_setting(
          'kinflow.test.horizon_daily_series_id'
        )::uuid
          and occurrence.due_local_date = '2028-12-22'
      ),
      1,
      '30000000-0000-4000-8000-000000000102'
    )
  $$,
  'one existing daily occurrence is reassigned before horizon extension'
);
select lives_ok(
  $$
    select * from public.reschedule_chore_occurrence(
      '4f100000-0000-4000-8000-000000000005',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        where occurrence.series_id = current_setting(
          'kinflow.test.horizon_daily_series_id'
        )::uuid
          and occurrence.due_local_date = '2028-12-23'
      ),
      1,
      '2028-12-24',
      '11:00'
    )
  $$,
  'one existing daily occurrence is rescheduled before horizon extension'
);

reset role;
set local role service_role;
select is(
  (
    select concat_ws(
      ':',
      result.claimed_count,
      result.succeeded_count,
      result.failed_count,
      result.inserted_count,
      result.batch_exhausted
    )
    from public.run_chore_horizon_worker(
      '2028-12-24 16:00:00+00',
      365,
      7,
      100,
      current_setting('kinflow.test.horizon_daily_series_id')::uuid
    ) as result
  ),
  '1:1:0:359:f',
  'targeted daily worker extends beyond the original year in one bounded window'
);

reset role;
select is(
  (
    select count(*)
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.horizon_daily_series_id'
    )::uuid
  ),
  725::bigint,
  'daily series contains the initial 366 plus 359 extended occurrences'
);
select is(
  (
    select max(occurrence.due_local_date)
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.horizon_daily_series_id'
    )::uuid
  ),
  '2029-12-25'::date,
  'daily series reaches the household-local future target'
);
select is(
  (
    select occurrence.due_at
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.horizon_daily_series_id'
    )::uuid
      and occurrence.due_local_date = '2029-06-01'
  ),
  '2029-06-01 00:30:00+00'::timestamptz,
  'late-window timed occurrence keeps Asia/Seoul local-to-UTC semantics'
);
select is(
  (
    select concat_ws(
      ':', occurrence.status::text, occurrence.version,
      occurrence.completed_at is not null
    )
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.horizon_daily_series_id'
    )::uuid
      and occurrence.occurrence_key = current_setting(
        'kinflow.test.horizon_daily_series_id'
      ) || ':2028-12-20'
  ),
  'completed:2:t',
  'worker does not overwrite a completed occurrence'
);
select is(
  (
    select concat_ws(':', occurrence.status::text, occurrence.version)
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.horizon_daily_series_id'
    )::uuid
      and occurrence.occurrence_key = current_setting(
        'kinflow.test.horizon_daily_series_id'
      ) || ':2028-12-21'
  ),
  'skipped:2',
  'worker does not restore a skipped occurrence'
);
select is(
  (
    select concat_ws(
      ':', occurrence.assignee_member_id::text, occurrence.version
    )
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.horizon_daily_series_id'
    )::uuid
      and occurrence.occurrence_key = current_setting(
        'kinflow.test.horizon_daily_series_id'
      ) || ':2028-12-22'
  ),
  '30000000-0000-4000-8000-000000000102:2',
  'worker does not overwrite a reassigned occurrence'
);
select is(
  (
    select concat_ws(
      ':', occurrence.due_local_date::text,
      to_char(occurrence.due_at at time zone 'UTC', 'YYYY-MM-DD HH24:MI'),
      occurrence.version
    )
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.horizon_daily_series_id'
    )::uuid
      and occurrence.occurrence_key = current_setting(
        'kinflow.test.horizon_daily_series_id'
      ) || ':2028-12-23'
  ),
  '2028-12-24:2028-12-24 02:00:2',
  'worker preserves a rescheduled occurrence under its stable original key'
);
select is(
  (
    select concat_ws(
      ':', series.version, revision.revision_number,
      revision.default_assignee_member_id::text,
      revision.recurrence_rule->>'frequency'
    )
    from public.chore_series as series
    join public.chore_series_revisions as revision
      on revision.id = series.active_revision_id
    where series.id = current_setting(
      'kinflow.test.horizon_daily_series_id'
    )::uuid
  ),
  '1:1:30000000-0000-4000-8000-000000000101:daily',
  'worker leaves series version and canonical revision definition unchanged'
);
select is(
  (
    select concat_ws(
      ':', state.covered_through::text, state.last_window_start::text,
      state.last_target_date::text, state.last_result,
      state.last_inserted_count, state.attempt_count,
      (state.next_repair_at = '2028-12-25 16:00:00+00'::timestamptz)
    )
    from app_private.chore_materialization_states as state
    where state.series_id = current_setting(
      'kinflow.test.horizon_daily_series_id'
    )::uuid
  ),
  '2029-12-25:2028-12-18:2029-12-25:succeeded:359:1:t',
  'daily coverage state records the bounded window and next repair gate'
);
select ok(
  exists (
    select 1
    from app_private.chore_materialization_runs as run
    where run.target_series_id = current_setting(
      'kinflow.test.horizon_daily_series_id'
    )::uuid
      and run.as_of = '2028-12-24 16:00:00+00'::timestamptz
      and run.claimed_count = 1
      and run.succeeded_count = 1
      and run.failed_count = 0
      and run.inserted_count = 359
      and not run.batch_exhausted
  ),
  'daily worker stores one privacy-minimal successful run aggregate'
);

set local role service_role;
select is(
  (
    select result.inserted_count
    from public.run_chore_horizon_worker(
      '2028-12-24 16:00:00+00',
      365,
      7,
      100,
      current_setting('kinflow.test.horizon_daily_series_id')::uuid
    ) as result
  ),
  0,
  'same targeted window replay inserts no duplicate occurrences'
);

reset role;
select is(
  (
    select count(*)
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.horizon_daily_series_id'
    )::uuid
  ),
  725::bigint,
  'targeted replay preserves the exact occurrence count'
);
select is(
  (
    select state.attempt_count
    from app_private.chore_materialization_states as state
    where state.series_id = current_setting(
      'kinflow.test.horizon_daily_series_id'
    )::uuid
  ),
  2::bigint,
  'targeted replay advances only the operational attempt count'
);

delete from public.chore_occurrences as occurrence
where occurrence.series_id = current_setting(
  'kinflow.test.horizon_daily_series_id'
)::uuid
  and occurrence.due_local_date = '2029-06-01';

set local role service_role;
select is(
  (
    select result.inserted_count
    from public.run_chore_horizon_worker(
      '2028-12-24 16:00:00+00',
      365,
      7,
      100,
      current_setting('kinflow.test.horizon_daily_series_id')::uuid
    ) as result
  ),
  1,
  'targeted replay repairs one missing future occurrence'
);

reset role;
select is(
  (
    select concat_ws(
      ':', count(*), min(occurrence.status::text),
      min(occurrence.assignee_member_id::text), min(occurrence.version)
    )
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.horizon_daily_series_id'
    )::uuid
      and occurrence.occurrence_key = current_setting(
        'kinflow.test.horizon_daily_series_id'
      ) || ':2029-06-01'
  ),
  '1:scheduled:30000000-0000-4000-8000-000000000101:1',
  'repair restores the stable key with canonical default state'
);
select is(
  (
    select count(*)
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.horizon_daily_series_id'
    )::uuid
  ),
  725::bigint,
  'repair returns the daily series to its exact covered count'
);
select throws_ok(
  $$
    select app_private.materialize_chore_revision(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.horizon_daily_series_id')::uuid,
      (
        select series.active_revision_id
        from public.chore_series as series
        where series.id = current_setting(
          'kinflow.test.horizon_daily_series_id'
        )::uuid
      ),
      '2029-01-01'
    )
  $$,
  'KFC07',
  'invalid chore recurrence rule',
  'legacy initial materializer retains its start-plus-365 bound'
);

-- Late bounded windows preserve weekly global count ordinals.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '4f200000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Horizon weekly count',
      null,
      '30000000-0000-4000-8000-000000000101',
      '2028-01-03',
      null,
      '{"frequency":"weekly","interval":2,"weekdays":["MO","WE"],"end":{"type":"count","count":60}}'
    )
  $$,
  'weekly count fixture is created'
);
select set_config(
  'kinflow.test.horizon_weekly_series_id',
  (
    select series.id::text
    from public.chore_series as series
    where series.title = 'Horizon weekly count'
  ),
  true
);
select is(
  (
    select count(*)
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.horizon_weekly_series_id'
    )::uuid
  ),
  53::bigint,
  'initial first-year window contains the first 53 weekly occurrences'
);

reset role;
set local role service_role;
select is(
  (
    select result.inserted_count
    from public.run_chore_horizon_worker(
      '2028-12-25 00:00:00+00',
      365,
      7,
      100,
      current_setting('kinflow.test.horizon_weekly_series_id')::uuid
    ) as result
  ),
  7,
  'late weekly window adds only the seven remaining globally-counted dates'
);

reset role;
select is(
  (
    select count(*)
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.horizon_weekly_series_id'
    )::uuid
  ),
  60::bigint,
  'weekly count rule ends at exactly 60 occurrences'
);
select is(
  (
    select max(occurrence.due_local_date)
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.horizon_weekly_series_id'
    )::uuid
  ),
  '2028-01-03'::date + 408,
  'weekly multi-day ordinal ends on the exact sixtieth date'
);
select ok(
  (
    select state.next_repair_at = 'infinity'::timestamptz
      and state.covered_through = '2029-12-25'::date
      and state.last_inserted_count = 7
    from app_private.chore_materialization_states as state
    where state.series_id = current_setting(
      'kinflow.test.horizon_weekly_series_id'
    )::uuid
  ),
  'completed count series is marked fully covered and no longer scheduled'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '4f200000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      'Horizon weekly midweek count',
      null,
      '30000000-0000-4000-8000-000000000101',
      '2028-01-05',
      null,
      '{"frequency":"weekly","interval":1,"weekdays":["MO","WE"],"end":{"type":"count","count":110}}'
    )
  $$,
  'midweek weekly count fixture is created'
);
select set_config(
  'kinflow.test.horizon_midweek_series_id',
  (
    select series.id::text
    from public.chore_series as series
    where series.title = 'Horizon weekly midweek count'
  ),
  true
);
select is(
  (
    select count(*)
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.horizon_midweek_series_id'
    )::uuid
  ),
  105::bigint,
  'initial midweek window excludes Monday before the Wednesday anchor'
);

reset role;
set local role service_role;
select is(
  (
    select result.inserted_count
    from public.run_chore_horizon_worker(
      '2028-12-24 16:00:00+00',
      365,
      7,
      100,
      current_setting('kinflow.test.horizon_midweek_series_id')::uuid
    ) as result
  ),
  5,
  'late midweek window applies the global ordinal after a partial first week'
);

reset role;
select is(
  (
    select count(*)
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.horizon_midweek_series_id'
    )::uuid
  ),
  110::bigint,
  'midweek weekly rule ends at exactly 110 occurrences'
);
select is(
  (
    select max(occurrence.due_local_date)
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.horizon_midweek_series_id'
    )::uuid
  ),
  '2028-01-05'::date + 383,
  'midweek global ordinal ends on the exact Monday count boundary'
);
select ok(
  (
    select state.next_repair_at = 'infinity'::timestamptz
      and state.last_inserted_count = 5
    from app_private.chore_materialization_states as state
    where state.series_id = current_setting(
      'kinflow.test.horizon_midweek_series_id'
    )::uuid
  ),
  'completed midweek count series leaves the scheduled claim set'
);

-- Monthly day-31 and until end remain exact across multiple windows.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '4f300000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Horizon monthly until',
      null,
      '30000000-0000-4000-8000-000000000101',
      '2028-01-31',
      null,
      '{"frequency":"monthly","interval":1,"monthDay":31,"end":{"type":"until","localDate":"2030-12-31"}}'
    )
  $$,
  'monthly until fixture is created'
);
select set_config(
  'kinflow.test.horizon_monthly_series_id',
  (
    select series.id::text
    from public.chore_series as series
    where series.title = 'Horizon monthly until'
  ),
  true
);
select is(
  (
    select count(*)
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.horizon_monthly_series_id'
    )::uuid
  ),
  7::bigint,
  'initial monthly year skips every month without day 31'
);

reset role;
set local role service_role;
select is(
  (
    select result.inserted_count
    from public.run_chore_horizon_worker(
      '2028-12-25 00:00:00+00',
      365,
      7,
      100,
      current_setting('kinflow.test.horizon_monthly_series_id')::uuid
    ) as result
  ),
  6,
  'first monthly extension adds only valid day-31 dates before its target'
);
select is(
  (
    select result.inserted_count
    from public.run_chore_horizon_worker(
      '2030-01-02 00:00:00+00',
      365,
      7,
      100,
      current_setting('kinflow.test.horizon_monthly_series_id')::uuid
    ) as result
  ),
  8,
  'second monthly extension reaches the exact until boundary'
);

reset role;
select is(
  (
    select count(*)
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.horizon_monthly_series_id'
    )::uuid
  ),
  21::bigint,
  'three years contain exactly 21 valid monthly day-31 occurrences'
);
select ok(
  not exists (
    select 1
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.horizon_monthly_series_id'
    )::uuid
      and (
        extract(day from occurrence.due_local_date) <> 31
        or occurrence.due_at is not null
      )
  ),
  'monthly worker neither clamps a missing day nor invents an all-day instant'
);
select is(
  (
    select max(occurrence.due_local_date)
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.horizon_monthly_series_id'
    )::uuid
  ),
  '2030-12-31'::date,
  'monthly worker stops on the exact until date'
);
select ok(
  (
    select state.next_repair_at = 'infinity'::timestamptz
      and state.covered_through = '2030-12-31'::date
    from app_private.chore_materialization_states as state
    where state.series_id = current_setting(
      'kinflow.test.horizon_monthly_series_id'
    )::uuid
  ),
  'until-complete monthly state is removed from future scheduled claims'
);

-- Normal batches are bounded and continue deterministically across invocations.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$select * from public.create_repeating_chore(
    '4f400000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000101',
    'Horizon batch A', null,
    '30000000-0000-4000-8000-000000000101',
    '2028-12-25', null,
    '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
  )$$,
  'first bounded batch fixture is created'
);
select lives_ok(
  $$select * from public.create_repeating_chore(
    '4f400000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000101',
    'Horizon batch B', null,
    '30000000-0000-4000-8000-000000000101',
    '2028-12-25', null,
    '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
  )$$,
  'second bounded batch fixture is created'
);
select lives_ok(
  $$select * from public.create_repeating_chore(
    '4f400000-0000-4000-8000-000000000003',
    '20000000-0000-4000-8000-000000000101',
    'Horizon batch C', null,
    '30000000-0000-4000-8000-000000000101',
    '2028-12-25', null,
    '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
  )$$,
  'third bounded batch fixture is created'
);

reset role;
set local role service_role;
select is(
  (
    select concat_ws(':', result.claimed_count, result.batch_exhausted)
    from public.run_chore_horizon_worker(
      '2028-12-25 00:00:00+00', 365, 7, 2, null
    ) as result
  ),
  '2:t',
  'first normal invocation stops exactly at its two-series batch bound'
);

reset role;
select is(
  (
    select count(*)
    from app_private.chore_materialization_states as state
    join public.chore_series as series on series.id = state.series_id
    where series.title like 'Horizon batch %'
  ),
  2::bigint,
  'first batch records state for exactly two new series'
);

set local role service_role;
select is(
  (
    select concat_ws(':', result.claimed_count, result.batch_exhausted)
    from public.run_chore_horizon_worker(
      '2028-12-25 00:00:00+00', 365, 7, 2, null
    ) as result
  ),
  '1:f',
  'second normal invocation continues with the remaining new series'
);

reset role;
select is(
  (
    select count(*)
    from app_private.chore_materialization_states as state
    join public.chore_series as series on series.id = state.series_id
    where series.title like 'Horizon batch %'
  ),
  3::bigint,
  'bounded continuation covers all three batch fixtures without duplication'
);

set local role service_role;
select is(
  (
    select result.claimed_count
    from public.run_chore_horizon_worker(
      '2028-12-25 00:00:00+00', 365, 7, 2, null
    ) as result
  ),
  0,
  'next-repair and coverage gates suppress an immediate normal replay'
);

-- A removed default assignee is isolated while healthy series continue.
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$select * from public.create_repeating_chore(
    '4f500000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000101',
    'Horizon unavailable assignee', null,
    '30000000-0000-4000-8000-000000000102',
    '2028-12-25', null,
    '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
  )$$,
  'unavailable-assignee worker fixture is created while member is active'
);
select lives_ok(
  $$select * from public.create_repeating_chore(
    '4f500000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000101',
    'Horizon healthy follower', null,
    '30000000-0000-4000-8000-000000000101',
    '2028-12-25', null,
    '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
  )$$,
  'healthy worker fixture is created after the poison candidate'
);

reset role;
update public.household_members
set removed_at = clock_timestamp()
where id = '30000000-0000-4000-8000-000000000102';

set local role service_role;
select is(
  (
    select concat_ws(
      ':', result.claimed_count, result.succeeded_count,
      result.failed_count, result.inserted_count,
      result.batch_exhausted
    )
    from public.run_chore_horizon_worker(
      '2029-12-26 00:00:00+00', 365, 7, 500, null
    ) as result
  ),
  '3:2:1:732:f',
  'one failed assignee series is isolated while two healthy series extend'
);

reset role;
select is(
  (
    select concat_ws(
      ':', state.last_result, state.last_error_code,
      state.covered_through is null,
      state.next_repair_at = '2029-12-26 01:00:00+00'::timestamptz
    )
    from app_private.chore_materialization_states as state
    join public.chore_series as series on series.id = state.series_id
    where series.title = 'Horizon unavailable assignee'
  ),
  'failed:assignee_unavailable:t:t',
  'failed series records only an allowlisted error and a bounded retry time'
);
select is(
  (
    select concat_ws(
      ':', state.last_result, state.last_error_code is null,
      state.covered_through::text, state.last_inserted_count
    )
    from app_private.chore_materialization_states as state
    join public.chore_series as series on series.id = state.series_id
    where series.title = 'Horizon healthy follower'
  ),
  'succeeded:t:2030-12-26:366',
  'healthy follower reaches its new horizon despite the isolated failure'
);
select is(
  (
    select max(occurrence.due_local_date)
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Horizon healthy follower'
  ),
  '2030-12-26'::date,
  'healthy follower materializes the complete next sliding year'
);
select is(
  (
    select max(occurrence.due_local_date)
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Horizon unavailable assignee'
  ),
  '2029-12-25'::date,
  'removed default assignee receives no newly materialized occurrence'
);
select is(
  (
    select concat_ws(
      ':', occurrence.status::text,
      occurrence.assignee_member_id::text,
      occurrence.version
    )
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.horizon_daily_series_id'
    )::uuid
      and occurrence.occurrence_key = current_setting(
        'kinflow.test.horizon_daily_series_id'
      ) || ':2028-12-22'
  ),
  'scheduled:30000000-0000-4000-8000-000000000102:2',
  'later worker runs still preserve the historical reassignment override'
);
select ok(
  not exists (
    select 1
    from app_private.chore_materialization_runs as run
    where run.claimed_count <> run.succeeded_count + run.failed_count
      or run.claimed_count > run.batch_size
  ),
  'every worker run keeps exact bounded aggregate accounting'
);
select throws_ok(
  $$
    update app_private.chore_materialization_runs
    set inserted_count = inserted_count + 1
    where id = (
      select run.id
      from app_private.chore_materialization_runs as run
      order by run.invoked_at
      limit 1
    )
  $$,
  '55000',
  'chore materialization runs are immutable',
  'database-side run audit cannot be rewritten'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    delete from public.chore_occurrences
    where series_id = current_setting(
      'kinflow.test.horizon_daily_series_id'
    )::uuid
  $$,
  '42501',
  'permission denied for table chore_occurrences',
  'authenticated clients cannot delete occurrences to forge repair work'
);

reset role;
select is(
  (
    select count(*)
    from cron.job
    where jobname = 'kinflow-chore-horizon-v1'
  ),
  1::bigint,
  'worker activity never duplicates or mutates the named cron schedule'
);

select * from finish();
rollback;
