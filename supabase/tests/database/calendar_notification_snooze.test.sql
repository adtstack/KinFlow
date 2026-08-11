begin;
set constraints all deferred;

select plan(47);

-- 1-10: additive schema, N-1 compatibility, and least privilege.
select has_table(
  'app_private',
  'calendar_notification_snooze_commands',
  'an immutable Calendar notification snooze command ledger exists'
);
select has_function(
  'public',
  'list_notification_inbox_items_v2',
  array['uuid', 'integer', 'timestamp with time zone', 'uuid'],
  'the additive inbox v2 projection exists'
);
select has_function(
  'public',
  'snooze_calendar_notification',
  array['uuid', 'uuid', 'integer', 'uuid', 'bigint'],
  'the versioned idempotent snooze command exists'
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
          and routine_name = 'list_notification_inbox_items_v2'
        limit 1
      )
      and parameter_mode = 'OUT'
  ),
  'inbox_item_id,item_version,source_event_id,household_id,category,subject_type,subject_id,scheduled_at,created_at,read_at,payload,snooze_count,snooze_max_minutes,has_more,next_before_created_at,next_before_id',
  'inbox v2 has the exact additive 16-field response'
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
          and routine_name = 'snooze_calendar_notification'
        limit 1
      )
      and parameter_mode = 'OUT'
  ),
  'command_id,source_event_id,inbox_item_id,item_version,snoozed_until,snooze_minutes,snooze_count,unread_count,recorded_at',
  'snooze returns the exact nine-field receipt'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.list_notification_inbox_items_v2(uuid,integer,timestamptz,uuid)',
    'execute'
  )
    and has_function_privilege(
      'authenticated',
      'public.snooze_calendar_notification(uuid,uuid,integer,uuid,bigint)',
      'execute'
    )
    and not has_function_privilege(
      'anon',
      'public.snooze_calendar_notification(uuid,uuid,integer,uuid,bigint)',
      'execute'
    )
    and not has_function_privilege(
      'service_role',
      'public.snooze_calendar_notification(uuid,uuid,integer,uuid,bigint)',
      'execute'
    ),
  'only authenticated clients can read v2 and execute snooze'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.calendar_notification_snooze_commands',
    'select'
  )
    and not has_table_privilege(
      'service_role',
      'app_private.calendar_notification_snooze_commands',
      'select'
    ),
  'the command ledger is sealed from client and worker roles'
);
select ok(
  pg_catalog.pg_get_constraintdef(
    (
      select oid
      from pg_catalog.pg_constraint
      where conname = 'notification_source_event_type_ck'
    )
  ) like '%calendar.occurrence_reminder_snoozed%'
    and pg_catalog.pg_get_constraintdef(
      (
        select oid
        from pg_catalog.pg_constraint
        where conname = 'notification_source_event_audience_key'
      )
    ) like '%UNIQUE NULLS NOT DISTINCT%causation_id%',
  'the source envelope admits command-keyed snoozes without weakening dedupe'
);
select ok(
  pg_catalog.pg_get_constraintdef(
    (
      select oid
      from pg_catalog.pg_constraint
      where conname = 'notification_inbox_items_cancellation_reason_check'
    )
  ) like '%snoozed%'
    and exists (
      select 1
      from pg_catalog.pg_trigger
      where tgname = 'calendar_notification_snooze_commands_immutable'
        and not tgisinternal
    ),
  'inbox supersession is explicit and the receipt ledger is immutable'
);
select ok(
  (
    select pg_proc.prosecdef
      and pg_proc.provolatile = 'v'
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_catalog.pg_proc
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'snooze_calendar_notification'
  )
    and (
      select pg_proc.prosecdef
        and pg_proc.provolatile = 's'
        and pg_proc.proconfig @> array['search_path=""']::text[]
      from pg_catalog.pg_proc
      join pg_catalog.pg_namespace
        on pg_namespace.oid = pg_proc.pronamespace
      where pg_namespace.nspname = 'public'
        and pg_proc.proname = 'list_notification_inbox_items_v2'
    ),
  'public APIs use exact authority, volatility, and an empty search path'
);

