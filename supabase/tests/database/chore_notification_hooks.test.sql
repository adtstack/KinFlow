begin;
set constraints all deferred;

select plan(79);

-- Exact private outbox, producer, resolver, and least-privilege contract.
select has_table(
  'app_private',
  'chore_notification_outbox',
  'private chore notification outbox exists'
);
select is(
  (
    select string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'chore_notification_outbox'
  ),
  'event_id,event_type,event_version,household_id,actor_user_id,actor_member_id,acting_member_id,aggregate_type,aggregate_id,aggregate_version,correlation_id,causation_id,payload,occurred_at,dispatched_at,attempts,next_attempt_at,last_error_code,processing_status,max_attempts,lease_owner,lease_token,lease_expires_at,dead_lettered_at,replay_count,audience_member_id,reminder_lead_minutes',
  'outbox exposes the exact internal envelope, leased state, audience, and reminder identity'
);
select has_trigger(
  'public',
  'chore_occurrences',
  'chore_occurrences_capture_notification_events',
  'every occurrence mutation has one notification producer trigger'
);
select ok(
  (
    select pg_get_triggerdef(pg_trigger.oid) like
      '%AFTER INSERT OR UPDATE ON public.chore_occurrences FOR EACH ROW%'
    from pg_trigger
    join pg_class on pg_class.oid = pg_trigger.tgrelid
    join pg_namespace on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'chore_occurrences'
      and pg_trigger.tgname =
        'chore_occurrences_capture_notification_events'
  ),
  'notification capture runs after the occurrence version trigger'
);
select has_function(
  'app_private',
  'capture_chore_notification_events',
  array[]::text[],
  'notification producer function exists'
);
select ok(
  (
    select pg_proc.prosecdef
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'app_private'
      and pg_proc.proname = 'capture_chore_notification_events'
  ),
  'producer is security-definer with an empty search path'
);
select has_function(
  'app_private',
  'resolve_chore_notification_event',
  array['uuid'],
  'latest-state notification resolver exists'
);
select ok(
  (
    select not pg_proc.prosecdef
      and pg_proc.provolatile = 's'
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'app_private'
      and pg_proc.proname = 'resolve_chore_notification_event'
  ),
  'resolver is an internal stable invoker function with empty search path'
);
select is(
  (
    select string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'app_private'
      and specific_name like 'resolve_chore_notification_event_%'
      and parameter_mode = 'OUT'
  ),
  'event_id,event_type,event_version,event_occurred_at,household_id,actor_member_id,occurrence_id,event_occurrence_version,current_occurrence_version,notification_category,subject_type,recipient_member_id,recipient_user_id,due_local_date,due_at,timezone,occurrence_status,is_current,should_create_intent,suppression_reason',
  'resolver exposes only the versioned routing and latest-state contract'
);
select ok(
  pg_get_indexdef(
    'app_private.chore_notification_outbox_pending_idx'::regclass
  ) like '%(next_attempt_at, occurred_at, event_id)%WHERE (dispatched_at IS NULL)%',
  'pending dispatcher index is bounded to undispatched events'
);
select ok(
  exists (
    select 1
    from pg_constraint
    join pg_class on pg_class.oid = pg_constraint.conrelid
    join pg_namespace on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'app_private'
      and pg_class.relname = 'chore_notification_outbox'
      and pg_constraint.contype = 'u'
      and pg_get_constraintdef(pg_constraint.oid) =
        'UNIQUE NULLS NOT DISTINCT (household_id, event_type, aggregate_id, aggregate_version, audience_member_id, causation_id, reminder_lead_minutes)'
  ),
  'aggregate version, Snooze causation, and reminder lead form the producer dedupe key'
);
select ok(
  (
    select pg_constraint.convalidated
      and pg_get_constraintdef(pg_constraint.oid) like '%dueLocalDate%'
      and pg_get_constraintdef(pg_constraint.oid) like '%assigneeMemberId%'
    from pg_constraint
    join pg_class on pg_class.oid = pg_constraint.conrelid
    join pg_namespace on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'app_private'
      and pg_class.relname = 'chore_notification_outbox'
      and pg_constraint.conname = 'notification_source_payload_ck'
  ),
  'payload constraint is validated and binds both exact version-one shapes'
);
select ok(
  not has_table_privilege(
    'anon',
    'app_private.chore_notification_outbox',
    'select,insert,update,delete'
  ),
  'anonymous clients have no outbox table privilege'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.chore_notification_outbox',
    'select,insert,update,delete'
  ),
  'authenticated clients have no outbox table privilege'
);
select ok(
  not has_table_privilege(
    'service_role',
    'app_private.chore_notification_outbox',
    'select,insert,update,delete'
  ),
  'service role receives no premature direct outbox privilege'
);
select ok(
  not has_function_privilege(
    'anon',
    'app_private.resolve_chore_notification_event(uuid)',
    'execute'
  )
    and not has_function_privilege(
      'authenticated',
      'app_private.resolve_chore_notification_event(uuid)',
      'execute'
    )
    and not has_function_privilege(
      'service_role',
      'app_private.resolve_chore_notification_event(uuid)',
      'execute'
    ),
  'resolver is not an API or direct worker surface'
);
select ok(
  not has_function_privilege(
    'anon',
    'app_private.capture_chore_notification_events()',
    'execute'
  )
    and not has_function_privilege(
      'authenticated',
      'app_private.capture_chore_notification_events()',
      'execute'
    )
    and not has_function_privilege(
      'service_role',
      'app_private.capture_chore_notification_events()',
      'execute'
    ),
  'producer cannot be invoked outside its trigger'
);
select hasnt_column(
  'app_private',
  'chore_notification_outbox',
  'title',
  'outbox does not snapshot a chore title'
);
select hasnt_column(
  'app_private',
  'chore_notification_outbox',
  'description',
  'outbox does not snapshot chore notes'
);
select hasnt_column(
  'app_private',
  'chore_notification_outbox',
  'display_name',
  'outbox does not snapshot a member display name'
);
select hasnt_column(
  'app_private',
  'chore_notification_outbox',
  'email',
  'outbox does not store email'
);
select hasnt_column(
  'app_private',
  'chore_notification_outbox',
  'token',
  'outbox does not store a provider token'
);

