begin;
set constraints all deferred;

select plan(46);

-- Schema, strict polymorphic routing, and least privilege.
select has_function(
  'public',
  'enqueue_calendar_event_reminder_events',
  array['timestamp with time zone', 'timestamp with time zone'],
  'bounded Calendar reminder horizon producer exists'
);
select has_function(
  'app_private',
  'resolve_notification_event',
  array['uuid'],
  'generic latest-state resolver exists'
);
select ok(
  app_private.is_valid_notification_timestamp_text(
    '2030-01-01T00:00:00Z'
  )
    and app_private.is_valid_notification_timestamp_text(
      '2030-01-01T09:00:00+09:00'
    )
    and not app_private.is_valid_notification_timestamp_text(
      '2030-01-01T00:00:00'
    ),
  'notification source timestamps require an explicit UTC or numeric offset'
);
select has_trigger(
  'public',
  'event_occurrences',
  'event_occurrences_capture_notification_events',
  'Calendar occurrence changes capture reminder source events'
);
select has_trigger(
  'public',
  'event_participants',
  'event_participants_capture_notification_events',
  'one-time participant changes capture exact audience events'
);
select has_trigger(
  'public',
  'chore_occurrences',
  'chore_occurrences_delete_notification_sources',
  'Chore hard deletion preserves the former source-event cascade'
);
select has_trigger(
  'public',
  'event_occurrences',
  'event_occurrences_delete_notification_sources',
  'Calendar hard deletion removes polymorphic source events'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.enqueue_calendar_event_reminder_events(timestamptz,timestamptz)',
    'execute'
  )
    and not has_function_privilege(
      'authenticated',
      'public.enqueue_calendar_event_reminder_events(timestamptz,timestamptz)',
      'execute'
    )
    and not has_function_privilege(
      'anon',
      'public.enqueue_calendar_event_reminder_events(timestamptz,timestamptz)',
      'execute'
    ),
  'only service role can run the Calendar reminder horizon producer'
);
select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'chore_notification_outbox'
      and column_name = 'audience_member_id'
      and is_nullable = 'NO'
  ),
  'source events persist an exact non-null audience member'
);
select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'notification_event_resolutions'
      and column_name = 'audience_member_id'
      and is_nullable = 'NO'
  ),
  'suppressed and candidate resolutions retain exact audience identity'
);
select ok(
  pg_catalog.pg_get_constraintdef(
    (
      select oid
      from pg_catalog.pg_constraint
      where conname = 'notification_event_resolution_subject_type_ck'
    )
  ) like '%calendar_event%calendar_occurrence%'
    and pg_catalog.pg_get_constraintdef(
      (
        select oid
        from pg_catalog.pg_constraint
        where conname = 'notification_inbox_subject_type_ck'
      )
    ) like '%calendar_event%calendar_occurrence%'
    and pg_catalog.pg_get_constraintdef(
      (
        select oid
        from pg_catalog.pg_constraint
        where conname = 'notification_push_delivery_subject_type_ck'
      )
    ) like '%calendar_event%calendar_occurrence%',
  'resolution inbox and push enforce the Calendar category-subject pair'
);
select ok(
  (
    select pg_proc.prosecdef
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_catalog.pg_proc
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'enqueue_calendar_event_reminder_events'
  )
    and (
      select not pg_proc.prosecdef
        and pg_proc.provolatile = 's'
        and pg_proc.proconfig @> array['search_path=""']::text[]
      from pg_catalog.pg_proc
      join pg_catalog.pg_namespace
        on pg_namespace.oid = pg_proc.pronamespace
      where pg_namespace.nspname = 'app_private'
        and pg_proc.proname = 'resolve_notification_event'
    ),
  'producer and resolver use their exact authority and empty search paths'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema in ('public', 'app_private')
      and table_name in (
        'chore_notification_outbox',
        'notification_event_resolutions',
        'notification_inbox_items',
        'notification_push_deliveries'
      )
      and column_name in (
        'title', 'description', 'display_name', 'email_address',
        'raw_error', 'error_message', 'provider_body', 'token'
      )
  ),
  'Calendar reminder persistence contains no family content or provider secret'
);

