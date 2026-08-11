begin;
set constraints all deferred;

select plan(64);

-- Schema, compatibility, and least-privilege contract.
select has_function(
  'public',
  'create_repeating_chore',
  array[
    'uuid', 'uuid', 'text', 'text', 'uuid', 'date',
    'time without time zone', 'jsonb'
  ],
  'repeating chore command exists'
);
select has_function(
  'public',
  'get_today_chores_v2',
  array['uuid'],
  'recurrence-aware Today v2 exists'
);
select has_function(
  'public',
  'get_today_chores',
  array['uuid'],
  'legacy Today v1 remains available'
);
select has_function(
  'app_private',
  'is_valid_chore_recurrence_rule',
  array['jsonb'],
  'canonical recurrence validator exists'
);
select has_function(
  'app_private',
  'materialize_chore_revision',
  array['uuid', 'uuid', 'uuid', 'date'],
  'bounded recurrence materializer exists'
);
select has_table(
  'app_private',
  'chore_repeating_command_requests',
  'private repeating idempotency table exists'
);
select ok(
  exists (
    select 1
    from pg_constraint
    join pg_class on pg_class.oid = pg_constraint.conrelid
    join pg_namespace on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'chore_series_revisions'
      and pg_constraint.conname = 'chore_recurrence_rule_valid_ck'
      and pg_constraint.convalidated
  ),
  'recurrence validation constraint is present and validated'
);
select ok(
  (
    select bool_and(pg_proc.prosecdef)
      and bool_and(pg_proc.proconfig @> array['search_path=""']::text[])
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname in (
        'create_repeating_chore',
        'get_today_chores_v2'
      )
  ),
  'public repeating functions are security-definer with empty search paths'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.create_repeating_chore(uuid,uuid,text,text,uuid,date,time without time zone,jsonb)',
    'execute'
  )
    and has_function_privilege(
      'authenticated',
      'public.get_today_chores_v2(uuid)',
      'execute'
    ),
  'authenticated clients can execute mediated repeating functions'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.create_repeating_chore(uuid,uuid,text,text,uuid,date,time without time zone,jsonb)',
    'execute'
  )
    and not has_function_privilege(
      'anon',
      'public.get_today_chores_v2(uuid)',
      'execute'
    ),
  'anonymous clients cannot execute repeating functions'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.chore_repeating_command_requests',
    'select'
  ),
  'clients cannot inspect repeating command records'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.is_valid_chore_recurrence_rule(jsonb)',
    'execute'
  )
    and not has_function_privilege(
      'authenticated',
      'app_private.materialize_chore_revision(uuid,uuid,uuid,date)',
      'execute'
    ),
  'clients cannot execute private recurrence helpers'
);
select hasnt_column(
  'app_private',
  'chore_repeating_command_requests',
  'title',
  'repeating command records do not store titles'
);
select hasnt_column(
  'app_private',
  'chore_repeating_command_requests',
  'description',
  'repeating command records do not store notes'
);

