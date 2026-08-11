begin;
set constraints all deferred;

select plan(86);

-- Exact schema, mediated API, and least-privilege worker boundary.
select has_table(
  'app_private',
  'notification_event_resolutions',
  'durable notification resolution table exists'
);
select has_table(
  'app_private',
  'notification_worker_transitions',
  'immutable notification transition audit exists'
);
select has_table(
  'app_private',
  'notification_worker_control',
  'server worker pause control exists'
);

select has_function(
  'public',
  'claim_chore_notification_events',
  array['uuid', 'integer', 'integer', 'timestamp with time zone'],
  'bounded lease claim API exists'
);
select has_function(
  'public',
  'heartbeat_chore_notification_event',
  array['uuid', 'uuid', 'integer', 'timestamp with time zone'],
  'lease heartbeat API exists'
);
select has_function(
  'public',
  'process_chore_notification_event',
  array['uuid', 'uuid', 'timestamp with time zone'],
  'latest-state process API exists'
);
select has_function(
  'public',
  'fail_chore_notification_event',
  array['uuid', 'uuid', 'text', 'timestamp with time zone'],
  'bounded failure API exists'
);
select has_function(
  'public',
  'replay_chore_notification_dead_letter',
  array['uuid', 'text', 'timestamp with time zone'],
  'manual dead-letter replay API exists'
);
select has_function(
  'public',
  'set_chore_notification_worker_paused',
  array['boolean', 'text', 'timestamp with time zone'],
  'worker pause control API exists'
);
select has_function(
  'public',
  'get_chore_notification_queue_health',
  array['timestamp with time zone'],
  'aggregate queue health API exists'
);

