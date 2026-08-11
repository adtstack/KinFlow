begin;
set constraints all deferred;

select plan(47);

-- 01-12: schema, grants, exact projections, and content-free reuse.
select has_function(
  'public',
  'get_deleted_one_time_chores',
  array['uuid', 'integer', 'text'],
  'bounded one-time chore trash projection exists'
); -- 01
select has_function(
  'public',
  'restore_one_time_chore',
  array['uuid', 'uuid', 'uuid', 'uuid', 'bigint', 'bigint'],
  'dual-version one-time chore restore command exists'
); -- 02
select ok(
  (
    select pg_catalog.bool_and(pg_proc.prosecdef)
      and pg_catalog.bool_and(
        pg_proc.proconfig @> array['search_path=""']::text[]
      )
    from pg_catalog.pg_proc
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname in (
        'get_deleted_one_time_chores',
        'restore_one_time_chore'
      )
  ),
  'trash RPCs are security-definer with empty search paths'
); -- 03
select ok(
  has_function_privilege(
    'authenticated',
    'public.get_deleted_one_time_chores(uuid,integer,text)',
    'execute'
  )
    and has_function_privilege(
      'authenticated',
      'public.restore_one_time_chore(uuid,uuid,uuid,uuid,bigint,bigint)',
      'execute'
    ),
  'authenticated clients can read trash and execute mediated restore'
); -- 04
select ok(
  not has_function_privilege(
    'anon',
    'public.get_deleted_one_time_chores(uuid,integer,text)',
    'execute'
  )
    and not has_function_privilege(
      'anon',
      'public.restore_one_time_chore(uuid,uuid,uuid,uuid,bigint,bigint)',
      'execute'
    ),
  'anonymous clients cannot read trash or restore chores'
); -- 05
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    join pg_catalog.pg_class
      on pg_class.oid = pg_constraint.conrelid
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'app_private'
      and pg_class.relname = 'one_time_chore_change_command_requests'
      and pg_constraint.conname =
        'one_time_chore_change_command_requests_operation_check'
      and pg_catalog.strpos(
        pg_catalog.pg_get_constraintdef(pg_constraint.oid),
        'restored'
      ) > 0
  ),
  'existing private command namespace admits exact restored operations'
); -- 06
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    join pg_catalog.pg_class
      on pg_class.oid = pg_constraint.conrelid
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'one_time_chore_change_events'
      and pg_constraint.conname = 'one_time_chore_change_event_shape_ck'
      and pg_catalog.strpos(
        pg_catalog.pg_get_constraintdef(pg_constraint.oid),
        'restored'
      ) > 0
      and pg_constraint.convalidated
  ),
  'restored audit shape is database constrained'
); -- 07
select hasnt_column(
  'public',
  'one_time_chore_change_events',
  'title',
  'restored audit still does not duplicate chore titles'
); -- 08
select hasnt_column(
  'app_private',
  'one_time_chore_change_command_requests',
  'description',
  'restore idempotency state still does not store chore notes'
); -- 09
select is(
  (
    select pg_catalog.string_agg(
      parameter_name,
      ',' order by ordinal_position
    )
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name like 'get_deleted_one_time_chores_%'
      and parameter_mode = 'OUT'
  ),
  'household_id,household_timezone,generated_at,page_limit,has_more,'
    || 'page_cursor,occurrence_id,series_id,title,description,'
    || 'assignee_member_id,assignee_display_name,due_local_date,'
    || 'due_local_time,due_at,deleted_at,series_version,'
    || 'occurrence_version',
  'trash read exposes the exact 18-field contract'
); -- 10
select is(
  (
    select pg_catalog.string_agg(
      parameter_name,
      ',' order by ordinal_position
    )
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name like 'restore_one_time_chore_%'
      and parameter_mode = 'OUT'
  ),
  'household_id,series_id,occurrence_id,status,series_version,'
    || 'occurrence_version,changed',
  'restore exposes the exact strict metadata result contract'
); -- 11
select has_index(
  'public',
  'chore_series',
  'chore_series_deleted_list_idx',
  'trash ordering has a partial household deletion index'
); -- 12

