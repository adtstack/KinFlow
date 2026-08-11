begin;
set constraints all deferred;

select plan(55);

-- Schema, grants, baseline audit vocabulary, and content-free command state.
select has_function(
  'public',
  'restore_skipped_chore_occurrence',
  array['uuid', 'uuid', 'uuid', 'bigint'],
  'versioned skipped-occurrence restore command exists'
); -- 1
select has_table(
  'app_private',
  'chore_restore_command_requests',
  'private restore idempotency table exists'
); -- 2
select ok(
  (
    select pg_proc.prosecdef
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'restore_skipped_chore_occurrence'
  ),
  'restore command is security-definer with an empty search path'
); -- 3
select ok(
  has_function_privilege(
    'authenticated',
    'public.restore_skipped_chore_occurrence(uuid,uuid,uuid,bigint)',
    'execute'
  ),
  'authenticated clients can execute the mediated restore command'
); -- 4
select ok(
  not has_function_privilege(
    'anon',
    'public.restore_skipped_chore_occurrence(uuid,uuid,uuid,bigint)',
    'execute'
  ),
  'anonymous clients cannot execute the restore command'
); -- 5
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.chore_restore_command_requests',
    'select'
  ),
  'clients cannot inspect restore idempotency state'
); -- 6
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.chore_restore_command_requests',
    'insert'
  )
    and not has_table_privilege(
      'authenticated',
      'app_private.chore_restore_command_requests',
      'update'
    )
    and not has_table_privilege(
      'authenticated',
      'app_private.chore_restore_command_requests',
      'delete'
    ),
  'clients cannot mutate restore idempotency state'
); -- 7
select ok(
  (
    select pg_get_constraintdef(pg_constraint.oid) like '%completed%'
      and pg_get_constraintdef(pg_constraint.oid) like '%reopened%'
      and pg_get_constraintdef(pg_constraint.oid) like '%skipped%'
      and pg_get_constraintdef(pg_constraint.oid) not like '%restored%'
    from pg_constraint
    join pg_class on pg_class.oid = pg_constraint.conrelid
    join pg_namespace on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'chore_completion_events'
      and pg_constraint.conname = 'chore_completion_events_event_type_check'
  ),
  'restore reuses baseline reopened audit without widening event vocabulary'
); -- 8
select hasnt_column(
  'app_private',
  'chore_restore_command_requests',
  'title',
  'restore command state does not store chore titles'
); -- 9
select hasnt_column(
  'app_private',
  'chore_restore_command_requests',
  'description',
  'restore command state does not store chore notes'
); -- 10

-- Authentication, validation, and deterministic fixtures.
select throws_ok(
  $$
    select * from public.restore_skipped_chore_occurrence(
      '48000000-0000-4000-8000-000000000700',
      '20000000-0000-4000-8000-000000000101',
      '56000000-0000-4000-8000-000000000700',
      1
    )
  $$,
  'KFC01',
  'authentication required',
  'restore derives identity from JWT'
); -- 11

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.restore_skipped_chore_occurrence(
      '48000000-0000-4000-8000-000000000701',
      '20000000-0000-4000-8000-000000000101',
      '56000000-0000-4000-8000-000000000701',
      0
    )
  $$,
  'KFC02',
  'invalid chore input',
  'restore requires a positive expected version'
); -- 12
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '47000000-0000-4000-8000-000000000701',
      '20000000-0000-4000-8000-000000000101',
      'Member restore target',
      null,
      '30000000-0000-4000-8000-000000000102',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":2}}'
    )
  $$,
  'owner can create a two-occurrence Member restore fixture'
); -- 13
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '47000000-0000-4000-8000-000000000702',
      '20000000-0000-4000-8000-000000000101',
      'Owner restore target',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
    )
  $$,
  'owner can create an Owner restore fixture'
); -- 14
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '47000000-0000-4000-8000-000000000703',
      '20000000-0000-4000-8000-000000000101',
      'Admin restore target',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
    )
  $$,
  'owner can create a future Admin restore fixture'
); -- 15
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '47000000-0000-4000-8000-000000000704',
      '20000000-0000-4000-8000-000000000101',
      'Completed restore target',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
    )
  $$,
  'owner can create a completed-state restore fixture'
); -- 16
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '47000000-0000-4000-8000-000000000705',
      '20000000-0000-4000-8000-000000000101',
      'One-time restore target',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null
    )
  $$,
  'owner can create a one-time restore-denial fixture'
); -- 17
select lives_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '46000000-0000-4000-8000-000000000704',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Completed restore target'
      ),
      1,
      true
    )
  $$,
  'owner can complete the completed-state restore fixture'
); -- 18