-- Authenticated create paths cover one-time, all-day, and materialized rows.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '47000000-0000-4000-8000-000000000701',
      '20000000-0000-4000-8000-000000000101',
      'Notification hook timed',
      'Must never enter an event payload',
      '30000000-0000-4000-8000-000000000102',
      (statement_timestamp() at time zone 'Asia/Seoul')::date + 1,
      time '09:15'
    )
  $$,
  'timed one-time creation commits its notification hooks'
);
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '47000000-0000-4000-8000-000000000702',
      '20000000-0000-4000-8000-000000000101',
      'Notification hook all day',
      null,
      '30000000-0000-4000-8000-000000000102',
      (statement_timestamp() at time zone 'Asia/Seoul')::date + 2,
      null
    )
  $$,
  'all-day creation records an unresolved due hook without inventing time'
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '47000000-0000-4000-8000-000000000703',
      '20000000-0000-4000-8000-000000000101',
      'Notification hook mutation',
      null,
      '30000000-0000-4000-8000-000000000102',
      (statement_timestamp() at time zone 'Asia/Seoul')::date + 3,
      time '10:00',
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
    )
  $$,
  'repeating materialization records hooks for its occurrence'
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '47000000-0000-4000-8000-000000000704',
      '20000000-0000-4000-8000-000000000101',
      'Notification hook skip restore',
      null,
      '30000000-0000-4000-8000-000000000101',
      (statement_timestamp() at time zone 'Asia/Seoul')::date,
      time '11:00',
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":1}}'
    )
  $$,
  'skip and restore fixture starts with one materialized occurrence'
);
select lives_ok(
  $$
    select * from public.create_repeating_chore(
      '47000000-0000-4000-8000-000000000705',
      '20000000-0000-4000-8000-000000000101',
      'Notification hook series cancel',
      null,
      '30000000-0000-4000-8000-000000000101',
      (statement_timestamp() at time zone 'Asia/Seoul')::date,
      time '12:00',
      '{"frequency":"daily","interval":1,"end":{"type":"count","count":2}}'
    )
  $$,
  'series cancellation fixture starts with two materialized occurrences'
);
reset role;

select set_config(
  'kinflow.test.notification_cancel_series_id',
  (
    select series.id::text
    from public.chore_series as series
    where series.title = 'Notification hook series cancel'
  ),
  true
);

