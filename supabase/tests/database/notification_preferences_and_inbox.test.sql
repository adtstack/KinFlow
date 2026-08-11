begin;
set constraints all deferred;

select plan(85);

-- Schema, API shape, and least-privilege boundaries.
select has_table(
  'public',
  'notification_preferences',
  'per-user notification preference table exists'
);
select has_table(
  'public',
  'notification_inbox_items',
  'durable notification inbox table exists'
);
select has_table(
  'app_private',
  'notification_inbox_evaluations',
  'private source-event materialization audit exists'
);
select has_function(
  'app_private',
  'resolve_notification_delivery_not_before',
  array[
    'timestamp with time zone',
    'time without time zone',
    'time without time zone',
    'text'
  ],
  'private quiet-hours resolver exists'
);
select has_function(
  'public',
  'get_notification_preferences',
  array['uuid'],
  'preference projection API exists'
);
select has_function(
  'public',
  'update_notification_preference',
  array[
    'uuid', 'text', 'boolean', 'boolean', 'boolean', 'boolean',
    'time without time zone', 'time without time zone', 'text', 'bigint'
  ],
  'versioned preference command exists'
);
select has_function(
  'public',
  'list_notification_inbox_items',
  array['uuid', 'integer', 'timestamp with time zone', 'uuid'],
  'stable inbox page API exists'
);
select has_function(
  'public',
  'get_notification_unread_count',
  array['uuid'],
  'server-authoritative unread count API exists'
);
select has_function(
  'public',
  'mark_notification_inbox_items_read',
  array['uuid', 'uuid[]'],
  'bounded item read command exists'
);
select has_function(
  'public',
  'mark_all_notification_inbox_read',
  array['uuid', 'timestamp with time zone'],
  'bounded read-all command exists'
);
select has_function(
  'public',
  'materialize_chore_notification_inbox',
  array['integer', 'timestamp with time zone'],
  'service-only inbox materializer exists'
);
select is(
  (
    select string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'notification_preferences'
  ),
  'auth_user_id,household_id,category,native_push,web_push,email,in_app,quiet_start,quiet_end,timezone,updated_at,version,reminder_lead_minutes,additional_reminder_lead_minutes',
  'preference persistence has exact channel, quiet-hour, timezone, version, primary, and additional lead fields'
);
select is(
  (
    select string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'notification_inbox_items'
  ),
  'id,item_version,source_event_id,source_aggregate_version,recipient_user_id,recipient_member_id,household_id,category,subject_type,subject_id,scheduled_at,created_at,updated_at,read_at,cancelled_at,cancellation_reason,payload',
  'inbox persistence is content-free and includes durable read/cancel state'
);
select is(
  (
    select string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'notification_inbox_evaluations'
  ),
  'source_event_id,outcome,inbox_item_id,preference_version,delivery_not_before,quiet_applied,reason_code,evaluated_at',
  'materialization audit stores only outcome, routing reference, timing, and preference version'
);
select is(
  (
    select string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name = (
        select specific_name
        from information_schema.routines
        where specific_schema = 'public'
          and routine_name = 'get_notification_preferences'
        limit 1
      )
      and parameter_mode = 'OUT'
  ),
  'household_id,category,native_push,web_push,email,in_app,quiet_start,quiet_end,timezone,updated_at,version,is_default',
  'preference response shape is exact'
);
select is(
  (
    select string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name = (
        select specific_name
        from information_schema.routines
        where specific_schema = 'public'
          and routine_name = 'list_notification_inbox_items'
        limit 1
      )
      and parameter_mode = 'OUT'
  ),
  'inbox_item_id,item_version,source_event_id,household_id,category,subject_type,subject_id,scheduled_at,created_at,read_at,payload,has_more,next_before_created_at,next_before_id',
  'inbox page exposes only the exact content-free recipient contract'
);
select is(
  (
    select string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name like 'materialize_chore_notification_inbox_%'
      and parameter_mode = 'OUT'
  ),
  'captured_at,claimed_count,created_count,disabled_count,stale_count,suppressed_count,cancelled_count',
  'materializer response is aggregate-only'
);
select ok(
  (
    select c.relrowsecurity and c.relforcerowsecurity
    from pg_class as c
    join pg_namespace as n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'notification_preferences'
  ),
  'notification preferences enable and force RLS'
);
select ok(
  (
    select c.relrowsecurity and c.relforcerowsecurity
    from pg_class as c
    join pg_namespace as n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'notification_inbox_items'
  ),
  'notification inbox enables and forces RLS'
);
select ok(
  not exists (
    select 1
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname in (
        'get_notification_preferences',
        'update_notification_preference',
        'list_notification_inbox_items',
        'get_notification_unread_count',
        'mark_notification_inbox_items_read',
        'mark_all_notification_inbox_read',
        'materialize_chore_notification_inbox'
      )
      and (
        not pg_proc.prosecdef
        or not pg_proc.proconfig @> array['search_path=""']::text[]
      )
  ),
  'every public notification API is security-definer with an empty search path'
);
select ok(
  (
    select pg_proc.provolatile = 's'
      and not pg_proc.prosecdef
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'app_private'
      and pg_proc.proname = 'resolve_notification_delivery_not_before'
  ),
  'quiet-hours resolver is stable, invoker-rights, and private'
);
select has_trigger(
  'public',
  'notification_preferences',
  'notification_preferences_set_updated_at_and_version',
  'preference updates advance server version and timestamp'
);
select has_trigger(
  'public',
  'notification_inbox_items',
  'notification_inbox_items_protect',
  'inbox transition trigger protects immutable routing fields'
);
select has_trigger(
  'app_private',
  'notification_inbox_evaluations',
  'notification_inbox_evaluations_immutable',
  'materialization decisions are immutable'
);
select ok(
  pg_get_indexdef(
    'public.notification_inbox_recipient_page_idx'::regclass
  ) like '%recipient_user_id%household_id%created_at DESC%id DESC%'
    and pg_get_indexdef(
      'public.notification_inbox_recipient_page_idx'::regclass
    ) like '%cancelled_at IS NULL%',
  'recipient page index matches active keyset ordering'
);
select ok(
  pg_get_indexdef(
    'public.notification_inbox_recipient_unread_idx'::regclass
  ) like '%read_at IS NULL%cancelled_at IS NULL%',
  'badge count has an active unread partial index'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.get_notification_preferences(uuid)',
    'execute'
  )
    and has_function_privilege(
      'authenticated',
      'public.update_notification_preference(uuid,text,boolean,boolean,boolean,boolean,time without time zone,time without time zone,text,bigint)',
      'execute'
    )
    and has_function_privilege(
      'authenticated',
      'public.list_notification_inbox_items(uuid,integer,timestamptz,uuid)',
      'execute'
    )
    and has_function_privilege(
      'authenticated',
      'public.get_notification_unread_count(uuid)',
      'execute'
    )
    and has_function_privilege(
      'authenticated',
      'public.mark_notification_inbox_items_read(uuid,uuid[])',
      'execute'
    )
    and has_function_privilege(
      'authenticated',
      'public.mark_all_notification_inbox_read(uuid,timestamptz)',
      'execute'
    ),
  'authenticated clients can execute only the mediated preference and inbox APIs'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.materialize_chore_notification_inbox(integer,timestamptz)',
    'execute'
  )
    and not has_function_privilege(
      'authenticated',
      'public.materialize_chore_notification_inbox(integer,timestamptz)',
      'execute'
    )
    and not has_function_privilege(
      'anon',
      'public.materialize_chore_notification_inbox(integer,timestamptz)',
      'execute'
    ),
  'only service role can execute the inbox materializer'
);
select ok(
  has_table_privilege(
    'authenticated',
    'public.notification_preferences',
    'select'
  )
    and not has_table_privilege(
      'authenticated',
      'public.notification_preferences',
      'insert,update,delete'
    )
    and has_table_privilege(
      'authenticated',
      'public.notification_inbox_items',
      'select'
    )
    and not has_table_privilege(
      'authenticated',
      'public.notification_inbox_items',
      'insert,update,delete'
    ),
  'clients may RLS-select but cannot directly mutate notification state'
);
select ok(
  not has_table_privilege(
    'service_role',
    'app_private.notification_inbox_evaluations',
    'select,insert,update,delete'
  )
    and not has_function_privilege(
      'service_role',
      'app_private.resolve_notification_delivery_not_before(timestamptz,time without time zone,time without time zone,text)',
      'execute'
    ),
  'service role cannot bypass the materializer through private state or helpers'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema in ('public', 'app_private')
      and table_name in (
        'notification_preferences',
        'notification_inbox_items',
        'notification_inbox_evaluations'
      )
      and column_name in (
        'title', 'description', 'display_name', 'email_address',
        'token', 'provider_body', 'raw_error', 'error_message'
      )
  ),
  'notification persistence has no household content, identity text, token, or raw provider error'
);

