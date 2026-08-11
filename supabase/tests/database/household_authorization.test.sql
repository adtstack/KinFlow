begin;

select plan(62);

select is(
  (
    select count(*)
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'app_private'
      and pg_proc.proname in (
        'is_valid_iana_timezone',
        'current_user_member_id',
        'is_active_household_member',
        'has_household_role',
        'assert_household_owner_integrity'
      )
  ),
  5::bigint,
  'household authorization helper set is materialized'
);

select ok(
  (
    select count(*) = 2 and bool_and(pg_constraint.convalidated)
    from pg_constraint
    where pg_constraint.conname in (
      'profiles_timezone_iana_ck',
      'households_timezone_iana_ck'
    )
  ),
  'profile and household IANA timezone constraints are validated'
);

select ok(
  (
    select count(*) = 2
      and bool_and(pg_trigger.tgdeferrable)
      and bool_and(pg_trigger.tginitdeferred)
    from pg_trigger
    where pg_trigger.tgname in (
      'households_owner_integrity',
      'household_members_owner_integrity'
    )
  ),
  'owner integrity constraint triggers are deferred by default'
);

select results_eq(
  $$
    select enum_value::text
    from unnest(enum_range(null::public.household_role)) as enum_value
  $$,
  $$ values ('owner'::text), ('admin'::text), ('member'::text) $$,
  'Store MVP adult role enum remains exact'
);

select ok(
  to_regclass('public.managed_members') is null
    and to_regclass('public.member_guardians') is null
    and to_regclass('public.acting_contexts') is null,
  'P1 Managed Child tables remain absent'
);

select policies_are(
  'public',
  'user_active_households',
  array['active_household_select_self'],
  'active household policies remain exact'
);

select ok(
  not has_table_privilege('authenticated', 'public.households', 'insert')
    and not has_table_privilege(
      'authenticated',
      'public.households',
      'update'
    )
    and not has_table_privilege(
      'authenticated',
      'public.households',
      'delete'
    )
    and not has_table_privilege(
      'authenticated',
      'public.household_members',
      'insert'
    )
    and not has_table_privilege(
      'authenticated',
      'public.household_members',
      'update'
    )
    and not has_table_privilege(
      'authenticated',
      'public.household_members',
      'delete'
    ),
  'direct household and member mutation stays denied'
);

select ok(
  has_function_privilege(
    'authenticated',
    'app_private.current_user_member_id(uuid)',
    'execute'
  )
    and has_function_privilege(
      'authenticated',
      'app_private.is_active_household_member(uuid)',
      'execute'
    )
    and has_function_privilege(
      'authenticated',
      'app_private.has_household_role(uuid,public.household_role[])',
      'execute'
    )
    and not has_function_privilege(
      'authenticated',
      'app_private.assert_household_owner_integrity(uuid)',
      'execute'
    )
    and not has_function_privilege(
      'authenticated',
      'app_private.enforce_household_owner_integrity()',
      'execute'
    ),
  'authenticated role cannot execute Owner integrity functions directly'
);

select ok(
  not has_function_privilege(
    'anon',
    'app_private.current_user_member_id(uuid)',
    'execute'
  )
    and not has_function_privilege(
      'anon',
      'app_private.is_active_household_member(uuid)',
      'execute'
    )
    and not has_function_privilege(
      'anon',
      'app_private.has_household_role(uuid,public.household_role[])',
      'execute'
    ),
  'anonymous role cannot execute household authorization helpers'
);

select ok(
  app_private.is_valid_iana_timezone('UTC'),
  'UTC is an approved timezone'
);
select ok(
  app_private.is_valid_iana_timezone('Asia/Seoul'),
  'Asia/Seoul is an approved IANA timezone'
);
select ok(
  app_private.is_valid_iana_timezone('America/New_York'),
  'DST-aware IANA timezone is approved'
);
select ok(
  not app_private.is_valid_iana_timezone('Not/A_Real_Zone'),
  'unknown timezone is rejected'
);
select ok(
  not app_private.is_valid_iana_timezone('posix/Asia/Seoul'),
  'posix compatibility timezone is rejected'
);
select ok(
  not app_private.is_valid_iana_timezone('right/Asia/Seoul'),
  'right compatibility timezone is rejected'
);

select throws_ok(
  $$
    update public.profiles
    set timezone = 'Not/A_Real_Zone'
    where auth_user_id = '00000000-0000-4000-8000-000000000101'
  $$,
  '23514',
  'new row for relation "profiles" violates check constraint "profiles_timezone_iana_ck"',
  'profile cannot persist an invalid timezone'
);

select throws_ok(
  $$
    update public.households
    set timezone = 'Not/A_Real_Zone'
    where id = '20000000-0000-4000-8000-000000000101'
  $$,
  '23514',
  'new row for relation "households" violates check constraint "households_timezone_iana_ck"',
  'household cannot persist an invalid timezone'
);

