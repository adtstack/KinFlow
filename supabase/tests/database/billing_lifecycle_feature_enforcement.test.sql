begin;
set constraints all deferred;

select no_plan();

select has_column(
  'app_private',
  'billing_runtime_config',
  'feature_enforcement_enabled',
  'runtime config has an explicit feature-enforcement switch'
);
select has_function(
  'public',
  'configure_billing_feature_enforcement',
  array['boolean', 'bigint', 'uuid']
);
select has_function(
  'public',
  'get_household_feature_gate',
  array['uuid', 'text', 'integer']
);
select has_function(
  'app_private',
  'enforce_household_feature_capacity',
  array['uuid', 'text', 'integer']
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_trigger as trigger
    where trigger.tgrelid = 'public.household_members'::regclass
      and trigger.tgname = 'household_members_enforce_feature_capacity'
      and not trigger.tgisinternal
  ),
  'household member capacity trigger exists'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_trigger as trigger
    where trigger.tgrelid = 'public.chore_series_revisions'::regclass
      and trigger.tgname = 'chore_revisions_enforce_feature_capacity'
      and not trigger.tgisinternal
  ),
  'recurring chore capacity trigger exists'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_trigger as trigger
    where trigger.tgrelid = 'public.event_series_revisions'::regclass
      and trigger.tgname = 'event_revisions_enforce_feature_capacity'
      and not trigger.tgisinternal
  ),
  'recurring event capacity trigger exists'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.configure_billing_feature_enforcement(boolean,bigint,uuid)',
    'execute'
  )
    and has_function_privilege(
      'authenticated',
      'public.get_household_feature_gate(uuid,text,integer)',
      'execute'
    )
    and not has_function_privilege(
      'authenticated',
      'public.configure_billing_feature_enforcement(boolean,bigint,uuid)',
      'execute'
    )
    and not has_function_privilege(
      'service_role',
      'app_private.enforce_household_feature_capacity(uuid,text,integer)',
      'execute'
    ),
  'configuration read and private enforcement grants are exact'
);

