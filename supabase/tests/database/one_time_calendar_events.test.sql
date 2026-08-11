begin;
set constraints all deferred;

select plan(120);

-- 01-32: schema, contracts, RLS, and least privilege.
select has_table('public', 'event_series', 'event series table exists');
select has_table(
  'public',
  'event_series_revisions',
  'event revision table exists'
);
select has_table(
  'public',
  'event_participants',
  'event participants table exists'
);
select has_table(
  'public',
  'event_occurrences',
  'event occurrences table exists'
);
select has_table(
  'app_private',
  'calendar_command_requests',
  'private calendar idempotency table exists'
);
select has_table(
  'app_private',
  'calendar_audit_events',
  'private calendar audit table exists'
);
select has_function(
  'public',
  'create_one_time_event',
  array[
    'uuid', 'uuid', 'text', 'text', 'boolean', 'date',
    'time without time zone', 'integer', 'date', 'text', 'text', 'uuid[]'
  ],
  'one-time event create RPC exists'
);
select has_function(
  'public',
  'update_one_time_event',
  array[
    'uuid', 'uuid', 'uuid', 'bigint', 'text', 'text', 'boolean', 'date',
    'time without time zone', 'integer', 'date', 'text', 'text', 'uuid[]'
  ],
  'one-time event update RPC exists'
);
select has_function(
  'public',
  'delete_one_time_event',
  array['uuid', 'uuid', 'uuid', 'bigint'],
  'one-time event delete RPC exists'
);
select has_function(
  'public',
  'list_one_time_events',
  array['uuid', 'integer'],
  'one-time event list RPC exists'
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
    where pg_namespace.nspname = 'public'
      and pg_proc.proname in (
        'create_one_time_event',
        'update_one_time_event',
        'delete_one_time_event',
        'list_one_time_events'
      )
  ),
  'all Calendar RPCs are security-definer with an empty search path'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.create_one_time_event(uuid,uuid,text,text,boolean,date,time without time zone,integer,date,text,text,uuid[])',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.update_one_time_event(uuid,uuid,uuid,bigint,text,text,boolean,date,time without time zone,integer,date,text,text,uuid[])',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.delete_one_time_event(uuid,uuid,uuid,bigint)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.list_one_time_events(uuid,integer)',
    'execute'
  ),
  'authenticated clients can execute mediated Calendar RPCs'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.create_one_time_event(uuid,uuid,text,text,boolean,date,time without time zone,integer,date,text,text,uuid[])',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.update_one_time_event(uuid,uuid,uuid,bigint,text,text,boolean,date,time without time zone,integer,date,text,text,uuid[])',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.delete_one_time_event(uuid,uuid,uuid,bigint)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.list_one_time_events(uuid,integer)',
    'execute'
  ),
  'anonymous clients cannot execute Calendar RPCs'
);
select ok(
  has_table_privilege('authenticated', 'public.event_series', 'select')
  and has_table_privilege(
    'authenticated',
    'public.event_series_revisions',
    'select'
  )
  and has_table_privilege(
    'authenticated',
    'public.event_participants',
    'select'
  )
  and has_table_privilege(
    'authenticated',
    'public.event_occurrences',
    'select'
  ),
  'authenticated clients receive read-only Calendar table grants'
);
select ok(
  not has_table_privilege('authenticated', 'public.event_series', 'insert')
  and not has_table_privilege(
    'authenticated',
    'public.event_series',
    'update'
  )
  and not has_table_privilege(
    'authenticated',
    'public.event_series',
    'delete'
  )
  and not has_table_privilege(
    'authenticated',
    'public.event_participants',
    'insert'
  ),
  'authenticated clients cannot bypass Calendar mutation RPCs'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.calendar_command_requests',
    'select'
  )
  and not has_table_privilege(
    'authenticated',
    'app_private.calendar_audit_events',
    'select'
  )
  and not has_table_privilege(
    'service_role',
    'app_private.calendar_command_requests',
    'select'
  )
  and not has_table_privilege(
    'service_role',
    'app_private.calendar_audit_events',
    'select'
  ),
  'API roles cannot inspect Calendar command or audit storage'
);
select ok(
  (
    select pg_catalog.bool_and(pg_class.relrowsecurity)
      and pg_catalog.bool_and(pg_class.relforcerowsecurity)
    from pg_catalog.pg_class
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname in (
        'event_series',
        'event_series_revisions',
        'event_participants',
        'event_occurrences'
      )
  ),
  'all Calendar tables enable and force RLS'
);
select is(
  (
    select pg_catalog.count(*)
    from pg_catalog.pg_policy
    join pg_catalog.pg_class
      on pg_class.oid = pg_policy.polrelid
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname in (
        'event_series',
        'event_series_revisions',
        'event_participants',
        'event_occurrences'
      )
      and pg_policy.polcmd = 'r'
  ),
  4::bigint,
  'each Calendar table has exactly one select policy'
);
select ok(
  (
    select pg_catalog.pg_get_constraintdef(pg_constraint.oid) like
      'FOREIGN KEY (household_id, id, active_revision_id)%'
    from pg_catalog.pg_constraint
    where pg_constraint.conname = 'event_active_revision_fk'
  ),
  'active revision FK binds household and its own series identity'
);
select ok(
  (
    select pg_catalog.pg_get_constraintdef(pg_constraint.oid) like
      'FOREIGN KEY (household_id, series_id, revision_id)%'
    from pg_catalog.pg_constraint
    where pg_constraint.conname = 'event_occurrence_revision_fk'
  ),
  'occurrence revision FK binds the same household and series'
);
select ok(
  (
    select pg_catalog.pg_get_constraintdef(pg_constraint.oid) like
      'FOREIGN KEY (household_id, member_id)%'
    from pg_catalog.pg_constraint
    where pg_constraint.conname = 'event_participant_member_fk'
  ),
  'participant FK enforces same-household member identity'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where pg_constraint.conname = 'event_series_time_mode_ck'
      and pg_constraint.contype = 'c'
  ),
  'series timed/all-day mode check exists'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where pg_constraint.conname = 'event_revision_time_ck'
      and pg_constraint.contype = 'c'
  ),
  'revision local-time shape check exists'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where pg_constraint.conname = 'event_occurrence_time_ck'
      and pg_constraint.contype = 'c'
  ),
  'occurrence canonical-time shape check exists'
);
select ok(
  (
    select pg_proc.provolatile = 'i'
    from pg_catalog.pg_proc
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'app_private'
      and pg_proc.proname = 'is_valid_calendar_dst_adjustment'
  ),
  'DST adjustment validator is immutable'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.is_valid_calendar_dst_adjustment(jsonb)',
    'execute'
  )
  and not has_function_privilege(
    'service_role',
    'app_private.is_valid_calendar_dst_adjustment(jsonb)',
    'execute'
  ),
  'API roles cannot execute the private DST payload validator'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.one_time_event_snapshot(uuid,uuid)',
    'execute'
  )
  and not has_function_privilege(
    'service_role',
    'app_private.one_time_event_snapshot(uuid,uuid)',
    'execute'
  ),
  'API roles cannot execute the private event snapshot helper'
);
select is(
  (
    select pg_catalog.count(*)
    from pg_catalog.pg_trigger
    join pg_catalog.pg_class on pg_class.oid = pg_trigger.tgrelid
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname in ('event_series', 'event_occurrences')
      and pg_trigger.tgname in (
        'event_series_set_updated_at_and_version',
        'event_occurrences_set_updated_at_and_version'
      )
      and not pg_trigger.tgisinternal
  ),
  2::bigint,
  'series and occurrence version triggers are installed'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_trigger
    join pg_catalog.pg_class on pg_class.oid = pg_trigger.tgrelid
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'app_private'
      and pg_class.relname = 'calendar_audit_events'
      and pg_trigger.tgname = 'calendar_audit_events_immutable'
      and not pg_trigger.tgisinternal
  ),
  'Calendar audit immutability trigger is enabled'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'calendar_audit_events'
      and column_name in ('title', 'description', 'display_name')
  ),
  'Calendar audit storage does not duplicate event content or names'
);
select is(
  (
    select pg_catalog.string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'calendar_command_requests'
  ),
  'authenticated_user_id,idempotency_key,command_name,request_hash,household_id,series_id,occurrence_id,created_at',
  'command storage contains only identity hash target IDs and time'
);
select is(
  (
    select pg_catalog.string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'calendar_audit_events'
  ),
  'id,household_id,action,series_id,occurrence_id,actor_user_id,actor_member_id,correlation_id,series_version,occurrence_version,occurred_at',
  'audit storage uses the exact content-free envelope'
);

