begin;
set constraints all deferred;

select plan(41);

-- Read-contract shape and privilege boundary.
select has_function(
  'public',
  'get_chore_occurrence_history',
  array[
    'uuid',
    'uuid',
    'integer',
    'timestamp with time zone',
    'text'
  ],
  'bounded occurrence history read function exists'
);
select ok(
  (
    select pg_proc.prosecdef
      and pg_proc.provolatile = 's'
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'get_chore_occurrence_history'
  ),
  'history read is stable security-definer with an empty search path'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.get_chore_occurrence_history(uuid,uuid,integer,timestamptz,text)',
    'execute'
  ),
  'authenticated clients can execute the mediated history read'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.get_chore_occurrence_history(uuid,uuid,integer,timestamptz,text)',
    'execute'
  ),
  'anonymous clients cannot execute the history read'
);
select throws_ok(
  $$
    select * from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      '60000000-0000-4000-8000-000000000701',
      20,
      null,
      null
    )
  $$,
  'KFC01',
  'authentication required',
  'history derives identity from the authenticated session'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '60000000-0000-4000-8000-000000000711',
      '20000000-0000-4000-8000-000000000101',
      'Persistent history fixture',
      'Synthetic notes',
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      time '09:00',
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
    )
  $$,
  'owner can create the occurrence history fixture'
);
select set_config(
  'kinflow.test.history_occurrence_id',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    join public.chore_series as series
      on series.id = occurrence.series_id
    where series.title = 'Persistent history fixture'
  ),
  true
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '60000000-0000-4000-8000-000000000712',
      '20000000-0000-4000-8000-000000000101',
      'Empty history fixture',
      null,
      '30000000-0000-4000-8000-000000000101',
      (clock_timestamp() at time zone 'Asia/Seoul')::date,
      null
    )
  $$,
  'owner can create a valid occurrence with no activity history'
);
select set_config(
  'kinflow.test.empty_history_occurrence_id',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    join public.chore_series as series
      on series.id = occurrence.series_id
    where series.title = 'Empty history fixture'
  ),
  true
);

select throws_ok(
  $$
    select * from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      0,
      null,
      null
    )
  $$,
  'KFC02',
  'invalid chore input',
  'history rejects a zero page limit'
);
select throws_ok(
  $$
    select * from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      101,
      null,
      null
    )
  $$,
  'KFC02',
  'invalid chore input',
  'history rejects a page limit above the bounded maximum'
);
select throws_ok(
  $$
    select * from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      20,
      timestamptz '2026-08-07 05:00:00+00',
      null
    )
  $$,
  'KFC02',
  'invalid chore input',
  'history requires both cursor fields'
);
select throws_ok(
  $$
    select * from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      20,
      null,
      'completion:61000000-0000-4000-8000-000000000701'
    )
  $$,
  'KFC02',
  'invalid chore input',
  'history rejects an entry cursor without its timestamp'
);
select throws_ok(
  $$
    select * from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      20,
      timestamptz '2026-08-07 05:00:00+00',
      'completion:not-a-uuid'
    )
  $$,
  'KFC02',
  'invalid chore input',
  'history rejects a malformed entry cursor'
);

-- Fixed synthetic audit rows isolate projection, classification, and cursor
-- semantics from wall-clock timing in the mutation tests.
reset role;
insert into public.chore_completion_events (
  id,
  household_id,
  occurrence_id,
  event_type,
  actor_user_id,
  actor_member_id,
  acting_member_id,
  occurred_at,
  occurrence_version,
  correlation_id
)
values
  (
    '61000000-0000-4000-8000-000000000701',
    '20000000-0000-4000-8000-000000000101',
    current_setting('kinflow.test.history_occurrence_id')::uuid,
    'completed',
    '00000000-0000-4000-8000-000000000102',
    '30000000-0000-4000-8000-000000000102',
    null,
    timestamptz '2026-08-07 00:00:00+00',
    1,
    '61000000-0000-4000-8000-000000000711'
  ),
  (
    '61000000-0000-4000-8000-000000000702',
    '20000000-0000-4000-8000-000000000101',
    current_setting('kinflow.test.history_occurrence_id')::uuid,
    'reopened',
    '00000000-0000-4000-8000-000000000102',
    '30000000-0000-4000-8000-000000000102',
    null,
    timestamptz '2026-08-07 01:00:00+00',
    2,
    '61000000-0000-4000-8000-000000000712'
  ),
  (
    '61000000-0000-4000-8000-000000000703',
    '20000000-0000-4000-8000-000000000101',
    current_setting('kinflow.test.history_occurrence_id')::uuid,
    'skipped',
    '00000000-0000-4000-8000-000000000102',
    '30000000-0000-4000-8000-000000000102',
    null,
    timestamptz '2026-08-07 02:00:00+00',
    3,
    '61000000-0000-4000-8000-000000000713'
  ),
  (
    '61000000-0000-4000-8000-000000000704',
    '20000000-0000-4000-8000-000000000101',
    current_setting('kinflow.test.history_occurrence_id')::uuid,
    'reopened',
    '00000000-0000-4000-8000-000000000102',
    '30000000-0000-4000-8000-000000000102',
    null,
    timestamptz '2026-08-07 03:00:00+00',
    4,
    '61000000-0000-4000-8000-000000000714'
  );