-- Quiet-hour wall-clock semantics, including DST gaps and overlaps.
select is(
  (
    select concat_ws(
      ':',
      delivery_not_before,
      quiet_applied,
      dst_resolution
    )
    from app_private.resolve_notification_delivery_not_before(
      '2030-01-01 14:30:00+00',
      time '22:00',
      time '07:00',
      'Asia/Seoul'
    )
  ),
  '2030-01-01 22:00:00+00:t:normal',
  'cross-midnight quiet hours defer to 07:00 in the recipient timezone'
);
select is(
  (
    select concat_ws(':', delivery_not_before, quiet_applied, dst_resolution)
    from app_private.resolve_notification_delivery_not_before(
      '2030-01-01 04:00:00+00',
      time '22:00',
      time '07:00',
      'Asia/Seoul'
    )
  ),
  '2030-01-01 04:00:00+00:f:not_applicable',
  'outside quiet hours preserves the original delivery instant'
);
select is(
  (
    select concat_ws(':', delivery_not_before, quiet_applied, dst_resolution)
    from app_private.resolve_notification_delivery_not_before(
      '2026-03-08 09:45:00+00',
      time '01:00',
      time '02:30',
      'America/Los_Angeles'
    )
  ),
  '2026-03-08 10:00:00+00:t:gap_forward',
  'nonexistent quiet end advances to the first valid minute after a DST gap'
);
select is(
  (
    select concat_ws(':', delivery_not_before, quiet_applied, dst_resolution)
    from app_private.resolve_notification_delivery_not_before(
      '2026-11-01 08:15:00+00',
      time '00:30',
      time '01:30',
      'America/Los_Angeles'
    )
  ),
  '2026-11-01 09:30:00+00:t:overlap_later',
  'ambiguous quiet end chooses the later DST-fold instant'
);
select throws_ok(
  $$
    select * from app_private.resolve_notification_delivery_not_before(
      '2030-01-01 00:00:00+00',
      time '22:00',
      time '22:00',
      'Asia/Seoul'
    )
  $$,
  'KNP01',
  'invalid notification preference input',
  'equal quiet start and end is rejected instead of inventing a 24-hour rule'
);

