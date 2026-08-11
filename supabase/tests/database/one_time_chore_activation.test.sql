begin;
set constraints all deferred;

select plan(61);

-- 01-19: schema, least privilege, RLS, and content-free event contract.
select has_type(
  'public',
  'occurrence_status',
  'chore occurrence status enum exists'
);
select has_table('public', 'chore_series', 'chore series table exists');
select has_table(
  'public',
  'chore_series_revisions',
  'chore revision table exists'
);
select has_table(
  'public',
  'chore_occurrences',
  'chore occurrence table exists'
);
select has_table(
  'app_private',
  'chore_command_requests',
  'private chore idempotency table exists'
);
select has_table(
  'app_private',
  'chore_domain_events',
  'private chore event table exists'
);
select has_function(
  'public',
  'create_one_time_chore',
  array['uuid', 'uuid', 'text', 'text', 'uuid', 'date', 'time without time zone'],
  'one-time chore command has an authority-free input contract'
);
select has_function(
  'public',
  'get_today_chores',
  array['uuid'],
  'server-local Today chore query exists'
);
select ok(
  (
    select bool_and(pg_proc.prosecdef)
      and bool_and(pg_proc.proconfig @> array['search_path=""']::text[])
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname in (
        'create_one_time_chore',
        'get_today_chores'
      )
  ),
  'chore functions are security-definer with an empty search path'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.create_one_time_chore(uuid,uuid,text,text,uuid,date,time without time zone)',
    'execute'
  )
    and has_function_privilege(
      'authenticated',
      'public.get_today_chores(uuid)',
      'execute'
    ),
  'authenticated clients can execute mediated chore functions'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.create_one_time_chore(uuid,uuid,text,text,uuid,date,time without time zone)',
    'execute'
  )
    and not has_function_privilege(
      'anon',
      'public.get_today_chores(uuid)',
      'execute'
    ),
  'anonymous clients cannot execute chore functions'
);
select ok(
  has_table_privilege('authenticated', 'public.chore_series', 'select')
    and has_table_privilege(
      'authenticated',
      'public.chore_series_revisions',
      'select'
    )
    and has_table_privilege(
      'authenticated',
      'public.chore_occurrences',
      'select'
    ),
  'authenticated clients have read-only chore table grants'
);
select ok(
  not has_table_privilege('authenticated', 'public.chore_series', 'insert')
    and not has_table_privilege(
      'authenticated',
      'public.chore_series',
      'update'
    )
    and not has_table_privilege(
      'authenticated',
      'public.chore_series',
      'delete'
    )
    and not has_table_privilege(
      'authenticated',
      'public.chore_occurrences',
      'update'
    ),
  'client roles cannot bypass mediated chore mutations'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.chore_command_requests',
    'select'
  )
    and not has_table_privilege(
      'authenticated',
      'app_private.chore_domain_events',
      'select'
    ),
  'client roles cannot inspect chore idempotency or event records'
);
select ok(
  (
    select bool_and(pg_class.relrowsecurity)
      and bool_and(pg_class.relforcerowsecurity)
    from pg_class
    join pg_namespace on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname in (
        'chore_series',
        'chore_series_revisions',
        'chore_occurrences'
      )
  ),
  'all chore tables enable and force RLS'
);
select ok(
  exists (
    select 1
    from pg_trigger
    join pg_class on pg_class.oid = pg_trigger.tgrelid
    join pg_namespace on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'app_private'
      and pg_class.relname = 'chore_domain_events'
      and pg_trigger.tgname = 'chore_domain_events_immutable'
      and not pg_trigger.tgisinternal
      and pg_trigger.tgenabled = 'O'
  ),
  'chore event immutability trigger is enabled'
);
select hasnt_column(
  'app_private',
  'chore_domain_events',
  'title',
  'chore event records do not store titles'
);
select hasnt_column(
  'app_private',
  'chore_domain_events',
  'description',
  'chore event records do not store descriptions'
);
select hasnt_column(
  'app_private',
  'chore_domain_events',
  'authenticated_user_id',
  'activation event records avoid auth user identifiers'
);

-- 20-24: authentication and input validation.
select throws_ok(
  $$
    select * from public.create_one_time_chore(
      '40000000-0000-4000-8000-000000000601',
      '20000000-0000-4000-8000-000000000101',
      'Unauthenticated chore',
      null,
      '30000000-0000-4000-8000-000000000101',
      current_date,
      null
    )
  $$,
  'KFC01',
  'authentication required',
  'create command derives identity from JWT'
);
select throws_ok(
  $$select * from public.get_today_chores(
    '20000000-0000-4000-8000-000000000101'
  )$$,
  'KFC01',
  'authentication required',
  'Today query requires authentication'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);

