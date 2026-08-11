begin;
set constraints all deferred;

select plan(58);

-- 1-15: public/private boundary, exact compatibility and privacy shape.
select has_function(
  'public',
  'resume_recurring_calendar_series_cancellation',
  array['uuid', 'uuid', 'uuid', 'uuid', 'bigint'],
  'selected-boundary Calendar cancellation resume command exists'
);
select has_function(
  'public',
  'cancel_recurring_calendar_series_from_occurrence',
  array['uuid', 'uuid', 'uuid', 'uuid', 'bigint'],
  'compatible selected-boundary cancellation command remains public'
);
select has_function(
  'app_private',
  'cancel_recurring_calendar_series_from_occurrence_wp04_15',
  array['uuid', 'uuid', 'uuid', 'uuid', 'bigint'],
  'the WP04-15 selected-boundary engine is private'
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
        'cancel_recurring_calendar_series_from_occurrence',
        'cancel_recurring_calendar_series_from_occurrence_wp04_15',
        'resume_recurring_calendar_series_cancellation'
      )
  ),
  'Calendar cancellation and resume boundaries are hardened definers'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.resume_recurring_calendar_series_cancellation(uuid,uuid,uuid,uuid,bigint)',
    'execute'
  ),
  'authenticated clients can execute immediate Calendar cancellation Undo'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.resume_recurring_calendar_series_cancellation(uuid,uuid,uuid,uuid,bigint)',
    'execute'
  ),
  'anonymous clients cannot execute Calendar cancellation Undo'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.cancel_recurring_calendar_series_from_occurrence_wp04_15(uuid,uuid,uuid,uuid,bigint)',
    'execute'
  ),
  'authenticated clients cannot bypass the compatible cancellation wrapper'
);
select is(
  (
    select pg_catalog.string_agg(
      parameter_name, ',' order by ordinal_position
    )
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name =
        'resume_recurring_calendar_series_cancellation_' || (
          'public.resume_recurring_calendar_series_cancellation(uuid,uuid,uuid,uuid,bigint)'
            ::regprocedure::oid::text
        )
      and parameter_mode = 'OUT'
  ),
  'household_id,series_id,effective_local_date,version,restored_count,preserved_past_count,revision_id,revision_number,changed',
  'resume returns the exact compact nine-key result envelope'
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
  'the selected cancellation keeps its exact WP04-15 result envelope'
);
select has_table(
  'app_private',
  'calendar_series_cancellation_undo_items',
  'a private exact pre/post-state ledger exists'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.calendar_series_cancellation_undo_items',
    'select'
  ),
  'authenticated clients cannot read the private Undo ledger'
);
select ok(
  not has_table_privilege(
    'service_role',
    'app_private.calendar_series_cancellation_undo_items',
    'select'
  ),
  'service clients cannot read the private Undo ledger'
);
select is(
  (
    select pg_catalog.count(*)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'calendar_series_cancellation_undo_items'
      and column_name in (
        'title', 'description', 'local_start_date', 'local_start_time',
        'timezone', 'member_id', 'display_name', 'email', 'payload', 'token'
      )
  ),
  0::bigint,
  'the private ledger contains no event content, identity or token payload'
);
select has_trigger(
  'app_private',
  'calendar_series_cancellation_undo_items',
  'calendar_series_cancellation_undo_items_immutable',
  'the private Undo ledger has an immutable trigger'
);
select throws_ok(
  $$
    select *
    from public.resume_recurring_calendar_series_cancellation(
      '4c000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      '4c100000-0000-4000-8000-000000000001',
      '4c200000-0000-4000-8000-000000000001',
      2
    )
  $$,
  'KFE01',
  'authentication required',
  'resume derives the actor from JWT'
);

