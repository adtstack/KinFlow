begin;
set constraints all deferred;

select plan(58);

-- Schema, least privilege, and content-free metadata contracts.
select has_table(
  'public',
  'notification_endpoints',
  'encrypted notification endpoint table exists'
);
select has_table(
  'app_private',
  'notification_endpoint_events',
  'private endpoint lifecycle audit exists'
);
select has_function(
  'public',
  'get_notification_endpoint_status',
  array['uuid', 'text'],
  'authenticated metadata status API exists'
);
select has_function(
  'public',
  'upsert_notification_endpoint',
  array[
    'uuid', 'uuid', 'uuid', 'text', 'text', 'text', 'text', 'integer',
    'text', 'text', 'text', 'text', 'text', 'text', 'uuid', 'bigint',
    'timestamp with time zone'
  ],
  'service registration API exists'
);
select has_function(
  'public',
  'revoke_notification_endpoint_by_secret',
  array['uuid', 'text', 'uuid', 'text', 'timestamp with time zone'],
  'binding-secret revoke API exists'
);
select has_function(
  'public',
  'invalidate_notification_endpoint',
  array['uuid', 'text', 'text', 'timestamp with time zone'],
  'provider invalid-token cleanup API exists'
);
select has_function(
  'app_private',
  'decode_notification_endpoint_material',
  array['text', 'integer', 'integer', 'integer'],
  'private base64 material validator exists'
);
select is(
  (
    select string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'notification_endpoints'
  ),
  'id,auth_user_id,household_id,member_id,installation_id,channel,platform,token_ciphertext,token_fingerprint,token_key_version,revocation_secret_hash,permission_state,locale,timezone,app_version,runtime_version,last_registration_id,last_seen_at,revoked_at,revocation_reason,created_at,updated_at,version',
  'endpoint persistence has exact routing, sealed-token, proof, metadata, and lifecycle columns'
);
select is(
  (
    select string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'notification_endpoint_events'
  ),
  'id,endpoint_id,transition,reason_code,endpoint_version,occurred_at',
  'endpoint audit excludes user display data and all token material'
);
select is(
  (
    select string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name like 'get_notification_endpoint_status_%'
      and parameter_mode = 'OUT'
  ),
  'endpoint_id,household_id,member_id,installation_id,channel,platform,permission_state,locale,timezone,app_version,runtime_version,last_registration_id,last_seen_at,revoked_at,revocation_reason,version',
  'client status response is metadata-only'
);
select is(
  (
    select string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name like 'upsert_notification_endpoint_%'
      and parameter_mode = 'OUT'
  ),
  'endpoint_id,household_id,member_id,installation_id,channel,platform,permission_state,locale,timezone,app_version,runtime_version,last_registration_id,last_seen_at,revoked_at,revocation_reason,version',
  'registration response exposes no token ciphertext fingerprint or secret hash'
);
select ok(
  (
    select c.relrowsecurity and c.relforcerowsecurity
    from pg_class as c
    join pg_namespace as n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'notification_endpoints'
  ),
  'endpoint table enables and forces RLS'
);
select policies_are(
  'public',
  'notification_endpoints',
  array['notification_endpoints_select_self'],
  'endpoint table has one recipient metadata policy'
);
select has_trigger(
  'public',
  'notification_endpoints',
  'notification_endpoints_set_updated_at_and_version',
  'endpoint updates advance server version'
);
select has_trigger(
  'public',
  'notification_endpoints',
  'notification_endpoints_audit_transition',
  'endpoint lifecycle is audited'
);
select has_trigger(
  'app_private',
  'notification_endpoint_events',
  'notification_endpoint_events_immutable',
  'endpoint audit is immutable'
);
select has_trigger(
  'public',
  'household_members',
  'household_members_revoke_notification_endpoints',
  'member removal revokes household endpoint bindings'
);
select ok(
  pg_get_indexdef('public.notification_endpoints_active_token_uq'::regclass)
    like '%channel, token_fingerprint%WHERE (revoked_at IS NULL)%',
  'one active endpoint can own a provider token fingerprint'
);
select ok(
  not has_table_privilege('authenticated', 'public.notification_endpoints', 'select')
    and not has_table_privilege('authenticated', 'public.notification_endpoints', 'insert')
    and not has_table_privilege('service_role', 'public.notification_endpoints', 'select')
    and not has_table_privilege('service_role', 'public.notification_endpoints', 'update'),
  'client and direct service-role table access are denied'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.get_notification_endpoint_status(uuid,text)',
    'execute'
  )
    and not has_function_privilege(
      'anon',
      'public.get_notification_endpoint_status(uuid,text)',
      'execute'
    )
    and not has_function_privilege(
      'service_role',
      'public.get_notification_endpoint_status(uuid,text)',
      'execute'
    ),
  'only authenticated users can request their endpoint metadata'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.upsert_notification_endpoint(uuid,uuid,uuid,text,text,text,text,integer,text,text,text,text,text,text,uuid,bigint,timestamptz)',
    'execute'
  )
    and has_function_privilege(
      'service_role',
      'public.revoke_notification_endpoint_by_secret(uuid,text,uuid,text,timestamptz)',
      'execute'
    )
    and has_function_privilege(
      'service_role',
      'public.invalidate_notification_endpoint(uuid,text,text,timestamptz)',
      'execute'
    )
    and not has_function_privilege(
      'authenticated',
      'public.upsert_notification_endpoint(uuid,uuid,uuid,text,text,text,text,integer,text,text,text,text,text,text,uuid,bigint,timestamptz)',
      'execute'
    ),
  'only service role can use sealed-token mutation APIs'
);
select ok(
  not has_function_privilege(
    'service_role',
    'app_private.decode_notification_endpoint_material(text,integer,integer,integer)',
    'execute'
  )
    and not has_table_privilege(
      'service_role',
      'app_private.notification_endpoint_events',
      'select'
    ),
  'service clients cannot call private token helpers or read lifecycle audit'
);
select ok(
  not exists (
    select 1
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname in (
        'get_notification_endpoint_status',
        'upsert_notification_endpoint',
        'revoke_notification_endpoint_by_secret',
        'invalidate_notification_endpoint'
      )
      and (
        not pg_proc.prosecdef
        or not pg_proc.proconfig @> array['search_path=""']::text[]
      )
  ),
  'every endpoint API is security-definer with empty search path'
);