-- Default projection and versioned, response-loss-safe preference update.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
set local role authenticated;
select is(
  (
    select count(*)
    from public.get_notification_preferences(
      '20000000-0000-4000-8000-000000000101'
    )
  ),
  3::bigint,
  'missing rows project all supported categories'
);
select is(
  (
    select string_agg(
      concat_ws(':', category, in_app, native_push, version, is_default),
      ',' order by category
    )
    from public.get_notification_preferences(
      '20000000-0000-4000-8000-000000000101'
    )
  ),
  'calendar_event:t:t:0:t,chore_assignment:t:t:0:t,chore_due:t:t:0:t',
  'default category preferences are explicit and version zero'
);
select is(
  (
    select string_agg(distinct timezone, ',')
    from public.get_notification_preferences(
      '20000000-0000-4000-8000-000000000101'
    )
  ),
  'Asia/Seoul',
  'default preference timezone comes from the authorized household'
);
select throws_ok(
  $$
    select * from public.get_notification_preferences(
      '20000000-0000-4000-8000-000000000201'
    )
  $$,
  'KNP03',
  'notification household not found or forbidden',
  'another household preference projection is denied'
);
select is(
  (
    select concat_ws(
      ':', category, in_app, quiet_start, quiet_end, timezone, version,
      is_default
    )
    from public.update_notification_preference(
      '20000000-0000-4000-8000-000000000101',
      'chore_due',
      true,
      false,
      false,
      true,
      time '08:00',
      time '10:00',
      'Asia/Seoul',
      0
    )
  ),
  'chore_due:t:08:00:00:10:00:00:Asia/Seoul:1:f',
  'version-zero command materializes the first category preference'
);
select is(
  (
    select version
    from public.update_notification_preference(
      '20000000-0000-4000-8000-000000000101',
      'chore_due',
      true,
      false,
      false,
      true,
      time '08:00',
      time '10:00',
      'Asia/Seoul',
      0
    )
  ),
  1::bigint,
  'response-loss replay returns the existing identical preference despite the old version'
);
select throws_ok(
  $$
    select * from public.update_notification_preference(
      '20000000-0000-4000-8000-000000000101',
      'chore_due', true, false, false, false,
      time '08:00', time '10:00', 'Asia/Seoul', 0
    )
  $$,
  'KNP06',
  'notification preference version conflict',
  'a stale version cannot overwrite different preference values'
);
select throws_ok(
  $$
    select * from public.update_notification_preference(
      '20000000-0000-4000-8000-000000000101',
      'chore_due', true, false, false, true,
      time '08:00', null, 'Asia/Seoul', 1
    )
  $$,
  'KNP01',
  'invalid notification preference input',
  'partial quiet hours are rejected'
);
select throws_ok(
  $$
    select * from public.update_notification_preference(
      '20000000-0000-4000-8000-000000000101',
      'chore_due', true, false, false, true,
      null, null, 'Not/A_Real_Zone', 1
    )
  $$,
  'KNP01',
  'invalid notification preference input',
  'unknown timezone identifiers are rejected'
);
select is(
  (select count(*) from public.notification_preferences),
  1::bigint,
  'RLS direct select exposes only the current user preference'
);
reset role;

