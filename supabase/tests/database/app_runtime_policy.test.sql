begin;
set constraints all deferred;

select no_plan();

select has_table(
  'app_private',
  'app_runtime_policies',
  'private runtime policy table exists'
);
select has_table(
  'app_private',
  'app_runtime_policy_events',
  'private immutable runtime policy audit exists'
);
select has_function(
  'public',
  'get_app_runtime_policy',
  array['text', 'text']
);
select has_function(
  'public',
  'configure_app_runtime_policy',
  array[
    'text',
    'text',
    'text',
    'bigint',
    'date',
    'date',
    'boolean',
    'bigint',
    'uuid'
  ]
);
select is(
  (
    select procedure.provolatile::text
    from pg_catalog.pg_proc as procedure
    join pg_catalog.pg_namespace as namespace
      on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname = 'get_app_runtime_policy'
      and pg_catalog.pg_get_function_identity_arguments(procedure.oid) =
        'p_environment text, p_platform text'
  ),
  'v'::text,
  'runtime policy read volatility matches its wall-clock evaluated_at field'
);

select results_eq(
  $$
    select environment, platform, minimum_supported_version,
      minimum_supported_build, minimum_contract_version,
      maximum_contract_version, mutations_enabled, version
    from app_private.app_runtime_policies
    where platform = 'android'
    order by environment
  $$,
  $$
    values
      ('dev'::text, 'android'::text, '0.0.0'::text, 0::bigint,
        null::date, null::date, true, 1::bigint),
      ('prod'::text, 'android'::text, '0.0.0'::text, 0::bigint,
        null::date, null::date, true, 1::bigint)
  $$,
  'dev and prod Android policies ship compatibility-open'
);

select ok(
  has_function_privilege(
    'anon',
    'public.get_app_runtime_policy(text,text)',
    'execute'
  )
    and has_function_privilege(
      'authenticated',
      'public.get_app_runtime_policy(text,text)',
      'execute'
    )
    and not has_function_privilege(
      'authenticated',
      'public.configure_app_runtime_policy(text,text,text,bigint,date,date,boolean,bigint,uuid)',
      'execute'
    )
    and has_function_privilege(
      'service_role',
      'public.configure_app_runtime_policy(text,text,text,bigint,date,date,boolean,bigint,uuid)',
      'execute'
    ),
  'public read and service mutation grants are exact'
);
select ok(
  not has_table_privilege(
    'anon',
    'app_private.app_runtime_policies',
    'select'
  )
    and not has_table_privilege(
      'authenticated',
      'app_private.app_runtime_policies',
      'select'
    )
    and not has_table_privilege(
      'service_role',
      'app_private.app_runtime_policies',
      'select'
    )
    and not has_table_privilege(
      'service_role',
      'app_private.app_runtime_policy_events',
      'select'
    ),
  'private policy and audit have no direct client or service grants'
);
select is(
  (
    select pg_catalog.count(*)
    from pg_catalog.pg_trigger as trigger
    join pg_catalog.pg_class as relation
      on relation.oid = trigger.tgrelid
    join pg_catalog.pg_namespace as namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and trigger.tgname = 'app_runtime_policy_guard'
      and not trigger.tgisinternal
  ),
  30::bigint,
  'all current non-privacy product tables have a runtime policy guard'
);
select ok(
  not exists (
    select 1
    from pg_catalog.pg_trigger as trigger
    where trigger.tgname = 'app_runtime_policy_guard'
      and trigger.tgrelid in (
        'public.privacy_requests'::regclass,
        'public.data_exports'::regclass,
        'public.household_exports'::regclass
      )
      and not trigger.tgisinternal
  ),
  'privacy and export lifecycles remain outside the global mutation gate'
);

set local role anon;
select results_eq(
  $$
    select environment, platform, minimum_supported_version,
      minimum_supported_build, minimum_contract_version,
      maximum_contract_version, mutations_enabled, policy_version
    from public.get_app_runtime_policy('dev', 'android')
  $$,
  $$
    values ('dev'::text, 'android'::text, '0.0.0'::text, 0::bigint,
      null::text, null::text, true, 1::bigint)
  $$,
  'anonymous startup can read only the sanitized exact policy'
);
select throws_ok(
  $$ select * from public.get_app_runtime_policy('staging', 'android') $$,
  '22023',
  'invalid app runtime policy scope',
  'unknown environment is rejected'
);
reset role;

