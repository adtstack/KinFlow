begin;
set constraints all deferred;

select plan(56);

-- Schema, least privilege, RLS, and content-free audit contract.
select has_table(
  'public',
  'chore_completion_events',
  'completion audit table exists'
);
select has_table(
  'app_private',
  'chore_completion_command_requests',
  'private completion idempotency table exists'
);
select has_function(
  'public',
  'set_chore_occurrence_completion',
  array['uuid', 'uuid', 'uuid', 'bigint', 'boolean'],
  'versioned completion command exists'
);
select ok(
  (
    select pg_proc.prosecdef
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'set_chore_occurrence_completion'
  ),
  'completion command is security-definer with an empty search path'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.set_chore_occurrence_completion(uuid,uuid,uuid,bigint,boolean)',
    'execute'
  ),
  'authenticated clients can execute the mediated completion command'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.set_chore_occurrence_completion(uuid,uuid,uuid,bigint,boolean)',
    'execute'
  ),
  'anonymous clients cannot execute the completion command'
);
select ok(
  has_table_privilege(
    'authenticated',
    'public.chore_completion_events',
    'select'
  ),
  'authenticated clients can read same-household completion audit'
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
  'client roles cannot mutate completion audit rows'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.chore_completion_command_requests',
    'select'
  ),
  'client roles cannot inspect completion idempotency records'
);
select ok(
  (
    select pg_class.relrowsecurity and pg_class.relforcerowsecurity
    from pg_class
    join pg_namespace on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'chore_completion_events'
  ),
  'completion audit enables and forces RLS'
);
select ok(
  exists (
    select 1
    from pg_trigger
    join pg_class on pg_class.oid = pg_trigger.tgrelid
    join pg_namespace on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'chore_completion_events'
      and pg_trigger.tgname = 'chore_completion_events_immutable'
      and not pg_trigger.tgisinternal
      and pg_trigger.tgenabled = 'O'
  ),
  'completion audit immutability trigger is enabled'
);
select hasnt_column(
  'public',
  'chore_completion_events',
  'title',
  'completion audit does not store chore titles'
);
select hasnt_column(
  'public',
  'chore_completion_events',
  'description',
  'completion audit does not store chore notes'
);

-- Authentication, validation, and deterministic fixture creation.
select throws_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '41000000-0000-4000-8000-000000000601',
      '20000000-0000-4000-8000-000000000101',
      '51000000-0000-4000-8000-000000000601',
      1,
      true
    )
  $$,
  'KFC01',
  'authentication required',
  'completion derives identity from JWT'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);

select throws_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '41000000-0000-4000-8000-000000000602',
      '20000000-0000-4000-8000-000000000101',
      '51000000-0000-4000-8000-000000000602',
      0,
      true
    )
  $$,
  'KFC02',
  'invalid chore input',
  'completion requires a positive expected version'
);

select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '42000000-0000-4000-8000-000000000601',
      '20000000-0000-4000-8000-000000000101',
      'Member self target',
      null,
      '30000000-0000-4000-8000-000000000102',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null
    )
  $$,
  'owner can create the member self-completion fixture'
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '42000000-0000-4000-8000-000000000602',
      '20000000-0000-4000-8000-000000000101',
      'Owner target',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null
    )
  $$,
  'owner can create the owner-assigned fixture'
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '42000000-0000-4000-8000-000000000603',
      '20000000-0000-4000-8000-000000000101',
      'Owner completes member target',
      null,
      '30000000-0000-4000-8000-000000000102',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null
    )
  $$,
  'owner can create the privileged completion fixture'
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '42000000-0000-4000-8000-000000000604',
      '20000000-0000-4000-8000-000000000101',
      'Admin completes owner target',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null
    )
  $$,
  'owner can create the future admin completion fixture'
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '42000000-0000-4000-8000-000000000605',
      '20000000-0000-4000-8000-000000000101',
      'Stale completion target',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null
    )
  $$,
  'owner can create the stale-write fixture'
);

select set_config(
  'kinflow.test.member_target_occurrence_id',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Member self target'
  ),
  true
);
select set_config(
  'kinflow.test.owner_target_occurrence_id',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Owner target'
  ),
  true
);

