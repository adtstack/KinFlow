-- KinFlow WP06-06 lifecycle-aware, policy-neutral feature enforcement.
--
-- D-027 numeric limits remain intentionally unset. A service operator must
-- finalize both plan policies and explicitly activate enforcement before the
-- member/recurring-series triggers become authoritative. The public gate stays
-- fail-closed while that activation is absent.

alter table app_private.billing_runtime_config
  add column feature_enforcement_enabled boolean not null default false;

create or replace function app_private.current_household_feature_usage(
  p_household_id uuid,
  p_feature_key text
)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_usage bigint;
begin
  if p_feature_key = 'members' then
    select pg_catalog.count(*)
    into v_usage
    from public.household_members as member
    where member.household_id = p_household_id
      and member.removed_at is null;
  elsif p_feature_key = 'activeSeries' then
    select
      (
        select pg_catalog.count(*)
        from public.chore_series as series
        join public.chore_series_revisions as revision
          on revision.household_id = series.household_id
         and revision.id = series.active_revision_id
        where series.household_id = p_household_id
          and series.deleted_at is null
          and revision.recurrence_rule <> '{"type":"once"}'::jsonb
      ) + (
        select pg_catalog.count(*)
        from public.event_series as series
        join public.event_series_revisions as revision
          on revision.household_id = series.household_id
         and revision.series_id = series.id
         and revision.id = series.active_revision_id
        where series.household_id = p_household_id
          and series.deleted_at is null
          and revision.recurrence_rule is not null
      )
    into v_usage;
  else
    raise exception using
      errcode = 'KFB11',
      message = 'unknown household feature key';
  end if;

  return v_usage;
end;
$$;

revoke all on function app_private.current_household_feature_usage(uuid, text)
  from public, anon, authenticated, service_role;

create or replace function app_private.protect_enabled_billing_plan_policy()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
    from app_private.billing_runtime_config as config
    where config.singleton
      and config.feature_enforcement_enabled
  ) and (
    not new.active
    or not new.limits_finalized
    or not new.feature_limits ? 'members'
    or not new.feature_limits ? 'activeSeries'
    or (new.feature_limits ->> 'members')::bigint < 1
  ) then
    raise exception using
      errcode = 'KFB41',
      message = 'enabled billing feature policy cannot be made incomplete';
  end if;

  return new;
end;
$$;

revoke all on function app_private.protect_enabled_billing_plan_policy()
  from public, anon, authenticated, service_role;

create trigger plan_catalog_protect_enabled_feature_policy
before update on public.plan_catalog
for each row execute function
  app_private.protect_enabled_billing_plan_policy();

