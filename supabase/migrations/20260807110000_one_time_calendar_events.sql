-- KinFlow WP04-02 one-time Calendar event vertical slice.
-- Timed instants are server-resolved; all-day values remain date-only.

create or replace function app_private.is_valid_calendar_dst_adjustment(
  p_adjustment jsonb
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select
    p_adjustment is not null
    and pg_catalog.jsonb_typeof(p_adjustment) = 'object'
    and (
      select pg_catalog.count(*)
      from pg_catalog.jsonb_object_keys(p_adjustment)
    ) = 5
    and p_adjustment ?& array[
      'candidateCount',
      'gapPolicy',
      'overlapPolicy',
      'resolution',
      'utcOffsetSeconds'
    ]
    and p_adjustment->>'gapPolicy' = 'reject'
    and p_adjustment->>'overlapPolicy' in ('earlier', 'later')
    and p_adjustment->>'resolution' in (
      'normal',
      'overlap_earlier',
      'overlap_later'
    )
    and p_adjustment->>'candidateCount' ~ '^[1-9][0-9]*$'
    and p_adjustment->>'utcOffsetSeconds' ~ '^-?[0-9]+$'
    and (p_adjustment->>'utcOffsetSeconds')::integer
      between -57600 and 57600
    and (
      (
        p_adjustment->>'resolution' = 'normal'
        and (p_adjustment->>'candidateCount')::integer = 1
      )
      or (
        p_adjustment->>'resolution' = 'overlap_earlier'
        and p_adjustment->>'overlapPolicy' = 'earlier'
        and (p_adjustment->>'candidateCount')::integer >= 2
      )
      or (
        p_adjustment->>'resolution' = 'overlap_later'
        and p_adjustment->>'overlapPolicy' = 'later'
        and (p_adjustment->>'candidateCount')::integer >= 2
      )
    )
$$;

revoke all on function app_private.is_valid_calendar_dst_adjustment(jsonb)
  from public, anon, authenticated, service_role;

create table public.event_series (
  id uuid primary key default extensions.gen_random_uuid(),
  household_id uuid not null
    references public.households(id) on delete cascade,
  title text not null check (pg_catalog.char_length(title) between 1 and 200),
  description text check (
    description is null or pg_catalog.char_length(description) <= 8000
  ),
  timezone text,
  is_all_day boolean not null,
  active_revision_id uuid not null,
  created_by_user_id uuid
    references auth.users(id) on delete set null,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  version bigint not null default 1 check (version > 0),
  deleted_at timestamptz,
  unique (household_id, id),
  constraint event_series_time_mode_ck check (
    (is_all_day and timezone is null)
    or (
      not is_all_day
      and app_private.is_valid_iana_timezone(timezone)
    )
  )
);

create table public.event_series_revisions (
  id uuid primary key default extensions.gen_random_uuid(),
  household_id uuid not null,
  series_id uuid not null,
  revision_number integer not null check (revision_number > 0),
  local_start_date date not null,
  local_start_time time without time zone,
  duration_minutes integer,
  all_day_end_date_exclusive date,
  gap_policy text,
  overlap_policy text,
  recurrence_rule jsonb check (
    recurrence_rule is null
    or pg_catalog.jsonb_typeof(recurrence_rule) = 'object'
  ),
  created_by_user_id uuid
    references auth.users(id) on delete set null,
  created_at timestamptz not null default pg_catalog.now(),
  unique (household_id, id),
  unique (series_id, revision_number),
  unique (household_id, series_id, id),
  constraint event_revision_series_fk
    foreign key (household_id, series_id)
    references public.event_series(household_id, id)
    on delete cascade,
  constraint event_revision_time_ck check (
    (
      local_start_time is null
      and duration_minutes is null
      and all_day_end_date_exclusive > local_start_date
      and gap_policy is null
      and overlap_policy is null
    )
    or (
      local_start_time is not null
      and extract(second from local_start_time) = 0
      and duration_minutes between 1 and 10080
      and all_day_end_date_exclusive is null
      and gap_policy = 'reject'
      and overlap_policy in ('earlier', 'later')
    )
  )
);

alter table public.event_series
  add constraint event_active_revision_fk
  foreign key (household_id, id, active_revision_id)
  references public.event_series_revisions(household_id, series_id, id)
  deferrable initially deferred;

create table public.event_participants (
  household_id uuid not null,
  series_id uuid not null,
  member_id uuid not null,
  created_at timestamptz not null default pg_catalog.now(),
  primary key (household_id, series_id, member_id),
  constraint event_participant_series_fk
    foreign key (household_id, series_id)
    references public.event_series(household_id, id)
    on delete cascade,
  constraint event_participant_member_fk
    foreign key (household_id, member_id)
    references public.household_members(household_id, id)
);

create table public.event_occurrences (
  id uuid primary key default extensions.gen_random_uuid(),
  household_id uuid not null,
  series_id uuid not null,
  revision_id uuid not null,
  occurrence_key text not null check (
    pg_catalog.char_length(occurrence_key) between 1 and 240
  ),
  local_start_date date not null,
  starts_at timestamptz,
  ends_at timestamptz,
  all_day_end_date_exclusive date,
  timezone text,
  status public.occurrence_status not null default 'scheduled',
  dst_adjustment jsonb,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  version bigint not null default 1 check (version > 0),
  unique (household_id, id),
  unique (household_id, occurrence_key),
  constraint event_occurrence_series_fk
    foreign key (household_id, series_id)
    references public.event_series(household_id, id)
    on delete cascade,
  constraint event_occurrence_revision_fk
    foreign key (household_id, series_id, revision_id)
    references public.event_series_revisions(household_id, series_id, id),
  constraint event_occurrence_time_ck check (
    (
      starts_at is null
      and ends_at is null
      and all_day_end_date_exclusive > local_start_date
      and timezone is null
      and dst_adjustment is null
    )
    or (
      starts_at is not null
      and ends_at > starts_at
      and all_day_end_date_exclusive is null
      and app_private.is_valid_iana_timezone(timezone)
      and app_private.is_valid_calendar_dst_adjustment(dst_adjustment)
    )
  )
);

create index event_occurrences_range_idx
  on public.event_occurrences(
    household_id,
    local_start_date,
    status,
    starts_at
  );

create index event_occurrences_instant_idx
  on public.event_occurrences(household_id, starts_at)
  where starts_at is not null;

create index event_participants_member_idx
  on public.event_participants(household_id, member_id, series_id);

create trigger event_series_set_updated_at_and_version
before update on public.event_series
for each row execute function app_private.set_updated_at_and_version();

create trigger event_occurrences_set_updated_at_and_version
before update on public.event_occurrences
for each row execute function app_private.set_updated_at_and_version();

create table app_private.calendar_command_requests (
  authenticated_user_id uuid not null
    references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  command_name text not null check (
    command_name in ('create_one_time', 'update_one_time', 'delete_one_time')
  ),
  request_hash bytea not null check (pg_catalog.octet_length(request_hash) = 32),
  household_id uuid not null
    references public.households(id) on delete cascade,
  series_id uuid not null,
  occurrence_id uuid not null,
  created_at timestamptz not null default pg_catalog.now(),
  primary key (authenticated_user_id, idempotency_key)
);

create table app_private.calendar_audit_events (
  id uuid primary key default extensions.gen_random_uuid(),
  household_id uuid not null
    references public.households(id) on delete cascade,
  action text not null check (
    action in ('calendar.created', 'calendar.updated', 'calendar.deleted')
  ),
  series_id uuid not null,
  occurrence_id uuid not null,
  actor_user_id uuid
    references auth.users(id) on delete set null,
  actor_member_id uuid not null,
  correlation_id uuid not null,
  series_version bigint not null check (series_version > 0),
  occurrence_version bigint not null check (occurrence_version > 0),
  occurred_at timestamptz not null default pg_catalog.now(),
  unique (household_id, action, correlation_id),
  constraint calendar_audit_actor_fk
    foreign key (household_id, actor_member_id)
    references public.household_members(household_id, id)
);

revoke all on table app_private.calendar_command_requests
  from public, anon, authenticated, service_role;
revoke all on table app_private.calendar_audit_events
  from public, anon, authenticated, service_role;

create or replace function app_private.reject_calendar_audit_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'calendar audit events are immutable';
end;
$$;

revoke all on function app_private.reject_calendar_audit_mutation()
  from public, anon, authenticated, service_role;

create trigger calendar_audit_events_immutable
before update or delete on app_private.calendar_audit_events
for each row execute function app_private.reject_calendar_audit_mutation();

alter table public.event_series enable row level security;
alter table public.event_series force row level security;
alter table public.event_series_revisions enable row level security;
alter table public.event_series_revisions force row level security;
alter table public.event_participants enable row level security;
alter table public.event_participants force row level security;
alter table public.event_occurrences enable row level security;
alter table public.event_occurrences force row level security;

create policy event_series_select_member
on public.event_series
for select
to authenticated
using (
  deleted_at is null
  and app_private.is_active_household_member(household_id)
);

create policy event_revisions_select_member
on public.event_series_revisions
for select
to authenticated
using (
  app_private.is_active_household_member(household_id)
  and exists (
    select 1
    from public.event_series as series
    where series.household_id = event_series_revisions.household_id
      and series.id = event_series_revisions.series_id
      and series.deleted_at is null
  )
);

create policy event_participants_select_member
on public.event_participants
for select
to authenticated
using (
  app_private.is_active_household_member(household_id)
  and exists (
    select 1
    from public.event_series as series
    where series.household_id = event_participants.household_id
      and series.id = event_participants.series_id
      and series.deleted_at is null
  )
);

create policy event_occurrences_select_member
on public.event_occurrences
for select
to authenticated
using (
  app_private.is_active_household_member(household_id)
  and exists (
    select 1
    from public.event_series as series
    where series.household_id = event_occurrences.household_id
      and series.id = event_occurrences.series_id
      and series.deleted_at is null
  )
);

revoke all on table public.event_series from anon, authenticated;
revoke all on table public.event_series_revisions from anon, authenticated;
revoke all on table public.event_participants from anon, authenticated;
revoke all on table public.event_occurrences from anon, authenticated;

grant select on table public.event_series to authenticated;
grant select on table public.event_series_revisions to authenticated;
grant select on table public.event_participants to authenticated;
grant select on table public.event_occurrences to authenticated;

create or replace function app_private.one_time_event_snapshot(
  p_household_id uuid,
  p_series_id uuid
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
    series.title,
    series.description,
    series.is_all_day,
    revision.local_start_date,
    revision.local_start_time,
    revision.duration_minutes,
    revision.all_day_end_date_exclusive,
    series.timezone,
    revision.overlap_policy,
    occurrence.starts_at,
    occurrence.ends_at,
    occurrence.dst_adjustment->>'resolution',
    (occurrence.dst_adjustment->>'utcOffsetSeconds')::integer,
    participant_snapshot.member_ids,
    participant_snapshot.display_names,
    series.version,
    occurrence.version,
    series.deleted_at is not null
  from public.event_series as series
  join public.households as household
    on household.id = series.household_id
   and household.deleted_at is null
  join public.event_series_revisions as revision
    on revision.household_id = series.household_id
   and revision.series_id = series.id
   and revision.id = series.active_revision_id
   and revision.recurrence_rule is null
  join public.event_occurrences as occurrence
    on occurrence.household_id = series.household_id
   and occurrence.series_id = series.id
   and occurrence.revision_id = revision.id
   and occurrence.occurrence_key = series.id::text || ':once'
  cross join lateral (
    select
      pg_catalog.array_agg(participant.member_id order by participant.member_id)
        as member_ids,
      pg_catalog.array_agg(member.display_name order by participant.member_id)
        as display_names
    from public.event_participants as participant
    join public.household_members as member
      on member.household_id = participant.household_id
     and member.id = participant.member_id
    where participant.household_id = series.household_id
      and participant.series_id = series.id
  ) as participant_snapshot
  where series.household_id = p_household_id
    and series.id = p_series_id
$$;

revoke all on function app_private.one_time_event_snapshot(uuid, uuid)
  from public, anon, authenticated, service_role;

create or replace function public.create_one_time_event(
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
  p_participant_member_ids uuid[]
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
  version bigint,
  occurrence_version bigint,
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
  v_participant_member_ids uuid[];
  v_participant_count integer;
  v_request_hash bytea;
  v_existing_command_name text;
  v_existing_request_hash bytea;
  v_series_id uuid;
  v_revision_id uuid;
  v_occurrence_id uuid;
  v_starts_at timestamptz;
  v_ends_at timestamptz;
  v_utc_offset_seconds integer;
  v_dst_resolution text;
  v_candidate_count integer;
  v_dst_adjustment jsonb;
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
    or pg_catalog.array_position(p_participant_member_ids, null) is not null
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
        or p_overlap_policy is null
        or p_overlap_policy not in ('earlier', 'later')
      )
    ) then
    raise exception using
      errcode = 'KFE02',
      message = 'invalid calendar event input';
  end if;

  select caller.id
  into v_actor_member_id
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

  select pg_catalog.array_agg(participant_id order by participant_id)
  into v_participant_member_ids
  from pg_catalog.unnest(p_participant_member_ids) as participant_id;

  v_request_hash := extensions.digest(
    pg_catalog.convert_to(
      pg_catalog.jsonb_build_object(
        'command', 'create_one_time',
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
        'participant_member_ids', v_participant_member_ids
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_authenticated_user_id::text
        || ':calendar-command:'
        || p_idempotency_key::text,
      0
    )
  );

  select
    request.command_name,
    request.request_hash,
    request.series_id,
    request.occurrence_id
  into
    v_existing_command_name,
    v_existing_request_hash,
    v_series_id,
    v_occurrence_id
  from app_private.calendar_command_requests as request
  where request.authenticated_user_id = v_authenticated_user_id
    and request.idempotency_key = p_idempotency_key;

  if found then
    if v_existing_command_name <> 'create_one_time'
      or v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFE04',
        message = 'idempotency key reused with different calendar input';
    end if;

    return query
    select
      snapshot.household_id,
      snapshot.household_timezone,
      snapshot.household_local_date,
      snapshot.series_id,
      snapshot.occurrence_id,
      snapshot.title,
      snapshot.description,
      snapshot.is_all_day,
      snapshot.local_start_date,
      snapshot.local_start_time,
      snapshot.duration_minutes,
      snapshot.all_day_end_date_exclusive,
      snapshot.timezone,
      snapshot.overlap_policy,
      snapshot.starts_at,
      snapshot.ends_at,
      snapshot.dst_resolution,
      snapshot.utc_offset_seconds,
      snapshot.participant_member_ids,
      snapshot.participant_display_names,
      snapshot.series_version,
      snapshot.occurrence_version,
      false
    from app_private.one_time_event_snapshot(
      p_household_id,
      v_series_id
    ) as snapshot
    where not snapshot.deleted;

    if not found then
      raise exception using
        errcode = 'KFE03',
        message = 'calendar event not found or forbidden';
    end if;
    return;
  end if;

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

  if not p_is_all_day then
    begin
      select
        resolved.resolved_at,
        resolved.utc_offset_seconds,
        resolved.resolution,
        resolved.candidate_count
      into
        v_starts_at,
        v_utc_offset_seconds,
        v_dst_resolution,
        v_candidate_count
      from app_private.resolve_calendar_zoned_datetime(
        p_local_start_date,
        p_local_start_time,
        p_timezone,
        p_overlap_policy
      ) as resolved;
    exception
      when sqlstate 'KFT01' then
        raise exception using
          errcode = 'KFE02',
          message = 'invalid calendar event input';
      when sqlstate 'KFT02' then
        raise exception using
          errcode = 'KFE06',
          message = 'nonexistent calendar local time';
    end;
    v_ends_at := v_starts_at
      + pg_catalog.make_interval(mins => p_duration_minutes);
    v_dst_adjustment := pg_catalog.jsonb_build_object(
      'candidateCount', v_candidate_count,
      'gapPolicy', 'reject',
      'overlapPolicy', p_overlap_policy,
      'resolution', v_dst_resolution,
      'utcOffsetSeconds', v_utc_offset_seconds
    );
  end if;

  v_series_id := extensions.gen_random_uuid();
  v_revision_id := extensions.gen_random_uuid();
  v_occurrence_id := extensions.gen_random_uuid();

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
    created_by_user_id
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
    null,
    v_authenticated_user_id
  );

  insert into public.event_occurrences (
    id,
    household_id,
    series_id,
    revision_id,
    occurrence_key,
    local_start_date,
    starts_at,
    ends_at,
    all_day_end_date_exclusive,
    timezone,
    dst_adjustment
  ) values (
    v_occurrence_id,
    p_household_id,
    v_series_id,
    v_revision_id,
    v_series_id::text || ':once',
    p_local_start_date,
    v_starts_at,
    v_ends_at,
    p_all_day_end_date_exclusive,
    p_timezone,
    v_dst_adjustment
  );

  insert into public.event_participants (
    household_id,
    series_id,
    member_id
  )
  select p_household_id, v_series_id, participant_id
  from pg_catalog.unnest(v_participant_member_ids) as participant_id;

  insert into app_private.calendar_command_requests (
    authenticated_user_id,
    idempotency_key,
    command_name,
    request_hash,
    household_id,
    series_id,
    occurrence_id
  ) values (
    v_authenticated_user_id,
    p_idempotency_key,
    'create_one_time',
    v_request_hash,
    p_household_id,
    v_series_id,
    v_occurrence_id
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
    v_occurrence_id,
    v_authenticated_user_id,
    v_actor_member_id,
    p_idempotency_key,
    1,
    1
  );

  return query
  select
    snapshot.household_id,
    snapshot.household_timezone,
    snapshot.household_local_date,
    snapshot.series_id,
    snapshot.occurrence_id,
    snapshot.title,
    snapshot.description,
    snapshot.is_all_day,
    snapshot.local_start_date,
    snapshot.local_start_time,
    snapshot.duration_minutes,
    snapshot.all_day_end_date_exclusive,
    snapshot.timezone,
    snapshot.overlap_policy,
    snapshot.starts_at,
    snapshot.ends_at,
    snapshot.dst_resolution,
    snapshot.utc_offset_seconds,
    snapshot.participant_member_ids,
    snapshot.participant_display_names,
    snapshot.series_version,
    snapshot.occurrence_version,
    true
  from app_private.one_time_event_snapshot(
    p_household_id,
    v_series_id
  ) as snapshot;
end;
$$;

create or replace function public.update_one_time_event(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_expected_version bigint,
  p_title text,
  p_description text,
  p_is_all_day boolean,
  p_local_start_date date,
  p_local_start_time time without time zone,
  p_duration_minutes integer,
  p_all_day_end_date_exclusive date,
  p_timezone text,
  p_overlap_policy text,
  p_participant_member_ids uuid[]
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
  version bigint,
  occurrence_version bigint,
  changed boolean
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
  v_participant_member_ids uuid[];
  v_participant_count integer;
  v_request_hash bytea;
  v_existing_command_name text;
  v_existing_request_hash bytea;
  v_existing_series_id uuid;
  v_occurrence_id uuid;
  v_current_series_version bigint;
  v_current_occurrence_version bigint;
  v_revision_number integer;
  v_revision_id uuid;
  v_starts_at timestamptz;
  v_ends_at timestamptz;
  v_utc_offset_seconds integer;
  v_dst_resolution text;
  v_candidate_count integer;
  v_dst_adjustment jsonb;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFE01',
      message = 'authentication required';
  end if;

  if p_idempotency_key is null
    or p_household_id is null
    or p_series_id is null
    or p_expected_version is null
    or p_expected_version < 1
    or p_is_all_day is null
    or p_local_start_date is null
    or p_participant_member_ids is null
    or pg_catalog.cardinality(p_participant_member_ids) not between 1 and 50
    or pg_catalog.array_position(p_participant_member_ids, null) is not null
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
        or p_overlap_policy is null
        or p_overlap_policy not in ('earlier', 'later')
      )
    ) then
    raise exception using
      errcode = 'KFE02',
      message = 'invalid calendar event input';
  end if;

  select caller.id
  into v_actor_member_id
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

  select pg_catalog.array_agg(participant_id order by participant_id)
  into v_participant_member_ids
  from pg_catalog.unnest(p_participant_member_ids) as participant_id;

  v_request_hash := extensions.digest(
    pg_catalog.convert_to(
      pg_catalog.jsonb_build_object(
        'command', 'update_one_time',
        'household_id', p_household_id,
        'series_id', p_series_id,
        'expected_version', p_expected_version,
        'title', v_title,
        'description', v_description,
        'is_all_day', p_is_all_day,
        'local_start_date', p_local_start_date,
        'local_start_time', p_local_start_time,
        'duration_minutes', p_duration_minutes,
        'all_day_end_date_exclusive', p_all_day_end_date_exclusive,
        'timezone', p_timezone,
        'overlap_policy', p_overlap_policy,
        'participant_member_ids', v_participant_member_ids
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_authenticated_user_id::text
        || ':calendar-command:'
        || p_idempotency_key::text,
      0
    )
  );

  select
    request.command_name,
    request.request_hash,
    request.series_id,
    request.occurrence_id
  into
    v_existing_command_name,
    v_existing_request_hash,
    v_existing_series_id,
    v_occurrence_id
  from app_private.calendar_command_requests as request
  where request.authenticated_user_id = v_authenticated_user_id
    and request.idempotency_key = p_idempotency_key;

  if found then
    if v_existing_command_name <> 'update_one_time'
      or v_existing_request_hash <> v_request_hash
      or v_existing_series_id <> p_series_id then
      raise exception using
        errcode = 'KFE04',
        message = 'idempotency key reused with different calendar input';
    end if;

    return query
    select
      snapshot.household_id,
      snapshot.household_timezone,
      snapshot.household_local_date,
      snapshot.series_id,
      snapshot.occurrence_id,
      snapshot.title,
      snapshot.description,
      snapshot.is_all_day,
      snapshot.local_start_date,
      snapshot.local_start_time,
      snapshot.duration_minutes,
      snapshot.all_day_end_date_exclusive,
      snapshot.timezone,
      snapshot.overlap_policy,
      snapshot.starts_at,
      snapshot.ends_at,
      snapshot.dst_resolution,
      snapshot.utc_offset_seconds,
      snapshot.participant_member_ids,
      snapshot.participant_display_names,
      snapshot.series_version,
      snapshot.occurrence_version,
      false
    from app_private.one_time_event_snapshot(
      p_household_id,
      p_series_id
    ) as snapshot
    where not snapshot.deleted;

    if not found then
      raise exception using
        errcode = 'KFE03',
        message = 'calendar event not found or forbidden';
    end if;
    return;
  end if;

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

  select
    series.version,
    occurrence.id,
    occurrence.version
  into
    v_current_series_version,
    v_occurrence_id,
    v_current_occurrence_version
  from public.event_series as series
  join public.event_series_revisions as revision
    on revision.household_id = series.household_id
   and revision.series_id = series.id
   and revision.id = series.active_revision_id
   and revision.recurrence_rule is null
  join public.event_occurrences as occurrence
    on occurrence.household_id = series.household_id
   and occurrence.series_id = series.id
   and occurrence.occurrence_key = series.id::text || ':once'
   and occurrence.status = 'scheduled'
  where series.household_id = p_household_id
    and series.id = p_series_id
    and series.deleted_at is null
  for update of series, occurrence;

  if not found then
    raise exception using
      errcode = 'KFE03',
      message = 'calendar event not found or forbidden';
  end if;

  if v_current_series_version <> p_expected_version then
    raise exception using
      errcode = 'KFE05',
      message = 'stale calendar event version';
  end if;

  if not p_is_all_day then
    begin
      select
        resolved.resolved_at,
        resolved.utc_offset_seconds,
        resolved.resolution,
        resolved.candidate_count
      into
        v_starts_at,
        v_utc_offset_seconds,
        v_dst_resolution,
        v_candidate_count
      from app_private.resolve_calendar_zoned_datetime(
        p_local_start_date,
        p_local_start_time,
        p_timezone,
        p_overlap_policy
      ) as resolved;
    exception
      when sqlstate 'KFT01' then
        raise exception using
          errcode = 'KFE02',
          message = 'invalid calendar event input';
      when sqlstate 'KFT02' then
        raise exception using
          errcode = 'KFE06',
          message = 'nonexistent calendar local time';
    end;
    v_ends_at := v_starts_at
      + pg_catalog.make_interval(mins => p_duration_minutes);
    v_dst_adjustment := pg_catalog.jsonb_build_object(
      'candidateCount', v_candidate_count,
      'gapPolicy', 'reject',
      'overlapPolicy', p_overlap_policy,
      'resolution', v_dst_resolution,
      'utcOffsetSeconds', v_utc_offset_seconds
    );
  end if;

  select pg_catalog.max(revision.revision_number) + 1
  into v_revision_number
  from public.event_series_revisions as revision
  where revision.series_id = p_series_id;
  v_revision_id := extensions.gen_random_uuid();

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
    created_by_user_id
  ) values (
    v_revision_id,
    p_household_id,
    p_series_id,
    v_revision_number,
    p_local_start_date,
    p_local_start_time,
    p_duration_minutes,
    p_all_day_end_date_exclusive,
    case when p_is_all_day then null else 'reject' end,
    p_overlap_policy,
    null,
    v_authenticated_user_id
  );

  update public.event_series as series
  set
    title = v_title,
    description = v_description,
    timezone = p_timezone,
    is_all_day = p_is_all_day,
    active_revision_id = v_revision_id
  where series.household_id = p_household_id
    and series.id = p_series_id;

  update public.event_occurrences as occurrence
  set
    revision_id = v_revision_id,
    local_start_date = p_local_start_date,
    starts_at = v_starts_at,
    ends_at = v_ends_at,
    all_day_end_date_exclusive = p_all_day_end_date_exclusive,
    timezone = p_timezone,
    dst_adjustment = v_dst_adjustment
  where occurrence.household_id = p_household_id
    and occurrence.id = v_occurrence_id;

  delete from public.event_participants as participant
  where participant.household_id = p_household_id
    and participant.series_id = p_series_id;

  insert into public.event_participants (
    household_id,
    series_id,
    member_id
  )
  select p_household_id, p_series_id, participant_id
  from pg_catalog.unnest(v_participant_member_ids) as participant_id;

  insert into app_private.calendar_command_requests (
    authenticated_user_id,
    idempotency_key,
    command_name,
    request_hash,
    household_id,
    series_id,
    occurrence_id
  ) values (
    v_authenticated_user_id,
    p_idempotency_key,
    'update_one_time',
    v_request_hash,
    p_household_id,
    p_series_id,
    v_occurrence_id
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
    'calendar.updated',
    p_series_id,
    v_occurrence_id,
    v_authenticated_user_id,
    v_actor_member_id,
    p_idempotency_key,
    v_current_series_version + 1,
    v_current_occurrence_version + 1
  );

  return query
  select
    snapshot.household_id,
    snapshot.household_timezone,
    snapshot.household_local_date,
    snapshot.series_id,
    snapshot.occurrence_id,
    snapshot.title,
    snapshot.description,
    snapshot.is_all_day,
    snapshot.local_start_date,
    snapshot.local_start_time,
    snapshot.duration_minutes,
    snapshot.all_day_end_date_exclusive,
    snapshot.timezone,
    snapshot.overlap_policy,
    snapshot.starts_at,
    snapshot.ends_at,
    snapshot.dst_resolution,
    snapshot.utc_offset_seconds,
    snapshot.participant_member_ids,
    snapshot.participant_display_names,
    snapshot.series_version,
    snapshot.occurrence_version,
    true
  from app_private.one_time_event_snapshot(
    p_household_id,
    p_series_id
  ) as snapshot;
