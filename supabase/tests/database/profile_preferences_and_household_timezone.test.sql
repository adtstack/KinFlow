begin;

select no_plan();

select has_table(
  'app_private',
  'household_timezone_audit_events',
  'household timezone changes have a private audit table'
);
select has_function(
  'public',
  'get_profile_preferences',
  array[]::text[],
  'authenticated profile preference projection exists'
);
select has_function(
  'public',
  'update_profile_preferences',
  array['text', 'text', 'text', 'text', 'bigint', 'text', 'bigint'],
  'atomic profile and household preference command exists'
);
select ok(
  (
    select pg_catalog.bool_and(pg_proc.prosecdef)
      and pg_catalog.bool_and(
        pg_proc.proconfig @> array['search_path=""']::text[]
      )
    from pg_catalog.pg_proc
    join pg_catalog.pg_namespace
      on pg_catalog.pg_namespace.oid = pg_catalog.pg_proc.pronamespace
    where pg_catalog.pg_namespace.nspname = 'public'
      and pg_catalog.pg_proc.proname in (
        'get_profile_preferences',
        'update_profile_preferences'
      )
  ),
  'settings RPCs are security-definer with an empty search path'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.get_profile_preferences()',
    'execute'
  )
    and has_function_privilege(
      'authenticated',
      'public.update_profile_preferences(text,text,text,text,bigint,text,bigint)',
      'execute'
    ),
  'authenticated adults can execute only the mediated settings RPCs'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.get_profile_preferences()',
    'execute'
  )
    and not has_function_privilege(
      'anon',
      'public.update_profile_preferences(text,text,text,text,bigint,text,bigint)',
      'execute'
    )
    and not has_function_privilege(
      'service_role',
      'public.update_profile_preferences(text,text,text,text,bigint,text,bigint)',
      'execute'
    ),
  'anonymous and service roles cannot impersonate the self-service command'
);
select ok(
  not has_column_privilege(
    'authenticated',
    'public.profiles',
    'display_name',
    'update'
  )
    and not has_column_privilege(
      'authenticated',
      'public.profiles',
      'avatar_key',
      'update'
    )
    and not has_column_privilege(
      'authenticated',
      'public.profiles',
      'locale',
      'update'
    )
    and not has_column_privilege(
      'authenticated',
      'public.profiles',
      'timezone',
      'update'
    ),
  'direct profile mutation cannot bypass membership synchronization'
);
select is(
  (
    select pg_catalog.count(*)
    from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'profiles_update_self'
  ),
  0::bigint,
  'legacy direct self-update policy is removed'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.household_timezone_audit_events',
    'select'
  )
    and not has_table_privilege(
      'service_role',
      'app_private.household_timezone_audit_events',
      'select'
    ),
  'private timezone audit is not exposed to client or service roles'
);
select ok(
  pg_catalog.strpos(
    pg_catalog.pg_get_functiondef(
      'public.update_profile_preferences(text,text,text,text,bigint,text,bigint)'::regprocedure
    ),
    'chore_series'
  ) = 0,
  'household timezone changes do not rewrite stored chore-series timezone'
);
select ok(
  pg_catalog.strpos(
    pg_catalog.pg_get_functiondef(
      'public.update_profile_preferences(text,text,text,text,bigint,text,bigint)'::regprocedure
    ),
    'event_series'
  ) = 0,
  'household timezone changes do not rewrite stored calendar-series timezone'
);

select throws_ok(
  $$select * from public.get_profile_preferences()$$,
  'KFS01',
  'authentication required',
  'anonymous preference projection is rejected'
);
select throws_ok(
  $$
    select * from public.update_profile_preferences(
      'No identity', null, 'en', 'UTC', 1, null, null
    )
  $$,
  'KFS01',
  'authentication required',
  'anonymous preference update is rejected'
);

set local role authenticated;
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);

select is(
  (
    select pg_catalog.concat_ws(
      '|',
      preference.profile_id,
      preference.display_name,
      coalesce(preference.avatar_key, 'none'),
      preference.locale,
      preference.profile_timezone,
      preference.profile_version,
      preference.household_id,
      preference.household_name,
      preference.household_timezone,
      preference.household_version,
      preference.household_role,
      preference.can_manage_household_timezone
    )
    from public.get_profile_preferences() as preference
  ),
  '10000000-0000-4000-8000-000000000101|Adult A|none|ko|Asia/Seoul|1|20000000-0000-4000-8000-000000000101|Primary Local Household|Asia/Seoul|1|owner|t',
  'Owner receives only its authoritative profile and active-household projection'
);

