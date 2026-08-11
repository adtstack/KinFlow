begin;
set constraints all deferred;

select plan(48);

select has_table(
  'app_private',
  'notification_push_provider_health',
  'content-free FCM provider health table exists'
);
select has_table(
  'app_private',
  'notification_push_delivery_transitions',
  'immutable push delivery transition table exists'
);
select has_function(
  'public',
  'mark_notification_push_submission_started',
  array['uuid', 'uuid', 'text', 'timestamp with time zone'],
  'provider ambiguity boundary marker exists'
);
select has_function(
  'public',
  'replay_notification_push_delivery',
  array['uuid', 'timestamp with time zone'],
  'bounded explicit retry replay exists'
);
select has_function(
  'public',
  'reset_notification_push_provider_backoff',
  array['timestamp with time zone'],
  'provider backoff reset exists'
);
select has_function(
  'public',
  'get_notification_push_reliability_health',
  array['timestamp with time zone'],
  'aggregate push reliability health exists'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.mark_notification_push_submission_started(uuid,uuid,text,timestamptz)',
    'execute'
  )
    and has_function_privilege(
      'service_role',
      'public.get_notification_push_reliability_health(timestamptz)',
      'execute'
    )
    and not has_function_privilege(
      'authenticated',
      'public.mark_notification_push_submission_started(uuid,uuid,text,timestamptz)',
      'execute'
    )
    and not has_function_privilege(
      'authenticated',
      'public.get_notification_push_reliability_health(timestamptz)',
      'execute'
    ),
  'reliability control and health remain service-only'
);
select ok(
  not has_table_privilege(
    'service_role',
    'app_private.notification_push_provider_health',
    'select,insert,update,delete'
  )
    and not has_table_privilege(
      'authenticated',
      'app_private.notification_push_delivery_transitions',
      'select,insert,update,delete'
    ),
  'private reliability state cannot bypass mediated functions'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name in (
        'notification_push_provider_health',
        'notification_push_delivery_transitions'
      )
      and column_name in (
        'household_id', 'recipient_user_id', 'recipient_member_id',
        'subject_id', 'token', 'provider_body', 'raw_error', 'error_message'
      )
  ),
  'health and transition records omit household content token and provider body'
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
          and routine_name = 'get_notification_push_reliability_health'
      )
      and parameter_mode = 'OUT'
  ),
  'captured_at,health_status,alert_code,worker_paused,pause_reason_code,provider_backoff_active,provider_backoff_until,provider_backoff_reason_code,consecutive_retryable_failures,pending_evaluation_count,no_endpoint_count,pending_delivery_count,leased_count,retry_wait_count,succeeded_count,failed_count,cancelled_count,ready_count,expired_lease_count,ambiguous_count_24h,permanent_failure_count_24h,stale_suppressed_count_24h,slo_eligible_count_24h,slo_within_5m_count_24h,oldest_ready_at,next_retry_at',
  'health response is an exact aggregate-only contract'
);

create temporary table reliability_source_claims (
  event_id uuid primary key,
  lease_token uuid not null,
  attempt integer not null,
  max_attempts integer not null,
  lease_expires_at timestamptz not null
);

