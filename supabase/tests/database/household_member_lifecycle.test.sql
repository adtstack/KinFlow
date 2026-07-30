begin;
set constraints all deferred;

select plan(64);

-- Additional deterministic adults exercise peer-admin, leave, and fallback paths.
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
    '00000000-0000-4000-8000-000000000103',
    'authenticated',
    'authenticated',
    'adult-c@local.kinflow.invalid',
    now(),
    '{"provider":"local_fixture","providers":["local_fixture"]}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-000000000104',
    'authenticated',
    'authenticated',
    'adult-d@local.kinflow.invalid',
    now(),
    '{"provider":"local_fixture","providers":["local_fixture"]}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  );

insert into public.profiles (id, auth_user_id, display_name, locale, timezone)
values
  (
    '10000000-0000-4000-8000-000000000103',
    '00000000-0000-4000-8000-000000000103',
    'Adult C',
    'ko',
    'Asia/Seoul'
  ),
  (
    '10000000-0000-4000-8000-000000000104',
    '00000000-0000-4000-8000-000000000104',
    'Adult D',
    'ko',
    'Asia/Seoul'
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
    '30000000-0000-4000-8000-000000000103',
    '20000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000103',
    'Adult C',
    'member',
    '00000000-0000-4000-8000-000000000101'
  ),
  (
    '30000000-0000-4000-8000-000000000202',
    '20000000-0000-4000-8000-000000000201',
    '00000000-0000-4000-8000-000000000103',
    'Adult C',
    'member',
    '00000000-0000-4000-8000-000000000201'
  ),
  (
    '30000000-0000-4000-8000-000000000104',
    '20000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000104',
    'Adult D',
    'member',
    '00000000-0000-4000-8000-000000000101'
  );

insert into public.user_active_households (auth_user_id, household_id, member_id)
values
  (
    '00000000-0000-4000-8000-000000000103',
    '20000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000103'
  ),
  (
    '00000000-0000-4000-8000-000000000104',
    '20000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000104'
  );

-- 01-15: command surface, least privilege, and audit shape.
select has_table(
  'app_private',
  'household_member_command_requests',
  'member command idempotency table exists'
);
select has_table(
  'app_private',
  'household_audit_events',
  'household audit table exists'
);
select has_function(
  'public',
  'get_household_member_roster',
  array['uuid'],
  'minimal member roster query exists'
);
select has_function(
  'public',
  'change_household_member_role',
  array['uuid', 'uuid', 'uuid', 'text', 'bigint', 'uuid'],
  'role change command exists'
);
select has_function(
  'public',
  'remove_household_member',
  array['uuid', 'uuid', 'uuid', 'bigint', 'uuid'],
  'member removal command exists'
);
select has_function(
  'public',
  'leave_household',
  array['uuid', 'uuid', 'bigint', 'uuid'],
  'leave household command exists'
);
select has_function(
  'public',
  'transfer_household_owner',
  array['uuid', 'uuid', 'uuid', 'bigint', 'uuid'],
  'owner transfer command exists'
);
select ok(
  (
    select bool_and(pg_proc.prosecdef)
      and bool_and(pg_proc.proconfig @> array['search_path=""']::text[])
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname in (
        'get_household_member_roster',
        'change_household_member_role',
        'remove_household_member',
        'leave_household',
        'transfer_household_owner'
      )
  ),
  'member functions are security-definer with empty search path'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.change_household_member_role(uuid,uuid,uuid,text,bigint,uuid)',
    'execute'
  ) and has_function_privilege(
    'service_role',
    'public.remove_household_member(uuid,uuid,uuid,bigint,uuid)',
    'execute'
  ) and has_function_privilege(
    'service_role',
    'public.leave_household(uuid,uuid,bigint,uuid)',
    'execute'
  ) and has_function_privilege(
    'service_role',
    'public.transfer_household_owner(uuid,uuid,uuid,bigint,uuid)',
    'execute'
  ),
  'service role can execute all mediated mutations'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.change_household_member_role(uuid,uuid,uuid,text,bigint,uuid)',
    'execute'
  ) and not has_function_privilege(
    'authenticated',
    'public.remove_household_member(uuid,uuid,uuid,bigint,uuid)',
    'execute'
  ) and not has_function_privilege(
    'authenticated',
    'public.leave_household(uuid,uuid,bigint,uuid)',
    'execute'
  ) and not has_function_privilege(
    'authenticated',
    'public.transfer_household_owner(uuid,uuid,uuid,bigint,uuid)',
    'execute'
  ),
  'authenticated clients cannot bypass Edge mutation mediation'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.get_household_member_roster(uuid)',
    'execute'
  ) and not has_function_privilege(
    'anon',
    'public.get_household_member_roster(uuid)',
    'execute'
  ),
  'only authenticated clients can query the minimal roster'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.household_member_command_requests',
    'select'
  ) and not has_table_privilege(
    'authenticated',
    'app_private.household_audit_events',
    'select'
  ),
  'private lifecycle records are inaccessible to clients'
);
select is(
  (
    select string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'household_audit_events'
  ),
  'id,household_id,authenticated_user_id,actor_member_id,action,target_member_id,correlation_id,aggregate_version,result,occurred_at',
  'audit schema contains identifiers, result, version, and time only'
);
select ok(
  exists (
    select 1
    from pg_trigger
    join pg_class on pg_class.oid = pg_trigger.tgrelid
    join pg_namespace on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'app_private'
      and pg_class.relname = 'household_audit_events'
      and pg_trigger.tgname = 'household_audit_events_immutable'
      and not pg_trigger.tgisinternal
      and pg_trigger.tgenabled = 'O'
  ),
  'audit immutability trigger is enabled'
);
select hasnt_column(
  'app_private',
  'household_audit_events',
  'token',
  'audit has no token field'
);

