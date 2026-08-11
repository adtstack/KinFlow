-- KinFlow WP04-04A recurring Calendar creation and bounded materialization.
-- Existing v1 one-time commands and reads remain available for N-1 clients.

create or replace function app_private.is_valid_calendar_recurrence_end(
  p_end jsonb
)
returns boolean
language plpgsql
immutable
strict
set search_path = ''
as $$
declare
  v_count integer;
  v_until date;
begin
  if pg_catalog.jsonb_typeof(p_end) <> 'object' then
    return false;
  end if;

  if p_end = '{"type":"never"}'::jsonb then
    return true;
  end if;

  if p_end->>'type' = 'count'
    and (select pg_catalog.count(*) from pg_catalog.jsonb_object_keys(p_end)) = 2
    and p_end ? 'count'
    and pg_catalog.jsonb_typeof(p_end->'count') = 'number'
    and p_end->>'count' ~ '^[0-9]+$' then
    v_count := (p_end->>'count')::integer;
    return v_count between 1 and 1000;
  end if;

  if p_end->>'type' = 'until'
    and (select pg_catalog.count(*) from pg_catalog.jsonb_object_keys(p_end)) = 2
    and p_end ? 'localDate'
    and pg_catalog.jsonb_typeof(p_end->'localDate') = 'string'
    and p_end->>'localDate' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    v_until := pg_catalog.make_date(
      pg_catalog.substr(p_end->>'localDate', 1, 4)::integer,
      pg_catalog.substr(p_end->>'localDate', 6, 2)::integer,
      pg_catalog.substr(p_end->>'localDate', 9, 2)::integer
    );
    return v_until is not null;
  end if;

  return false;
exception
  when invalid_text_representation
    or datetime_field_overflow
    or numeric_value_out_of_range then
    return false;
end;
$$;

revoke all on function app_private.is_valid_calendar_recurrence_end(jsonb)
  from public, anon, authenticated, service_role;

create or replace function app_private.is_valid_calendar_recurrence_rule(
  p_rule jsonb
)
returns boolean
language plpgsql
immutable
strict
set search_path = ''
as $$
declare
  v_frequency text;
  v_interval integer;
  v_month_day integer;
  v_weekday_count integer;
  v_distinct_weekday_count integer;
begin
  if pg_catalog.jsonb_typeof(p_rule) <> 'object'
    or not p_rule ? 'frequency'
    or not p_rule ? 'interval'
    or not p_rule ? 'end'
    or pg_catalog.jsonb_typeof(p_rule->'frequency') <> 'string'
    or pg_catalog.jsonb_typeof(p_rule->'interval') <> 'number'
    or p_rule->>'interval' !~ '^[0-9]+$'
    or not app_private.is_valid_calendar_recurrence_end(p_rule->'end') then
    return false;
  end if;

  v_frequency := p_rule->>'frequency';
  v_interval := (p_rule->>'interval')::integer;
  if v_interval not between 1 and 30 then
    return false;
  end if;

  if v_frequency = 'daily' then
    return (
      select pg_catalog.count(*)
      from pg_catalog.jsonb_object_keys(p_rule)
    ) = 3;
  end if;

  if v_frequency = 'weekly' then
    if (
      select pg_catalog.count(*)
      from pg_catalog.jsonb_object_keys(p_rule)
    ) <> 4
      or not p_rule ? 'weekdays'
      or pg_catalog.jsonb_typeof(p_rule->'weekdays') <> 'array'
      or pg_catalog.jsonb_array_length(p_rule->'weekdays') not between 1 and 7
      or exists (
        select 1
        from pg_catalog.jsonb_array_elements(p_rule->'weekdays') as weekday(value)
        where pg_catalog.jsonb_typeof(weekday.value) <> 'string'
          or weekday.value #>> '{}' not in (
            'MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'
          )
      ) then
      return false;
    end if;

    select
      pg_catalog.count(*),
      pg_catalog.count(distinct weekday.value)
    into v_weekday_count, v_distinct_weekday_count
    from pg_catalog.jsonb_array_elements_text(
      p_rule->'weekdays'
    ) as weekday(value);
    return v_weekday_count = v_distinct_weekday_count;
  end if;

  if v_frequency = 'monthly' then
    if (
      select pg_catalog.count(*)
      from pg_catalog.jsonb_object_keys(p_rule)
    ) <> 4
      or not p_rule ? 'monthDay'
      or pg_catalog.jsonb_typeof(p_rule->'monthDay') <> 'number'
      or p_rule->>'monthDay' !~ '^[0-9]+$' then
      return false;
    end if;
    v_month_day := (p_rule->>'monthDay')::integer;
    return v_month_day between 1 and 31;
  end if;

  return false;
exception
  when invalid_text_representation or numeric_value_out_of_range then
    return false;
end;
$$;

revoke all on function app_private.is_valid_calendar_recurrence_rule(jsonb)
  from public, anon, authenticated, service_role;

alter table public.event_series_revisions
  add column snapshot_title text,
  add column snapshot_description text,
  add column snapshot_timezone text,
  add column snapshot_is_all_day boolean;

alter table public.event_series_revisions
  add constraint event_recurring_revision_snapshot_ck
  check (
    recurrence_rule is null
    or (
      app_private.is_valid_calendar_recurrence_rule(recurrence_rule)
      and snapshot_title is not null
      and pg_catalog.char_length(snapshot_title) between 1 and 200
      and snapshot_title !~ '[[:cntrl:]]'
      and (
        snapshot_description is null
        or pg_catalog.char_length(snapshot_description) <= 8000
      )
      and snapshot_is_all_day is not null
      and (
        snapshot_is_all_day and snapshot_timezone is null
        or not snapshot_is_all_day
          and app_private.is_valid_iana_timezone(snapshot_timezone)
      )
    )
  ) not valid;

alter table public.event_series_revisions
  validate constraint event_recurring_revision_snapshot_ck;

