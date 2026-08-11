begin;
set constraints all deferred;

select plan(46);

select has_function(
  'public',
  'cancel_repeating_chore_series_from_occurrence',
  array['uuid', 'uuid', 'uuid', 'uuid', 'bigint'],
  'selected-occurrence series cancellation command exists'
);
select ok(
  (
    select procedure.prosecdef
      and procedure.proconfig @> array['search_path=""']::text[]
    from pg_proc as procedure
    join pg_namespace as namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname =
        'cancel_repeating_chore_series_from_occurrence'
  ),
  'the selected cancellation command is security-definer with empty search path'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.cancel_repeating_chore_series_from_occurrence(uuid,uuid,uuid,uuid,bigint)',
    'execute'
  ),
  'authenticated users can execute the mediated selected cancellation'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.cancel_repeating_chore_series_from_occurrence(uuid,uuid,uuid,uuid,bigint)',
    'execute'
  ),
  'anonymous users cannot execute the selected cancellation'
);
select hasnt_column(
  'public',
  'chore_series',
  'cancelled_from_local_date',
  'future cancellation uses immutable revisions instead of a mutable cutoff column'
);
select hasnt_column(
  'app_private',
  'chore_series_change_command_requests',
  'effective_occurrence_id',
  'private replay state keeps only hash and aggregate result metadata'
);
select throws_ok(
  $$
    select * from public.cancel_repeating_chore_series_from_occurrence(
      '6b000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      '6b100000-0000-4000-8000-000000000001',
      '6b200000-0000-4000-8000-000000000001',
      1
    )
  $$,
  'KFC01',
  'authentication required',
  'the selected cancellation derives identity from JWT'
);