end;
$$;

create or replace function public.delete_one_time_event(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_expected_version bigint
)
returns table (
  household_id uuid,
  series_id uuid,
  occurrence_id uuid,
  version bigint,
  occurrence_version bigint,
  deleted boolean,
  changed boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_actor_member_id uuid;
  v_request_hash bytea;
  v_existing_command_name text;
  v_existing_request_hash bytea;
  v_existing_series_id uuid;
  v_occurrence_id uuid;
  v_current_series_version bigint;
  v_current_occurrence_version bigint;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFE01',
      message = 'authentication required';
  end if;

  if p_idempotency_key is null
    or p_household_id is null
    or p_series_id is null
    or p_expected_version is null
    or p_expected_version < 1 then
    raise exception using
      errcode = 'KFE02',
      message = 'invalid calendar event input';
  end if;

  select caller.id
  into v_actor_member_id
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

  v_request_hash := extensions.digest(
    pg_catalog.convert_to(
      pg_catalog.jsonb_build_object(
        'command', 'delete_one_time',
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
        || ':calendar-command:'
        || p_idempotency_key::text,
      0
    )
  );

  select
    request.command_name,
    request.request_hash,
    request.series_id,
    request.occurrence_id
  into
    v_existing_command_name,
    v_existing_request_hash,
    v_existing_series_id,
    v_occurrence_id
  from app_private.calendar_command_requests as request
  where request.authenticated_user_id = v_authenticated_user_id
    and request.idempotency_key = p_idempotency_key;

  if found then
    if v_existing_command_name <> 'delete_one_time'
      or v_existing_request_hash <> v_request_hash
      or v_existing_series_id <> p_series_id then
      raise exception using
        errcode = 'KFE04',
        message = 'idempotency key reused with different calendar input';
    end if;

    return query
    select
      p_household_id,
      p_series_id,
      v_occurrence_id,
      series.version,
      occurrence.version,
      series.deleted_at is not null,
      false
    from public.event_series as series
    join public.event_occurrences as occurrence
      on occurrence.household_id = series.household_id
     and occurrence.id = v_occurrence_id
    where series.household_id = p_household_id
      and series.id = p_series_id;
    return;
  end if;

  select
    series.version,
    occurrence.id,
    occurrence.version
  into
    v_current_series_version,
    v_occurrence_id,
    v_current_occurrence_version
  from public.event_series as series
  join public.event_series_revisions as revision
    on revision.household_id = series.household_id
   and revision.series_id = series.id
   and revision.id = series.active_revision_id
   and revision.recurrence_rule is null
  join public.event_occurrences as occurrence
    on occurrence.household_id = series.household_id
   and occurrence.series_id = series.id
   and occurrence.occurrence_key = series.id::text || ':once'
   and occurrence.status = 'scheduled'
  where series.household_id = p_household_id
    and series.id = p_series_id
    and series.deleted_at is null
  for update of series, occurrence;

  if not found then
    raise exception using
      errcode = 'KFE03',
      message = 'calendar event not found or forbidden';
  end if;

  if v_current_series_version <> p_expected_version then
    raise exception using
      errcode = 'KFE05',
      message = 'stale calendar event version';
  end if;

  update public.event_series as series
  set deleted_at = pg_catalog.statement_timestamp()
  where series.household_id = p_household_id
    and series.id = p_series_id;

  update public.event_occurrences as occurrence
  set status = 'cancelled'
  where occurrence.household_id = p_household_id
    and occurrence.id = v_occurrence_id;

  insert into app_private.calendar_command_requests (
    authenticated_user_id,
    idempotency_key,
    command_name,
    request_hash,
    household_id,
    series_id,
    occurrence_id
  ) values (
    v_authenticated_user_id,
    p_idempotency_key,
    'delete_one_time',
    v_request_hash,
    p_household_id,
    p_series_id,
    v_occurrence_id
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
    'calendar.deleted',
    p_series_id,
    v_occurrence_id,
    v_authenticated_user_id,
    v_actor_member_id,
    p_idempotency_key,
    v_current_series_version + 1,
    v_current_occurrence_version + 1
  );

  return query select
    p_household_id,
    p_series_id,
    v_occurrence_id,
    v_current_series_version + 1,
    v_current_occurrence_version + 1,
    true,
    true;
end;
$$;

create or replace function public.list_one_time_events(
  p_household_id uuid,
  p_limit integer
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
  version bigint,
  occurrence_version bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_household_timezone text;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFE01',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or p_limit is null
    or p_limit not between 1 and 100 then
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

  return query
  select
    p_household_id,
    v_household_timezone,
    (pg_catalog.statement_timestamp() at time zone v_household_timezone)::date,
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
    item.occurrence_version
  from (select true) as envelope
  left join lateral (
    select snapshot.*
    from public.event_series as series
    cross join lateral app_private.one_time_event_snapshot(
      series.household_id,
      series.id
    ) as snapshot
    where series.household_id = p_household_id
      and series.deleted_at is null
      and not snapshot.deleted
    order by
      snapshot.local_start_date,
      snapshot.local_start_time nulls first,
      pg_catalog.lower(snapshot.title),
      snapshot.series_id
    limit p_limit
  ) as item on true
  order by
    item.local_start_date nulls last,
    item.local_start_time nulls first,
    pg_catalog.lower(item.title) nulls last,
    item.series_id;
end;
$$;

revoke all on function public.create_one_time_event(
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
  uuid[]
) from public, anon, authenticated;

revoke all on function public.update_one_time_event(
  uuid,
  uuid,
  uuid,
  bigint,
  text,
  text,
  boolean,
  date,
  time without time zone,
  integer,
  date,
  text,
  text,
  uuid[]
) from public, anon, authenticated;

revoke all on function public.delete_one_time_event(uuid, uuid, uuid, bigint)
  from public, anon, authenticated;
revoke all on function public.list_one_time_events(uuid, integer)
  from public, anon, authenticated;

grant execute on function public.create_one_time_event(
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
  uuid[]
) to authenticated;

grant execute on function public.update_one_time_event(
  uuid,
  uuid,
  uuid,
  bigint,
  text,
  text,
  boolean,
  date,
  time without time zone,
  integer,
  date,
  text,
  text,
  uuid[]
) to authenticated;

grant execute on function public.delete_one_time_event(
  uuid,
  uuid,
  uuid,
  bigint
) to authenticated;

grant execute on function public.list_one_time_events(uuid, integer)
  to authenticated;