select is(
  (
    select count(*)
    from app_private.chore_notification_outbox as event
    join public.chore_occurrences as occurrence
      on occurrence.id = event.aggregate_id
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Notification hook timed'
  ),
  2::bigint,
  'one occurrence insert atomically emits due and assignment events'
);
select is(
  (
    select string_agg(event.event_type, ',' order by event.event_type)
    from app_private.chore_notification_outbox as event
    join public.chore_occurrences as occurrence
      on occurrence.id = event.aggregate_id
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Notification hook timed'
  ),
  'chore.occurrence_assigned,chore.occurrence_due_changed',
  'insert event vocabulary is exact'
);
select ok(
  (
    select bool_and(
      event.event_version = 1
      and event.aggregate_type = 'chore_occurrence'
      and event.aggregate_version = occurrence.version
      and event.occurred_at is not null
    )
    from app_private.chore_notification_outbox as event
    join public.chore_occurrences as occurrence
      on occurrence.id = event.aggregate_id
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Notification hook timed'
  ),
  'insert events bind version-one envelopes to occurrence version one'
);
select is(
  (
    select count(distinct event.correlation_id)
    from app_private.chore_notification_outbox as event
    join public.chore_occurrences as occurrence
      on occurrence.id = event.aggregate_id
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Notification hook timed'
  ),
  1::bigint,
  'events from one row change share one correlation ID'
);
select ok(
  (
    select bool_and(
      event.actor_user_id =
        '00000000-0000-4000-8000-000000000101'::uuid
      and event.actor_member_id =
        '30000000-0000-4000-8000-000000000101'::uuid
      and event.acting_member_id is null
      and event.causation_id is null
    )
    from app_private.chore_notification_outbox as event
    join public.chore_occurrences as occurrence
      on occurrence.id = event.aggregate_id
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Notification hook timed'
  ),
  'authenticated mutation records only its active adult actor pair'
);
select ok(
  (
    select event.payload ?& array[
      'dueLocalDate', 'dueAt', 'timezone', 'status'
    ]
      and event.payload - array[
        'dueLocalDate', 'dueAt', 'timezone', 'status'
      ] = '{}'::jsonb
      and jsonb_typeof(event.payload->'dueAt') = 'string'
      and event.payload->>'timezone' = 'Asia/Seoul'
      and event.payload->>'status' = 'scheduled'
    from app_private.chore_notification_outbox as event
    join public.chore_occurrences as occurrence
      on occurrence.id = event.aggregate_id
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Notification hook timed'
      and event.event_type = 'chore.occurrence_due_changed'
  ),
  'timed due payload has only exact schedule and state keys'
);
select ok(
  (
    select event.payload = jsonb_build_object(
      'assigneeMemberId',
      '30000000-0000-4000-8000-000000000102'::uuid,
      'status',
      'scheduled'
    )
    from app_private.chore_notification_outbox as event
    join public.chore_occurrences as occurrence
      on occurrence.id = event.aggregate_id
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Notification hook timed'
      and event.event_type = 'chore.occurrence_assigned'
  ),
  'assignment payload has only recipient member and state'
);
select ok(
  not exists (
    select 1
    from app_private.chore_notification_outbox as event
    where event.payload::text ~*
      '(title|description|display.?name|email|token|auth.?user|raw.?error)'
  ),
  'every payload excludes free-form content, identity, token, and raw error keys'
);