insert into app_private.chore_restore_command_requests (
  authenticated_user_id,
  idempotency_key,
  request_hash,
  household_id,
  occurrence_id,
  result_version,
  result_event_id
)
values (
  '00000000-0000-4000-8000-000000000102',
  '61000000-0000-4000-8000-000000000714',
  decode(repeat('00', 32), 'hex'),
  '20000000-0000-4000-8000-000000000101',
  current_setting('kinflow.test.history_occurrence_id')::uuid,
  4,
  '61000000-0000-4000-8000-000000000704'
);

insert into public.chore_reschedule_events (
  id,
  household_id,
  occurrence_id,
  actor_user_id,
  actor_member_id,
  previous_due_local_date,
  previous_due_local_time,
  previous_due_at,
  new_due_local_date,
  new_due_local_time,
  new_due_at,
  occurred_at,
  occurrence_version,
  correlation_id
)
values (
  '62000000-0000-4000-8000-000000000701',
  '20000000-0000-4000-8000-000000000101',
  current_setting('kinflow.test.history_occurrence_id')::uuid,
  '00000000-0000-4000-8000-000000000102',
  '30000000-0000-4000-8000-000000000102',
  date '2026-08-07',
  time '09:00',
  timestamptz '2026-08-07 00:00:00+00',
  date '2026-08-08',
  time '18:30',
  timestamptz '2026-08-08 09:30:00+00',
  timestamptz '2026-08-07 05:00:00+00',
  5,
  '62000000-0000-4000-8000-000000000711'
);