-- Strict supported-subset validation.
select is(
  app_private.is_valid_chore_recurrence_rule('{"type":"once"}'::jsonb),
  true,
  'existing one-time recurrence definition remains valid'
);
select is(
  app_private.is_valid_chore_recurrence_rule(
    '{"frequency":"daily","interval":1,"end":{"type":"never"}}'::jsonb
  ),
  true,
  'daily never-ending rule is valid'
);
select is(
  app_private.is_valid_chore_recurrence_rule(
    '{"frequency":"weekly","interval":2,"weekdays":["MO","WE"],"end":{"type":"count","count":5}}'::jsonb
  ),
  true,
  'weekly multi-day count rule is valid'
);
select is(
  app_private.is_valid_chore_recurrence_rule(
    '{"frequency":"monthly","interval":1,"monthDay":31,"end":{"type":"until","localDate":"2028-12-31"}}'::jsonb
  ),
  true,
  'monthly until rule is valid'
);
select is(
  app_private.is_valid_chore_recurrence_rule(
    '{"frequency":"daily","interval":1,"end":{"type":"never"},"extra":true}'::jsonb
  ),
  false,
  'unknown recurrence keys are rejected'
);
select is(
  app_private.is_valid_chore_recurrence_rule(
    '{"frequency":"daily","interval":1.5,"end":{"type":"never"}}'::jsonb
  ),
  false,
  'fractional intervals are rejected'
);
select is(
  app_private.is_valid_chore_recurrence_rule(
    '{"frequency":"weekly","interval":1,"weekdays":["MO","MO"],"end":{"type":"never"}}'::jsonb
  ),
  false,
  'duplicate weekdays are rejected'
);
select is(
  app_private.is_valid_chore_recurrence_rule(
    '{"frequency":"monthly","interval":1,"monthDay":32,"end":{"type":"never"}}'::jsonb
  ),
  false,
  'out-of-range month days are rejected'
);
select is(
  app_private.is_valid_chore_recurrence_rule(
    '{"frequency":"daily","interval":1,"end":{"type":"until","localDate":"2028-02-30"}}'::jsonb
  ),
  false,
  'invalid calendar end dates are rejected'
);

-- Authentication and anchored creation validation.
select throws_ok(
  $$
    select * from public.create_repeating_chore(
      '43000000-0000-4000-8000-000000000601',
      '20000000-0000-4000-8000-000000000101',
      'Unauthenticated repeat',
      null,
      '30000000-0000-4000-8000-000000000101',
      '2028-01-03',
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    )
  $$,
  'KFC01',
  'authentication required',
  'repeating create derives identity from JWT'
);
select throws_ok(
  $$select * from public.get_today_chores_v2(
    '20000000-0000-4000-8000-000000000101'
  )$$,
  'KFC01',
  'authentication required',
  'Today v2 requires authentication'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.create_repeating_chore(
      '43000000-0000-4000-8000-000000000602',
      '20000000-0000-4000-8000-000000000101',
      'Bad weekly anchor',
      null,
      '30000000-0000-4000-8000-000000000101',
      '2028-01-03',
      null,
      '{"frequency":"weekly","interval":1,"weekdays":["TU"],"end":{"type":"never"}}'
    )
  $$,
  'KFC07',
  'invalid chore recurrence rule',
  'weekly rule must include the first due weekday'
);
select throws_ok(
  $$
    select * from public.create_repeating_chore(
      '43000000-0000-4000-8000-000000000603',
      '20000000-0000-4000-8000-000000000101',
      'Bad until boundary',
      null,
      '30000000-0000-4000-8000-000000000101',
      '2028-01-03',
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"until","localDate":"2028-01-02"}}'
    )
  $$,
  'KFC07',
  'invalid chore recurrence rule',
  'until date cannot precede the first due date'
);
select throws_ok(
  $$
    select * from public.create_repeating_chore(
      '43000000-0000-4000-8000-000000000604',
      '20000000-0000-4000-8000-000000000101',
      'Once through repeat API',
      null,
      '30000000-0000-4000-8000-000000000101',
      '2028-01-03',
      null,
      '{"type":"once"}'
    )
  $$,
  'KFC07',
  'invalid chore recurrence rule',
  'one-time rules cannot use the repeating command'
);