-- 16-20: roster authentication, minimization, and household isolation.
select throws_ok(
  $$select * from public.get_household_member_roster(
    '20000000-0000-4000-8000-000000000101'
  )$$,
  'KFM01',
  'authentication required',
  'roster requires authentication'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select count(*)
    from public.get_household_member_roster(
      '20000000-0000-4000-8000-000000000101'
    )
  ),
  4::bigint,
  'same-household roster returns every active adult'
);
select is(
  (
    select count(*)
    from public.get_household_member_roster(
      '20000000-0000-4000-8000-000000000101'
    ) as roster
    where roster.is_current_user
  ),
  1::bigint,
  'roster identifies exactly one current adult'
);
select ok(
  not exists (
    select 1
    from public.get_household_member_roster(
      '20000000-0000-4000-8000-000000000101'
    ) as roster
    where to_jsonb(roster) ? 'auth_user_id'
  ),
  'roster never exposes auth user identifiers'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$select * from public.get_household_member_roster(
    '20000000-0000-4000-8000-000000000101'
  )$$,
  'KFM05',
  'household member not found or forbidden',
  'other-household adult cannot enumerate a roster'
);
reset role;

-- 21-35: role authority, expected version, and idempotent replay.
select throws_ok(
  $$select * from public.change_household_member_role(
    '00000000-0000-4000-8000-000000009999',
    '20000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000102',
    'admin',
    1,
    '80000000-0000-4000-8000-000000000001'
  )$$,
  'KFM01',
  'authentication required',
  'role command rejects an unverified identity'
);
select throws_ok(
  $$select * from public.change_household_member_role(
    '00000000-0000-4000-8000-000000000104',
    '20000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000103',
    'admin',
    1,
    '80000000-0000-4000-8000-000000000002'
  )$$,
  'KFM05',
  'household member not found or forbidden',
  'ordinary member cannot change another role'
);
select throws_ok(
  $$select * from public.change_household_member_role(
    '00000000-0000-4000-8000-000000000201',
    '20000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000102',
    'admin',
    1,
    '80000000-0000-4000-8000-000000000003'
  )$$,
  'KFM05',
  'household member not found or forbidden',
  'other-household Owner cannot inject a household ID'
);
select lives_ok(
  $$select * from public.change_household_member_role(
    '00000000-0000-4000-8000-000000000101',
    '20000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000102',
    'admin',
    1,
    '80000000-0000-4000-8000-000000000004'
  )$$,
  'Owner promotes a member to Admin'
);
select is(
  (
    select role::text || ':' || version::text
    from public.household_members
    where id = '30000000-0000-4000-8000-000000000102'
  ),
  'admin:2',
  'role mutation increments only the target version'
);
select is(
  (
    select role || ':' || version::text
    from public.change_household_member_role(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      '30000000-0000-4000-8000-000000000102',
      'admin',
      1,
      '80000000-0000-4000-8000-000000000004'
    )
  ),
  'admin:2',
  'same role command key replays the stored result'
);
select is(
  (
    select
      (select count(*) from app_private.household_member_command_requests
       where idempotency_key = '80000000-0000-4000-8000-000000000004')::text
      || ':' ||
      (select count(*) from app_private.household_audit_events
       where correlation_id = '80000000-0000-4000-8000-000000000004')::text
  ),
  '1:1',
  'role replay stores one command and one audit event'
);
select throws_ok(
  $$select * from public.change_household_member_role(
    '00000000-0000-4000-8000-000000000101',
    '20000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000102',
    'member',
    2,
    '80000000-0000-4000-8000-000000000004'
  )$$,
  'KFM04',
  'idempotency key reused with different member input',
  'role key reuse with changed input conflicts'
);
select throws_ok(
  $$select * from public.change_household_member_role(
    '00000000-0000-4000-8000-000000000101',
    '20000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000102',
    'member',
    1,
    '80000000-0000-4000-8000-000000000005'
  )$$,
  'KFM06',
  'household member version conflict',
  'stale target version is rejected'
);
select throws_ok(
  $$select * from public.change_household_member_role(
    '00000000-0000-4000-8000-000000000101',
    '20000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000101',
    'member',
    1,
    '80000000-0000-4000-8000-000000000006'
  )$$,
  'KFM07',
  'role change not allowed',
  'Owner cannot self-demote through role change'
);
select lives_ok(
  $$select * from public.change_household_member_role(
    '00000000-0000-4000-8000-000000000102',
    '20000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000104',
    'admin',
    1,
    '80000000-0000-4000-8000-000000000007'
  )$$,
  'Admin promotes an ordinary Member'
);
select is(
  (
    select role::text || ':' || version::text
    from public.household_members
    where id = '30000000-0000-4000-8000-000000000104'
  ),
  'admin:2',
  'Admin promotion increments the target version'
);
select throws_ok(
  $$select * from public.change_household_member_role(
    '00000000-0000-4000-8000-000000000102',
    '20000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000104',
    'member',
    2,
    '80000000-0000-4000-8000-000000000008'
  )$$,
  'KFM03',
  'household member permission denied',
  'Admin cannot demote a peer Admin'
);
select lives_ok(
  $$select * from public.change_household_member_role(
    '00000000-0000-4000-8000-000000000101',
    '20000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000104',
    'member',
    2,
    '80000000-0000-4000-8000-000000000009'
  )$$,
  'Owner demotes an Admin to Member'
);
select is(
  (
    select role::text || ':' || version::text
    from public.household_members
    where id = '30000000-0000-4000-8000-000000000104'
  ),
  'member:3',
  'Owner demotion preserves the expected version sequence'
);