select set_config(
  'kinflow.test.member_restore_occurrence_id',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Member restore target'
    order by occurrence.due_local_date
    limit 1
  ),
  true
);
select set_config(
  'kinflow.test.owner_restore_occurrence_id',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Owner restore target'
  ),
  true
);
select set_config(
  'kinflow.test.admin_restore_occurrence_id',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Admin restore target'
  ),
  true
);
select set_config(
  'kinflow.test.one_time_restore_occurrence_id',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'One-time restore target'
  ),
  true
);

select lives_ok(
  $$
    select * from public.skip_chore_occurrence(
      '46000000-0000-4000-8000-000000000702',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_restore_occurrence_id')::uuid,
      1
    )
  $$,
  'owner can prepare a skipped Owner restore fixture'
); -- 19
select lives_ok(
  $$
    select * from public.skip_chore_occurrence(
      '46000000-0000-4000-8000-000000000703',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.admin_restore_occurrence_id')::uuid,
      1
    )
  $$,
  'owner can prepare a skipped future Admin restore fixture'
); -- 20

-- Assigned Member success, history/sibling isolation, and replay safety.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select lives_ok(
  $$
    select * from public.skip_chore_occurrence(
      '46000000-0000-4000-8000-000000000701',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_restore_occurrence_id')::uuid,
      1
    )
  $$,
  'Member can prepare their assigned skipped occurrence'
); -- 21
select is(
  (
    select result.status || ':' || result.version::text
    from public.restore_skipped_chore_occurrence(
      '48000000-0000-4000-8000-000000000702',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_restore_occurrence_id')::uuid,
      2
    ) as result
  ),
  'scheduled:3',
  'a Member can restore their assigned skipped occurrence'
); -- 22

