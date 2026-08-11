-- KinFlow WP03-05G repeating series future edit and termination.
-- Store MVP scope: whole-series changes from the server-derived household
-- local date. Arbitrary "this and future" boundaries remain out of scope.

-- Content belongs to an immutable revision so editing a series cannot rewrite
-- the title/notes shown by past or completed occurrences.
alter table public.chore_series_revisions
  add column title text,
  add column description text;

update public.chore_series_revisions as revision
set
  title = series.title,
  description = series.description
from public.chore_series as series
where series.household_id = revision.household_id
  and series.id = revision.series_id;

alter table public.chore_series_revisions
  alter column title set not null,
  add constraint chore_revision_title_ck check (
    char_length(title) between 1 and 160
    and title !~ '[[:cntrl:]]'
  ),
  add constraint chore_revision_description_ck check (
    description is null or char_length(description) <= 4000
  );

create or replace function app_private.populate_chore_revision_content()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Legacy create RPCs omit the new columns. A non-null title means a newer
  -- command supplied an explicit snapshot, including an intentional null note.
  if new.title is null then
    select series.title, series.description
    into new.title, new.description
    from public.chore_series as series
    where series.household_id = new.household_id
      and series.id = new.series_id;
  end if;
  return new;
end;
$$;

revoke all on function app_private.populate_chore_revision_content()
  from public;

create trigger chore_revision_populate_content
before insert on public.chore_series_revisions
for each row
execute function app_private.populate_chore_revision_content();

create or replace function app_private.reject_chore_revision_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'chore series revisions are immutable';
end;
$$;

revoke all on function app_private.reject_chore_revision_update()
  from public;

create trigger chore_revisions_immutable
before update on public.chore_series_revisions
for each row
execute function app_private.reject_chore_revision_update();

-- Keep the original recurrence slot separate from a one-occurrence reschedule.
alter table public.chore_occurrences
  add column recurrence_local_date date;

update public.chore_occurrences as occurrence
set recurrence_local_date = case
  when revision.recurrence_rule = '{"type":"once"}'::jsonb
    then occurrence.due_local_date
  else substring(
    occurrence.occurrence_key
    from '([0-9]{4}-[0-9]{2}-[0-9]{2})$'
  )::date
end
from public.chore_series_revisions as revision
where revision.household_id = occurrence.household_id
  and revision.id = occurrence.revision_id;

alter table public.chore_occurrences
  alter column recurrence_local_date set not null,
  add constraint chore_occurrence_recurrence_key_ck check (
    occurrence_key = series_id::text || ':once'
    or occurrence_key =
      series_id::text || ':' || recurrence_local_date::text
  ) not valid;

alter table public.chore_occurrences
  validate constraint chore_occurrence_recurrence_key_ck;

create or replace function app_private.populate_chore_recurrence_local_date()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.recurrence_local_date is null then
    new.recurrence_local_date := new.due_local_date;
  end if;
  return new;
end;
$$;

revoke all on function app_private.populate_chore_recurrence_local_date()
  from public;

create trigger chore_occurrence_populate_recurrence_local_date
before insert on public.chore_occurrences
for each row
execute function app_private.populate_chore_recurrence_local_date();

create or replace function app_private.reject_chore_occurrence_identity_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.household_id is distinct from old.household_id
    or new.series_id is distinct from old.series_id
    or new.occurrence_key is distinct from old.occurrence_key
    or new.recurrence_local_date is distinct from old.recurrence_local_date then
    raise exception using
      errcode = '55000',
      message = 'chore occurrence recurrence identity is immutable';
  end if;
  return new;
end;
$$;

revoke all on function app_private.reject_chore_occurrence_identity_change()
  from public;

create trigger chore_occurrence_recurrence_identity_immutable
before update on public.chore_occurrences
for each row
execute function app_private.reject_chore_occurrence_identity_change();

-- Canonical candidate generation is shared by the worker and the series-edit
-- command so both use exactly the same count/interval/month-end semantics.
create or replace function app_private.chore_revision_candidate_dates(
  p_household_id uuid,
  p_series_id uuid,
  p_revision_id uuid,
  p_window_start date,
  p_window_end date
)
returns table (
  recurrence_local_date date,
  due_at timestamptz
)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_timezone text;
  v_start_date date;
  v_due_local_time time without time zone;
  v_assignee_member_id uuid;
  v_rule jsonb;
  v_frequency text;
  v_interval integer;
  v_weekday_numbers integer[];
  v_weekday_count integer;
  v_start_iso_dow integer;
  v_first_week_count integer;
  v_month_day integer;
  v_end_type text;
  v_end_count integer;
  v_end_until date;
  v_effective_window_start date;
  v_effective_window_end date;
