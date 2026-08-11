begin;
set constraints all deferred;

select plan(35);

select has_column(
  'public',
  'user_active_households',
  'version',
  'active household selection has an optimistic version'
);
select has_table(
  'app_private',
  'active_household_switch_audit_events',
  'active household switching has a private audit table'
);
select has_function(
  'public',
  'list_my_households',
  array[]::text[],
  'self-only household selection projection exists'
);
select has_function(
  'public',
  'switch_active_household',
  array['uuid', 'bigint'],
  'versioned active household command exists'
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
        'list_my_households',
        'switch_active_household'
      )
  ),
  'household selection RPCs are security-definer with empty search paths'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.list_my_households()',
    'execute'
  )
    and has_function_privilege(
      'authenticated',
      'public.switch_active_household(uuid,bigint)',
      'execute'
    ),
  'authenticated adults can execute the mediated selection RPCs'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.list_my_households()',
    'execute'
  )
    and not has_function_privilege(
      'service_role',
      'public.switch_active_household(uuid,bigint)',
      'execute'
    ),
  'anonymous and service roles cannot impersonate household selection'
);
select ok(
  not has_column_privilege(
    'authenticated',
    'public.user_active_households',
    'household_id',
    'update'
  )
    and not has_column_privilege(
      'authenticated',
      'public.user_active_households',
      'member_id',
      'update'
    ),
  'authenticated clients cannot bypass optimistic switching with direct updates'
);
select policies_are(
  'public',
  'user_active_households',
  array['active_household_select_self'],
  'active household selection is self-readable and RPC-write-only'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.active_household_switch_audit_events',
    'select'
  )
    and not has_table_privilege(
      'service_role',
      'app_private.active_household_switch_audit_events',
      'select'
    ),
  'private household switch audit is not exposed to client or service roles'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_trigger
    join pg_catalog.pg_class
      on pg_catalog.pg_class.oid = pg_catalog.pg_trigger.tgrelid
    join pg_catalog.pg_namespace
      on pg_catalog.pg_namespace.oid = pg_catalog.pg_class.relnamespace
    where pg_catalog.pg_namespace.nspname = 'public'
      and pg_catalog.pg_class.relname = 'user_active_households'
      and pg_catalog.pg_trigger.tgname =
        'user_active_households_set_updated_at_and_version'
      and not pg_catalog.pg_trigger.tgisinternal
  ),
  'active selection updates increment version through the standard trigger'
);
select ok(
  pg_catalog.strpos(
    pg_catalog.pg_get_functiondef(
      'public.switch_active_household(uuid,bigint)'::regprocedure
    ),
    'p_target_member'
  ) = 0,
  'client cannot submit a target member identifier'
);
select throws_ok(
  $$select * from public.list_my_households()$$,
  'KFH01',
  'authentication required',
  'anonymous household listing is rejected'
);
select throws_ok(
  $sql$select * from public.switch_active_household(
    '20000000-0000-4000-8000-000000000101',
    1
  )$sql$,
  'KFH01',
  'authentication required',
  'anonymous household switching is rejected'
);

insert into public.households (
  id,
  name,
  timezone,
  owner_member_id,
  created_by_user_id
)
values (
  '20000000-0000-4000-8000-000000000301',
  'Secondary Adult Household',
  'Asia/Seoul',
  '30000000-0000-4000-8000-000000000301',
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
  '30000000-0000-4000-8000-000000000301',
  '20000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000101',
  'Adult A',
  'owner',
  '00000000-0000-4000-8000-000000000101'
);

set local role authenticated;
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);

