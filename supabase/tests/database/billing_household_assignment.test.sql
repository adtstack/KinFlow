begin;
set constraints all deferred;

select no_plan();

-- Schema, mediated APIs, and privacy boundaries.
select has_table(
  'app_private',
  'billing_assignment_intents',
  'private assignment intent records exist'
);
select has_table(
  'app_private',
  'billing_assignment_release_results',
  'private release idempotency records exist'
);
select has_table(
  'app_private',
  'billing_assignment_remediation_requests',
  'private remediation requests exist'
);
select has_table(
  'app_private',
  'billing_assignment_remediation_command_results',
  'private remediation idempotency aliases exist'
);
select has_table(
  'app_private',
  'billing_assignment_transitions',
  'private immutable assignment transitions exist'
);
select has_table(
  'app_private',
  'billing_assignment_remediation_actions',
  'private immutable remediation actions exist'
);

select has_column(
  'public',
  'billing_household_assignments',
  'binding_state',
  'assignment distinguishes provisional and confirmed bindings'
);
select has_column(
  'public',
  'billing_household_assignments',
  'confirmed_at',
  'assignment records provider confirmation time'
);
select has_column(
  'public',
  'billing_household_assignments',
  'intent_expires_at',
  'assignment records bounded provisional expiry'
);

select has_function(
  'public',
  'prepare_billing_household_assignment',
  array['uuid', 'uuid']
);
select has_function(
  'public',
  'release_billing_household_assignment',
  array['uuid', 'bigint', 'uuid']
);
select has_function(
  'public',
  'get_billing_household_assignment_status',
  array['uuid']
);
select has_function(
  'public',
  'request_billing_assignment_remediation',
  array['uuid', 'text', 'uuid']
);
select has_function(
  'public',
  'expire_billing_household_assignments',
  array['timestamp with time zone', 'integer', 'uuid']
);
select has_function(
  'public',
  'resolve_billing_assignment_remediation',
  array[
    'uuid',
    'text',
    'bigint',
    'text',
    'text',
    'timestamp with time zone',
    'uuid'
  ]
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.prepare_billing_household_assignment(uuid,uuid)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.release_billing_household_assignment(uuid,bigint,uuid)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.get_billing_household_assignment_status(uuid)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.request_billing_assignment_remediation(uuid,text,uuid)',
    'execute'
  ),
  'authenticated clients receive only mediated assignment commands'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.resolve_billing_assignment_remediation(uuid,text,bigint,text,text,timestamp with time zone,uuid)',
    'execute'
  )
  and has_function_privilege(
    'service_role',
    'public.resolve_billing_assignment_remediation(uuid,text,bigint,text,text,timestamp with time zone,uuid)',
    'execute'
  ),
  'manual assignment resolution remains service-only'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.billing_assignment_intents',
    'select'
  )
  and not has_table_privilege(
    'service_role',
    'app_private.billing_assignment_remediation_actions',
    'select'
  )
  and not has_table_privilege(
    'authenticated',
    'app_private.billing_assignment_remediation_command_results',
    'select'
  ),
  'client and service roles cannot inspect private intent or support audit rows'
);

select is(
  (
    select pg_catalog.string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'billing_assignment_remediation_actions'
  ),
  'id,request_id,action,reason_code,case_reference_hash,previous_assignment_id,result_assignment_id,correlation_id,resolved_at',
  'support audit contains a case hash and aggregate IDs but no raw ticket text'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name in (
        'billing_assignment_intents',
        'billing_assignment_remediation_requests',
        'billing_assignment_remediation_command_results',
        'billing_assignment_remediation_actions',
        'billing_assignment_transitions'
      )
      and column_name in (
        'provider_customer_ref',
        'transaction_ref',
        'receipt',
        'payload',
        'case_reference',
        'notes'
      )
  ),
  'assignment private state stores no provider reference raw payload or support notes'
);

-- Runtime is deliberately enabled only for synthetic local fixtures.
select lives_ok(
  $$
    select *
    from public.configure_billing_runtime(
      'sandbox',
      true,
      1,
      '86000000-0000-4000-8000-000000000001'
    )
  $$,
  'synthetic sandbox billing runtime is enabled'
);

-- A Member cannot bind billing ownership.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select throws_ok(
  $$
    select *
    from public.prepare_billing_household_assignment(
      '20000000-0000-4000-8000-000000000101',
      '86000000-0000-4000-8000-000000000002'
    )
  $$,
  '42501',
  'billing assignment requires active Owner or Admin',
  'ordinary Member cannot prepare a paid-household assignment'
);
reset role;

