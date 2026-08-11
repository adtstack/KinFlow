begin;
set constraints all deferred;

select plan(38);

-- 01-14: content-free schema, least privilege, triggers, and publication.
select has_table(
  'public',
  'calendar_sync_watermarks',
  'Calendar sync watermark table exists'
);
select is(
  (
    select pg_catalog.string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'calendar_sync_watermarks'
  ),
  'household_id,generation,changed_at',
  'watermark exposes only household generation and time'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'calendar_sync_watermarks'
      and column_name in (
        'title', 'description', 'participant_id', 'actor_user_id',
        'correlation_id', 'series_id', 'occurrence_id'
      )
  ),
  'Realtime invalidation storage contains no event content or actor identity'
);
select ok(
  (
    select pg_class.relrowsecurity and pg_class.relforcerowsecurity
    from pg_catalog.pg_class
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'calendar_sync_watermarks'
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
      and pg_class.relname = 'calendar_sync_watermarks'
      and pg_policy.polcmd = 'r'
      and pg_policy.polroles = array['authenticated'::regrole::oid]
  ),
  1::bigint,
  'watermark has one authenticated select policy'
);
select ok(
  has_table_privilege(
    'authenticated',
    'public.calendar_sync_watermarks',
    'select'
  )
  and not has_table_privilege(
    'authenticated',
    'public.calendar_sync_watermarks',
    'insert'
  )
  and not has_table_privilege(
    'authenticated',
    'public.calendar_sync_watermarks',
    'update'
  )
  and not has_table_privilege(
    'authenticated',
    'public.calendar_sync_watermarks',
    'delete'
  ),
  'authenticated clients receive read-only watermark access'
);
select ok(
  not has_table_privilege(
    'anon',
    'public.calendar_sync_watermarks',
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
        'calendar_audit_advance_sync_watermark',
        'event_occurrences_insert_advance_sync_watermark',
        'event_occurrences_update_advance_sync_watermark'
      )
  ),
  3::bigint,
  'interactive and horizon occurrence changes advance the watermark'
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
        'advance_calendar_sync_watermark',
        'advance_calendar_sync_from_audit',
        'advance_calendar_sync_from_occurrences'
      )
  ),
  'private watermark writers are security-definer with empty search paths'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.advance_calendar_sync_watermark(uuid,timestamp with time zone)',
    'execute'
  )
  and not has_function_privilege(
    'service_role',
    'app_private.advance_calendar_sync_watermark(uuid,timestamp with time zone)',
    'execute'
  ),
  'API roles cannot advance a watermark directly'
);
select has_function(
  'public',
  'get_calendar_occurrence_locator',
  array['uuid', 'uuid'],
  'content-free occurrence locator RPC exists'
);
select ok(
  (
    select pg_proc.prosecdef
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_catalog.pg_proc
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'get_calendar_occurrence_locator'
      and pg_catalog.pg_get_function_identity_arguments(pg_proc.oid) =
        'p_household_id uuid, p_occurrence_id uuid'
  ),
  'locator is security-definer with an empty search path'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.get_calendar_occurrence_locator(uuid,uuid)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.get_calendar_occurrence_locator(uuid,uuid)',
    'execute'
  ),
  'only authenticated clients execute the locator'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'calendar_sync_watermarks'
  ),
  'only the content-free watermark table is published for this feature'
);

-- 15-16: stable authentication and input errors.
select throws_ok(
  $$select * from public.get_calendar_occurrence_locator(
    '20000000-0000-4000-8000-000000000101',
    '50000000-0000-4000-8000-000000000001'
  )$$,
  'KFE01',
  'authentication required',
  'locator derives its caller from JWT'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$select * from public.get_calendar_occurrence_locator(
    null,
    '50000000-0000-4000-8000-000000000001'
  )$$,
  'KFE02',
  'invalid calendar occurrence locator input',
  'locator validates both UUID inputs'
);

-- 17-26: create, RLS visibility, locator shape, and write denial.
select lives_ok(
  $$select * from public.create_one_time_event(
    '48000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000101',
    'Realtime contract event', 'private description', true,
    date '2026-08-08', null, null, date '2026-08-09',
    null, null,
    array['30000000-0000-4000-8000-000000000101'::uuid]
  )$$,
  'an interactive Calendar create succeeds'
);