create temporary table snooze_fixture (
  series_id uuid primary key,
  occurrence_id uuid not null,
  starts_at timestamptz not null
);
create temporary table snooze_source_claims (
  event_id uuid primary key,
  lease_token uuid not null,
  attempt integer not null,
  max_attempts integer not null,
  lease_expires_at timestamptz not null
);
create temporary table snooze_source_results (
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
create temporary table snooze_inbox (
  inbox_item_id uuid primary key,
  item_version bigint not null,
  source_event_id uuid not null
);
create temporary table snooze_receipts (
  command_id uuid primary key,
  source_event_id uuid not null,
  inbox_item_id uuid not null,
  item_version bigint not null,
  snoozed_until timestamptz not null,
  snooze_minutes integer not null,
  snooze_count integer not null,
  unread_count integer not null,
  recorded_at timestamptz not null
);
create temporary table snooze_push_claims (
  claim_label text not null,
  delivery_id uuid not null,
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
grant all on table snooze_fixture to authenticated;
grant all on table snooze_source_claims to service_role;
grant all on table snooze_source_results to service_role;
grant all on table snooze_inbox to authenticated;
grant all on table snooze_receipts to authenticated;
grant select on table snooze_receipts to service_role;
grant select on table snooze_fixture to service_role;
grant all on table snooze_push_claims to service_role;

-- 11-17: authentication, validation, and one due Calendar reminder fixture.
set local role authenticated;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$
    select * from public.snooze_calendar_notification(
      '20000000-0000-4000-8000-000000000101',
      '65000000-0000-4000-8000-000000000001',
      10,
      '65000000-0000-4000-8000-000000000002',
      1
    )
  $$,
  'KNP02',
  'authentication required',
  'a role without an authenticated subject cannot snooze'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.snooze_calendar_notification(
      '20000000-0000-4000-8000-000000000101',
      '65000000-0000-4000-8000-000000000001',
      15,
      '65000000-0000-4000-8000-000000000002',
      1
    )
  $$,
  'KNP01',
  'invalid notification snooze command',
  'only the exact 5, 10, and 30 minute options are accepted'
);
select throws_ok(
  $$
    select * from public.snooze_calendar_notification(
      '20000000-0000-4000-8000-000000000201',
      '65000000-0000-4000-8000-000000000001',
      10,
      '65000000-0000-4000-8000-000000000002',
      1
    )
  $$,
  'KNP03',
  'notification household not found or forbidden',
  'another household cannot be targeted'
);
select lives_ok(
  $$
    insert into snooze_fixture
    select result.series_id, result.occurrence_id, result.starts_at
    from public.create_one_time_event(
      '65000000-0000-4000-8000-000000000010',
      '20000000-0000-4000-8000-000000000101',
      'Snooze fixture title',
      'Must never enter a notification envelope',
      false,
      (
        pg_catalog.date_trunc('minute', pg_catalog.statement_timestamp())
          at time zone 'Asia/Seoul' - interval '10 minutes'
      )::date,
      (
        pg_catalog.date_trunc('minute', pg_catalog.statement_timestamp())
          at time zone 'Asia/Seoul' - interval '10 minutes'
      )::time,
      60,
      null,
      'Asia/Seoul',
      'earlier',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    ) as result
  $$,
  'a currently useful Calendar occurrence is created'
);
reset role;

set local role service_role;
insert into snooze_source_claims
select *
from public.claim_chore_notification_events(
  '65000000-0000-4000-8000-000000000011',
  100,
  60,
  pg_catalog.statement_timestamp()
);
insert into snooze_source_results
select result.*
from snooze_source_claims as claim
cross join lateral public.process_chore_notification_event(
  claim.event_id,
  claim.lease_token,
  pg_catalog.statement_timestamp()
) as result;
select is(
  (
    select pg_catalog.concat_ws(
      ':', pg_catalog.count(*), pg_catalog.min(notification_category),
      pg_catalog.min(outcome)
    )
    from snooze_source_results
  ),
  '1:calendar_event:candidate',
  'the existing source worker resolves one Calendar candidate'
);
select lives_ok(
  $$
    select *
    from public.upsert_notification_endpoint(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      '65000000-0000-4000-8000-000000000012',
      'native_push',
      'android',
      encode(decode(repeat('31', 32), 'hex'), 'base64'),
      encode(decode(repeat('32', 32), 'hex'), 'base64'),
      1,
      encode(decode(repeat('33', 32), 'hex'), 'base64'),
      'granted',
      'ko-KR',
      'Asia/Seoul',
      '0.1.0+1',
      'Flutter 3.44.7',
      '65000000-0000-4000-8000-000000000013',
      0,
      pg_catalog.statement_timestamp()
    )
  $$,
  'an Android endpoint is available to prove push rescheduling'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', claimed_count, created_count, disabled_count, stale_count
    )
    from public.materialize_chore_notification_inbox(
      100,
      pg_catalog.statement_timestamp()
    )
  ),
  '1:1:0:0',
  'the due candidate creates its original durable inbox item'
);
reset role;