select ok(
  not exists (
    select 1
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname in (
        'claim_chore_notification_events',
        'heartbeat_chore_notification_event',
        'process_chore_notification_event',
        'fail_chore_notification_event',
        'replay_chore_notification_dead_letter',
        'set_chore_notification_worker_paused',
        'get_chore_notification_queue_health'
      )
      and (
        not pg_proc.prosecdef
        or not pg_proc.proconfig @> array['search_path=""']::text[]
      )
  ),
  'every public worker API is security-definer with an empty search path'
);
select ok(
  (
    select pg_proc.provolatile = 's'
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'get_chore_notification_queue_health'
  ),
  'queue health is a stable read-only aggregate'
);
select ok(
  pg_get_functiondef(
    'app_private.claim_notification_events_wp05_07_legacy(uuid,integer,integer,timestamptz)'::regprocedure
  ) ilike '%for update skip locked%',
  'claim uses row locking with SKIP LOCKED for competing workers'
);
select is(
  (
    select string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'notification_event_resolutions'
  ),
  'source_event_id,outcome,household_id,notification_category,subject_type,subject_id,recipient_member_id,recipient_user_id,scheduled_at,timezone,suppression_reason,resolved_at,audience_member_id',
  'resolution stores only routing IDs, schedule, timezone, and allowlisted outcome'
);
select is(
  (
    select string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'notification_worker_transitions'
  ),
  'id,source_event_id,transition,worker_id,attempt,error_code,occurred_at',
  'transition audit is content-free and operational only'
);
select is(
  (
    select string_agg(column_name, ',' order by ordinal_position)
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'notification_worker_control'
  ),
  'worker_key,paused,reason_code,updated_at',
  'pause control stores only a stable reason and timestamp'
);
select has_trigger(
  'app_private',
  'notification_worker_transitions',
  'notification_worker_transitions_immutable',
  'transition audit has an immutable trigger'
);
select ok(
  pg_get_indexdef(
    'app_private.chore_notification_outbox_worker_ready_idx'::regclass
  ) like '%processing_status%next_attempt_at%lease_expires_at%occurred_at%event_id%'
    and pg_get_indexdef(
      'app_private.chore_notification_outbox_worker_ready_idx'::regclass
    ) like '%pending%retry_wait%leased%',
  'ready index covers bounded lifecycle selection and ordering'
);
select is(
  (
    select string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name like 'claim_chore_notification_events_%'
      and parameter_mode = 'OUT'
  ),
  'event_id,lease_token,attempt,max_attempts,lease_expires_at',
  'claim response exposes no event content or household identity'
);
select is(
  (
    select string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name like 'process_chore_notification_event_%'
      and parameter_mode = 'OUT'
  ),
  'source_event_id,outcome,notification_category,subject_type,subject_id,recipient_member_id,recipient_user_id,scheduled_at,timezone,suppression_reason,resolved_at',
  'process response is the exact content-free candidate contract'
);
select is(
  (
    select string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name like 'fail_chore_notification_event_%'
      and parameter_mode = 'OUT'
  ),
  'event_id,processing_status,attempts,max_attempts,next_attempt_at,dead_lettered_at',
  'failure response exposes only lifecycle state'
);
select is(
  (
    select string_agg(parameter_name, ',' order by ordinal_position)
    from information_schema.parameters
    where specific_schema = 'public'
      and specific_name like 'get_chore_notification_queue_health_%'
      and parameter_mode = 'OUT'
  ),
  'captured_at,paused,pause_reason_code,pending_count,leased_count,retry_wait_count,succeeded_count,dead_letter_count,ready_count,expired_lease_count,oldest_ready_at,next_retry_at',
  'health response is aggregate-only and contains no event or household IDs'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.claim_chore_notification_events(uuid,integer,integer,timestamptz)',
    'execute'
  )
    and has_function_privilege(
      'service_role',
      'public.heartbeat_chore_notification_event(uuid,uuid,integer,timestamptz)',
      'execute'
    )
    and has_function_privilege(
      'service_role',
      'public.process_chore_notification_event(uuid,uuid,timestamptz)',
      'execute'
    )
    and has_function_privilege(
      'service_role',
      'public.fail_chore_notification_event(uuid,uuid,text,timestamptz)',
      'execute'
    )
    and has_function_privilege(
      'service_role',
      'public.replay_chore_notification_dead_letter(uuid,text,timestamptz)',
      'execute'
    )
    and has_function_privilege(
      'service_role',
      'public.set_chore_notification_worker_paused(boolean,text,timestamptz)',
      'execute'
    )
    and has_function_privilege(
      'service_role',
      'public.get_chore_notification_queue_health(timestamptz)',
      'execute'
    ),
  'service role can execute every mediated worker API'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.claim_chore_notification_events(uuid,integer,integer,timestamptz)',
    'execute'
  )
    and not has_function_privilege(
      'authenticated',
      'public.get_chore_notification_queue_health(timestamptz)',
      'execute'
    )
    and not has_function_privilege(
      'anon',
      'public.claim_chore_notification_events(uuid,integer,integer,timestamptz)',
      'execute'
    )
    and not has_function_privilege(
      'anon',
      'public.get_chore_notification_queue_health(timestamptz)',
      'execute'
    ),
  'client roles cannot claim work or inspect queue health'
);
select ok(
  not has_table_privilege(
    'service_role',
    'app_private.chore_notification_outbox',
    'select,insert,update,delete'
  )
    and not has_table_privilege(
      'service_role',
      'app_private.notification_event_resolutions',
      'select,insert,update,delete'
    )
    and not has_table_privilege(
      'service_role',
      'app_private.notification_worker_transitions',
      'select,insert,update,delete'
    )
    and not has_table_privilege(
      'service_role',
      'app_private.notification_worker_control',
      'select,insert,update,delete'
    ),
  'service role cannot bypass mediated APIs through private tables'
);
select ok(
  not has_function_privilege(
    'service_role',
    'app_private.notification_retry_delay(uuid,integer)',
    'execute'
  )
    and not has_function_privilege(
      'service_role',
      'app_private.resolve_chore_notification_event(uuid)',
      'execute'
    )
    and not has_function_privilege(
      'authenticated',
      'app_private.notification_retry_delay(uuid,integer)',
      'execute'
    ),
  'worker roles cannot invoke private helpers or the resolver directly'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name in (
        'notification_event_resolutions',
        'notification_worker_transitions',
        'notification_worker_control'
      )
      and column_name in (
        'title',
        'description',
        'display_name',
        'email',
        'token',
        'payload',
        'raw_error',
        'error_message'
      )
  ),
  'worker state contains no household content, token, email, or raw error field'
);

set local role authenticated;
select throws_ok(
  $$
    select * from public.claim_chore_notification_events(
      '51000000-0000-4000-8000-000000000001', 1, 60,
      '2030-01-01 00:00:00+00'
    )
  $$,
  '42501',
  'permission denied for function claim_chore_notification_events',
  'authenticated clients are denied before worker execution'
);
reset role;
set local role anon;
select throws_ok(
  $$
    select * from public.get_chore_notification_queue_health(
      '2030-01-01 00:00:00+00'
    )
  $$,
  '42501',
  'permission denied for function get_chore_notification_queue_health',
  'anonymous clients cannot inspect queue health'
);
reset role;

