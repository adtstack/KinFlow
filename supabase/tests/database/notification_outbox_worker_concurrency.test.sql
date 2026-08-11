create extension if not exists dblink with schema extensions;

do $$
begin
  perform extensions.dblink_connect(
    'kinflow_notification_lock',
    'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres sslmode=disable'
  );
  perform extensions.dblink_exec(
    'kinflow_notification_lock',
    $setup$
      begin;
      set constraints all deferred;

      insert into public.chore_series (
        id,
        household_id,
        title,
        timezone,
        active_revision_id
      )
      values
        (
          '51600000-0000-4000-8000-000000000001',
          '20000000-0000-4000-8000-000000000101',
          'Notification concurrency first',
          'Asia/Seoul',
          '51610000-0000-4000-8000-000000000001'
        ),
        (
          '51600000-0000-4000-8000-000000000002',
          '20000000-0000-4000-8000-000000000101',
          'Notification concurrency second',
          'Asia/Seoul',
          '51610000-0000-4000-8000-000000000002'
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
      values
        (
          '51610000-0000-4000-8000-000000000001',
          '20000000-0000-4000-8000-000000000101',
          '51600000-0000-4000-8000-000000000001',
          1,
          '2030-01-10',
          time '09:00',
          '{"type":"once"}',
          '30000000-0000-4000-8000-000000000101'
        ),
        (
          '51610000-0000-4000-8000-000000000002',
          '20000000-0000-4000-8000-000000000101',
          '51600000-0000-4000-8000-000000000002',
          1,
          '2030-01-11',
          time '10:00',
          '{"type":"once"}',
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
      values
        (
          '51620000-0000-4000-8000-000000000001',
          '20000000-0000-4000-8000-000000000101',
          '51600000-0000-4000-8000-000000000001',
          '51610000-0000-4000-8000-000000000001',
          '51600000-0000-4000-8000-000000000001:once',
          '2030-01-10',
          '2030-01-10 00:00:00+00',
          'Asia/Seoul',
          '30000000-0000-4000-8000-000000000101'
        ),
        (
          '51620000-0000-4000-8000-000000000002',
          '20000000-0000-4000-8000-000000000101',
          '51600000-0000-4000-8000-000000000002',
          '51610000-0000-4000-8000-000000000002',
          '51600000-0000-4000-8000-000000000002:once',
          '2030-01-11',
          '2030-01-11 01:00:00+00',
          'Asia/Seoul',
          '30000000-0000-4000-8000-000000000101'
        );

      commit;
    $setup$
  );
end;
$$;

begin;
set constraints all deferred;

select plan(7);

create temporary table notification_concurrency_claims (
  claim_order integer not null,
  event_id uuid not null,
  lease_token uuid not null,
  attempt integer not null,
  max_attempts integer not null,
  lease_expires_at timestamptz not null,
  primary key (event_id)
);
grant all on table notification_concurrency_claims to service_role;

select is(
  (
    select count(*)
    from app_private.chore_notification_outbox
    where aggregate_id in (
      '51620000-0000-4000-8000-000000000001',
      '51620000-0000-4000-8000-000000000002'
    )
  ),
  4::bigint,
  'two committed occurrences expose four source events to competing workers'
);

do $$
begin
  perform extensions.dblink_exec('kinflow_notification_lock', 'begin');
  perform extensions.dblink_exec(
    'kinflow_notification_lock',
    $lock$
      do $locked$
      begin
        perform event.event_id
        from app_private.chore_notification_outbox as event
        where event.aggregate_id in (
          '51620000-0000-4000-8000-000000000001',
          '51620000-0000-4000-8000-000000000002'
        )
        order by event.occurred_at, event.event_id
        for update
        limit 1;
      end;
      $locked$;
    $lock$
  );
end;
$$;

select ok(
  (
    select event.processing_status = 'pending'
    from app_private.chore_notification_outbox as event
    where event.event_id = (
      select candidate.event_id
      from app_private.chore_notification_outbox as candidate
      where candidate.aggregate_id in (
        '51620000-0000-4000-8000-000000000001',
        '51620000-0000-4000-8000-000000000002'
      )
      order by candidate.occurred_at, candidate.event_id
      limit 1
    )
  ),
  'externally locked first event remains pending and visible to ordinary reads'
);

set local role service_role;
insert into notification_concurrency_claims
select 1, claim.*
from public.claim_chore_notification_events(
  '51630000-0000-4000-8000-000000000001',
  1,
  60,
  '2030-01-01 00:00:00+00'
) as claim;
reset role;

select is(
  (select count(*) from notification_concurrency_claims),
  1::bigint,
  'first worker fills its batch despite the head row lock'
);
select isnt(
  (
    select event_id
    from notification_concurrency_claims
    where claim_order = 1
  ),
  (
    select candidate.event_id
    from app_private.chore_notification_outbox as candidate
    where candidate.aggregate_id in (
      '51620000-0000-4000-8000-000000000001',
      '51620000-0000-4000-8000-000000000002'
    )
    order by candidate.occurred_at, candidate.event_id
    limit 1
  ),
  'SKIP LOCKED prevents the first worker from waiting on or duplicating the lock owner'
);
select is(
  (
    select count(*)
    from app_private.notification_worker_transitions as transition
    join notification_concurrency_claims as claim
      on claim.event_id = transition.source_event_id
    where transition.transition = 'claimed'
      and transition.worker_id =
        '51630000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'first worker records exactly one independent claim transition'
);

do $$
begin
  perform extensions.dblink_exec('kinflow_notification_lock', 'rollback');
end;
$$;

set local role service_role;
insert into notification_concurrency_claims
select 2, claim.*
from public.claim_chore_notification_events(
  '51630000-0000-4000-8000-000000000002',
  1,
  60,
  '2030-01-01 00:00:01+00'
) as claim;
reset role;

select is(
  (
    select event_id
    from notification_concurrency_claims
    where claim_order = 2
  ),
  (
    select candidate.event_id
    from app_private.chore_notification_outbox as candidate
    where candidate.aggregate_id in (
      '51620000-0000-4000-8000-000000000001',
      '51620000-0000-4000-8000-000000000002'
    )
    order by candidate.occurred_at, candidate.event_id
    limit 1
  ),
  'second worker claims the previously locked head event after release'
);
select is(
  (
    select concat_ws(
      ':',
      count(*),
      count(distinct event_id),
      count(distinct lease_token),
      min(attempt),
      max(attempt)
    )
    from notification_concurrency_claims
  ),
  '2:2:2:1:1',
  'competing workers receive unique events and opaque leases at attempt one'
);

select * from finish();
rollback;

do $$
begin
  perform extensions.dblink_exec(
    'kinflow_notification_lock',
    $cleanup$
      delete from public.chore_series
      where id in (
        '51600000-0000-4000-8000-000000000001',
        '51600000-0000-4000-8000-000000000002'
      );
    $cleanup$
  );
  perform extensions.dblink_disconnect('kinflow_notification_lock');
end;
$$;

drop extension dblink;
