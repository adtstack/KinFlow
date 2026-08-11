begin;
set constraints all deferred;

select plan(64);

-- Schema, mediated access, immutable history, and content-free command state.
select has_column(
  'public', 'event_series', 'ended_at',
  'calendar series records an explicit lifecycle end instant'
);
select has_column(
  'public', 'event_series', 'ended_effective_local_date',
  'calendar series records the server-owned local end boundary'
);
select has_table(
  'public', 'event_series_change_events',
  'content-free recurring series change history exists'
);
select has_table(
  'app_private', 'calendar_series_change_command_requests',
  'private recurring series command replay state exists'
);
select has_function(
  'public', 'get_recurring_calendar_series', array['uuid', 'uuid'],
  'active recurring series detail command exists'
);
select has_function(
  'public',
  'update_recurring_calendar_series',
  array[
    'uuid', 'uuid', 'uuid', 'bigint', 'text', 'text', 'boolean',
    'date', 'time without time zone', 'integer', 'date', 'text',
    'text', 'jsonb', 'uuid[]'
  ],
  'whole recurring series update command exists'
);
select has_function(
  'public', 'cancel_recurring_calendar_series',
  array['uuid', 'uuid', 'uuid', 'bigint'],
  'whole recurring series cancellation command exists'
);
select has_trigger(
  'public', 'event_series_change_events',
  'event_series_change_events_immutable',
  'series change history rejects mutation'
);
select ok(
  (
    select pg_class.relrowsecurity and pg_class.relforcerowsecurity
    from pg_catalog.pg_class
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'event_series_change_events'
  ),
  'series change history enables and forces RLS'
);
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
        'get_recurring_calendar_series',
        'update_recurring_calendar_series',
        'cancel_recurring_calendar_series'
      )
  ),
  'recurring series functions are security-definer with empty search paths'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.get_recurring_calendar_series(uuid,uuid)', 'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.update_recurring_calendar_series(uuid,uuid,uuid,bigint,text,text,boolean,date,time without time zone,integer,date,text,text,jsonb,uuid[])',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.cancel_recurring_calendar_series(uuid,uuid,uuid,bigint)',
    'execute'
  ),
  'authenticated clients can execute mediated recurring series functions'
);
select ok(
  not has_function_privilege(
    'anon', 'public.get_recurring_calendar_series(uuid,uuid)', 'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.update_recurring_calendar_series(uuid,uuid,uuid,bigint,text,text,boolean,date,time without time zone,integer,date,text,text,jsonb,uuid[])',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.cancel_recurring_calendar_series(uuid,uuid,uuid,bigint)',
    'execute'
  ),
  'anonymous clients cannot execute recurring series functions'
);
select ok(
  has_table_privilege(
    'authenticated', 'public.event_series_change_events', 'select'
  )
  and not has_table_privilege(
    'authenticated', 'public.event_series_change_events',
    'insert,update,delete'
  ),
  'clients can only read authorized series change history'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.calendar_series_change_command_requests', 'select'
  )
  and not has_table_privilege(
    'service_role',
    'app_private.calendar_series_change_command_requests', 'select'
  ),
  'API roles cannot inspect private recurring series command state'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema in ('public', 'app_private')
      and table_name in (
        'event_series_change_events',
        'calendar_series_change_command_requests'
      )
      and column_name in (
        'title', 'description', 'display_name',
        'participant_member_ids', 'recurrence_rule'
      )
  ),
  'series history and replay state contain no calendar content or people list'
);
select is(
  (
    select pg_catalog.string_agg(
      parameter_name, ',' order by ordinal_position
    )
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name =
        'update_recurring_calendar_series_' || (
          'public.update_recurring_calendar_series(uuid,uuid,uuid,bigint,text,text,boolean,date,time without time zone,integer,date,text,text,jsonb,uuid[])'
            ::regprocedure::oid::text
        )
      and parameter_mode = 'OUT'
  ),
  'household_id,household_timezone,household_local_date,series_id,revision_id,revision_number,effective_local_date,materialized_through,version,rebuilt_count,cancelled_count,preserved_exception_count,changed',
  'series update returns the exact compact result envelope'
);
select is(
  (
    select pg_catalog.string_agg(
      parameter_name, ',' order by ordinal_position
    )
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name =
        'cancel_recurring_calendar_series_' || (
          'public.cancel_recurring_calendar_series(uuid,uuid,uuid,bigint)'
            ::regprocedure::oid::text
        )
      and parameter_mode = 'OUT'
  ),
  'household_id,household_timezone,household_local_date,series_id,effective_local_date,version,cancelled_count,preserved_past_count,changed',
  'series cancellation returns the exact compact result envelope'
);
select is(
  (
    select pg_catalog.string_agg(
      parameter_name, ',' order by ordinal_position
    )
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name =
        'get_recurring_calendar_series_' || (
          'public.get_recurring_calendar_series(uuid,uuid)'
            ::regprocedure::oid::text
        )
      and parameter_mode = 'OUT'
  ),
  'household_id,household_timezone,household_local_date,series_id,revision_id,revision_number,title,description,is_all_day,local_start_date,local_start_time,duration_minutes,all_day_end_date_exclusive,timezone,overlap_policy,recurrence_rule,participant_member_ids,participant_display_names,version',
  'series detail returns the exact editable active-revision fields'
);