-- Owner explicitly selects the current household before Store work.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select results_eq(
  $$
    select outcome, binding_state, assignment_version > 0,
      intent_expires_at is not null, requeued_job_count, duplicate
    from public.prepare_billing_household_assignment(
      '20000000-0000-4000-8000-000000000101',
      '86000000-0000-4000-8000-000000000003'
    )
  $$,
  $$ values (
    'ready'::text,
    'provisional'::text,
    true,
    true,
    0,
    false
  ) $$,
  'Owner prepare creates a bounded provisional binding only'
);
select results_eq(
  $$
    select outcome, binding_state, duplicate
    from public.prepare_billing_household_assignment(
      '20000000-0000-4000-8000-000000000101',
      '86000000-0000-4000-8000-000000000003'
    )
  $$,
  $$ values ('ready'::text, 'provisional'::text, true) $$,
  'exact prepare replay returns the original assignment without renewal'
);
select throws_ok(
  $$
    select *
    from public.prepare_billing_household_assignment(
      '20000000-0000-4000-8000-000000000201',
      '86000000-0000-4000-8000-000000000003'
    )
  $$,
  'KFB50',
  'billing assignment idempotency key reused',
  'changed prepare input cannot reuse an idempotency key'
);
select results_eq(
  $$
    select assignment_state, ownership_state, owner_membership_state,
      can_prepare, requires_support, assignment_version > 0,
      intent_expires_at is not null
    from public.get_billing_household_assignment_status(
      '20000000-0000-4000-8000-000000000101'
    )
  $$,
  $$ values (
    'provisional'::text,
    'current_user'::text,
    'active'::text,
    true,
    false,
    true,
    true
  ) $$,
  'status projection exposes safe aggregate ownership and expiry only'
);
reset role;

select is(
  (
    select pg_catalog.count(*)
    from public.household_entitlements
    where household_id = '20000000-0000-4000-8000-000000000101'
      and plan_code = 'free'
      and status = 'none'
      and assignment_id is null
  ),
  1::bigint,
  'provisional assignment never grants Plus'
);

-- The verified provider transaction atomically confirms the prior choice.
select lives_ok(
  $$
    select *
    from public.apply_verified_billing_event(
      'revenuecat',
      'sandbox',
      'wp06-05-confirm-primary',
      'initial_purchase',
      '2026-08-08 01:00:00+00',
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000101',
      'wp06-05-transaction-primary',
      'wp06-05-original-primary',
      'kinflow_plus_monthly',
      'play_store',
      '20000000-0000-4000-8000-000000000101',
      'active',
      'plus',
      '2026-08-01 00:00:00+00',
      '2026-09-01 00:00:00+00',
      true,
      'wp06-05',
      null,
      '86000000-0000-4000-8000-000000000004'
    )
  $$,
  'verified event applies through the existing authority'
);
select results_eq(
  $$
    select assignment.binding_state,
      assignment.confirmed_at is not null,
      assignment.intent_expires_at is null,
      entitlement.plan_code,
      entitlement.status::text
    from public.billing_household_assignments as assignment
    join public.household_entitlements as entitlement
      on entitlement.assignment_id = assignment.id
    where assignment.household_id =
      '20000000-0000-4000-8000-000000000101'
      and assignment.status = 'active'
  $$,
  $$ values (
    'confirmed'::text,
    true,
    true,
    'plus'::text,
    'active'::text
  ) $$,
  'verified transaction confirms assignment and materializes Plus'
);
select results_eq(
  $$
    select lifecycle_state,
      resolved_at is not null
    from app_private.billing_assignment_intents
    where idempotency_key =
      '86000000-0000-4000-8000-000000000003'
  $$,
  $$ values ('consumed'::text, true) $$,
  'provider confirmation consumes the explicit intent'
);
select is(
  (
    select pg_catalog.count(*)
    from app_private.billing_assignment_transitions
    where action in ('prepared', 'confirmed')
      and target_household_id =
        '20000000-0000-4000-8000-000000000101'
  ),
  2::bigint,
  'prepare and provider confirmation both have immutable lifecycle audit'
);

-- Confirmed assignment cannot be released by the client.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select results_eq(
  $$
    select outcome, assignment_version is not null, duplicate
    from public.release_billing_household_assignment(
      '20000000-0000-4000-8000-000000000101',
      (
        select version
        from public.billing_household_assignments
        where household_id =
          '20000000-0000-4000-8000-000000000101'
          and status = 'active'
      ),
      '86000000-0000-4000-8000-000000000005'
    )
  $$,
  $$ values ('support_required'::text, true, false) $$,
  'confirmed binding requires audited support instead of client release'
);
reset role;

