-- KinFlow WP01-04 local foundation schema.
-- Store MVP scope: adult accounts only; no Managed Child surfaces.

create extension if not exists pgcrypto with schema extensions;

create schema if not exists app_private;
revoke all on schema app_private from public;

create type public.household_role as enum ('owner', 'admin', 'member');

create or replace function app_private.set_updated_at_and_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  new.version := old.version + 1;
  return new;
end;
$$;

create or replace function app_private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function app_private.set_updated_at_and_version() from public;
revoke all on function app_private.set_updated_at() from public;

create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  locale text not null default 'en' check (char_length(locale) between 2 and 20),
  timezone text not null default 'UTC' check (char_length(timezone) between 1 and 100),
  avatar_key text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  deleted_at timestamptz
);

create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  timezone text not null check (char_length(timezone) between 1 and 100),
  owner_member_id uuid not null,
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  deleted_at timestamptz,
  unique (id, owner_member_id)
);

create table public.household_members (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  role public.household_role not null,
  avatar_key text,
  joined_at timestamptz not null default now(),
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  removed_at timestamptz,
  unique (household_id, id),
  unique (household_id, id, auth_user_id)
);

create unique index household_members_active_auth_uq
  on public.household_members(household_id, auth_user_id)
  where removed_at is null;

create unique index household_members_single_owner_uq
  on public.household_members(household_id)
  where role = 'owner' and removed_at is null;

alter table public.households
  add constraint households_owner_same_household_fk
  foreign key (id, owner_member_id)
  references public.household_members(household_id, id)
  deferrable initially deferred;

create table public.user_active_households (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  member_id uuid not null,
  updated_at timestamptz not null default now(),
  constraint active_household_member_fk
    foreign key (household_id, member_id, auth_user_id)
    references public.household_members(household_id, id, auth_user_id)
    on delete cascade
);

create trigger profiles_set_updated_at_and_version
before update on public.profiles
for each row execute function app_private.set_updated_at_and_version();

create trigger households_set_updated_at_and_version
before update on public.households
for each row execute function app_private.set_updated_at_and_version();

create trigger household_members_set_updated_at_and_version
before update on public.household_members
for each row execute function app_private.set_updated_at_and_version();

create trigger user_active_households_set_updated_at
before update on public.user_active_households
for each row execute function app_private.set_updated_at();

create or replace function app_private.is_active_household_member(
  p_household_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.household_members as member
    where member.household_id = p_household_id
      and member.auth_user_id = (select auth.uid())
      and member.removed_at is null
  )
$$;

revoke all on function app_private.is_active_household_member(uuid) from public;
grant usage on schema app_private to authenticated;
grant execute on function app_private.is_active_household_member(uuid)
  to authenticated;

alter table public.profiles enable row level security;
alter table public.profiles force row level security;
alter table public.households enable row level security;
alter table public.households force row level security;
alter table public.household_members enable row level security;
alter table public.household_members force row level security;
alter table public.user_active_households enable row level security;
alter table public.user_active_households force row level security;

create policy profiles_select_self
on public.profiles
for select
to authenticated
using (auth_user_id = (select auth.uid()));

create policy profiles_update_self
on public.profiles
for update
to authenticated
using (auth_user_id = (select auth.uid()))
with check (auth_user_id = (select auth.uid()));

create policy households_select_member
on public.households
for select
to authenticated
using (app_private.is_active_household_member(id));

create policy household_members_select_member
on public.household_members
for select
to authenticated
using (app_private.is_active_household_member(household_id));

create policy active_household_select_self
on public.user_active_households
for select
to authenticated
using (auth_user_id = (select auth.uid()));

create policy active_household_update_self
on public.user_active_households
for update
to authenticated
using (auth_user_id = (select auth.uid()))
with check (
  auth_user_id = (select auth.uid())
  and exists (
    select 1
    from public.household_members as member
    where member.household_id = user_active_households.household_id
      and member.id = user_active_households.member_id
      and member.auth_user_id = (select auth.uid())
      and member.removed_at is null
  )
);

revoke all on table public.profiles from anon, authenticated;
revoke all on table public.households from anon, authenticated;
revoke all on table public.household_members from anon, authenticated;
revoke all on table public.user_active_households from anon, authenticated;

grant select on table public.profiles to authenticated;
grant update (display_name, locale, timezone, avatar_key)
  on table public.profiles to authenticated;
grant select on table public.households to authenticated;
grant select on table public.household_members to authenticated;
grant select on table public.user_active_households to authenticated;
grant update (household_id, member_id)
  on table public.user_active_households to authenticated;