-- Identity must come from JWT, and the effective boundary comes from household
-- local server time rather than a client-supplied date.
select throws_ok(
  $$
    select * from public.get_recurring_calendar_series(
      '20000000-0000-4000-8000-000000000101',
      '45000000-0000-4000-8000-000000000001'
    )
  $$,
  'KFE01', 'authentication required',
  'series detail derives the caller from JWT'
);
select throws_ok(
  $$
    select * from public.update_recurring_calendar_series(
      '45000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000101',
      '45000000-0000-4000-8000-000000000002', 1,
      'No auth', null, false, current_date, time '09:00', 30, null,
      'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE01', 'authentication required',
  'series update derives the caller from JWT'
);
select throws_ok(
  $$
    select * from public.cancel_recurring_calendar_series(
      '45000000-0000-4000-8000-000000000003',
      '20000000-0000-4000-8000-000000000101',
      '45000000-0000-4000-8000-000000000002', 1
    )
  $$,
  'KFE01', 'authentication required',
  'series cancellation derives the caller from JWT'
);

select set_config(
  'kinflow.test.calendar_series_today',
  (pg_catalog.statement_timestamp() at time zone 'Asia/Seoul')::date::text,
  true
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101', true
);
select is(
  (
    select materialized_count
    from public.create_recurring_calendar_event(
      '45000000-0000-4000-8000-000000000010',
      '20000000-0000-4000-8000-000000000101',
      'Series old title', 'Series old description', false,
      current_setting('kinflow.test.calendar_series_today')::date - 3,
      time '08:00', 60, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  ),
  366,
  'daily fixture materializes its initial inclusive one-year window'
);
select set_config(
  'kinflow.test.calendar_series_id',
  (
    select series.id::text
    from public.event_series as series
    where series.title = 'Series old title'
  ),
  true
);
select set_config(
  'kinflow.test.calendar_series_revision_1',
  (
    select series.active_revision_id::text
    from public.event_series as series
    where series.id = current_setting('kinflow.test.calendar_series_id')::uuid
  ),
  true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.revision_number, result.title, result.version,
      result.household_local_date::text,
      pg_catalog.cardinality(result.participant_member_ids)
    )
    from public.get_recurring_calendar_series(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_series_id')::uuid
    ) as result
  ),
  '1:Series old title:1:'
    || current_setting('kinflow.test.calendar_series_today') || ':1',
  'series detail loads the active normalized source revision'
);
select set_config(
  'kinflow.test.calendar_exception_occurrence_id',
  (
    select occurrence.id::text
    from public.event_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.calendar_series_id')::uuid
      and occurrence.recurrence_local_start_date =
        current_setting('kinflow.test.calendar_series_today')::date + 2
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
      '45000000-0000-4000-8000-000000000011',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_series_id')::uuid,
      current_setting('kinflow.test.calendar_exception_occurrence_id')::uuid,
      1, 'Exception title', 'Exception description', false,
      current_setting('kinflow.test.calendar_series_today')::date + 20,
      time '15:30', 90, null, 'Asia/Seoul', 'later',
      array[
        '30000000-0000-4000-8000-000000000101'::uuid,
        '30000000-0000-4000-8000-000000000102'::uuid
      ]
    ) as result
  ),
  '2:1:f:t',
  'future occurrence fixture becomes an explicit moved exception'
);
select set_config(
  'kinflow.test.calendar_exception_revision',
  (
    select occurrence.revision_id::text
    from public.event_occurrences as occurrence
    where occurrence.id = current_setting(
      'kinflow.test.calendar_exception_occurrence_id'
    )::uuid
  ),
  true
);
select ok(
  exists (
    select 1
    from public.event_occurrence_exceptions as exception
    join public.event_occurrences as occurrence
      on occurrence.id = exception.occurrence_id
    where exception.occurrence_id = current_setting(
        'kinflow.test.calendar_exception_occurrence_id'
      )::uuid
      and exception.exception_revision_id = current_setting(
        'kinflow.test.calendar_exception_revision'
      )::uuid
      and exception.version = 1
      and not exception.cancelled
      and occurrence.version = 2
      and occurrence.local_start_date =
        current_setting('kinflow.test.calendar_series_today')::date + 20
  ),
  'exception fixture has stable normalized identity before whole-series edit'
);

