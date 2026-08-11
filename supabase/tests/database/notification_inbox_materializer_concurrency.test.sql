create extension if not exists dblink with schema extensions;

do $$
begin
  perform extensions.dblink_connect(
    'kinflow_notification_inbox_lock',
    'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres sslmode=disable'
  );
  perform extensions.dblink_exec(
    'kinflow_notification_inbox_lock',
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
          '52600000-0000-4000-8000-000000000001',
          '20000000-0000-4000-8000-000000000101',
          'Inbox materializer concurrency first',
          'Asia/Seoul',
          '52610000-0000-4000-8000-000000000001'
        ),
        (
          '52600000-0000-4000-8000-000000000002',
          '20000000-0000-4000-8000-000000000101',
          'Inbox materializer concurrency second',
          'Asia/Seoul',
          '52610000-0000-4000-8000-000000000002'
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
          '52610000-0000-4000-8000-000000000001',
          '20000000-0000-4000-8000-000000000101',
          '52600000-0000-4000-8000-000000000001',
          1,
          '2030-01-10',
          time '09:00',
          '{"type":"once"}',
          '30000000-0000-4000-8000-000000000102'
        ),
        (
          '52610000-0000-4000-8000-000000000002',
          '20000000-0000-4000-8000-000000000101',
          '52600000-0000-4000-8000-000000000002',
          1,
          '2030-01-11',
          time '10:00',
          '{"type":"once"}',
          '30000000-0000-4000-8000-000000000102'
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
          '52620000-0000-4000-8000-000000000001',
          '20000000-0000-4000-8000-000000000101',
          '52600000-0000-4000-8000-000000000001',
          '52610000-0000-4000-8000-000000000001',
          '52600000-0000-4000-8000-000000000001:once',
          '2030-01-10',
          '2030-01-10 00:00:00+00',
          'Asia/Seoul',
          '30000000-0000-4000-8000-000000000102'
        ),
        (
          '52620000-0000-4000-8000-000000000002',
          '20000000-0000-4000-8000-000000000101',
          '52600000-0000-4000-8000-000000000002',
          '52610000-0000-4000-8000-000000000002',
          '52600000-0000-4000-8000-000000000002:once',
          '2030-01-11',
          '2030-01-11 01:00:00+00',
          'Asia/Seoul',
          '30000000-0000-4000-8000-000000000102'
        );

      do $process$
      declare
        v_claim record;
      begin
        for v_claim in
          select *
          from public.claim_chore_notification_events(
            '52630000-0000-4000-8000-000000000001',
            10,
            60,
            '2030-01-01 00:00:00+00'
          )
        loop
          perform public.process_chore_notification_event(
            v_claim.event_id,
            v_claim.lease_token,
            '2030-01-01 00:00:01+00'
          );
        end loop;
      end;
      $process$;

      commit;
    $setup$
  );
end;
$$;

begin;
set constraints all deferred;

select plan(10);

select is(
  (
    select count(*)
    from app_private.notification_event_resolutions as resolution
    join app_private.chore_notification_outbox as event
      on event.event_id = resolution.source_event_id
    where event.aggregate_id in (
      '52620000-0000-4000-8000-000000000001',
      '52620000-0000-4000-8000-000000000002'
    )
  ),
  4::bigint,
  'two committed occurrences expose four resolved notification candidates'
);

do $$
begin
  perform extensions.dblink_exec(
    'kinflow_notification_inbox_lock',
    'begin'
  );
  perform extensions.dblink_exec(
    'kinflow_notification_inbox_lock',
    $lock$
      do $locked$
      begin
        perform resolution.source_event_id
        from app_private.notification_event_resolutions as resolution
        join app_private.chore_notification_outbox as event
          on event.event_id = resolution.source_event_id
        where event.aggregate_id in (
          '52620000-0000-4000-8000-000000000001',
          '52620000-0000-4000-8000-000000000002'
        )
        order by event.occurred_at, event.event_id
        for update of resolution
        limit 1;
      end;
      $locked$;
    $lock$
  );
end;
$$;

select is(
  (
    select count(*)
    from app_private.notification_inbox_evaluations as evaluation
    join app_private.chore_notification_outbox as event
      on event.event_id = evaluation.source_event_id
    where event.aggregate_id in (
      '52620000-0000-4000-8000-000000000001',
      '52620000-0000-4000-8000-000000000002'
    )
  ),
  0::bigint,
  'externally locked head resolution remains unevaluated'
);

