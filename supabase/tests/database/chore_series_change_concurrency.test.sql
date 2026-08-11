create extension if not exists dblink with schema extensions;

create or replace function app_private.test_concurrent_series_update(
  p_idempotency_key uuid,
  p_title text
)
returns text
language plpgsql
set search_path = ''
as $$
begin
  perform 1
  from public.update_repeating_chore_series(
    p_idempotency_key,
    '20000000-0000-4000-8000-000000000101',
    '4c600000-0000-4000-8000-000000000001',
    1,
    p_title,
    null,
    '30000000-0000-4000-8000-000000000101',
    null,
    '{"frequency":"daily","interval":1,"end":{"type":"count","count":2}}'
  ) as result;
  return 'updated';
exception
  when others then
    return sqlstate;
end;
$$;

do $$
begin
  perform extensions.dblink_connect(
    'kinflow_series_lock',
    'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres sslmode=disable'
  );
  perform extensions.dblink_connect(
    'kinflow_series_a',
    'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres sslmode=disable'
  );
  perform extensions.dblink_connect(
    'kinflow_series_b',
    'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres sslmode=disable'
  );
  perform extensions.dblink_exec(
    'kinflow_series_lock',
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
      values (
        '4c600000-0000-4000-8000-000000000001',
        '20000000-0000-4000-8000-000000000101',
        'Concurrent series fixture',
        'Asia/Seoul',
        '4c610000-0000-4000-8000-000000000001'
      );
      insert into public.chore_series_revisions (
        id,
        household_id,
        series_id,
        revision_number,
        effective_local_date,
        recurrence_rule,
        default_assignee_member_id
      )
      values (
        '4c610000-0000-4000-8000-000000000001',
        '20000000-0000-4000-8000-000000000101',
        '4c600000-0000-4000-8000-000000000001',
        1,
        (statement_timestamp() at time zone 'Asia/Seoul')::date,
        '{"frequency":"daily","interval":1,"end":{"type":"count","count":2}}',
        '30000000-0000-4000-8000-000000000101'
      );
      commit;
    $setup$
  );
  perform extensions.dblink_exec(
    'kinflow_series_a',
    $claim$
      do $body$
      begin
        perform set_config(
          'request.jwt.claim.sub',
          '00000000-0000-4000-8000-000000000101',
          false
        );
      end;
      $body$;
    $claim$
  );
  perform extensions.dblink_exec(
    'kinflow_series_b',
    $claim$
      do $body$
      begin
        perform set_config(
          'request.jwt.claim.sub',
          '00000000-0000-4000-8000-000000000101',
          false
        );
      end;
      $body$;
    $claim$
  );
end;
$$;

begin;
set constraints all deferred;

select plan(10);

select is(
  (
    select concat_ws(
      ':', series.version, revision.revision_number,
      revision.title, count(occurrence.id)
    )
    from public.chore_series as series
    join public.chore_series_revisions as revision
      on revision.id = series.active_revision_id
    left join public.chore_occurrences as occurrence
      on occurrence.series_id = series.id
    where series.id = '4c600000-0000-4000-8000-000000000001'
    group by series.version, revision.revision_number, revision.title
  ),
  '1:1:Concurrent series fixture:0',
  'committed concurrency fixture starts at one revision without occurrences'
);

do $$
begin
  perform extensions.dblink_exec('kinflow_series_lock', 'begin');
  perform extensions.dblink_exec(
    'kinflow_series_lock',
    $lock$
      do $body$
      begin
        perform 1
        from public.chore_series
        where id = '4c600000-0000-4000-8000-000000000001'
        for update;
      end;
      $body$;
    $lock$
  );
end;
$$;

select is(
  (
    select concat_ws(
      ':',
      extensions.dblink_send_query(
        'kinflow_series_a',
        $$select app_private.test_concurrent_series_update(
          '4c620000-0000-4000-8000-000000000001',
          'Concurrent winner A'
        )$$
      ),
      extensions.dblink_send_query(
        'kinflow_series_b',
        $$select app_private.test_concurrent_series_update(
          '4c620000-0000-4000-8000-000000000002',
          'Concurrent winner B'
        )$$
      )
    )
  ),
  '1:1',
  'both competing updates are queued while the series row is locked'
);

