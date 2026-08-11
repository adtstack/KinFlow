begin;
set constraints all deferred;

select no_plan();

-- Compact fixture wrapper around the service-only normalized event command.
create function pg_temp.apply_billing_test_event(
  p_event_id text,
  p_event_type text,
  p_occurred_at timestamptz,
  p_auth_user_id uuid,
  p_customer_ref text,
  p_transaction_ref text,
  p_household_id uuid,
  p_status public.entitlement_status,
  p_plan_code text,
  p_will_renew boolean,
  p_environment text default 'sandbox',
  p_source text default 'play_store'
)
returns table (
  receipt_id uuid,
  processing_status text,
  duplicate boolean,
  billing_customer_id uuid,
  billing_transaction_id uuid,
  assignment_id uuid,
  household_id uuid,
  plan_code text,
  entitlement_status public.entitlement_status,
  entitlement_version bigint,
  provider_updated_at timestamptz
)
language sql
as $$
  select *
  from public.apply_verified_billing_event(
    'revenuecat',
    p_environment,
    p_event_id,
    p_event_type,
    p_occurred_at,
    p_auth_user_id,
    p_customer_ref,
    p_transaction_ref,
    'play-original-1',
    'kinflow_plus_monthly',
    p_source,
    p_household_id,
    p_status,
    p_plan_code,
    '2026-08-01 00:00:00+00'::timestamptz,
    '2026-09-01 00:00:00+00'::timestamptz,
    p_will_renew,
    '2026-08-08-wp06-01',
    pg_catalog.convert_to('encrypted-fixture', 'UTF8'),
    extensions.gen_random_uuid()
  )
$$;

-- Exact schema and state model.
select has_type(
  'public',
  'entitlement_status',
  'billing entitlement state enum exists'
);
select results_eq(
  $$
    select enum_value::text
    from pg_catalog.unnest(
      pg_catalog.enum_range(null::public.entitlement_status)
    ) as enum_value
  $$,
  $$
    values
      ('none'::text),
      ('trialing'::text),
      ('active'::text),
      ('grace'::text),
      ('billing_issue'::text),
      ('expired'::text),
      ('revoked'::text)
  $$,
  'entitlement lifecycle values remain exact and ordered'
);

select has_table('public', 'billing_customers', 'billing customer table exists');
select has_table(
  'public',
  'billing_webhook_receipts',
  'billing verified-event receipt table exists'
);
select has_table(
  'public',
  'billing_transactions',
  'billing transaction table exists'
);
select has_table(
  'public',
  'billing_household_assignments',
  'billing household assignment table exists'
);
select has_table('public', 'plan_catalog', 'plan policy table exists');
select has_table(
  'public',
  'household_entitlements',
  'household entitlement table exists'
);
select has_table(
  'app_private',
  'billing_runtime_config',
  'private billing runtime configuration exists'
);
select has_table(
  'app_private',
  'billing_entitlement_transitions',
  'private entitlement transition audit exists'
);
select has_table(
  'app_private',
  'billing_policy_events',
  'private policy audit exists'
);

select is(
  (
    select pg_catalog.string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'billing_customers'
  ),
  'id,auth_user_id,provider,environment,provider_customer_ref,provider_customer_ref_hash,last_verified_at,provider_updated_at,last_receipt_id,created_at,updated_at,version',
  'billing customer persistence has exact identity environment and ordering fields'
);
select is(
  (
    select pg_catalog.string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'household_entitlements'
  ),
  'household_id,assignment_id,billing_owner_user_id,plan_code,status,source,product_id,current_period_start,current_period_end,will_renew,features,provider_updated_at,verified_at,created_at,updated_at,version',
  'household entitlement has exact authority state limit and version fields'
);
select is(
  (
    select pg_catalog.string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'billing_entitlement_transitions'
  ),
  'id,receipt_id,household_id,assignment_id,billing_transaction_id,event_type,previous_plan_code,next_plan_code,previous_status,next_status,provider_occurred_at,correlation_id,applied_at',
  'entitlement audit excludes customer refs receipts and family content'
);

