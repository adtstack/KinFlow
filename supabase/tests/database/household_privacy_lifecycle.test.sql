begin;
set constraints all deferred;

select no_plan();

select has_table('public', 'household_exports', 'safe household export metadata exists');
select has_table(
  'app_private', 'household_export_jobs', 'private household export jobs exist'
);
select has_table(
  'app_private', 'household_export_download_grants',
  'private one-time download grants exist'
);
select has_table(
  'app_private', 'household_export_purge_jobs',
  'private household export purge jobs exist'
);
select has_table(
  'app_private', 'household_deletion_jobs',
  'private household deletion jobs exist'
);
select has_table(
  'app_private', 'household_deletion_retention_holds',
  'private deletion retention holds exist'
);
select has_table(
  'app_private', 'household_privacy_events',
  'immutable household privacy audit exists'
);

select has_function(
  'public', 'request_household_export', array['uuid', 'uuid', 'text', 'uuid']
);
select has_function(
  'public', 'claim_household_export_requests',
  array['uuid', 'integer', 'integer', 'timestamp with time zone']
);
select has_function(
  'public', 'complete_household_deletion_request',
  array['uuid', 'uuid', 'timestamp with time zone']
);
select has_function(
  'public', 'claim_household_export_purge_jobs',
  array['uuid', 'integer', 'integer', 'timestamp with time zone']
);

select ok(
  has_function_privilege(
    'service_role',
    'public.request_household_export(uuid,uuid,text,uuid)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.request_household_export(uuid,uuid,text,uuid)',
    'execute'
  )
  and has_function_privilege(
    'service_role',
    'public.complete_household_deletion_request(uuid,uuid,timestamptz)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.complete_household_deletion_request(uuid,uuid,timestamptz)',
    'execute'
  ),
  'recent-auth Edge commands and destructive worker RPCs are service-only'
);

select ok(
  not has_table_privilege(
    'authenticated', 'app_private.household_export_jobs', 'select'
  )
  and not has_table_privilege(
    'authenticated', 'app_private.household_deletion_jobs', 'select'
  )
  and not has_column_privilege(
    'authenticated', 'public.household_exports', 'machine_object_key', 'select'
  )
  and not has_column_privilege(
    'authenticated', 'public.household_exports', 'human_object_key', 'select'
  ),
  'clients cannot read leases token hashes or private Storage paths'
);

-- Shared content proves the household archive boundary and later redaction.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '91000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Household export chore',
      'Shared chore content to redact',
      '30000000-0000-4000-8000-000000000102',
      current_date + 1,
      '09:00'::time
    )
  $$,
  'shared chore fixture is created through its authoritative command'
);
select lives_ok(
  $$
    select * from public.create_one_time_event(
      '91000000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      'Household export event',
      'Shared calendar content to redact',
      false,
      current_date + 2,
      '10:00'::time,
      60,
      null,
      'Asia/Seoul',
      'earlier',
      array[
        '30000000-0000-4000-8000-000000000101'::uuid,
        '30000000-0000-4000-8000-000000000102'::uuid
      ]
    )
  $$,
  'shared calendar fixture is created through its authoritative command'
);
reset role;

insert into public.billing_customers (
  id, auth_user_id, provider, environment,
  provider_customer_ref, provider_customer_ref_hash
) values (
  '92000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000101',
  'web',
  'sandbox',
  'household-provider-secret-reference',
  extensions.digest(
    convert_to('household-provider-secret-reference', 'UTF8'), 'sha256'
  )
);

insert into public.billing_household_assignments (
  id, billing_customer_id, billing_owner_user_id,
  household_id, status, assigned_at
) values (
  '92000000-0000-4000-8000-000000000002',
  '92000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000101',
  '20000000-0000-4000-8000-000000000101',
  'active',
  pg_catalog.statement_timestamp()
);

update public.household_entitlements as entitlement
set assignment_id = '92000000-0000-4000-8000-000000000002',
    billing_owner_user_id = '00000000-0000-4000-8000-000000000101',
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