create temporary table calendar_reminder_events (
  fixture_label text primary key,
  series_id uuid not null,
  occurrence_id uuid not null,
  local_start_date date not null,
  starts_at timestamptz,
  version bigint not null,
  occurrence_version bigint not null
);
create temporary table calendar_recurring_creation (
  series_id uuid primary key,
  first_occurrence_id uuid,
  materialized_count integer not null,
  version bigint not null
);
create temporary table calendar_source_claims (
  event_id uuid primary key,
  lease_token uuid not null,
  attempt integer not null,
  max_attempts integer not null,
  lease_expires_at timestamptz not null
);
create temporary table calendar_source_results (
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
create temporary table calendar_materializer_results (
  captured_at timestamptz not null,
  claimed_count integer not null,
  created_count integer not null,
  disabled_count integer not null,
  stale_count integer not null,
  suppressed_count integer not null,
  cancelled_count integer not null
);
create temporary table calendar_push_claims (
  delivery_id uuid primary key,
  source_event_id uuid not null,
  inbox_item_id uuid,
  endpoint_id uuid not null,
  household_id uuid not null,
  category text not null,
  subject_type text not null,
  subject_id uuid not null,
  token_ciphertext_base64 text not null,
  token_fingerprint_base64 text not null,
  token_key_version integer not null,
  locale text,
  attempt integer not null,
  max_attempts integer not null,
  lease_token uuid not null,
  lease_expires_at timestamptz not null,
  scheduled_at timestamptz not null,
  expires_at timestamptz not null
);
grant all on table calendar_reminder_events to authenticated;
grant all on table calendar_reminder_events to service_role;
grant insert, select on table calendar_recurring_creation to authenticated;
grant all on table calendar_source_claims to service_role;
grant all on table calendar_source_results to service_role;
grant all on table calendar_materializer_results to service_role;
grant all on table calendar_push_claims to service_role;
grant select on table calendar_push_claims to authenticated;

-- Timed and all-day one-time events fan out content-free source events.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
set local role authenticated;
select lives_ok(
  $$
    insert into calendar_reminder_events
    select
      'timed',
      result.series_id,
      result.occurrence_id,
      result.local_start_date,
      result.starts_at,
      result.version,
      result.occurrence_version
    from public.create_one_time_event(
      '59000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Calendar reminder timed',
      'Private timed description',
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
  'timed Calendar create commits with two reminder participants'
);
reset role;
select is(
  (
    select pg_catalog.count(*)
    from app_private.chore_notification_outbox as event
    where event.aggregate_type = 'calendar_occurrence'
      and event.aggregate_id = (
        select occurrence_id
        from calendar_reminder_events
        where fixture_label = 'timed'
      )
  ),
  2::bigint,
  'timed occurrence emits one source event per participant'
);
select ok(
  (
    select pg_catalog.bool_and(
      event.event_type = 'calendar.occurrence_start_changed'
      and event.event_version = 1
      and event.aggregate_version = fixture.occurrence_version
      and event.audience_member_id =
        (event.payload->>'recipientMemberId')::uuid
    )
    from app_private.chore_notification_outbox as event
    join calendar_reminder_events as fixture
      on fixture.occurrence_id = event.aggregate_id
     and fixture.fixture_label = 'timed'
  ),
  'Calendar source envelopes bind exact occurrence version and audience'
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
      and event.payload::text !~* 'Calendar reminder|Private timed'
    )
    from app_private.chore_notification_outbox as event
    where event.aggregate_id = (
      select occurrence_id
      from calendar_reminder_events
      where fixture_label = 'timed'
    )
  ),
  'Calendar source payload is exact and excludes title and description'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      pg_catalog.count(*),
      pg_catalog.count(*) filter (where resolved.should_create_intent),
      pg_catalog.min(resolved.notification_category),
      pg_catalog.min(resolved.subject_type),
      pg_catalog.bool_and(resolved.due_at = fixture.starts_at)
    )
    from app_private.chore_notification_outbox as event
    join calendar_reminder_events as fixture
      on fixture.occurrence_id = event.aggregate_id
     and fixture.fixture_label = 'timed'
    cross join lateral app_private.resolve_notification_event(
      event.event_id
    ) as resolved
  ),
  '2:2:calendar_event:calendar_occurrence:t',
  'timed sources resolve two exact start-time candidates'
);

