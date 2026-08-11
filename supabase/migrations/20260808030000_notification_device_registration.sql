-- KinFlow WP05-03 notification device registration and token lifecycle.
-- Raw provider tokens are sealed by the notification-endpoint Edge Function.
-- PostgreSQL stores only an opaque AES-GCM envelope, SHA-256 fingerprint, and
-- a one-way binding-secret hash. No client role can read those fields.

create table public.notification_endpoints (
  id uuid primary key default extensions.gen_random_uuid(),
  auth_user_id uuid not null
    references auth.users(id) on delete cascade,
  household_id uuid not null
    references public.households(id) on delete cascade,
  member_id uuid not null,
  installation_id uuid not null,
  channel text not null check (channel = 'native_push'),
  platform text not null check (platform in ('ios', 'android')),
  token_ciphertext bytea not null check (
    octet_length(token_ciphertext) between 29 and 8192
  ),
  token_fingerprint bytea not null check (
    octet_length(token_fingerprint) = 32
  ),
  token_key_version integer not null check (
    token_key_version between 1 and 1000000
  ),
  revocation_secret_hash bytea not null check (
    octet_length(revocation_secret_hash) = 32
  ),
  permission_state text not null check (
    permission_state in ('granted', 'denied', 'prompt', 'unsupported')
  ),
  locale text check (
    locale is null
    or (
      char_length(locale) between 2 and 35
      and locale = btrim(locale)
      and locale ~ '^[A-Za-z]{2,3}([_-][A-Za-z0-9]{2,8})*$'
    )
  ),
  timezone text not null check (
    app_private.is_valid_iana_timezone(timezone)
  ),
  app_version text not null check (
    char_length(app_version) between 1 and 64
    and app_version = btrim(app_version)
    and app_version !~ '[[:cntrl:]]'
  ),
  runtime_version text not null check (
    char_length(runtime_version) between 1 and 64
    and runtime_version = btrim(runtime_version)
    and runtime_version !~ '[[:cntrl:]]'
  ),
  last_registration_id uuid not null,
  last_seen_at timestamptz not null,
  revoked_at timestamptz,
  revocation_reason text check (
    revocation_reason is null
    or revocation_reason in (
      'client_revoked',
      'token_reassigned',
      'provider_unregistered',
      'provider_invalid_argument',
      'membership_removed',
      'permission_revoked',
      'rollback_disabled'
    )
  ),
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  version bigint not null default 1 check (version > 0),
  unique (auth_user_id, installation_id, channel),
  unique (auth_user_id, last_registration_id),
  constraint notification_endpoint_member_fk
    foreign key (household_id, member_id, auth_user_id)
    references public.household_members(household_id, id, auth_user_id)
    on delete cascade,
  constraint notification_endpoint_lifecycle_ck check (
    (
      revoked_at is null
      and revocation_reason is null
      and permission_state = 'granted'
    )
    or (
      revoked_at is not null
      and revocation_reason is not null
      and revoked_at >= created_at
    )
  ),
  constraint notification_endpoint_timestamps_ck check (
    updated_at >= created_at
    and last_seen_at >= created_at
  )
);

create unique index notification_endpoints_active_token_uq
  on public.notification_endpoints(channel, token_fingerprint)
  where revoked_at is null;

create index notification_endpoints_active_recipient_idx
  on public.notification_endpoints(auth_user_id, household_id, last_seen_at desc)
  where revoked_at is null and permission_state = 'granted';

create index notification_endpoints_installation_idx
  on public.notification_endpoints(installation_id, channel, last_registration_id);

create or replace function app_private.set_notification_endpoint_updated_at_and_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := greatest(
    pg_catalog.clock_timestamp(),
    old.updated_at,
    new.last_seen_at,
    coalesce(new.revoked_at, '-infinity'::timestamptz)
  );
  new.version := old.version + 1;
  return new;
end;
$$;

revoke all on function
  app_private.set_notification_endpoint_updated_at_and_version()
  from public, anon, authenticated, service_role;

create trigger notification_endpoints_set_updated_at_and_version
before update on public.notification_endpoints
for each row execute function
  app_private.set_notification_endpoint_updated_at_and_version();