set local role authenticated;
select lives_ok(
  $$
    select * from public.create_one_time_chore(
      '47000000-0000-4000-8000-000000000701',
      '20000000-0000-4000-8000-000000000101',
      'Notification hook timed',
      'Must never enter an event payload',
      '30000000-0000-4000-8000-000000000102',
      (statement_timestamp() at time zone 'Asia/Seoul')::date + 1,
      time '09:15'
    )
  $$,
  'idempotent create replay succeeds without a second mutation'
);
reset role;
select is(
  (
    select count(*)
    from app_private.chore_notification_outbox as event
    join public.chore_occurrences as occurrence
      on occurrence.id = event.aggregate_id
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Notification hook timed'
  ),
  2::bigint,
  'create replay produces no duplicate events'
);
select is(
  (
    select concat_ws(
      ':',
      notification_category,
      subject_type,
      recipient_member_id,
      recipient_user_id,
      occurrence_status,
      is_current,
      should_create_intent,
      coalesce(suppression_reason, 'none')
    )
    from app_private.resolve_chore_notification_event(
      (
        select event.event_id
        from app_private.chore_notification_outbox as event
        join public.chore_occurrences as occurrence
          on occurrence.id = event.aggregate_id
        join public.chore_series as series
          on series.id = occurrence.series_id
        where series.title = 'Notification hook timed'
          and event.event_type = 'chore.occurrence_due_changed'
      )
    )
  ),
  'chore_due:chore_occurrence:30000000-0000-4000-8000-000000000102:00000000-0000-4000-8000-000000000102:scheduled:t:t:none',
  'due resolver selects the latest active assignee without content'
);
select is(
  (
    select concat_ws(
      ':', notification_category, recipient_member_id,
      recipient_user_id, is_current, should_create_intent,
      coalesce(suppression_reason, 'none')
    )
    from app_private.resolve_chore_notification_event(
      (
        select event.event_id
        from app_private.chore_notification_outbox as event
        join public.chore_occurrences as occurrence
          on occurrence.id = event.aggregate_id
        join public.chore_series as series
          on series.id = occurrence.series_id
        where series.title = 'Notification hook timed'
          and event.event_type = 'chore.occurrence_assigned'
      )
    )
  ),
  'chore_assignment:30000000-0000-4000-8000-000000000102:00000000-0000-4000-8000-000000000102:t:t:none',
  'assignment resolver selects the event assignee when still current'
);
select is(
  (
    select concat_ws(
      ':', is_current, should_create_intent,
      coalesce(suppression_reason, 'none')
    )
    from app_private.resolve_chore_notification_event(
      (
        select event.event_id
        from app_private.chore_notification_outbox as event
        join public.chore_occurrences as occurrence
          on occurrence.id = event.aggregate_id
        join public.chore_series as series
          on series.id = occurrence.series_id
        where series.title = 'Notification hook all day'
          and event.event_type = 'chore.occurrence_due_changed'
      )
    )
  ),
  't:f:schedule_unresolved',
  'all-day due remains current but cannot invent a reminder instant'
);
select is(
  (
    select concat_ws(
      ':', is_current, should_create_intent,
      coalesce(suppression_reason, 'none')
    )
    from app_private.resolve_chore_notification_event(
      (
        select event.event_id
        from app_private.chore_notification_outbox as event
        join public.chore_occurrences as occurrence
          on occurrence.id = event.aggregate_id
        join public.chore_series as series
          on series.id = occurrence.series_id
        where series.title = 'Notification hook all day'
          and event.event_type = 'chore.occurrence_assigned'
      )
    )
  ),
  't:t:none',
  'all-day schedule does not suppress a current assignment intent'
);

-- Due and assignment changes remain independently current across versions.
set local role authenticated;
select lives_ok(
  $$
    select * from public.reschedule_chore_occurrence(
      '47000000-0000-4000-8000-000000000711',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Notification hook mutation'
      ),
      1,
      (statement_timestamp() at time zone 'Asia/Seoul')::date + 4,
      time '08:30'
    )
  $$,
  'single-occurrence reschedule commits a due-change hook'
);
reset role;
select is(
  (
    select concat_ws(
      ':',
      count(*) filter (
        where event.event_type = 'chore.occurrence_due_changed'
      ),
      count(*) filter (
        where event.event_type = 'chore.occurrence_assigned'
      ),
      max(event.aggregate_version)
    )
    from app_private.chore_notification_outbox as event
    join public.chore_occurrences as occurrence
      on occurrence.id = event.aggregate_id
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Notification hook mutation'
  ),
  '2:1:2',
  'reschedule adds only a version-two due event'
);
select is(
  (
    select concat_ws(
      ':', is_current, should_create_intent,
      coalesce(suppression_reason, 'none')
    )
    from app_private.resolve_chore_notification_event(
      (
        select event.event_id
        from app_private.chore_notification_outbox as event
        join public.chore_occurrences as occurrence
          on occurrence.id = event.aggregate_id
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Notification hook mutation'
          and event.event_type = 'chore.occurrence_due_changed'
        order by event.aggregate_version
        limit 1
      )
    )
  ),
  'f:f:stale_event',
  'older due event becomes stale after reschedule'
);
select is(
  (
    select concat_ws(
      ':', recipient_member_id, is_current, should_create_intent,
      coalesce(suppression_reason, 'none')
    )
    from app_private.resolve_chore_notification_event(
      (
        select event.event_id
        from app_private.chore_notification_outbox as event
        join public.chore_occurrences as occurrence
          on occurrence.id = event.aggregate_id
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Notification hook mutation'
          and event.event_type = 'chore.occurrence_due_changed'
        order by event.aggregate_version desc
        limit 1
      )
    )
  ),
  '30000000-0000-4000-8000-000000000102:t:t:none',
  'new due event is current and resolves the current assignee'
);
select is(
  (
    select concat_ws(
      ':', is_current, should_create_intent,
      coalesce(suppression_reason, 'none')
    )
    from app_private.resolve_chore_notification_event(
      (
        select event.event_id
        from app_private.chore_notification_outbox as event
        join public.chore_occurrences as occurrence
          on occurrence.id = event.aggregate_id
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Notification hook mutation'
          and event.event_type = 'chore.occurrence_assigned'
      )
    )
  ),
  't:t:none',
  'assignment remains current after an unrelated due version change'
);