select set_config(
  'kinflow.test.cancel_from_today',
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
      '6b010000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Cancel-from old title',
      'Cancel-from old notes',
      '30000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_from_today')::date - 2,
      '08:00',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    )
  $$,
  'owner creates a daily cancellation fixture'
);
select set_config(
  'kinflow.test.cancel_from_series',
  (
    select series.id::text
    from public.chore_series as series
    where series.title = 'Cancel-from old title'
  ),
  true
);
select set_config(
  'kinflow.test.cancel_from_revision_1',
  (
    select series.active_revision_id::text
    from public.chore_series as series
    where series.id = current_setting('kinflow.test.cancel_from_series')::uuid
  ),
  true
);
select set_config(
  'kinflow.test.cancel_from_boundary',
  (current_setting('kinflow.test.cancel_from_today')::date + 5)::text,
  true
);
select set_config(
  'kinflow.test.cancel_from_target',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.cancel_from_series')::uuid
      and occurrence.recurrence_local_date =
        current_setting('kinflow.test.cancel_from_boundary')::date
  ),
  true
);
select set_config(
  'kinflow.test.cancel_from_prefix',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.cancel_from_series')::uuid
      and occurrence.recurrence_local_date =
        current_setting('kinflow.test.cancel_from_boundary')::date - 1
  ),
  true
);
select set_config(
  'kinflow.test.cancel_from_completed',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.cancel_from_series')::uuid
      and occurrence.recurrence_local_date =
        current_setting('kinflow.test.cancel_from_boundary')::date + 7
  ),
  true
);
select set_config(
  'kinflow.test.cancel_from_skipped',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.cancel_from_series')::uuid
      and occurrence.recurrence_local_date =
        current_setting('kinflow.test.cancel_from_boundary')::date + 3
  ),
  true
);
select lives_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '6b010000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_from_completed')::uuid,
      1,
      true
    )
  $$,
  'a completion after the selected boundary is recorded first'
);
select lives_ok(
  $$
    select * from public.reschedule_chore_occurrence(
      '6b010000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_from_prefix')::uuid,
      1,
      current_setting('kinflow.test.cancel_from_boundary')::date + 20,
      '12:45'
    )
  $$,
  'the surviving prefix receives a later one-occurrence due-date exception'
);
select lives_ok(
  $$
    select * from public.reschedule_chore_occurrence(
      '6b010000-0000-4000-8000-000000000004',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_from_target')::uuid,
      1,
      current_setting('kinflow.test.cancel_from_boundary')::date + 30,
      '13:15'
    )
  $$,
  'the selected target due date is moved without changing its recurrence slot'
);
select lives_ok(
  $$
    select * from public.skip_chore_occurrence(
      '6b010000-0000-4000-8000-000000000005',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_from_skipped')::uuid,
      1
    )
  $$,
  'a skipped target-denial fixture is recorded'
);
select throws_ok(
  $$
    select * from public.cancel_repeating_chore_series_from_occurrence(
      '6b020000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_from_series')::uuid,
      current_setting('kinflow.test.cancel_from_skipped')::uuid,
      1
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'a skipped occurrence cannot become the cancellation boundary'
);
select throws_ok(
  $$
    select * from public.cancel_repeating_chore_series_from_occurrence(
      '6b020000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_from_series')::uuid,
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        where occurrence.series_id =
          current_setting('kinflow.test.cancel_from_series')::uuid
          and occurrence.recurrence_local_date =
            current_setting('kinflow.test.cancel_from_today')::date - 1
      ),
      1
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'a past recurrence slot cannot become the cancellation boundary'
);
select throws_ok(
  $$
    select * from public.cancel_repeating_chore_series_from_occurrence(
      '6b020000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_from_series')::uuid,
      null,
      1
    )
  $$,
  'KFC02',
  'invalid chore input',
  'the additive command requires an occurrence identity'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select throws_ok(
  $$
    select * from public.cancel_repeating_chore_series_from_occurrence(
      '6b020000-0000-4000-8000-000000000004',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_from_series')::uuid,
      current_setting('kinflow.test.cancel_from_target')::uuid,
      1
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'a plain member cannot schedule a series cancellation'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.cancel_repeating_chore_series_from_occurrence(
      '6b020000-0000-4000-8000-000000000005',
      '20000000-0000-4000-8000-000000000201',
      current_setting('kinflow.test.cancel_from_series')::uuid,
      current_setting('kinflow.test.cancel_from_target')::uuid,
      1
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'a cross-household request does not disclose the series'
);

select is(
  (
    select concat_ws(
      ':', result.effective_local_date::text, result.version,
      result.cancelled_count > 0, result.preserved_completed_count,
      result.terminal_revision_id is not null,
      result.terminal_revision_number, result.changed
    )
    from public.cancel_repeating_chore_series_from_occurrence(
      '6b030000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_from_series')::uuid,
      current_setting('kinflow.test.cancel_from_target')::uuid,
      1
    ) as result
  ),
  current_setting('kinflow.test.cancel_from_boundary') || ':2:t:1:t:2:t',
  'the server derives the recurrence boundary and returns a terminal revision'
);
select set_config(
  'kinflow.test.cancel_from_terminal_revision',
  (
    select series.active_revision_id::text
    from public.chore_series as series
    where series.id = current_setting('kinflow.test.cancel_from_series')::uuid
  ),
  true
);
select is(
  (
    select concat_ws(
      ':', series.version, series.deleted_at is null,
      revision.revision_number, revision.title, revision.description,
      revision.effective_local_date::text,
      revision.default_assignee_member_id::text,
      to_char(revision.due_local_time, 'HH24:MI')
    )
    from public.chore_series as series
    join public.chore_series_revisions as revision
      on revision.id = series.active_revision_id
    where series.id = current_setting('kinflow.test.cancel_from_series')::uuid
  ),
  '2:t:2:Cancel-from old title:Cancel-from old notes:'
    || (current_setting('kinflow.test.cancel_from_today')::date - 2)::text
    || ':30000000-0000-4000-8000-000000000101:08:00',
  'the surviving prefix keeps source content, anchor, assignee and time'
);
select is(
  (
    select (revision.recurrence_rule->'end'->>'type')
      || ':' || (revision.recurrence_rule->'end'->>'localDate')
    from public.chore_series_revisions as revision
    where revision.id =
      current_setting('kinflow.test.cancel_from_terminal_revision')::uuid
  ),
  'until:'
    || (current_setting('kinflow.test.cancel_from_boundary')::date - 1)::text,
  'the terminal never-rule is bounded immediately before the selected slot'
);
select is(
  (
    select concat_ws(
      ':', occurrence.status::text,
      occurrence.recurrence_local_date::text,
      occurrence.due_local_date::text,
      to_char(occurrence.due_at at time zone 'Asia/Seoul', 'HH24:MI'),
      occurrence.revision_id::text
    )
    from public.chore_occurrences as occurrence
    where occurrence.id = current_setting('kinflow.test.cancel_from_prefix')::uuid
  ),
  'scheduled:'
    || (current_setting('kinflow.test.cancel_from_boundary')::date - 1)::text
    || ':'
    || (current_setting('kinflow.test.cancel_from_boundary')::date + 20)::text
    || ':12:45:'
    || current_setting('kinflow.test.cancel_from_terminal_revision'),
  'the recurrence-before-boundary prefix keeps its later due-date exception'
);
select is(
  (
    select concat_ws(
      ':', occurrence.status::text,
      occurrence.recurrence_local_date::text,
      occurrence.due_local_date::text
    )
    from public.chore_occurrences as occurrence
    where occurrence.id = current_setting('kinflow.test.cancel_from_target')::uuid
  ),
  'cancelled:' || current_setting('kinflow.test.cancel_from_boundary')
    || ':'
    || (current_setting('kinflow.test.cancel_from_boundary')::date + 30)::text,
  'the moved target is cancelled by immutable recurrence slot, not due date'
);
select is(
  (
    select count(*)::integer
    from public.chore_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.cancel_from_series')::uuid
      and occurrence.recurrence_local_date >=
        current_setting('kinflow.test.cancel_from_boundary')::date
      and occurrence.status not in ('completed', 'cancelled')
  ),
  0,
  'every later incomplete occurrence across revisions is cancelled'
);
select is(
  (
    select concat_ws(
      ':', occurrence.status::text, occurrence.revision_id::text,
      occurrence.completed_by_member_id::text,
      occurrence.completed_at is not null
    )
    from public.chore_occurrences as occurrence
    where occurrence.id =
      current_setting('kinflow.test.cancel_from_completed')::uuid
  ),
  'completed:' || current_setting('kinflow.test.cancel_from_revision_1')
    || ':30000000-0000-4000-8000-000000000101:t',
  'completed history after the boundary remains on its historical revision'
);
select is(
  (
    select concat_ws(
      ':', event.operation, event.previous_revision_id::text,
      event.new_revision_id::text, event.effective_local_date::text,
      event.series_version, event.rebuilt_count,
      event.cancelled_count > 0, event.preserved_completed_count
    )
    from public.chore_series_change_events as event
    where event.series_id = current_setting('kinflow.test.cancel_from_series')::uuid
  ),
  'cancelled:' || current_setting('kinflow.test.cancel_from_revision_1')
    || ':' || current_setting('kinflow.test.cancel_from_terminal_revision')
    || ':' || current_setting('kinflow.test.cancel_from_boundary')
    || ':2:0:t:1',
  'one content-free aggregate event records the terminal boundary'
);
reset role;
select is(
  (
    select concat_ws(
      ':', count(*), min(octet_length(request.request_hash)),
      min(request.result_revision_id::text)
    )
    from app_private.chore_series_change_command_requests as request
    where request.series_id = current_setting('kinflow.test.cancel_from_series')::uuid
  ),
  '1:32:' || current_setting('kinflow.test.cancel_from_terminal_revision'),
  'private replay state stores one hash and terminal revision identity'
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
      ':', result.changed, result.version,
      result.terminal_revision_id::text, result.terminal_revision_number
    )
    from public.cancel_repeating_chore_series_from_occurrence(
      '6b030000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_from_series')::uuid,
      current_setting('kinflow.test.cancel_from_target')::uuid,
      1
    ) as result
  ),
  'f:2:' || current_setting('kinflow.test.cancel_from_terminal_revision')
    || ':2',
  'an identical selected cancellation replays its exact stored result'
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
    where revision.series_id = current_setting('kinflow.test.cancel_from_series')::uuid
  ),
  '2:1:1',
  'replay creates no duplicate terminal revision, event or command row'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.cancel_repeating_chore_series_from_occurrence(
      '6b030000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_from_series')::uuid,
      current_setting('kinflow.test.cancel_from_prefix')::uuid,
      2
    )
  $$,
  'KFC04',
  'idempotency key reused with different chore input',
  'the same command UUID cannot move to another target or version'
);
select throws_ok(
  $$
    select * from public.cancel_repeating_chore_series_from_occurrence(
      '6b030000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_from_series')::uuid,
      current_setting('kinflow.test.cancel_from_prefix')::uuid,
      1
    )
  $$,
  'KFC05',
  'chore series version conflict',
  'a stale selected cancellation loses optimistic concurrency'
);