-- Member self-completion, completed fields, audit, and idempotent replay.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select result.status
    from public.set_chore_occurrence_completion(
      '41000000-0000-4000-8000-000000000603',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Member self target'
      ),
      1,
      true
    ) as result
  ),
  'completed',
  'a Member can complete their assigned occurrence'
);
reset role;
select ok(
  exists (
    select 1
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Member self target'
      and occurrence.status = 'completed'
      and occurrence.completed_by_member_id =
        '30000000-0000-4000-8000-000000000102'
      and occurrence.completed_by_user_id =
        '00000000-0000-4000-8000-000000000102'
      and occurrence.completed_at is not null
  ),
  'completion records the authenticated user and actor member atomically'
);
select is(
  (
    select occurrence.version
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Member self target'
  ),
  2::bigint,
  'completion increments the occurrence version exactly once'
);
select is(
  (
    select count(*)
    from public.chore_completion_events as event
    where event.event_type = 'completed'
      and event.actor_member_id =
        '30000000-0000-4000-8000-000000000102'
  ),
  1::bigint,
  'completion emits one actor audit event'
);
select ok(
  exists (
    select 1
    from public.chore_completion_events as event
    where event.event_type = 'completed'
      and event.occurrence_version = 2
      and event.acting_member_id is null
      and event.actor_user_id =
        '00000000-0000-4000-8000-000000000102'
  ),
  'adult completion audit records no acting child context'
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
    from public.set_chore_occurrence_completion(
      '41000000-0000-4000-8000-000000000603',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Member self target'
      ),
      1,
      true
    ) as result
  ),
  false,
  'same-key same-input completion replay returns the original result'
);
select is(
  (
    select result.version
    from public.set_chore_occurrence_completion(
      '41000000-0000-4000-8000-000000000603',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Member self target'
      ),
      1,
      true
    ) as result
  ),
  2::bigint,
  'completion replay keeps the original result version'
);
select throws_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '41000000-0000-4000-8000-000000000603',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Member self target'
      ),
      2,
      false
    )
  $$,
  'KFC04',
  'idempotency key reused with different chore input',
  'same key with a different completion request is rejected'
);
select throws_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '41000000-0000-4000-8000-000000000604',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Member self target'
      ),
      2,
      true
    )
  $$,
  'KFC06',
  'chore occurrence transition not allowed',
  'a new complete command cannot complete an already completed occurrence'
);
select throws_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '41000000-0000-4000-8000-000000000605',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Owner target'
      ),
      1,
      true
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'a Member cannot complete another adult assignment'
);

-- Owner/Admin authority and optimistic-version conflict behavior.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select result.status
    from public.set_chore_occurrence_completion(
      '41000000-0000-4000-8000-000000000606',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Owner completes member target'
      ),
      1,
      true
    ) as result
  ),
  'completed',
  'Owner can complete another member assignment'
);
reset role;
select is(
  (
    select occurrence.completed_by_member_id
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Owner completes member target'
  ),
  '30000000-0000-4000-8000-000000000101'::uuid,
  'privileged completion records the Owner actor'
);

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
    from public.set_chore_occurrence_completion(
      '41000000-0000-4000-8000-000000000607',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Admin completes owner target'
      ),
      1,
      true
    ) as result
  ),
  'completed',
  'Admin can complete another member assignment'
);
reset role;
select is(
  (
    select occurrence.completed_by_member_id
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Admin completes owner target'
  ),
  '30000000-0000-4000-8000-000000000102'::uuid,
  'privileged completion records the Admin actor'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select result.version
    from public.set_chore_occurrence_completion(
      '41000000-0000-4000-8000-000000000608',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Stale completion target'
      ),
      1,
      true
    ) as result
  ),
  2::bigint,
  'the first command with an expected version succeeds'
);
select throws_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '41000000-0000-4000-8000-000000000609',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Stale completion target'
      ),
      1,
      false
    )
  $$,
  'KFC05',
  'chore occurrence version conflict',
  'a second command with the stale expected version is rejected'
);