set local role authenticated;
insert into snooze_inbox
select inbox_item_id, item_version, source_event_id
from public.list_notification_inbox_items_v2(
  '20000000-0000-4000-8000-000000000101',
  30,
  null,
  null
)
where category = 'calendar_event';
reset role;

-- 18-31: optimistic command, content-free source, cancellation, and replay.
set local role service_role;
insert into snooze_push_claims
select 'original', claim.*
from public.claim_notification_push_deliveries(
  '65000000-0000-4000-8000-000000000014',
  100,
  60,
  pg_catalog.statement_timestamp()
) as claim;
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', pg_catalog.count(*), pg_catalog.min(category),
      pg_catalog.min(subject_type)
    )
    from snooze_push_claims
    where claim_label = 'original'
  ),
  '1:calendar_event:calendar_occurrence',
  'the original reminder has one leased Android delivery'
);

set local role authenticated;
select is(
  (
    select pg_catalog.concat_ws(
      ':', snooze_count, snooze_max_minutes,
      (
        select pg_catalog.count(*)
        from pg_catalog.jsonb_object_keys(to_jsonb(item))
      )
    )
    from public.list_notification_inbox_items_v2(
      '20000000-0000-4000-8000-000000000101', 30, null, null
    ) as item
    where item.inbox_item_id = (select inbox_item_id from snooze_inbox)
  ),
  '0:30:16',
  'a fresh Calendar reminder exposes all fixed snooze choices in v2'
);
select is(
  (
    select pg_catalog.count(*)
    from public.list_notification_inbox_items(
      '20000000-0000-4000-8000-000000000101', 30, null, null
    ) as item
    cross join lateral pg_catalog.jsonb_object_keys(to_jsonb(item))
    limit 1
  ),
  14::bigint,
  'the v1 inbox response remains the exact 14-field N-1 contract'
);
select throws_ok(
  format(
    'select * from public.snooze_calendar_notification(%L,%L,10,%L,99)',
    '20000000-0000-4000-8000-000000000101',
    (select inbox_item_id from snooze_inbox),
    '65000000-0000-4000-8000-000000000020'
  ),
  'KNP06',
  'notification item version conflict',
  'a stale item version cannot schedule another reminder'
);
insert into snooze_receipts
select *
from public.snooze_calendar_notification(
  '20000000-0000-4000-8000-000000000101',
  (select inbox_item_id from snooze_inbox),
  10,
  '65000000-0000-4000-8000-000000000021',
  (select item_version from snooze_inbox)
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', command_id, inbox_item_id, item_version, snooze_minutes,
      snooze_count, unread_count,
      extract(epoch from (snoozed_until - recorded_at))::integer
    )
    from snooze_receipts
  ),
  (
    select pg_catalog.concat_ws(
      ':',
      '65000000-0000-4000-8000-000000000021',
      inbox_item_id,
      2,
      10,
      1,
      0,
      600
    )
    from snooze_inbox
  )::text,
  'the command returns the exact versioned ten-minute receipt'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', item.item_version, item.read_at is not null,
      item.cancellation_reason
    )
    from public.notification_inbox_items as item
    where item.id = (select inbox_item_id from snooze_inbox)
  ),
  '2:t:snoozed',
  'the original inbox item is atomically read and explicitly superseded'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', pg_catalog.count(*), pg_catalog.min(snooze_count),
      pg_catalog.min(snooze_minutes), pg_catalog.min(unread_count)
    )
    from app_private.calendar_notification_snooze_commands
  ),
  '1:1:10:0',
  'the immutable command ledger stores one bounded content-free receipt'
);
select ok(
  (
    select event.payload ?& array[
      'recipientMemberId', 'originalInboxItemId', 'localStartDate',
      'occurrenceScheduledAt', 'scheduledAt', 'snoozeMinutes',
      'snoozeCount', 'timezone', 'status'
    ]
      and event.payload - array[
        'recipientMemberId', 'originalInboxItemId', 'localStartDate',
        'occurrenceScheduledAt', 'scheduledAt', 'snoozeMinutes',
        'snoozeCount', 'timezone', 'status'
      ] = '{}'::jsonb
      and event.payload::text !~* 'Snooze fixture|Must never'
      and event.causation_id =
        '65000000-0000-4000-8000-000000000021'
    from app_private.chore_notification_outbox as event
    where event.event_id = (select source_event_id from snooze_receipts)
  ),
  'the snooze source contains only exact routing and schedule metadata'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', delivery.processing_status, delivery.last_result_code,
      evaluation.processing_status
    )
    from app_private.notification_push_deliveries as delivery
    join app_private.notification_push_evaluations as evaluation
      on evaluation.source_event_id = delivery.source_event_id
    where delivery.id = (
      select delivery_id
      from snooze_push_claims
      where claim_label = 'original'
    )
  ),
  'cancelled:LATEST_STATE_SUPPRESSED:materialized',
  'an already materialized original push is cancelled without rewriting history'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', public.get_notification_unread_count(
        '20000000-0000-4000-8000-000000000101'
      ),
      (
        select pg_catalog.count(*)
        from public.list_notification_inbox_items_v2(
          '20000000-0000-4000-8000-000000000101', 30, null, null
        )
      )
    )
  ),
  '0:0',
  'the superseded reminder immediately leaves the inbox and unread badge'
);
set local role authenticated;
select is(
  (
    select pg_catalog.concat_ws(
      ':', source_event_id, item_version, snoozed_until, unread_count
    )
    from public.snooze_calendar_notification(
      '20000000-0000-4000-8000-000000000101',
      (select inbox_item_id from snooze_inbox),
      10,
      '65000000-0000-4000-8000-000000000021',
      (select item_version from snooze_inbox)
    )
  ),
  (
    select pg_catalog.concat_ws(
      ':', source_event_id, item_version, snoozed_until, unread_count
    )
    from snooze_receipts
  )::text,
  'an identical response-loss replay returns the original receipt'
);
select throws_ok(
  format(
    'select * from public.snooze_calendar_notification(%L,%L,30,%L,%s)',
    '20000000-0000-4000-8000-000000000101',
    (select inbox_item_id from snooze_inbox),
    '65000000-0000-4000-8000-000000000021',
    (select item_version from snooze_inbox)
  ),
  'KNP06',
  'notification snooze command conflict',
  'a command id cannot be reused with different minutes'
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      (
        select pg_catalog.count(*)
        from app_private.calendar_notification_snooze_commands
      ),
      (
        select pg_catalog.count(*)
        from app_private.chore_notification_outbox
        where event_type = 'calendar.occurrence_reminder_snoozed'
      )
    )
  ),
  '1:1',
  'replay and conflict paths create no duplicate command or source event'
);
select throws_ok(
  $$
    update app_private.calendar_notification_snooze_commands
    set unread_count = 99
  $$,
  '55000',
  'calendar notification snooze commands are immutable',
  'the durable command receipt cannot be updated'
);
set local role authenticated;
select throws_ok(
  $$
    select * from public.snooze_calendar_notification(
      '20000000-0000-4000-8000-000000000101',
      '65000000-0000-4000-8000-000000000099',
      5,
      '65000000-0000-4000-8000-000000000098',
      1
    )
  $$,
  'KNS04',
  'calendar notification snooze unavailable',
  'an unavailable item is rejected without leaking its existence'
);
reset role;

