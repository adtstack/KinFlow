-- KinFlow WP07-03A secure, short-lived household invite codes.
-- Raw codes never enter PostgreSQL; only SHA-256 hashes are accepted here.

alter table public.household_invites
  add column short_code_expires_at timestamptz;

alter table public.household_invites
  add constraint household_invites_short_code_shape_ck check (
    (
      short_code_hash is null
      and short_code_expires_at is null
    )
    or (
      short_code_hash is not null
      and short_code_expires_at is not null
      and short_code_expires_at > created_at
      and short_code_expires_at <= expires_at
      and short_code_expires_at <= created_at + interval '24 hours 1 minute'
    )
  );

alter table app_private.invite_rate_limits
  drop constraint if exists invite_rate_limits_scope_check;

alter table app_private.invite_rate_limits
  add constraint invite_rate_limits_scope_check check (
    scope in (
      'create',
      'preview',
      'accept',
      'revoke',
      'preview_short_code',
      'accept_short_code'
    )
  );

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
  v_scope text := pg_catalog.lower(pg_catalog.btrim(p_scope));
  v_key_hash bytea;
  v_now timestamptz := pg_catalog.clock_timestamp();
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
      ('revoke'::text, 20, interval '5 minutes'),
      ('preview_short_code'::text, 10, interval '10 minutes'),
      ('accept_short_code'::text, 10, interval '10 minutes')
  ) as configured(scope, request_limit, window_length)
  where configured.scope = v_scope;

  if not found then
    raise exception using
      errcode = 'KFI02',
      message = 'invalid invite input';
  end if;

  v_key_hash := pg_catalog.decode(pg_catalog.lower(p_key_hash_hex), 'hex');

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