-- 36-45: atomic Owner transfer and last-owner rule.
select throws_ok(
  $$select * from public.transfer_household_owner(
    '00000000-0000-4000-8000-000000000101',
    '20000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000102',
    2,
    '80000000-0000-4000-8000-000000000010'
  )$$,
  'KFM06',
  'household version conflict',
  'stale household version blocks Owner transfer'
);
select throws_ok(
  $$select * from public.transfer_household_owner(
    '00000000-0000-4000-8000-000000000101',
    '20000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000201',
    1,
    '80000000-0000-4000-8000-000000000011'
  )$$,
  'KFM05',
  'household member not found or forbidden',
  'Owner transfer rejects an outsider member ID'
);
select lives_ok(
  $$select * from public.transfer_household_owner(
    '00000000-0000-4000-8000-000000000101',
    '20000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000102',
    1,
    '80000000-0000-4000-8000-000000000012'
  )$$,
  'Owner transfer succeeds atomically'
);
select is(
  (
    select owner_member_id::text || ':' || version::text
    from public.households
    where id = '20000000-0000-4000-8000-000000000101'
  ),
  '30000000-0000-4000-8000-000000000102:2',
  'household pointer and version move to the new Owner'
);
select is(
  (
    select string_agg(id::text || '=' || role::text, ',' order by id)
    from public.household_members
    where household_id = '20000000-0000-4000-8000-000000000101'
      and role = 'owner'
      and removed_at is null
  ),
  '30000000-0000-4000-8000-000000000102=owner',
  'transfer leaves exactly one active Owner'
);
select is(
  (
    select version::text || ':' ||
      (select count(*)::text from app_private.household_audit_events
       where correlation_id = '80000000-0000-4000-8000-000000000012')
    from public.transfer_household_owner(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      '30000000-0000-4000-8000-000000000102',
      1,
      '80000000-0000-4000-8000-000000000012'
    )
  ),
  '2:1',
  'Owner transfer replay returns the stored result without duplicate audit'
);
select lives_ok(
  $$select * from public.transfer_household_owner(
    '00000000-0000-4000-8000-000000000102',
    '20000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000101',
    2,
    '80000000-0000-4000-8000-000000000013'
  )$$,
  'new Owner can transfer ownership back'
);
select is(
  (
    select owner_member_id::text || ':' || version::text
    from public.households
    where id = '20000000-0000-4000-8000-000000000101'
  ),
  '30000000-0000-4000-8000-000000000101:3',
  'second transfer advances the household version'
);
select is(
  (
    select string_agg(id::text || '=' || role::text, ',' order by id)
    from public.household_members
    where household_id = '20000000-0000-4000-8000-000000000101'
      and role = 'owner'
      and removed_at is null
  ),
  '30000000-0000-4000-8000-000000000101=owner',
  'second transfer still leaves exactly one active Owner'
);
select throws_ok(
  $$select * from public.leave_household(
    '00000000-0000-4000-8000-000000000101',
    '20000000-0000-4000-8000-000000000101',
    3,
    '80000000-0000-4000-8000-000000000014'
  )$$,
  'KFM08',
  'owner transfer required',
  'last Owner cannot leave before transferring ownership'
);

