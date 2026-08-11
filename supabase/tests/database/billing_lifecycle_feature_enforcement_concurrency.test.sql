create extension if not exists dblink with schema extensions;

do $$
begin
  perform extensions.dblink_connect(
    'kinflow_feature_lock',
    'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres sslmode=disable'
  );
  perform extensions.dblink_connect(
    'kinflow_feature_a',
    'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres sslmode=disable'
  );
  perform extensions.dblink_connect(
    'kinflow_feature_b',
    'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres sslmode=disable'
  );
  perform extensions.dblink_exec(
    'kinflow_feature_lock',
    $setup$
      begin;
      set constraints all deferred;
      create temporary table kinflow_feature_runtime_backup
      on commit preserve rows as
      select * from app_private.billing_runtime_config;
      create temporary table kinflow_feature_plan_backup
      on commit preserve rows as
      select * from public.plan_catalog;

      update public.plan_catalog
      set feature_limits = case plan_code
            when 'free' then '{"members":2,"activeSeries":1}'::jsonb
            else '{"members":4,"activeSeries":3}'::jsonb
          end,
          limits_finalized = true;
      update app_private.billing_runtime_config
      set feature_enforcement_enabled = true;

      insert into auth.users(
        instance_id,
        id,
        aud,
        role,
        email,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at
      ) values
        (
          '00000000-0000-0000-0000-000000000000',
          '00000000-0000-4000-8000-000000000401',
          'authenticated',
          'authenticated',
          'feature-concurrent-owner@local.kinflow.invalid',
          pg_catalog.now(),
          '{}'::jsonb,
          '{}'::jsonb,
          pg_catalog.now(),
          pg_catalog.now()
        ),
        (
          '00000000-0000-0000-0000-000000000000',
          '00000000-0000-4000-8000-000000000402',
          'authenticated',
          'authenticated',
          'feature-concurrent-a@local.kinflow.invalid',
          pg_catalog.now(),
          '{}'::jsonb,
          '{}'::jsonb,
          pg_catalog.now(),
          pg_catalog.now()
        ),
        (
          '00000000-0000-0000-0000-000000000000',
          '00000000-0000-4000-8000-000000000403',
          'authenticated',
          'authenticated',
          'feature-concurrent-b@local.kinflow.invalid',
          pg_catalog.now(),
          '{}'::jsonb,
          '{}'::jsonb,
          pg_catalog.now(),
          pg_catalog.now()
        );

      insert into public.households(
        id,
        name,
        timezone,
        owner_member_id,
        created_by_user_id
      ) values (
        '20000000-0000-4000-8000-000000000401',
        'Concurrent Feature Household',
        'UTC',
        '30000000-0000-4000-8000-000000000401',
        '00000000-0000-4000-8000-000000000401'
      );
      insert into public.household_members(
        id,
        household_id,
        auth_user_id,
        display_name,
        role,
        created_by_user_id
      ) values (
        '30000000-0000-4000-8000-000000000401',
        '20000000-0000-4000-8000-000000000401',
        '00000000-0000-4000-8000-000000000401',
        'Concurrent Feature Owner',
        'owner',
        '00000000-0000-4000-8000-000000000401'
      );

      create or replace function app_private.test_insert_feature_member(
        p_member_id uuid,
        p_user_id uuid,
        p_display_name text
      )
      returns text
      language plpgsql
      set search_path = ''
      as $body$
      begin
        insert into public.household_members(
          id,
          household_id,
          auth_user_id,
          display_name,
          role,
          created_by_user_id
        ) values (
          p_member_id,
          '20000000-0000-4000-8000-000000000401',
          p_user_id,
          p_display_name,
          'member',
          '00000000-0000-4000-8000-000000000401'
        );
        return 'inserted';
      exception
        when others then
          return sqlstate;
      end;
      $body$;
      commit;
    $setup$
  );
end;
$$;

begin;
set constraints all deferred;

select plan(6);

select is(
  (
    select pg_catalog.count(*)
    from public.household_members
    where household_id = '20000000-0000-4000-8000-000000000401'
      and removed_at is null
  ),
  1::bigint,
  'concurrent feature fixture starts with one of two member slots used'
);

