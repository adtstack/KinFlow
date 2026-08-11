-- KinFlow WP08-04B capability-specific Android runtime mutation policy.
--
-- Global compatibility/update policy remains the first authority. Existing
-- product capabilities are explicitly compatibility-open, while missing or
-- unknown feature policy fails closed for direct and Edge-forwarded user work.

create table app_private.app_runtime_feature_policies (
  environment text not null check (environment in ('dev', 'prod')),
  platform text not null check (platform = 'android'),
  feature text not null check (feature in (
    'household',
    'chores',
    'calendar',
    'notifications',
    'profile',
    'billing'
  )),
  mutations_enabled boolean not null default true,
  version bigint not null default 1 check (version > 0),
  updated_at timestamptz not null default pg_catalog.now(),
  primary key (environment, platform, feature)
);

insert into app_private.app_runtime_feature_policies(
  environment,
  platform,
  feature
)
select environment, 'android', feature
from unnest(array['dev', 'prod']) as environment
cross join unnest(array[
  'household',
  'chores',
  'calendar',
  'notifications',
  'profile',
  'billing'
]) as feature;

create table app_private.app_runtime_feature_policy_events (
  id bigint generated always as identity primary key,
  environment text not null check (environment in ('dev', 'prod')),
  platform text not null check (platform = 'android'),
  feature text not null check (feature in (
    'household',
    'chores',
    'calendar',
    'notifications',
    'profile',
    'billing'
  )),
  mutations_enabled boolean not null,
  policy_version bigint not null check (policy_version > 1),
  correlation_id uuid not null unique,
  changed_at timestamptz not null default pg_catalog.now()
);

revoke all on table app_private.app_runtime_feature_policies
  from public, anon, authenticated, service_role;
revoke all on table app_private.app_runtime_feature_policy_events
  from public, anon, authenticated, service_role;
revoke all on sequence app_private.app_runtime_feature_policy_events_id_seq
  from public, anon, authenticated, service_role;

create trigger app_runtime_feature_policies_set_version
before update on app_private.app_runtime_feature_policies
for each row execute function app_private.set_app_runtime_policy_version();

create trigger app_runtime_feature_policy_events_immutable
before update or delete on app_private.app_runtime_feature_policy_events
for each row execute function
  app_private.reject_app_runtime_policy_event_mutation();