select throws_ok(
  $$
    select * from public.create_one_time_chore(
      '40000000-0000-4000-8000-000000000602',
      '20000000-0000-4000-8000-000000000101',
      '   ',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null
    )
  $$,
  'KFC02',
  'invalid chore input',
  'blank chore title is rejected'
);
select throws_ok(
  $$
    select * from public.create_one_time_chore(
      '40000000-0000-4000-8000-000000000603',
      '20000000-0000-4000-8000-000000000101',
      E'Line one\nLine two',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null
    )
  $$,
  'KFC02',
  'invalid chore input',
  'control characters in chore title are rejected'
);
select throws_ok(
  $$
    select * from public.create_one_time_chore(
      '40000000-0000-4000-8000-000000000604',
      '20000000-0000-4000-8000-000000000101',
      'No due date',
      null,
      '30000000-0000-4000-8000-000000000101',
      null,
      null
    )
  $$,
  'KFC02',
  'invalid chore input',
  'a household-local due date is required'
);
select throws_ok(
  $$
    select * from public.create_one_time_chore(
      '40000000-0000-4000-8000-000000000611',
      '20000000-0000-4000-8000-000000000101',
      'Second precision',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      '09:30:01'::time
    )
  $$,
  'KFC02',
  'invalid chore input',
  'due times use the client minute-precision contract'
);

-- 25-37: valid creation, invariant projection, events, and idempotency.
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '40000000-0000-4000-8000-000000000605',
      '20000000-0000-4000-8000-000000000101',
      '  Wash dishes  ',
      '  After dinner  ',
      '30000000-0000-4000-8000-000000000102',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      '09:30'::time
    )
  $$,
  'an active household adult can create a one-time chore'
);

reset role;
select is(
  (select count(*) from public.chore_series),
  1::bigint,
  'one series is persisted'
);
select is(
  (select count(*) from public.chore_series_revisions),
  1::bigint,
  'one immutable revision is persisted'
);
select is(
  (select count(*) from public.chore_occurrences),
  1::bigint,
  'one occurrence is materialized'
);
select ok(
  exists (
    select 1
    from public.chore_series as series
    join public.chore_series_revisions as revision
      on revision.household_id = series.household_id
     and revision.id = series.active_revision_id
    join public.chore_occurrences as occurrence
      on occurrence.household_id = series.household_id
     and occurrence.series_id = series.id
     and occurrence.revision_id = revision.id
    where revision.recurrence_rule = '{"type":"once"}'::jsonb
      and revision.revision_number = 1
      and occurrence.occurrence_key = series.id::text || ':once'
  ),
  'series, active revision, and occurrence remain separate and linked'
);
select ok(
  exists (
    select 1
    from public.chore_occurrences as occurrence
    where occurrence.timezone = 'Asia/Seoul'
      and occurrence.due_at is not null
      and occurrence.due_local_date =
        (occurrence.due_at at time zone occurrence.timezone)::date
  ),
  'timed due intent preserves the household local date'
);
select is(
  (
    select occurrence.assignee_member_id
    from public.chore_occurrences as occurrence
  ),
  '30000000-0000-4000-8000-000000000102'::uuid,
  'the requested same-household active adult is assigned'
);
select is(
  (
    select count(*)
    from app_private.chore_domain_events
    where event_name = 'chore.series_created'
  ),
  1::bigint,
  'series creation emits one content-free domain event'
);
select is(
  (
    select count(*)
    from app_private.chore_domain_events
    where event_name = 'activation.adult_first_chore_created'
  ),
  1::bigint,
  'the actor first-action event is recorded once'
);
select throws_ok(
  $$update app_private.chore_domain_events set aggregate_version = 2$$,
  '55000',
  'chore domain events are immutable',
  'chore domain events cannot be updated'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select result.created
    from public.create_one_time_chore(
      '40000000-0000-4000-8000-000000000605',
      '20000000-0000-4000-8000-000000000101',
      'Wash dishes',
      'After dinner',
      '30000000-0000-4000-8000-000000000102',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      '09:30'::time
    ) as result
  ),
  false,
  'same-key same-input replay returns the existing result'
);
reset role;
select is(
  (
    select count(*)
    from public.chore_series
  ) + (
    select count(*)
    from public.chore_series_revisions
  ) + (
    select count(*)
    from public.chore_occurrences
  ),
  3::bigint,
  'idempotent replay creates no duplicate series, revision, or occurrence'
);
select is(
  (select count(*) from app_private.chore_domain_events),
  2::bigint,
  'idempotent replay creates no duplicate domain events'
);