create temporary table reliability_delivery_claims (
  fixture_label text primary key,
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

create function pg_temp.prepare_push_assignment(p_chore_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_claim record;
begin
  perform pg_catalog.set_config(
    'request.jwt.claim.sub',
    '00000000-0000-4000-8000-000000000101',
    true
  );
  perform *
  from public.create_one_time_chore(
    p_chore_id,
    '20000000-0000-4000-8000-000000000101',
    'Synthetic reliability title',
    'Synthetic reliability description',
    '30000000-0000-4000-8000-000000000102',
    '2031-01-01',
    time '09:00'
  );

  truncate table reliability_source_claims;
  insert into reliability_source_claims
  select *
  from public.claim_chore_notification_events(
    p_chore_id,
    20,
    60,
    pg_catalog.statement_timestamp()
  );

  for v_claim in select * from reliability_source_claims loop
    perform public.process_chore_notification_event(
      v_claim.event_id,
      v_claim.lease_token,
      pg_catalog.statement_timestamp()
    );
  end loop;
end;
$$;

select lives_ok(
  $$
    select *
    from public.upsert_notification_endpoint(
      '00000000-0000-4000-8000-000000000102',
      '20000000-0000-4000-8000-000000000101',
      '55000000-0000-4000-8000-000000000001',
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
      '55010000-0000-4000-8000-000000000001',
      0,
      '2030-01-01 00:00:00+00'
    )
  $$,
  'active Android endpoint fixture is registered'
);

-- Explicit provider rejection: retry with provider-wide backpressure.
select pg_temp.prepare_push_assignment(
  '55020000-0000-4000-8000-000000000001'
);
insert into reliability_delivery_claims
select 'ambiguity', claim.*
from public.claim_notification_push_deliveries(
  '55030000-0000-4000-8000-000000000001',
  10,
  60,
  '2030-01-01 00:00:00+00'
) as claim;
select is(
  (
    select concat_ws(
      ':', attempt, scheduled_at, expires_at,
      extract(epoch from expires_at - scheduled_at)::integer
    )
    from reliability_delivery_claims
    where fixture_label = 'ambiguity'
  ),
  '1:2030-01-01 00:00:00+00:2030-01-01 01:00:00+00:3600',
  'claim exposes an exact one-hour provider submission window'
);
select is(
  (
    select submission_started_at
    from public.mark_notification_push_submission_started(
      (select delivery_id from reliability_delivery_claims where fixture_label = 'ambiguity'),
      (select lease_token from reliability_delivery_claims where fixture_label = 'ambiguity'),
      encode(decode(repeat('32', 32), 'hex'), 'base64'),
      '2030-01-01 00:00:01+00'
    )
  ),
  '2030-01-01 00:00:01+00'::timestamptz,
  'submission marker is durable before provider I/O'
);
select is(
  (
    select submission_started_at
    from public.mark_notification_push_submission_started(
      (select delivery_id from reliability_delivery_claims where fixture_label = 'ambiguity'),
      (select lease_token from reliability_delivery_claims where fixture_label = 'ambiguity'),
      encode(decode(repeat('32', 32), 'hex'), 'base64'),
      '2030-01-01 00:00:02+00'
    )
  ),
  '2030-01-01 00:00:01+00'::timestamptz,
  'submission marker replay returns the original ambiguity boundary'
);
select is(
  (
    select string_agg(transition, ',' order by id)
    from app_private.notification_push_delivery_transitions
    where delivery_id = (
      select delivery_id
      from reliability_delivery_claims
      where fixture_label = 'ambiguity'
    )
  ),
  'claimed,submission_started',
  'claim and submission transitions are recorded without payload'
);
select is(
  (
    select concat_ws(':', processing_status, result_code, next_attempt_at)
    from public.complete_notification_push_delivery(
      (select delivery_id from reliability_delivery_claims where fixture_label = 'ambiguity'),
      (select lease_token from reliability_delivery_claims where fixture_label = 'ambiguity'),
      encode(decode(repeat('32', 32), 'hex'), 'base64'),
      'retryable',
      'FCM_UNAVAILABLE',
      null,
      60,
      '2030-01-01 00:00:03+00'
    )
  ),
  'retry_wait:FCM_UNAVAILABLE:2030-01-01 00:01:03+00',
  'explicit provider rejection schedules the exact bounded retry'
);
select is(
  (
    select concat_ws(
      ':', backoff_reason_code, consecutive_retryable_failures,
      backoff_until
    )
    from app_private.notification_push_provider_health
  ),
  'FCM_UNAVAILABLE:1:2030-01-01 00:01:03+00',
  'explicit retry also applies provider-wide backpressure'
);
select is(
  (
    select concat_ws(':', health_status, alert_code, provider_backoff_active)
    from public.get_notification_push_reliability_health(
      '2030-01-01 00:00:04+00'
    )
  ),
  'degraded:PROVIDER_BACKOFF_ACTIVE:t',
  'active provider backoff is exposed as a stable aggregate alert'
);
select is(
  (
    select concat_ws(
      ':', backoff_until is null, backoff_reason_code is null,
      consecutive_retryable_failures
    )
    from public.reset_notification_push_provider_backoff(
      '2030-01-01 00:00:05+00'
    )
  ),
  't:t:0',
  'operator reset clears backoff without altering deliveries'
);

delete from reliability_delivery_claims where fixture_label = 'ambiguity_retry';
insert into reliability_delivery_claims
select 'ambiguity_retry', claim.*
from public.claim_notification_push_deliveries(
  '55030000-0000-4000-8000-000000000002',
  10,
  60,
  '2030-01-01 00:01:03+00'
) as claim;
select is(
  (
    select concat_ws(
      ':', attempt,
      submission_started_at is null,
      submission_lease_token is null
    )
    from reliability_delivery_claims as claim
    join app_private.notification_push_deliveries as delivery
      on delivery.id = claim.delivery_id
    where claim.fixture_label = 'ambiguity_retry'
  ),
  '2:t:t',
  'a new retry lease clears the preceding submission marker'
);
select lives_ok(
  $$
    select *
    from public.mark_notification_push_submission_started(
      (select delivery_id from reliability_delivery_claims where fixture_label = 'ambiguity_retry'),
      (select lease_token from reliability_delivery_claims where fixture_label = 'ambiguity_retry'),
      encode(decode(repeat('32', 32), 'hex'), 'base64'),
      '2030-01-01 00:01:04+00'
    )
  $$,
  'retry lease can establish its own submission boundary'
);
select is(
  (
    select concat_ws(':', processing_status, result_code, endpoint_invalidated)
    from public.complete_notification_push_delivery(
      (select delivery_id from reliability_delivery_claims where fixture_label = 'ambiguity_retry'),
      (select lease_token from reliability_delivery_claims where fixture_label = 'ambiguity_retry'),
      encode(decode(repeat('32', 32), 'hex'), 'base64'),
      'ambiguous',
      'FCM_SUBMISSION_AMBIGUOUS',
      null,
      null,
      '2030-01-01 00:01:05+00'
    )
  ),
  'failed:FCM_SUBMISSION_AMBIGUOUS:f',
  'unknown provider acceptance is terminal instead of auto-retried'
);
select is(
  (
    select concat_ws(':', processing_status, result_code)
    from public.complete_notification_push_delivery(
      (select delivery_id from reliability_delivery_claims where fixture_label = 'ambiguity_retry'),
      (select lease_token from reliability_delivery_claims where fixture_label = 'ambiguity_retry'),
      encode(decode(repeat('32', 32), 'hex'), 'base64'),
      'ambiguous',
      'FCM_SUBMISSION_AMBIGUOUS',
      null,
      null,
      '2030-01-01 00:01:06+00'
    )
  ),
  'failed:FCM_SUBMISSION_AMBIGUOUS',
  'ambiguity completion replay is exact and idempotent'
);
select throws_ok(
  $$
    select *
    from public.replay_notification_push_delivery(
      (select delivery_id from reliability_delivery_claims where fixture_label = 'ambiguity_retry'),
      '2030-01-01 00:01:07+00'
    )
  $$,
  'KPS05',
  'notification push delivery is not replayable',
  'ambiguous provider submissions cannot be manually duplicated'
);
select is(
  (
    select concat_ws(':', health_status, alert_code, ambiguous_count_24h)
    from public.get_notification_push_reliability_health(
      '2030-01-01 00:01:07+00'
    )
  ),
  'degraded:AMBIGUOUS_SUBMISSION:1',
  'ambiguity has alert precedence over its protective backoff'
);
select throws_ok(
  $$
    update app_private.notification_push_delivery_transitions
    set attempt = attempt
    where delivery_id = (
      select delivery_id
      from reliability_delivery_claims
      where fixture_label = 'ambiguity_retry'
    )
  $$,
  'KPS04',
  'notification push transition is immutable',
  'transition forensic history rejects mutation'
);

-- A retry cannot outlive the one-hour usefulness window.
select pg_temp.prepare_push_assignment(
  '55020000-0000-4000-8000-000000000002'
);
insert into reliability_delivery_claims
select 'stale', claim.*
from public.claim_notification_push_deliveries(
  '55030000-0000-4000-8000-000000000003',
  10,
  60,
  '2030-01-02 00:00:00+00'
) as claim;
select lives_ok(
  $$
    select *
    from public.mark_notification_push_submission_started(
      (select delivery_id from reliability_delivery_claims where fixture_label = 'stale'),
      (select lease_token from reliability_delivery_claims where fixture_label = 'stale'),
      encode(decode(repeat('32', 32), 'hex'), 'base64'),
      '2030-01-02 00:00:01+00'
    )
  $$,
  'stale fixture records a real provider attempt boundary'
);
select is(
  (
    select concat_ws(':', processing_status, next_attempt_at)
    from public.complete_notification_push_delivery(
      (select delivery_id from reliability_delivery_claims where fixture_label = 'stale'),
      (select lease_token from reliability_delivery_claims where fixture_label = 'stale'),
      encode(decode(repeat('32', 32), 'hex'), 'base64'),
      'retryable',
      'FCM_QUOTA_EXCEEDED',
      null,
      3600,
      '2030-01-02 00:00:02+00'
    )
  ),
  'retry_wait:2030-01-02 01:00:02+00',
  'quota response may schedule a retry at the bounded maximum delay'
);
select lives_ok(
  $$
    select *
    from public.reset_notification_push_provider_backoff(
      '2030-01-02 00:00:03+00'
    )
  $$,
  'stale fixture clears global backoff before exercising expiry'
);
select is(
  (
    select count(*)
    from public.claim_notification_push_deliveries(
      '55030000-0000-4000-8000-000000000004',
      10,
      60,
      '2030-01-02 01:00:03+00'
    )
  ),
  0::bigint,
  'expired retry is suppressed before any provider material is returned'
);
select is(
  (
    select concat_ws(':', processing_status, last_result_code)
    from app_private.notification_push_deliveries
    where id = (
      select delivery_id
      from reliability_delivery_claims
      where fixture_label = 'stale'
    )
  ),
  'cancelled:STALE_DELIVERY_WINDOW',
  'expired retry becomes a stable stale cancellation'
);
select is(
  (
    select concat_ws(
      ':', health_status, alert_code, stale_suppressed_count_24h,
      slo_eligible_count_24h, slo_within_5m_count_24h
    )
    from public.get_notification_push_reliability_health(
      '2030-01-02 01:00:04+00'
    )
  ),
  'critical:PROVIDER_SUBMIT_SLO_BREACH:1:1:0',
  'stale provider submission raises the absolute-count SLO alert'
);

-- Only explicit exhausted retries may be manually replayed before expiry.
select pg_temp.prepare_push_assignment(
  '55020000-0000-4000-8000-000000000003'
);
insert into reliability_delivery_claims
select 'replayable', claim.*
from public.claim_notification_push_deliveries(
  '55030000-0000-4000-8000-000000000005',
  10,
  60,
  '2030-01-03 00:00:00+00'
) as claim;
update app_private.notification_push_deliveries
set attempts = 5
where id = (
  select delivery_id
  from reliability_delivery_claims
  where fixture_label = 'replayable'
);
select is(
  (
    select concat_ws(':', processing_status, attempts, result_code)
    from public.complete_notification_push_delivery(
      (select delivery_id from reliability_delivery_claims where fixture_label = 'replayable'),
      (select lease_token from reliability_delivery_claims where fixture_label = 'replayable'),
      encode(decode(repeat('32', 32), 'hex'), 'base64'),
      'retryable',
      'FCM_INTERNAL',
      null,
      60,
      '2030-01-03 00:00:01+00'
    )
  ),
  'failed:5:ATTEMPTS_EXHAUSTED',
  'fifth explicit retryable failure is terminal'
);
select is(
  (
    select concat_ws(':', processing_status, replay_count, next_attempt_at)
    from public.replay_notification_push_delivery(
      (select delivery_id from reliability_delivery_claims where fixture_label = 'replayable'),
      '2030-01-03 00:00:02+00'
    )
  ),
  'pending:1:2030-01-03 00:00:02+00',
  'operator may replay an explicit exhausted failure inside its window'
);
select is(
  (
    select transition
    from app_private.notification_push_delivery_transitions
    where delivery_id = (
      select delivery_id
      from reliability_delivery_claims
      where fixture_label = 'replayable'
    )
    order by id desc
    limit 1
  ),
  'replayed',
  'manual replay is recorded in immutable transition history'
);
select lives_ok(
  $$
    select *
    from public.reset_notification_push_provider_backoff(
      '2030-01-03 00:00:02+00'
    )
  $$,
  'manual replay can resume after explicit operator backoff reset'
);
delete from reliability_delivery_claims where fixture_label = 'replayed_claim';
insert into reliability_delivery_claims
select 'replayed_claim', claim.*
from public.claim_notification_push_deliveries(
  '55030000-0000-4000-8000-000000000006',
  10,
  60,
  '2030-01-03 00:00:03+00'
) as claim;
select is(
  (
    select attempt
    from reliability_delivery_claims
    where fixture_label = 'replayed_claim'
  ),
  1,
  'manual replay receives a fresh bounded attempt sequence'
);
select lives_ok(
  $$
    select *
    from public.mark_notification_push_submission_started(
      (select delivery_id from reliability_delivery_claims where fixture_label = 'replayed_claim'),
      (select lease_token from reliability_delivery_claims where fixture_label = 'replayed_claim'),
      encode(decode(repeat('32', 32), 'hex'), 'base64'),
      '2030-01-03 00:00:04+00'
    )
  $$,
  'replayed provider request records its submission boundary'
);
select lives_ok(
  $$
    select *
    from public.complete_notification_push_delivery(
      (select delivery_id from reliability_delivery_claims where fixture_label = 'replayed_claim'),
      (select lease_token from reliability_delivery_claims where fixture_label = 'replayed_claim'),
      encode(decode(repeat('32', 32), 'hex'), 'base64'),
      'permanent',
      'FCM_REQUEST_REJECTED',
      null,
      null,
      '2030-01-03 00:00:05+00'
    )
  $$,
  'documented non-retryable provider rejection is terminalized'
);

-- A process crash after the marker is assumed ambiguous and never resent.
select pg_temp.prepare_push_assignment(
  '55020000-0000-4000-8000-000000000004'
);
insert into reliability_delivery_claims
select 'completion_loss', claim.*
from public.claim_notification_push_deliveries(
  '55030000-0000-4000-8000-000000000007',
  10,
  60,
  '2030-01-04 00:00:00+00'
) as claim;
select lives_ok(
  $$
    select *
    from public.mark_notification_push_submission_started(
      (select delivery_id from reliability_delivery_claims where fixture_label = 'completion_loss'),
      (select lease_token from reliability_delivery_claims where fixture_label = 'completion_loss'),
      encode(decode(repeat('32', 32), 'hex'), 'base64'),
      '2030-01-04 00:00:01+00'
    )
  $$,
  'completion-loss fixture crosses the provider boundary'
);
select is(
  (
    select count(*)
    from public.claim_notification_push_deliveries(
      '55030000-0000-4000-8000-000000000008',
      10,
      60,
      '2030-01-04 00:01:01+00'
    )
  ),
  0::bigint,
  'expired marked lease is not reclaimed for provider resend'
);
select is(
  (
    select concat_ws(':', processing_status, last_result_code, completion_outcome)
    from app_private.notification_push_deliveries
    where id = (
      select delivery_id
      from reliability_delivery_claims
      where fixture_label = 'completion_loss'
    )
  ),
  'failed:FCM_SUBMISSION_AMBIGUOUS:ambiguous',
  'completion loss is quarantined with stable ambiguity state'
);

-- Permission recovery re-evaluates a recent no-endpoint source only once.
select is(
  public.revoke_notification_endpoint_by_secret(
    '55000000-0000-4000-8000-000000000001',
    'native_push',
    '55010000-0000-4000-8000-000000000001',
    encode(decode(repeat('33', 32), 'hex'), 'base64'),
    '2030-01-05 00:00:00+00'
  ),
  1,
  'endpoint is revoked for no-endpoint recovery fixture'
);
select pg_temp.prepare_push_assignment(
  '55020000-0000-4000-8000-000000000005'
);
select is(
  (
    select count(*)
    from public.claim_notification_push_deliveries(
      '55030000-0000-4000-8000-000000000009',
      10,
      60,
      '2030-01-05 00:00:01+00'
    )
  ),
  0::bigint,
  'source with no active endpoint returns no provider material'
);
select is(
  (
    select count(*)
    from app_private.notification_push_evaluations as evaluation
    join app_private.notification_event_resolutions as resolution
      on resolution.source_event_id = evaluation.source_event_id
    where resolution.subject_id = (
      select request.occurrence_id
      from app_private.chore_command_requests as request
      where request.idempotency_key =
        '55020000-0000-4000-8000-000000000005'
    )
      and resolution.notification_category = 'chore_assignment'
      and evaluation.processing_status = 'no_endpoint'
  ),
  1::bigint,
  'no-endpoint evaluation is durable during inbox fallback'
);
select lives_ok(
  $$
    select *
    from public.upsert_notification_endpoint(
      '00000000-0000-4000-8000-000000000102',
      '20000000-0000-4000-8000-000000000101',
      '55000000-0000-4000-8000-000000000001',
      'native_push',
      'android',
      encode(decode(repeat('41', 32), 'hex'), 'base64'),
      encode(decode(repeat('42', 32), 'hex'), 'base64'),
      2,
      encode(decode(repeat('43', 32), 'hex'), 'base64'),
      'granted',
      'ko-KR',
      'Asia/Seoul',
      '0.1.1+2',
      'Flutter 3.44.7',
      '55010000-0000-4000-8000-000000000002',
      2,
      '2030-01-05 00:00:02+00'
    )
  $$,
  'recent permission recovery reactivates the endpoint'
);
select is(
  (
    select processing_status
    from app_private.notification_push_evaluations as evaluation
    join app_private.notification_event_resolutions as resolution
      on resolution.source_event_id = evaluation.source_event_id
    where resolution.subject_id = (
      select request.occurrence_id
      from app_private.chore_command_requests as request
      where request.idempotency_key =
        '55020000-0000-4000-8000-000000000005'
    )
      and resolution.notification_category = 'chore_assignment'
  ),
  'pending',
  'endpoint recovery wakes the recent no-endpoint evaluation'
);
select is(
  (
    select count(*)
    from public.claim_notification_push_deliveries(
      '55030000-0000-4000-8000-000000000010',
      10,
      60,
      '2030-01-05 00:00:03+00'
    )
  ),
  1::bigint,
  'woken source becomes provider-claimable exactly once'
);

select * from finish();
rollback;