insert into public.notification_endpoints (
  id, auth_user_id, household_id, member_id, installation_id,
  channel, platform, token_ciphertext, token_fingerprint,
  token_key_version, revocation_secret_hash, permission_state,
  locale, timezone, app_version, runtime_version,
  last_registration_id, last_seen_at
) values (
  '93000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000101',
  '20000000-0000-4000-8000-000000000101',
  '30000000-0000-4000-8000-000000000101',
  '93000000-0000-4000-8000-000000000002',
  'native_push',
  'android',
  pg_catalog.decode(pg_catalog.repeat('ab', 29), 'hex'),
  extensions.digest(convert_to('household-provider-token', 'UTF8'), 'sha256'),
  1,
  extensions.digest(convert_to('household-revocation-proof', 'UTF8'), 'sha256'),
  'granted',
  'ko',
  'Asia/Seoul',
  '1.0.0',
  '3.44.7',
  '93000000-0000-4000-8000-000000000003',
  pg_catalog.statement_timestamp()
);

insert into public.notification_preferences (
  auth_user_id, household_id, category, timezone
) values (
  '00000000-0000-4000-8000-000000000101',
  '20000000-0000-4000-8000-000000000101',
  'chore_due',
  'Asia/Seoul'
);

insert into public.household_invites (
  id, household_id, role, token_hash, status, expires_at,
  created_by_member_id
) values (
  '94000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000101',
  'member',
  extensions.digest(convert_to('household-invite-token', 'UTF8'), 'sha256'),
  'active',
  pg_catalog.statement_timestamp() + interval '7 days',
  '30000000-0000-4000-8000-000000000101'
);

set local role service_role;

select results_eq(
  $$
    select result->'household'->>'name',
      (result->>'memberCount')::integer,
      (result->>'activeSubscription')::boolean,
      (result->>'canExport')::boolean,
      (result->>'canDelete')::boolean
    from public.get_household_privacy_preflight(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101'
    )
  $$,
  $$ values ('Primary Local Household'::text, 2, true, true, true) $$,
  'current Owner receives exact impact and capability preflight'
);

create temporary table household_privacy_preflight on commit drop as
select (preflight.result->'household'->>'version')::bigint as household_version
from public.get_household_privacy_preflight(
  '00000000-0000-4000-8000-000000000101',
  '20000000-0000-4000-8000-000000000101'
) as preflight;

select throws_ok(
  $$
    select * from public.request_household_export(
      '00000000-0000-4000-8000-000000000102',
      '20000000-0000-4000-8000-000000000101',
      'non-owner-export-key-0001',
      '95000000-0000-4000-8000-000000000001'
    )
  $$,
  'KHP03',
  'current Owner required',
  'non-Owner cannot request a full household archive'
);

create temporary table household_export_request on commit drop as
select
  (requested.result->>'requestId')::uuid as request_id,
  (requested.result->>'version')::bigint as request_version
from public.request_household_export(
  '00000000-0000-4000-8000-000000000101',
  '20000000-0000-4000-8000-000000000101',
  'owner-household-export-key-01',
  '95000000-0000-4000-8000-000000000002'
) as requested;

select results_eq(
  $$ select request_version from household_export_request $$,
  $$ values (1::bigint) $$,
  'Owner export request queues exactly one versioned aggregate'
);

select is(
  (
    select count(*) from public.request_household_export(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'owner-household-export-key-01',
      '95000000-0000-4000-8000-000000000002'
    )
  ),
  1::bigint,
  'household export request idempotency replays one safe projection'
);

select throws_ok(
  $$
    select * from public.request_household_deletion(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      1,
      'Primary Local Household',
      true,
      true,
      true,
      'conflicting-household-delete-01',
      '95000000-0000-4000-8000-000000000003'
    )
  $$,
  'KHP05',
  'privacy request already pending',
  'household deletion cannot race a pending household export'
);

create temporary table household_export_clock on commit drop as
select pg_catalog.clock_timestamp() + interval '1 second' as claimed_at;

create temporary table household_export_claim on commit drop as
select claim.*
from household_export_clock as test_clock
cross join lateral public.claim_household_export_requests(
  '96000000-0000-4000-8000-000000000001',
  2,
  300,
  test_clock.claimed_at
) as claim;

select results_eq(
  $$ select attempts from household_export_claim $$,
  $$ values (1) $$,
  'worker claims the due household export once'
);

create temporary table household_export_package on commit drop as
select package.result as payload
from household_export_claim as claim
cross join household_export_clock as test_clock
cross join lateral public.load_household_export_package(
  claim.privacy_request_id,
  claim.lease_token,
  test_clock.claimed_at + interval '1 second'
) as package;

