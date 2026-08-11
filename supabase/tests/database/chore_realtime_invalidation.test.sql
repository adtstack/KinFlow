begin;
set constraints all deferred;

select plan(29);

-- 01-13: exact content-free schema, least privilege, triggers, publication.
select has_table(
  'public',
  'chore_sync_watermarks',
  'Chore sync watermark table exists'
);
select is(
  (
    select pg_catalog.string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'chore_sync_watermarks'
  ),
  'household_id,generation,changed_at',
  'watermark exposes only household generation and time'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'chore_sync_watermarks'
      and column_name in (
        'title', 'description', 'assignee_member_id', 'actor_user_id',
        'series_id', 'occurrence_id', 'correlation_id', 'command_id'
      )
  ),
  'Realtime invalidation storage contains no Chore content or target identity'
);
select ok(
  (
    select pg_class.relrowsecurity and pg_class.relforcerowsecurity
    from pg_catalog.pg_class
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'chore_sync_watermarks'
  ),
  'watermark RLS is enabled and forced'
);
select is(
  (
    select pg_catalog.count(*)
    from pg_catalog.pg_policy
    join pg_catalog.pg_class on pg_class.oid = pg_policy.polrelid
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'chore_sync_watermarks'
      and pg_policy.polcmd = 'r'
      and pg_policy.polroles = array['authenticated'::regrole::oid]
  ),
  1::bigint,
  'watermark has one authenticated select policy'
);
select ok(
  has_table_privilege(
    'authenticated',
    'public.chore_sync_watermarks',
    'select'
  )
  and not has_table_privilege(
    'authenticated',
    'public.chore_sync_watermarks',
    'insert'
  )
  and not has_table_privilege(
    'authenticated',
    'public.chore_sync_watermarks',
    'update'
  )
  and not has_table_privilege(
    'authenticated',
    'public.chore_sync_watermarks',
    'delete'
  ),
  'authenticated clients receive read-only watermark access'
);
select ok(
  not has_table_privilege(
    'anon',
    'public.chore_sync_watermarks',
    'select'
  ),
  'anonymous clients cannot read watermarks'
);
select is(
  (
    select pg_catalog.count(*)
    from pg_catalog.pg_trigger
    join pg_catalog.pg_class on pg_class.oid = pg_trigger.tgrelid
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where not pg_trigger.tgisinternal
      and pg_trigger.tgname in (
        'chore_occurrences_insert_advance_sync_watermark',
        'chore_occurrences_update_advance_sync_watermark',
        'chore_series_update_advance_sync_watermark',
        'household_members_update_advance_chore_sync_watermark',
        'households_update_advance_chore_sync_watermark'
      )
  ),
  5::bigint,
  'all Chore-visible change classes advance the watermark'
);
select ok(
  (
    select pg_catalog.bool_and(pg_proc.prosecdef)
      and pg_catalog.bool_and(
        pg_proc.proconfig @> array['search_path=""']::text[]
      )
    from pg_catalog.pg_proc
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'app_private'
      and pg_proc.proname in (
        'advance_chore_sync_watermark',
        'advance_chore_sync_from_changes',
        'advance_chore_sync_from_households'
      )
  ),
  'private watermark writers are security-definer with empty search paths'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.advance_chore_sync_watermark(uuid,timestamp with time zone)',
    'execute'
  )
  and not has_function_privilege(
    'service_role',
    'app_private.advance_chore_sync_watermark(uuid,timestamp with time zone)',
    'execute'
  ),
  'API roles cannot advance a watermark directly'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'chore_sync_watermarks'
  ),
  'the content-free Chore watermark is published'
);
select ok(
  not exists (
    select 1
    from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename in (
        'chore_series', 'chore_series_revisions', 'chore_occurrences'
      )
  ),
  'contentful Chore tables are not published by this contract'
);
select ok(
  not exists (
    select 1
    from pg_catalog.pg_trigger as trigger
    join pg_catalog.pg_class as relation on relation.oid = trigger.tgrelid
    join pg_catalog.pg_namespace as namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = 'chore_sync_watermarks'
      and trigger.tgname = 'app_runtime_policy_guard'
      and not trigger.tgisinternal
  ),
  'derived read-only watermark does not become a client mutation surface'
);

-- 14-19: a real mediated create emits one row and replay is silent.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$select * from public.create_one_time_chore(
    '4f000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000101',
    'Realtime Chore contract',
    'private content',
    '30000000-0000-4000-8000-000000000101',
    (pg_catalog.clock_timestamp() at time zone 'Asia/Seoul')::date,
    null
  )$$,
  'an interactive Chore create succeeds'
);

