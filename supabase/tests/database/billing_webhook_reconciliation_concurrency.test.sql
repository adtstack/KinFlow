create extension if not exists dblink with schema extensions;

do $$
begin
  perform extensions.dblink_connect(
    'kinflow_billing_lock',
    'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres sslmode=disable'
  );
  perform extensions.dblink_exec(
    'kinflow_billing_lock',
    $setup$
      begin;
      insert into app_private.billing_reconciliation_jobs(
        id,
        source,
        provider_event_id,
        request_hash,
        api_version,
        event_type,
        auth_user_id,
        environment,
        provider_occurred_at,
        processing_status,
        next_attempt_at,
        received_at,
        last_received_at,
        updated_at,
        correlation_id
      ) values
        (
          '66100000-0000-4000-8000-000000000001',
          'webhook',
          'billing-concurrency-a',
          extensions.digest(
            pg_catalog.convert_to('billing-concurrency-a', 'UTF8'),
            'sha256'
          ),
          '1.0',
          'RENEWAL',
          '00000000-0000-4000-8000-000000000101',
          'sandbox',
          '2026-08-08 00:00:00+00',
          'queued',
          '2026-08-08 00:00:00+00',
          '2026-08-08 00:00:00+00',
          '2026-08-08 00:00:00+00',
          '2026-08-08 00:00:00+00',
          '66100000-0000-4000-8000-000000000011'
        ),
        (
          '66100000-0000-4000-8000-000000000002',
          'webhook',
          'billing-concurrency-b',
          extensions.digest(
            pg_catalog.convert_to('billing-concurrency-b', 'UTF8'),
            'sha256'
          ),
          '1.0',
          'RENEWAL',
          '00000000-0000-4000-8000-000000000101',
          'sandbox',
          '2026-08-08 00:00:01+00',
          'queued',
          '2026-08-08 00:00:01+00',
          '2026-08-08 00:00:01+00',
          '2026-08-08 00:00:01+00',
          '2026-08-08 00:00:01+00',
          '66100000-0000-4000-8000-000000000012'
        );
      commit;
    $setup$
  );
end;
$$;

begin;
set constraints all deferred;

select plan(7);

update app_private.billing_runtime_config
set accepted_environment = 'sandbox',
    ingestion_enabled = true;

select is(
  (
    select pg_catalog.count(*)
    from app_private.billing_reconciliation_jobs
    where id in (
      '66100000-0000-4000-8000-000000000001',
      '66100000-0000-4000-8000-000000000002'
    )
      and processing_status = 'queued'
  ),
  2::bigint,
  'two committed due jobs are visible to competing reconciliation workers'
);

do $$
begin
  perform extensions.dblink_exec('kinflow_billing_lock', 'begin');
  perform extensions.dblink_exec(
    'kinflow_billing_lock',
    $lock$
      do $locked$
      begin
        perform job.id
        from app_private.billing_reconciliation_jobs as job
        where job.id = '66100000-0000-4000-8000-000000000001'
        for update;
      end;
      $locked$;
    $lock$
  );
end;
$$;

select is(
  (
    select processing_status
    from app_private.billing_reconciliation_jobs
    where id = '66100000-0000-4000-8000-000000000001'
  ),
  'queued',
  'externally locked head job remains queued for ordinary reads'
);

create temporary table billing_concurrency_claims (
  claim_order integer not null,
  job_id uuid primary key,
  lease_token uuid not null,
  auth_user_id uuid not null,
  environment text not null,
  provider_occurred_at timestamptz not null,
  household_id uuid,
  attempt_count integer not null
);

insert into billing_concurrency_claims
select 1, claim.*
from public.claim_billing_reconciliation_jobs(
  '66100000-0000-4000-8000-000000000021',
  1,
  60,
  '2026-08-08 00:01:00+00'
) as claim;

select is(
  (
    select job_id
    from billing_concurrency_claims
    where claim_order = 1
  ),
  '66100000-0000-4000-8000-000000000002'::uuid,
  'first worker skips the locked head job and fills its bounded batch'
);
select is(
  (
    select pg_catalog.count(*)
    from app_private.billing_reconciliation_transitions
    where job_id = '66100000-0000-4000-8000-000000000002'
      and transition = 'claimed'
      and attempt = 1
  ),
  1::bigint,
  'unlocked job records one independent attempt-one claim transition'
);

do $$
begin
  perform extensions.dblink_exec('kinflow_billing_lock', 'rollback');
end;
$$;

insert into billing_concurrency_claims
select 2, claim.*
from public.claim_billing_reconciliation_jobs(
  '66100000-0000-4000-8000-000000000022',
  1,
  60,
  '2026-08-08 00:01:01+00'
) as claim;

select is(
  (
    select job_id
    from billing_concurrency_claims
    where claim_order = 2
  ),
  '66100000-0000-4000-8000-000000000001'::uuid,
  'next worker claims the previously locked head job after release'
);
select is(
  (
    select concat_ws(
      ':',
      pg_catalog.count(*),
      pg_catalog.count(distinct job_id),
      pg_catalog.count(distinct lease_token),
      pg_catalog.min(attempt_count),
      pg_catalog.max(attempt_count)
    )
    from billing_concurrency_claims
  ),
  '2:2:2:1:1',
  'competing workers receive unique jobs and opaque leases at attempt one'
);
select is(
  (
    select pg_catalog.count(*)
    from app_private.billing_reconciliation_jobs
    where id in (
      '66100000-0000-4000-8000-000000000001',
      '66100000-0000-4000-8000-000000000002'
    )
      and processing_status = 'leased'
      and attempts = 1
  ),
  2::bigint,
  'both jobs finish the competition leased exactly once'
);

select * from finish();
rollback;

do $$
begin
  perform extensions.dblink_exec(
    'kinflow_billing_lock',
    $cleanup$
      alter table app_private.billing_reconciliation_transitions
        disable trigger billing_reconciliation_transitions_immutable;
      delete from app_private.billing_reconciliation_transitions
      where job_id in (
        '66100000-0000-4000-8000-000000000001',
        '66100000-0000-4000-8000-000000000002'
      );
      alter table app_private.billing_reconciliation_transitions
        enable trigger billing_reconciliation_transitions_immutable;
      delete from app_private.billing_reconciliation_jobs
      where id in (
        '66100000-0000-4000-8000-000000000001',
        '66100000-0000-4000-8000-000000000002'
      );
    $cleanup$
  );
  perform extensions.dblink_disconnect('kinflow_billing_lock');
end;
$$;

drop extension dblink;