set local role authenticated;
select lives_ok(
  $$
    select * from public.reassign_chore_occurrence(
      '47000000-0000-4000-8000-000000000712',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Notification hook mutation'
      ),
      2,
      '30000000-0000-4000-8000-000000000101'
    )
  $$,
  'single-occurrence reassign commits an assignment hook'
);
reset role;
select is(
  (
    select concat_ws(
      ':',
      count(*) filter (
        where event.event_type = 'chore.occurrence_due_changed'
      ),
      count(*) filter (
        where event.event_type = 'chore.occurrence_assigned'
      ),
      max(event.aggregate_version)
    )
    from app_private.chore_notification_outbox as event
    join public.chore_occurrences as occurrence
      on occurrence.id = event.aggregate_id
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Notification hook mutation'
  ),
  '3:2:3',
  'reassign adds version-three assignment and due-recipient events'
);
select is(
  (
    select concat_ws(
      ':', is_current, should_create_intent,
      coalesce(suppression_reason, 'none')
    )
    from app_private.resolve_chore_notification_event(
      (
        select event.event_id
        from app_private.chore_notification_outbox as event
        join public.chore_occurrences as occurrence
          on occurrence.id = event.aggregate_id
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Notification hook mutation'
          and event.event_type = 'chore.occurrence_assigned'
        order by event.aggregate_version
        limit 1
      )
    )
  ),
  'f:f:stale_event',
  'previous assignment event becomes stale after reassignment'
);
select is(
  (
    select concat_ws(
      ':', recipient_member_id, recipient_user_id,
      is_current, should_create_intent,
      coalesce(suppression_reason, 'none')
    )
    from app_private.resolve_chore_notification_event(
      (
        select event.event_id
        from app_private.chore_notification_outbox as event
        join public.chore_occurrences as occurrence
          on occurrence.id = event.aggregate_id
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Notification hook mutation'
          and event.event_type = 'chore.occurrence_assigned'
        order by event.aggregate_version desc
        limit 1
      )
    )
  ),
  '30000000-0000-4000-8000-000000000101:00000000-0000-4000-8000-000000000101:t:t:none',
  'new assignment event resolves the new active recipient'
);
select is(
  (
    select concat_ws(
      ':', recipient_member_id, is_current, should_create_intent
    )
    from app_private.resolve_chore_notification_event(
      (
        select event.event_id
        from app_private.chore_notification_outbox as event
        join public.chore_occurrences as occurrence
          on occurrence.id = event.aggregate_id
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Notification hook mutation'
          and event.event_type = 'chore.occurrence_due_changed'
        order by event.aggregate_version desc
        limit 1
      )
    )
  ),
  '30000000-0000-4000-8000-000000000101:t:t',
  'still-current due event routes to the latest assignee'
);

set local role authenticated;
select lives_ok(
  $$
    select * from public.reassign_chore_occurrence(
      '47000000-0000-4000-8000-000000000712',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Notification hook mutation'
      ),
      2,
      '30000000-0000-4000-8000-000000000101'
    )
  $$,
  'idempotent reassignment replay returns its stored result'
);
reset role;
select is(
  (
    select count(*)
    from app_private.chore_notification_outbox as event
    join public.chore_occurrences as occurrence
      on occurrence.id = event.aggregate_id
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Notification hook mutation'
  ),
  5::bigint,
  'reassignment replay adds no duplicate event'
);

set local role authenticated;
select lives_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '47000000-0000-4000-8000-000000000713',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Notification hook mutation'
      ),
      3,
      true
    )
  $$,
  'completion commits a due reconciliation event'
);
reset role;
select is(
  (
    select concat_ws(
      ':', occurrence_status, is_current, should_create_intent,
      coalesce(suppression_reason, 'none')
    )
    from app_private.resolve_chore_notification_event(
      (
        select event.event_id
        from app_private.chore_notification_outbox as event
        join public.chore_occurrences as occurrence
          on occurrence.id = event.aggregate_id
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Notification hook mutation'
          and event.event_type = 'chore.occurrence_due_changed'
        order by event.aggregate_version desc
        limit 1
      )
    )
  ),
  'completed:t:f:occurrence_not_scheduled',
  'completion event is current but suppresses a new intent'
);
select is(
  (
    select concat_ws(
      ':', is_current, coalesce(suppression_reason, 'none')
    )
    from app_private.resolve_chore_notification_event(
      (
        select event.event_id
        from app_private.chore_notification_outbox as event
        join public.chore_occurrences as occurrence
          on occurrence.id = event.aggregate_id
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Notification hook mutation'
          and event.event_type = 'chore.occurrence_due_changed'
          and event.aggregate_version = 2
      )
    )
  ),
  'f:stale_event',
  'previous scheduled due event becomes stale after completion'
);
select is(
  (
    select concat_ws(
      ':', is_current, coalesce(suppression_reason, 'none')
    )
    from app_private.resolve_chore_notification_event(
      (
        select event.event_id
        from app_private.chore_notification_outbox as event
        join public.chore_occurrences as occurrence
          on occurrence.id = event.aggregate_id
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Notification hook mutation'
          and event.event_type = 'chore.occurrence_assigned'
          and event.aggregate_version = 3
      )
    )
  ),
  'f:stale_event',
  'scheduled assignment event becomes stale after completion'
);

