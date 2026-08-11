begin;
set constraints all deferred;

select no_plan();

select has_table(
  'app_private',
  'app_runtime_feature_policies',
  'private runtime feature policy table exists'
);
select has_table(
  'app_private',
  'app_runtime_feature_policy_events',
  'private immutable runtime feature policy audit exists'
);
select has_function(
  'public',
  'get_app_runtime_feature_policies',
  array['text', 'text']
);
select has_function(
  'public',
  'configure_app_runtime_feature_policy',
  array['text', 'text', 'text', 'boolean', 'bigint', 'uuid']
);
select is(
  (
    select procedure.provolatile::text
    from pg_catalog.pg_proc as procedure
    join pg_catalog.pg_namespace as namespace
      on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname = 'get_app_runtime_feature_policies'
  ),
  'v'::text,
  'feature policy read volatility matches its wall-clock evaluated_at field'
);

select results_eq(
  $$
    select environment, platform, feature, mutations_enabled, version
    from app_private.app_runtime_feature_policies
    where platform = 'android'
    order by environment, feature
  $$,
  $$
    values
      ('dev'::text, 'android'::text, 'billing'::text, true, 1::bigint),
      ('dev'::text, 'android'::text, 'calendar'::text, true, 1::bigint),
      ('dev'::text, 'android'::text, 'chores'::text, true, 1::bigint),
      ('dev'::text, 'android'::text, 'household'::text, true, 1::bigint),
      ('dev'::text, 'android'::text, 'notifications'::text, true, 1::bigint),
      ('dev'::text, 'android'::text, 'profile'::text, true, 1::bigint),
      ('prod'::text, 'android'::text, 'billing'::text, true, 1::bigint),
      ('prod'::text, 'android'::text, 'calendar'::text, true, 1::bigint),
      ('prod'::text, 'android'::text, 'chores'::text, true, 1::bigint),
      ('prod'::text, 'android'::text, 'household'::text, true, 1::bigint),
      ('prod'::text, 'android'::text, 'notifications'::text, true, 1::bigint),
      ('prod'::text, 'android'::text, 'profile'::text, true, 1::bigint)
  $$,
  'all six existing capabilities are explicitly compatibility-open per environment'
);

select ok(
  has_function_privilege(
    'anon',
    'public.get_app_runtime_feature_policies(text,text)',
    'execute'
  )
    and has_function_privilege(
      'authenticated',
      'public.get_app_runtime_feature_policies(text,text)',
      'execute'
    )
    and not has_function_privilege(
      'authenticated',
      'public.configure_app_runtime_feature_policy(text,text,text,boolean,bigint,uuid)',
      'execute'
    )
    and has_function_privilege(
      'service_role',
      'public.configure_app_runtime_feature_policy(text,text,text,boolean,bigint,uuid)',
      'execute'
    ),
  'feature policy public read and service mutation grants are exact'
);
select ok(
  not has_table_privilege(
    'anon',
    'app_private.app_runtime_feature_policies',
    'select'
  )
    and not has_table_privilege(
      'authenticated',
      'app_private.app_runtime_feature_policies',
      'select'
    )
    and not has_table_privilege(
      'service_role',
      'app_private.app_runtime_feature_policies',
      'select'
    )
    and not has_table_privilege(
      'service_role',
      'app_private.app_runtime_feature_policy_events',
      'select'
    ),
  'feature policy and audit have no direct client or service grants'
);

select ok(
  (
    select pg_catalog.count(*) = 30
    from pg_catalog.pg_trigger as trigger
    join pg_catalog.pg_class as relation
      on relation.oid = trigger.tgrelid
    join pg_catalog.pg_namespace as namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and trigger.tgname = 'app_runtime_policy_guard'
      and not trigger.tgisinternal
  )
    and not exists (
      select 1
      from (values
        ('billing_customers'::text, 'billing'::text),
        ('billing_household_assignments'::text, 'billing'::text),
        ('billing_transactions'::text, 'billing'::text),
        ('billing_webhook_receipts'::text, 'billing'::text),
        ('calendar_sync_watermarks'::text, 'calendar'::text),
        ('chore_assignment_events'::text, 'chores'::text),
        ('chore_completion_events'::text, 'chores'::text),
        ('chore_occurrences'::text, 'chores'::text),
        ('chore_reschedule_events'::text, 'chores'::text),
        ('chore_series'::text, 'chores'::text),
        ('chore_series_change_events'::text, 'chores'::text),
        ('chore_series_revisions'::text, 'chores'::text),
        ('event_occurrence_exceptions'::text, 'calendar'::text),
        ('event_occurrences'::text, 'calendar'::text),
        ('event_participants'::text, 'calendar'::text),
        ('event_revision_participants'::text, 'calendar'::text),
        ('event_series'::text, 'calendar'::text),
        ('event_series_change_events'::text, 'calendar'::text),
        ('event_series_revisions'::text, 'calendar'::text),
        ('household_entitlements'::text, 'billing'::text),
        ('household_invites'::text, 'household'::text),
        ('household_members'::text, 'household'::text),
        ('households'::text, 'household'::text),
        ('notification_endpoints'::text, 'notifications'::text),
        ('notification_inbox_items'::text, 'notifications'::text),
        ('notification_preferences'::text, 'notifications'::text),
        ('one_time_chore_change_events'::text, 'chores'::text),
        ('plan_catalog'::text, 'billing'::text),
        ('profiles'::text, 'profile'::text),
        ('user_active_households'::text, 'household'::text)
      ) as expected(table_name, feature)
      where not exists (
        select 1
        from pg_catalog.pg_trigger as trigger
        join pg_catalog.pg_class as relation
          on relation.oid = trigger.tgrelid
        join pg_catalog.pg_namespace as namespace
          on namespace.oid = relation.relnamespace
        where namespace.nspname = 'public'
          and relation.relname = expected.table_name
          and trigger.tgname = 'app_runtime_policy_guard'
          and not trigger.tgisinternal
          and pg_catalog.strpos(
            pg_catalog.pg_get_triggerdef(trigger.oid),
            pg_catalog.quote_literal(expected.feature)
          ) > 0
      )
    ),
  'all 30 protected product tables carry one exact capability argument'
);

