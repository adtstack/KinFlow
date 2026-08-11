begin;
set constraints all deferred;

select plan(59);

-- Schema, grants, immutable audit, and content minimization.
select has_function(
  'public',
  'reassign_chore_occurrence',
  array['uuid', 'uuid', 'uuid', 'bigint', 'uuid'],
  'versioned single-occurrence reassignment command exists'
);
select has_table(
  'public',
  'chore_assignment_events',
  'immutable assignment audit table exists'
);
select has_table(
  'app_private',
  'chore_assignment_command_requests',
  'private assignment idempotency table exists'
);
select col_not_null(
  'public',
  'chore_occurrences',
  'assignee_member_id',
  'every occurrence keeps exactly one explicit assignee'
);
select ok(
  (
    select pg_proc.prosecdef
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'reassign_chore_occurrence'
  ),
  'reassignment command is security-definer with an empty search path'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.reassign_chore_occurrence(uuid,uuid,uuid,bigint,uuid)',
    'execute'
  ),
  'authenticated clients can execute the mediated reassignment command'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.reassign_chore_occurrence(uuid,uuid,uuid,bigint,uuid)',
    'execute'
  ),
  'anonymous clients cannot execute the reassignment command'
);
select ok(
  has_table_privilege(
    'authenticated',
    'public.chore_assignment_events',
    'select'
  ),
  'active household members can read assignment history through RLS'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.chore_assignment_events',
    'insert'
  )
    and not has_table_privilege(
      'authenticated',
      'public.chore_assignment_events',
      'update'
    )
    and not has_table_privilege(
      'authenticated',
      'public.chore_assignment_events',
      'delete'
    ),
  'client roles cannot mutate assignment audit rows'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.chore_assignment_command_requests',
    'select'
  ),
  'clients cannot inspect assignment idempotency state'
);
select hasnt_column(
  'app_private',
  'chore_assignment_command_requests',
  'title',
  'assignment command state does not store chore titles'
);
select hasnt_column(
  'app_private',
  'chore_assignment_command_requests',
  'assignee_display_name',
  'assignment command state does not copy display names'
);
select hasnt_column(
  'public',
  'chore_assignment_events',
  'title',
  'assignment audit does not store chore titles'
);
select ok(
  exists (
    select 1
    from pg_constraint
    join pg_class on pg_class.oid = pg_constraint.conrelid
    join pg_namespace on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'chore_assignment_events'
      and pg_constraint.conname = 'chore_assignment_event_changed_ck'
      and pg_constraint.convalidated
  ),
  'assignment audit requires different previous and new assignees'
);

-- Authentication, validation, and deterministic fixtures.
select throws_ok(
  $$
    select * from public.reassign_chore_occurrence(
      '4a000000-0000-4000-8000-000000000601',
      '20000000-0000-4000-8000-000000000101',
      '5a000000-0000-4000-8000-000000000601',
      1,
      '30000000-0000-4000-8000-000000000101'
    )
  $$,
  'KFC01',
  'authentication required',
  'reassignment derives identity from JWT'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.reassign_chore_occurrence(
      '4a000000-0000-4000-8000-000000000602',
      '20000000-0000-4000-8000-000000000101',
      '5a000000-0000-4000-8000-000000000602',
      0,
      '30000000-0000-4000-8000-000000000101'
    )
  $$,
  'KFC02',
  'invalid chore input',
  'reassignment requires a positive expected version'
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '4b000000-0000-4000-8000-000000000601',
      '20000000-0000-4000-8000-000000000101',
      'Member recurring assignment target',
      null,
      '30000000-0000-4000-8000-000000000102',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      time '09:00',
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":2}}'
    )
  $$,
  'owner can create a two-occurrence Member reassignment fixture'
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '4b000000-0000-4000-8000-000000000602',
      '20000000-0000-4000-8000-000000000101',
      'Owner recurring assignment target',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      time '10:00',
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
    )
  $$,
  'owner can create an Owner reassignment fixture'
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '4b000000-0000-4000-8000-000000000603',
      '20000000-0000-4000-8000-000000000101',
      'Admin recurring assignment target',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      time '11:00',
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
    )
  $$,
  'owner can create a future Admin reassignment fixture'
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '4b000000-0000-4000-8000-000000000604',
      '20000000-0000-4000-8000-000000000101',
      'Completed recurring assignment target',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      time '12:00',
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
    )
  $$,
  'owner can create a completed-state reassignment fixture'
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '4b000000-0000-4000-8000-000000000605',
      '20000000-0000-4000-8000-000000000101',
      'Skipped recurring assignment target',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      time '13:00',
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
    )
  $$,
  'owner can create a skipped-state reassignment fixture'
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '4b000000-0000-4000-8000-000000000606',
      '20000000-0000-4000-8000-000000000101',
      'One-time assignment target',
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
      '4b000000-0000-4000-8000-000000000607',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Completed recurring assignment target'
      ),
      1,
      true
    )
  $$,
  'owner can complete the completed-state reassignment fixture'
);
select lives_ok(
  $$
    select * from public.skip_chore_occurrence(
      '4b000000-0000-4000-8000-000000000608',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Skipped recurring assignment target'
      ),
      1
    )
  $$,
  'owner can skip the skipped-state reassignment fixture'
);