alter table public.event_occurrences
  add column recurrence_local_start_date date;

update public.event_occurrences
set recurrence_local_start_date = local_start_date
where recurrence_local_start_date is null;

alter table public.event_occurrences
  alter column recurrence_local_start_date set not null;

create index event_occurrences_recurrence_slot_idx
  on public.event_occurrences(
    household_id,
    series_id,
    recurrence_local_start_date,
    status
  );

create or replace function app_private.populate_event_occurrence_recurrence_date()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.recurrence_local_start_date := coalesce(
    new.recurrence_local_start_date,
    new.local_start_date
  );
  return new;
end;
$$;

revoke all on function app_private.populate_event_occurrence_recurrence_date()
  from public, anon, authenticated, service_role;

create trigger event_occurrence_populate_recurrence_date
before insert on public.event_occurrences
for each row execute function app_private.populate_event_occurrence_recurrence_date();

create or replace function app_private.reject_event_revision_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'calendar event revisions are immutable';
end;
$$;

revoke all on function app_private.reject_event_revision_update()
  from public, anon, authenticated, service_role;

create trigger event_revisions_immutable
before update on public.event_series_revisions
for each row execute function app_private.reject_event_revision_update();

create or replace function app_private.reject_event_occurrence_identity_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.household_id is distinct from old.household_id
    or new.series_id is distinct from old.series_id
    or new.occurrence_key is distinct from old.occurrence_key
    or new.recurrence_local_start_date is distinct from
       old.recurrence_local_start_date then
    raise exception using
      errcode = '55000',
      message = 'calendar occurrence recurrence identity is immutable';
  end if;
  return new;
end;
$$;

revoke all on function app_private.reject_event_occurrence_identity_change()
  from public, anon, authenticated, service_role;

create trigger event_occurrence_recurrence_identity_immutable
before update on public.event_occurrences
for each row execute function app_private.reject_event_occurrence_identity_change();

create table public.event_revision_participants (
  household_id uuid not null,
  series_id uuid not null,
  revision_id uuid not null,
  member_id uuid not null,
  created_at timestamptz not null default pg_catalog.now(),
  primary key (household_id, revision_id, member_id),
  constraint event_revision_participant_revision_fk
    foreign key (household_id, series_id, revision_id)
    references public.event_series_revisions(household_id, series_id, id)
    on delete cascade,
  constraint event_revision_participant_member_fk
    foreign key (household_id, member_id)
    references public.household_members(household_id, id)
);

create index event_revision_participants_member_idx
  on public.event_revision_participants(household_id, member_id, revision_id);

alter table public.event_revision_participants enable row level security;
alter table public.event_revision_participants force row level security;

create policy event_revision_participants_select_member
on public.event_revision_participants
for select
to authenticated
using (
  app_private.is_active_household_member(household_id)
  and exists (
    select 1
    from public.event_series as series
    where series.household_id = event_revision_participants.household_id
      and series.id = event_revision_participants.series_id
      and series.deleted_at is null
  )
);

revoke all on table public.event_revision_participants
  from anon, authenticated;
grant select on table public.event_revision_participants to authenticated;

create table app_private.calendar_recurring_command_requests (
  authenticated_user_id uuid not null
    references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  request_hash bytea not null check (pg_catalog.octet_length(request_hash) = 32),
  household_id uuid not null,
  series_id uuid not null,
  revision_id uuid not null,
  first_occurrence_id uuid not null,
  result_materialized_through date not null,
  result_materialized_count integer not null check (
    result_materialized_count between 1 and 366
  ),
  created_at timestamptz not null default pg_catalog.now(),
  primary key (authenticated_user_id, idempotency_key),
  constraint calendar_recurring_request_series_fk
    foreign key (household_id, series_id)
    references public.event_series(household_id, id)
    on delete cascade,
  constraint calendar_recurring_request_revision_fk
    foreign key (household_id, series_id, revision_id)
    references public.event_series_revisions(household_id, series_id, id),
  constraint calendar_recurring_request_occurrence_fk
    foreign key (household_id, first_occurrence_id)
    references public.event_occurrences(household_id, id)
    on delete cascade
);

revoke all on table app_private.calendar_recurring_command_requests
  from public, anon, authenticated, service_role;

create or replace function app_private.calendar_revision_candidate_dates(
  p_household_id uuid,
  p_series_id uuid,
  p_revision_id uuid,
  p_window_start date,
  p_window_end date
)
returns table (recurrence_local_start_date date)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_start_date date;
  v_rule jsonb;
  v_frequency text;
  v_interval integer;
  v_weekdays text[];
  v_month_day integer;
  v_end_type text;
  v_end_count integer;
  v_end_until date;
  v_effective_end date;