-- 16-22: member-owned cancellation captures exact normal, exception and
-- terminal-prefix state without altering the compatible result.
select set_config(
  'kinflow.test.calendar_undo_today',
  (pg_catalog.statement_timestamp() at time zone 'Asia/Seoul')::date::text,
  true
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select result.materialized_count
    from public.create_recurring_calendar_event(
      '4c010000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Calendar Undo source', 'Private source notes', false,
      current_setting('kinflow.test.calendar_undo_today')::date - 2,
      time '08:30', 75, null, 'Asia/Seoul', 'later',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array[
        '30000000-0000-4000-8000-000000000101'::uuid,
        '30000000-0000-4000-8000-000000000102'::uuid
      ]
    ) as result
  ),
  366,
  'an active Member creates the bounded Calendar Undo fixture'
);
select set_config(
  'kinflow.test.calendar_undo_series',
  (
    select series.id::text
    from public.event_series as series
    where series.title = 'Calendar Undo source'
  ),
  true
);
select set_config(
  'kinflow.test.calendar_undo_source_revision',
  (
    select series.active_revision_id::text
    from public.event_series as series
    where series.id = current_setting(
      'kinflow.test.calendar_undo_series'
    )::uuid
  ),
  true
);
select set_config(
  'kinflow.test.calendar_undo_boundary',
  (current_setting('kinflow.test.calendar_undo_today')::date + 5)::text,
  true
);
select set_config(
  'kinflow.test.calendar_undo_target',
  (
    select occurrence.id::text
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.calendar_undo_series'
    )::uuid
      and occurrence.recurrence_local_start_date = current_setting(
        'kinflow.test.calendar_undo_boundary'
      )::date
  ),
  true
);
select set_config(
  'kinflow.test.calendar_undo_prefix_exception',
  (
    select occurrence.id::text
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.calendar_undo_series'
    )::uuid
      and occurrence.recurrence_local_start_date = current_setting(
        'kinflow.test.calendar_undo_boundary'
      )::date - 1
  ),
  true
);
select set_config(
  'kinflow.test.calendar_undo_later_exception',
  (
    select occurrence.id::text
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.calendar_undo_series'
    )::uuid
      and occurrence.recurrence_local_start_date = current_setting(
        'kinflow.test.calendar_undo_boundary'
      )::date + 8
  ),
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.occurrence_version, result.exception_version, result.changed
    )
    from public.update_recurring_calendar_occurrence(
      '4c010000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_undo_series')::uuid,
      current_setting('kinflow.test.calendar_undo_prefix_exception')::uuid,
      1, 'Undo prefix exception', 'Must remain exact', false,
      current_setting('kinflow.test.calendar_undo_boundary')::date + 20,
      time '12:45', 45, null, 'Asia/Seoul', 'earlier',
      array['30000000-0000-4000-8000-000000000102'::uuid]
    ) as result
  ),
  '2:1:t',
  'the prefix exception moves beyond the displayed boundary'
);
select set_config(
  'kinflow.test.calendar_undo_prefix_exception_revision',
  (
    select occurrence.revision_id::text
    from public.event_occurrences as occurrence
    where occurrence.id = current_setting(
      'kinflow.test.calendar_undo_prefix_exception'
    )::uuid
  ),
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.occurrence_version, result.exception_version, result.changed
    )
    from public.update_recurring_calendar_occurrence(
      '4c010000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_undo_series')::uuid,
      current_setting('kinflow.test.calendar_undo_later_exception')::uuid,
      1, 'Undo later exception', 'Must restore exactly', false,
      current_setting('kinflow.test.calendar_undo_boundary')::date - 3,
      time '14:15', 30, null, 'Asia/Seoul', 'later',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    ) as result
  ),
  '2:1:t',
  'a later recurrence exception moves before the displayed boundary'
);
select set_config(
  'kinflow.test.calendar_undo_later_exception_revision',
  (
    select occurrence.revision_id::text
    from public.event_occurrences as occurrence
    where occurrence.id = current_setting(
      'kinflow.test.calendar_undo_later_exception'
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
      '4c020000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_undo_series')::uuid,
      current_setting('kinflow.test.calendar_undo_target')::uuid,
      1
    ) as result
  ),
  current_setting('kinflow.test.calendar_undo_boundary')
    || ':2:359:7:4:t',
  'the compatible cancellation creates the exact terminal result'
);
select set_config(
  'kinflow.test.calendar_undo_terminal_revision',
  (
    select series.active_revision_id::text
    from public.event_series as series
    where series.id = current_setting(
      'kinflow.test.calendar_undo_series'
    )::uuid
  ),
  true
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      pg_catalog.count(*) filter (
        where item.mutation_kind = 'cancelled_status'
      ),
      pg_catalog.count(*) filter (
        where item.mutation_kind = 'terminal_repoint'
      ),
      pg_catalog.count(*)
    )
    from app_private.calendar_series_cancellation_undo_items as item
    where item.cancellation_idempotency_key =
      '4c020000-0000-4000-8000-000000000001'
  ),
  '359:4:363',
  'the private ledger captures every changed suffix and terminal-prefix row'
);
select ok(
  not exists (
    select 1
    from app_private.calendar_series_cancellation_undo_items as item
    where item.cancellation_idempotency_key =
      '4c020000-0000-4000-8000-000000000001'
      and (
        item.post_version <> item.previous_version + 1
        or item.mutation_kind = 'cancelled_status'
           and item.post_status <> 'cancelled'
        or item.mutation_kind = 'terminal_repoint'
           and item.previous_revision_id = item.post_revision_id
      )
  ),
  'every ledger item binds exact pre/post status, revision and version'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.version, result.cancelled_count, result.changed
    )
    from public.cancel_recurring_calendar_series_from_occurrence(
      '4c020000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_undo_series')::uuid,
      current_setting('kinflow.test.calendar_undo_target')::uuid,
      1
    ) as result
  ),
  '2:359:f',
  'cancellation replay remains compatible and unchanged'
);
reset role;
select is(
  (
    select pg_catalog.count(*)
    from app_private.calendar_series_cancellation_undo_items as item
    where item.cancellation_idempotency_key =
      '4c020000-0000-4000-8000-000000000001'
  ),
  363::bigint,
  'cancellation replay creates no duplicate Undo ledger rows'
);