select throws_ok(
  $$
    select * from public.configure_app_runtime_policy(
      'dev',
      'android',
      '1.0.0',
      0,
      null,
      null,
      true,
      1,
      '68000000-0000-4000-8000-000000000001'
    )
  $$,
  '22023',
  'invalid app runtime policy configuration',
  'a display minimum cannot be configured without an enforcing build'
);
select throws_ok(
  $$
    select * from public.configure_app_runtime_policy(
      'dev',
      'android',
      '1.0.0',
      2,
      '2026-12-31',
      '2026-01-01',
      true,
      1,
      '68000000-0000-4000-8000-000000000002'
    )
  $$,
  '22023',
  'invalid app runtime policy configuration',
  'inverted contract range is rejected'
);

select results_eq(
  $$
    select environment, platform, minimum_supported_version,
      minimum_supported_build, minimum_contract_version,
      maximum_contract_version, mutations_enabled, policy_version
    from public.configure_app_runtime_policy(
      'dev',
      'android',
      '1.0.0',
      2,
      '2026-07-25',
      '2026-12-31',
      false,
      1,
      '68000000-0000-4000-8000-000000000003'
    )
  $$,
  $$
    values ('dev'::text, 'android'::text, '1.0.0'::text, 2::bigint,
      '2026-07-25'::text, '2026-12-31'::text, false, 2::bigint)
  $$,
  'service configuration atomically raises the minimum and disables mutations'
);
select results_eq(
  $$
    select environment, platform, minimum_supported_version,
      minimum_supported_build, minimum_contract_version,
      maximum_contract_version, mutations_enabled, policy_version
    from public.configure_app_runtime_policy(
      'dev',
      'android',
      '1.0.0',
      2,
      '2026-07-25',
      '2026-12-31',
      false,
      1,
      '68000000-0000-4000-8000-000000000003'
    )
  $$,
  $$
    values ('dev'::text, 'android'::text, '1.0.0'::text, 2::bigint,
      '2026-07-25'::text, '2026-12-31'::text, false, 2::bigint)
  $$,
  'exact correlation replay returns the original policy result'
);
select is(
  (
    select pg_catalog.count(*)
    from app_private.app_runtime_policy_events
    where correlation_id =
      '68000000-0000-4000-8000-000000000003'
  ),
  1::bigint,
  'configuration replay does not duplicate audit'
);
select throws_ok(
  $$
    select * from public.configure_app_runtime_policy(
      'dev',
      'android',
      '1.0.1',
      3,
      '2026-07-25',
      '2026-12-31',
      false,
      2,
      '68000000-0000-4000-8000-000000000003'
    )
  $$,
  'KFR05',
  'app runtime policy correlation reused',
  'mismatched correlation reuse is rejected'
);
select throws_ok(
  $$
    select * from public.configure_app_runtime_policy(
      'dev',
      'android',
      '1.0.0',
      2,
      '2026-07-25',
      '2026-12-31',
      false,
      1,
      '68000000-0000-4000-8000-000000000004'
    )
  $$,
  'KFR04',
  'app runtime policy version conflict',
  'stale operator version is rejected'
);
select throws_ok(
  $$
    update app_private.app_runtime_policy_events
    set mutations_enabled = true
    where correlation_id =
      '68000000-0000-4000-8000-000000000003'
  $$,
  '42501',
  'app runtime policy events are immutable',
  'runtime policy audit cannot be rewritten'
);

insert into public.households (
  id,
  name,
  timezone,
  owner_member_id,
  created_by_user_id
)
values (
  '28000000-0000-4000-8000-000000000101',
  'Runtime Policy Switch Target',
  'Asia/Seoul',
  '38000000-0000-4000-8000-000000000101',
  '00000000-0000-4000-8000-000000000101'
);
insert into public.household_members (
  id,
  household_id,
  auth_user_id,
  display_name,
  role,
  created_by_user_id
)
values (
  '38000000-0000-4000-8000-000000000101',
  '28000000-0000-4000-8000-000000000101',
  '00000000-0000-4000-8000-000000000101',
  'Runtime Policy Adult',
  'owner',
  '00000000-0000-4000-8000-000000000101'
);

set local role authenticated;
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select pg_catalog.set_config(
  'request.headers',
  '{"x-kinflow-client-version":"0.1.0-dev+1","x-kinflow-client-build":"1","x-kinflow-contract-version":"2026-07-25","x-kinflow-platform":"android","x-kinflow-environment":"dev"}',
  true
);
select pg_catalog.set_config('app.runtime_policy_checked', '', true);
select throws_ok(
  $$
    select * from public.switch_active_household(
      '28000000-0000-4000-8000-000000000101',
      1
    )
  $$,
  'KFR01',
  'client update required',
  'minimum build takes precedence over the read-only switch'
);