select throws_ok(
  $$
    select * from public.update_recurring_calendar_series(
      '45000000-0000-4000-8000-000000000020',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_series_id')::uuid, 1,
      'Duplicate people', null, false,
      current_setting('kinflow.test.calendar_series_today')::date - 3,
      time '09:00', 60, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array[
        '30000000-0000-4000-8000-000000000101'::uuid,
        '30000000-0000-4000-8000-000000000101'::uuid
      ]
    )
  $$,
  'KFE07', 'invalid calendar recurrence rule',
  'series update rejects duplicate participant IDs'
);
select throws_ok(
  $$
    select * from public.update_recurring_calendar_series(
      '45000000-0000-4000-8000-000000000021',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_series_id')::uuid, 1,
      'Series old title', 'Series old description', false,
      current_setting('kinflow.test.calendar_series_today')::date - 3,
      time '08:00', 60, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE08', 'calendar series transition not allowed',
  'series update rejects a normalized no-op'
);
select throws_ok(
  $$
    select * from public.update_recurring_calendar_series(
      '45000000-0000-4000-8000-000000000022',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_series_id')::uuid, 99,
      'Stale title', null, false,
      current_setting('kinflow.test.calendar_series_today')::date - 3,
      time '09:00', 60, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE05', 'stale calendar event version',
  'series update rejects a stale version'
);
select throws_ok(
  $$
    select * from public.update_recurring_calendar_series(
      '45000000-0000-4000-8000-000000000023',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_series_id')::uuid, 1,
      'DST gap title', null, false,
      current_setting('kinflow.test.calendar_series_today')::date - 3,
      time '02:30', 60, null, 'America/Los_Angeles', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE06', 'nonexistent calendar local time',
  'series update rejects a DST gap atomically'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201', true
);
select throws_ok(
  $$
    select * from public.update_recurring_calendar_series(
      '45000000-0000-4000-8000-000000000024',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_series_id')::uuid, 1,
      'Outsider title', null, false,
      current_setting('kinflow.test.calendar_series_today')::date - 3,
      time '09:00', 60, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE03', 'calendar event not found or forbidden',
  'an outsider cannot update another household series'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101', true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', pg_catalog.count(*), pg_catalog.max(revision.revision_number),
      pg_catalog.max(series.version)
    )
    from public.event_series as series
    join public.event_series_revisions as revision
      on revision.series_id = series.id
    where series.id = current_setting('kinflow.test.calendar_series_id')::uuid
  ),
  '2:2:1',
  'failed updates leave source, exception revision, and series version intact'
);

-- Interval change applies from household-local today, not the anchor. It
-- rebuilds matching source slots, cancels obsolete source slots, and never
-- overwrites an explicit occurrence exception.
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.revision_number, result.version,
      result.effective_local_date::text, result.rebuilt_count,
      result.cancelled_count, result.preserved_exception_count,
      result.changed
    )
    from public.update_recurring_calendar_series(
      '45000000-0000-4000-8000-000000000100',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_series_id')::uuid, 1,
      'Series new title', 'Series new description', false,
      current_setting('kinflow.test.calendar_series_today')::date - 3,
      time '09:00', 45, null, 'Asia/Seoul', 'later',
      '{"frequency":"daily","interval":2,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000102'::uuid]
    ) as result
  ),
  '3:2:' || current_setting('kinflow.test.calendar_series_today')
    || ':183:181:1:t',
  'whole-series edit rebuilds the exact future interval partition'
);
select set_config(
  'kinflow.test.calendar_series_revision_3',
  (
    select series.active_revision_id::text
    from public.event_series as series
    where series.id = current_setting('kinflow.test.calendar_series_id')::uuid
  ),
  true
);
select ok(
  exists (
    select 1
    from public.event_series as series
    join public.event_series_revisions as revision
      on revision.id = series.active_revision_id
    where series.id = current_setting('kinflow.test.calendar_series_id')::uuid
      and series.version = 2
      and series.title = 'Series new title'
      and revision.revision_number = 3
      and revision.snapshot_title = 'Series new title'
      and revision.local_start_time = time '09:00'
      and revision.duration_minutes = 45
      and revision.recurrence_rule->>'interval' = '2'
  ),
  'series projection points to a new immutable normalized revision'
);
select ok(
  exists (
    select 1
    from public.event_series_revisions as revision
    where revision.id = current_setting(
        'kinflow.test.calendar_series_revision_1'
      )::uuid
      and revision.snapshot_title = 'Series old title'
      and revision.snapshot_description = 'Series old description'
      and revision.local_start_time = time '08:00'
  ),
  'source revision content remains unchanged'
);
select ok(
  exists (
    select 1
    from public.event_occurrences as occurrence
    where occurrence.series_id =
        current_setting('kinflow.test.calendar_series_id')::uuid
      and occurrence.recurrence_local_start_date =
        current_setting('kinflow.test.calendar_series_today')::date - 2
      and occurrence.revision_id = current_setting(
        'kinflow.test.calendar_series_revision_1'
      )::uuid
      and (occurrence.starts_at at time zone occurrence.timezone)::time =
        time '08:00'
      and occurrence.status = 'scheduled'
      and occurrence.version = 1
  ),
  'past source occurrence stays byte-for-byte on the old revision projection'
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
        'kinflow.test.calendar_exception_occurrence_id'
      )::uuid
      and occurrence.recurrence_local_start_date =
        current_setting('kinflow.test.calendar_series_today')::date + 2
      and occurrence.local_start_date =
        current_setting('kinflow.test.calendar_series_today')::date + 20
      and (occurrence.starts_at at time zone occurrence.timezone)::time =
        time '15:30'
      and occurrence.revision_id = current_setting(
        'kinflow.test.calendar_exception_revision'
      )::uuid
      and occurrence.version = 2
      and occurrence.status = 'scheduled'
      and exception.version = 1
      and not exception.cancelled
      and revision.snapshot_title = 'Exception title'
  ),
  'whole-series edit does not overwrite a future modified exception'
);
select ok(
  exists (
    select 1
    from public.event_occurrences as occurrence
    where occurrence.series_id =
        current_setting('kinflow.test.calendar_series_id')::uuid
      and occurrence.recurrence_local_start_date =
        current_setting('kinflow.test.calendar_series_today')::date + 1
      and occurrence.revision_id = current_setting(
        'kinflow.test.calendar_series_revision_3'
      )::uuid
      and (occurrence.starts_at at time zone occurrence.timezone)::time =
        time '09:00'
      and occurrence.ends_at - occurrence.starts_at = interval '45 minutes'
      and occurrence.status = 'scheduled'
      and occurrence.version = 2
  ),
  'matching future source slot reuses identity and adopts the new revision'
);
select ok(
  exists (
    select 1
    from public.event_occurrences as occurrence
    where occurrence.series_id =
        current_setting('kinflow.test.calendar_series_id')::uuid
      and occurrence.recurrence_local_start_date =
        current_setting('kinflow.test.calendar_series_today')::date
      and occurrence.revision_id = current_setting(
        'kinflow.test.calendar_series_revision_1'
      )::uuid
      and occurrence.status = 'cancelled'
      and occurrence.version = 2
  ),
  'obsolete future source slot remains as cancelled history'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':',
      pg_catalog.count(*) filter (where occurrence.status = 'scheduled'),
      pg_catalog.count(*) filter (where occurrence.status = 'cancelled'),
      pg_catalog.count(*) filter (
        where exception.occurrence_id is not null
      ),
      pg_catalog.count(distinct occurrence.occurrence_key)
    )
    from public.event_occurrences as occurrence
    left join public.event_occurrence_exceptions as exception
      on exception.occurrence_id = occurrence.id
    where occurrence.series_id =
      current_setting('kinflow.test.calendar_series_id')::uuid
      and occurrence.recurrence_local_start_date >=
        current_setting('kinflow.test.calendar_series_today')::date
  ),
  '184:181:1:365',
  'future slots form an exact unique scheduled, cancelled, and exception set'
);
select is(
  (
    select pg_catalog.array_agg(
      participant.member_id order by participant.member_id
    )
    from public.event_revision_participants as participant
    where participant.revision_id = current_setting(
      'kinflow.test.calendar_series_revision_3'
    )::uuid
  ),
  array['30000000-0000-4000-8000-000000000102'::uuid],
  'new revision owns the exact normalized participant snapshot'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', event.operation, event.effective_local_date::text,
      event.rebuilt_count, event.cancelled_count,
      event.preserved_exception_count, event.preserved_past_count,
      event.series_version
    )
    from public.event_series_change_events as event
    where event.series_id = current_setting(
      'kinflow.test.calendar_series_id'
    )::uuid
      and event.operation = 'updated'
  ),
  'updated:' || current_setting('kinflow.test.calendar_series_today')
    || ':183:181:1:3:2',
  'series edit records one content-free aggregate history event'
);
reset role;
select ok(
  exists (
    select 1
    from app_private.calendar_materialization_states as state
    where state.series_id = current_setting(
        'kinflow.test.calendar_series_id'
      )::uuid
      and state.revision_id = current_setting(
        'kinflow.test.calendar_series_revision_3'
      )::uuid
      and state.covered_through =
        current_setting('kinflow.test.calendar_series_today')::date + 365
      and state.last_result = 'succeeded'
      and state.last_changed_count = 183
  ),
  'series edit advances rolling coverage to the new active revision'
);
select ok(
  exists (
    select 1
    from app_private.calendar_audit_events as audit
    join public.event_occurrences as occurrence
      on occurrence.id = audit.occurrence_id
    where audit.series_id = current_setting(
        'kinflow.test.calendar_series_id'
      )::uuid
      and audit.action = 'calendar.series_updated'
      and audit.series_version = 2
      and audit.occurrence_version = occurrence.version
  ),
  'series audit stores the actual selected occurrence version'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101', true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.revision_number, result.title,
      result.local_start_time::text, result.version,
      pg_catalog.cardinality(result.participant_member_ids)
    )
    from public.get_recurring_calendar_series(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_series_id')::uuid
    ) as result
  ),
  '3:Series new title:09:00:00:2:1',
  'series editor detail uses the active series revision, not an exception snapshot'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.revision_number, result.version,
      result.rebuilt_count, result.cancelled_count,
      result.preserved_exception_count, result.changed
    )
    from public.update_recurring_calendar_series(
      '45000000-0000-4000-8000-000000000100',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_series_id')::uuid, 1,
      'Series new title', 'Series new description', false,
      current_setting('kinflow.test.calendar_series_today')::date - 3,
      time '09:00', 45, null, 'Asia/Seoul', 'later',
      '{"frequency":"daily","interval":2,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000102'::uuid]
    ) as result
  ),
  '3:2:183:181:1:f',
  'same series update key replays the original result without side effects'
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
    where revision.series_id = current_setting(
      'kinflow.test.calendar_series_id'
    )::uuid
  ),
  '3:1:1',
  'update replay creates no duplicate revision, event, or command row'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101', true
);
select throws_ok(
  $$
    select * from public.update_recurring_calendar_series(
      '45000000-0000-4000-8000-000000000100',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_series_id')::uuid, 2,
      'Different replay title', null, false,
      current_setting('kinflow.test.calendar_series_today')::date - 3,
      time '10:00', 30, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000102'::uuid]
    )
  $$,
  'KFE04', 'idempotency key reused with different calendar input',
  'same series update key with different input is rejected'
);
select throws_ok(
  $$
    select * from public.update_recurring_calendar_series(
      '45000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_series_id')::uuid, 1,
      'Stale second edit', null, false,
      current_setting('kinflow.test.calendar_series_today')::date - 3,
      time '10:00', 30, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000102'::uuid]
    )
  $$,
  'KFE05', 'stale calendar event version',
  'a new series update key still rejects a stale version'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201', true
);
select is(
  (
    select pg_catalog.count(*)
    from public.event_series_change_events
    where series_id = current_setting('kinflow.test.calendar_series_id')::uuid
  ),
  0::bigint,
  'series history RLS hides another household from an outsider'
);
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102', true
);
select is(
  (
    select pg_catalog.count(*)
    from public.event_series_change_events
    where series_id = current_setting('kinflow.test.calendar_series_id')::uuid
  ),
  1::bigint,
  'series history RLS exposes the aggregate event to a household member'
);