-- Create an explicit destination owned by the purchaser for support transfer.
insert into public.households(
  id,
  name,
  timezone,
  owner_member_id,
  created_by_user_id
) values (
  '20000000-0000-4000-8000-000000000301',
  'Billing Transfer Target',
  'UTC',
  '30000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000101'
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
  '00000000-0000-4000-8000-000000000101',
  'Adult A',
  'owner',
  '00000000-0000-4000-8000-000000000101'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select results_eq(
  $$
    select outcome, binding_state is null, assignment_version is null
    from public.prepare_billing_household_assignment(
      '20000000-0000-4000-8000-000000000301',
      '86000000-0000-4000-8000-000000000006'
    )
  $$,
  $$ values ('customer_conflict'::text, true, true) $$,
  'confirmed customer conflict does not silently move the paid household'
);
select results_eq(
  $$
    select status, issue_kind, duplicate
    from public.request_billing_assignment_remediation(
      '20000000-0000-4000-8000-000000000301',
      'customer_conflict',
      '86000000-0000-4000-8000-000000000007'
    )
  $$,
  $$ values ('open'::text, 'customer_conflict'::text, false) $$,
  'conflict creates an aggregate-only support request'
);
select results_eq(
  $$
    select status, issue_kind, duplicate
    from public.request_billing_assignment_remediation(
      '20000000-0000-4000-8000-000000000301',
      'customer_conflict',
      '86000000-0000-4000-8000-000000000007'
    )
  $$,
  $$ values ('open'::text, 'customer_conflict'::text, true) $$,
  'support request replay is idempotent'
);
select results_eq(
  $$
    select status, issue_kind, duplicate
    from public.request_billing_assignment_remediation(
      '20000000-0000-4000-8000-000000000301',
      'customer_conflict',
      '86000000-0000-4000-8000-000000000018'
    )
  $$,
  $$ values ('open'::text, 'customer_conflict'::text, true) $$,
  'new command key converges on the same open support request'
);
select throws_ok(
  $$
    select *
    from public.request_billing_assignment_remediation(
      '20000000-0000-4000-8000-000000000301',
      'restore_conflict',
      '86000000-0000-4000-8000-000000000018'
    )
  $$,
  'KFB50',
  'billing assignment idempotency key reused',
  'open-request alias key cannot later be reused for another issue'
);
reset role;

select is(
  (
    select pg_catalog.count(*)
    from app_private.billing_assignment_remediation_command_results
    where request_id = (
      select id
      from app_private.billing_assignment_remediation_requests
      where idempotency_key =
        '86000000-0000-4000-8000-000000000007'
    )
  ),
  2::bigint,
  'every accepted support command key is durably bound to one request'
);

select results_eq(
  $$
    select request_status, resolution, assignment_id is not null,
      assignment_version > 0, duplicate
    from public.resolve_billing_assignment_remediation(
      (
        select id
        from app_private.billing_assignment_remediation_requests
        where idempotency_key =
          '86000000-0000-4000-8000-000000000007'
      ),
      'transfer_customer',
      (
        select version
        from public.billing_household_assignments
        where household_id =
          '20000000-0000-4000-8000-000000000101'
          and status = 'active'
      ),
      'ownership_verified',
      pg_catalog.encode(
        extensions.digest(
          pg_catalog.convert_to('synthetic-case-1', 'UTF8'),
          'sha256'
        ),
        'base64'
      ),
      pg_catalog.statement_timestamp(),
      '86000000-0000-4000-8000-000000000008'
    )
  $$,
  $$ values (
    'resolved'::text,
    'transfer_customer'::text,
    true,
    true,
    false
  ) $$,
  'versioned support command transfers the verified customer explicitly'
);
select results_eq(
  $$
    select household_id, plan_code, status::text, assignment_id is null
    from public.household_entitlements
    where household_id in (
      '20000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000301'
    )
    order by household_id
  $$,
  $$ values
    (
      '20000000-0000-4000-8000-000000000101'::uuid,
      'free'::text,
      'none'::text,
      true
    ),
    (
      '20000000-0000-4000-8000-000000000301'::uuid,
      'plus'::text,
      'active'::text,
      false
    )
  $$,
  'transfer removes source access and preserves paid state on target atomically'
);
select results_eq(
  $$
    select status, binding_state
    from public.billing_household_assignments
    where billing_owner_user_id =
      '00000000-0000-4000-8000-000000000101'
    order by assigned_at, id
  $$,
  $$ values
    ('ended'::text, 'confirmed'::text),
    ('active'::text, 'confirmed'::text)
  $$,
  'one customer retains exactly one active confirmed household after transfer'
);
select results_eq(
  $$
    select action, reason_code,
      pg_catalog.octet_length(case_reference_hash),
      previous_assignment_id is not null,
      result_assignment_id is not null
    from app_private.billing_assignment_remediation_actions
  $$,
  $$ values (
    'transfer_customer'::text,
    'ownership_verified'::text,
    32,
    true,
    true
  ) $$,
  'manual resolution stores only a SHA-256 case reference and aggregate IDs'
);
select throws_ok(
  $$
    update app_private.billing_assignment_remediation_actions
    set reason_code = 'policy_denied'
  $$,
  'KFB59',
  'billing assignment audit is immutable',
  'manual remediation audit cannot be rewritten'
);

-- Household conflict is distinct and contains no other-customer identifiers.
update public.household_members
set role = 'admin'
where household_id = '20000000-0000-4000-8000-000000000301'
  and auth_user_id = '00000000-0000-4000-8000-000000000101';
insert into public.household_members(
  id,
  household_id,
  auth_user_id,
  display_name,
  role,
  created_by_user_id
) values (
  '30000000-0000-4000-8000-000000000302',
  '20000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000102',
  'Adult B',
  'admin',
  '00000000-0000-4000-8000-000000000101'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select results_eq(
  $$
    select outcome, binding_state is null, assignment_version is null
    from public.prepare_billing_household_assignment(
      '20000000-0000-4000-8000-000000000301',
      '86000000-0000-4000-8000-000000000009'
    )
  $$,
  $$ values ('household_conflict'::text, true, true) $$,
  'another customer receives a stable household conflict without identifiers'
);
reset role;

-- Owner membership drift is visible without revoking or transferring Plus.
update public.household_members
set removed_at = '2026-08-08 03:00:00+00'
where household_id = '20000000-0000-4000-8000-000000000301'
  and auth_user_id = '00000000-0000-4000-8000-000000000101';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select results_eq(
  $$
    select assignment_state, ownership_state, owner_membership_state,
      can_prepare, requires_support
    from public.get_billing_household_assignment_status(
      '20000000-0000-4000-8000-000000000301'
    )
  $$,
  $$ values (
    'confirmed'::text,
    'another_user'::text,
    'removed'::text,
    false,
    true
  ) $$,
  'remaining Admin sees owner-membership drift as support-required'
);
reset role;
select results_eq(
  $$
    select plan_code, status::text
    from public.household_entitlements
    where household_id = '20000000-0000-4000-8000-000000000301'
  $$,
  $$ values ('plus'::text, 'active'::text) $$,
  'purchaser removal does not silently revoke paid household data access'
);

-- Missing-assignment dead letter is requeued only after an explicit choice.
select results_eq(
  $$
    select processing_status, duplicate
    from public.enqueue_revenuecat_webhook(
      'wp06-05-missing-assignment',
      pg_catalog.encode(
        extensions.digest(
          pg_catalog.convert_to('wp06-05-missing', 'UTF8'),
          'sha256'
        ),
        'base64'
      ),
      '1.0',
      'INITIAL_PURCHASE',
      '00000000-0000-4000-8000-000000000201',
      'sandbox',
      pg_catalog.statement_timestamp() - interval '1 second',
      'reconcile',
      pg_catalog.statement_timestamp(),
      '86000000-0000-4000-8000-000000000010'
    )
  $$,
  $$ values ('queued'::text, false) $$,
  'webhook for unassigned customer enters the durable queue'
);
create temporary table missing_assignment_claim on commit drop as
select *
from public.claim_billing_reconciliation_jobs(
  '86000000-0000-4000-8000-000000000011',
  1,
  30,
  pg_catalog.statement_timestamp()
);
select is(
  (select household_id from missing_assignment_claim),
  null::uuid,
  'worker claim does not infer the active application household'
);
select lives_ok(
  $$
    select *
    from public.complete_billing_reconciliation_job(
      (select job_id from missing_assignment_claim),
      (select lease_token from missing_assignment_claim),
      'dead_letter',
      'ASSIGNMENT_REQUIRED',
      pg_catalog.statement_timestamp()
    )
  $$,
  'missing assignment reaches its explicit dead letter state'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select results_eq(
  $$
    select outcome, binding_state, requeued_job_count, duplicate
    from public.prepare_billing_household_assignment(
      '20000000-0000-4000-8000-000000000201',
      '86000000-0000-4000-8000-000000000012'
    )
  $$,
  $$ values ('ready'::text, 'provisional'::text, 1, false) $$,
  'explicit selection requeues exactly the matching missing-assignment job'
);
reset role;
select results_eq(
  $$
    select processing_status, last_error_code, completed_at is null
    from app_private.billing_reconciliation_jobs
    where provider_event_id = 'wp06-05-missing-assignment'
  $$,
  $$ values ('queued'::text, null::text, true) $$,
  'requeued job clears terminal lease and error state'
);
select is(
  (
    select pg_catalog.count(*)
    from app_private.billing_reconciliation_transitions as transition
    join app_private.billing_reconciliation_jobs as job
      on job.id = transition.job_id
    where job.provider_event_id = 'wp06-05-missing-assignment'
      and transition.transition = 'requeued'
  ),
  1::bigint,
  'missing-assignment recovery leaves one immutable requeue transition'
);
select results_eq(
  $$
    select household_id, attempt_count
    from public.claim_billing_reconciliation_jobs(
      '86000000-0000-4000-8000-000000000013',
      1,
      30,
      pg_catalog.statement_timestamp()
    )
  $$,
  $$ values (
    '20000000-0000-4000-8000-000000000201'::uuid,
    2
  ) $$,
  'requeued work resolves only the explicitly selected household'
);

-- A provisional binding can be released idempotently and never schedules
-- periodic provider work.
select is(
  public.schedule_due_billing_reconciliations(
    pg_catalog.statement_timestamp() + interval '10 minutes',
    300,
    100,
    '86000000-0000-4000-8000-000000000014'
  ),
  1,
  'periodic scheduler includes only the remaining confirmed customer'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select results_eq(
  $$
    select outcome, assignment_version is not null, duplicate
    from public.release_billing_household_assignment(
      '20000000-0000-4000-8000-000000000201',
      (
        select version
        from public.billing_household_assignments
        where household_id =
          '20000000-0000-4000-8000-000000000201'
          and status = 'active'
      ),
      '86000000-0000-4000-8000-000000000015'
    )
  $$,
  $$ values ('released'::text, true, false) $$,
  'client can release its unconfirmed provisional choice'
);
select results_eq(
  $$
    select outcome, duplicate
    from public.release_billing_household_assignment(
      '20000000-0000-4000-8000-000000000201',
      (
        select version - 1
        from public.billing_household_assignments
        where household_id =
          '20000000-0000-4000-8000-000000000201'
        order by assigned_at desc, id desc
        limit 1
      ),
      '86000000-0000-4000-8000-000000000015'
    )
  $$,
  $$ values ('released'::text, true) $$,
  'exact release replay returns the first result after the version advances'
);
reset role;

-- Expiry cleanup is bounded and cannot mutate immutable audit.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select lives_ok(
  $$
    select *
    from public.prepare_billing_household_assignment(
      '20000000-0000-4000-8000-000000000201',
      '86000000-0000-4000-8000-000000000016'
    )
  $$,
  'released customer may make a new explicit provisional choice'
);
reset role;

update public.billing_household_assignments
set assigned_at = pg_catalog.statement_timestamp() - interval '1 hour',
    intent_expires_at = pg_catalog.statement_timestamp() - interval '30 minutes'
where household_id = '20000000-0000-4000-8000-000000000201'
  and status = 'active'
  and binding_state = 'provisional';
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
  'admin',
  '00000000-0000-4000-8000-000000000201'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select results_eq(
  $$
    select outcome, binding_state, duplicate
    from public.prepare_billing_household_assignment(
      '20000000-0000-4000-8000-000000000201',
      '86000000-0000-4000-8000-000000000019'
    )
  $$,
  $$ values ('ready'::text, 'provisional'::text, false) $$,
  'new explicit owner choice retires another customer stale provisional block'
);
reset role;
select is(
  (
    select pg_catalog.count(*)
    from app_private.billing_assignment_transitions
    where target_household_id =
      '20000000-0000-4000-8000-000000000201'
      and action = 'expired'
      and reason_code = 'intent_expired_during_prepare'
  ),
  1::bigint,
  'stale target cleanup is explicitly audited before reassignment'
);
select is(
  public.expire_billing_household_assignments(
    pg_catalog.now() + interval '31 minutes',
    100,
    '86000000-0000-4000-8000-000000000017'
  ),
  1,
  'bounded cleanup expires the stale unverified assignment'
);
select results_eq(
  $$
    select status, binding_state
    from public.billing_household_assignments
    where household_id = '20000000-0000-4000-8000-000000000201'
    order by assigned_at desc, id desc
    limit 1
  $$,
  $$ values ('ended'::text, 'provisional'::text) $$,
  'expired provisional binding cannot be claimed as active'
);

select * from finish();
rollback;
