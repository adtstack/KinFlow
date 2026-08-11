-- KinFlow WP07-06A adult profile, locale, and timezone settings.
-- Existing recurrence rows retain their own stored timezone semantics.

create table app_private.household_timezone_audit_events (
  id uuid primary key default extensions.gen_random_uuid(),
  household_id uuid not null,
  authenticated_user_id uuid not null,
  actor_member_id uuid not null,
  previous_timezone text not null check (
    app_private.is_valid_iana_timezone(previous_timezone)
  ),
  next_timezone text not null check (
    app_private.is_valid_iana_timezone(next_timezone)
  ),
  aggregate_version bigint not null check (aggregate_version > 0),
  occurred_at timestamptz not null default pg_catalog.clock_timestamp(),
  check (previous_timezone <> next_timezone)
);

create index household_timezone_audit_events_household_time_idx
  on app_private.household_timezone_audit_events(
    household_id,
    occurred_at desc
  );

revoke all on table app_private.household_timezone_audit_events
  from public, anon, authenticated, service_role;

create trigger household_timezone_audit_events_immutable
before update or delete on app_private.household_timezone_audit_events
for each row execute function app_private.reject_household_audit_mutation();

-- Profile identity changes must pass through the atomic command so the active
-- membership display stays consistent with the self profile.
drop policy if exists profiles_update_self on public.profiles;
revoke update on table public.profiles from authenticated;
revoke update (display_name, locale, timezone, avatar_key)
  on table public.profiles from authenticated;