set local role authenticated;
select lives_ok(
  $$
    select * from public.set_chore_occurrence_completion(
      '47000000-0000-4000-8000-000000000714',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Notification hook mutation'
      ),
      4,
      false
    )
  $$,
  'reopen commits a fresh due reconciliation event'
);
reset role;
select is(
  (
    select concat_ws(
      ':', occurrence_status, is_current, should_create_intent,
      coalesce(suppression_reason, 'none')
    )
    from app_private.resolve_chore_notification_event(
      (
        select event.event_id
        from app_private.chore_notification_outbox as event
        join public.chore_occurrences as occurrence
          on occurrence.id = event.aggregate_id
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Notification hook mutation'
          and event.event_type = 'chore.occurrence_due_changed'
        order by event.aggregate_version desc
        limit 1
      )
    )
  ),
  'scheduled:t:t:none',
  'reopened latest state is eligible for a new intent evaluation'
);
select is(
  (
    select concat_ws(
      ':',
      count(*) filter (where resolved.is_current),
      max(event.aggregate_version) filter (where resolved.is_current)
    )
    from app_private.chore_notification_outbox as event
    join public.chore_occurrences as occurrence
      on occurrence.id = event.aggregate_id
    join public.chore_series as series on series.id = occurrence.series_id
    cross join lateral app_private.resolve_chore_notification_event(
      event.event_id
    ) as resolved
    where series.title = 'Notification hook mutation'
      and event.event_type = 'chore.occurrence_due_changed'
  ),
  '1:5',
  'reopen cannot revive an older due event with the same payload'
);
select is(
  (
    select count(*)
    from app_private.chore_notification_outbox as event
    join public.chore_occurrences as occurrence
      on occurrence.id = event.aggregate_id
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Notification hook mutation'
      and event.event_type = 'chore.occurrence_assigned'
  ),
  2::bigint,
  'completion and reopen do not fabricate assignment events'
);

-- Skip/restore and whole-series cancellation feed the same due contract.
set local role authenticated;
select lives_ok(
  $$
    select * from public.skip_chore_occurrence(
      '47000000-0000-4000-8000-000000000721',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Notification hook skip restore'
      ),
      1
    )
  $$,
  'skip commits a due reconciliation event'
);
reset role;
select is(
  (
    select concat_ws(
      ':', occurrence_status, is_current, should_create_intent,
      coalesce(suppression_reason, 'none')
    )
    from app_private.resolve_chore_notification_event(
      (
        select event.event_id
        from app_private.chore_notification_outbox as event
        join public.chore_occurrences as occurrence
          on occurrence.id = event.aggregate_id
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Notification hook skip restore'
          and event.event_type = 'chore.occurrence_due_changed'
        order by event.aggregate_version desc
        limit 1
      )
    )
  ),
  'skipped:t:f:occurrence_not_scheduled',
  'skipped latest state suppresses intent creation'
);

