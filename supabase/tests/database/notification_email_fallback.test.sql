begin;
set constraints all deferred;

select plan(68);

-- Schema, exact mediated APIs, and least-privilege boundaries.
select has_table(
  'app_private',
  'notification_email_evaluations',
  'private email source evaluation table exists'
);
select has_table(
  'app_private',
  'notification_email_deliveries',
  'private address-free email delivery table exists'
);
select has_table(
  'app_private',
  'notification_email_delivery_transitions',
  'private immutable email transition table exists'
);
select has_table(
  'app_private',
  'notification_email_worker_control',
  'private email worker kill switch exists'
);
select has_function(
  'public',
  'claim_notification_email_deliveries',
  array['uuid', 'integer', 'integer', 'timestamp with time zone'],
  'service-only email claim API exists'
);
select has_function(
  'public',
  'mark_notification_email_submission_started',
  array['uuid', 'uuid', 'timestamp with time zone'],
  'service-only email submission marker API exists'
);
select has_function(
  'public',
  'complete_notification_email_delivery',
  array[
    'uuid', 'uuid', 'text', 'text', 'text', 'integer',
    'timestamp with time zone'
  ],
  'service-only email completion API exists'
);
select has_function(
  'public',
  'set_notification_email_worker_paused',
  array['boolean', 'timestamp with time zone'],
  'service-only email pause API exists'
);
select is(
  (
    select pg_catalog.string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'notification_email_evaluations'
  ),
  'source_event_id,processing_status,next_evaluation_at,reason_code,created_at,evaluated_at',
  'email evaluation stores only source identity timing and stable outcome'
);
select is(
  (
    select pg_catalog.string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'notification_email_deliveries'
  ),
  'id,source_event_id,inbox_item_id,recipient_user_id,recipient_member_id,household_id,category,subject_type,subject_id,processing_status,attempts,max_attempts,next_attempt_at,lease_owner,lease_token,lease_expires_at,submission_started_at,submission_lease_token,last_result_code,provider_message_id_hash,completed_lease_token,completion_outcome,completed_retry_after_seconds,scheduled_at,expires_at,created_at,updated_at,completed_at',
  'email delivery exact schema contains no address or message content'
);
select is(
  (
    select pg_catalog.string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name in (
        select specific_name
        from information_schema.routines
        where routine_schema = 'public'
          and routine_name = 'claim_notification_email_deliveries'
      )
      and parameter_mode = 'OUT'
  ),
  'delivery_id,source_event_id,inbox_item_id,household_id,category,subject_type,subject_id,recipient_email,locale,attempt,max_attempts,lease_token,lease_expires_at,scheduled_at,expires_at',
  'claim response has the exact ephemeral recipient and content-free routing shape'
);
select is(
  (
    select pg_catalog.string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name in (
        select specific_name
        from information_schema.routines
        where routine_schema = 'public'
          and routine_name = 'mark_notification_email_submission_started'
      )
      and parameter_mode = 'OUT'
  ),
  'delivery_id,submission_started_at',
  'submission marker response is exact and metadata only'
);
select is(
  (
    select pg_catalog.string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name in (
        select specific_name
        from information_schema.routines
        where routine_schema = 'public'
          and routine_name = 'complete_notification_email_delivery'
      )
      and parameter_mode = 'OUT'
  ),
  'delivery_id,processing_status,attempts,max_attempts,next_attempt_at,completed_at,result_code',
  'completion response is exact and omits email and provider body'
);
select has_trigger(
  'public',
  'notification_preferences',
  'notification_preferences_wake_email_evaluations',
  'preference changes wake pending email evaluation'
);
select has_trigger(
  'app_private',
  'notification_event_resolutions',
  'notification_resolution_sync_email_schedule',
  'pending email work follows eligible source rescheduling'
);
select has_trigger(
  'app_private',
  'notification_email_deliveries',
  'notification_email_delivery_validate_subject',
  'email delivery validates Chore and Calendar subject identity'
);
select has_trigger(
  'app_private',
  'notification_email_delivery_transitions',
  'notification_email_delivery_transitions_immutable',
  'email transition history is immutable'
);
select ok(
  pg_catalog.pg_get_indexdef(
    'app_private.notification_email_deliveries_source_event_id_key'::regclass
  ) like '%source_event_id%',
  'one source event has at most one email delivery'
);
select ok(
  not pg_catalog.has_table_privilege(
    'service_role',
    'app_private.notification_email_deliveries',
    'select,insert,update,delete'
  )
    and not pg_catalog.has_table_privilege(
      'authenticated',
      'app_private.notification_email_evaluations',
      'select,insert,update,delete'
    ),
  'service and client roles cannot bypass mediated private email state'
);
select ok(
  pg_catalog.has_function_privilege(
    'service_role',
    'public.claim_notification_email_deliveries(uuid,integer,integer,timestamptz)',
    'execute'
  )
    and pg_catalog.has_function_privilege(
      'service_role',
      'public.complete_notification_email_delivery(uuid,uuid,text,text,text,integer,timestamptz)',
      'execute'
    )
    and not pg_catalog.has_function_privilege(
      'authenticated',
      'public.claim_notification_email_deliveries(uuid,integer,integer,timestamptz)',
      'execute'
    ),
  'only service role can claim and finalize email delivery'
);
select ok(
  not exists (
    select 1
    from pg_catalog.pg_proc
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname in (
        'claim_notification_email_deliveries',
        'mark_notification_email_submission_started',
        'complete_notification_email_delivery',
        'set_notification_email_worker_paused'
      )
      and (
        not pg_proc.prosecdef
        or not pg_proc.proconfig @> array['search_path=""']::text[]
      )
  ),
  'every public email API is security-definer with empty search path'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name like 'notification_email%'
      and column_name in (
        'email', 'recipient_email', 'sender_email', 'title', 'subject',
        'description', 'body', 'provider_body', 'raw_error', 'error_message',
        'token'
      )
  ),
  'email persistence excludes addresses content token provider body and raw errors'
);
select throws_ok(
  $$
    select * from public.claim_notification_email_deliveries(
      null,
      0,
      0,
      null
    )
  $$,
  'KEM01',
  'invalid notification email input',
  'email claim rejects invalid worker bounds'
);

