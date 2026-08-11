create extension if not exists dblink with schema extensions;

do $$
begin
  perform extensions.dblink_connect(
    'kinflow_horizon_lock',
    'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres sslmode=disable'
  );
  perform extensions.dblink_exec(
    'kinflow_horizon_lock',
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
          '4f600000-0000-4000-8000-000000000001',
          '20000000-0000-4000-8000-000000000101',
          'Concurrent locked horizon fixture',
          'Asia/Seoul',
          '4f610000-0000-4000-8000-000000000001'
        ),
        (
          '4f600000-0000-4000-8000-000000000002',
          '20000000-0000-4000-8000-000000000101',
          'Concurrent available horizon fixture',
          'Asia/Seoul',
          '4f610000-0000-4000-8000-000000000002'
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
      values
        (
          '4f610000-0000-4000-8000-000000000001',
          '20000000-0000-4000-8000-000000000101',
          '4f600000-0000-4000-8000-000000000001',
          1,
          '2028-01-01',
          '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
          '30000000-0000-4000-8000-000000000101'
        ),
        (
          '4f610000-0000-4000-8000-000000000002',
          '20000000-0000-4000-8000-000000000101',
          '4f600000-0000-4000-8000-000000000002',
          1,
          '2028-01-01',
          '{"frequency":"daily","interval":1,"end":{"type":"never"}}',
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

select is(
  (
    select count(*)
    from public.chore_series
    where id in (
      '4f600000-0000-4000-8000-000000000001',
      '4f600000-0000-4000-8000-000000000002'
    )
  ),
  2::bigint,
  'two committed concurrency fixtures are visible to the worker transaction'
);

do $$
begin
  perform extensions.dblink_exec('kinflow_horizon_lock', 'begin');
  perform extensions.dblink_exec(
    'kinflow_horizon_lock',
    $lock$
      do $locked$
      begin
        perform 1
        from public.chore_series
        where id = '4f600000-0000-4000-8000-000000000001'
        for update;
      end;
      $locked$;
    $lock$
  );
end;
$$;

set local role service_role;
select is(
  (
    select concat_ws(
      ':', result.claimed_count, result.succeeded_count,
      result.failed_count, result.inserted_count,
      result.batch_exhausted
    )
    from public.run_chore_horizon_worker(
      '2028-12-25 00:00:00+00', 365, 7, 1, null
    ) as result
  ),
  '1:1:0:373:t',
  'worker skips the externally locked first series and fills its bounded batch'
);

reset role;
select is(
  (
    select string_agg(state.series_id::text, ',' order by state.series_id)
    from app_private.chore_materialization_states as state
    where state.series_id in (
      '4f600000-0000-4000-8000-000000000001',
      '4f600000-0000-4000-8000-000000000002'
    )
  ),
  '4f600000-0000-4000-8000-000000000002',
  'only the unlocked second series records coverage on the first invocation'
);
select is(
  (
    select concat_ws(
      ':',
      count(*) filter (
        where occurrence.series_id =
          '4f600000-0000-4000-8000-000000000001'
      ),
      count(*) filter (
        where occurrence.series_id =
          '4f600000-0000-4000-8000-000000000002'
      )
    )
    from public.chore_occurrences as occurrence
    where occurrence.series_id in (
      '4f600000-0000-4000-8000-000000000001',
      '4f600000-0000-4000-8000-000000000002'
    )
  ),
  '0:373',
  'locked series receives no occurrence while the available series is repaired'
);

do $$
begin
  perform extensions.dblink_exec('kinflow_horizon_lock', 'rollback');
end;
$$;

set local role service_role;
select is(
  (
    select concat_ws(
      ':', result.claimed_count, result.succeeded_count,
      result.failed_count, result.inserted_count,
      result.batch_exhausted
    )
    from public.run_chore_horizon_worker(
      '2028-12-25 00:00:00+00', 365, 7, 1, null
    ) as result
  ),
  '1:1:0:373:t',
  'next invocation claims the previously locked series after lock release'
);

reset role;
select is(
  (
    select count(*)
    from app_private.chore_materialization_states as state
    where state.series_id in (
      '4f600000-0000-4000-8000-000000000001',
      '4f600000-0000-4000-8000-000000000002'
    )
  ),
  2::bigint,
  'both concurrency fixtures eventually receive independent coverage state'
);
select is(
  (
    select concat_ws(
      ':', count(*), count(distinct occurrence.occurrence_key)
    )
    from public.chore_occurrences as occurrence
    where occurrence.series_id in (
      '4f600000-0000-4000-8000-000000000001',
      '4f600000-0000-4000-8000-000000000002'
    )
  ),
  '746:746',
  'overlapping workers leave exact unique occurrence keys across both series'
);

select * from finish();
rollback;

do $$
begin
  perform extensions.dblink_exec(
    'kinflow_horizon_lock',
    $cleanup$
      delete from public.chore_series
      where id in (
        '4f600000-0000-4000-8000-000000000001',
        '4f600000-0000-4000-8000-000000000002'
      );
    $cleanup$
  );
  perform extensions.dblink_disconnect('kinflow_horizon_lock');
end;
$$;

drop extension dblink;