set local role anon;
select results_eq(
  $$
    select environment, platform, feature, mutations_enabled, policy_version
    from public.get_app_runtime_feature_policies('dev', 'android')
    order by feature
  $$,
  $$
    values
      ('dev'::text, 'android'::text, 'billing'::text, true, 1::bigint),
      ('dev'::text, 'android'::text, 'calendar'::text, true, 1::bigint),
      ('dev'::text, 'android'::text, 'chores'::text, true, 1::bigint),
      ('dev'::text, 'android'::text, 'household'::text, true, 1::bigint),
      ('dev'::text, 'android'::text, 'notifications'::text, true, 1::bigint),
      ('dev'::text, 'android'::text, 'profile'::text, true, 1::bigint)
  $$,
  'anonymous startup reads exactly six sanitized capability rows'
);
select throws_ok(
  $$
    select * from public.get_app_runtime_feature_policies(null, 'android')
  $$,
  '22023',
  'invalid app runtime feature policy scope',
  'null feature policy scope is rejected'
);
reset role;

select throws_ok(
  $$
    select * from public.configure_app_runtime_feature_policy(
      'dev',
      'android',
      'unknown',
      false,
      1,
      '69000000-0000-4000-8000-000000000001'
    )
  $$,
  '22023',
  'invalid app runtime feature policy configuration',
  'operator cannot invent a capability'
);
select results_eq(
  $$
    select environment, platform, feature, mutations_enabled, policy_version
    from public.configure_app_runtime_feature_policy(
      'dev',
      'android',
      'household',
      false,
      1,
      '69000000-0000-4000-8000-000000000002'
    )
  $$,
  $$
    values ('dev'::text, 'android'::text, 'household'::text,
      false, 2::bigint)
  $$,
  'service operator disables one exact capability with expected version'
);
select results_eq(
  $$
    select environment, platform, feature, mutations_enabled, policy_version
    from public.configure_app_runtime_feature_policy(
      'dev',
      'android',
      'household',
      false,
      1,
      '69000000-0000-4000-8000-000000000002'
    )
  $$,
  $$
    values ('dev'::text, 'android'::text, 'household'::text,
      false, 2::bigint)
  $$,
  'exact feature correlation replay returns the original result'
);
select is(
  (
    select pg_catalog.count(*)
    from app_private.app_runtime_feature_policy_events
    where correlation_id =
      '69000000-0000-4000-8000-000000000002'
  ),
  1::bigint,
  'feature correlation replay does not duplicate audit'
);
select throws_ok(
  $$
    select * from public.configure_app_runtime_feature_policy(
      'dev',
      'android',
      'household',
      true,
      2,
      '69000000-0000-4000-8000-000000000002'
    )
  $$,
  'KFR05',
  'app runtime feature policy correlation reused',
  'mismatched feature correlation reuse is rejected'
);
select throws_ok(
  $$
    select * from public.configure_app_runtime_feature_policy(
      'dev',
      'android',
      'household',
      true,
      1,
      '69000000-0000-4000-8000-000000000003'
    )
  $$,
  'KFR04',
  'app runtime feature policy version conflict',
  'stale feature policy version is rejected'
);
select throws_ok(
  $$
    update app_private.app_runtime_feature_policy_events
    set mutations_enabled = true
    where correlation_id =
      '69000000-0000-4000-8000-000000000002'
  $$,
  '42501',
  'app runtime policy events are immutable',
  'feature policy audit cannot be rewritten'
);

create temporary table runtime_household_probe(id integer);
create temporary table runtime_chores_probe(id integer);
create temporary table runtime_calendar_probe(id integer);
create temporary table runtime_notifications_probe(id integer);
create temporary table runtime_profile_probe(id integer);
create temporary table runtime_billing_probe(id integer);
grant insert on runtime_household_probe to authenticated;
grant insert on runtime_chores_probe to authenticated;
grant insert on runtime_calendar_probe to authenticated;
grant insert on runtime_notifications_probe to authenticated;
grant insert on runtime_profile_probe to authenticated;
grant insert on runtime_billing_probe to authenticated;
create trigger runtime_household_probe_guard
before insert on runtime_household_probe
for each row execute function
  app_private.enforce_app_runtime_policy('household');
