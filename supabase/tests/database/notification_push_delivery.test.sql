begin;
set constraints all deferred;

select plan(48);

-- Schema, mediated APIs, and least-privilege boundaries.
select has_table(
  'app_private',
  'notification_push_evaluations',
  'private push source evaluation table exists'
);
select has_table(
  'app_private',
  'notification_push_deliveries',
  'private per-endpoint push delivery table exists'
);
select has_table(
  'app_private',
  'notification_push_worker_control',
  'private Android push kill switch exists'
);
select has_function(
  'public',
  'claim_notification_push_deliveries',
  array['uuid', 'integer', 'integer', 'timestamp with time zone'],
  'service-only push claim API exists'
);
select has_function(
  'public',
  'complete_notification_push_delivery',
  array[
    'uuid', 'uuid', 'text', 'text', 'text', 'text', 'integer',
    'timestamp with time zone'
  ],
  'service-only provider completion API exists'
);
select has_function(
  'public',
  'resolve_notification_push_target',
  array['uuid', 'uuid', 'uuid'],
  'authenticated push tap authorization API exists'
);
select is(
  (
    select string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'notification_push_evaluations'
  ),
  'source_event_id,processing_status,next_evaluation_at,reason_code,created_at,evaluated_at',
  'push evaluation state contains only source identity timing and stable outcome'
);
select is(
  (
    select string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name in (
        select specific_name
        from information_schema.routines
        where routine_schema = 'public'
          and routine_name = 'claim_notification_push_deliveries'
      )
      and parameter_mode = 'OUT'
  ),
  'delivery_id,source_event_id,inbox_item_id,endpoint_id,household_id,category,subject_type,subject_id,token_ciphertext_base64,token_fingerprint_base64,token_key_version,locale,attempt,max_attempts,lease_token,lease_expires_at,scheduled_at,expires_at',
  'claim response has exact private provider material and content-free routing keys'
);
select is(
  (
    select string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name like 'resolve_notification_push_target_%'
      and parameter_mode = 'OUT'
  ),
  'delivery_id,household_id,category,subject_type,subject_id,inbox_item_id,safe_destination',
  'client target response omits token receipt and provider state'
);
select has_trigger(
  'public',
  'notification_preferences',
  'notification_preferences_wake_push_evaluations',
  'preference changes wake pending delivery timing for reevaluation'
);
select ok(
  pg_get_indexdef(
    'app_private.notification_push_deliveries_source_event_id_endpoint_id_key'::regclass
  ) like '%source_event_id, endpoint_id%',
  'one source event has at most one delivery per endpoint'
);
select ok(
  not has_table_privilege(
    'service_role',
    'app_private.notification_push_deliveries',
    'select,insert,update,delete'
  )
    and not has_table_privilege(
      'authenticated',
      'app_private.notification_push_evaluations',
      'select,insert,update,delete'
    ),
  'service and client roles cannot bypass mediated private push state'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.claim_notification_push_deliveries(uuid,integer,integer,timestamptz)',
    'execute'
  )
    and has_function_privilege(
      'service_role',
      'public.complete_notification_push_delivery(uuid,uuid,text,text,text,text,integer,timestamptz)',
      'execute'
    )
    and not has_function_privilege(
      'authenticated',
      'public.claim_notification_push_deliveries(uuid,integer,integer,timestamptz)',
      'execute'
    ),
  'only service role can claim and finalize provider delivery'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.resolve_notification_push_target(uuid,uuid,uuid)',
    'execute'
  )
    and not has_function_privilege(
      'anon',
      'public.resolve_notification_push_target(uuid,uuid,uuid)',
      'execute'
    ),
  'only authenticated users can authorize a push tap target'
);
select ok(
  not exists (
    select 1
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname in (
        'claim_notification_push_deliveries',
        'complete_notification_push_delivery',
        'resolve_notification_push_target',
        'set_notification_push_worker_paused'
      )
      and (
        not pg_proc.prosecdef
        or not pg_proc.proconfig @> array['search_path=""']::text[]
      )
  ),
  'every public push API is security-definer with an empty search path'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name in (
        'notification_push_evaluations',
        'notification_push_deliveries'
      )
      and column_name in (
        'title', 'description', 'display_name', 'email', 'provider_body',
        'raw_error', 'error_message', 'token'
      )
  ),
  'push persistence excludes household content identity text raw token and provider body'
);