select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '6b040000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Cancel-from one-time',
      null,
      '30000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_from_today')::date + 20,
      null
    )
  $$,
  'owner creates a one-time incompatibility fixture'
);
select throws_ok(
  $$
    select * from public.cancel_repeating_chore_series_from_occurrence(
      '6b040000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      (
        select series.id
        from public.chore_series as series
        where series.title = 'Cancel-from one-time'
      ),
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Cancel-from one-time'
      ),
      1
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'a one-time occurrence cannot become a repeating cancellation boundary'
);

select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '6b050000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Count terminal fixture',
      null,
      '30000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_from_today')::date - 2,
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":20}}'
    )
  $$,
  'owner creates a count-bounded terminal fixture'
);
select set_config(
  'kinflow.test.cancel_count_series',
  (
    select series.id::text
    from public.chore_series as series
    where series.title = 'Count terminal fixture'
  ),
  true
);
select set_config(
  'kinflow.test.cancel_count_boundary',
  (current_setting('kinflow.test.cancel_from_today')::date + 5)::text,
  true
);
select is(
  (
    select concat_ws(
      ':', result.version, result.terminal_revision_id is not null,
      result.terminal_revision_number, result.changed
    )
    from public.cancel_repeating_chore_series_from_occurrence(
      '6b050000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_count_series')::uuid,
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        where occurrence.series_id =
          current_setting('kinflow.test.cancel_count_series')::uuid
          and occurrence.recurrence_local_date =
            current_setting('kinflow.test.cancel_count_boundary')::date
      ),
      1
    ) as result
  ),
  '2:t:2:t',
  'a count rule also produces an immutable terminal revision'
);
select is(
  (
    select (revision.recurrence_rule->'end'->>'type')
      || ':' || (revision.recurrence_rule->'end'->>'count')
    from public.chore_series as series
    join public.chore_series_revisions as revision
      on revision.id = series.active_revision_id
    where series.id = current_setting('kinflow.test.cancel_count_series')::uuid
  ),
  'count:7',
  'the terminal count is bounded to source recurrence slots before the target'
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
      current_setting('kinflow.test.cancel_count_series')::uuid
    )
  $$,
  'the canonical worker accepts the bounded terminal revision'
);
reset role;
select is(
  (
    select count(*)::integer
    from public.chore_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.cancel_count_series')::uuid
      and occurrence.recurrence_local_date >=
        current_setting('kinflow.test.cancel_count_boundary')::date
      and occurrence.status = 'scheduled'
  ),
  0,
  'the worker does not regenerate a scheduled row at or after the boundary'
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
      '6b060000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'No prefix fixture',
      null,
      '30000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_from_today')::date + 20,
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":3}}'
    )
  $$,
  'owner creates a series whose selected target is its first slot'
);
select set_config(
  'kinflow.test.cancel_no_prefix_series',
  (
    select series.id::text
    from public.chore_series as series
    where series.title = 'No prefix fixture'
  ),
  true
);
select is(
  (
    select concat_ws(
      ':', result.version, result.cancelled_count,
      result.terminal_revision_id is null,
      result.terminal_revision_number is null, result.changed
    )
    from public.cancel_repeating_chore_series_from_occurrence(
      '6b060000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_no_prefix_series')::uuid,
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        where occurrence.series_id =
          current_setting('kinflow.test.cancel_no_prefix_series')::uuid
        order by occurrence.recurrence_local_date
        limit 1
      ),
      1
    ) as result
  ),
  '2:3:t:t:t',
  'a first-slot cancellation returns a null terminal revision pair'
);
reset role;
select is(
  (
    select concat_ws(
      ':', series.deleted_at is not null,
      count(*) filter (where occurrence.status = 'cancelled'),
      count(*) filter (where occurrence.status = 'scheduled')
    )
    from public.chore_series as series
    join public.chore_occurrences as occurrence
      on occurrence.series_id = series.id
    where series.id =
      current_setting('kinflow.test.cancel_no_prefix_series')::uuid
    group by series.deleted_at
  ),
  't:3:0',
  'without a scheduled prefix the series soft-deletes and all rows cancel'
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
      '6b070000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Old revision cancellation fixture',
      null,
      '30000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_from_today')::date,
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":12}}'
    )
  $$,
  'owner creates an old-revision denial fixture'
);
select set_config(
  'kinflow.test.cancel_old_revision_series',
  (
    select series.id::text
    from public.chore_series as series
    where series.title = 'Old revision cancellation fixture'
  ),
  true
);
select lives_ok(
  $$
    select * from public.update_repeating_chore_series_from_occurrence(
      '6b070000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_old_revision_series')::uuid,
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        where occurrence.series_id =
          current_setting('kinflow.test.cancel_old_revision_series')::uuid
          and occurrence.recurrence_local_date =
            current_setting('kinflow.test.cancel_from_today')::date + 5
      ),
      1,
      'Old revision cancellation fixture updated',
      null,
      '30000000-0000-4000-8000-000000000101',
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":12}}'
    )
  $$,
  'selected-occurrence editing remains compatible before cancellation'
);
select throws_ok(
  $$
    select * from public.cancel_repeating_chore_series_from_occurrence(
      '6b070000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_old_revision_series')::uuid,
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        where occurrence.series_id =
          current_setting('kinflow.test.cancel_old_revision_series')::uuid
          and occurrence.recurrence_local_date =
            current_setting('kinflow.test.cancel_from_today')::date + 2
      ),
      2
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'an occurrence on an old revision cannot become the cancellation boundary'
);

select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '6b080000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Legacy whole cancel fixture',
      null,
      '30000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.cancel_from_today')::date,
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":2}}'
    )
  $$,
  'owner creates a legacy whole-cancel fixture'
);
select is(
  (
    select concat_ws(
      ':', result.effective_local_date::text, result.version,
      result.cancelled_count, result.changed
    )
    from public.cancel_repeating_chore_series(
      '6b080000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      (
        select series.id
        from public.chore_series as series
        where series.title = 'Legacy whole cancel fixture'
      ),
      1
    ) as result
  ),
  current_setting('kinflow.test.cancel_from_today') || ':2:2:t',
  'the legacy whole-series cancellation signature and behavior remain intact'
);

reset role;
select hasnt_column(
  'public',
  'chore_series_change_events',
  'title',
  'the cancellation audit does not copy chore content'
);

select * from finish();
rollback;
