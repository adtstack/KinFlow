-- Deterministic synthetic local fixtures. Never use production identities here.

begin;
set constraints all deferred;

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
values
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-000000000101',
    'authenticated',
    'authenticated',
    'adult-a@local.kinflow.invalid',
    now(),
    '{"provider":"local_fixture","providers":["local_fixture"]}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-000000000102',
    'authenticated',
    'authenticated',
    'adult-b@local.kinflow.invalid',
    now(),
    '{"provider":"local_fixture","providers":["local_fixture"]}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-000000000201',
    'authenticated',
    'authenticated',
    'isolation-adult@local.kinflow.invalid',
    now(),
    '{"provider":"local_fixture","providers":["local_fixture"]}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  );

insert into public.profiles (id, auth_user_id, display_name, locale, timezone)
values
  (
    '10000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000101',
    'Adult A',
    'ko',
    'Asia/Seoul'
  ),
  (
    '10000000-0000-4000-8000-000000000102',
    '00000000-0000-4000-8000-000000000102',
    'Adult B',
    'ko',
    'Asia/Seoul'
  ),
  (
    '10000000-0000-4000-8000-000000000201',
    '00000000-0000-4000-8000-000000000201',
    'Isolation Adult',
    'en',
    'UTC'
  );

insert into public.households (
  id,
  name,
  timezone,
  owner_member_id,
  created_by_user_id
)
values
  (
    '20000000-0000-4000-8000-000000000101',
    'Primary Local Household',
    'Asia/Seoul',
    '30000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000101'
  ),
  (
    '20000000-0000-4000-8000-000000000201',
    'Isolation Local Household',
    'UTC',
    '30000000-0000-4000-8000-000000000201',
    '00000000-0000-4000-8000-000000000201'
  );

insert into public.household_members (
  id,
  household_id,
  auth_user_id,
  display_name,
  role,
  created_by_user_id
)
values
  (
    '30000000-0000-4000-8000-000000000101',
    '20000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000101',
    'Adult A',
    'owner',
    '00000000-0000-4000-8000-000000000101'
  ),
  (
    '30000000-0000-4000-8000-000000000102',
    '20000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000102',
    'Adult B',
    'member',
    '00000000-0000-4000-8000-000000000101'
  ),
  (
    '30000000-0000-4000-8000-000000000201',
    '20000000-0000-4000-8000-000000000201',
    '00000000-0000-4000-8000-000000000201',
    'Isolation Adult',
    'owner',
    '00000000-0000-4000-8000-000000000201'
  );

insert into public.user_active_households (
  auth_user_id,
  household_id,
  member_id
)
values
  (
    '00000000-0000-4000-8000-000000000101',
    '20000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000101'
  ),
  (
    '00000000-0000-4000-8000-000000000102',
    '20000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000102'
  ),
  (
    '00000000-0000-4000-8000-000000000201',
    '20000000-0000-4000-8000-000000000201',
    '30000000-0000-4000-8000-000000000201'
  );

commit;
