-- KinFlow WP02-06 adult activation handoff.
-- Store MVP scope: active adults create one-time chores through mediated RPCs.

create type public.occurrence_status as enum (
  'scheduled',
  'completed',
  'skipped',
  'cancelled'
);

create table public.chore_series (
  id uuid primary key default extensions.gen_random_uuid(),
  household_id uuid not null
    references public.households(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 160),
  description text check (char_length(description) <= 4000),
  timezone text not null check (
    app_private.is_valid_iana_timezone(timezone)
  ),
  active_revision_id uuid not null,
  created_by_user_id uuid
    references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  deleted_at timestamptz,
  unique (household_id, id)
);

create table public.chore_series_revisions (
  id uuid primary key default extensions.gen_random_uuid(),
  household_id uuid not null,
  series_id uuid not null,
  revision_number integer not null check (revision_number > 0),
  effective_local_date date not null,
  due_local_time time without time zone,
  recurrence_rule jsonb not null check (
    jsonb_typeof(recurrence_rule) = 'object'
  ),
  default_assignee_member_id uuid not null,
  created_by_user_id uuid
    references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (household_id, id),
  unique (series_id, revision_number),
  constraint chore_revision_series_fk
    foreign key (household_id, series_id)
    references public.chore_series(household_id, id)
    on delete cascade,
  constraint chore_revision_assignee_fk
    foreign key (household_id, default_assignee_member_id)
    references public.household_members(household_id, id)
);

alter table public.chore_series
  add constraint chore_active_revision_fk
  foreign key (household_id, active_revision_id)
  references public.chore_series_revisions(household_id, id)
  deferrable initially deferred;

create table public.chore_occurrences (
  id uuid primary key default extensions.gen_random_uuid(),
  household_id uuid not null,
  series_id uuid not null,
  revision_id uuid not null,
  occurrence_key text not null check (
    char_length(occurrence_key) between 1 and 240
  ),
  due_local_date date not null,
  due_at timestamptz,
  timezone text not null check (
    app_private.is_valid_iana_timezone(timezone)
  ),
  status public.occurrence_status not null default 'scheduled',
  assignee_member_id uuid not null,
  completed_by_member_id uuid,
  completed_by_user_id uuid
    references auth.users(id) on delete set null,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  unique (household_id, id),
  unique (household_id, occurrence_key),
  constraint chore_occurrence_series_fk
    foreign key (household_id, series_id)
    references public.chore_series(household_id, id)
    on delete cascade,
  constraint chore_occurrence_revision_fk
    foreign key (household_id, revision_id)
    references public.chore_series_revisions(household_id, id),
  constraint chore_occurrence_assignee_fk
    foreign key (household_id, assignee_member_id)
    references public.household_members(household_id, id),
  constraint chore_occurrence_completer_fk
    foreign key (household_id, completed_by_member_id)
    references public.household_members(household_id, id),
  constraint chore_completion_fields_ck check (
    (
      status = 'completed'
      and completed_at is not null
      and completed_by_member_id is not null
      and completed_by_user_id is not null
    )
    or (
      status <> 'completed'
      and completed_at is null
      and completed_by_member_id is null
      and completed_by_user_id is null
    )
  )
);

create index chore_occurrences_today_idx
  on public.chore_occurrences(
    household_id,
    due_local_date,
    status,
    due_at
  );

create index chore_occurrences_assignee_idx
  on public.chore_occurrences(
    household_id,
    assignee_member_id,
    due_local_date
  );

create trigger chore_series_set_updated_at_and_version
before update on public.chore_series
for each row execute function app_private.set_updated_at_and_version();

create trigger chore_occurrences_set_updated_at_and_version
before update on public.chore_occurrences
for each row execute function app_private.set_updated_at_and_version();

create table app_private.chore_command_requests (
  authenticated_user_id uuid not null
    references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  household_id uuid not null,
  series_id uuid not null,
  occurrence_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (authenticated_user_id, idempotency_key),
  constraint chore_request_series_fk
    foreign key (household_id, series_id)
    references public.chore_series(household_id, id)
    on delete cascade,
  constraint chore_request_occurrence_fk
    foreign key (household_id, occurrence_id)
    references public.chore_occurrences(household_id, id)
    on delete cascade
);

