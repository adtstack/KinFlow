begin;
set constraints all deferred;

select plan(50);

-- 1-11: additive storage, exact versioned contracts, and least privilege.
select has_column(
  'public',
  'notification_preferences',
  'additional_reminder_lead_minutes',
  'notification preferences persist additional Calendar reminder leads'
);
select ok(
  (
    select column_default = '''{}''::integer[]'
      and is_nullable = 'NO'
      and data_type = 'ARRAY'
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'notification_preferences'
      and column_name = 'additional_reminder_lead_minutes'
  )
    and pg_catalog.pg_get_constraintdef(
      (
        select oid
        from pg_catalog.pg_constraint
        where conname =
          'notification_preferences_additional_reminder_leads_ck'
      )
    ) like '%is_valid_notification_additional_reminder_leads%',
  'additional lead storage is non-null, empty by default, and constrained'
);
select has_column(
  'app_private',
  'chore_notification_outbox',
  'reminder_lead_minutes',
  'content-free Calendar sources have an internal reminder identity'
);
select ok(
  pg_catalog.pg_get_constraintdef(
    (
      select oid
      from pg_catalog.pg_constraint
      where conname = 'notification_source_event_audience_key'
    )
  ) like '%reminder_lead_minutes%',
  'source uniqueness includes the internal reminder identity'
);
select has_function(
  'public',
  'get_notification_preferences_v3',
  array['uuid'],
  'v3 preference projection exists'
);
select has_function(
  'public',
  'update_notification_preference_v3',
  array[
    'uuid', 'text', 'boolean', 'boolean', 'boolean', 'boolean',
    'time without time zone', 'time without time zone', 'text', 'integer',
    'integer[]', 'bigint'
  ],
  'v3 multiple-reminder command exists'
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
  'v1 preference response remains the exact 12-field contract'
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
  'v2 preference response remains the exact 13-field contract'
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
          and routine_name = 'get_notification_preferences_v3'
        limit 1
      )
      and parameter_mode = 'OUT'
  ),
  'household_id,category,native_push,web_push,email,in_app,quiet_start,quiet_end,timezone,reminder_lead_minutes,additional_reminder_lead_minutes,updated_at,version,is_default',
  'v3 preference response has the exact additive 14-field contract'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.get_notification_preferences_v3(uuid)',
    'execute'
  )
    and has_function_privilege(
      'authenticated',
      'public.update_notification_preference_v3(uuid,text,boolean,boolean,boolean,boolean,time without time zone,time without time zone,text,integer,integer[],bigint)',
      'execute'
    )
    and not has_function_privilege(
      'anon',
      'public.get_notification_preferences_v3(uuid)',
      'execute'
    )
    and not has_function_privilege(
      'service_role',
      'public.update_notification_preference_v3(uuid,text,boolean,boolean,boolean,boolean,time without time zone,time without time zone,text,integer,integer[],bigint)',
      'execute'
    ),
  'only authenticated callers execute the v3 preference surface'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.calendar_notification_additional_lead_is_selected(uuid,uuid,integer)',
    'execute'
  )
    and not has_function_privilege(
      'service_role',
      'app_private.reconcile_calendar_notification_reminders(uuid,uuid,integer,integer[],timestamp with time zone)',
      'execute'
    ),
  'selection and reconciliation helpers remain private'
);

-- 12-28: strict input, optimistic replay, and v1/v2 preservation.
set local role authenticated;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$
    select * from public.get_notification_preferences_v3(
      '20000000-0000-4000-8000-000000000101'
    )
  $$,
  'KNP02',
  'authentication required',
  'an authenticated role without a subject cannot read v3 preferences'
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
        ':', category, reminder_lead_minutes,
        pg_catalog.array_to_string(additional_reminder_lead_minutes, '|'),
        version, is_default
      ),
      ',' order by category
    )
    from public.get_notification_preferences_v3(
      '20000000-0000-4000-8000-000000000101'
    )
  ),
  'calendar_event:0::0:t,chore_assignment:0::0:t,chore_due:0::0:t',
  'v3 defaults all three categories to one primary zero-minute reminder'
);
select ok(
  (
    select pg_catalog.bool_and(
      (
        select pg_catalog.count(*)
        from pg_catalog.jsonb_object_keys(to_jsonb(preference))
      ) = 14
      and to_jsonb(preference) ? 'additional_reminder_lead_minutes'
    )
    from public.get_notification_preferences_v3(
      '20000000-0000-4000-8000-000000000101'
    ) as preference
  ),
  'every v3 row serializes to exactly 14 keys'
);
select throws_ok(
  $$
    select * from public.get_notification_preferences_v3(
      '20000000-0000-4000-8000-000000000201'
    )
  $$,
  'KNP03',
  'notification household not found or forbidden',
  'another household v3 projection is denied'
);
select throws_ok(
  $$
    select * from public.update_notification_preference_v3(
      '20000000-0000-4000-8000-000000000101',
      'calendar_event', true, false, false, true,
      null, null, 'Asia/Seoul', 15, array[60, 30], 0
    )
  $$,
  'KNP01',
  'invalid notification preference input',
  'additional leads must be strictly increasing'
);
select throws_ok(
  $$
    select * from public.update_notification_preference_v3(
      '20000000-0000-4000-8000-000000000101',
      'calendar_event', true, false, false, true,
      null, null, 'Asia/Seoul', 15, array[15], 0
    )
  $$,
  'KNP01',
  'invalid notification preference input',
  'the primary lead cannot also be additional'
);
select throws_ok(
  $$
    select * from public.update_notification_preference_v3(
      '20000000-0000-4000-8000-000000000101',
      'calendar_event', true, false, false, true,
      null, null, 'Asia/Seoul', 15, array[0, 30, 60], 0
    )
  $$,
  'KNP01',
  'invalid notification preference input',
  'at most two additional reminders are accepted'
);
select throws_ok(
  $$
    select * from public.update_notification_preference_v3(
      '20000000-0000-4000-8000-000000000101',
      'calendar_event', true, false, false, true,
      null, null, 'Asia/Seoul', 15, array[7], 0
    )
  $$,
  'KNP01',
  'invalid notification preference input',
  'only the fixed reminder vocabulary is accepted'
);
select throws_ok(
  $$
    select * from public.update_notification_preference_v3(
      '20000000-0000-4000-8000-000000000101',
      'chore_due', true, false, false, true,
      null, null, 'Asia/Seoul', 0, array[5], 0
    )
  $$,
  'KNP01',
  'invalid notification preference input',
  'non-Calendar categories cannot store additional reminders'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', reminder_lead_minutes,
      pg_catalog.array_to_string(additional_reminder_lead_minutes, '|'),
      version, is_default
    )
    from public.update_notification_preference_v3(
      '20000000-0000-4000-8000-000000000101',
      'calendar_event', true, false, false, true,
      null, null, 'Asia/Seoul', 15, array[30, 60], 0
    )
  ),
  '15:30|60:1:f',
  'v3 materializes one primary and two additional Calendar reminders'
);
select is(
  (
    select version
    from public.update_notification_preference_v3(
      '20000000-0000-4000-8000-000000000101',
      'calendar_event', true, false, false, true,
      null, null, 'Asia/Seoul', 15, array[30, 60], 0
    )
  ),
  1::bigint,
  'an identical v3 response-loss replay is a version-preserving no-op'
);
select throws_ok(
  $$
    select * from public.update_notification_preference_v3(
      '20000000-0000-4000-8000-000000000101',
      'calendar_event', true, false, false, true,
      null, null, 'Asia/Seoul', 10, array[30, 60], 0
    )
  $$,
  'KNP06',
  'notification preference version conflict',
  'a stale v3 version cannot overwrite a different reminder set'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      (
        select pg_catalog.count(*)
        from pg_catalog.jsonb_object_keys(to_jsonb(preference))
      ),
      preference.native_push,
      preference.version
    )
    from public.update_notification_preference(
      '20000000-0000-4000-8000-000000000101',
      'calendar_event', false, false, false, true,
      null, null, 'Asia/Seoul', 1
    ) as preference
  ),
  '12:f:2',
  'the v1 command keeps its exact response while updating shared fields'
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', reminder_lead_minutes,
      pg_catalog.array_to_string(additional_reminder_lead_minutes, '|')
    )
    from public.notification_preferences
    where auth_user_id = '00000000-0000-4000-8000-000000000101'
      and household_id = '20000000-0000-4000-8000-000000000101'
      and category = 'calendar_event'
  ),
  '15:30|60',
  'a v1 write preserves both primary and additional reminders'
);
set local role authenticated;
select is(
  (
    select pg_catalog.concat_ws(
      ':', reminder_lead_minutes, version,
      (
        select pg_catalog.count(*)
        from pg_catalog.jsonb_object_keys(to_jsonb(preference))
      )
    )
    from public.update_notification_preference_v2(
      '20000000-0000-4000-8000-000000000101',
      'calendar_event', true, false, false, true,
      null, null, 'Asia/Seoul', 30, 2
    ) as preference
  ),
  '30:3:13',
  'v2 can promote an additional lead while retaining its exact shape'
);
reset role;
select is(
  (
    select pg_catalog.array_to_string(
      additional_reminder_lead_minutes,
      '|'
    )
    from public.notification_preferences
    where auth_user_id = '00000000-0000-4000-8000-000000000101'
      and household_id = '20000000-0000-4000-8000-000000000101'
      and category = 'calendar_event'
  ),
  '60',
  'v2 removes only the additional value promoted to primary'
);
set local role authenticated;
select is(
  (
    select pg_catalog.concat_ws(
      ':', reminder_lead_minutes,
      pg_catalog.array_to_string(additional_reminder_lead_minutes, '|'),
      version
    )
    from public.update_notification_preference_v3(
      '20000000-0000-4000-8000-000000000101',
      'calendar_event', true, false, false, true,
      null, null, 'Asia/Seoul', 10, array[30, 60], 3
    )
  ),
  '10:30|60:4',
  'v3 restores the three-reminder fixture set'
);
reset role;

create temporary table calendar_multiple_fixture (
  occurrence_id uuid primary key,
  starts_at timestamptz not null
);
create temporary table calendar_multiple_claims (
  event_id uuid primary key,
  lease_token uuid not null,
  attempt integer not null,
  max_attempts integer not null,
  lease_expires_at timestamptz not null
);
create temporary table calendar_multiple_results (
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
grant all on table calendar_multiple_fixture to authenticated;
grant all on table calendar_multiple_fixture to service_role;
grant all on table calendar_multiple_claims to service_role;
grant all on table calendar_multiple_results to service_role;

-- 29-37: one content-free source per selected recipient lead.
set local role authenticated;
select lives_ok(
  $$
    insert into calendar_multiple_fixture
    select result.occurrence_id, result.starts_at
    from public.create_one_time_event(
      '5c000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Multiple reminder private title',
      'Must never enter the notification envelope',
      false,
      (pg_catalog.statement_timestamp() at time zone 'Asia/Seoul')::date + 1,
      time '15:00',
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
  'a timed occurrence with one v3 and one default recipient is created'
);
reset role;
select is(
  (
    select pg_catalog.count(*)
    from app_private.chore_notification_outbox as event
    where event.aggregate_id = (
      select occurrence_id from calendar_multiple_fixture
    )
  ),
  4::bigint,
  'the occurrence emits three sources for v3 and one for the default recipient'
);
select is(
  (
    select pg_catalog.string_agg(
      pg_catalog.concat_ws(
        ':', event.audience_member_id,
        coalesce(event.reminder_lead_minutes::text, 'primary')
      ),
      ',' order by event.audience_member_id,
        event.reminder_lead_minutes nulls first
    )
    from app_private.chore_notification_outbox as event
    where event.aggregate_id = (
      select occurrence_id from calendar_multiple_fixture
    )
  ),
  '30000000-0000-4000-8000-000000000101:primary,30000000-0000-4000-8000-000000000101:30,30000000-0000-4000-8000-000000000101:60,30000000-0000-4000-8000-000000000102:primary',
  'source identity distinguishes the primary and each additional lead'
);
select ok(
  (
    select pg_catalog.bool_and(
      event.payload ?& array[
        'recipientMemberId', 'localStartDate', 'scheduledAt', 'timezone',
        'status'
      ]
      and event.payload - array[
        'recipientMemberId', 'localStartDate', 'scheduledAt', 'timezone',
        'status'
      ] = '{}'::jsonb
      and event.payload::text !~* 'Multiple reminder|Must never|reminderLead'
    )
    from app_private.chore_notification_outbox as event
    where event.aggregate_id = (
      select occurrence_id from calendar_multiple_fixture
    )
  ),
  'all source payloads retain the exact content-free five-key envelope'
);
select is(
  (
    select pg_catalog.string_agg(
      pg_catalog.concat_ws(
        ':', resolved.recipient_member_id,
        coalesce(event.reminder_lead_minutes::text, 'primary'),
        (
          extract(epoch from (fixture.starts_at - resolved.due_at)) / 60
        )::integer
      ),
      ',' order by resolved.recipient_member_id,
        event.reminder_lead_minutes nulls first
    )
    from app_private.chore_notification_outbox as event
    join calendar_multiple_fixture as fixture
      on fixture.occurrence_id = event.aggregate_id
    cross join lateral app_private.resolve_notification_event(
      event.event_id
    ) as resolved
  ),
  '30000000-0000-4000-8000-000000000101:primary:10,30000000-0000-4000-8000-000000000101:30:30,30000000-0000-4000-8000-000000000101:60:60,30000000-0000-4000-8000-000000000102:primary:0',
  'each recipient and selected lead resolves an exact independent instant'
);
select is(
  app_private.insert_calendar_notification_event(
    '20000000-0000-4000-8000-000000000101',
    (select occurrence_id from calendar_multiple_fixture),
    '30000000-0000-4000-8000-000000000101',
    null,
    null,
    '5c000000-0000-4000-8000-000000000099'
  ),
  false,
  'replaying source insertion creates no duplicate reminder slots'
);
set local role service_role;
insert into calendar_multiple_claims
select *
from public.claim_chore_notification_events(
  '5c000000-0000-4000-8000-000000000101',
  100,
  60,
  pg_catalog.statement_timestamp()
);
reset role;
select is(
  (select pg_catalog.count(*) from calendar_multiple_claims),
  4::bigint,
  'the source worker leases all four reminder slots'
);
set local role service_role;
insert into calendar_multiple_results
select result.*
from calendar_multiple_claims as claim
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
    from calendar_multiple_results
  ),
  '4:4:calendar_event',
  'all reminder slots persist independent Calendar candidate resolutions'
);
select is(
  (
    select pg_catalog.count(distinct resolution.scheduled_at)
    from app_private.notification_event_resolutions as resolution
    join calendar_multiple_results as result
      on result.source_event_id = resolution.source_event_id
  ),
  4::bigint,
  'the four recipient reminder instants remain distinct in this fixture'
);

-- Freeze the removed 60-minute history and leave selected work pending.
insert into app_private.notification_inbox_evaluations (
  source_event_id,
  outcome,
  preference_version,
  reason_code,
  evaluated_at
)
select
  event.event_id,
  'disabled',
  4,
  'CATEGORY_DISABLED',
  pg_catalog.statement_timestamp()
from app_private.chore_notification_outbox as event
where event.aggregate_id = (
    select occurrence_id from calendar_multiple_fixture
  )
  and event.audience_member_id =
    '30000000-0000-4000-8000-000000000101'
  and event.reminder_lead_minutes = 60;

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
join app_private.chore_notification_outbox as event
  on event.event_id = resolution.source_event_id
where event.aggregate_id = (
    select occurrence_id from calendar_multiple_fixture
  )
  and event.audience_member_id =
    '30000000-0000-4000-8000-000000000101'
  and (
    event.reminder_lead_minutes is null
    or event.reminder_lead_minutes = 30
  );

-- 38-46: selected pending work reconciles; removed and evaluated work freezes.
set local role authenticated;
select is(
  (
    select pg_catalog.concat_ws(
      ':', reminder_lead_minutes,
      pg_catalog.array_to_string(additional_reminder_lead_minutes, '|'),
      version
    )
    from public.update_notification_preference_v3(
      '20000000-0000-4000-8000-000000000101',
      'calendar_event', true, false, false, true,
      null, null, 'Asia/Seoul', 15, array[5, 30], 4
    )
  ),
  '15:5|30:5',
  'a v3 change replaces the primary and selected additional set'
);
reset role;
select is(
  (
    select pg_catalog.count(*)
    from app_private.chore_notification_outbox as event
    where event.aggregate_id = (
        select occurrence_id from calendar_multiple_fixture
      )
      and event.audience_member_id =
        '30000000-0000-4000-8000-000000000101'
  ),
  4::bigint,
  'reconciliation adds only the newly selected five-minute source'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      pg_catalog.count(*) filter (where resolved.should_create_intent),
      pg_catalog.count(*) filter (
        where not resolved.should_create_intent
          and resolved.suppression_reason = 'stale_event'
      )
    )
    from app_private.chore_notification_outbox as event
    cross join lateral app_private.resolve_notification_event(
      event.event_id
    ) as resolved
    where event.aggregate_id = (
        select occurrence_id from calendar_multiple_fixture
      )
      and event.audience_member_id =
        '30000000-0000-4000-8000-000000000101'
  ),
  '3:1',
  'the current primary plus two selected extras stay actionable and 60 is stale'
);
select is(
  (
    select pg_catalog.string_agg(
      pg_catalog.concat_ws(
        ':', coalesce(event.reminder_lead_minutes::text, 'primary'),
        (
          extract(epoch from (fixture.starts_at - resolution.scheduled_at))
          / 60
        )::integer
      ),
      ',' order by event.reminder_lead_minutes nulls first
    )
    from app_private.notification_event_resolutions as resolution
    join app_private.chore_notification_outbox as event
      on event.event_id = resolution.source_event_id
    join calendar_multiple_fixture as fixture
      on fixture.occurrence_id = event.aggregate_id
    where event.audience_member_id =
      '30000000-0000-4000-8000-000000000101'
  ),
  'primary:15,30:30,60:60',
  'pending primary changes while explicit and evaluated reminder schedules hold'
);
select ok(
  (
    select pg_catalog.bool_and(
      evaluation.next_evaluation_at = resolution.scheduled_at
    )
    from app_private.notification_push_evaluations as evaluation
    join app_private.notification_event_resolutions as resolution
      on resolution.source_event_id = evaluation.source_event_id
    join app_private.chore_notification_outbox as event
      on event.event_id = evaluation.source_event_id
    where event.aggregate_id = (
        select occurrence_id from calendar_multiple_fixture
      )
      and event.audience_member_id =
        '30000000-0000-4000-8000-000000000101'
  ),
  'pending push evaluations follow the reconciled selected schedules'
);
select is(
  (
    select outcome
    from app_private.notification_inbox_evaluations as evaluation
    join app_private.chore_notification_outbox as event
      on event.event_id = evaluation.source_event_id
    where event.aggregate_id = (
        select occurrence_id from calendar_multiple_fixture
      )
      and event.reminder_lead_minutes = 60
  ),
  'disabled',
  'evaluated 60-minute history remains frozen after removal'
);
select throws_ok(
  $$
    update app_private.chore_notification_outbox
    set reminder_lead_minutes = 15
    where aggregate_id = (
        select occurrence_id from calendar_multiple_fixture
      )
      and audience_member_id =
        '30000000-0000-4000-8000-000000000101'
      and reminder_lead_minutes = 30
  $$,
  '55000',
  'notification source transition is invalid',
  'an emitted reminder identity is immutable'
);
set local role service_role;
truncate table calendar_multiple_claims;
insert into calendar_multiple_claims
select *
from public.claim_chore_notification_events(
  '5c000000-0000-4000-8000-000000000102',
  100,
  60,
  pg_catalog.statement_timestamp()
);
reset role;
select is(
  (select pg_catalog.count(*) from calendar_multiple_claims),
  1::bigint,
  'only the newly selected five-minute source remains to be leased'
);
set local role service_role;
truncate table calendar_multiple_results;
insert into calendar_multiple_results
select result.*
from calendar_multiple_claims as claim
cross join lateral public.process_chore_notification_event(
  claim.event_id,
  claim.lease_token,
  pg_catalog.statement_timestamp()
) as result;
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', outcome,
      (
        extract(epoch from (
          (select starts_at from calendar_multiple_fixture) - scheduled_at
        )) / 60
      )::integer
    )
    from calendar_multiple_results
  ),
  'candidate:5',
  'the new additional source resolves through the existing worker path'
);

-- 47-50: independent due instants materialize while the inbox keeps one latest item.
set local role service_role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', claimed_count, created_count, cancelled_count
    )
    from public.materialize_chore_notification_inbox(
      100,
      (select starts_at - interval '30 minutes'
       from calendar_multiple_fixture)
    )
  ),
  '1:1:0',
  'the earliest currently selected additional reminder materializes alone'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', claimed_count, created_count, cancelled_count
    )
    from public.materialize_chore_notification_inbox(
      100,
      (select starts_at - interval '15 minutes'
       from calendar_multiple_fixture)
    )
  ),
  '1:1:1',
  'the primary reminder materializes later and supersedes the prior badge'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', claimed_count, created_count, cancelled_count
    )
    from public.materialize_chore_notification_inbox(
      100,
      (select starts_at - interval '5 minutes'
       from calendar_multiple_fixture)
    )
  ),
  '1:1:1',
  'the final five-minute reminder independently materializes and becomes latest'
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', pg_catalog.count(*),
      pg_catalog.count(*) filter (where item.cancelled_at is null)
    )
    from public.notification_inbox_items as item
    where item.subject_id = (
        select occurrence_id from calendar_multiple_fixture
      )
      and item.recipient_user_id =
        '00000000-0000-4000-8000-000000000101'
  ),
  '3:1',
  'three independent reminders leave exactly one current content-free inbox item'
);

select * from finish();
rollback;
