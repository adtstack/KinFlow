-- KinFlow WP02-05 adult household role and owner lifecycle.
-- All mutations are server commands; clients retain same-household read only.

create table app_private.household_member_command_requests (
  authenticated_user_id uuid not null
    references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  operation text not null check (
    operation in (
      'change_role',
      'remove_member',
      'leave_household',
      'transfer_owner'
    )
  ),
  request_hash bytea not null check (octet_length(request_hash) = 32),
  result jsonb not null check (jsonb_typeof(result) = 'object'),
  created_at timestamptz not null default now(),
  primary key (authenticated_user_id, idempotency_key)
);

create table app_private.household_audit_events (
  id uuid primary key default extensions.gen_random_uuid(),
  household_id uuid not null,
  authenticated_user_id uuid not null,
  actor_member_id uuid not null,
  action text not null check (
    action in (
      'member.role_changed',
      'member.removed',
      'household.owner_transferred'
    )
  ),
  target_member_id uuid not null,
  correlation_id uuid not null,
  aggregate_version bigint not null check (aggregate_version > 0),
  result text not null check (result in ('succeeded', 'removed', 'left')),
  occurred_at timestamptz not null default now(),
  unique (authenticated_user_id, correlation_id)
);

create index household_audit_events_household_time_idx
  on app_private.household_audit_events(household_id, occurred_at desc);

revoke all on table app_private.household_member_command_requests
  from public, anon, authenticated;
revoke all on table app_private.household_audit_events
  from public, anon, authenticated;

create or replace function app_private.reject_household_audit_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'household audit events are immutable';
end;
$$;

revoke all on function app_private.reject_household_audit_mutation()
  from public;

create trigger household_audit_events_immutable
before update or delete on app_private.household_audit_events
for each row execute function app_private.reject_household_audit_mutation();