create table app_private.chore_domain_events (
  id uuid primary key default extensions.gen_random_uuid(),
  household_id uuid not null,
  event_name text not null check (
    event_name in (
      'chore.series_created',
      'activation.adult_first_chore_created'
    )
  ),
  aggregate_id uuid not null,
  actor_member_id uuid not null,
  correlation_id uuid not null,
  aggregate_version bigint not null check (aggregate_version > 0),
  occurred_at timestamptz not null default now(),
  unique (household_id, event_name, correlation_id),
  constraint chore_event_series_fk
    foreign key (household_id, aggregate_id)
    references public.chore_series(household_id, id)
    on delete cascade,
  constraint chore_event_actor_fk
    foreign key (household_id, actor_member_id)
    references public.household_members(household_id, id)
);

create unique index chore_adult_first_action_uq
  on app_private.chore_domain_events(
    household_id,
    actor_member_id,
    event_name
  )
  where event_name = 'activation.adult_first_chore_created';

revoke all on table app_private.chore_command_requests
  from public, anon, authenticated;
revoke all on table app_private.chore_domain_events
  from public, anon, authenticated;

create or replace function app_private.reject_chore_domain_event_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'chore domain events are immutable';
end;
$$;

revoke all on function app_private.reject_chore_domain_event_mutation()
  from public;

create trigger chore_domain_events_immutable
before update or delete on app_private.chore_domain_events
for each row
execute function app_private.reject_chore_domain_event_mutation();

alter table public.chore_series enable row level security;
alter table public.chore_series force row level security;
alter table public.chore_series_revisions enable row level security;
alter table public.chore_series_revisions force row level security;
alter table public.chore_occurrences enable row level security;
alter table public.chore_occurrences force row level security;

create policy chore_series_select_member
on public.chore_series
for select
to authenticated
using (
  deleted_at is null
  and app_private.is_active_household_member(household_id)
);

create policy chore_revisions_select_member
on public.chore_series_revisions
for select
to authenticated
using (app_private.is_active_household_member(household_id));

create policy chore_occurrences_select_member
on public.chore_occurrences
for select
to authenticated
using (app_private.is_active_household_member(household_id));

revoke all on table public.chore_series from anon, authenticated;
revoke all on table public.chore_series_revisions from anon, authenticated;
revoke all on table public.chore_occurrences from anon, authenticated;

grant select on table public.chore_series to authenticated;
grant select on table public.chore_series_revisions to authenticated;
grant select on table public.chore_occurrences to authenticated;