select throws_ok(
  $$
    update public.profiles
    set display_name = 'Direct bypass'
    where auth_user_id = '00000000-0000-4000-8000-000000000101'
  $$,
  '42501',
  'permission denied for table profiles',
  'authenticated client cannot directly mutate its profile'
);

select is(
  (
    select pg_catalog.concat_ws(
      '|',
      preference.display_name,
      preference.avatar_key,
      preference.locale,
      preference.profile_timezone,
      preference.profile_version,
      preference.household_timezone,
      preference.household_version
    )
    from public.update_profile_preferences(
      '  Adult Alpha  ',
      'preset:sun',
      'EN',
      'America/New_York',
      1,
      null,
      null
    ) as preference
  ),
  'Adult Alpha|preset:sun|en|America/New_York|2|Asia/Seoul|1',
  'profile-only save normalizes fields and keeps household version stable'
);
select is(
  (
    select pg_catalog.concat_ws(
      '|',
      profile.display_name,
      profile.avatar_key,
      profile.locale,
      profile.timezone,
      member.display_name,
      member.avatar_key
    )
    from public.profiles as profile
    join public.household_members as member
      on member.auth_user_id = profile.auth_user_id
     and member.removed_at is null
    where profile.auth_user_id = '00000000-0000-4000-8000-000000000101'
  ),
  'Adult Alpha|preset:sun|en|America/New_York|Adult Alpha|preset:sun',
  'profile identity synchronizes to the active household membership atomically'
);
reset role;
select is(
  (
    select count(*)
    from app_private.household_timezone_audit_events
  ),
  0::bigint,
  'profile-only save creates no household audit event'
);
set local role authenticated;
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);

select is(
  (
    select pg_catalog.concat_ws(
      '|',
      preference.profile_version,
      preference.household_version
    )
    from public.update_profile_preferences(
      'Adult Alpha',
      'preset:sun',
      'en',
      'America/New_York',
      2,
      null,
      null
    ) as preference
  ),
  '2|1',
  'an exact no-op does not increment profile or household version'
);

select throws_ok(
  $$
    select * from public.update_profile_preferences(
      'Adult Alpha', 'preset:unknown', 'en', 'America/New_York', 2,
      null, null
    )
  $$,
  'KFS02',
  'invalid profile preferences input',
  'unknown remote or preset avatar key is rejected'
);
select throws_ok(
  $$
    select * from public.update_profile_preferences(
      'Adult Alpha', 'preset:sun', 'fr', 'America/New_York', 2,
      null, null
    )
  $$,
  'KFS02',
  'invalid profile preferences input',
  'unsupported locale is rejected'
);
select throws_ok(
  $$
    select * from public.update_profile_preferences(
      'Adult Alpha', 'preset:sun', 'en', 'Not/A_Real_Zone', 2,
      null, null
    )
  $$,
  'KFS02',
  'invalid profile preferences input',
  'unknown profile timezone is rejected'
);
select throws_ok(
  $$
    select * from public.update_profile_preferences(
      E'Adult\nAlpha', 'preset:sun', 'en', 'America/New_York', 2,
      null, null
    )
  $$,
  'KFS02',
  'invalid profile preferences input',
  'control characters in display names are rejected'
);
select throws_ok(
  $$
    select * from public.update_profile_preferences(
      'Adult Alpha', 'preset:sun', 'en', 'America/New_York', 2,
      null, 1
    )
  $$,
  'KFS02',
  'invalid profile preferences input',
  'household expected version cannot be submitted without a timezone mutation'
);
select throws_ok(
  $$
    select * from public.update_profile_preferences(
      'Adult Alpha', 'preset:sun', 'en', 'America/New_York', 1,
      null, null
    )
  $$,
  'KFS05',
  'profile version conflict',
  'stale profile write is rejected'
);