-- 13-16: authentication and bounded input.
select throws_ok(
  $$
    select * from public.get_deleted_one_time_chores(
      '20000000-0000-4000-8000-000000000101',
      30,
      null
    )
  $$,
  'KFC01',
  'authentication required',
  'trash read derives caller identity from JWT'
); -- 13
select throws_ok(
  $$
    select * from public.restore_one_time_chore(
      '4fa00000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      '4fa10000-0000-4000-8000-000000000001',
      '4fa20000-0000-4000-8000-000000000001',
      1,
      1
    )
  $$,
  'KFC01',
  'authentication required',
  'restore derives caller identity from JWT'
); -- 14

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.get_deleted_one_time_chores(
      '20000000-0000-4000-8000-000000000101',
      0,
      null
    )
  $$,
  'KFC02',
  'invalid chore input',
  'trash read enforces bounded page size'
); -- 15
select throws_ok(
  $$
    select * from public.get_deleted_one_time_chores(
      '20000000-0000-4000-8000-000000000101',
      30,
      'not-a-cursor'
    )
  $$,
  'KFC02',
  'invalid chore input',
  'trash read rejects malformed cursors'
); -- 16

-- 17-25: two deterministic deleted fixtures and exact pagination.
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '4fa30000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Trash earlier item',
      'Preserved earlier notes',
      '30000000-0000-4000-8000-000000000102',
      (pg_catalog.statement_timestamp() at time zone 'Asia/Seoul')::date + 1,
      time '08:15'
    )
  $$,
  'owner creates the first trash fixture'
); -- 17
select set_config(
  'kinflow.test.trash_series_a',
  (
    select series.id::text
    from public.chore_series as series
    where series.title = 'Trash earlier item'
  ),
  true
);
select set_config(
  'kinflow.test.trash_occurrence_a',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.trash_series_a')::uuid
  ),
  true
);
select set_config(
  'kinflow.test.trash_revision_a',
  (
    select series.active_revision_id::text
    from public.chore_series as series
    where series.id = current_setting('kinflow.test.trash_series_a')::uuid
  ),
  true
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '4fa30000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      'Trash newer item',
      null,
      '30000000-0000-4000-8000-000000000101',
      (pg_catalog.statement_timestamp() at time zone 'Asia/Seoul')::date,
      null
    )
  $$,
  'owner creates the second trash fixture'
); -- 18
select set_config(
  'kinflow.test.trash_series_b',
  (
    select series.id::text
    from public.chore_series as series
    where series.title = 'Trash newer item'
  ),
  true
);
select set_config(
  'kinflow.test.trash_occurrence_b',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.trash_series_b')::uuid
  ),
  true
);
select set_config(
  'kinflow.test.trash_revision_b',
  (
    select series.active_revision_id::text
    from public.chore_series as series
    where series.id = current_setting('kinflow.test.trash_series_b')::uuid
  ),
  true
);
select lives_ok(
  $$
    select * from public.delete_one_time_chore(
      '4fa40000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.trash_series_a')::uuid,
      current_setting('kinflow.test.trash_occurrence_a')::uuid,
      1,
      1
    )
  $$,
  'first one-time chore is soft-deleted through the existing command'
); -- 19
select lives_ok(
  $$
    select * from public.delete_one_time_chore(
      '4fa40000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.trash_series_b')::uuid,
      current_setting('kinflow.test.trash_occurrence_b')::uuid,
      1,
      1
    )
  $$,
  'second one-time chore is soft-deleted through the existing command'
); -- 20
select is(
  (
    select pg_catalog.string_agg(item.title, '|' order by item.deleted_at desc)
    from public.get_deleted_one_time_chores(
      '20000000-0000-4000-8000-000000000101',
      30,
      null
    ) as item
    where item.occurrence_id in (
      current_setting('kinflow.test.trash_occurrence_a')::uuid,
      current_setting('kinflow.test.trash_occurrence_b')::uuid
    )
  ),
  'Trash newer item|Trash earlier item',
  'trash projection orders newest deletion first'
); -- 21
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      item.title,
      item.description,
      item.assignee_member_id::text,
      item.due_local_time::text,
      item.series_version,
      item.occurrence_version,
      item.deleted_at is not null
    )
    from public.get_deleted_one_time_chores(
      '20000000-0000-4000-8000-000000000101',
      30,
      null
    ) as item
    where item.occurrence_id =
      current_setting('kinflow.test.trash_occurrence_a')::uuid
  ),
  'Trash earlier item:Preserved earlier notes:'
    || '30000000-0000-4000-8000-000000000102:08:15:00:2:2:t',
  'trash projection preserves exact content and scheduling intent'
); -- 22
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      pg_catalog.count(*),
      pg_catalog.bool_and(item.page_limit = 1),
      pg_catalog.bool_and(item.has_more),
      pg_catalog.bool_and(item.page_cursor is not null),
      pg_catalog.bool_and(item.title = 'Trash newer item')
    )
    from public.get_deleted_one_time_chores(
      '20000000-0000-4000-8000-000000000101',
      1,
      null
    ) as item
  ),
  '1:t:t:t:t',
  'first trash page returns exact bounded metadata and one item'
); -- 23
select set_config(
  'kinflow.test.trash_cursor',
  (
    select item.page_cursor
    from public.get_deleted_one_time_chores(
      '20000000-0000-4000-8000-000000000101',
      1,
      null
    ) as item
  ),
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      item.title,
      item.has_more,
      item.page_cursor is null
    )
    from public.get_deleted_one_time_chores(
      '20000000-0000-4000-8000-000000000101',
      1,
      current_setting('kinflow.test.trash_cursor')
    ) as item
  ),
  'Trash earlier item:f:t',
  'opaque cursor returns the deterministic second trash page'
); -- 24
select throws_ok(
  $$
    select * from public.get_deleted_one_time_chores(
      '20000000-0000-4000-8000-000000000201',
      30,
      null
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'trash read hides another household'
); -- 25

-- 26-38: restore, exact replay, and state/type failures.
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      result.status,
      result.series_version,
      result.occurrence_version,
      result.changed
    )
    from public.restore_one_time_chore(
      '4fa50000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.trash_series_b')::uuid,
      current_setting('kinflow.test.trash_occurrence_b')::uuid,
      2,
      2
    ) as result
  ),
  'scheduled:3:3:t',
  'active member restores a deleted one-time chore with dual versions'
); -- 26
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      series.deleted_at is null,
      series.active_revision_id::text,
      series.version,
      occurrence.status::text,
      occurrence.version,
      occurrence.assignee_member_id::text,
      occurrence.due_at is null
    )
    from public.chore_series as series
    join public.chore_occurrences as occurrence
      on occurrence.series_id = series.id
    where series.id = current_setting('kinflow.test.trash_series_b')::uuid
  ),
  't:' || current_setting('kinflow.test.trash_revision_b')
    || ':3:scheduled:3:30000000-0000-4000-8000-000000000101:t',
  'restore preserves revision assignee and due intent while reactivating rows'
); -- 27
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      event.operation,
      event.previous_revision_id = event.new_revision_id,
      event.previous_due_local_date = event.new_due_local_date,
      event.previous_assignee_member_id = event.new_assignee_member_id,
      event.series_version,
      event.occurrence_version,
      event.actor_member_id::text
    )
    from public.one_time_chore_change_events as event
    where event.correlation_id =
      '4fa50000-0000-4000-8000-000000000001'
  ),
  'restored:t:t:t:3:3:30000000-0000-4000-8000-000000000101',
  'restore appends exact content-free preserved-intent audit metadata'
); -- 28
select ok(
  not exists (
    select 1
    from public.get_deleted_one_time_chores(
      '20000000-0000-4000-8000-000000000101',
      30,
      null
    ) as item
    where item.occurrence_id =
      current_setting('kinflow.test.trash_occurrence_b')::uuid
  )
    and exists (
      select 1
      from public.get_deleted_one_time_chores(
        '20000000-0000-4000-8000-000000000101',
        30,
        null
      ) as item
      where item.occurrence_id =
        current_setting('kinflow.test.trash_occurrence_a')::uuid
    ),
  'restored item leaves trash while other deleted items remain'
); -- 29
select ok(
  exists (
    select 1
    from public.get_today_chores_v2(
      '20000000-0000-4000-8000-000000000101'
    ) as today
    where today.occurrence_id =
      current_setting('kinflow.test.trash_occurrence_b')::uuid
      and today.status = 'scheduled'
      and today.version = 3
  ),
  'restored due-today chore reappears in authoritative Today'
); -- 30
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      result.series_version,
      result.occurrence_version,
      result.changed
    )
    from public.restore_one_time_chore(
      '4fa50000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.trash_series_b')::uuid,
      current_setting('kinflow.test.trash_occurrence_b')::uuid,
      2,
      2
    ) as result
  ),
  '3:3:f',
  'same-key same-input restore replays exact metadata'
); -- 31
select is(
  (
    select pg_catalog.count(*)::integer
    from public.one_time_chore_change_events as event
    where event.correlation_id =
      '4fa50000-0000-4000-8000-000000000001'
  ),
  1,
  'restore replay emits no duplicate audit event'
); -- 32
select throws_ok(
  $$
    select * from public.restore_one_time_chore(
      '4fa50000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.trash_series_b')::uuid,
      current_setting('kinflow.test.trash_occurrence_b')::uuid,
      3,
      3
    )
  $$,
  'KFC04',
  'idempotency key reused with different chore input',
  'same restore key with a changed request is rejected'
); -- 33
select throws_ok(
  $$
    select * from public.restore_one_time_chore(
      '4fa40000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.trash_series_a')::uuid,
      current_setting('kinflow.test.trash_occurrence_a')::uuid,
      2,
      2
    )
  $$,
  'KFC04',
  'idempotency key reused with different chore input',
  'delete key cannot be reused for restore'
); -- 34
select throws_ok(
  $$
    select * from public.restore_one_time_chore(
      '4fa50000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.trash_series_a')::uuid,
      current_setting('kinflow.test.trash_occurrence_a')::uuid,
      1,
      2
    )
  $$,
  'KFC05',
  'chore version conflict',
  'restore rejects either stale dual version'
); -- 35
select throws_ok(
  $$
    select * from public.restore_one_time_chore(
      '4fa50000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.trash_series_b')::uuid,
      current_setting('kinflow.test.trash_occurrence_b')::uuid,
      3,
      3
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'an active non-deleted one-time chore cannot enter restore'
); -- 36
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '4fa30000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      'Trash repeating guard',
      null,
      '30000000-0000-4000-8000-000000000101',
      (pg_catalog.statement_timestamp() at time zone 'Asia/Seoul')::date,
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
    )
  $$,
  'owner creates a repeating restore guard fixture'
); -- 37
select throws_ok(
  $$
    select * from public.restore_one_time_chore(
      '4fa50000-0000-4000-8000-000000000004',
      '20000000-0000-4000-8000-000000000101',
      (
        select series.id
        from public.chore_series as series
        where series.title = 'Trash repeating guard'
      ),
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Trash repeating guard'
      ),
      1,
      1
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'repeating series cannot enter one-time restore'
); -- 38