-- 33-43: authentication, shape validation, DST errors, and injection denial.
select throws_ok(
  $$
    select * from public.create_one_time_event(
      '41000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Unauthenticated event', null, false,
      date '2026-07-14', time '09:00', 60, null,
      'Asia/Seoul', 'earlier',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE01',
  'authentication required',
  'create derives the actor from JWT'
);
select throws_ok(
  $$select * from public.list_one_time_events(
    '20000000-0000-4000-8000-000000000101', 100
  )$$,
  'KFE01',
  'authentication required',
  'list requires authentication'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);

select throws_ok(
  $$
    select * from public.create_one_time_event(
      '41000000-0000-4000-8000-000000000010',
      '20000000-0000-4000-8000-000000000101',
      '   ', null, false, date '2026-07-14', time '09:00', 60, null,
      'Asia/Seoul', 'earlier',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE02',
  'invalid calendar event input',
  'blank title is rejected'
);
select throws_ok(
  $$
    select * from public.create_one_time_event(
      '41000000-0000-4000-8000-000000000011',
      '20000000-0000-4000-8000-000000000101',
      'Duplicate participants', null, false,
      date '2026-07-14', time '09:00', 60, null,
      'Asia/Seoul', 'earlier',
      array[
        '30000000-0000-4000-8000-000000000101'::uuid,
        '30000000-0000-4000-8000-000000000101'::uuid
      ]
    )
  $$,
  'KFE02',
  'invalid calendar event input',
  'duplicate participant IDs are rejected'
);
select throws_ok(
  $$
    select * from public.create_one_time_event(
      '41000000-0000-4000-8000-000000000012',
      '20000000-0000-4000-8000-000000000101',
      'No participants', null, true,
      date '2026-07-14', null, null, date '2026-07-15',
      null, null, array[]::uuid[]
    )
  $$,
  'KFE02',
  'invalid calendar event input',
  'at least one participant is required'
);
select throws_ok(
  $$
    select * from public.create_one_time_event(
      '41000000-0000-4000-8000-000000000013',
      '20000000-0000-4000-8000-000000000101',
      'Polluted all day', null, true,
      date '2026-07-14', null, null, date '2026-07-15',
      'Asia/Seoul', null,
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE02',
  'invalid calendar event input',
  'all-day input cannot carry a timezone'
);
select throws_ok(
  $$
    select * from public.create_one_time_event(
      '41000000-0000-4000-8000-000000000014',
      '20000000-0000-4000-8000-000000000101',
      'Missing duration', null, false,
      date '2026-07-14', time '09:00', null, null,
      'Asia/Seoul', 'earlier',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE02',
  'invalid calendar event input',
  'timed input requires a positive duration'
);
select throws_ok(
  $$
    select * from public.create_one_time_event(
      '41000000-0000-4000-8000-000000000015',
      '20000000-0000-4000-8000-000000000101',
      'Second precision', null, false,
      date '2026-07-14', time '09:00:01', 60, null,
      'Asia/Seoul', 'earlier',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE02',
  'invalid calendar event input',
  'timed input remains minute precision'
);
select throws_ok(
  $$
    select * from public.create_one_time_event(
      '41000000-0000-4000-8000-000000000016',
      '20000000-0000-4000-8000-000000000101',
      'Spring gap', null, false,
      date '2026-03-08', time '02:30', 60, null,
      'America/Los_Angeles', 'earlier',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE06',
  'nonexistent calendar local time',
  'private DST gap maps to a stable public error'
);
select throws_ok(
  $$
    select * from public.create_one_time_event(
      '41000000-0000-4000-8000-000000000017',
      '20000000-0000-4000-8000-000000000101',
      'Unknown zone', null, false,
      date '2026-07-14', time '09:00', 60, null,
      'America/Not_A_Zone', 'earlier',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE02',
  'invalid calendar event input',
  'unknown timezone maps to invalid public input'
);
select throws_ok(
  $$
    select * from public.create_one_time_event(
      '41000000-0000-4000-8000-000000000018',
      '20000000-0000-4000-8000-000000000101',
      'Injected participant', null, false,
      date '2026-07-14', time '09:00', 60, null,
      'Asia/Seoul', 'earlier',
      array['30000000-0000-4000-8000-000000000201'::uuid]
    )
  $$,
  'KFE03',
  'calendar event not found or forbidden',
  'another household participant cannot be injected'
);

-- 44-61: timed creation, exact resolution, list envelope, and idempotency.
select lives_ok(
  $$
    select * from public.create_one_time_event(
      '41000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      '  Doctor visit  ', '  Bring documents  ', false,
      date '2026-07-14', time '09:00', 90, null,
      'Asia/Seoul', 'earlier',
      array[
        '30000000-0000-4000-8000-000000000102'::uuid,
        '30000000-0000-4000-8000-000000000101'::uuid
      ]
    )
  $$,
  'an active adult can create a timed event'
);
reset role;
select is(
  (select count(*) from public.event_series)
    + (select count(*) from public.event_series_revisions)
    + (select count(*) from public.event_occurrences),
  3::bigint,
  'timed create persists one series revision and occurrence'
);
select is(
  (select count(*) from public.event_participants),
  2::bigint,
  'timed create persists the exact participant set'
);
select ok(
  exists (
    select 1
    from public.event_series as series
    join public.event_series_revisions as revision
      on revision.household_id = series.household_id
     and revision.series_id = series.id
     and revision.id = series.active_revision_id
    join public.event_occurrences as occurrence
      on occurrence.household_id = series.household_id
     and occurrence.series_id = series.id
     and occurrence.revision_id = revision.id
    where occurrence.occurrence_key = series.id::text || ':once'
      and revision.recurrence_rule is null
  ),
  'one-time series revision and occurrence identities are separate and linked'
);
select ok(
  exists (
    select 1
    from public.event_series
    where title = 'Doctor visit'
      and description = 'Bring documents'
  ),
  'event content is normalized once at the aggregate boundary'
);
select is(
  (
    select pg_catalog.to_char(
      occurrence.starts_at at time zone 'UTC',
      'YYYY-MM-DD"T"HH24:MI:SS"Z"'
    )
    from public.event_occurrences as occurrence
  ),
  '2026-07-14T00:00:00Z',
  'Seoul local start is stored as the exact server-resolved UTC instant'
);
select is(
  (
    select extract(epoch from occurrence.ends_at - occurrence.starts_at)::integer
    from public.event_occurrences as occurrence
  ),
  5400,
  'timed duration produces a strictly later canonical end instant'
);
select is(
  (
    select occurrence.dst_adjustment
    from public.event_occurrences as occurrence
  ),
  '{"candidateCount":1,"gapPolicy":"reject","overlapPolicy":"earlier","resolution":"normal","utcOffsetSeconds":32400}'::jsonb,
  'timed occurrence stores the exact DST resolution metadata'
);
select ok(
  exists (
    select 1
    from public.event_series as series
    join public.event_occurrences as occurrence
      on occurrence.household_id = series.household_id
     and occurrence.series_id = series.id
    where not series.is_all_day
      and series.timezone = 'Asia/Seoul'
      and occurrence.timezone = 'Asia/Seoul'
      and occurrence.all_day_end_date_exclusive is null
  ),
  'timed rows carry a pinned IANA timezone and no all-day end'
);
select is(
  (
    select count(*)
    from app_private.calendar_audit_events
    where action = 'calendar.created'
  ),
  1::bigint,
  'create records one content-free audit event'
);
select is(
  (select count(*) from app_private.calendar_command_requests),
  1::bigint,
  'create records one private idempotency result'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      pg_catalog.array_to_string(snapshot.participant_member_ids, ','),
      pg_catalog.array_to_string(snapshot.participant_display_names, ',')
    )
    from app_private.one_time_event_snapshot(
      '20000000-0000-4000-8000-000000000101',
      (select id from public.event_series where title = 'Doctor visit')
    ) as snapshot
  ),
  '30000000-0000-4000-8000-000000000101,30000000-0000-4000-8000-000000000102:Adult A,Adult B',
  'snapshot returns participant IDs and names in one deterministic order'
);
select set_config(
  'kinflow_test.timed_series_id',
  (select id::text from public.event_series where title = 'Doctor visit'),
  true
);
select set_config(
  'kinflow_test.timed_occurrence_id',
  (
    select id::text
    from public.event_occurrences
    where series_id = current_setting('kinflow_test.timed_series_id')::uuid
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
      '41000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Doctor visit', 'Bring documents', false,
      date '2026-07-14', time '09:00', 90, null,
      'Asia/Seoul', 'earlier',
      array[
        '30000000-0000-4000-8000-000000000102'::uuid,
        '30000000-0000-4000-8000-000000000101'::uuid
      ]
    ) as result
  ),
  false,
  'same-key same-input create replay returns the existing target'
);
reset role;
select is(
  (select count(*) from public.event_series)
    + (select count(*) from public.event_series_revisions)
    + (select count(*) from public.event_occurrences),
  3::bigint,
  'create replay adds no duplicate aggregate rows'
);
select is(
  (select count(*) from app_private.calendar_audit_events),
  1::bigint,
  'create replay adds no duplicate audit event'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.create_one_time_event(
      '41000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Changed replay', 'Bring documents', false,
      date '2026-07-14', time '09:00', 90, null,
      'Asia/Seoul', 'earlier',
      array[
        '30000000-0000-4000-8000-000000000101'::uuid,
        '30000000-0000-4000-8000-000000000102'::uuid
      ]
    )
  $$,
  'KFE04',
  'idempotency key reused with different calendar input',
  'same key with different create input is rejected'
);
select is(
  (
    select count(*)
    from public.list_one_time_events(
      '20000000-0000-4000-8000-000000000101',
      100
    ) as item
    where item.series_id is not null
      and item.title = 'Doctor visit'
      and item.starts_at = '2026-07-14T00:00:00Z'::timestamptz
  ),
  1::bigint,
  'list returns the authoritative timed event snapshot'
);
select ok(
  not exists (
    select 1
    from public.list_one_time_events(
      '20000000-0000-4000-8000-000000000101',
      100
    ) as item
    where item.household_timezone <> 'Asia/Seoul'
      or item.household_local_date < date '2026-01-01'
  ),
  'list envelope uses server household timezone metadata'
);

-- 62-71: date-only all-day creation and empty-envelope behavior.
select lives_ok(
  $$
    select * from public.create_one_time_event(
      '41000000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      'Family trip', null, true,
      date '2026-07-10', null, null, date '2026-07-12',
      null, null,
      array['30000000-0000-4000-8000-000000000102'::uuid]
    )
  $$,
  'an active adult can create a date-only all-day event'
);
reset role;
select is(
  (select count(*) from public.event_series)
    + (select count(*) from public.event_series_revisions)
    + (select count(*) from public.event_occurrences),
  6::bigint,
  'all-day create adds one series revision and occurrence'
);
select ok(
  exists (
    select 1
    from public.event_series as series
    join public.event_occurrences as occurrence
      on occurrence.household_id = series.household_id
     and occurrence.series_id = series.id
    where series.title = 'Family trip'
      and series.is_all_day
      and series.timezone is null
      and occurrence.starts_at is null
      and occurrence.ends_at is null
      and occurrence.timezone is null
      and occurrence.dst_adjustment is null
  ),
  'all-day persistence contains no timezone instant or DST metadata'
);
select ok(
  exists (
    select 1
    from public.event_series_revisions as revision
    join public.event_series as series
      on series.household_id = revision.household_id
     and series.id = revision.series_id
    where series.title = 'Family trip'
      and revision.local_start_time is null
      and revision.duration_minutes is null
      and revision.gap_policy is null
      and revision.overlap_policy is null
  ),
  'all-day revision contains only date semantics'
);
select is(
  (
    select occurrence.all_day_end_date_exclusive
      - occurrence.local_start_date
    from public.event_occurrences as occurrence
    join public.event_series as series
      on series.household_id = occurrence.household_id
     and series.id = occurrence.series_id
    where series.title = 'Family trip'
  ),
  2,
  'all-day end is exclusive and later than start'
);
select is(
  (
    select pg_catalog.array_to_string(
      snapshot.participant_member_ids,
      ','
    )
    from app_private.one_time_event_snapshot(
      '20000000-0000-4000-8000-000000000101',
      (select id from public.event_series where title = 'Family trip')
    ) as snapshot
  ),
  '30000000-0000-4000-8000-000000000102',
  'all-day event retains its exact participant set'
);
select is(
  (
    select count(*)
    from app_private.calendar_audit_events
    where action = 'calendar.created'
  ),
  2::bigint,
  'each successful create has one audit event'
);
select set_config(
  'kinflow_test.all_day_series_id',
  (select id::text from public.event_series where title = 'Family trip'),
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
    select pg_catalog.string_agg(item.title, ',' order by item.local_start_date)
    from public.list_one_time_events(
      '20000000-0000-4000-8000-000000000101',
      100
    ) as item
    where item.series_id is not null
  ),
  'Family trip,Doctor visit',
  'list order is deterministic across all-day and timed events'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select ok(
  exists (
    select 1
    from public.list_one_time_events(
      '20000000-0000-4000-8000-000000000201',
      100
    ) as item
    where item.household_timezone = 'UTC'
      and item.series_id is null
  ),
  'an empty household receives context without a synthetic event'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);

-- 72-91: immutable revision edits, participant replacement, fold policy, and stale protection.
select is(
  (
    select result.changed
    from public.update_one_time_event(
      '41000000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow_test.timed_series_id')::uuid,
      1,
      'Doctor all day', null, true,
      date '2026-07-15', null, null, date '2026-07-16',
      null, null,
      array['30000000-0000-4000-8000-000000000101'::uuid]
    ) as result
  ),
  true,
  'timed event can be edited into an all-day event'
);
reset role;
select ok(
  exists (
    select 1
    from public.event_series as series
    join public.event_occurrences as occurrence
      on occurrence.household_id = series.household_id
     and occurrence.series_id = series.id
    where series.id = current_setting('kinflow_test.timed_series_id')::uuid
      and occurrence.id =
        current_setting('kinflow_test.timed_occurrence_id')::uuid
      and series.version = 2
      and occurrence.version = 2
  ),
  'edit preserves IDs and advances both optimistic versions'
);
select ok(
  (
    select count(*) = 2
      and max(revision.revision_number) = 2
      and pg_catalog.bool_or(
        revision.revision_number = 2
        and revision.id = series.active_revision_id
      )
    from public.event_series_revisions as revision
    join public.event_series as series
      on series.household_id = revision.household_id
     and series.id = revision.series_id
    where series.id = current_setting('kinflow_test.timed_series_id')::uuid
    group by series.active_revision_id
  ),
  'edit appends revision two and activates it'
);
select ok(
  exists (
    select 1
    from public.event_series_revisions as revision
    where revision.series_id =
        current_setting('kinflow_test.timed_series_id')::uuid
      and revision.revision_number = 1
      and revision.local_start_date = date '2026-07-14'
      and revision.local_start_time = time '09:00'
      and revision.duration_minutes = 90
  ),
  'previous revision remains immutable after edit'
);
select ok(
  exists (
    select 1
    from public.event_series
    where id = current_setting('kinflow_test.timed_series_id')::uuid
      and title = 'Doctor all day'
      and is_all_day
      and timezone is null
  ),
  'aggregate switches to all-day mode without a timezone'
);
select ok(
  exists (
    select 1
    from public.event_occurrences
    where id = current_setting('kinflow_test.timed_occurrence_id')::uuid
      and local_start_date = date '2026-07-15'
      and all_day_end_date_exclusive = date '2026-07-16'
      and starts_at is null
      and ends_at is null
      and dst_adjustment is null
  ),
  'occurrence switches to exact date-only fields'
);
select is(
  (
    select pg_catalog.array_to_string(
      pg_catalog.array_agg(member_id order by member_id),
      ','
    )
    from public.event_participants
    where series_id = current_setting('kinflow_test.timed_series_id')::uuid
  ),
  '30000000-0000-4000-8000-000000000101',
  'edit atomically replaces the participant set'
);
select is(
  (
    select count(*)
    from app_private.calendar_audit_events
    where action = 'calendar.updated'
  ),
  1::bigint,
  'edit records one content-free audit event'
);
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
      '41000000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow_test.timed_series_id')::uuid,
      1,
      'Doctor all day', null, true,
      date '2026-07-15', null, null, date '2026-07-16',
      null, null,
      array['30000000-0000-4000-8000-000000000101'::uuid]
    ) as result
  ),
  false,
  'same edit replay returns success without another mutation'
);
reset role;
select ok(
  (
    select count(*) = 2
    from public.event_series_revisions
    where series_id = current_setting('kinflow_test.timed_series_id')::uuid
  )
  and (
    select count(*) = 1
    from app_private.calendar_audit_events
    where action = 'calendar.updated'
  ),
  'edit replay adds neither a revision nor an audit event'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.update_one_time_event(
      '41000000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow_test.timed_series_id')::uuid,
      1,
      'Changed edit replay', null, true,
      date '2026-07-15', null, null, date '2026-07-16',
      null, null,
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE04',
  'idempotency key reused with different calendar input',
  'same update key with changed input is rejected'
);
select throws_ok(
  $$
    select * from public.update_one_time_event(
      '41000000-0000-4000-8000-000000000019',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow_test.timed_series_id')::uuid,
      1,
      'Stale update', null, true,
      date '2026-07-15', null, null, date '2026-07-16',
      null, null,
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE05',
  'stale calendar event version',
  'different stale update cannot overwrite revision two'
);
select is(
  (
    select result.changed
    from public.update_one_time_event(
      '41000000-0000-4000-8000-000000000004',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow_test.timed_series_id')::uuid,
      2,
      'Doctor evening', 'Fold choice', false,
      date '2026-11-01', time '01:30', 60, null,
      'America/Los_Angeles', 'later',
      array[
        '30000000-0000-4000-8000-000000000101'::uuid,
        '30000000-0000-4000-8000-000000000102'::uuid
      ]
    ) as result
  ),
  true,
  'all-day event can be edited back to timed with explicit later fold'
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      pg_catalog.to_char(
        occurrence.starts_at at time zone 'UTC',
        'YYYY-MM-DD"T"HH24:MI:SS"Z"'
      ),
      pg_catalog.to_char(
        occurrence.ends_at at time zone 'UTC',
        'YYYY-MM-DD"T"HH24:MI:SS"Z"'
      ),
      occurrence.dst_adjustment->>'utcOffsetSeconds',
      occurrence.dst_adjustment->>'resolution'
    )
    from public.event_occurrences as occurrence
    where occurrence.id =
      current_setting('kinflow_test.timed_occurrence_id')::uuid
  ),
  '2026-11-01T09:30:00Z:2026-11-01T10:30:00Z:-28800:overlap_later',
  'later fold selection and duration survive persistence exactly'
);
select ok(
  exists (
    select 1
    from public.event_series as series
    join public.event_occurrences as occurrence
      on occurrence.household_id = series.household_id
     and occurrence.series_id = series.id
    where series.id = current_setting('kinflow_test.timed_series_id')::uuid
      and series.version = 3
      and occurrence.version = 3
  ),
  'second edit advances aggregate and occurrence to version three'
);
select is(
  (
    select count(*)
    from public.event_series_revisions
    where series_id = current_setting('kinflow_test.timed_series_id')::uuid
  ),
  3::bigint,
  'second edit appends revision three'
);
select is(
  (
    select count(*)
    from public.event_participants
    where series_id = current_setting('kinflow_test.timed_series_id')::uuid
  ),
  2::bigint,
  'second edit restores two exact participants'
);
select is(
  (
    select count(*)
    from app_private.calendar_audit_events
    where action = 'calendar.updated'
  ),
  2::bigint,
  'each effective edit has one audit event'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.update_one_time_event(
      '41000000-0000-4000-8000-000000000005',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow_test.timed_series_id')::uuid,
      3,
      'Invalid gap edit', null, false,
      date '2026-03-08', time '02:30', 60, null,
      'America/Los_Angeles', 'earlier',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE06',
  'nonexistent calendar local time',
  'gap edit fails before mutating the event'
);
reset role;
select ok(
  (
    select version = 3
    from public.event_series
    where id = current_setting('kinflow_test.timed_series_id')::uuid
  )
  and (
    select count(*) = 3
    from public.event_series_revisions
    where series_id = current_setting('kinflow_test.timed_series_id')::uuid
  ),
  'failed gap edit leaves versions and revisions unchanged'
);

-- 92-102: versioned soft delete, replay, and list suppression.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.delete_one_time_event(
      '41000000-0000-4000-8000-000000000007',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow_test.timed_series_id')::uuid,
      2
    )
  $$,
  'KFE05',
  'stale calendar event version',
  'stale delete cannot remove a newer event'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      result.deleted,
      result.changed,
      result.version,
      result.occurrence_version
    )
    from public.delete_one_time_event(
      '41000000-0000-4000-8000-000000000006',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow_test.timed_series_id')::uuid,
      3
    ) as result
  ),
  't:t:4:4',
  'current delete soft-deletes and advances both versions'
);
reset role;
select ok(
  exists (
    select 1
    from public.event_series as series
    join public.event_occurrences as occurrence
      on occurrence.household_id = series.household_id
     and occurrence.series_id = series.id
    where series.id = current_setting('kinflow_test.timed_series_id')::uuid
      and series.deleted_at is not null
      and series.version = 4
      and occurrence.status = 'cancelled'
      and occurrence.version = 4
  ),
  'delete persists a soft-deleted series and cancelled occurrence'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select pg_catalog.string_agg(item.title, ',')
    from public.list_one_time_events(
      '20000000-0000-4000-8000-000000000101',
      100
    ) as item
    where item.series_id is not null
  ),
  'Family trip',
  'list suppresses a soft-deleted event'
);
reset role;
select is(
  (
    select count(*)
    from public.event_participants
    where series_id = current_setting('kinflow_test.timed_series_id')::uuid
  ),
  2::bigint,
  'soft delete preserves participant history'
);
select is(
  (
    select count(*)
    from app_private.calendar_audit_events
    where action = 'calendar.deleted'
  ),
  1::bigint,
  'delete records one content-free audit event'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select result.changed
    from public.delete_one_time_event(
      '41000000-0000-4000-8000-000000000006',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow_test.timed_series_id')::uuid,
      3
    ) as result
  ),
  false,
  'same delete replay reports no additional mutation'
);
reset role;
select is(
  (
    select count(*)
    from app_private.calendar_audit_events
    where action = 'calendar.deleted'
  ),
  1::bigint,
  'delete replay adds no duplicate audit event'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.delete_one_time_event(
      '41000000-0000-4000-8000-000000000006',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow_test.timed_series_id')::uuid,
      4
    )
  $$,
  'KFE04',
  'idempotency key reused with different calendar input',
  'same delete key with changed expected version is rejected'
);
select throws_ok(
  $$
    select * from public.create_one_time_event(
      '41000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Doctor visit', 'Bring documents', false,
      date '2026-07-14', time '09:00', 90, null,
      'Asia/Seoul', 'earlier',
      array[
        '30000000-0000-4000-8000-000000000102'::uuid,
        '30000000-0000-4000-8000-000000000101'::uuid
      ]
    )
  $$,
  'KFE03',
  'calendar event not found or forbidden',
  'create replay cannot surface an event deleted by a later command'
);
select throws_ok(
  $$
    select * from public.update_one_time_event(
      '41000000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow_test.timed_series_id')::uuid,
      1,
      'Doctor all day', null, true,
      date '2026-07-15', null, null, date '2026-07-16',
      null, null,
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE03',
  'calendar event not found or forbidden',
  'update replay cannot surface an event deleted by a later command'
);