select is(
  (
    select pg_catalog.string_agg(
      pg_catalog.concat_ws(
        '|',
        selection.household_id,
        selection.member_id,
        selection.household_name,
        selection.member_role,
        selection.membership_version,
        selection.is_active,
        selection.selection_version
      ),
      ';'
      order by selection.is_active desc, selection.household_name
    )
    from public.list_my_households() as selection
  ),
  '20000000-0000-4000-8000-000000000101|30000000-0000-4000-8000-000000000101|Primary Local Household|owner|1|t|1;20000000-0000-4000-8000-000000000301|30000000-0000-4000-8000-000000000301|Secondary Adult Household|owner|1|f|1',
  'list returns only exact self memberships with active selection first'
);
select is(
  (
    select pg_catalog.count(*)
    from public.list_my_households() as selection
    where selection.household_id =
      '20000000-0000-4000-8000-000000000201'
  ),
  0::bigint,
  'list does not expose an unrelated household'
);
select throws_ok(
  $sql$update public.user_active_households
    set household_id = '20000000-0000-4000-8000-000000000301',
        member_id = '30000000-0000-4000-8000-000000000301'
    where auth_user_id = '00000000-0000-4000-8000-000000000101'$sql$,
  '42501',
  'permission denied for table user_active_households',
  'direct active household update is denied'
);
select throws_ok(
  $sql$select * from public.switch_active_household(
    '20000000-0000-4000-8000-000000000301',
    -1
  )$sql$,
  'KFH02',
  'invalid household selection input',
  'negative expected selection version is rejected'
);
select throws_ok(
  $sql$select * from public.switch_active_household(
    '20000000-0000-4000-8000-000000000201',
    1
  )$sql$,
  'KFH06',
  'household selection target unavailable',
  'cross-account target is generically unavailable'
);
select is(
  (
    select pg_catalog.concat_ws(
      '|',
      switched.household_id,
      switched.member_id,
      switched.selection_version,
      switched.changed
    )
    from public.switch_active_household(
      '20000000-0000-4000-8000-000000000101',
      0
    ) as switched
  ),
  '20000000-0000-4000-8000-000000000101|30000000-0000-4000-8000-000000000101|1|f',
  'same-target retry is an idempotent no-op with the current version'
);
select is(
  (
    select pg_catalog.concat_ws(
      '|',
      switched.household_id,
      switched.member_id,
      switched.selection_version,
      switched.changed
    )
    from public.switch_active_household(
      '20000000-0000-4000-8000-000000000301',
      1
    ) as switched
  ),
  '20000000-0000-4000-8000-000000000301|30000000-0000-4000-8000-000000000301|2|t',
  'exact version switches to the server-derived target member once'
);
select is(
  (
    select pg_catalog.concat_ws(
      '|',
      active_household.household_id,
      active_household.member_id,
      active_household.version
    )
    from public.user_active_households as active_household
    where active_household.auth_user_id =
      '00000000-0000-4000-8000-000000000101'
  ),
  '20000000-0000-4000-8000-000000000301|30000000-0000-4000-8000-000000000301|2',
  'authoritative pointer stores the new household member and version'
);
select is(
  (
    select pg_catalog.string_agg(
      pg_catalog.concat_ws(
        '|',
        selection.household_name,
        selection.is_active,
        selection.selection_version
      ),
      ';'
      order by selection.is_active desc, selection.household_name
    )
    from public.list_my_households() as selection
  ),
  'Secondary Adult Household|t|2;Primary Local Household|f|2',
  'post-switch list gives every own row the new selection version'
);
select throws_ok(
  $sql$select * from public.switch_active_household(
    '20000000-0000-4000-8000-000000000101',
    1
  )$sql$,
  'KFH07',
  'household selection version conflict',
  'stale version cannot switch to a different household'
);
select is(
  (
    select pg_catalog.concat_ws(
      '|',
      switched.selection_version,
      switched.changed
    )
    from public.switch_active_household(
      '20000000-0000-4000-8000-000000000101',
      2
    ) as switched
  ),
  '3|t',
  'fresh version switches back and increments exactly once'
);
select is(
  (
    select pg_catalog.concat_ws(
      '|',
      switched.selection_version,
      switched.changed
    )
    from public.switch_active_household(
      '20000000-0000-4000-8000-000000000101',
      2
    ) as switched
  ),
  '3|f',
  'response-loss retry on the selected target does not increment again'
);
reset role;

select is(
  (
    select pg_catalog.count(*)
    from app_private.active_household_switch_audit_events as event
    where event.auth_user_id =
      '00000000-0000-4000-8000-000000000101'
  ),
  2::bigint,
  'only the two real household changes create audit events'
);
select is(
  (
    select pg_catalog.string_agg(
      pg_catalog.concat_ws(
        '|',
        event.previous_household_id,
        event.next_household_id,
        event.previous_selection_version,
        event.next_selection_version
      ),
      ';'
      order by event.next_selection_version
    )
    from app_private.active_household_switch_audit_events as event
    where event.auth_user_id =
      '00000000-0000-4000-8000-000000000101'
  ),
  '20000000-0000-4000-8000-000000000101|20000000-0000-4000-8000-000000000301|1|2;20000000-0000-4000-8000-000000000301|20000000-0000-4000-8000-000000000101|2|3',
  'private audit records only exact old/new identifiers and versions'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'active_household_switch_audit_events'
      and column_name in (
        'household_name',
        'member_display_name',
        'email',
        'raw_error',
        'payload'
      )
  ),
  'switch audit has no household content or raw-error column'
);

update public.household_members
set removed_at = pg_catalog.statement_timestamp()
where id = '30000000-0000-4000-8000-000000000301';

set local role authenticated;
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select pg_catalog.count(*)
    from public.list_my_households() as selection
    where selection.household_id =
      '20000000-0000-4000-8000-000000000301'
  ),
  0::bigint,
  'removed membership disappears from the self-only list'
);
select throws_ok(
  $sql$select * from public.switch_active_household(
    '20000000-0000-4000-8000-000000000301',
    3
  )$sql$,
  'KFH06',
  'household selection target unavailable',
  'removed membership cannot become active again'
);
reset role;

update public.households
set deleted_at = pg_catalog.statement_timestamp()
where id = '20000000-0000-4000-8000-000000000301';

set local role authenticated;
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select pg_catalog.count(*)
    from public.list_my_households() as selection
  ),
  1::bigint,
  'deleted household remains absent while the current valid membership remains'
);
reset role;

select is(
  (
    select pg_catalog.concat_ws(
      '|',
      active_household.household_id,
      active_household.version
    )
    from public.user_active_households as active_household
    where active_household.auth_user_id =
      '00000000-0000-4000-8000-000000000101'
  ),
  '20000000-0000-4000-8000-000000000101|3',
  'invalid target attempts leave the authoritative selection unchanged'
);

delete from public.user_active_households
where auth_user_id = '00000000-0000-4000-8000-000000000102';

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
      selection.is_active,
      selection.selection_version
    )
    from public.list_my_households() as selection
  ),
  'f|0',
  'membership listing without a selection returns false and version zero'
);
select is(
  (
    select pg_catalog.concat_ws(
      '|',
      switched.selection_version,
      switched.changed
    )
    from public.switch_active_household(
      '20000000-0000-4000-8000-000000000101',
      0
    ) as switched
  ),
  '1|t',
  'first active selection is created from expected version zero'
);
reset role;

select * from finish();
rollback;
