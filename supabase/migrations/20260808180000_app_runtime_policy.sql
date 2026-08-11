-- KinFlow WP08-04A server-authoritative Android runtime policy.
--
-- The client banner is advisory. Authenticated product mutations are checked
-- again at the database boundary while reads and privacy/export lifecycles
-- remain available. Compatibility headers are not an authorization boundary.

create table app_private.app_runtime_policies (
  environment text not null check (environment in ('dev', 'prod')),
  platform text not null check (platform = 'android'),
  minimum_supported_version text not null default '0.0.0' check (
    pg_catalog.char_length(minimum_supported_version) between 5 and 64
    and minimum_supported_version ~
      '^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$'
  ),
  minimum_supported_build bigint not null default 0 check (
    minimum_supported_build between 0 and 2147483647
  ),
  minimum_contract_version date,
  maximum_contract_version date,
  mutations_enabled boolean not null default true,
  version bigint not null default 1 check (version > 0),
  updated_at timestamptz not null default pg_catalog.now(),
  primary key (environment, platform),
  constraint app_runtime_policy_version_build_ck check (
    minimum_supported_build > 0
    or minimum_supported_version = '0.0.0'
  ),
  constraint app_runtime_policy_contract_range_ck check (
    minimum_contract_version is null
    or maximum_contract_version is null
    or minimum_contract_version <= maximum_contract_version
  )
);

insert into app_private.app_runtime_policies(environment, platform)
values ('dev', 'android'), ('prod', 'android');

create table app_private.app_runtime_policy_events (
  id bigint generated always as identity primary key,
  environment text not null check (environment in ('dev', 'prod')),
  platform text not null check (platform = 'android'),
  minimum_supported_version text not null check (
    pg_catalog.char_length(minimum_supported_version) between 5 and 64
    and minimum_supported_version ~
      '^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$'
  ),
  minimum_supported_build bigint not null check (
    minimum_supported_build between 0 and 2147483647
  ),
  minimum_contract_version date,
  maximum_contract_version date,
  mutations_enabled boolean not null,
  policy_version bigint not null check (policy_version > 1),
  correlation_id uuid not null unique,
  changed_at timestamptz not null default pg_catalog.now(),
  constraint app_runtime_policy_event_version_build_ck check (
    minimum_supported_build > 0
    or minimum_supported_version = '0.0.0'
  ),
  constraint app_runtime_policy_event_contract_range_ck check (
    minimum_contract_version is null
    or maximum_contract_version is null
    or minimum_contract_version <= maximum_contract_version
  )
);

revoke all on table app_private.app_runtime_policies
  from public, anon, authenticated, service_role;
revoke all on table app_private.app_runtime_policy_events
  from public, anon, authenticated, service_role;
revoke all on sequence app_private.app_runtime_policy_events_id_seq
  from public, anon, authenticated, service_role;

create or replace function app_private.set_app_runtime_policy_version()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.version := old.version + 1;
  new.updated_at := pg_catalog.now();
  return new;
end;
$$;

revoke all on function app_private.set_app_runtime_policy_version()
  from public, anon, authenticated, service_role;

create trigger app_runtime_policies_set_version
before update on app_private.app_runtime_policies
for each row execute function app_private.set_app_runtime_policy_version();

create or replace function app_private.reject_app_runtime_policy_event_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = '42501',
    message = 'app runtime policy events are immutable';
end;
$$;

revoke all on function app_private.reject_app_runtime_policy_event_mutation()
  from public, anon, authenticated, service_role;

create trigger app_runtime_policy_events_immutable
before update or delete on app_private.app_runtime_policy_events
for each row execute function
  app_private.reject_app_runtime_policy_event_mutation();