create temporary table email_source_claims (
  event_id uuid primary key,
  lease_token uuid not null,
  attempt integer not null,
  max_attempts integer not null,
  lease_expires_at timestamptz not null
);
create temporary table email_fixtures (
  fixture_label text primary key,
  occurrence_id uuid not null
);
create temporary table email_delivery_claims (
  fixture_label text not null,
  delivery_id uuid not null,
  source_event_id uuid not null,
  inbox_item_id uuid,
  household_id uuid not null,
  category text not null,
  subject_type text not null,
  subject_id uuid not null,
  recipient_email text not null,
  locale text not null,
  attempt integer not null,
  max_attempts integer not null,
  lease_token uuid not null,
  lease_expires_at timestamptz not null,
  scheduled_at timestamptz not null,
  expires_at timestamptz not null
);
create temporary table email_retry_schedule (
  fixture_label text primary key,
  next_attempt_at timestamptz not null
);
grant all on table email_source_claims to service_role;
grant all on table email_delivery_claims to service_role;
grant all on table email_retry_schedule to service_role;

-- A confirmed recipient can opt into generic email independently of inbox/push.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
set local role authenticated;
select is(
  (
    select pg_catalog.concat_ws(':', email, native_push, in_app, version)
    from public.update_notification_preference(
      '20000000-0000-4000-8000-000000000101',
      'chore_assignment',
      false,
      false,
      true,
      false,
      null,
      null,
      'Asia/Seoul',
      0
    )
  ),
  't:f:f:1',
  'assignment email can be enabled while inbox and native push remain disabled'
);
reset role;

select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    insert into email_fixtures
    select 'accepted', result.occurrence_id
    from public.create_one_time_chore(
      '5e010000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Private email fixture title one',
      'Never copied into email one',
      '30000000-0000-4000-8000-000000000102',
      '2030-01-02',
      time '09:15'
    ) as result
  $$,
  'assigned Chore emits source events without adding email content'
);