create or replace function public.create_one_time_chore(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_title text,
  p_description text,
  p_assignee_member_id uuid,
  p_due_local_date date,
  p_due_local_time time without time zone
)
returns table (
  household_id uuid,
  series_id uuid,
  occurrence_id uuid,
  title text,
  description text,
  assignee_member_id uuid,
  assignee_display_name text,
  due_local_date date,
  due_local_time time without time zone,
  due_at timestamptz,
  status text,
  version bigint,
  created boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_title text := btrim(p_title);
  v_description text := nullif(btrim(p_description), '');
  v_timezone text;
  v_actor_member_id uuid;
  v_assignee_display_name text;
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_series_id uuid;
  v_revision_id uuid;
  v_occurrence_id uuid;
  v_due_at timestamptz;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFC01',
      message = 'authentication required';
  end if;

  if p_idempotency_key is null
    or p_household_id is null
    or p_assignee_member_id is null
    or p_due_local_date is null
    or (
      p_due_local_time is not null
      and extract(second from p_due_local_time) <> 0
    )
    or v_title is null
    or char_length(v_title) not between 1 and 160
    or v_title ~ '[[:cntrl:]]'
    or (
      v_description is not null
      and char_length(v_description) > 4000
    ) then
    raise exception using
      errcode = 'KFC02',
      message = 'invalid chore input';
  end if;

  select household.timezone, caller.id
  into v_timezone, v_actor_member_id
  from public.households as household
  join public.household_members as caller
    on caller.household_id = household.id
   and caller.auth_user_id = v_authenticated_user_id
   and caller.removed_at is null
  where household.id = p_household_id
    and household.deleted_at is null
  for update of caller;

  if not found then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  select assignee.display_name
  into v_assignee_display_name
  from public.household_members as assignee
  where assignee.household_id = p_household_id
    and assignee.id = p_assignee_member_id
    and assignee.removed_at is null
  for update of assignee;

  if not found then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  v_request_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'household_id', p_household_id,
        'title', v_title,
        'description', v_description,
        'assignee_member_id', p_assignee_member_id,
        'due_local_date', p_due_local_date,
        'due_local_time', p_due_local_time
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_authenticated_user_id::text
        || ':chore-create:'
        || p_idempotency_key::text,
      0
    )
  );

  select
    request.request_hash,
    request.series_id,
    request.occurrence_id
  into
    v_existing_request_hash,
    v_series_id,
    v_occurrence_id
  from app_private.chore_command_requests as request
  where request.authenticated_user_id = v_authenticated_user_id
    and request.idempotency_key = p_idempotency_key;

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFC04',
        message = 'idempotency key reused with different chore input';
    end if;

    return query
    select
      occurrence.household_id,
      series.id,
      occurrence.id,
      series.title,
      series.description,
      occurrence.assignee_member_id,
      assignee.display_name,
      occurrence.due_local_date,
      revision.due_local_time,
      occurrence.due_at,
      occurrence.status::text,
      occurrence.version,
      false
    from public.chore_occurrences as occurrence
    join public.chore_series as series
      on series.household_id = occurrence.household_id
     and series.id = occurrence.series_id
    join public.chore_series_revisions as revision
      on revision.household_id = occurrence.household_id
     and revision.id = occurrence.revision_id
    join public.household_members as assignee
      on assignee.household_id = occurrence.household_id
     and assignee.id = occurrence.assignee_member_id
    where occurrence.household_id = p_household_id
      and occurrence.id = v_occurrence_id;
    return;
  end if;

  v_series_id := extensions.gen_random_uuid();
  v_revision_id := extensions.gen_random_uuid();
  v_occurrence_id := extensions.gen_random_uuid();
  v_due_at := case
    when p_due_local_time is null then null
    else (p_due_local_date + p_due_local_time) at time zone v_timezone
  end;

  insert into public.chore_series (
    id,
    household_id,
    title,
    description,
    timezone,
    active_revision_id,
    created_by_user_id
  )
  values (
    v_series_id,
    p_household_id,
    v_title,
    v_description,
    v_timezone,
    v_revision_id,
    v_authenticated_user_id
  );

  insert into public.chore_series_revisions (
    id,
    household_id,
    series_id,
    revision_number,
    effective_local_date,
    due_local_time,
    recurrence_rule,
    default_assignee_member_id,
    created_by_user_id
  )
  values (
    v_revision_id,
    p_household_id,
    v_series_id,
    1,
    p_due_local_date,
    p_due_local_time,
    '{"type":"once"}'::jsonb,
    p_assignee_member_id,
    v_authenticated_user_id
  );

  insert into public.chore_occurrences (
    id,
    household_id,
    series_id,
    revision_id,
    occurrence_key,
    due_local_date,
    due_at,
    timezone,
    assignee_member_id
  )
  values (
    v_occurrence_id,
    p_household_id,
    v_series_id,
    v_revision_id,
    v_series_id::text || ':once',
    p_due_local_date,
    v_due_at,
    v_timezone,
    p_assignee_member_id
  );

  insert into app_private.chore_command_requests (
    authenticated_user_id,
    idempotency_key,
    request_hash,
    household_id,
    series_id,
    occurrence_id
  )
  values (
    v_authenticated_user_id,
    p_idempotency_key,
    v_request_hash,
    p_household_id,
    v_series_id,
    v_occurrence_id
  );

  insert into app_private.chore_domain_events (
    household_id,
    event_name,
    aggregate_id,
    actor_member_id,
    correlation_id,
    aggregate_version
  )
  values (
    p_household_id,
    'chore.series_created',
    v_series_id,
    v_actor_member_id,
    p_idempotency_key,
    1
  );

  insert into app_private.chore_domain_events (
    household_id,
    event_name,
    aggregate_id,
    actor_member_id,
    correlation_id,
    aggregate_version
  )
  select
    p_household_id,
    'activation.adult_first_chore_created',
    v_series_id,
    v_actor_member_id,
    p_idempotency_key,
    1
  where not exists (
    select 1
    from app_private.chore_domain_events as existing
    where existing.household_id = p_household_id
      and existing.actor_member_id = v_actor_member_id
      and existing.event_name = 'activation.adult_first_chore_created'
  );

  return query select
    p_household_id,
    v_series_id,
    v_occurrence_id,
    v_title,
    v_description,
    p_assignee_member_id,
    v_assignee_display_name,
    p_due_local_date,
    p_due_local_time,
    v_due_at,
    'scheduled'::text,
    1::bigint,
    true;
