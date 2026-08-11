begin;
set constraints all deferred;

select plan(49);

-- Schema, grants, and content-free command/audit contract.
select has_function(
  'public',
  'skip_chore_occurrence',
  array['uuid', 'uuid', 'uuid', 'bigint'],
  'versioned single-occurrence skip command exists'
);
select has_table(
  'app_private',
  'chore_skip_command_requests',
  'private skip idempotency table exists'
);
select col_not_null(
  'public',
  'chore_occurrences',
  'assignee_member_id',
  'every occurrence keeps an explicit assignee for Member authorization'
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
      and pg_get_constraintdef(pg_constraint.oid) like '%skipped%'
  ),
  'the immutable occurrence audit accepts skipped events'
);
select ok(
  (
    select pg_proc.prosecdef
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'skip_chore_occurrence'
  ),
  'skip command is security-definer with an empty search path'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.skip_chore_occurrence(uuid,uuid,uuid,bigint)',
    'execute'
  ),
  'authenticated clients can execute the mediated skip command'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.skip_chore_occurrence(uuid,uuid,uuid,bigint)',
    'execute'
  ),
  'anonymous clients cannot execute the skip command'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.chore_skip_command_requests',
    'select'
  ),
  'clients cannot inspect skip idempotency state'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.chore_completion_events',
    'insert'
  )
    and not has_table_privilege(
      'authenticated',
      'public.chore_completion_events',
      'update'
    )
    and not has_table_privilege(
      'authenticated',
      'public.chore_completion_events',
      'delete'
    ),
  'client roles cannot mutate occurrence audit rows'
);
select hasnt_column(
  'app_private',
  'chore_skip_command_requests',
  'title',
  'skip command state does not store chore titles'
);
select hasnt_column(
  'app_private',
  'chore_skip_command_requests',
  'description',
  'skip command state does not store chore notes'
);

-- Authentication, validation, and deterministic fixtures.
select throws_ok(
  $$
    select * from public.skip_chore_occurrence(
      '46000000-0000-4000-8000-000000000601',
      '20000000-0000-4000-8000-000000000101',
      '56000000-0000-4000-8000-000000000601',
      1
    )
  $$,
  'KFC01',
  'authentication required',
  'skip derives identity from JWT'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.skip_chore_occurrence(
      '46000000-0000-4000-8000-000000000602',
      '20000000-0000-4000-8000-000000000101',
      '56000000-0000-4000-8000-000000000602',
      0
    )
  $$,
  'KFC02',
  'invalid chore input',
  'skip requires a positive expected version'
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '47000000-0000-4000-8000-000000000601',
      '20000000-0000-4000-8000-000000000101',
      'Member recurring skip target',
      null,
      '30000000-0000-4000-8000-000000000102',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":2}}'
    )
  $$,
  'owner can create a two-occurrence Member skip fixture'
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '47000000-0000-4000-8000-000000000602',
      '20000000-0000-4000-8000-000000000101',
      'Owner recurring skip target',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
    )
  $$,
  'owner can create an Owner skip fixture'
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '47000000-0000-4000-8000-000000000603',
      '20000000-0000-4000-8000-000000000101',
      'Admin recurring skip target',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
    )
  $$,
  'owner can create a future Admin skip fixture'
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '47000000-0000-4000-8000-000000000604',
      '20000000-0000-4000-8000-000000000101',
      'Completed recurring skip target',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
    )
  $$,
  'owner can create a completed-state skip fixture'
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '47000000-0000-4000-8000-000000000605',
      '20000000-0000-4000-8000-000000000101',
      'One-time skip target',
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
      '47000000-0000-4000-8000-000000000606',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Completed recurring skip target'
      ),
      1,
      true
    )
  $$,
  'owner can complete the completed-state skip fixture'
);

select set_config(
  'kinflow.test.member_skip_occurrence_id',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Member recurring skip target'
    order by occurrence.due_local_date
    limit 1
  ),
  true
);
select set_config(
  'kinflow.test.owner_skip_occurrence_id',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Owner recurring skip target'
  ),
  true
);
-- Assigned Member success, series/sibling isolation, and replay safety.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select result.status || ':' || result.version::text
    from public.skip_chore_occurrence(
      '46000000-0000-4000-8000-000000000603',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_skip_occurrence_id')::uuid,
      1
    ) as result
  ),
  'skipped:2',
  'a Member can skip their assigned repeating occurrence'
);