-- Input rejection does not create partial endpoint state.
set local role service_role;
select throws_ok(
  $$
    select * from public.upsert_notification_endpoint(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      '53000000-0000-4000-8000-000000000001',
      'native_push', 'android', 'not-base64', 'not-base64', 1,
      'not-base64', 'granted', 'ko', 'Asia/Seoul', '0.1.0',
      'Flutter 3.44.7', '53010000-0000-4000-8000-000000000001', 0,
      '2026-08-08 00:00:00+00'
    )
  $$,
  'KND01',
  'invalid notification endpoint input',
  'malformed sealed material is rejected'
);
select throws_ok(
  $$
    select * from public.upsert_notification_endpoint(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      '53000000-0000-4000-8000-000000000001',
      'native_push', 'android',
      encode(decode(repeat('01', 32), 'hex'), 'base64'),
      encode(decode(repeat('02', 32), 'hex'), 'base64'), 1,
      encode(decode(repeat('03', 32), 'hex'), 'base64'),
      'prompt', 'ko', 'Asia/Seoul', '0.1.0', 'Flutter 3.44.7',
      '53010000-0000-4000-8000-000000000001', 0,
      '2026-08-08 00:00:00+00'
    )
  $$,
  'KND01',
  'invalid notification endpoint input',
  'only granted provider tokens can become active endpoints'
);
select throws_ok(
  $$
    select * from public.upsert_notification_endpoint(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000201',
      '53000000-0000-4000-8000-000000000001',
      'native_push', 'android',
      encode(decode(repeat('01', 32), 'hex'), 'base64'),
      encode(decode(repeat('02', 32), 'hex'), 'base64'), 1,
      encode(decode(repeat('03', 32), 'hex'), 'base64'),
      'granted', 'ko', 'Asia/Seoul', '0.1.0', 'Flutter 3.44.7',
      '53010000-0000-4000-8000-000000000001', 0,
      '2026-08-08 00:00:00+00'
    )
  $$,
  'KND03',
  'notification household not found or forbidden',
  'verified identity cannot bind an unrelated household'
);
reset role;
select is(
  (select count(*) from public.notification_endpoints),
  0::bigint,
  'rejected registration leaves no endpoint'
);