create or replace function public.configure_billing_feature_enforcement(
  p_enabled boolean,
  p_expected_version bigint,
  p_correlation_id uuid
)
returns table (
  feature_enforcement_enabled boolean,
  version bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_previous_version bigint;
  v_free public.plan_catalog%rowtype;
  v_plus public.plan_catalog%rowtype;
  v_next app_private.billing_runtime_config%rowtype;
begin
  if p_enabled is null
    or p_expected_version is null
    or p_correlation_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid billing feature-enforcement configuration';
  end if;

  select config.version
  into v_previous_version
  from app_private.billing_runtime_config as config
  where config.singleton
  for update;

  if v_previous_version <> p_expected_version then
    raise exception using
      errcode = 'KFB30',
      message = 'billing runtime version conflict';
  end if;

  if p_enabled then
    select catalog.*
    into v_free
    from public.plan_catalog as catalog
    where catalog.plan_code = 'free'
    for share;

    select catalog.*
    into v_plus
    from public.plan_catalog as catalog
    where catalog.plan_code = 'plus'
    for share;

    if not v_free.active
      or not v_plus.active
      or not v_free.limits_finalized
      or not v_plus.limits_finalized
      or not v_free.feature_limits ? 'members'
      or not v_free.feature_limits ? 'activeSeries'
      or not v_plus.feature_limits ? 'members'
      or not v_plus.feature_limits ? 'activeSeries'
      or (v_free.feature_limits ->> 'members')::bigint < 1
      or (v_plus.feature_limits ->> 'members')::bigint < 1
      or exists (
        select 1
        from pg_catalog.jsonb_each_text(
          v_free.feature_limits
        ) as free_limit(key, value)
        where not v_plus.feature_limits ? free_limit.key
          or (v_plus.feature_limits ->> free_limit.key)::bigint
            < free_limit.value::bigint
      ) then
      raise exception using
        errcode = 'KFB40',
        message = 'billing feature policies are not activation-ready';
    end if;
  end if;

  update app_private.billing_runtime_config as config
  set feature_enforcement_enabled = p_enabled
  where config.singleton
  returning config.* into v_next;

  insert into app_private.billing_policy_events(
    policy_kind,
    policy_key,
    previous_version,
    next_version,
    correlation_id
  ) values (
    'runtime',
    'feature_enforcement',
    v_previous_version,
    v_next.version,
    p_correlation_id
  );

  return query select
    v_next.feature_enforcement_enabled,
    v_next.version;
end;
$$;

create or replace function app_private.evaluate_household_feature_gate(
  p_household_id uuid,
  p_feature_key text,
  p_requested_delta integer default 1
)
returns table (
  decision text,
  household_id uuid,
  feature_key text,
  requested_delta integer,
  current_usage bigint,
  limit_value bigint,
  remaining_after_delta bigint,
  plan_code text,
  entitlement_status public.entitlement_status,
  enforcement_enabled boolean,
  limits_finalized boolean,
  entitlement_version bigint,
  policy_version bigint,
  runtime_version bigint,
  evaluated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_entitlement public.household_entitlements%rowtype;
  v_catalog public.plan_catalog%rowtype;
  v_runtime app_private.billing_runtime_config%rowtype;
  v_usage bigint;
  v_limit bigint;
  v_decision text;
  v_remaining bigint;
begin
  if p_household_id is null
    or p_feature_key not in ('members', 'activeSeries')
    or p_requested_delta is null
    or p_requested_delta < 1
    or p_requested_delta > 1000 then
    raise exception using
      errcode = '22023',
      message = 'invalid household feature-gate request';
  end if;

  select entitlement.*
  into v_entitlement
  from public.household_entitlements as entitlement
  where entitlement.household_id = p_household_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'household entitlement unavailable';
  end if;

  select catalog.*
  into v_catalog
  from public.plan_catalog as catalog
  where catalog.plan_code = v_entitlement.plan_code;

  select config.*
  into v_runtime
  from app_private.billing_runtime_config as config
  where config.singleton;

  v_usage := app_private.current_household_feature_usage(
    p_household_id,
    p_feature_key
  );

  if not v_runtime.feature_enforcement_enabled
    or not v_catalog.active
    or not v_catalog.limits_finalized then
    v_decision := 'policy_unavailable';
  elsif not v_catalog.feature_limits ? p_feature_key then
    v_decision := 'feature_unconfigured';
  else
    v_limit := (v_catalog.feature_limits ->> p_feature_key)::bigint;
    if v_usage + p_requested_delta > v_limit then
      v_decision := 'limit_reached';
      v_remaining := 0;
    else
      v_decision := 'allowed';
      v_remaining := v_limit - v_usage - p_requested_delta;
    end if;
  end if;

  return query select
    v_decision,
    p_household_id,
    p_feature_key,
    p_requested_delta,
    v_usage,
    case
      when v_decision in ('allowed', 'limit_reached') then v_limit
      else null::bigint
    end,
    v_remaining,
    v_entitlement.plan_code,
    v_entitlement.status,
    v_runtime.feature_enforcement_enabled,
    v_catalog.limits_finalized,
    v_entitlement.version,
    v_catalog.version,
    v_runtime.version,
    pg_catalog.statement_timestamp();
end;
$$;

revoke all on function app_private.evaluate_household_feature_gate(
  uuid,
  text,
  integer
) from public, anon, authenticated, service_role;

create or replace function public.get_household_feature_gate(
  p_household_id uuid,
  p_feature_key text,
  p_requested_delta integer default 1
)
returns table (
  decision text,
  household_id uuid,
  feature_key text,
  requested_delta integer,
  current_usage bigint,
  limit_value bigint,
  remaining_after_delta bigint,
  plan_code text,
  entitlement_status public.entitlement_status,
  enforcement_enabled boolean,
  limits_finalized boolean,
  entitlement_version bigint,
  policy_version bigint,
  runtime_version bigint,
  evaluated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception using
      errcode = '42501',
      message = 'authentication required';
  end if;

  if not app_private.is_active_household_member(p_household_id) then
    raise exception using
      errcode = '42501',
      message = 'active household membership required';
  end if;

  return query
  select gate.*
  from app_private.evaluate_household_feature_gate(
    p_household_id,
    p_feature_key,
    p_requested_delta
  ) as gate;
end;
$$;

create or replace function app_private.enforce_household_feature_capacity(
  p_household_id uuid,
  p_feature_key text,
  p_requested_delta integer default 1
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_enabled boolean;
  v_decision text;
begin
  select config.feature_enforcement_enabled
  into v_enabled
  from app_private.billing_runtime_config as config
  where config.singleton
  for share;

  if not v_enabled then
    return;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'billing-feature:' || p_household_id::text || ':' || p_feature_key,
      0
    )
  );

  perform 1
  from public.household_entitlements as entitlement
  join public.plan_catalog as catalog
    on catalog.plan_code = entitlement.plan_code
  where entitlement.household_id = p_household_id
  for share of entitlement, catalog;

  select gate.decision
  into v_decision
  from app_private.evaluate_household_feature_gate(
    p_household_id,
    p_feature_key,
    p_requested_delta
  ) as gate;

  if v_decision = 'allowed' then
    return;
  elsif v_decision = 'limit_reached' then
    raise exception using
      errcode = 'KFB12',
      message = 'household feature limit reached';
  elsif v_decision = 'feature_unconfigured' then
    raise exception using
      errcode = 'KFB11',
      message = 'household feature limit is not configured';
  else
    raise exception using
      errcode = 'KFB10',
      message = 'household feature policy is unavailable';
  end if;
end;
$$;

revoke all on function app_private.enforce_household_feature_capacity(
  uuid,
  text,
  integer
) from public, anon, authenticated, service_role;

create or replace function app_private.enforce_member_feature_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.removed_at is null then
      perform app_private.enforce_household_feature_capacity(
        new.household_id,
        'members',
        1
      );
    end if;
  elsif old.removed_at is not null and new.removed_at is null then
    perform app_private.enforce_household_feature_capacity(
      new.household_id,
      'members',
      1
    );
  end if;
  return new;
end;
$$;

create or replace function app_private.enforce_chore_series_feature_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rule jsonb;
begin
  if tg_table_name = 'chore_series_revisions' then
    if new.revision_number = 1
      and new.recurrence_rule <> '{"type":"once"}'::jsonb then
      perform app_private.enforce_household_feature_capacity(
        new.household_id,
        'activeSeries',
        1
      );
    end if;
  elsif old.deleted_at is not null and new.deleted_at is null then
    select revision.recurrence_rule
    into v_rule
    from public.chore_series_revisions as revision
    where revision.household_id = new.household_id
      and revision.id = new.active_revision_id;
    if v_rule <> '{"type":"once"}'::jsonb then
      perform app_private.enforce_household_feature_capacity(
        new.household_id,
        'activeSeries',
        1
      );
    end if;
  end if;
  return new;
end;
$$;

create or replace function app_private.enforce_event_series_feature_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rule jsonb;
begin
  if tg_table_name = 'event_series_revisions' then
    if new.revision_number = 1 and new.recurrence_rule is not null then
      perform app_private.enforce_household_feature_capacity(
        new.household_id,
        'activeSeries',
        1
      );
    end if;
  elsif old.deleted_at is not null and new.deleted_at is null then
    select revision.recurrence_rule
    into v_rule
    from public.event_series_revisions as revision
    where revision.household_id = new.household_id
      and revision.series_id = new.id
      and revision.id = new.active_revision_id;
    if v_rule is not null then
      perform app_private.enforce_household_feature_capacity(
        new.household_id,
        'activeSeries',
        1
      );
    end if;
  end if;
  return new;
end;
$$;

revoke all on function app_private.enforce_member_feature_trigger()
  from public, anon, authenticated, service_role;
revoke all on function app_private.enforce_chore_series_feature_trigger()
  from public, anon, authenticated, service_role;
revoke all on function app_private.enforce_event_series_feature_trigger()
  from public, anon, authenticated, service_role;

create trigger household_members_enforce_feature_capacity
before insert or update of removed_at on public.household_members
for each row execute function app_private.enforce_member_feature_trigger();

create trigger chore_revisions_enforce_feature_capacity
before insert on public.chore_series_revisions
for each row execute function
  app_private.enforce_chore_series_feature_trigger();

create trigger chore_series_reactivation_enforce_feature_capacity
before update of deleted_at on public.chore_series
for each row execute function
  app_private.enforce_chore_series_feature_trigger();

create trigger event_revisions_enforce_feature_capacity
before insert on public.event_series_revisions
for each row execute function
  app_private.enforce_event_series_feature_trigger();

create trigger event_series_reactivation_enforce_feature_capacity
before update of deleted_at on public.event_series
for each row execute function
  app_private.enforce_event_series_feature_trigger();

revoke all on function public.configure_billing_feature_enforcement(
  boolean,
  bigint,
  uuid
) from public, anon, authenticated, service_role;
revoke all on function public.get_household_feature_gate(uuid, text, integer)
  from public, anon, authenticated, service_role;

grant execute on function public.configure_billing_feature_enforcement(
  boolean,
  bigint,
  uuid
) to service_role;
grant execute on function public.get_household_feature_gate(
  uuid,
  text,
  integer
) to authenticated;

comment on function public.configure_billing_feature_enforcement(
  boolean,
  bigint,
  uuid
) is
  'Versioned service-only activation after both D-027 plan policies are finalized; emits immutable policy audit.';
comment on function public.get_household_feature_gate(uuid, text, integer) is
  'Authenticated aggregate lifecycle/capacity projection; no provider, billing-owner, member identity, or family content.';
comment on function app_private.enforce_household_feature_capacity(
  uuid,
  text,
  integer
) is
  'Serialized server mutation authority for activated member and recurring-series limits.';