select lives_ok(
  $$
    update public.profiles
    set timezone = 'America/New_York'
    where auth_user_id = '00000000-0000-4000-8000-000000000101'
  $$,
  'profile accepts a valid DST-aware timezone'
);

select is(
  (
    select timezone
    from public.profiles
    where auth_user_id = '00000000-0000-4000-8000-000000000101'
  ),
  'America/New_York',
  'valid profile timezone is persisted exactly'
);

update public.profiles
set timezone = 'Asia/Seoul'
where auth_user_id = '00000000-0000-4000-8000-000000000101';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);

select is(
  app_private.current_user_member_id(
    '20000000-0000-4000-8000-000000000101'
  ),
  '30000000-0000-4000-8000-000000000101'::uuid,
  'Owner resolves its exact current member ID'
);
select ok(
  app_private.is_active_household_member(
    '20000000-0000-4000-8000-000000000101'
  ),
  'Owner is an active member of its household'
);
select ok(
  not app_private.is_active_household_member(
    '20000000-0000-4000-8000-000000000201'
  ),
  'Owner is not active in another household'
);
select ok(
  app_private.has_household_role(
    '20000000-0000-4000-8000-000000000101',
    array['owner']::public.household_role[]
  ),
  'Owner helper recognizes Owner'
);
select ok(
  not app_private.has_household_role(
    '20000000-0000-4000-8000-000000000101',
    array['admin']::public.household_role[]
  ),
  'Owner is not mislabeled as Admin'
);
select ok(
  not app_private.has_household_role(
    '20000000-0000-4000-8000-000000000101',
    array['member']::public.household_role[]
  ),
  'Owner is not mislabeled as Member'
);
select is(
  (select count(*) from public.households),
  1::bigint,
  'Owner reads only its household'
);
select is(
  (select count(*) from public.household_members),
  2::bigint,
  'Owner reads both same-household adults'
);
select is(
  (select count(*) from public.user_active_households),
  1::bigint,
  'Owner reads only its active household selection'
);
select is(
  (select count(*) from public.profiles),
  1::bigint,
  'Owner reads only its own profile'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);

select is(
  app_private.current_user_member_id(
    '20000000-0000-4000-8000-000000000101'
  ),
  '30000000-0000-4000-8000-000000000102'::uuid,
  'Member resolves its exact current member ID'
);
select ok(
  app_private.is_active_household_member(
    '20000000-0000-4000-8000-000000000101'
  ),
  'Member is active in its household'
);
select ok(
  app_private.has_household_role(
    '20000000-0000-4000-8000-000000000101',
    array['member']::public.household_role[]
  ),
  'Member helper recognizes Member'
);
select ok(
  not app_private.has_household_role(
    '20000000-0000-4000-8000-000000000101',
    array['owner', 'admin']::public.household_role[]
  ),
  'Member has no elevated household role'
);
select is(
  (select count(*) from public.households),
  1::bigint,
  'Member reads its household'
);
select is(
  (select count(*) from public.household_members),
  2::bigint,
  'Member reads same-household adults'
);
select is(
  (select count(*) from public.user_active_households),
  1::bigint,
  'Member reads only its active household selection'
);

reset role;
update public.household_members
set role = 'admin'
where id = '30000000-0000-4000-8000-000000000102';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);

select ok(
  app_private.has_household_role(
    '20000000-0000-4000-8000-000000000101',
    array['admin']::public.household_role[]
  ),
  'Admin helper recognizes Admin'
);
select ok(
  not app_private.has_household_role(
    '20000000-0000-4000-8000-000000000101',
    array['member']::public.household_role[]
  ),
  'Admin is not mislabeled as Member'
);
select is(
  (select count(*) from public.households),
  1::bigint,
  'Admin reads its household'
);
select is(
  (select count(*) from public.household_members),
  2::bigint,
  'Admin reads same-household adults'
);

reset role;
update public.household_members
set role = 'member'
where id = '30000000-0000-4000-8000-000000000102';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);

select is(
  app_private.current_user_member_id(
    '20000000-0000-4000-8000-000000000101'
  ),
  null::uuid,
  'other-household actor has no member ID in the primary household'
);
select ok(
  not app_private.is_active_household_member(
    '20000000-0000-4000-8000-000000000101'
  ),
  'other-household actor is not an active primary member'
);
select ok(
  not app_private.has_household_role(
    '20000000-0000-4000-8000-000000000101',
    array['owner', 'admin', 'member']::public.household_role[]
  ),
  'other-household actor has no role in the primary household'
);
select is(
  (
    select count(*)
    from public.households
    where id = '20000000-0000-4000-8000-000000000101'
  ),
  0::bigint,
  'other-household actor cannot read the primary household'
);
select is(
  (select count(*) from public.households),
  1::bigint,
  'other-household actor reads only its own household'
);
select throws_ok(
  $$
    select * from public.switch_active_household(
      '20000000-0000-4000-8000-000000000101',
      1
    )
  $$,
  'KFH06',
  'household selection target unavailable',
  'other-household actor cannot inject a foreign active member'
);