do $$
begin
  perform extensions.dblink_exec('kinflow_feature_lock', 'begin');
  perform extensions.dblink_exec(
    'kinflow_feature_lock',
    $lock$
      do $body$
      begin
        perform pg_catalog.pg_advisory_xact_lock(
          pg_catalog.hashtextextended(
            'billing-feature:' ||
              '20000000-0000-4000-8000-000000000401' ||
              ':members',
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
    select pg_catalog.concat_ws(
      ':',
      extensions.dblink_send_query(
        'kinflow_feature_a',
        $$
          select app_private.test_insert_feature_member(
            '30000000-0000-4000-8000-000000000402',
            '00000000-0000-4000-8000-000000000402',
            'Concurrent Feature A'
          )
        $$
      ),
      extensions.dblink_send_query(
        'kinflow_feature_b',
        $$
          select app_private.test_insert_feature_member(
            '30000000-0000-4000-8000-000000000403',
            '00000000-0000-4000-8000-000000000403',
            'Concurrent Feature B'
          )
        $$
      )
    )
  ),
  '1:1',
  'both final-slot inserts queue behind the same feature lock'
);

do $$
begin
  perform extensions.dblink_exec('kinflow_feature_lock', 'rollback');
end;
$$;

do $$
declare
  v_outcome_a text;
  v_outcome_b text;
begin
  select result.outcome
  into v_outcome_a
  from extensions.dblink_get_result('kinflow_feature_a')
    as result(outcome text);
  select result.outcome
  into v_outcome_b
  from extensions.dblink_get_result('kinflow_feature_b')
    as result(outcome text);
  perform pg_catalog.set_config(
    'kinflow.test.feature_concurrency_outcomes',
    least(v_outcome_a, v_outcome_b) || ':' ||
      greatest(v_outcome_a, v_outcome_b),
    true
  );
end;
$$;

select is(
  current_setting('kinflow.test.feature_concurrency_outcomes'),
  'inserted:KFB12',
  'exactly one concurrent member wins and one receives the stable limit code'
);
select is(
  (
    select pg_catalog.count(*)
    from public.household_members
    where household_id = '20000000-0000-4000-8000-000000000401'
      and removed_at is null
  ),
  2::bigint,
  'serialized concurrent inserts cannot exceed the finalized limit'
);
select is(
  (
    select pg_catalog.count(*)
    from public.household_members
    where id in (
      '30000000-0000-4000-8000-000000000402',
      '30000000-0000-4000-8000-000000000403'
    )
  ),
  1::bigint,
  'only one candidate member row is committed'
);
select results_eq(
  $$
    select decision, current_usage, limit_value, remaining_after_delta
    from app_private.evaluate_household_feature_gate(
      '20000000-0000-4000-8000-000000000401',
      'members',
      1
    )
  $$,
  $$ values ('limit_reached'::text, 2::bigint, 2::bigint, 0::bigint) $$,
  'post-race aggregate gate agrees with the committed member count'
);

select * from finish();
rollback;

do $$
begin
  perform extensions.dblink_exec(
    'kinflow_feature_lock',
    $cleanup$
      begin;
      set constraints all deferred;
      drop function if exists app_private.test_insert_feature_member(
        uuid,
        uuid,
        text
      );
      delete from public.household_members
      where household_id = '20000000-0000-4000-8000-000000000401';
      delete from public.households
      where id = '20000000-0000-4000-8000-000000000401';
      delete from auth.users
      where id in (
        '00000000-0000-4000-8000-000000000401',
        '00000000-0000-4000-8000-000000000402',
        '00000000-0000-4000-8000-000000000403'
      );

      alter table app_private.billing_runtime_config
        disable trigger billing_runtime_config_set_updated_at_and_version;
      update app_private.billing_runtime_config as config
      set provider = backup.provider,
          accepted_environment = backup.accepted_environment,
          ingestion_enabled = backup.ingestion_enabled,
          feature_enforcement_enabled =
            backup.feature_enforcement_enabled,
          updated_at = backup.updated_at,
          version = backup.version
      from kinflow_feature_runtime_backup as backup
      where config.singleton = backup.singleton;
      alter table app_private.billing_runtime_config
        enable trigger billing_runtime_config_set_updated_at_and_version;

      alter table public.plan_catalog
        disable trigger plan_catalog_protect_enabled_feature_policy;
      alter table public.plan_catalog
        disable trigger plan_catalog_set_updated_at_and_version;
      update public.plan_catalog as catalog
      set feature_limits = backup.feature_limits,
          limits_finalized = backup.limits_finalized,
          active = backup.active,
          created_at = backup.created_at,
          updated_at = backup.updated_at,
          version = backup.version
      from kinflow_feature_plan_backup as backup
      where catalog.plan_code = backup.plan_code;
      alter table public.plan_catalog
        enable trigger plan_catalog_set_updated_at_and_version;
      alter table public.plan_catalog
        enable trigger plan_catalog_protect_enabled_feature_policy;
      commit;
    $cleanup$
  );
  perform extensions.dblink_disconnect('kinflow_feature_lock');
  perform extensions.dblink_disconnect('kinflow_feature_a');
  perform extensions.dblink_disconnect('kinflow_feature_b');
end;
$$;

drop extension dblink;