set local role service_role;
select throws_ok(
  $$
    select * from public.claim_chore_notification_events(
      '51000000-0000-4000-8000-000000000001', 0, 60,
      '2030-01-01 00:00:00+00'
    )
  $$,
  'KFN01',
  'invalid notification worker input',
  'claim rejects an empty batch'
);
select throws_ok(
  $$
    select * from public.claim_chore_notification_events(
      '51000000-0000-4000-8000-000000000001', 101, 60,
      '2030-01-01 00:00:00+00'
    )
  $$,
  'KFN01',
  'invalid notification worker input',
  'claim rejects a batch above one hundred'
);
select throws_ok(
  $$
    select * from public.claim_chore_notification_events(
      '51000000-0000-4000-8000-000000000001', 1, 4,
      '2030-01-01 00:00:00+00'
    )
  $$,
  'KFN01',
  'invalid notification worker input',
  'claim rejects a lease below five seconds'
);
select throws_ok(
  $$
    select public.heartbeat_chore_notification_event(
      '51000000-0000-4000-8000-000000000101',
      '51000000-0000-4000-8000-000000000201',
      301,
      '2030-01-01 00:00:00+00'
    )
  $$,
  'KFN01',
  'invalid notification worker input',
  'heartbeat rejects an extension above five minutes'
);
select throws_ok(
  $$
    select * from public.fail_chore_notification_event(
      '51000000-0000-4000-8000-000000000101',
      '51000000-0000-4000-8000-000000000201',
      'raw provider body',
      '2030-01-01 00:00:00+00'
    )
  $$,
  'KFN01',
  'invalid notification worker input',
  'failure rejects raw or lowercase error content'
);
select throws_ok(
  $$
    select * from public.replay_chore_notification_dead_letter(
      '51000000-0000-4000-8000-000000000101',
      'operator wrote a sentence',
      '2030-01-01 00:00:00+00'
    )
  $$,
  'KFN01',
  'invalid notification worker input',
  'replay accepts only a stable uppercase reason code'
);
select throws_ok(
  $$
    select * from public.set_chore_notification_worker_paused(
      true, null, '2030-01-01 00:00:00+00'
    )
  $$,
  'KFN01',
  'invalid notification worker input',
  'pause requires a stable reason code'
);
select throws_ok(
  $$select * from public.get_chore_notification_queue_health(null)$$,
  'KFN01',
  'invalid notification worker input',
  'health requires an explicit deterministic clock'
);
reset role;

create temporary table worker_fixtures (
  fixture_label text primary key,
  series_id uuid not null,
  occurrence_id uuid not null
);
create temporary table worker_claims (
  event_id uuid primary key,
  lease_token uuid not null,
  attempt integer not null,
  max_attempts integer not null,
  lease_expires_at timestamptz not null
);
create temporary table worker_results (
  fixture_label text not null,
  source_event_id uuid primary key,
  outcome text not null,
  notification_category text not null,
  subject_type text not null,
  subject_id uuid not null,
  recipient_member_id uuid,
  recipient_user_id uuid,
  scheduled_at timestamptz,
  timezone text not null,
  suppression_reason text,
  resolved_at timestamptz not null
);
grant all on table worker_claims, worker_results to service_role;

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);

-- Candidate resolution, leases, heartbeat, and response-loss replay.
select lives_ok(
  $$
    insert into worker_fixtures (fixture_label, series_id, occurrence_id)
    select 'candidate', result.series_id, result.occurrence_id
    from public.create_one_time_chore(
      '51000000-0000-4000-8000-000000000301',
      '20000000-0000-4000-8000-000000000101',
      'Worker candidate fixture',
      'Must never enter worker state',
      '30000000-0000-4000-8000-000000000102',
      '2030-01-02',
      time '09:15'
    ) as result
  $$,
  'candidate fixture emits its source events atomically'
);

set local role service_role;
insert into worker_claims
select *
from public.claim_chore_notification_events(
  '51000000-0000-4000-8000-000000000001',
  10,
  60,
  '2030-01-01 00:00:00+00'
);
reset role;

select is(
  (select count(*) from worker_claims),
  2::bigint,
  'one occurrence yields two independently leased source events'
);
select is(
  (
    select concat_ws(
      ':',
      min(attempt),
      max(attempt),
      min(max_attempts),
      max(max_attempts),
      count(distinct lease_token),
      min(lease_expires_at)
    )
    from worker_claims
  ),
  '1:1:5:5:2:2030-01-01 00:01:00+00',
  'claim returns attempt one, unique opaque tokens, and exact lease expiry'
);
select is(
  (
    select string_agg(
      concat_ws(':', event.processing_status, event.attempts),
      ',' order by event.event_type
    )
    from app_private.chore_notification_outbox as event
    join worker_fixtures as fixture
      on fixture.occurrence_id = event.aggregate_id
    where fixture.fixture_label = 'candidate'
  ),
  'leased:1,leased:1',
  'claim atomically persists the lifecycle before returning work'
);
select is(
  (
    select count(*)
    from app_private.notification_worker_transitions as transition
    join worker_claims as claim
      on claim.event_id = transition.source_event_id
    where transition.transition = 'claimed'
      and transition.worker_id =
        '51000000-0000-4000-8000-000000000001'
  ),
  2::bigint,
  'every lease has one content-free claimed transition'
);

set local role service_role;
select throws_ok(
  format(
    'select public.heartbeat_chore_notification_event(%L,%L,30,%L)',
    (select event_id from worker_claims order by event_id limit 1),
    '51000000-0000-4000-8000-000000000299',
    '2030-01-01 00:00:10+00'
  ),
  'KFN03',
  'notification lease not found or expired',
  'heartbeat rejects a mismatched lease token'
);
select is(
  (
    select public.heartbeat_chore_notification_event(
      claim.event_id,
      claim.lease_token,
      30,
      '2030-01-01 00:00:10+00'
    )
    from worker_claims as claim
    order by claim.event_id
    limit 1
  ),
  '2030-01-01 00:01:30+00'::timestamptz,
  'heartbeat extends from the current lease while respecting the cap'
);