select results_eq(
  $$
    select payload->'household'->>'name',
      jsonb_array_length(payload->'members'),
      jsonb_array_length(payload->'choreSeries'),
      jsonb_array_length(payload->'calendarSeries'),
      payload->'billingSummary'->>'planCode'
    from household_export_package
  $$,
  $$ values ('Primary Local Household'::text, 2, 1, 1, 'plus'::text) $$,
  'archive contains the implemented shared household categories'
);

select ok(
  (
    select payload::text not like '%adult-a@local.kinflow.invalid%'
      and payload::text not like '%adult-b@local.kinflow.invalid%'
      and payload::text not like '%household-provider-secret-reference%'
      and payload::text not like '%provider_customer_ref%'
      and payload::text not like '%billing_customer_id%'
      and (payload->'scope'->>'memberAuthIdentitiesIncluded')::boolean = false
      and (payload->'scope'->>'providerIdentifiersIncluded')::boolean = false
    from household_export_package
  ),
  'archive excludes Auth identities personal inbox state and provider IDs'
);

select results_eq(
  $$
    select completed.result->>'status',
      (completed.result->'artifact'->>'available')::boolean,
      (completed.result->'artifact'->>'version')::bigint
    from household_export_claim as claim
    cross join household_export_clock as test_clock
    cross join lateral public.complete_household_export_request(
      claim.privacy_request_id,
      claim.lease_token,
      'household-exports/' || claim.household_export_id::text ||
        '/kinflow-household.json',
      'household-exports/' || claim.household_export_id::text ||
        '/kinflow-household.txt',
      repeat('a', 64),
      repeat('b', 64),
      4096,
      2048,
      test_clock.claimed_at + interval '2 seconds'
    ) as completed
  $$,
  $$ values ('completed'::text, true, 2::bigint) $$,
  'worker completion exposes only bounded artifact metadata'
);

create temporary table household_export_grant on commit drop as
select grant_result.result
from household_export_request as request
cross join lateral public.create_household_export_download_grant(
  '00000000-0000-4000-8000-000000000101',
  request.request_id,
  'json',
  encode(
    extensions.digest(convert_to('household-one-time-token', 'UTF8'), 'sha256'),
    'base64'
  ),
  '97000000-0000-4000-8000-000000000001'
) as grant_result;

select results_eq(
  $$ select result->>'format' from household_export_grant $$,
  $$ values ('json'::text) $$,
  'download capability returns format and expiry without its stored hash'
);

select results_eq(
  $$
    select consumed.export_format, consumed.file_name,
      consumed.content_type, consumed.size_bytes
    from public.consume_household_export_download_grant(
      encode(
        extensions.digest(
          convert_to('household-one-time-token', 'UTF8'), 'sha256'
        ),
        'base64'
      ),
      pg_catalog.clock_timestamp()
    ) as consumed
  $$,
  $$ values (
    'json'::text,
    'kinflow-household.json'::text,
    'application/json; charset=utf-8'::text,
    4096::bigint
  ) $$,
  'one-time capability atomically resolves one private household object'
);

select throws_ok(
  $$
    select * from public.consume_household_export_download_grant(
      encode(
        extensions.digest(
          convert_to('household-one-time-token', 'UTF8'), 'sha256'
        ),
        'base64'
      ),
      pg_catalog.clock_timestamp()
    )
  $$,
  'KHP15',
  'download grant invalid',
  'download capability cannot be consumed twice'
);

select throws_ok(
  $$
    select * from public.request_household_deletion(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      (select household_version from household_privacy_preflight),
      'Wrong household name',
      true,
      true,
      true,
      'wrong-name-household-delete-01',
      '98000000-0000-4000-8000-000000000001'
    )
  $$,
  'KHP10',
  'household name confirmation mismatch',
  'deletion requires the exact current household name'
);

create temporary table first_household_deletion on commit drop as
select
  (requested.result->>'requestId')::uuid as request_id,
  (requested.result->>'version')::bigint as request_version
from public.request_household_deletion(
  '00000000-0000-4000-8000-000000000101',
  '20000000-0000-4000-8000-000000000101',
  (select household_version from household_privacy_preflight),
  'Primary Local Household',
  true,
  true,
  true,
  'cancel-household-delete-key-01',
  '98000000-0000-4000-8000-000000000002'
) as requested;

