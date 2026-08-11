begin;
set constraints all deferred;

select plan(45);

-- 1-10: additive schema, v1 compatibility, and least privilege.
select has_column(
  'public',
  'notification_preferences',
  'reminder_lead_minutes',
  'notification preferences persist a Calendar reminder lead'
);
select ok(
  (
    select column_default = '0'
      and is_nullable = 'NO'
      and data_type = 'integer'
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'notification_preferences'
      and column_name = 'reminder_lead_minutes'
  )
    and pg_catalog.pg_get_constraintdef(
      (
        select oid
        from pg_catalog.pg_constraint
        where conname =
          'notification_preferences_reminder_lead_minutes_ck'
      )
    ) like '%0, 5, 10, 15, 30, 60%calendar_event%',
  'lead storage defaults to zero and enforces the exact Calendar-only set'
);
select has_function(
  'app_private',
  'calendar_notification_lead_minutes',
  array['uuid', 'uuid'],
  'private exact-audience lead resolver exists'
);
select has_function(
  'app_private',
  'calendar_notification_reminder_at',
  array['uuid', 'uuid', 'uuid', 'uuid'],
  'private lead-adjusted reminder resolver exists'
);
select has_function(
  'public',
  'get_notification_preferences_v2',
  array['uuid'],
  'v2 preference projection exists'
);
select has_function(
  'public',
  'update_notification_preference_v2',
  array[
    'uuid', 'text', 'boolean', 'boolean', 'boolean', 'boolean',
    'time without time zone', 'time without time zone', 'text', 'integer',
    'bigint'
  ],
  'v2 versioned preference command exists'
);
select is(
  (
    select pg_catalog.string_agg(parameter_name, ',' order by ordinal_position)
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
  'v1 preference response remains the exact 12-field N-1 contract'
);
select is(
  (
    select pg_catalog.string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name = (
        select specific_name
        from information_schema.routines
        where specific_schema = 'public'
          and routine_name = 'get_notification_preferences_v2'
        limit 1
      )
      and parameter_mode = 'OUT'
  ),
  'household_id,category,native_push,web_push,email,in_app,quiet_start,quiet_end,timezone,reminder_lead_minutes,updated_at,version,is_default',
  'v2 preference response has the exact additive 13-field contract'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.get_notification_preferences_v2(uuid)',
    'execute'
  )
    and has_function_privilege(
      'authenticated',
      'public.update_notification_preference_v2(uuid,text,boolean,boolean,boolean,boolean,time without time zone,time without time zone,text,integer,bigint)',
      'execute'
    )
    and not has_function_privilege(
      'anon',
      'public.get_notification_preferences_v2(uuid)',
      'execute'
    )
    and not has_function_privilege(
      'service_role',
      'public.update_notification_preference_v2(uuid,text,boolean,boolean,boolean,boolean,time without time zone,time without time zone,text,integer,bigint)',
      'execute'
    )
    and not has_function_privilege(
      'authenticated',
      'app_private.calendar_notification_lead_minutes(uuid,uuid)',
      'execute'
    ),
  'only authenticated clients execute v2 while private timing helpers stay sealed'
);
select ok(
  (
    select pg_proc.prosecdef
      and pg_proc.provolatile = 's'
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_catalog.pg_proc
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'get_notification_preferences_v2'
  )
    and (
      select pg_proc.prosecdef
        and pg_proc.provolatile = 'v'
        and pg_proc.proconfig @> array['search_path=""']::text[]
      from pg_catalog.pg_proc
      join pg_catalog.pg_namespace
        on pg_namespace.oid = pg_proc.pronamespace
      where pg_namespace.nspname = 'public'
        and pg_proc.proname = 'update_notification_preference_v2'
    )
    and not exists (
      select 1
      from pg_catalog.pg_proc
      join pg_catalog.pg_namespace
        on pg_namespace.oid = pg_proc.pronamespace
      where pg_namespace.nspname = 'app_private'
        and pg_proc.proname in (
          'calendar_notification_lead_minutes',
          'calendar_notification_reminder_at'
        )
        and (
          pg_proc.prosecdef
          or pg_proc.provolatile <> 's'
          or not pg_proc.proconfig @> array['search_path=""']::text[]
        )
    ),
  'v2 APIs and private timing helpers use the intended authority and search path'
);

