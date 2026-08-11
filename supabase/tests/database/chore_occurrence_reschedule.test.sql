begin;
set constraints all deferred;

select plan(61);

-- Schema, grants, immutable audit, and content minimization.
select has_function(
  'public',
  'reschedule_chore_occurrence',
  array['uuid', 'uuid', 'uuid', 'bigint', 'date', 'time without time zone'],
  'versioned single-occurrence reschedule command exists'
);
select has_table(
  'public',
  'chore_reschedule_events',
  'immutable reschedule audit table exists'
);
select has_table(
  'app_private',
  'chore_reschedule_command_requests',
  'private reschedule idempotency table exists'
);
select col_not_null(
  'public',
  'chore_occurrences',
  'assignee_member_id',
  'every occurrence keeps an explicit assignee for Member authorization'
);
select ok(
  (
    select pg_proc.prosecdef
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'reschedule_chore_occurrence'
  ),
  'reschedule command is security-definer with an empty search path'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.reschedule_chore_occurrence(uuid,uuid,uuid,bigint,date,time without time zone)',
    'execute'
  ),
  'authenticated clients can execute the mediated reschedule command'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.reschedule_chore_occurrence(uuid,uuid,uuid,bigint,date,time without time zone)',
    'execute'
  ),
  'anonymous clients cannot execute the reschedule command'
);
select ok(
  has_table_privilege(
    'authenticated',
    'public.chore_reschedule_events',
    'select'
  ),
  'active household members can read reschedule history through RLS'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.chore_reschedule_events',
    'insert'
  )
    and not has_table_privilege(
      'authenticated',
      'public.chore_reschedule_events',
      'update'
    )
    and not has_table_privilege(
      'authenticated',
      'public.chore_reschedule_events',
      'delete'
    ),
  'client roles cannot mutate reschedule audit rows'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.chore_reschedule_command_requests',
    'select'
  ),
  'clients cannot inspect reschedule idempotency state'
);
select hasnt_column(
  'app_private',
  'chore_reschedule_command_requests',
  'title',
  'reschedule command state does not store chore titles'
);
select hasnt_column(
  'app_private',
  'chore_reschedule_command_requests',
  'description',
  'reschedule command state does not store chore notes'
);
select hasnt_column(
  'public',
  'chore_reschedule_events',
  'title',
  'reschedule audit does not store chore titles'
);
select ok(
  exists (
    select 1
    from pg_constraint
    join pg_class on pg_class.oid = pg_constraint.conrelid
    join pg_namespace on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'chore_completion_events'
      and pg_constraint.conname =
        'chore_completion_events_event_type_check'
      and pg_constraint.convalidated
      and pg_get_constraintdef(pg_constraint.oid) not like '%rescheduled%'
  ),
  'reschedule does not expand the baseline completion audit vocabulary'
);