begin
  if p_household_id is null
    or p_series_id is null
    or p_revision_id is null
    or p_window_start is null
    or p_window_end is null
    or p_window_end < p_window_start
    or p_window_end - p_window_start > 396 then
    raise exception using
      errcode = 'KFW01',
      message = 'invalid chore materialization window';
  end if;

  select
    series.timezone,
    revision.effective_local_date,
    revision.due_local_time,
    revision.default_assignee_member_id,
    revision.recurrence_rule
  into
    v_timezone,
    v_start_date,
    v_due_local_time,
    v_assignee_member_id,
    v_rule
  from public.chore_series as series
  join public.chore_series_revisions as revision
    on revision.household_id = series.household_id
   and revision.series_id = series.id
   and revision.id = p_revision_id
  where series.household_id = p_household_id
    and series.id = p_series_id
    and series.active_revision_id = p_revision_id
    and series.deleted_at is null;

  if not found
    or not app_private.is_valid_chore_recurrence_rule(v_rule)
    or v_rule = '{"type":"once"}'::jsonb then
    raise exception using
      errcode = 'KFW02',
      message = 'invalid chore recurrence';
  end if;

  perform 1
  from public.household_members as assignee
  where assignee.household_id = p_household_id
    and assignee.id = v_assignee_member_id
    and assignee.removed_at is null;

  if not found then
    raise exception using
      errcode = 'KFW03',
      message = 'chore assignee unavailable';
  end if;

  v_frequency := v_rule->>'frequency';
  v_interval := (v_rule->>'interval')::integer;
  v_month_day := nullif(v_rule->>'monthDay', '')::integer;
  v_end_type := v_rule->'end'->>'type';
  v_end_count := nullif(v_rule->'end'->>'count', '')::integer;
  v_end_until := nullif(v_rule->'end'->>'localDate', '')::date;
  v_start_iso_dow := extract(isodow from v_start_date)::integer;

  if v_frequency = 'weekly' then
    select
      array_agg(
        case weekday.value
          when 'MO' then 1
          when 'TU' then 2
          when 'WE' then 3
          when 'TH' then 4
          when 'FR' then 5
          when 'SA' then 6
          when 'SU' then 7
        end
        order by weekday.ordinality
      ),
      count(*)::integer
    into v_weekday_numbers, v_weekday_count
    from jsonb_array_elements_text(v_rule->'weekdays')
      with ordinality as weekday(value, ordinality);

    select count(*)::integer
    into v_first_week_count
    from unnest(v_weekday_numbers) as weekday_number(value)
    where weekday_number.value >= v_start_iso_dow;
  end if;

  v_effective_window_start := greatest(p_window_start, v_start_date);
  v_effective_window_end := p_window_end;
  if v_end_type = 'until' then
    v_effective_window_end := least(v_effective_window_end, v_end_until);
  end if;

  if v_effective_window_end < v_effective_window_start then
    return;
  end if;

  return query
  with candidate_dates as (
    select generated.due_date::date as due_date
    from generate_series(
      v_effective_window_start::timestamp,
      v_effective_window_end::timestamp,
      interval '1 day'
    ) as generated(due_date)
  ),
  date_offsets as (
    select
      candidate.due_date,
      candidate.due_date - v_start_date as day_offset,
      (
        (
          extract(year from candidate.due_date)::integer
          - extract(year from v_start_date)::integer
        ) * 12
        + extract(month from candidate.due_date)::integer
        - extract(month from v_start_date)::integer
      ) as month_offset,
      (
        candidate.due_date
        - (v_start_date - (v_start_iso_dow - 1))
      ) / 7 as week_offset,
      extract(isodow from candidate.due_date)::integer as iso_dow
    from candidate_dates as candidate
  ),
  matched_dates as (
    select
      candidate.due_date,
      case v_frequency
        when 'daily' then
          (candidate.day_offset / v_interval + 1)::bigint
        when 'monthly' then
          (candidate.month_offset / v_interval + 1)::bigint
        when 'weekly' then
          case
            when candidate.week_offset = 0 then (
              select count(*)::bigint
              from unnest(v_weekday_numbers) as weekday_number(value)
              where weekday_number.value between v_start_iso_dow
                and candidate.iso_dow
            )
            else
              v_first_week_count::bigint
              + (
                candidate.week_offset / v_interval - 1
              )::bigint * v_weekday_count::bigint
              + (
                select count(*)::bigint
                from unnest(v_weekday_numbers) as weekday_number(value)
                where weekday_number.value <= candidate.iso_dow
              )
          end
      end as occurrence_number
    from date_offsets as candidate
    where case v_frequency
      when 'daily' then
        candidate.day_offset % v_interval = 0
      when 'weekly' then
        candidate.week_offset % v_interval = 0
        and candidate.iso_dow = any(v_weekday_numbers)
      when 'monthly' then
        extract(day from candidate.due_date)::integer = v_month_day
        and candidate.month_offset % v_interval = 0
      else false
    end
  )
  select
    matched.due_date,
    case
      when v_due_local_time is null then null
      else (matched.due_date + v_due_local_time) at time zone v_timezone
    end
  from matched_dates as matched
  where v_end_type <> 'count'
    or matched.occurrence_number <= v_end_count
  order by matched.due_date;