create or replace function app_private.reassign_active_household_after_removal(
  p_authenticated_user_id uuid,
  p_removed_household_id uuid,
  p_removed_member_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_deleted_count integer;
  v_fallback_household_id uuid;
  v_fallback_member_id uuid;
begin
  delete from public.user_active_households as active_household
  where active_household.auth_user_id = p_authenticated_user_id
    and active_household.household_id = p_removed_household_id
    and active_household.member_id = p_removed_member_id;

  get diagnostics v_deleted_count = row_count;
  if v_deleted_count = 0 then
    return;
  end if;

  select member.household_id, member.id
  into v_fallback_household_id, v_fallback_member_id
  from public.household_members as member
  join public.households as household
    on household.id = member.household_id
   and household.deleted_at is null
  where member.auth_user_id = p_authenticated_user_id
    and member.removed_at is null
    and member.household_id <> p_removed_household_id
  order by member.joined_at, member.id
  limit 1;

  if found then
    insert into public.user_active_households (
      auth_user_id,
      household_id,
      member_id
    )
    values (
      p_authenticated_user_id,
      v_fallback_household_id,
      v_fallback_member_id
    )
    on conflict (auth_user_id) do update
    set household_id = excluded.household_id,
        member_id = excluded.member_id;
  end if;
end;
$$;

revoke all on function app_private.reassign_active_household_after_removal(
  uuid,
  uuid,
  uuid
) from public;

create or replace function public.get_household_member_roster(
  p_household_id uuid
)
returns table (
  household_id uuid,
  household_name text,
  household_version bigint,
  member_id uuid,
  display_name text,
  role text,
  member_version bigint,
  is_current_user boolean
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
      errcode = 'KFM01',
      message = 'authentication required';
  end if;

  if p_household_id is null then
    raise exception using
      errcode = 'KFM02',
      message = 'invalid household member input';
  end if;

  if not exists (
    select 1
    from public.households as household
    join public.household_members as caller
      on caller.household_id = household.id
     and caller.auth_user_id = v_authenticated_user_id
     and caller.removed_at is null
    where household.id = p_household_id
      and household.deleted_at is null
  ) then
    raise exception using
      errcode = 'KFM05',
      message = 'household member not found or forbidden';
  end if;

  return query
  select
    household.id,
    household.name,
    household.version,
    member.id,
    member.display_name,
    member.role::text,
    member.version,
    member.auth_user_id = v_authenticated_user_id
  from public.households as household
  join public.household_members as member
    on member.household_id = household.id
   and member.removed_at is null
  where household.id = p_household_id
    and household.deleted_at is null
  order by
    case member.role
      when 'owner' then 0
      when 'admin' then 1
      else 2
    end,
    lower(member.display_name),
    member.id;
end;
$$;

revoke all on function public.get_household_member_roster(uuid)
  from public, anon, authenticated;
grant execute on function public.get_household_member_roster(uuid)
  to authenticated;

create or replace function public.change_household_member_role(
  p_authenticated_user_id uuid,
  p_household_id uuid,
  p_target_member_id uuid,
  p_new_role text,
  p_expected_version bigint,
  p_idempotency_key uuid
)
returns table (
  household_id uuid,
  member_id uuid,
  role text,
  version bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_new_role text := lower(btrim(p_new_role));
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_result jsonb;
  v_actor_member_id uuid;
  v_actor_role public.household_role;
  v_target_role public.household_role;
  v_target_version bigint;
begin
  if p_authenticated_user_id is null
    or not exists (
      select 1
      from auth.users as authenticated_user
      where authenticated_user.id = p_authenticated_user_id
        and authenticated_user.deleted_at is null
    ) then
    raise exception using
      errcode = 'KFM01',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or p_target_member_id is null
    or p_idempotency_key is null
    or p_expected_version is null
    or p_expected_version < 1
    or v_new_role is null
    or v_new_role not in ('admin', 'member') then
    raise exception using
      errcode = 'KFM02',
      message = 'invalid household member input';
  end if;

  v_request_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'operation', 'change_role',
        'household_id', p_household_id,
        'target_member_id', p_target_member_id,
        'new_role', v_new_role,
        'expected_version', p_expected_version
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      p_authenticated_user_id::text
        || ':household-member-command:'
        || p_idempotency_key::text,
      0
    )
  );

  select request.request_hash, request.result
  into v_existing_request_hash, v_result
  from app_private.household_member_command_requests as request
  where request.authenticated_user_id = p_authenticated_user_id
    and request.idempotency_key = p_idempotency_key;

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFM04',
        message = 'idempotency key reused with different member input';
    end if;
    return query select
      (v_result->>'household_id')::uuid,
      (v_result->>'member_id')::uuid,
      v_result->>'role',
      (v_result->>'version')::bigint;
    return;
  end if;

  select actor.id, actor.role
  into v_actor_member_id, v_actor_role
  from public.household_members as actor
  join public.households as household
    on household.id = actor.household_id
   and household.deleted_at is null
  where actor.household_id = p_household_id
    and actor.auth_user_id = p_authenticated_user_id
    and actor.removed_at is null
  for update of actor;

  if not found or v_actor_role not in ('owner', 'admin') then
    raise exception using
      errcode = 'KFM05',
      message = 'household member not found or forbidden';
  end if;

  select target.role, target.version
  into v_target_role, v_target_version
  from public.household_members as target
  where target.household_id = p_household_id
    and target.id = p_target_member_id
    and target.removed_at is null
  for update;

  if not found then
    raise exception using
      errcode = 'KFM05',
      message = 'household member not found or forbidden';
  end if;

  if v_target_version <> p_expected_version then
    raise exception using
      errcode = 'KFM06',
      message = 'household member version conflict';
  end if;

  if p_target_member_id = v_actor_member_id then
    raise exception using
      errcode = 'KFM07',
      message = 'role change not allowed';
  end if;

  if v_target_role = 'owner' then
    raise exception using
      errcode = 'KFM08',
      message = 'owner transfer required';
  end if;

  if v_actor_role = 'admin'
    and not (v_target_role = 'member' and v_new_role = 'admin') then
    raise exception using
      errcode = 'KFM03',
      message = 'household member permission denied';
  end if;

  if v_target_role::text <> v_new_role then
    update public.household_members as target
    set role = v_new_role::public.household_role
    where target.household_id = p_household_id
      and target.id = p_target_member_id
    returning target.version into v_target_version;

    insert into app_private.household_audit_events (
      household_id,
      authenticated_user_id,
      actor_member_id,
      action,
      target_member_id,
      correlation_id,
      aggregate_version,
      result
    )
    values (
      p_household_id,
      p_authenticated_user_id,
      v_actor_member_id,
      'member.role_changed',
      p_target_member_id,
      p_idempotency_key,
      v_target_version,
      'succeeded'
    );
  end if;

  v_result := jsonb_build_object(
    'household_id', p_household_id,
    'member_id', p_target_member_id,
    'role', v_new_role,
    'version', v_target_version
  );

  insert into app_private.household_member_command_requests (
    authenticated_user_id,
    idempotency_key,
    operation,
    request_hash,
    result
  )
  values (
    p_authenticated_user_id,
    p_idempotency_key,
    'change_role',
    v_request_hash,
    v_result
  );

  return query select
    p_household_id,
    p_target_member_id,
    v_new_role,
    v_target_version;
end;
$$;

create or replace function public.remove_household_member(
  p_authenticated_user_id uuid,
  p_household_id uuid,
  p_target_member_id uuid,
  p_expected_version bigint,
  p_idempotency_key uuid
)
returns table (
  household_id uuid,
  member_id uuid,
  version bigint,
  removed_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_result jsonb;
  v_actor_member_id uuid;
  v_actor_role public.household_role;
  v_target_auth_user_id uuid;
  v_target_role public.household_role;
  v_target_version bigint;
  v_removed_at timestamptz;
begin
  if p_authenticated_user_id is null
    or not exists (
      select 1
      from auth.users as authenticated_user
      where authenticated_user.id = p_authenticated_user_id
        and authenticated_user.deleted_at is null
    ) then
    raise exception using
      errcode = 'KFM01',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or p_target_member_id is null
    or p_idempotency_key is null
    or p_expected_version is null
    or p_expected_version < 1 then
    raise exception using
      errcode = 'KFM02',
      message = 'invalid household member input';
  end if;

  v_request_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'operation', 'remove_member',
        'household_id', p_household_id,
        'target_member_id', p_target_member_id,
        'expected_version', p_expected_version
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      p_authenticated_user_id::text
        || ':household-member-command:'
        || p_idempotency_key::text,
      0
    )
  );

  select request.request_hash, request.result
  into v_existing_request_hash, v_result
  from app_private.household_member_command_requests as request
  where request.authenticated_user_id = p_authenticated_user_id
    and request.idempotency_key = p_idempotency_key;

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFM04',
        message = 'idempotency key reused with different member input';
    end if;
    return query select
      (v_result->>'household_id')::uuid,
      (v_result->>'member_id')::uuid,
      (v_result->>'version')::bigint,
      (v_result->>'removed_at')::timestamptz;
    return;
  end if;

  select actor.id, actor.role
  into v_actor_member_id, v_actor_role
  from public.household_members as actor
  join public.households as household
    on household.id = actor.household_id
   and household.deleted_at is null
  where actor.household_id = p_household_id
    and actor.auth_user_id = p_authenticated_user_id
    and actor.removed_at is null
  for update of actor;

  if not found or v_actor_role not in ('owner', 'admin') then
    raise exception using
      errcode = 'KFM05',
      message = 'household member not found or forbidden';
  end if;

  select target.auth_user_id, target.role, target.version
  into v_target_auth_user_id, v_target_role, v_target_version
  from public.household_members as target
  where target.household_id = p_household_id
    and target.id = p_target_member_id
    and target.removed_at is null
  for update;

  if not found then
    raise exception using
      errcode = 'KFM05',
      message = 'household member not found or forbidden';
  end if;

  if v_target_version <> p_expected_version then
    raise exception using
      errcode = 'KFM06',
      message = 'household member version conflict';
  end if;

  if p_target_member_id = v_actor_member_id then
    raise exception using
      errcode = 'KFM07',
      message = 'use leave household for self removal';
  end if;

  if v_target_role = 'owner' then
    raise exception using
      errcode = 'KFM08',
      message = 'owner transfer required';
  end if;

  if v_actor_role = 'admin' and v_target_role <> 'member' then
    raise exception using
      errcode = 'KFM03',
      message = 'household member permission denied';
  end if;

  v_removed_at := clock_timestamp();
  update public.household_members as target
  set removed_at = v_removed_at
  where target.household_id = p_household_id
    and target.id = p_target_member_id
  returning target.version into v_target_version;

  update public.household_invites as invite
  set status = 'revoked',
      revoked_at = v_removed_at
  where invite.household_id = p_household_id
    and invite.created_by_member_id = p_target_member_id
    and invite.status = 'active';

  perform app_private.reassign_active_household_after_removal(
    v_target_auth_user_id,
    p_household_id,
    p_target_member_id
  );

  insert into app_private.household_audit_events (
    household_id,
    authenticated_user_id,
    actor_member_id,
    action,
    target_member_id,
    correlation_id,
    aggregate_version,
    result
  )
  values (
    p_household_id,
    p_authenticated_user_id,
    v_actor_member_id,
    'member.removed',
    p_target_member_id,
    p_idempotency_key,
    v_target_version,
    'removed'
  );

  v_result := jsonb_build_object(
    'household_id', p_household_id,
    'member_id', p_target_member_id,
    'version', v_target_version,
    'removed_at', v_removed_at
  );

  insert into app_private.household_member_command_requests (
    authenticated_user_id,
    idempotency_key,
    operation,
    request_hash,
    result
  )
  values (
    p_authenticated_user_id,
    p_idempotency_key,
    'remove_member',
    v_request_hash,
    v_result
  );

  return query select
    p_household_id,
    p_target_member_id,
    v_target_version,
    v_removed_at;