insert into worker_results
select 'candidate', resolution.*
from worker_claims as claim
cross join lateral public.process_chore_notification_event(
  claim.event_id,
  claim.lease_token,
  '2030-01-01 00:00:20+00'
) as resolution;
reset role;

select is(
  (
    select concat_ws(
      ':',
      count(*),
      count(*) filter (where outcome = 'candidate'),
      count(*) filter (where suppression_reason is null),
      count(*) filter (
        where recipient_member_id is not null
          and recipient_user_id is not null
          and scheduled_at is not null
      )
    )
    from worker_results
    where fixture_label = 'candidate'
  ),
  '2:2:2:2',
  'due and assignment events become actionable content-free candidates'
);
select is(
  (
    select string_agg(notification_category, ',' order by notification_category)
    from worker_results
    where fixture_label = 'candidate'
  ),
  'chore_assignment,chore_due',
  'candidate resolution preserves the two allowlisted categories'
);
select is(
  (
    select scheduled_at
    from worker_results
    where fixture_label = 'candidate'
      and notification_category = 'chore_due'
  ),
  '2030-01-02 00:15:00+00'::timestamptz,
  'timed due candidate is resolved through the household timezone'
);
select is(
  (
    select concat_ws(
      ':',
      count(*),
      count(distinct resolution.source_event_id),
      count(*) filter (where event.processing_status = 'succeeded')
    )
    from app_private.notification_event_resolutions as resolution
    join app_private.chore_notification_outbox as event
      on event.event_id = resolution.source_event_id
    join worker_fixtures as fixture
      on fixture.occurrence_id = event.aggregate_id
    where fixture.fixture_label = 'candidate'
  ),
  '2:2:2',
  'resolution insert and succeeded transition commit atomically per event'
);
select is(
  (
    select count(*)
    from app_private.notification_worker_transitions as transition
    join worker_claims as claim
      on claim.event_id = transition.source_event_id
    where transition.transition = 'succeeded'
  ),
  2::bigint,
  'each candidate has one succeeded transition'
);

set local role service_role;
select is(
  (
    select replay.resolved_at
    from worker_claims as claim
    cross join lateral public.process_chore_notification_event(
      claim.event_id,
      claim.lease_token,
      '2030-01-01 00:10:00+00'
    ) as replay
    order by claim.event_id
    limit 1
  ),
  (
    select result.resolved_at
    from worker_results as result
    join worker_claims as claim on claim.event_id = result.source_event_id
    order by claim.event_id
    limit 1
  ),
  'response-loss replay returns the original durable resolution'
);
reset role;
select is(
  (
    select concat_ws(
      ':',
      count(*),
      count(*) filter (where transition.transition = 'succeeded')
    )
    from app_private.notification_worker_transitions as transition
    join worker_claims as claim on claim.event_id = transition.source_event_id
  ),
  '4:2',
  'response replay does not duplicate resolution transitions'
);
select throws_ok(
  format(
    'update app_private.notification_worker_transitions set attempt = 9 where source_event_id = %L',
    (select event_id from worker_claims order by event_id limit 1)
  ),
  '55000',
  'notification worker transitions are immutable',
  'transition audit cannot be rewritten even by its owner'
);

-- Retry, deterministic backoff, final dead letter, and manual replay.
truncate worker_claims;
select lives_ok(
  $$
    insert into worker_fixtures (fixture_label, series_id, occurrence_id)
    select 'retry', result.series_id, result.occurrence_id
    from public.create_one_time_chore(
      '51000000-0000-4000-8000-000000000302',
      '20000000-0000-4000-8000-000000000101',
      'Worker retry fixture',
      null,
      '30000000-0000-4000-8000-000000000102',
      '2030-01-03',
      time '10:00'
    ) as result
  $$,
  'retry fixture emits two new pending events'
);
set local role service_role;
insert into worker_claims
select * from public.claim_chore_notification_events(
  '51000000-0000-4000-8000-000000000002',
  10,
  60,
  '2030-01-01 01:00:00+00'
);
reset role;
insert into worker_results
select 'retry-cleanup', resolution.*
from worker_claims as claim
join app_private.chore_notification_outbox as event
  on event.event_id = claim.event_id
cross join lateral public.process_chore_notification_event(
  claim.event_id,
  claim.lease_token,
  '2030-01-01 01:00:10+00'
) as resolution
where event.event_type = 'chore.occurrence_assigned';

create temporary table worker_failure_state as
select failure.*
from worker_claims as claim
join app_private.chore_notification_outbox as event
  on event.event_id = claim.event_id