create or replace function public.create_household_invite_with_short_code(
  p_authenticated_user_id uuid,
  p_household_id uuid,
  p_idempotency_key text,
  p_token_hash_hex text,
  p_short_code_hash_hex text,
  p_role text,
  p_target_email text,
  p_expires_in_hours integer,
  p_short_code_expires_in_hours integer
)
returns table (
  invite_id uuid,
  household_id uuid,
  role text,
  expires_at timestamptz,
  short_code_expires_at timestamptz,
  status text,
  created boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invite_id uuid;
  v_household_id uuid;
  v_role text;
  v_expires_at timestamptz;
  v_short_code_expires_at timestamptz;
  v_status text;
  v_created boolean;
begin
  if p_short_code_hash_hex is null
    or p_short_code_hash_hex !~ '^[0-9A-Fa-f]{64}$'
    or p_short_code_expires_in_hours is null
    or p_short_code_expires_in_hours not between 1 and 24 then
    raise exception using
      errcode = 'KFI02',
      message = 'invalid invite input';
  end if;

  select
    created_invite.invite_id,
    created_invite.household_id,
    created_invite.role,
    created_invite.expires_at,
    created_invite.status,
    created_invite.created
  into
    v_invite_id,
    v_household_id,
    v_role,
    v_expires_at,
    v_status,
    v_created
  from public.create_household_invite(
    p_authenticated_user_id,
    p_household_id,
    p_idempotency_key,
    p_token_hash_hex,
    p_role,
    p_target_email,
    p_expires_in_hours
  ) as created_invite;

  if not found then
    raise exception using
      errcode = 'KFI02',
      message = 'invalid invite result';
  end if;

  if v_created then
    v_short_code_expires_at := least(
      v_expires_at,
      pg_catalog.clock_timestamp() + pg_catalog.make_interval(
        hours => p_short_code_expires_in_hours
      )
    );
    update public.household_invites as invite
    set short_code_hash = pg_catalog.decode(
          pg_catalog.lower(p_short_code_hash_hex),
          'hex'
        ),
        short_code_expires_at = v_short_code_expires_at
    where invite.id = v_invite_id;
  else
    select invite.short_code_expires_at
    into v_short_code_expires_at
    from public.household_invites as invite
    where invite.id = v_invite_id;
  end if;

  return query select
    v_invite_id,
    v_household_id,
    v_role,
    v_expires_at,
    v_short_code_expires_at,
    v_status,
    v_created;
end;
$$;

create or replace function public.preview_household_invite_short_code(
  p_short_code_hash_hex text
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
  v_token_hash_hex text;
  v_short_code_expires_at timestamptz;
  v_valid boolean;
  v_household_display_name text;
  v_inviter_display_name text;
  v_role text;
begin
  if p_short_code_hash_hex is null
    or p_short_code_hash_hex !~ '^[0-9A-Fa-f]{64}$' then
    raise exception using
      errcode = 'KFI05',
      message = 'invite invalid';
  end if;

  select
    pg_catalog.encode(invite.token_hash, 'hex'),
    invite.short_code_expires_at
  into v_token_hash_hex, v_short_code_expires_at
  from public.household_invites as invite
  where invite.short_code_hash = pg_catalog.decode(
      pg_catalog.lower(p_short_code_hash_hex),
      'hex'
    )
    and invite.short_code_expires_at > pg_catalog.clock_timestamp()
    and invite.expires_at > pg_catalog.clock_timestamp()
    and invite.status = 'active'
    and invite.used_count < invite.max_uses;

  if not found then
    raise exception using
      errcode = 'KFI05',
      message = 'invite invalid';
  end if;

  begin
    select
      preview.valid,
      preview.household_display_name,
      preview.inviter_display_name,
      preview.role
    into
      v_valid,
      v_household_display_name,
      v_inviter_display_name,
      v_role
    from public.preview_household_invite(v_token_hash_hex) as preview;
  exception
    when sqlstate 'KFI05'
      or sqlstate 'KFI06'
      or sqlstate 'KFI08'
      or sqlstate 'KFI09' then
      raise exception using
        errcode = 'KFI05',
        message = 'invite invalid';
  end;

  return query select
    v_valid,
    v_household_display_name,
    v_inviter_display_name,
    v_role,
    v_short_code_expires_at;
end;
$$;

create or replace function public.accept_household_invite_short_code(
  p_authenticated_user_id uuid,
  p_idempotency_key text,
  p_short_code_hash_hex text,
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
  v_token_hash_hex text;
begin
  if p_short_code_hash_hex is null
    or p_short_code_hash_hex !~ '^[0-9A-Fa-f]{64}$' then
    raise exception using
      errcode = 'KFI05',
      message = 'invite invalid';
  end if;

  select pg_catalog.encode(invite.token_hash, 'hex')
  into v_token_hash_hex
  from public.household_invites as invite
  where invite.short_code_hash = pg_catalog.decode(
      pg_catalog.lower(p_short_code_hash_hex),
      'hex'
    )
    and invite.short_code_expires_at > pg_catalog.clock_timestamp()
    and invite.expires_at > pg_catalog.clock_timestamp()
    and invite.status in ('active', 'accepted');

  if not found then
    raise exception using
      errcode = 'KFI05',
      message = 'invite invalid';
  end if;

  begin
    return query
    select accepted.*
    from public.accept_household_invite(
      p_authenticated_user_id,
      p_idempotency_key,
      v_token_hash_hex,
      p_set_active_household
    ) as accepted;
  exception
    when sqlstate 'KFI05'
      or sqlstate 'KFI06'
      or sqlstate 'KFI08'
      or sqlstate 'KFI09' then
      raise exception using
        errcode = 'KFI05',
        message = 'invite invalid';
  end;
end;
$$;

revoke all on function public.create_household_invite_with_short_code(
  uuid, uuid, text, text, text, text, text, integer, integer
) from public, anon, authenticated;
revoke all on function public.preview_household_invite_short_code(text)
  from public, anon, authenticated;
revoke all on function public.accept_household_invite_short_code(
  uuid, text, text, boolean
) from public, anon, authenticated;

grant execute on function public.create_household_invite_with_short_code(
  uuid, uuid, text, text, text, text, text, integer, integer
) to service_role;
grant execute on function public.preview_household_invite_short_code(text)
  to service_role;
grant execute on function public.accept_household_invite_short_code(
  uuid, text, text, boolean
) to service_role;

comment on column public.household_invites.short_code_hash is
  'SHA-256 of the normalized 8-symbol invite code; raw code storage is forbidden.';
comment on column public.household_invites.short_code_expires_at is
  'Short-code capability expiry, bounded to 24 hours and never after the primary invite.';
comment on function public.preview_household_invite_short_code(text) is
  'Service-only generic short-code preview behind an Edge client-address lockout.';
comment on function public.accept_household_invite_short_code(
  uuid, text, text, boolean
) is
  'Service-only short-code acceptance reusing the existing idempotent membership transaction.';