select has_function(
  'public',
  'configure_billing_runtime',
  array['text', 'boolean', 'bigint', 'uuid']
);
select has_function(
  'public',
  'configure_plan_feature_limits',
  array['text', 'jsonb', 'boolean', 'bigint', 'uuid']
);
select has_function(
  'public',
  'get_household_entitlement',
  array['uuid']
);
select has_function(
  'app_private',
  'assert_household_feature_capacity',
  array['uuid', 'text', 'integer']
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_proc as procedure
    join pg_catalog.pg_namespace as namespace
      on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname = 'apply_verified_billing_event'
      and procedure.pronargs = 20
  ),
  'verified normalized billing event command has its exact typed surface'
);
select ok(
  not exists (
    select 1
    from pg_catalog.pg_proc as procedure
    join pg_catalog.pg_namespace as namespace
      on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in (
        'configure_billing_runtime',
        'configure_plan_feature_limits',
        'apply_verified_billing_event',
        'get_household_entitlement'
      )
      and (
        not procedure.prosecdef
        or not procedure.proconfig @> array['search_path=""']::text[]
      )
  ),
  'all public billing APIs are security-definer with an empty search path'
);

select ok(
  (
    select pg_catalog.bool_and(class.relrowsecurity and class.relforcerowsecurity)
    from pg_catalog.pg_class as class
    join pg_catalog.pg_namespace as namespace
      on namespace.oid = class.relnamespace
    where namespace.nspname = 'public'
      and class.relname in (
        'billing_customers',
        'billing_webhook_receipts',
        'billing_transactions',
        'billing_household_assignments',
        'plan_catalog',
        'household_entitlements'
      )
  ),
  'every public billing table enables and forces RLS'
);
select policies_are(
  'public',
  'billing_customers',
  array['billing_customers_select_self']
);
select policies_are(
  'public',
  'billing_household_assignments',
  array['billing_assignments_select_member']
);
select policies_are(
  'public',
  'plan_catalog',
  array['plan_catalog_select_authenticated']
);
select policies_are(
  'public',
  'household_entitlements',
  array['household_entitlements_select_member']
);
select is(
  (
    select pg_catalog.count(*)
    from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename in ('billing_webhook_receipts', 'billing_transactions')
  ),
  0::bigint,
  'receipt and transaction tables have no client RLS path'
);

select ok(
  has_function_privilege(
    'service_role',
    'public.configure_billing_runtime(text,boolean,bigint,uuid)',
    'execute'
  )
    and has_function_privilege(
      'service_role',
      'public.configure_plan_feature_limits(text,jsonb,boolean,bigint,uuid)',
      'execute'
    )
    and has_function_privilege(
      'authenticated',
      'public.get_household_entitlement(uuid)',
      'execute'
    ),
  'service configuration and authenticated read grants are explicit'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.configure_billing_runtime(text,boolean,bigint,uuid)',
    'execute'
  )
    and not has_function_privilege(
      'authenticated',
      'public.configure_plan_feature_limits(text,jsonb,boolean,bigint,uuid)',
      'execute'
    )
    and not has_function_privilege(
      'authenticated',
      'app_private.assert_household_feature_capacity(uuid,text,integer)',
      'execute'
    ),
  'authenticated clients cannot configure policy or invoke limit authority'
);
select ok(
  not has_table_privilege(
    'service_role',
    'public.billing_webhook_receipts',
    'insert'
  )
    and not has_table_privilege(
      'authenticated',
      'public.billing_transactions',
      'select'
    )
    and not has_table_privilege(
      'authenticated',
      'app_private.billing_entitlement_transitions',
      'select'
    ),
  'provider receipt transaction and audit require mediated server code'
);

