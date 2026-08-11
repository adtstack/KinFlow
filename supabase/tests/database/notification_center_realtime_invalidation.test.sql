begin;
set constraints all deferred;

select plan(42);

-- 01-13: exact content-free schema, least privilege, triggers, publication.
select has_table(
  'public',
  'notification_sync_watermarks',
  'Notification Center sync watermark table exists'
);
select is(
  (
    select pg_catalog.string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'notification_sync_watermarks'
  ),
  'auth_user_id,generation,changed_at',
  'watermark exposes only user routing, generation, and time'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'notification_sync_watermarks'
      and column_name in (
        'household_id', 'member_id', 'inbox_item_id', 'source_event_id',
        'subject_id', 'category', 'read_at', 'payload', 'title',
        'description', 'command_id', 'correlation_id'
      )
  ),
  'Realtime invalidation storage contains no notification content or target'
);
select ok(
  (
    select pg_class.relrowsecurity and pg_class.relforcerowsecurity
    from pg_catalog.pg_class
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'notification_sync_watermarks'
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
      and pg_class.relname = 'notification_sync_watermarks'
      and pg_policy.polcmd = 'r'
      and pg_policy.polroles = array['authenticated'::regrole::oid]
  ),
  1::bigint,
  'watermark has one authenticated self-select policy'
);
select ok(
  has_table_privilege(
    'authenticated',
    'public.notification_sync_watermarks',
    'select'
  )
  and not has_table_privilege(
    'authenticated',
    'public.notification_sync_watermarks',
    'insert'
  )
  and not has_table_privilege(
    'authenticated',
    'public.notification_sync_watermarks',
    'update'
  )
  and not has_table_privilege(
    'authenticated',
    'public.notification_sync_watermarks',
    'delete'
  ),
  'authenticated clients receive read-only watermark access'
);
select ok(
  not has_table_privilege(
    'anon',
    'public.notification_sync_watermarks',
    'select'
  ),
  'anonymous clients cannot read notification watermarks'
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
        'notification_inbox_insert_advance_sync_watermark',
        'notification_inbox_update_advance_sync_watermark',
        'notification_preferences_insert_advance_sync_watermark',
        'notification_preferences_update_advance_sync_watermark',
        'household_members_update_advance_notification_sync_watermark',
        'households_update_advance_notification_sync_watermark'
      )
  ),
  6::bigint,
  'all notification-visible change classes advance the watermark'
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
        'advance_notification_sync_watermark',
        'advance_notification_sync_from_inbox',
        'advance_notification_sync_from_preferences',
        'advance_notification_sync_from_members',
        'advance_notification_sync_from_households'
      )
  ),
  'private watermark writers are security-definer with empty search paths'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.advance_notification_sync_watermark(uuid,timestamp with time zone)',
    'execute'
  )
  and not has_function_privilege(
    'service_role',
    'app_private.advance_notification_sync_watermark(uuid,timestamp with time zone)',
    'execute'
  ),
  'API roles cannot advance a notification watermark directly'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notification_sync_watermarks'
  ),
  'the content-free notification watermark is published'
);
select ok(
  not exists (
    select 1
    from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename in (
        'notification_preferences', 'notification_inbox_items'
      )
  ),
  'contentful notification tables are not published by this contract'
);
select ok(
  not exists (
    select 1
    from pg_catalog.pg_trigger as trigger
    join pg_catalog.pg_class as relation on relation.oid = trigger.tgrelid
    join pg_catalog.pg_namespace as namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = 'notification_sync_watermarks'
      and trigger.tgname = 'app_runtime_policy_guard'
      and not trigger.tgisinternal
  ),
  'derived read-only watermark is not a client mutation surface'
);