-- 39-47: inactive scope, runtime switch, immutable boundaries, and empty trash.
reset role;
update public.household_members
set removed_at = pg_catalog.statement_timestamp()
where id = '30000000-0000-4000-8000-000000000102';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.restore_one_time_chore(
      '4fa50000-0000-4000-8000-000000000005',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.trash_series_a')::uuid,
      current_setting('kinflow.test.trash_occurrence_a')::uuid,
      2,
      2
    )
  $$,
  'KFC06',
  'chore transition not allowed',
  'restore refuses to silently reassign a removed original assignee'
); -- 39
reset role;
update public.household_members
set removed_at = null
where id = '30000000-0000-4000-8000-000000000102';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$
    select * from public.restore_one_time_chore(
      '4fa50000-0000-4000-8000-000000000006',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.trash_series_a')::uuid,
      current_setting('kinflow.test.trash_occurrence_a')::uuid,
      2,
      2
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'another household member cannot restore the target'
); -- 40
reset role;
update app_private.app_runtime_feature_policies
set mutations_enabled = false
where environment = 'prod'
  and platform = 'android'
  and feature = 'chores';
select set_config('app.runtime_policy_checked', '', true);
select set_config('app.runtime_policy_feature_checked_chores', '', true);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select * from public.get_deleted_one_time_chores(
      '20000000-0000-4000-8000-000000000101',
      30,
      null
    )
  $$,
  'disabled chores mutation policy preserves trash reads'
); -- 41
select throws_ok(
  $$
    select * from public.restore_one_time_chore(
      '4fa50000-0000-4000-8000-000000000007',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.trash_series_a')::uuid,
      current_setting('kinflow.test.trash_occurrence_a')::uuid,
      2,
      2
    )
  $$,
  'KFR06',
  'client feature disabled',
  'disabled chores mutation policy remains authoritative for restore'
); -- 42
select throws_ok(
  $$
    update public.chore_series
    set deleted_at = null
    where id = current_setting('kinflow.test.trash_series_a')::uuid
  $$,
  '42501',
  'permission denied for table chore_series',
  'authenticated clients cannot bypass restore with direct table mutation'
); -- 43
reset role;
update app_private.app_runtime_feature_policies
set mutations_enabled = true
where environment = 'prod'
  and platform = 'android'
  and feature = 'chores';