end;
$$;

create or replace function public.get_today_chores(
  p_household_id uuid
)
returns table (
  household_id uuid,
  household_timezone text,
  household_local_date date,
  occurrence_id uuid,
  series_id uuid,
  title text,
  description text,
  assignee_member_id uuid,
  assignee_display_name text,
  due_local_time time without time zone,
  due_at timestamptz,
  status text,
  version bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_timezone text;
  v_local_date date;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFC01',
      message = 'authentication required';
  end if;

  if p_household_id is null then
    raise exception using
      errcode = 'KFC02',
      message = 'invalid chore input';
  end if;

  select household.timezone
  into v_timezone
  from public.households as household
  join public.household_members as caller
    on caller.household_id = household.id
   and caller.auth_user_id = v_authenticated_user_id
   and caller.removed_at is null
  where household.id = p_household_id
    and household.deleted_at is null;

  if not found then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  v_local_date := (statement_timestamp() at time zone v_timezone)::date;

  return query
  select
    household.id,
    household.timezone,
    v_local_date,
    item.occurrence_id,
    item.series_id,
    item.title,
    item.description,
    item.assignee_member_id,
    item.assignee_display_name,
    item.due_local_time,
    item.due_at,
    item.status,
    item.version
  from public.households as household
  left join lateral (
    select
      occurrence.id as occurrence_id,
      series.id as series_id,
      series.title,
      series.description,
      occurrence.assignee_member_id,
      assignee.display_name as assignee_display_name,
      revision.due_local_time,
      occurrence.due_at,
      occurrence.status::text as status,
      occurrence.version
    from public.chore_occurrences as occurrence
    join public.chore_series as series
      on series.household_id = occurrence.household_id
     and series.id = occurrence.series_id
     and series.deleted_at is null
    join public.chore_series_revisions as revision
      on revision.household_id = occurrence.household_id
     and revision.id = occurrence.revision_id
    join public.household_members as assignee
      on assignee.household_id = occurrence.household_id
     and assignee.id = occurrence.assignee_member_id
    where occurrence.household_id = household.id
      and occurrence.due_local_date = v_local_date
      and occurrence.status in ('scheduled', 'completed')
    order by
      occurrence.due_at nulls last,
      lower(series.title),
      occurrence.id
  ) as item on true
  where household.id = p_household_id
  order by
    item.due_at nulls last,
    lower(item.title) nulls last,
    item.occurrence_id;
end;
$$;

revoke all on function public.create_one_time_chore(
  uuid,
  uuid,
  text,
  text,
  uuid,
  date,
  time without time zone
) from public, anon, authenticated;

revoke all on function public.get_today_chores(uuid)
  from public, anon, authenticated;

grant execute on function public.create_one_time_chore(
  uuid,
  uuid,
  text,
  text,
  uuid,
  date,
  time without time zone
) to authenticated;

grant execute on function public.get_today_chores(uuid)
  to authenticated;