begin
  if p_household_id is null
    or p_series_id is null
    or p_revision_id is null
    or p_window_start is null
    or p_window_end is null
    or p_window_end < p_window_start then
    raise exception using
      errcode = 'KFE07',
      message = 'invalid calendar recurrence rule';
  end if;

  select revision.local_start_date, revision.recurrence_rule
  into v_start_date, v_rule
  from public.event_series as series
  join public.event_series_revisions as revision
    on revision.household_id = series.household_id
   and revision.series_id = series.id
   and revision.id = p_revision_id
  where series.household_id = p_household_id
    and series.id = p_series_id
    and series.active_revision_id = p_revision_id
    and series.deleted_at is null;

  if not found
    or v_rule is null
    or not app_private.is_valid_calendar_recurrence_rule(v_rule)
    or p_window_end > v_start_date + 365 then
    raise exception using
      errcode = 'KFE07',
      message = 'invalid calendar recurrence rule';
  end if;

  v_frequency := v_rule->>'frequency';
  v_interval := (v_rule->>'interval')::integer;
  v_month_day := nullif(v_rule->>'monthDay', '')::integer;
  v_end_type := v_rule->'end'->>'type';
  v_end_count := nullif(v_rule->'end'->>'count', '')::integer;
  v_end_until := nullif(v_rule->'end'->>'localDate', '')::date;
  if v_frequency = 'weekly' then
    select pg_catalog.array_agg(weekday.value order by weekday.ordinality)
    into v_weekdays
    from pg_catalog.jsonb_array_elements_text(v_rule->'weekdays')
      with ordinality as weekday(value, ordinality);
  end if;

  v_effective_end := p_window_end;
  if v_end_type = 'until' then
    v_effective_end := least(v_effective_end, v_end_until);
  end if;
  if v_effective_end < v_start_date then
    return;
  end if;

  return query
  with candidate_dates as materialized (
    select generated.local_date::date as local_date
    from pg_catalog.generate_series(
      v_start_date::timestamp without time zone,
      v_effective_end::timestamp without time zone,
      interval '1 day'
    ) as generated(local_date)
  ),
  matched_dates as materialized (
    select candidate.local_date
    from candidate_dates as candidate
    where case v_frequency
      when 'daily' then
        (candidate.local_date - v_start_date) % v_interval = 0
      when 'weekly' then
        (
          (
            candidate.local_date
            - (
              v_start_date
              - (extract(isodow from v_start_date)::integer - 1)
            )
          ) / 7
        ) % v_interval = 0
        and (
          array['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU']
        )[extract(isodow from candidate.local_date)::integer] = any(v_weekdays)
      when 'monthly' then
        extract(day from candidate.local_date)::integer = v_month_day
        and (
          (
            extract(year from candidate.local_date)::integer
            - extract(year from v_start_date)::integer
          ) * 12
          + extract(month from candidate.local_date)::integer
          - extract(month from v_start_date)::integer
        ) % v_interval = 0
      else false
    end
  ),
  numbered_dates as materialized (
    select
      matched.local_date,
      pg_catalog.row_number() over (order by matched.local_date) as occurrence_number
    from matched_dates as matched
  )
  select numbered.local_date
  from numbered_dates as numbered
  where numbered.local_date >= greatest(p_window_start, v_start_date)
    and (
      v_end_type <> 'count'
      or numbered.occurrence_number <= v_end_count
    )
  order by numbered.local_date;
end;
$$;

revoke all on function app_private.calendar_revision_candidate_dates(
  uuid,
  uuid,
  uuid,
  date,
  date
) from public, anon, authenticated, service_role;

