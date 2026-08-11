begin;
set constraints all deferred;

select plan(32);

-- Schema and least-privilege read boundary.
select has_function(
  'public',
  'get_household_activation_progress',
  array['uuid'],
  'activation progress RPC exists'
);
select ok(
  (
    select pg_proc.prosecdef
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_catalog.pg_proc
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'get_household_activation_progress'
  ),
  'activation progress RPC is security-definer with an empty search path'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.get_household_activation_progress(uuid)',
    'execute'
  ),
  'authenticated clients can execute the mediated aggregate read'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.get_household_activation_progress(uuid)',
    'execute'
  ),
  'anonymous clients cannot execute the activation progress read'
);
select has_index(
  'public',
  'chore_completion_events',
  'chore_completion_events_activation_progress_idx',
  'completed actor lookup has a bounded household index'
);

select throws_ok(
  $$select * from public.get_household_activation_progress(
    '20000000-0000-4000-8000-000000000101'
  )$$,
  'KFC01',
  'authentication required',
  'activation progress derives caller identity from JWT'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$select * from public.get_household_activation_progress(null)$$,
  'KFC02',
  'invalid chore input',
  'activation progress rejects a missing household id'
);
select throws_ok(
  $$select * from public.get_household_activation_progress(
    '20000000-0000-4000-8000-000000000201'
  )$$,
  'KFC03',
  'chore not found or forbidden',
  'activation progress does not disclose another household'
);
reset role;

-- Fix the household creation instant to the current household-local date.
update public.households
set created_at = (
  (pg_catalog.clock_timestamp() at time zone 'Asia/Seoul')::date::timestamp
  at time zone 'Asia/Seoul'
)
where id = '20000000-0000-4000-8000-000000000101';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select pg_catalog.array_agg(field.key order by field.key)::text
    from public.get_household_activation_progress(
      '20000000-0000-4000-8000-000000000101'
    ) as progress
    cross join lateral pg_catalog.jsonb_object_keys(
      pg_catalog.to_jsonb(progress)
    ) as field(key)
  ),
  '{adult_participant_progress,chore_creation_progress,distinct_adult_completer_progress,household_id,return_after_first_day_reached}',
  'projection exposes only the exact capped content-free allowlist'
);
select is(
  (
    select progress.household_id
    from public.get_household_activation_progress(
      '20000000-0000-4000-8000-000000000101'
    ) as progress
  ),
  '20000000-0000-4000-8000-000000000101'::uuid,
  'projection returns the exact requested household id'
);
select is(
  (
    select progress.adult_participant_progress
    from public.get_household_activation_progress(
      '20000000-0000-4000-8000-000000000101'
    ) as progress
  ),
  2::smallint,
  'two distinct fixture adults satisfy the participation milestone'
);
select is(
  (
    select progress.chore_creation_progress
    from public.get_household_activation_progress(
      '20000000-0000-4000-8000-000000000101'
    ) as progress
  ),
  0::smallint,
  'a household with no series-created event starts at zero chores'
);
select is(
  (
    select progress.distinct_adult_completer_progress
    from public.get_household_activation_progress(
      '20000000-0000-4000-8000-000000000101'
    ) as progress
  ),
  0::smallint,
  'a household with no completed audit starts at zero completers'
);
select is(
  (
    select progress.return_after_first_day_reached
    from public.get_household_activation_progress(
      '20000000-0000-4000-8000-000000000101'
    ) as progress
  ),
  false,
  'the household-local creation day does not satisfy the return milestone'
);

-- Both one-time and repeating producers contribute content-free series events.
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '72000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'Activation owner item',
      null,
      '30000000-0000-4000-8000-000000000101',
      (pg_catalog.clock_timestamp() at time zone 'Asia/Seoul')::date,
      null
    )
  $$,
  'first one-time series is created'
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '72000000-0000-4000-8000-000000000102',
      '20000000-0000-4000-8000-000000000101',
      'Activation member item',
      null,
      '30000000-0000-4000-8000-000000000102',
      (pg_catalog.clock_timestamp() at time zone 'Asia/Seoul')::date,
      null
    )
  $$,
  'second one-time series is created'
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '72000000-0000-4000-8000-000000000103',
      '20000000-0000-4000-8000-000000000101',
      'Activation extra item',
      null,
      '30000000-0000-4000-8000-000000000101',
      (pg_catalog.clock_timestamp() at time zone 'Asia/Seoul')::date,
      null
    )
  $$,
  'third one-time series is created'
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '72000000-0000-4000-8000-000000000104',
      '20000000-0000-4000-8000-000000000101',
      'Activation repeating item',
      null,
      '30000000-0000-4000-8000-000000000101',
      (pg_catalog.clock_timestamp() at time zone 'Asia/Seoul')::date,
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    )
  $$,
  'repeating series contributes the same content-free creation event'
);
select is(
  (
    select progress.chore_creation_progress
    from public.get_household_activation_progress(
      '20000000-0000-4000-8000-000000000101'
    ) as progress
  ),
  3::smallint,
  'four distinct created series are privacy-capped at the goal of three'
);