-- 38-46: injection, outsider, RLS, and direct-write denial.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.create_one_time_chore(
      '40000000-0000-4000-8000-000000000605',
      '20000000-0000-4000-8000-000000000101',
      'Different input',
      'After dinner',
      '30000000-0000-4000-8000-000000000102',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      '09:30'::time
    )
  $$,
  'KFC04',
  'idempotency key reused with different chore input',
  'same key with changed input is rejected'
);
select throws_ok(
  $$
    select * from public.create_one_time_chore(
      '40000000-0000-4000-8000-000000000606',
      '20000000-0000-4000-8000-000000000101',
      'Injected assignee',
      null,
      '30000000-0000-4000-8000-000000000201',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'another household member cannot be injected as assignee'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$
    select * from public.create_one_time_chore(
      '40000000-0000-4000-8000-000000000607',
      '20000000-0000-4000-8000-000000000101',
      'Outsider chore',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'an outsider cannot create in another household'
);
select throws_ok(
  $$select * from public.get_today_chores(
    '20000000-0000-4000-8000-000000000101'
  )$$,
  'KFC03',
  'chore not found or forbidden',
  'an outsider cannot query another household Today'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select count(*)
    from public.chore_series
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  1::bigint,
  'same-household RLS permits series reads'
);
select is(
  (
    select count(*)
    from public.chore_series
    where household_id = '20000000-0000-4000-8000-000000000201'
  ),
  0::bigint,
  'same-household RLS hides other-household series'
);
select is(
  (select count(*) from public.chore_series_revisions),
  1::bigint,
  'same-household RLS permits revision reads'
);
select is(
  (select count(*) from public.chore_occurrences),
  1::bigint,
  'same-household RLS permits occurrence reads'
);
select throws_ok(
  $$
    insert into public.chore_series (
      household_id,
      title,
      timezone,
      active_revision_id
    ) values (
      '20000000-0000-4000-8000-000000000101',
      'Direct bypass',
      'Asia/Seoul',
      '50000000-0000-4000-8000-000000000699'
    )
  $$,
  '42501',
  'permission denied for table chore_series',
  'authenticated clients cannot bypass the create command'
);

-- 47-55: second adult first action and server-local Today behavior.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '40000000-0000-4000-8000-000000000608',
      '20000000-0000-4000-8000-000000000101',
      'Take out recycling',
      null,
      '30000000-0000-4000-8000-000000000102',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      '11:00'::time
    )
  $$,
  'the invited adult can independently create a chore'
);
reset role;
select is(
  (
    select count(*)
    from app_private.chore_domain_events
    where event_name = 'activation.adult_first_chore_created'
  ),
  2::bigint,
  'each distinct adult records exactly one first independent action'
);
select is(
  (
    select count(*)
    from app_private.chore_domain_events
    where event_name = 'chore.series_created'
  ),
  2::bigint,
  'each created series emits its own domain event'
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
    from public.get_today_chores(
      '20000000-0000-4000-8000-000000000101'
    ) as today
    where today.occurrence_id is not null
  ),
  2::bigint,
  'Today returns both chores due on the household local date'
);
select ok(
  not exists (
    select 1
    from public.get_today_chores(
      '20000000-0000-4000-8000-000000000101'
    ) as today
    where today.household_timezone <> 'Asia/Seoul'
      or today.household_local_date <>
        (clock_timestamp() at time zone 'Asia/Seoul')::date
  ),
  'Today metadata is calculated in the server household timezone'
);
select is(
  (
    select string_agg(
      to_char(today.due_local_time, 'HH24:MI'),
      ','
      order by today.due_at nulls last
    )
    from public.get_today_chores(
      '20000000-0000-4000-8000-000000000101'
    ) as today
    where today.occurrence_id is not null
  ),
  '09:30,11:00',
  'Today chores are ordered by due instant'
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '40000000-0000-4000-8000-000000000609',
      '20000000-0000-4000-8000-000000000101',
      'Tomorrow chore',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date + 1,
      null
    )
  $$,
  'a future one-time chore can be created'
);
select is(
  (
    select count(*)
    from public.get_today_chores(
      '20000000-0000-4000-8000-000000000101'
    ) as today
    where today.occurrence_id is not null
  ),
  2::bigint,
  'future chores are excluded from Today'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select ok(
  exists (
    select 1
    from public.get_today_chores(
      '20000000-0000-4000-8000-000000000201'
    ) as today
    where today.household_timezone = 'UTC'
      and today.occurrence_id is null
  ),
  'an empty household receives Today metadata with no synthetic chore'
);

-- 56-60: removed member denial, assignment denial, immutable deletion, and minimal request storage.
reset role;
update public.household_members
set removed_at = clock_timestamp()
where household_id = '20000000-0000-4000-8000-000000000101'
  and id = '30000000-0000-4000-8000-000000000102';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select throws_ok(
  $$select * from public.get_today_chores(
    '20000000-0000-4000-8000-000000000101'
  )$$,
  'KFC03',
  'chore not found or forbidden',
  'a removed adult immediately loses Today access'
);
select is(
  (select count(*) from public.chore_occurrences),
  0::bigint,
  'RLS hides all former-household occurrences from a removed adult'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.create_one_time_chore(
      '40000000-0000-4000-8000-000000000610',
      '20000000-0000-4000-8000-000000000101',
      'Removed assignee',
      null,
      '30000000-0000-4000-8000-000000000102',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'a removed adult cannot receive a new assignment'
);
reset role;
select throws_ok(
  $$delete from app_private.chore_domain_events$$,
  '55000',
  'chore domain events are immutable',
  'chore domain events cannot be deleted'
);
select is(
  (
    select string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'chore_command_requests'
  ),
  'authenticated_user_id,idempotency_key,request_hash,household_id,series_id,occurrence_id,created_at',
  'idempotency storage contains only identity, hash, aggregate IDs, and time'
);

select * from finish();
rollback;
