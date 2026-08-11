begin;
set constraints all deferred;

select plan(61);

-- 01-18: schema, least privilege, exact RPC shape, and content-free audit.
select has_function(
  'public',
  'update_one_time_chore',
  array[
    'uuid', 'uuid', 'uuid', 'uuid', 'bigint', 'bigint', 'text', 'text',
    'uuid', 'date', 'time without time zone'
  ],
  'dual-version one-time chore update command exists'
);
select has_function(
  'public',
  'delete_one_time_chore',
  array['uuid', 'uuid', 'uuid', 'uuid', 'bigint', 'bigint'],
  'dual-version one-time chore soft-delete command exists'
);
select has_table(
  'public',
  'one_time_chore_change_events',
  'immutable one-time chore audit table exists'
);
select has_table(
  'app_private',
  'one_time_chore_change_command_requests',
  'private one-time chore idempotency table exists'
);
select has_trigger(
  'public',
  'one_time_chore_change_events',
  'one_time_chore_change_events_immutable',
  'one-time chore audit rejects update and delete'
);
select ok(
  (
    select bool_and(pg_proc.prosecdef)
      and bool_and(pg_proc.proconfig @> array['search_path=""']::text[])
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname in (
        'update_one_time_chore',
        'delete_one_time_chore'
      )
  ),
  'one-time chore commands are security-definer with empty search paths'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.update_one_time_chore(uuid,uuid,uuid,uuid,bigint,bigint,text,text,uuid,date,time without time zone)',
    'execute'
  )
    and has_function_privilege(
      'authenticated',
      'public.delete_one_time_chore(uuid,uuid,uuid,uuid,bigint,bigint)',
      'execute'
    ),
  'authenticated clients can execute mediated one-time chore commands'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.update_one_time_chore(uuid,uuid,uuid,uuid,bigint,bigint,text,text,uuid,date,time without time zone)',
    'execute'
  )
    and not has_function_privilege(
      'anon',
      'public.delete_one_time_chore(uuid,uuid,uuid,uuid,bigint,bigint)',
      'execute'
    ),
  'anonymous clients cannot execute one-time chore commands'
);
select ok(
  has_table_privilege(
    'authenticated',
    'public.one_time_chore_change_events',
    'select'
  )
    and not has_table_privilege(
      'authenticated',
      'public.one_time_chore_change_events',
      'insert,update,delete'
    ),
  'authenticated clients can read scoped audit but cannot forge it'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.one_time_chore_change_command_requests',
    'select'
  )
    and not has_table_privilege(
      'service_role',
      'app_private.one_time_chore_change_command_requests',
      'select'
    ),
  'client and service roles cannot inspect one-time command hashes'
);
select ok(
  (
    select pg_class.relrowsecurity and pg_class.relforcerowsecurity
    from pg_class
    join pg_namespace on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'one_time_chore_change_events'
  ),
  'one-time chore audit enables and forces RLS'
);
select hasnt_column(
  'public',
  'one_time_chore_change_events',
  'title',
  'one-time chore audit does not duplicate titles'
);
select hasnt_column(
  'public',
  'one_time_chore_change_events',
  'description',
  'one-time chore audit does not duplicate notes'
);
select hasnt_column(
  'app_private',
  'one_time_chore_change_command_requests',
  'title',
  'private one-time command state does not store titles'
);
select hasnt_column(
  'app_private',
  'one_time_chore_change_command_requests',
  'description',
  'private one-time command state does not store notes'
);
select is(
  (
    select string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name like 'update_one_time_chore_%'
      and parameter_mode = 'OUT'
  ),
  'household_id,series_id,occurrence_id,revision_id,revision_number,due_local_date,due_local_time,due_at,assignee_member_id,series_version,occurrence_version,changed',
  'update exposes the exact strict metadata result contract'
);
select is(
  (
    select string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name like 'delete_one_time_chore_%'
      and parameter_mode = 'OUT'
  ),
  'household_id,series_id,occurrence_id,status,series_version,occurrence_version,changed',
  'delete exposes the exact strict metadata result contract'
);
select ok(
  exists (
    select 1
    from pg_constraint
    join pg_class on pg_class.oid = pg_constraint.conrelid
    join pg_namespace on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'one_time_chore_change_events'
      and pg_constraint.conname = 'one_time_chore_change_event_shape_ck'
      and pg_constraint.convalidated
  ),
  'audit operation shape is database constrained'
);

