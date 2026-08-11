begin;
set constraints all deferred;

select plan(48);

select has_function(
  'public',
  'cancel_recurring_calendar_series_from_occurrence',
  array['uuid', 'uuid', 'uuid', 'uuid', 'bigint'],
  'selected-occurrence Calendar series cancellation command exists'
);
select has_function(
  'app_private',
  'cancel_recurring_calendar_series_at_boundary',
  array['uuid', 'uuid', 'uuid', 'uuid', 'bigint'],
  'legacy and selected cancellation commands share one boundary engine'
);
select ok(
  (
    select pg_catalog.bool_and(procedure.prosecdef)
      and pg_catalog.bool_and(
        procedure.proconfig @> array['search_path=""']::text[]
      )
    from pg_catalog.pg_proc as procedure
    join pg_catalog.pg_namespace as namespace
      on namespace.oid = procedure.pronamespace
    where namespace.nspname in ('public', 'app_private')
      and procedure.proname in (
        'cancel_recurring_calendar_series',
        'cancel_recurring_calendar_series_from_occurrence',
        'cancel_recurring_calendar_series_at_boundary'
      )
  ),
  'all Calendar cancellation boundary functions are hardened definers'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.cancel_recurring_calendar_series_from_occurrence(uuid,uuid,uuid,uuid,bigint)',
    'execute'
  ),
  'authenticated clients can execute selected-boundary cancellation'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.cancel_recurring_calendar_series_from_occurrence(uuid,uuid,uuid,uuid,bigint)',
    'execute'
  ),
  'anonymous clients cannot execute selected-boundary cancellation'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.cancel_recurring_calendar_series_at_boundary(uuid,uuid,uuid,uuid,bigint)',
    'execute'
  ),
  'clients cannot bypass the private cancellation boundary engine'
);
select is(
  (
    select pg_catalog.string_agg(
      parameter_name, ',' order by ordinal_position
    )
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name =
        'cancel_recurring_calendar_series_from_occurrence_' || (
          'public.cancel_recurring_calendar_series_from_occurrence(uuid,uuid,uuid,uuid,bigint)'
            ::regprocedure::oid::text
        )
      and parameter_mode = 'OUT'
  ),
  'household_id,household_timezone,household_local_date,series_id,effective_local_date,version,cancelled_count,preserved_past_count,terminal_revision_id,terminal_revision_number,changed',
  'selected cancellation returns the exact compact additive envelope'
);
select is(
  (
    select pg_catalog.string_agg(
      parameter_name, ',' order by ordinal_position
    )
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name = 'cancel_recurring_calendar_series_' || (
        'public.cancel_recurring_calendar_series(uuid,uuid,uuid,bigint)'
          ::regprocedure::oid::text
      )
      and parameter_mode = 'OUT'
  ),
  'household_id,household_timezone,household_local_date,series_id,effective_local_date,version,cancelled_count,preserved_past_count,changed',
  'legacy whole-series cancellation keeps its exact result envelope'
);
select hasnt_column(
  'public',
  'event_series',
  'cancelled_from_local_date',
  'future cancellation uses immutable revisions instead of a cutoff column'
);
select hasnt_column(
  'app_private',
  'calendar_series_change_command_requests',
  'effective_occurrence_id',
  'private replay state stores no selected occurrence identity'
);
select throws_ok(
  $$
    select *
    from public.cancel_recurring_calendar_series_from_occurrence(
      '4b000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      '4b100000-0000-4000-8000-000000000001',
      '4b200000-0000-4000-8000-000000000001',
      1
    )
  $$,
  'KFE01',
  'authentication required',
  'the selected cancellation derives identity from JWT'
);