do $$
begin
  perform extensions.dblink_exec('kinflow_series_lock', 'rollback');
end;
$$;

do $$
declare
  v_outcome_a text;
  v_outcome_b text;
begin
  select result.outcome
  into v_outcome_a
  from extensions.dblink_get_result('kinflow_series_a')
    as result(outcome text);
  select result.outcome
  into v_outcome_b
  from extensions.dblink_get_result('kinflow_series_b')
    as result(outcome text);
  perform set_config(
    'kinflow.test.series_concurrency_outcomes',
    least(v_outcome_a, v_outcome_b) || ':' || greatest(
      v_outcome_a,
      v_outcome_b
    ),
    true
  );
end;
$$;

select is(
  current_setting('kinflow.test.series_concurrency_outcomes'),
  'KFC05:updated',
  'exactly one concurrent update wins and the loser receives stale version'
);
select ok(
  (
    select series.version = 2
      and series.title in ('Concurrent winner A', 'Concurrent winner B')
    from public.chore_series as series
    where series.id = '4c600000-0000-4000-8000-000000000001'
  ),
  'winner advances the series once with one of the complete input snapshots'
);
select is(
  (
    select count(*)
    from public.chore_series_revisions as revision
    where revision.series_id = '4c600000-0000-4000-8000-000000000001'
  ),
  2::bigint,
  'losing transaction leaves no orphan revision'
);
select is(
  (
    select count(*)
    from public.chore_series_change_events as event
    where event.series_id = '4c600000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'concurrent updates record exactly one immutable event'
);
select is(
  (
    select count(*)
    from app_private.chore_series_change_command_requests as request
    where request.series_id = '4c600000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'losing transaction leaves no idempotency result row'
);
select is(
  (
    select concat_ws(
      ':', count(*), count(distinct occurrence.occurrence_key),
      count(distinct occurrence.recurrence_local_date),
      count(distinct occurrence.revision_id)
    )
    from public.chore_occurrences as occurrence
    where occurrence.series_id = '4c600000-0000-4000-8000-000000000001'
  ),
  '2:2:2:1',
  'winner materializes one exact two-slot active revision without duplicates'
);
select ok(
  (
    select bool_and(occurrence.status = 'scheduled')
      and bool_and(occurrence.version = 1)
      and bool_and(
        occurrence.revision_id = series.active_revision_id
      )
    from public.chore_occurrences as occurrence
    join public.chore_series as series on series.id = occurrence.series_id
    where occurrence.series_id = '4c600000-0000-4000-8000-000000000001'
  ),
  'materialized slots all belong to the single winning revision'
);
select is(
  (
    select concat_ws(
      ':', event.series_version, event.rebuilt_count,
      event.cancelled_count, event.preserved_completed_count,
      request.result_version
    )
    from public.chore_series_change_events as event
    join app_private.chore_series_change_command_requests as request
      on request.result_event_id = event.id
    where event.series_id = '4c600000-0000-4000-8000-000000000001'
  ),
  '2:2:0:0:2',
  'winner event and idempotency summary agree on the atomic result'
);

select * from finish();
rollback;

do $$
begin
  perform extensions.dblink_exec(
    'kinflow_series_lock',
    $cleanup$
      delete from app_private.chore_series_change_command_requests
      where series_id = '4c600000-0000-4000-8000-000000000001';
      alter table public.chore_series_change_events
        disable trigger chore_series_change_events_immutable;
      delete from public.chore_series
      where id = '4c600000-0000-4000-8000-000000000001';
      alter table public.chore_series_change_events
        enable trigger chore_series_change_events_immutable;
      drop function app_private.test_concurrent_series_update(uuid, text);
    $cleanup$
  );
  perform extensions.dblink_disconnect('kinflow_series_lock');
  perform extensions.dblink_disconnect('kinflow_series_a');
  perform extensions.dblink_disconnect('kinflow_series_b');
end;
$$;

drop extension dblink;