cross join lateral public.fail_chore_notification_event(
  claim.event_id,
  claim.lease_token,
  'WORKER_PROCESSING_FAILED',
  '2030-01-01 01:00:10+00'
) as failure
where event.event_type = 'chore.occurrence_due_changed';
grant all on table worker_failure_state to service_role;

select is(
  (
    select concat_ws(
      ':',
      processing_status,
      attempts,
      max_attempts,
      dead_lettered_at is null
    )
    from worker_failure_state
  ),
  'retry_wait:1:5:t',
  'first worker failure schedules a retry without dead-lettering'
);
select ok(
  (
    select next_attempt_at between
      '2030-01-01 01:00:40+00'::timestamptz
      and '2030-01-01 01:00:55+00'::timestamptz
    from worker_failure_state
  ),
  'attempt-one backoff is thirty seconds plus bounded deterministic jitter'
);
set local role service_role;
select is(
  (
    select count(*)
    from public.claim_chore_notification_events(
      '51000000-0000-4000-8000-000000000003',
      10,
      60,
      (select next_attempt_at - interval '1 microsecond'
       from worker_failure_state)
    )
  ),
  0::bigint,
  'retry cannot be claimed before its server-computed due instant'
);
reset role;
select ok(
  (
    select app_private.notification_retry_delay(event_id, 1)
      = app_private.notification_retry_delay(event_id, 1)
      and app_private.notification_retry_delay(event_id, 2)
        between interval '60 seconds' and interval '75 seconds'
      and app_private.notification_retry_delay(event_id, 3)
        between interval '120 seconds' and interval '135 seconds'
      and app_private.notification_retry_delay(event_id, 4)
        between interval '240 seconds' and interval '255 seconds'
    from worker_failure_state
  ),
  'retry delay is deterministic exponential backoff with bounded jitter'
);
select lives_ok(
  $retry$
    do $body$
    declare
      v_event_id uuid;
      v_next timestamptz;
      v_token uuid;
      v_attempt integer;
      v_status text;
      v_expected integer;
    begin
      select state.event_id, state.next_attempt_at
      into v_event_id, v_next
      from worker_failure_state as state;

      for v_expected in 2..5 loop
        select claim.lease_token, claim.attempt
        into v_token, v_attempt
        from public.claim_chore_notification_events(
          '51000000-0000-4000-8000-000000000003',
          1,
          60,
          v_next
        ) as claim;

        if v_attempt is distinct from v_expected then
          raise exception 'unexpected retry attempt';
        end if;

        select failure.processing_status, failure.next_attempt_at
        into v_status, v_next
        from public.fail_chore_notification_event(
          v_event_id,
          v_token,
          'WORKER_PROCESSING_FAILED',
          v_next + interval '1 second'
        ) as failure;

        if v_expected < 5 and v_status <> 'retry_wait' then
          raise exception 'retry dead-lettered early';
        end if;
        if v_expected = 5 and v_status <> 'dead_letter' then
          raise exception 'final retry was not dead-lettered';
        end if;
      end loop;
    end;
    $body$;
  $retry$,
  'bounded retry loop isolates the poison event at attempt five'
);
select is(
  (
    select concat_ws(
      ':',
      event.processing_status,
      event.attempts,
      event.max_attempts,
      event.last_error_code,
      event.next_attempt_at is null,
      event.dead_lettered_at is not null
    )
    from app_private.chore_notification_outbox as event
    join worker_failure_state as state on state.event_id = event.event_id
  ),
  'dead_letter:5:5:WORKER_PROCESSING_FAILED:t:t',
  'final failure persists only the stable code and terminal lifecycle state'
);
select is(
  (
    select concat_ws(
      ':',
      count(*) filter (where transition = 'claimed'),
      count(*) filter (where transition = 'retry_scheduled'),
      count(*) filter (where transition = 'dead_lettered')
    )
    from app_private.notification_worker_transitions as transition
    join worker_failure_state as state
      on state.event_id = transition.source_event_id
  ),
  '5:4:1',
  'all retries and final isolation have one immutable transition each'
);

