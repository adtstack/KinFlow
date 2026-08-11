begin;
set constraints all deferred;

select no_plan();

select has_table('public', 'data_exports', 'public safe export metadata exists');
select has_table(
  'app_private', 'data_export_jobs', 'private generation jobs exist'
);
select has_table(
  'app_private', 'data_export_download_grants',
  'private hash-only download grants exist'
);
select has_table(
  'app_private', 'data_export_purge_jobs', 'private artifact purge jobs exist'
);
select has_table(
  'app_private', 'data_export_events', 'immutable export audit exists'
);

select has_function(
  'public', 'request_data_export', array['uuid', 'text', 'uuid']
);
select has_function(
  'public', 'claim_data_export_requests',
  array['uuid', 'integer', 'integer', 'timestamp with time zone']
);
select has_function(
  'public', 'build_personal_data_export_package',
  array['uuid', 'uuid', 'timestamp with time zone']
);
select has_function(
  'public', 'create_data_export_download_grant',
  array['uuid', 'uuid', 'text', 'text', 'uuid']
);
select has_function(
  'public', 'consume_data_export_download_grant',
  array['text', 'timestamp with time zone']
);
select has_function(
  'public', 'claim_data_export_purges',
  array['uuid', 'integer', 'integer', 'timestamp with time zone']
);

select ok(
  has_function_privilege(
    'service_role', 'public.request_data_export(uuid,text,uuid)', 'execute'
  )
  and not has_function_privilege(
    'authenticated', 'public.request_data_export(uuid,text,uuid)', 'execute'
  )
  and has_function_privilege(
    'service_role',
    'public.build_personal_data_export_package(uuid,uuid,timestamptz)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.build_personal_data_export_package(uuid,uuid,timestamptz)',
    'execute'
  ),
  'recent-auth Edge commands and PII worker snapshots are service-only'
);

select ok(
  not has_table_privilege(
    'authenticated', 'app_private.data_export_jobs', 'select'
  )
  and not has_table_privilege(
    'authenticated', 'app_private.data_export_download_grants', 'select'
  )
  and not has_column_privilege(
    'authenticated', 'public.data_exports', 'machine_object_key', 'select'
  )
  and not has_column_privilege(
    'authenticated', 'public.data_exports', 'human_object_key', 'select'
  ),
  'clients cannot read leases token hashes or private Storage paths'
);