select set_config(
  'kinflow.test.calendar_cancel_today',
  (pg_catalog.statement_timestamp() at time zone 'Asia/Seoul')::date::text,
  true
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select result.materialized_count
    from public.create_recurring_calendar_event(
      '4b010000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Calendar cancel-from old', 'Old cancellation notes', false,
      current_setting('kinflow.test.calendar_cancel_today')::date - 2,
      time '08:00', 60, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array[
        '30000000-0000-4000-8000-000000000101'::uuid,
        '30000000-0000-4000-8000-000000000102'::uuid
      ]
    ) as result
  ),
  366,
  'daily cancellation fixture materializes its bounded source window'
);
select set_config(
  'kinflow.test.calendar_cancel_series',
  (
    select series.id::text
    from public.event_series as series
    where series.title = 'Calendar cancel-from old'
  ),
  true
);
select set_config(
  'kinflow.test.calendar_cancel_revision_1',
  (
    select series.active_revision_id::text
    from public.event_series as series
    where series.id =
      current_setting('kinflow.test.calendar_cancel_series')::uuid
  ),
  true
);
select set_config(
  'kinflow.test.calendar_cancel_boundary',
  (current_setting('kinflow.test.calendar_cancel_today')::date + 5)::text,
  true
);
select set_config(
  'kinflow.test.calendar_cancel_target',
  (
    select occurrence.id::text
    from public.event_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.calendar_cancel_series')::uuid
      and occurrence.recurrence_local_start_date =
        current_setting('kinflow.test.calendar_cancel_boundary')::date
  ),
  true
);
select set_config(
  'kinflow.test.calendar_cancel_prefix_exception',
  (
    select occurrence.id::text
    from public.event_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.calendar_cancel_series')::uuid
      and occurrence.recurrence_local_start_date =
        current_setting('kinflow.test.calendar_cancel_boundary')::date - 1
  ),
  true
);
select set_config(
  'kinflow.test.calendar_cancel_later_exception',
  (
    select occurrence.id::text
    from public.event_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.calendar_cancel_series')::uuid
      and occurrence.recurrence_local_start_date =
        current_setting('kinflow.test.calendar_cancel_boundary')::date + 8
  ),
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.occurrence_version, result.exception_version,
      result.cancelled, result.changed
    )
    from public.update_recurring_calendar_occurrence(
      '4b010000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_cancel_series')::uuid,
      current_setting('kinflow.test.calendar_cancel_prefix_exception')::uuid,
      1, 'Preserved prefix exception', 'Moved beyond boundary', false,
      current_setting('kinflow.test.calendar_cancel_boundary')::date + 20,
      time '12:30', 45, null, 'Asia/Seoul', 'later',
      array['30000000-0000-4000-8000-000000000102'::uuid]
    ) as result
  ),
  '2:1:f:t',
  'a prefix exception is moved beyond the future cancellation display date'
);
select set_config(
  'kinflow.test.calendar_cancel_prefix_exception_revision',
  (
    select occurrence.revision_id::text
    from public.event_occurrences as occurrence
    where occurrence.id = current_setting(
      'kinflow.test.calendar_cancel_prefix_exception'
    )::uuid
  ),
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.occurrence_version, result.exception_version,
      result.cancelled, result.changed
    )
    from public.update_recurring_calendar_occurrence(
      '4b010000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_cancel_series')::uuid,
      current_setting('kinflow.test.calendar_cancel_later_exception')::uuid,
      1, 'Cancelled later exception', 'Moved before boundary', false,
      current_setting('kinflow.test.calendar_cancel_boundary')::date - 3,
      time '14:15', 30, null, 'Asia/Seoul', 'earlier',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    ) as result
  ),
  '2:1:f:t',
  'a later recurrence-slot exception is moved before the boundary display date'
);
select set_config(
  'kinflow.test.calendar_cancel_later_exception_revision',
  (
    select occurrence.revision_id::text
    from public.event_occurrences as occurrence
    where occurrence.id = current_setting(
      'kinflow.test.calendar_cancel_later_exception'
    )::uuid
  ),
  true
);