set local role service_role;
select is(
  (
    select concat_ws(
      ':',
      replay.processing_status,
      replay.replay_count,
      replay.next_attempt_at
    )
    from worker_failure_state as state
    cross join lateral public.replay_chore_notification_dead_letter(
      state.event_id,
      'OPERATOR_RETRY',
      '2030-01-01 02:00:00+00'
    ) as replay
  ),
  'pending:1:2030-01-01 02:00:00+00',
  'manual replay resets the dead letter to a deterministic pending instant'
);
select throws_ok(
  format(
    'select * from public.replay_chore_notification_dead_letter(%L,%L,%L)',
    (select event_id from worker_failure_state),
    'OPERATOR_RETRY',
    '2030-01-01 02:00:01+00'
  ),
  'KFN05',
  'notification event is not replayable',
  'only a dead-letter event can be replayed'
);
truncate worker_claims;
insert into worker_claims
select * from public.claim_chore_notification_events(
  '51000000-0000-4000-8000-000000000004',
  1,
  60,
  '2030-01-01 02:00:00+00'
);
select throws_ok(
  format(
    'select * from public.fail_chore_notification_event(%L,%L,%L,%L)',
    (select event_id from worker_claims),
    (select lease_token from worker_claims),
    'private provider response',
    '2030-01-01 02:00:10+00'
  ),
  'KFN01',
  'invalid notification worker input',
  'raw provider failure cannot cross the API boundary'
);
insert into worker_results
select 'retry-replayed', resolution.*
from worker_claims as claim
cross join lateral public.process_chore_notification_event(
  claim.event_id,
  claim.lease_token,
  '2030-01-01 02:00:20+00'
) as resolution;
reset role;
select is(
  (
    select concat_ws(
      ':',
      event.processing_status,
      event.attempts,
      event.replay_count,
      count(transition.id) filter (where transition.transition = 'replayed')
    )
    from app_private.chore_notification_outbox as event
    join worker_failure_state as state on state.event_id = event.event_id
    left join app_private.notification_worker_transitions as transition
      on transition.source_event_id = event.event_id
    group by event.processing_status, event.attempts, event.replay_count
  ),
  'succeeded:1:1:1',
  'replayed event restarts attempts and keeps one replay audit'
);

-- A crash on the final lease is swept into dead letter by the next claim.
truncate worker_claims;
select lives_ok(
  $$
    insert into worker_fixtures (fixture_label, series_id, occurrence_id)
    select 'expired-final', result.series_id, result.occurrence_id
    from public.create_one_time_chore(
      '51000000-0000-4000-8000-000000000303',
      '20000000-0000-4000-8000-000000000101',
      'Worker expired lease fixture',
      null,
      '30000000-0000-4000-8000-000000000102',
      '2030-01-04',
      time '11:00'
    ) as result
  $$,
  'expired lease fixture emits two new events'
);
insert into worker_claims
select * from public.claim_chore_notification_events(
  '51000000-0000-4000-8000-000000000005',
  10,
  60,
  '2030-01-01 03:00:00+00'
);
insert into worker_results
select 'expired-cleanup', resolution.*
from worker_claims as claim
join app_private.chore_notification_outbox as event
  on event.event_id = claim.event_id
cross join lateral public.process_chore_notification_event(
  claim.event_id,
  claim.lease_token,
  '2030-01-01 03:00:10+00'
) as resolution
where event.event_type = 'chore.occurrence_assigned';
select lives_ok(
  $expired$
    do $body$
    declare
      v_event_id uuid;
      v_token uuid;
      v_as_of timestamptz := '2030-01-01 03:00:10+00';
      v_next timestamptz;
      v_attempt integer := 1;
    begin
      select claim.event_id, claim.lease_token
      into v_event_id, v_token
      from worker_claims as claim
      join app_private.chore_notification_outbox as event
        on event.event_id = claim.event_id
      where event.event_type = 'chore.occurrence_due_changed';

      while v_attempt < 5 loop
        select failure.next_attempt_at
        into v_next
        from public.fail_chore_notification_event(
          v_event_id,
          v_token,
          'WORKER_PROCESSING_FAILED',
          v_as_of
        ) as failure;

        select claim.lease_token, claim.attempt
        into v_token, v_attempt
        from public.claim_chore_notification_events(
          '51000000-0000-4000-8000-000000000005',
          1,
          60,
          v_next
        ) as claim;

        v_as_of := v_next + interval '1 second';
      end loop;
    end;
    $body$;
  $expired$,
  'event reaches its final lease without recording a provider failure'
);
select is(
  (
    select count(*)
    from public.claim_chore_notification_events(
      '51000000-0000-4000-8000-000000000006',
      1,
      60,
      (
        select event.lease_expires_at
        from app_private.chore_notification_outbox as event
        join worker_fixtures as fixture
          on fixture.occurrence_id = event.aggregate_id
        where fixture.fixture_label = 'expired-final'
          and event.event_type = 'chore.occurrence_due_changed'
      )
    )
  ),
  0::bigint,
  'next claim sweeps an expired final lease without returning poison work'
);
select is(
  (
    select concat_ws(
      ':',
      event.processing_status,
      event.attempts,
      event.last_error_code,
      event.dead_lettered_at is not null
    )
    from app_private.chore_notification_outbox as event
    join worker_fixtures as fixture
      on fixture.occurrence_id = event.aggregate_id
    where fixture.fixture_label = 'expired-final'
      and event.event_type = 'chore.occurrence_due_changed'
  ),
  'dead_letter:5:LEASE_EXPIRED:t',
  'expired final lease records a stable terminal crash code'
);