reset role;
select ok(
  exists (
    select 1
    from public.chore_occurrences as occurrence
    where occurrence.id = current_setting(
      'kinflow.test.member_restore_occurrence_id'
    )::uuid
      and occurrence.status = 'scheduled'
      and occurrence.version = 3
      and occurrence.completed_by_member_id is null
      and occurrence.completed_by_user_id is null
      and occurrence.completed_at is null
  ),
  'restore changes only status/version and keeps completion fields empty'
); -- 23
select is(
  (
    select string_agg(
      event.event_type || ':' || event.occurrence_version::text || ':' ||
        event.actor_user_id::text,
      ','
      order by event.occurrence_version
    )
    from public.chore_completion_events as event
    where event.occurrence_id = current_setting(
      'kinflow.test.member_restore_occurrence_id'
    )::uuid
  ),
  'skipped:2:00000000-0000-4000-8000-000000000102,reopened:3:00000000-0000-4000-8000-000000000102',
  'restore appends one actor-bound reopened event after skipped history'
); -- 24
select ok(
  exists (
    select 1
    from public.chore_occurrences as sibling
    where sibling.series_id = (
      select restored.series_id
      from public.chore_occurrences as restored
      where restored.id = current_setting(
        'kinflow.test.member_restore_occurrence_id'
      )::uuid
    )
      and sibling.id <> current_setting(
        'kinflow.test.member_restore_occurrence_id'
      )::uuid
      and sibling.status = 'scheduled'
      and sibling.version = 1
  ),
  'restoring one occurrence preserves its sibling status and version'
); -- 25
select ok(
  exists (
    select 1
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    join public.chore_series_revisions as revision
      on revision.id = occurrence.revision_id
    where occurrence.id = current_setting(
      'kinflow.test.member_restore_occurrence_id'
    )::uuid
      and series.version = 1
      and revision.revision_number = 1
      and revision.recurrence_rule =
        '{"frequency":"daily","interval":1,"end":{"type":"count","count":2}}'::jsonb
  ),
  'restore does not change series or recurrence revision definition'
); -- 26
select is(
  (
    select count(*)
    from public.get_today_chores_v2(
      '20000000-0000-4000-8000-000000000101'
    ) as today
    where today.title = 'Member restore target'
  ),
  1::bigint,
  'Today v2 includes the restored occurrence again'
); -- 27
select is(
  app_private.materialize_chore_revision(
    '20000000-0000-4000-8000-000000000101',
    (
      select occurrence.series_id
      from public.chore_occurrences as occurrence
      where occurrence.id = current_setting(
        'kinflow.test.member_restore_occurrence_id'
      )::uuid
    ),
    (
      select occurrence.revision_id
      from public.chore_occurrences as occurrence
      where occurrence.id = current_setting(
        'kinflow.test.member_restore_occurrence_id'
      )::uuid
    ),
    (clock_timestamp() at time zone 'Asia/Seoul')::date + 1
  ),
  0,
  'materializer replay inserts no duplicate restored occurrence'
); -- 28
select is(
  (
    select occurrence.status::text || ':' || occurrence.version::text
    from public.chore_occurrences as occurrence
    where occurrence.id = current_setting(
      'kinflow.test.member_restore_occurrence_id'
    )::uuid
  ),
  'scheduled:3',
  'materializer replay does not overwrite restored state'
); -- 29

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select result.changed
    from public.restore_skipped_chore_occurrence(
      '48000000-0000-4000-8000-000000000702',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_restore_occurrence_id')::uuid,
      2
    ) as result
  ),
  false,
  'same-key same-input restore replay returns the original result'
); -- 30
select is(
  (
    select result.version
    from public.restore_skipped_chore_occurrence(
      '48000000-0000-4000-8000-000000000702',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_restore_occurrence_id')::uuid,
      2
    ) as result
  ),
  3::bigint,
  'restore replay keeps the original result version'
); -- 31
select is(
  (
    select count(*)
    from public.chore_completion_events as event
    where event.occurrence_id = current_setting(
      'kinflow.test.member_restore_occurrence_id'
    )::uuid
      and event.event_type = 'reopened'
  ),
  1::bigint,
  'restore replay emits no duplicate audit event'
); -- 32
select throws_ok(
  $$
    select * from public.restore_skipped_chore_occurrence(
      '48000000-0000-4000-8000-000000000702',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_restore_occurrence_id')::uuid,
      3
    )
  $$,
  'KFC04',
  'idempotency key reused with different chore input',
  'same key with a different restore request is rejected'
); -- 33
select throws_ok(
  $$
    select * from public.restore_skipped_chore_occurrence(
      '48000000-0000-4000-8000-000000000703',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_restore_occurrence_id')::uuid,
      3
    )
  $$,
  'KFC06',
  'chore occurrence transition not allowed',
  'a new command cannot restore an already scheduled occurrence'
); -- 34
select throws_ok(
  $$
    select * from public.restore_skipped_chore_occurrence(
      '48000000-0000-4000-8000-000000000704',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_restore_occurrence_id')::uuid,
      2
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'a Member cannot restore another adult assignment'
); -- 35

-- Owner/Admin authority and invalid/stale transition behavior.
reset role;
update public.chore_occurrences
set status = 'skipped'
where id = current_setting(
  'kinflow.test.one_time_restore_occurrence_id'
)::uuid;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select result.status
    from public.restore_skipped_chore_occurrence(
      '48000000-0000-4000-8000-000000000705',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_restore_occurrence_id')::uuid,
      2
    ) as result
  ),
  'scheduled',
  'Owner can restore a same-household skipped occurrence'
); -- 36
select throws_ok(
  $$
    select * from public.restore_skipped_chore_occurrence(
      '48000000-0000-4000-8000-000000000706',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.admin_restore_occurrence_id')::uuid,
      3
    )
  $$,
  'KFC05',
  'chore occurrence version conflict',
  'restore rejects a stale or future expected version'
); -- 37
select throws_ok(
  $$
    select * from public.restore_skipped_chore_occurrence(
      '48000000-0000-4000-8000-000000000707',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Completed restore target'
      ),
      2
    )
  $$,
  'KFC06',
  'chore occurrence transition not allowed',
  'completed occurrence cannot be restored as a skipped occurrence'
); -- 38
select throws_ok(
  $$
    select * from public.restore_skipped_chore_occurrence(
      '48000000-0000-4000-8000-000000000708',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.one_time_restore_occurrence_id')::uuid,
      2
    )
  $$,
  'KFC06',
  'chore occurrence transition not allowed',
  'one-time occurrence cannot use repeating restore semantics'
); -- 39
select throws_ok(
  $$
    select * from public.restore_skipped_chore_occurrence(
      '48000000-0000-4000-8000-000000000709',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_restore_occurrence_id')::uuid,
      3
    )
  $$,
  'KFC06',
  'chore occurrence transition not allowed',
  'scheduled repeating occurrence cannot be restored again'
); -- 40

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
    from public.restore_skipped_chore_occurrence(
      '48000000-0000-4000-8000-000000000710',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.admin_restore_occurrence_id')::uuid,
      2
    ) as result
  ),
  'scheduled',
  'Admin can restore another member assignment'
); -- 41