select is(
  (
    select pg_catalog.concat_ws(
      ':', result.effective_local_date::text, result.version,
      result.cancelled_count, result.preserved_past_count,
      result.terminal_revision_number, result.changed
    )
    from public.cancel_recurring_calendar_series_from_occurrence(
      '4b020000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_cancel_series')::uuid,
      current_setting('kinflow.test.calendar_cancel_target')::uuid,
      1
    ) as result
  ),
  current_setting('kinflow.test.calendar_cancel_boundary')
    || ':2:359:7:4:t',
  'the server derives the boundary and creates one bounded terminal revision'
);
select set_config(
  'kinflow.test.calendar_cancel_terminal_revision',
  (
    select series.active_revision_id::text
    from public.event_series as series
    where series.id =
      current_setting('kinflow.test.calendar_cancel_series')::uuid
  ),
  true
);
select ok(
  exists (
    select 1
    from public.event_series as series
    join public.event_series_revisions as revision
      on revision.household_id = series.household_id
     and revision.series_id = series.id
     and revision.id = series.active_revision_id
    where series.id =
      current_setting('kinflow.test.calendar_cancel_series')::uuid
      and series.version = 2
      and series.ended_at is null
      and revision.revision_number = 4
      and revision.snapshot_title = 'Calendar cancel-from old'
      and revision.snapshot_description = 'Old cancellation notes'
      and revision.local_start_time = time '08:00'
      and revision.duration_minutes = 60
      and revision.recurrence_rule->'end'->>'type' = 'until'
      and revision.recurrence_rule->'end'->>'localDate' =
        (current_setting('kinflow.test.calendar_cancel_boundary')::date - 1)
          ::text
  ),
  'the terminal revision preserves source content and ends before the boundary'
);
select is(
  (
    select pg_catalog.array_agg(
      participant.member_id order by participant.member_id
    )
    from public.event_revision_participants as participant
    where participant.revision_id = current_setting(
      'kinflow.test.calendar_cancel_terminal_revision'
    )::uuid
  ),
  array[
    '30000000-0000-4000-8000-000000000101'::uuid,
    '30000000-0000-4000-8000-000000000102'::uuid
  ],
  'the terminal revision keeps the exact participant snapshot'
);
select ok(
  exists (
    select 1
    from public.event_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.calendar_cancel_series')::uuid
      and occurrence.recurrence_local_start_date =
        current_setting('kinflow.test.calendar_cancel_today')::date - 2
      and occurrence.revision_id = current_setting(
        'kinflow.test.calendar_cancel_revision_1'
      )::uuid
      and occurrence.status = 'scheduled'
      and occurrence.version = 1
  ),
  'historical occurrence identity, revision, status and version stay exact'
);
select ok(
  exists (
    select 1
    from public.event_occurrences as occurrence
    join public.event_series_revisions as revision
      on revision.id = occurrence.revision_id
    where occurrence.series_id =
      current_setting('kinflow.test.calendar_cancel_series')::uuid
      and occurrence.recurrence_local_start_date =
        current_setting('kinflow.test.calendar_cancel_boundary')::date - 2
      and occurrence.revision_id = current_setting(
        'kinflow.test.calendar_cancel_terminal_revision'
      )::uuid
      and occurrence.status = 'scheduled'
      and (occurrence.starts_at at time zone occurrence.timezone)::time =
        time '08:00'
      and revision.snapshot_title = 'Calendar cancel-from old'
  ),
  'an actionable prefix stays scheduled on the terminal active revision'
);
select ok(
  exists (
    select 1
    from public.event_occurrences as occurrence
    join public.event_occurrence_exceptions as exception
      on exception.occurrence_id = occurrence.id
    join public.event_series_revisions as revision
      on revision.id = occurrence.revision_id
    where occurrence.id = current_setting(
      'kinflow.test.calendar_cancel_prefix_exception'
    )::uuid
      and occurrence.revision_id = current_setting(
        'kinflow.test.calendar_cancel_prefix_exception_revision'
      )::uuid
      and occurrence.recurrence_local_start_date =
        current_setting('kinflow.test.calendar_cancel_boundary')::date - 1
      and occurrence.local_start_date =
        current_setting('kinflow.test.calendar_cancel_boundary')::date + 20
      and occurrence.status = 'scheduled'
      and occurrence.version = 2
      and exception.version = 1
      and not exception.cancelled
      and revision.snapshot_title = 'Preserved prefix exception'
  ),
  'a prefix exception remains exact even when displayed after the boundary'
);
select ok(
  exists (
    select 1
    from public.event_occurrences as occurrence
    where occurrence.id =
      current_setting('kinflow.test.calendar_cancel_target')::uuid
      and occurrence.recurrence_local_start_date =
        current_setting('kinflow.test.calendar_cancel_boundary')::date
      and occurrence.status = 'cancelled'
      and occurrence.version = 2
  ),
  'the selected target becomes cancelled history'
);
select ok(
  exists (
    select 1
    from public.event_occurrences as occurrence
    join public.event_occurrence_exceptions as exception
      on exception.occurrence_id = occurrence.id
    where occurrence.id = current_setting(
      'kinflow.test.calendar_cancel_later_exception'
    )::uuid
      and occurrence.revision_id = current_setting(
        'kinflow.test.calendar_cancel_later_exception_revision'
      )::uuid
      and occurrence.local_start_date =
        current_setting('kinflow.test.calendar_cancel_boundary')::date - 3
      and occurrence.status = 'cancelled'
      and occurrence.version = 3
      and exception.version = 1
      and not exception.cancelled
  ),
  'a moved later exception is cancelled by immutable recurrence slot'
);
select is(
  (
    select pg_catalog.count(*)
    from public.event_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.calendar_cancel_series')::uuid
      and occurrence.recurrence_local_start_date >=
        current_setting('kinflow.test.calendar_cancel_boundary')::date
      and occurrence.status = 'scheduled'
  ),
  0::bigint,
  'no scheduled occurrence survives at or after the selected boundary'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', event.operation, event.effective_local_date::text,
      event.cancelled_count, event.preserved_exception_count,
      event.preserved_past_count, event.series_version,
      event.materialized_through::text
    )
    from public.event_series_change_events as event
    where event.series_id =
      current_setting('kinflow.test.calendar_cancel_series')::uuid
      and event.operation = 'cancelled'
  ),
  'cancelled:' || current_setting('kinflow.test.calendar_cancel_boundary')
    || ':359:1:7:2:'
    || (current_setting('kinflow.test.calendar_cancel_boundary')::date - 1),
  'series history records only aggregate selected-boundary cancellation state'
);
reset role;
select ok(
  exists (
    select 1
    from app_private.calendar_materialization_states as state
    where state.series_id =
      current_setting('kinflow.test.calendar_cancel_series')::uuid
      and state.revision_id = current_setting(
        'kinflow.test.calendar_cancel_terminal_revision'
      )::uuid
      and state.covered_through =
        current_setting('kinflow.test.calendar_cancel_boundary')::date - 1
      and state.next_repair_at = 'infinity'::timestamptz
      and state.last_result = 'succeeded'
  ),
  'terminal materialization state prevents normal rolling regeneration'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.revision_number, result.version,
      result.recurrence_rule->'end'->>'type',
      result.recurrence_rule->'end'->>'localDate'
    )
    from public.get_recurring_calendar_series(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_cancel_series')::uuid
    ) as result
  ),
  '4:2:until:'
    || (current_setting('kinflow.test.calendar_cancel_boundary')::date - 1),
  'the surviving prefix remains available through recurring series detail'
);
select is(
  (
    select pg_catalog.concat_ws(':', page.title, page.local_start_time::text)
    from public.get_calendar_event_page_v2(
      '20000000-0000-4000-8000-000000000101', 'day',
      current_setting('kinflow.test.calendar_cancel_boundary')::date - 2,
      current_setting('kinflow.test.calendar_cancel_boundary')::date - 1,
      30, null
    ) as page
    where page.series_id =
      current_setting('kinflow.test.calendar_cancel_series')::uuid
  ),
  'Calendar cancel-from old:08:00:00',
  'Calendar reads retain the source content for the surviving prefix'
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.claimed_count, result.succeeded_count,
      result.failed_count, result.changed_count
    )
    from public.run_calendar_horizon_worker(
      pg_catalog.statement_timestamp(), 30, 0, 1,
      current_setting('kinflow.test.calendar_cancel_series')::uuid
    ) as result
  ),
  '1:1:0:0',
  'a targeted worker pass accepts the bounded terminal revision as a no-op'
);
select is(
  (
    select pg_catalog.count(*)
    from public.event_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.calendar_cancel_series')::uuid
      and occurrence.recurrence_local_start_date >=
        current_setting('kinflow.test.calendar_cancel_boundary')::date
      and occurrence.status = 'scheduled'
  ),
  0::bigint,
  'the horizon worker cannot regenerate events beyond the terminal boundary'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', pg_catalog.count(distinct event.id),
      pg_catalog.count(distinct request.idempotency_key),
      pg_catalog.count(distinct audit.id)
    )
    from public.event_series_change_events as event
    join app_private.calendar_series_change_command_requests as request
      on request.series_id = event.series_id
    join app_private.calendar_audit_events as audit
      on audit.series_id = event.series_id
     and audit.action = 'calendar.series_cancelled'
    where event.series_id =
      current_setting('kinflow.test.calendar_cancel_series')::uuid
  ),
  '1:1:1',
  'the first command stores one history, replay and cancellation audit row'
);
select is(
  (
    select audit.occurrence_id
    from app_private.calendar_audit_events as audit
    where audit.series_id =
      current_setting('kinflow.test.calendar_cancel_series')::uuid
      and audit.action = 'calendar.series_cancelled'
  ),
  current_setting('kinflow.test.calendar_cancel_target')::uuid,
  'the content-free audit references the selected target identity'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.effective_local_date::text, result.version,
      result.cancelled_count, result.preserved_past_count,
      result.terminal_revision_number, result.changed
    )
    from public.cancel_recurring_calendar_series_from_occurrence(
      '4b020000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_cancel_series')::uuid,
      current_setting('kinflow.test.calendar_cancel_target')::uuid,
      1
    ) as result
  ),
  current_setting('kinflow.test.calendar_cancel_boundary')
    || ':2:359:7:4:f',
  'the same selected-boundary command replays its original result'
);
select throws_ok(
  $$
    select *
    from public.cancel_recurring_calendar_series_from_occurrence(
      '4b020000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_cancel_series')::uuid,
      current_setting('kinflow.test.calendar_cancel_prefix_exception')::uuid,
      2
    )
  $$,
  'KFE04',
  'idempotency key reused with different calendar input',
  'same key with a different target fails closed'
);
select throws_ok(
  $$
    select *
    from public.update_recurring_calendar_series(
      '4b020000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_cancel_series')::uuid,
      2, 'Collision', null, false,
      current_setting('kinflow.test.calendar_cancel_today')::date - 2,
      time '08:00', 60, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE04',
  'idempotency key reused with different calendar input',
  'a selected cancellation key cannot cross into series update'
);
select throws_ok(
  $$
    select *
    from public.cancel_recurring_calendar_series_from_occurrence(
      '4b020000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_cancel_series')::uuid,
      (
        select occurrence.id
        from public.event_occurrences as occurrence
        where occurrence.series_id =
          current_setting('kinflow.test.calendar_cancel_series')::uuid
          and occurrence.recurrence_local_start_date =
            current_setting('kinflow.test.calendar_cancel_boundary')::date - 2
      ),
      1
    )
  $$,
  'KFE05',
  'stale calendar event version',
  'a new selected cancellation key rejects a stale series version'
);
select throws_ok(
  $$
    select *
    from public.cancel_recurring_calendar_series_from_occurrence(
      '4b020000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_cancel_series')::uuid,
      current_setting('kinflow.test.calendar_cancel_prefix_exception')::uuid,
      2
    )
  $$,
  'KFE03',
  'calendar event not found or forbidden',
  'an explicit exception cannot become a cancellation boundary'
);
select throws_ok(
  $$
    select *
    from public.cancel_recurring_calendar_series_from_occurrence(
      '4b020000-0000-4000-8000-000000000004',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_cancel_series')::uuid,
      '4bffffff-0000-4000-8000-000000000001',
      2
    )
  $$,
  'KFE03',
  'calendar event not found or forbidden',
  'a missing target uses the generic unavailable failure'
);
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$
    select *
    from public.cancel_recurring_calendar_series_from_occurrence(
      '4b020000-0000-4000-8000-000000000005',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_cancel_series')::uuid,
      current_setting('kinflow.test.calendar_cancel_target')::uuid,
      2
    )
  $$,
  'KFE03',
  'calendar event not found or forbidden',
  'an outsider cannot cancel another household series from an occurrence'
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', pg_catalog.count(distinct revision.id),
      pg_catalog.count(distinct event.id),
      pg_catalog.count(distinct request.idempotency_key)
    )
    from public.event_series_revisions as revision
    left join public.event_series_change_events as event
      on event.series_id = revision.series_id
    left join app_private.calendar_series_change_command_requests as request
      on request.series_id = revision.series_id
    where revision.series_id =
      current_setting('kinflow.test.calendar_cancel_series')::uuid
  ),
  '4:1:1',
  'replay and rejected commands create no duplicate terminal state'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select *
    from public.create_recurring_calendar_event(
      '4b030000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Calendar cancel no prefix', null, false,
      current_setting('kinflow.test.calendar_cancel_today')::date,
      time '09:00', 30, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'a first-slot selected cancellation fixture is created'
);
select set_config(
  'kinflow.test.calendar_cancel_no_prefix_series',
  (
    select series.id::text
    from public.event_series as series
    where series.title = 'Calendar cancel no prefix'
  ),
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.effective_local_date::text, result.version,
      result.cancelled_count, result.preserved_past_count,
      result.terminal_revision_id is null,
      result.terminal_revision_number is null, result.changed
    )
    from public.cancel_recurring_calendar_series_from_occurrence(
      '4b030000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_cancel_no_prefix_series')::uuid,
      (
        select occurrence.id
        from public.event_occurrences as occurrence
        where occurrence.series_id = current_setting(
          'kinflow.test.calendar_cancel_no_prefix_series'
        )::uuid
          and occurrence.recurrence_local_start_date =
            current_setting('kinflow.test.calendar_cancel_today')::date
      ),
      1
    ) as result
  ),
  current_setting('kinflow.test.calendar_cancel_today') || ':2:366:0:t:t:t',
  'a first-slot boundary ends the series without a terminal revision'
);
select ok(
  exists (
    select 1
    from public.event_series as series
    where series.id = current_setting(
      'kinflow.test.calendar_cancel_no_prefix_series'
    )::uuid
      and series.version = 2
      and series.ended_at is not null
      and series.ended_effective_local_date =
        current_setting('kinflow.test.calendar_cancel_today')::date
  ),
  'the no-prefix series records its exact server-derived end boundary'
);
reset role;
select is(
  (
    select pg_catalog.count(*)
    from app_private.calendar_materialization_states as state
    where state.series_id = current_setting(
      'kinflow.test.calendar_cancel_no_prefix_series'
    )::uuid
  ),
  0::bigint,
  'an ended no-prefix series has no rolling materialization state'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select *
    from public.create_recurring_calendar_event(
      '4b040000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Calendar legacy cancellation', null, false,
      current_setting('kinflow.test.calendar_cancel_today')::date,
      time '10:00', 30, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'a whole-series legacy cancellation fixture is created'
);
select set_config(
  'kinflow.test.calendar_cancel_legacy_series',
  (
    select series.id::text
    from public.event_series as series
    where series.title = 'Calendar legacy cancellation'
  ),
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.household_local_date::text,
      result.effective_local_date::text, result.version,
      result.cancelled_count, result.preserved_past_count, result.changed
    )
    from public.cancel_recurring_calendar_series(
      '4b040000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_cancel_legacy_series')::uuid,
      1
    ) as result
  ),
  current_setting('kinflow.test.calendar_cancel_today') || ':'
    || current_setting('kinflow.test.calendar_cancel_today')
    || ':2:366:0:t',
  'legacy whole-series cancellation keeps today-boundary result semantics'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.effective_local_date::text, result.version, result.changed
    )
    from public.cancel_recurring_calendar_series(
      '4b040000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_cancel_legacy_series')::uuid,
      1
    ) as result
  ),
  current_setting('kinflow.test.calendar_cancel_today') || ':2:f',
  'legacy same-key replay remains an unchanged result'
);
reset role;
select is(
  (
    select pg_catalog.encode(request.request_hash, 'hex')
    from app_private.calendar_series_change_command_requests as request
    where request.series_id = current_setting(
      'kinflow.test.calendar_cancel_legacy_series'
    )::uuid
  ),
  pg_catalog.encode(
    extensions.digest(
      pg_catalog.convert_to(
        pg_catalog.jsonb_build_object(
          'command', 'cancel_recurring_calendar_series',
          'household_id',
            '20000000-0000-4000-8000-000000000101'::uuid,
          'series_id', current_setting(
            'kinflow.test.calendar_cancel_legacy_series'
          )::uuid,
          'expected_version', 1
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  ),
  'legacy normalized command hash remains byte-for-byte compatible'
);
select ok(
  exists (
    select 1
    from public.event_series as series
    where series.id = current_setting(
      'kinflow.test.calendar_cancel_legacy_series'
    )::uuid
      and series.ended_at is not null
      and series.ended_effective_local_date =
        current_setting('kinflow.test.calendar_cancel_today')::date
  ),
  'legacy cancellation still ends the series immediately'
);

select * from finish();
rollback;