-- 14-22: preference writes are monotonic, replay-safe, and user-batched.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
set local role authenticated;
select is(
  (
    select version
    from public.update_notification_preference(
      '20000000-0000-4000-8000-000000000101',
      'chore_due', true, false, false, true,
      null, null, 'Asia/Seoul', 0
    )
  ),
  1::bigint,
  'first preference command creates version one'
);
reset role;
select is(
  (
    select pg_catalog.count(*)
    from public.notification_sync_watermarks
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
  ),
  1::bigint,
  'one bounded watermark row exists per changed user'
);
select ok(
  (
    select generation > 0 and changed_at is not null
    from public.notification_sync_watermarks
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
  ),
  'preference creation emits a positive generation and timestamp'
);
select set_config(
  'kinflow_test.notification_sync_generation',
  (
    select generation::text
    from public.notification_sync_watermarks
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
  ),
  true
);
set local role authenticated;
select is(
  (
    select version
    from public.update_notification_preference(
      '20000000-0000-4000-8000-000000000101',
      'chore_due', true, false, false, true,
      null, null, 'Asia/Seoul', 0
    )
  ),
  1::bigint,
  'identical response-loss replay returns the stored preference'
);
reset role;
select is(
  (
    select generation
    from public.notification_sync_watermarks
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
  ),
  current_setting('kinflow_test.notification_sync_generation')::bigint,
  'identical preference replay does not advance the watermark'
);
set local role authenticated;
select is(
  (
    select version
    from public.update_notification_preference(
      '20000000-0000-4000-8000-000000000101',
      'chore_due', true, false, true, true,
      null, null, 'Asia/Seoul', 1
    )
  ),
  2::bigint,
  'an effective preference change advances its version'
);
reset role;
select is(
  (
    select generation
    from public.notification_sync_watermarks
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
  ),
  current_setting('kinflow_test.notification_sync_generation')::bigint + 1,
  'an effective preference change advances notification generation once'
);
set local role authenticated;
select is(
  (
    select version
    from public.update_notification_preference(
      '20000000-0000-4000-8000-000000000101',
      'chore_assignment', true, false, false, true,
      null, null, 'Asia/Seoul', 0
    )
  ),
  1::bigint,
  'a second category creates an independently versioned preference'
);
reset role;
select set_config(
  'kinflow_test.notification_sync_generation',
  (
    select generation::text
    from public.notification_sync_watermarks
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
  ),
  true
);
update public.notification_preferences
set timezone = timezone
where auth_user_id = '00000000-0000-4000-8000-000000000102';
select is(
  (
    select generation
    from public.notification_sync_watermarks
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
  ),
  current_setting('kinflow_test.notification_sync_generation')::bigint + 1,
  'one multi-row preference statement advances the user exactly once'
);

