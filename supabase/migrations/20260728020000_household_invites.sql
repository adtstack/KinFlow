-- KinFlow WP02-04 secure adult household invitations.
-- Raw invite tokens, email addresses, and client IP addresses are never stored here.

create type public.invite_status as enum (
  'active',
  'accepted',
  'revoked',
  'expired'
);

create table public.household_invites (
  id uuid primary key default extensions.gen_random_uuid(),
  household_id uuid not null
    references public.households(id) on delete cascade,
  role public.household_role not null
    check (role in ('admin', 'member')),
  token_hash bytea not null unique
    check (octet_length(token_hash) = 32),
  short_code_hash bytea unique
    check (
      short_code_hash is null
      or octet_length(short_code_hash) = 32
    ),
  target_email_hash bytea
    check (
      target_email_hash is null
      or octet_length(target_email_hash) = 32
    ),
  status public.invite_status not null default 'active',
  expires_at timestamptz not null,
  max_uses integer not null default 1
    check (max_uses between 1 and 50),
  used_count integer not null default 0
    check (used_count >= 0 and used_count <= max_uses),
  created_by_member_id uuid not null,
  accepted_by_member_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revoked_at timestamptz,
  version bigint not null default 1 check (version > 0),
  constraint invite_creator_same_household_fk
    foreign key (household_id, created_by_member_id)
    references public.household_members(household_id, id),
  constraint invite_acceptor_same_household_fk
    foreign key (household_id, accepted_by_member_id)
    references public.household_members(household_id, id),
  constraint invite_status_shape_ck check (
    (status = 'active'
      and revoked_at is null
      and accepted_by_member_id is null
      and used_count < max_uses)
    or (status = 'accepted'
      and revoked_at is null
      and accepted_by_member_id is not null
      and used_count = max_uses)
    or (status = 'revoked'
      and revoked_at is not null
      and accepted_by_member_id is null
      and used_count < max_uses)
    or (status = 'expired'
      and revoked_at is null
      and accepted_by_member_id is null
      and used_count < max_uses)
  )
);

create index household_invites_active_idx
  on public.household_invites(household_id, expires_at)
  where status = 'active';

create trigger household_invites_set_updated_at_and_version
before update on public.household_invites
for each row execute function app_private.set_updated_at_and_version();

alter table public.household_invites enable row level security;
alter table public.household_invites force row level security;

create policy household_invites_select_admin
on public.household_invites
for select
to authenticated
using (
  app_private.has_household_role(
    household_id,
    array['owner', 'admin']::public.household_role[]
  )
);

revoke all on table public.household_invites from anon, authenticated;
grant select on table public.household_invites to authenticated;

