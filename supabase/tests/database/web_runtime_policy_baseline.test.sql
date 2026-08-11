begin;
set constraints all deferred;

select no_plan();

select results_eq(
  $$
    select environment, platform, minimum_supported_version,
      minimum_supported_build, mutations_enabled, version
    from app_private.app_runtime_policies
    where platform = 'web'
    order by environment
  $$,
  $$
    values
      ('dev'::text, 'web'::text, '0.0.0'::text, 0::bigint, true, 1::bigint),
      ('prod'::text, 'web'::text, '0.0.0'::text, 0::bigint, true, 1::bigint)
  $$,
  'dev and prod Web runtime policies are independently seeded'
);

select is(
  (
    select pg_catalog.count(*)
    from app_private.app_runtime_feature_policies
    where platform = 'web'
      and mutations_enabled
  ),
  12::bigint,
  'all six Web capabilities are explicitly seeded per environment'
);

set local role anon;
select results_eq(
  $$
    select environment, platform, minimum_supported_version,
      minimum_supported_build, minimum_contract_version,
      maximum_contract_version, mutations_enabled, policy_version
    from public.get_app_runtime_policy('dev', 'web')
  $$,
  $$
    values ('dev'::text, 'web'::text, '0.0.0'::text, 0::bigint,
      null::text, null::text, true, 1::bigint)
  $$,
  'anonymous Web bootstrap reads only its sanitized policy'
);
select is(
  (
    select pg_catalog.count(*)
    from public.get_app_runtime_feature_policies('dev', 'web')
  ),
  6::bigint,
  'anonymous Web bootstrap reads exactly six capability policies'
);
select throws_ok(
  $$ select * from public.get_app_runtime_policy('dev', 'ios') $$,
  '22023',
  'invalid app runtime policy scope',
  'an undeclared runtime platform remains fail-closed'
);
reset role;

select results_eq(
  $$
    select environment, platform, minimum_supported_version,
      minimum_supported_build, mutations_enabled, policy_version
    from public.configure_app_runtime_policy(
      'dev',
      'web',
      '0.1.0-dev',
      1,
      '2026-07-25',
      '2026-12-31',
      true,
      1,
      '70000000-0000-4000-8000-000000000001'
    )
  $$,
  $$
    values ('dev'::text, 'web'::text, '0.1.0-dev'::text,
      1::bigint, true, 2::bigint)
  $$,
  'service configuration versions the Web compatibility policy'
);

select results_eq(
  $$
    select environment, platform, minimum_supported_version,
      minimum_supported_build, mutations_enabled, policy_version
    from public.configure_app_runtime_policy(
      'dev',
      'web',
      '0.1.0-dev',
      1,
      '2026-07-25',
      '2026-12-31',
      true,
      1,
      '70000000-0000-4000-8000-000000000001'
    )
  $$,
  $$
    values ('dev'::text, 'web'::text, '0.1.0-dev'::text,
      1::bigint, true, 2::bigint)
  $$,
  'Web compatibility policy correlation replay is idempotent'
);

select results_eq(
  $$
    select environment, platform, feature, mutations_enabled, policy_version
    from public.configure_app_runtime_feature_policy(
      'dev',
      'web',
      'chores',
      false,
      1,
      '70000000-0000-4000-8000-000000000002'
    )
  $$,
  $$
    values ('dev'::text, 'web'::text, 'chores'::text, false, 2::bigint)
  $$,
  'service configuration independently disables one Web capability'
);

select is(
  (
    select pg_catalog.count(*)
    from app_private.app_runtime_policy_events
    where platform = 'web'
      and correlation_id = '70000000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'Web compatibility configuration appends one immutable audit event'
);
select is(
  (
    select pg_catalog.count(*)
    from app_private.app_runtime_feature_policy_events
    where platform = 'web'
      and correlation_id = '70000000-0000-4000-8000-000000000002'
  ),
  1::bigint,
  'Web capability configuration appends one immutable audit event'
);

create temporary table web_runtime_household_probe(id integer);
create temporary table web_runtime_chore_probe(id integer);
grant insert on web_runtime_household_probe to authenticated;
grant insert on web_runtime_chore_probe to authenticated;
create trigger web_runtime_household_probe_guard
before insert on web_runtime_household_probe
for each row execute function
  app_private.enforce_app_runtime_policy('household');
create trigger web_runtime_chore_probe_guard
before insert on web_runtime_chore_probe
for each row execute function app_private.enforce_app_runtime_policy('chores');

set local role authenticated;
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select pg_catalog.set_config(
  'request.headers',
  '{"x-kinflow-client-version":"0.1.0-dev+1","x-kinflow-client-build":"1","x-kinflow-contract-version":"2026-07-25","x-kinflow-platform":"web","x-kinflow-environment":"dev"}',
  true
);
select pg_catalog.set_config('app.runtime_policy_checked', '', true);
select pg_catalog.set_config(
  'app.runtime_policy_feature_checked_household',
  '',
  true
);
select pg_catalog.set_config(
  'app.runtime_policy_feature_checked_chores',
  '',
  true
);
select lives_ok(
  $$ insert into web_runtime_household_probe(id) values (1) $$,
  'an enabled Web capability passes the server mutation gate'
);
select throws_ok(
  $$ insert into web_runtime_chore_probe(id) values (1) $$,
  'KFR06',
  'client feature disabled',
  'a disabled Web capability is blocked at the server mutation gate'
);
reset role;

select throws_ok(
  $$
    update app_private.app_runtime_policy_events
    set mutations_enabled = false
    where correlation_id = '70000000-0000-4000-8000-000000000001'
  $$,
  '42501',
  'app runtime policy events are immutable',
  'Web runtime policy audit cannot be rewritten'
);

select * from finish();
rollback;
