begin;

select plan(37);

select has_function(
  'public',
  'create_first_household',
  array['uuid', 'text', 'text', 'text', 'text'],
  'first household command exists with an authority-free input contract'
);

select has_table(
  'app_private',
  'first_household_requests',
  'private first household idempotency records exist'
);

select ok(
  (
    select pg_proc.prosecdef
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'create_first_household'
  ),
  'first household command is security-definer with an empty search path'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.create_first_household(uuid,text,text,text,text)',
    'execute'
  ),
  'authenticated role can execute the first household command'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.create_first_household(uuid,text,text,text,text)',
    'execute'
  ),
  'anonymous role cannot execute the first household command'
);

select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.first_household_requests',
    'select'
  )
    and not has_table_privilege(
      'authenticated',
      'app_private.first_household_requests',
      'insert'
    ),
  'client roles cannot inspect or write idempotency records'
);

select throws_ok(
  $$
    select *
    from public.create_first_household(
      '40000000-0000-4000-8000-000000000301',
      'Unauthenticated household',
      'Unauthenticated adult',
      'en',
      'UTC'
    )
  $$,
  'KFH01',
  'authentication required',
  'command derives identity from an authenticated JWT'
);

insert into auth.users (
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
)
values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-4000-8000-000000000301',
  'authenticated',
  'authenticated',
  'onboarding-adult@local.kinflow.invalid',
  now(),
  '{"provider":"local_fixture","providers":["local_fixture"]}'::jsonb,
  '{}'::jsonb,
  now(),
  now()
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000301',
  true
);

select throws_ok(
  $$
    select *
    from public.create_first_household(
      null,
      'New household',
      'New adult',
      'en',
      'UTC'
    )
  $$,
  'KFH02',
  'invalid first household input',
  'null idempotency key is rejected'
);

select throws_ok(
  $$
    select *
    from public.create_first_household(
      '40000000-0000-4000-8000-000000000301',
      '   ',
      'New adult',
      'en',
      'UTC'
    )
  $$,
  'KFH02',
  'invalid first household input',
  'blank household name is rejected'
);

select throws_ok(
  $$
    select *
    from public.create_first_household(
      '40000000-0000-4000-8000-000000000301',
      E'Line one\nLine two',
      'New adult',
      'en',
      'UTC'
    )
  $$,
  'KFH02',
  'invalid first household input',
  'control characters in household name are rejected'
);

select throws_ok(
  $$
    select *
    from public.create_first_household(
      '40000000-0000-4000-8000-000000000301',
      'New household',
      '   ',
      'en',
      'UTC'
    )
  $$,
  'KFH02',
  'invalid first household input',
  'blank Owner display name is rejected'
);

select throws_ok(
  $$
    select *
    from public.create_first_household(
      '40000000-0000-4000-8000-000000000301',
      'New household',
      'New adult',
      'fr',
      'UTC'
    )
  $$,
  'KFH02',
  'invalid first household input',
  'unsupported onboarding locale is rejected'
);

select throws_ok(
  $$
    select *
    from public.create_first_household(
      '40000000-0000-4000-8000-000000000301',
      'New household',
      'New adult',
      'en',
      'Not/A_Real_Zone'
    )
  $$,
  'KFH02',
  'invalid first household input',
  'unknown timezone is rejected'
);

reset role;
select is(
  (
    select count(*)
    from public.profiles
    where auth_user_id = '00000000-0000-4000-8000-000000000301'
  ),
  0::bigint,
  'invalid requests leave no profile or partial onboarding state'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000301',
  true
);

select lives_ok(
  $$
    select *
    from public.create_first_household(
      '40000000-0000-4000-8000-000000000301',
      '  New household  ',
      '  New adult  ',
      'KO',
      'Asia/Seoul'
    )
  $$,
  'valid first household command succeeds'
);

reset role;
select is(
  (
    select count(*)
    from public.profiles
    where auth_user_id = '00000000-0000-4000-8000-000000000301'
  ),
  1::bigint,
  'command creates exactly one profile'
);

select row_eq(
  $$
    select display_name, locale, timezone, version
    from public.profiles
    where auth_user_id = '00000000-0000-4000-8000-000000000301'
  $$,
  row(
    'New adult'::text,
    'ko'::text,
    'Asia/Seoul'::text,
    1::bigint
  ),
  'profile bootstrap persists normalized onboarding values'
);

select is(
  (
    select count(*)
    from public.households
    where created_by_user_id = '00000000-0000-4000-8000-000000000301'
  ),
  1::bigint,
  'command creates exactly one household'
);

select row_eq(
  $$
    select name, timezone
    from public.households
    where created_by_user_id = '00000000-0000-4000-8000-000000000301'
  $$,
  row('New household'::text, 'Asia/Seoul'::text),
  'household stores normalized name and IANA timezone'
);

select is(
  (
    select count(*)
    from public.household_members
    where auth_user_id = '00000000-0000-4000-8000-000000000301'
      and removed_at is null
  ),
  1::bigint,
  'command creates exactly one active Owner membership'
);