-- Pause stops new claims while an existing lease can finish; health is aggregate.
truncate worker_claims;
select lives_ok(
  $$
    insert into worker_fixtures (fixture_label, series_id, occurrence_id)
    select 'pause', result.series_id, result.occurrence_id
    from public.create_one_time_chore(
      '51000000-0000-4000-8000-000000000304',
      '20000000-0000-4000-8000-000000000101',
      'Worker pause fixture',
      null,
      '30000000-0000-4000-8000-000000000102',
      '2030-01-05',
      time '12:00'
    ) as result
  $$,
  'pause fixture emits two independently claimable events'
);
set local role service_role;
insert into worker_claims
select * from public.claim_chore_notification_events(
  '51000000-0000-4000-8000-000000000007',
  1,
  60,
  '2030-01-01 04:00:00+00'
);
select is(
  (
    select concat_ws(':', paused, reason_code, updated_at)
    from public.set_chore_notification_worker_paused(
      true,
      'OPERATOR_PAUSE',
      '2030-01-01 04:00:01+00'
    )
  ),
  't:OPERATOR_PAUSE:2030-01-01 04:00:01+00',
  'worker can be paused with a stable operational reason'
);
select is(
  (
    select count(*)
    from public.claim_chore_notification_events(
      '51000000-0000-4000-8000-000000000008',
      10,
      60,
      '2030-01-01 04:00:02+00'
    )
  ),
  0::bigint,
  'paused worker returns an empty claim without mutating ready rows'
);
select lives_ok(
  format(
    'select * from public.process_chore_notification_event(%L,%L,%L)',
    (select event_id from worker_claims),
    (select lease_token from worker_claims),
    '2030-01-01 04:00:03+00'
  ),
  'an existing lease can finish cleanly while new claims are paused'
);
select is(
  (
    select concat_ws(
      ':',
      health.paused,
      health.pause_reason_code,
      health.pending_count,
      health.leased_count,
      health.ready_count,
      health.expired_lease_count,
      health.dead_letter_count
    )
    from public.get_chore_notification_queue_health(
      '2030-01-01 04:00:04+00'
    ) as health
  ),
  't:OPERATOR_PAUSE:1:0:1:0:1',
  'health reports only aggregate pause, ready, lease, and dead-letter state'
);
select is(
  (
    select concat_ws(':', paused, reason_code is null)
    from public.set_chore_notification_worker_paused(
      false,
      null,
      '2030-01-01 04:00:05+00'
    )
  ),
  'f:t',
  'worker resumes only when the pause reason is cleared'
);
truncate worker_claims;
insert into worker_claims
select * from public.claim_chore_notification_events(
  '51000000-0000-4000-8000-000000000008',
  10,
  60,
  '2030-01-01 04:00:06+00'
);
insert into worker_results
select 'pause-cleanup', resolution.*
from worker_claims as claim
cross join lateral public.process_chore_notification_event(
  claim.event_id,
  claim.lease_token,
  '2030-01-01 04:00:07+00'
) as resolution;
reset role;
select is(
  (
    select concat_ws(':', paused, ready_count, expired_lease_count)
    from public.get_chore_notification_queue_health(
      '2030-01-01 04:00:08+00'
    )
  ),
  'f:0:0',
  'resumed queue drains to zero ready or expired work'
);

-- Every latest-state suppression reason is durable and content-free.
truncate worker_claims;
select lives_ok(
  $$
    insert into worker_fixtures (fixture_label, series_id, occurrence_id)
    select 'schedule-unresolved', result.series_id, result.occurrence_id
    from public.create_one_time_chore(
      '51000000-0000-4000-8000-000000000305',
      '20000000-0000-4000-8000-000000000101',
      'Worker all-day suppression',
      null,
      '30000000-0000-4000-8000-000000000102',
      '2030-01-06',
      null
    ) as result
  $$,
  'all-day fixture emits events without inventing a due instant'
);
insert into worker_claims
select * from public.claim_chore_notification_events(
  '51000000-0000-4000-8000-000000000009',
  10,
  60,
  '2030-01-01 05:00:00+00'
);
insert into worker_results
select 'schedule-unresolved', resolution.*
from worker_claims as claim
cross join lateral public.process_chore_notification_event(
  claim.event_id,
  claim.lease_token,
  '2030-01-01 05:00:10+00'
) as resolution;

truncate worker_claims;
select lives_ok(
  $$
    insert into worker_fixtures (fixture_label, series_id, occurrence_id)
    select 'not-scheduled', result.series_id, result.occurrence_id
    from public.create_one_time_chore(
      '51000000-0000-4000-8000-000000000306',
      '20000000-0000-4000-8000-000000000101',
      'Worker completed suppression',
      null,
      '30000000-0000-4000-8000-000000000102',
      '2030-01-07',
      time '08:00'
    ) as result
  $$,
  'not-scheduled fixture begins as a timed occurrence'
);
update public.chore_occurrences as occurrence
set status = 'skipped'
from worker_fixtures as fixture
where fixture.fixture_label = 'not-scheduled'
  and occurrence.id = fixture.occurrence_id;