reset role;
select set_config(
  'kinflow_test.chore_sync_occurrence_id',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    join public.chore_series_revisions as revision
      on revision.household_id = occurrence.household_id
     and revision.id = occurrence.revision_id
    where revision.title = 'Realtime Chore contract'
  ),
  true
);
select is(
  (
    select pg_catalog.count(*)
    from public.chore_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  1::bigint,
  'one bounded watermark row exists per changed household'
);
select ok(
  (
    select generation > 0 and changed_at is not null
    from public.chore_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  'create emits a positive generation and timestamp'
);
select set_config(
  'kinflow_test.chore_sync_generation',
  (
    select generation::text
    from public.chore_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  true
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
      '4f000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Realtime Chore contract',
      'private content',
      '30000000-0000-4000-8000-000000000101',
      (pg_catalog.clock_timestamp() at time zone 'Asia/Seoul')::date,
      null
    ) as result
  ),
  false,
  'idempotent create replay returns the stored result'
);
reset role;
select is(
  (
    select generation
    from public.chore_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  current_setting('kinflow_test.chore_sync_generation')::bigint,
  'idempotent replay does not advance the watermark'
);
select ok(
  current_setting('kinflow_test.chore_sync_occurrence_id', true) is not null,
  'created occurrence identity is available only to the authoritative test'
);

-- 20-23: statement producers are monotonic and household-batched.
select set_config(
  'kinflow_test.chore_sync_generation',
  (
    select generation::text
    from public.chore_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  true
);
update public.household_members
set display_name = display_name
where household_id = '20000000-0000-4000-8000-000000000101'
  and removed_at is null;
select is(
  (
    select generation
    from public.chore_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  current_setting('kinflow_test.chore_sync_generation')::bigint + 1,
  'one multi-row member statement advances the household exactly once'
);
select set_config(
  'kinflow_test.chore_sync_generation',
  (
    select generation::text
    from public.chore_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  true
);
update public.households
set timezone = timezone
where id = '20000000-0000-4000-8000-000000000101';
select is(
  (
    select generation
    from public.chore_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  current_setting('kinflow_test.chore_sync_generation')::bigint + 1,
  'household boundary update advances the Chore watermark once'
);
select set_config(
  'kinflow_test.chore_sync_generation',
  (
    select generation::text
    from public.chore_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  true
);
update public.chore_series
set title = title
where id = (
  select occurrence.series_id
  from public.chore_occurrences as occurrence
  where occurrence.id =
    current_setting('kinflow_test.chore_sync_occurrence_id')::uuid
);
select is(
  (
    select generation
    from public.chore_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  current_setting('kinflow_test.chore_sync_generation')::bigint + 1,
  'series projection update advances the Chore watermark once'
);
select set_config(
  'kinflow_test.chore_sync_generation',
  (
    select generation::text
    from public.chore_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  true
);
update public.chore_occurrences
set status = status
where id = current_setting('kinflow_test.chore_sync_occurrence_id')::uuid;
select is(
  (
    select generation
    from public.chore_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  current_setting('kinflow_test.chore_sync_generation')::bigint + 1,
  'occurrence projection update advances the Chore watermark once'
);

-- 24-29: RLS visibility and client writes fail closed.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select pg_catalog.count(*)
    from public.chore_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  1::bigint,
  'active member can see its household watermark'
);
select throws_ok(
  $$insert into public.chore_sync_watermarks (
    household_id, generation, changed_at
  ) values (
    '20000000-0000-4000-8000-000000000201', 1, pg_catalog.now()
  )$$,
  '42501',
  'permission denied for table chore_sync_watermarks',
  'authenticated client cannot insert a watermark'
);
select throws_ok(
  $$update public.chore_sync_watermarks set generation = 99$$,
  '42501',
  'permission denied for table chore_sync_watermarks',
  'authenticated client cannot update a watermark'
);
select throws_ok(
  $$delete from public.chore_sync_watermarks$$,
  '42501',
  'permission denied for table chore_sync_watermarks',
  'authenticated client cannot delete a watermark'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select is(
  (
    select pg_catalog.count(*)
    from public.chore_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  0::bigint,
  'another household cannot see the watermark'
);
reset role;
update public.household_members
set removed_at = pg_catalog.clock_timestamp()
where household_id = '20000000-0000-4000-8000-000000000101'
  and id = '30000000-0000-4000-8000-000000000102';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select pg_catalog.count(*)
    from public.chore_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  0::bigint,
  'removed member immediately loses watermark visibility'
);

select * from finish();
rollback;