select set_config(
  'kinflow.test.member_assignment_occurrence_id',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Member recurring assignment target'
    order by occurrence.due_local_date
    limit 1
  ),
  true
);
select set_config(
  'kinflow.test.member_assignment_occurrence_key',
  (
    select occurrence.occurrence_key
    from public.chore_occurrences as occurrence
    where occurrence.id = current_setting(
      'kinflow.test.member_assignment_occurrence_id'
    )::uuid
  ),
  true
);
select set_config(
  'kinflow.test.owner_assignment_occurrence_id',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Owner recurring assignment target'
  ),
  true
);

-- Assigned Member success, history, display, and replay safety.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select
      result.status || ':' || result.version::text || ':'
        || result.changed::text || ':' || result.assignee_member_id::text || ':'
        || result.assignee_display_name
    from public.reassign_chore_occurrence(
      '4a000000-0000-4000-8000-000000000603',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_assignment_occurrence_id')::uuid,
      1,
      '30000000-0000-4000-8000-000000000101'
    ) as result
  ),
  'scheduled:2:true:30000000-0000-4000-8000-000000000101:Adult A',
  'a Member can hand their assigned repeating occurrence to another adult'
);

reset role;
select ok(
  exists (
    select 1
    from public.chore_occurrences as occurrence
    where occurrence.id = current_setting(
      'kinflow.test.member_assignment_occurrence_id'
    )::uuid
      and occurrence.assignee_member_id =
        '30000000-0000-4000-8000-000000000101'
      and occurrence.status = 'scheduled'
      and occurrence.version = 2
      and occurrence.due_local_date =
        (clock_timestamp() at time zone 'Asia/Seoul')::date
      and (occurrence.due_at at time zone occurrence.timezone)::time =
        time '09:00'
      and occurrence.occurrence_key = current_setting(
        'kinflow.test.member_assignment_occurrence_key'
      )
      and occurrence.completed_by_member_id is null
      and occurrence.completed_by_user_id is null
      and occurrence.completed_at is null
  ),
  'reassignment changes only effective assignee/version and preserves state'
);
select ok(
  exists (
    select 1
    from public.chore_assignment_events as event
    where event.occurrence_id = current_setting(
      'kinflow.test.member_assignment_occurrence_id'
    )::uuid
      and event.actor_user_id =
        '00000000-0000-4000-8000-000000000102'
      and event.actor_member_id =
        '30000000-0000-4000-8000-000000000102'
      and event.previous_assignee_member_id =
        '30000000-0000-4000-8000-000000000102'
      and event.new_assignee_member_id =
        '30000000-0000-4000-8000-000000000101'
      and event.occurrence_version = 2
  ),
  'reassignment emits one structured before/after adult actor audit row'
);
select ok(
  exists (
    select 1
    from public.chore_occurrences as sibling
    where sibling.series_id = (
      select changed.series_id
      from public.chore_occurrences as changed
      where changed.id = current_setting(
        'kinflow.test.member_assignment_occurrence_id'
      )::uuid
    )
      and sibling.id <> current_setting(
        'kinflow.test.member_assignment_occurrence_id'
      )::uuid
      and sibling.assignee_member_id =
        '30000000-0000-4000-8000-000000000102'
      and sibling.status = 'scheduled'
      and sibling.version = 1
  ),
  'changing one occurrence preserves its sibling assignee and version'
);
select ok(
  exists (
    select 1
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    join public.chore_series_revisions as revision
      on revision.id = occurrence.revision_id
    where occurrence.id = current_setting(
      'kinflow.test.member_assignment_occurrence_id'
    )::uuid
      and series.version = 1
      and revision.revision_number = 1
      and revision.default_assignee_member_id =
        '30000000-0000-4000-8000-000000000102'
      and revision.recurrence_rule =
        '{"frequency":"daily","interval":1,"end":{"type":"count","count":2}}'::jsonb
  ),
  'reassignment does not change series or revision default assignee'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select today.assignee_member_id::text || ':' || today.assignee_display_name
    from public.get_today_chores_v2(
      '20000000-0000-4000-8000-000000000101'
    ) as today
    where today.title = 'Member recurring assignment target'
  ),
  '30000000-0000-4000-8000-000000000101:Adult A',
  'Today v2 renders the effective occurrence assignee and display name'
);

