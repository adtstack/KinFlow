begin;
set constraints all deferred;

select plan(46);

select has_function(
  'public',
  'resume_repeating_chore_series_cancellation',
  array['uuid', 'uuid', 'uuid', 'uuid', 'bigint'],
  'selected-boundary chore cancellation resume command exists'
);
select ok(
  (
    select procedure.prosecdef
      and procedure.proconfig @> array['search_path=""']::text[]
    from pg_proc as procedure
    join pg_namespace as namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname =
        'resume_repeating_chore_series_cancellation'
  ),
  'the resume command is security-definer with an empty search path'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.resume_repeating_chore_series_cancellation(uuid,uuid,uuid,uuid,bigint)',
    'execute'
  ),
  'authenticated users can execute the mediated resume command'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.resume_repeating_chore_series_cancellation(uuid,uuid,uuid,uuid,bigint)',
    'execute'
  ),
  'anonymous users cannot execute the resume command'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.cancel_repeating_chore_series_from_occurrence_wp03_21(uuid,uuid,uuid,uuid,bigint)',
    'execute'
  ),
  'the compatibility cancellation engine is private from clients'
);
select has_table(
  'app_private',
  'chore_series_cancellation_undo_items',
  'a private cancellation pre-state ledger exists'
);
select columns_are(
  'app_private',
  'chore_series_cancellation_undo_items',
  array[
    'authenticated_user_id',
    'cancellation_idempotency_key',
    'household_id',
    'series_id',
    'occurrence_id',
    'mutation_kind',
    'previous_status',
    'previous_revision_id',
    'previous_version',
    'post_status',
    'post_revision_id',
    'post_version',
    'created_at'
  ],
  'the ledger contains only bounded command and occurrence state metadata'
);
select hasnt_column(
  'app_private',
  'chore_series_cancellation_undo_items',
  'title',
  'the ledger stores no chore title'
);
select hasnt_column(
  'app_private',
  'chore_series_cancellation_undo_items',
  'assignee_member_id',
  'the ledger stores no assignee identity'
);
select ok(
  not has_table_privilege(
    'service_role',
    'app_private.chore_series_cancellation_undo_items',
    'select'
  ),
  'service role has no direct ledger read grant'
);
select is(
  (
    select array_to_string(procedure.proargnames, ',')
    from pg_proc as procedure
    join pg_namespace as namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname =
        'cancel_repeating_chore_series_from_occurrence'
  ),
  'p_idempotency_key,p_household_id,p_series_id,p_effective_occurrence_id,p_expected_version,household_id,series_id,effective_local_date,version,cancelled_count,preserved_completed_count,terminal_revision_id,terminal_revision_number,changed',
  'the legacy cancellation keeps its exact five-input and nine-output shape'
);
select is(
  (
    select array_to_string(procedure.proargnames, ',')
    from pg_proc as procedure
    join pg_namespace as namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname =
        'resume_repeating_chore_series_cancellation'
  ),
  'p_idempotency_key,p_household_id,p_series_id,p_cancellation_idempotency_key,p_expected_version,household_id,series_id,effective_local_date,version,restored_count,preserved_completed_count,revision_id,revision_number,changed',
  'the resume command exposes an exact five-input and nine-output shape'
);
select throws_ok(
  $$
    select * from public.resume_repeating_chore_series_cancellation(
      '6c000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      '6c100000-0000-4000-8000-000000000001',
      '6c200000-0000-4000-8000-000000000001',
      2
    )
  $$,
  'KFC01',
  'authentication required',
  'resume derives identity from the JWT'
);