end;
$$;

create or replace function public.leave_household(
  p_authenticated_user_id uuid,
  p_household_id uuid,
  p_expected_version bigint,
  p_idempotency_key uuid
)
returns table (
  household_id uuid,
  member_id uuid,
  version bigint,
  removed_at timestamptz,
  active_household_id uuid,
  active_member_id uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_result jsonb;
  v_actor_member_id uuid;
  v_actor_role public.household_role;
  v_actor_version bigint;
  v_removed_at timestamptz;
  v_active_household_id uuid;
  v_active_member_id uuid;
begin
  if p_authenticated_user_id is null
    or not exists (
      select 1
      from auth.users as authenticated_user
      where authenticated_user.id = p_authenticated_user_id
        and authenticated_user.deleted_at is null
    ) then
    raise exception using
      errcode = 'KFM01',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or p_idempotency_key is null
    or p_expected_version is null
    or p_expected_version < 1 then
    raise exception using
      errcode = 'KFM02',
      message = 'invalid household member input';
  end if;

  v_request_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'operation', 'leave_household',
        'household_id', p_household_id,
        'expected_version', p_expected_version
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      p_authenticated_user_id::text
        || ':household-member-command:'
        || p_idempotency_key::text,
      0
    )
  );

  select request.request_hash, request.result
  into v_existing_request_hash, v_result
  from app_private.household_member_command_requests as request
  where request.authenticated_user_id = p_authenticated_user_id
    and request.idempotency_key = p_idempotency_key;

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFM04',
        message = 'idempotency key reused with different member input';
    end if;
    return query select
      (v_result->>'household_id')::uuid,
      (v_result->>'member_id')::uuid,
      (v_result->>'version')::bigint,
      (v_result->>'removed_at')::timestamptz,
      nullif(v_result->>'active_household_id', '')::uuid,
      nullif(v_result->>'active_member_id', '')::uuid;
    return;
  end if;

  select actor.id, actor.role, actor.version
  into v_actor_member_id, v_actor_role, v_actor_version
  from public.household_members as actor
  join public.households as household
    on household.id = actor.household_id
   and household.deleted_at is null
  where actor.household_id = p_household_id
    and actor.auth_user_id = p_authenticated_user_id
    and actor.removed_at is null
  for update of actor;

  if not found then
    raise exception using
      errcode = 'KFM05',
      message = 'household member not found or forbidden';
  end if;

  if v_actor_version <> p_expected_version then
    raise exception using
      errcode = 'KFM06',
      message = 'household member version conflict';
  end if;

  if v_actor_role = 'owner' then
    raise exception using
      errcode = 'KFM08',
      message = 'owner transfer required';
  end if;

  v_removed_at := clock_timestamp();
  update public.household_members as actor
  set removed_at = v_removed_at
  where actor.household_id = p_household_id
    and actor.id = v_actor_member_id
  returning actor.version into v_actor_version;

  update public.household_invites as invite
  set status = 'revoked',
      revoked_at = v_removed_at
  where invite.household_id = p_household_id
    and invite.created_by_member_id = v_actor_member_id
    and invite.status = 'active';

  perform app_private.reassign_active_household_after_removal(
    p_authenticated_user_id,
    p_household_id,
    v_actor_member_id
  );

  select active_household.household_id, active_household.member_id
  into v_active_household_id, v_active_member_id
  from public.user_active_households as active_household
  where active_household.auth_user_id = p_authenticated_user_id;

  insert into app_private.household_audit_events (
    household_id,
    authenticated_user_id,
    actor_member_id,
    action,
    target_member_id,
    correlation_id,
    aggregate_version,
    result
  )
  values (
    p_household_id,
    p_authenticated_user_id,
    v_actor_member_id,
    'member.removed',
    v_actor_member_id,
    p_idempotency_key,
    v_actor_version,
    'left'
  );

  v_result := jsonb_build_object(
    'household_id', p_household_id,
    'member_id', v_actor_member_id,
    'version', v_actor_version,
    'removed_at', v_removed_at,
    'active_household_id', v_active_household_id,
    'active_member_id', v_active_member_id
  );

  insert into app_private.household_member_command_requests (
    authenticated_user_id,
    idempotency_key,
    operation,
    request_hash,
    result
  )
  values (
    p_authenticated_user_id,
    p_idempotency_key,
    'leave_household',
    v_request_hash,
    v_result
  );

  return query select
    p_household_id,
    v_actor_member_id,
    v_actor_version,
    v_removed_at,
    v_active_household_id,
    v_active_member_id;