end;
$$;

revoke all on function app_private.chore_revision_candidate_dates(
  uuid,
  uuid,
  uuid,
  date,
  date
) from public, anon, authenticated, service_role;

create or replace function app_private.materialize_chore_revision_window(
  p_household_id uuid,
  p_series_id uuid,
  p_revision_id uuid,
  p_window_start date,
  p_window_end date
)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_timezone text;
  v_assignee_member_id uuid;
  v_inserted_count integer;
begin
  select series.timezone, revision.default_assignee_member_id
  into v_timezone, v_assignee_member_id
  from public.chore_series as series
  join public.chore_series_revisions as revision
    on revision.household_id = series.household_id
   and revision.series_id = series.id
   and revision.id = p_revision_id
  where series.household_id = p_household_id
    and series.id = p_series_id
    and series.active_revision_id = p_revision_id
    and series.deleted_at is null;

  insert into public.chore_occurrences (
    id,
    household_id,
    series_id,
    revision_id,
    occurrence_key,
    recurrence_local_date,
    due_local_date,
    due_at,
    timezone,
    assignee_member_id
  )
  select
    extensions.gen_random_uuid(),
    p_household_id,
    p_series_id,
    p_revision_id,
    p_series_id::text || ':' || candidate.recurrence_local_date::text,
    candidate.recurrence_local_date,
    candidate.recurrence_local_date,
    candidate.due_at,
    v_timezone,
    v_assignee_member_id
  from app_private.chore_revision_candidate_dates(
    p_household_id,
    p_series_id,
    p_revision_id,
    p_window_start,
    p_window_end
  ) as candidate
  on conflict (household_id, occurrence_key) do nothing;

  get diagnostics v_inserted_count = row_count;
  return v_inserted_count;
end;
$$;

revoke all on function app_private.materialize_chore_revision_window(
  uuid,
  uuid,
  uuid,
  date,
  date
) from public, anon, authenticated, service_role;

create table public.chore_series_change_events (
  id uuid primary key default extensions.gen_random_uuid(),
  household_id uuid not null,
  series_id uuid not null,
  operation text not null check (operation in ('updated', 'cancelled')),
  previous_revision_id uuid not null,
  new_revision_id uuid,
  effective_local_date date not null,
  actor_user_id uuid
    references auth.users(id) on delete set null,
  actor_member_id uuid not null,
  rebuilt_count integer not null check (rebuilt_count >= 0),
  cancelled_count integer not null check (cancelled_count >= 0),
  preserved_completed_count integer not null check (
    preserved_completed_count >= 0
  ),
  series_version bigint not null check (series_version > 0),
  correlation_id uuid not null,
  occurred_at timestamptz not null default now(),
  unique (household_id, id),
  unique (actor_user_id, correlation_id),
  constraint chore_series_change_event_revision_shape_ck check (
    (operation = 'updated' and new_revision_id is not null)
    or (operation = 'cancelled' and new_revision_id is null)
  ),
  constraint chore_series_change_event_series_fk
    foreign key (household_id, series_id)
    references public.chore_series(household_id, id)
    on delete cascade,
  constraint chore_series_change_event_previous_revision_fk
    foreign key (household_id, previous_revision_id)
    references public.chore_series_revisions(household_id, id),
  constraint chore_series_change_event_new_revision_fk
    foreign key (household_id, new_revision_id)
    references public.chore_series_revisions(household_id, id),
  constraint chore_series_change_event_actor_fk
    foreign key (household_id, actor_member_id)
    references public.household_members(household_id, id)
);

create index chore_series_change_events_series_time_idx
  on public.chore_series_change_events(
    household_id,
    series_id,
    occurred_at desc
  );

create or replace function app_private.reject_chore_series_change_event_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'chore series change events are immutable';
end;
$$;

revoke all on function app_private.reject_chore_series_change_event_mutation()
  from public;

create trigger chore_series_change_events_immutable
before update or delete on public.chore_series_change_events
for each row
execute function app_private.reject_chore_series_change_event_mutation();