create temporary table push_endpoint_results (
  endpoint_id uuid not null,
  household_id uuid not null,
  member_id uuid not null,
  installation_id uuid not null,
  channel text not null,
  platform text not null,
  permission_state text not null,
  locale text,
  timezone text not null,
  app_version text not null,
  runtime_version text not null,
  last_registration_id uuid not null,
  last_seen_at timestamptz not null,
  revoked_at timestamptz,
  revocation_reason text,
  version bigint not null
);
create temporary table push_source_claims (
  event_id uuid primary key,
  lease_token uuid not null,
  attempt integer not null,
  max_attempts integer not null,
  lease_expires_at timestamptz not null
);
create temporary table push_delivery_claims (
  fixture_label text not null,
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
grant all on table push_endpoint_results to service_role;
grant all on table push_source_claims to service_role;
grant all on table push_delivery_claims to service_role;
grant select on table push_delivery_claims to authenticated;

-- Register one Android endpoint for the assignee.
set local role service_role;
insert into push_endpoint_results
select *
from public.upsert_notification_endpoint(
  '00000000-0000-4000-8000-000000000102',
  '20000000-0000-4000-8000-000000000101',
  '54000000-0000-4000-8000-000000000001',
  'native_push',
  'android',
  encode(decode(repeat('11', 32), 'hex'), 'base64'),
  encode(decode(repeat('12', 32), 'hex'), 'base64'),
  1,
  encode(decode(repeat('13', 32), 'hex'), 'base64'),
  'granted',
  'ko-KR',
  'Asia/Seoul',
  '0.1.0+1',
  'Flutter 3.44.7',
  '54010000-0000-4000-8000-000000000001',
  0,
  '2026-08-08 00:00:00+00'
);
reset role;
select is(
  (select concat_ws(':', platform, permission_state, version)
   from push_endpoint_results),
  'android:granted:1',
  'active Android endpoint fixture is registered'
);

-- Native push remains independent when the durable in-app channel is off.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
set local role authenticated;
select is(
  (
    select concat_ws(':', native_push, in_app, version)
    from public.update_notification_preference(
      '20000000-0000-4000-8000-000000000101',
      'chore_assignment',
      true,
      false,
      false,
      false,
      null,
      null,
      'Asia/Seoul',
      0
    )
  ),
  't:f:1',
  'assignment native push can be enabled while in-app is disabled'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '54020000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Private fixture title one',
      'Never copied into provider state one',
      '30000000-0000-4000-8000-000000000102',
      '2030-01-02',
      time '09:15'
    )
  $$,
  'first assigned chore emits notification source events'
);

set local role service_role;
insert into push_source_claims
select * from public.claim_chore_notification_events(
  '54030000-0000-4000-8000-000000000001',
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
    from push_source_claims as claim
  $$,
  'first chore source events resolve to latest state'
);
select lives_ok(
  $$
    select * from public.materialize_chore_notification_inbox(
      10,
      pg_catalog.statement_timestamp()
    )
  $$,
  'inbox materializer independently records the disabled in-app outcome'
);
insert into push_delivery_claims
select 'first', claim.*
from public.claim_notification_push_deliveries(
  '54040000-0000-4000-8000-000000000001',
  10,
  60,
  '2030-01-01 00:00:00+00'
) as claim;
reset role;
select is(
  (
    select concat_ws(
      ':', category, inbox_item_id is null, attempt, max_attempts,
      token_key_version, locale
    )
    from push_delivery_claims
    where fixture_label = 'first'
  ),
  'chore_assignment:t:1:5:1:ko-KR',
  'native push materializes without an in-app item and returns bounded provider material'
);
select is(
  (
    select concat_ws(
      ':',
      token_ciphertext_base64 = encode(decode(repeat('11', 32), 'hex'), 'base64'),
      token_fingerprint_base64 = encode(decode(repeat('12', 32), 'hex'), 'base64')
    )
    from push_delivery_claims
    where fixture_label = 'first'
  ),
  't:t',
  'claim binds the exact sealed token envelope and fingerprint snapshot'
);
select is(
  (
    select count(*)
    from app_private.notification_inbox_evaluations as evaluation
    join app_private.notification_event_resolutions as resolution
      on resolution.source_event_id = evaluation.source_event_id
    where resolution.notification_category = 'chore_assignment'
      and evaluation.outcome = 'disabled'
  ),
  1::bigint,
  'in-app disabled remains independently durable from successful push materialization'
);