-- 103-115: household isolation, direct-write denial, and removed-member handling.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$select * from public.list_one_time_events(
    '20000000-0000-4000-8000-000000000101', 100
  )$$,
  'KFE03',
  'calendar event not found or forbidden',
  'outsider cannot list another household Calendar'
);
select is(
  (
    select count(*)
    from public.event_series
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  0::bigint,
  'RLS hides another household event series'
);
select is(
  (select count(*) from public.event_series_revisions),
  0::bigint,
  'RLS hides another household event revisions'
);
select is(
  (select count(*) from public.event_participants),
  0::bigint,
  'RLS hides another household event participants'
);
select is(
  (select count(*) from public.event_occurrences),
  0::bigint,
  'RLS hides another household event occurrences'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (select count(*) from public.event_series),
  1::bigint,
  'same-household RLS exposes only the non-deleted event'
);
select throws_ok(
  $$
    insert into public.event_series (
      household_id,
      title,
      timezone,
      is_all_day,
      active_revision_id
    ) values (
      '20000000-0000-4000-8000-000000000101',
      'Direct bypass',
      null,
      true,
      '51000000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'permission denied for table event_series',
  'authenticated client cannot directly insert an event'
);
select throws_ok(
  $$update public.event_series set title = 'Direct update'$$,
  '42501',
  'permission denied for table event_series',
  'authenticated client cannot directly update an event'
);
select throws_ok(
  $$select * from app_private.calendar_command_requests$$,
  '42501',
  'permission denied for table calendar_command_requests',
  'authenticated client cannot inspect private command hashes'
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
select throws_ok(
  $$select * from public.list_one_time_events(
    '20000000-0000-4000-8000-000000000101', 100
  )$$,
  'KFE03',
  'calendar event not found or forbidden',
  'removed adult immediately loses Calendar RPC access'
);
select is(
  (select count(*) from public.event_series),
  0::bigint,
  'removed adult loses all Calendar table visibility'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.create_one_time_event(
      '41000000-0000-4000-8000-000000000008',
      '20000000-0000-4000-8000-000000000101',
      'Removed participant', null, true,
      date '2026-08-01', null, null, date '2026-08-02',
      null, null,
      array['30000000-0000-4000-8000-000000000102'::uuid]
    )
  $$,
  'KFE03',
  'calendar event not found or forbidden',
  'removed member cannot be selected for a new event'
);
select throws_ok(
  $$
    select * from public.update_one_time_event(
      '41000000-0000-4000-8000-000000000009',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow_test.all_day_series_id')::uuid,
      1,
      'Family trip', null, true,
      date '2026-07-10', null, null, date '2026-07-12',
      null, null,
      array['30000000-0000-4000-8000-000000000102'::uuid]
    )
  $$,
  'KFE03',
  'calendar event not found or forbidden',
  'removed member cannot be retained by an explicit edit request'
);

-- 116-120: append-only audit, exact DST payload, and composite FK injection.
reset role;
select throws_ok(
  $$update app_private.calendar_audit_events set series_version = 99$$,
  '55000',
  'calendar audit events are immutable',
  'Calendar audit rows cannot be updated'
);
select throws_ok(
  $$delete from app_private.calendar_audit_events$$,
  '55000',
  'calendar audit events are immutable',
  'Calendar audit rows cannot be deleted'
);
select ok(
  app_private.is_valid_calendar_dst_adjustment(
    '{"candidateCount":1,"gapPolicy":"reject","overlapPolicy":"earlier","resolution":"normal","utcOffsetSeconds":0}'::jsonb
  ),
  'exact normal DST adjustment is valid'
);
select ok(
  not app_private.is_valid_calendar_dst_adjustment(
    '{"candidateCount":1,"gapPolicy":"reject","overlapPolicy":"earlier","resolution":"normal","utcOffsetSeconds":0,"extra":true}'::jsonb
  ),
  'additional DST adjustment keys fail closed'
);
select throws_ok(
  format(
    'insert into public.event_participants '
      || '(household_id,series_id,member_id) values (%L,%L,%L)',
    '20000000-0000-4000-8000-000000000101',
    current_setting('kinflow_test.all_day_series_id'),
    '30000000-0000-4000-8000-000000000201'
  ),
  '23503',
  null,
  'composite FK rejects another household participant even for a trusted writer'
);
select is(
  (select count(*) from app_private.calendar_command_requests),
  5::bigint,
  'only five effective create update and delete commands are retained'
);

select * from finish();
rollback;
