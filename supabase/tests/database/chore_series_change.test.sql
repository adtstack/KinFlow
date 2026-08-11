begin;
set constraints all deferred;

select plan(85);

-- Schema, least privilege, immutable history, and privacy-minimal command data.
select has_function(
  'public',
  'update_repeating_chore_series',
  array[
    'uuid', 'uuid', 'uuid', 'bigint', 'text', 'text', 'uuid',
    'time without time zone', 'jsonb'
  ],
  'whole repeating-series update command exists'
);
select has_function(
  'public',
  'cancel_repeating_chore_series',
  array['uuid', 'uuid', 'uuid', 'bigint'],
  'repeating-series termination command exists'
);
select has_function(
  'app_private',
  'chore_revision_candidate_dates',
  array['uuid', 'uuid', 'uuid', 'date', 'date'],
  'series edit and worker share canonical candidate generation'
);
select has_table(
  'public',
  'chore_series_change_events',
  'content-free series change history exists'
);
select has_table(
  'app_private',
  'chore_series_change_command_requests',
  'private series command idempotency state exists'
);
select col_not_null(
  'public',
  'chore_series_revisions',
  'title',
  'revision content title is a required snapshot'
);
select has_column(
  'public',
  'chore_series_revisions',
  'description',
  'revision content includes an optional notes snapshot'
);
select col_not_null(
  'public',
  'chore_occurrences',
  'recurrence_local_date',
  'every occurrence keeps its immutable recurrence slot date'
);
select has_trigger(
  'public',
  'chore_series_revisions',
  'chore_revisions_immutable',
  'revision rows reject in-place updates'
);
select has_trigger(
  'public',
  'chore_occurrences',
  'chore_occurrence_recurrence_identity_immutable',
  'occurrence recurrence identity rejects in-place changes'
);
select has_trigger(
  'public',
  'chore_series_change_events',
  'chore_series_change_events_immutable',
  'series change events reject update and delete'
);
select ok(
  (
    select bool_and(pg_proc.prosecdef)
      and bool_and(pg_proc.proconfig @> array['search_path=""']::text[])
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname in (
        'update_repeating_chore_series',
        'cancel_repeating_chore_series',
        'get_today_chores_v2'
      )
  ),
  'public series functions are security-definer with empty search paths'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.update_repeating_chore_series(uuid,uuid,uuid,bigint,text,text,uuid,time without time zone,jsonb)',
    'execute'
  )
    and has_function_privilege(
      'authenticated',
      'public.cancel_repeating_chore_series(uuid,uuid,uuid,bigint)',
      'execute'
    ),
  'authenticated clients can execute only mediated series commands'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.update_repeating_chore_series(uuid,uuid,uuid,bigint,text,text,uuid,time without time zone,jsonb)',
    'execute'
  )
    and not has_function_privilege(
      'anon',
      'public.cancel_repeating_chore_series(uuid,uuid,uuid,bigint)',
      'execute'
    ),
  'anonymous clients cannot execute series commands'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.chore_revision_candidate_dates(uuid,uuid,uuid,date,date)',
    'execute'
  ),
  'clients cannot invoke the private recurrence candidate helper'
);
select ok(
  has_table_privilege(
    'authenticated',
    'public.chore_series_change_events',
    'select'
  )
    and not has_table_privilege(
      'authenticated',
      'public.chore_series_change_events',
      'insert,update,delete'
    ),
  'clients can read same-household series history but cannot mutate it'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.chore_series_change_command_requests',
    'select'
  )
    and not has_table_privilege(
      'service_role',
      'app_private.chore_series_change_command_requests',
      'select'
    ),
  'client and service roles cannot inspect private command state'
);
select hasnt_column(
  'app_private',
  'chore_series_change_command_requests',
  'title',
  'private command state does not store chore titles'
);
select hasnt_column(
  'app_private',
  'chore_series_change_command_requests',
  'description',
  'private command state does not store chore notes'
);
select hasnt_column(
  'public',
  'chore_series_change_events',
  'title',
  'series change audit does not duplicate chore titles'
);
select is(
  (
    select string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name like 'get_today_chores_v2_%'
      and parameter_mode = 'OUT'
  ),
  'household_id,household_timezone,household_local_date,occurrence_id,series_id,title,description,assignee_member_id,assignee_display_name,due_local_time,due_at,status,version,recurrence_frequency,series_version,series_default_assignee_member_id,series_due_local_time,recurrence_rule,can_manage_series',
  'Today v2 exposes the exact strict series-management fields'
);