-- 11-22: auth, validation, optimistic versioning, and N-1 preservation.
set local role authenticated;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$
    select * from public.get_notification_preferences_v2(
      '20000000-0000-4000-8000-000000000101'
    )
  $$,
  'KNP02',
  'authentication required',
  'an authenticated role without a subject cannot read preferences'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select pg_catalog.string_agg(
      pg_catalog.concat_ws(
        ':', category, reminder_lead_minutes, version, is_default
      ),
      ',' order by category
    )
    from public.get_notification_preferences_v2(
      '20000000-0000-4000-8000-000000000101'
    )
  ),
  'calendar_event:0:0:t,chore_assignment:0:0:t,chore_due:0:0:t',
  'v2 projects all three default categories with zero lead'
);
select ok(
  (
    select pg_catalog.bool_and(
      (
        select pg_catalog.count(*)
        from pg_catalog.jsonb_object_keys(to_jsonb(preference))
      ) = 13
      and to_jsonb(preference) ? 'reminder_lead_minutes'
    )
    from public.get_notification_preferences_v2(
      '20000000-0000-4000-8000-000000000101'
    ) as preference
  ),
  'every v2 row serializes to exactly 13 keys including lead time'
);
select throws_ok(
  $$
    select * from public.get_notification_preferences_v2(
      '20000000-0000-4000-8000-000000000201'
    )
  $$,
  'KNP03',
  'notification household not found or forbidden',
  'another household v2 preference projection is denied'
);
select throws_ok(
  $$
    select * from public.update_notification_preference_v2(
      '20000000-0000-4000-8000-000000000101',
      'calendar_event', true, false, false, true,
      null, null, 'Asia/Seoul', 7, 0
    )
  $$,
  'KNP01',
  'invalid notification preference input',
  'an unsupported Calendar lead is rejected'
);
select throws_ok(
  $$
    select * from public.update_notification_preference_v2(
      '20000000-0000-4000-8000-000000000101',
      'chore_due', true, false, false, true,
      null, null, 'Asia/Seoul', 5, 0
    )
  $$,
  'KNP01',
  'invalid notification preference input',
  'non-Calendar categories cannot persist a non-zero lead'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', category, reminder_lead_minutes, version, is_default
    )
    from public.update_notification_preference_v2(
      '20000000-0000-4000-8000-000000000101',
      'calendar_event', true, false, false, true,
      null, null, 'Asia/Seoul', 15, 0
    )
  ),
  'calendar_event:15:1:f',
  'version-zero v2 command materializes a 15-minute Calendar preference'
);
select is(
  (
    select version
    from public.update_notification_preference_v2(
      '20000000-0000-4000-8000-000000000101',
      'calendar_event', true, false, false, true,
      null, null, 'Asia/Seoul', 15, 0
    )
  ),
  1::bigint,
  'an identical v2 response-loss replay is a version-preserving no-op'
);
select throws_ok(
  $$
    select * from public.update_notification_preference_v2(
      '20000000-0000-4000-8000-000000000101',
      'calendar_event', true, false, false, true,
      null, null, 'Asia/Seoul', 30, 0
    )
  $$,
  'KNP06',
  'notification preference version conflict',
  'a stale v2 version cannot overwrite a different lead'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', (
        select pg_catalog.count(*)
        from pg_catalog.jsonb_object_keys(to_jsonb(preference))
      ),
      preference.native_push, preference.version
    )
    from public.update_notification_preference(
      '20000000-0000-4000-8000-000000000101',
      'calendar_event', false, false, false, true,
      null, null, 'Asia/Seoul', 1
    ) as preference
  ),
  '12:f:2',
  'the N-1 update still returns 12 keys and advances one version'
);
reset role;
select is(
  (
    select reminder_lead_minutes
    from public.notification_preferences
    where auth_user_id = '00000000-0000-4000-8000-000000000101'
      and household_id = '20000000-0000-4000-8000-000000000101'
      and category = 'calendar_event'
  ),
  15,
  'an N-1 write preserves the already stored Calendar lead'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
set local role authenticated;
select is(
  (
    select pg_catalog.concat_ws(
      ':', reminder_lead_minutes, quiet_start, quiet_end, version
    )
    from public.update_notification_preference_v2(
      '20000000-0000-4000-8000-000000000101',
      'calendar_event', true, false, false, true,
      time '09:00', time '10:30', 'Asia/Seoul', 30, 0
    )
  ),
  '30:09:00:00:10:30:00:1',
  'a second participant stores an independent lead and quiet window'
);
reset role;

create temporary table calendar_lead_events (
  fixture_label text primary key,
  series_id uuid not null,
  occurrence_id uuid not null,
  local_start_date date not null,
  starts_at timestamptz,
  occurrence_version bigint not null
);
create temporary table calendar_lead_claims (
  event_id uuid primary key,
  lease_token uuid not null,
  attempt integer not null,
  max_attempts integer not null,
  lease_expires_at timestamptz not null
);
create temporary table calendar_lead_results (
  source_event_id uuid primary key,
  outcome text not null,
  notification_category text not null,
  subject_type text not null,
  subject_id uuid not null,
  recipient_member_id uuid,
  recipient_user_id uuid,
  scheduled_at timestamptz,
  timezone text not null,
  suppression_reason text,
  resolved_at timestamptz not null
);
grant all on table calendar_lead_events to authenticated;
grant all on table calendar_lead_claims to service_role;
grant all on table calendar_lead_results to service_role;

-- 23-32: content-free base schedules become exact personal reminder times.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
set local role authenticated;
select lives_ok(
  $$
    insert into calendar_lead_events
    select
      'timed',
      result.series_id,
      result.occurrence_id,
      result.local_start_date,
      result.starts_at,
      result.occurrence_version
    from public.create_one_time_event(
      '5b000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Personal lead timed fixture',
      'Must never enter notification payload',
      false,
      (pg_catalog.statement_timestamp() at time zone 'Asia/Seoul')::date + 1,
      time '10:00',
      60,
      null,
      'Asia/Seoul',
      'earlier',
      array[
        '30000000-0000-4000-8000-000000000101'::uuid,
        '30000000-0000-4000-8000-000000000102'::uuid
      ]
    ) as result
  $$,
  'a timed occurrence with two reminder audiences is created'
);
reset role;
select is(
  (
    select pg_catalog.count(*)
    from app_private.chore_notification_outbox as event
    where event.aggregate_id = (
      select occurrence_id
      from calendar_lead_events
      where fixture_label = 'timed'
    )
  ),
  2::bigint,
  'the timed occurrence emits one source per participant'
);
select ok(
  (
    select pg_catalog.bool_and(
      (event.payload->>'scheduledAt')::timestamptz = fixture.starts_at
      and event.payload ?& array[
        'recipientMemberId', 'localStartDate', 'scheduledAt', 'timezone',
        'status'
      ]
      and event.payload - array[
        'recipientMemberId', 'localStartDate', 'scheduledAt', 'timezone',
        'status'
      ] = '{}'::jsonb
      and event.payload::text !~* 'Personal lead|Must never'
    )
    from app_private.chore_notification_outbox as event
    join calendar_lead_events as fixture
      on fixture.occurrence_id = event.aggregate_id
     and fixture.fixture_label = 'timed'
  ),
  'source payload retains the exact content-free base schedule'
);
select is(
  (
    select pg_catalog.string_agg(
      pg_catalog.concat_ws(
        ':',
        resolved.recipient_member_id,
        (
          extract(epoch from (fixture.starts_at - resolved.due_at)) / 60
        )::integer
      ),
      ',' order by resolved.recipient_member_id
    )
    from app_private.chore_notification_outbox as event
    join calendar_lead_events as fixture
      on fixture.occurrence_id = event.aggregate_id
     and fixture.fixture_label = 'timed'
    cross join lateral app_private.resolve_notification_event(
      event.event_id
    ) as resolved
  ),
  '30000000-0000-4000-8000-000000000101:15,30000000-0000-4000-8000-000000000102:30',
  'the same occurrence resolves an independent lead per audience'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      pg_catalog.to_char(
        resolved.due_at at time zone preference.timezone,
        'HH24:MI'
      ),
      pg_catalog.to_char(
        delivery.delivery_not_before at time zone preference.timezone,
        'HH24:MI'
      ),
      delivery.quiet_applied
    )
    from app_private.chore_notification_outbox as event
    cross join lateral app_private.resolve_notification_event(
      event.event_id
    ) as resolved
    join public.notification_preferences as preference
      on preference.auth_user_id = resolved.recipient_user_id
     and preference.household_id = resolved.household_id
     and preference.category = resolved.notification_category
    cross join lateral app_private.resolve_notification_delivery_not_before(
      resolved.due_at,
      preference.quiet_start,
      preference.quiet_end,
      preference.timezone
    ) as delivery
    where event.aggregate_id = (
      select occurrence_id
      from calendar_lead_events
      where fixture_label = 'timed'
    )
      and resolved.recipient_member_id =
        '30000000-0000-4000-8000-000000000102'
  ),
  '09:30:10:30:t',
  'quiet hours are applied after the 30-minute reminder lead'
);
set local role authenticated;
select lives_ok(
  $$
    insert into calendar_lead_events
    select
      'all_day',
      result.series_id,
      result.occurrence_id,
      result.local_start_date,
      result.starts_at,
      result.occurrence_version
    from public.create_one_time_event(
      '5b000000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      'Personal lead all-day fixture',
      null,
      true,
      (pg_catalog.statement_timestamp() at time zone 'Asia/Seoul')::date + 1,
      null,
      null,
      (pg_catalog.statement_timestamp() at time zone 'Asia/Seoul')::date + 2,
      null,
      null,
      array['30000000-0000-4000-8000-000000000101'::uuid]
    ) as result
  $$,
  'an all-day occurrence with one audience is created'
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      resolved.due_local_date,
      pg_catalog.to_char(
        resolved.due_at at time zone resolved.timezone,
        'HH24:MI'
      ),
      resolved.timezone
    )
    from app_private.chore_notification_outbox as event
    cross join lateral app_private.resolve_notification_event(
      event.event_id
    ) as resolved
    where event.aggregate_id = (
      select occurrence_id
      from calendar_lead_events
      where fixture_label = 'all_day'
    )
  ),
  (
    select pg_catalog.concat_ws(
      ':', local_start_date, '08:45', 'Asia/Seoul'
    )
    from calendar_lead_events
    where fixture_label = 'all_day'
  )::text,
  'all-day date semantics stay intact while 09:00 is shifted by 15 minutes'
);
set local role service_role;
insert into calendar_lead_claims
select *
from public.claim_chore_notification_events(
  '5b000000-0000-4000-8000-000000000101',
  100,
  60,
  pg_catalog.statement_timestamp()
);
reset role;
select is(
  (select pg_catalog.count(*) from calendar_lead_claims),
  3::bigint,
  'the worker leases all three personal reminder source events'
);
set local role service_role;
insert into calendar_lead_results
select result.*
from calendar_lead_claims as claim
cross join lateral public.process_chore_notification_event(
  claim.event_id,
  claim.lease_token,
  pg_catalog.statement_timestamp()
) as result;
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', pg_catalog.count(*),
      pg_catalog.count(*) filter (where outcome = 'candidate'),
      pg_catalog.min(notification_category)
    )
    from calendar_lead_results
  ),
  '3:3:calendar_event',
  'worker resolutions persist three Calendar candidates'
);
select is(
  (
    select pg_catalog.string_agg(
      pg_catalog.concat_ws(
        ':', fixture.fixture_label, resolution.recipient_member_id,
        pg_catalog.to_char(
          resolution.scheduled_at at time zone resolution.timezone,
          'HH24:MI'
        )
      ),
      ',' order by fixture.fixture_label, resolution.recipient_member_id
    )
    from app_private.notification_event_resolutions as resolution
    join calendar_lead_results as result
      on result.source_event_id = resolution.source_event_id
    join calendar_lead_events as fixture
      on fixture.occurrence_id = resolution.subject_id
  ),
  'all_day:30000000-0000-4000-8000-000000000101:08:45,timed:30000000-0000-4000-8000-000000000101:09:45,timed:30000000-0000-4000-8000-000000000102:09:30',
  'durable candidate schedules preserve each personal reminder instant'
);