create table app_private.invite_create_requests (
  authenticated_user_id uuid not null
    references auth.users(id) on delete cascade,
  idempotency_key text not null
    check (char_length(idempotency_key) between 16 and 200),
  request_hash bytea not null
    check (octet_length(request_hash) = 32),
  invite_id uuid not null
    references public.household_invites(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (authenticated_user_id, idempotency_key)
);

create table app_private.invite_accept_requests (
  authenticated_user_id uuid not null
    references auth.users(id) on delete cascade,
  idempotency_key text not null
    check (char_length(idempotency_key) between 16 and 200),
  request_hash bytea not null
    check (octet_length(request_hash) = 32),
  invite_id uuid not null
    references public.household_invites(id) on delete cascade,
  household_id uuid not null,
  member_id uuid not null,
  active_household_set boolean not null,
  created_at timestamptz not null default now(),
  primary key (authenticated_user_id, idempotency_key),
  constraint invite_accept_request_member_fk
    foreign key (household_id, member_id, authenticated_user_id)
    references public.household_members(household_id, id, auth_user_id)
    on delete cascade
    deferrable initially deferred
);

create table app_private.invite_revoke_requests (
  authenticated_user_id uuid not null
    references auth.users(id) on delete cascade,
  idempotency_key text not null
    check (char_length(idempotency_key) between 16 and 200),
  request_hash bytea not null
    check (octet_length(request_hash) = 32),
  invite_id uuid not null
    references public.household_invites(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (authenticated_user_id, idempotency_key)
);

create table app_private.invite_rate_limits (
  scope text not null
    check (scope in ('create', 'preview', 'accept', 'revoke')),
  key_hash bytea not null
    check (octet_length(key_hash) = 32),
  window_started_at timestamptz not null,
  request_count integer not null check (request_count > 0),
  updated_at timestamptz not null default now(),
  primary key (scope, key_hash)
);

revoke all on table app_private.invite_create_requests from public;
revoke all on table app_private.invite_create_requests
  from anon, authenticated;
revoke all on table app_private.invite_accept_requests from public;
revoke all on table app_private.invite_accept_requests
  from anon, authenticated;
revoke all on table app_private.invite_revoke_requests from public;
revoke all on table app_private.invite_revoke_requests
  from anon, authenticated;
revoke all on table app_private.invite_rate_limits from public;
revoke all on table app_private.invite_rate_limits
  from anon, authenticated;

create or replace function public.consume_invite_rate_limit(
  p_scope text,
  p_key_hash_hex text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_scope text := lower(btrim(p_scope));
  v_key_hash bytea;
  v_now timestamptz := clock_timestamp();
  v_limit integer;
  v_window interval;
  v_count integer;
begin
  if p_key_hash_hex is null
    or p_key_hash_hex !~ '^[0-9A-Fa-f]{64}$' then
    raise exception using
      errcode = 'KFI02',
      message = 'invalid invite input';
  end if;

  select configured.request_limit, configured.window_length
  into v_limit, v_window
  from (
    values
      ('create'::text, 10, interval '1 hour'),
      ('preview'::text, 30, interval '5 minutes'),
      ('accept'::text, 20, interval '5 minutes'),
      ('revoke'::text, 20, interval '5 minutes')
  ) as configured(scope, request_limit, window_length)
  where configured.scope = v_scope;

  if not found then
    raise exception using
      errcode = 'KFI02',
      message = 'invalid invite input';
  end if;

  v_key_hash := decode(lower(p_key_hash_hex), 'hex');

  insert into app_private.invite_rate_limits as rate_limit (
    scope,
    key_hash,
    window_started_at,
    request_count,
    updated_at
  )
  values (
    v_scope,
    v_key_hash,
    v_now,
    1,
    v_now
  )
  on conflict (scope, key_hash) do update
  set window_started_at = case
        when rate_limit.window_started_at + v_window <= v_now
          then v_now
        else rate_limit.window_started_at
      end,
      request_count = case
        when rate_limit.window_started_at + v_window <= v_now
          then 1
        else rate_limit.request_count + 1
      end,
      updated_at = v_now
  returning request_count into v_count;

  return v_count <= v_limit;
end;
$$;

create or replace function public.create_household_invite(
  p_authenticated_user_id uuid,
  p_household_id uuid,
  p_idempotency_key text,
  p_token_hash_hex text,
  p_role text,
  p_target_email text,
  p_expires_in_hours integer
)
returns table (
  invite_id uuid,
  household_id uuid,
  role text,
  expires_at timestamptz,
  status text,
  created boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_idempotency_key text := btrim(p_idempotency_key);
  v_role text := lower(btrim(p_role));
  v_target_email text := lower(btrim(p_target_email));
  v_token_hash bytea;
  v_target_email_hash bytea;
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_invite_id uuid;
  v_creator_member_id uuid;
  v_expires_at timestamptz;
begin
  if p_authenticated_user_id is null
    or not exists (
      select 1
      from auth.users as authenticated_user
      where authenticated_user.id = p_authenticated_user_id
        and authenticated_user.deleted_at is null
    ) then
    raise exception using
      errcode = 'KFI01',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or v_idempotency_key is null
    or char_length(v_idempotency_key) not between 16 and 200
    or v_idempotency_key ~ '[[:cntrl:]]'
    or p_token_hash_hex is null
    or p_token_hash_hex !~ '^[0-9A-Fa-f]{64}$'
    or v_role not in ('admin', 'member')
    or p_expires_in_hours is null
    or p_expires_in_hours not between 1 and 720
    or (
      nullif(v_target_email, '') is not null
      and (
        char_length(v_target_email) > 254
        or v_target_email !~ '^[^[:space:]@]+@[^[:space:]@]+$'
      )
    ) then
    raise exception using
      errcode = 'KFI02',
      message = 'invalid invite input';
  end if;

  v_target_email := nullif(v_target_email, '');
  v_token_hash := decode(lower(p_token_hash_hex), 'hex');
  v_target_email_hash := case
    when v_target_email is null then null
    else extensions.digest(convert_to(v_target_email, 'UTF8'), 'sha256')
  end;
  v_request_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'household_id', p_household_id,
        'role', v_role,
        'target_email_hash', encode(v_target_email_hash, 'hex'),
        'expires_in_hours', p_expires_in_hours
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      p_authenticated_user_id::text || ':invite-create:' || v_idempotency_key,
      0
    )
  );

  select request.request_hash, request.invite_id
  into v_existing_request_hash, v_invite_id
  from app_private.invite_create_requests as request
  where request.authenticated_user_id = p_authenticated_user_id
    and request.idempotency_key = v_idempotency_key;

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFI04',
        message = 'idempotency key reused with different invite input';
    end if;

    return query
    select
      invite.id,
      invite.household_id,
      invite.role::text,
      invite.expires_at,
      invite.status::text,
      false
    from public.household_invites as invite
    where invite.id = v_invite_id;
    return;
  end if;

  select member.id
  into v_creator_member_id
  from public.household_members as member
  where member.household_id = p_household_id
    and member.auth_user_id = p_authenticated_user_id
    and member.removed_at is null
    and member.role in ('owner', 'admin')
  for update;

  if not found then
    raise exception using
      errcode = 'KFI03',
      message = 'invite permission denied';
  end if;

  v_invite_id := extensions.gen_random_uuid();
  v_expires_at := clock_timestamp()
    + pg_catalog.make_interval(hours => p_expires_in_hours);

  insert into public.household_invites (
    id,
    household_id,
    role,
    token_hash,
    target_email_hash,
    expires_at,
    created_by_member_id
  )
  values (
    v_invite_id,
    p_household_id,
    v_role::public.household_role,
    v_token_hash,
    v_target_email_hash,
    v_expires_at,
    v_creator_member_id
  );

  insert into app_private.invite_create_requests (
    authenticated_user_id,
    idempotency_key,
    request_hash,
    invite_id
  )
  values (
    p_authenticated_user_id,
    v_idempotency_key,
    v_request_hash,
    v_invite_id
  );

  return query select
    v_invite_id,
    p_household_id,
    v_role,
    v_expires_at,
    'active'::text,
    true;
end;
$$;

create or replace function public.preview_household_invite(
  p_token_hash_hex text
)
returns table (
  valid boolean,
  household_display_name text,
  inviter_display_name text,
  role text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token_hash bytea;
  v_household_name text;
  v_inviter_display_name text;
  v_role text;
  v_expires_at timestamptz;
  v_status public.invite_status;
  v_used_count integer;
  v_max_uses integer;
begin
  if p_token_hash_hex is null
    or p_token_hash_hex !~ '^[0-9A-Fa-f]{64}$' then
    raise exception using
      errcode = 'KFI05',
      message = 'invite invalid';
  end if;

  v_token_hash := decode(lower(p_token_hash_hex), 'hex');

  select
    household.name,
    creator.display_name,
    invite.role::text,
    invite.expires_at,
    invite.status,
    invite.used_count,
    invite.max_uses
  into
    v_household_name,
    v_inviter_display_name,
    v_role,
    v_expires_at,
    v_status,
    v_used_count,
    v_max_uses
  from public.household_invites as invite
  join public.households as household
    on household.id = invite.household_id
  join public.household_members as creator
    on creator.household_id = invite.household_id
   and creator.id = invite.created_by_member_id
  where invite.token_hash = v_token_hash;

  if not found then
    raise exception using
      errcode = 'KFI05',
      message = 'invite invalid';
  end if;

  if v_status = 'revoked' then
    raise exception using
      errcode = 'KFI08',
      message = 'invite revoked';
  end if;

  if v_status = 'accepted' or v_used_count >= v_max_uses then
    raise exception using
      errcode = 'KFI09',
      message = 'invite already used';
  end if;

  if v_status = 'expired' or v_expires_at <= clock_timestamp() then
    raise exception using
      errcode = 'KFI06',
      message = 'invite expired';
  end if;

  return query select
    true,
    v_household_name,
    v_inviter_display_name,
    v_role,
    v_expires_at;
end;
$$;

create or replace function public.accept_household_invite(
  p_authenticated_user_id uuid,
  p_idempotency_key text,
  p_token_hash_hex text,
  p_set_active_household boolean
)
returns table (
  invite_id uuid,
  household_id uuid,
  member_id uuid,
  display_name text,
  role text,
  active_household_set boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_idempotency_key text := btrim(p_idempotency_key);
  v_token_hash bytea;
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_invite_id uuid;
  v_household_id uuid;
  v_member_id uuid;
  v_display_name text;
  v_role public.household_role;
  v_status public.invite_status;
  v_expires_at timestamptz;
  v_used_count integer;
  v_max_uses integer;
  v_target_email_hash bytea;
  v_authenticated_email_hash bytea;
  v_accepted_by_member_id uuid;
  v_creator_auth_user_id uuid;
  v_should_set_active boolean;
  v_existing_member_display_name text;
  v_existing_member_role public.household_role;
begin
  if p_authenticated_user_id is null
    or not exists (
      select 1
      from auth.users as authenticated_user
      where authenticated_user.id = p_authenticated_user_id
        and authenticated_user.deleted_at is null
    ) then
    raise exception using
      errcode = 'KFI01',
      message = 'authentication required';
  end if;

  if v_idempotency_key is null
    or char_length(v_idempotency_key) not between 16 and 200
    or v_idempotency_key ~ '[[:cntrl:]]'
    or p_token_hash_hex is null
    or p_token_hash_hex !~ '^[0-9A-Fa-f]{64}$'
    or p_set_active_household is null then
    raise exception using
      errcode = 'KFI02',
      message = 'invalid invite input';
  end if;

  v_token_hash := decode(lower(p_token_hash_hex), 'hex');
  v_request_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'token_hash', lower(p_token_hash_hex),
        'set_active_household', p_set_active_household
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      p_authenticated_user_id::text || ':invite-accept:' || v_idempotency_key,
      0
    )
  );

  select
    request.request_hash,
    request.invite_id,
    request.household_id,
    request.member_id,
    request.active_household_set
  into
    v_existing_request_hash,
    v_invite_id,
    v_household_id,
    v_member_id,
    v_should_set_active
  from app_private.invite_accept_requests as request
  where request.authenticated_user_id = p_authenticated_user_id
    and request.idempotency_key = v_idempotency_key;

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFI04',
        message = 'idempotency key reused with different invite input';
    end if;

    return query
    select
      v_invite_id,
      v_household_id,
      member.id,
      member.display_name,
      member.role::text,
      v_should_set_active
    from public.household_members as member
    where member.household_id = v_household_id
      and member.id = v_member_id
      and member.auth_user_id = p_authenticated_user_id;
    return;
  end if;

  select
    invite.id,
    invite.household_id,
    invite.role,
    invite.status,
    invite.expires_at,
    invite.used_count,
    invite.max_uses,
    invite.target_email_hash,
    invite.accepted_by_member_id,
    creator.auth_user_id
  into
    v_invite_id,
    v_household_id,
    v_role,
    v_status,
    v_expires_at,
    v_used_count,
    v_max_uses,
    v_target_email_hash,
    v_accepted_by_member_id,
    v_creator_auth_user_id
  from public.household_invites as invite
  join public.household_members as creator
    on creator.household_id = invite.household_id
   and creator.id = invite.created_by_member_id
  where invite.token_hash = v_token_hash
  for update of invite;

  if not found then
    raise exception using
      errcode = 'KFI05',
      message = 'invite invalid';
  end if;

  if v_status = 'revoked' then
    raise exception using
      errcode = 'KFI08',
      message = 'invite revoked';
  end if;

  if v_status = 'expired' or v_expires_at <= clock_timestamp() then
    raise exception using
      errcode = 'KFI06',
      message = 'invite expired';
  end if;

  if v_status = 'accepted' or v_used_count >= v_max_uses then
    select member.id, member.display_name, member.role
    into v_member_id, v_display_name, v_role
    from public.household_members as member
    where member.household_id = v_household_id
      and member.id = v_accepted_by_member_id
      and member.auth_user_id = p_authenticated_user_id
      and member.removed_at is null;

    if not found then
      raise exception using
        errcode = 'KFI09',
        message = 'invite already used';
    end if;
  else
    select
      profile.display_name,
      case
        when authenticated_user.email is null then null
        else extensions.digest(
          convert_to(lower(btrim(authenticated_user.email)), 'UTF8'),
          'sha256'
        )
      end
    into v_display_name, v_authenticated_email_hash
    from auth.users as authenticated_user
    join public.profiles as profile
      on profile.auth_user_id = authenticated_user.id
     and profile.deleted_at is null
    where authenticated_user.id = p_authenticated_user_id;

    if not found then
      raise exception using
        errcode = 'KFI11',
        message = 'invite profile unavailable';
    end if;

    if v_target_email_hash is not null
      and v_target_email_hash is distinct from v_authenticated_email_hash then
      raise exception using
        errcode = 'KFI10',
        message = 'invite email mismatch';
    end if;

    select member.id, member.display_name, member.role
    into
      v_member_id,
      v_existing_member_display_name,
      v_existing_member_role
    from public.household_members as member
    where member.household_id = v_household_id
      and member.auth_user_id = p_authenticated_user_id
      and member.removed_at is null
    for update;

    if not found then
      v_member_id := extensions.gen_random_uuid();
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
        p_authenticated_user_id,
        v_display_name,
        v_role,
        v_creator_auth_user_id
      );
    else
      v_display_name := v_existing_member_display_name;
      v_role := v_existing_member_role;
    end if;

    update public.household_invites as invite
    set status = 'accepted',
        used_count = invite.max_uses,
        accepted_by_member_id = v_member_id
    where invite.id = v_invite_id;
  end if;

  v_should_set_active := p_set_active_household or not exists (
    select 1
    from public.user_active_households as active_household
    where active_household.auth_user_id = p_authenticated_user_id
  );

  if v_should_set_active then
    insert into public.user_active_households (
      auth_user_id,
      household_id,
      member_id
    )
    values (
      p_authenticated_user_id,
      v_household_id,
      v_member_id
    )
    on conflict (auth_user_id) do update
    set household_id = excluded.household_id,
        member_id = excluded.member_id;
  end if;

  insert into app_private.invite_accept_requests (
    authenticated_user_id,
    idempotency_key,
    request_hash,
    invite_id,
    household_id,
    member_id,
    active_household_set
  )
  values (
    p_authenticated_user_id,
    v_idempotency_key,
    v_request_hash,
    v_invite_id,
    v_household_id,
    v_member_id,
    v_should_set_active
  );

  return query select
    v_invite_id,
    v_household_id,
    v_member_id,
    v_display_name,
    v_role::text,
    v_should_set_active;
end;
$$;

create or replace function public.revoke_household_invite(
  p_authenticated_user_id uuid,
  p_household_id uuid,
  p_invite_id uuid,
  p_idempotency_key text
)
returns table (
  invite_id uuid,
  household_id uuid,
  status text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_idempotency_key text := btrim(p_idempotency_key);
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_status public.invite_status;
  v_expires_at timestamptz;
begin
  if p_authenticated_user_id is null
    or not exists (
      select 1
      from auth.users as authenticated_user
      where authenticated_user.id = p_authenticated_user_id
        and authenticated_user.deleted_at is null
    ) then
    raise exception using
      errcode = 'KFI01',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or p_invite_id is null
    or v_idempotency_key is null
    or char_length(v_idempotency_key) not between 16 and 200
    or v_idempotency_key ~ '[[:cntrl:]]' then
    raise exception using
      errcode = 'KFI02',
      message = 'invalid invite input';
  end if;

  v_request_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'household_id', p_household_id,
        'invite_id', p_invite_id
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      p_authenticated_user_id::text || ':invite-revoke:' || v_idempotency_key,
      0
    )
  );

  select request.request_hash
  into v_existing_request_hash
  from app_private.invite_revoke_requests as request
  where request.authenticated_user_id = p_authenticated_user_id
    and request.idempotency_key = v_idempotency_key;

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFI04',
        message = 'idempotency key reused with different invite input';
    end if;
    return query select p_invite_id, p_household_id, 'revoked'::text;
    return;
  end if;

  if not exists (
    select 1
    from public.household_members as member
    where member.household_id = p_household_id
      and member.auth_user_id = p_authenticated_user_id
      and member.removed_at is null
      and member.role in ('owner', 'admin')
  ) then
    raise exception using
      errcode = 'KFI03',
      message = 'invite permission denied';
  end if;

  select invite.status, invite.expires_at
  into v_status, v_expires_at
  from public.household_invites as invite
  where invite.id = p_invite_id
    and invite.household_id = p_household_id
  for update;

  if not found then
    raise exception using
      errcode = 'KFI05',
      message = 'invite invalid';
  end if;

  if v_status = 'accepted' then
    raise exception using
      errcode = 'KFI09',
      message = 'invite already used';
  end if;

  if v_status = 'expired' or v_expires_at <= clock_timestamp() then
    raise exception using
      errcode = 'KFI06',
      message = 'invite expired';
  end if;

  if v_status = 'active' then
    update public.household_invites as invite
    set status = 'revoked',
        revoked_at = clock_timestamp()
    where invite.id = p_invite_id;
  end if;

  insert into app_private.invite_revoke_requests (
    authenticated_user_id,
    idempotency_key,
    request_hash,
    invite_id
  )
  values (
    p_authenticated_user_id,
    v_idempotency_key,
    v_request_hash,
    p_invite_id
  );

  return query select p_invite_id, p_household_id, 'revoked'::text;
end;
$$;

revoke all on function public.consume_invite_rate_limit(text, text)
  from public, anon, authenticated;
revoke all on function public.create_household_invite(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  integer
) from public, anon, authenticated;
revoke all on function public.preview_household_invite(text)
  from public, anon, authenticated;
revoke all on function public.accept_household_invite(
  uuid,
  text,
  text,
  boolean
) from public, anon, authenticated;
revoke all on function public.revoke_household_invite(
  uuid,
  uuid,
  uuid,
  text
) from public, anon, authenticated;

grant execute on function public.consume_invite_rate_limit(text, text)
  to service_role;
grant execute on function public.create_household_invite(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  integer
) to service_role;
grant execute on function public.preview_household_invite(text)
  to service_role;
grant execute on function public.accept_household_invite(
  uuid,
  text,
  text,
  boolean
) to service_role;
grant execute on function public.revoke_household_invite(
  uuid,
  uuid,
  uuid,
  text
) to service_role;

comment on table public.household_invites is
  'Hashed, expiring adult household invitation metadata. Raw tokens are never stored.';
comment on function public.preview_household_invite(text) is
  'Service-only minimal invite preview; public access is mediated by the rate-limited Edge endpoint.';