create or replace function public.get_profile_preferences()
returns table (
  profile_id uuid,
  display_name text,
  avatar_key text,
  locale text,
  profile_timezone text,
  profile_version bigint,
  household_id uuid,
  household_name text,
  household_timezone text,
  household_version bigint,
  household_role text,
  can_manage_household_timezone boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFS01',
      message = 'authentication required';
  end if;

  return query
  select
    profile.id,
    profile.display_name,
    profile.avatar_key,
    profile.locale,
    profile.timezone,
    profile.version,
    household.id,
    household.name,
    household.timezone,
    household.version,
    member.role::text,
    member.role in ('owner', 'admin')
  from public.profiles as profile
  join public.user_active_households as active_household
    on active_household.auth_user_id = profile.auth_user_id
  join public.household_members as member
    on member.household_id = active_household.household_id
   and member.id = active_household.member_id
   and member.auth_user_id = profile.auth_user_id
   and member.removed_at is null
  join public.households as household
    on household.id = active_household.household_id
   and household.deleted_at is null
  where profile.auth_user_id = v_authenticated_user_id
    and profile.deleted_at is null;

  if not found then
    raise exception using
      errcode = 'KFS03',
      message = 'profile preferences unavailable';
  end if;
end;
$$;

create or replace function public.update_profile_preferences(
  p_display_name text,
  p_avatar_key text,
  p_locale text,
  p_profile_timezone text,
  p_expected_profile_version bigint,
  p_household_timezone text default null,
  p_expected_household_version bigint default null
)
returns table (
  profile_id uuid,
  display_name text,
  avatar_key text,
  locale text,
  profile_timezone text,
  profile_version bigint,
  household_id uuid,
  household_name text,
  household_timezone text,
  household_version bigint,
  household_role text,
  can_manage_household_timezone boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_display_name text := pg_catalog.btrim(p_display_name);
  v_avatar_key text := p_avatar_key;
  v_locale text := pg_catalog.lower(pg_catalog.btrim(p_locale));
  v_profile_timezone text := pg_catalog.btrim(p_profile_timezone);
  v_household_timezone text := case
    when p_household_timezone is null then null
    else pg_catalog.btrim(p_household_timezone)
  end;
  v_profile record;
  v_active record;
  v_result_household_version bigint;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFS01',
      message = 'authentication required';
  end if;

  if v_display_name is null
    or pg_catalog.char_length(v_display_name) not between 1 and 80
    or v_display_name ~ '[[:cntrl:]]'
    or v_avatar_key is not null
      and v_avatar_key not in (
        'preset:sun',
        'preset:heart',
        'preset:leaf',
        'preset:star'
      )
    or v_locale is null
    or v_locale not in ('en', 'ko')
    or not app_private.is_valid_iana_timezone(v_profile_timezone)
    or p_expected_profile_version is null
    or p_expected_profile_version < 1
    or v_household_timezone is not null
      and not app_private.is_valid_iana_timezone(v_household_timezone)
    or (v_household_timezone is null)
      <> (p_expected_household_version is null)
    or p_expected_household_version is not null
      and p_expected_household_version < 1 then
    raise exception using
      errcode = 'KFS02',
      message = 'invalid profile preferences input';
  end if;

  select
    profile.id,
    profile.version
  into v_profile
  from public.profiles as profile
  where profile.auth_user_id = v_authenticated_user_id
    and profile.deleted_at is null
  for update of profile;

  if not found then
    raise exception using
      errcode = 'KFS03',
      message = 'profile preferences unavailable';
  end if;

  if v_profile.version <> p_expected_profile_version then
    raise exception using
      errcode = 'KFS05',
      message = 'profile version conflict';
  end if;

  select
    active_household.household_id,
    active_household.member_id,
    member.role,
    household.timezone,
    household.version
  into v_active
  from public.user_active_households as active_household
  join public.household_members as member
    on member.household_id = active_household.household_id
   and member.id = active_household.member_id
   and member.auth_user_id = v_authenticated_user_id
   and member.removed_at is null
  join public.households as household
    on household.id = active_household.household_id
   and household.deleted_at is null
  where active_household.auth_user_id = v_authenticated_user_id
  for update of member, household;

  if not found then
    raise exception using
      errcode = 'KFS03',
      message = 'profile preferences unavailable';
  end if;

  if v_household_timezone is not null then
    if v_active.role not in ('owner', 'admin') then
      raise exception using
        errcode = 'KFS04',
        message = 'household timezone permission denied';
    end if;

    if v_active.version <> p_expected_household_version then
      raise exception using
        errcode = 'KFS06',
        message = 'household version conflict';
    end if;
  end if;

  update public.profiles as profile
  set display_name = v_display_name,
      avatar_key = v_avatar_key,
      locale = v_locale,
      timezone = v_profile_timezone
  where profile.id = v_profile.id
    and row(
      profile.display_name,
      profile.avatar_key,
      profile.locale,
      profile.timezone
    ) is distinct from row(
      v_display_name,
      v_avatar_key,
      v_locale,
      v_profile_timezone
    );

  update public.household_members as member
  set display_name = v_display_name,
      avatar_key = v_avatar_key
  where member.household_id = v_active.household_id
    and member.id = v_active.member_id
    and row(member.display_name, member.avatar_key)
      is distinct from row(v_display_name, v_avatar_key);

  v_result_household_version := v_active.version;
  if v_household_timezone is not null
    and v_household_timezone <> v_active.timezone then
    update public.households as household
    set timezone = v_household_timezone
    where household.id = v_active.household_id
    returning household.version into v_result_household_version;

    insert into app_private.household_timezone_audit_events (
      household_id,
      authenticated_user_id,
      actor_member_id,
      previous_timezone,
      next_timezone,
      aggregate_version
    )
    values (
      v_active.household_id,
      v_authenticated_user_id,
      v_active.member_id,
      v_active.timezone,
      v_household_timezone,
      v_result_household_version
    );
  end if;

  return query
  select *
  from public.get_profile_preferences();
end;
$$;

revoke all on function public.get_profile_preferences()
  from public, anon, authenticated;
revoke all on function public.update_profile_preferences(
  text,
  text,
  text,
  text,
  bigint,
  text,
  bigint
) from public, anon, authenticated;

grant execute on function public.get_profile_preferences()
  to authenticated;
grant execute on function public.update_profile_preferences(
  text,
  text,
  text,
  text,
  bigint,
  text,
  bigint
) to authenticated;