-- Distinct adult completion counts accounts, not event volume.
select lives_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '73000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Activation owner item'
      ),
      1,
      true
    )
  $$,
  'owner completes one occurrence'
);
select is(
  (
    select progress.distinct_adult_completer_progress
    from public.get_household_activation_progress(
      '20000000-0000-4000-8000-000000000101'
    ) as progress
  ),
  1::smallint,
  'one adult with a completed event contributes exactly one completer'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select lives_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '73000000-0000-4000-8000-000000000102',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Activation member item'
      ),
      1,
      true
    )
  $$,
  'second adult completes their assigned occurrence'
);
select is(
  (
    select progress.distinct_adult_completer_progress
    from public.get_household_activation_progress(
      '20000000-0000-4000-8000-000000000101'
    ) as progress
  ),
  2::smallint,
  'two distinct adult accounts satisfy the completion milestone'
);
select lives_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '73000000-0000-4000-8000-000000000103',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Activation member item'
      ),
      2,
      false
    )
  $$,
  'second adult reopens the completed occurrence'
);
select is(
  (
    select progress.distinct_adult_completer_progress
    from public.get_household_activation_progress(
      '20000000-0000-4000-8000-000000000101'
    ) as progress
  ),
  2::smallint,
  'a later reopen does not erase the historical completion milestone'
);
reset role;

-- Historical milestones survive ordinary soft lifecycle changes.
update public.chore_series
set deleted_at = pg_catalog.clock_timestamp()
where title = 'Activation extra item';
update public.household_members
set removed_at = pg_catalog.clock_timestamp()
where id = '30000000-0000-4000-8000-000000000102';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select progress.adult_participant_progress
    from public.get_household_activation_progress(
      '20000000-0000-4000-8000-000000000101'
    ) as progress
  ),
  2::smallint,
  'later member removal preserves the historical participation milestone'
);
select is(
  (
    select progress.chore_creation_progress
    from public.get_household_activation_progress(
      '20000000-0000-4000-8000-000000000101'
    ) as progress
  ),
  3::smallint,
  'soft-deleting a series preserves its historical creation milestone'
);
select is(
  (
    select progress.distinct_adult_completer_progress
    from public.get_household_activation_progress(
      '20000000-0000-4000-8000-000000000101'
    ) as progress
  ),
  2::smallint,
  'later member removal preserves their historical completion milestone'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select throws_ok(
  $$select * from public.get_household_activation_progress(
    '20000000-0000-4000-8000-000000000101'
  )$$,
  'KFC03',
  'chore not found or forbidden',
  'a removed adult cannot read the household aggregate'
);
reset role;

update public.households
set created_at = (
  (
    (pg_catalog.clock_timestamp() at time zone 'Asia/Seoul')::date - 1
  )::timestamp at time zone 'Asia/Seoul'
)
where id = '20000000-0000-4000-8000-000000000101';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select progress.return_after_first_day_reached
    from public.get_household_activation_progress(
      '20000000-0000-4000-8000-000000000101'
    ) as progress
  ),
  true,
  'DB clock and household timezone satisfy the milestone after a local date boundary'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select is(
  (
    select progress.adult_participant_progress
    from public.get_household_activation_progress(
      '20000000-0000-4000-8000-000000000201'
    ) as progress
  ),
  1::smallint,
  'a one-adult household remains below the participation goal'
);
reset role;

update public.households
set deleted_at = pg_catalog.clock_timestamp()
where id = '20000000-0000-4000-8000-000000000201';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$select * from public.get_household_activation_progress(
    '20000000-0000-4000-8000-000000000201'
  )$$,
  'KFC03',
  'chore not found or forbidden',
  'a deleted household cannot read activation progress'
);
reset role;

select * from finish();
rollback;
