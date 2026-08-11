-- KinFlow WP01-12 Web Companion runtime policy baseline.
--
-- Web uses the same server-authoritative compatibility and capability gates as
-- Android, but keeps an independent environment/platform policy scope. The
-- existing policy functions are rewritten in place so grants, signatures,
-- error codes, idempotency, and optimistic concurrency remain unchanged.

alter table app_private.app_runtime_policies
  drop constraint app_runtime_policies_platform_check,
  add constraint app_runtime_policies_platform_check
    check (platform in ('android', 'web'));

alter table app_private.app_runtime_policy_events
  drop constraint app_runtime_policy_events_platform_check,
  add constraint app_runtime_policy_events_platform_check
    check (platform in ('android', 'web'));

alter table app_private.app_runtime_feature_policies
  drop constraint app_runtime_feature_policies_platform_check,
  add constraint app_runtime_feature_policies_platform_check
    check (platform in ('android', 'web'));

alter table app_private.app_runtime_feature_policy_events
  drop constraint app_runtime_feature_policy_events_platform_check,
  add constraint app_runtime_feature_policy_events_platform_check
    check (platform in ('android', 'web'));

insert into app_private.app_runtime_policies(environment, platform)
values ('dev', 'web'), ('prod', 'web')
on conflict (environment, platform) do nothing;

insert into app_private.app_runtime_feature_policies(
  environment,
  platform,
  feature
)
select environment, 'web', feature
from unnest(array['dev', 'prod']) as environment
cross join unnest(array[
  'household',
  'chores',
  'calendar',
  'notifications',
  'profile',
  'billing'
]) as feature
on conflict (environment, platform, feature) do nothing;

do $migration$
declare
  v_definition text;
  v_updated text;
begin
  v_definition := pg_catalog.pg_get_functiondef(
    'public.get_app_runtime_policy(text,text)'::regprocedure
  );
  v_updated := pg_catalog.replace(
    v_definition,
    'p_platform <> ''android''',
    'p_platform not in (''android'', ''web'')'
  );
  if v_updated = v_definition then
    raise exception 'get_app_runtime_policy platform guard not found';
  end if;
  execute v_updated;

  v_definition := pg_catalog.pg_get_functiondef(
    'public.configure_app_runtime_policy(text,text,text,bigint,date,date,boolean,bigint,uuid)'::regprocedure
  );
  v_updated := pg_catalog.replace(
    v_definition,
    'p_platform <> ''android''',
    'p_platform not in (''android'', ''web'')'
  );
  if v_updated = v_definition then
    raise exception 'configure_app_runtime_policy platform guard not found';
  end if;
  execute v_updated;

  v_definition := pg_catalog.pg_get_functiondef(
    'public.get_app_runtime_feature_policies(text,text)'::regprocedure
  );
  v_updated := pg_catalog.replace(
    v_definition,
    'p_platform <> ''android''',
    'p_platform not in (''android'', ''web'')'
  );
  if v_updated = v_definition then
    raise exception 'get_app_runtime_feature_policies platform guard not found';
  end if;
  execute v_updated;

  v_definition := pg_catalog.pg_get_functiondef(
    'public.configure_app_runtime_feature_policy(text,text,text,boolean,bigint,uuid)'::regprocedure
  );
  v_updated := pg_catalog.replace(
    v_definition,
    'p_platform <> ''android''',
    'p_platform not in (''android'', ''web'')'
  );
  if v_updated = v_definition then
    raise exception 'configure_app_runtime_feature_policy platform guard not found';
  end if;
  execute v_updated;

  v_definition := pg_catalog.pg_get_functiondef(
    'app_private.enforce_app_runtime_policy()'::regprocedure
  );
  v_updated := pg_catalog.replace(
    v_definition,
    'v_platform <> ''android''',
    'v_platform not in (''android'', ''web'')'
  );
  if v_updated = v_definition then
    raise exception 'enforce_app_runtime_policy platform guard not found';
  end if;
  execute v_updated;
end;
$migration$;

comment on table app_private.app_runtime_policies is
  'WP08-04A/WP01-12 environment/platform runtime compatibility and mutation policy for Android and Web.';
comment on table app_private.app_runtime_feature_policies is
  'WP08-04B/WP01-12 exact capability mutation availability by environment/platform for Android and Web.';
comment on function app_private.enforce_app_runtime_policy() is
  'Enforces Android/Web global compatibility first and exact trigger-classified capability policy second.';