reset role;
select is(
  app_private.materialize_chore_revision(
    '20000000-0000-4000-8000-000000000101',
    (
      select occurrence.series_id
      from public.chore_occurrences as occurrence
      where occurrence.id = current_setting(
        'kinflow.test.member_assignment_occurrence_id'
      )::uuid
    ),
    (
      select occurrence.revision_id
      from public.chore_occurrences as occurrence
      where occurrence.id = current_setting(
        'kinflow.test.member_assignment_occurrence_id'
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
      'kinflow.test.member_assignment_occurrence_id'
    )::uuid
      and occurrence.assignee_member_id =
        '30000000-0000-4000-8000-000000000101'
      and occurrence.version = 2
  ),
  'materializer replay does not overwrite the reassigned occurrence'
);
select is(
  (
    select count(*)
    from public.chore_completion_events as event
    where event.occurrence_id = current_setting(
      'kinflow.test.member_assignment_occurrence_id'
    )::uuid
  ),
  0::bigint,
  'reassignment does not forge completion audit history'
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
    from public.reassign_chore_occurrence(
      '4a000000-0000-4000-8000-000000000603',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_assignment_occurrence_id')::uuid,
      1,
      '30000000-0000-4000-8000-000000000101'
    ) as result
  ),
  false,
  'same-key same-input reassignment replay returns the original result'
);
select is(
  (
    select result.version
    from public.reassign_chore_occurrence(
      '4a000000-0000-4000-8000-000000000603',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_assignment_occurrence_id')::uuid,
      1,
      '30000000-0000-4000-8000-000000000101'
    ) as result
  ),
  2::bigint,
  'reassignment replay keeps the original result version'
);
select is(
  (
    select count(*)
    from public.chore_assignment_events as event
    where event.occurrence_id = current_setting(
      'kinflow.test.member_assignment_occurrence_id'
    )::uuid
  ),
  1::bigint,
  'reassignment replay emits no duplicate audit row'
);
select throws_ok(
  $$
    select * from public.reassign_chore_occurrence(
      '4a000000-0000-4000-8000-000000000603',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_assignment_occurrence_id')::uuid,
      2,
      '30000000-0000-4000-8000-000000000102'
    )
  $$,
  'KFC04',
  'idempotency key reused with different chore input',
  'same key with a different reassignment request is rejected'
);
select throws_ok(
  $$
    select * from public.reassign_chore_occurrence(
      '4a000000-0000-4000-8000-000000000604',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_assignment_occurrence_id')::uuid,
      1,
      '30000000-0000-4000-8000-000000000102'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'a Member cannot reassign another adult assignment'
);

-- Owner/Admin authority and stale/no-op/invalid transition behavior.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.reassign_chore_occurrence(
      '4a000000-0000-4000-8000-000000000605',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_assignment_occurrence_id')::uuid,
      2,
      '30000000-0000-4000-8000-000000000102'
    )
  $$,
  'KFC05',
  'chore occurrence version conflict',
  'reassignment rejects a stale or future expected version'
);
select is(
  (
    select
      result.status || ':' || result.version::text || ':'
        || result.assignee_display_name
    from public.reassign_chore_occurrence(
      '4a000000-0000-4000-8000-000000000606',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_assignment_occurrence_id')::uuid,
      1,
      '30000000-0000-4000-8000-000000000102'
    ) as result
  ),
  'scheduled:2:Adult B',
  'Owner can reassign any same-household scheduled occurrence'
);
select is(
  (
    select today.assignee_display_name
    from public.get_today_chores_v2(
      '20000000-0000-4000-8000-000000000101'
    ) as today
    where today.title = 'Owner recurring assignment target'
  ),
  'Adult B',
  'Today v2 reflects the Owner reassignment'
);
select throws_ok(
  $$
    select * from public.reassign_chore_occurrence(
      '4a000000-0000-4000-8000-000000000607',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_assignment_occurrence_id')::uuid,
      2,
      '30000000-0000-4000-8000-000000000102'
    )
  $$,
  'KFC06',
  'chore occurrence transition not allowed',
  'reassignment rejects the current assignee as a no-op'
);
select throws_ok(
  $$
    select * from public.reassign_chore_occurrence(
      '4a000000-0000-4000-8000-000000000608',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Completed recurring assignment target'
      ),
      2,
      '30000000-0000-4000-8000-000000000102'
    )
  $$,
  'KFC06',
  'chore occurrence transition not allowed',
  'completed occurrence cannot be reassigned'
);
select throws_ok(
  $$
    select * from public.reassign_chore_occurrence(
      '4a000000-0000-4000-8000-000000000609',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'One-time assignment target'
      ),
      1,
      '30000000-0000-4000-8000-000000000102'
    )
  $$,
  'KFC06',
  'chore occurrence transition not allowed',
  'one-time occurrence cannot use repeating reassignment semantics'
);
select throws_ok(
  $$
    select * from public.reassign_chore_occurrence(
      '4a000000-0000-4000-8000-000000000610',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Skipped recurring assignment target'
      ),
      2,
      '30000000-0000-4000-8000-000000000102'
    )
  $$,
  'KFC06',
  'chore occurrence transition not allowed',
  'skipped occurrence must be restored before reassignment'
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
    select result.status || ':' || result.version::text
    from public.reassign_chore_occurrence(
      '4a000000-0000-4000-8000-000000000611',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Admin recurring assignment target'
      ),
      1,
      '30000000-0000-4000-8000-000000000102'
    ) as result
  ),
  'scheduled:2',
  'Admin can reassign another adult assignment'
);