create table app_private.notification_endpoint_events (
  id uuid primary key default extensions.gen_random_uuid(),
  endpoint_id uuid not null,
  transition text not null check (
    transition in ('registered', 'refreshed', 'rotated', 'revoked')
  ),
  reason_code text check (
    reason_code is null
    or reason_code in (
      'client_revoked',
      'token_reassigned',
      'provider_unregistered',
      'provider_invalid_argument',
      'membership_removed',
      'permission_revoked',
      'rollback_disabled'
    )
  ),
  endpoint_version bigint not null check (endpoint_version > 0),
  occurred_at timestamptz not null,
  constraint notification_endpoint_event_reason_ck check (
    (transition = 'revoked') = (reason_code is not null)
  )
);

create index notification_endpoint_events_endpoint_idx
  on app_private.notification_endpoint_events(
    endpoint_id,
    endpoint_version,
    occurred_at
  );

revoke all on table app_private.notification_endpoint_events
  from public, anon, authenticated, service_role;

create or replace function app_private.reject_notification_endpoint_event_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'notification endpoint events are immutable';
end;
$$;

revoke all on function app_private.reject_notification_endpoint_event_mutation()
  from public, anon, authenticated, service_role;

create trigger notification_endpoint_events_immutable
before update or delete on app_private.notification_endpoint_events
for each row execute function
  app_private.reject_notification_endpoint_event_mutation();

create or replace function app_private.audit_notification_endpoint_transition()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_transition text;
  v_reason_code text;
begin
  if tg_op = 'INSERT' then
    v_transition := 'registered';
  elsif old.revoked_at is null and new.revoked_at is not null then
    v_transition := 'revoked';
    v_reason_code := new.revocation_reason;
  elsif old.revoked_at is not null and new.revoked_at is null then
    v_transition := 'registered';
  elsif old.token_fingerprint is distinct from new.token_fingerprint then
    v_transition := 'rotated';
  elsif old.last_registration_id is distinct from new.last_registration_id then
    v_transition := 'refreshed';
  else
    return new;
  end if;

  insert into app_private.notification_endpoint_events (
    endpoint_id,
    transition,
    reason_code,
    endpoint_version,
    occurred_at
  ) values (
    new.id,
    v_transition,
    v_reason_code,
    new.version,
    new.updated_at
  );
  return new;
end;
$$;

revoke all on function app_private.audit_notification_endpoint_transition()
  from public, anon, authenticated, service_role;

create trigger notification_endpoints_audit_transition
after insert or update on public.notification_endpoints
for each row execute function
  app_private.audit_notification_endpoint_transition();

create or replace function app_private.decode_notification_endpoint_material(
  p_value text,
  p_exact_octets integer,
  p_minimum_octets integer,
  p_maximum_octets integer
)
returns bytea
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_decoded bytea;
  v_canonical text;
  v_octets integer;
begin
  if p_value is null
    or p_value = ''
    or char_length(p_value) > 12000
    or p_value !~ '^[A-Za-z0-9+/]+={0,2}$' then
    raise exception using
      errcode = 'KND01',
      message = 'invalid notification endpoint input';
  end if;

  begin
    v_decoded := pg_catalog.decode(p_value, 'base64');
  exception when others then
    raise exception using
      errcode = 'KND01',
      message = 'invalid notification endpoint input';
  end;
  v_octets := pg_catalog.octet_length(v_decoded);
  v_canonical := pg_catalog.replace(
    pg_catalog.encode(v_decoded, 'base64'),
    pg_catalog.chr(10),
    ''
  );

  if v_canonical <> p_value
    or p_exact_octets is not null and v_octets <> p_exact_octets
    or p_minimum_octets is not null and v_octets < p_minimum_octets
    or p_maximum_octets is not null and v_octets > p_maximum_octets then
    raise exception using
      errcode = 'KND01',
      message = 'invalid notification endpoint input';
  end if;
  return v_decoded;
end;
$$;

revoke all on function app_private.decode_notification_endpoint_material(
  text,
  integer,
  integer,
  integer
) from public, anon, authenticated, service_role;

alter table public.notification_endpoints enable row level security;
alter table public.notification_endpoints force row level security;

create policy notification_endpoints_select_self
on public.notification_endpoints
for select
to authenticated
using (
  auth_user_id = (select auth.uid())
  and app_private.is_active_household_member(household_id)
);

revoke all on table public.notification_endpoints
  from public, anon, authenticated, service_role;