set local role service_role;
select is(
  (
    select count(*)
    from public.claim_notification_push_deliveries(
      '54040000-0000-4000-8000-000000000002',
      10,
      60,
      '2030-01-01 00:00:01+00'
    )
  ),
  0::bigint,
  'a live lease prevents a duplicate provider attempt'
);
select is(
  (
    select concat_ws(
      ':', processing_status, attempts, result_code, endpoint_invalidated
    )
    from public.complete_notification_push_delivery(
      (select delivery_id from push_delivery_claims where fixture_label = 'first'),
      (select lease_token from push_delivery_claims where fixture_label = 'first'),
      encode(decode(repeat('12', 32), 'hex'), 'base64'),
      'accepted',
      'FCM_ACCEPTED',
      encode(decode(repeat('aa', 32), 'hex'), 'base64'),
      null,
      '2030-01-01 00:00:02+00'
    )
  ),
  'succeeded:1:FCM_ACCEPTED:f',
  'accepted provider receipt finalizes one delivery'
);
select is(
  (
    select concat_ws(
      ':', processing_status, attempts, result_code, endpoint_invalidated
    )
    from public.complete_notification_push_delivery(
      (select delivery_id from push_delivery_claims where fixture_label = 'first'),
      (select lease_token from push_delivery_claims where fixture_label = 'first'),
      encode(decode(repeat('12', 32), 'hex'), 'base64'),
      'accepted',
      'FCM_ACCEPTED',
      encode(decode(repeat('aa', 32), 'hex'), 'base64'),
      null,
      '2030-01-01 00:00:03+00'
    )
  ),
  'succeeded:1:FCM_ACCEPTED:f',
  'response-loss completion replay returns the existing receipt state'
);
reset role;
select is(
  (
    select concat_ws(
      ':', octet_length(provider_receipt_hash), provider_receipt_hash = decode(repeat('aa', 32), 'hex')
    )
    from app_private.notification_push_deliveries
    where id = (
      select delivery_id from push_delivery_claims where fixture_label = 'first'
    )
  ),
  '32:t',
  'only the 256-bit provider receipt hash is persisted'
);

-- Tap authorization binds the current authenticated recipient and latest state.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
set local role authenticated;
select is(
  (
    select concat_ws(':', category, inbox_item_id is null, safe_destination)
    from public.resolve_notification_push_target(
      (select delivery_id from push_delivery_claims where fixture_label = 'first'),
      '20000000-0000-4000-8000-000000000101',
      (select subject_id from push_delivery_claims where fixture_label = 'first')
    )
  ),
  'chore_assignment:t:chore_occurrence',
  'recipient can authorize the content-free push target without an inbox item'
);
reset role;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
set local role authenticated;
select is(
  (
    select count(*)
    from public.resolve_notification_push_target(
      (select delivery_id from push_delivery_claims where fixture_label = 'first'),
      '20000000-0000-4000-8000-000000000101',
      (select subject_id from push_delivery_claims where fixture_label = 'first')
    )
  ),
  0::bigint,
  'another household member cannot authorize the recipient push target'
);
reset role;