-- Authentication and server-owned boundary validation.
select throws_ok(
  $$
    select * from public.update_repeating_chore_series(
      '4b000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      '4b100000-0000-4000-8000-000000000001',
      1,
      'No auth',
      null,
      '30000000-0000-4000-8000-000000000101',
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    )
  $$,
  'KFC01',
  'authentication required',
  'series update derives identity from JWT'
);
select throws_ok(
  $$
    select * from public.cancel_repeating_chore_series(
      '4b000000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      '4b100000-0000-4000-8000-000000000001',
      1
    )
  $$,
  'KFC01',
  'authentication required',
  'series cancellation derives identity from JWT'
);

select set_config(
  'kinflow.test.series_change_today',
  (statement_timestamp() at time zone 'Asia/Seoul')::date::text,
  true
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
      '4a100000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Series edit old title',
      'Series edit old notes',
      '30000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.series_change_today')::date - 3,
      '08:00',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    )
  $$,
  'daily series fixture spans past and future slots'
);
select set_config(
  'kinflow.test.series_change_id',
  (
    select series.id::text
    from public.chore_series as series
    where series.title = 'Series edit old title'
  ),
  true
);
select set_config(
  'kinflow.test.series_change_revision_1',
  (
    select series.active_revision_id::text
    from public.chore_series as series
    where series.id = current_setting('kinflow.test.series_change_id')::uuid
  ),
  true
);

select lives_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '4a100000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        where occurrence.series_id =
          current_setting('kinflow.test.series_change_id')::uuid
          and occurrence.recurrence_local_date =
            current_setting('kinflow.test.series_change_today')::date - 2
      ),
      1,
      true
    )
  $$,
  'past completion fixture is recorded before the series edit'
);
select lives_ok(
  $$
    select * from public.skip_chore_occurrence(
      '4a100000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        where occurrence.series_id =
          current_setting('kinflow.test.series_change_id')::uuid
          and occurrence.recurrence_local_date =
            current_setting('kinflow.test.series_change_today')::date - 1
      ),
      1
    )
  $$,
  'past skipped fixture is recorded before the series edit'
);
select lives_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '4a100000-0000-4000-8000-000000000004',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        where occurrence.series_id =
          current_setting('kinflow.test.series_change_id')::uuid
          and occurrence.recurrence_local_date =
            current_setting('kinflow.test.series_change_today')::date + 2
      ),
      1,
      true
    )
  $$,
  'future completed fixture is recorded before the series edit'
);

select set_config(
  'kinflow.test.series_change_rescheduled_id',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.series_change_id')::uuid
      and occurrence.recurrence_local_date =
        current_setting('kinflow.test.series_change_today')::date + 7
  ),
  true
);
select lives_ok(
  $$
    select * from public.reschedule_chore_occurrence(
      '4a100000-0000-4000-8000-000000000005',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.series_change_rescheduled_id')::uuid,
      1,
      current_setting('kinflow.test.series_change_today')::date + 8,
      '11:15'
    )
  $$,
  'future matching slot receives a one-occurrence reschedule override'
);

select set_config(
  'kinflow.test.series_change_reassigned_id',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.series_change_id')::uuid
      and occurrence.recurrence_local_date =
        current_setting('kinflow.test.series_change_today')::date + 14
  ),
  true
);
select lives_ok(
  $$
    select * from public.reassign_chore_occurrence(
      '4a100000-0000-4000-8000-000000000006',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.series_change_reassigned_id')::uuid,
      1,
      '30000000-0000-4000-8000-000000000102'
    )
  $$,
  'future matching slot receives a one-occurrence assignee override'
);