set local role authenticated;
select lives_ok(
  $$
    insert into calendar_reminder_events
    select
      'all_day',
      result.series_id,
      result.occurrence_id,
      result.local_start_date,
      result.starts_at,
      result.version,
      result.occurrence_version
    from public.create_one_time_event(
      '59000000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      'Calendar reminder all day',
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
  'all-day Calendar create commits with one participant'
);
reset role;
select is(
  (
    select pg_catalog.count(*)
    from app_private.chore_notification_outbox as event
    where event.aggregate_id = (
      select occurrence_id
      from calendar_reminder_events
      where fixture_label = 'all_day'
    )
  ),
  1::bigint,
  'all-day occurrence emits one audience source event'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      resolved.due_local_date,
      pg_catalog.to_char(
        resolved.due_at at time zone resolved.timezone,
        'HH24:MI'
      ),
      resolved.timezone,
      resolved.should_create_intent
    )
    from app_private.chore_notification_outbox as event
    cross join lateral app_private.resolve_notification_event(
      event.event_id
    ) as resolved
    where event.aggregate_id = (
      select occurrence_id
      from calendar_reminder_events
      where fixture_label = 'all_day'
    )
  ),
  (
    select pg_catalog.concat_ws(
      ':', local_start_date, '09:00', 'Asia/Seoul', true
    )
    from calendar_reminder_events
    where fixture_label = 'all_day'
  )::text,
  'all-day reminder uses date-only event semantics and 09:00 household time'
);

-- Worker resolution is immediate, while future Calendar inbox creation waits.
set local role service_role;
insert into calendar_source_claims
select *
from public.claim_chore_notification_events(
  '59000000-0000-4000-8000-000000000101',
  100,
  60,
  pg_catalog.statement_timestamp()
);
reset role;
select is(
  (select pg_catalog.count(*) from calendar_source_claims),
  3::bigint,
  'backward-compatible worker claim leases all three Calendar audience events'
);
set local role service_role;
insert into calendar_source_results
select result.*
from calendar_source_claims as claim
cross join lateral public.process_chore_notification_event(
  claim.event_id,
  claim.lease_token,
  pg_catalog.statement_timestamp()
) as result;
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      pg_catalog.count(*),
      pg_catalog.count(*) filter (where outcome = 'candidate'),
      pg_catalog.min(notification_category),
      pg_catalog.min(subject_type)
    )
    from calendar_source_results
  ),
  '3:3:calendar_event:calendar_occurrence',
  'worker durably resolves all Calendar audiences as content-free candidates'
);
set local role service_role;
insert into calendar_materializer_results
select *
from public.materialize_chore_notification_inbox(
  100,
  pg_catalog.statement_timestamp()
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(':', claimed_count, created_count)
    from calendar_materializer_results
  ),
  '0:0',
  'future Calendar candidates do not appear in the inbox before start'
);

truncate calendar_materializer_results;
set local role service_role;
insert into calendar_materializer_results
select *
from public.materialize_chore_notification_inbox(
  100,
  (
    select starts_at
    from calendar_reminder_events
    where fixture_label = 'timed'
  )
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(':', claimed_count, created_count)
    from calendar_materializer_results
  ),
  '3:3',
  'due Calendar candidates materialize one durable inbox item per audience'
);
select ok(
  (
    select pg_catalog.count(*) = 3
      and pg_catalog.bool_and(category = 'calendar_event')
      and pg_catalog.bool_and(subject_type = 'calendar_occurrence')
      and pg_catalog.bool_and(
        payload ?& array['householdId', 'occurrenceId']
        and payload - array['householdId', 'occurrenceId'] = '{}'::jsonb
      )
    from public.notification_inbox_items
    where category = 'calendar_event'
      and cancelled_at is null
  ),
  'Calendar inbox items retain only exact content-free routing payloads'
);