create or replace function app_private.materialize_calendar_revision_window(
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
  v_is_all_day boolean;
  v_timezone text;
  v_local_start_time time without time zone;
  v_duration_minutes integer;
  v_overlap_policy text;
  v_all_day_span integer;
  v_inserted_count integer := 0;
  v_branch_count integer;
begin
  select
    revision.snapshot_is_all_day,
    revision.snapshot_timezone,
    revision.local_start_time,
    revision.duration_minutes,
    revision.overlap_policy,
    revision.all_day_end_date_exclusive - revision.local_start_date
  into
    v_is_all_day,
    v_timezone,
    v_local_start_time,
    v_duration_minutes,
    v_overlap_policy,
    v_all_day_span
  from public.event_series as series
  join public.event_series_revisions as revision
    on revision.household_id = series.household_id
   and revision.series_id = series.id
   and revision.id = p_revision_id
  where series.household_id = p_household_id
    and series.id = p_series_id
    and series.active_revision_id = p_revision_id
    and series.deleted_at is null
    and revision.recurrence_rule is not null;

  if not found then
    raise exception using
      errcode = 'KFE07',
      message = 'invalid calendar recurrence rule';
  end if;

  if v_is_all_day then
    insert into public.event_occurrences (
      id,
      household_id,
      series_id,
      revision_id,
      occurrence_key,
      recurrence_local_start_date,
      local_start_date,
      all_day_end_date_exclusive
    )
    select
      extensions.gen_random_uuid(),
      p_household_id,
      p_series_id,
      p_revision_id,
      p_series_id::text || ':' || candidate.recurrence_local_start_date::text,
      candidate.recurrence_local_start_date,
      candidate.recurrence_local_start_date,
      candidate.recurrence_local_start_date + v_all_day_span
    from app_private.calendar_revision_candidate_dates(
      p_household_id,
      p_series_id,
      p_revision_id,
      p_window_start,
      p_window_end
    ) as candidate
    on conflict (household_id, occurrence_key) do nothing;

    get diagnostics v_inserted_count = row_count;
    return v_inserted_count;
  end if;

  insert into public.event_occurrences (
    id,
    household_id,
    series_id,
    revision_id,
    occurrence_key,
    recurrence_local_start_date,
    local_start_date,
    starts_at,
    ends_at,
    timezone,
    dst_adjustment
  )
  select
    extensions.gen_random_uuid(),
    p_household_id,
    p_series_id,
    p_revision_id,
    p_series_id::text || ':' || candidate.recurrence_local_start_date::text,
    candidate.recurrence_local_start_date,
    candidate.recurrence_local_start_date,
    resolved.resolved_at,
    resolved.resolved_at
      + pg_catalog.make_interval(mins => v_duration_minutes),
    v_timezone,
    pg_catalog.jsonb_build_object(
      'candidateCount', resolved.candidate_count,
      'gapPolicy', 'reject',
      'overlapPolicy', v_overlap_policy,
      'resolution', resolved.resolution,
      'utcOffsetSeconds', resolved.utc_offset_seconds
    )
  from app_private.calendar_revision_candidate_dates(
    p_household_id,
    p_series_id,
    p_revision_id,
    p_window_start,
    p_window_end
  ) as candidate
  cross join lateral app_private.resolve_calendar_zoned_datetime(
    candidate.recurrence_local_start_date,
    v_local_start_time,
    v_timezone,
    v_overlap_policy
  ) as resolved
  on conflict (household_id, occurrence_key) do nothing;

  get diagnostics v_branch_count = row_count;
  v_inserted_count := v_inserted_count + v_branch_count;
  return v_inserted_count;
end;
$$;

revoke all on function app_private.materialize_calendar_revision_window(
  uuid,
  uuid,
  uuid,
  date,
  date
) from public, anon, authenticated, service_role;

create or replace function app_private.calendar_occurrence_snapshot(
  p_household_id uuid,
  p_occurrence_id uuid
)
returns table (
  household_id uuid,
  household_timezone text,
  household_local_date date,
  series_id uuid,
  occurrence_id uuid,
  title text,
  description text,
  is_all_day boolean,
  local_start_date date,
  local_start_time time without time zone,
  duration_minutes integer,
  all_day_end_date_exclusive date,
  timezone text,
  overlap_policy text,
  starts_at timestamptz,
  ends_at timestamptz,
  dst_resolution text,
  utc_offset_seconds integer,
  participant_member_ids uuid[],
  participant_display_names text[],
  series_version bigint,
  occurrence_version bigint,
  recurrence_rule jsonb,
  recurrence_local_start_date date,
  revision_number integer,
  is_exception boolean,
  deleted boolean
)
language sql
stable
set search_path = ''
as $$
  select
    household.id,
    household.timezone,
    (pg_catalog.statement_timestamp() at time zone household.timezone)::date,
    series.id,
    occurrence.id,
    coalesce(revision.snapshot_title, series.title),
    case
      when revision.recurrence_rule is null then series.description
      else revision.snapshot_description
    end,
    coalesce(revision.snapshot_is_all_day, series.is_all_day),
    occurrence.local_start_date,
    revision.local_start_time,
    revision.duration_minutes,
    occurrence.all_day_end_date_exclusive,
    occurrence.timezone,
    revision.overlap_policy,
    occurrence.starts_at,
    occurrence.ends_at,
    occurrence.dst_adjustment->>'resolution',
    (occurrence.dst_adjustment->>'utcOffsetSeconds')::integer,
    participant_snapshot.member_ids,
    participant_snapshot.display_names,
    series.version,
    occurrence.version,
    revision.recurrence_rule,
    occurrence.recurrence_local_start_date,
    revision.revision_number,
    false,
    series.deleted_at is not null
  from public.event_occurrences as occurrence
  join public.event_series as series
    on series.household_id = occurrence.household_id
   and series.id = occurrence.series_id
  join public.households as household
    on household.id = series.household_id
   and household.deleted_at is null
  join public.event_series_revisions as revision
    on revision.household_id = occurrence.household_id
   and revision.series_id = occurrence.series_id
   and revision.id = occurrence.revision_id
  cross join lateral (
    select
      pg_catalog.array_agg(selected.member_id order by selected.member_id)
        as member_ids,
      pg_catalog.array_agg(member.display_name order by selected.member_id)
        as display_names
    from (
      select participant.member_id
      from public.event_revision_participants as participant
      where revision.recurrence_rule is not null
        and participant.household_id = revision.household_id
        and participant.series_id = revision.series_id
        and participant.revision_id = revision.id
      union all
      select participant.member_id
      from public.event_participants as participant
      where revision.recurrence_rule is null
        and participant.household_id = revision.household_id
        and participant.series_id = revision.series_id
    ) as selected
    join public.household_members as member
      on member.household_id = revision.household_id
     and member.id = selected.member_id
  ) as participant_snapshot
  where occurrence.household_id = p_household_id
    and occurrence.id = p_occurrence_id
$$;

revoke all on function app_private.calendar_occurrence_snapshot(uuid, uuid)
  from public, anon, authenticated, service_role;

create or replace function public.create_recurring_calendar_event(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_title text,
  p_description text,
  p_is_all_day boolean,
  p_local_start_date date,
  p_local_start_time time without time zone,
  p_duration_minutes integer,
  p_all_day_end_date_exclusive date,
  p_timezone text,
  p_overlap_policy text,
  p_recurrence_rule jsonb,
  p_participant_member_ids uuid[]
)
returns table (
  household_id uuid,
  household_timezone text,
  household_local_date date,
  series_id uuid,
  first_occurrence_id uuid,
  recurrence_rule jsonb,
  materialized_through date,
  materialized_count integer,
  version bigint,
  created boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_actor_member_id uuid;
  v_title text := pg_catalog.btrim(p_title);
  v_description text := nullif(pg_catalog.btrim(p_description), '');
  v_household_timezone text;
  v_household_local_date date;
  v_participant_member_ids uuid[];
  v_participant_count integer;
  v_start_weekday text;
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_series_id uuid;
  v_revision_id uuid;
  v_first_occurrence_id uuid;
  v_initial_horizon_end date;
  v_materialized_count integer;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFE01',
      message = 'authentication required';
  end if;

  if p_idempotency_key is null
    or p_household_id is null
    or p_is_all_day is null
    or p_local_start_date is null
    or p_participant_member_ids is null
    or pg_catalog.cardinality(p_participant_member_ids) not between 1 and 50
    or (
      select pg_catalog.count(distinct participant_id)
      from pg_catalog.unnest(p_participant_member_ids) as participant_id
    ) <> pg_catalog.cardinality(p_participant_member_ids)
    or v_title is null
    or pg_catalog.char_length(v_title) not between 1 and 200
    or v_title ~ '[[:cntrl:]]'
    or (
      v_description is not null
      and pg_catalog.char_length(v_description) > 8000
    )
    or p_recurrence_rule is null
    or not app_private.is_valid_calendar_recurrence_rule(p_recurrence_rule)
    or (
      p_is_all_day
      and (
        p_local_start_time is not null
        or p_duration_minutes is not null
        or p_all_day_end_date_exclusive is null
        or p_all_day_end_date_exclusive <= p_local_start_date
        or p_timezone is not null
        or p_overlap_policy is not null
      )
    )
    or (
      not p_is_all_day
      and (
        p_local_start_time is null
        or extract(second from p_local_start_time) <> 0
        or p_duration_minutes is null
        or p_duration_minutes not between 1 and 10080
        or p_all_day_end_date_exclusive is not null
        or p_timezone is null
        or not app_private.is_valid_iana_timezone(p_timezone)
        or p_overlap_policy not in ('earlier', 'later')
      )
    ) then
    raise exception using
      errcode = 'KFE07',
      message = 'invalid calendar recurrence rule';
  end if;

  v_start_weekday := (
    array['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU']
  )[extract(isodow from p_local_start_date)::integer];
  if (
    p_recurrence_rule->>'frequency' = 'weekly'
    and not (p_recurrence_rule->'weekdays' ? v_start_weekday)
  ) or (
    p_recurrence_rule->>'frequency' = 'monthly'
    and (p_recurrence_rule->>'monthDay')::integer
      <> extract(day from p_local_start_date)::integer
  ) or (
    p_recurrence_rule->'end'->>'type' = 'until'
    and (p_recurrence_rule->'end'->>'localDate')::date < p_local_start_date
  ) then
    raise exception using
      errcode = 'KFE07',
      message = 'invalid calendar recurrence rule';
  end if;

  select household.timezone, caller.id
  into v_household_timezone, v_actor_member_id
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
      errcode = 'KFE03',
      message = 'calendar event not found or forbidden';
  end if;

  v_household_local_date :=
    (pg_catalog.statement_timestamp() at time zone v_household_timezone)::date;
  select pg_catalog.array_agg(participant_id order by participant_id)
  into v_participant_member_ids
  from pg_catalog.unnest(p_participant_member_ids) as participant_id;

  select pg_catalog.count(*)::integer
  into v_participant_count
  from public.household_members as participant
  where participant.household_id = p_household_id
    and participant.id = any(v_participant_member_ids)
    and participant.removed_at is null;

  if v_participant_count <> pg_catalog.cardinality(v_participant_member_ids) then
    raise exception using
      errcode = 'KFE03',
      message = 'calendar event not found or forbidden';
  end if;

  v_request_hash := extensions.digest(
    pg_catalog.convert_to(
      pg_catalog.jsonb_build_object(
        'command', 'create_recurring_calendar_event',
        'household_id', p_household_id,
        'title', v_title,
        'description', v_description,
        'is_all_day', p_is_all_day,
        'local_start_date', p_local_start_date,
        'local_start_time', p_local_start_time,
        'duration_minutes', p_duration_minutes,
        'all_day_end_date_exclusive', p_all_day_end_date_exclusive,
        'timezone', p_timezone,
        'overlap_policy', p_overlap_policy,
        'recurrence_rule', p_recurrence_rule,
        'participant_member_ids', v_participant_member_ids
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_authenticated_user_id::text
        || ':calendar-recurring-create:'
        || p_idempotency_key::text,
      0
    )
  );

  select
    request.request_hash,
    request.series_id,
    request.revision_id,
    request.first_occurrence_id,
    request.result_materialized_through,
    request.result_materialized_count
  into
    v_existing_request_hash,
    v_series_id,
    v_revision_id,
    v_first_occurrence_id,
    v_initial_horizon_end,
    v_materialized_count
  from app_private.calendar_recurring_command_requests as request
  where request.authenticated_user_id = v_authenticated_user_id
    and request.idempotency_key = p_idempotency_key;

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFE04',
        message = 'idempotency key reused with different calendar input';
    end if;

    return query
    select
      p_household_id,
      v_household_timezone,
      v_household_local_date,
      v_series_id,
      v_first_occurrence_id,
      revision.recurrence_rule,
      v_initial_horizon_end,
      v_materialized_count,
      series.version,
      false
    from public.event_series as series
    join public.event_series_revisions as revision
      on revision.household_id = series.household_id
     and revision.series_id = series.id
     and revision.id = v_revision_id
    where series.household_id = p_household_id
      and series.id = v_series_id;
    return;
  end if;

  v_series_id := extensions.gen_random_uuid();
  v_revision_id := extensions.gen_random_uuid();
  v_initial_horizon_end := p_local_start_date + 365;
  if p_recurrence_rule->'end'->>'type' = 'until' then
    v_initial_horizon_end := least(
      v_initial_horizon_end,
      (p_recurrence_rule->'end'->>'localDate')::date
    );
  end if;

  insert into public.event_series (
    id,
    household_id,
    title,
    description,
    timezone,
    is_all_day,
    active_revision_id,
    created_by_user_id
  ) values (
    v_series_id,
    p_household_id,
    v_title,
    v_description,
    p_timezone,
    p_is_all_day,
    v_revision_id,
    v_authenticated_user_id
  );

  insert into public.event_series_revisions (
    id,
    household_id,
    series_id,
    revision_number,
    local_start_date,
    local_start_time,
    duration_minutes,
    all_day_end_date_exclusive,
    gap_policy,
    overlap_policy,
    recurrence_rule,
    created_by_user_id,
    snapshot_title,
    snapshot_description,
    snapshot_timezone,
    snapshot_is_all_day
  ) values (
    v_revision_id,
    p_household_id,
    v_series_id,
    1,
    p_local_start_date,
    p_local_start_time,
    p_duration_minutes,
    p_all_day_end_date_exclusive,
    case when p_is_all_day then null else 'reject' end,
    p_overlap_policy,
    p_recurrence_rule,
    v_authenticated_user_id,
    v_title,
    v_description,
    p_timezone,
    p_is_all_day
  );

  insert into public.event_participants (
    household_id,
    series_id,
    member_id
  )
  select p_household_id, v_series_id, participant_id
  from pg_catalog.unnest(v_participant_member_ids) as participant_id;

  insert into public.event_revision_participants (
    household_id,
    series_id,
    revision_id,
    member_id
  )
  select p_household_id, v_series_id, v_revision_id, participant_id
  from pg_catalog.unnest(v_participant_member_ids) as participant_id;

  begin
    perform app_private.materialize_calendar_revision_window(
      p_household_id,
      v_series_id,
      v_revision_id,
      p_local_start_date,
      v_initial_horizon_end
    );
  exception
    when sqlstate 'KFT01' then
      raise exception using
        errcode = 'KFE07',
        message = 'invalid calendar recurrence rule';
    when sqlstate 'KFT02' then
      raise exception using
        errcode = 'KFE06',
        message = 'nonexistent calendar local time';
  end;

  select occurrence.id
  into v_first_occurrence_id
  from public.event_occurrences as occurrence
  where occurrence.household_id = p_household_id
    and occurrence.series_id = v_series_id
    and occurrence.recurrence_local_start_date = p_local_start_date
    and occurrence.status = 'scheduled';

  select pg_catalog.count(*)::integer
  into v_materialized_count
  from public.event_occurrences as occurrence
  where occurrence.household_id = p_household_id
    and occurrence.series_id = v_series_id
    and occurrence.status = 'scheduled';

  if v_first_occurrence_id is null
    or v_materialized_count not between 1 and 366 then
    raise exception using
      errcode = 'KFE07',
      message = 'invalid calendar recurrence rule';
  end if;

  insert into app_private.calendar_recurring_command_requests (
    authenticated_user_id,
    idempotency_key,
    request_hash,
    household_id,
    series_id,
    revision_id,
    first_occurrence_id,
    result_materialized_through,
    result_materialized_count
  ) values (
    v_authenticated_user_id,
    p_idempotency_key,
    v_request_hash,
    p_household_id,
    v_series_id,
    v_revision_id,
    v_first_occurrence_id,
    v_initial_horizon_end,
    v_materialized_count
  );

  insert into app_private.calendar_audit_events (
    household_id,
    action,
    series_id,
    occurrence_id,
    actor_user_id,
    actor_member_id,
    correlation_id,
    series_version,
    occurrence_version
  ) values (
    p_household_id,
    'calendar.created',
    v_series_id,
    v_first_occurrence_id,
    v_authenticated_user_id,
    v_actor_member_id,
    p_idempotency_key,
    1,
    1
  );

  return query select
    p_household_id,
    v_household_timezone,
    v_household_local_date,
    v_series_id,
    v_first_occurrence_id,
    p_recurrence_rule,
    v_initial_horizon_end,
    v_materialized_count,
    1::bigint,
    true;
end;
$$;

revoke all on function public.create_recurring_calendar_event(
  uuid,
  uuid,
  text,
  text,
  boolean,
  date,
  time without time zone,
  integer,
  date,
  text,
  text,
  jsonb,
  uuid[]
) from public, anon, authenticated;

grant execute on function public.create_recurring_calendar_event(
  uuid,
  uuid,
  text,
  text,
  boolean,
  date,
  time without time zone,
  integer,
  date,
  text,
  text,
  jsonb,
  uuid[]
) to authenticated;

create function public.get_calendar_event_page_v2(
  p_household_id uuid,
  p_view text default 'agenda',
  p_range_start_date date default null,
  p_range_end_date_exclusive date default null,
  p_limit integer default 30,
  p_after_cursor text default null
)
returns table (
  household_id uuid,
  household_timezone text,
  household_local_date date,
  generated_at timestamptz,
  view_mode text,
  range_start_date date,
  range_end_date_exclusive date,
  page_limit integer,
  has_more boolean,
  page_cursor text,
  view_local_date date,
  view_local_time time without time zone,
  series_id uuid,
  occurrence_id uuid,
  title text,
  description text,
  is_all_day boolean,
  local_start_date date,
  local_start_time time without time zone,
  duration_minutes integer,
  all_day_end_date_exclusive date,
  timezone text,
  overlap_policy text,
  starts_at timestamptz,
  ends_at timestamptz,
  dst_resolution text,
  utc_offset_seconds integer,
  participant_member_ids uuid[],
  participant_display_names text[],
  version bigint,
  occurrence_version bigint,
  recurrence_rule jsonb,
  recurrence_local_start_date date,
  revision_number integer,
  is_exception boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_generated_at timestamptz := pg_catalog.statement_timestamp();
  v_view text := pg_catalog.lower(pg_catalog.btrim(coalesce(p_view, '')));
  v_household_timezone text;
  v_household_local_date date;
  v_range_start_date date;
  v_range_end_date_exclusive date;
  v_range_starts_at timestamptz;
  v_range_ends_at timestamptz;
  v_cursor_json jsonb;
  v_cursor_date date;
  v_cursor_kind integer;
  v_cursor_minute integer;
  v_cursor_occurrence_id uuid;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFE01',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or v_view not in ('agenda', 'day')
    or p_limit is null
    or p_limit not between 1 and 100
    or (p_range_start_date is null) <> (p_range_end_date_exclusive is null)
    or p_range_start_date is null and v_view <> 'agenda'
    or p_range_start_date is not null and (
      p_range_end_date_exclusive <= p_range_start_date
      or p_range_end_date_exclusive - p_range_start_date > 366
      or v_view = 'day'
         and p_range_end_date_exclusive - p_range_start_date <> 1
    )
    or p_after_cursor is not null and (
      p_range_start_date is null
      or pg_catalog.char_length(p_after_cursor) not between 2 and 1000
      or pg_catalog.char_length(p_after_cursor) % 2 <> 0
      or p_after_cursor !~ '^[0-9a-f]+$'
    ) then
    raise exception using
      errcode = 'KFE02',
      message = 'invalid calendar event input';
  end if;

  select household.timezone
  into v_household_timezone
  from public.households as household
  join public.household_members as caller
    on caller.household_id = household.id
   and caller.auth_user_id = v_authenticated_user_id
   and caller.removed_at is null
  where household.id = p_household_id
    and household.deleted_at is null;

  if not found then
    raise exception using
      errcode = 'KFE03',
      message = 'calendar event not found or forbidden';
  end if;

  v_household_local_date :=
    (v_generated_at at time zone v_household_timezone)::date;
  v_range_start_date := coalesce(p_range_start_date, v_household_local_date);
  v_range_end_date_exclusive := coalesce(
    p_range_end_date_exclusive,
    v_range_start_date + 90
  );
  v_range_starts_at :=
    (v_range_start_date::timestamp without time zone)
      at time zone v_household_timezone;
  v_range_ends_at :=
    (v_range_end_date_exclusive::timestamp without time zone)
      at time zone v_household_timezone;

  if p_after_cursor is not null then
    begin
      v_cursor_json := pg_catalog.convert_from(
        pg_catalog.decode(p_after_cursor, 'hex'),
        'UTF8'
      )::jsonb;

      if pg_catalog.jsonb_typeof(v_cursor_json) <> 'object'
        or (
          select pg_catalog.count(*)
          from pg_catalog.jsonb_object_keys(v_cursor_json)
        ) <> 9
        or not v_cursor_json ?& array[
          'v', 'household', 'view', 'rangeStart', 'rangeEndExclusive',
          'date', 'kind', 'minute', 'id'
        ]
        or pg_catalog.jsonb_typeof(v_cursor_json->'v') <> 'number'
        or (v_cursor_json->>'v')::integer <> 2
        or pg_catalog.jsonb_typeof(v_cursor_json->'household') <> 'string'
        or v_cursor_json->>'household' <> p_household_id::text
        or pg_catalog.jsonb_typeof(v_cursor_json->'view') <> 'string'
        or v_cursor_json->>'view' <> v_view
        or pg_catalog.jsonb_typeof(v_cursor_json->'rangeStart') <> 'string'
        or (v_cursor_json->>'rangeStart')::date <> v_range_start_date
        or pg_catalog.jsonb_typeof(v_cursor_json->'rangeEndExclusive') <> 'string'
        or (v_cursor_json->>'rangeEndExclusive')::date <>
           v_range_end_date_exclusive
        or pg_catalog.jsonb_typeof(v_cursor_json->'date') <> 'string'
        or pg_catalog.jsonb_typeof(v_cursor_json->'kind') <> 'number'
        or pg_catalog.jsonb_typeof(v_cursor_json->'minute') <> 'number'
        or pg_catalog.jsonb_typeof(v_cursor_json->'id') <> 'string' then
        raise exception using
          errcode = 'KFE02',
          message = 'invalid calendar event input';
      end if;

      v_cursor_date := (v_cursor_json->>'date')::date;
      v_cursor_kind := (v_cursor_json->>'kind')::integer;
      v_cursor_minute := (v_cursor_json->>'minute')::integer;
      v_cursor_occurrence_id := (v_cursor_json->>'id')::uuid;

      if v_cursor_date < v_range_start_date
        or v_cursor_date >= v_range_end_date_exclusive
        or v_cursor_kind not in (0, 1)
        or v_cursor_kind = 0 and v_cursor_minute <> -1
        or v_cursor_kind = 1 and v_cursor_minute not between 0 and 1439 then
        raise exception using
          errcode = 'KFE02',
          message = 'invalid calendar event input';
      end if;
    exception
      when sqlstate 'KFE02' then raise;
      when others then
        raise exception using
          errcode = 'KFE02',
          message = 'invalid calendar event input';
    end;
  end if;

  return query
  with base as materialized (
    select
      snapshot.*,
      greatest(
        case
          when snapshot.is_all_day then snapshot.local_start_date
          else (snapshot.starts_at at time zone v_household_timezone)::date
        end,
        v_range_start_date
      ) as sort_date,
      case when snapshot.is_all_day then 0 else 1 end as sort_kind,
      case
        when snapshot.is_all_day then -1
        when snapshot.starts_at <= v_range_starts_at then 0
        else
          extract(
            hour from snapshot.starts_at at time zone v_household_timezone
          )::integer * 60
          + extract(
            minute from snapshot.starts_at at time zone v_household_timezone
          )::integer
      end as sort_minute
    from public.event_occurrences as occurrence
    cross join lateral app_private.calendar_occurrence_snapshot(
      occurrence.household_id,
      occurrence.id
    ) as snapshot
    where occurrence.household_id = p_household_id
      and occurrence.status = 'scheduled'
      and not snapshot.deleted
      and (
        snapshot.is_all_day
        and snapshot.local_start_date < v_range_end_date_exclusive
        and snapshot.all_day_end_date_exclusive > v_range_start_date
        or not snapshot.is_all_day
        and snapshot.starts_at < v_range_ends_at
        and snapshot.ends_at > v_range_starts_at
      )
  ),
  candidate as materialized (
    select base.*
    from base
    where p_after_cursor is null
      or (
        base.sort_date,
        base.sort_kind,
        base.sort_minute,
        base.occurrence_id
      ) > (
        v_cursor_date,
        v_cursor_kind,
        v_cursor_minute,
        v_cursor_occurrence_id
      )
  ),
  page_plus as materialized (
    select candidate.*
    from candidate
    order by
      candidate.sort_date,
      candidate.sort_kind,
      candidate.sort_minute,
      candidate.occurrence_id
    limit p_limit + 1
  ),
  ranked_page as materialized (
    select
      page_plus.*,
      pg_catalog.row_number() over (
        order by
          page_plus.sort_date,
          page_plus.sort_kind,
          page_plus.sort_minute,
          page_plus.occurrence_id
      ) as page_rank
    from page_plus
  ),
  metadata as (
    select
      pg_catalog.count(*) > p_limit as has_more,
      case
        when pg_catalog.count(*) > p_limit then (
          select pg_catalog.encode(
            pg_catalog.convert_to(
              pg_catalog.jsonb_build_object(
                'v', 2,
                'household', p_household_id,
                'view', v_view,
                'rangeStart', v_range_start_date,
                'rangeEndExclusive', v_range_end_date_exclusive,
                'date', cursor_item.sort_date,
                'kind', cursor_item.sort_kind,
                'minute', cursor_item.sort_minute,
                'id', cursor_item.occurrence_id
              )::text,
              'UTF8'
            ),
            'hex'
          )
          from ranked_page as cursor_item
          where cursor_item.page_rank = p_limit
        )
        else null
      end as page_cursor
    from ranked_page
  )
  select
    p_household_id,
    v_household_timezone,
    v_household_local_date,
    v_generated_at,
    v_view,
    v_range_start_date,
    v_range_end_date_exclusive,
    p_limit,
    metadata.has_more,
    metadata.page_cursor,
    item.sort_date,
    case
      when item.sort_kind = 0 then null
      else pg_catalog.make_time(
        item.sort_minute / 60,
        item.sort_minute % 60,
        0
      )
    end,
    item.series_id,
    item.occurrence_id,
    item.title,
    item.description,
    item.is_all_day,
    item.local_start_date,
    item.local_start_time,
    item.duration_minutes,
    item.all_day_end_date_exclusive,
    item.timezone,
    item.overlap_policy,
    item.starts_at,
    item.ends_at,
    item.dst_resolution,
    item.utc_offset_seconds,
    item.participant_member_ids,
    item.participant_display_names,
    item.series_version,
    item.occurrence_version,
    item.recurrence_rule,
    item.recurrence_local_start_date,
    item.revision_number,
    item.is_exception
  from metadata
  left join ranked_page as item
    on item.page_rank <= p_limit
  order by item.page_rank nulls first;
end;
$$;

create function public.get_calendar_month_summary_v2(
  p_household_id uuid,
  p_month_start_date date
)
returns table (
  household_id uuid,
  household_timezone text,
  household_local_date date,
  generated_at timestamptz,
  month_start_date date,
  month_end_date_exclusive date,
  day_date date,
  event_count integer,
  all_day_count integer,
  timed_count integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_generated_at timestamptz := pg_catalog.statement_timestamp();
  v_household_timezone text;
  v_household_local_date date;
  v_month_end_date_exclusive date;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFE01',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or p_month_start_date is null
    or pg_catalog.date_trunc(
      'month',
      p_month_start_date::timestamp without time zone
    )::date <> p_month_start_date then
    raise exception using
      errcode = 'KFE02',
      message = 'invalid calendar event input';
  end if;

  select household.timezone
  into v_household_timezone
  from public.households as household
  join public.household_members as caller
    on caller.household_id = household.id
   and caller.auth_user_id = v_authenticated_user_id
   and caller.removed_at is null
  where household.id = p_household_id
    and household.deleted_at is null;

  if not found then
    raise exception using
      errcode = 'KFE03',
      message = 'calendar event not found or forbidden';
  end if;

  v_household_local_date :=
    (v_generated_at at time zone v_household_timezone)::date;
  v_month_end_date_exclusive := (
    p_month_start_date::timestamp without time zone + interval '1 month'
  )::date;

  return query
  with month_days as materialized (
    select day_value::date as day_date
    from pg_catalog.generate_series(
      p_month_start_date::timestamp without time zone,
      (v_month_end_date_exclusive - 1)::timestamp without time zone,
      interval '1 day'
    ) as day_value
  )
  select
    p_household_id,
    v_household_timezone,
    v_household_local_date,
    v_generated_at,
    p_month_start_date,
    v_month_end_date_exclusive,
    month_day.day_date,
    pg_catalog.count(item.occurrence_id)::integer,
    pg_catalog.count(item.occurrence_id) filter (
      where item.is_all_day
    )::integer,
    pg_catalog.count(item.occurrence_id) filter (
      where not item.is_all_day
    )::integer
  from month_days as month_day
  left join lateral (
    select occurrence.id as occurrence_id, snapshot.is_all_day
    from public.event_occurrences as occurrence
    cross join lateral app_private.calendar_occurrence_snapshot(
      occurrence.household_id,
      occurrence.id
    ) as snapshot
    where occurrence.household_id = p_household_id
      and occurrence.status = 'scheduled'
      and not snapshot.deleted
      and (
        snapshot.is_all_day
        and snapshot.local_start_date < month_day.day_date + 1
        and snapshot.all_day_end_date_exclusive > month_day.day_date
        or not snapshot.is_all_day
        and snapshot.starts_at < (
          (month_day.day_date + 1)::timestamp without time zone
            at time zone v_household_timezone
        )
        and snapshot.ends_at > (
          month_day.day_date::timestamp without time zone
            at time zone v_household_timezone
        )
      )
  ) as item on true
  group by month_day.day_date
  order by month_day.day_date;
end;
$$;

revoke all on function public.get_calendar_event_page_v2(
  uuid,
  text,
  date,
  date,
  integer,
  text
) from public, anon, authenticated;
revoke all on function public.get_calendar_month_summary_v2(uuid, date)
  from public, anon, authenticated;

grant execute on function public.get_calendar_event_page_v2(
  uuid,
  text,
  date,
  date,
  integer,
  text
) to authenticated;
grant execute on function public.get_calendar_month_summary_v2(uuid, date)
  to authenticated;

comment on function public.create_recurring_calendar_event(
  uuid,
  uuid,
  text,
  text,
  boolean,
  date,
  time without time zone,
  integer,
  date,
  text,
  text,
  jsonb,
  uuid[]
) is 'WP04-04A authenticated idempotent recurring Calendar creation with server-resolved first-year occurrences.';

comment on function public.get_calendar_event_page_v2(
  uuid,
  text,
  date,
  date,
  integer,
  text
) is 'WP04-04A mixed one-time and recurring Calendar occurrence page with v2 query-bound cursor.';

comment on function public.get_calendar_month_summary_v2(uuid, date)
  is 'WP04-04A mixed one-time and recurring content-free month counts.';
