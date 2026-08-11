create extension if not exists dblink with schema extensions;

do $$
begin
  perform extensions.dblink_connect(
    'kinflow_assignment_lock',
    'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres sslmode=disable'
  );
  perform extensions.dblink_connect(
    'kinflow_assignment_a',
    'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres sslmode=disable'
  );
  perform extensions.dblink_connect(
    'kinflow_assignment_b',
    'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres sslmode=disable'
  );
  perform extensions.dblink_exec(
    'kinflow_assignment_lock',
    $setup$
      begin;
      set constraints all deferred;
      create temporary table kinflow_assignment_runtime_backup
      on commit preserve rows as
      select * from app_private.billing_runtime_config;
      alter table app_private.billing_runtime_config
        disable trigger billing_runtime_config_set_updated_at_and_version;
      update app_private.billing_runtime_config
      set accepted_environment = 'sandbox',
          ingestion_enabled = true;
      alter table app_private.billing_runtime_config
        enable trigger billing_runtime_config_set_updated_at_and_version;
      insert into public.households(
        id,
        name,
        timezone,
        owner_member_id,
        created_by_user_id
      ) values (
        '20000000-0000-4000-8000-000000000401',
        'Concurrent Billing Household',
        'UTC',
        '30000000-0000-4000-8000-000000000401',
        '00000000-0000-4000-8000-000000000101'
      );
      insert into public.household_members(
        id,
        household_id,
        auth_user_id,
        display_name,
        role,
        created_by_user_id
      ) values
        (
          '30000000-0000-4000-8000-000000000401',
          '20000000-0000-4000-8000-000000000401',
          '00000000-0000-4000-8000-000000000101',
          'Concurrent Owner',
          'owner',
          '00000000-0000-4000-8000-000000000101'
        ),
        (
          '30000000-0000-4000-8000-000000000402',
          '20000000-0000-4000-8000-000000000401',
          '00000000-0000-4000-8000-000000000102',
          'Concurrent Admin',
          'admin',
          '00000000-0000-4000-8000-000000000101'
        );
      commit;
    $setup$
  );
  perform extensions.dblink_exec(
    'kinflow_assignment_a',
    $session$
      do $body$
      begin
        perform set_config(
          'request.jwt.claim.sub',
          '00000000-0000-4000-8000-000000000101',
          false
        );
      end;
      $body$;
      set role authenticated;
    $session$
  );
  perform extensions.dblink_exec(
    'kinflow_assignment_b',
    $session$
      do $body$
      begin
        perform set_config(
          'request.jwt.claim.sub',
          '00000000-0000-4000-8000-000000000102',
          false
        );
      end;
      $body$;
      set role authenticated;
    $session$
  );
end;
$$;

begin;
set constraints all deferred;

select plan(7);

select is(
  (
    select pg_catalog.count(*)
    from public.billing_household_assignments
    where household_id = '20000000-0000-4000-8000-000000000401'
  ),
  0::bigint,
  'concurrent fixture starts without a billing assignment'
);

do $$
begin
  perform extensions.dblink_exec('kinflow_assignment_lock', 'begin');
  perform extensions.dblink_exec(
    'kinflow_assignment_lock',
    $lock$
      do $body$
      begin
        perform pg_catalog.pg_advisory_xact_lock(
          pg_catalog.hashtextextended(
            'billing-assignment-household:' ||
              '20000000-0000-4000-8000-000000000401',
            0
          )
        );
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
        'kinflow_assignment_a',
        $$
          select outcome
          from public.prepare_billing_household_assignment(
            '20000000-0000-4000-8000-000000000401',
            '86000000-0000-4000-8000-000000000401'
          )
        $$
      ),
      extensions.dblink_send_query(
        'kinflow_assignment_b',
        $$
          select outcome
          from public.prepare_billing_household_assignment(
            '20000000-0000-4000-8000-000000000401',
            '86000000-0000-4000-8000-000000000402'
          )
        $$
      )
    )
  ),
  '1:1',
  'both prepares are queued behind the same household serialization key'
);

do $$
begin
  perform extensions.dblink_exec('kinflow_assignment_lock', 'rollback');