-- Calendar candidates reuse Android provider claim and authenticated tap auth.
set local role service_role;
select lives_ok(
  $$
    select *
    from public.upsert_notification_endpoint(
      '00000000-0000-4000-8000-000000000102',
      '20000000-0000-4000-8000-000000000101',
      '59000000-0000-4000-8000-000000000201',
      'native_push',
      'android',
      encode(decode(repeat('21', 32), 'hex'), 'base64'),
      encode(decode(repeat('22', 32), 'hex'), 'base64'),
      1,
      encode(decode(repeat('23', 32), 'hex'), 'base64'),
      'granted',
      'ko-KR',
      'Asia/Seoul',
      '0.1.0+1',
      'Flutter 3.44.7',
      '59000000-0000-4000-8000-000000000202',
      0,
      (
        select starts_at
        from calendar_reminder_events
        where fixture_label = 'timed'
      )
    )
  $$,
  'active Android endpoint is registered for one Calendar participant'
);
insert into calendar_push_claims
select *
from public.claim_notification_push_deliveries(
  '59000000-0000-4000-8000-000000000203',
  100,
  60,
  (
    select starts_at
    from calendar_reminder_events
    where fixture_label = 'timed'
  )
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', pg_catalog.count(*), pg_catalog.min(category),
      pg_catalog.min(subject_type)
    )
    from calendar_push_claims
  ),
  '1:calendar_event:calendar_occurrence',
  'provider claim accepts the strict Calendar routing pair'
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
      ':', target.category, target.subject_type, target.safe_destination
    )
    from calendar_push_claims as claim
    cross join lateral public.resolve_notification_push_target(
      claim.delivery_id,
      claim.household_id,
      claim.subject_id
    ) as target
  ),
  'calendar_event:calendar_occurrence:calendar_event',
  'exact Calendar recipient authorizes its occurrence-specific destination'
);
reset role;

-- Participant removal cancels only that audience and creates one replacement.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
set local role authenticated;
select lives_ok(
  $$
    select *
    from public.update_one_time_event(
      '59000000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      (
        select series_id
        from calendar_reminder_events
        where fixture_label = 'timed'
      ),
      (
        select series.version
        from public.event_series as series
        where series.id = (
          select series_id
          from calendar_reminder_events
          where fixture_label = 'timed'
        )
      ),
      'Calendar reminder timed',
      'Private timed description',
      false,
      (
        select local_start_date
        from calendar_reminder_events
        where fixture_label = 'timed'
      ),
      time '10:00',
      60,
      null,
      'Asia/Seoul',
      'earlier',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'one-time update removes one Calendar reminder participant'
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      pg_catalog.count(*) filter (
        where item.subject_id = (
          select occurrence_id
          from calendar_reminder_events
          where fixture_label = 'timed'
        ) and item.cancelled_at is null
      ),
      pg_catalog.count(*) filter (
        where item.subject_id = (
          select occurrence_id
          from calendar_reminder_events
          where fixture_label = 'all_day'
        ) and item.cancelled_at is null
      )
    )
    from public.notification_inbox_items as item
    where item.category = 'calendar_event'
  ),
  '0:1',
  'schedule source change immediately cancels only the changed occurrence inbox'
);
select is(
  (
    select pg_catalog.count(*)
    from app_private.chore_notification_outbox as event
    where event.aggregate_id = (
      select occurrence_id
      from calendar_reminder_events
      where fixture_label = 'timed'
    )
      and event.aggregate_version = 2
  ),
  2::bigint,
  'participant change emits one version-two source for retained and removed audiences'
);

truncate calendar_source_claims, calendar_source_results;
set local role service_role;
insert into calendar_source_claims
select *
from public.claim_chore_notification_events(
  '59000000-0000-4000-8000-000000000301',
  100,
  60,
  pg_catalog.statement_timestamp()
);
insert into calendar_source_results
select result.*
from calendar_source_claims as claim
cross join lateral public.process_chore_notification_event(
  claim.event_id,
  claim.lease_token,
  pg_catalog.statement_timestamp()
) as result;
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      pg_catalog.count(*) filter (where outcome = 'candidate'),
      pg_catalog.count(*) filter (where outcome = 'suppressed')
    )
    from calendar_source_results
  ),
  '1:1',
  'latest-state worker keeps retained audience and suppresses removed audience'
);