-- Quiet hours are re-evaluated immediately before provider claim.
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
      'chore_assignment',
      true,
      false,
      false,
      false,
      time '22:00',
      time '07:00',
      'Asia/Seoul',
      1
    )
  ),
  2::bigint,
  'assignment quiet hours update advances the preference version'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '54020000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      'Private fixture title two',
      'Never copied into provider state two',
      '30000000-0000-4000-8000-000000000102',
      '2030-01-03',
      time '09:15'
    )
  $$,
  'second assigned chore emits notification source events'
);

truncate table push_source_claims;
set local role service_role;
insert into push_source_claims
select * from public.claim_chore_notification_events(
  '54030000-0000-4000-8000-000000000002',
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
    from push_source_claims as claim
  $$,
  'second chore source events resolve to latest state'
);
select is(
  (
    select count(*)
    from public.claim_notification_push_deliveries(
      '54040000-0000-4000-8000-000000000003',
      10,
      60,
      '2030-01-01 14:30:00+00'
    )
  ),
  0::bigint,
  'quiet interval suppresses the immediate provider claim'
);
reset role;
select is(
  (
    select next_evaluation_at
    from app_private.notification_push_evaluations as evaluation
    join app_private.notification_event_resolutions as resolution
      on resolution.source_event_id = evaluation.source_event_id
    where resolution.notification_category = 'chore_assignment'
      and resolution.subject_id <> (
        select subject_id from push_delivery_claims where fixture_label = 'first'
      )
  ),
  '2030-01-01 22:00:00+00'::timestamptz,
  'quiet interval records the deterministic recipient-local wake instant'
);
set local role service_role;
insert into push_delivery_claims
select 'second', claim.*
from public.claim_notification_push_deliveries(
  '54040000-0000-4000-8000-000000000004',
  10,
  60,
  '2030-01-01 22:00:00+00'
) as claim;
reset role;
select is(
  (
    select concat_ws(':', category, attempt)
    from push_delivery_claims where fixture_label = 'second'
  ),
  'chore_assignment:1',
  'delivery becomes claimable exactly when quiet hours end'
);