-- Authentication, validation, and deterministic fixtures.
select throws_ok(
  $$
    select * from public.reschedule_chore_occurrence(
      '48000000-0000-4000-8000-000000000601',
      '20000000-0000-4000-8000-000000000101',
      '58000000-0000-4000-8000-000000000601',
      1,
      date '2026-08-08',
      time '18:30'
    )
  $$,
  'KFC01',
  'authentication required',
  'reschedule derives identity from JWT'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.reschedule_chore_occurrence(
      '48000000-0000-4000-8000-000000000602',
      '20000000-0000-4000-8000-000000000101',
      '58000000-0000-4000-8000-000000000602',
      0,
      date '2026-08-08',
      time '18:30'
    )
  $$,
  'KFC02',
  'invalid chore input',
  'reschedule requires a positive expected version'
);
select throws_ok(
  $$
    select * from public.reschedule_chore_occurrence(
      '48000000-0000-4000-8000-000000000603',
      '20000000-0000-4000-8000-000000000101',
      '58000000-0000-4000-8000-000000000603',
      1,
      date '2026-08-08',
      time '18:30:01'
    )
  $$,
  'KFC02',
  'invalid chore input',
  'reschedule accepts only minute-precision local time'
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '49000000-0000-4000-8000-000000000601',
      '20000000-0000-4000-8000-000000000101',
      'Member recurring reschedule target',
      null,
      '30000000-0000-4000-8000-000000000102',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      time '09:00',
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":2}}'
    )
  $$,
  'owner can create a two-occurrence Member reschedule fixture'
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '49000000-0000-4000-8000-000000000602',
      '20000000-0000-4000-8000-000000000101',
      'Owner recurring reschedule target',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      time '10:00',
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
    )
  $$,
  'owner can create an Owner reschedule fixture'
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '49000000-0000-4000-8000-000000000603',
      '20000000-0000-4000-8000-000000000101',
      'Admin recurring reschedule target',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      time '11:00',
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
    )
  $$,
  'owner can create a future Admin reschedule fixture'
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '49000000-0000-4000-8000-000000000604',
      '20000000-0000-4000-8000-000000000101',
      'Completed recurring reschedule target',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      time '12:00',
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
    )
  $$,
  'owner can create a completed-state reschedule fixture'
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '49000000-0000-4000-8000-000000000605',
      '20000000-0000-4000-8000-000000000101',
      'Skipped recurring reschedule target',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      time '13:00',
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
    )
  $$,
  'owner can create a skipped-state reschedule fixture'
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '49000000-0000-4000-8000-000000000606',
      '20000000-0000-4000-8000-000000000101',
      'One-time reschedule target',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null
    )
  $$,
  'owner can create a one-time transition-denial fixture'
);
select lives_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '49000000-0000-4000-8000-000000000607',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Completed recurring reschedule target'
      ),
      1,
      true
    )
  $$,
  'owner can complete the completed-state reschedule fixture'
);
select lives_ok(
  $$
    select * from public.skip_chore_occurrence(
      '49000000-0000-4000-8000-000000000608',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Skipped recurring reschedule target'
      ),
      1
    )
  $$,
  'owner can skip the skipped-state reschedule fixture'
);

select set_config(
  'kinflow.test.member_reschedule_occurrence_id',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Member recurring reschedule target'
    order by occurrence.due_local_date
    limit 1
  ),
  true
);
select set_config(
  'kinflow.test.member_reschedule_occurrence_key',
  (
    select occurrence.occurrence_key
    from public.chore_occurrences as occurrence
    where occurrence.id = current_setting(
      'kinflow.test.member_reschedule_occurrence_id'
    )::uuid
  ),
  true
);
select set_config(
  'kinflow.test.owner_reschedule_occurrence_id',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Owner recurring reschedule target'
  ),
  true
);

-- Assigned Member success, source-date removal, history, and replay safety.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select
      result.status || ':' || result.version::text || ':'
        || result.changed::text || ':' || result.due_local_date::text || ':'
        || result.due_local_time::text
    from public.reschedule_chore_occurrence(
      '48000000-0000-4000-8000-000000000604',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_reschedule_occurrence_id')::uuid,
      1,
      (clock_timestamp() at time zone 'Asia/Seoul')::date + 1,
      time '18:30'
    ) as result
  ),
  'scheduled:2:true:'
    || ((clock_timestamp() at time zone 'Asia/Seoul')::date + 1)::text
    || ':18:30:00',
  'a Member can move their assigned repeating occurrence to a new date/time'
);