truncate calendar_materializer_results;
set local role service_role;
insert into calendar_materializer_results
select *
from public.materialize_chore_notification_inbox(
  100,
  (
    select starts_at + interval '1 minute'
    from calendar_reminder_events
    where fixture_label = 'timed'
  )
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      pg_catalog.count(*) filter (
        where item.subject_id = (
          select occurrence_id
          from calendar_reminder_events
          where fixture_label = 'timed'
        ) and item.cancelled_at is null
      ),
      pg_catalog.min(item.recipient_member_id::text) filter (
        where item.subject_id = (
          select occurrence_id
          from calendar_reminder_events
          where fixture_label = 'timed'
        ) and item.cancelled_at is null
      ),
      pg_catalog.count(*) filter (
        where item.subject_id = (
          select occurrence_id
          from calendar_reminder_events
          where fixture_label = 'all_day'
        ) and item.cancelled_at is null
      )
    )
    from public.notification_inbox_items as item
    where item.category = 'calendar_event'
  ),
  '1:30000000-0000-4000-8000-000000000101:1',
  'per-audience materialization leaves retained timed and unrelated all-day items active'
);

-- Far future one-time events are captured later by the bounded sweep.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
set local role authenticated;
select lives_ok(
  $$
    insert into calendar_reminder_events
    select
      'far',
      result.series_id,
      result.occurrence_id,
      result.local_start_date,
      result.starts_at,
      result.version,
      result.occurrence_version
    from public.create_one_time_event(
      '59000000-0000-4000-8000-000000000004',
      '20000000-0000-4000-8000-000000000101',
      'Calendar reminder far future',
      null,
      false,
      (pg_catalog.statement_timestamp() at time zone 'Asia/Seoul')::date + 40,
      time '10:00',
      60,
      null,
      'Asia/Seoul',
      'earlier',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    ) as result
  $$,
  'far future one-time event is created normally'
);
reset role;
select is(
  (
    select pg_catalog.count(*)
    from app_private.chore_notification_outbox
    where aggregate_id = (
      select occurrence_id
      from calendar_reminder_events
      where fixture_label = 'far'
    )
  ),
  0::bigint,
  'far future insert does not immediately expand the notification queue'
);
set local role service_role;
select is(
  (
    select enqueued_count
    from public.enqueue_calendar_event_reminder_events(
      pg_catalog.statement_timestamp() + interval '9 days',
      pg_catalog.statement_timestamp() + interval '41 days'
    )
  ),
  1,
  'bounded sweep enqueues the far event when it enters the 32-day horizon'
);
reset role;
select is(
  (
    select pg_catalog.count(*)
    from app_private.chore_notification_outbox
    where aggregate_id = (
      select occurrence_id
      from calendar_reminder_events
      where fixture_label = 'far'
    )
  ),
  1::bigint,
  'horizon sweep persists exactly one far-event audience source'
);
set local role service_role;
select is(
  (
    select enqueued_count
    from public.enqueue_calendar_event_reminder_events(
      pg_catalog.statement_timestamp() + interval '9 days',
      pg_catalog.statement_timestamp() + interval '41 days'
    )
  ),
  0,
  'Calendar horizon enqueue is idempotent for the exact version and audience'
);
reset role;

-- Calendar preferences are explicit and versioned like Chore categories.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
set local role authenticated;
select is(
  (
    select pg_catalog.count(*)
    from public.get_notification_preferences(
      '20000000-0000-4000-8000-000000000101'
    )
  ),
  3::bigint,
  'preference projection includes Calendar and both Chore categories'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', category, native_push, in_app, version, is_default
    )
    from public.update_notification_preference(
      '20000000-0000-4000-8000-000000000101',
      'calendar_event',
      false,
      false,
      false,
      true,
      null,
      null,
      'Asia/Seoul',
      0
    )
  ),
  'calendar_event:f:t:1:f',
  'Calendar preference uses the existing versioned mediated command'
);
reset role;