insert into worker_claims
select * from public.claim_chore_notification_events(
  '51000000-0000-4000-8000-000000000010',
  10,
  60,
  '2030-01-01 06:00:00+00'
);
insert into worker_results
select 'not-scheduled', resolution.*
from worker_claims as claim
cross join lateral public.process_chore_notification_event(
  claim.event_id,
  claim.lease_token,
  '2030-01-01 06:00:10+00'
) as resolution;

truncate worker_claims;
select lives_ok(
  $$
    insert into worker_fixtures (fixture_label, series_id, occurrence_id)
    select 'inactive-series', result.series_id, result.occurrence_id
    from public.create_one_time_chore(
      '51000000-0000-4000-8000-000000000307',
      '20000000-0000-4000-8000-000000000101',
      'Worker inactive series suppression',
      null,
      '30000000-0000-4000-8000-000000000102',
      '2030-01-08',
      time '08:30'
    ) as result
  $$,
  'inactive-series fixture begins with current events'
);
update public.chore_series as series
set deleted_at = '2030-01-01 06:30:00+00'
from worker_fixtures as fixture
where fixture.fixture_label = 'inactive-series'
  and series.id = fixture.series_id;
insert into worker_claims
select * from public.claim_chore_notification_events(
  '51000000-0000-4000-8000-000000000011',
  10,
  60,
  '2030-01-01 07:00:00+00'
);
insert into worker_results
select 'inactive-series', resolution.*
from worker_claims as claim
cross join lateral public.process_chore_notification_event(
  claim.event_id,
  claim.lease_token,
  '2030-01-01 07:00:10+00'
) as resolution;

truncate worker_claims;
select lives_ok(
  $$
    insert into worker_fixtures (fixture_label, series_id, occurrence_id)
    select 'inactive-recipient', result.series_id, result.occurrence_id
    from public.create_one_time_chore(
      '51000000-0000-4000-8000-000000000308',
      '20000000-0000-4000-8000-000000000101',
      'Worker inactive recipient suppression',
      null,
      '30000000-0000-4000-8000-000000000102',
      '2030-01-09',
      time '09:00'
    ) as result
  $$,
  'inactive-recipient fixture begins with an active assignee'
);
update public.household_members
set removed_at = '2030-01-01 07:30:00+00'
where household_id = '20000000-0000-4000-8000-000000000101'
  and id = '30000000-0000-4000-8000-000000000102';
insert into worker_claims
select * from public.claim_chore_notification_events(
  '51000000-0000-4000-8000-000000000012',
  10,
  60,
  '2030-01-01 08:00:00+00'
);
insert into worker_results
select 'inactive-recipient', resolution.*
from worker_claims as claim
cross join lateral public.process_chore_notification_event(
  claim.event_id,
  claim.lease_token,
  '2030-01-01 08:00:10+00'
) as resolution;

select is(
  (
    select string_agg(
      concat_ws(':', notification_category, outcome,
        coalesce(suppression_reason, 'none')),
      ',' order by notification_category
    )
    from worker_results
    where fixture_label = 'schedule-unresolved'
  ),
  'chore_assignment:candidate:none,chore_due:suppressed:schedule_unresolved',
  'all-day due is suppressed while assignment remains actionable'
);
select is(
  (
    select string_agg(suppression_reason, ',' order by suppression_reason)
    from worker_results
    where fixture_label = 'not-scheduled'
  ),
  'occurrence_not_scheduled,stale_event,stale_event',
  'status change suppresses the current event and marks older event types stale'
);
select is(
  (
    select string_agg(suppression_reason, ',' order by notification_category)
    from worker_results
    where fixture_label = 'inactive-series'
  ),
  'inactive_series,inactive_series',
  'deleted series suppresses both current categories at processing time'
);
select is(
  (
    select string_agg(suppression_reason, ',' order by notification_category)
    from worker_results
    where fixture_label = 'inactive-recipient'
  ),
  'inactive_recipient,inactive_recipient',
  'removed recipient suppresses both current categories at processing time'
);
select is(
  (
    select count(*)
    from worker_results
    where outcome = 'suppressed'
      and (
        recipient_member_id is not null
        or recipient_user_id is not null
        or scheduled_at is not null
      )
  ),
  0::bigint,
  'suppression never retains a recipient route or delivery instant'
);
select is(
  (
    select string_agg(distinct suppression_reason, ',' order by suppression_reason)
    from worker_results
    where outcome = 'suppressed'
  ),
  'inactive_recipient,inactive_series,occurrence_not_scheduled,schedule_unresolved,stale_event',
  'worker durably covers the complete allowlisted suppression vocabulary'
);
select is(
  (
    select concat_ws(':', paused, ready_count, expired_lease_count)
    from public.get_chore_notification_queue_health(
      '2030-01-01 08:01:00+00'
    )
  ),
  'f:0:0',
  'all non-dead-letter fixture work is fully drained after suppression checks'
);

select * from finish();
rollback;