alter table public.chore_series_change_events enable row level security;
alter table public.chore_series_change_events force row level security;

create policy chore_series_change_events_select_member
on public.chore_series_change_events
for select
to authenticated
using (app_private.is_active_household_member(household_id));

revoke all on table public.chore_series_change_events
  from anon, authenticated;
grant select on table public.chore_series_change_events
  to authenticated;

create table app_private.chore_series_change_command_requests (
  authenticated_user_id uuid not null
    references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  operation text not null check (operation in ('updated', 'cancelled')),
  household_id uuid not null,
  series_id uuid not null,
  result_revision_id uuid,
  result_effective_local_date date not null,
  result_version bigint not null check (result_version > 0),
  result_rebuilt_count integer not null check (result_rebuilt_count >= 0),
  result_cancelled_count integer not null check (
    result_cancelled_count >= 0
  ),
  result_preserved_completed_count integer not null check (
    result_preserved_completed_count >= 0
  ),
  result_event_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (authenticated_user_id, idempotency_key),
  constraint chore_series_change_request_revision_shape_ck check (
    (operation = 'updated' and result_revision_id is not null)
    or (operation = 'cancelled' and result_revision_id is null)
  ),
  constraint chore_series_change_request_series_fk
    foreign key (household_id, series_id)
    references public.chore_series(household_id, id)
    on delete cascade,
  constraint chore_series_change_request_revision_fk
    foreign key (household_id, result_revision_id)
    references public.chore_series_revisions(household_id, id),
  constraint chore_series_change_request_event_fk
    foreign key (household_id, result_event_id)
    references public.chore_series_change_events(household_id, id)
    on delete cascade
);

revoke all on table app_private.chore_series_change_command_requests
  from public, anon, authenticated, service_role;