-- Every existing/new household starts with a server-owned Free/none row.
select is(
  (select pg_catalog.count(*) from public.household_entitlements),
  (select pg_catalog.count(*) from public.households),
  'migration and seed produce one entitlement for every household'
);
select results_eq(
  $$
    select plan_code, status::text, source, features, will_renew
    from public.household_entitlements
    where household_id = '20000000-0000-4000-8000-000000000101'
  $$,
  $$ values ('free'::text, 'none'::text, 'none'::text, '{}'::jsonb, false) $$,
  'default entitlement is Free none and contains no provisional numeric policy'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select results_eq(
  $$
    select plan_code, status::text, feature_limits,
      limits_finalized, is_billing_owner
    from public.get_household_entitlement(
      '20000000-0000-4000-8000-000000000201'
    )
  $$,
  $$
    values (
      'free'::text,
      'none'::text,
      '{}'::jsonb,
      false,
      false
    )
  $$,
  'default projection returns a concrete false billing-owner flag'
);
reset role;

select throws_ok(
  $$
    select app_private.assert_household_feature_capacity(
      '20000000-0000-4000-8000-000000000101',
      'members',
      1
    )
  $$,
  'KFB10',
  'household feature limits are not finalized',
  'unresolved D-027 limits fail closed when authority is invoked'
);

select results_eq(
  $$
    select processing_status, plan_code, entitlement_status::text
    from pg_temp.apply_billing_test_event(
      'event-disabled',
      'initial_purchase',
      '2026-08-01 00:00:00+00',
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000101',
      'play-disabled-1',
      '20000000-0000-4000-8000-000000000101',
      'active',
      'plus',
      true
    )
  $$,
  $$ values ('quarantined'::text, null::text, null::text) $$,
  'billing ingestion ships disabled before explicit environment setup'
);
select is(
  (
    select last_error_code
    from public.billing_webhook_receipts
    where provider_event_id = 'event-disabled'
  ),
  'BILLING_DISABLED',
  'disabled ingestion uses a stable quarantine code'
);

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-4000-8000-000000000301',
  'authenticated',
  'authenticated',
  'billing-trigger@local.kinflow.invalid',
  pg_catalog.now(),
  '{"provider":"local_fixture","providers":["local_fixture"]}'::jsonb,
  '{}'::jsonb,
  pg_catalog.now(),
  pg_catalog.now()
);
insert into public.profiles(
  id,
  auth_user_id,
  display_name,
  locale,
  timezone
) values (
  '10000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000301',
  'Billing Trigger',
  'en',
  'UTC'
);
insert into public.households(
  id,
  name,
  timezone,
  owner_member_id,
  created_by_user_id
) values (
  '20000000-0000-4000-8000-000000000301',
  'Billing Trigger Household',
  'UTC',
  '30000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000301'
);
insert into public.household_members(
  id,
  household_id,
  auth_user_id,
  display_name,
  role,
  created_by_user_id
) values (
  '30000000-0000-4000-8000-000000000301',
  '20000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000301',
  'Billing Trigger',
  'owner',
  '00000000-0000-4000-8000-000000000301'
);
select results_eq(
  $$
    select plan_code, status::text
    from public.household_entitlements
    where household_id = '20000000-0000-4000-8000-000000000301'
  $$,
  $$ values ('free'::text, 'none'::text) $$,
  'new-household trigger creates the same authoritative default'
);