select set_config(
  'kinflow.test.series_change_skipped_id',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.series_change_id')::uuid
      and occurrence.recurrence_local_date =
        current_setting('kinflow.test.series_change_today')::date + 21
  ),
  true
);
select lives_ok(
  $$
    select * from public.skip_chore_occurrence(
      '4a100000-0000-4000-8000-000000000007',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.series_change_skipped_id')::uuid,
      1
    )
  $$,
  'future matching slot receives a skip override'
);

reset role;
set local role service_role;
select is(
  (
    select result.claimed_count
    from public.run_chore_horizon_worker(
      statement_timestamp(),
      365,
      7,
      100,
      current_setting('kinflow.test.series_change_id')::uuid
    ) as result
  ),
  1,
  'worker establishes old-revision coverage before the edit'
);
reset role;
select ok(
  exists (
    select 1
    from app_private.chore_materialization_states as state
    where state.series_id =
      current_setting('kinflow.test.series_change_id')::uuid
      and state.revision_id =
        current_setting('kinflow.test.series_change_revision_1')::uuid
  ),
  'old revision has a worker coverage record to invalidate'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select concat_ws(
      ':', result.revision_number, result.version,
      result.effective_local_date::text, result.rebuilt_count,
      result.cancelled_count, result.preserved_completed_count,
      result.changed
    )
    from public.update_repeating_chore_series(
      '4a200000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.series_change_id')::uuid,
      1,
      'Series edit new title',
      'Series edit new notes',
      '30000000-0000-4000-8000-000000000102',
      '10:30',
      jsonb_build_object(
        'frequency', 'weekly',
        'interval', 1,
        'weekdays', jsonb_build_array(
          (array['MO','TU','WE','TH','FR','SA','SU'])[
            extract(
              isodow from current_setting(
                'kinflow.test.series_change_today'
              )::date
            )::integer
          ]
        ),
        'end', jsonb_build_object('type', 'never')
      )
    ) as result
  ),
  '2:2:' || current_setting('kinflow.test.series_change_today') || ':53:312:1:t',
  'owner update creates revision two and rebuilds the exact future horizon'
);
select set_config(
  'kinflow.test.series_change_revision_2',
  (
    select series.active_revision_id::text
    from public.chore_series as series
    where series.id = current_setting('kinflow.test.series_change_id')::uuid
  ),
  true
);