create or replace function public.update_repeating_chore_series(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_expected_version bigint,
  p_title text,
  p_description text,
  p_assignee_member_id uuid,
  p_due_local_time time without time zone,
  p_recurrence_rule jsonb
)
returns table (
  household_id uuid,
  series_id uuid,
  revision_id uuid,
  revision_number integer,
  effective_local_date date,
  version bigint,
  rebuilt_count integer,
  cancelled_count integer,
  preserved_completed_count integer,
  changed boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_actor_member_id uuid;
  v_actor_role public.household_role;
  v_title text := btrim(p_title);
  v_description text := nullif(btrim(p_description), '');
  v_timezone text;
  v_current_title text;
  v_current_description text;
  v_current_version bigint;
  v_previous_revision_id uuid;
  v_previous_assignee_member_id uuid;
  v_previous_due_local_time time without time zone;
  v_previous_recurrence_rule jsonb;
  v_revision_id uuid;
  v_revision_number integer;
  v_effective_local_date date;
  v_horizon_end date;
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_result_revision_id uuid;
  v_result_revision_number integer;
  v_result_effective_local_date date;
  v_result_version bigint;
  v_result_rebuilt_count integer;
  v_result_cancelled_count integer;
  v_result_preserved_completed_count integer;
  v_result_event_id uuid;
  v_reused_count integer;
  v_inserted_count integer;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFC01',
      message = 'authentication required';
  end if;

  if p_idempotency_key is null
    or p_household_id is null
    or p_series_id is null
    or p_expected_version is null
    or p_expected_version < 1
    or p_assignee_member_id is null
    or v_title is null
    or char_length(v_title) not between 1 and 160
    or v_title ~ '[[:cntrl:]]'
    or (v_description is not null and char_length(v_description) > 4000)
    or (
      p_due_local_time is not null
      and extract(second from p_due_local_time) <> 0
    )
    or not app_private.is_valid_chore_recurrence_rule(p_recurrence_rule)
    or p_recurrence_rule = '{"type":"once"}'::jsonb then
    raise exception using
      errcode = 'KFC07',
      message = 'invalid chore recurrence rule';
  end if;

  select actor.id, actor.role
  into v_actor_member_id, v_actor_role
  from public.household_members as actor
  join public.households as household
    on household.id = actor.household_id
   and household.deleted_at is null
  where actor.household_id = p_household_id
    and actor.auth_user_id = v_authenticated_user_id
    and actor.removed_at is null
  for update of actor;

  if not found or v_actor_role not in ('owner', 'admin') then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  v_request_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'operation', 'update_repeating_chore_series',
        'household_id', p_household_id,
        'series_id', p_series_id,
        'expected_version', p_expected_version,
        'title', v_title,
        'description', v_description,
        'assignee_member_id', p_assignee_member_id,
        'due_local_time', p_due_local_time,
        'recurrence_rule', p_recurrence_rule
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_authenticated_user_id::text
        || ':chore-series-change:'
        || p_idempotency_key::text,
      0
    )
  );

  select
    request.request_hash,
    request.result_revision_id,
    revision.revision_number,
    request.result_effective_local_date,
    request.result_version,
    request.result_rebuilt_count,
    request.result_cancelled_count,
    request.result_preserved_completed_count
  into
    v_existing_request_hash,
    v_result_revision_id,
    v_result_revision_number,
    v_result_effective_local_date,
    v_result_version,
    v_result_rebuilt_count,
    v_result_cancelled_count,
    v_result_preserved_completed_count
  from app_private.chore_series_change_command_requests as request
  join public.chore_series_revisions as revision
    on revision.household_id = request.household_id
   and revision.id = request.result_revision_id
  where request.authenticated_user_id = v_authenticated_user_id
    and request.idempotency_key = p_idempotency_key
    and request.operation = 'updated';

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFC04',
        message = 'idempotency key reused with different chore input';
    end if;

    return query select
      p_household_id,
      p_series_id,
      v_result_revision_id,
      v_result_revision_number,
      v_result_effective_local_date,
      v_result_version,
      v_result_rebuilt_count,
      v_result_cancelled_count,
      v_result_preserved_completed_count,
      false;
    return;
  end if;

  if exists (
    select 1
    from app_private.chore_series_change_command_requests as request
    where request.authenticated_user_id = v_authenticated_user_id
      and request.idempotency_key = p_idempotency_key
  ) then
    raise exception using
      errcode = 'KFC04',
      message = 'idempotency key reused with different chore input';
  end if;

  select
    series.timezone,
    series.title,
    series.description,
    series.version,
    revision.id,
    revision.default_assignee_member_id,
    revision.due_local_time,
    revision.recurrence_rule
  into
    v_timezone,
    v_current_title,
    v_current_description,
    v_current_version,
    v_previous_revision_id,
    v_previous_assignee_member_id,
    v_previous_due_local_time,
    v_previous_recurrence_rule
  from public.chore_series as series
  join public.chore_series_revisions as revision
    on revision.household_id = series.household_id
   and revision.series_id = series.id
   and revision.id = series.active_revision_id
  where series.household_id = p_household_id
    and series.id = p_series_id
    and series.deleted_at is null
  for update of series;

  if not found
    or v_previous_recurrence_rule = '{"type":"once"}'::jsonb then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  if v_current_version <> p_expected_version then
    raise exception using
      errcode = 'KFC05',
      message = 'chore series version conflict';
  end if;

  perform 1
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

  v_effective_local_date :=
    (statement_timestamp() at time zone v_timezone)::date;

  if p_recurrence_rule->'end'->>'type' = 'until'
    and (p_recurrence_rule->'end'->>'localDate')::date
      < v_effective_local_date then
    raise exception using
      errcode = 'KFC07',
      message = 'invalid chore recurrence rule';
  end if;

  if v_current_title is not distinct from v_title
    and v_current_description is not distinct from v_description
    and v_previous_assignee_member_id = p_assignee_member_id
    and v_previous_due_local_time is not distinct from p_due_local_time
    and v_previous_recurrence_rule = p_recurrence_rule then
    raise exception using
      errcode = 'KFC06',
      message = 'chore series transition not allowed';
  end if;

  v_revision_id := extensions.gen_random_uuid();
  select coalesce(max(revision.revision_number), 0) + 1
  into v_revision_number
  from public.chore_series_revisions as revision
  where revision.series_id = p_series_id;

  insert into public.chore_series_revisions (
    id,
    household_id,
    series_id,
    revision_number,
    effective_local_date,
    due_local_time,
    recurrence_rule,
    default_assignee_member_id,
    created_by_user_id,
    title,
    description
  )
  values (
    v_revision_id,
    p_household_id,
    p_series_id,
    v_revision_number,
    v_effective_local_date,
    p_due_local_time,
    p_recurrence_rule,
    p_assignee_member_id,
    v_authenticated_user_id,
    v_title,
    v_description
  );

  update public.chore_series as series
  set
    title = v_title,
    description = v_description,
    active_revision_id = v_revision_id
  where series.household_id = p_household_id
    and series.id = p_series_id
  returning series.version into v_result_version;

  v_horizon_end := v_effective_local_date + 365;
  if p_recurrence_rule->'end'->>'type' = 'until' then
    v_horizon_end := least(
      v_horizon_end,
      (p_recurrence_rule->'end'->>'localDate')::date
    );
  end if;

  with candidates as materialized (
    select candidate.recurrence_local_date, candidate.due_at
    from app_private.chore_revision_candidate_dates(
      p_household_id,
      p_series_id,
      v_revision_id,
      v_effective_local_date,
      v_horizon_end
    ) as candidate
  )
  update public.chore_occurrences as occurrence
  set
    revision_id = v_revision_id,
    due_local_date = occurrence.recurrence_local_date,
    due_at = candidate.due_at,
    timezone = v_timezone,
    status = 'scheduled',
    assignee_member_id = p_assignee_member_id,
    completed_by_member_id = null,
    completed_by_user_id = null,
    completed_at = null
  from candidates as candidate
  where occurrence.household_id = p_household_id
    and occurrence.series_id = p_series_id
    and occurrence.revision_id = v_previous_revision_id
    and occurrence.recurrence_local_date >= v_effective_local_date
    and occurrence.status <> 'completed'
    and occurrence.recurrence_local_date = candidate.recurrence_local_date;

  get diagnostics v_reused_count = row_count;

  update public.chore_occurrences as occurrence
  set status = 'cancelled'
  where occurrence.household_id = p_household_id
    and occurrence.series_id = p_series_id
    and occurrence.revision_id = v_previous_revision_id
    and occurrence.recurrence_local_date >= v_effective_local_date
    and occurrence.status not in ('completed', 'cancelled')
    and not exists (
      select 1
      from app_private.chore_revision_candidate_dates(
        p_household_id,
        p_series_id,
        v_revision_id,
        v_effective_local_date,
        v_horizon_end
      ) as candidate
      where candidate.recurrence_local_date =
        occurrence.recurrence_local_date
    );

  get diagnostics v_result_cancelled_count = row_count;

  v_inserted_count := app_private.materialize_chore_revision_window(
    p_household_id,
    p_series_id,
    v_revision_id,
    v_effective_local_date,
    v_horizon_end
  );
  v_result_rebuilt_count := v_reused_count + v_inserted_count;

  select count(*)::integer
  into v_result_preserved_completed_count
  from public.chore_occurrences as occurrence
  where occurrence.household_id = p_household_id
    and occurrence.series_id = p_series_id
    and occurrence.recurrence_local_date >= v_effective_local_date
    and occurrence.status = 'completed';

  delete from app_private.chore_materialization_states as state
  where state.household_id = p_household_id
    and state.series_id = p_series_id;

  insert into public.chore_series_change_events (
    household_id,
    series_id,
    operation,
    previous_revision_id,
    new_revision_id,
    effective_local_date,
    actor_user_id,
    actor_member_id,
    rebuilt_count,
    cancelled_count,
    preserved_completed_count,
    series_version,
    correlation_id
  )
  values (
    p_household_id,
    p_series_id,
    'updated',
    v_previous_revision_id,
    v_revision_id,
    v_effective_local_date,
    v_authenticated_user_id,
    v_actor_member_id,
    v_result_rebuilt_count,
    v_result_cancelled_count,
    v_result_preserved_completed_count,
    v_result_version,
    p_idempotency_key
  )
  returning id into v_result_event_id;

  insert into app_private.chore_series_change_command_requests (
    authenticated_user_id,
    idempotency_key,
    request_hash,
    operation,
    household_id,
    series_id,
    result_revision_id,
    result_effective_local_date,
    result_version,
    result_rebuilt_count,
    result_cancelled_count,
    result_preserved_completed_count,
    result_event_id
  )
  values (
    v_authenticated_user_id,
    p_idempotency_key,
    v_request_hash,
    'updated',
    p_household_id,
    p_series_id,
    v_revision_id,
    v_effective_local_date,
    v_result_version,
    v_result_rebuilt_count,
    v_result_cancelled_count,
    v_result_preserved_completed_count,
    v_result_event_id
  );

  return query select
    p_household_id,
    p_series_id,
    v_revision_id,
    v_revision_number,
    v_effective_local_date,
    v_result_version,
    v_result_rebuilt_count,
    v_result_cancelled_count,
    v_result_preserved_completed_count,
    true;