-- Versioned runtime and feature policies.
select lives_ok(
  $$
    select * from public.configure_billing_runtime(
      'sandbox',
      true,
      1,
      '60000000-0000-4000-8000-000000000001'
    )
  $$,
  'service runtime can explicitly enable only sandbox ingestion'
);
select results_eq(
  $$
    select accepted_environment, ingestion_enabled, version
    from app_private.billing_runtime_config
  $$,
  $$ values ('sandbox'::text, true, 2::bigint) $$,
  'runtime configuration advances optimistic version'
);
select throws_ok(
  $$
    select * from public.configure_billing_runtime(
      'production',
      true,
      1,
      '60000000-0000-4000-8000-000000000002'
    )
  $$,
  'KFB30',
  'billing runtime version conflict',
  'stale runtime policy writes are rejected'
);
select throws_ok(
  $$
    select * from public.configure_plan_feature_limits(
      'free',
      '{"members": 2.5}'::jsonb,
      true,
      1,
      '60000000-0000-4000-8000-000000000003'
    )
  $$,
  '22023',
  'invalid billing plan policy',
  'fractional feature limits are rejected'
);
select lives_ok(
  $$
    select * from public.configure_plan_feature_limits(
      'free',
      '{"members": 2, "activeSeries": 2}'::jsonb,
      true,
      1,
      '60000000-0000-4000-8000-000000000004'
    )
  $$,
  'Free feature limits can be finalized without pricing'
);
select lives_ok(
  $$
    select * from public.configure_plan_feature_limits(
      'plus',
      '{"members": 10, "activeSeries": 100}'::jsonb,
      true,
      1,
      '60000000-0000-4000-8000-000000000005'
    )
  $$,
  'Plus feature limits can be finalized independently of Store catalog'
);
select throws_ok(
  $$
    select * from public.configure_plan_feature_limits(
      'plus',
      '{"members": 1, "activeSeries": 1}'::jsonb,
      true,
      2,
      '60000000-0000-4000-8000-000000000006'
    )
  $$,
  'KFB32',
  'Plus limits cannot be lower than Free limits',
  'Plus cannot be configured below finalized Free capacity'
);
select is(
  app_private.current_household_feature_usage(
    '20000000-0000-4000-8000-000000000101',
    'members'
  ),
  2::bigint,
  'server computes active household member usage without a client count'
);
select is(
  app_private.current_household_feature_usage(
    '20000000-0000-4000-8000-000000000101',
    'activeSeries'
  ),
  0::bigint,
  'server computes combined active chore and event series usage'
);
select throws_ok(
  $$
    select app_private.assert_household_feature_capacity(
      '20000000-0000-4000-8000-000000000101',
      'members',
      1
    )
  $$,
  'KFB12',
  'household feature limit reached',
  'Free household cannot exceed finalized member capacity'
);
select is(
  app_private.assert_household_feature_capacity(
    '20000000-0000-4000-8000-000000000101',
    'activeSeries',
    2
  ),
  0::bigint,
  'capacity assertion returns exact remaining Free capacity'
);
select throws_ok(
  $$
    select app_private.assert_household_feature_capacity(
      '20000000-0000-4000-8000-000000000101',
      'unknownFeature',
      1
    )
  $$,
  'KFB11',
  'household feature limit is not configured',
  'missing policy key fails closed'
);

-- Service-only event ingestion and exact identity/environment gates.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.apply_verified_billing_event(
      'revenuecat', 'sandbox', 'event-denied', 'initial_purchase',
      '2026-08-01 00:00:00+00',
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000101',
      'transaction-denied', null, 'kinflow_plus_monthly', 'play_store',
      '20000000-0000-4000-8000-000000000101',
      'active', 'plus',
      '2026-08-01 00:00:00+00', '2026-09-01 00:00:00+00', true,
      null, null, '60000000-0000-4000-8000-000000000007'
    )
  $$,
  '42501',
  'permission denied for function apply_verified_billing_event',
  'authenticated client cannot submit a verified provider event'
);
reset role;

