begin;
set constraints all deferred;

select no_plan();

select has_table(
  'public',
  'privacy_requests',
  'privacy request aggregate exists'
);
select has_table(
  'app_private',
  'account_deletion_jobs',
  'private deletion worker jobs exist'
);
select has_table(
  'app_private',
  'account_deletion_command_requests',
  'private deletion idempotency records exist'
);
select has_table(
  'app_private',
  'account_deletion_events',
  'private deletion audit events exist'
);
select has_table(
  'app_private',
  'privacy_runtime_events',
  'private runtime policy audit exists'
);
select has_function(
  'public',
  'request_account_deletion',
  array['uuid', 'text', 'boolean', 'uuid']
);
select has_function(
  'public',
  'cancel_account_deletion',
  array['uuid', 'uuid', 'bigint', 'text', 'uuid']
);
select has_function(
  'public',
  'claim_account_deletion_requests',
  array['uuid', 'integer', 'integer', 'timestamp with time zone']
);
select has_function(
  'public',
  'prepare_account_deletion_request',
  array['uuid', 'uuid', 'timestamp with time zone']
);
select has_function(
  'public',
  'complete_account_deletion_request',
  array['uuid', 'uuid', 'timestamp with time zone']
);
select has_function(
  'public',
  'fail_account_deletion_request',
  array['uuid', 'uuid', 'text', 'boolean', 'timestamp with time zone']
);

select ok(
  has_function_privilege(
    'service_role',
    'public.request_account_deletion(uuid,text,boolean,uuid)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.request_account_deletion(uuid,text,boolean,uuid)',
    'execute'
  )
  and has_function_privilege(
    'service_role',
    'public.claim_account_deletion_requests(uuid,integer,integer,timestamptz)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.claim_account_deletion_requests(uuid,integer,integer,timestamptz)',
    'execute'
  ),
  'Edge-mediated account commands and worker RPCs are service-only'
);

select ok(
  not has_table_privilege('authenticated', 'public.privacy_requests', 'insert')
  and not has_table_privilege(
    'authenticated',
    'public.privacy_requests',
    'update'
  )
  and not has_table_privilege(
    'authenticated',
    'app_private.account_deletion_jobs',
    'select'
  ),
  'clients cannot bypass the account deletion state machine or read leases'
);

-- Preserve one shared chore assigned to the deleting non-Owner.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '71000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Shared deletion fixture',
      'Must survive identity deletion',
      '30000000-0000-4000-8000-000000000102',
      current_date + 1,
      '09:00'::time
    )
  $$,
  'shared chore fixture is created through its authoritative command'
);
reset role;

-- Synthetic confirmed subscription for Adult B exercises explicit guidance.
insert into public.billing_customers (
  id,
  auth_user_id,
  provider,
  environment,
  provider_customer_ref,
  provider_customer_ref_hash
) values (
  '72000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000102',
  'revenuecat',
  'sandbox',
  '00000000-0000-4000-8000-000000000102',
  extensions.digest(
    convert_to('00000000-0000-4000-8000-000000000102', 'UTF8'),
    'sha256'
  )
);

insert into public.billing_household_assignments (
  id,
  billing_customer_id,
  billing_owner_user_id,
  household_id,
  status,
  assigned_at
) values (
  '72000000-0000-4000-8000-000000000002',
  '72000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000102',
  '20000000-0000-4000-8000-000000000101',
  'active',
  pg_catalog.statement_timestamp()
);

update public.household_entitlements as entitlement
set assignment_id = '72000000-0000-4000-8000-000000000002',
    billing_owner_user_id = '00000000-0000-4000-8000-000000000102',
    plan_code = 'plus',
    status = 'active',
    source = 'play_store',
    product_id = 'kinflow_plus_monthly',
    current_period_start = pg_catalog.statement_timestamp(),
    current_period_end = pg_catalog.statement_timestamp() + interval '30 days',
    will_renew = true,
    provider_updated_at = pg_catalog.statement_timestamp(),
    verified_at = pg_catalog.statement_timestamp()
where entitlement.household_id = '20000000-0000-4000-8000-000000000101';