-- 32-44: existing workers delay, materialize, and push the snoozed reminder.
select is(
  (
    select pg_catalog.concat_ws(
      ':', resolved.should_create_intent, resolved.notification_category,
      resolved.subject_type,
      extract(
        epoch from (resolved.due_at - receipt.recorded_at)
      )::integer
    )
    from snooze_receipts as receipt
    cross join lateral app_private.resolve_notification_event(
      receipt.source_event_id
    ) as resolved
  ),
  't:calendar_event:calendar_occurrence:600',
  'latest-state resolution preserves the explicit ten-minute schedule'
);
truncate snooze_source_claims;
truncate snooze_source_results;
set local role service_role;
insert into snooze_source_claims
select *
from public.claim_chore_notification_events(
  '65000000-0000-4000-8000-000000000030',
  100,
  60,
  pg_catalog.statement_timestamp()
);
insert into snooze_source_results
select result.*
from snooze_source_claims as claim
cross join lateral public.process_chore_notification_event(
  claim.event_id,
  claim.lease_token,
  pg_catalog.statement_timestamp()
) as result;
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', pg_catalog.count(*), pg_catalog.min(outcome),
      extract(
        epoch from (
          pg_catalog.min(result.scheduled_at) -
          pg_catalog.min(receipt.recorded_at)
        )
      )::integer
    )
    from snooze_source_results as result
    cross join snooze_receipts as receipt
  ),
  '1:candidate:600',
  'the unchanged worker persists the explicit snooze candidate schedule'
);
set local role authenticated;
select lives_ok(
  $$
    select *
    from public.update_notification_preference_v2(
      '20000000-0000-4000-8000-000000000101',
      'calendar_event', true, false, false, true,
      null, null, 'Asia/Seoul', 60, 0
    )
  $$,
  'a lead-time preference can change while snooze is pending'
);
reset role;
select is(
  (
    select extract(
      epoch from (resolution.scheduled_at - receipt.recorded_at)
    )::integer
    from app_private.notification_event_resolutions as resolution
    cross join snooze_receipts as receipt
    where resolution.source_event_id = receipt.source_event_id
  ),
  600,
  'a preference change never rewrites an explicit pending snooze'
);
set local role service_role;
select is(
  (
    select pg_catalog.concat_ws(':', claimed_count, created_count)
    from public.materialize_chore_notification_inbox(
      100,
      (select snoozed_until - interval '1 second' from snooze_receipts)
    )
  ),
  '0:0',
  'the durable inbox does not reappear before snoozed_until'
);
select is(
  (
    select pg_catalog.count(*)
    from public.claim_notification_push_deliveries(
      '65000000-0000-4000-8000-000000000031',
      100,
      60,
      (select snoozed_until - interval '1 second' from snooze_receipts)
    )
  ),
  0::bigint,
  'native push is not claimable before snoozed_until'
);
select is(
  (
    select pg_catalog.concat_ws(':', claimed_count, created_count)
    from public.materialize_chore_notification_inbox(
      100,
      (select snoozed_until from snooze_receipts)
    )
  ),
  '1:1',
  'the existing materializer resurfaces one inbox item exactly when due'
);
reset role;
set local role authenticated;
select is(
  (
    select pg_catalog.concat_ws(
      ':', pg_catalog.count(*), pg_catalog.min(snooze_count),
      pg_catalog.min(snooze_max_minutes),
      public.get_notification_unread_count(
        '20000000-0000-4000-8000-000000000101'
      )
    )
    from public.list_notification_inbox_items_v2(
      '20000000-0000-4000-8000-000000000101', 30, null, null
    )
  ),
  '1:1:30:1',
  'the resurfaced item is unread and carries its consecutive snooze count'
);
reset role;
set local role service_role;
insert into snooze_push_claims
select 'snoozed', claim.*
from public.claim_notification_push_deliveries(
  '65000000-0000-4000-8000-000000000032',
  100,
  60,
  (select snoozed_until from snooze_receipts)
) as claim;
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', pg_catalog.count(*), pg_catalog.min(category),
      pg_catalog.min(subject_type),
      pg_catalog.bool_and(inbox_item_id is not null)
    )
    from snooze_push_claims
    where claim_label = 'snoozed'
  ),
  '1:calendar_event:calendar_occurrence:t',
  'the existing reliable push queue claims the snoozed reminder once'
);
select ok(
  (
    select claim.source_event_id = receipt.source_event_id
      and claim.scheduled_at = receipt.snoozed_until
      and claim.expires_at = receipt.snoozed_until + interval '1 hour'
    from snooze_push_claims as claim
    cross join snooze_receipts as receipt
    where claim.claim_label = 'snoozed'
  ),
  'the second delivery has an independent source and one-hour usefulness window'
);
select is(
  app_private.calendar_notification_snooze_max_minutes(
    '20000000-0000-4000-8000-000000000101',
    (select occurrence_id from snooze_fixture),
    '30000000-0000-4000-8000-000000000101',
    3,
    pg_catalog.statement_timestamp()
  ),
  0,
  'the third consecutive snooze is the bounded final one'
);
select is(
  app_private.calendar_notification_snooze_max_minutes(
    '20000000-0000-4000-8000-000000000101',
    (select occurrence_id from snooze_fixture),
    '30000000-0000-4000-8000-000000000101',
    1,
    (select starts_at + interval '56 minutes' from snooze_fixture)
  ),
  0,
  'no option is offered when even five minutes exceeds the usefulness bound'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema in ('public', 'app_private')
      and table_name in (
        'chore_notification_outbox',
        'notification_inbox_items',
        'calendar_notification_snooze_commands'
      )
      and column_name in (
        'title', 'description', 'display_name', 'email_address',
        'raw_error', 'error_message', 'provider_body', 'token'
      )
  ),
  'snooze persistence adds no family content or provider secret columns'
);

-- 45-47: strict source validation and legacy behavior remain intact.
select throws_ok(
  $$
    insert into app_private.chore_notification_outbox (
      event_type, household_id, aggregate_type, aggregate_id,
      aggregate_version, audience_member_id, correlation_id, causation_id,
      payload
    )
    select
      'calendar.occurrence_reminder_snoozed',
      '20000000-0000-4000-8000-000000000101',
      'calendar_occurrence',
      fixture.occurrence_id,
      1,
      '30000000-0000-4000-8000-000000000101',
      '65000000-0000-4000-8000-000000000040',
      null,
      '{}'::jsonb
    from snooze_fixture as fixture
  $$,
  '23514',
  null,
  'a snooze source without causation and exact payload is rejected'
);
select is(
  (
    select pg_catalog.count(*)
    from app_private.chore_notification_outbox
    where event_type = 'calendar.occurrence_start_changed'
      and aggregate_id = (select occurrence_id from snooze_fixture)
  ),
  1::bigint,
  'the original Calendar source dedupe remains unchanged'
);
select * from finish();
rollback;
