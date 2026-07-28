-- KinFlow WP02-03 transactional first-household onboarding.
-- The caller supplies no user, role, household, or member authority fields.

create table app_private.first_household_requests (
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  request_hash bytea not null
    check (octet_length(request_hash) = 32),
  household_id uuid not null,
  member_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (auth_user_id, idempotency_key),
  unique (household_id),
  constraint first_household_request_member_fk
    foreign key (household_id, member_id, auth_user_id)
    references public.household_members(household_id, id, auth_user_id)
    on delete cascade
    deferrable initially deferred
);

revoke all on table app_private.first_household_requests from public;
revoke all on table app_private.first_household_requests
  from anon, authenticated;

create or replace function public.create_first_household(
  p_idempotency_key uuid,
  p_household_name text,
  p_owner_display_name text,
  p_locale text,
  p_timezone text
)
returns table (
  household_id uuid,
  owner_member_id uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_user_id uuid := (select auth.uid());
  v_household_name text := btrim(p_household_name);
  v_owner_display_name text := btrim(p_owner_display_name);
  v_locale text := lower(btrim(p_locale));
  v_timezone text := btrim(p_timezone);
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_household_id uuid;
  v_member_id uuid;
  v_profile_deleted_at timestamptz;
begin
  if v_auth_user_id is null then
    raise exception using
      errcode = 'KFH01',
      message = 'authentication required';
  end if;

  if p_idempotency_key is null
    or v_household_name is null
    or char_length(v_household_name) not between 1 and 80
    or v_household_name ~ '[[:cntrl:]]'
    or v_owner_display_name is null
    or char_length(v_owner_display_name) not between 1 and 80
    or v_owner_display_name ~ '[[:cntrl:]]'
    or v_locale not in ('en', 'ko')
    or not app_private.is_valid_iana_timezone(v_timezone) then
    raise exception using
      errcode = 'KFH02',
      message = 'invalid first household input';
  end if;

  v_request_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'household_name', v_household_name,
        'owner_display_name', v_owner_display_name,
        'locale', v_locale,
        'timezone', v_timezone
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  insert into public.profiles (
    auth_user_id,
    display_name,
    locale,
    timezone
  )
  values (
    v_auth_user_id,
    v_owner_display_name,
    v_locale,
    v_timezone
  )
  on conflict (auth_user_id) do nothing;

  select profile.deleted_at
  into v_profile_deleted_at
  from public.profiles as profile
  where profile.auth_user_id = v_auth_user_id
  for update;

  if not found or v_profile_deleted_at is not null then
    raise exception using
      errcode = 'KFH05',
      message = 'profile unavailable';
  end if;

  select
    request.request_hash,
    request.household_id,
    request.member_id
  into
    v_existing_request_hash,
    v_household_id,
    v_member_id
  from app_private.first_household_requests as request
  where request.auth_user_id = v_auth_user_id
    and request.idempotency_key = p_idempotency_key;

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFH04',
        message = 'idempotency key reused with different input';
    end if;

    return query select v_household_id, v_member_id;
    return;
  end if;

  if exists (
    select 1
    from public.household_members as member
    where member.auth_user_id = v_auth_user_id
      and member.removed_at is null
  ) then
    raise exception using
      errcode = 'KFH03',
      message = 'active household already exists';
  end if;

  update public.profiles as profile
  set display_name = v_owner_display_name,
      locale = v_locale,
      timezone = v_timezone
  where profile.auth_user_id = v_auth_user_id
    and (
      profile.display_name,
      profile.locale,
      profile.timezone
    ) is distinct from (
      v_owner_display_name,
      v_locale,
      v_timezone
    );

  v_household_id := extensions.gen_random_uuid();
  v_member_id := extensions.gen_random_uuid();

  insert into public.households (
    id,
    name,
    timezone,
    owner_member_id,
    created_by_user_id
  )
  values (
    v_household_id,
    v_household_name,
    v_timezone,
    v_member_id,
    v_auth_user_id
  );

  insert into public.household_members (
    id,
    household_id,
    auth_user_id,
    display_name,
    role,
    created_by_user_id
  )
  values (
    v_member_id,
    v_household_id,
    v_auth_user_id,
    v_owner_display_name,
    'owner',
    v_auth_user_id
  );

  insert into public.user_active_households (
    auth_user_id,
    household_id,
    member_id
  )
  values (
    v_auth_user_id,
    v_household_id,
    v_member_id
  )
  on conflict (auth_user_id) do update
  set household_id = excluded.household_id,
      member_id = excluded.member_id;

  perform app_private.assert_household_owner_integrity(v_household_id);

  insert into app_private.first_household_requests (
    auth_user_id,
    idempotency_key,
    request_hash,
    household_id,
    member_id
  )
  values (
    v_auth_user_id,
    p_idempotency_key,
    v_request_hash,
    v_household_id,
    v_member_id
  );

  return query select v_household_id, v_member_id;
end;
$$;

revoke all on function public.create_first_household(
  uuid,
  text,
  text,
  text,
  text
) from public, anon, authenticated;

grant execute on function public.create_first_household(
  uuid,
  text,
  text,
  text,
  text
) to authenticated;