end;
$$;

revoke all on function public.update_repeating_chore_series(
  uuid,
  uuid,
  uuid,
  bigint,
  text,
  text,
  uuid,
  time without time zone,
  jsonb
) from public, anon, authenticated;

grant execute on function public.update_repeating_chore_series(
  uuid,
  uuid,
  uuid,
  bigint,
  text,
  text,
  uuid,
  time without time zone,
  jsonb
) to authenticated;

create or replace function public.cancel_repeating_chore_series(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_expected_version bigint
)
returns table (
  household_id uuid,
  series_id uuid,
  effective_local_date date,
  version bigint,
  cancelled_count integer,
  preserved_completed_count integer,
  changed boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_actor_member_id uuid;
  v_actor_role public.household_role;
  v_timezone text;
  v_current_version bigint;
  v_previous_revision_id uuid;
  v_previous_recurrence_rule jsonb;
  v_effective_local_date date;
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_result_effective_local_date date;
  v_result_version bigint;
  v_result_cancelled_count integer;
  v_result_preserved_completed_count integer;
  v_result_event_id uuid;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFC01',
      message = 'authentication required';
  end if;

  if p_idempotency_key is null
    or p_household_id is null
    or p_series_id is null
    or p_expected_version is null
    or p_expected_version < 1 then
    raise exception using
      errcode = 'KFC02',
      message = 'invalid chore input';
  end if;

  select actor.id, actor.role
  into v_actor_member_id, v_actor_role
  from public.household_members as actor
  join public.households as household
    on household.id = actor.household_id
   and household.deleted_at is null
  where actor.household_id = p_household_id
    and actor.auth_user_id = v_authenticated_user_id
    and actor.removed_at is null
  for update of actor;

  if not found or v_actor_role not in ('owner', 'admin') then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  v_request_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'operation', 'cancel_repeating_chore_series',
        'household_id', p_household_id,
        'series_id', p_series_id,
        'expected_version', p_expected_version
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_authenticated_user_id::text
        || ':chore-series-change:'
        || p_idempotency_key::text,
      0
    )
  );

  select
    request.request_hash,
    request.result_effective_local_date,
    request.result_version,
    request.result_cancelled_count,
    request.result_preserved_completed_count
  into
    v_existing_request_hash,
    v_result_effective_local_date,
    v_result_version,
    v_result_cancelled_count,
    v_result_preserved_completed_count
  from app_private.chore_series_change_command_requests as request
  where request.authenticated_user_id = v_authenticated_user_id
    and request.idempotency_key = p_idempotency_key
    and request.operation = 'cancelled';

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFC04',
        message = 'idempotency key reused with different chore input';
    end if;

    return query select
      p_household_id,
      p_series_id,
      v_result_effective_local_date,
      v_result_version,
      v_result_cancelled_count,
      v_result_preserved_completed_count,
      false;
    return;
  end if;

  if exists (
    select 1
    from app_private.chore_series_change_command_requests as request
    where request.authenticated_user_id = v_authenticated_user_id
      and request.idempotency_key = p_idempotency_key
  ) then
    raise exception using
      errcode = 'KFC04',
      message = 'idempotency key reused with different chore input';
  end if;

  select
    series.timezone,
    series.version,
    revision.id,
    revision.recurrence_rule
  into
    v_timezone,
    v_current_version,
    v_previous_revision_id,
    v_previous_recurrence_rule
  from public.chore_series as series
  join public.chore_series_revisions as revision
    on revision.household_id = series.household_id
   and revision.series_id = series.id
   and revision.id = series.active_revision_id
  where series.household_id = p_household_id
    and series.id = p_series_id
    and series.deleted_at is null
  for update of series;

  if not found
    or v_previous_recurrence_rule = '{"type":"once"}'::jsonb then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  if v_current_version <> p_expected_version then
    raise exception using
      errcode = 'KFC05',
      message = 'chore series version conflict';
  end if;

  v_effective_local_date :=
    (statement_timestamp() at time zone v_timezone)::date;

  select count(*)::integer
  into v_result_preserved_completed_count
  from public.chore_occurrences as occurrence
  where occurrence.household_id = p_household_id
    and occurrence.series_id = p_series_id
    and occurrence.recurrence_local_date >= v_effective_local_date
    and occurrence.status = 'completed';

  update public.chore_occurrences as occurrence
  set status = 'cancelled'
  where occurrence.household_id = p_household_id
    and occurrence.series_id = p_series_id
    and occurrence.revision_id = v_previous_revision_id
    and occurrence.recurrence_local_date >= v_effective_local_date
    and occurrence.status not in ('completed', 'cancelled');

  get diagnostics v_result_cancelled_count = row_count;

  update public.chore_series as series
  set deleted_at = statement_timestamp()
  where series.household_id = p_household_id
    and series.id = p_series_id
  returning series.version into v_result_version;

  delete from app_private.chore_materialization_states as state
  where state.household_id = p_household_id
    and state.series_id = p_series_id;

  insert into public.chore_series_change_events (
    household_id,
    series_id,
    operation,
    previous_revision_id,
    new_revision_id,
    effective_local_date,
    actor_user_id,
    actor_member_id,
    rebuilt_count,
    cancelled_count,
    preserved_completed_count,
    series_version,
    correlation_id
  )
  values (
    p_household_id,
    p_series_id,
    'cancelled',
    v_previous_revision_id,
    null,
    v_effective_local_date,
    v_authenticated_user_id,
    v_actor_member_id,
    0,
    v_result_cancelled_count,
    v_result_preserved_completed_count,
    v_result_version,
    p_idempotency_key
  )
  returning id into v_result_event_id;

  insert into app_private.chore_series_change_command_requests (
    authenticated_user_id,
    idempotency_key,
    request_hash,
    operation,
    household_id,
    series_id,
    result_revision_id,
    result_effective_local_date,
    result_version,
    result_rebuilt_count,
    result_cancelled_count,
    result_preserved_completed_count,
    result_event_id
  )
  values (
    v_authenticated_user_id,
    p_idempotency_key,
    v_request_hash,
    'cancelled',
    p_household_id,
    p_series_id,
    null,
    v_effective_local_date,
    v_result_version,
    0,
    v_result_cancelled_count,
    v_result_preserved_completed_count,
    v_result_event_id
  );

  return query select
    p_household_id,
    p_series_id,
    v_effective_local_date,
    v_result_version,
    v_result_cancelled_count,
    v_result_preserved_completed_count,
    true;
