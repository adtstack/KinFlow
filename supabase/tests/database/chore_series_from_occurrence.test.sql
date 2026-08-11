begin;
set constraints all deferred;

select plan(36);

select has_function(
  'public',
  'update_repeating_chore_series_from_occurrence',
  array[
    'uuid', 'uuid', 'uuid', 'uuid', 'bigint', 'text', 'text', 'uuid',
    'time without time zone', 'jsonb'
  ],
  'selected-occurrence series update command exists'
);
select has_function(
  'app_private',
  'update_repeating_chore_series_at_boundary',
  array[
    'uuid', 'uuid', 'uuid', 'uuid', 'bigint', 'text', 'text', 'uuid',
    'time without time zone', 'jsonb'
  ],
  'legacy and selected-occurrence commands share one boundary engine'
);
select ok(
  (
    select bool_and(procedure.prosecdef)
      and bool_and(procedure.proconfig @> array['search_path=""']::text[])
    from pg_proc as procedure
    join pg_namespace as namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname in ('public', 'app_private')
      and procedure.proname in (
        'update_repeating_chore_series',
        'update_repeating_chore_series_from_occurrence',
        'update_repeating_chore_series_at_boundary'
      )
  ),
  'all selected-boundary functions are security-definer with empty search paths'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.update_repeating_chore_series_from_occurrence(uuid,uuid,uuid,uuid,bigint,text,text,uuid,time without time zone,jsonb)',
    'execute'
  ),
  'authenticated users can execute the mediated selected-boundary command'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.update_repeating_chore_series_from_occurrence(uuid,uuid,uuid,uuid,bigint,text,text,uuid,time without time zone,jsonb)',
    'execute'
  ),
  'anonymous users cannot execute the selected-boundary command'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.update_repeating_chore_series_at_boundary(uuid,uuid,uuid,uuid,bigint,text,text,uuid,time without time zone,jsonb)',
    'execute'
  ),
  'clients cannot bypass the private boundary engine'
);
select hasnt_column(
  'app_private',
  'chore_series_change_command_requests',
  'effective_occurrence_id',
  'private replay state stores only the request hash and aggregate result'
);
select throws_ok(
  $$
    select * from public.update_repeating_chore_series_from_occurrence(
      '6a000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      '6a100000-0000-4000-8000-000000000001',
      '6a200000-0000-4000-8000-000000000001',
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
  'the selected-boundary command derives identity from JWT'
);

select set_config(
  'kinflow.test.from_here_today',
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
      '6a010000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'From-here old title',
      'From-here old notes',
      '30000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.from_here_today')::date - 2,
      '08:00',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    )
  $$,
  'owner creates a daily series spanning the selected future boundary'
);
select set_config(
  'kinflow.test.from_here_series',
  (
    select series.id::text
    from public.chore_series as series
    where series.title = 'From-here old title'
  ),
  true
);
select set_config(
  'kinflow.test.from_here_revision_1',
  (
    select series.active_revision_id::text
    from public.chore_series as series
    where series.id = current_setting('kinflow.test.from_here_series')::uuid
  ),
  true
);
select set_config(
  'kinflow.test.from_here_boundary',
  (current_setting('kinflow.test.from_here_today')::date + 5)::text,
  true
);
select set_config(
  'kinflow.test.from_here_target',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.from_here_series')::uuid
      and occurrence.recurrence_local_date =
        current_setting('kinflow.test.from_here_boundary')::date
  ),
  true
);
select set_config(
  'kinflow.test.from_here_completed',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.from_here_series')::uuid
      and occurrence.recurrence_local_date =
        current_setting('kinflow.test.from_here_boundary')::date + 7
  ),
  true
);
select lives_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '6a010000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.from_here_completed')::uuid,
      1,
      true
    )
  $$,
  'a completion after the selected boundary is recorded before editing'
);
select set_config(
  'kinflow.test.from_here_override',
  (
    select occurrence.id::text
    from public.chore_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.from_here_series')::uuid
      and occurrence.recurrence_local_date =
        current_setting('kinflow.test.from_here_boundary')::date + 14
  ),
  true
);
select lives_ok(
  $$
    select * from public.reschedule_chore_occurrence(
      '6a010000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.from_here_override')::uuid,
      1,
      current_setting('kinflow.test.from_here_boundary')::date + 15,
      '11:15'
    )
  $$,
  'a later matching slot receives a one-occurrence override before editing'
);
select is(
  (
    select concat_ws(
      ':', result.revision_number, result.version,
      result.effective_local_date::text, result.changed
    )
    from public.update_repeating_chore_series_from_occurrence(
      '6a020000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.from_here_series')::uuid,
      current_setting('kinflow.test.from_here_target')::uuid,
      1,
      'From-here new title',
      'From-here new notes',
      '30000000-0000-4000-8000-000000000102',
      '10:30',
      jsonb_build_object(
        'frequency', 'weekly',
        'interval', 1,
        'weekdays', jsonb_build_array(
          (array['MO','TU','WE','TH','FR','SA','SU'])[
            extract(
              isodow from current_setting(
                'kinflow.test.from_here_boundary'
              )::date
            )::integer
          ]
        ),
        'end', jsonb_build_object('type', 'never')
      )
    ) as result
  ),
  '2:2:' || current_setting('kinflow.test.from_here_boundary') || ':t',
  'the database derives the exact immutable recurrence-slot boundary'
);
select set_config(
  'kinflow.test.from_here_revision_2',
  (
    select series.active_revision_id::text
    from public.chore_series as series
    where series.id = current_setting('kinflow.test.from_here_series')::uuid
  ),
  true
);
select is(
  (
    select concat_ws(
      ':', series.version, revision.revision_number,
      revision.effective_local_date::text, revision.title,
      revision.default_assignee_member_id::text,
      revision.recurrence_rule->>'frequency'
    )
    from public.chore_series as series
    join public.chore_series_revisions as revision
      on revision.id = series.active_revision_id
    where series.id = current_setting('kinflow.test.from_here_series')::uuid
  ),
  '2:2:' || current_setting('kinflow.test.from_here_boundary')
    || ':From-here new title:30000000-0000-4000-8000-000000000102:weekly',
  'the series points to a new immutable revision at the selected boundary'
);
select is(
  (
    select concat_ws(
      ':', occurrence.status::text, occurrence.revision_id::text,
      revision.title
    )
    from public.chore_occurrences as occurrence
    join public.chore_series_revisions as revision
      on revision.id = occurrence.revision_id
    where occurrence.series_id =
      current_setting('kinflow.test.from_here_series')::uuid
      and occurrence.recurrence_local_date =
        current_setting('kinflow.test.from_here_boundary')::date - 1
  ),
  'scheduled:' || current_setting('kinflow.test.from_here_revision_1')
    || ':From-here old title',
  'the incomplete occurrence before the boundary stays on old content'
);
select is(
  (
    select concat_ws(
      ':', occurrence.id::text, occurrence.status::text,
      occurrence.revision_id::text, occurrence.assignee_member_id::text
    )
    from public.chore_occurrences as occurrence
    where occurrence.id = current_setting('kinflow.test.from_here_target')::uuid
  ),
  current_setting('kinflow.test.from_here_target')
    || ':scheduled:' || current_setting('kinflow.test.from_here_revision_2')
    || ':30000000-0000-4000-8000-000000000102',
  'the selected occurrence keeps identity and adopts the new defaults'
);
select is(
  (
    select concat_ws(
      ':', occurrence.status::text, occurrence.revision_id::text,
      revision.title, occurrence.completed_at is not null
    )
    from public.chore_occurrences as occurrence
    join public.chore_series_revisions as revision
      on revision.id = occurrence.revision_id
    where occurrence.id =
      current_setting('kinflow.test.from_here_completed')::uuid
  ),
  'completed:' || current_setting('kinflow.test.from_here_revision_1')
    || ':From-here old title:t',
  'a completed occurrence after the boundary preserves its historical revision'
);
select is(
  (
    select concat_ws(
      ':', occurrence.status::text, occurrence.version,
      occurrence.recurrence_local_date::text,
      occurrence.due_local_date::text,
      occurrence.assignee_member_id::text,
      to_char(occurrence.due_at at time zone 'Asia/Seoul', 'HH24:MI')
    )
    from public.chore_occurrences as occurrence
    where occurrence.id =
      current_setting('kinflow.test.from_here_override')::uuid
  ),
  'scheduled:3:'
    || (current_setting('kinflow.test.from_here_boundary')::date + 14)::text
    || ':'
    || (current_setting('kinflow.test.from_here_boundary')::date + 14)::text
    || ':30000000-0000-4000-8000-000000000102:10:30',
  'a later incomplete one-occurrence override resets to the new series defaults'
);
select is(
  (
    select concat_ws(':', occurrence.status::text, occurrence.revision_id::text)
    from public.chore_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.from_here_series')::uuid
      and occurrence.recurrence_local_date =
        current_setting('kinflow.test.from_here_boundary')::date + 1
  ),
  'cancelled:' || current_setting('kinflow.test.from_here_revision_1'),
  'an obsolete incomplete slot remains as cancelled history'
);
select is(
  (
    select concat_ws(
      ':', event.operation, event.effective_local_date::text,
      event.series_version, event.rebuilt_count > 0,
      event.cancelled_count > 0, event.preserved_completed_count
    )
    from public.chore_series_change_events as event
    where event.series_id = current_setting('kinflow.test.from_here_series')::uuid
  ),
  'updated:' || current_setting('kinflow.test.from_here_boundary')
    || ':2:t:t:1',
  'the selected-boundary mutation records one content-free aggregate event'
);
reset role;
select is(
  (
    select concat_ws(':', count(*), min(octet_length(request.request_hash)))
    from app_private.chore_series_change_command_requests as request
    where request.series_id = current_setting('kinflow.test.from_here_series')::uuid
  ),
  '1:32',
  'private replay state stores one SHA-256 request hash only'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select result.changed
    from public.update_repeating_chore_series_from_occurrence(
      '6a020000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.from_here_series')::uuid,
      current_setting('kinflow.test.from_here_target')::uuid,
      1,
      'From-here new title',
      'From-here new notes',
      '30000000-0000-4000-8000-000000000102',
      '10:30',
      jsonb_build_object(
        'frequency', 'weekly',
        'interval', 1,
        'weekdays', jsonb_build_array(
          (array['MO','TU','WE','TH','FR','SA','SU'])[
            extract(isodow from current_setting(
              'kinflow.test.from_here_boundary'
            )::date)::integer
          ]
        ),
        'end', jsonb_build_object('type', 'never')
      )
    ) as result
  ),
  false,
  'an identical selected-boundary command replays without another mutation'
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
    where revision.series_id = current_setting('kinflow.test.from_here_series')::uuid
  ),
  '2:1:1',
  'replay creates no duplicate revision, event, or private command row'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    select * from public.update_repeating_chore_series_from_occurrence(
      '6a020000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.from_here_series')::uuid,
      current_setting('kinflow.test.from_here_target')::uuid,
      2,
      'Different replay input',
      null,
      '30000000-0000-4000-8000-000000000102',
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    )
  $$,
  'KFC04',
  'idempotency key reused with different chore input',
  'the same command UUID cannot target different input'
);
select throws_ok(
  $$
    select * from public.update_repeating_chore_series_from_occurrence(
      '6a020000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.from_here_series')::uuid,
      current_setting('kinflow.test.from_here_target')::uuid,
      1,
      'Stale selected edit',
      null,
      '30000000-0000-4000-8000-000000000101',
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    )
  $$,
  'KFC05',
  'chore series version conflict',
  'a stale selected-boundary edit loses optimistic concurrency'
);
select throws_ok(
  $$
    select * from public.update_repeating_chore_series_from_occurrence(
      '6a020000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.from_here_series')::uuid,
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        where occurrence.series_id = current_setting('kinflow.test.from_here_series')::uuid
          and occurrence.recurrence_local_date =
            current_setting('kinflow.test.from_here_boundary')::date - 1
      ),
      2,
      'Old revision target',
      null,
      '30000000-0000-4000-8000-000000000102',
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'an occurrence on an old revision cannot become a new boundary'
);
select throws_ok(
  $$
    select * from public.update_repeating_chore_series_from_occurrence(
      '6a020000-0000-4000-8000-000000000004',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.from_here_series')::uuid,
      current_setting('kinflow.test.from_here_completed')::uuid,
      2,
      'Completed target',
      null,
      '30000000-0000-4000-8000-000000000102',
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'a completed occurrence cannot become the selected boundary'
);
select throws_ok(
  $$
    select * from public.update_repeating_chore_series_from_occurrence(
      '6a020000-0000-4000-8000-000000000005',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.from_here_series')::uuid,
      null,
      2,
      'Null target',
      null,
      '30000000-0000-4000-8000-000000000102',
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'the additive command cannot fall back to a client-omitted boundary'
);
select throws_ok(
  $$
    select * from public.update_repeating_chore_series_from_occurrence(
      '6a020000-0000-4000-8000-000000000006',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.from_here_series')::uuid,
      current_setting('kinflow.test.from_here_target')::uuid,
      2,
      'Expired selected recurrence',
      null,
      '30000000-0000-4000-8000-000000000102',
      null,
      jsonb_build_object(
        'frequency', 'daily',
        'interval', 1,
        'end', jsonb_build_object(
          'type', 'until',
          'localDate', (
            current_setting('kinflow.test.from_here_boundary')::date - 1
          )::text
        )
      )
    )
  $$,
  'KFC07',
  'invalid chore recurrence rule',
  'the recurrence end cannot precede the server-derived selected boundary'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select throws_ok(
  $$
    select * from public.update_repeating_chore_series_from_occurrence(
      '6a030000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.from_here_series')::uuid,
      current_setting('kinflow.test.from_here_target')::uuid,
      2,
      'Member denied',
      null,
      '30000000-0000-4000-8000-000000000102',
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'a plain member cannot edit a series from a selected occurrence'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '6a040000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'From-here one-time',
      null,
      '30000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.from_here_today')::date + 9,
      null
    )
  $$,
  'owner creates a one-time incompatibility fixture'
);
select throws_ok(
  $$
    select * from public.update_repeating_chore_series_from_occurrence(
      '6a040000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      (
        select series.id
        from public.chore_series as series
        where series.title = 'From-here one-time'
      ),
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'From-here one-time'
      ),
      1,
      'One-time denied',
      null,
      '30000000-0000-4000-8000-000000000101',
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}'
    )
  $$,
  'KFC03',
  'chore not found or forbidden',
  'a one-time occurrence cannot become a repeating-series boundary'
);