select results_eq(
  $$
    select cancelled.result->>'status',
      (cancelled.result->>'cancellable')::boolean
    from first_household_deletion as deletion
    cross join lateral public.cancel_household_privacy_request(
      '00000000-0000-4000-8000-000000000101',
      deletion.request_id,
      'deletion',
      deletion.request_version,
      'cancel-household-delete-command-01',
      '98000000-0000-4000-8000-000000000003'
    ) as cancelled
  $$,
  $$ values ('cancelled'::text, false) $$,
  'queued deletion remains cancellable during cooling-off'
);

create temporary table final_household_deletion on commit drop as
select
  (requested.result->>'requestId')::uuid as request_id,
  (requested.result->>'scheduledFor')::timestamptz as scheduled_for
from public.request_household_deletion(
  '00000000-0000-4000-8000-000000000101',
  '20000000-0000-4000-8000-000000000101',
  (select household_version from household_privacy_preflight),
  'Primary Local Household',
  true,
  true,
  true,
  'final-household-delete-key-001',
  '98000000-0000-4000-8000-000000000004'
) as requested;

select results_eq(
  $$
    select (hold.result->>'active')::boolean,
      (hold.result->>'version')::bigint
    from public.configure_household_deletion_retention_hold(
      '20000000-0000-4000-8000-000000000101',
      true,
      pg_catalog.clock_timestamp() + interval '10 days',
      encode(
        extensions.digest(convert_to('retention-case-reference', 'UTF8'), 'sha256'),
        'base64'
      ),
      0,
      '99000000-0000-4000-8000-000000000001'
    ) as hold
  $$,
  $$ values (true, 1::bigint) $$,
  'service retention hold blocks a queued deletion without exposing its reference'
);

select is(
  (
    select count(*) from public.claim_household_deletion_requests(
      '99000000-0000-4000-8000-000000000002',
      5,
      180,
      pg_catalog.clock_timestamp() + interval '2 days'
    )
  ),
  0::bigint,
  'retention-held deletion cannot be claimed after cooling-off'
);

select results_eq(
  $$
    select (hold.result->>'active')::boolean,
      (hold.result->>'version')::bigint
    from public.configure_household_deletion_retention_hold(
      '20000000-0000-4000-8000-000000000101',
      false,
      null,
      null,
      1,
      '99000000-0000-4000-8000-000000000003'
    ) as hold
  $$,
  $$ values (false, 2::bigint) $$,
  'releasing the hold returns deletion to its due queue'
);

create temporary table household_deletion_claim on commit drop as
select claim.*
from public.claim_household_deletion_requests(
  '99000000-0000-4000-8000-000000000004',
  5,
  180,
  pg_catalog.clock_timestamp() + interval '2 days'
) as claim;

select results_eq(
  $$ select attempts from household_deletion_claim $$,
  $$ values (1) $$,
  'deletion worker obtains one bounded lease after hold release'
);

select results_eq(
  $$
    select completed.result->>'status',
      completed.result->'deletion'->>'accessRevokedAt' is not null,
      completed.result->'deletion'->>'redactedAt' is not null,
      completed.result->'deletion'->>'billingUnlinkedAt' is not null
    from household_deletion_claim as claim
    cross join lateral public.complete_household_deletion_request(
      claim.privacy_request_id,
      claim.lease_token,
      pg_catalog.clock_timestamp() + interval '2 days 1 second'
    ) as completed
  $$,
  $$ values ('completed'::text, true, true, true) $$,
  'one transaction closes access redacts content and unlinks billing'
);

reset role;

select results_eq(
  $$
    select household.name, household.deleted_at is not null,
      household.created_by_user_id is null
    from public.households as household
    where household.id = '20000000-0000-4000-8000-000000000101'
  $$,
  $$ values ('Deleted household'::text, true, true) $$,
  'household aggregate is tombstoned without physical deletion'
);

select results_eq(
  $$
    select count(*), bool_and(member.display_name = 'Deleted member'),
      bool_and(member.avatar_key is null),
      bool_and(member.removed_at is not null)
    from public.household_members as member
    where member.household_id = '20000000-0000-4000-8000-000000000101'
  $$,
  $$ values (2::bigint, true, true, true) $$,
  'all household member display identities are tombstoned and removed'
);