end;
$$;

create or replace function public.transfer_household_owner(
  p_authenticated_user_id uuid,
  p_household_id uuid,
  p_new_owner_member_id uuid,
  p_expected_version bigint,
  p_idempotency_key uuid
)
returns table (
  household_id uuid,
  owner_member_id uuid,
  version bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_result jsonb;
  v_actor_member_id uuid;
  v_actor_role public.household_role;
  v_household_owner_member_id uuid;
  v_household_version bigint;
  v_new_owner_role public.household_role;
begin
  if p_authenticated_user_id is null
    or not exists (
      select 1
      from auth.users as authenticated_user
      where authenticated_user.id = p_authenticated_user_id
        and authenticated_user.deleted_at is null
    ) then
    raise exception using
      errcode = 'KFM01',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or p_new_owner_member_id is null
    or p_idempotency_key is null
    or p_expected_version is null
    or p_expected_version < 1 then
    raise exception using
      errcode = 'KFM02',
      message = 'invalid household member input';
  end if;

  v_request_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'operation', 'transfer_owner',
        'household_id', p_household_id,
        'new_owner_member_id', p_new_owner_member_id,
        'expected_version', p_expected_version
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      p_authenticated_user_id::text
        || ':household-member-command:'
        || p_idempotency_key::text,
      0
    )
  );

  select request.request_hash, request.result
  into v_existing_request_hash, v_result
  from app_private.household_member_command_requests as request
  where request.authenticated_user_id = p_authenticated_user_id
    and request.idempotency_key = p_idempotency_key;

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFM04',
        message = 'idempotency key reused with different member input';
    end if;
    return query select
      (v_result->>'household_id')::uuid,
      (v_result->>'owner_member_id')::uuid,
      (v_result->>'version')::bigint;
    return;
  end if;

  select household.owner_member_id, household.version
  into v_household_owner_member_id, v_household_version
  from public.households as household
  where household.id = p_household_id
    and household.deleted_at is null
  for update;

  if not found then
    raise exception using
      errcode = 'KFM05',
      message = 'household member not found or forbidden';
  end if;

  if v_household_version <> p_expected_version then
    raise exception using
      errcode = 'KFM06',
      message = 'household version conflict';
  end if;

  select actor.id, actor.role
  into v_actor_member_id, v_actor_role
  from public.household_members as actor
  where actor.household_id = p_household_id
    and actor.auth_user_id = p_authenticated_user_id
    and actor.removed_at is null
  for update;

  if not found
    or v_actor_role <> 'owner'
    or v_actor_member_id <> v_household_owner_member_id then
    raise exception using
      errcode = 'KFM05',
      message = 'household member not found or forbidden';
  end if;

  if p_new_owner_member_id = v_actor_member_id then
    raise exception using
      errcode = 'KFM07',
      message = 'new owner must be another active member';
  end if;

  select target.role
  into v_new_owner_role
  from public.household_members as target
  where target.household_id = p_household_id
    and target.id = p_new_owner_member_id
    and target.removed_at is null
  for update;

  if not found or v_new_owner_role = 'owner' then
    raise exception using
      errcode = 'KFM05',
      message = 'household member not found or forbidden';
  end if;

  update public.household_members as current_owner
  set role = 'admin'
  where current_owner.household_id = p_household_id
    and current_owner.id = v_actor_member_id;

  update public.household_members as new_owner
  set role = 'owner'
  where new_owner.household_id = p_household_id
    and new_owner.id = p_new_owner_member_id;

  update public.households as household
  set owner_member_id = p_new_owner_member_id
  where household.id = p_household_id
  returning household.version into v_household_version;

  perform app_private.assert_household_owner_integrity(p_household_id);

  insert into app_private.household_audit_events (
    household_id,
    authenticated_user_id,
    actor_member_id,
    action,
    target_member_id,
    correlation_id,
    aggregate_version,
    result
  )
  values (
    p_household_id,
    p_authenticated_user_id,
    v_actor_member_id,
    'household.owner_transferred',
    p_new_owner_member_id,
    p_idempotency_key,
    v_household_version,
    'succeeded'
  );

  v_result := jsonb_build_object(
    'household_id', p_household_id,
    'owner_member_id', p_new_owner_member_id,
    'version', v_household_version
  );

  insert into app_private.household_member_command_requests (
    authenticated_user_id,
    idempotency_key,
    operation,
    request_hash,
    result
  )
  values (
    p_authenticated_user_id,
    p_idempotency_key,
    'transfer_owner',
    v_request_hash,
    v_result
  );

  return query select
    p_household_id,
    p_new_owner_member_id,
    v_household_version;
end;
$$;

revoke all on function public.change_household_member_role(
  uuid,
  uuid,
  uuid,
  text,
  bigint,
  uuid
) from public, anon, authenticated;
revoke all on function public.remove_household_member(
  uuid,
  uuid,
  uuid,
  bigint,
  uuid
) from public, anon, authenticated;
revoke all on function public.leave_household(
  uuid,
  uuid,
  bigint,
  uuid
) from public, anon, authenticated;
revoke all on function public.transfer_household_owner(
  uuid,
  uuid,
  uuid,
  bigint,
  uuid
) from public, anon, authenticated;

grant execute on function public.change_household_member_role(
  uuid,
  uuid,
  uuid,
  text,
  bigint,
  uuid
) to service_role;
grant execute on function public.remove_household_member(
  uuid,
  uuid,
  uuid,
  bigint,
  uuid
) to service_role;
grant execute on function public.leave_household(
  uuid,
  uuid,
  bigint,
  uuid
) to service_role;
grant execute on function public.transfer_household_owner(
  uuid,
  uuid,
  uuid,
  bigint,
  uuid
) to service_role;
