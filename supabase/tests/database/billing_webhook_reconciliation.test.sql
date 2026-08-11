begin;
set constraints all deferred;

select no_plan();

create temporary table billing_reconciliation_test_clock (
  as_of timestamptz not null
);
insert into billing_reconciliation_test_clock values (
  pg_catalog.statement_timestamp()
);

create function pg_temp.enqueue_billing_webhook(
  p_event_id text,
  p_hash_seed text,
  p_action text default 'reconcile',
  p_event_type text default 'INITIAL_PURCHASE',
  p_user_id uuid default '00000000-0000-4000-8000-000000000101',
  p_environment text default 'sandbox'
)
returns table (
  job_id uuid,
  processing_status text,
  duplicate boolean,
  delivery_count integer
)
language sql
as $$
  select *
  from public.enqueue_revenuecat_webhook(
    p_event_id,
    pg_catalog.encode(
      extensions.digest(pg_catalog.convert_to(p_hash_seed, 'UTF8'), 'sha256'),
      'base64'
    ),
    '1.0',
    p_event_type,
    p_user_id,
    p_environment,
    (select clock.as_of - interval '1 minute'
     from pg_temp.billing_reconciliation_test_clock as clock),
    p_action,
    (select clock.as_of
     from pg_temp.billing_reconciliation_test_clock as clock),
    extensions.gen_random_uuid()
  )
$$;

select has_table(
  'app_private',
  'billing_reconciliation_jobs',
  'private billing webhook inbox and reconciliation queue exists'
);
select has_table(
  'app_private',
  'billing_reconciliation_transitions',
  'private immutable billing reconciliation audit exists'
);
select is(
  (
    select pg_catalog.string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'billing_reconciliation_jobs'
  ),
  'id,provider,source,provider_event_id,request_hash,api_version,event_type,auth_user_id,environment,provider_occurred_at,processing_status,delivery_count,attempts,max_attempts,next_attempt_at,lease_owner,lease_token,lease_expires_at,completed_lease_token,last_error_code,received_at,last_received_at,updated_at,completed_at,correlation_id',
  'job persistence is metadata-only with exact lease and retry state'
);
select is(
  (
    select pg_catalog.string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'billing_reconciliation_transitions'
  ),
  'id,job_id,transition,attempt,result_code,occurred_at',
  'audit persistence is aggregate-only and contains no provider payload'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name in (
        'billing_reconciliation_jobs',
        'billing_reconciliation_transitions'
      )
      and column_name ~ '(payload|body|receipt|transaction|product|attribute|alias)'
  ),
  'reconciliation storage has no raw provider body or subscriber material column'
);

select has_function(
  'public',
  'enqueue_revenuecat_webhook',
  array[
    'text', 'text', 'text', 'text', 'uuid', 'text', 'timestamp with time zone',
    'text', 'timestamp with time zone', 'uuid'
  ]
);
select has_function(
  'public',
  'schedule_due_billing_reconciliations',
  array['timestamp with time zone', 'integer', 'integer', 'uuid']
);
select has_function(
  'public',
  'claim_billing_reconciliation_jobs',
  array['uuid', 'integer', 'integer', 'timestamp with time zone']
);
select has_function(
  'public',
  'complete_billing_reconciliation_job',
  array['uuid', 'uuid', 'text', 'text', 'timestamp with time zone']
);
select has_function(
  'public',
  'get_billing_reconciliation_health',
  array['timestamp with time zone']
);
select ok(
  not exists (
    select 1
    from pg_catalog.pg_proc as procedure
    join pg_catalog.pg_namespace as namespace
      on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in (
        'enqueue_revenuecat_webhook',
        'schedule_due_billing_reconciliations',
        'claim_billing_reconciliation_jobs',
        'complete_billing_reconciliation_job',
        'get_billing_reconciliation_health'
      )
      and (
        not procedure.prosecdef
        or not procedure.proconfig @> array['search_path=""']::text[]
      )
  ),
  'every public reconciliation RPC is security-definer with empty search path'
);
select ok(
  not has_table_privilege(
    'service_role',
    'app_private.billing_reconciliation_jobs',
    'select'
  )
    and not has_table_privilege(
      'authenticated',
      'app_private.billing_reconciliation_transitions',
      'select'
    ),
  'private queue and audit have no direct service or client table path'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.enqueue_revenuecat_webhook(text,text,text,text,uuid,text,timestamptz,text,timestamptz,uuid)',
    'execute'
  )
    and has_function_privilege(
      'service_role',
      'public.claim_billing_reconciliation_jobs(uuid,integer,integer,timestamptz)',
      'execute'
    )
    and not has_function_privilege(
      'authenticated',
      'public.enqueue_revenuecat_webhook(text,text,text,text,uuid,text,timestamptz,text,timestamptz,uuid)',
      'execute'
    ),
  'only the service role receives the mediated reconciliation RPC surface'
);