select results_eq(
  $$
    select series.title, series.description is null,
      revision.title, revision.description is null
    from public.chore_series as series
    join public.chore_series_revisions as revision
      on revision.household_id = series.household_id
     and revision.series_id = series.id
    where series.household_id = '20000000-0000-4000-8000-000000000101'
  $$,
  $$ values ('Deleted chore'::text, true, 'Deleted chore'::text, true) $$,
  'chore aggregate and immutable revision content are safely redacted'
);

select results_eq(
  $$
    select series.title, series.description is null,
      revision.snapshot_description is null
    from public.event_series as series
    join public.event_series_revisions as revision
      on revision.household_id = series.household_id
     and revision.series_id = series.id
    where series.household_id = '20000000-0000-4000-8000-000000000101'
  $$,
  $$ values ('Deleted event'::text, true, true) $$,
  'calendar aggregate and revision content are safely redacted'
);

select results_eq(
  $$
    select endpoint.revocation_reason,
      endpoint.permission_state,
      endpoint.token_ciphertext = decode(repeat('00', 29), 'hex'),
      endpoint.revoked_at is not null
    from public.notification_endpoints as endpoint
    where endpoint.id = '93000000-0000-4000-8000-000000000001'
  $$,
  $$ values ('household_deleted'::text, 'denied'::text, true, true) $$,
  'provider endpoint material is erased and permanently revoked'
);

select results_eq(
  $$
    select assignment.status, assignment.ended_at is not null,
      entitlement.plan_code, entitlement.status::text,
      entitlement.assignment_id is null, entitlement.will_renew
    from public.billing_household_assignments as assignment
    join public.household_entitlements as entitlement
      on entitlement.household_id = assignment.household_id
    where assignment.id = '92000000-0000-4000-8000-000000000002'
  $$,
  $$ values ('ended'::text, true, 'free'::text, 'none'::text, true, false) $$,
  'billing assignment ends and entitlement resets without deleting provider history'
);

select results_eq(
  $$
    select count(*), bool_and(profile.deleted_at is null)
    from public.profiles as profile
    where profile.auth_user_id in (
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000102'
    )
  $$,
  $$ values (2::bigint, true) $$,
  'member accounts and personal profiles remain active'
);

select is(
  (
    select count(*) from public.user_active_households as active_household
    where active_household.household_id =
      '20000000-0000-4000-8000-000000000101'
  ),
  0::bigint,
  'deleted household is removed from every active selector'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select count(*) from public.households as household
    where household.id = '20000000-0000-4000-8000-000000000101'
  ),
  0::bigint,
  'stale authenticated session immediately loses deleted-household RLS access'
);
reset role;

set local role service_role;
create temporary table household_export_purge_claim on commit drop as
select purge.*
from public.claim_household_export_purge_jobs(
  '99000000-0000-4000-8000-000000000005',
  10,
  120,
  pg_catalog.clock_timestamp() + interval '2 days 2 seconds'
) as purge;

select is(
  (select count(*) from household_export_purge_claim),
  1::bigint,
  'household deletion immediately queues its shared archive for purge'
);

select lives_ok(
  $$
    select *
    from household_export_purge_claim as claim
    cross join lateral public.complete_household_export_purge_job(
      claim.household_export_id,
      claim.lease_token,
      pg_catalog.clock_timestamp() + interval '2 days 3 seconds'
    )
  $$,
  'confirmed Storage removal completes the private archive purge'
);
reset role;

select results_eq(
  $$
    select export.machine_object_key is null,
      export.human_object_key is null,
      export.machine_checksum_sha256 = repeat('a', 64),
      export.purged_at is not null
    from public.household_exports as export
  $$,
  $$ values (true, true, true, true) $$,
  'purge erases object paths while retaining non-secret integrity evidence'
);

select throws_ok(
  $$ update app_private.household_privacy_events
     set transition = 'deletion_failed' $$,
  'KHP30',
  'household privacy audit is immutable',
  'household privacy audit evidence cannot be rewritten'
);

select results_eq(
  $$
    select action, actor_kind, reason_code
    from app_private.billing_assignment_transitions
    where assignment_id = '92000000-0000-4000-8000-000000000002'
      and reason_code = 'household_deleted'
  $$,
  $$ values ('released'::text, 'system'::text, 'household_deleted'::text) $$,
  'billing unlink leaves immutable system audit without cancelling the Store plan'
);

select * from finish();
rollback;