end;
$$;

do $$
declare
  v_outcome_a text;
  v_outcome_b text;
begin
  select result.outcome
  into v_outcome_a
  from extensions.dblink_get_result('kinflow_assignment_a')
    as result(outcome text);
  select result.outcome
  into v_outcome_b
  from extensions.dblink_get_result('kinflow_assignment_b')
    as result(outcome text);
  perform set_config(
    'kinflow.test.assignment_concurrency_outcomes',
    least(v_outcome_a, v_outcome_b) || ':' ||
      greatest(v_outcome_a, v_outcome_b),
    true
  );
end;
$$;

select is(
  current_setting('kinflow.test.assignment_concurrency_outcomes'),
  'household_conflict:ready',
  'exactly one concurrent household selection wins and one conflicts'
);
select is(
  (
    select concat_ws(
      ':',
      pg_catalog.count(*),
      pg_catalog.count(*) filter (where status = 'active'),
      pg_catalog.count(*) filter (where binding_state = 'provisional')
    )
    from public.billing_household_assignments
    where household_id = '20000000-0000-4000-8000-000000000401'
  ),
  '1:1:1',
  'concurrent selection creates one active provisional binding only'
);
select is(
  (
    select pg_catalog.count(*)
    from app_private.billing_assignment_intents
    where household_id = '20000000-0000-4000-8000-000000000401'
  ),
  2::bigint,
  'winner and conflict each retain one idempotent aggregate result'
);
select results_eq(
  $$
    select outcome, pg_catalog.count(*)
    from app_private.billing_assignment_intents
    where household_id = '20000000-0000-4000-8000-000000000401'
    group by outcome
    order by outcome
  $$,
  $$ values
    ('household_conflict'::text, 1::bigint),
    ('ready'::text, 1::bigint)
  $$,
  'concurrent idempotency results match the serialized outcomes'
);
select is(
  (
    select pg_catalog.count(*)
    from app_private.billing_assignment_transitions
    where target_household_id =
      '20000000-0000-4000-8000-000000000401'
      and action = 'prepared'
  ),
  1::bigint,
  'only the winning prepare emits an assignment transition'
);

select * from finish();
rollback;

do $$
begin
  perform extensions.dblink_exec(
    'kinflow_assignment_lock',
    $cleanup$
      begin;
      reset role;
      alter table app_private.billing_assignment_transitions
        disable trigger billing_assignment_transitions_immutable;
      delete from app_private.billing_assignment_transitions
      where target_household_id =
        '20000000-0000-4000-8000-000000000401';
      alter table app_private.billing_assignment_transitions
        enable trigger billing_assignment_transitions_immutable;
      delete from app_private.billing_assignment_intents
      where household_id = '20000000-0000-4000-8000-000000000401';
      delete from public.billing_household_assignments
      where household_id = '20000000-0000-4000-8000-000000000401';
      delete from public.billing_customers
      where auth_user_id in (
        '00000000-0000-4000-8000-000000000101',
        '00000000-0000-4000-8000-000000000102'
      )
        and provider = 'revenuecat'
        and environment = 'sandbox';
      delete from public.household_members
      where household_id = '20000000-0000-4000-8000-000000000401';
      delete from public.households
      where id = '20000000-0000-4000-8000-000000000401';
      alter table app_private.billing_runtime_config
        disable trigger billing_runtime_config_set_updated_at_and_version;
      update app_private.billing_runtime_config as config
      set provider = backup.provider,
          accepted_environment = backup.accepted_environment,
          ingestion_enabled = backup.ingestion_enabled,
          updated_at = backup.updated_at,
          version = backup.version
      from kinflow_assignment_runtime_backup as backup
      where config.singleton = backup.singleton;
      alter table app_private.billing_runtime_config
        enable trigger billing_runtime_config_set_updated_at_and_version;
      commit;
    $cleanup$
  );
  perform extensions.dblink_disconnect('kinflow_assignment_lock');
  perform extensions.dblink_disconnect('kinflow_assignment_a');
  perform extensions.dblink_disconnect('kinflow_assignment_b');
end;
$$;

drop extension dblink;