select is(
  (
    select feature_enforcement_enabled
    from app_private.billing_runtime_config
    where singleton
  ),
  false,
  'feature enforcement ships disabled while D-027 is open'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select results_eq(
  $$
    select decision, feature_key, requested_delta, current_usage,
      limit_value, remaining_after_delta, plan_code,
      entitlement_status::text, enforcement_enabled, limits_finalized
    from public.get_household_feature_gate(
      '20000000-0000-4000-8000-000000000101',
      'activeSeries',
      1
    )
  $$,
  $$
    values (
      'policy_unavailable'::text,
      'activeSeries'::text,
      1,
      0::bigint,
      null::bigint,
      null::bigint,
      'free'::text,
      'none'::text,
      false,
      false
    )
  $$,
  'unfinalized client gate fails closed without a guessed number'
);
select throws_ok(
  $$
    select * from public.get_household_feature_gate(
      '20000000-0000-4000-8000-000000000101',
      'unknownFeature',
      1
    )
  $$,
  '22023',
  'invalid household feature-gate request',
  'unknown feature keys are rejected'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$
    select * from public.get_household_feature_gate(
      '20000000-0000-4000-8000-000000000101',
      'members',
      1
    )
  $$,
  '42501',
  'active household membership required',
  'cross-household feature usage and policy are not projected'
);
reset role;

select throws_ok(
  $$
    select * from public.configure_billing_feature_enforcement(
      true,
      1,
      '67000000-0000-4000-8000-000000000001'
    )
  $$,
  'KFB40',
  'billing feature policies are not activation-ready',
  'unfinalized policies cannot activate enforcement'
);

select lives_ok(
  $$
    select * from public.configure_plan_feature_limits(
      'free',
      '{"members":2,"activeSeries":1}'::jsonb,
      true,
      1,
      '67000000-0000-4000-8000-000000000002'
    )
  $$,
  'synthetic Free policy can be finalized without changing product docs'
);
select lives_ok(
  $$
    select * from public.configure_plan_feature_limits(
      'plus',
      '{"members":4,"activeSeries":3}'::jsonb,
      true,
      1,
      '67000000-0000-4000-8000-000000000003'
    )
  $$,
  'synthetic Plus policy can be finalized for local enforcement tests'
);
select results_eq(
  $$
    select feature_enforcement_enabled, version
    from public.configure_billing_feature_enforcement(
      true,
      1,
      '67000000-0000-4000-8000-000000000004'
    )
  $$,
  $$ values (true, 2::bigint) $$,
  'versioned service command activates complete policies'
);
select results_eq(
  $$
    select policy_kind, policy_key, previous_version, next_version,
      correlation_id
    from app_private.billing_policy_events
    where policy_key = 'feature_enforcement'
  $$,
  $$
    values (
      'runtime'::text,
      'feature_enforcement'::text,
      1::bigint,
      2::bigint,
      '67000000-0000-4000-8000-000000000004'::uuid
    )
  $$,
  'activation emits an immutable version/correlation audit without content'
);
select throws_ok(
  $$
    select * from public.configure_billing_feature_enforcement(
      false,
      1,
      '67000000-0000-4000-8000-000000000005'
    )
  $$,
  'KFB30',
  'billing runtime version conflict',
  'stale enforcement toggles are rejected'
);
select throws_ok(
  $$
    select * from public.configure_plan_feature_limits(
      'free',
      '{}'::jsonb,
      false,
      2,
      '67000000-0000-4000-8000-000000000006'
    )
  $$,
  'KFB41',
  'enabled billing feature policy cannot be made incomplete',
  'an enabled plan cannot be silently unfinalized'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select results_eq(
  $$
    select decision, current_usage, limit_value, remaining_after_delta,
      plan_code, entitlement_status::text, enforcement_enabled,
      limits_finalized, entitlement_version, policy_version, runtime_version
    from public.get_household_feature_gate(
      '20000000-0000-4000-8000-000000000101',
      'members',
      1
    )
  $$,
  $$
    values (
      'limit_reached'::text,
      2::bigint,
      2::bigint,
      0::bigint,
      'free'::text,
      'none'::text,
      true,
      true,
      2::bigint,
      2::bigint,
      2::bigint
    )
  $$,
  'member gate uses authoritative usage and the effective Free lifecycle'
);
select results_eq(
  $$
    select decision, current_usage, limit_value, remaining_after_delta
    from public.get_household_feature_gate(
      '20000000-0000-4000-8000-000000000101',
      'activeSeries',
      1
    )
  $$,
  $$ values ('allowed'::text, 0::bigint, 1::bigint, 0::bigint) $$,
  'last recurring-series slot is projected as allowed with zero remaining'
);
reset role;

insert into auth.users(
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
) values
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-000000000301',
    'authenticated',
    'authenticated',
    'feature-owner@local.kinflow.invalid',
    pg_catalog.now(),
    '{}'::jsonb,
    '{}'::jsonb,
    pg_catalog.now(),
    pg_catalog.now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-000000000302',
    'authenticated',
    'authenticated',
    'feature-member-a@local.kinflow.invalid',
    pg_catalog.now(),
    '{}'::jsonb,
    '{}'::jsonb,
    pg_catalog.now(),
    pg_catalog.now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-000000000303',
    'authenticated',
    'authenticated',
    'feature-member-b@local.kinflow.invalid',
    pg_catalog.now(),
    '{}'::jsonb,
    '{}'::jsonb,
    pg_catalog.now(),
    pg_catalog.now()
  );

insert into public.households(
  id,
  name,
  timezone,
  owner_member_id,
  created_by_user_id
) values (
  '20000000-0000-4000-8000-000000000301',
  'Feature Limit Household',
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
  'Feature Owner',
  'owner',
  '00000000-0000-4000-8000-000000000301'
);
select lives_ok(
  $$
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
      '00000000-0000-4000-8000-000000000302',
      'Feature Member A',
      'member',
      '00000000-0000-4000-8000-000000000301'
    )
  $$,
  'second active member consumes the final Free member slot'
);
select throws_ok(
  $$
    insert into public.household_members(
      id,
      household_id,
      auth_user_id,
      display_name,
      role,
      created_by_user_id
    ) values (
      '30000000-0000-4000-8000-000000000303',
      '20000000-0000-4000-8000-000000000301',
      '00000000-0000-4000-8000-000000000303',
      'Feature Member B',
      'member',
      '00000000-0000-4000-8000-000000000301'
    )
  $$,
  'KFB12',
  'household feature limit reached',
  'actual member insert cannot exceed the activated server limit'
);
select lives_ok(
  $$
    update public.household_members
    set removed_at = pg_catalog.statement_timestamp()
    where id = '30000000-0000-4000-8000-000000000302'
  $$,
  'downgrade gate never blocks member removal'
);
select lives_ok(
  $$
    insert into public.household_members(
      id,
      household_id,
      auth_user_id,
      display_name,
      role,
      created_by_user_id
    ) values (
      '30000000-0000-4000-8000-000000000303',
      '20000000-0000-4000-8000-000000000301',
      '00000000-0000-4000-8000-000000000303',
      'Feature Member B',
      'member',
      '00000000-0000-4000-8000-000000000301'
    )
  $$,
  'a removed member frees one authoritative capacity slot'
);
select throws_ok(
  $$
    update public.household_members
    set removed_at = null
    where id = '30000000-0000-4000-8000-000000000302'
  $$,
  'KFB12',
  'household feature limit reached',
  'reactivating a removed member is enforced like a new member'
);

