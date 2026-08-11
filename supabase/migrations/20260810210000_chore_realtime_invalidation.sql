-- KinFlow WP05-15 content-free Chore invalidation for Today and Chores.

create table public.chore_sync_watermarks (
  household_id uuid primary key
    references public.households(id) on delete cascade,
  generation bigint not null default 1 check (generation > 0),
  changed_at timestamptz not null default pg_catalog.now()
);

alter table public.chore_sync_watermarks enable row level security;
alter table public.chore_sync_watermarks force row level security;

create policy chore_sync_watermarks_select_member
on public.chore_sync_watermarks
for select
to authenticated
using (app_private.is_active_household_member(household_id));

revoke all on table public.chore_sync_watermarks
  from public, anon, authenticated;
grant select on table public.chore_sync_watermarks to authenticated;

create or replace function app_private.advance_chore_sync_watermark(
  p_household_id uuid,
  p_changed_at timestamptz
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.chore_sync_watermarks (
    household_id,
    generation,
    changed_at
  )
  values (
    p_household_id,
    1,
    coalesce(p_changed_at, pg_catalog.statement_timestamp())
  )
  on conflict (household_id) do update
  set generation = public.chore_sync_watermarks.generation + 1,
      changed_at = greatest(
        public.chore_sync_watermarks.changed_at,
        excluded.changed_at
      );
$$;

revoke all on function app_private.advance_chore_sync_watermark(
  uuid,
  timestamptz
) from public, anon, authenticated, service_role;

-- Every transition relation below exposes household_id. The shared trigger
-- advances at most once per affected household for each producer statement.
create or replace function app_private.advance_chore_sync_from_changes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_household_id uuid;
begin
  for v_household_id in
    select distinct changed.household_id
    from changed_chore_rows as changed
  loop
    perform app_private.advance_chore_sync_watermark(
      v_household_id,
      pg_catalog.statement_timestamp()
    );
  end loop;
  return null;
end;
$$;

revoke all on function app_private.advance_chore_sync_from_changes()
  from public, anon, authenticated, service_role;

create or replace function app_private.advance_chore_sync_from_households()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_household_id uuid;
begin
  for v_household_id in
    select distinct changed.id
    from changed_chore_households as changed
  loop
    perform app_private.advance_chore_sync_watermark(
      v_household_id,
      pg_catalog.statement_timestamp()
    );
  end loop;
  return null;
end;
$$;

revoke all on function app_private.advance_chore_sync_from_households()
  from public, anon, authenticated, service_role;

create trigger chore_occurrences_insert_advance_sync_watermark
after insert on public.chore_occurrences
referencing new table as changed_chore_rows
for each statement execute function
  app_private.advance_chore_sync_from_changes();

create trigger chore_occurrences_update_advance_sync_watermark
after update on public.chore_occurrences
referencing new table as changed_chore_rows
for each statement execute function
  app_private.advance_chore_sync_from_changes();

create trigger chore_series_update_advance_sync_watermark
after update on public.chore_series
referencing new table as changed_chore_rows
for each statement execute function
  app_private.advance_chore_sync_from_changes();

-- Assignee display name, role, or active-membership changes alter the list
-- projection or its authorization boundary without touching an occurrence.
create trigger household_members_update_advance_chore_sync_watermark
after update on public.household_members
referencing new table as changed_chore_rows
for each statement execute function
  app_private.advance_chore_sync_from_changes();

-- Household timezone and deletion state affect every list query boundary.
create trigger households_update_advance_chore_sync_watermark
after update on public.households
referencing new table as changed_chore_households
for each statement execute function
  app_private.advance_chore_sync_from_households();

do $$
begin
  if exists (
    select 1
    from pg_catalog.pg_publication
    where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'chore_sync_watermarks'
  ) then
    alter publication supabase_realtime
      add table public.chore_sync_watermarks;
  end if;
end;
$$;

comment on table public.chore_sync_watermarks is
  'WP05-15 content-free household generation for Chore list invalidation.';
comment on function app_private.advance_chore_sync_watermark(
  uuid,
  timestamptz
) is
  'Trusted monotonic Chore invalidation writer; not an API mutation surface.';