create or replace function public.get_notification_endpoint_status(
  p_installation_id uuid,
  p_channel text default 'native_push'
)
returns table (
  endpoint_id uuid,
  household_id uuid,
  member_id uuid,
  installation_id uuid,
  channel text,
  platform text,
  permission_state text,
  locale text,
  timezone text,
  app_version text,
  runtime_version text,
  last_registration_id uuid,
  last_seen_at timestamptz,
  revoked_at timestamptz,
  revocation_reason text,
  version bigint
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
      errcode = 'KND02',
      message = 'authentication required';
  end if;
  if p_installation_id is null or p_channel <> 'native_push' then
    raise exception using
      errcode = 'KND01',
      message = 'invalid notification endpoint input';
  end if;

  return query
  select
    endpoint.id,
    endpoint.household_id,
    endpoint.member_id,
    endpoint.installation_id,
    endpoint.channel,
    endpoint.platform,
    endpoint.permission_state,
    endpoint.locale,
    endpoint.timezone,
    endpoint.app_version,
    endpoint.runtime_version,
    endpoint.last_registration_id,
    endpoint.last_seen_at,
    endpoint.revoked_at,
    endpoint.revocation_reason,
    endpoint.version
  from public.notification_endpoints as endpoint
  where endpoint.auth_user_id = v_authenticated_user_id
    and endpoint.installation_id = p_installation_id
    and endpoint.channel = p_channel
    and exists (
      select 1
      from public.household_members as member
      join public.households as household
        on household.id = member.household_id
       and household.deleted_at is null
      where member.household_id = endpoint.household_id
        and member.id = endpoint.member_id
        and member.auth_user_id = v_authenticated_user_id
        and member.removed_at is null
    );
end;
$$;

create or replace function public.upsert_notification_endpoint(
  p_authenticated_user_id uuid,
  p_household_id uuid,
  p_installation_id uuid,
  p_channel text,
  p_platform text,
  p_token_ciphertext_base64 text,
  p_token_fingerprint_base64 text,
  p_token_key_version integer,
  p_revocation_secret_hash_base64 text,
  p_permission_state text,
  p_locale text,
  p_timezone text,
  p_app_version text,
  p_runtime_version text,
  p_registration_id uuid,
  p_expected_version bigint,
  p_as_of timestamptz
)
returns table (
  endpoint_id uuid,
  household_id uuid,
  member_id uuid,
  installation_id uuid,
  channel text,
  platform text,
  permission_state text,
  locale text,
  timezone text,
  app_version text,
  runtime_version text,
  last_registration_id uuid,
  last_seen_at timestamptz,
  revoked_at timestamptz,
  revocation_reason text,
  version bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token_ciphertext bytea;
  v_token_fingerprint bytea;
  v_revocation_secret_hash bytea;
  v_member_id uuid;
  v_existing public.notification_endpoints%rowtype;
  v_result public.notification_endpoints%rowtype;
begin
  if p_authenticated_user_id is null
    or p_household_id is null
    or p_installation_id is null
    or p_channel <> 'native_push'
    or p_platform not in ('ios', 'android')
    or p_token_key_version is null
    or p_token_key_version not between 1 and 1000000
    or p_permission_state <> 'granted'
    or p_timezone is null
    or not app_private.is_valid_iana_timezone(p_timezone)
    or p_app_version is null
    or char_length(p_app_version) not between 1 and 64
    or p_app_version <> btrim(p_app_version)
    or p_app_version ~ '[[:cntrl:]]'
    or p_runtime_version is null
    or char_length(p_runtime_version) not between 1 and 64
    or p_runtime_version <> btrim(p_runtime_version)
    or p_runtime_version ~ '[[:cntrl:]]'
    or p_registration_id is null
    or p_expected_version is null
    or p_expected_version < 0
    or p_as_of is null
    or p_locale is not null and (
      char_length(p_locale) not between 2 and 35
      or p_locale <> btrim(p_locale)
      or p_locale !~ '^[A-Za-z]{2,3}([_-][A-Za-z0-9]{2,8})*$'
    ) then
    raise exception using
      errcode = 'KND01',
      message = 'invalid notification endpoint input';
  end if;

  v_token_ciphertext := app_private.decode_notification_endpoint_material(
    p_token_ciphertext_base64, null, 29, 8192
  );
  v_token_fingerprint := app_private.decode_notification_endpoint_material(
    p_token_fingerprint_base64, 32, null, null
  );
  v_revocation_secret_hash := app_private.decode_notification_endpoint_material(
    p_revocation_secret_hash_base64, 32, null, null
  );

  select member.id
  into v_member_id
  from public.household_members as member
  join public.households as household
    on household.id = member.household_id
   and household.deleted_at is null
  where member.household_id = p_household_id
    and member.auth_user_id = p_authenticated_user_id
    and member.removed_at is null;

  if not found then
    raise exception using
      errcode = 'KND03',
      message = 'notification household not found or forbidden';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      p_channel || ':' || pg_catalog.encode(v_token_fingerprint, 'hex'),
      0
    )
  );

  select endpoint.*
  into v_existing
  from public.notification_endpoints as endpoint
  where endpoint.auth_user_id = p_authenticated_user_id
    and endpoint.installation_id = p_installation_id
    and endpoint.channel = p_channel
  for update;

  if found and v_existing.last_registration_id = p_registration_id then
    if v_existing.household_id <> p_household_id
      or v_existing.member_id <> v_member_id
      or v_existing.platform <> p_platform
      or v_existing.token_fingerprint <> v_token_fingerprint
      or v_existing.token_key_version <> p_token_key_version
      or v_existing.revocation_secret_hash <> v_revocation_secret_hash
      or v_existing.permission_state <> p_permission_state
      or v_existing.locale is distinct from p_locale
      or v_existing.timezone <> p_timezone
      or v_existing.app_version <> p_app_version
      or v_existing.runtime_version <> p_runtime_version then
      raise exception using
        errcode = 'KND04',
        message = 'notification registration id reused';
    end if;
    v_result := v_existing;
  else
    if v_existing.id is null and p_expected_version <> 0 then
      raise exception using
        errcode = 'KND06',
        message = 'notification endpoint version conflict';
    elsif v_existing.id is not null
      and v_existing.version <> p_expected_version then
      raise exception using
        errcode = 'KND06',
        message = 'notification endpoint version conflict';
    end if;

    update public.notification_endpoints as endpoint
    set revoked_at = p_as_of,
        revocation_reason = 'token_reassigned'
    where endpoint.channel = p_channel
      and endpoint.token_fingerprint = v_token_fingerprint
      and endpoint.revoked_at is null
      and not (
        endpoint.auth_user_id = p_authenticated_user_id
        and endpoint.installation_id = p_installation_id
      );

    if v_existing.id is null then
      insert into public.notification_endpoints (
        auth_user_id,
        household_id,
        member_id,
        installation_id,
        channel,
        platform,
        token_ciphertext,
        token_fingerprint,
        token_key_version,
        revocation_secret_hash,
        permission_state,
        locale,
        timezone,
        app_version,
        runtime_version,
        last_registration_id,
        last_seen_at,
        created_at,
        updated_at
      ) values (
        p_authenticated_user_id,
        p_household_id,
        v_member_id,
        p_installation_id,
        p_channel,
        p_platform,
        v_token_ciphertext,
        v_token_fingerprint,
        p_token_key_version,
        v_revocation_secret_hash,
        p_permission_state,
        p_locale,
        p_timezone,
        p_app_version,
        p_runtime_version,
        p_registration_id,
        p_as_of,
        p_as_of,
        p_as_of
      )
      returning * into v_result;
    else
      update public.notification_endpoints as endpoint
      set household_id = p_household_id,
          member_id = v_member_id,
          platform = p_platform,
          token_ciphertext = v_token_ciphertext,
          token_fingerprint = v_token_fingerprint,
          token_key_version = p_token_key_version,
          revocation_secret_hash = v_revocation_secret_hash,
          permission_state = p_permission_state,
          locale = p_locale,
          timezone = p_timezone,
          app_version = p_app_version,
          runtime_version = p_runtime_version,
          last_registration_id = p_registration_id,
          last_seen_at = p_as_of,
          revoked_at = null,
          revocation_reason = null
      where endpoint.id = v_existing.id
      returning * into v_result;
    end if;
  end if;

  return query
  select
    v_result.id,
    v_result.household_id,
    v_result.member_id,
    v_result.installation_id,
    v_result.channel,
    v_result.platform,
    v_result.permission_state,
    v_result.locale,
    v_result.timezone,
    v_result.app_version,
    v_result.runtime_version,
    v_result.last_registration_id,
    v_result.last_seen_at,
    v_result.revoked_at,
    v_result.revocation_reason,
    v_result.version;