-- Daily first-year materialization, local-time conversion, and replay.
select is(
  (
    select result.created
    from public.create_repeating_chore(
      '43000000-0000-4000-8000-000000000605',
      '20000000-0000-4000-8000-000000000101',
      'Daily timed repeat',
      'Synthetic repeat notes',
      '30000000-0000-4000-8000-000000000102',
      '2028-01-01',
      '09:00',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    ) as result
  ),
  true,
  'daily repeating create reports a new series'
);
select set_config(
  'kinflow.test.daily_series_id',
  (
    select series.id::text
    from public.chore_series as series
    where series.title = 'Daily timed repeat'
  ),
  true
);
select is(
  (
    select result.materialized_count
    from public.create_repeating_chore(
      '43000000-0000-4000-8000-000000000605',
      '20000000-0000-4000-8000-000000000101',
      'Daily timed repeat',
      'Synthetic repeat notes',
      '30000000-0000-4000-8000-000000000102',
      '2028-01-01',
      '09:00',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    ) as result
  ),
  366,
  'daily replay returns the bounded 366-occurrence summary'
);
select is(
  (
    select min(occurrence.due_local_date)::text
      || ':' || max(occurrence.due_local_date)::text
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.daily_series_id'
    )::uuid
  ),
  '2028-01-01:2028-12-31',
  'daily materialization includes the bounded first-year window'
);
select is(
  (
    select count(distinct occurrence.occurrence_key)
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.daily_series_id'
    )::uuid
  ),
  366::bigint,
  'daily occurrences have unique stable keys'
);
select ok(
  exists (
    select 1
    from public.chore_series as series
    join public.chore_series_revisions as revision
      on revision.id = series.active_revision_id
    where series.id = current_setting('kinflow.test.daily_series_id')::uuid
      and revision.recurrence_rule =
        '{"frequency":"daily","interval":1,"end":{"type":"never"}}'::jsonb
      and revision.revision_number = 1
  ),
  'series identity and canonical revision definition remain separate'
);
select is(
  (
    select occurrence.due_at
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.daily_series_id'
    )::uuid
      and occurrence.due_local_date = '2028-01-01'
  ),
  '2028-01-01 00:00:00+00'::timestamptz,
  'household local 09:00 is materialized as the expected UTC instant'
);
select is(
  (
    select result.created
    from public.create_repeating_chore(
      '43000000-0000-4000-8000-000000000605',
      '20000000-0000-4000-8000-000000000101',
      'Daily timed repeat',
      'Synthetic repeat notes',
      '30000000-0000-4000-8000-000000000102',
      '2028-01-01',
      '09:00',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    ) as result
  ),
  false,
  'same-key same-input replay reports the original result'
);
select is(
  (
    select result.series_id
    from public.create_repeating_chore(
      '43000000-0000-4000-8000-000000000605',
      '20000000-0000-4000-8000-000000000101',
      'Daily timed repeat',
      'Synthetic repeat notes',
      '30000000-0000-4000-8000-000000000102',
      '2028-01-01',
      '09:00',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    ) as result
  ),
  current_setting('kinflow.test.daily_series_id')::uuid,
  'replay returns the original series identity'
);
select is(
  (
    select count(*)
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.daily_series_id'
    )::uuid
  ),
  366::bigint,
  'command replay does not duplicate occurrences'
);
select throws_ok(
  $$
    select * from public.create_repeating_chore(
      '43000000-0000-4000-8000-000000000605',
      '20000000-0000-4000-8000-000000000101',
      'Daily timed repeat',
      'Synthetic repeat notes',
      '30000000-0000-4000-8000-000000000102',
      '2028-01-01',
      '09:00',
      '{"frequency":"daily","interval":2,"end":{"type":"never"}}'
    )
  $$,
  'KFC04',
  'idempotency key reused with different chore input',
  'same key with a different recurrence rule is rejected'
);

reset role;
select is(
  app_private.materialize_chore_revision(
    '20000000-0000-4000-8000-000000000101',
    current_setting('kinflow.test.daily_series_id')::uuid,
    (
      select series.active_revision_id
      from public.chore_series as series
      where series.id = current_setting('kinflow.test.daily_series_id')::uuid
    ),
    '2028-12-31'
  ),
  0,
  'materializer retry inserts no duplicate rows'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);

