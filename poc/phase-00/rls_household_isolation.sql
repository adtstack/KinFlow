\set ON_ERROR_STOP on

begin;

create extension if not exists pgcrypto;
create schema auth;
create schema app_private;

create role authenticated nologin;

create or replace function auth.uid()
returns uuid
language sql
stable
set search_path = ''
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

create type public.household_role as enum ('owner', 'admin', 'member', 'managed_child');

create table public.households (
  id uuid primary key,
  name text not null,
  deleted_at timestamptz
);

create table public.household_members (
  id uuid primary key,
  household_id uuid not null references public.households(id) on delete cascade,
  auth_user_id uuid,
  display_name text not null,
  role public.household_role not null,
  removed_at timestamptz,
  constraint managed_child_identity_ck check (
    (role = 'managed_child' and auth_user_id is null)
    or (role <> 'managed_child' and auth_user_id is not null)
  )
);

create or replace function app_private.is_active_household_member(p_household_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.household_members hm
    where hm.household_id = p_household_id
      and hm.auth_user_id = auth.uid()
      and hm.removed_at is null
  )
$$;

revoke all on function app_private.is_active_household_member(uuid) from public;
grant usage on schema public, app_private, auth to authenticated;
grant execute on function auth.uid() to authenticated;
grant execute on function app_private.is_active_household_member(uuid) to authenticated;
grant select on public.households, public.household_members to authenticated;

alter table public.households enable row level security;
alter table public.households force row level security;
alter table public.household_members enable row level security;
alter table public.household_members force row level security;

create policy households_select_member on public.households
for select to authenticated
using (app_private.is_active_household_member(id));

create policy household_members_select_member on public.household_members
for select to authenticated
using (app_private.is_active_household_member(household_id));

insert into public.households (id, name) values
  ('10000000-0000-0000-0000-000000000001', 'Household A'),
  ('20000000-0000-0000-0000-000000000002', 'Household B');

insert into public.household_members (
  id,
  household_id,
  auth_user_id,
  display_name,
  role,
  removed_at
) values
  (
    '11000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'Owner A',
    'owner',
    null
  ),
  (
    '12000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000001',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'Member A',
    'member',
    null
  ),
  (
    '21000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000002',
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'Owner B',
    'owner',
    null
  ),
  (
    '22000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000002',
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'Removed B',
    'member',
    now()
  );

set role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  false
);

do $$
declare
  household_count integer;
  member_count integer;
begin
  select count(*) into household_count from public.households;
  if household_count <> 1 then
    raise exception 'User A expected 1 visible household, got %', household_count;
  end if;

  if exists (
    select 1
    from public.households
    where id = '20000000-0000-0000-0000-000000000002'
  ) then
    raise exception 'User A can read cross-household row';
  end if;

  select count(*) into member_count from public.household_members;
  if member_count <> 2 then
    raise exception 'User A expected 2 same-household members, got %', member_count;
  end if;
end
$$;

select set_config(
  'request.jwt.claim.sub',
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  false
);

do $$
begin
  if exists (select 1 from public.households) then
    raise exception 'Removed member can still read a household';
  end if;
end
$$;

select set_config(
  'request.jwt.claim.sub',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  false
);

do $$
begin
  begin
    insert into public.households (id, name)
    values ('30000000-0000-0000-0000-000000000003', 'Forbidden');
    raise exception 'Authenticated direct insert unexpectedly succeeded';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

reset role;

select 'PASS: household RLS isolation and direct-write denial' as phase_00_result;

rollback;