select results_eq(
  $$
    select processing_status, duplicate, household_id, plan_code,
      entitlement_status::text
    from pg_temp.apply_billing_test_event(
      'event-production',
      'initial_purchase',
      '2026-08-01 00:00:00+00',
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000101',
      'play-production-1',
      '20000000-0000-4000-8000-000000000101',
      'active',
      'plus',
      true,
      'production'
    )
  $$,
  $$
    values (
      'quarantined'::text,
      false,
      '20000000-0000-4000-8000-000000000101'::uuid,
      null::text,
      null::text
    )
  $$,
  'production event is quarantined while sandbox is the accepted environment'
);
select is(
  (
    select last_error_code
    from public.billing_webhook_receipts
    where provider_event_id = 'event-production'
  ),
  'ENVIRONMENT_MISMATCH',
  'environment quarantine uses a stable non-sensitive code'
);

select results_eq(
  $$
    select processing_status, plan_code, entitlement_status::text
    from pg_temp.apply_billing_test_event(
      'event-identity',
      'initial_purchase',
      '2026-08-01 00:00:00+00',
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'play-identity-1',
      '20000000-0000-4000-8000-000000000101',
      'active',
      'plus',
      true
    )
  $$,
  $$ values ('quarantined'::text, null::text, null::text) $$,
  'household ID cannot be used as a RevenueCat customer identity'
);
select is(
  (
    select last_error_code
    from public.billing_webhook_receipts
    where provider_event_id = 'event-identity'
  ),
  'IDENTITY_MISMATCH',
  'identity mismatch is retained without creating a customer'
);

-- Initial purchase materialization and exact replay.
select results_eq(
  $$
    select processing_status, duplicate, plan_code,
      entitlement_status::text
    from pg_temp.apply_billing_test_event(
      'event-active-1',
      'initial_purchase',
      '2026-08-01 00:00:00+00',
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000101',
      'play-order-1',
      '20000000-0000-4000-8000-000000000101',
      'active',
      'plus',
      true
    )
  $$,
  $$ values ('applied'::text, false, 'plus'::text, 'active'::text) $$,
  'verified initial purchase materializes server Plus'
);
select is(
  (select pg_catalog.count(*) from public.billing_customers),
  1::bigint,
  'one provider customer is materialized'
);
select is(
  (select pg_catalog.count(*) from public.billing_transactions),
  1::bigint,
  'one normalized transaction is materialized'
);
select is(
  (select pg_catalog.count(*) from public.billing_household_assignments),
  1::bigint,
  'one customer-to-household assignment is materialized'
);
select is(
  (select pg_catalog.count(*) from app_private.billing_entitlement_transitions),
  1::bigint,
  'one content-free entitlement transition is appended'
);
select results_eq(
  $$
    select customer.auth_user_id, customer.provider_customer_ref,
      assignment.billing_owner_user_id, assignment.household_id,
      entitlement.plan_code, entitlement.status::text,
      entitlement.features
    from public.billing_customers as customer
    join public.billing_household_assignments as assignment
      on assignment.billing_customer_id = customer.id
    join public.household_entitlements as entitlement
      on entitlement.assignment_id = assignment.id
  $$,
  $$
    values (
      '00000000-0000-4000-8000-000000000101'::uuid,
      '00000000-0000-4000-8000-000000000101'::text,
      '00000000-0000-4000-8000-000000000101'::uuid,
      '20000000-0000-4000-8000-000000000101'::uuid,
      'plus'::text,
      'active'::text,
      '{"members": 10, "activeSeries": 100}'::jsonb
    )
  $$,
  'customer owner household and finalized Plus features remain separate and exact'
);
select is(
  app_private.assert_household_feature_capacity(
    '20000000-0000-4000-8000-000000000101',
    'members',
    1
  ),
  7::bigint,
  'server capacity immediately follows authoritative Plus entitlement'
);