reset role;
select ok(
  exists (
    select 1
    from public.chore_occurrences as occurrence
    where occurrence.id = current_setting(
      'kinflow.test.member_skip_occurrence_id'
    )::uuid
      and occurrence.status = 'skipped'
      and occurrence.version = 2
      and occurrence.completed_by_member_id is null
      and occurrence.completed_by_user_id is null
      and occurrence.completed_at is null
  ),
  'skip changes only status/version and keeps completion fields empty'
);
select ok(
  exists (
    select 1
    from public.chore_completion_events as event
    where event.occurrence_id = current_setting(
      'kinflow.test.member_skip_occurrence_id'
    )::uuid
      and event.event_type = 'skipped'
      and event.actor_user_id =
        '00000000-0000-4000-8000-000000000102'
      and event.actor_member_id =
        '30000000-0000-4000-8000-000000000102'
      and event.acting_member_id is null
      and event.occurrence_version = 2
  ),
  'skip emits one content-free adult actor audit event'
);
select ok(
  exists (
    select 1
    from public.chore_occurrences as sibling
    where sibling.series_id = (
      select skipped.series_id
      from public.chore_occurrences as skipped
      where skipped.id = current_setting(
        'kinflow.test.member_skip_occurrence_id'
      )::uuid
    )
      and sibling.id <> current_setting(
        'kinflow.test.member_skip_occurrence_id'
      )::uuid
      and sibling.status = 'scheduled'
      and sibling.version = 1
  ),
  'skipping one occurrence preserves its sibling status and version'
);
select ok(
  exists (
    select 1
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    join public.chore_series_revisions as revision
      on revision.id = occurrence.revision_id
    where occurrence.id = current_setting(
      'kinflow.test.member_skip_occurrence_id'
    )::uuid
      and series.version = 1
      and revision.revision_number = 1
      and revision.recurrence_rule =
        '{"frequency":"daily","interval":1,"end":{"type":"count","count":2}}'::jsonb
  ),
  'skip does not change series or recurrence revision definition'
);
select is(
  (
    select count(*)
    from public.get_today_chores_v2(
      '20000000-0000-4000-8000-000000000101'
    ) as today
    where today.title = 'Member recurring skip target'
  ),
  0::bigint,
  'Today v2 excludes the skipped occurrence'
);
select is(
  app_private.materialize_chore_revision(
    '20000000-0000-4000-8000-000000000101',
    (
      select occurrence.series_id
      from public.chore_occurrences as occurrence
      where occurrence.id = current_setting(
        'kinflow.test.member_skip_occurrence_id'
      )::uuid
    ),
    (
      select occurrence.revision_id
      from public.chore_occurrences as occurrence
      where occurrence.id = current_setting(
        'kinflow.test.member_skip_occurrence_id'
      )::uuid
    ),
    (clock_timestamp() at time zone 'Asia/Seoul')::date + 1
  ),
  0,
  'materializer replay inserts no replacement occurrence'
);
select is(
  (
    select occurrence.status::text
    from public.chore_occurrences as occurrence
    where occurrence.id = current_setting(
      'kinflow.test.member_skip_occurrence_id'
    )::uuid
  ),
  'skipped',
  'materializer replay does not overwrite skipped state'
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
    from public.skip_chore_occurrence(
      '46000000-0000-4000-8000-000000000603',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_skip_occurrence_id')::uuid,
      1
    ) as result
  ),
  false,
  'same-key same-input skip replay returns the original result'
);
select is(
  (
    select result.version
    from public.skip_chore_occurrence(
      '46000000-0000-4000-8000-000000000603',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_skip_occurrence_id')::uuid,
      1
    ) as result
  ),
  2::bigint,
  'skip replay keeps the original result version'
);
select is(
  (
    select count(*)
    from public.chore_completion_events as event
    where event.occurrence_id = current_setting(
      'kinflow.test.member_skip_occurrence_id'
    )::uuid
      and event.event_type = 'skipped'
  ),
  1::bigint,
  'skip replay emits no duplicate audit event'
);
select throws_ok(
  $$
    select * from public.skip_chore_occurrence(
      '46000000-0000-4000-8000-000000000603',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_skip_occurrence_id')::uuid,
      2
    )
  $$,
  'KFC04',
  'idempotency key reused with different chore input',
  'same key with a different skip request is rejected'
);
select throws_ok(
  $$
    select * from public.skip_chore_occurrence(
      '46000000-0000-4000-8000-000000000604',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_skip_occurrence_id')::uuid,
      2
    )
  $$,
  'KFC06',
  'chore occurrence transition not allowed',
  'a new command cannot skip an already skipped occurrence'
);
select throws_ok(
  $$
    select * from public.skip_chore_occurrence(
      '46000000-0000-4000-8000-000000000605',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_skip_occurrence_id')::uuid,
      1
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'a Member cannot skip another adult assignment'
);
-- Owner/Admin authority and invalid/stale transition behavior.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select result.status
    from public.skip_chore_occurrence(
      '46000000-0000-4000-8000-000000000606',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_skip_occurrence_id')::uuid,
      1
    ) as result
  ),
  'skipped',
  'Owner can skip a same-household occurrence'
);
select throws_ok(
  $$
    select * from public.skip_chore_occurrence(
      '46000000-0000-4000-8000-000000000607',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Admin recurring skip target'
      ),
      2
    )
  $$,
  'KFC05',
  'chore occurrence version conflict',
  'skip rejects a stale or future expected version'
);
select throws_ok(
  $$
    select * from public.skip_chore_occurrence(
      '46000000-0000-4000-8000-000000000608',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Completed recurring skip target'
      ),
      2
    )
  $$,
  'KFC06',
  'chore occurrence transition not allowed',
  'completed occurrence cannot be skipped'
);
select throws_ok(
  $$
    select * from public.skip_chore_occurrence(
      '46000000-0000-4000-8000-000000000609',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'One-time skip target'
      ),
      1
    )
  $$,
  'KFC06',
  'chore occurrence transition not allowed',
  'one-time occurrence cannot use repeating skip semantics'
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
select is(
  (
    select result.status
    from public.skip_chore_occurrence(
      '46000000-0000-4000-8000-000000000610',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Admin recurring skip target'
      ),
      1
    ) as result
  ),
  'skipped',
  'Admin can skip another member assignment'
);