select is(
  (
    select concat_ws(
      ':', series.version, revision.revision_number,
      revision.effective_local_date::text,
      revision.title, revision.description,
      revision.default_assignee_member_id::text,
      revision.due_local_time::text,
      revision.recurrence_rule->>'frequency'
    )
    from public.chore_series as series
    join public.chore_series_revisions as revision
      on revision.id = series.active_revision_id
    where series.id = current_setting('kinflow.test.series_change_id')::uuid
  ),
  '2:2:' || current_setting('kinflow.test.series_change_today')
    || ':Series edit new title:Series edit new notes:'
    || '30000000-0000-4000-8000-000000000102:10:30:00:weekly',
  'series points to the immutable normalized revision snapshot'
);
select is(
  (
    select concat_ws(':', revision.title, revision.description)
    from public.chore_series_revisions as revision
    where revision.id =
      current_setting('kinflow.test.series_change_revision_1')::uuid
  ),
  'Series edit old title:Series edit old notes',
  'previous revision content remains unchanged'
);
select is(
  (
    select concat_ws(
      ':', occurrence.status::text, occurrence.version,
      revision.title, occurrence.completed_at is not null
    )
    from public.chore_occurrences as occurrence
    join public.chore_series_revisions as revision
      on revision.id = occurrence.revision_id
    where occurrence.series_id =
      current_setting('kinflow.test.series_change_id')::uuid
      and occurrence.recurrence_local_date =
        current_setting('kinflow.test.series_change_today')::date - 2
  ),
  'completed:2:Series edit old title:t',
  'past completed occurrence and old content snapshot are preserved'
);
select is(
  (
    select concat_ws(
      ':', occurrence.status::text, occurrence.version,
      revision.title
    )
    from public.chore_occurrences as occurrence
    join public.chore_series_revisions as revision
      on revision.id = occurrence.revision_id
    where occurrence.series_id =
      current_setting('kinflow.test.series_change_id')::uuid
      and occurrence.recurrence_local_date =
        current_setting('kinflow.test.series_change_today')::date - 1
  ),
  'skipped:2:Series edit old title',
  'past skipped occurrence remains an untouched historical exception'
);
select is(
  (
    select concat_ws(
      ':', occurrence.status::text, occurrence.version,
      occurrence.revision_id::text, revision.title,
      occurrence.completed_at is not null
    )
    from public.chore_occurrences as occurrence
    join public.chore_series_revisions as revision
      on revision.id = occurrence.revision_id
    where occurrence.series_id =
      current_setting('kinflow.test.series_change_id')::uuid
      and occurrence.recurrence_local_date =
        current_setting('kinflow.test.series_change_today')::date + 2
  ),
  'completed:2:'
    || current_setting('kinflow.test.series_change_revision_1')
    || ':Series edit old title:t',
  'future completed occurrence stays on its original revision and content'
);
select is(
  (
    select concat_ws(
      ':', occurrence.id::text, occurrence.status::text,
      occurrence.version, occurrence.recurrence_local_date::text,
      occurrence.due_local_date::text,
      occurrence.assignee_member_id::text,
      to_char(
        occurrence.due_at at time zone 'Asia/Seoul',
        'HH24:MI'
      )
    )
    from public.chore_occurrences as occurrence
    where occurrence.id = current_setting(
      'kinflow.test.series_change_rescheduled_id'
    )::uuid
  ),
  current_setting('kinflow.test.series_change_rescheduled_id')
    || ':scheduled:3:'
    || (current_setting('kinflow.test.series_change_today')::date + 7)::text
    || ':'
    || (current_setting('kinflow.test.series_change_today')::date + 7)::text
    || ':30000000-0000-4000-8000-000000000102:10:30',
  'matching rescheduled slot reuses identity and resets to new defaults'
);
select is(
  (
    select concat_ws(
      ':', occurrence.id::text, occurrence.status::text,
      occurrence.version, occurrence.assignee_member_id::text,
      occurrence.revision_id::text
    )
    from public.chore_occurrences as occurrence
    where occurrence.id = current_setting(
      'kinflow.test.series_change_reassigned_id'
    )::uuid
  ),
  current_setting('kinflow.test.series_change_reassigned_id')
    || ':scheduled:3:30000000-0000-4000-8000-000000000102:'
    || current_setting('kinflow.test.series_change_revision_2'),
  'matching reassigned slot keeps identity and adopts the new revision default'
);
select is(
  (
    select concat_ws(
      ':', occurrence.id::text, occurrence.status::text,
      occurrence.version, occurrence.revision_id::text
    )
    from public.chore_occurrences as occurrence
    where occurrence.id = current_setting(
      'kinflow.test.series_change_skipped_id'
    )::uuid
  ),
  current_setting('kinflow.test.series_change_skipped_id')
    || ':scheduled:3:'
    || current_setting('kinflow.test.series_change_revision_2'),
  'matching skipped slot keeps identity and is rebuilt as scheduled'
);
select is(
  (
    select concat_ws(
      ':', occurrence.status::text, occurrence.version,
      occurrence.revision_id::text
    )
    from public.chore_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.series_change_id')::uuid
      and occurrence.recurrence_local_date =
        current_setting('kinflow.test.series_change_today')::date + 1
  ),
  'cancelled:2:' || current_setting('kinflow.test.series_change_revision_1'),
  'obsolete future slot is retained as cancelled history'
);
select is(
  (
    select concat_ws(
      ':', count(*) filter (where occurrence.status = 'scheduled'),
      count(*) filter (where occurrence.status = 'cancelled'),
      count(*) filter (where occurrence.status = 'completed'),
      count(distinct occurrence.occurrence_key)
    )
    from public.chore_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.series_change_id')::uuid
      and occurrence.recurrence_local_date >=
        current_setting('kinflow.test.series_change_today')::date
  ),
  '53:312:1:366',
  'future edit leaves an exact unique scheduled/cancelled/completed partition'
);
reset role;
select ok(
  not exists (
    select 1
    from app_private.chore_materialization_states as state
    where state.series_id =
      current_setting('kinflow.test.series_change_id')::uuid
  ),
  'series edit resets old worker coverage'
);
select is(
  (
    select concat_ws(
      ':', event.operation, event.effective_local_date::text,
      event.rebuilt_count, event.cancelled_count,
      event.preserved_completed_count, event.series_version
    )
    from public.chore_series_change_events as event
    where event.series_id =
      current_setting('kinflow.test.series_change_id')::uuid
  ),
  'updated:' || current_setting('kinflow.test.series_change_today')
    || ':53:312:1:2',
  'update records one content-free aggregate event'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select concat_ws(
      ':', result.revision_number, result.version,
      result.rebuilt_count, result.cancelled_count,
      result.preserved_completed_count, result.changed
    )
    from public.update_repeating_chore_series(
      '4a200000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.series_change_id')::uuid,
      1,
      'Series edit new title',
      'Series edit new notes',
      '30000000-0000-4000-8000-000000000102',
      '10:30',
      jsonb_build_object(
        'frequency', 'weekly',
        'interval', 1,
        'weekdays', jsonb_build_array(
          (array['MO','TU','WE','TH','FR','SA','SU'])[
            extract(
              isodow from current_setting(
                'kinflow.test.series_change_today'
              )::date
            )::integer
          ]
        ),
        'end', jsonb_build_object('type', 'never')
      )
    ) as result
  ),
  '2:2:53:312:1:f',
  'same update command replays the original summary without a new revision'
);
reset role;
select is(
  (
    select concat_ws(
      ':',
      count(distinct revision.id),
      count(distinct event.id),
      count(distinct request.idempotency_key)
    )
    from public.chore_series_revisions as revision
    left join public.chore_series_change_events as event
      on event.series_id = revision.series_id
    left join app_private.chore_series_change_command_requests as request
      on request.series_id = revision.series_id
    where revision.series_id =
      current_setting('kinflow.test.series_change_id')::uuid
  ),
  '2:1:1',
  'update replay creates no duplicate revision, event, or command row'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.update_repeating_chore_series(
      '4a200000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.series_change_id')::uuid,
      2,
      'Different replay title',
      null,
      '30000000-0000-4000-8000-000000000102',
      '10:30',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    )
  $$,
  'KFC04',
  'idempotency key reused with different chore input',
  'same command UUID with different input is rejected'
);
select throws_ok(
  $$
    select * from public.update_repeating_chore_series(
      '4a200000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.series_change_id')::uuid,
      1,
      'Stale series update',
      null,
      '30000000-0000-4000-8000-000000000101',
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    )
  $$,
  'KFC05',
  'chore series version conflict',
  'stale whole-series update loses optimistic concurrency'
);
select throws_ok(
  $$
    select * from public.update_repeating_chore_series(
      '4a200000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.series_change_id')::uuid,
      2,
      'Series edit new title',
      'Series edit new notes',
      '30000000-0000-4000-8000-000000000102',
      '10:30',
      (
        select revision.recurrence_rule
        from public.chore_series as series
        join public.chore_series_revisions as revision
          on revision.id = series.active_revision_id
        where series.id =
          current_setting('kinflow.test.series_change_id')::uuid
      )
    )
  $$,
  'KFC06',
  'chore series transition not allowed',
  'identical series input does not create an empty revision'
);
select throws_ok(
  $$
    select * from public.update_repeating_chore_series(
      '4a200000-0000-4000-8000-000000000004',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.series_change_id')::uuid,
      2,
      'Expired recurrence',
      null,
      '30000000-0000-4000-8000-000000000101',
      null,
      jsonb_build_object(
        'frequency', 'daily',
        'interval', 1,
        'end', jsonb_build_object(
          'type', 'until',
          'localDate', (
            current_setting('kinflow.test.series_change_today')::date - 1
          )::text
        )
      )
    )
  $$,
  'KFC07',
  'invalid chore recurrence rule',
  'until boundary cannot precede server-derived household today'
);
select throws_ok(
  $$
    select * from public.update_repeating_chore_series(
      '4a200000-0000-4000-8000-000000000005',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.series_change_id')::uuid,
      2,
      'Second precision invalid',
      null,
      '30000000-0000-4000-8000-000000000101',
      '10:30:01',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    )
  $$,
  'KFC07',
  'invalid chore recurrence rule',
  'series update rejects second precision local times'
);
select throws_ok(
  $$
    select * from public.update_repeating_chore_series(
      '4a200000-0000-4000-8000-000000000006',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.series_change_id')::uuid,
      2,
      'Cross household assignee',
      null,
      '30000000-0000-4000-8000-000000000201',
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'cross-household default assignee is rejected'
);

select is(
  (
    select concat_ws(
      ':', today.title, today.series_version,
      today.series_default_assignee_member_id::text,
      today.series_due_local_time::text,
      today.recurrence_rule->>'frequency',
      today.can_manage_series
    )
    from public.get_today_chores_v2(
      '20000000-0000-4000-8000-000000000101'
    ) as today
    where today.series_id =
      current_setting('kinflow.test.series_change_id')::uuid
  ),
  'Series edit new title:2:'
    || '30000000-0000-4000-8000-000000000102:10:30:00:weekly:t',
  'owner Today payload carries the strict active series management snapshot'
);

-- Member and outsider denial is enforced independently of the UI hint.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select today.can_manage_series
    from public.get_today_chores_v2(
      '20000000-0000-4000-8000-000000000101'
    ) as today
    where today.series_id =
      current_setting('kinflow.test.series_change_id')::uuid
  ),
  false,
  'member Today payload does not advertise series management'
);
select throws_ok(
  $$
    select * from public.cancel_repeating_chore_series(
      '4a300000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.series_change_id')::uuid,
      2
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'member cannot terminate the whole series'
);
select throws_ok(
  $$
    select * from public.update_repeating_chore_series(
      '4a300000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.series_change_id')::uuid,
      2,
      'Member edit denied',
      null,
      '30000000-0000-4000-8000-000000000102',
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'member cannot update the whole series'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$
    select * from public.cancel_repeating_chore_series(
      '4a300000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.series_change_id')::uuid,
      2
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'outsider cannot terminate another household series'
);
select is(
  (
    select count(*)
    from public.chore_series_change_events as event
    where event.series_id =
      current_setting('kinflow.test.series_change_id')::uuid
  ),
  0::bigint,
  'event RLS hides another household series history'
);