select pg_catalog.set_config(
  'request.headers',
  '{"x-kinflow-client-version":"1.0.0+2","x-kinflow-client-build":"2","x-kinflow-contract-version":"2026-07-25","x-kinflow-platform":"android","x-kinflow-environment":"dev"}',
  true
);
select pg_catalog.set_config('app.runtime_policy_checked', '', true);
select throws_ok(
  $$
    select * from public.switch_active_household(
      '28000000-0000-4000-8000-000000000101',
      1
    )
  $$,
  'KFR02',
  'client mutations disabled',
  'compatible build is still stopped by the global mutation switch'
);

select pg_catalog.set_config(
  'request.headers',
  '{"x-kinflow-client-build":"two","x-kinflow-platform":"android","x-kinflow-environment":"dev"}',
  true
);
select pg_catalog.set_config('app.runtime_policy_checked', '', true);
select throws_ok(
  $$
    select * from public.switch_active_household(
      '28000000-0000-4000-8000-000000000101',
      1
    )
  $$,
  'KFR03',
  'app runtime policy unavailable',
  'malformed compatibility headers fail with a stable policy error'
);
reset role;

select pg_catalog.set_config('request.jwt.claim.sub', '', true);
select pg_catalog.set_config(
  'request.headers',
  '{"x-kinflow-forwarded-user-operation":"1","x-kinflow-client-version":"0.1.0-dev+1","x-kinflow-client-build":"1","x-kinflow-contract-version":"2026-07-25","x-kinflow-platform":"android","x-kinflow-environment":"dev"}',
  true
);
select pg_catalog.set_config('app.runtime_policy_checked', '', true);
select throws_ok(
  $$
    update public.user_active_households
    set household_id = household_id
    where auth_user_id =
      '00000000-0000-4000-8000-000000000101'
  $$,
  'KFR01',
  'client update required',
  'forwarded service-role user operations cannot bypass the minimum build'
);

select results_eq(
  $$
    select minimum_supported_version, minimum_supported_build,
      minimum_contract_version, maximum_contract_version,
      mutations_enabled, policy_version
    from public.configure_app_runtime_policy(
      'dev',
      'android',
      '0.0.0',
      0,
      null,
      null,
      true,
      2,
      '68000000-0000-4000-8000-000000000005'
    )
  $$,
  $$
    values ('0.0.0'::text, 0::bigint, null::text, null::text,
      true, 3::bigint)
  $$,
  'audited emergency rollback can reopen mutations and lower the minimum'
);

set local role authenticated;
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select pg_catalog.set_config(
  'request.headers',
  '{"x-kinflow-client-version":"0.1.0-dev+1","x-kinflow-client-build":"1","x-kinflow-contract-version":"2026-07-25","x-kinflow-platform":"android","x-kinflow-environment":"dev"}',
  true
);
select pg_catalog.set_config('app.runtime_policy_checked', '', true);
select lives_ok(
  $$
    select * from public.switch_active_household(
      '28000000-0000-4000-8000-000000000101',
      1
    )
  $$,
  'compatible authenticated mutation resumes after policy rollback'
);
reset role;

select pg_catalog.set_config(
  'request.headers',
  '{"x-kinflow-forwarded-user-operation":"1","x-kinflow-client-version":"0.1.0-dev+1","x-kinflow-client-build":"1","x-kinflow-contract-version":"2026-07-25","x-kinflow-platform":"android","x-kinflow-environment":"dev"}',
  true
);
select pg_catalog.set_config('app.runtime_policy_checked', '', true);
select lives_ok(
  $$
    update public.user_active_households
    set household_id = household_id
    where auth_user_id =
      '00000000-0000-4000-8000-000000000101'
  $$,
  'forwarded user operation marker evaluates and allows a compatible service RPC'
);

select pg_catalog.set_config('request.headers', '{}', true);
select pg_catalog.set_config('app.runtime_policy_checked', '', true);
select lives_ok(
  $$
    update public.user_active_households
    set household_id = household_id
    where auth_user_id =
      '00000000-0000-4000-8000-000000000101'
  $$,
  'worker and service writes without a user marker remain available'
);

select * from finish();
rollback;