-- Reopen clears completion fields but preserves append-only history.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select result.status
    from public.set_chore_occurrence_completion(
      '41000000-0000-4000-8000-000000000610',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Member self target'
      ),
      2,
      false
    ) as result
  ),
  'scheduled',
  'the assignee can reopen a completed occurrence'
);
select ok(
  (
    select result.completed_by_member_id is null
      and result.completed_at is null
      and result.version = 3
    from public.set_chore_occurrence_completion(
      '41000000-0000-4000-8000-000000000610',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Member self target'
      ),
      2,
      false
    ) as result
  ),
  'reopen replay returns cleared completion fields and result version'
);
reset role;
select ok(
  exists (
    select 1
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Member self target'
      and occurrence.status = 'scheduled'
      and occurrence.version = 3
      and occurrence.completed_by_member_id is null
      and occurrence.completed_by_user_id is null
      and occurrence.completed_at is null
  ),
  'reopen atomically clears every completion field'
);
select is(
  (
    select string_agg(
      event.event_type || ':' || event.occurrence_version::text,
      ','
      order by event.occurrence_version
    )
    from public.chore_completion_events as event
    join public.chore_series as series on series.id = (
      select occurrence.series_id
      from public.chore_occurrences as occurrence
      where occurrence.id = event.occurrence_id
    )
    where series.title = 'Member self target'
  ),
  'completed:2,reopened:3',
  'reopen preserves ordered completion history'
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
    from public.set_chore_occurrence_completion(
      '41000000-0000-4000-8000-000000000610',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Member self target'
      ),
      2,
      false
    ) as result
  ),
  false,
  'same-key reopen replay is idempotent'
);
select is(
  (
    select result.status || ':' || result.version::text
    from public.set_chore_occurrence_completion(
      '41000000-0000-4000-8000-000000000603',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Member self target'
      ),
      1,
      true
    ) as result
  ),
  'completed:2',
  'old completion replay remains stable after a later reopen'
);
select throws_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '41000000-0000-4000-8000-000000000611',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Member self target'
      ),
      3,
      false
    )
  $$,
  'KFC06',
  'chore occurrence transition not allowed',
  'a new reopen command cannot reopen a scheduled occurrence'
);
select is(
  (
    select today.status || ':' || today.version::text
    from public.get_today_chores(
      '20000000-0000-4000-8000-000000000101'
    ) as today
    where today.title = 'Member self target'
  ),
  'scheduled:3',
  'Today reflects the reopened authoritative status and version'
);

-- Cross-household, removed-member, RLS, and direct-write denial.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '41000000-0000-4000-8000-000000000612',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.owner_target_occurrence_id')::uuid,
      1,
      true
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'an outsider cannot inject another household occurrence'
);
select is(
  (
    select count(*)
    from public.chore_completion_events
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  0::bigint,
  'completion audit RLS hides another household'
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
    select * from public.set_chore_occurrence_completion(
      '41000000-0000-4000-8000-000000000613',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.member_target_occurrence_id')::uuid,
      3,
      true
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'a removed adult cannot complete a former-household occurrence'
);
select is(
  (select count(*) from public.chore_completion_events),
  0::bigint,
  'removed member RLS hides former-household completion audit'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    update public.chore_occurrences
    set status = 'completed'
    where household_id = '20000000-0000-4000-8000-000000000101'
  $$,
  '42501',
  'permission denied for table chore_occurrences',
  'authenticated clients cannot directly update occurrence status'
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
      '51000000-0000-4000-8000-000000000699',
      'completed',
      '30000000-0000-4000-8000-000000000101',
      1,
      '41000000-0000-4000-8000-000000000699'
    )
  $$,
  '42501',
  'permission denied for table chore_completion_events',
  'authenticated clients cannot forge completion audit'
);
select is(
  (
    select count(*)
    from public.chore_completion_events
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  5::bigint,
  'same-household RLS exposes the five successful transition events'
);

reset role;
select throws_ok(
  $$update public.chore_completion_events set occurrence_version = 99$$,
  '55000',
  'chore completion events are immutable',
  'completion audit cannot be updated'
);
select throws_ok(
  $$delete from public.chore_completion_events$$,
  '55000',
  'chore completion events are immutable',
  'completion audit cannot be deleted'
);
select is(
  (
    select count(*)
    from app_private.chore_completion_command_requests
  ),
  5::bigint,
  'only successful unique transition commands persist idempotency results'
);
select is(
  (
    select string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'chore_completion_command_requests'
  ),
  'authenticated_user_id,idempotency_key,request_hash,household_id,occurrence_id,result_status,result_version,result_completed_by_member_id,result_completed_at,result_event_id,created_at',
  'completion idempotency storage contains only hashes, IDs, result state, and time'
);
select is(
  (
    select string_agg(
      distinct event.event_type,
      ','
      order by event.event_type
    )
    from public.chore_completion_events as event
  ),
  'completed,reopened',
  'completion audit contains only adult complete and reopen transitions'
);

select * from finish();
rollback;