insert into public.chore_assignment_events (
  id,
  household_id,
  occurrence_id,
  actor_user_id,
  actor_member_id,
  previous_assignee_member_id,
  new_assignee_member_id,
  occurred_at,
  occurrence_version,
  correlation_id
)
values (
  '63000000-0000-4000-8000-000000000701',
  '20000000-0000-4000-8000-000000000101',
  current_setting('kinflow.test.history_occurrence_id')::uuid,
  '00000000-0000-4000-8000-000000000102',
  '30000000-0000-4000-8000-000000000102',
  '30000000-0000-4000-8000-000000000101',
  '30000000-0000-4000-8000-000000000102',
  timestamptz '2026-08-07 05:00:00+00',
  6,
  '63000000-0000-4000-8000-000000000711'
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
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      20,
      null,
      null
    )
  ),
  6::bigint,
  'history merges every existing occurrence audit source'
);
select is(
  array(
    select history.event_type
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      20,
      null,
      null
    ) as history
  ),
  array[
    'rescheduled',
    'reassigned',
    'restored',
    'skipped',
    'reopened',
    'completed'
  ]::text[],
  'history is newest-first with deterministic source-entry tie breaking'
);
select ok(
  (
    select (
        select count(*)
        from jsonb_object_keys(to_jsonb(history))
      ) = 19
      and not to_jsonb(history) ?| array[
        'actor_user_id',
        'correlation_id',
        'title',
        'description',
        'request_hash',
        'raw_error'
      ]
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      1,
      null,
      null
    ) as history
  ),
  'history response has the exact minimal shape and no sensitive command data'
);
select ok(
  not exists (
    select 1
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      20,
      null,
      null
    ) as history
    where history.event_type not in (
      'completed',
      'reopened',
      'skipped',
      'restored',
      'rescheduled',
      'reassigned'
    )
  ),
  'history exposes only the allowlisted event vocabulary'
);
select ok(
  not exists (
    select 1
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      20,
      null,
      null
    ) as history
    where history.actor_member_id <>
        '30000000-0000-4000-8000-000000000102'
      or history.actor_display_name <> 'Adult B'
  ),
  'history resolves the household-scoped actor without returning auth identity'
);
select ok(
  not exists (
    select 1
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      20,
      null,
      null
    ) as history
    where history.acting_member_id is not null
      or history.acting_display_name is not null
  ),
  'adult history keeps optional acting-member fields absent as a pair'
);
select ok(
  not exists (
    select 1
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      20,
      null,
      null
    ) as history
    where history.event_type not in ('rescheduled', 'reassigned')
      and (
        history.previous_due_local_date is not null
        or history.previous_due_local_time is not null
        or history.new_due_local_date is not null
        or history.new_due_local_time is not null
        or history.previous_assignee_member_id is not null
        or history.previous_assignee_display_name is not null
        or history.new_assignee_member_id is not null
        or history.new_assignee_display_name is not null
      )
  ),
  'status events do not receive unrelated schedule or assignment payloads'
);
select is(
  (
    select
      history.previous_due_local_date::text || 'T'
        || history.previous_due_local_time::text || '>'
        || history.new_due_local_date::text || 'T'
        || history.new_due_local_time::text
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      20,
      null,
      null
    ) as history
    where history.event_type = 'rescheduled'
  ),
  '2026-08-07T09:00:00>2026-08-08T18:30:00',
  'reschedule history returns both local schedule snapshots'
);
select is(
  (
    select
      history.previous_assignee_member_id::text || ':'
        || history.previous_assignee_display_name || '>'
        || history.new_assignee_member_id::text || ':'
        || history.new_assignee_display_name
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      20,
      null,
      null
    ) as history
    where history.event_type = 'reassigned'
  ),
  '30000000-0000-4000-8000-000000000101:Adult A>'
    || '30000000-0000-4000-8000-000000000102:Adult B',
  'assignment history returns household-scoped previous and new members'
);
select is(
  (
    select count(*)
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      20,
      null,
      null
    ) as history
    where history.event_type = 'restored'
  ),
  1::bigint,
  'a restore-command linked reopened event is classified as restored'
);
select is(
  (
    select count(*)
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      20,
      null,
      null
    ) as history
    where history.event_type = 'reopened'
  ),
  1::bigint,
  'a normal completion undo remains classified as reopened'
);
select is(
  array(
    select history.occurrence_version
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      20,
      null,
      null
    ) as history
  ),
  array[5, 6, 4, 3, 2, 1]::bigint[],
  'history preserves each source occurrence version'
);