-- Count, multi-weekday, monthly missing-day, and all-day fixtures.
select is(
  (
    select result.materialized_count
    from public.create_repeating_chore(
      '43000000-0000-4000-8000-000000000606',
      '20000000-0000-4000-8000-000000000101',
      'Daily count repeat',
      null,
      '30000000-0000-4000-8000-000000000101',
      '2028-02-01',
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":3}}'
    ) as result
  ),
  3,
  'count end materializes only the requested number of dates'
);
select is(
  (
    select string_agg(
      occurrence.due_local_date::text,
      ','
      order by occurrence.due_local_date
    )
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Daily count repeat'
  ),
  '2028-02-01,2028-02-02,2028-02-03',
  'count end keeps exact ordered daily dates'
);
select is(
  (
    select result.materialized_count
    from public.create_repeating_chore(
      '43000000-0000-4000-8000-000000000607',
      '20000000-0000-4000-8000-000000000101',
      'Weekly multi-day repeat',
      null,
      '30000000-0000-4000-8000-000000000101',
      '2028-01-03',
      null,
      '{"frequency":"weekly","interval":1,"weekdays":["MO","WE"],"end":{"type":"count","count":5}}'
    ) as result
  ),
  5,
  'weekly multi-day count rule materializes five dates'
);
select is(
  (
    select string_agg(
      occurrence.due_local_date::text,
      ','
      order by occurrence.due_local_date
    )
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Weekly multi-day repeat'
  ),
  '2028-01-03,2028-01-05,2028-01-10,2028-01-12,2028-01-17',
  'weekly materialization follows ISO weekdays'
);
select is(
  (
    select result.materialized_count
    from public.create_repeating_chore(
      '43000000-0000-4000-8000-000000000608',
      '20000000-0000-4000-8000-000000000101',
      'Monthly day 31 repeat',
      null,
      '30000000-0000-4000-8000-000000000101',
      '2028-01-31',
      null,
      '{"frequency":"monthly","interval":1,"monthDay":31,"end":{"type":"never"}}'
    ) as result
  ),
  7,
  'monthly day 31 skips months without that local date'
);
select is(
  (
    select string_agg(
      to_char(occurrence.due_local_date, 'YYYY-MM-DD'),
      ','
      order by occurrence.due_local_date
    )
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Monthly day 31 repeat'
  ),
  '2028-01-31,2028-03-31,2028-05-31,2028-07-31,2028-08-31,2028-10-31,2028-12-31',
  'monthly missing days are skipped rather than clamped'
);
select ok(
  not exists (
    select 1
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title in (
      'Daily count repeat',
      'Weekly multi-day repeat',
      'Monthly day 31 repeat'
    )
      and occurrence.due_at is not null
  ),
  'all-day repeating occurrences keep a null instant'
);

-- Today v2 metadata and occurrence completion/history isolation.
select is(
  (
    select result.materialized_count
    from public.create_repeating_chore(
      '43000000-0000-4000-8000-000000000609',
      '20000000-0000-4000-8000-000000000101',
      'Today daily repeat',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":2}}'
    ) as result
  ),
  2,
  'Today fixture creates two independent daily occurrences'
);
select is(
  (
    select today.recurrence_frequency
    from public.get_today_chores_v2(
      '20000000-0000-4000-8000-000000000101'
    ) as today
    where today.title = 'Today daily repeat'
  ),
  'daily',
  'Today v2 exposes allowlisted recurrence frequency'
);
select is(
  (
    select count(*)
    from public.get_today_chores(
      '20000000-0000-4000-8000-000000000101'
    ) as today
    where today.title = 'Today daily repeat'
  ),
  1::bigint,
  'legacy Today v1 still returns recurring occurrences'
);
select lives_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '43000000-0000-4000-8000-000000000610',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Today daily repeat'
          and occurrence.due_local_date =
            (clock_timestamp() at time zone 'Asia/Seoul')::date
      ),
      1,
      true
    )
  $$,
  'a materialized recurring occurrence can be completed'
);
select ok(
  exists (
    select 1
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Today daily repeat'
      and occurrence.due_local_date =
        (clock_timestamp() at time zone 'Asia/Seoul')::date + 1
      and occurrence.status = 'scheduled'
      and occurrence.version = 1
  ),
  'completing one occurrence does not alter the next occurrence'
);
select ok(
  exists (
    select 1
    from public.chore_series_revisions as revision
    join public.chore_series as series on series.id = revision.series_id
    where series.title = 'Today daily repeat'
      and revision.recurrence_rule =
        '{"frequency":"daily","interval":1,"end":{"type":"count","count":2}}'::jsonb
      and revision.revision_number = 1
  ),
  'occurrence completion does not mutate recurrence definition'
);