-- 19-23: authentication and normalized input validation.
select throws_ok(
  $$
    select * from public.update_one_time_chore(
      '4f000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      '4f100000-0000-4000-8000-000000000001',
      '4f200000-0000-4000-8000-000000000001',
      1,
      1,
      'No auth',
      null,
      '30000000-0000-4000-8000-000000000101',
      date '2026-08-09',
      null
    )
  $$,
  'KFC01',
  'authentication required',
  'update derives caller identity from JWT'
);
select throws_ok(
  $$
    select * from public.delete_one_time_chore(
      '4f000000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      '4f100000-0000-4000-8000-000000000002',
      '4f200000-0000-4000-8000-000000000002',
      1,
      1
    )
  $$,
  'KFC01',
  'authentication required',
  'delete derives caller identity from JWT'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.update_one_time_chore(
      '4f000000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      '4f100000-0000-4000-8000-000000000003',
      '4f200000-0000-4000-8000-000000000003',
      0,
      1,
      'Invalid version',
      null,
      '30000000-0000-4000-8000-000000000101',
      date '2026-08-09',
      null
    )
  $$,
  'KFC02',
  'invalid chore input',
  'update requires positive series and occurrence versions'
);
select throws_ok(
  $$
    select * from public.update_one_time_chore(
      '4f000000-0000-4000-8000-000000000004',
      '20000000-0000-4000-8000-000000000101',
      '4f100000-0000-4000-8000-000000000004',
      '4f200000-0000-4000-8000-000000000004',
      1,
      1,
      'Invalid precision',
      null,
      '30000000-0000-4000-8000-000000000101',
      date '2026-08-09',
      time '18:30:01'
    )
  $$,
  'KFC02',
  'invalid chore input',
  'update accepts only minute-precision local time'
);
select throws_ok(
  $$
    select * from public.update_one_time_chore(
      '4f000000-0000-4000-8000-000000000005',
      '20000000-0000-4000-8000-000000000101',
      '4f100000-0000-4000-8000-000000000005',
      '4f200000-0000-4000-8000-000000000005',
      1,
      1,
      '   ',
      null,
      '30000000-0000-4000-8000-000000000101',
      date '2026-08-09',
      null
    )
  $$,
  'KFC02',
  'invalid chore input',
  'update rejects a blank normalized title'
);

-- 24-26: deterministic one-time, repeating, and completed fixtures.
select set_config(
  'kinflow.test.one_time_today',
  (statement_timestamp() at time zone 'Asia/Seoul')::date::text,
  true
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '4f300000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'One-time lifecycle original',
      'Original notes',
      '30000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.one_time_today')::date,
      time '08:00'
    )
  $$,
  'owner creates the one-time update fixture'
);
select set_config(
  'kinflow.test.one_time_series',
  (
    select series.id::text
    from public.chore_series as series
    where series.title = 'One-time lifecycle original'
  ),
  true
);
select set_config(
  'kinflow.test.one_time_occurrence',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.one_time_series')::uuid
  ),
  true
);
select set_config(
  'kinflow.test.one_time_revision_1',
  (
    select series.active_revision_id::text
    from public.chore_series as series
    where series.id = current_setting('kinflow.test.one_time_series')::uuid
  ),
  true
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '4f300000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      'One-time lifecycle repeating guard',
      null,
      '30000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.one_time_today')::date,
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
    )
  $$,
  'owner creates a repeating wrong-type fixture'
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '4f300000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      'One-time lifecycle delete target',
      null,
      '30000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.one_time_today')::date + 1,
      null
    )
  $$,
  'owner creates the one-time delete fixture'
);
select set_config(
  'kinflow.test.one_time_delete_series',
  (
    select series.id::text
    from public.chore_series as series
    where series.title = 'One-time lifecycle delete target'
  ),
  true
);
select set_config(
  'kinflow.test.one_time_delete_occurrence',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.one_time_delete_series')::uuid
  ),
  true
);