reset role;
set local role service_role;
select is(
  (
    select concat_ws(
      ':', result.claimed_count, result.succeeded_count,
      result.failed_count, result.inserted_count
    )
    from public.run_chore_horizon_worker(
      statement_timestamp(),
      365,
      7,
      100,
      current_setting('kinflow.test.series_change_id')::uuid
    ) as result
  ),
  '1:1:0:0',
  'worker replay recognizes the new revision without duplicates'
);
reset role;
select ok(
  exists (
    select 1
    from app_private.chore_materialization_states as state
    where state.series_id =
      current_setting('kinflow.test.series_change_id')::uuid
      and state.revision_id =
        current_setting('kinflow.test.series_change_revision_2')::uuid
  ),
  'worker coverage is re-established against revision two'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '4a400000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        where occurrence.series_id =
          current_setting('kinflow.test.series_change_id')::uuid
          and occurrence.recurrence_local_date =
            current_setting('kinflow.test.series_change_today')::date + 28
      ),
      2,
      true
    )
  $$,
  'one new-revision future occurrence is completed before termination'
);
select is(
  (
    select concat_ws(
      ':', result.effective_local_date::text, result.version,
      result.cancelled_count, result.preserved_completed_count,
      result.changed
    )
    from public.cancel_repeating_chore_series(
      '4a400000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.series_change_id')::uuid,
      2
    ) as result
  ),
  current_setting('kinflow.test.series_change_today') || ':3:52:2:t',
  'termination soft-deletes series and cancels only future incomplete slots'
);
reset role;
select is(
  (
    select concat_ws(
      ':', series.version, series.deleted_at is not null,
      series.active_revision_id::text
    )
    from public.chore_series as series
    where series.id = current_setting('kinflow.test.series_change_id')::uuid
  ),
  '3:t:' || current_setting('kinflow.test.series_change_revision_2'),
  'termination preserves the active revision identity on a soft-deleted series'
);
select is(
  (
    select concat_ws(
      ':', count(*) filter (where occurrence.status = 'cancelled'),
      count(*) filter (where occurrence.status = 'completed')
    )
    from public.chore_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.series_change_id')::uuid
      and occurrence.recurrence_local_date >=
        current_setting('kinflow.test.series_change_today')::date
  ),
  '364:2',
  'termination retains prior obsolete rows and both completed occurrences'
);
reset role;
select ok(
  not exists (
    select 1
    from app_private.chore_materialization_states as state
    where state.series_id =
      current_setting('kinflow.test.series_change_id')::uuid
  ),
  'termination removes stale operational coverage state'
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
    from public.get_today_chores_v2(
      '20000000-0000-4000-8000-000000000101'
    ) as today
    where today.series_id =
      current_setting('kinflow.test.series_change_id')::uuid
  ),
  0::bigint,
  'soft-deleted series disappears from Today'
);
select is(
  (
    select concat_ws(
      ':', result.version, result.cancelled_count,
      result.preserved_completed_count, result.changed
    )
    from public.cancel_repeating_chore_series(
      '4a400000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.series_change_id')::uuid,
      2
    ) as result
  ),
  '3:52:2:f',
  'cancellation replay succeeds after soft deletion without more mutations'
);
select throws_ok(
  $$
    select * from public.cancel_repeating_chore_series(
      '4a400000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.series_change_id')::uuid,
      3
    )
  $$,
  'KFC04',
  'idempotency key reused with different chore input',
  'cancellation command UUID cannot be reused with different input'
);
select is(
  (
    select concat_ws(
      ':', count(*),
      count(*) filter (where event.operation = 'updated'),
      count(*) filter (where event.operation = 'cancelled')
    )
    from public.chore_series_change_events as event
    where event.series_id =
      current_setting('kinflow.test.series_change_id')::uuid
  ),
  '2:1:1',
  'series history contains exactly one update and one termination event'
);
reset role;
select is(
  (
    select count(*)
    from app_private.chore_series_change_command_requests as request
    where request.series_id =
      current_setting('kinflow.test.series_change_id')::uuid
  ),
  2::bigint,
  'private idempotency state contains exactly the two successful commands'
);