create or replace function public.get_app_runtime_feature_policies(
  p_environment text,
  p_platform text
)
returns table (
  environment text,
  platform text,
  feature text,
  mutations_enabled boolean,
  policy_version bigint,
  updated_at timestamptz,
  evaluated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
volatile
as $$
declare
  v_count bigint;
  v_evaluated_at timestamptz := pg_catalog.clock_timestamp();
begin
  if p_environment is null
    or p_environment not in ('dev', 'prod')
    or p_platform is null
    or p_platform <> 'android' then
    raise exception using
      errcode = '22023',
      message = 'invalid app runtime feature policy scope';
  end if;

  select pg_catalog.count(*)
  into v_count
  from app_private.app_runtime_feature_policies as policy
  where policy.environment = p_environment
    and policy.platform = p_platform;

  if v_count <> 6 then
    raise exception using
      errcode = 'KFR03',
      message = 'app runtime policy unavailable';
  end if;

  return query
  select
    policy.environment,
    policy.platform,
    policy.feature,
    policy.mutations_enabled,
    policy.version,
    policy.updated_at,
    v_evaluated_at
  from app_private.app_runtime_feature_policies as policy
  where policy.environment = p_environment
    and policy.platform = p_platform
  order by policy.feature;
end;
$$;

revoke all on function public.get_app_runtime_feature_policies(text, text)
  from public;
grant execute on function public.get_app_runtime_feature_policies(text, text)
  to anon, authenticated;

create or replace function public.configure_app_runtime_feature_policy(
  p_environment text,
  p_platform text,
  p_feature text,
  p_mutations_enabled boolean,
  p_expected_version bigint,
  p_correlation_id uuid
)
returns table (
  environment text,
  platform text,
  feature text,
  mutations_enabled boolean,
  policy_version bigint,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing app_private.app_runtime_feature_policy_events%rowtype;
  v_previous_version bigint;
  v_next app_private.app_runtime_feature_policies%rowtype;
begin
  if p_environment is null
    or p_environment not in ('dev', 'prod')
    or p_platform is null
    or p_platform <> 'android'
    or p_feature is null
    or p_feature not in (
      'household',
      'chores',
      'calendar',
      'notifications',
      'profile',
      'billing'
    )
    or p_mutations_enabled is null
    or p_expected_version is null
    or p_expected_version < 1
    or p_correlation_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid app runtime feature policy configuration';
  end if;

  select event.*
  into v_existing
  from app_private.app_runtime_feature_policy_events as event
  where event.correlation_id = p_correlation_id;

  if found then
    if v_existing.environment <> p_environment
      or v_existing.platform <> p_platform
      or v_existing.feature <> p_feature
      or v_existing.mutations_enabled <> p_mutations_enabled then
      raise exception using
        errcode = 'KFR05',
        message = 'app runtime feature policy correlation reused';
    end if;

    return query select
      v_existing.environment,
      v_existing.platform,
      v_existing.feature,
      v_existing.mutations_enabled,
      v_existing.policy_version,
      v_existing.changed_at;
    return;
  end if;

  select policy.version
  into v_previous_version
  from app_private.app_runtime_feature_policies as policy
  where policy.environment = p_environment
    and policy.platform = p_platform
    and policy.feature = p_feature
  for update;

  if not found then
    raise exception using
      errcode = 'KFR03',
      message = 'app runtime policy unavailable';
  end if;

  if v_previous_version <> p_expected_version then
    raise exception using
      errcode = 'KFR04',
      message = 'app runtime feature policy version conflict';
  end if;

  update app_private.app_runtime_feature_policies as policy
  set mutations_enabled = p_mutations_enabled
  where policy.environment = p_environment
    and policy.platform = p_platform
    and policy.feature = p_feature
  returning policy.* into v_next;

  insert into app_private.app_runtime_feature_policy_events(
    environment,
    platform,
    feature,
    mutations_enabled,
    policy_version,
    correlation_id,
    changed_at
  ) values (
    v_next.environment,
    v_next.platform,
    v_next.feature,
    v_next.mutations_enabled,
    v_next.version,
    p_correlation_id,
    v_next.updated_at
  );

  return query select
    v_next.environment,
    v_next.platform,
    v_next.feature,
    v_next.mutations_enabled,
    v_next.version,
    v_next.updated_at;
end;
$$;

revoke all on function public.configure_app_runtime_feature_policy(
  text,
  text,
  text,
  boolean,
  bigint,
  uuid
) from public, anon, authenticated;
grant execute on function public.configure_app_runtime_feature_policy(
  text,
  text,
  text,
  boolean,
  bigint,
  uuid
) to service_role;

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
  v_feature text;
  v_feature_policy app_private.app_runtime_feature_policies%rowtype;
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

  v_feature := case when tg_nargs = 1 then tg_argv[0] else null end;
  if v_feature is null
    or v_feature not in (
      'household',
      'chores',
      'calendar',
      'notifications',
      'profile',
      'billing'
    ) then
    raise exception using
      errcode = 'KFR03',
      message = 'app runtime policy unavailable';
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

  if pg_catalog.current_setting(
    'app.runtime_policy_checked',
    true
  ) is distinct from 'allowed' then
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
  end if;

  if pg_catalog.current_setting(
    'app.runtime_policy_feature_checked_' || v_feature,
    true
  ) = 'allowed' then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  select policy.*
  into v_feature_policy
  from app_private.app_runtime_feature_policies as policy
  where policy.environment = v_environment
    and policy.platform = v_platform
    and policy.feature = v_feature;

  if not found then
    raise exception using
      errcode = 'KFR03',
      message = 'app runtime policy unavailable';
  end if;

  if not v_feature_policy.mutations_enabled then
    raise exception using
      errcode = 'KFR06',
      message = 'client feature disabled';
  end if;

  perform pg_catalog.set_config(
    'app.runtime_policy_feature_checked_' || v_feature,
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
  v_feature text;
  v_table text;
begin
  for v_table, v_feature in
    select mapping.table_name, mapping.feature
    from (values
      ('profiles', 'profile'),
      ('households', 'household'),
      ('household_members', 'household'),
      ('user_active_households', 'household'),
      ('household_invites', 'household'),
      ('chore_series', 'chores'),
      ('chore_series_revisions', 'chores'),
      ('chore_occurrences', 'chores'),
      ('chore_completion_events', 'chores'),
      ('chore_reschedule_events', 'chores'),
      ('chore_assignment_events', 'chores'),
      ('chore_series_change_events', 'chores'),
      ('one_time_chore_change_events', 'chores'),
      ('event_series', 'calendar'),
      ('event_series_revisions', 'calendar'),
      ('event_participants', 'calendar'),
      ('event_occurrences', 'calendar'),
      ('event_revision_participants', 'calendar'),
      ('event_occurrence_exceptions', 'calendar'),
      ('event_series_change_events', 'calendar'),
      ('calendar_sync_watermarks', 'calendar'),
      ('notification_preferences', 'notifications'),
      ('notification_inbox_items', 'notifications'),
      ('notification_endpoints', 'notifications'),
      ('billing_customers', 'billing'),
      ('billing_webhook_receipts', 'billing'),
      ('billing_transactions', 'billing'),
      ('billing_household_assignments', 'billing'),
      ('plan_catalog', 'billing'),
      ('household_entitlements', 'billing')
    ) as mapping(table_name, feature)
  loop
    execute pg_catalog.format(
      'drop trigger if exists app_runtime_policy_guard on public.%I',
      v_table
    );
    execute pg_catalog.format(
      'create trigger app_runtime_policy_guard '
      'before insert or update or delete on public.%I '
      'for each row execute function '
      'app_private.enforce_app_runtime_policy(%L)',
      v_table,
      v_feature
    );
  end loop;
end;
$$;

comment on table app_private.app_runtime_feature_policies is
  'WP08-04B exact capability mutation availability by environment/platform.';
comment on table app_private.app_runtime_feature_policy_events is
  'WP08-04B immutable content-free capability policy mutation audit.';
comment on function public.get_app_runtime_feature_policies(text, text) is
  'Returns the exact six content-free capability policies to clients.';
comment on function public.configure_app_runtime_feature_policy(
  text,
  text,
  text,
  boolean,
  bigint,
  uuid
) is
  'Service-only optimistic and idempotent capability policy mutation.';
comment on function app_private.enforce_app_runtime_policy() is
  'Enforces global compatibility first and exact trigger-classified capability policy second.';