-- A late invalid-token result for rotated material retries instead of revoking.
set local role service_role;
insert into push_endpoint_results
select *
from public.upsert_notification_endpoint(
  '00000000-0000-4000-8000-000000000102',
  '20000000-0000-4000-8000-000000000101',
  '54000000-0000-4000-8000-000000000001',
  'native_push',
  'android',
  encode(decode(repeat('21', 32), 'hex'), 'base64'),
  encode(decode(repeat('22', 32), 'hex'), 'base64'),
  2,
  encode(decode(repeat('23', 32), 'hex'), 'base64'),
  'granted',
  'ko-KR',
  'Asia/Seoul',
  '0.1.1+2',
  'Flutter 3.44.7',
  '54010000-0000-4000-8000-000000000002',
  1,
  '2030-01-01 22:00:01+00'
);
select is(
  (
    select concat_ws(':', processing_status, attempts, result_code, endpoint_invalidated)
    from public.complete_notification_push_delivery(
      (select delivery_id from push_delivery_claims where fixture_label = 'second'),
      (select lease_token from push_delivery_claims where fixture_label = 'second'),
      encode(decode(repeat('12', 32), 'hex'), 'base64'),
      'invalid_token',
      'FCM_UNREGISTERED',
      null,
      null,
      '2030-01-01 22:00:02+00'
    )
  ),
  'retry_wait:1:ENDPOINT_MATERIAL_CHANGED:f',
  'old-token invalidation schedules the same delivery against current material'
);
reset role;
select is(
  (
    select concat_ws(':', revoked_at is null, version)
    from public.notification_endpoints
    where installation_id = '54000000-0000-4000-8000-000000000001'
  ),
  't:2',
  'late old-token provider failure leaves the rotated endpoint active'
);
set local role service_role;
insert into push_delivery_claims
select 'second_retry', claim.*
from public.claim_notification_push_deliveries(
  '54040000-0000-4000-8000-000000000005',
  10,
  60,
  '2030-01-01 22:00:08+00'
) as claim;
select is(
  (
    select concat_ws(
      ':', attempt,
      token_fingerprint_base64 = encode(decode(repeat('22', 32), 'hex'), 'base64')
    )
    from push_delivery_claims where fixture_label = 'second_retry'
  ),
  '2:t',
  'retry claims the rotated token fingerprint as attempt two'
);
select is(
  (
    select concat_ws(':', processing_status, attempts, result_code, endpoint_invalidated)
    from public.complete_notification_push_delivery(
      (select delivery_id from push_delivery_claims where fixture_label = 'second_retry'),
      (select lease_token from push_delivery_claims where fixture_label = 'second_retry'),
      encode(decode(repeat('22', 32), 'hex'), 'base64'),
      'invalid_token',
      'FCM_UNREGISTERED',
      null,
      null,
      '2030-01-01 22:00:09+00'
    )
  ),
  'failed:2:FCM_UNREGISTERED:t',
  'current invalid token fails delivery and invalidates exactly one endpoint'
);
reset role;
select is(
  (
    select concat_ws(':', revocation_reason, version)
    from public.notification_endpoints
    where installation_id = '54000000-0000-4000-8000-000000000001'
  ),
  'provider_unregistered:3',
  'provider invalidation stores only stable endpoint lifecycle state'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
set local role authenticated;
select is(
  (
    select count(*)
    from public.resolve_notification_push_target(
      (select delivery_id from push_delivery_claims where fixture_label = 'second_retry'),
      '20000000-0000-4000-8000-000000000101',
      (select subject_id from push_delivery_claims where fixture_label = 'second_retry')
    )
  ),
  0::bigint,
  'failed delivery no longer authorizes a tap target'
);
reset role;

-- Native-push off suppresses due deliveries even though in-app remains on.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select concat_ws(':', native_push, in_app, version)
    from public.update_notification_preference(
      '20000000-0000-4000-8000-000000000101',
      'chore_due',
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
  'f:t:1',
  'due native push can be disabled while durable in-app remains enabled'
);
reset role;
set local role service_role;
select is(
  (
    select count(*)
    from public.claim_notification_push_deliveries(
      '54040000-0000-4000-8000-000000000006',
      10,
      60,
      '2030-01-04 00:00:00+00'
    )
  ),
  0::bigint,
  'native-push-off due sources create no provider delivery'
);
reset role;
select is(
  (
    select count(*)
    from app_private.notification_push_evaluations as evaluation
    join app_private.notification_event_resolutions as resolution
      on resolution.source_event_id = evaluation.source_event_id
    where resolution.notification_category = 'chore_due'
      and evaluation.processing_status = 'disabled'
      and evaluation.reason_code = 'NATIVE_PUSH_DISABLED'
  ),
  2::bigint,
  'each due source records one stable native-push-disabled outcome'
);
select is(
  (
    select count(*)
    from app_private.notification_push_deliveries as delivery
    where delivery.category = 'chore_due'
  ),
  0::bigint,
  'disabled due category persists no provider token delivery row'
);
select ok(
  not exists (
    select 1
    from app_private.notification_push_deliveries as delivery
    where row_to_json(delivery)::text ilike '%Private fixture%'
       or row_to_json(delivery)::text ilike '%Never copied%'
  ),
  'delivery state never contains fixture title or description content'
);

set local role service_role;
select throws_ok(
  $$
    select * from public.complete_notification_push_delivery(
      '54050000-0000-4000-8000-000000000099',
      '54060000-0000-4000-8000-000000000099',
      'not-base64',
      'accepted',
      'FCM_UNREGISTERED',
      null,
      null,
      '2030-01-04 00:00:00+00'
    )
  $$,
  'KPS01',
  'invalid notification push input',
  'malformed provider completion fails before reading delivery state'
);
reset role;

select * from finish();
rollback;