select row_eq(
  $$
    select display_name, role::text
    from public.household_members
    where auth_user_id = '00000000-0000-4000-8000-000000000301'
      and removed_at is null
  $$,
  row('New adult'::text, 'owner'::text),
  'membership uses the server-selected Owner role and display name'
);

select ok(
  (
    select household.owner_member_id = member.id
    from public.households as household
    join public.household_members as member
      on member.household_id = household.id
    where household.created_by_user_id =
      '00000000-0000-4000-8000-000000000301'
      and member.auth_user_id =
        '00000000-0000-4000-8000-000000000301'
  ),
  'household Owner pointer references its active Owner membership'
);

select ok(
  (
    select active.household_id = member.household_id
      and active.member_id = member.id
    from public.user_active_households as active
    join public.household_members as member
      on member.auth_user_id = active.auth_user_id
     and member.household_id = active.household_id
     and member.id = active.member_id
    where active.auth_user_id =
      '00000000-0000-4000-8000-000000000301'
  ),
  'active selection binds the authenticated user to the created member'
);

select is(
  (
    select count(*)
    from app_private.first_household_requests
    where auth_user_id = '00000000-0000-4000-8000-000000000301'
      and octet_length(request_hash) = 32
  ),
  1::bigint,
  'server stores one SHA-256 idempotency result without raw form content'
);

select ok(
  (
    select request.household_id = household.id
      and request.member_id = household.owner_member_id
    from app_private.first_household_requests as request
    join public.households as household
      on household.id = request.household_id
    where request.auth_user_id =
      '00000000-0000-4000-8000-000000000301'
  ),
  'idempotency result binds the exact household and Owner member'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000301',
  true
);

select is(
  (select count(*) from public.households),
  1::bigint,
  'created Owner reads only the created household'
);

select is(
  (select count(*) from public.household_members),
  1::bigint,
  'created Owner reads only the created membership'
);

select is(
  (select count(*) from public.user_active_households),
  1::bigint,
  'created Owner reads the exact active selection'
);

select results_eq(
  $$
    select *
    from public.create_first_household(
      '40000000-0000-4000-8000-000000000301',
      'New household',
      'New adult',
      'ko',
      'Asia/Seoul'
    )
  $$,
  $$
    select household_id, member_id
    from public.user_active_households
    where auth_user_id = '00000000-0000-4000-8000-000000000301'
  $$,
  'same idempotency key and normalized request returns the first result'
);

reset role;
select ok(
  (
    select count(*) = 1
      and min(profile.version) = 1
    from public.profiles as profile
    where profile.auth_user_id =
      '00000000-0000-4000-8000-000000000301'
  )
    and (
      select count(*) = 1
      from public.households as household
      where household.created_by_user_id =
        '00000000-0000-4000-8000-000000000301'
    )
    and (
      select count(*) = 1
      from public.household_members as member
      where member.auth_user_id =
        '00000000-0000-4000-8000-000000000301'
    ),
  'idempotent retry creates no row and causes no profile version churn'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000301',
  true
);

select throws_ok(
  $$
    select *
    from public.create_first_household(
      '40000000-0000-4000-8000-000000000301',
      'Changed household',
      'New adult',
      'ko',
      'Asia/Seoul'
    )
  $$,
  'KFH04',
  'idempotency key reused with different input',
  'same key with changed input is rejected'
);

select throws_ok(
  $$
    select *
    from public.create_first_household(
      '40000000-0000-4000-8000-000000000302',
      'Second household',
      'New adult',
      'ko',
      'Asia/Seoul'
    )
  $$,
  'KFH03',
  'active household already exists',
  'a different key cannot create a second active household'
);

reset role;
select ok(
  (
    select count(*) = 1
    from public.households
    where created_by_user_id = '00000000-0000-4000-8000-000000000301'
  )
    and (
      select count(*) = 1
      from app_private.first_household_requests
      where auth_user_id = '00000000-0000-4000-8000-000000000301'
    ),
  'conflicting retries leave the first result unchanged'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);

select throws_ok(
  $$
    select *
    from public.create_first_household(
      '40000000-0000-4000-8000-000000000101',
      'Another household',
      'Adult A',
      'ko',
      'Asia/Seoul'
    )
  $$,
  'KFH03',
  'active household already exists',
  'existing fixture Owner cannot create another active household'
);

select throws_ok(
  $$
    update public.households
    set name = 'Client overwrite'
  $$,
  '42501',
  'permission denied for table households',
  'new Owner still cannot mutate the household table directly'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);

select is(
  (
    select count(*)
    from public.households
    where created_by_user_id = '00000000-0000-4000-8000-000000000301'
  ),
  0::bigint,
  'other-household actor cannot read the newly created household'
);

reset role;
select ok(
  not exists (
    select 1
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name like 'create_first_household_%'
      and parameter_name in (
        'p_auth_user_id',
        'p_household_id',
        'p_member_id',
        'p_role'
      )
  ),
  'RPC exposes no caller-supplied identity, household, member, or role'
);

select * from finish();
rollback;