set local role service_role;
insert into email_source_claims
select * from public.claim_chore_notification_events(
  '5e020000-0000-4000-8000-000000000001',
  10,
  60,
  pg_catalog.statement_timestamp()
);
reset role;
select is(
  (select pg_catalog.count(*) from email_source_claims),
  2::bigint,
  'source worker leases assignment and due events independently'
);
set local role service_role;
select lives_ok(
  $$
    select public.process_chore_notification_event(
      claim.event_id,
      claim.lease_token,
      pg_catalog.statement_timestamp()
    )
    from email_source_claims as claim
  $$,
  'content-free source events resolve before email evaluation'
);
insert into email_delivery_claims
select 'accepted', claim.*
from public.claim_notification_email_deliveries(
  '5e030000-0000-4000-8000-000000000001',
  10,
  60,
  pg_catalog.statement_timestamp() + interval '1 second'
) as claim;
reset role;
select is(
  (select pg_catalog.count(*) from email_delivery_claims),
  1::bigint,
  'one enabled assignment email is claimed'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', category, subject_type, inbox_item_id is null,
      recipient_email, locale, attempt, max_attempts
    )
    from email_delivery_claims
    where fixture_label = 'accepted'
  ),
  'chore_assignment:chore_occurrence:t:adult-b@local.kinflow.invalid:ko:1:5',
  'claim returns one ephemeral confirmed address and latest locale only'
);
select ok(
  (
    select delivery.expires_at > delivery.scheduled_at
      and delivery.expires_at <= delivery.scheduled_at + interval '1 hour'
    from app_private.notification_email_deliveries as delivery
    where delivery.id = (
      select delivery_id
      from email_delivery_claims
      where fixture_label = 'accepted'
    )
  ),
  'delivery has a bounded one-hour usefulness window'
);

set local role service_role;
select is(
  (
    select pg_catalog.count(*)
    from public.claim_notification_email_deliveries(
      '5e030000-0000-4000-8000-000000000002',
      10,
      60,
      pg_catalog.statement_timestamp() + interval '2 seconds'
    )
  ),
  0::bigint,
  'a live email lease prevents duplicate provider work'
);
select is(
  (
    select pg_catalog.concat_ws(':', delivery_id, submission_started_at is not null)
    from public.mark_notification_email_submission_started(
      (select delivery_id from email_delivery_claims where fixture_label = 'accepted'),
      (select lease_token from email_delivery_claims where fixture_label = 'accepted'),
      pg_catalog.statement_timestamp() + interval '3 seconds'
    )
  ),
  (
    select pg_catalog.concat_ws(':', delivery_id, true)
    from email_delivery_claims
    where fixture_label = 'accepted'
  ),
  'provider submission is durably marked before network I/O'
);
select is(
  (
    select pg_catalog.count(*)
    from public.mark_notification_email_submission_started(
      (select delivery_id from email_delivery_claims where fixture_label = 'accepted'),
      (select lease_token from email_delivery_claims where fixture_label = 'accepted'),
      pg_catalog.statement_timestamp() + interval '4 seconds'
    )
  ),
  1::bigint,
  'same-lease submission marker replay is idempotent'
);
reset role;
select is(
  (
    select pg_catalog.count(*)
    from app_private.notification_email_delivery_transitions
    where delivery_id = (
      select delivery_id from email_delivery_claims where fixture_label = 'accepted'
    )
      and transition = 'submission_started'
  ),
  1::bigint,
  'submission marker replay creates one immutable transition'
);
set local role service_role;
select is(
  (
    select pg_catalog.concat_ws(':', processing_status, attempts, result_code)
    from public.complete_notification_email_delivery(
      (select delivery_id from email_delivery_claims where fixture_label = 'accepted'),
      (select lease_token from email_delivery_claims where fixture_label = 'accepted'),
      'accepted',
      'EMAIL_ACCEPTED',
      pg_catalog.encode(pg_catalog.decode(repeat('ab', 32), 'hex'), 'base64'),
      null,
      pg_catalog.statement_timestamp() + interval '5 seconds'
    )
  ),
  'succeeded:1:EMAIL_ACCEPTED',
  'SendGrid accepted outcome finalizes one delivery'
);
select is(
  (
    select pg_catalog.concat_ws(':', processing_status, attempts, result_code)
    from public.complete_notification_email_delivery(
      (select delivery_id from email_delivery_claims where fixture_label = 'accepted'),
      (select lease_token from email_delivery_claims where fixture_label = 'accepted'),
      'accepted',
      'EMAIL_ACCEPTED',
      pg_catalog.encode(pg_catalog.decode(repeat('ab', 32), 'hex'), 'base64'),
      null,
      pg_catalog.statement_timestamp() + interval '6 seconds'
    )
  ),
  'succeeded:1:EMAIL_ACCEPTED',
  'accepted completion response-loss replay returns the same state'
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', pg_catalog.octet_length(provider_message_id_hash),
      provider_message_id_hash = pg_catalog.decode(repeat('ab', 32), 'hex')
    )
    from app_private.notification_email_deliveries
    where id = (
      select delivery_id from email_delivery_claims where fixture_label = 'accepted'
    )
  ),
  '32:t',
  'only the optional provider message ID hash is persisted'
);
select is(
  (
    select pg_catalog.count(*)
    from app_private.notification_email_deliveries
    where source_event_id = (
      select source_event_id
      from email_delivery_claims
      where fixture_label = 'accepted'
    )
  ),
  1::bigint,
  'source replay cannot create a second email delivery'
);