-- One-time compatibility and immutable identity protections.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '4a500000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Series change one-time compatibility',
      null,
      '30000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.series_change_today')::date,
      null
    )
  $$,
  'legacy one-time create populates new immutable snapshot columns'
);
select ok(
  exists (
    select 1
    from public.chore_occurrences as occurrence
    join public.chore_series_revisions as revision
      on revision.id = occurrence.revision_id
    join public.chore_series as series
      on series.id = occurrence.series_id
    where series.title = 'Series change one-time compatibility'
      and revision.title = series.title
      and occurrence.recurrence_local_date = occurrence.due_local_date
  ),
  'legacy insert triggers populate revision content and recurrence slot'
);
select throws_ok(
  $$
    select * from public.cancel_repeating_chore_series(
      '4a500000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      (
        select series.id
        from public.chore_series as series
        where series.title = 'Series change one-time compatibility'
      ),
      1
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'repeating-series termination cannot target a one-time chore'
);

reset role;
select throws_ok(
  $$
    update public.chore_series_revisions
    set title = 'History rewrite denied'
    where id = current_setting(
      'kinflow.test.series_change_revision_1'
    )::uuid
  $$,
  '55000',
  'chore series revisions are immutable',
  'database-owner update cannot rewrite an immutable revision'
);
select throws_ok(
  $$
    update public.chore_occurrences
    set recurrence_local_date = recurrence_local_date + 1
    where id = current_setting(
      'kinflow.test.series_change_rescheduled_id'
    )::uuid
  $$,
  '55000',
  'chore occurrence recurrence identity is immutable',
  'database-owner update cannot rewrite a stable recurrence slot'
);
select throws_ok(
  $$
    update public.chore_series_change_events
    set rebuilt_count = rebuilt_count + 1
    where series_id = current_setting(
      'kinflow.test.series_change_id'
    )::uuid
  $$,
  '55000',
  'chore series change events are immutable',
  'database-owner update cannot rewrite series change history'
);
select throws_ok(
  $$
    delete from public.chore_series_change_events
    where series_id = current_setting(
      'kinflow.test.series_change_id'
    )::uuid
  $$,
  '55000',
  'chore series change events are immutable',
  'database-owner delete cannot remove series change history'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    update public.chore_series
    set title = 'Direct series write denied'
    where id = current_setting('kinflow.test.series_change_id')::uuid
  $$,
  '42501',
  null,
  'authenticated client cannot bypass mediated series mutation'
);
select throws_ok(
  $$
    insert into public.chore_series_change_events (
      household_id,
      series_id,
      operation,
      previous_revision_id,
      effective_local_date,
      actor_member_id,
      rebuilt_count,
      cancelled_count,
      preserved_completed_count,
      series_version,
      correlation_id
    )
    values (
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.series_change_id')::uuid,
      'cancelled',
      current_setting('kinflow.test.series_change_revision_2')::uuid,
      current_setting('kinflow.test.series_change_today')::date,
      '30000000-0000-4000-8000-000000000101',
      0,
      0,
      0,
      3,
      '4a500000-0000-4000-8000-000000000003'
    )
  $$,
  '42501',
  null,
  'authenticated client cannot forge series change history'
);
select throws_ok(
  $$
    select * from app_private.chore_series_change_command_requests
  $$,
  '42501',
  null,
  'authenticated client cannot inspect private series command hashes'
);