-- Outsider, removed member, direct mutation, RLS, and immutability denial.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$
    select * from public.reassign_chore_occurrence(
      '4a000000-0000-4000-8000-000000000612',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_assignment_occurrence_id')::uuid,
      2,
      '30000000-0000-4000-8000-000000000101'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'outsider cannot inject another household assignment'
);
select is(
  (
    select count(*)
    from public.chore_assignment_events
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  0::bigint,
  'assignment audit RLS hides another household'
);

reset role;
update public.household_members
set removed_at = clock_timestamp()
where id = '30000000-0000-4000-8000-000000000102';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.reassign_chore_occurrence(
      '4a000000-0000-4000-8000-000000000613',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Admin recurring assignment target'
      ),
      2,
      '30000000-0000-4000-8000-000000000102'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'removed target cannot receive a reassigned occurrence'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select throws_ok(
  $$
    select * from public.reassign_chore_occurrence(
      '4a000000-0000-4000-8000-000000000614',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_assignment_occurrence_id')::uuid,
      2,
      '30000000-0000-4000-8000-000000000101'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'removed actor cannot reassign an occurrence'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.chore_occurrences',
    'update'
  ),
  'clients cannot bypass the command with direct occurrence updates'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.chore_assignment_events',
    'insert,update,delete'
  ),
  'clients retain no assignment audit mutation privilege'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.chore_assignment_command_requests',
    'select,insert,update,delete'
  ),
  'clients retain no assignment command-state privilege'
);

reset role;
select throws_ok(
  $$
    update public.chore_assignment_events
    set new_assignee_member_id = previous_assignee_member_id
    where correlation_id = '4a000000-0000-4000-8000-000000000603'
  $$,
  '55000',
  'chore assignment events are immutable',
  'assignment history cannot be updated even by a privileged path'
);
select throws_ok(
  $$
    delete from public.chore_assignment_events
    where correlation_id = '4a000000-0000-4000-8000-000000000603'
  $$,
  '55000',
  'chore assignment events are immutable',
  'assignment history cannot be deleted even by a privileged path'
);
select is(
  (
    select count(*)
    from app_private.chore_assignment_command_requests
  ),
  3::bigint,
  'exactly one private command result exists per successful assignment'
);
select is(
  (
    select count(*)
    from public.chore_assignment_events
  ),
  3::bigint,
  'exactly one immutable audit row exists per successful assignment'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select count(*)
    from public.chore_assignment_events
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  3::bigint,
  'active household owner can read the complete assignment history'
);

reset role;
select ok(
  exists (
    select 1
    from pg_constraint
    join pg_class on pg_class.oid = pg_constraint.conrelid
    join pg_namespace on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'chore_completion_events'
      and pg_constraint.conname = 'chore_completion_events_event_type_check'
      and pg_get_constraintdef(pg_constraint.oid) not like '%assigned%'
  ),
  'reassignment does not expand or forge completion audit vocabulary'
);

select * from finish();
rollback;