select results_eq(
  $$
    select processing_status, duplicate, plan_code,
      entitlement_status::text
    from pg_temp.apply_billing_test_event(
      'event-active-1',
      'initial_purchase',
      '2026-08-01 00:00:00+00',
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000101',
      'play-order-1',
      '20000000-0000-4000-8000-000000000101',
      'active',
      'plus',
      true
    )
  $$,
  $$ values ('applied'::text, true, 'plus'::text, 'active'::text) $$,
  'exact provider event replay returns the existing result'
);
select is(
  (
    select replay_count
    from public.billing_webhook_receipts
    where provider_event_id = 'event-active-1'
  ),
  1,
  'exact replay increments only receipt replay metadata'
);
select is(
  (select pg_catalog.count(*) from public.billing_transactions),
  1::bigint,
  'exact replay creates no duplicate transaction'
);
select is(
  (select pg_catalog.count(*) from app_private.billing_entitlement_transitions),
  1::bigint,
  'exact replay appends no duplicate transition'
);
select throws_ok(
  $$
    select * from pg_temp.apply_billing_test_event(
      'event-active-1',
      'cancellation',
      '2026-08-01 00:00:00+00',
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000101',
      'play-order-1',
      '20000000-0000-4000-8000-000000000101',
      'active',
      'plus',
      false
    )
  $$,
  'KFB20',
  'billing event ID was reused with different normalized data',
  'same event ID with different normalized state is rejected'
);

-- Older and equal-time events cannot regress the customer aggregate.
select results_eq(
  $$
    select processing_status, plan_code, entitlement_status::text
    from pg_temp.apply_billing_test_event(
      'event-old-expiration',
      'expiration',
      '2026-07-31 23:59:59+00',
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000101',
      'play-order-1',
      '20000000-0000-4000-8000-000000000101',
      'expired',
      'free',
      false
    )
  $$,
  $$ values ('stale'::text, 'plus'::text, 'active'::text) $$,
  'out-of-order expiration is recorded stale without entitlement regression'
);
select results_eq(
  $$
    select processing_status, plan_code, entitlement_status::text
    from pg_temp.apply_billing_test_event(
      'event-same-time',
      'cancellation',
      '2026-08-01 00:00:00+00',
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000101',
      'play-order-1',
      '20000000-0000-4000-8000-000000000101',
      'active',
      'plus',
      false
    )
  $$,
  $$ values ('quarantined'::text, 'plus'::text, 'active'::text) $$,
  'different same-time event is quarantined instead of arrival-order overwrite'
);
select is(
  (select pg_catalog.count(*) from app_private.billing_entitlement_transitions),
  1::bigint,
  'stale and ambiguous events append no entitlement transition'
);