reset role;
select ok(
  exists (
    select 1
    from public.chore_occurrences as occurrence
    where occurrence.id = current_setting(
      'kinflow.test.member_reschedule_occurrence_id'
    )::uuid
      and occurrence.status = 'scheduled'
      and occurrence.version = 2
      and occurrence.due_local_date =
        (clock_timestamp() at time zone 'Asia/Seoul')::date + 1
      and occurrence.due_at = (
        (clock_timestamp() at time zone 'Asia/Seoul')::date
          + 1 + time '18:30'
      ) at time zone occurrence.timezone
      and occurrence.occurrence_key = current_setting(
        'kinflow.test.member_reschedule_occurrence_key'
      )
      and occurrence.assignee_member_id =
        '30000000-0000-4000-8000-000000000102'
      and occurrence.completed_by_member_id is null
      and occurrence.completed_by_user_id is null
      and occurrence.completed_at is null
  ),
  'reschedule changes only effective schedule/version and preserves identity/state'
);
select ok(
  exists (
    select 1
    from public.chore_reschedule_events as event
    where event.occurrence_id = current_setting(
      'kinflow.test.member_reschedule_occurrence_id'
    )::uuid
      and event.actor_user_id =
        '00000000-0000-4000-8000-000000000102'
      and event.actor_member_id =
        '30000000-0000-4000-8000-000000000102'
      and event.previous_due_local_date =
        (clock_timestamp() at time zone 'Asia/Seoul')::date
      and event.previous_due_local_time = time '09:00'
      and event.new_due_local_date =
        (clock_timestamp() at time zone 'Asia/Seoul')::date + 1
      and event.new_due_local_time = time '18:30'
      and event.occurrence_version = 2
  ),
  'reschedule emits one structured before/after adult actor audit row'
);
select ok(
  exists (
    select 1
    from public.chore_occurrences as sibling
    where sibling.series_id = (
      select moved.series_id
      from public.chore_occurrences as moved
      where moved.id = current_setting(
        'kinflow.test.member_reschedule_occurrence_id'
      )::uuid
    )
      and sibling.id <> current_setting(
        'kinflow.test.member_reschedule_occurrence_id'
      )::uuid
      and sibling.status = 'scheduled'
      and sibling.version = 1
      and sibling.due_local_date =
        (clock_timestamp() at time zone 'Asia/Seoul')::date + 1
      and (sibling.due_at at time zone sibling.timezone)::time = time '09:00'
  ),
  'moving one occurrence preserves its sibling schedule and version'
);
select ok(
  exists (
    select 1
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    join public.chore_series_revisions as revision
      on revision.id = occurrence.revision_id
    where occurrence.id = current_setting(
      'kinflow.test.member_reschedule_occurrence_id'
    )::uuid
      and series.version = 1
      and revision.revision_number = 1
      and revision.due_local_time = time '09:00'
      and revision.recurrence_rule =
        '{"frequency":"daily","interval":1,"end":{"type":"count","count":2}}'::jsonb
  ),
  'reschedule does not change series or recurrence revision definition'
);
select is(
  (
    select count(*)
    from public.get_today_chores_v2(
      '20000000-0000-4000-8000-000000000101'
    ) as today
    where today.title = 'Member recurring reschedule target'
  ),
  0::bigint,
  'Today v2 removes an occurrence moved away from household Today'
);
select is(
  app_private.materialize_chore_revision(
    '20000000-0000-4000-8000-000000000101',
    (
      select occurrence.series_id
      from public.chore_occurrences as occurrence
      where occurrence.id = current_setting(
        'kinflow.test.member_reschedule_occurrence_id'
      )::uuid
    ),
    (
      select occurrence.revision_id
      from public.chore_occurrences as occurrence
      where occurrence.id = current_setting(
        'kinflow.test.member_reschedule_occurrence_id'
      )::uuid
    ),
    (clock_timestamp() at time zone 'Asia/Seoul')::date + 1
  ),
  0,
  'materializer replay inserts no replacement occurrence'
);
select ok(
  exists (
    select 1
    from public.chore_occurrences as occurrence
    where occurrence.id = current_setting(
      'kinflow.test.member_reschedule_occurrence_id'
    )::uuid
      and occurrence.version = 2
      and occurrence.due_local_date =
        (clock_timestamp() at time zone 'Asia/Seoul')::date + 1
      and (occurrence.due_at at time zone occurrence.timezone)::time =
        time '18:30'
  ),
  'materializer replay does not overwrite the rescheduled occurrence'
);
select is(
  (
    select count(*)
    from public.chore_completion_events as event
    where event.occurrence_id = current_setting(
      'kinflow.test.member_reschedule_occurrence_id'
    )::uuid
  ),
  0::bigint,
  'reschedule does not forge completion audit history'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select result.changed
    from public.reschedule_chore_occurrence(
      '48000000-0000-4000-8000-000000000604',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_reschedule_occurrence_id')::uuid,
      1,
      (clock_timestamp() at time zone 'Asia/Seoul')::date + 1,
      time '18:30'
    ) as result
  ),
  false,
  'same-key same-input reschedule replay returns the original result'
);
select is(
  (
    select result.version
    from public.reschedule_chore_occurrence(
      '48000000-0000-4000-8000-000000000604',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_reschedule_occurrence_id')::uuid,
      1,
      (clock_timestamp() at time zone 'Asia/Seoul')::date + 1,
      time '18:30'
    ) as result
  ),
  2::bigint,
  'reschedule replay keeps the original result version'
);
select is(
  (
    select count(*)
    from public.chore_reschedule_events as event
    where event.occurrence_id = current_setting(
      'kinflow.test.member_reschedule_occurrence_id'
    )::uuid
  ),
  1::bigint,
  'reschedule replay emits no duplicate audit row'
);
select throws_ok(
  $$
    select * from public.reschedule_chore_occurrence(
      '48000000-0000-4000-8000-000000000604',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_reschedule_occurrence_id')::uuid,
      2,
      (clock_timestamp() at time zone 'Asia/Seoul')::date + 2,
      time '19:00'
    )
  $$,
  'KFC04',
  'idempotency key reused with different chore input',
  'same key with a different reschedule request is rejected'
);
select throws_ok(
  $$
    select * from public.reschedule_chore_occurrence(
      '48000000-0000-4000-8000-000000000605',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_reschedule_occurrence_id')::uuid,
      1,
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      time '19:00'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'a Member cannot reschedule another adult assignment'
);

-- Owner/Admin authority and stale/no-op/invalid transition behavior.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.reschedule_chore_occurrence(
      '48000000-0000-4000-8000-000000000606',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_reschedule_occurrence_id')::uuid,
      2,
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      time '20:00'
    )
  $$,
  'KFC05',
  'chore occurrence version conflict',
  'reschedule rejects a stale or future expected version'
);
select is(
  (
    select result.status || ':' || result.version::text
    from public.reschedule_chore_occurrence(
      '48000000-0000-4000-8000-000000000607',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_reschedule_occurrence_id')::uuid,
      1,
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      time '20:00'
    ) as result
  ),
  'scheduled:2',
  'Owner can change the time of a same-household occurrence'
);
select is(
  (
    select today.due_local_time
    from public.get_today_chores_v2(
      '20000000-0000-4000-8000-000000000101'
    ) as today
    where today.title = 'Owner recurring reschedule target'
  ),
  time '20:00',
  'Today v2 renders effective occurrence time instead of revision time'
);
select throws_ok(
  $$
    select * from public.reschedule_chore_occurrence(
      '48000000-0000-4000-8000-000000000608',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_reschedule_occurrence_id')::uuid,
      2,
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      time '20:00'
    )
  $$,
  'KFC06',
  'chore occurrence transition not allowed',
  'reschedule rejects a no-op schedule'
);
select throws_ok(
  $$
    select * from public.reschedule_chore_occurrence(
      '48000000-0000-4000-8000-000000000609',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Completed recurring reschedule target'
      ),
      2,
      (clock_timestamp() at time zone 'Asia/Seoul')::date + 1,
      time '12:00'
    )
  $$,
  'KFC06',
  'chore occurrence transition not allowed',
  'completed occurrence cannot be rescheduled'
);
select throws_ok(
  $$
    select * from public.reschedule_chore_occurrence(
      '48000000-0000-4000-8000-000000000610',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'One-time reschedule target'
      ),
      1,
      (clock_timestamp() at time zone 'Asia/Seoul')::date + 1,
      null
    )
  $$,
  'KFC06',
  'chore occurrence transition not allowed',
  'one-time occurrence cannot use repeating reschedule semantics'
);
select throws_ok(
  $$
    select * from public.reschedule_chore_occurrence(
      '48000000-0000-4000-8000-000000000611',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Skipped recurring reschedule target'
      ),
      2,
      (clock_timestamp() at time zone 'Asia/Seoul')::date + 1,
      time '13:00'
    )
  $$,
  'KFC06',
  'chore occurrence transition not allowed',
  'skipped occurrence must be restored before reschedule'
);