-- Outsider, removed member, direct mutation, RLS, and immutability denial.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$
    select * from public.skip_chore_occurrence(
      '46000000-0000-4000-8000-000000000611',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_skip_occurrence_id')::uuid,
      2
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'outsider cannot inject another household occurrence'
);
select is(
  (
    select count(*)
    from public.chore_completion_events
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  0::bigint,
  'occurrence audit RLS hides another household'
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
    select * from public.skip_chore_occurrence(
      '46000000-0000-4000-8000-000000000612',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_skip_occurrence_id')::uuid,
      2
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'removed adult cannot mutate a former-household occurrence'
);
select throws_ok(
  $$
    update public.chore_occurrences
    set status = 'skipped'
    where id = current_setting(
      'kinflow.test.owner_skip_occurrence_id'
    )::uuid
  $$,
  '42501',
  'permission denied for table chore_occurrences',
  'authenticated clients cannot bypass the skip command'
);
select throws_ok(
  $$
    insert into public.chore_completion_events (
      household_id,
      occurrence_id,
      event_type,
      actor_member_id,
      occurrence_version,
      correlation_id
    ) values (
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_skip_occurrence_id')::uuid,
      'skipped',
      '30000000-0000-4000-8000-000000000101',
      3,
      '46000000-0000-4000-8000-000000000699'
    )
  $$,
  '42501',
  'permission denied for table chore_completion_events',
  'authenticated clients cannot forge skip audit events'
);
select throws_ok(
  $$select * from app_private.chore_skip_command_requests$$,
  '42501',
  'permission denied for table chore_skip_command_requests',
  'authenticated clients cannot read private skip command state'
);

reset role;
select throws_ok(
  $$
    update public.chore_completion_events
    set occurrence_version = occurrence_version + 1
    where event_type = 'skipped'
  $$,
  '55000',
  'chore completion events are immutable',
  'skip audit remains append-only'
);
select is(
  (
    select count(*)
    from app_private.chore_skip_command_requests
  ),
  3::bigint,
  'only three unique successful skip commands persist results'
);
select is(
  (
    select string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'chore_skip_command_requests'
  ),
  'authenticated_user_id,idempotency_key,request_hash,household_id,occurrence_id,result_version,result_event_id,created_at',
  'private skip state contains only hashes, IDs, result version, and time'
);
select is(
  (
    select count(*)
    from public.chore_completion_events
    where event_type = 'skipped'
  ),
  3::bigint,
  'each successful skip emits exactly one event'
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
        where series.title = 'Completed recurring skip target'
      )
  ),
  1::bigint,
  'completed fixture history is preserved after denied skip'
);

select * from finish();
rollback;