end;
$$;

create or replace function public.revoke_notification_endpoint_by_secret(
  p_installation_id uuid,
  p_channel text,
  p_registration_id uuid,
  p_revocation_secret_hash_base64 text,
  p_as_of timestamptz
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_revocation_secret_hash bytea;
  v_count integer;
begin
  if p_installation_id is null
    or p_channel <> 'native_push'
    or p_registration_id is null
    or p_as_of is null then
    raise exception using
      errcode = 'KND01',
      message = 'invalid notification endpoint input';
  end if;
  v_revocation_secret_hash := app_private.decode_notification_endpoint_material(
    p_revocation_secret_hash_base64, 32, null, null
  );

  update public.notification_endpoints as endpoint
  set revoked_at = p_as_of,
      revocation_reason = 'client_revoked'
  where endpoint.installation_id = p_installation_id
    and endpoint.channel = p_channel
    and endpoint.last_registration_id = p_registration_id
    and endpoint.revocation_secret_hash = v_revocation_secret_hash
    and endpoint.revoked_at is null;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.invalidate_notification_endpoint(
  p_endpoint_id uuid,
  p_token_fingerprint_base64 text,
  p_reason_code text,
  p_as_of timestamptz
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token_fingerprint bytea;
  v_count integer;
begin
  if p_endpoint_id is null
    or p_reason_code not in (
      'provider_unregistered',
      'provider_invalid_argument'
    )
    or p_as_of is null then
    raise exception using
      errcode = 'KND01',
      message = 'invalid notification endpoint input';
  end if;
  v_token_fingerprint := app_private.decode_notification_endpoint_material(
    p_token_fingerprint_base64, 32, null, null
  );

  update public.notification_endpoints as endpoint
  set revoked_at = p_as_of,
      revocation_reason = p_reason_code
  where endpoint.id = p_endpoint_id
    and endpoint.token_fingerprint = v_token_fingerprint
    and endpoint.revoked_at is null;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function app_private.revoke_removed_member_notification_endpoints()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.removed_at is null and new.removed_at is not null then
    update public.notification_endpoints as endpoint
    set revoked_at = greatest(
          new.removed_at,
          endpoint.last_seen_at,
          pg_catalog.statement_timestamp()
        ),
        revocation_reason = 'membership_removed'
    where endpoint.household_id = new.household_id
      and endpoint.member_id = new.id
      and endpoint.auth_user_id = new.auth_user_id
      and endpoint.revoked_at is null;
  end if;
  return new;
end;
$$;

revoke all on function app_private.revoke_removed_member_notification_endpoints()
  from public, anon, authenticated, service_role;

create trigger household_members_revoke_notification_endpoints
after update of removed_at on public.household_members
for each row execute function
  app_private.revoke_removed_member_notification_endpoints();

revoke all on function public.get_notification_endpoint_status(uuid, text)
  from public, anon, authenticated, service_role;
revoke all on function public.upsert_notification_endpoint(
  uuid,
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  integer,
  text,
  text,
  text,
  text,
  text,
  text,
  uuid,
  bigint,
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.revoke_notification_endpoint_by_secret(
  uuid,
  text,
  uuid,
  text,
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.invalidate_notification_endpoint(
  uuid,
  text,
  text,
  timestamptz
) from public, anon, authenticated, service_role;

grant execute on function public.get_notification_endpoint_status(uuid, text)
  to authenticated;
grant execute on function public.upsert_notification_endpoint(
  uuid,
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  integer,
  text,
  text,
  text,
  text,
  text,
  text,
  uuid,
  bigint,
  timestamptz
) to service_role;
grant execute on function public.revoke_notification_endpoint_by_secret(
  uuid,
  text,
  uuid,
  text,
  timestamptz
) to service_role;
grant execute on function public.invalidate_notification_endpoint(
  uuid,
  text,
  text,
  timestamptz
) to service_role;

comment on table public.notification_endpoints is
  'WP05-03 encrypted native-push endpoint binding; token material is never client-readable.';
comment on table app_private.notification_endpoint_events is
  'WP05-03 immutable content-free endpoint lifecycle audit without token material.';
comment on function public.revoke_notification_endpoint_by_secret(
  uuid,
  text,
  uuid,
  text,
  timestamptz
) is
  'WP05-03 logout/account-switch revoke using a 256-bit binding-secret hash; callers receive no endpoint oracle.';
comment on function public.invalidate_notification_endpoint(
  uuid,
  text,
  text,
  timestamptz
) is
  'WP05-03 provider invalid-token cleanup guarded by the exact current token fingerprint.';