reset role;
set constraints households_owner_integrity,
  household_members_owner_integrity immediate;

select throws_ok(
  $$
    update public.household_members
    set role = 'admin'
    where id = '30000000-0000-4000-8000-000000000101'
  $$,
  '23514',
  'household must have exactly one active owner',
  'the only active Owner cannot be demoted'
);
select throws_ok(
  $$
    update public.household_members
    set removed_at = now()
    where id = '30000000-0000-4000-8000-000000000101'
  $$,
  '23514',
  'household must have exactly one active owner',
  'the only active Owner cannot be removed'
);
select throws_ok(
  $$
    update public.households
    set owner_member_id = '30000000-0000-4000-8000-000000000102'
    where id = '20000000-0000-4000-8000-000000000101'
  $$,
  '23514',
  'household owner pointer must reference its active owner',
  'Owner pointer cannot target a regular same-household member'
);
select throws_ok(
  $$
    update public.households
    set owner_member_id = '30000000-0000-4000-8000-000000000201'
    where id = '20000000-0000-4000-8000-000000000101'
  $$,
  '23514',
  'household owner pointer must reference its active owner',
  'Owner pointer cannot target another household'
);
select throws_ok(
  $$
    update public.household_members
    set role = 'owner'
    where id = '30000000-0000-4000-8000-000000000102'
  $$,
  '23505',
  'duplicate key value violates unique constraint "household_members_single_owner_uq"',
  'a second active Owner cannot be created'
);

set constraints households_owner_integrity,
  household_members_owner_integrity deferred;
update public.household_members
set role = 'admin'
where id = '30000000-0000-4000-8000-000000000101';
update public.household_members
set role = 'owner'
where id = '30000000-0000-4000-8000-000000000102';
update public.households
set owner_member_id = '30000000-0000-4000-8000-000000000102'
where id = '20000000-0000-4000-8000-000000000101';
set constraints households_owner_integrity,
  household_members_owner_integrity immediate;

select is(
  (
    select owner_member_id
    from public.households
    where id = '20000000-0000-4000-8000-000000000101'
  ),
  '30000000-0000-4000-8000-000000000102'::uuid,
  'atomic Owner transfer updates the pointer'
);
select is(
  (
    select count(*)
    from public.household_members
    where household_id = '20000000-0000-4000-8000-000000000101'
      and role = 'owner'
      and removed_at is null
  ),
  1::bigint,
  'atomic Owner transfer preserves exactly one active Owner'
);

set constraints households_owner_integrity,
  household_members_owner_integrity deferred;
update public.household_members
set role = 'member'
where id = '30000000-0000-4000-8000-000000000102';
update public.household_members
set role = 'owner'
where id = '30000000-0000-4000-8000-000000000101';
update public.households
set owner_member_id = '30000000-0000-4000-8000-000000000101'
where id = '20000000-0000-4000-8000-000000000101';
set constraints households_owner_integrity,
  household_members_owner_integrity immediate;

select is(
  (
    select owner_member_id
    from public.households
    where id = '20000000-0000-4000-8000-000000000101'
  ),
  '30000000-0000-4000-8000-000000000101'::uuid,
  'Owner transfer fixture is restored'
);

update public.household_members
set removed_at = now()
where id = '30000000-0000-4000-8000-000000000102';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);

select is(
  app_private.current_user_member_id(
    '20000000-0000-4000-8000-000000000101'
  ),
  null::uuid,
  'removed member has no current member ID'
);
select ok(
  not app_private.has_household_role(
    '20000000-0000-4000-8000-000000000101',
    array['owner', 'admin', 'member']::public.household_role[]
  ),
  'removed member has no household role'
);
select is(
  (select count(*) from public.households),
  0::bigint,
  'removed member cannot read its former household'
);
select is(
  (select count(*) from public.household_members),
  0::bigint,
  'removed member cannot read former household members'
);
select is(
  (select count(*) from public.user_active_households),
  0::bigint,
  'removed member cannot read a stale active-household row'
);
select is(
  (select count(*) from public.profiles),
  1::bigint,
  'removed member retains access only to its own profile'
);
select throws_ok(
  $$
    select * from public.switch_active_household(
      '20000000-0000-4000-8000-000000000101',
      1
    )
  $$,
  'KFH06',
  'household selection target unavailable',
  'removed member cannot mutate a stale active-household row'
);

reset role;
select ok(
  not has_table_privilege('anon', 'public.profiles', 'select')
    and not has_table_privilege('anon', 'public.households', 'select')
    and not has_table_privilege(
      'anon',
      'public.household_members',
      'select'
    )
    and not has_table_privilege(
      'anon',
      'public.user_active_households',
      'select'
    ),
  'anonymous actor has no household table read privileges'
);

select * from finish();
rollback;