-- 23-43: only the original active Member can restore the exact suffix while
-- later prefix state stays untouched; replay and worker continuation are safe.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select *
    from public.resume_recurring_calendar_series_cancellation(
      '4c030000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_undo_series')::uuid,
      '4c020000-0000-4000-8000-000000000001',
      2
    )
  $$,
  'KFE03',
  'calendar event not found or forbidden',
  'another active household Owner cannot resume a Member cancellation'
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
    from public.resume_recurring_calendar_series_cancellation(
      '4c030000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_undo_series')::uuid,
      '4c020000-0000-4000-8000-000000000001',
      2
    )
  $$,
  'KFE03',
  'calendar event not found or forbidden',
  'an outsider cannot resume another household cancellation'
);
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.effective_local_date::text, result.version,
      result.restored_count, result.preserved_past_count,
      result.revision_number, result.changed
    )
    from public.resume_recurring_calendar_series_cancellation(
      '4c030000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_undo_series')::uuid,
      '4c020000-0000-4000-8000-000000000001',
      2
    ) as result
  ),
  current_setting('kinflow.test.calendar_undo_boundary')
    || ':3:359:7:5:t',
  'the original active Member restores the exact cancellation revision'
);
select set_config(
  'kinflow.test.calendar_undo_resumed_revision',
  (
    select series.active_revision_id::text
    from public.event_series as series
    where series.id = current_setting(
      'kinflow.test.calendar_undo_series'
    )::uuid
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
    where series.id = current_setting(
      'kinflow.test.calendar_undo_series'
    )::uuid
      and series.version = 3
      and series.ended_at is null
      and series.ended_effective_local_date is null
      and series.title = 'Calendar Undo source'
      and series.description = 'Private source notes'
      and series.timezone = 'Asia/Seoul'
      and revision.revision_number = 5
      and revision.local_start_time = time '08:30'
      and revision.duration_minutes = 75
      and revision.overlap_policy = 'later'
      and revision.recurrence_rule->'end'->>'type' = 'never'
  ),
  'resume activates a new immutable clone of the pre-cancellation source'
);
select is(
  (
    select pg_catalog.array_agg(
      participant.member_id order by participant.member_id
    )
    from public.event_revision_participants as participant
    where participant.revision_id = current_setting(
      'kinflow.test.calendar_undo_resumed_revision'
    )::uuid
  ),
  array[
    '30000000-0000-4000-8000-000000000101'::uuid,
    '30000000-0000-4000-8000-000000000102'::uuid
  ],
  'resume restores the exact source participant snapshot'
);
select ok(
  exists (
    select 1
    from public.event_occurrences as occurrence
    where occurrence.id = current_setting(
      'kinflow.test.calendar_undo_target'
    )::uuid
      and occurrence.status = 'scheduled'
      and occurrence.version = 3
      and occurrence.revision_id = current_setting(
        'kinflow.test.calendar_undo_resumed_revision'
      )::uuid
  ),
  'the selected target is restored on the new active revision'
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
      'kinflow.test.calendar_undo_later_exception'
    )::uuid
      and occurrence.status = 'scheduled'
      and occurrence.version = 4
      and occurrence.revision_id = current_setting(
        'kinflow.test.calendar_undo_later_exception_revision'
      )::uuid
      and occurrence.local_start_date = current_setting(
        'kinflow.test.calendar_undo_boundary'
      )::date - 3
      and exception.version = 1
      and not exception.cancelled
      and revision.snapshot_title = 'Undo later exception'
  ),
  'a moved later exception restores its exact status and exception revision'
);
select ok(
  exists (
    select 1
    from public.event_occurrences as occurrence
    join public.event_occurrence_exceptions as exception
      on exception.occurrence_id = occurrence.id
    where occurrence.id = current_setting(
      'kinflow.test.calendar_undo_prefix_exception'
    )::uuid
      and occurrence.status = 'scheduled'
      and occurrence.version = 2
      and occurrence.revision_id = current_setting(
        'kinflow.test.calendar_undo_prefix_exception_revision'
      )::uuid
      and occurrence.local_start_date = current_setting(
        'kinflow.test.calendar_undo_boundary'
      )::date + 20
      and exception.version = 1
      and not exception.cancelled
  ),
  'the pre-boundary moved exception remains byte-for-byte untouched'
);
select ok(
  exists (
    select 1
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.calendar_undo_series'
    )::uuid
      and occurrence.recurrence_local_start_date = current_setting(
        'kinflow.test.calendar_undo_boundary'
      )::date - 2
      and occurrence.status = 'scheduled'
      and occurrence.version = 3
      and occurrence.revision_id = current_setting(
        'kinflow.test.calendar_undo_resumed_revision'
      )::uuid
  ),
  'an unchanged terminal-prefix row is repointed to the resumed revision'
);
select ok(
  exists (
    select 1
    from public.event_series_revisions as revision
    where revision.id = current_setting(
      'kinflow.test.calendar_undo_terminal_revision'
    )::uuid
      and revision.recurrence_rule->'end'->>'type' = 'until'
      and revision.recurrence_rule->'end'->>'localDate' = (
        current_setting('kinflow.test.calendar_undo_boundary')::date - 1
      )::text
  ),
  'the immutable cancellation terminal revision remains valid history'
);
reset role;
select is(
  (
    select pg_catalog.count(*)
    from app_private.calendar_materialization_states as state
    where state.series_id = current_setting(
      'kinflow.test.calendar_undo_series'
    )::uuid
  ),
  0::bigint,
  'resume clears bounded terminal coverage for canonical worker repair'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', event.operation, event.rebuilt_count, event.cancelled_count,
      event.preserved_exception_count, event.preserved_past_count,
      event.series_version
    )
    from public.event_series_change_events as event
    where event.series_id = current_setting(
      'kinflow.test.calendar_undo_series'
    )::uuid
      and event.operation = 'resumed'
  ),
  'resumed:359:0:1:7:3',
  'one content-free aggregate resume history row records exact counts'
);
select is(
  (
    select pg_catalog.count(*)
    from app_private.calendar_series_change_command_requests as request
    where request.series_id = current_setting(
      'kinflow.test.calendar_undo_series'
    )::uuid
      and request.operation = 'resumed'
  ),
  1::bigint,
  'one immutable resume replay record is stored'
);
select is(
  (
    select audit.occurrence_id
    from app_private.calendar_audit_events as audit
    where audit.series_id = current_setting(
      'kinflow.test.calendar_undo_series'
    )::uuid
      and audit.action = 'calendar.series_resumed'
  ),
  current_setting('kinflow.test.calendar_undo_target')::uuid,
  'the private content-free resume audit references the selected boundary'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.version, result.restored_count,
      result.revision_number, result.changed
    )
    from public.resume_recurring_calendar_series_cancellation(
      '4c030000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_undo_series')::uuid,
      '4c020000-0000-4000-8000-000000000001',
      2
    ) as result
  ),
  '3:359:5:f',
  'the exact resume key replays the original summary unchanged'
);
select throws_ok(
  $$
    select *
    from public.resume_recurring_calendar_series_cancellation(
      '4c030000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_undo_series')::uuid,
      '4c020000-0000-4000-8000-000000000001',
      3
    )
  $$,
  'KFE04',
  'idempotency key reused with different calendar input',
  'the same resume key with different input conflicts'
);
select throws_ok(
  $$
    select *
    from public.resume_recurring_calendar_series_cancellation(
      '4c030000-0000-4000-8000-000000000004',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_undo_series')::uuid,
      '4c020000-0000-4000-8000-000000000001',
      2
    )
  $$,
  'KFE05',
  'stale calendar event version',
  'a second resume command rejects the now-stale cancellation version'
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', pg_catalog.count(distinct revision.id),
      pg_catalog.count(distinct event.id),
      pg_catalog.count(distinct request.idempotency_key),
      pg_catalog.count(distinct audit.id)
    )
    from public.event_series_revisions as revision
    left join public.event_series_change_events as event
      on event.series_id = revision.series_id
    left join app_private.calendar_series_change_command_requests as request
      on request.series_id = revision.series_id
    left join app_private.calendar_audit_events as audit
      on audit.series_id = revision.series_id
     and audit.action in (
       'calendar.series_cancelled', 'calendar.series_resumed'
     )
    where revision.series_id = current_setting(
      'kinflow.test.calendar_undo_series'
    )::uuid
  ),
  '5:2:2:2',
  'replay and rejected resumes create no duplicate revision or audit state'
);
select lives_ok(
  $$
    select *
    from public.run_calendar_horizon_worker(
      pg_catalog.statement_timestamp(), 30, 0, 1,
      current_setting('kinflow.test.calendar_undo_series')::uuid
    )
  $$,
  'the canonical worker continues the resumed active revision'
);
select ok(
  exists (
    select 1
    from app_private.calendar_materialization_states as state
    where state.series_id = current_setting(
      'kinflow.test.calendar_undo_series'
    )::uuid
      and state.revision_id = current_setting(
        'kinflow.test.calendar_undo_resumed_revision'
      )::uuid
      and state.last_result = 'succeeded'
  ),
  'worker coverage now belongs to the resumed revision'
);
select is(
  (
    select pg_catalog.count(*)
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.calendar_undo_series'
    )::uuid
      and occurrence.recurrence_local_start_date >= current_setting(
        'kinflow.test.calendar_undo_boundary'
      )::date
      and occurrence.status = 'cancelled'
  ),
  0::bigint,
  'the restored and repaired suffix contains no obsolete cancellation state'
);