select is(
  (
    select pg_catalog.concat_ws(
      '|',
      preference.display_name,
      preference.profile_version,
      preference.household_timezone,
      preference.household_version
    )
    from public.update_profile_preferences(
      'Adult Alpha Two',
      'preset:heart',
      'ko',
      'Asia/Seoul',
      2,
      'America/Los_Angeles',
      1
    ) as preference
  ),
  'Adult Alpha Two|3|America/Los_Angeles|2',
  'Owner atomically changes profile and household default timezone'
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      '|',
      audit.authenticated_user_id,
      audit.actor_member_id,
      audit.previous_timezone,
      audit.next_timezone,
      audit.aggregate_version
    )
    from app_private.household_timezone_audit_events as audit
  ),
  '00000000-0000-4000-8000-000000000101|30000000-0000-4000-8000-000000000101|Asia/Seoul|America/Los_Angeles|2',
  'timezone audit records server-derived actor, before/after values, and version'
);
set local role authenticated;
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      '|',
      preference.household_role,
      preference.can_manage_household_timezone
    )
    from public.get_profile_preferences() as preference
  ),
  'member|f',
  'ordinary Member receives a read-only household-timezone capability flag'
);
select throws_ok(
  $$
    select * from public.update_profile_preferences(
      'Member escalation', null, 'ko', 'Asia/Seoul', 1,
      'Europe/London', 2
    )
  $$,
  'KFS04',
  'household timezone permission denied',
  'ordinary Member cannot mutate household timezone'
);
select is(
  (
    select pg_catalog.concat_ws('|', profile.display_name, profile.version)
    from public.profiles as profile
    where profile.auth_user_id = '00000000-0000-4000-8000-000000000102'
  ),
  'Adult B|1',
  'forbidden household mutation rolls back the attempted profile change'
);
select is(
  (
    select pg_catalog.concat_ws(
      '|',
      preference.display_name,
      preference.avatar_key,
      preference.locale,
      preference.profile_timezone,
      preference.profile_version
    )
    from public.update_profile_preferences(
      'Adult Beta',
      'preset:leaf',
      'en',
      'Europe/London',
      1,
      null,
      null
    ) as preference
  ),
  'Adult Beta|preset:leaf|en|Europe/London|2',
  'ordinary Member can still update its own personal preferences'
);

reset role;
update public.household_members as member
set role = 'admin'
where member.id = '30000000-0000-4000-8000-000000000102';
set local role authenticated;
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      '|',
      preference.household_role,
      preference.can_manage_household_timezone,
      preference.household_timezone,
      preference.household_version
    )
    from public.update_profile_preferences(
      'Adult Beta',
      'preset:leaf',
      'en',
      'Europe/London',
      2,
      'Europe/London',
      2
    ) as preference
  ),
  'admin|t|Europe/London|3',
  'active Admin can change the household default timezone'
);
reset role;
select is(
  (
    select count(*)
    from app_private.household_timezone_audit_events
  ),
  2::bigint,
  'each real household timezone change appends exactly one audit event'
);
set local role authenticated;
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select preference.household_version
    from public.update_profile_preferences(
      'Adult Beta',
      'preset:leaf',
      'en',
      'Europe/London',
      2,
      'Europe/London',
      3
    ) as preference
  ),
  3::bigint,
  'authorized household no-op keeps its version stable'
);
reset role;
select is(
  (
    select count(*)
    from app_private.household_timezone_audit_events
  ),
  2::bigint,
  'authorized household no-op adds no audit event'
);
set local role authenticated;
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.update_profile_preferences(
      'Must Roll Back', 'preset:star', 'en', 'UTC', 3,
      'Asia/Tokyo', 2
    )
  $$,
  'KFS06',
  'household version conflict',
  'stale household write rejects the combined command'
);
select is(
  (
    select pg_catalog.concat_ws(
      '|',
      profile.display_name,
      profile.avatar_key,
      profile.locale,
      profile.timezone,
      profile.version,
      member.display_name,
      household.timezone,
      household.version
    )
    from public.profiles as profile
    join public.household_members as member
      on member.auth_user_id = profile.auth_user_id
     and member.removed_at is null
    join public.households as household
      on household.id = member.household_id
    where profile.auth_user_id = '00000000-0000-4000-8000-000000000101'
  ),
  'Adult Alpha Two|preset:heart|ko|Asia/Seoul|3|Adult Alpha Two|Europe/London|3',
  'household conflict leaves profile, membership, household, and versions unchanged'
);

reset role;
select throws_ok(
  $$
    update app_private.household_timezone_audit_events
    set next_timezone = 'Asia/Tokyo'
  $$,
  '55000',
  'household audit events are immutable',
  'timezone audit rows cannot be rewritten even by a privileged path'
);
select throws_ok(
  $$delete from app_private.household_timezone_audit_events$$,
  '55000',
  'household audit events are immutable',
  'timezone audit rows cannot be deleted'
);

select * from finish();
rollback;