-- Default OFF and unconfirmed address fail without provider delivery.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    insert into email_fixtures
    select 'disabled', result.occurrence_id
    from public.create_one_time_chore(
      '5e010000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      'Private disabled fixture',
      null,
      '30000000-0000-4000-8000-000000000101',
      '2030-01-03',
      time '09:15'
    ) as result
  $$,
  'default-off recipient source is created'
);
truncate table email_source_claims;
set local role service_role;
insert into email_source_claims
select * from public.claim_chore_notification_events(
  '5e020000-0000-4000-8000-000000000002',
  10,
  60,
  pg_catalog.statement_timestamp()
);
select public.process_chore_notification_event(
  claim.event_id,
  claim.lease_token,
  pg_catalog.statement_timestamp()
)
from email_source_claims as claim;
select is(
  (
    select pg_catalog.count(*)
    from public.claim_notification_email_deliveries(
      '5e030000-0000-4000-8000-000000000003',
      20,
      60,
      pg_catalog.statement_timestamp() + interval '1 second'
    )
  ),
  0::bigint,
  'default-off email produces no provider claim'
);
reset role;
select is(
  (
    select evaluation.processing_status || ':' || evaluation.reason_code
    from app_private.notification_email_evaluations as evaluation
    join app_private.chore_notification_outbox as event
      on event.event_id = evaluation.source_event_id
    where event.aggregate_id = (
      select occurrence_id from email_fixtures where fixture_label = 'disabled'
    )
      and event.event_type = 'chore.occurrence_assigned'
  ),
  'disabled:EMAIL_DISABLED',
  'default-off choice is a stable independent evaluation outcome'
);

set local role authenticated;
select is(
  (
    select version
    from public.update_notification_preference(
      '20000000-0000-4000-8000-000000000101',
      'chore_assignment',
      false,
      false,
      true,
      false,
      null,
      null,
      'Asia/Seoul',
      0
    )
  ),
  1::bigint,
  'owner enables assignment email without another channel'
);
reset role;
update auth.users
set email_confirmed_at = null
where id = '00000000-0000-4000-8000-000000000101';

select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    insert into email_fixtures
    select 'unconfirmed', result.occurrence_id
    from public.create_one_time_chore(
      '5e010000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      'Private unconfirmed fixture',
      null,
      '30000000-0000-4000-8000-000000000101',
      '2030-01-04',
      time '09:15'
    ) as result
  $$,
  'unconfirmed recipient source is created'
);
truncate table email_source_claims;
set local role service_role;
insert into email_source_claims
select * from public.claim_chore_notification_events(
  '5e020000-0000-4000-8000-000000000003',
  10,
  60,
  pg_catalog.statement_timestamp()
);
select public.process_chore_notification_event(
  claim.event_id,
  claim.lease_token,
  pg_catalog.statement_timestamp()
)
from email_source_claims as claim;
select is(
  (
    select pg_catalog.count(*)
    from public.claim_notification_email_deliveries(
      '5e030000-0000-4000-8000-000000000004',
      20,
      60,
      pg_catalog.statement_timestamp() + interval '1 second'
    )
  ),
  0::bigint,
  'unconfirmed Auth address produces no provider claim'
);
reset role;
select is(
  (
    select evaluation.processing_status || ':' || evaluation.reason_code
    from app_private.notification_email_evaluations as evaluation
    join app_private.chore_notification_outbox as event
      on event.event_id = evaluation.source_event_id
    where event.aggregate_id = (
      select occurrence_id from email_fixtures where fixture_label = 'unconfirmed'
    )
      and event.event_type = 'chore.occurrence_assigned'
  ),
  'no_address:NO_CONFIRMED_EMAIL',
  'unconfirmed address is retained only as a stable metadata outcome'
);
update auth.users
set email_confirmed_at = pg_catalog.statement_timestamp()
where id = '00000000-0000-4000-8000-000000000101';