-- 44-58: no-prefix reactivation, immutable ledger, legacy exclusion, drift
-- detection and actor removal all fail or restore at the intended boundary.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select lives_ok(
  $$
    select *
    from public.create_recurring_calendar_event(
      '4c040000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Calendar Undo no prefix', null, false,
      current_setting('kinflow.test.calendar_undo_today')::date,
      time '09:00', 30, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000102'::uuid]
    )
  $$,
  'a no-prefix resume fixture is created'
);
select set_config(
  'kinflow.test.calendar_undo_no_prefix_series',
  (
    select series.id::text
    from public.event_series as series
    where series.title = 'Calendar Undo no prefix'
  ),
  true
);
select set_config(
  'kinflow.test.calendar_undo_no_prefix_target',
  (
    select occurrence.id::text
    from public.event_occurrences as occurrence
    where occurrence.series_id = current_setting(
      'kinflow.test.calendar_undo_no_prefix_series'
    )::uuid
      and occurrence.recurrence_local_start_date = current_setting(
        'kinflow.test.calendar_undo_today'
      )::date
  ),
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.version, result.cancelled_count,
      result.terminal_revision_id is null, result.changed
    )
    from public.cancel_recurring_calendar_series_from_occurrence(
      '4c040000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_undo_no_prefix_series')::uuid,
      current_setting('kinflow.test.calendar_undo_no_prefix_target')::uuid,
      1
    ) as result
  ),
  '2:366:t:t',
  'a first-slot cancellation ends the no-prefix series'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.version, result.restored_count,
      result.revision_number, result.changed
    )
    from public.resume_recurring_calendar_series_cancellation(
      '4c040000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_undo_no_prefix_series')::uuid,
      '4c040000-0000-4000-8000-000000000002',
      2
    ) as result
  ),
  '3:366:2:t',
  'resume reactivates the exact no-prefix cancellation'
);
select ok(
  exists (
    select 1
    from public.event_series as series
    join public.event_series_revisions as revision
      on revision.id = series.active_revision_id
    where series.id = current_setting(
      'kinflow.test.calendar_undo_no_prefix_series'
    )::uuid
      and series.version = 3
      and series.ended_at is null
      and series.ended_effective_local_date is null
      and revision.revision_number = 2
      and revision.recurrence_rule->'end'->>'type' = 'never'
  ),
  'the ended series becomes one active immutable resumed revision'
);
reset role;
select throws_ok(
  $$
    update app_private.calendar_series_cancellation_undo_items
    set previous_version = previous_version
    where cancellation_idempotency_key =
      '4c040000-0000-4000-8000-000000000002'
  $$,
  '55000',
  'calendar series cancellation undo items are immutable',
  'the private ledger rejects updates'
);
select throws_ok(
  $$
    delete from app_private.calendar_series_cancellation_undo_items
    where cancellation_idempotency_key =
      '4c040000-0000-4000-8000-000000000002'
  $$,
  '55000',
  'calendar series cancellation undo items are immutable',
  'the private ledger rejects deletes'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select lives_ok(
  $$
    select *
    from public.create_recurring_calendar_event(
      '4c050000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Calendar Undo legacy exclusion', null, false,
      current_setting('kinflow.test.calendar_undo_today')::date,
      time '10:00', 30, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000102'::uuid]
    )
  $$,
  'a legacy whole-series cancellation fixture is created'
);
select set_config(
  'kinflow.test.calendar_undo_legacy_series',
  (
    select series.id::text
    from public.event_series as series
    where series.title = 'Calendar Undo legacy exclusion'
  ),
  true
);
select lives_ok(
  $$
    select *
    from public.cancel_recurring_calendar_series(
      '4c050000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_undo_legacy_series')::uuid,
      1
    )
  $$,
  'legacy whole-series cancellation remains compatible'
);
select throws_ok(
  $$
    select *
    from public.resume_recurring_calendar_series_cancellation(
      '4c050000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_undo_legacy_series')::uuid,
      '4c050000-0000-4000-8000-000000000002',
      2
    )
  $$,
  'KFE08',
  'calendar series transition not allowed',
  'a legacy whole-series cancellation has no selected-boundary Undo ledger'
);
select lives_ok(
  $$
    select *
    from public.cancel_recurring_calendar_series_from_occurrence(
      '4c040000-0000-4000-8000-000000000004',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_undo_no_prefix_series')::uuid,
      current_setting('kinflow.test.calendar_undo_no_prefix_target')::uuid,
      3
    )
  $$,
  'the resumed no-prefix series can be selected-cancelled again'
);
reset role;
select lives_ok(
  $$
    update public.event_occurrences as occurrence
    set status = 'scheduled'
    where occurrence.series_id = current_setting(
      'kinflow.test.calendar_undo_no_prefix_series'
    )::uuid
      and occurrence.recurrence_local_start_date = current_setting(
        'kinflow.test.calendar_undo_today'
      )::date + 1
  $$,
  'a simulated concurrent occurrence write changes one cancellation post-state'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select throws_ok(
  $$
    select *
    from public.resume_recurring_calendar_series_cancellation(
      '4c040000-0000-4000-8000-000000000005',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_undo_no_prefix_series')::uuid,
      '4c040000-0000-4000-8000-000000000004',
      4
    )
  $$,
  'KFE08',
  'calendar series transition not allowed',
  'one drifted cancellation row prevents a partial resume'
);
reset role;
select lives_ok(
  $$
    update public.household_members
    set removed_at = pg_catalog.statement_timestamp()
    where id = '30000000-0000-4000-8000-000000000102'
  $$,
  'the original cancellation actor is removed for the authority check'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select throws_ok(
  $$
    select *
    from public.resume_recurring_calendar_series_cancellation(
      '4c040000-0000-4000-8000-000000000006',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_undo_no_prefix_series')::uuid,
      '4c040000-0000-4000-8000-000000000004',
      4
    )
  $$,
  'KFE03',
  'calendar event not found or forbidden',
  'a removed original actor can no longer resume the cancellation'
);

select * from finish();
rollback;