-- 23-33: materialization and read-all invalidate once; replays stay silent.
create temporary table notification_sync_claims (
  event_id uuid primary key,
  lease_token uuid not null,
  attempt integer not null,
  max_attempts integer not null,
  lease_expires_at timestamptz not null
);
grant all on table notification_sync_claims to service_role;

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '52000000-0000-4000-8000-000000000316',
      '20000000-0000-4000-8000-000000000101',
      'Notification sync fixture',
      'Never copied to the watermark',
      '30000000-0000-4000-8000-000000000102',
      '2031-01-02',
      time '09:15'
    )
  $$,
  'one-time Chore creation emits notification source events'
);
set local role service_role;
select lives_ok(
  $$
    insert into notification_sync_claims
    select *
    from public.claim_chore_notification_events(
      '52000000-0000-4000-8000-000000000016',
      10,
      60,
      pg_catalog.statement_timestamp()
    )
  $$,
  'service worker claims the notification source events'
);
select is(
  (select pg_catalog.count(*) from notification_sync_claims),
  2::bigint,
  'due and assignment sources are independently claimed'
);
select lives_ok(
  $$
    select public.process_chore_notification_event(
      claim.event_id,
      claim.lease_token,
      pg_catalog.statement_timestamp()
    )
    from notification_sync_claims as claim
  $$,
  'claimed sources resolve before inbox materialization'
);
select is(
  (
    select concat_ws(
      ':', claimed_count, created_count, disabled_count, stale_count,
      suppressed_count, cancelled_count
    )
    from public.materialize_chore_notification_inbox(
      10,
      pg_catalog.statement_timestamp()
    )
  ),
  '2:2:0:0:0:0',
  'one worker pass creates both durable inbox items'
);
reset role;
select is(
  (
    select pg_catalog.count(*)
    from public.notification_inbox_items
    where recipient_user_id = '00000000-0000-4000-8000-000000000102'
      and cancelled_at is null
  ),
  2::bigint,
  'recipient has two active inbox items'
);
select is(
  (
    select pg_catalog.count(*)
    from public.notification_sync_watermarks
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
  ),
  1::bigint,
  'inbox changes retain one bounded row for the recipient'
);
select set_config(
  'kinflow_test.notification_sync_generation',
  (
    select generation::text
    from public.notification_sync_watermarks
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
  ),
  true
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
set local role authenticated;
select is(
  (
    select concat_ws(':', marked_count, unread_count)
    from public.mark_all_notification_inbox_read(
      '20000000-0000-4000-8000-000000000101',
      null
    )
  ),
  '2:0',
  'read-all updates every unread item and badge atomically'
);
reset role;
select is(
  (
    select generation
    from public.notification_sync_watermarks
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
  ),
  current_setting('kinflow_test.notification_sync_generation')::bigint + 1,
  'one multi-row read statement advances the user exactly once'
);
select set_config(
  'kinflow_test.notification_sync_generation',
  (
    select generation::text
    from public.notification_sync_watermarks
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
  ),
  true
);
set local role authenticated;
select is(
  (
    select concat_ws(':', marked_count, unread_count)
    from public.mark_all_notification_inbox_read(
      '20000000-0000-4000-8000-000000000101',
      null
    )
  ),
  '0:0',
  'read-all response-loss replay returns the authoritative zero badge'
);
reset role;
select is(
  (
    select generation
    from public.notification_sync_watermarks
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
  ),
  current_setting('kinflow_test.notification_sync_generation')::bigint,
  'zero-row read replay does not advance the watermark'
);

-- 34-35: authorization projection changes are also statement-batched.
select set_config(
  'kinflow_test.notification_sync_generation',
  (
    select generation::text
    from public.notification_sync_watermarks
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
  ),
  true
);
update public.households
set timezone = timezone
where id = '20000000-0000-4000-8000-000000000101';
select is(
  (
    select generation
    from public.notification_sync_watermarks
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
  ),
  current_setting('kinflow_test.notification_sync_generation')::bigint + 1,
  'household default-preference boundary advances notification sync once'
);
select set_config(
  'kinflow_test.notification_sync_generation',
  (
    select generation::text
    from public.notification_sync_watermarks
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
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
    from public.notification_sync_watermarks
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
  ),
  current_setting('kinflow_test.notification_sync_generation')::bigint + 1,
  'one multi-member statement advances each affected user exactly once'
);

-- 36-42: self-only RLS and revocation delivery fail closed.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (select pg_catalog.count(*) from public.notification_sync_watermarks),
  1::bigint,
  'authenticated user sees exactly its own watermark'
);
select throws_ok(
  $$insert into public.notification_sync_watermarks (
    auth_user_id, generation, changed_at
  ) values (
    '00000000-0000-4000-8000-000000000201', 1, pg_catalog.now()
  )$$,
  '42501',
  'permission denied for table notification_sync_watermarks',
  'authenticated client cannot insert a watermark'
);
select throws_ok(
  $$update public.notification_sync_watermarks set generation = 99$$,
  '42501',
  'permission denied for table notification_sync_watermarks',
  'authenticated client cannot update a watermark'
);
select throws_ok(
  $$delete from public.notification_sync_watermarks$$,
  '42501',
  'permission denied for table notification_sync_watermarks',
  'authenticated client cannot delete a watermark'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select is(
  (
    select pg_catalog.count(*)
    from public.notification_sync_watermarks
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
  ),
  0::bigint,
  'another user cannot see the recipient watermark'
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
  (select pg_catalog.count(*) from public.notification_sync_watermarks),
  1::bigint,
  'removed member still receives its self-scoped purge signal'
);
select throws_ok(
  $$select * from public.get_notification_preferences(
    '20000000-0000-4000-8000-000000000101'
  )$$,
  'KNP03',
  'notification household not found or forbidden',
  'authoritative refetch rejects the removed member and triggers client purge'
);

select * from finish();
rollback;