-- Explicit provider retry is bounded and completion is exactly replayable.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    insert into email_fixtures
    select 'retry', result.occurrence_id
    from public.create_one_time_chore(
      '5e010000-0000-4000-8000-000000000004',
      '20000000-0000-4000-8000-000000000101',
      'Private retry fixture',
      null,
      '30000000-0000-4000-8000-000000000101',
      '2030-01-05',
      time '09:15'
    ) as result
  $$,
  'retry fixture source is created'
);
truncate table email_source_claims;
set local role service_role;
insert into email_source_claims
select * from public.claim_chore_notification_events(
  '5e020000-0000-4000-8000-000000000004',
  10,
  60,
  pg_catalog.statement_timestamp()
);
select public.process_chore_notification_event(
  claim.event_id,
  claim.lease_token,
  pg_catalog.statement_timestamp()
)
from email_source_claims as claim;
insert into email_delivery_claims
select 'retry-1', claim.*
from public.claim_notification_email_deliveries(
  '5e030000-0000-4000-8000-000000000005',
  20,
  60,
  pg_catalog.statement_timestamp() + interval '1 second'
) as claim;
select is(
  (
    select attempt
    from email_delivery_claims
    where fixture_label = 'retry-1'
  ),
  1,
  'retry fixture receives its first exact lease'
);
select lives_ok(
  $$
    select * from public.mark_notification_email_submission_started(
      (select delivery_id from email_delivery_claims where fixture_label = 'retry-1'),
      (select lease_token from email_delivery_claims where fixture_label = 'retry-1'),
      pg_catalog.statement_timestamp() + interval '2 seconds'
    )
  $$,
  'retry fixture marks its first submission'
);
insert into email_retry_schedule (fixture_label, next_attempt_at)
select 'retry', next_attempt_at
from public.complete_notification_email_delivery(
  (select delivery_id from email_delivery_claims where fixture_label = 'retry-1'),
  (select lease_token from email_delivery_claims where fixture_label = 'retry-1'),
  'retryable',
  'EMAIL_RATE_LIMITED',
  null,
  60,
  pg_catalog.statement_timestamp() + interval '3 seconds'
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', processing_status, attempts, last_result_code,
      completed_at is null
    )
    from app_private.notification_email_deliveries
    where id = (
      select delivery_id from email_delivery_claims where fixture_label = 'retry-1'
    )
  ),
  'retry_wait:1:EMAIL_RATE_LIMITED:t',
  'explicit rate limit schedules a bounded retry without a completed timestamp'
);
set local role service_role;
select is(
  (
    select processing_status || ':' || result_code
    from public.complete_notification_email_delivery(
      (select delivery_id from email_delivery_claims where fixture_label = 'retry-1'),
      (select lease_token from email_delivery_claims where fixture_label = 'retry-1'),
      'retryable',
      'EMAIL_RATE_LIMITED',
      null,
      60,
      pg_catalog.statement_timestamp() + interval '4 seconds'
    )
  ),
  'retry_wait:EMAIL_RATE_LIMITED',
  'retry completion replay returns the existing schedule'
);
select is(
  (
    select pg_catalog.count(*)
    from public.claim_notification_email_deliveries(
      '5e030000-0000-4000-8000-000000000006',
      20,
      60,
      (select next_attempt_at - interval '1 second'
       from email_retry_schedule where fixture_label = 'retry')
    )
  ),
  0::bigint,
  'retry cannot be claimed before its authoritative schedule'
);
insert into email_delivery_claims
select 'retry-2', claim.*
from public.claim_notification_email_deliveries(
  '5e030000-0000-4000-8000-000000000007',
  20,
  60,
  (select next_attempt_at
   from email_retry_schedule where fixture_label = 'retry')
) as claim;
select is(
  (
    select attempt
    from email_delivery_claims
    where fixture_label = 'retry-2'
  ),
  2,
  'due retry receives a new second-attempt lease'
);
select lives_ok(
  $$
    select * from public.mark_notification_email_submission_started(
      (select delivery_id from email_delivery_claims where fixture_label = 'retry-2'),
      (select lease_token from email_delivery_claims where fixture_label = 'retry-2'),
      pg_catalog.statement_timestamp() + interval '70 seconds'
    )
  $$,
  'second attempt receives a distinct submission marker'
);
select is(
  (
    select processing_status || ':' || result_code
    from public.complete_notification_email_delivery(
      (select delivery_id from email_delivery_claims where fixture_label = 'retry-2'),
      (select lease_token from email_delivery_claims where fixture_label = 'retry-2'),
      'permanent',
      'EMAIL_AUTH_REJECTED',
      null,
      null,
      pg_catalog.statement_timestamp() + interval '71 seconds'
    )
  ),
  'failed:EMAIL_AUTH_REJECTED',
  'explicit provider authentication rejection is terminal'
);
reset role;