-- One active invite created by Adult D must be revoked with membership removal.
insert into public.household_invites (
  id,
  household_id,
  role,
  token_hash,
  status,
  expires_at,
  created_by_member_id
)
values (
  '50000000-0000-4000-8000-000000000105',
  '20000000-0000-4000-8000-000000000101',
  'member',
  decode(repeat('dd', 32), 'hex'),
  'active',
  now() + interval '1 day',
  '30000000-0000-4000-8000-000000000104'
);

-- 46-52: Admin removal, invite cleanup, access denial, and replay.
select lives_ok(
  $$select * from public.remove_household_member(
    '00000000-0000-4000-8000-000000000102',
    '20000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000104',
    3,
    '80000000-0000-4000-8000-000000000015'
  )$$,
  'Admin removes an ordinary Member'
);
select is(
  (
    select (removed_at is not null)::text || ':' || version::text
    from public.household_members
    where id = '30000000-0000-4000-8000-000000000104'
  ),
  'true:4',
  'removal tombstones the membership and increments its version'
);
select is(
  (
    select status::text || ':' || (revoked_at is not null)::text
    from public.household_invites
    where id = '50000000-0000-4000-8000-000000000105'
  ),
  'revoked:true',
  'removal revokes active invites created by the target'
);
select is(
  (
    select count(*)
    from public.user_active_households
    where auth_user_id = '00000000-0000-4000-8000-000000000104'
  ),
  0::bigint,
  'removal clears an active selection when no fallback exists'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000104',
  true
);
select throws_ok(
  $$select * from public.get_household_member_roster(
    '20000000-0000-4000-8000-000000000101'
  )$$,
  'KFM05',
  'household member not found or forbidden',
  'removed adult immediately loses roster access'
);
reset role;
select is(
  (
    select version::text || ':' ||
      (select count(*)::text from app_private.household_audit_events
       where correlation_id = '80000000-0000-4000-8000-000000000015')
    from public.remove_household_member(
      '00000000-0000-4000-8000-000000000102',
      '20000000-0000-4000-8000-000000000101',
      '30000000-0000-4000-8000-000000000104',
      3,
      '80000000-0000-4000-8000-000000000015'
    )
  ),
  '4:1',
  'remove replay returns the tombstone result with one audit event'
);
select throws_ok(
  $$select * from public.remove_household_member(
    '00000000-0000-4000-8000-000000000102',
    '20000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000103',
    1,
    '80000000-0000-4000-8000-000000000015'
  )$$,
  'KFM04',
  'idempotency key reused with different member input',
  'remove key reuse with another target conflicts'
);

