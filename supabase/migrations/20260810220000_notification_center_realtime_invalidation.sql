-- KinFlow WP05-16 content-free user invalidation for Notification Center.

create table public.notification_sync_watermarks (
  auth_user_id uuid primary key
    references auth.users(id) on delete cascade,
  generation bigint not null default 1 check (generation > 0),
  changed_at timestamptz not null default pg_catalog.now()
);

alter table public.notification_sync_watermarks enable row level security;
alter table public.notification_sync_watermarks force row level security;

-- The row remains visible to its authenticated owner after household access is
-- revoked so that the client can receive the signal and purge its old snapshot.
create policy notification_sync_watermarks_select_self
on public.notification_sync_watermarks
for select
to authenticated
using (auth_user_id = (select auth.uid()));

revoke all on table public.notification_sync_watermarks
  from public, anon, authenticated, service_role;
grant select on table public.notification_sync_watermarks to authenticated;

create or replace function app_private.advance_notification_sync_watermark(
  p_auth_user_id uuid,
  p_changed_at timestamptz
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notification_sync_watermarks (
    auth_user_id,
    generation,
    changed_at
  )
  values (
    p_auth_user_id,
    1,
    coalesce(p_changed_at, pg_catalog.statement_timestamp())
  )
  on conflict (auth_user_id) do update
  set generation = public.notification_sync_watermarks.generation + 1,
      changed_at = greatest(
        public.notification_sync_watermarks.changed_at,
        excluded.changed_at
      );
$$;

revoke all on function app_private.advance_notification_sync_watermark(
  uuid,
  timestamptz
) from public, anon, authenticated, service_role;

create or replace function app_private.advance_notification_sync_from_inbox()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_user_id uuid;
begin
  for v_auth_user_id in
    select distinct changed.recipient_user_id
    from changed_notification_inbox as changed
  loop
    perform app_private.advance_notification_sync_watermark(
      v_auth_user_id,
      pg_catalog.statement_timestamp()
    );
  end loop;
  return null;
end;
$$;

revoke all on function app_private.advance_notification_sync_from_inbox()
  from public, anon, authenticated, service_role;

create or replace function
app_private.advance_notification_sync_from_preferences()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_user_id uuid;
begin
  for v_auth_user_id in
    select distinct changed.auth_user_id
    from changed_notification_preferences as changed
  loop
    perform app_private.advance_notification_sync_watermark(
      v_auth_user_id,
      pg_catalog.statement_timestamp()
    );
  end loop;
  return null;
end;
$$;

revoke all on function
  app_private.advance_notification_sync_from_preferences()
  from public, anon, authenticated, service_role;

create or replace function app_private.advance_notification_sync_from_members()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_user_id uuid;
begin
  for v_auth_user_id in
    select distinct affected.auth_user_id
    from (
      select previous.auth_user_id
      from previous_notification_members as previous
      union
      select changed.auth_user_id
      from changed_notification_members as changed
    ) as affected
  loop
    perform app_private.advance_notification_sync_watermark(
      v_auth_user_id,
      pg_catalog.statement_timestamp()
    );
  end loop;
  return null;
end;
$$;

revoke all on function app_private.advance_notification_sync_from_members()
  from public, anon, authenticated, service_role;

create or replace function
app_private.advance_notification_sync_from_households()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_user_id uuid;
begin
  for v_auth_user_id in
    select distinct member.auth_user_id
    from changed_notification_households as changed
    join public.household_members as member
      on member.household_id = changed.id
     and member.removed_at is null
  loop
    perform app_private.advance_notification_sync_watermark(
      v_auth_user_id,
      pg_catalog.statement_timestamp()
    );
  end loop;
  return null;
end;
$$;

revoke all on function
  app_private.advance_notification_sync_from_households()
  from public, anon, authenticated, service_role;

create trigger notification_inbox_insert_advance_sync_watermark
after insert on public.notification_inbox_items
referencing new table as changed_notification_inbox
for each statement execute function
  app_private.advance_notification_sync_from_inbox();

create trigger notification_inbox_update_advance_sync_watermark
after update on public.notification_inbox_items
referencing new table as changed_notification_inbox
for each statement execute function
  app_private.advance_notification_sync_from_inbox();

create trigger notification_preferences_insert_advance_sync_watermark
after insert on public.notification_preferences
referencing new table as changed_notification_preferences
for each statement execute function
  app_private.advance_notification_sync_from_preferences();

create trigger notification_preferences_update_advance_sync_watermark
after update on public.notification_preferences
referencing new table as changed_notification_preferences
for each statement execute function
  app_private.advance_notification_sync_from_preferences();

create trigger household_members_update_advance_notification_sync_watermark
after update on public.household_members
referencing old table as previous_notification_members
  new table as changed_notification_members
for each statement execute function
  app_private.advance_notification_sync_from_members();

create trigger households_update_advance_notification_sync_watermark
after update on public.households
referencing new table as changed_notification_households
for each statement execute function
  app_private.advance_notification_sync_from_households();

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
      and tablename = 'notification_sync_watermarks'
  ) then
    alter publication supabase_realtime
      add table public.notification_sync_watermarks;
  end if;
end;
$$;

comment on table public.notification_sync_watermarks is
  'WP05-16 content-free user generation for Notification Center invalidation.';
comment on function app_private.advance_notification_sync_watermark(
  uuid,
  timestamptz
) is
  'Trusted monotonic notification invalidation writer; not an API mutation surface.';