create temporary table feature_created_series(
  kind text primary key,
  series_id uuid not null
) on commit drop;
grant select, insert on table feature_created_series to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '68000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'One-time limit-neutral chore',
      '',
      '30000000-0000-4000-8000-000000000101',
      '2026-08-08',
      null
    )
  $$,
  'one-time chore creation is not a recurring-series expansion'
);
select lives_ok(
  $$
    select * from public.create_one_time_event(
      '68000000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      'One-time limit-neutral event',
      '',
      true,
      '2026-08-08',
      null,
      null,
      '2026-08-09',
      null,
      null,
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'one-time calendar event remains available under the recurring limit'
);
select is(
  (
    select current_usage
    from public.get_household_feature_gate(
      '20000000-0000-4000-8000-000000000101',
      'activeSeries',
      1
    )
  ),
  0::bigint,
  'one-time chore and event rows are excluded from recurring usage'
);
insert into feature_created_series(kind, series_id)
select 'chore', created.series_id
from public.create_repeating_chore(
  '68000000-0000-4000-8000-000000000003',
  '20000000-0000-4000-8000-000000000101',
  'Recurring limit fixture',
  '',
  '30000000-0000-4000-8000-000000000101',
  '2026-08-08',
  null,
  '{"frequency":"daily","interval":1,"end":{"type":"count","count":2}}'
) as created;
select is(
  (
    select current_usage
    from public.get_household_feature_gate(
      '20000000-0000-4000-8000-000000000101',
      'activeSeries',
      1
    )
  ),
  1::bigint,
  'first recurring chore consumes the combined active-series slot'
);
select throws_ok(
  $$
    select * from public.create_recurring_calendar_event(
      '68000000-0000-4000-8000-000000000004',
      '20000000-0000-4000-8000-000000000101',
      'Blocked recurring event',
      '',
      true,
      '2026-08-08',
      null,
      null,
      '2026-08-09',
      null,
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":2}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFB12',
  'household feature limit reached',
  'actual recurring calendar mutation cannot bypass the server limit'
);
reset role;

select results_eq(
  $$
    select feature_enforcement_enabled, version
    from public.configure_billing_feature_enforcement(
      false,
      2,
      '67000000-0000-4000-8000-000000000007'
    )
  $$,
  $$ values (false, 3::bigint) $$,
  'emergency disable is versioned and does not rewrite family data'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
insert into feature_created_series(kind, series_id)
select 'event', created.series_id
from public.create_recurring_calendar_event(
  '68000000-0000-4000-8000-000000000005',
  '20000000-0000-4000-8000-000000000101',
  'Preserved recurring event',
  '',
  true,
  '2026-08-08',
  null,
  null,
  '2026-08-09',
  null,
  null,
  '{"frequency":"daily","interval":1,"end":{"type":"count","count":2}}',
  array['30000000-0000-4000-8000-000000000101'::uuid]
) as created;
reset role;

select results_eq(
  $$
    select feature_enforcement_enabled, version
    from public.configure_billing_feature_enforcement(
      true,
      3,
      '67000000-0000-4000-8000-000000000008'
    )
  $$,
  $$ values (true, 4::bigint) $$,
  'complete policies can be reactivated after an emergency disable'
);
select is(
  app_private.current_household_feature_usage(
    '20000000-0000-4000-8000-000000000101',
    'activeSeries'
  ),
  2::bigint,
  'reactivation preserves an existing over-limit household without deletion'
);
select lives_ok(
  $$
    update public.event_series
    set title = 'Updated preserved recurring event'
    where id = (
      select series_id from feature_created_series where kind = 'event'
    )
  $$,
  'existing over-limit family data remains editable'
);
select lives_ok(
  $$
    update public.event_series
    set deleted_at = pg_catalog.statement_timestamp()
    where id = (
      select series_id from feature_created_series where kind = 'event'
    )
  $$,
  'existing recurring series can be cancelled to reduce usage'
);
select is(
  (
    select pg_catalog.count(*)
    from public.event_series
    where id = (
      select series_id from feature_created_series where kind = 'event'
    )
  ),
  1::bigint,
  'downgrade/cancel preserves the event series row'
);
select is(
  (
    select pg_catalog.count(*)
    from public.event_series_revisions
    where series_id = (
      select series_id from feature_created_series where kind = 'event'
    )
  ),
  1::bigint,
  'downgrade/cancel preserves immutable event content and history'
);
select throws_ok(
  $$
    update public.event_series
    set deleted_at = null
    where id = (
      select series_id from feature_created_series where kind = 'event'
    )
  $$,
  'KFB12',
  'household feature limit reached',
  'reactivating recurring data is enforced as new capacity expansion'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select results_eq(
  $$
    select decision, current_usage, limit_value, remaining_after_delta,
      runtime_version
    from public.get_household_feature_gate(
      '20000000-0000-4000-8000-000000000101',
      'activeSeries',
      1
    )
  $$,
  $$ values ('limit_reached'::text, 1::bigint, 1::bigint, 0::bigint, 4::bigint) $$,
  'client projection and mutation trigger converge after over-limit recovery'
);
reset role;

select is(
  (
    select pg_catalog.count(*)
    from app_private.billing_policy_events
    where policy_key = 'feature_enforcement'
  ),
  3::bigint,
  'activation disable and reactivation each append one immutable audit row'
);
select throws_ok(
  $$
    delete from app_private.billing_policy_events
    where policy_key = 'feature_enforcement'
  $$,
  '42501',
  'billing audit records are immutable',
  'feature-enforcement policy history cannot be deleted'
);

select * from finish();
rollback;