select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '6a050000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      'Legacy boundary old',
      null,
      '30000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.from_here_today')::date,
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":3}}'
    )
  $$,
  'legacy whole-series compatibility fixture is created'
);
select is(
  (
    select concat_ws(':', result.effective_local_date::text, result.version, result.changed)
    from public.update_repeating_chore_series(
      '6a050000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      (
        select series.id
        from public.chore_series as series
        where series.title = 'Legacy boundary old'
      ),
      1,
      'Legacy boundary new',
      null,
      '30000000-0000-4000-8000-000000000101',
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":3}}'
    ) as result
  ),
  current_setting('kinflow.test.from_here_today') || ':2:t',
  'the legacy RPC still derives household-local today exactly'
);
select is(
  (
    select result.changed
    from public.update_repeating_chore_series(
      '6a050000-0000-4000-8000-000000000002',
      '20000000-0000-4000-8000-000000000101',
      (
        select series.id
        from public.chore_series as series
        where series.title = 'Legacy boundary new'
      ),
      1,
      'Legacy boundary new',
      null,
      '30000000-0000-4000-8000-000000000101',
      null,
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":3}}'
    ) as result
  ),
  false,
  'the legacy request hash remains replay compatible after refactoring'
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
      current_setting('kinflow.test.from_here_series')::uuid
    )
  $$,
  'the worker accepts the selected-boundary active revision without duplicates'
);
reset role;
select hasnt_column(
  'public',
  'chore_series_change_events',
  'description',
  'public aggregate audit does not copy user notes'
);

select * from finish();
rollback;