-- A marked lease expiry is ambiguous and never automatically resent.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    insert into email_fixtures
    select 'ambiguous', result.occurrence_id
    from public.create_one_time_chore(
      '5e010000-0000-4000-8000-000000000005',
      '20000000-0000-4000-8000-000000000101',
      'Private ambiguity fixture',
      null,
      '30000000-0000-4000-8000-000000000101',
      '2030-01-06',
      time '09:15'
    ) as result
  $$,
  'ambiguity fixture source is created'
);
truncate table email_source_claims;
set local role service_role;
insert into email_source_claims
select * from public.claim_chore_notification_events(
  '5e020000-0000-4000-8000-000000000005',
  10,
  60,
  pg_catalog.statement_timestamp()
);
select public.process_chore_notification_event(
  claim.event_id,
  claim.lease_token,
  pg_catalog.statement_timestamp()
)
from email_source_claims as claim;
insert into email_delivery_claims
select 'ambiguous', claim.*
from public.claim_notification_email_deliveries(
  '5e030000-0000-4000-8000-000000000008',
  20,
  60,
  pg_catalog.statement_timestamp() + interval '1 second'
) as claim;
select lives_ok(
  $$
    select * from public.mark_notification_email_submission_started(
      (select delivery_id from email_delivery_claims where fixture_label = 'ambiguous'),
      (select lease_token from email_delivery_claims where fixture_label = 'ambiguous'),
      pg_catalog.statement_timestamp() + interval '2 seconds'
    )
  $$,
  'ambiguity fixture durably marks provider submission'
);
select is(
  (
    select pg_catalog.count(*)
    from public.claim_notification_email_deliveries(
      '5e030000-0000-4000-8000-000000000009',
      20,
      60,
      (
        select lease_expires_at + interval '1 second'
        from email_delivery_claims
        where fixture_label = 'ambiguous'
      )
    )
  ),
  0::bigint,
  'marked expired lease is not automatically reclaimed'
);
reset role;
select is(
  (
    select processing_status || ':' || last_result_code || ':' || completion_outcome
    from app_private.notification_email_deliveries
    where id = (
      select delivery_id from email_delivery_claims where fixture_label = 'ambiguous'
    )
  ),
  'failed:EMAIL_SUBMISSION_AMBIGUOUS:ambiguous',
  'response ambiguity is terminally quarantined'
);

-- Recipient quiet hours defer within the window; pause and latest state remain authoritative.
select pg_catalog.set_config(
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
      'chore_assignment',
      false,
      false,
      true,
      false,
      time '22:00',
      time '23:00',
      'Asia/Seoul',
      1
    )
  ),
  2::bigint,
  'recipient configures a one-hour quiet interval for email'
);
reset role;
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
insert into email_fixtures
select 'quiet', result.occurrence_id
from public.create_one_time_chore(
  '5e010000-0000-4000-8000-000000000006',
  '20000000-0000-4000-8000-000000000101',
  'Private quiet fixture',
  null,
  '30000000-0000-4000-8000-000000000102',
  '2030-01-07',
  time '09:15'
) as result;
truncate table email_source_claims;
set local role service_role;
insert into email_source_claims
select * from public.claim_chore_notification_events(
  '5e020000-0000-4000-8000-000000000006',
  10,
  60,
  pg_catalog.statement_timestamp()
);
select public.process_chore_notification_event(
  claim.event_id,
  claim.lease_token,
  pg_catalog.statement_timestamp()
)
from email_source_claims as claim;
reset role;
update app_private.notification_event_resolutions as resolution
set scheduled_at = '2030-01-01 13:30:00+00'
from app_private.chore_notification_outbox as event
where event.event_id = resolution.source_event_id
  and event.aggregate_id = (
    select occurrence_id from email_fixtures where fixture_label = 'quiet'
  )
  and event.event_type = 'chore.occurrence_assigned';