insert into public.notification_endpoints (
  id,
  auth_user_id,
  household_id,
  member_id,
  installation_id,
  channel,
  platform,
  token_ciphertext,
  token_fingerprint,
  token_key_version,
  revocation_secret_hash,
  permission_state,
  locale,
  timezone,
  app_version,
  runtime_version,
  last_registration_id,
  last_seen_at
) values (
  '73000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000102',
  '20000000-0000-4000-8000-000000000101',
  '30000000-0000-4000-8000-000000000102',
  '73000000-0000-4000-8000-000000000002',
  'native_push',
  'android',
  pg_catalog.decode(pg_catalog.repeat('ab', 29), 'hex'),
  extensions.digest(convert_to('provider-token', 'UTF8'), 'sha256'),
  1,
  extensions.digest(convert_to('revocation-proof', 'UTF8'), 'sha256'),
  'granted',
  'ko',
  'Asia/Seoul',
  '1.0.0',
  '3.44.7',
  '73000000-0000-4000-8000-000000000003',
  pg_catalog.statement_timestamp()
);

insert into public.notification_preferences (
  auth_user_id,
  household_id,
  category,
  timezone
) values (
  '00000000-0000-4000-8000-000000000102',
  '20000000-0000-4000-8000-000000000101',
  'chore_due',
  'Asia/Seoul'
);

insert into public.household_invites (
  id,
  household_id,
  role,
  token_hash,
  status,
  expires_at,
  created_by_member_id
) values (
  '74000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000101',
  'member',
  extensions.digest(convert_to('account-delete-invite', 'UTF8'), 'sha256'),
  'active',
  pg_catalog.statement_timestamp() + interval '7 days',
  '30000000-0000-4000-8000-000000000102'
);

set local role service_role;

select results_eq(
  $$
    select can_request, owner_household_count, has_active_subscription,
      pending_request_id is null, requests_enabled,
      cancellation_window_seconds
    from public.get_account_deletion_preflight(
      '00000000-0000-4000-8000-000000000101'
    )
  $$,
  $$ values (false, 1, false, true, true, 86400) $$,
  'an active Owner must transfer or delete each household first'
);

select results_eq(
  $$
    select can_request, owner_household_count, has_active_subscription,
      pending_request_id is null, requests_enabled,
      cancellation_window_seconds
    from public.get_account_deletion_preflight(
      '00000000-0000-4000-8000-000000000102'
    )
  $$,
  $$ values (true, 0, true, true, true, 86400) $$,
  'a non-Owner receives a safe active-subscription preflight'
);

select throws_ok(
  $$
    select * from public.request_account_deletion(
      '00000000-0000-4000-8000-000000000101',
      'owner-request-key-0001',
      false,
      '75000000-0000-4000-8000-000000000001'
    )
  $$,
  'KFP08',
  'owner transfer required before account deletion',
  'request RPC enforces the last-Owner rule again'
);

select throws_ok(
  $$
    select * from public.request_account_deletion(
      '00000000-0000-4000-8000-000000000102',
      'subscription-key-0001',
      false,
      '75000000-0000-4000-8000-000000000002'
    )
  $$,
  'KFP09',
  'active subscription acknowledgement required',
  'active Store subscription cannot be silently orphaned'
);

select results_eq(
  $$
    select status, active_subscription_at_request,
      subscription_acknowledged, cancellable,
      scheduled_for > requested_at, version
    from public.request_account_deletion(
      '00000000-0000-4000-8000-000000000102',
      'cancel-path-key-0001',
      true,
      '75000000-0000-4000-8000-000000000003'
    )
  $$,
  $$ values ('queued'::text, true, true, true, true, 1::bigint) $$,
  'recent-auth mediated request is queued with a cancellation window'
);

select is(
  (
    select count(*)
    from public.request_account_deletion(
      '00000000-0000-4000-8000-000000000102',
      'cancel-path-key-0001',
      true,
      '75000000-0000-4000-8000-000000000003'
    )
  ),
  1::bigint,
  'identical request idempotency replays one safe projection'
);

select throws_ok(
  $$
    select * from public.request_account_deletion(
      '00000000-0000-4000-8000-000000000102',
      'cancel-path-key-0001',
      false,
      '75000000-0000-4000-8000-000000000003'
    )
  $$,
  'KFP04',
  'account deletion idempotency key reused',
  'same key with a different acknowledgment is rejected'
);

select results_eq(
  $$
    select status, cancellable, version
    from public.cancel_account_deletion(
      '00000000-0000-4000-8000-000000000102',
      (
        select request.request_id
        from public.get_account_deletion_request(
          '00000000-0000-4000-8000-000000000102',
          null
        ) as request
        where request.status = 'queued'
      ),
      1,
      'cancel-command-key-0001',
      '75000000-0000-4000-8000-000000000004'
    )
  $$,
  $$ values ('cancelled'::text, false, 2::bigint) $$,
  'queued request can be cancelled with optimistic versioning'
);