select results_eq(
  $$
    select processing_status, duplicate, delivery_count
    from pg_temp.enqueue_billing_webhook('webhook-disabled', 'hash-disabled')
  $$,
  $$ values ('queued'::text, false, 1::integer) $$,
  'disabled runtime durably queues a valid receipt instead of discarding it'
);
select is(
  (
    select pg_catalog.count(*)
    from public.claim_billing_reconciliation_jobs(
      '66000000-0000-4000-8000-000000000001',
      10,
      60,
      (select as_of from billing_reconciliation_test_clock)
    )
  ),
  0::bigint,
  'disabled runtime never leases queued billing work'
);
select results_eq(
  $$
    select processing_status, duplicate, delivery_count
    from pg_temp.enqueue_billing_webhook('webhook-disabled', 'hash-disabled')
  $$,
  $$ values ('queued'::text, true, 2::integer) $$,
  'exact RevenueCat replay converges on one row and increments delivery count'
);
select is(
  (
    select pg_catalog.count(*)
    from app_private.billing_reconciliation_jobs
    where provider_event_id = 'webhook-disabled'
  ),
  1::bigint,
  'replayed event retains exactly one durable job'
);
select throws_ok(
  $$
    select *
    from pg_temp.enqueue_billing_webhook('webhook-disabled', 'different-hash')
  $$,
  'KFB40',
  'RevenueCat event ID collision',
  'same provider event ID with a different raw hash fails closed'
);
select results_eq(
  $$
    select processing_status, duplicate
    from pg_temp.enqueue_billing_webhook(
      'webhook-test', 'hash-test', 'ignore', 'TEST', null, null
    )
  $$,
  $$ values ('ignored'::text, false) $$,
  'known non-entitlement event is durably ignored with a fast terminal state'
);
select results_eq(
  $$
    select processing_status, duplicate
    from pg_temp.enqueue_billing_webhook(
      'webhook-transfer', 'hash-transfer', 'manual_review', 'TRANSFER', null, null
    )
  $$,
  $$ values ('dead_letter'::text, false) $$,
  'transfer without exact assignment enters explicit manual review'
);
select is(
  (
    select last_error_code
    from app_private.billing_reconciliation_jobs
    where provider_event_id = 'webhook-transfer'
  ),
  'MANUAL_REVIEW_REQUIRED',
  'manual review stores only a stable aggregate error code'
);

select lives_ok(
  $$
    select *
    from public.configure_billing_runtime(
      'sandbox',
      true,
      1,
      '66000000-0000-4000-8000-000000000002'
    )
  $$,
  'billing runtime can explicitly enable the sandbox reconciliation worker'
);
select results_eq(
  $$
    select processing_status
    from pg_temp.enqueue_billing_webhook(
      'webhook-production',
      'hash-production',
      'reconcile',
      'RENEWAL',
      '00000000-0000-4000-8000-000000000101',
      'production'
    )
  $$,
  $$ values ('dead_letter'::text) $$,
  'enabled sandbox runtime rejects a production receipt without provider access'
);
select is(
  (
    select last_error_code
    from app_private.billing_reconciliation_jobs
    where provider_event_id = 'webhook-production'
  ),
  'ENVIRONMENT_MISMATCH',
  'environment mismatch is represented by a stable dead-letter code'
);

create temporary table first_billing_claim as
select *
from public.claim_billing_reconciliation_jobs(
  '66000000-0000-4000-8000-000000000003',
  1,
  60,
  (select as_of + interval '1 second'
   from billing_reconciliation_test_clock)
);
select is(
  (
    select concat_ws(
      ':', attempt_count, environment, household_id is null
    )
    from first_billing_claim
  ),
  '1:sandbox:t',
  'claim does not infer a current household when no billing assignment exists'
);
select results_eq(
  $$
    select processing_status, attempt_count, last_error_code,
      next_attempt_at = (
        select as_of + interval '91 seconds'
        from billing_reconciliation_test_clock
      )
    from public.complete_billing_reconciliation_job(
      (select job_id from first_billing_claim),
      (select lease_token from first_billing_claim),
      'retryable',
      'PROVIDER_NETWORK',
      (select as_of + interval '31 seconds'
       from billing_reconciliation_test_clock)
    )
  $$,
  $$ values ('retry_wait'::text, 1, 'PROVIDER_NETWORK'::text, true) $$,
  'transient provider failure receives the database-owned first retry delay'
);
select results_eq(
  $$
    select processing_status, attempt_count, last_error_code
    from public.complete_billing_reconciliation_job(
      (select job_id from first_billing_claim),
      (select lease_token from first_billing_claim),
      'retryable',
      'PROVIDER_NETWORK',
      (select as_of + interval '31 seconds'
       from billing_reconciliation_test_clock)
    )
  $$,
  $$ values ('retry_wait'::text, 1, 'PROVIDER_NETWORK'::text) $$,
  'completion replay with the same opaque lease is idempotent'
);