-- Create personal/shared fixtures through their authoritative commands.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '81000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Adult B authored chore',
      'Personal chore description',
      '30000000-0000-4000-8000-000000000102',
      current_date + 1,
      '09:00'::time
    )
  $$,
  'Adult B authored chore fixture is created'
);
select lives_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '81000000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series
          on series.household_id = occurrence.household_id
         and series.id = occurrence.series_id
        where series.title = 'Adult B authored chore'
      ),
      1,
      true
    )
  $$,
  'Adult B personal completion action is recorded'
);
select lives_ok(
  $$
    select * from public.create_one_time_event(
      '81000000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      'Adult B authored calendar',
      'Personal calendar description',
      false,
      current_date + 2,
      '10:00'::time,
      60,
      null,
      'Asia/Seoul',
      'earlier',
      array['30000000-0000-4000-8000-000000000102'::uuid]
    )
  $$,
  'Adult B authored calendar fixture is created'
);
select lives_ok(
  $$
    select * from public.update_notification_preference(
      '20000000-0000-4000-8000-000000000101',
      'chore_due',
      true,
      false,
      true,
      true,
      '22:00'::time,
      '07:00'::time,
      'Asia/Seoul',
      0
    )
  $$,
  'Adult B notification preference fixture is created'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '81000000-0000-4000-8000-000000000011',
      '20000000-0000-4000-8000-000000000101',
      'Other member secret chore',
      'Must not enter the personal export',
      '30000000-0000-4000-8000-000000000101',
      current_date + 1,
      '11:00'::time
    )
  $$,
  'another member authored chore fixture is created'
);
select lives_ok(
  $$
    select * from public.create_one_time_event(
      '81000000-0000-4000-8000-000000000012',
      '20000000-0000-4000-8000-000000000101',
      'Shared participant event',
      'Adult B participates without other identities',
      false,
      current_date + 2,
      '13:00'::time,
      30,
      null,
      'Asia/Seoul',
      'earlier',
      array['30000000-0000-4000-8000-000000000102'::uuid]
    )
  $$,
  'shared calendar participation fixture is created'
);
select lives_ok(
  $$
    select * from public.create_one_time_event(
      '81000000-0000-4000-8000-000000000013',
      '20000000-0000-4000-8000-000000000101',
      'Other member private event',
      'Must not enter the personal export',
      false,
      current_date + 3,
      '14:00'::time,
      30,
      null,
      'Asia/Seoul',
      'earlier',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'unrelated calendar fixture is created'
);
reset role;

-- Synthetic web billing data proves provider/customer identifiers are omitted.
insert into public.billing_customers (
  id, auth_user_id, provider, environment,
  provider_customer_ref, provider_customer_ref_hash
) values (
  '82000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000102',
  'web',
  'sandbox',
  'provider-secret-customer-reference',
  extensions.digest(
    convert_to('provider-secret-customer-reference', 'UTF8'), 'sha256'
  )
);

insert into public.billing_household_assignments (
  id, billing_customer_id, billing_owner_user_id,
  household_id, status, assigned_at
) values (
  '82000000-0000-4000-8000-000000000002',
  '82000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000102',
  '20000000-0000-4000-8000-000000000101',
  'active',
  pg_catalog.statement_timestamp()
);

update public.household_entitlements as entitlement
set assignment_id = '82000000-0000-4000-8000-000000000002',
    billing_owner_user_id = '00000000-0000-4000-8000-000000000102',
    plan_code = 'plus',
    status = 'active',
    source = 'web',
    product_id = 'kinflow_plus_monthly',
    current_period_start = pg_catalog.statement_timestamp(),
    current_period_end = pg_catalog.statement_timestamp() + interval '30 days',
    will_renew = true,
    provider_updated_at = pg_catalog.statement_timestamp(),
    verified_at = pg_catalog.statement_timestamp()
where entitlement.household_id = '20000000-0000-4000-8000-000000000101';

set local role service_role;

select results_eq(
  $$
    select can_request, pending_request_id is null,
      conflicting_request_pending, requests_enabled, downloads_enabled,
      artifact_ttl_seconds, download_grant_ttl_seconds
    from public.get_data_export_preflight(
      '00000000-0000-4000-8000-000000000102'
    )
  $$,
  $$ values (true, true, false, true, true, 86400, 300) $$,
  'active Adult B receives an enabled personal export preflight'
);

select results_eq(
  $$
    select status, cancellable, artifact_version, available
    from public.request_data_export(
      '00000000-0000-4000-8000-000000000102',
      'first-export-request-key-0001',
      '83000000-0000-4000-8000-000000000001'
    )
  $$,
  $$ values ('queued'::text, true, 1::bigint, false) $$,
  'recent-auth Edge request queues one private export job'
);

select is(
  (
    select count(*) from public.request_data_export(
      '00000000-0000-4000-8000-000000000102',
      'first-export-request-key-0001',
      '83000000-0000-4000-8000-000000000001'
    )
  ),
  1::bigint,
  'request idempotency replays one safe projection'
);

select throws_ok(
  $$
    select * from public.request_account_deletion(
      '00000000-0000-4000-8000-000000000102',
      'conflicting-delete-key-0001',
      true,
      '83000000-0000-4000-8000-000000000002'
    )
  $$,
  'KFP05',
  'another privacy request is already pending',
  'account deletion cannot race a pending personal export'
);

select results_eq(
  $$
    select status, cancellable, request_version
    from public.cancel_data_export(
      '00000000-0000-4000-8000-000000000102',
      (
        select request_id from public.get_data_export_request(
          '00000000-0000-4000-8000-000000000102', null
        )
      ),
      1,
      'first-export-cancel-key-0001',
      '83000000-0000-4000-8000-000000000003'
    )
  $$,
  $$ values ('cancelled'::text, false, 2::bigint) $$,
  'queued export can be cancelled with an optimistic version'
);

select lives_ok(
  $$
    select * from public.request_data_export(
      '00000000-0000-4000-8000-000000000102',
      'processing-export-key-0001',
      '83000000-0000-4000-8000-000000000004'
    )
  $$,
  'a new export can follow a cancelled export'
);

create temporary table data_export_test_clock on commit drop as
select pg_catalog.clock_timestamp() + interval '1 second' as claimed_at;

create temporary table data_export_claim on commit drop as
select claim.*
from data_export_test_clock as test_clock
cross join lateral public.claim_data_export_requests(
  '84000000-0000-4000-8000-000000000001',
  5,
  300,
  test_clock.claimed_at
) as claim;

select results_eq(
  $$ select attempts, request_version from data_export_claim $$,
  $$ values (1, 2::bigint) $$,
  'worker claim leases exactly one due export and advances its request'
);

create temporary table data_export_package on commit drop as
select package.*
from data_export_claim as claim
cross join data_export_test_clock as test_clock
cross join lateral public.build_personal_data_export_package(
  claim.privacy_request_id,
  claim.lease_token,
  test_clock.claimed_at + interval '1 second'
) as package;

select results_eq(
  $$
    select payload->'profile'->>'displayName',
      jsonb_array_length(payload->'memberships'),
      jsonb_array_length(payload->'authoredChores'),
      jsonb_array_length(payload->'choreActions'),
      jsonb_array_length(payload->'authoredCalendarEvents'),
      jsonb_array_length(payload->'calendarParticipation'),
      jsonb_array_length(payload->'notificationPreferences'),
      jsonb_array_length(payload->'billingSummary')
    from data_export_package
  $$,
  $$ values ('Adult B'::text, 1, 1, 1, 1, 2, 1, 1) $$,
  'personal package contains every implemented category owned by Adult B'
);

select ok(
  (
    select payload::text not like '%Other member secret chore%'
      and payload::text not like '%Other member private event%'
      and payload::text not like '%provider-secret-customer-reference%'
      and payload::text not like '%billing_customer_id%'
      and payload::text not like '%provider_customer_ref%'
      and payload::text like '%Shared participant event%'
      and (payload->'scope'->>'otherMemberProfilesIncluded')::boolean = false
      and (payload->'scope'->>'providerIdentifiersIncluded')::boolean = false
    from data_export_package
  ),
  'snapshot excludes unrelated shared content other identities and provider IDs'
);

select results_eq(
  $$
    select completed.status,
      completed.artifact_expires_at
        > test_clock.claimed_at + interval '2 seconds',
      completed.request_version,
      completed.artifact_version
    from data_export_claim as claim
    cross join data_export_test_clock as test_clock
    cross join lateral public.complete_data_export_request(
      claim.privacy_request_id,
      claim.lease_token,
      'exports/' || claim.artifact_prefix::text || '/kinflow-data.json',
      repeat('a', 64),
      4096,
      'exports/' || claim.artifact_prefix::text || '/kinflow-data.txt',
      repeat('b', 64),
      2048,
      test_clock.claimed_at + interval '2 seconds'
    ) as completed
  $$,
  $$ values ('completed'::text, true, 3::bigint, 2::bigint) $$,
  'worker completion records bounded private object metadata and expiry'
);

create temporary table data_export_grant on commit drop as
select grant_result.*
from data_export_claim as claim
cross join lateral public.create_data_export_download_grant(
  '00000000-0000-4000-8000-000000000102',
  claim.privacy_request_id,
  'json',
  encode(
    extensions.digest(convert_to('one-time-raw-token', 'UTF8'), 'sha256'),
    'base64'
  ),
  '85000000-0000-4000-8000-000000000001'
) as grant_result;

select results_eq(
  $$ select export_format, expires_at > pg_catalog.clock_timestamp()
     from data_export_grant $$,
  $$ values ('json'::text, true) $$,
  'download grant returns only safe format and expiry metadata'
);

select results_eq(
  $$
    select consumed.export_format, consumed.file_name,
      consumed.content_type, consumed.size_bytes
    from public.consume_data_export_download_grant(
      encode(
        extensions.digest(convert_to('one-time-raw-token', 'UTF8'), 'sha256'),
        'base64'
      ),
      pg_catalog.clock_timestamp()
    ) as consumed
  $$,
  $$ values (
    'json'::text,
    'kinflow-data.json'::text,
    'application/json; charset=utf-8'::text,
    4096::bigint
  ) $$,
  'valid token hash atomically consumes one private artifact capability'
);

select throws_ok(
  $$
    select * from public.consume_data_export_download_grant(
      encode(
        extensions.digest(convert_to('one-time-raw-token', 'UTF8'), 'sha256'),
        'base64'
      ),
      pg_catalog.clock_timestamp()
    )
  $$,
  'KFX12',
  'download grant invalid',
  'the same download capability cannot be consumed twice'
);

select lives_ok(
  $$
    select * from data_export_claim as claim
    cross join lateral public.create_data_export_download_grant(
      '00000000-0000-4000-8000-000000000102',
      claim.privacy_request_id,
      'text',
      encode(
        extensions.digest(convert_to('revoked-raw-token', 'UTF8'), 'sha256'),
        'base64'
      ),
      '85000000-0000-4000-8000-000000000002'
    )
  $$,
  'a second format receives an independent one-time capability'
);

select results_eq(
  $$
    select revoked_at is not null, available, artifact_version
    from data_export_claim as claim
    cross join lateral public.revoke_data_export(
      '00000000-0000-4000-8000-000000000102',
      claim.privacy_request_id,
      2,
      'completed-export-revoke-key-0001',
      '85000000-0000-4000-8000-000000000003'
    )
  $$,
  $$ values (true, false, 3::bigint) $$,
  'immediate revocation closes outstanding grants and advances purge due time'
);

select throws_ok(
  $$
    select * from public.consume_data_export_download_grant(
      encode(
        extensions.digest(convert_to('revoked-raw-token', 'UTF8'), 'sha256'),
        'base64'
      ),
      pg_catalog.clock_timestamp()
    )
  $$,
  'KFX12',
  'download grant invalid',
  'artifact revocation invalidates an unconsumed capability'
);

create temporary table data_export_purge_claim on commit drop as
select purge.*
from public.claim_data_export_purges(
  '86000000-0000-4000-8000-000000000001',
  5,
  300,
  pg_catalog.clock_timestamp() + interval '5 seconds'
) as purge;

select is(
  (select count(*) from data_export_purge_claim),
  1::bigint,
  'revoked artifact is immediately leased for physical deletion'
);

select results_eq(
  $$
    select purged_at is not null, artifact_version
    from data_export_purge_claim as claim
    cross join lateral public.complete_data_export_purge(
      claim.data_export_id,
      claim.lease_token,
      pg_catalog.clock_timestamp() + interval '6 seconds'
    )
  $$,
  $$ values (true, 4::bigint) $$,
  'confirmed Storage removal clears private paths and marks the artifact purged'
);

reset role;
select results_eq(
  $$
    select machine_object_key is null, human_object_key is null,
      machine_checksum_sha256 = repeat('a', 64), purged_at is not null
    from public.data_exports as export
    join data_export_claim as claim
      on claim.data_export_id = export.id
  $$,
  $$ values (true, true, true, true) $$,
  'purge retains non-secret integrity evidence but erases both object paths'
);

-- Exercise generation lease recovery and bounded terminal failure.
set local role service_role;
select lives_ok(
  $$
    select * from public.request_data_export(
      '00000000-0000-4000-8000-000000000102',
      'lease-recovery-export-key-01',
      '87000000-0000-4000-8000-000000000001'
    )
  $$,
  'a later export can be requested after completion'
);

create temporary table expired_generation_claim on commit drop as
select claim.*
from public.claim_data_export_requests(
  '87000000-0000-4000-8000-000000000002',
  5,
  30,
  pg_catalog.clock_timestamp() + interval '10 seconds'
) as claim;

select results_eq(
  $$
    select retry_scheduled, dead_letter
    from public.recover_expired_data_export_generation_leases(
      pg_catalog.clock_timestamp() + interval '41 seconds'
    )
  $$,
  $$ values (1, 0) $$,
  'expired generation lease becomes an auditable immediate retry'
);

create temporary table recovered_generation_claim on commit drop as
select claim.*
from public.claim_data_export_requests(
  '87000000-0000-4000-8000-000000000003',
  5,
  30,
  pg_catalog.clock_timestamp() + interval '42 seconds'
) as claim;

select results_eq(
  $$
    select status, failure_code, next_attempt_at is null
    from recovered_generation_claim as claim
    cross join lateral public.fail_data_export_request(
      claim.privacy_request_id,
      claim.lease_token,
      'PROCESSING_PRECONDITION_FAILED',
      false,
      pg_catalog.clock_timestamp() + interval '43 seconds'
    )
  $$,
  $$ values (
    'failed'::text,
    'PROCESSING_PRECONDITION_FAILED'::text,
    true
  ) $$,
  'nonretryable snapshot precondition closes the request without looping'
);

reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select count(export.id) from public.data_exports as export
  ),
  3::bigint,
  'caller can read only its own safe export metadata rows'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select is(
  (select count(export.id) from public.data_exports as export),
  0::bigint,
  'unrelated authenticated adult cannot enumerate export metadata'
);
reset role;

select throws_ok(
  $$ update app_private.data_export_events set transition = 'failed' $$,
  'KFX30',
  'data export audit is immutable',
  'export audit evidence cannot be rewritten'
);

set local role service_role;
select results_eq(
  $$
    select requests_enabled, downloads_enabled,
      artifact_ttl_seconds, download_grant_ttl_seconds, version
    from public.configure_data_export_runtime(
      true,
      false,
      43200,
      120,
      1,
      '88000000-0000-4000-8000-000000000001'
    )
  $$,
  $$ values (true, false, 43200, 120, 2::bigint) $$,
  'service runtime controls pause downloads and tune bounded retention'
);
reset role;

select results_eq(
  $$
    select previous_downloads_enabled, next_downloads_enabled,
      previous_version, next_version, correlation_id
    from app_private.data_export_runtime_events
  $$,
  $$
    values (
      true,
      false,
      1::bigint,
      2::bigint,
      '88000000-0000-4000-8000-000000000001'::uuid
    )
  $$,
  'runtime changes leave immutable versioned evidence'
);

select * from finish();
rollback;