select results_eq(
  $$
    select status, version
    from public.cancel_account_deletion(
      '00000000-0000-4000-8000-000000000102',
      (
        select request.request_id
        from public.get_account_deletion_request(
          '00000000-0000-4000-8000-000000000102',
          null
        ) as request
        where request.status = 'cancelled'
      ),
      1,
      'cancel-command-key-0001',
      '75000000-0000-4000-8000-000000000004'
    )
  $$,
  $$ values ('cancelled'::text, 2::bigint) $$,
  'cancel idempotency replay remains stable after the version changes'
);

select lives_ok(
  $$
    select * from public.request_account_deletion(
      '00000000-0000-4000-8000-000000000102',
      'processing-path-key-01',
      true,
      '75000000-0000-4000-8000-000000000005'
    )
  $$,
  'a new request can follow a cancelled request'
);

select is(
  (
    select count(*)
    from public.claim_account_deletion_requests(
      '76000000-0000-4000-8000-000000000001',
      5,
      300,
      pg_catalog.clock_timestamp()
    )
  ),
  0::bigint,
  'worker cannot bypass the cancellation delay'
);

create temporary table account_deletion_test_clock on commit drop as
select pg_catalog.clock_timestamp() + interval '25 hours' as claimed_at;

create temporary table account_deletion_claim on commit drop as
select claim.*
from account_deletion_test_clock as test_clock
cross join lateral public.claim_account_deletion_requests(
  '76000000-0000-4000-8000-000000000001',
  5,
  300,
  test_clock.claimed_at
) as claim;

select is(
  (select count(*) from account_deletion_claim),
  1::bigint,
  'one due request is claimed with a private lease'
);
select results_eq(
  $$ select attempts, request_version from account_deletion_claim $$,
  $$ values (1, 2::bigint) $$,
  'claim increments attempt and public request versions'
);

select is(
  (
    select count(*)
    from account_deletion_test_clock as test_clock
    cross join lateral public.claim_account_deletion_requests(
      '76000000-0000-4000-8000-000000000099',
      5,
      300,
      test_clock.claimed_at
    )
  ),
  0::bigint,
  'a competing worker cannot claim an already leased deletion request'
);

select results_eq(
  $$
    select affected_membership_count, erased_endpoint_count,
      revoked_invite_count, already_tombstoned
    from account_deletion_claim as claim
    cross join account_deletion_test_clock as test_clock
    cross join lateral public.prepare_account_deletion_request(
      claim.privacy_request_id,
      claim.lease_token,
      test_clock.claimed_at + interval '10 seconds'
    )
  $$,
  $$ values (1, 1, 1, false) $$,
  'prepare tombstones identity and erases device material atomically'
);

select results_eq(
  $$
    select status, failure_code, next_attempt_at is not null, version
    from account_deletion_claim as claim
    cross join account_deletion_test_clock as test_clock
    cross join lateral public.fail_account_deletion_request(
      claim.privacy_request_id,
      claim.lease_token,
      'AUTH_DELETE_UNAVAILABLE',
      true,
      test_clock.claimed_at + interval '20 seconds'
    )
  $$,
  $$ values ('processing'::text, 'AUTH_DELETE_UNAVAILABLE'::text, true, 3::bigint) $$,
  'transient Auth deletion failure schedules a retry without reopening cancel'
);

create temporary table account_deletion_retry_claim on commit drop as
select claim.*
from account_deletion_test_clock as test_clock
cross join lateral public.claim_account_deletion_requests(
  '76000000-0000-4000-8000-000000000002',
  5,
  300,
  test_clock.claimed_at + interval '2 minutes'
) as claim;

select results_eq(
  $$ select attempts, request_version from account_deletion_retry_claim $$,
  $$ values (2, 4::bigint) $$,
  'retry obtains a new lease without duplicating the request'
);

select results_eq(
  $$
    select affected_membership_count, erased_endpoint_count,
      revoked_invite_count, already_tombstoned
    from account_deletion_retry_claim as claim
    cross join account_deletion_test_clock as test_clock
    cross join lateral public.prepare_account_deletion_request(
      claim.privacy_request_id,
      claim.lease_token,
      test_clock.claimed_at + interval '130 seconds'
    )
  $$,
  $$ values (0, 0, 0, true) $$,
  'prepare replay never repeats destructive tombstone work'
);

select results_eq(
  $$
    select status, completed_at is not null, version
    from account_deletion_retry_claim as claim
    cross join account_deletion_test_clock as test_clock
    cross join lateral public.complete_account_deletion_request(
      claim.privacy_request_id,
      claim.lease_token,
      test_clock.claimed_at + interval '140 seconds'
    )
  $$,
  $$ values ('completed'::text, true, 5::bigint) $$,
  'verified Auth soft-delete completion closes the request'
);