-- Bounded keyset pagination, including the equal-timestamp source tie.
select is(
  (
    select count(*)
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      2,
      null,
      null
    )
  ),
  2::bigint,
  'first history page honors the requested limit'
);
select is(
  array(
    select history.event_type
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      2,
      null,
      null
    ) as history
  ),
  array['rescheduled', 'reassigned']::text[],
  'first page deterministically orders events sharing one timestamp'
);
select ok(
  (
    select bool_and(history.has_more)
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      2,
      null,
      null
    ) as history
  ),
  'first page advertises more history'
);
select set_config(
  'kinflow.test.history_cursor_time',
  (
    select history.occurred_at::text
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      2,
      null,
      null
    ) as history
    offset 1 limit 1
  ),
  true
);
select set_config(
  'kinflow.test.history_cursor_id',
  (
    select history.history_entry_id
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      2,
      null,
      null
    ) as history
    offset 1 limit 1
  ),
  true
);
select is(
  (
    select count(*)
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      2,
      current_setting('kinflow.test.history_cursor_time')::timestamptz,
      current_setting('kinflow.test.history_cursor_id')
    )
  ),
  2::bigint,
  'second history page remains bounded'
);
select is(
  array(
    select history.event_type
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      2,
      current_setting('kinflow.test.history_cursor_time')::timestamptz,
      current_setting('kinflow.test.history_cursor_id')
    ) as history
  ),
  array['restored', 'skipped']::text[],
  'second page continues without repeating the equal-timestamp boundary'
);
select ok(
  (
    select bool_and(history.has_more)
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      2,
      current_setting('kinflow.test.history_cursor_time')::timestamptz,
      current_setting('kinflow.test.history_cursor_id')
    ) as history
  ),
  'second page still advertises the remaining history'
);
select set_config(
  'kinflow.test.history_cursor_time_2',
  (
    select history.occurred_at::text
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      2,
      current_setting('kinflow.test.history_cursor_time')::timestamptz,
      current_setting('kinflow.test.history_cursor_id')
    ) as history
    offset 1 limit 1
  ),
  true
);
select set_config(
  'kinflow.test.history_cursor_id_2',
  (
    select history.history_entry_id
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      2,
      current_setting('kinflow.test.history_cursor_time')::timestamptz,
      current_setting('kinflow.test.history_cursor_id')
    ) as history
    offset 1 limit 1
  ),
  true
);
select is(
  (
    select count(*)
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      2,
      current_setting('kinflow.test.history_cursor_time_2')::timestamptz,
      current_setting('kinflow.test.history_cursor_id_2')
    )
  ),
  2::bigint,
  'final history page contains the last two events'
);
select is(
  array(
    select history.event_type
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      2,
      current_setting('kinflow.test.history_cursor_time_2')::timestamptz,
      current_setting('kinflow.test.history_cursor_id_2')
    ) as history
  ),
  array['reopened', 'completed']::text[],
  'final page preserves the remaining chronological order'
);
select ok(
  (
    select not bool_or(history.has_more)
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      2,
      current_setting('kinflow.test.history_cursor_time_2')::timestamptz,
      current_setting('kinflow.test.history_cursor_id_2')
    ) as history
  ),
  'final page reports that pagination is exhausted'
);
select is(
  (
    with first_page as (
      select history.history_entry_id
      from public.get_chore_occurrence_history(
        '20000000-0000-4000-8000-000000000101',
        current_setting('kinflow.test.history_occurrence_id')::uuid,
        2,
        null,
        null
      ) as history
    ),
    second_page as (
      select history.history_entry_id
      from public.get_chore_occurrence_history(
        '20000000-0000-4000-8000-000000000101',
        current_setting('kinflow.test.history_occurrence_id')::uuid,
        2,
        current_setting('kinflow.test.history_cursor_time')::timestamptz,
        current_setting('kinflow.test.history_cursor_id')
      ) as history
    ),
    third_page as (
      select history.history_entry_id
      from public.get_chore_occurrence_history(
        '20000000-0000-4000-8000-000000000101',
        current_setting('kinflow.test.history_occurrence_id')::uuid,
        2,
        current_setting('kinflow.test.history_cursor_time_2')::timestamptz,
        current_setting('kinflow.test.history_cursor_id_2')
      ) as history
    ),
    combined as (
      select * from first_page
      union all
      select * from second_page
      union all
      select * from third_page
    )
    select count(*) - count(distinct history_entry_id)
    from combined
  ),
  0::bigint,
  'keyset pages contain no duplicate history entries'
);

-- Active-member visibility and non-enumerable denial behavior.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select count(*)
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      20,
      null,
      null
    )
  ),
  6::bigint,
  'an active Member can read same-household occurrence history'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$
    select * from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      20,
      null,
      null
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'an outsider cannot read another household occurrence history'
);
select throws_ok(
  $$
    select * from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000201',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      20,
      null,
      null
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'a mismatched household and occurrence cannot bypass isolation'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      '60000000-0000-4000-8000-000000000799',
      20,
      null,
      null
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'an unknown occurrence is indistinguishable from a forbidden one'
);
select is(
  (
    select count(*)
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.empty_history_occurrence_id')::uuid,
      20,
      null,
      null
    )
  ),
  0::bigint,
  'a valid occurrence with no events returns an empty success page'
);

reset role;
update public.household_members
set removed_at = timestamptz '2026-08-07 06:00:00+00'
where id = '30000000-0000-4000-8000-000000000102';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select ok(
  not exists (
    select 1
    from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      20,
      null,
      null
    ) as history
    where history.actor_display_name <> 'Adult B'
  ),
  'a removed historical actor remains understandable without a new snapshot'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select throws_ok(
  $$
    select * from public.get_chore_occurrence_history(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.history_occurrence_id')::uuid,
      20,
      null,
      null
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'a removed member immediately loses history access'
);

select * from finish();
rollback;