select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '43000000-0000-4000-8000-000000000611',
      '20000000-0000-4000-8000-000000000101',
      'Today one-time compatibility',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null
    )
  $$,
  'one-time create remains compatible with recurrence validation'
);
select ok(
  exists (
    select 1
    from public.get_today_chores_v2(
      '20000000-0000-4000-8000-000000000101'
    ) as today
    where today.title = 'Today one-time compatibility'
      and today.recurrence_frequency is null
  ),
  'Today v2 keeps one-time recurrence metadata null'
);

-- Cross-household, removed member, and direct-write denial.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$
    select * from public.create_repeating_chore(
      '43000000-0000-4000-8000-000000000612',
      '20000000-0000-4000-8000-000000000101',
      'Outsider repeat',
      null,
      '30000000-0000-4000-8000-000000000101',
      '2028-01-01',
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'outsider cannot create a repeating chore in another household'
);
select throws_ok(
  $$select * from public.get_today_chores_v2(
    '20000000-0000-4000-8000-000000000101'
  )$$,
  'KFC03',
  'chore not found or forbidden',
  'outsider cannot query another household Today v2'
);
select is(
  (
    select count(*)
    from public.chore_series
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  0::bigint,
  'chore RLS hides another household recurring series'
);

reset role;
update public.household_members
set removed_at = clock_timestamp()
where id = '30000000-0000-4000-8000-000000000102';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select throws_ok(
  $$
    select * from public.create_repeating_chore(
      '43000000-0000-4000-8000-000000000613',
      '20000000-0000-4000-8000-000000000101',
      'Removed member repeat',
      null,
      '30000000-0000-4000-8000-000000000101',
      '2028-01-01',
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'removed member cannot create a repeating chore'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    insert into public.chore_series (
      id,
      household_id,
      title,
      timezone,
      active_revision_id
    ) values (
      '44000000-0000-4000-8000-000000000699',
      '20000000-0000-4000-8000-000000000101',
      'Direct repeat injection',
      'Asia/Seoul',
      '45000000-0000-4000-8000-000000000699'
    )
  $$,
  '42501',
  'permission denied for table chore_series',
  'authenticated clients cannot directly inject recurring series'
);
select throws_ok(
  $$select * from app_private.chore_repeating_command_requests$$,
  '42501',
  'permission denied for table chore_repeating_command_requests',
  'authenticated clients cannot read private repeating command state'
);

reset role;
select is(
  (
    select count(*)
    from app_private.chore_repeating_command_requests
  ),
  5::bigint,
  'only five unique successful repeating commands persist results'
);
select is(
  (
    select string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'chore_repeating_command_requests'
  ),
  'authenticated_user_id,idempotency_key,request_hash,household_id,series_id,first_occurrence_id,result_recurrence_rule,result_materialized_through,result_materialized_count,created_at',
  'private repeating state contains only hashes, IDs, rule, date, and count'
);
select is(
  (
    select count(*)
    from app_private.chore_domain_events
    where event_name = 'chore.series_created'
  ),
  6::bigint,
  'each repeating or one-time series emits one content-free create event'
);
select is(
  (
    select count(*)
    from public.chore_occurrences
  ),
  384::bigint,
  'materialization and replay leave the exact expected occurrence count'
);

select * from finish();
rollback;