create temporary table endpoint_results (
  label text primary key,
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
grant all on table endpoint_results to service_role;
grant select on table endpoint_results to authenticated;

-- Initial registration and response-loss replay.
set local role service_role;
insert into endpoint_results
select 'initial', result.*
from public.upsert_notification_endpoint(
  '00000000-0000-4000-8000-000000000101',
  '20000000-0000-4000-8000-000000000101',
  '53000000-0000-4000-8000-000000000001',
  'native_push', 'android',
  encode(decode(repeat('11', 32), 'hex'), 'base64'),
  encode(decode(repeat('12', 32), 'hex'), 'base64'), 1,
  encode(decode(repeat('13', 32), 'hex'), 'base64'),
  'granted', 'ko-KR', 'Asia/Seoul', '0.1.0+1', 'Flutter 3.44.7',
  '53010000-0000-4000-8000-000000000001', 0,
  '2026-08-08 00:00:00+00'
) as result;
reset role;
select is(
  (
    select concat_ws(
      ':', household_id, member_id, installation_id, channel, platform,
      permission_state, locale, timezone, version, revoked_at
    )
    from endpoint_results where label = 'initial'
  ),
  '20000000-0000-4000-8000-000000000101:30000000-0000-4000-8000-000000000101:53000000-0000-4000-8000-000000000001:native_push:android:granted:ko-KR:Asia/Seoul:1',
  'initial registration returns exact metadata and version one'
);
select is(
  (
    select concat_ws(
      ':', octet_length(token_ciphertext), octet_length(token_fingerprint),
      octet_length(revocation_secret_hash), token_key_version
    )
    from public.notification_endpoints
    where installation_id = '53000000-0000-4000-8000-000000000001'
  ),
  '32:32:32:1',
  'server persistence contains bounded sealed material only'
);
select is(
  (
    select concat_ws(':', transition, endpoint_version, reason_code)
    from app_private.notification_endpoint_events
  ),
  'registered:1',
  'initial endpoint lifecycle emits one content-free registered audit'
);

set local role service_role;
insert into endpoint_results
select 'replay', result.*
from public.upsert_notification_endpoint(
  '00000000-0000-4000-8000-000000000101',
  '20000000-0000-4000-8000-000000000101',
  '53000000-0000-4000-8000-000000000001',
  'native_push', 'android',
  encode(decode(repeat('14', 32), 'hex'), 'base64'),
  encode(decode(repeat('12', 32), 'hex'), 'base64'), 1,
  encode(decode(repeat('13', 32), 'hex'), 'base64'),
  'granted', 'ko-KR', 'Asia/Seoul', '0.1.0+1', 'Flutter 3.44.7',
  '53010000-0000-4000-8000-000000000001', 0,
  '2026-08-08 00:00:01+00'
) as result;
reset role;
select is(
  (
    select concat_ws(
      ':', replay.endpoint_id = initial.endpoint_id,
      replay.version, replay.last_seen_at
    )
    from endpoint_results as replay
    join endpoint_results as initial on initial.label = 'initial'
    where replay.label = 'replay'
  ),
  't:1:2026-08-08 00:00:00+00',
  'response-loss replay returns the original endpoint without advancing state'
);
select is(
  (
    select count(*)
    from app_private.notification_endpoint_events
  ),
  1::bigint,
  'response-loss replay emits no duplicate audit'
);

set local role service_role;
select throws_ok(
  $$
    select * from public.upsert_notification_endpoint(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      '53000000-0000-4000-8000-000000000001',
      'native_push', 'ios',
      encode(decode(repeat('11', 32), 'hex'), 'base64'),
      encode(decode(repeat('12', 32), 'hex'), 'base64'), 1,
      encode(decode(repeat('13', 32), 'hex'), 'base64'),
      'granted', 'ko-KR', 'Asia/Seoul', '0.1.0+1', 'Flutter 3.44.7',
      '53010000-0000-4000-8000-000000000001', 1,
      '2026-08-08 00:00:02+00'
    )
  $$,
  'KND04',
  'notification registration id reused',
  'one registration id cannot be reused with different metadata'
);
select throws_ok(
  $$
    select * from public.upsert_notification_endpoint(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      '53000000-0000-4000-8000-000000000001',
      'native_push', 'android',
      encode(decode(repeat('21', 32), 'hex'), 'base64'),
      encode(decode(repeat('22', 32), 'hex'), 'base64'), 1,
      encode(decode(repeat('23', 32), 'hex'), 'base64'),
      'granted', 'ko-KR', 'Asia/Seoul', '0.1.0+1', 'Flutter 3.44.7',
      '53010000-0000-4000-8000-000000000002', 0,
      '2026-08-08 00:00:02+00'
    )
  $$,
  'KND06',
  'notification endpoint version conflict',
  'stale expected version cannot rotate a token'
);
reset role;

-- Same-token refresh then token rotation.
set local role service_role;
insert into endpoint_results
select 'refresh', result.*
from public.upsert_notification_endpoint(
  '00000000-0000-4000-8000-000000000101',
  '20000000-0000-4000-8000-000000000101',
  '53000000-0000-4000-8000-000000000001',
  'native_push', 'android',
  encode(decode(repeat('15', 32), 'hex'), 'base64'),
  encode(decode(repeat('12', 32), 'hex'), 'base64'), 2,
  encode(decode(repeat('16', 32), 'hex'), 'base64'),
  'granted', 'ko-KR', 'Asia/Seoul', '0.1.1+2', 'Flutter 3.44.7',
  '53010000-0000-4000-8000-000000000002', 1,
  '2026-08-08 00:01:00+00'
) as result;
insert into endpoint_results
select 'rotation', result.*
from public.upsert_notification_endpoint(
  '00000000-0000-4000-8000-000000000101',
  '20000000-0000-4000-8000-000000000101',
  '53000000-0000-4000-8000-000000000001',
  'native_push', 'android',
  encode(decode(repeat('25', 32), 'hex'), 'base64'),
  encode(decode(repeat('22', 32), 'hex'), 'base64'), 2,
  encode(decode(repeat('26', 32), 'hex'), 'base64'),
  'granted', 'ko-KR', 'Asia/Seoul', '0.1.2+3', 'Flutter 3.44.7',
  '53010000-0000-4000-8000-000000000003', 2,
  '2026-08-08 00:02:00+00'
) as result;
reset role;
select is(
  (select version from endpoint_results where label = 'refresh'),
  2::bigint,
  'same-token metadata refresh advances the endpoint version'
);
select is(
  (select version from endpoint_results where label = 'rotation'),
  3::bigint,
  'token rotation updates the same endpoint at the next version'
);
select is(
  (
    select string_agg(
      concat_ws(':', transition, endpoint_version),
      ',' order by endpoint_version
    )
    from app_private.notification_endpoint_events
  ),
  'registered:1,refreshed:2,rotated:3',
  'registration refresh and rotation have distinct immutable transitions'
);
select is(
  (
    select count(distinct endpoint_id)
    from endpoint_results
    where label in ('initial', 'refresh', 'rotation')
  ),
  1::bigint,
  'rotation preserves one endpoint identity for one installation'
);

-- Authenticated metadata status is recipient-only and contains no token material.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
set local role authenticated;
select is(
  (
    select concat_ws(
      ':', endpoint_id, installation_id, last_registration_id, version,
      revoked_at
    )
    from public.get_notification_endpoint_status(
      '53000000-0000-4000-8000-000000000001', 'native_push'
    )
  ),
  (
    select concat_ws(
      ':', endpoint_id, installation_id, last_registration_id, version,
      revoked_at
    )
    from endpoint_results where label = 'rotation'
  ),
  'owner can recover exact current endpoint metadata'
);
reset role;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
set local role authenticated;
select is(
  (
    select count(*)
    from public.get_notification_endpoint_status(
      '53000000-0000-4000-8000-000000000001', 'native_push'
    )
  ),
  0::bigint,
  'another household member cannot inspect the owner installation'
);
reset role;
select set_config('request.jwt.claim.sub', '', true);
set local role authenticated;
select throws_ok(
  $$
    select * from public.get_notification_endpoint_status(
      '53000000-0000-4000-8000-000000000001', 'native_push'
    )
  $$,
  'KND02',
  'authentication required',
  'status API requires authentication'
);
reset role;

-- Late provider failures cannot invalidate a rotated token.
set local role service_role;
select is(
  public.invalidate_notification_endpoint(
    (select endpoint_id from endpoint_results where label = 'rotation'),
    encode(decode(repeat('12', 32), 'hex'), 'base64'),
    'provider_unregistered',
    '2026-08-08 00:03:00+00'
  ),
  0,
  'late invalid-token result for the previous fingerprint is ignored'
);
select is(
  public.invalidate_notification_endpoint(
    (select endpoint_id from endpoint_results where label = 'rotation'),
    encode(decode(repeat('22', 32), 'hex'), 'base64'),
    'provider_unregistered',
    '2026-08-08 00:03:01+00'
  ),
  1,
  'current provider fingerprint revokes exactly one endpoint'
);
reset role;
select is(
  (
    select concat_ws(':', revocation_reason, version)
    from public.notification_endpoints
    where installation_id = '53000000-0000-4000-8000-000000000001'
  ),
  'provider_unregistered:4',
  'provider invalidation stores only stable reason and advances version'
);

-- Re-registration rotates the proof, and only the exact current proof revokes.
set local role service_role;
insert into endpoint_results
select 'reactivated', result.*
from public.upsert_notification_endpoint(
  '00000000-0000-4000-8000-000000000101',
  '20000000-0000-4000-8000-000000000101',
  '53000000-0000-4000-8000-000000000001',
  'native_push', 'android',
  encode(decode(repeat('35', 32), 'hex'), 'base64'),
  encode(decode(repeat('32', 32), 'hex'), 'base64'), 3,
  encode(decode(repeat('36', 32), 'hex'), 'base64'),
  'granted', 'ko-KR', 'Asia/Seoul', '0.1.3+4', 'Flutter 3.44.7',
  '53010000-0000-4000-8000-000000000004', 4,
  '2026-08-08 00:04:00+00'
) as result;
select is(
  public.revoke_notification_endpoint_by_secret(
    '53000000-0000-4000-8000-000000000001',
    'native_push',
    '53010000-0000-4000-8000-000000000003',
    encode(decode(repeat('26', 32), 'hex'), 'base64'),
    '2026-08-08 00:04:01+00'
  ),
  0,
  'stale registration proof cannot revoke a reactivated endpoint'
);
select is(
  public.revoke_notification_endpoint_by_secret(
    '53000000-0000-4000-8000-000000000001',
    'native_push',
    '53010000-0000-4000-8000-000000000004',
    encode(decode(repeat('99', 32), 'hex'), 'base64'),
    '2026-08-08 00:04:02+00'
  ),
  0,
  'wrong 256-bit proof reveals no active endpoint match'
);
select is(
  public.revoke_notification_endpoint_by_secret(
    '53000000-0000-4000-8000-000000000001',
    'native_push',
    '53010000-0000-4000-8000-000000000004',
    encode(decode(repeat('36', 32), 'hex'), 'base64'),
    '2026-08-08 00:04:03+00'
  ),
  1,
  'exact binding proof revokes one active endpoint'
);
select is(
  public.revoke_notification_endpoint_by_secret(
    '53000000-0000-4000-8000-000000000001',
    'native_push',
    '53010000-0000-4000-8000-000000000004',
    encode(decode(repeat('36', 32), 'hex'), 'base64'),
    '2026-08-08 00:04:04+00'
  ),
  0,
  'binding proof revoke replay is idempotent'
);
reset role;
select is(
  (
    select concat_ws(':', revocation_reason, version)
    from public.notification_endpoints
    where installation_id = '53000000-0000-4000-8000-000000000001'
  ),
  'client_revoked:6',
  'client revoke stores no free-form reason and advances version once'
);

-- Active token possession reassigns ownership atomically across accounts.
set local role service_role;
insert into endpoint_results
select 'adult-a-shared-token', result.*
from public.upsert_notification_endpoint(
  '00000000-0000-4000-8000-000000000101',
  '20000000-0000-4000-8000-000000000101',
  '53000000-0000-4000-8000-000000000011',
  'native_push', 'android',
  encode(decode(repeat('41', 32), 'hex'), 'base64'),
  encode(decode(repeat('42', 32), 'hex'), 'base64'), 1,
  encode(decode(repeat('43', 32), 'hex'), 'base64'),
  'granted', 'ko', 'Asia/Seoul', '0.2.0', 'Flutter 3.44.7',
  '53010000-0000-4000-8000-000000000011', 0,
  '2026-08-08 00:05:00+00'
) as result;
insert into endpoint_results
select 'adult-b-shared-token', result.*
from public.upsert_notification_endpoint(
  '00000000-0000-4000-8000-000000000102',
  '20000000-0000-4000-8000-000000000101',
  '53000000-0000-4000-8000-000000000012',
  'native_push', 'android',
  encode(decode(repeat('44', 32), 'hex'), 'base64'),
  encode(decode(repeat('42', 32), 'hex'), 'base64'), 1,
  encode(decode(repeat('45', 32), 'hex'), 'base64'),
  'granted', 'ko', 'Asia/Seoul', '0.2.0', 'Flutter 3.44.7',
  '53010000-0000-4000-8000-000000000012', 0,
  '2026-08-08 00:05:01+00'
) as result;
reset role;
select is(
  (
    select concat_ws(
      ':',
      count(*) filter (where revoked_at is null),
      count(*) filter (
        where revocation_reason = 'token_reassigned'
      )
    )
    from public.notification_endpoints
    where installation_id in (
      '53000000-0000-4000-8000-000000000011',
      '53000000-0000-4000-8000-000000000012'
    )
  ),
  '1:1',
  'same provider token has one active owner and revokes the previous account'
);
select is(
  (
    select auth_user_id
    from public.notification_endpoints
    where token_fingerprint = decode(repeat('42', 32), 'hex')
      and revoked_at is null
  ),
  '00000000-0000-4000-8000-000000000102'::uuid,
  'latest verified token possession owns the active binding'
);

-- Household membership removal automatically revokes the matching binding.
select lives_ok(
  $$
    update public.household_members
    set removed_at = '2026-08-08 00:06:00+00'
    where household_id = '20000000-0000-4000-8000-000000000101'
      and id = '30000000-0000-4000-8000-000000000102'
  $$,
  'member removal completes with endpoint revocation in the same transaction'
);
select is(
  (
    select concat_ws(':', revocation_reason, version)
    from public.notification_endpoints
    where installation_id = '53000000-0000-4000-8000-000000000012'
  ),
  'membership_removed:2',
  'removed member endpoint is immediately inactive with stable reason'
);
select is(
  (
    select count(*)
    from app_private.notification_endpoint_events
    where reason_code = 'membership_removed'
      and transition = 'revoked'
  ),
  1::bigint,
  'membership removal emits one content-free revoke audit'
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
    from public.get_notification_endpoint_status(
      '53000000-0000-4000-8000-000000000012', 'native_push'
    )
  ),
  0::bigint,
  'removed member cannot recover revoked household endpoint metadata'
);
reset role;

select ok(
  not exists (
    select 1
    from public.notification_endpoints as endpoint
    where position(
      encode(convert_to('device-token', 'UTF8'), 'hex')
      in encode(endpoint.token_ciphertext, 'hex')
    ) > 0
  ),
  'sealed endpoint bytes do not contain a synthetic raw token marker'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'notification_endpoint_events'
      and column_name in (
        'token', 'token_ciphertext', 'token_fingerprint',
        'revocation_secret_hash', 'email', 'payload', 'error_detail'
      )
  ),
  'lifecycle audit cannot persist token content identity display or raw errors'
);
select throws_ok(
  $$
    update app_private.notification_endpoint_events
    set reason_code = 'client_revoked'
    where transition = 'registered'
  $$,
  '55000',
  'notification endpoint events are immutable',
  'endpoint lifecycle audit rejects mutation'
);

select * from finish();
rollback;