-- Freeze the all-day inbox history and leave the timed push evaluation pending.
insert into app_private.notification_push_evaluations (
  source_event_id,
  processing_status,
  next_evaluation_at,
  created_at
)
select
  resolution.source_event_id,
  'pending',
  resolution.scheduled_at,
  pg_catalog.statement_timestamp()
from app_private.notification_event_resolutions as resolution
join calendar_lead_events as fixture
  on fixture.occurrence_id = resolution.subject_id
where fixture.fixture_label = 'timed'
  and resolution.recipient_user_id =
    '00000000-0000-4000-8000-000000000101';

insert into app_private.notification_inbox_evaluations (
  source_event_id,
  outcome,
  preference_version,
  reason_code,
  evaluated_at
)
select
  resolution.source_event_id,
  'disabled',
  2,
  'CATEGORY_DISABLED',
  pg_catalog.statement_timestamp()
from app_private.notification_event_resolutions as resolution
join calendar_lead_events as fixture
  on fixture.occurrence_id = resolution.subject_id
where fixture.fixture_label = 'all_day'
  and resolution.recipient_user_id =
    '00000000-0000-4000-8000-000000000101';

-- 33-40: a preference change reschedules pending work but freezes history.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
set local role authenticated;
select is(
  (
    select pg_catalog.concat_ws(':', reminder_lead_minutes, version)
    from public.update_notification_preference_v2(
      '20000000-0000-4000-8000-000000000101',
      'calendar_event', false, false, false, true,
      null, null, 'Asia/Seoul', 60, 2
    )
  ),
  '60:3',
  'changing the lead to 60 minutes advances exactly one version'
);
reset role;
select is(
  (
    select pg_catalog.string_agg(
      pg_catalog.concat_ws(
        ':', fixture.fixture_label, resolution.recipient_member_id,
        pg_catalog.to_char(
          resolution.scheduled_at at time zone resolution.timezone,
          'HH24:MI'
        )
      ),
      ',' order by fixture.fixture_label, resolution.recipient_member_id
    )
    from app_private.notification_event_resolutions as resolution
    join calendar_lead_results as result
      on result.source_event_id = resolution.source_event_id
    join calendar_lead_events as fixture
      on fixture.occurrence_id = resolution.subject_id
  ),
  'all_day:30000000-0000-4000-8000-000000000101:08:45,timed:30000000-0000-4000-8000-000000000101:09:00,timed:30000000-0000-4000-8000-000000000102:09:30',
  'only the unevaluated current-user resolution is rescheduled'
);
select is(
  (
    select pg_catalog.to_char(
      evaluation.next_evaluation_at at time zone resolution.timezone,
      'HH24:MI'
    )
    from app_private.notification_push_evaluations as evaluation
    join app_private.notification_event_resolutions as resolution
      on resolution.source_event_id = evaluation.source_event_id
  ),
  '09:00',
  'a pending push evaluation follows the updated resolution atomically'
);
select is(
  (
    select pg_catalog.string_agg(
      pg_catalog.concat_ws(
        ':', fixture.fixture_label,
        pg_catalog.to_char(
          resolved.due_at at time zone resolved.timezone,
          'HH24:MI'
        )
      ),
      ',' order by fixture.fixture_label
    )
    from app_private.chore_notification_outbox as event
    join calendar_lead_events as fixture
      on fixture.occurrence_id = event.aggregate_id
    cross join lateral app_private.resolve_notification_event(
      event.event_id
    ) as resolved
    where resolved.recipient_user_id =
      '00000000-0000-4000-8000-000000000101'
  ),
  'all_day:08:45,timed:09:00',
  'latest-state resolution uses the new pending time and frozen inbox time'
);