create or replace function public.get_app_runtime_policy(
  p_environment text,
  p_platform text
)
returns table (
  environment text,
  platform text,
  minimum_supported_version text,
  minimum_supported_build bigint,
  minimum_contract_version text,
  maximum_contract_version text,
  mutations_enabled boolean,
  policy_version bigint,
  updated_at timestamptz,
  evaluated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
stable
as $$
declare
  v_evaluated_at timestamptz := pg_catalog.clock_timestamp();
begin
  if p_environment not in ('dev', 'prod')
    or p_platform <> 'android' then
    raise exception using
      errcode = '22023',
      message = 'invalid app runtime policy scope';
  end if;

  return query
  select
    policy.environment,
    policy.platform,
    policy.minimum_supported_version,
    policy.minimum_supported_build,
    pg_catalog.to_char(policy.minimum_contract_version, 'YYYY-MM-DD'),
    pg_catalog.to_char(policy.maximum_contract_version, 'YYYY-MM-DD'),
    policy.mutations_enabled,
    policy.version,
    policy.updated_at,
    v_evaluated_at
  from app_private.app_runtime_policies as policy
  where policy.environment = p_environment
    and policy.platform = p_platform;

  if not found then
    raise exception using
      errcode = 'KFR03',
      message = 'app runtime policy unavailable';
  end if;
end;
$$;

revoke all on function public.get_app_runtime_policy(text, text)
  from public;
grant execute on function public.get_app_runtime_policy(text, text)
  to anon, authenticated;

create or replace function public.configure_app_runtime_policy(
  p_environment text,
  p_platform text,
  p_minimum_supported_version text,
  p_minimum_supported_build bigint,
  p_minimum_contract_version date,
  p_maximum_contract_version date,
  p_mutations_enabled boolean,
  p_expected_version bigint,
  p_correlation_id uuid
)
returns table (
  environment text,
  platform text,
  minimum_supported_version text,
  minimum_supported_build bigint,
  minimum_contract_version text,
  maximum_contract_version text,
  mutations_enabled boolean,
  policy_version bigint,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing app_private.app_runtime_policy_events%rowtype;
  v_previous_version bigint;
  v_next app_private.app_runtime_policies%rowtype;
begin
  if p_environment not in ('dev', 'prod')
    or p_platform <> 'android'
    or p_minimum_supported_version is null
    or pg_catalog.char_length(p_minimum_supported_version) not between 5 and 64
    or p_minimum_supported_version !~
      '^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$'
    or p_minimum_supported_build is null
    or p_minimum_supported_build not between 0 and 2147483647
    or (
      p_minimum_supported_build = 0
      and p_minimum_supported_version <> '0.0.0'
    )
    or (
      p_minimum_contract_version is not null
      and p_maximum_contract_version is not null
      and p_minimum_contract_version > p_maximum_contract_version
    )
    or p_mutations_enabled is null
    or p_expected_version is null
    or p_expected_version < 1
    or p_correlation_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid app runtime policy configuration';
  end if;

  select event.*
  into v_existing
  from app_private.app_runtime_policy_events as event
  where event.correlation_id = p_correlation_id;

  if found then
    if v_existing.environment <> p_environment
      or v_existing.platform <> p_platform
      or v_existing.minimum_supported_version <>
        p_minimum_supported_version
      or v_existing.minimum_supported_build <> p_minimum_supported_build
      or v_existing.minimum_contract_version is distinct from
        p_minimum_contract_version
      or v_existing.maximum_contract_version is distinct from
        p_maximum_contract_version
      or v_existing.mutations_enabled <> p_mutations_enabled then
      raise exception using
        errcode = 'KFR05',
        message = 'app runtime policy correlation reused';
    end if;

    return query select
      v_existing.environment,
      v_existing.platform,
      v_existing.minimum_supported_version,
      v_existing.minimum_supported_build,
      pg_catalog.to_char(
        v_existing.minimum_contract_version,
        'YYYY-MM-DD'
      ),
      pg_catalog.to_char(
        v_existing.maximum_contract_version,
        'YYYY-MM-DD'
      ),
      v_existing.mutations_enabled,
      v_existing.policy_version,
      v_existing.changed_at;
    return;
  end if;

  select policy.version
  into v_previous_version
  from app_private.app_runtime_policies as policy
  where policy.environment = p_environment
    and policy.platform = p_platform
  for update;

  if not found then
    raise exception using
      errcode = 'KFR03',
      message = 'app runtime policy unavailable';
  end if;

  if v_previous_version <> p_expected_version then
    raise exception using
      errcode = 'KFR04',
      message = 'app runtime policy version conflict';
  end if;

  update app_private.app_runtime_policies as policy
  set minimum_supported_version = p_minimum_supported_version,
      minimum_supported_build = p_minimum_supported_build,
      minimum_contract_version = p_minimum_contract_version,
      maximum_contract_version = p_maximum_contract_version,
      mutations_enabled = p_mutations_enabled
  where policy.environment = p_environment
    and policy.platform = p_platform
  returning policy.* into v_next;

  insert into app_private.app_runtime_policy_events(
    environment,
    platform,
    minimum_supported_version,
    minimum_supported_build,
    minimum_contract_version,
    maximum_contract_version,
    mutations_enabled,
    policy_version,
    correlation_id,
    changed_at
  ) values (
    v_next.environment,
    v_next.platform,
    v_next.minimum_supported_version,
    v_next.minimum_supported_build,
    v_next.minimum_contract_version,
    v_next.maximum_contract_version,
    v_next.mutations_enabled,
    v_next.version,
    p_correlation_id,
    v_next.updated_at
  );

  return query select
    v_next.environment,
    v_next.platform,
    v_next.minimum_supported_version,
    v_next.minimum_supported_build,
    pg_catalog.to_char(v_next.minimum_contract_version, 'YYYY-MM-DD'),
    pg_catalog.to_char(v_next.maximum_contract_version, 'YYYY-MM-DD'),
    v_next.mutations_enabled,
    v_next.version,
    v_next.updated_at;
end;
$$;

revoke all on function public.configure_app_runtime_policy(
  text,
  text,
  text,
  bigint,
  date,
  date,
  boolean,
  bigint,
  uuid
) from public, anon, authenticated;
grant execute on function public.configure_app_runtime_policy(
  text,
  text,
  text,
  bigint,
  date,
  date,
  boolean,
  bigint,
  uuid
) to service_role;

create or replace function app_private.app_runtime_request_header(
  p_name text
)
returns text
language plpgsql
security definer
set search_path = ''
stable
as $$
declare
  v_headers jsonb;
  v_raw text := pg_catalog.current_setting('request.headers', true);
begin
  if p_name is null
    or p_name !~ '^[a-z][a-z0-9-]{0,63}$'
    or v_raw is null
    or v_raw = '' then
    return null;
  end if;

  begin
    v_headers := v_raw::jsonb;
  exception when others then
    return null;
  end;

  return v_headers ->> p_name;
end;
$$;

revoke all on function app_private.app_runtime_request_header(text)
  from public, anon, authenticated, service_role;

create or replace function app_private.enforce_app_runtime_policy()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_build bigint;
  v_build_text text;
  v_contract date;
  v_contract_text text;
  v_environment text;
  v_forwarded boolean;
  v_platform text;
  v_policy app_private.app_runtime_policies%rowtype;
  v_version_text text;
begin
  v_forwarded := coalesce(
    app_private.app_runtime_request_header(
      'x-kinflow-forwarded-user-operation'
    ) = '1',
    false
  );
  if (select auth.uid()) is null and not v_forwarded then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  if pg_catalog.current_setting(
    'app.runtime_policy_checked',
    true
  ) = 'allowed' then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  v_environment := coalesce(
    app_private.app_runtime_request_header('x-kinflow-environment'),
    'prod'
  );
  v_platform := coalesce(
    app_private.app_runtime_request_header('x-kinflow-platform'),
    'android'
  );
  v_build_text := coalesce(
    app_private.app_runtime_request_header('x-kinflow-client-build'),
    '0'
  );
  v_contract_text := app_private.app_runtime_request_header(
    'x-kinflow-contract-version'
  );
  v_version_text := app_private.app_runtime_request_header(
    'x-kinflow-client-version'
  );

  if v_environment not in ('dev', 'prod')
    or v_platform <> 'android'
    or v_build_text !~ '^(0|[1-9][0-9]{0,9})$'
    or (
      v_contract_text is not null
      and v_contract_text !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    )
    or (
      v_version_text is not null
      and (
        pg_catalog.char_length(v_version_text) not between 5 and 64
        or v_version_text !~
          '^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9]+)?$'
      )
    ) then
    raise exception using
      errcode = 'KFR03',
      message = 'app runtime policy unavailable';
  end if;

  v_build := v_build_text::bigint;
  if v_build > 2147483647 then
    raise exception using
      errcode = 'KFR03',
      message = 'app runtime policy unavailable';
  end if;

  if v_contract_text is not null then
    begin
      v_contract := v_contract_text::date;
    exception when others then
      raise exception using
        errcode = 'KFR03',
        message = 'app runtime policy unavailable';
    end;
    if pg_catalog.to_char(v_contract, 'YYYY-MM-DD') <> v_contract_text then
      raise exception using
        errcode = 'KFR03',
        message = 'app runtime policy unavailable';
    end if;
  end if;

  select policy.*
  into v_policy
  from app_private.app_runtime_policies as policy
  where policy.environment = v_environment
    and policy.platform = v_platform;

  if not found then
    raise exception using
      errcode = 'KFR03',
      message = 'app runtime policy unavailable';
  end if;

  if v_build < v_policy.minimum_supported_build
    or (
      v_policy.minimum_contract_version is not null
      and (
        v_contract is null
        or v_contract < v_policy.minimum_contract_version
      )
    )
    or (
      v_policy.maximum_contract_version is not null
      and (
        v_contract is null
        or v_contract > v_policy.maximum_contract_version
      )
    ) then
    raise exception using
      errcode = 'KFR01',
      message = 'client update required';
  end if;

  if not v_policy.mutations_enabled then
    raise exception using
      errcode = 'KFR02',
      message = 'client mutations disabled';
  end if;

  perform pg_catalog.set_config(
    'app.runtime_policy_checked',
    'allowed',
    true
  );
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

revoke all on function app_private.enforce_app_runtime_policy()
  from public, anon, authenticated, service_role;

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'profiles',
    'households',
    'household_members',
    'user_active_households',
    'household_invites',
    'chore_series',
    'chore_series_revisions',
    'chore_occurrences',
    'chore_completion_events',
    'chore_reschedule_events',
    'chore_assignment_events',
    'chore_series_change_events',
    'one_time_chore_change_events',
    'event_series',
    'event_series_revisions',
    'event_participants',
    'event_occurrences',
    'event_revision_participants',
    'event_occurrence_exceptions',
    'event_series_change_events',
    'calendar_sync_watermarks',
    'notification_preferences',
    'notification_inbox_items',
    'notification_endpoints',
    'billing_customers',
    'billing_webhook_receipts',
    'billing_transactions',
    'billing_household_assignments',
    'plan_catalog',
    'household_entitlements'
  ] loop
    execute pg_catalog.format(
      'create trigger app_runtime_policy_guard '
      'before insert or update or delete on public.%I '
      'for each row execute function '
      'app_private.enforce_app_runtime_policy()',
      v_table
    );
  end loop;
end;
$$;

comment on table app_private.app_runtime_policies is
  'WP08-04A environment/platform runtime compatibility and mutation policy.';
comment on table app_private.app_runtime_policy_events is
  'WP08-04A immutable content-free runtime policy mutation audit.';
comment on function public.get_app_runtime_policy(text, text) is
  'Returns the exact content-free runtime policy to anon/authenticated clients.';
comment on function public.configure_app_runtime_policy(
  text,
  text,
  text,
  bigint,
  date,
  date,
  boolean,
  bigint,
  uuid
) is
  'Service-only optimistic and idempotent runtime policy mutation.';