-- Whole-series cancellation keeps the series and past rows queryable, but
-- cancels every source and exception occurrence at or after local today.
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101', true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.version, result.effective_local_date::text,
      result.cancelled_count, result.preserved_past_count, result.changed
    )
    from public.cancel_recurring_calendar_series(
      '45000000-0000-4000-8000-000000000200',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_series_id')::uuid, 2
    ) as result
  ),
  '3:' || current_setting('kinflow.test.calendar_series_today')
    || ':184:3:t',
  'series cancellation future-cancels every remaining scheduled occurrence'
);
select ok(
  exists (
    select 1
    from public.event_series as series
    where series.id = current_setting('kinflow.test.calendar_series_id')::uuid
      and series.deleted_at is null
      and series.ended_at is not null
      and series.ended_effective_local_date =
        current_setting('kinflow.test.calendar_series_today')::date
      and series.version = 3
  ),
  'series cancellation records lifecycle end without soft-deleting history'
);
select ok(
  exists (
    select 1
    from public.event_occurrences as occurrence
    where occurrence.series_id =
        current_setting('kinflow.test.calendar_series_id')::uuid
      and occurrence.recurrence_local_start_date =
        current_setting('kinflow.test.calendar_series_today')::date - 2
      and occurrence.status = 'scheduled'
      and occurrence.version = 1
      and occurrence.revision_id = current_setting(
        'kinflow.test.calendar_series_revision_1'
      )::uuid
  ),
  'series cancellation leaves past occurrence history untouched'
);
select is(
  (
    select pg_catalog.count(*)
    from public.event_occurrences as occurrence
    where occurrence.series_id =
      current_setting('kinflow.test.calendar_series_id')::uuid
      and occurrence.recurrence_local_start_date >=
        current_setting('kinflow.test.calendar_series_today')::date
      and occurrence.status <> 'cancelled'
  ),
  0::bigint,
  'series cancellation leaves no active future occurrence, including exceptions'
);
select is(
  (
    select pg_catalog.concat_ws(':', page.title, page.local_start_time::text)
    from public.get_calendar_event_page_v2(
      '20000000-0000-4000-8000-000000000101', 'day',
      current_setting('kinflow.test.calendar_series_today')::date - 2,
      current_setting('kinflow.test.calendar_series_today')::date - 1,
      30, null
    ) as page
    where page.series_id = current_setting(
      'kinflow.test.calendar_series_id'
    )::uuid
  ),
  'Series old title:08:00:00',
  'past Calendar view remains queryable with its historical revision content'
);
select is(
  (
    select pg_catalog.count(*)
    from public.get_calendar_event_page_v2(
      '20000000-0000-4000-8000-000000000101', 'day',
      current_setting('kinflow.test.calendar_series_today')::date + 1,
      current_setting('kinflow.test.calendar_series_today')::date + 2,
      30, null
    ) as page
    where page.series_id = current_setting(
      'kinflow.test.calendar_series_id'
    )::uuid
  ),
  0::bigint,
  'future Calendar view excludes a terminated series'
);
select throws_ok(
  $$
    select * from public.get_recurring_calendar_series(
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_series_id')::uuid
    )
  $$,
  'KFE03', 'calendar event not found or forbidden',
  'ended series cannot be reopened in the active series editor'
);
reset role;
select ok(
  not exists (
    select 1
    from app_private.calendar_materialization_states as state
    where state.series_id = current_setting(
      'kinflow.test.calendar_series_id'
    )::uuid
  ),
  'series cancellation removes rolling materialization eligibility state'
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', event.operation, event.effective_local_date::text,
      event.cancelled_count, event.preserved_exception_count,
      event.preserved_past_count, event.series_version
    )
    from public.event_series_change_events as event
    where event.series_id = current_setting(
        'kinflow.test.calendar_series_id'
      )::uuid
      and event.operation = 'cancelled'
  ),
  'cancelled:' || current_setting('kinflow.test.calendar_series_today')
    || ':184:1:3:3',
  'series cancellation records a content-free aggregate history event'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101', true
);
select is(
  (
    select pg_catalog.concat_ws(
      ':', result.version, result.cancelled_count,
      result.preserved_past_count, result.changed
    )
    from public.cancel_recurring_calendar_series(
      '45000000-0000-4000-8000-000000000200',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_series_id')::uuid, 2
    ) as result
  ),
  '3:184:3:f',
  'same cancellation key replays its original result'
);
select throws_ok(
  $$
    select * from public.update_recurring_calendar_series(
      '45000000-0000-4000-8000-000000000201',
      '20000000-0000-4000-8000-000000000101',
      current_setting('kinflow.test.calendar_series_id')::uuid, 3,
      'Ended edit', null, false,
      current_setting('kinflow.test.calendar_series_today')::date - 3,
      time '10:00', 30, null, 'Asia/Seoul', 'earlier',
      '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
      array['30000000-0000-4000-8000-000000000101'::uuid]
    )
  $$,
  'KFE03', 'calendar event not found or forbidden',
  'ended series rejects further whole-series edits'
);
reset role;
select is(
  (
    select pg_catalog.concat_ws(
      ':', pg_catalog.count(*),
      pg_catalog.count(*) filter (where operation = 'updated'),
      pg_catalog.count(*) filter (where operation = 'cancelled')
    )
    from public.event_series_change_events
    where series_id = current_setting('kinflow.test.calendar_series_id')::uuid
  ),
  '2:1:1',
  'update and cancellation replays create no duplicate history events'
);
select is(
  (
    select pg_catalog.count(*)
    from app_private.calendar_audit_events as audit
    where audit.series_id = current_setting(
        'kinflow.test.calendar_series_id'
      )::uuid
      and audit.action in (
        'calendar.series_updated', 'calendar.series_cancelled'
      )
  ),
  2::bigint,
  'whole-series commands emit one audit record per committed transition'
);
select throws_ok(
  format(
    'update public.event_series_change_events set rebuilt_count = 0 where series_id = %L',
    current_setting('kinflow.test.calendar_series_id')
  ),
  '55000', 'calendar series change events are immutable',
  'series change history rejects in-place mutation'
);

select * from finish();
rollback;