update app_private.notification_push_evaluations
set processing_status = 'materialized',
    next_evaluation_at = null,
    evaluated_at = pg_catalog.statement_timestamp()
where processing_status = 'pending';

set local role authenticated;
select is(
  (
    select pg_catalog.concat_ws(':', reminder_lead_minutes, version)
    from public.update_notification_preference_v2(
      '20000000-0000-4000-8000-000000000101',
      'calendar_event', false, false, false, true,
      null, null, 'Asia/Seoul', 5, 3
    )
  ),
  '5:4',
  'a later preference change is stored after terminal evaluation'
);
reset role;
select is(
  (
    select pg_catalog.string_agg(
      pg_catalog.concat_ws(
        ':', fixture.fixture_label,
        pg_catalog.to_char(
          resolved.due_at at time zone resolved.timezone,
          'HH24:MI'
        )
      ),
      ',' order by fixture.fixture_label
    )
    from app_private.chore_notification_outbox as event
    join calendar_lead_events as fixture
      on fixture.occurrence_id = event.aggregate_id
    cross join lateral app_private.resolve_notification_event(
      event.event_id
    ) as resolved
    where resolved.recipient_user_id =
      '00000000-0000-4000-8000-000000000101'
  ),
  'all_day:08:45,timed:09:00',
  'terminal inbox and push schedules remain immutable after a new lead'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', preference.reminder_lead_minutes,
      pg_catalog.to_char(
        resolution.scheduled_at at time zone resolution.timezone,
        'HH24:MI'
      )
    )
    from public.notification_preferences as preference
    join app_private.notification_event_resolutions as resolution
      on resolution.recipient_user_id = preference.auth_user_id
     and resolution.household_id = preference.household_id
     and resolution.notification_category = preference.category
    join calendar_lead_events as fixture
      on fixture.occurrence_id = resolution.subject_id
     and fixture.fixture_label = 'timed'
    where preference.auth_user_id =
      '00000000-0000-4000-8000-000000000101'
      and preference.category = 'calendar_event'
  ),
  '5:09:00',
  'current preference and frozen delivery history remain intentionally distinct'
);