end;
$$;

revoke all on function public.cancel_repeating_chore_series(
  uuid,
  uuid,
  uuid,
  bigint
) from public, anon, authenticated;

grant execute on function public.cancel_repeating_chore_series(
  uuid,
  uuid,
  uuid,
  bigint
) to authenticated;

-- Today returns only the active management contract needed by the client.
-- Display content remains tied to each occurrence's immutable revision.
drop function public.get_today_chores_v2(uuid);

create function public.get_today_chores_v2(
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
  version bigint,
  recurrence_frequency text,
  series_version bigint,
  series_default_assignee_member_id uuid,
  series_due_local_time time without time zone,
  recurrence_rule jsonb,
  can_manage_series boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_timezone text;
  v_actor_role public.household_role;
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

  select household.timezone, caller.role
  into v_timezone, v_actor_role
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
    item.version,
    item.recurrence_frequency,
    item.series_version,
    item.series_default_assignee_member_id,
    item.series_due_local_time,
    item.recurrence_rule,
    item.can_manage_series
  from public.households as household
  left join lateral (
    select
      occurrence.id as occurrence_id,
      series.id as series_id,
      display_revision.title,
      display_revision.description,
      occurrence.assignee_member_id,
      assignee.display_name as assignee_display_name,
      case
        when occurrence.due_at is null then null
        else (occurrence.due_at at time zone occurrence.timezone)::time
      end as due_local_time,
      occurrence.due_at,
      occurrence.status::text as status,
      occurrence.version,
      case
        when display_revision.recurrence_rule->>'frequency' in (
          'daily', 'weekly', 'monthly'
        ) then display_revision.recurrence_rule->>'frequency'
        else null
      end as recurrence_frequency,
      series.version as series_version,
      active_revision.default_assignee_member_id
        as series_default_assignee_member_id,
      active_revision.due_local_time as series_due_local_time,
      case
        when active_revision.recurrence_rule = '{"type":"once"}'::jsonb
          then null
        else active_revision.recurrence_rule
      end as recurrence_rule,
      (
        v_actor_role in ('owner', 'admin')
        and active_revision.recurrence_rule <> '{"type":"once"}'::jsonb
      ) as can_manage_series
    from public.chore_occurrences as occurrence
    join public.chore_series as series
      on series.household_id = occurrence.household_id
     and series.id = occurrence.series_id
     and series.deleted_at is null
    join public.chore_series_revisions as display_revision
      on display_revision.household_id = occurrence.household_id
     and display_revision.id = occurrence.revision_id
    join public.chore_series_revisions as active_revision
      on active_revision.household_id = series.household_id
     and active_revision.id = series.active_revision_id
    join public.household_members as assignee
      on assignee.household_id = occurrence.household_id
     and assignee.id = occurrence.assignee_member_id
    where occurrence.household_id = household.id
      and occurrence.due_local_date = v_local_date
      and occurrence.status in ('scheduled', 'completed')
    order by
      occurrence.due_at nulls last,
      lower(display_revision.title),
      occurrence.id
  ) as item on true
  where household.id = p_household_id
  order by
    item.due_at nulls last,
    lower(item.title),
    item.occurrence_id;
end;
$$;

revoke all on function public.get_today_chores_v2(uuid)
  from public, anon, authenticated;
grant execute on function public.get_today_chores_v2(uuid)
  to authenticated;