set local role authenticated;
select lives_ok(
  $$
    select * from public.restore_skipped_chore_occurrence(
      '47000000-0000-4000-8000-000000000722',
      '20000000-0000-4000-8000-000000000101',
      (
        select occurrence.id
        from public.chore_occurrences as occurrence
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Notification hook skip restore'
      ),
      2
    )
  $$,
  'restore commits a fresh due reconciliation event'
);
reset role;
select is(
  (
    select concat_ws(
      ':', occurrence_status, is_current, should_create_intent,
      coalesce(suppression_reason, 'none')
    )
    from app_private.resolve_chore_notification_event(
      (
        select event.event_id
        from app_private.chore_notification_outbox as event
        join public.chore_occurrences as occurrence
          on occurrence.id = event.aggregate_id
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Notification hook skip restore'
          and event.event_type = 'chore.occurrence_due_changed'
        order by event.aggregate_version desc
        limit 1
      )
    )
  ),
  'scheduled:t:t:none',
  'restored latest state is eligible again'
);
select is(
  (
    select concat_ws(
      ':',
      count(*) filter (where resolved.is_current),
      max(event.aggregate_version) filter (where resolved.is_current)
    )
    from app_private.chore_notification_outbox as event
    join public.chore_occurrences as occurrence
      on occurrence.id = event.aggregate_id
    join public.chore_series as series on series.id = occurrence.series_id
    cross join lateral app_private.resolve_chore_notification_event(
      event.event_id
    ) as resolved
    where series.title = 'Notification hook skip restore'
      and event.event_type = 'chore.occurrence_due_changed'
  ),
  '1:3',
  'restore cannot revive a pre-skip due event with the same payload'
);
select is(
  (
    select concat_ws(
      ':',
      count(*) filter (
        where event.event_type = 'chore.occurrence_due_changed'
      ),
      count(*) filter (
        where event.event_type = 'chore.occurrence_assigned'
      )
    )
    from app_private.chore_notification_outbox as event
    join public.chore_occurrences as occurrence
      on occurrence.id = event.aggregate_id
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Notification hook skip restore'
  ),
  '3:1',
  'insert, skip, and restore produce exactly three due and one assignment events'
);

set local role authenticated;
select lives_ok(
  $$
    select * from public.cancel_repeating_chore_series(
      '47000000-0000-4000-8000-000000000723',
      '20000000-0000-4000-8000-000000000101',
      current_setting(
        'kinflow.test.notification_cancel_series_id'
      )::uuid,
      1
    )
  $$,
  'whole-series cancellation reconciles every future occurrence'
);
reset role;
select is(
  (
    select concat_ws(
      ':',
      count(*) filter (
        where event.event_type = 'chore.occurrence_due_changed'
      ),
      count(*) filter (
        where event.event_type = 'chore.occurrence_assigned'
      )
    )
    from app_private.chore_notification_outbox as event
    join public.chore_occurrences as occurrence
      on occurrence.id = event.aggregate_id
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Notification hook series cancel'
  ),
  '4:2',
  'two cancelled occurrences each add one due event and no assignment event'
);
select ok(
  (
    select bool_and(
      not resolved.should_create_intent
      and resolved.suppression_reason = 'inactive_series'
    )
    from app_private.chore_notification_outbox as event
    join public.chore_occurrences as occurrence
      on occurrence.id = event.aggregate_id
    join public.chore_series as series on series.id = occurrence.series_id
    cross join lateral app_private.resolve_chore_notification_event(
      event.event_id
    ) as resolved
    where series.title = 'Notification hook series cancel'
      and event.event_type = 'chore.occurrence_due_changed'
      and event.aggregate_version = occurrence.version
  ),
  'latest cancelled-series events are suppressed by current series state'
);

set local role authenticated;
select lives_ok(
  $$
    select * from public.cancel_repeating_chore_series(
      '47000000-0000-4000-8000-000000000723',
      '20000000-0000-4000-8000-000000000101',
      current_setting(
        'kinflow.test.notification_cancel_series_id'
      )::uuid,
      1
    )
  $$,
  'series cancellation replay returns its stored result'
);
reset role;
select is(
  (
    select count(*)
    from app_private.chore_notification_outbox as event
    join public.chore_occurrences as occurrence
      on occurrence.id = event.aggregate_id
    join public.chore_series as series on series.id = occurrence.series_id
    where series.title = 'Notification hook series cancel'
  ),
  6::bigint,
  'series cancellation replay produces no duplicate events'
);