set local role authenticated;
select lives_ok(
  $$
    insert into calendar_lead_events
    select
      'latest',
      result.series_id,
      result.occurrence_id,
      result.local_start_date,
      result.starts_at,
      result.occurrence_version
    from public.create_one_time_event(
      '5b000000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      'Latest lead fixture',
      null,
      false,
      (pg_catalog.statement_timestamp() at time zone 'Asia/Seoul')::date + 2,
      time '12:00',
      30,
      null,
      'Asia/Seoul',
      'earlier',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    ) as result
  $$,
  'a new occurrence is created after the preference changes'
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      pg_catalog.to_char(
        (event.payload->>'scheduledAt')::timestamptz
          at time zone resolved.timezone,
        'HH24:MI'
      ),
      pg_catalog.to_char(
        resolved.due_at at time zone resolved.timezone,
        'HH24:MI'
      )
    )
    from app_private.chore_notification_outbox as event
    cross join lateral app_private.resolve_notification_event(
      event.event_id
    ) as resolved
    where event.aggregate_id = (
      select occurrence_id
      from calendar_lead_events
      where fixture_label = 'latest'
    )
  ),
  '12:00:11:55',
  'new source payload stays base-timed while resolver uses the latest lead'
);

-- 41-45: N-1 read shape, DB defense, isolation, and privacy close the slice.
set local role authenticated;
select ok(
  (
    select pg_catalog.bool_and(
      (
        select pg_catalog.count(*)
        from pg_catalog.jsonb_object_keys(to_jsonb(preference))
      ) = 12
      and not to_jsonb(preference) ? 'reminder_lead_minutes'
    )
    from public.get_notification_preferences(
      '20000000-0000-4000-8000-000000000101'
    ) as preference
  ),
  'the N-1 preference reader still serializes exact 12-key rows'
);
reset role;
select throws_ok(
  $$
    insert into public.notification_preferences (
      auth_user_id,
      household_id,
      category,
      timezone,
      reminder_lead_minutes
    ) values (
      '00000000-0000-4000-8000-000000000201',
      '20000000-0000-4000-8000-000000000201',
      'chore_due',
      'UTC',
      5
    )
  $$,
  '23514',
  null,
  'the table constraint rejects a non-Calendar non-zero lead'
);
select is(
  app_private.calendar_notification_lead_minutes(
    '20000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000102'
  ),
  30,
  'one participant helper lookup cannot inherit another participant lead'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema in ('public', 'app_private')
      and table_name in (
        'notification_preferences',
        'chore_notification_outbox',
        'notification_event_resolutions',
        'notification_inbox_items',
        'notification_push_evaluations',
        'notification_push_deliveries'
      )
      and column_name in (
        'title', 'description', 'display_name', 'email_address',
        'raw_error', 'error_message', 'provider_body', 'token'
      )
  ),
  'lead-time persistence adds no family content, identity text, token, or raw provider error'
);

select * from finish();
rollback;
