begin;

select plan(37);

select has_table('public', 'profiles', 'profiles table exists');
select has_table('public', 'households', 'households table exists');
select has_table(
  'public',
  'household_members',
  'household_members table exists'
);
select has_table(
  'public',
  'user_active_households',
  'user_active_households table exists'
);
select ok(
  (
    select cardinality(pg_constraint.conkey) = 3
      and cardinality(pg_constraint.confkey) = 3
    from pg_constraint
    where pg_constraint.conname = 'active_household_member_fk'
  ),
  'active household foreign key binds household, member, and auth user'
);

select results_eq(
  $$
    select enum_value::text
    from unnest(enum_range(null::public.household_role)) as enum_value
  $$,
  $$ values ('owner'::text), ('admin'::text), ('member'::text) $$,
  'adult-only role enum is exact'
);

select ok(
  (
    select count(*) = 4
      and bool_and(pg_class.relrowsecurity)
      and bool_and(pg_class.relforcerowsecurity)
    from pg_class
    join pg_namespace on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname in (
        'profiles',
        'households',
        'household_members',
        'user_active_households'
      )
  ),
  'all baseline tables enable and force RLS'
);

select policies_are(
  'public',
  'profiles',
  array['profiles_select_self', 'profiles_update_self'],
  'profiles policies are exact'
);
select policies_are(
  'public',
  'households',
  array['households_select_member'],
  'households policies are exact'
);
select policies_are(
  'public',
  'household_members',
  array['household_members_select_member'],
  'household member policies are exact'
);
select policies_are(
  'public',
  'user_active_households',
  array['active_household_select_self', 'active_household_update_self'],
  'active household policies are exact'
);

select is(
  (
    select count(*)
    from public.household_members
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  2::bigint,
  'primary local household has two adults'
);
select is(
  (
    select count(*)
    from public.household_members
    where role::text not in ('owner', 'admin', 'member')
  ),
  0::bigint,
  'seed contains no deferred member role'
);

select ok(
  not has_table_privilege('anon', 'public.profiles', 'select'),
  'anon has no profile select privilege'
);
select ok(
  not has_table_privilege('anon', 'public.households', 'select'),
  'anon has no household select privilege'
);
select ok(
  not has_table_privilege('anon', 'public.household_members', 'select'),
  'anon has no household member select privilege'
);
select ok(
  not has_table_privilege('anon', 'public.user_active_households', 'select'),
  'anon has no active household select privilege'
);
select ok(
  not has_table_privilege('authenticated', 'public.households', 'insert'),
  'authenticated cannot insert households directly'
);
select ok(
  not has_table_privilege('authenticated', 'public.households', 'update'),
  'authenticated cannot update households directly'
);
select ok(
  not has_table_privilege('authenticated', 'public.households', 'delete'),
  'authenticated cannot delete households directly'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.household_members',
    'insert'
  ),
  'authenticated cannot insert members directly'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.household_members',
    'update'
  ),
  'authenticated cannot update members directly'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.household_members',
    'delete'
  ),
  'authenticated cannot delete members directly'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.user_active_households',
    'insert'
  ),
  'authenticated cannot insert active household rows directly'
);
select ok(
  not has_column_privilege(
    'authenticated',
    'public.profiles',
    'auth_user_id',
    'update'
  ),
  'profile identity cannot be updated directly'
);
select ok(
  has_column_privilege(
    'authenticated',
    'public.profiles',
    'display_name',
    'update'
  ),
  'profile display name has explicit update privilege'
);
select ok(
  has_column_privilege(
    'authenticated',
    'public.user_active_households',
    'household_id',
    'update'
  ),
  'active household selection has explicit update privilege'
);
select ok(
  not has_column_privilege(
    'authenticated',
    'public.user_active_households',
    'auth_user_id',
    'update'
  ),
  'active household identity cannot be updated directly'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);

select is(
  (select count(*) from public.profiles),
  1::bigint,
  'user sees only own profile'
);
select is(
  (select count(*) from public.households),
  1::bigint,
  'user sees only active same-household rows'
);
select is(
  (select count(*) from public.household_members),
  2::bigint,
  'user sees both adults in own household'
);
select is(
  (
    select count(*)
    from public.households
    where id = '20000000-0000-4000-8000-000000000201'
  ),
  0::bigint,
  'cross-household row is hidden'
);
select is(
  (select count(*) from public.user_active_households),
  1::bigint,
  'user sees only own active household selection'
);
select throws_ok(
  $$
    update public.user_active_households
    set household_id = '20000000-0000-4000-8000-000000000201',
        member_id = '30000000-0000-4000-8000-000000000201'
    where auth_user_id = '00000000-0000-4000-8000-000000000101'
  $$,
  '42501',
  'new row violates row-level security policy for table "user_active_households"',
  'user cannot select another household member as active identity'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);

select results_eq(
  'select id from public.households order by id',
  $$ values ('20000000-0000-4000-8000-000000000201'::uuid) $$,
  'isolation user sees only isolation household'
);

reset role;
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
  (select count(*) from public.households),
  0::bigint,
  'removed member loses household read access'
);

reset role;
select is(
  (
    select version
    from public.household_members
    where id = '30000000-0000-4000-8000-000000000102'
  ),
  2::bigint,
  'member update trigger increments optimistic version'
);

select * from finish();
rollback;