-- 27-38: a plain Member updates all fields through an immutable revision.
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select concat_ws(
      ':',
      result.revision_number,
      result.series_version,
      result.occurrence_version,
      result.due_local_date::text,
      result.due_local_time::text,
      result.assignee_member_id::text,
      result.changed
    )
    from public.update_one_time_chore(
      '4f400000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.one_time_series')::uuid,
      current_setting('kinflow.test.one_time_occurrence')::uuid,
      1,
      1,
      '  One-time lifecycle updated  ',
      '  Updated notes  ',
      '30000000-0000-4000-8000-000000000102',
      current_setting('kinflow.test.one_time_today')::date + 2,
      time '18:45'
    ) as result
  ),
  '2:2:2:'
    || (current_setting('kinflow.test.one_time_today')::date + 2)::text
    || ':18:45:00:30000000-0000-4000-8000-000000000102:t',
  'active plain Member can atomically update every editable one-time field'
);
select set_config(
  'kinflow.test.one_time_revision_2',
  (
    select series.active_revision_id::text
    from public.chore_series as series
    where series.id = current_setting('kinflow.test.one_time_series')::uuid
  ),
  true
);
select is(
  (
    select concat_ws(
      ':',
      series.title,
      series.description,
      series.version,
      revision.revision_number,
      revision.title,
      revision.description,
      revision.default_assignee_member_id::text,
      revision.due_local_time::text,
      revision.recurrence_rule->>'type'
    )
    from public.chore_series as series
    join public.chore_series_revisions as revision
      on revision.id = series.active_revision_id
    where series.id = current_setting('kinflow.test.one_time_series')::uuid
  ),
  'One-time lifecycle updated:Updated notes:2:2:One-time lifecycle updated:'
    || 'Updated notes:30000000-0000-4000-8000-000000000102:18:45:00:once',
  'series points at the normalized next immutable one-time revision'
);
select is(
  (
    select concat_ws(
      ':',
      occurrence.id::text,
      occurrence.status::text,
      occurrence.version,
      occurrence.recurrence_local_date::text,
      occurrence.due_local_date::text,
      occurrence.assignee_member_id::text,
      occurrence.revision_id::text,
      to_char(occurrence.due_at at time zone 'Asia/Seoul', 'HH24:MI')
    )
    from public.chore_occurrences as occurrence
    where occurrence.id =
      current_setting('kinflow.test.one_time_occurrence')::uuid
  ),
  current_setting('kinflow.test.one_time_occurrence')
    || ':scheduled:2:'
    || current_setting('kinflow.test.one_time_today')
    || ':'
    || (current_setting('kinflow.test.one_time_today')::date + 2)::text
    || ':30000000-0000-4000-8000-000000000102:'
    || current_setting('kinflow.test.one_time_revision_2')
    || ':18:45',
  'stable occurrence keeps its source identity while adopting edited due intent'
);
select is(
  (
    select concat_ws(
      ':', revision.revision_number, revision.title, revision.description,
      revision.default_assignee_member_id::text,
      revision.due_local_time::text
    )
    from public.chore_series_revisions as revision
    where revision.id =
      current_setting('kinflow.test.one_time_revision_1')::uuid
  ),
  '1:One-time lifecycle original:Original notes:'
    || '30000000-0000-4000-8000-000000000101:08:00:00',
  'previous one-time revision content remains unchanged'
);
select is(
  (
    select concat_ws(
      ':', event.operation, event.series_version,
      event.occurrence_version, event.previous_revision_id::text,
      event.new_revision_id::text, event.previous_due_local_date::text,
      event.new_due_local_date::text,
      event.previous_assignee_member_id::text,
      event.new_assignee_member_id::text,
      event.actor_member_id::text
    )
    from public.one_time_chore_change_events as event
    where event.correlation_id =
      '4f400000-0000-4000-8000-000000000001'
  ),
  'updated:2:2:'
    || current_setting('kinflow.test.one_time_revision_1')
    || ':' || current_setting('kinflow.test.one_time_revision_2')
    || ':' || current_setting('kinflow.test.one_time_today')
    || ':'
    || (current_setting('kinflow.test.one_time_today')::date + 2)::text
    || ':30000000-0000-4000-8000-000000000101:'
    || '30000000-0000-4000-8000-000000000102:'
    || '30000000-0000-4000-8000-000000000102',
  'update audit records only exact metadata and the authenticated Member actor'
);
reset role;
select is(
  (
    select count(*)::integer
    from app_private.one_time_chore_change_command_requests as request
    where request.authenticated_user_id =
      '00000000-0000-4000-8000-000000000102'
      and request.idempotency_key =
        '4f400000-0000-4000-8000-000000000001'
  ),
  1,
  'update stores one private idempotency record'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select concat_ws(
      ':', result.revision_id::text, result.series_version,
      result.occurrence_version, result.changed
    )
    from public.update_one_time_chore(
      '4f400000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.one_time_series')::uuid,
      current_setting('kinflow.test.one_time_occurrence')::uuid,
      1,
      1,
      '  One-time lifecycle updated  ',
      '  Updated notes  ',
      '30000000-0000-4000-8000-000000000102',
      current_setting('kinflow.test.one_time_today')::date + 2,
      time '18:45'
    ) as result
  ),
  current_setting('kinflow.test.one_time_revision_2') || ':2:2:f',
  'same update request replays exact metadata with changed false'
);
select is(
  (
    select concat_ws(
      ':',
      count(*) filter (
        where revision.series_id =
          current_setting('kinflow.test.one_time_series')::uuid
      ),
      (
        select count(*)
        from public.one_time_chore_change_events as event
        where event.series_id =
          current_setting('kinflow.test.one_time_series')::uuid
      )
    )
    from public.chore_series_revisions as revision
  ),
  '2:1',
  'idempotent replay creates no duplicate revision or audit event'
);
select throws_ok(
  $$
    select * from public.update_one_time_chore(
      '4f400000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.one_time_series')::uuid,
      current_setting('kinflow.test.one_time_occurrence')::uuid,
      1,
      1,
      'Payload collision',
      'Updated notes',
      '30000000-0000-4000-8000-000000000102',
      current_setting('kinflow.test.one_time_today')::date + 2,
      time '18:45'
    )
  $$,
  'KFC04',
  'idempotency key reused with different chore input',
  'same update key with a changed payload is rejected'
);
select throws_ok(
  $$
    select * from public.delete_one_time_chore(
      '4f400000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.one_time_series')::uuid,
      current_setting('kinflow.test.one_time_occurrence')::uuid,
      2,
      2
    )
  $$,
  'KFC04',
  'idempotency key reused with different chore input',
  'update key cannot be reused for delete'
);
select throws_ok(
  $$
    select * from public.update_one_time_chore(
      '4f400000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.one_time_series')::uuid,
      current_setting('kinflow.test.one_time_occurrence')::uuid,
      2,
      2,
      'One-time lifecycle updated',
      'Updated notes',
      '30000000-0000-4000-8000-000000000102',
      current_setting('kinflow.test.one_time_today')::date + 2,
      time '18:45'
    )
  $$,
  'KFC06',
  'chore transition not allowed',
  'normalized no-op update is rejected without a new revision'
);
select ok(
  not exists (
    select 1
    from public.get_today_chores_v2(
      '20000000-0000-4000-8000-000000000101'
    ) as today
    where today.occurrence_id =
      current_setting('kinflow.test.one_time_occurrence')::uuid
  )
    and exists (
      select 1
      from public.get_chore_list(
        '20000000-0000-4000-8000-000000000101',
        'upcoming',
        null,
        30,
        null
      ) as item
      where item.occurrence_id =
        current_setting('kinflow.test.one_time_occurrence')::uuid
        and item.title = 'One-time lifecycle updated'
        and item.series_version = 2
        and item.version = 2
    ),
  'authoritative lists move the edited occurrence and expose both new versions'
);
reset role;
select is(
  (
    select count(*)::integer
    from app_private.chore_notification_outbox as event
    where event.aggregate_id =
      current_setting('kinflow.test.one_time_occurrence')::uuid
      and event.aggregate_version = 2
  ),
  2,
  'due and assignee edits emit the existing content-free notification hooks'
);