reset role;
update public.household_members
set role = 'admin'
where id = '30000000-0000-4000-8000-000000000102';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select ok(
  (
    select
      result.due_local_time is null
      and result.due_at is null
      and result.version = 2
    from public.reschedule_chore_occurrence(
      '48000000-0000-4000-8000-000000000612',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Admin recurring reschedule target'
      ),
      1,
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null
    ) as result
  ),
  'Admin can turn another assignment into an all-day occurrence'
);
select ok(
  exists (
    select 1
    from public.get_today_chores_v2(
      '20000000-0000-4000-8000-000000000101'
    ) as today
    where today.title = 'Admin recurring reschedule target'
      and today.due_local_time is null
      and today.due_at is null
      and today.version = 2
  ),
  'Today v2 preserves the timed-to-all-day override'
);
select ok(
  exists (
    select 1
    from public.chore_reschedule_events as event
    join public.chore_series as series on series.title =
      'Admin recurring reschedule target'
    join public.chore_occurrences as occurrence
      on occurrence.series_id = series.id
     and occurrence.id = event.occurrence_id
    where event.previous_due_local_time = time '11:00'
      and event.previous_due_at is not null
      and event.new_due_local_time is null
      and event.new_due_at is null
      and event.occurrence_version = 2
  ),
  'all-day reschedule audit preserves the previous timed schedule'
);