delete from public.event_series
where id = (
  select series_id
  from calendar_reminder_events
  where fixture_label = 'far'
);
select is(
  (
    select pg_catalog.count(*)
    from app_private.chore_notification_outbox
    where aggregate_id = (
      select occurrence_id
      from calendar_reminder_events
      where fixture_label = 'far'
    )
  ),
  0::bigint,
  'Calendar occurrence hard delete cascades its polymorphic source events'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
set local role authenticated;
select lives_ok(
  $$
    insert into calendar_recurring_creation
    select
      created.series_id,
      created.first_occurrence_id,
      created.materialized_count,
      created.version
    from public.create_recurring_calendar_event(
        '59000000-0000-4000-8000-000000000005',
        '20000000-0000-4000-8000-000000000101',
        'Calendar reminder recurring snapshot',
        null,
        false,
        (pg_catalog.statement_timestamp() at time zone 'Asia/Seoul')::date
          + 2,
        time '11:00',
        60,
        null,
        'Asia/Seoul',
        'earlier',
        pg_catalog.jsonb_build_object(
          'frequency', 'daily',
          'interval', 1,
          'end', pg_catalog.jsonb_build_object(
            'type', 'count',
            'count', 1
          )
        ),
        array[
          '30000000-0000-4000-8000-000000000101'::uuid,
          '30000000-0000-4000-8000-000000000102'::uuid
        ]
      ) as created
  $$,
  'bounded recurring Calendar fixture materializes one reminder occurrence'
);
reset role;
insert into calendar_reminder_events
select
  'recurring',
  created.series_id,
  occurrence.id,
  occurrence.local_start_date,
  occurrence.starts_at,
  created.version,
  occurrence.version
from calendar_recurring_creation as created
join lateral (
  select candidate.*
  from public.event_occurrences as candidate
  where candidate.series_id = created.series_id
  order by candidate.local_start_date, candidate.id
  limit 1
) as occurrence on true;
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      (select materialized_count from calendar_recurring_creation),
      pg_catalog.count(*)
    )
    from public.event_revision_participants as participant
    join public.event_occurrences as occurrence
      on occurrence.household_id = participant.household_id
     and occurrence.series_id = participant.series_id
     and occurrence.revision_id = participant.revision_id
    where occurrence.id = (
      select occurrence_id
      from calendar_reminder_events
      where fixture_label = 'recurring'
    )
  ),
  '1:2',
  'recurring occurrence owns an immutable two-member revision snapshot'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      pg_catalog.count(*),
      pg_catalog.count(distinct event.audience_member_id),
      pg_catalog.bool_and(
        event.aggregate_version = (
          select occurrence_version
          from calendar_reminder_events
          where fixture_label = 'recurring'
        )
      )
    )
    from app_private.chore_notification_outbox as event
    where event.aggregate_id = (
      select occurrence_id
      from calendar_reminder_events
      where fixture_label = 'recurring'
    )
  ),
  '2:2:t',
  'recurring source fan-out binds both revision audiences to one occurrence version'
);
delete from public.event_participants
where series_id = (
    select series_id
    from calendar_reminder_events
    where fixture_label = 'recurring'
  )
  and member_id = '30000000-0000-4000-8000-000000000102';
select is(
  (
    select pg_catalog.string_agg(participant.member_id::text, ',' order by participant.member_id)
    from app_private.calendar_notification_participants(
      '20000000-0000-4000-8000-000000000101',
      (
        select series_id
        from calendar_reminder_events
        where fixture_label = 'recurring'
      ),
      (
        select occurrence.revision_id
        from public.event_occurrences as occurrence
        where occurrence.id = (
          select occurrence_id
          from calendar_reminder_events
          where fixture_label = 'recurring'
        )
      )
    ) as participant
  ),
  '30000000-0000-4000-8000-000000000101,30000000-0000-4000-8000-000000000102',
  'recurring audience resolution ignores later mutable series-participant drift'
);

select * from finish();
rollback;