-- Admin receives the same mediated capability while a plain member did not.
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '4a600000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Admin series fixture',
      null,
      '30000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.series_change_today')::date,
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":2}}'
    )
  $$,
  'owner creates a small fixture for admin mutation'
);
reset role;
update public.household_members
set role = 'admin'
where id = '30000000-0000-4000-8000-000000000102';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select result.changed
    from public.update_repeating_chore_series(
      '4a600000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      (
        select series.id
        from public.chore_series as series
        where series.title = 'Admin series fixture'
      ),
      1,
      'Admin series updated',
      null,
      '30000000-0000-4000-8000-000000000101',
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":2}}'
    ) as result
  ),
  true,
  'active admin can update a whole repeating series'
);
select ok(
  exists (
    select 1
    from public.chore_series_change_events as event
    join public.chore_series as series on series.id = event.series_id
    where series.title = 'Admin series updated'
      and event.actor_member_id =
        '30000000-0000-4000-8000-000000000102'
  ),
  'admin mutation audit records the authenticated actor member'
);
select is(
  (
    select today.can_manage_series
    from public.get_today_chores_v2(
      '20000000-0000-4000-8000-000000000101'
    ) as today
    where today.title = 'Admin series updated'
  ),
  true,
  'admin Today payload advertises the server-authorized management action'
);

select * from finish();
rollback;
