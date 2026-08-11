begin;
set constraints all deferred;

select plan(78);

-- Exact mediated read contract and supporting indexes.
select has_function(
  'public',
  'get_chore_list',
  array['uuid', 'text', 'uuid', 'integer', 'text'],
  'bounded chore list function exists'
);
select ok(
  (
    select pg_proc.prosecdef
      and pg_proc.provolatile = 's'
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'get_chore_list'
  ),
  'chore list is stable security-definer with an empty search path'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.get_chore_list(uuid,text,uuid,integer,text)',
    'execute'
  ),
  'authenticated clients can execute the chore list read'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.get_chore_list(uuid,text,uuid,integer,text)',
    'execute'
  ),
  'anonymous clients cannot execute the chore list read'
);
select is(
  (
    select string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name like 'get_chore_list_%'
      and parameter_mode = 'OUT'
  ),
  'household_id,household_timezone,household_local_date,generated_at,list_view,assignee_filter_member_id,page_limit,has_more,page_cursor,occurrence_id,series_id,title,description,assignee_member_id,assignee_display_name,due_local_date,due_local_time,due_at,status,version,recurrence_frequency,series_version,series_default_assignee_member_id,series_due_local_time,recurrence_rule,can_manage_series',
  'chore list exposes the exact allowlisted page and occurrence fields'
);
select ok(
  pg_get_indexdef(
    'public.chore_occurrences_list_idx'::regclass
  ) like '%(household_id, status, due_local_date, due_at, id)%',
  'Everyone list index covers status, local date, instant, and identity'
);
select ok(
  pg_get_indexdef(
    'public.chore_occurrences_assignee_list_idx'::regclass
  ) like '%(household_id, assignee_member_id, status, due_local_date, due_at, id)%',
  'Me list index additionally anchors the assignee'
);
select has_function(
  'public',
  'get_chore_occurrence_target',
  array['uuid', 'uuid'],
  'authoritative occurrence target function exists'
);
select ok(
  (
    select pg_proc.prosecdef
      and pg_proc.provolatile = 's'
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'get_chore_occurrence_target'
  ),
  'occurrence target is stable security-definer with an empty search path'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.get_chore_occurrence_target(uuid,uuid)',
    'execute'
  ),
  'authenticated clients can execute the occurrence target read'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.get_chore_occurrence_target(uuid,uuid)',
    'execute'
  ),
  'anonymous clients cannot execute the occurrence target read'
);
select ok(
  not has_function_privilege(
    'service_role',
    'public.get_chore_occurrence_target(uuid,uuid)',
    'execute'
  ),
  'service workers cannot bypass the authenticated occurrence target boundary'
);
select is(
  (
    select string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name like 'get_chore_occurrence_target_%'
      and parameter_mode = 'OUT'
  ),
  'household_id,series_id,occurrence_id,title,description,assignee_member_id,assignee_display_name,due_local_date,due_local_time,due_at,status,version,recurrence_frequency,series_version,series_default_assignee_member_id,series_due_local_time,recurrence_rule,can_manage_series',
  'occurrence target exposes only the exact allowlisted detail projection'
);
select has_function(
  'public',
  'get_chore_occurrence_action_target',
  array['uuid', 'uuid'],
  'N-1-safe actionable occurrence target function exists'
);
select ok(
  (
    select pg_proc.prosecdef
      and pg_proc.provolatile = 's'
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'get_chore_occurrence_action_target'
  ),
  'action target is stable security-definer with an empty search path'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.get_chore_occurrence_action_target(uuid,uuid)',
    'execute'
  ),
  'authenticated clients can execute the action target read'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.get_chore_occurrence_action_target(uuid,uuid)',
    'execute'
  ),
  'anonymous clients cannot execute the action target read'
);
select ok(
  not has_function_privilege(
    'service_role',
    'public.get_chore_occurrence_action_target(uuid,uuid)',
    'execute'
  ),
  'service workers cannot bypass the authenticated action target boundary'
);
select is(
  (
    select string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name like 'get_chore_occurrence_action_target_%'
      and parameter_mode = 'OUT'
  ),
  'household_id,series_id,occurrence_id,title,description,assignee_member_id,assignee_display_name,due_local_date,due_local_time,due_at,status,version,recurrence_frequency,series_version,series_default_assignee_member_id,series_due_local_time,recurrence_rule,can_manage_series,can_set_completion',
  'action target adds only the exact completion capability field'
);
select throws_ok(
  $$
    select * from public.get_chore_occurrence_target(
      '20000000-0000-4000-8000-000000000101',
      '4c620000-0000-4000-8000-000000000001'
    )
  $$,
  'KFC01',
  'authentication required',
  'occurrence target derives identity from the authenticated session'
);
select throws_ok(
  $$
    select * from public.get_chore_occurrence_action_target(
      '20000000-0000-4000-8000-000000000101',
      '4c620000-0000-4000-8000-000000000001'
    )
  $$,
  'KFC01',
  'authentication required',
  'action target derives identity from the authenticated session'
);
select throws_ok(
  $$
    select * from public.get_chore_list(
      '20000000-0000-4000-8000-000000000101'
    )
  $$,
  'KFC01',
  'authentication required',
  'chore list derives identity from the authenticated session'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.get_chore_list(
      '20000000-0000-4000-8000-000000000101',
      'tomorrow'
    )
  $$,
  'KFC02',
  'invalid chore input',
  'unknown view is rejected'
);
select throws_ok(
  $$
    select * from public.get_chore_list(
      '20000000-0000-4000-8000-000000000101',
      'today',
      null,
      0
    )
  $$,
  'KFC02',
  'invalid chore input',
  'zero page limit is rejected'
);
select throws_ok(
  $$
    select * from public.get_chore_list(
      '20000000-0000-4000-8000-000000000101',
      'today',
      null,
      101
    )
  $$,
  'KFC02',
  'invalid chore input',
  'page limit above the bounded maximum is rejected'
);
select throws_ok(
  $$
    select * from public.get_chore_list(
      '20000000-0000-4000-8000-000000000101',
      'today',
      null,
      30,
      'not-hex'
    )
  $$,
  'KFC02',
  'invalid chore input',
  'malformed opaque cursor is rejected'
);
select throws_ok(
  $$
    select * from public.get_chore_list(
      '20000000-0000-4000-8000-000000000101',
      'today',
      '30000000-0000-4000-8000-000000000201'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'foreign-household assignee probing is denied'
);
select throws_ok(
  $$
    select * from public.get_chore_occurrence_target(
      '20000000-0000-4000-8000-000000000101',
      null
    )
  $$,
  'KFC02',
  'invalid chore input',
  'null occurrence target input is rejected'
);
select throws_ok(
  $$
    select * from public.get_chore_occurrence_action_target(
      '20000000-0000-4000-8000-000000000101',
      null
    )
  $$,
  'KFC02',
  'invalid chore input',
  'null action target input is rejected'
);
select throws_ok(
  $$
    select * from public.get_chore_list(
      '20000000-0000-4000-8000-000000000201'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'cross-household list probing is denied'
);
select is(
  (
    select concat_ws(
      ':', count(*), count(occurrence_id), min(has_more::integer),
      count(page_cursor)
    )
    from public.get_chore_list(
      '20000000-0000-4000-8000-000000000101',
      'today'
    )
  ),
  '1:0:0:0',
  'an empty authorized query returns one metadata-only row'
);

reset role;

-- Fixed household-local fixtures isolate boundary, order, filter, and cursor.
insert into public.chore_series (
  id,
  household_id,
  title,
  description,
  timezone,
  active_revision_id
)
select
  ('4c600000-0000-4000-8000-' ||
    lpad(fixture.sequence::text, 12, '0'))::uuid,
  '20000000-0000-4000-8000-000000000101'::uuid,
  fixture.title,
  'Synthetic agenda fixture',
  'Asia/Seoul',
  ('4c610000-0000-4000-8000-' ||
    lpad(fixture.sequence::text, 12, '0'))::uuid
from (
  values
    (1, 'Today owner timed'),
    (2, 'Today member timed'),
    (3, 'Today completed all day'),
    (4, 'Upcoming scheduled'),
    (5, 'Overdue scheduled'),
    (6, 'Past completed'),
    (7, 'Future completed'),
    (8, 'Today skipped'),
    (9, 'Today cancelled'),
    (10, 'Deleted scheduled'),
    (11, 'Deleted completed'),
    (20, 'Today equal-time owner')
) as fixture(sequence, title);

insert into public.chore_series_revisions (
  id,
  household_id,
  series_id,
  revision_number,
  effective_local_date,
  due_local_time,
  recurrence_rule,
  default_assignee_member_id
)
select
  ('4c610000-0000-4000-8000-' ||
    lpad(fixture.sequence::text, 12, '0'))::uuid,
  '20000000-0000-4000-8000-000000000101'::uuid,
  ('4c600000-0000-4000-8000-' ||
    lpad(fixture.sequence::text, 12, '0'))::uuid,
  1,
  (statement_timestamp() at time zone 'Asia/Seoul')::date,
  fixture.due_local_time,
  case
    when fixture.sequence = 1 then
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'::jsonb
    else '{"type":"once"}'::jsonb
  end,
  case
    when fixture.sequence in (2, 3, 5, 8) then
      '30000000-0000-4000-8000-000000000102'::uuid
    else '30000000-0000-4000-8000-000000000101'::uuid
  end
from (
  values
    (1, time '08:00'),
    (2, time '08:00'),
    (3, null::time),
    (4, time '07:00'),
    (5, null::time),
    (6, time '09:00'),
    (7, time '10:00'),
    (8, time '11:00'),
    (9, time '12:00'),
    (10, time '13:00'),
    (11, null::time),
    (20, time '08:00')
) as fixture(sequence, due_local_time);

insert into public.chore_occurrences (
  id,
  household_id,
  series_id,
  revision_id,
  occurrence_key,
  due_local_date,
  due_at,
  timezone,
  status,
  assignee_member_id,
  completed_by_member_id,
  completed_by_user_id,
  completed_at
)
select
  ('4c620000-0000-4000-8000-' ||
    lpad(fixture.sequence::text, 12, '0'))::uuid,
  '20000000-0000-4000-8000-000000000101'::uuid,
  ('4c600000-0000-4000-8000-' ||
    lpad(fixture.sequence::text, 12, '0'))::uuid,
  ('4c610000-0000-4000-8000-' ||
    lpad(fixture.sequence::text, 12, '0'))::uuid,
  case
    when fixture.sequence = 1 then
      '4c600000-0000-4000-8000-' ||
        lpad(fixture.sequence::text, 12, '0') || ':' ||
        ((statement_timestamp() at time zone 'Asia/Seoul')::date)::text
    else '4c600000-0000-4000-8000-' ||
      lpad(fixture.sequence::text, 12, '0') || ':once'
  end,
  (statement_timestamp() at time zone 'Asia/Seoul')::date
    + fixture.day_offset,
  case
    when fixture.due_local_time is null then null
    else (
      (
        (statement_timestamp() at time zone 'Asia/Seoul')::date
          + fixture.day_offset
      ) + fixture.due_local_time
    ) at time zone 'Asia/Seoul'
  end,
  'Asia/Seoul',
  fixture.status::public.occurrence_status,
  case
    when fixture.sequence in (2, 3, 5, 8) then
      '30000000-0000-4000-8000-000000000102'::uuid
    else '30000000-0000-4000-8000-000000000101'::uuid
  end,
  case
    when fixture.status = 'completed' then
      '30000000-0000-4000-8000-000000000101'::uuid
    else null
  end,
  case
    when fixture.status = 'completed' then
      '00000000-0000-4000-8000-000000000101'::uuid
    else null
  end,
  case
    when fixture.status = 'completed' then statement_timestamp()
    else null
  end
from (
  values
    (1, 0, time '08:00', 'scheduled'),
    (2, 0, time '08:00', 'scheduled'),
    (3, 0, null::time, 'completed'),
    (4, 1, time '07:00', 'scheduled'),
    (5, -1, null::time, 'scheduled'),
    (6, -2, time '09:00', 'completed'),
    (7, 1, time '10:00', 'completed'),
    (8, 0, time '11:00', 'skipped'),
    (9, 0, time '12:00', 'cancelled'),
    (10, 0, time '13:00', 'scheduled'),
    (11, 0, null::time, 'completed'),
    (20, 0, time '08:00', 'scheduled')
) as fixture(sequence, day_offset, due_local_time, status);

update public.chore_series
set deleted_at = statement_timestamp()
where id in (
  '4c600000-0000-4000-8000-000000000010',
  '4c600000-0000-4000-8000-000000000011'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);

select is(
  (
    select min(household_local_date)
    from public.get_chore_list(
      '20000000-0000-4000-8000-000000000101',
      'today'
    )
  ),
  (statement_timestamp() at time zone 'Asia/Seoul')::date,
  'server computes one household-local date boundary'
);
select is(
  (
    select count(distinct concat_ws(
      ':', household_id, household_timezone, household_local_date,
      list_view, page_limit, assignee_filter_member_id
    ))
    from public.get_chore_list(
      '20000000-0000-4000-8000-000000000101',
      'today',
      null,
      30
    )
  ),
  1::bigint,
  'all rows repeat one consistent page metadata contract'
);
select is(
  (
    select count(*)
    from public.get_chore_list(
      '20000000-0000-4000-8000-000000000101',
      'today'
    )
  ),
  5::bigint,
  'Today includes only scheduled and completed occurrences on the boundary'
);
select is(
  (
    select count(*)
    from public.get_chore_list(
      '20000000-0000-4000-8000-000000000101',
      'today'
    )
    where title in (
      'Today skipped', 'Today cancelled', 'Deleted scheduled'
    )
  ),
  0::bigint,
  'Today excludes skipped, cancelled, and deleted scheduled work'
);
select is(
  (
    select array_agg(occurrence_id order by row_number)
    from (
      select occurrence_id, row_number() over ()
      from public.get_chore_list(
        '20000000-0000-4000-8000-000000000101',
        'today'
      )
    ) as ordered
  ),
  array[
    '4c620000-0000-4000-8000-000000000001'::uuid,
    '4c620000-0000-4000-8000-000000000002'::uuid,
    '4c620000-0000-4000-8000-000000000020'::uuid,
    '4c620000-0000-4000-8000-000000000003'::uuid,
    '4c620000-0000-4000-8000-000000000011'::uuid
  ],
  'Today orders timed work first and uses occurrence identity as the tie break'
);
select is(
  (
    select concat_ws(
      ':', count(*), min(title), min(status), min(assignee_display_name)
    )
    from public.get_chore_occurrence_target(
      '20000000-0000-4000-8000-000000000101',
      '4c620000-0000-4000-8000-000000000001'
    )
  ),
  '1:Today owner timed:scheduled:Adult A',
  'scheduled target returns the exact latest occurrence projection'
);
select is(
  (
    select concat_ws(
      ':', recurrence_frequency, can_manage_series::text,
      recurrence_rule->>'frequency'
    )
    from public.get_chore_occurrence_target(
      '20000000-0000-4000-8000-000000000101',
      '4c620000-0000-4000-8000-000000000001'
    )
  ),
  'daily:true:daily',
  'owner receives the existing series-management projection for a repeating target'
);
select is(
  (
    select can_set_completion
    from public.get_chore_occurrence_action_target(
      '20000000-0000-4000-8000-000000000101',
      '4c620000-0000-4000-8000-000000000001'
    )
  ),
  true,
  'Owner can complete an active-series occurrence from the exact target'
);
select is(
  (
    select can_set_completion
    from public.get_chore_occurrence_action_target(
      '20000000-0000-4000-8000-000000000101',
      '4c620000-0000-4000-8000-000000000002'
    )
  ),
  true,
  'Owner can complete an active-series occurrence assigned to another adult'
);
select is(
  (
    select concat_ws(':', count(*), min(title), min(status))
    from public.get_chore_occurrence_target(
      '20000000-0000-4000-8000-000000000101',
      '4c620000-0000-4000-8000-000000000011'
    )
  ),
  '1:Deleted completed:completed',
  'completed historical target remains available after its series is deleted'
);
select is(
  (
    select can_set_completion
    from public.get_chore_occurrence_action_target(
      '20000000-0000-4000-8000-000000000101',
      '4c620000-0000-4000-8000-000000000011'
    )
  ),
  false,
  'deleted-series completed history remains readable but cannot be reopened'
);
select throws_ok(
  $$
    select * from public.get_chore_occurrence_target(
      '20000000-0000-4000-8000-000000000101',
      '4c620000-0000-4000-8000-000000000008'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'skipped target is indistinguishably unavailable'
);
select throws_ok(
  $$
    select * from public.get_chore_occurrence_target(
      '20000000-0000-4000-8000-000000000101',
      '4c620000-0000-4000-8000-000000000010'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'deleted scheduled target is indistinguishably unavailable'
);
select throws_ok(
  $$
    select * from public.get_chore_occurrence_target(
      '20000000-0000-4000-8000-000000000101',
      '4c620000-0000-4000-8000-999999999999'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'missing target is indistinguishably unavailable'
);
select is(
  (
    select array_agg(title)
    from public.get_chore_list(
      '20000000-0000-4000-8000-000000000101',
      'upcoming'
    )
  ),
  array['Upcoming scheduled'::text],
  'Upcoming includes only future scheduled work'
);
select is(
  (
    select array_agg(title)
    from public.get_chore_list(
      '20000000-0000-4000-8000-000000000101',
      'overdue'
    )
  ),
  array['Overdue scheduled'::text],
  'Overdue includes only past scheduled work'
);
select is(
  (
    select count(*)
    from public.get_chore_list(
      '20000000-0000-4000-8000-000000000101',
      'completed'
    )
  ),
  4::bigint,
  'Completed includes completed work across local dates'
);
select is(
  (
    select array_agg(occurrence_id order by row_number)
    from (
      select occurrence_id, row_number() over ()
      from public.get_chore_list(
        '20000000-0000-4000-8000-000000000101',
        'completed'
      )
    ) as ordered
  ),
  array[
    '4c620000-0000-4000-8000-000000000007'::uuid,
    '4c620000-0000-4000-8000-000000000011'::uuid,
    '4c620000-0000-4000-8000-000000000003'::uuid,
    '4c620000-0000-4000-8000-000000000006'::uuid
  ],
  'Completed uses newest due date/time and descending identity tie breaks'
);
select is(
  (
    select count(*)
    from public.get_chore_list(
      '20000000-0000-4000-8000-000000000101',
      'completed'
    )
    where title = 'Deleted completed'
  ),
  1::bigint,
  'Completed preserves a historical occurrence after series deletion'
);
select is(
  (
    select count(*)
    from public.get_chore_list(
      '20000000-0000-4000-8000-000000000101',
      'today'
    )
    where title = 'Deleted scheduled'
  ),
  0::bigint,
  'scheduled work from a deleted series stays hidden'
);
select is(
  (
    select array_agg(occurrence_id order by row_number)
    from (
      select occurrence_id, row_number() over ()
      from public.get_chore_list(
        '20000000-0000-4000-8000-000000000101',
        'today',
        '30000000-0000-4000-8000-000000000101'
      )
    ) as ordered
  ),
  array[
    '4c620000-0000-4000-8000-000000000001'::uuid,
    '4c620000-0000-4000-8000-000000000020'::uuid,
    '4c620000-0000-4000-8000-000000000011'::uuid
  ],
  'Me filter returns only the active caller member assignment'
);
select is(
  (
    select array_agg(occurrence_id order by row_number)
    from (
      select occurrence_id, row_number() over ()
      from public.get_chore_list(
        '20000000-0000-4000-8000-000000000101',
        'today',
        '30000000-0000-4000-8000-000000000102'
      )
    ) as ordered
  ),
  array[
    '4c620000-0000-4000-8000-000000000002'::uuid,
    '4c620000-0000-4000-8000-000000000003'::uuid
  ],
  'assignee filter can select another active household adult without expansion'
);
select is(
  (
    select concat_ws(
      ':', recurrence_frequency, series_version,
      series_default_assignee_member_id, can_manage_series
    )
    from public.get_chore_list(
      '20000000-0000-4000-8000-000000000101',
      'today'
    )
    where occurrence_id = '4c620000-0000-4000-8000-000000000001'
  ),
  'daily:1:30000000-0000-4000-8000-000000000101:t',
  'owner receives active repeating-series management metadata'
);

reset role;
create temporary table chore_list_page_one as
select *
from public.get_chore_list(
  '20000000-0000-4000-8000-000000000101',
  'today',
  null,
  2
) with no data;
create temporary table chore_list_page_two as
select * from chore_list_page_one with no data;
create temporary table chore_list_page_three as
select * from chore_list_page_one with no data;
grant select, insert on chore_list_page_one to authenticated;
grant select, insert on chore_list_page_two to authenticated;
grant select, insert on chore_list_page_three to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
insert into chore_list_page_one
select *
from public.get_chore_list(
  '20000000-0000-4000-8000-000000000101',
  'today',
  null,
  2
);
select set_config(
  'kinflow.test.chore_list_cursor_one',
  (select min(page_cursor) from chore_list_page_one),
  true
);

select is(
  (
    select concat_ws(
      ':', count(*), min(has_more::integer),
      count(distinct page_cursor)
    )
    from chore_list_page_one
  ),
  '2:1:1',
  'first bounded page contains two rows and one next cursor'
);
select is(
  (select array_agg(occurrence_id order by occurrence_id) from chore_list_page_one),
  array[
    '4c620000-0000-4000-8000-000000000001'::uuid,
    '4c620000-0000-4000-8000-000000000002'::uuid
  ],
  'first page stops inside the equal-time identity tie'
);
select throws_ok(
  format(
    $query$
      select * from public.get_chore_list(
        '20000000-0000-4000-8000-000000000101',
        'upcoming', null, 2, %L
      )
    $query$,
    current_setting('kinflow.test.chore_list_cursor_one')
  ),
  'KFC02',
  'invalid chore input',
  'cursor cannot be reused with another view'
);
select throws_ok(
  format(
    $query$
      select * from public.get_chore_list(
        '20000000-0000-4000-8000-000000000101',
        'today',
        '30000000-0000-4000-8000-000000000101',
        2,
        %L
      )
    $query$,
    current_setting('kinflow.test.chore_list_cursor_one')
  ),
  'KFC02',
  'invalid chore input',
  'cursor cannot be reused with another assignee filter'
);

insert into chore_list_page_two
select *
from public.get_chore_list(
  '20000000-0000-4000-8000-000000000101',
  'today',
  null,
  2,
  current_setting('kinflow.test.chore_list_cursor_one')
);
select set_config(
  'kinflow.test.chore_list_cursor_two',
  (select min(page_cursor) from chore_list_page_two),
  true
);
select is(
  (select array_agg(occurrence_id order by row_number) from (
    select occurrence_id, row_number() over ()
    from chore_list_page_two
  ) as ordered),
  array[
    '4c620000-0000-4000-8000-000000000020'::uuid,
    '4c620000-0000-4000-8000-000000000003'::uuid
  ],
  'second page advances across timed and all-day groups without overlap'
);
select is(
  (
    select concat_ws(
      ':', count(*), min(has_more::integer),
      count(distinct page_cursor)
    )
    from chore_list_page_two
  ),
  '2:1:1',
  'second page exposes the final continuation cursor'
);

insert into chore_list_page_three
select *
from public.get_chore_list(
  '20000000-0000-4000-8000-000000000101',
  'today',
  null,
  2,
  current_setting('kinflow.test.chore_list_cursor_two')
);
select is(
  (
    select concat_ws(
      ':', count(*), min(has_more::integer), count(page_cursor),
      min(occurrence_id::text)
    )
    from chore_list_page_three
  ),
  '1:0:0:4c620000-0000-4000-8000-000000000011',
  'final page has one item and no continuation cursor'
);
select is(
  (
    select concat_ws(':', count(*), count(distinct occurrence_id))
    from (
      select occurrence_id from chore_list_page_one
      union all
      select occurrence_id from chore_list_page_two
      union all
      select occurrence_id from chore_list_page_three
    ) as all_pages
  ),
  '5:5',
  'three pages cover every Today occurrence exactly once'
);

reset role;
create temporary table chore_completed_page_one as
select * from chore_list_page_one with no data;
create temporary table chore_completed_page_two as
select * from chore_list_page_one with no data;
grant select, insert on chore_completed_page_one to authenticated;
grant select, insert on chore_completed_page_two to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
insert into chore_completed_page_one
select *
from public.get_chore_list(
  '20000000-0000-4000-8000-000000000101',
  'completed',
  null,
  2
);
select set_config(
  'kinflow.test.chore_completed_cursor',
  (select min(page_cursor) from chore_completed_page_one),
  true
);
select is(
  (select array_agg(occurrence_id order by row_number) from (
    select occurrence_id, row_number() over ()
    from chore_completed_page_one
  ) as ordered),
  array[
    '4c620000-0000-4000-8000-000000000007'::uuid,
    '4c620000-0000-4000-8000-000000000011'::uuid
  ],
  'first Completed page follows descending date and identity order'
);
select is(
  (
    select concat_ws(
      ':', count(*), min(has_more::integer),
      count(distinct page_cursor)
    )
    from chore_completed_page_one
  ),
  '2:1:1',
  'first Completed page exposes a descending continuation cursor'
);

insert into chore_completed_page_two
select *
from public.get_chore_list(
  '20000000-0000-4000-8000-000000000101',
  'completed',
  null,
  2,
  current_setting('kinflow.test.chore_completed_cursor')
);
select is(
  (select array_agg(occurrence_id order by row_number) from (
    select occurrence_id, row_number() over ()
    from chore_completed_page_two
  ) as ordered),
  array[
    '4c620000-0000-4000-8000-000000000003'::uuid,
    '4c620000-0000-4000-8000-000000000006'::uuid
  ],
  'second Completed page advances to older completed work'
);
select is(
  (
    select concat_ws(':', count(*), count(distinct occurrence_id))
    from (
      select occurrence_id from chore_completed_page_one
      union all
      select occurrence_id from chore_completed_page_two
    ) as completed_pages
  ),
  '4:4',
  'Completed pagination covers every completed occurrence exactly once'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select concat_ws(':', count(*), max(can_manage_series::integer))
    from public.get_chore_list(
      '20000000-0000-4000-8000-000000000101',
      'today'
    )
  ),
  '5:0',
  'regular active adult reads the same list without management expansion'
);
select is(
  (
    select can_manage_series
    from public.get_chore_occurrence_target(
      '20000000-0000-4000-8000-000000000101',
      '4c620000-0000-4000-8000-000000000001'
    )
  ),
  false,
  'regular active adult reads the target without series-management expansion'
);
select is(
  (
    select can_set_completion
    from public.get_chore_occurrence_action_target(
      '20000000-0000-4000-8000-000000000101',
      '4c620000-0000-4000-8000-000000000002'
    )
  ),
  true,
  'regular adult can complete their currently assigned occurrence'
);
select is(
  (
    select can_set_completion
    from public.get_chore_occurrence_action_target(
      '20000000-0000-4000-8000-000000000101',
      '4c620000-0000-4000-8000-000000000001'
    )
  ),
  false,
  'regular adult cannot complete another adult assignment from the target'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$
    select * from public.get_chore_list(
      '20000000-0000-4000-8000-000000000101',
      'today'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'active outsider cannot read another household list'
);
select throws_ok(
  $$
    select * from public.get_chore_occurrence_target(
      '20000000-0000-4000-8000-000000000101',
      '4c620000-0000-4000-8000-000000000001'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'active outsider cannot probe another household occurrence target'
);
select throws_ok(
  $$
    select * from public.get_chore_occurrence_action_target(
      '20000000-0000-4000-8000-000000000101',
      '4c620000-0000-4000-8000-000000000001'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'active outsider cannot probe another household action target'
);

reset role;
update public.household_members
set removed_at = statement_timestamp()
where id = '30000000-0000-4000-8000-000000000102';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select throws_ok(
  $$
    select * from public.get_chore_list(
      '20000000-0000-4000-8000-000000000101',
      'today'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'removed member immediately loses chore list access'
);
select throws_ok(
  $$
    select * from public.get_chore_occurrence_target(
      '20000000-0000-4000-8000-000000000101',
      '4c620000-0000-4000-8000-000000000001'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'removed member immediately loses occurrence target access'
);
select throws_ok(
  $$
    select * from public.get_chore_occurrence_action_target(
      '20000000-0000-4000-8000-000000000101',
      '4c620000-0000-4000-8000-000000000001'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'removed member immediately loses occurrence action target access'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.chore_occurrences',
    'insert'
  ),
  'new read contract does not add direct occurrence mutation access'
);

reset role;
select is(
  (
    select count(*)
    from app_private.chore_command_requests
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  0::bigint,
  'read-only filtering creates no command or idempotency state'
);

select * from finish();
rollback;