set local role service_role;
select is(
  (
    select concat_ws(':', result.claimed_count, result.created_count)
    from public.materialize_chore_notification_inbox(
      1,
      '2030-01-01 00:00:02+00'
    ) as result
  ),
  '1:1',
  'competing materializer skips the locked head and fills its bounded batch'
);
reset role;

select is(
  (
    select count(*)
    from app_private.notification_inbox_evaluations as evaluation
    join app_private.chore_notification_outbox as event
      on event.event_id = evaluation.source_event_id
    where event.aggregate_id in (
      '52620000-0000-4000-8000-000000000001',
      '52620000-0000-4000-8000-000000000002'
    )
  ),
  1::bigint,
  'first materializer records exactly one independent evaluation'
);
select isnt(
  (
    select evaluation.source_event_id
    from app_private.notification_inbox_evaluations as evaluation
    join app_private.chore_notification_outbox as event
      on event.event_id = evaluation.source_event_id
    where event.aggregate_id in (
      '52620000-0000-4000-8000-000000000001',
      '52620000-0000-4000-8000-000000000002'
    )
  ),
  (
    select resolution.source_event_id
    from app_private.notification_event_resolutions as resolution
    join app_private.chore_notification_outbox as event
      on event.event_id = resolution.source_event_id
    where event.aggregate_id in (
      '52620000-0000-4000-8000-000000000001',
      '52620000-0000-4000-8000-000000000002'
    )
    order by event.occurred_at, event.event_id
    limit 1
  ),
  'SKIP LOCKED prevents duplicate work on the lock owner row'
);

do $$
begin
  perform extensions.dblink_exec(
    'kinflow_notification_inbox_lock',
    'rollback'
  );
end;
$$;

set local role service_role;
select is(
  (
    select concat_ws(':', result.claimed_count, result.created_count)
    from public.materialize_chore_notification_inbox(
      1,
      '2030-01-01 00:00:03+00'
    ) as result
  ),
  '1:1',
  'next invocation claims the previously locked head after release'
);
reset role;

select ok(
  exists (
    select 1
    from app_private.notification_inbox_evaluations as evaluation
    where evaluation.source_event_id = (
      select resolution.source_event_id
      from app_private.notification_event_resolutions as resolution
      join app_private.chore_notification_outbox as event
        on event.event_id = resolution.source_event_id
      where event.aggregate_id in (
        '52620000-0000-4000-8000-000000000001',
        '52620000-0000-4000-8000-000000000002'
      )
      order by event.occurred_at, event.event_id
      limit 1
    )
  ),
  'released head resolution receives its immutable evaluation'
);

set local role service_role;
select is(
  (
    select concat_ws(':', result.claimed_count, result.created_count)
    from public.materialize_chore_notification_inbox(
      100,
      '2030-01-01 00:00:04+00'
    ) as result
  ),
  '2:2',
  'remaining resolved candidates materialize in the next bounded batch'
);
reset role;

select is(
  (
    select concat_ws(
      ':',
      count(evaluation.source_event_id),
      count(distinct evaluation.source_event_id),
      count(item.id),
      count(distinct item.source_event_id)
    )
    from app_private.notification_inbox_evaluations as evaluation
    join app_private.chore_notification_outbox as event
      on event.event_id = evaluation.source_event_id
    left join public.notification_inbox_items as item
      on item.id = evaluation.inbox_item_id
    where event.aggregate_id in (
      '52620000-0000-4000-8000-000000000001',
      '52620000-0000-4000-8000-000000000002'
    )
  ),
  '4:4:4:4',
  'overlapping materializers leave one evaluation and one item per source event'
);

set local role service_role;
select is(
  (
    select concat_ws(':', result.claimed_count, result.created_count)
    from public.materialize_chore_notification_inbox(
      100,
      '2030-01-01 00:00:05+00'
    ) as result
  ),
  '0:0',
  'materializer replay performs no duplicate work'
);
reset role;

select * from finish();
rollback;

do $$
begin
  perform extensions.dblink_exec(
    'kinflow_notification_inbox_lock',
    $cleanup$
      alter table app_private.notification_worker_transitions
        disable trigger notification_worker_transitions_immutable;
      delete from public.chore_series
      where id in (
        '52600000-0000-4000-8000-000000000001',
        '52600000-0000-4000-8000-000000000002'
      );
      alter table app_private.notification_worker_transitions
        enable trigger notification_worker_transitions_immutable;
    $cleanup$
  );
  perform extensions.dblink_disconnect('kinflow_notification_inbox_lock');
end;
$$;

drop extension dblink;