-- Cancellation remains paid through period end; lifecycle changes preserve data.
select results_eq(
  $$
    select processing_status, plan_code, entitlement_status::text
    from pg_temp.apply_billing_test_event(
      'event-cancel-1',
      'cancellation',
      '2026-08-02 00:00:00+00',
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000101',
      'play-order-1',
      '20000000-0000-4000-8000-000000000101',
      'active',
      'plus',
      false
    )
  $$,
  $$ values ('applied'::text, 'plus'::text, 'active'::text) $$,
  'cancellation keeps Plus active while marking will-renew false'
);
select is(
  (
    select will_renew
    from public.household_entitlements
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  false,
  'authoritative cancellation does not imply immediate expiry'
);
select results_eq(
  $$
    select processing_status, plan_code, entitlement_status::text
    from pg_temp.apply_billing_test_event(
      'event-grace-1',
      'grace',
      '2026-08-03 00:00:00+00',
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000101',
      'play-order-1',
      '20000000-0000-4000-8000-000000000101',
      'grace',
      'plus',
      false
    )
  $$,
  $$ values ('applied'::text, 'plus'::text, 'grace'::text) $$,
  'grace lifecycle remains an explicit Plus state'
);
select results_eq(
  $$
    select processing_status, plan_code, entitlement_status::text
    from pg_temp.apply_billing_test_event(
      'event-issue-1',
      'billing_issue',
      '2026-08-04 00:00:00+00',
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000101',
      'play-order-1',
      '20000000-0000-4000-8000-000000000101',
      'billing_issue',
      'plus',
      false
    )
  $$,
  $$ values ('applied'::text, 'plus'::text, 'billing_issue'::text) $$,
  'billing issue state can retain Plus under a later policy'
);

select is(
  (select pg_catalog.count(*) from public.households),
  3::bigint,
  'family household count is captured before downgrade'
);
select is(
  (select pg_catalog.count(*) from public.household_members),
  4::bigint,
  'family member count is captured before downgrade'
);
select results_eq(
  $$
    select processing_status, plan_code, entitlement_status::text
    from pg_temp.apply_billing_test_event(
      'event-expire-1',
      'expiration',
      '2026-08-05 00:00:00+00',
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000101',
      'play-order-1',
      '20000000-0000-4000-8000-000000000101',
      'expired',
      'free',
      false
    )
  $$,
  $$ values ('applied'::text, 'free'::text, 'expired'::text) $$,
  'expiration materializes Free without deleting assignment ownership'
);
select is(
  (select pg_catalog.count(*) from public.households),
  3::bigint,
  'expiration deletes no household data'
);
select is(
  (select pg_catalog.count(*) from public.household_members),
  4::bigint,
  'expiration deletes no member data'
);
select is(
  (
    select pg_catalog.count(*)
    from public.billing_household_assignments
    where status = 'active'
  ),
  1::bigint,
  'expired purchase stays assigned to prevent silent restore theft'
);
select results_eq(
  $$
    select processing_status, plan_code, entitlement_status::text
    from pg_temp.apply_billing_test_event(
      'event-revoke-1',
      'revoke',
      '2026-08-06 00:00:00+00',
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000101',
      'play-order-1',
      '20000000-0000-4000-8000-000000000101',
      'revoked',
      'free',
      false
    )
  $$,
  $$ values ('applied'::text, 'free'::text, 'revoked'::text) $$,
  'refund or revoke remains distinct from natural expiration'
);
select results_eq(
  $$
    select processing_status, plan_code, entitlement_status::text
    from pg_temp.apply_billing_test_event(
      'event-restore-1',
      'reconciliation',
      '2026-08-07 00:00:00+00',
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000101',
      'play-order-1',
      '20000000-0000-4000-8000-000000000101',
      'active',
      'plus',
      true
    )
  $$,
  $$ values ('applied'::text, 'plus'::text, 'active'::text) $$,
  'newer reconciliation can restore the same bound household'
);

-- Mapping conflict matrix is quarantined without moving Plus.
select results_eq(
  $$
    select processing_status, plan_code, entitlement_status::text
    from pg_temp.apply_billing_test_event(
      'event-customer-household-conflict',
      'reconciliation',
      '2026-08-08 00:00:00+00',
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000101',
      'play-order-2',
      '20000000-0000-4000-8000-000000000201',
      'active',
      'plus',
      true
    )
  $$,
  $$ values ('quarantined'::text, 'free'::text, 'none'::text) $$,
  'same customer cannot silently move to another household'
);
select is(
  (
    select last_error_code
    from public.billing_webhook_receipts
    where provider_event_id = 'event-customer-household-conflict'
  ),
  'ASSIGNMENT_CUSTOMER_CONFLICT',
  'customer-to-household conflict has a stable remediation code'
);

insert into public.household_members(
  id,
  household_id,
  auth_user_id,
  display_name,
  role,
  created_by_user_id
) values (
  '30000000-0000-4000-8000-000000000202',
  '20000000-0000-4000-8000-000000000201',
  '00000000-0000-4000-8000-000000000102',
  'Adult B',
  'member',
  '00000000-0000-4000-8000-000000000201'
);
select results_eq(
  $$
    select processing_status, plan_code, entitlement_status::text
    from pg_temp.apply_billing_test_event(
      'event-member-assignment',
      'initial_purchase',
      '2026-08-02 00:00:00+00',
      '00000000-0000-4000-8000-000000000102',
      '00000000-0000-4000-8000-000000000102',
      'play-member-1',
      '20000000-0000-4000-8000-000000000201',
      'active',
      'plus',
      true
    )
  $$,
  $$ values ('quarantined'::text, 'free'::text, 'none'::text) $$,
  'ordinary member cannot create an initial paid-household assignment'
);
select is(
  (
    select last_error_code
    from public.billing_webhook_receipts
    where provider_event_id = 'event-member-assignment'
  ),
  'INITIAL_ASSIGNMENT_FORBIDDEN',
  'initial assignment role denial is explicit and content-free'
);

select results_eq(
  $$
    select processing_status, plan_code, entitlement_status::text
    from pg_temp.apply_billing_test_event(
      'event-transaction-conflict',
      'initial_purchase',
      '2026-08-03 00:00:00+00',
      '00000000-0000-4000-8000-000000000201',
      '00000000-0000-4000-8000-000000000201',
      'play-order-1',
      '20000000-0000-4000-8000-000000000201',
      'active',
      'plus',
      true
    )
  $$,
  $$ values ('quarantined'::text, 'free'::text, 'none'::text) $$,
  'same transaction hash cannot bind to a second customer'
);
select is(
  (
    select last_error_code
    from public.billing_webhook_receipts
    where provider_event_id = 'event-transaction-conflict'
  ),
  'TRANSACTION_CUSTOMER_CONFLICT',
  'transaction ownership conflict is quarantined for support'
);

-- Client read is membership-scoped and excludes provider material.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select results_eq(
  $$
    select entitlement_key, plan_code, status::text, source,
      feature_limits, limits_finalized, is_billing_owner
    from public.get_household_entitlement(
      '20000000-0000-4000-8000-000000000101'
    )
  $$,
  $$
    values (
      'plus'::text,
      'plus'::text,
      'active'::text,
      'play_store'::text,
      '{"members": 10, "activeSeries": 100}'::jsonb,
      true,
      false
    )
  $$,
  'household member reads authoritative Plus without billing-owner identity'
);
select is(
  (select pg_catalog.count(*) from public.billing_customers),
  1::bigint,
  'member sees only its own quarantined customer mapping and not purchaser row'
);
select is(
  (
    select pg_catalog.count(*)
    from public.billing_customers
    where auth_user_id = '00000000-0000-4000-8000-000000000101'
  ),
  0::bigint,
  'member cannot read the purchaser customer identity'
);
select is(
  (select pg_catalog.count(*) from public.billing_household_assignments),
  1::bigint,
  'household member can read the household assignment under RLS'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$
    select * from public.get_household_entitlement(
      '20000000-0000-4000-8000-000000000101'
    )
  $$,
  '42501',
  'active household membership required',
  'cross-household entitlement projection is denied'
);
select is(
  (
    select pg_catalog.count(*)
    from public.household_entitlements
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  0::bigint,
  'direct cross-household entitlement read is filtered by RLS'
);
reset role;

select throws_ok(
  $$
    update app_private.billing_entitlement_transitions
    set next_plan_code = 'free'
    where id = (
      select pg_catalog.min(transition.id)
      from app_private.billing_entitlement_transitions as transition
    )
  $$,
  '42501',
  'billing audit records are immutable',
  'entitlement transition audit cannot be rewritten'
);
select throws_ok(
  $$
    delete from app_private.billing_policy_events
  $$,
  '42501',
  'billing audit records are immutable',
  'runtime and plan policy audit cannot be deleted'
);

select is(
  (
    select pg_catalog.count(*)
    from app_private.billing_entitlement_transitions
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  7::bigint,
  'only applied lifecycle events append immutable transitions'
);
select ok(
  not exists (
    select 1
    from app_private.billing_entitlement_transitions as transition
    where transition.event_type is null
      or transition.correlation_id is null
  ),
  'audit records retain stable event type correlation and no raw payload'
);

select * from finish();
rollback;