reset role;

select results_eq(
  $$
    select display_name, avatar_key is null, deleted_at is not null
    from public.profiles
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
  $$,
  $$ values ('Deleted account'::text, true, true) $$,
  'profile direct identifiers are tombstoned'
);
select results_eq(
  $$
    select display_name, avatar_key is null, removed_at is not null,
      identity_deleted_at is not null
    from public.household_members
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
  $$,
  $$ values ('Deleted member'::text, true, true, true) $$,
  'shared membership row survives as a removed identity tombstone'
);
select is(
  (
    select count(*) from public.chore_occurrences
    where household_id = '20000000-0000-4000-8000-000000000101'
      and assignee_member_id = '30000000-0000-4000-8000-000000000102'
  ),
  1::bigint,
  'shared chore history remains linked to the tombstone member'
);
select results_eq(
  $$
    select status::text, revoked_at is not null
    from public.household_invites
    where id = '74000000-0000-4000-8000-000000000001'
  $$,
  $$ values ('revoked'::text, true) $$,
  'active invitations created by the deleted member are revoked'
);
select results_eq(
  $$
    select revocation_reason, permission_state,
      token_ciphertext = decode(repeat('00', 29), 'hex'),
      token_fingerprint <>
        extensions.digest(convert_to('provider-token', 'UTF8'), 'sha256'),
      revocation_secret_hash <>
        extensions.digest(convert_to('revocation-proof', 'UTF8'), 'sha256')
    from public.notification_endpoints
    where id = '73000000-0000-4000-8000-000000000001'
  $$,
  $$ values ('account_deleted'::text, 'denied'::text, true, true, true) $$,
  'server endpoint ciphertext fingerprint and proof are irreversibly erased'
);
select is(
  (
    select count(*) from public.notification_preferences
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
  ),
  0::bigint,
  'personal notification preferences are removed'
);
select is(
  (
    select count(*) from public.user_active_households
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
  ),
  0::bigint,
  'active household selection is purged'
);
select results_eq(
  $$
    select assignment.status, entitlement.status::text,
      entitlement.plan_code
    from public.billing_household_assignments as assignment
    join public.household_entitlements as entitlement
      on entitlement.assignment_id = assignment.id
    where assignment.billing_owner_user_id =
      '00000000-0000-4000-8000-000000000102'
  $$,
  $$ values ('active'::text, 'active'::text, 'plus'::text) $$,
  'billing evidence and household entitlement survive account identity deletion'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (select count(*) from public.profiles),
  0::bigint,
  'old JWT cannot read its tombstoned profile'
);
select is(
  (select count(*) from public.billing_customers),
  0::bigint,
  'old JWT cannot read retained billing customer evidence'
);
select is(
  (select count(*) from public.billing_household_assignments),
  0::bigint,
  'old JWT loses billing-owner and household-member reads'
);
select is(
  (
    select count(*) from public.privacy_requests
    where status = 'completed'
  ),
  1::bigint,
  'only the caller-safe privacy status remains visible to an old JWT'
);
select is(
  app_private.is_current_user_active(),
  false,
  'central active-account authorization closes after tombstone'
);
reset role;

select throws_ok(
  $$
    update public.household_members
    set removed_at = null,
        identity_deleted_at = null
    where auth_user_id = '00000000-0000-4000-8000-000000000102'
  $$,
  'KFP13',
  'deleted account cannot hold an active membership',
  'old identity cannot be reactivated into a household'
);

select throws_ok(
  $$ update app_private.account_deletion_events set transition = 'failed' $$,
  'KFP30',
  'account deletion audit is immutable',
  'deletion audit cannot be rewritten'
);

set local role service_role;
select results_eq(
  $$
    select account_deletion_requests_enabled,
      cancellation_window_seconds, version
    from public.configure_account_deletion_runtime(
      false,
      86400,
      1,
      '79000000-0000-4000-8000-000000000001'
    )
  $$,
  $$ values (false, 86400, 2::bigint) $$,
  'service runtime flag can pause new requests without deleting queued audit'
);
reset role;

select results_eq(
  $$
    select previous_enabled, next_enabled, previous_version,
      next_version, correlation_id
    from app_private.privacy_runtime_events
  $$,
  $$
    values (
      true,
      false,
      1::bigint,
      2::bigint,
      '79000000-0000-4000-8000-000000000001'::uuid
    )
  $$,
  'runtime configuration change leaves immutable versioned evidence'
);

select * from finish();
rollback;