-- 39-50: scope, type, state, assignee, and stale-version rejection.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select throws_ok(
  $$
    select * from public.delete_one_time_chore(
      '4f500000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.one_time_delete_series')::uuid,
      current_setting('kinflow.test.one_time_delete_occurrence')::uuid,
      2,
      1
    )
  $$,
  'KFC05',
  'chore version conflict',
  'delete rejects a stale series version'
);
select throws_ok(
  $$
    select * from public.delete_one_time_chore(
      '4f500000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.one_time_delete_series')::uuid,
      current_setting('kinflow.test.one_time_delete_occurrence')::uuid,
      1,
      2
    )
  $$,
  'KFC05',
  'chore version conflict',
  'delete rejects a stale occurrence version'
);
select throws_ok(
  $$
    select * from public.delete_one_time_chore(
      '4f500000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000201',
      current_setting('kinflow.test.one_time_delete_series')::uuid,
      current_setting('kinflow.test.one_time_delete_occurrence')::uuid,
      1,
      1
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'cross-household command scope is rejected'
);
select throws_ok(
  $$
    select * from public.update_one_time_chore(
      '4f500000-0000-4000-8000-000000000004',
      '20000000-0000-4000-8000-000000000101',
      (
        select series.id
        from public.chore_series as series
        where series.title = 'One-time lifecycle repeating guard'
      ),
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'One-time lifecycle repeating guard'
      ),
      1,
      1,
      'Wrong type update',
      null,
      '30000000-0000-4000-8000-000000000102',
      current_setting('kinflow.test.one_time_today')::date,
      null
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'repeating series cannot enter the one-time update command'
);
select throws_ok(
  $$
    select * from public.delete_one_time_chore(
      '4f500000-0000-4000-8000-000000000005',
      '20000000-0000-4000-8000-000000000101',
      (
        select series.id
        from public.chore_series as series
        where series.title = 'One-time lifecycle repeating guard'
      ),
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'One-time lifecycle repeating guard'
      ),
      1,
      1
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'repeating series cannot enter the one-time delete command'
);

reset role;
update public.household_members
set removed_at = statement_timestamp()
where id = '30000000-0000-4000-8000-000000000102';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.update_one_time_chore(
      '4f500000-0000-4000-8000-000000000006',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.one_time_delete_series')::uuid,
      current_setting('kinflow.test.one_time_delete_occurrence')::uuid,
      1,
      1,
      'Inactive assignee rejected',
      null,
      '30000000-0000-4000-8000-000000000102',
      current_setting('kinflow.test.one_time_today')::date + 1,
      null
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'removed household member cannot become the edited assignee'
);
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
    select * from public.update_one_time_chore(
      '4f500000-0000-4000-8000-000000000007',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.one_time_delete_series')::uuid,
      current_setting('kinflow.test.one_time_delete_occurrence')::uuid,
      1,
      1,
      'Outsider rejected',
      null,
      '30000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.one_time_today')::date + 1,
      null
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'active member of another household cannot update the target'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '4f500000-0000-4000-8000-000000000008',
      '20000000-0000-4000-8000-000000000101',
      'One-time completed guard',
      null,
      '30000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.one_time_today')::date,
      null
    )
  $$,
  'owner creates a completed-state guard fixture'
);
select lives_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '4f500000-0000-4000-8000-000000000009',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'One-time completed guard'
      ),
      1,
      true
    )
  $$,
  'one-time guard fixture is completed through the existing command'
);
select throws_ok(
  $$
    select * from public.update_one_time_chore(
      '4f500000-0000-4000-8000-000000000010',
      '20000000-0000-4000-8000-000000000101',
      (
        select series.id
        from public.chore_series as series
        where series.title = 'One-time completed guard'
      ),
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'One-time completed guard'
      ),
      1,
      2,
      'Completed update rejected',
      null,
      '30000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.one_time_today')::date,
      null
    )
  $$,
  'KFC06',
  'chore transition not allowed',
  'completed one-time occurrence must be reopened before edit'
);
select throws_ok(
  $$
    select * from public.delete_one_time_chore(
      '4f500000-0000-4000-8000-000000000011',
      '20000000-0000-4000-8000-000000000101',
      (
        select series.id
        from public.chore_series as series
        where series.title = 'One-time completed guard'
      ),
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'One-time completed guard'
      ),
      1,
      2
    )
  $$,
  'KFC06',
  'chore transition not allowed',
  'completed one-time occurrence must be reopened before delete'
);