-- Trusted inserts without a JWT keep the actor nullable.
reset request.jwt.claim.sub;
insert into public.chore_series (
  id,
  household_id,
  title,
  timezone,
  active_revision_id
)
values (
  '4f700000-0000-4000-8000-000000000701',
  '20000000-0000-4000-8000-000000000101',
  'Notification hook trusted materializer',
  'Asia/Seoul',
  '4f710000-0000-4000-8000-000000000701'
);
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
values (
  '4f710000-0000-4000-8000-000000000701',
  '20000000-0000-4000-8000-000000000101',
  '4f700000-0000-4000-8000-000000000701',
  1,
  (statement_timestamp() at time zone 'Asia/Seoul')::date + 5,
  time '07:00',
  '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
  '30000000-0000-4000-8000-000000000101'
);
insert into public.chore_occurrences (
  id,
  household_id,
  series_id,
  revision_id,
  occurrence_key,
  due_local_date,
  due_at,
  timezone,
  assignee_member_id
)
values (
  '5f700000-0000-4000-8000-000000000701',
  '20000000-0000-4000-8000-000000000101',
  '4f700000-0000-4000-8000-000000000701',
  '4f710000-0000-4000-8000-000000000701',
  '4f700000-0000-4000-8000-000000000701:' ||
    (
      (statement_timestamp() at time zone 'Asia/Seoul')::date + 5
    )::text,
  (statement_timestamp() at time zone 'Asia/Seoul')::date + 5,
  (
    (
      (statement_timestamp() at time zone 'Asia/Seoul')::date + 5
    )::timestamp + time '07:00'
  ) at time zone 'Asia/Seoul',
  'Asia/Seoul',
  '30000000-0000-4000-8000-000000000101'
);
select is(
  (
    select count(*)
    from app_private.chore_notification_outbox
    where aggregate_id = '5f700000-0000-4000-8000-000000000701'
      and actor_user_id is null
      and actor_member_id is null
  ),
  2::bigint,
  'trusted materialization without JWT records two actor-null events'
);

-- Envelope protection, payload schema, and current recipient suppression.
select throws_ok(
  $$
    update app_private.chore_notification_outbox
    set attempts = attempts + 1,
        next_attempt_at = statement_timestamp() + interval '1 minute',
        last_error_code = 'TRANSIENT_FAILURE'
    where event_id = (
      select event.event_id
      from app_private.chore_notification_outbox as event
      join public.chore_occurrences as occurrence
        on occurrence.id = event.aggregate_id
      join public.chore_series as series on series.id = occurrence.series_id
      where series.title = 'Notification hook timed'
      order by event.event_type
      limit 1
    )
  $$,
  '23514',
  'new row for relation "chore_notification_outbox" violates check constraint "chore_notification_outbox_worker_state_ck"',
  'legacy partial dispatcher updates cannot bypass the leased lifecycle'
);
select throws_ok(
  $$
    update app_private.chore_notification_outbox
    set payload = payload || '{"title":"forbidden"}'::jsonb
    where event_id = (
      select event.event_id
      from app_private.chore_notification_outbox as event
      join public.chore_occurrences as occurrence
        on occurrence.id = event.aggregate_id
      join public.chore_series as series on series.id = occurrence.series_id
      where series.title = 'Notification hook timed'
      order by event.event_type
      limit 1
    )
  $$,
  '55000',
  'notification source transition is invalid',
  'dispatcher cannot mutate event payload content'
);
select throws_ok(
  $$
    insert into app_private.chore_notification_outbox (
      event_type,
      household_id,
      aggregate_id,
      aggregate_version,
      audience_member_id,
      payload
    )
    values (
      'chore.occurrence_due_changed',
      '20000000-0000-4000-8000-000000000101',
      '5f700000-0000-4000-8000-000000000701',
      99,
      '30000000-0000-4000-8000-000000000102',
      jsonb_build_object(
        'dueLocalDate', '2026-08-12',
        'dueAt', '2026-08-11T22:00:00Z',
        'timezone', 'Asia/Seoul',
        'status', 'scheduled',
        'title', 'forbidden'
      )
    )
  $$,
  '23514',
  'new row for relation "chore_notification_outbox" violates check constraint "notification_source_payload_ck"',
  'exact payload constraint rejects additional content keys'
);

update public.household_members
set removed_at = statement_timestamp()
where household_id = '20000000-0000-4000-8000-000000000101'
  and id = '30000000-0000-4000-8000-000000000102';
select is(
  (
    select concat_ws(
      ':', is_current, should_create_intent,
      coalesce(suppression_reason, 'none')
    )
    from app_private.resolve_chore_notification_event(
      (
        select event.event_id
        from app_private.chore_notification_outbox as event
        join public.chore_occurrences as occurrence
          on occurrence.id = event.aggregate_id
        join public.chore_series as series on series.id = occurrence.series_id
        where series.title = 'Notification hook all day'
          and event.event_type = 'chore.occurrence_assigned'
      )
    )
  ),
  't:f:inactive_recipient',
  'removed recipient suppresses an otherwise-current assignment event'
);

set local role authenticated;
select throws_ok(
  $$select count(*) from app_private.chore_notification_outbox$$,
  '42501',
  'permission denied for table chore_notification_outbox',
  'authenticated client cannot inspect private event rows'
);
reset role;
set local role service_role;
select throws_ok(
  $$
    select * from app_private.resolve_chore_notification_event(
      '00000000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'permission denied for schema app_private',
  'service role cannot enter the future mediated worker boundary'
);
reset role;

select * from finish();
rollback;