-- One Chore produces two candidates, then materializes independently of push.
create temporary table inbox_fixtures (
  fixture_label text primary key,
  series_id uuid not null,
  occurrence_id uuid not null,
  occurrence_version bigint not null
);
create temporary table inbox_claims (
  event_id uuid primary key,
  lease_token uuid not null,
  attempt integer not null,
  max_attempts integer not null,
  lease_expires_at timestamptz not null
);
grant all on table inbox_claims to service_role;

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    insert into inbox_fixtures (
      fixture_label,
      series_id,
      occurrence_id,
      occurrence_version
    )
    select 'primary', result.series_id, result.occurrence_id, result.version
    from public.create_one_time_chore(
      '52000000-0000-4000-8000-000000000301',
      '20000000-0000-4000-8000-000000000101',
      'Inbox fixture title',
      'Never copied into notification state',
      '30000000-0000-4000-8000-000000000102',
      '2030-01-02',
      time '09:15'
    ) as result
  $$,
  'one-time chore creation emits candidate source events'
);

set local role service_role;
select lives_ok(
  $$
    insert into inbox_claims
    select *
    from public.claim_chore_notification_events(
      '52000000-0000-4000-8000-000000000001',
      10,
      60,
      pg_catalog.statement_timestamp()
    )
  $$,
  'service worker claims the two source events'
);
select is(
  (select count(*) from inbox_claims),
  2::bigint,
  'due and assignment are independently claimed'
);
select lives_ok(
  $$
    select public.process_chore_notification_event(
      claim.event_id,
      claim.lease_token,
      pg_catalog.statement_timestamp()
    )
    from inbox_claims as claim
  $$,
  'both source events resolve before inbox materialization'
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
  'materializer creates two durable inbox items with no provider dependency'
);
reset role;
select is(
  (
    select string_agg(category, ',' order by category)
    from public.notification_inbox_items
  ),
  'chore_assignment,chore_due',
  'both supported categories are durable'
);
select is(
  (
    select count(*)
    from public.notification_inbox_items as item
    where (
        select count(*)
        from pg_catalog.jsonb_object_keys(item.payload)
      ) = 2
      and item.payload->>'householdId' = item.household_id::text
      and item.payload->>'occurrenceId' = item.subject_id::text
      and item.payload::text not ilike '%Inbox fixture%'
      and item.payload::text not ilike '%Never copied%'
  ),
  2::bigint,
  'inbox payload contains only household and occurrence routing identifiers'
);
select is(
  (
    select concat_ws(
      ':', count(*), count(*) filter (where outcome = 'created'),
      count(distinct source_event_id)
    )
    from app_private.notification_inbox_evaluations
  ),
  '2:2:2',
  'source event materialization is recorded once per resolution'
);
select is(
  (
    select concat_ws(
      ':', evaluation.delivery_not_before, evaluation.quiet_applied,
      evaluation.preference_version
    )
    from app_private.notification_inbox_evaluations as evaluation
    join app_private.notification_event_resolutions as resolution
      on resolution.source_event_id = evaluation.source_event_id
    where resolution.notification_category = 'chore_due'
  ),
  '2030-01-02 01:00:00+00:t:1',
  'recipient quiet hours defer future due delivery without delaying inbox creation'
);
set local role service_role;
select is(
  (
    select concat_ws(':', claimed_count, created_count, cancelled_count)
    from public.materialize_chore_notification_inbox(
      10,
      pg_catalog.statement_timestamp()
    )
  ),
  '0:0:0',
  'materializer response-loss replay performs no duplicate work'
);
reset role;

