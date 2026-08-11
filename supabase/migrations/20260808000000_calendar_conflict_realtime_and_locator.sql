-- KinFlow WP04-06 content-free Calendar invalidation and occurrence locator.

create table public.calendar_sync_watermarks (
  household_id uuid primary key
    references public.households(id) on delete cascade,
  generation bigint not null default 1 check (generation > 0),
  changed_at timestamptz not null default pg_catalog.now()
);

alter table public.calendar_sync_watermarks enable row level security;
alter table public.calendar_sync_watermarks force row level security;

create policy calendar_sync_watermarks_select_member
on public.calendar_sync_watermarks
for select
to authenticated
using (app_private.is_active_household_member(household_id));

revoke all on table public.calendar_sync_watermarks
  from public, anon, authenticated;
grant select on table public.calendar_sync_watermarks to authenticated;

create or replace function app_private.advance_calendar_sync_watermark(
  p_household_id uuid,
  p_changed_at timestamptz
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.calendar_sync_watermarks (
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
  set generation = public.calendar_sync_watermarks.generation + 1,
      changed_at = greatest(
        public.calendar_sync_watermarks.changed_at,
        excluded.changed_at
      );
$$;

revoke all on function app_private.advance_calendar_sync_watermark(
  uuid,
  timestamptz
) from public, anon, authenticated, service_role;

create or replace function app_private.advance_calendar_sync_from_audit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app_private.advance_calendar_sync_watermark(
    new.household_id,
    new.occurred_at
  );
  return new;
end;
$$;

revoke all on function app_private.advance_calendar_sync_from_audit()
  from public, anon, authenticated, service_role;

create trigger calendar_audit_advance_sync_watermark
after insert on app_private.calendar_audit_events
for each row execute function app_private.advance_calendar_sync_from_audit();

-- Horizon materialization inserts occurrences without an interactive audit row.
-- A statement-level transition table advances at most once per household.
create or replace function app_private.advance_calendar_sync_from_occurrences()
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
    from changed_calendar_occurrences as changed
  loop
    perform app_private.advance_calendar_sync_watermark(
      v_household_id,
      pg_catalog.statement_timestamp()
    );
  end loop;
  return null;
end;
$$;

revoke all on function app_private.advance_calendar_sync_from_occurrences()
  from public, anon, authenticated, service_role;

create trigger event_occurrences_insert_advance_sync_watermark
after insert on public.event_occurrences
referencing new table as changed_calendar_occurrences
for each statement execute function
  app_private.advance_calendar_sync_from_occurrences();

create trigger event_occurrences_update_advance_sync_watermark
after update on public.event_occurrences
referencing new table as changed_calendar_occurrences
for each statement execute function
  app_private.advance_calendar_sync_from_occurrences();

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
      and tablename = 'calendar_sync_watermarks'
  ) then
    alter publication supabase_realtime
      add table public.calendar_sync_watermarks;
  end if;
end;
$$;

create or replace function public.get_calendar_occurrence_locator(
  p_household_id uuid,
  p_occurrence_id uuid
)
returns table (
  household_id uuid,
  household_timezone text,
  household_local_date date,
  generated_at timestamptz,
  series_id uuid,
  occurrence_id uuid,
  view_local_date date,
  series_version bigint,
  occurrence_version bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_generated_at timestamptz := pg_catalog.statement_timestamp();
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFE01',
      message = 'authentication required';
  end if;

  if p_household_id is null or p_occurrence_id is null then
    raise exception using
      errcode = 'KFE02',
      message = 'invalid calendar occurrence locator input';
  end if;

  return query
  select
    household.id,
    household.timezone,
    (v_generated_at at time zone household.timezone)::date,
    v_generated_at,
    series.id,
    occurrence.id,
    occurrence.local_start_date,
    series.version,
    occurrence.version
  from public.households as household
  join public.household_members as caller
    on caller.household_id = household.id
   and caller.auth_user_id = v_authenticated_user_id
   and caller.removed_at is null
  join public.event_occurrences as occurrence
    on occurrence.household_id = household.id
   and occurrence.id = p_occurrence_id
   and occurrence.status = 'scheduled'
  join public.event_series as series
    on series.household_id = occurrence.household_id
   and series.id = occurrence.series_id
   and series.deleted_at is null
  where household.id = p_household_id
    and household.deleted_at is null;

  if not found then
    raise exception using
      errcode = 'KFE03',
      message = 'calendar occurrence not found or forbidden';
  end if;
end;
$$;

revoke all on function public.get_calendar_occurrence_locator(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.get_calendar_occurrence_locator(uuid, uuid)
  to authenticated;