-- 53-57: voluntary leave and deterministic active-household fallback.
select lives_ok(
  $$select * from public.leave_household(
    '00000000-0000-4000-8000-000000000103',
    '20000000-0000-4000-8000-000000000101',
    1,
    '80000000-0000-4000-8000-000000000016'
  )$$,
  'non-Owner adult leaves the household'
);
select is(
  (
    select member.removed_at is not null
      and active_household.household_id = '20000000-0000-4000-8000-000000000201'
      and active_household.member_id = '30000000-0000-4000-8000-000000000202'
    from public.household_members as member
    join public.user_active_households as active_household
      on active_household.auth_user_id = member.auth_user_id
    where member.id = '30000000-0000-4000-8000-000000000103'
  ),
  true,
  'leave tombstones membership and selects the deterministic fallback pair'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000103',
  true
);
select throws_ok(
  $$select * from public.get_household_member_roster(
    '20000000-0000-4000-8000-000000000101'
  )$$,
  'KFM05',
  'household member not found or forbidden',
  'departed adult cannot reopen the former roster'
);
select is(
  (
    select count(*)
    from public.get_household_member_roster(
      '20000000-0000-4000-8000-000000000201'
    )
  ),
  2::bigint,
  'departed adult can access the selected fallback household roster'
);
reset role;
select is(
  (
    select active_household_id::text || ':' || active_member_id::text || ':' ||
      (select count(*)::text from app_private.household_audit_events
       where correlation_id = '80000000-0000-4000-8000-000000000016')
    from public.leave_household(
      '00000000-0000-4000-8000-000000000103',
      '20000000-0000-4000-8000-000000000101',
      1,
      '80000000-0000-4000-8000-000000000016'
    )
  ),
  '20000000-0000-4000-8000-000000000201:30000000-0000-4000-8000-000000000202:1',
  'leave replay preserves the paired fallback and one audit event'
);

-- 58-64: aggregate audit/idempotency integrity and immediate RLS denial.
select is(
  (
    select
      (select count(*) from app_private.household_audit_events)::text
      || ':' ||
      (select count(*) from app_private.household_member_command_requests)::text
  ),
  '7:7',
  'successful unique commands produce one audit and one command record each'
);
select is(
  (
    select count(*)
    from app_private.household_audit_events
    where result = 'left'
      and action = 'member.removed'
      and actor_member_id = target_member_id
  ),
  1::bigint,
  'voluntary leave has one explicit PII-free audit result'
);
select throws_ok(
  $$update app_private.household_audit_events set result = 'succeeded'$$,
  '55000',
  'household audit events are immutable',
  'audit events cannot be updated'
);
select throws_ok(
  $$delete from app_private.household_audit_events$$,
  '55000',
  'household audit events are immutable',
  'audit events cannot be deleted'
);
select is(
  (
    select count(*)
    from app_private.household_member_command_requests
    where octet_length(request_hash) = 32
      and jsonb_typeof(result) = 'object'
  ),
  7::bigint,
  'every stored command has a fixed digest and typed result object'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000104',
  true
);
select is(
  (
    select count(*)
    from public.household_members
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  0::bigint,
  'RLS returns no former household members to a removed adult'
);
reset role;
select is(
  (
    select owner_member_id::text || ':' ||
      (select count(*)::text from public.household_members
       where household_id = household.id
         and role = 'owner'
         and removed_at is null)
    from public.households as household
    where household.id = '20000000-0000-4000-8000-000000000101'
  ),
  '30000000-0000-4000-8000-000000000101:1',
  'final Owner pointer matches exactly one active Owner'
);

select * from finish();
rollback;