create temporary table second_billing_claim as
select *
from public.claim_billing_reconciliation_jobs(
  '66000000-0000-4000-8000-000000000004',
  1,
  60,
  (select as_of + interval '92 seconds'
   from billing_reconciliation_test_clock)
);
select is(
  (select attempt_count from second_billing_claim),
  2,
  'retry claim advances the monotonic attempt count exactly once'
);
select results_eq(
  $$
    select processing_status, last_error_code, completed_at is not null
    from public.complete_billing_reconciliation_job(
      (select job_id from second_billing_claim),
      (select lease_token from second_billing_claim),
      'dead_letter',
      'ASSIGNMENT_REQUIRED',
      (select as_of + interval '100 seconds'
       from billing_reconciliation_test_clock)
    )
  $$,
  $$ values ('dead_letter'::text, 'ASSIGNMENT_REQUIRED'::text, true) $$,
  'missing explicit household assignment terminates without granting Plus'
);

select lives_ok(
  $$
    select *
    from public.apply_verified_billing_event(
      'revenuecat',
      'sandbox',
      'normalized-assignment-setup',
      'reconciliation',
      (select as_of - interval '2 minutes'
       from billing_reconciliation_test_clock),
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000101',
      'play-setup-transaction',
      'play-setup-transaction',
      'kinflow_plus_monthly',
      'play_store',
      '20000000-0000-4000-8000-000000000101',
      'active',
      'plus',
      (select as_of - interval '1 day'
       from billing_reconciliation_test_clock),
      (select as_of + interval '30 days'
       from billing_reconciliation_test_clock),
      true,
      '2026-08-08-wp06-04',
      null,
      '66000000-0000-4000-8000-000000000005'
    )
  $$,
  'existing normalized command creates an explicit active household assignment'
);
select results_eq(
  $$
    select processing_status
    from pg_temp.enqueue_billing_webhook(
      'webhook-assigned', 'hash-assigned', 'reconcile', 'RENEWAL'
    )
  $$,
  $$ values ('queued'::text) $$,
  'assigned subscriber webhook enters the authoritative refresh queue'
);

create temporary table assigned_billing_claim as
select *
from public.claim_billing_reconciliation_jobs(
  '66000000-0000-4000-8000-000000000006',
  1,
  60,
  (select as_of + interval '101 seconds'
   from billing_reconciliation_test_clock)
);
select is(
  (select household_id from assigned_billing_claim),
  '20000000-0000-4000-8000-000000000101'::uuid,
  'claim resolves only the persisted active billing assignment'
);
select results_eq(
  $$
    select processing_status, last_error_code, completed_at is not null
    from public.complete_billing_reconciliation_job(
      (select job_id from assigned_billing_claim),
      (select lease_token from assigned_billing_claim),
      'succeeded',
      null,
      (select as_of + interval '102 seconds'
       from billing_reconciliation_test_clock)
    )
  $$,
  $$ values ('succeeded'::text, null::text, true) $$,
  'authoritative refresh job can complete after normalized apply succeeds'
);

select is(
  public.schedule_due_billing_reconciliations(
    (select as_of + interval '2 hours'
     from billing_reconciliation_test_clock),
    3600,
    10,
    '66000000-0000-4000-8000-000000000007'
  ),
  1,
  'periodic repair queues a stale actively assigned billing customer'
);
select is(
  public.schedule_due_billing_reconciliations(
    (select as_of + interval '2 hours'
     from billing_reconciliation_test_clock),
    3600,
    10,
    '66000000-0000-4000-8000-000000000008'
  ),
  0,
  'periodic repair is idempotent while an active job already exists'
);
select is(
  (
    select pg_catalog.count(*)
    from app_private.billing_reconciliation_jobs
    where source = 'periodic'
      and auth_user_id = '00000000-0000-4000-8000-000000000101'
  ),
  1::bigint,
  'periodic reconciliation retains one bounded metadata-only job'
);

select ok(
  (
    select health.dead_letter_count >= 3
      and health.succeeded_24h_count >= 1
      and health.queued_count >= 1
      and health.oldest_due_at is not null
    from public.get_billing_reconciliation_health(
      (select as_of + interval '2 hours 1 second'
       from billing_reconciliation_test_clock)
    ) as health
  ),
  'aggregate health exposes queue, completion, dead letter and oldest due signals'
);
select is(
  (
    select pg_catalog.count(*)
    from app_private.billing_reconciliation_transitions
    where job_id = (
      select id
      from app_private.billing_reconciliation_jobs
      where provider_event_id = 'webhook-disabled'
    )
      and transition in (
        'queued', 'replayed', 'claimed', 'retry_scheduled', 'dead_lettered'
      )
  ),
  6::bigint,
  'immutable audit records every replay, claim, retry and terminal transition'
);
select throws_ok(
  $$
    update app_private.billing_reconciliation_jobs
    set provider_event_id = 'mutated-provider-event'
    where provider_event_id = 'webhook-disabled'
  $$,
  'KFB44',
  'billing reconciliation provider metadata is immutable',
  'provider routing metadata cannot be rewritten after receipt'
);
select throws_ok(
  $$
    update app_private.billing_reconciliation_transitions
    set result_code = 'MUTATED'
    where id = (
      select pg_catalog.min(id)
      from app_private.billing_reconciliation_transitions
    )
  $$,
  'KFB45',
  'billing reconciliation audit is immutable',
  'reconciliation transition audit rejects mutation'
);

select * from finish();
rollback;