select set_config('app.runtime_policy_checked', '', true);
select set_config('app.runtime_policy_feature_checked_chores', '', true);
select throws_ok(
  $$
    update public.one_time_chore_change_events
    set operation = 'deleted'
    where correlation_id = '4fa50000-0000-4000-8000-000000000001'
  $$,
  '55000',
  'one-time chore change events are immutable',
  'restored audit events remain immutable'
); -- 44
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.status, result.series_version,
      result.occurrence_version, result.changed
    )
    from public.restore_one_time_chore(
      '4fa50000-0000-4000-8000-000000000008',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.trash_series_a')::uuid,
      current_setting('kinflow.test.trash_occurrence_a')::uuid,
      2,
      2
    ) as result
  ),
  'scheduled:3:3:t',
  're-enabled exact feature allows the remaining restore'
); -- 45
select ok(
  (
    select pg_catalog.count(*) = 1
      and pg_catalog.count(item.occurrence_id) = 0
      and pg_catalog.bool_and(not item.has_more)
      and pg_catalog.bool_and(item.page_cursor is null)
    from public.get_deleted_one_time_chores(
      '20000000-0000-4000-8000-000000000101',
      30,
      null
    ) as item
  ),
  'empty trash returns one exact metadata-only row'
); -- 46
reset role;
update public.household_members
set removed_at = pg_catalog.statement_timestamp()
where id = '30000000-0000-4000-8000-000000000102';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select throws_ok(
  $$
    select * from public.get_deleted_one_time_chores(
      '20000000-0000-4000-8000-000000000101',
      30,
      null
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'removed household member cannot read former trash content'
); -- 47

select * from finish();
rollback;