-- Recipient-only list/read/badge semantics and stable keyset pagination.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
set local role authenticated;
select is(
  public.get_notification_unread_count(
    '20000000-0000-4000-8000-000000000101'
  ),
  0,
  'non-recipient household member has no unread badge'
);
select is(
  (
    select count(*)
    from public.list_notification_inbox_items(
      '20000000-0000-4000-8000-000000000101', 10, null, null
    )
  ),
  0::bigint,
  'non-recipient cannot list another member inbox'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
set local role authenticated;
select is(
  public.get_notification_unread_count(
    '20000000-0000-4000-8000-000000000101'
  ),
  2,
  'recipient badge is the server count of active unread rows'
);
select is(
  (
    select string_agg(category, ',' order by category)
    from public.list_notification_inbox_items(
      '20000000-0000-4000-8000-000000000101', 10, null, null
    )
  ),
  'chore_assignment,chore_due',
  'recipient page returns both active items'
);
select ok(
  (
    select bool_and(
      has_more
      and next_before_created_at is not null
      and next_before_id is not null
    )
    from public.list_notification_inbox_items(
      '20000000-0000-4000-8000-000000000101', 1, null, null
    )
  ),
  'one-row page returns an opaque complete keyset cursor when more rows exist'
);
select is(
  (
    with first_page as (
      select *
      from public.list_notification_inbox_items(
        '20000000-0000-4000-8000-000000000101', 1, null, null
      )
    )
    select count(*)
    from first_page
    cross join lateral public.list_notification_inbox_items(
      '20000000-0000-4000-8000-000000000101',
      1,
      first_page.next_before_created_at,
      first_page.next_before_id
    ) as next_page
    where next_page.inbox_item_id <> first_page.inbox_item_id
      and not next_page.has_more
  ),
  1::bigint,
  'keyset cursor returns the remaining distinct item exactly once'
);
select is(
  (
    select concat_ws(':', marked_count, unread_count)
    from public.mark_notification_inbox_items_read(
      '20000000-0000-4000-8000-000000000101',
      array[(
        select id
        from public.notification_inbox_items
        where cancelled_at is null
        order by id
        limit 1
      )]
    )
  ),
  '1:1',
  'mark-item command advances one item and badge atomically'
);
select is(
  (
    select count(*)
    from public.notification_inbox_items
    where read_at is not null
      and item_version = 2
  ),
  1::bigint,
  'read transition advances the durable item version once'
);
select is(
  (
    select concat_ws(':', marked_count, unread_count)
    from public.mark_notification_inbox_items_read(
      '20000000-0000-4000-8000-000000000101',
      array[(
        select id
        from public.notification_inbox_items
        where read_at is not null
        order by id
        limit 1
      )]
    )
  ),
  '0:1',
  'mark-item response-loss replay does not advance state twice'
);
select is(
  (
    select concat_ws(':', marked_count, unread_count)
    from public.mark_all_notification_inbox_read(
      '20000000-0000-4000-8000-000000000101', null
    )
  ),
  '1:0',
  'read-all marks the remaining snapshot and returns badge zero'
);
select is(
  (
    select concat_ws(':', marked_count, unread_count)
    from public.mark_all_notification_inbox_read(
      '20000000-0000-4000-8000-000000000101', null
    )
  ),
  '0:0',
  'read-all replay is idempotent'
);
reset role;

-- Disabled category, superseding updates, and terminal suppression.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
set local role authenticated;
select is(
  (
    select concat_ws(':', in_app, version)
    from public.update_notification_preference(
      '20000000-0000-4000-8000-000000000101',
      'chore_assignment', true, false, false, false,
      null, null, 'Asia/Seoul', 0
    )
  ),
  'f:1',
  'recipient can disable assignment inbox independently from due reminders'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    insert into inbox_fixtures (
      fixture_label, series_id, occurrence_id, occurrence_version
    )
    select 'disabled', result.series_id, result.occurrence_id, result.version
    from public.create_one_time_chore(
      '52000000-0000-4000-8000-000000000302',
      '20000000-0000-4000-8000-000000000101',
      'Disabled category fixture',
      null,
      '30000000-0000-4000-8000-000000000102',
      '2030-01-04',
      time '09:30'
    ) as result
  $$,
  'second occurrence emits both category events'
);
truncate table inbox_claims;
set local role service_role;
insert into inbox_claims
select *
from public.claim_chore_notification_events(
  '52000000-0000-4000-8000-000000000001',
  10,
  60,
  pg_catalog.statement_timestamp()
);
select lives_ok(
  $$
    select public.process_chore_notification_event(
      claim.event_id,
      claim.lease_token,
      pg_catalog.statement_timestamp()
    )
    from inbox_claims as claim
  $$,
  'second occurrence resolutions succeed'
);
select is(
  (
    select concat_ws(
      ':', claimed_count, created_count, disabled_count, stale_count,
      suppressed_count
    )
    from public.materialize_chore_notification_inbox(
      10,
      pg_catalog.statement_timestamp()
    )
  ),
  '2:1:1:0:0',
  'disabled assignment is audited while enabled due still reaches the inbox'
);
reset role;
select is(
  (
    select count(*)
    from app_private.notification_inbox_evaluations
    where outcome = 'disabled'
      and reason_code = 'CATEGORY_DISABLED'
      and preference_version = 1
  ),
  1::bigint,
  'disabled materialization retains only stable reason and preference version'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    with result as (
      update public.chore_occurrences as occurrence
      set due_local_date = '2030-01-03',
          due_at = '2030-01-03 00:30:00+00'
      from inbox_fixtures as fixture
      where fixture.fixture_label = 'primary'
        and occurrence.household_id =
          '20000000-0000-4000-8000-000000000101'
        and occurrence.id = fixture.occurrence_id
        and occurrence.version = fixture.occurrence_version
      returning occurrence.id as occurrence_id, occurrence.version
    )
    update inbox_fixtures as fixture
    set occurrence_version = result.version
    from result
    where fixture.fixture_label = 'primary'
      and fixture.occurrence_id = result.occurrence_id
  $$,
  'reschedule emits a newer due source event'
);
truncate table inbox_claims;
set local role service_role;
insert into inbox_claims
select *
from public.claim_chore_notification_events(
  '52000000-0000-4000-8000-000000000001',
  10,
  60,
  pg_catalog.statement_timestamp()
);
select is(
  (select count(*) from inbox_claims),
  1::bigint,
  'reschedule produces only one new due event'
);
select lives_ok(
  $$
    select public.process_chore_notification_event(
      claim.event_id,
      claim.lease_token,
      pg_catalog.statement_timestamp()
    )
    from inbox_claims as claim
  $$,
  'new due event resolves successfully'
);
select is(
  (
    select concat_ws(
      ':', claimed_count, created_count, stale_count, suppressed_count,
      cancelled_count
    )
    from public.materialize_chore_notification_inbox(
      10,
      pg_catalog.statement_timestamp()
    )
  ),
  '1:1:0:0:1',
  'newer due item atomically cancels the superseded active item'
);
reset role;
select is(
  (
    select concat_ws(
      ':',
      count(*) filter (where cancelled_at is null),
      count(*) filter (
        where cancelled_at is not null
          and cancellation_reason = 'superseded'
      )
    )
    from public.notification_inbox_items as item
    join inbox_fixtures as fixture on fixture.occurrence_id = item.subject_id
    where fixture.fixture_label = 'primary'
      and item.category = 'chore_due'
  ),
  '1:1',
  'superseded item remains durable but only the latest due item is active'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select lives_ok(
  $$
    with target as (
      select occurrence_id, occurrence_version
      from inbox_fixtures
      where fixture_label = 'primary'
    ), result as (
      select response.*
      from target
      cross join lateral public.set_chore_occurrence_completion(
        '52000000-0000-4000-8000-000000000402',
        '20000000-0000-4000-8000-000000000101',
        target.occurrence_id,
        target.occurrence_version,
        true
      ) as response
    )
    update inbox_fixtures as fixture
    set occurrence_version = result.version
    from result
    where fixture.fixture_label = 'primary'
      and fixture.occurrence_id = result.occurrence_id
  $$,
  'completion emits a latest-state due suppression event'
);
truncate table inbox_claims;
set local role service_role;
insert into inbox_claims
select *
from public.claim_chore_notification_events(
  '52000000-0000-4000-8000-000000000001',
  10,
  60,
  pg_catalog.statement_timestamp()
);
select lives_ok(
  $$
    select public.process_chore_notification_event(
      claim.event_id,
      claim.lease_token,
      pg_catalog.statement_timestamp()
    )
    from inbox_claims as claim
  $$,
  'completed occurrence resolves as source suppression'
);
select is(
  (
    select concat_ws(
      ':', claimed_count, created_count, stale_count, suppressed_count,
      cancelled_count
    )
    from public.materialize_chore_notification_inbox(
      10,
      pg_catalog.statement_timestamp()
    )
  ),
  '1:0:0:1:1',
  'terminal suppression cancels the latest active due item without replacement'
);
reset role;
select is(
  (
    select count(*)
    from public.notification_inbox_items as item
    join inbox_fixtures as fixture on fixture.occurrence_id = item.subject_id
    where fixture.fixture_label = 'primary'
      and item.category = 'chore_due'
      and item.cancelled_at is null
  ),
  0::bigint,
  'completed occurrence has no active due inbox item'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
set local role authenticated;
select is(
  public.get_notification_unread_count(
    '20000000-0000-4000-8000-000000000101'
  ),
  1,
  'badge excludes cancelled rows and includes only the remaining unread due item'
);
select throws_ok(
  $$
    select * from public.mark_notification_inbox_items_read(
      '20000000-0000-4000-8000-000000000101',
      array_fill(
        '52000000-0000-4000-8000-000000000999'::uuid,
        array[101]
      )
    )
  $$,
  'KNP01',
  'invalid notification read command',
  'read command rejects more than one hundred item identifiers'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
set local role authenticated;
select is(
  (select count(*) from public.notification_inbox_items),
  0::bigint,
  'RLS hides every inbox row from an unrelated household'
);
select throws_ok(
  $$
    select public.get_notification_unread_count(
      '20000000-0000-4000-8000-000000000101'
    )
  $$,
  'KNP03',
  'notification household not found or forbidden',
  'mediated badge query also rejects an unrelated household'
);
reset role;

select * from finish();
rollback;