create trigger runtime_chores_probe_guard
before insert on runtime_chores_probe
for each row execute function app_private.enforce_app_runtime_policy('chores');
create trigger runtime_calendar_probe_guard
before insert on runtime_calendar_probe
for each row execute function app_private.enforce_app_runtime_policy('calendar');
create trigger runtime_notifications_probe_guard
before insert on runtime_notifications_probe
for each row execute function
  app_private.enforce_app_runtime_policy('notifications');
create trigger runtime_profile_probe_guard
before insert on runtime_profile_probe
for each row execute function app_private.enforce_app_runtime_policy('profile');
create trigger runtime_billing_probe_guard
before insert on runtime_billing_probe
for each row execute function app_private.enforce_app_runtime_policy('billing');

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
select pg_catalog.set_config(
  'app.runtime_policy_feature_checked_household',
  '',
  true
);
select lives_ok(
  $$ insert into runtime_chores_probe(id) values (1) $$,
  'an unrelated enabled capability remains writable'
);
select throws_ok(
  $$ insert into runtime_household_probe(id) values (1) $$,
  'KFR06',
  'client feature disabled',
  'one disabled capability does not inherit another feature cache result'
);
reset role;

update app_private.app_runtime_feature_policies
set mutations_enabled = false
where environment = 'dev'
  and platform = 'android';

set local role authenticated;
select pg_catalog.set_config('app.runtime_policy_checked', '', true);
select pg_catalog.set_config(
  'app.runtime_policy_feature_checked_household', '', true
);
select pg_catalog.set_config(
  'app.runtime_policy_feature_checked_chores', '', true
);
select pg_catalog.set_config(
  'app.runtime_policy_feature_checked_calendar', '', true
);
select pg_catalog.set_config(
  'app.runtime_policy_feature_checked_notifications', '', true
);
select pg_catalog.set_config(
  'app.runtime_policy_feature_checked_profile', '', true
);
select pg_catalog.set_config(
  'app.runtime_policy_feature_checked_billing', '', true
);
select throws_ok(
  $$ insert into runtime_household_probe(id) values (2) $$,
  'KFR06',
  'client feature disabled',
  'household mutation is feature-gated'
);
select throws_ok(
  $$ insert into runtime_chores_probe(id) values (2) $$,
  'KFR06',
  'client feature disabled',
  'chore mutation is feature-gated'
);
select throws_ok(
  $$ insert into runtime_calendar_probe(id) values (2) $$,
  'KFR06',
  'client feature disabled',
  'calendar mutation is feature-gated'
);
select throws_ok(
  $$ insert into runtime_notifications_probe(id) values (2) $$,
  'KFR06',
  'client feature disabled',
  'notification mutation is feature-gated'
);
select throws_ok(
  $$ insert into runtime_profile_probe(id) values (2) $$,
  'KFR06',
  'client feature disabled',
  'profile mutation is feature-gated'
);
select throws_ok(
  $$ insert into runtime_billing_probe(id) values (2) $$,
  'KFR06',
  'client feature disabled',
  'billing mutation is feature-gated'
);
reset role;

select pg_catalog.set_config('request.jwt.claim.sub', '', true);
select pg_catalog.set_config(
  'request.headers',
  '{"x-kinflow-forwarded-user-operation":"1","x-kinflow-client-version":"0.1.0-dev+1","x-kinflow-client-build":"1","x-kinflow-contract-version":"2026-07-25","x-kinflow-platform":"android","x-kinflow-environment":"dev"}',
  true
);
select pg_catalog.set_config('app.runtime_policy_checked', '', true);
select pg_catalog.set_config(
  'app.runtime_policy_feature_checked_profile', '', true
);
select throws_ok(
  $$ insert into runtime_profile_probe(id) values (3) $$,
  'KFR06',
  'client feature disabled',
  'Edge-forwarded user work cannot bypass a disabled capability'
);

select pg_catalog.set_config('request.headers', '{}', true);
select pg_catalog.set_config('app.runtime_policy_checked', '', true);
select lives_ok(
  $$ insert into runtime_profile_probe(id) values (4) $$,
  'markerless service and worker work remains available'
);

delete from app_private.app_runtime_feature_policies
where environment = 'dev'
  and platform = 'android'
  and feature = 'calendar';

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
select pg_catalog.set_config(
  'app.runtime_policy_feature_checked_calendar', '', true
);
select throws_ok(
  $$ insert into runtime_calendar_probe(id) values (5) $$,
  'KFR03',
  'app runtime policy unavailable',
  'missing feature policy fails closed'
);
select throws_ok(
  $$ select * from public.get_app_runtime_feature_policies('dev', 'android') $$,
  'KFR03',
  'app runtime policy unavailable',
  'partial public feature projection fails closed'
);
reset role;

select * from finish();
rollback;