set local role service_role;
select is(
  (
    select pg_catalog.count(*)
    from public.claim_notification_email_deliveries(
      '5e030000-0000-4000-8000-000000000010',
      20,
      60,
      '2030-01-01 13:30:00+00'
    )
  ),
  0::bigint,
  'quiet interval prevents an immediate email lease'
);
reset role;
select is(
  (
    select next_evaluation_at
    from app_private.notification_email_evaluations as evaluation
    join app_private.chore_notification_outbox as event
      on event.event_id = evaluation.source_event_id
    where event.aggregate_id = (
      select occurrence_id from email_fixtures where fixture_label = 'quiet'
    )
      and event.event_type = 'chore.occurrence_assigned'
  ),
  '2030-01-01 14:00:00+00'::timestamptz,
  'quiet end resolves deterministically to 23:00 Asia/Seoul'
);
set local role service_role;
insert into email_delivery_claims
select 'quiet', claim.*
from public.claim_notification_email_deliveries(
  '5e030000-0000-4000-8000-000000000011',
  20,
  60,
  '2030-01-01 14:00:00+00'
) as claim;
reset role;
select is(
  (
    select pg_catalog.concat_ws(':', attempt, scheduled_at, expires_at)
    from email_delivery_claims
    where fixture_label = 'quiet'
  ),
  '1:2030-01-01 14:00:00+00:2030-01-01 14:30:00+00',
  'email is claimed at quiet end while retaining the source usefulness bound'
);

set local role service_role;
select is(
  (
    select paused || ':' || reason_code
    from public.set_notification_email_worker_paused(
      true,
      '2030-01-01 14:00:01+00'
    )
  ),
  'true:ROLLBACK_DISABLED',
  'service kill switch pauses new email claims'
);
select is(
  (
    select pg_catalog.count(*)
    from public.claim_notification_email_deliveries(
      '5e030000-0000-4000-8000-000000000012',
      20,
      60,
      '2030-01-01 14:00:02+00'
    )
  ),
  0::bigint,
  'paused worker performs no additional provider work'
);
select is(
  (
    select paused || ':' || (reason_code is null)
    from public.set_notification_email_worker_paused(
      false,
      '2030-01-01 14:00:03+00'
    )
  ),
  'false:true',
  'service kill switch resumes without altering queued history'
);
select is(
  (
    select processing_status || ':' || result_code
    from public.complete_notification_email_delivery(
      (select delivery_id from email_delivery_claims where fixture_label = 'quiet'),
      (select lease_token from email_delivery_claims where fixture_label = 'quiet'),
      'retryable',
      'EMAIL_PROVIDER_UNAVAILABLE',
      null,
      60,
      '2030-01-01 14:00:04+00'
    )
  ),
  'retry_wait:EMAIL_PROVIDER_UNAVAILABLE',
  'pre-network marker failure can defer safely without provider submission'
);
reset role;

-- Address and identity columns remain immutable even to an owner connection.
select throws_ok(
  $$
    update app_private.notification_email_deliveries
    set recipient_user_id = '00000000-0000-4000-8000-000000000201'
    where id = (
      select delivery_id from email_delivery_claims where fixture_label = 'quiet'
    )
  $$,
  '55000',
  'notification email delivery identity is immutable',
  'delivery recipient identity cannot be rewritten'
);
select throws_ok(
  $$
    update app_private.notification_email_delivery_transitions
    set result_code = 'EMAIL_REQUEST_REJECTED'
    where id = (
      select pg_catalog.min(id)
      from app_private.notification_email_delivery_transitions
    )
  $$,
  '55000',
  'notification email transition history is immutable',
  'email transition audit cannot be rewritten'
);

select * from finish();
rollback;