select set_config(
  'kinflow.test.undo_today',
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
      '6c010000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Cancellation Undo fixture',
      'Exact resumed notes',
      '30000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.undo_today')::date - 2,
      '08:15',
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":12}}'
    )
  $$,
  'owner creates a repeating Undo fixture'
);
select set_config(
  'kinflow.test.undo_series',
  (
    select series.id::text
    from public.chore_series as series
    where series.title = 'Cancellation Undo fixture'
  ),
  true
);
select set_config(
  'kinflow.test.undo_source_revision',
  (
    select series.active_revision_id::text
    from public.chore_series as series
    where series.id = current_setting('kinflow.test.undo_series')::uuid
  ),
  true
);
select set_config(
  'kinflow.test.undo_boundary',
  (current_setting('kinflow.test.undo_today')::date + 3)::text,
  true
);
select set_config(
  'kinflow.test.undo_target',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting('kinflow.test.undo_series')::uuid
      and occurrence.recurrence_local_date =
        current_setting('kinflow.test.undo_boundary')::date
  ),
  true
);
select set_config(
  'kinflow.test.undo_skipped',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting('kinflow.test.undo_series')::uuid
      and occurrence.recurrence_local_date =
        current_setting('kinflow.test.undo_boundary')::date + 1
  ),
  true
);
select set_config(
  'kinflow.test.undo_completed_future',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting('kinflow.test.undo_series')::uuid
      and occurrence.recurrence_local_date =
        current_setting('kinflow.test.undo_boundary')::date + 2
  ),
  true
);
select set_config(
  'kinflow.test.undo_prefix_changed',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting('kinflow.test.undo_series')::uuid
      and occurrence.recurrence_local_date =
        current_setting('kinflow.test.undo_boundary')::date - 2
  ),
  true
);
select set_config(
  'kinflow.test.undo_prefix_completed',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting('kinflow.test.undo_series')::uuid
      and occurrence.recurrence_local_date =
        current_setting('kinflow.test.undo_boundary')::date - 1
  ),
  true
);
select lives_ok(
  $$
    select * from public.skip_chore_occurrence(
      '6c010000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.undo_skipped')::uuid,
      1
    )
  $$,
  'a future skipped occurrence is prepared'
);
select lives_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '6c010000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.undo_completed_future')::uuid,
      1,
      true
    )
  $$,
  'a future completed occurrence is prepared'
);
select lives_ok(
  $$
    select * from public.reschedule_chore_occurrence(
      '6c010000-0000-4000-8000-000000000004',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.undo_prefix_changed')::uuid,
      1,
      current_setting('kinflow.test.undo_boundary')::date + 30,
      '14:45'
    )
  $$,
  'a surviving prefix due-date exception is prepared'
);
select is(
  (
    select concat_ws(
      ':', result.version, result.cancelled_count,
      result.preserved_completed_count,
      result.terminal_revision_id is not null,
      result.terminal_revision_number, result.changed
    )
    from public.cancel_repeating_chore_series_from_occurrence(
      '6c020000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.undo_series')::uuid,
      current_setting('kinflow.test.undo_target')::uuid,
      1
    ) as result
  ),
  '2:6:1:t:2:t',
  'selected-boundary cancellation remains compatible and records six rows'
);
select set_config(
  'kinflow.test.undo_terminal_revision',
  (
    select series.active_revision_id::text
    from public.chore_series as series
    where series.id = current_setting('kinflow.test.undo_series')::uuid
  ),
  true
);
reset role;
select is(
  (
    select count(*)::integer
    from app_private.chore_series_cancellation_undo_items as item
    where item.cancellation_idempotency_key =
      '6c020000-0000-4000-8000-000000000001'
      and item.mutation_kind = 'cancelled_status'
  ),
  6,
  'the ledger captures every status cancellation exactly once'
);
select is(
  (
    select count(*)::integer
    from app_private.chore_series_cancellation_undo_items as item
    where item.cancellation_idempotency_key =
      '6c020000-0000-4000-8000-000000000001'
      and item.mutation_kind = 'terminal_repoint'
  ),
  5,
  'the ledger captures every terminal-prefix revision move exactly once'
);
select is(
  (
    select concat_ws(
      ':', item.previous_status::text, item.post_status::text,
      item.previous_revision_id::text, item.post_revision_id::text,
      item.post_version - item.previous_version
    )
    from app_private.chore_series_cancellation_undo_items as item
    where item.occurrence_id = current_setting('kinflow.test.undo_skipped')::uuid
  ),
  'skipped:cancelled:' || current_setting('kinflow.test.undo_source_revision')
    || ':' || current_setting('kinflow.test.undo_source_revision') || ':1',
  'the skipped pre-state remains exact and content free'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select throws_ok(
  $$
    select * from public.resume_repeating_chore_series_cancellation(
      '6c030000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.undo_series')::uuid,
      '6c020000-0000-4000-8000-000000000001',
      2
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'a plain member cannot resume the cancellation'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$
    select * from public.resume_repeating_chore_series_cancellation(
      '6c030000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.undo_series')::uuid,
      '6c020000-0000-4000-8000-000000000001',
      2
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'another household owner cannot use the original actor command'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.resume_repeating_chore_series_cancellation(
      '6c030000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.undo_series')::uuid,
      '6c020000-0000-4000-8000-000000000099',
      2
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'an unknown cancellation command does not disclose series state'
);
select lives_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '6c030000-0000-4000-8000-000000000004',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.undo_prefix_completed')::uuid,
      (
        select occurrence.version
        from public.chore_occurrences as occurrence
        where occurrence.id =
          current_setting('kinflow.test.undo_prefix_completed')::uuid
      ),
      true
    )
  $$,
  'a prefix occurrence may complete after cancellation'
);
select is(
  (
    select concat_ws(
      ':', result.version, result.restored_count,
      result.preserved_completed_count, result.revision_number,
      result.changed
    )
    from public.resume_repeating_chore_series_cancellation(
      '6c040000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.undo_series')::uuid,
      '6c020000-0000-4000-8000-000000000001',
      2
    ) as result
  ),
  '3:6:1:3:t',
  'resume restores all cancellation-status rows into a new revision'
);
select set_config(
  'kinflow.test.undo_resumed_revision',
  (
    select series.active_revision_id::text
    from public.chore_series as series
    where series.id = current_setting('kinflow.test.undo_series')::uuid
  ),
  true
);
select is(
  (
    select concat_ws(
      ':', series.version, series.deleted_at is null,
      revision.revision_number, revision.title, revision.description,
      to_char(revision.due_local_time, 'HH24:MI'),
      revision.recurrence_rule->'end'->>'type',
      revision.recurrence_rule->'end'->>'count'
    )
    from public.chore_series as series
    join public.chore_series_revisions as revision
      on revision.id = series.active_revision_id
    where series.id = current_setting('kinflow.test.undo_series')::uuid
  ),
  '3:t:3:Cancellation Undo fixture:Exact resumed notes:08:15:count:12',
  'the resumed series restores the complete source recurrence snapshot'
);
select is(
  (
    select concat_ws(
      ':', occurrence.status::text, occurrence.revision_id::text
    )
    from public.chore_occurrences as occurrence
    where occurrence.id = current_setting('kinflow.test.undo_target')::uuid
  ),
  'scheduled:' || current_setting('kinflow.test.undo_resumed_revision'),
  'the selected target becomes scheduled on the resumed revision'
);
select is(
  (
    select concat_ws(
      ':', occurrence.status::text, occurrence.revision_id::text
    )
    from public.chore_occurrences as occurrence
    where occurrence.id = current_setting('kinflow.test.undo_skipped')::uuid
  ),
  'skipped:' || current_setting('kinflow.test.undo_resumed_revision'),
  'a skipped occurrence is restored as skipped rather than scheduled'
);
select is(
  (
    select concat_ws(
      ':', occurrence.status::text, occurrence.revision_id::text,
      occurrence.completed_by_member_id::text
    )
    from public.chore_occurrences as occurrence
    where occurrence.id =
      current_setting('kinflow.test.undo_completed_future')::uuid
  ),
  'completed:' || current_setting('kinflow.test.undo_source_revision')
    || ':30000000-0000-4000-8000-000000000101',
  'future completed history remains on its original revision'
);
select is(
  (
    select concat_ws(
      ':', occurrence.status::text, occurrence.revision_id::text
    )
    from public.chore_occurrences as occurrence
    where occurrence.id =
      current_setting('kinflow.test.undo_prefix_completed')::uuid
  ),
  'completed:' || current_setting('kinflow.test.undo_terminal_revision'),
  'a prefix completion after cancellation is preserved without rollback'
);
select is(
  (
    select concat_ws(
      ':', occurrence.status::text, occurrence.revision_id::text,
      occurrence.due_local_date::text,
      to_char(occurrence.due_at at time zone 'Asia/Seoul', 'HH24:MI')
    )
    from public.chore_occurrences as occurrence
    where occurrence.id =
      current_setting('kinflow.test.undo_prefix_changed')::uuid
  ),
  'scheduled:' || current_setting('kinflow.test.undo_resumed_revision')
    || ':'
    || (current_setting('kinflow.test.undo_boundary')::date + 30)::text
    || ':14:45',
  'an unchanged prefix restores revision identity while keeping its exception'
);
select is(
  (
    select count(*)::integer
    from public.chore_occurrences as occurrence
    where occurrence.series_id = current_setting('kinflow.test.undo_series')::uuid
      and occurrence.recurrence_local_date >=
        current_setting('kinflow.test.undo_boundary')::date
      and occurrence.status = 'cancelled'
  ),
  0,
  'no cancellation-status occurrence remains cancelled after resume'
);
select is(
  (
    select concat_ws(
      ':', event.operation, event.previous_revision_id::text,
      event.new_revision_id::text, event.rebuilt_count,
      event.cancelled_count, event.preserved_completed_count,
      event.series_version
    )
    from public.chore_series_change_events as event
    where event.series_id = current_setting('kinflow.test.undo_series')::uuid
      and event.operation = 'resumed'
  ),
  'resumed:' || current_setting('kinflow.test.undo_terminal_revision')
    || ':' || current_setting('kinflow.test.undo_resumed_revision')
    || ':6:0:1:3',
  'one content-free resumed event records the exact aggregate result'
);
select is(
  (
    select concat_ws(
      ':', result.changed, result.version, result.restored_count,
      result.revision_id::text, result.revision_number
    )
    from public.resume_repeating_chore_series_cancellation(
      '6c040000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.undo_series')::uuid,
      '6c020000-0000-4000-8000-000000000001',
      2
    ) as result
  ),
  'f:3:6:' || current_setting('kinflow.test.undo_resumed_revision') || ':3',
  'an identical resume replays the exact stored result'
);
reset role;
select is(
  (
    select concat_ws(
      ':', count(distinct revision.id), count(distinct event.id),
      count(distinct request.idempotency_key)
    )
    from public.chore_series_revisions as revision
    left join public.chore_series_change_events as event
      on event.series_id = revision.series_id
    left join app_private.chore_series_change_command_requests as request
      on request.series_id = revision.series_id
    where revision.series_id = current_setting('kinflow.test.undo_series')::uuid
  ),
  '3:2:2',
  'resume replay creates no duplicate revision, event or command row'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.resume_repeating_chore_series_cancellation(
      '6c040000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.undo_series')::uuid,
      '6c020000-0000-4000-8000-000000000099',
      2
    )
  $$,
  'KFC04',
  'idempotency key reused with different chore input',
  'the same resume key cannot point at another cancellation'
);
select throws_ok(
  $$
    select * from public.resume_repeating_chore_series_cancellation(
      '6c040000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.undo_series')::uuid,
      '6c020000-0000-4000-8000-000000000001',
      2
    )
  $$,
  'KFC05',
  'chore series version conflict',
  'a second resume loses optimistic concurrency after the first succeeds'
);
reset role;
select throws_ok(
  $$
    update app_private.chore_series_cancellation_undo_items
    set previous_version = previous_version + 1
    where cancellation_idempotency_key =
      '6c020000-0000-4000-8000-000000000001'
  $$,
  '55000',
  'chore series cancellation undo items are immutable',
  'the private restoration ledger is immutable after capture'
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
      '6c050000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Soft deleted Undo fixture',
      null,
      '30000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.undo_today')::date + 20,
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":3}}'
    )
  $$,
  'owner creates a first-slot cancellation fixture'
);
select set_config(
  'kinflow.test.undo_soft_series',
  (
    select series.id::text
    from public.chore_series as series
    where series.title = 'Soft deleted Undo fixture'
  ),
  true
);
select is(
  (
    select concat_ws(
      ':', result.version, result.cancelled_count,
      result.terminal_revision_id is null, result.changed
    )
    from public.cancel_repeating_chore_series_from_occurrence(
      '6c050000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.undo_soft_series')::uuid,
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        where occurrence.series_id =
          current_setting('kinflow.test.undo_soft_series')::uuid
        order by occurrence.recurrence_local_date
        limit 1
      ),
      1
    ) as result
  ),
  '2:3:t:t',
  'first-slot cancellation still soft-deletes through the wrapper'
);
reset role;
select is(
  (
    select concat_ws(
      ':', series.deleted_at is not null,
      count(*) filter (where occurrence.status = 'cancelled')
    )
    from public.chore_series as series
    join public.chore_occurrences as occurrence
      on occurrence.series_id = series.id
    where series.id = current_setting('kinflow.test.undo_soft_series')::uuid
    group by series.deleted_at
  ),
  't:3',
  'the no-prefix series and its three rows are cancelled before Undo'
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
      ':', result.version, result.restored_count,
      result.revision_number, result.changed
    )
    from public.resume_repeating_chore_series_cancellation(
      '6c050000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.undo_soft_series')::uuid,
      '6c050000-0000-4000-8000-000000000002',
      2
    ) as result
  ),
  '3:3:2:t',
  'Undo reactivates a soft-deleted first-slot cancellation'
);
select is(
  (
    select concat_ws(
      ':', series.deleted_at is null, series.version,
      revision.revision_number,
      count(*) filter (where occurrence.status = 'scheduled'),
      count(*) filter (
        where occurrence.revision_id = series.active_revision_id
      )
    )
    from public.chore_series as series
    join public.chore_series_revisions as revision
      on revision.id = series.active_revision_id
    join public.chore_occurrences as occurrence
      on occurrence.series_id = series.id
    where series.id = current_setting('kinflow.test.undo_soft_series')::uuid
    group by series.deleted_at, series.version, revision.revision_number
  ),
  't:3:2:3:3',
  'the reactivated series has one new active revision and all rows scheduled'
);
reset role;
set local role service_role;
select lives_ok(
  $$
    select * from public.run_chore_horizon_worker(
      statement_timestamp(),
      365,
      7,
      100,
      current_setting('kinflow.test.undo_soft_series')::uuid
    )
  $$,
  'the canonical worker accepts the resumed revision'
);
reset role;
select is(
  (
    select count(*)::integer
    from public.chore_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.undo_soft_series')::uuid
      and occurrence.status = 'scheduled'
  ),
  3,
  'worker replay neither duplicates nor re-cancels resumed bounded rows'
);

select * from finish();
rollback;