-- Outsider, removed member, direct mutation, RLS, and immutability denial.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$
    select * from public.reschedule_chore_occurrence(
      '48000000-0000-4000-8000-000000000613',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_reschedule_occurrence_id')::uuid,
      2,
      (clock_timestamp() at time zone 'Asia/Seoul')::date + 1,
      time '21:00'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'outsider cannot inject another household occurrence schedule'
);
select is(
  (
    select count(*)
    from public.chore_reschedule_events
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  0::bigint,
  'reschedule audit RLS hides another household'
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
    select * from public.reschedule_chore_occurrence(
      '48000000-0000-4000-8000-000000000614',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_reschedule_occurrence_id')::uuid,
      2,
      (clock_timestamp() at time zone 'Asia/Seoul')::date + 2,
      time '19:00'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'removed adult cannot mutate a former-household occurrence'
);
select throws_ok(
  $$
    update public.chore_occurrences
    set due_local_date = due_local_date + 1
    where id = current_setting(
      'kinflow.test.owner_reschedule_occurrence_id'
    )::uuid
  $$,
  '42501',
  'permission denied for table chore_occurrences',
  'authenticated clients cannot bypass the reschedule command'
);
select throws_ok(
  $$
    insert into public.chore_reschedule_events (
      household_id,
      occurrence_id,
      actor_member_id,
      previous_due_local_date,
      new_due_local_date,
      occurrence_version,
      correlation_id
    ) values (
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_reschedule_occurrence_id')::uuid,
      '30000000-0000-4000-8000-000000000101',
      date '2026-08-07',
      date '2026-08-08',
      3,
      '48000000-0000-4000-8000-000000000699'
    )
  $$,
  '42501',
  'permission denied for table chore_reschedule_events',
  'authenticated clients cannot forge reschedule audit rows'
);
select throws_ok(
  $$select * from app_private.chore_reschedule_command_requests$$,
  '42501',
  'permission denied for table chore_reschedule_command_requests',
  'authenticated clients cannot read private reschedule command state'
);

reset role;
select throws_ok(
  $$
    update public.chore_reschedule_events
    set occurrence_version = occurrence_version + 1
  $$,
  '55000',
  'chore reschedule events are immutable',
  'reschedule audit remains append-only'
);
select is(
  (
    select count(*)
    from app_private.chore_reschedule_command_requests
  ),
  3::bigint,
  'only three unique successful reschedule commands persist results'
);
select is(
  (
    select string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'chore_reschedule_command_requests'
  ),
  'authenticated_user_id,idempotency_key,request_hash,household_id,occurrence_id,result_due_local_date,result_due_local_time,result_due_at,result_version,result_event_id,created_at',
  'private reschedule state contains only hashes, IDs, schedule result, version, and time'
);
select is(
  (
    select count(*)
    from public.chore_reschedule_events
  ),
  3::bigint,
  'each successful reschedule emits exactly one audit row'
);
select is(
  (
    select count(*)
    from public.chore_completion_events
    where event_type = 'completed'
      and occurrence_id = (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Completed recurring reschedule target'
      )
  ),
  1::bigint,
  'completed fixture history is preserved after denied reschedule'
);
select is(
  (
    select count(*)
    from public.chore_occurrences as occurrence
    where occurrence.series_id = (
      select moved.series_id
      from public.chore_occurrences as moved
      where moved.id = current_setting(
        'kinflow.test.member_reschedule_occurrence_id'
      )::uuid
    )
  ),
  2::bigint,
  'reschedule and materializer replay preserve exact occurrence cardinality'
);

select * from finish();
rollback;