-- 51-61: plain Member soft-delete, replay, visibility, RLS, and immutability.
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select concat_ws(
      ':', result.status, result.series_version,
      result.occurrence_version, result.changed
    )
    from public.delete_one_time_chore(
      '4f600000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.one_time_delete_series')::uuid,
      current_setting('kinflow.test.one_time_delete_occurrence')::uuid,
      1,
      1
    ) as result
  ),
  'cancelled:2:2:t',
  'active plain Member can soft-delete a scheduled one-time chore'
);
reset role;
select is(
  (
    select concat_ws(
      ':', series.deleted_at is not null, series.version,
      occurrence.status::text, occurrence.version,
      count(revision.id)
    )
    from public.chore_series as series
    join public.chore_occurrences as occurrence
      on occurrence.series_id = series.id
    join public.chore_series_revisions as revision
      on revision.series_id = series.id
    where series.id =
      current_setting('kinflow.test.one_time_delete_series')::uuid
    group by series.deleted_at, series.version,
      occurrence.status, occurrence.version
  ),
  't:2:cancelled:2:1',
  'delete preserves one revision and occurrence while soft-deleting the series'
);
select is(
  (
    select concat_ws(
      ':', event.operation, event.new_revision_id is null,
      event.new_due_local_date is null,
      event.series_version, event.occurrence_version,
      event.actor_member_id::text
    )
    from public.one_time_chore_change_events as event
    where event.correlation_id =
      '4f600000-0000-4000-8000-000000000001'
  ),
  'deleted:t:t:2:2:30000000-0000-4000-8000-000000000102',
  'delete appends a content-free audit record with the Member actor'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select concat_ws(
      ':', result.status, result.series_version,
      result.occurrence_version, result.changed
    )
    from public.delete_one_time_chore(
      '4f600000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.one_time_delete_series')::uuid,
      current_setting('kinflow.test.one_time_delete_occurrence')::uuid,
      1,
      1
    ) as result
  ),
  'cancelled:2:2:f',
  'same delete request replays after soft deletion with changed false'
);
select ok(
  not exists (
    select 1
    from public.get_chore_list(
      '20000000-0000-4000-8000-000000000101',
      'today',
      null,
      100,
      null
    ) as item
    where item.occurrence_id =
      current_setting('kinflow.test.one_time_delete_occurrence')::uuid
  )
    and not exists (
      select 1
      from public.get_chore_list(
        '20000000-0000-4000-8000-000000000101',
        'upcoming',
        null,
        100,
        null
      ) as item
      where item.occurrence_id =
        current_setting('kinflow.test.one_time_delete_occurrence')::uuid
    ),
  'soft-deleted cancelled occurrence is absent from active list views'
);
select throws_ok(
  $$insert into public.one_time_chore_change_events default values$$,
  '42501',
  null,
  'authenticated client cannot forge one-time chore audit rows'
);
select throws_ok(
  $$select * from app_private.one_time_chore_change_command_requests$$,
  '42501',
  null,
  'authenticated client cannot inspect private one-time command state'
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
    select count(*)::integer
    from public.one_time_chore_change_events
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  0,
  'RLS hides one-time chore audit from another household'
);

reset role;
select throws_ok(
  $$
    update public.one_time_chore_change_events
    set operation = operation
    where correlation_id = '4f400000-0000-4000-8000-000000000001'
  $$,
  '55000',
  'one-time chore change events are immutable',
  'audit update is rejected even by a privileged repair session'
);
select throws_ok(
  $$
    delete from public.one_time_chore_change_events
    where correlation_id = '4f400000-0000-4000-8000-000000000001'
  $$,
  '55000',
  'one-time chore change events are immutable',
  'audit delete is rejected even by a privileged repair session'
);
select is(
  (
    select count(*)::integer
    from public.one_time_chore_change_events
    where series_id = current_setting('kinflow.test.one_time_delete_series')::uuid
  ),
  1,
  'delete replay and denied tampering leave one durable audit row'
);

select * from finish();
rollback;