-- Outsider, removed member, direct mutation, RLS, and immutability denial.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$
    select * from public.restore_skipped_chore_occurrence(
      '48000000-0000-4000-8000-000000000711',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_restore_occurrence_id')::uuid,
      3
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'outsider cannot inject another household occurrence'
); -- 42
select is(
  (
    select count(*)
    from public.chore_completion_events
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  0::bigint,
  'occurrence audit RLS hides another household'
); -- 43

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
    select * from public.restore_skipped_chore_occurrence(
      '48000000-0000-4000-8000-000000000712',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_restore_occurrence_id')::uuid,
      3
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'removed adult cannot mutate a former-household occurrence'
); -- 44
select throws_ok(
  $$
    update public.chore_occurrences
    set status = 'skipped'
    where id = current_setting(
      'kinflow.test.owner_restore_occurrence_id'
    )::uuid
  $$,
  '42501',
  'permission denied for table chore_occurrences',
  'authenticated clients cannot bypass the restore command'
); -- 45
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
      current_setting('kinflow.test.owner_restore_occurrence_id')::uuid,
      'reopened',
      '30000000-0000-4000-8000-000000000101',
      4,
      '48000000-0000-4000-8000-000000000799'
    )
  $$,
  '42501',
  'permission denied for table chore_completion_events',
  'authenticated clients cannot forge restore audit events'
); -- 46
select throws_ok(
  $$select * from app_private.chore_restore_command_requests$$,
  '42501',
  'permission denied for table chore_restore_command_requests',
  'authenticated clients cannot read private restore command state'
); -- 47

reset role;
select throws_ok(
  $$
    update public.chore_completion_events
    set occurrence_version = occurrence_version + 1
    where event_type = 'reopened'
  $$,
  '55000',
  'chore completion events are immutable',
  'restore audit remains append-only'
); -- 48
select is(
  (
    select count(*)
    from app_private.chore_restore_command_requests
  ),
  3::bigint,
  'only three unique successful restore commands persist results'
); -- 49
select is(
  (
    select string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'chore_restore_command_requests'
  ),
  'authenticated_user_id,idempotency_key,request_hash,household_id,occurrence_id,result_version,result_event_id,created_at',
  'private restore state contains only hashes, IDs, result version, and time'
); -- 50
select is(
  (
    select count(*)
    from public.chore_completion_events
    where event_type = 'reopened'
      and occurrence_id in (
        current_setting('kinflow.test.member_restore_occurrence_id')::uuid,
        current_setting('kinflow.test.owner_restore_occurrence_id')::uuid,
        current_setting('kinflow.test.admin_restore_occurrence_id')::uuid
      )
  ),
  3::bigint,
  'each successful restore emits exactly one reopened event'
); -- 51
select is(
  (
    select count(*)
    from public.chore_completion_events
    where event_type = 'completed'
      and occurrence_id = (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Completed restore target'
      )
  ),
  1::bigint,
  'completed fixture history is preserved after denied restore'
); -- 52
select is(
  (
    select count(*)
    from public.chore_completion_events
    where event_type = 'skipped'
      and occurrence_id in (
        current_setting('kinflow.test.member_restore_occurrence_id')::uuid,
        current_setting('kinflow.test.owner_restore_occurrence_id')::uuid,
        current_setting('kinflow.test.admin_restore_occurrence_id')::uuid
      )
  ),
  3::bigint,
  'restore preserves all prior skipped audit events'
); -- 53
select is(
  (
    select count(*)
    from public.chore_occurrences
    where id in (
      current_setting('kinflow.test.member_restore_occurrence_id')::uuid,
      current_setting('kinflow.test.owner_restore_occurrence_id')::uuid,
      current_setting('kinflow.test.admin_restore_occurrence_id')::uuid
    )
      and status = 'scheduled'
      and version = 3
  ),
  3::bigint,
  'all three authorized restores finish at scheduled version three'
); -- 54
select is(
  (
    select count(*)
    from public.chore_completion_events
    where event_type = 'reopened'
      and acting_member_id is not null
  ),
  0::bigint,
  'adult restore audit never fabricates a managed acting member'
); -- 55

select * from finish();
rollback;