reset role;
select set_config(
  'kinflow_test.sync_series_id',
  (
    select id::text
    from public.event_series
    where title = 'Realtime contract event'
  ),
  true
);
select set_config(
  'kinflow_test.sync_occurrence_id',
  (
    select id::text
    from public.event_occurrences
    where series_id = current_setting('kinflow_test.sync_series_id')::uuid
  ),
  true
);
select is(
  (
    select pg_catalog.count(*)
    from public.calendar_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  1::bigint,
  'one bounded watermark row exists per changed household'
);
select ok(
  (
    select generation >= 2 and changed_at is not null
    from public.calendar_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  'create advances a positive monotonic generation'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select pg_catalog.count(*)
    from public.calendar_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  1::bigint,
  'active member can see its household watermark'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      locator.household_id,
      locator.series_id,
      locator.occurrence_id
    )
    from public.get_calendar_occurrence_locator(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow_test.sync_occurrence_id')::uuid
    ) as locator
  ),
  '20000000-0000-4000-8000-000000000101:'
    || current_setting('kinflow_test.sync_series_id') || ':'
    || current_setting('kinflow_test.sync_occurrence_id'),
  'locator returns only the requested household and occurrence identity'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      locator.series_version,
      locator.occurrence_version
    )
    from public.get_calendar_occurrence_locator(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow_test.sync_occurrence_id')::uuid
    ) as locator
  ),
  '1:1',
  'locator returns current optimistic concurrency versions'
);
select ok(
  (
    select locator.household_timezone = 'Asia/Seoul'
      and locator.household_local_date is not null
      and locator.generated_at is not null
      and locator.view_local_date = date '2026-08-08'
    from public.get_calendar_occurrence_locator(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow_test.sync_occurrence_id')::uuid
    ) as locator
  ),
  'locator returns authoritative household-local navigation context'
);
select throws_ok(
  $$insert into public.calendar_sync_watermarks (
    household_id, generation, changed_at
  ) values (
    '20000000-0000-4000-8000-000000000201', 1, pg_catalog.now()
  )$$,
  '42501',
  'permission denied for table calendar_sync_watermarks',
  'authenticated client cannot insert a watermark'
);
select throws_ok(
  $$update public.calendar_sync_watermarks set generation = 99$$,
  '42501',
  'permission denied for table calendar_sync_watermarks',
  'authenticated client cannot update a watermark'
);
select throws_ok(
  $$delete from public.calendar_sync_watermarks$$,
  '42501',
  'permission denied for table calendar_sync_watermarks',
  'authenticated client cannot delete a watermark'
);

-- 27-28: replay is idempotent and does not emit a false invalidation.
reset role;
select set_config(
  'kinflow_test.sync_generation',
  (
    select generation::text
    from public.calendar_sync_watermarks
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
    from public.create_one_time_event(
      '48000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Realtime contract event', 'private description', true,
      date '2026-08-08', null, null, date '2026-08-09',
      null, null,
      array['30000000-0000-4000-8000-000000000101'::uuid]
    ) as result
  ),
  false,
  'idempotent create replay returns the stored result'
);
reset role;
select is(
  (
    select generation
    from public.calendar_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  current_setting('kinflow_test.sync_generation')::bigint,
  'idempotent replay does not advance the watermark'
);

-- 29-32: outsider and removed-member visibility fails closed.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select is(
  (
    select pg_catalog.count(*)
    from public.calendar_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  0::bigint,
  'another household cannot see the watermark'
);
select throws_ok(
  $$select * from public.get_calendar_occurrence_locator(
    '20000000-0000-4000-8000-000000000101',
    current_setting('kinflow_test.sync_occurrence_id')::uuid
  )$$,
  'KFE03',
  'calendar occurrence not found or forbidden',
  'another household cannot probe an occurrence deep link'
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
    from public.calendar_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  0::bigint,
  'removed member immediately loses watermark visibility'
);
select throws_ok(
  $$select * from public.get_calendar_occurrence_locator(
    '20000000-0000-4000-8000-000000000101',
    current_setting('kinflow_test.sync_occurrence_id')::uuid
  )$$,
  'KFE03',
  'calendar occurrence not found or forbidden',
  'removed member immediately loses deep-link access'
);

-- 33-38: updates advance versions; deletion makes the locator unavailable.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select result.changed
    from public.update_one_time_event(
      '48000000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow_test.sync_series_id')::uuid,
      1,
      'Realtime contract event updated', null, true,
      date '2026-08-08', null, null, date '2026-08-10',
      null, null,
      array['30000000-0000-4000-8000-000000000101'::uuid]
    ) as result
  ),
  true,
  'versioned event update succeeds'
);
reset role;
select ok(
  (
    select generation > current_setting('kinflow_test.sync_generation')::bigint
    from public.calendar_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  'effective update advances the watermark'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      locator.series_version,
      locator.occurrence_version
    )
    from public.get_calendar_occurrence_locator(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow_test.sync_occurrence_id')::uuid
    ) as locator
  ),
  '2:2',
  'locator exposes the latest versions after update'
);
select is(
  (
    select result.deleted
    from public.delete_one_time_event(
      '48000000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow_test.sync_series_id')::uuid,
      2
    ) as result
  ),
  true,
  'versioned event deletion succeeds'
);
reset role;
select ok(
  (
    select generation > current_setting('kinflow_test.sync_generation')::bigint
    from public.calendar_sync_watermarks
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  'effective deletion leaves an advanced invalidation watermark'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$select * from public.get_calendar_occurrence_locator(
    '20000000-0000-4000-8000-000000000101',
    current_setting('kinflow_test.sync_occurrence_id')::uuid
  )$$,
  'KFE03',
  'calendar occurrence not found or forbidden',
  'deleted occurrence deep link fails closed'
);

select * from finish();
rollback;
