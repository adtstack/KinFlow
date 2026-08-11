-- KinFlow WP04-04B single recurring occurrence edit/cancel exceptions.
-- Source series intent and immutable recurrence slot identity remain unchanged.

alter table public.event_occurrences
  add constraint event_occurrence_household_series_id_uq
  unique (household_id, series_id, id);

create table public.event_occurrence_exceptions (
  id uuid primary key default extensions.gen_random_uuid(),
  household_id uuid not null,
  series_id uuid not null,
  occurrence_id uuid not null,
  override_payload jsonb not null default '{}'::jsonb
    check (override_payload = '{}'::jsonb),
  exception_revision_id uuid,
  cancelled boolean not null default false,
  created_by_user_id uuid
    references auth.users(id) on delete set null,
  updated_by_user_id uuid
    references auth.users(id) on delete set null,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  version bigint not null default 1 check (version > 0),
  unique (household_id, id),
  unique (household_id, occurrence_id),
  constraint event_occurrence_exception_occurrence_fk
    foreign key (household_id, series_id, occurrence_id)
    references public.event_occurrences(household_id, series_id, id)
    on delete cascade,
  constraint event_occurrence_exception_revision_fk
    foreign key (household_id, series_id, exception_revision_id)
    references public.event_series_revisions(household_id, series_id, id),
  constraint event_occurrence_exception_meaningful_ck check (
    cancelled or exception_revision_id is not null
  )
);

create index event_occurrence_exceptions_revision_idx
  on public.event_occurrence_exceptions(
    household_id,
    series_id,
    exception_revision_id
  )
  where exception_revision_id is not null;

create or replace function app_private.reject_event_exception_identity_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id is distinct from old.id
    or new.household_id is distinct from old.household_id
    or new.series_id is distinct from old.series_id
    or new.occurrence_id is distinct from old.occurrence_id
    or new.override_payload is distinct from old.override_payload then
    raise exception using
      errcode = '55000',
      message = 'calendar occurrence exception identity is immutable';
  end if;
  return new;
end;
$$;

revoke all on function app_private.reject_event_exception_identity_change()
  from public, anon, authenticated, service_role;

create trigger event_occurrence_exception_identity_immutable
before update on public.event_occurrence_exceptions
for each row execute function
  app_private.reject_event_exception_identity_change();

create trigger event_occurrence_exceptions_set_updated_at_and_version
before update on public.event_occurrence_exceptions
for each row execute function app_private.set_updated_at_and_version();

alter table public.event_occurrence_exceptions enable row level security;
alter table public.event_occurrence_exceptions force row level security;

create policy event_occurrence_exceptions_select_member
on public.event_occurrence_exceptions
for select
to authenticated
using (
  app_private.is_active_household_member(household_id)
  and exists (
    select 1
    from public.event_series as series
    where series.household_id = event_occurrence_exceptions.household_id
      and series.id = event_occurrence_exceptions.series_id
      and series.deleted_at is null
  )
);

revoke all on table public.event_occurrence_exceptions
  from anon, authenticated;
grant select on table public.event_occurrence_exceptions to authenticated;

create table app_private.calendar_occurrence_exception_command_requests (
  authenticated_user_id uuid not null
    references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  command_name text not null check (
    command_name in ('update_occurrence', 'cancel_occurrence')
  ),
  request_hash bytea not null check (pg_catalog.octet_length(request_hash) = 32),
  household_id uuid not null,
  series_id uuid not null,
  occurrence_id uuid not null,
  exception_id uuid not null,
  result_revision_id uuid,
  result_occurrence_version bigint not null check (
    result_occurrence_version > 0
  ),
  result_exception_version bigint not null check (
    result_exception_version > 0
  ),
  result_cancelled boolean not null,
  created_at timestamptz not null default pg_catalog.now(),
  primary key (authenticated_user_id, idempotency_key),
  constraint calendar_occurrence_exception_command_occurrence_fk
    foreign key (household_id, series_id, occurrence_id)
    references public.event_occurrences(household_id, series_id, id)
    on delete cascade,
  constraint calendar_occurrence_exception_command_exception_fk
    foreign key (household_id, exception_id)
    references public.event_occurrence_exceptions(household_id, id)
    on delete cascade,
  constraint calendar_occurrence_exception_command_revision_fk
    foreign key (household_id, series_id, result_revision_id)
    references public.event_series_revisions(household_id, series_id, id),
  constraint calendar_occurrence_exception_command_result_ck check (
    (
      command_name = 'update_occurrence'
      and result_revision_id is not null
      and not result_cancelled
    )
    or (
      command_name = 'cancel_occurrence'
      and result_cancelled
    )
  )
);

revoke all on table
  app_private.calendar_occurrence_exception_command_requests
  from public, anon, authenticated, service_role;

alter table app_private.calendar_audit_events
  drop constraint calendar_audit_events_action_check;

alter table app_private.calendar_audit_events
  add constraint calendar_audit_events_action_check check (
    action in (
      'calendar.created',
      'calendar.updated',
      'calendar.deleted',
      'calendar.occurrence_updated',
      'calendar.occurrence_cancelled'
    )
  );

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
    exception.id is not null,
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
  left join public.event_occurrence_exceptions as exception
    on exception.household_id = occurrence.household_id
   and exception.series_id = occurrence.series_id
   and exception.occurrence_id = occurrence.id
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

create or replace function public.update_recurring_calendar_occurrence(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_occurrence_id uuid,
  p_expected_occurrence_version bigint,
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
  series_id uuid,
  occurrence_id uuid,
  revision_id uuid,
  occurrence_version bigint,
  exception_version bigint,
  cancelled boolean,
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
  v_existing_household_id uuid;
  v_existing_series_id uuid;
  v_existing_occurrence_id uuid;
  v_existing_result_revision_id uuid;
  v_existing_result_occurrence_version bigint;
  v_existing_result_exception_version bigint;
  v_existing_result_cancelled boolean;
  v_series_version bigint;
  v_active_recurrence_rule jsonb;
  v_current_occurrence_version bigint;
  v_current_occurrence_status public.occurrence_status;
  v_exception_id uuid;
  v_exception_cancelled boolean;
  v_revision_number integer;
  v_revision_id uuid;
  v_starts_at timestamptz;
  v_ends_at timestamptz;
  v_utc_offset_seconds integer;
  v_dst_resolution text;
  v_candidate_count integer;
  v_dst_adjustment jsonb;
  v_result_occurrence_version bigint;
  v_result_exception_version bigint;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFE01',
      message = 'authentication required';
  end if;

  if p_idempotency_key is null
    or p_household_id is null
    or p_series_id is null
    or p_occurrence_id is null
    or p_expected_occurrence_version is null
    or p_expected_occurrence_version < 1
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
        or not app_private.is_valid_iana_timezone(p_timezone)
        or p_overlap_policy not in ('earlier', 'later')
      )
    ) then
    raise exception using
      errcode = 'KFE02',
      message = 'invalid calendar occurrence input';
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
      message = 'calendar occurrence not found or forbidden';
  end if;

  select pg_catalog.array_agg(participant_id order by participant_id)
  into v_participant_member_ids
  from pg_catalog.unnest(p_participant_member_ids) as participant_id;

  v_request_hash := extensions.digest(
    pg_catalog.convert_to(
      pg_catalog.jsonb_build_object(
        'command', 'update_occurrence',
        'household_id', p_household_id,
        'series_id', p_series_id,
        'occurrence_id', p_occurrence_id,
        'expected_occurrence_version', p_expected_occurrence_version,
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
        || ':calendar-occurrence-command:'
        || p_idempotency_key::text,
      0
    )
  );

  select
    request.command_name,
    request.request_hash,
    request.household_id,
    request.series_id,
    request.occurrence_id,
    request.result_revision_id,
    request.result_occurrence_version,
    request.result_exception_version,
    request.result_cancelled
  into
    v_existing_command_name,
    v_existing_request_hash,
    v_existing_household_id,
    v_existing_series_id,
    v_existing_occurrence_id,
    v_existing_result_revision_id,
    v_existing_result_occurrence_version,
    v_existing_result_exception_version,
    v_existing_result_cancelled
  from app_private.calendar_occurrence_exception_command_requests as request
  where request.authenticated_user_id = v_authenticated_user_id
    and request.idempotency_key = p_idempotency_key;

  if found then
    if v_existing_command_name <> 'update_occurrence'
      or v_existing_request_hash <> v_request_hash
      or v_existing_household_id <> p_household_id
      or v_existing_series_id <> p_series_id
      or v_existing_occurrence_id <> p_occurrence_id then
      raise exception using
        errcode = 'KFE04',
        message = 'idempotency key reused with different calendar input';
    end if;

    return query select
      v_existing_household_id,
      v_existing_series_id,
      v_existing_occurrence_id,
      v_existing_result_revision_id,
      v_existing_result_occurrence_version,
      v_existing_result_exception_version,
      v_existing_result_cancelled,
      false;
    return;
  end if;

  if exists (
      select 1
      from app_private.calendar_command_requests as request
      where request.authenticated_user_id = v_authenticated_user_id
        and request.idempotency_key = p_idempotency_key
    )
    or exists (
      select 1
      from app_private.calendar_recurring_command_requests as request
      where request.authenticated_user_id = v_authenticated_user_id
        and request.idempotency_key = p_idempotency_key
    ) then
    raise exception using
      errcode = 'KFE04',
      message = 'idempotency key reused with different calendar input';
  end if;

  select pg_catalog.count(*)::integer
  into v_participant_count
  from public.household_members as participant
  where participant.household_id = p_household_id
    and participant.id = any(v_participant_member_ids)
    and participant.removed_at is null;

  if v_participant_count <> pg_catalog.cardinality(
    v_participant_member_ids
  ) then
    raise exception using
      errcode = 'KFE03',
      message = 'calendar occurrence not found or forbidden';
  end if;

  select
    series.version,
    active_revision.recurrence_rule,
    occurrence.version,
    occurrence.status,
    exception.id,
    exception.cancelled
  into
    v_series_version,
    v_active_recurrence_rule,
    v_current_occurrence_version,
    v_current_occurrence_status,
    v_exception_id,
    v_exception_cancelled
  from public.event_series as series
  join public.event_series_revisions as active_revision
    on active_revision.household_id = series.household_id
   and active_revision.series_id = series.id
   and active_revision.id = series.active_revision_id
  join public.event_occurrences as occurrence
    on occurrence.household_id = series.household_id
   and occurrence.series_id = series.id
   and occurrence.id = p_occurrence_id
  left join public.event_occurrence_exceptions as exception
    on exception.household_id = occurrence.household_id
   and exception.series_id = occurrence.series_id
   and exception.occurrence_id = occurrence.id
  where series.household_id = p_household_id
    and series.id = p_series_id
    and series.deleted_at is null
  for update of series, occurrence;

  if not found then
    raise exception using
      errcode = 'KFE03',
      message = 'calendar occurrence not found or forbidden';
  end if;

  if v_active_recurrence_rule is null
    or v_current_occurrence_status <> 'scheduled'
    or coalesce(v_exception_cancelled, false) then
    raise exception using
      errcode = 'KFE08',
      message = 'calendar occurrence transition not allowed';
  end if;

  if v_current_occurrence_version <> p_expected_occurrence_version then
    raise exception using
      errcode = 'KFE05',
      message = 'stale calendar occurrence version';
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
          message = 'invalid calendar occurrence input';
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

  select coalesce(pg_catalog.max(revision.revision_number), 0) + 1
  into v_revision_number
  from public.event_series_revisions as revision
  where revision.household_id = p_household_id
    and revision.series_id = p_series_id;

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
    created_by_user_id,
    snapshot_title,
    snapshot_description,
    snapshot_timezone,
    snapshot_is_all_day
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
    v_active_recurrence_rule,
    v_authenticated_user_id,
    v_title,
    v_description,
    p_timezone,
    p_is_all_day
  );

  insert into public.event_revision_participants (
    household_id,
    series_id,
    revision_id,
    member_id
  )
  select
    p_household_id,
    p_series_id,
    v_revision_id,
    participant_id
  from pg_catalog.unnest(v_participant_member_ids) as participant_id;

  if v_exception_id is null then
    v_exception_id := extensions.gen_random_uuid();
    insert into public.event_occurrence_exceptions (
      id,
      household_id,
      series_id,
      occurrence_id,
      exception_revision_id,
      cancelled,
      created_by_user_id,
      updated_by_user_id
    ) values (
      v_exception_id,
      p_household_id,
      p_series_id,
      p_occurrence_id,
      v_revision_id,
      false,
      v_authenticated_user_id,
      v_authenticated_user_id
    )
    returning version into v_result_exception_version;
  else
    update public.event_occurrence_exceptions as exception
    set
      exception_revision_id = v_revision_id,
      cancelled = false,
      updated_by_user_id = v_authenticated_user_id
    where exception.household_id = p_household_id
      and exception.id = v_exception_id
    returning exception.version into v_result_exception_version;
  end if;

  update public.event_occurrences as occurrence
  set
    revision_id = v_revision_id,
    local_start_date = p_local_start_date,
    starts_at = v_starts_at,
    ends_at = v_ends_at,
    all_day_end_date_exclusive = p_all_day_end_date_exclusive,
    timezone = p_timezone,
    status = 'scheduled',
    dst_adjustment = v_dst_adjustment
  where occurrence.household_id = p_household_id
    and occurrence.series_id = p_series_id
    and occurrence.id = p_occurrence_id
  returning occurrence.version into v_result_occurrence_version;

  insert into
    app_private.calendar_occurrence_exception_command_requests (
      authenticated_user_id,
      idempotency_key,
      command_name,
      request_hash,
      household_id,
      series_id,
      occurrence_id,
      exception_id,
      result_revision_id,
      result_occurrence_version,
      result_exception_version,
      result_cancelled
    ) values (
      v_authenticated_user_id,
      p_idempotency_key,
      'update_occurrence',
      v_request_hash,
      p_household_id,
      p_series_id,
      p_occurrence_id,
      v_exception_id,
      v_revision_id,
      v_result_occurrence_version,
      v_result_exception_version,
      false
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
    'calendar.occurrence_updated',
    p_series_id,
    p_occurrence_id,
    v_authenticated_user_id,
    v_actor_member_id,
    p_idempotency_key,
    v_series_version,
    v_result_occurrence_version
  );

  return query select
    p_household_id,
    p_series_id,
    p_occurrence_id,
    v_revision_id,
    v_result_occurrence_version,
    v_result_exception_version,
    false,
    true;
end;
$$;

revoke all on function public.update_recurring_calendar_occurrence(
  uuid,
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
) from public, anon, authenticated, service_role;

grant execute on function public.update_recurring_calendar_occurrence(
  uuid,
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

create or replace function public.cancel_recurring_calendar_occurrence(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_occurrence_id uuid,
  p_expected_occurrence_version bigint
)
returns table (
  household_id uuid,
  series_id uuid,
  occurrence_id uuid,
  revision_id uuid,
  occurrence_version bigint,
  exception_version bigint,
  cancelled boolean,
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
  v_existing_household_id uuid;
  v_existing_series_id uuid;
  v_existing_occurrence_id uuid;
  v_existing_result_revision_id uuid;
  v_existing_result_occurrence_version bigint;
  v_existing_result_exception_version bigint;
  v_existing_result_cancelled boolean;
  v_series_version bigint;
  v_active_recurrence_rule jsonb;
  v_current_occurrence_version bigint;
  v_current_occurrence_status public.occurrence_status;
  v_exception_id uuid;
  v_exception_revision_id uuid;
  v_exception_cancelled boolean;
  v_result_occurrence_version bigint;
  v_result_exception_version bigint;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFE01',
      message = 'authentication required';
  end if;

  if p_idempotency_key is null
    or p_household_id is null
    or p_series_id is null
    or p_occurrence_id is null
    or p_expected_occurrence_version is null
    or p_expected_occurrence_version < 1 then
    raise exception using
      errcode = 'KFE02',
      message = 'invalid calendar occurrence input';
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
      message = 'calendar occurrence not found or forbidden';
  end if;

  v_request_hash := extensions.digest(
    pg_catalog.convert_to(
      pg_catalog.jsonb_build_object(
        'command', 'cancel_occurrence',
        'household_id', p_household_id,
        'series_id', p_series_id,
        'occurrence_id', p_occurrence_id,
        'expected_occurrence_version', p_expected_occurrence_version
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_authenticated_user_id::text
        || ':calendar-occurrence-command:'
        || p_idempotency_key::text,
      0
    )
  );

  select
    request.command_name,
    request.request_hash,
    request.household_id,
    request.series_id,
    request.occurrence_id,
    request.result_revision_id,
    request.result_occurrence_version,
    request.result_exception_version,
    request.result_cancelled
  into
    v_existing_command_name,
    v_existing_request_hash,
    v_existing_household_id,
    v_existing_series_id,
    v_existing_occurrence_id,
    v_existing_result_revision_id,
    v_existing_result_occurrence_version,
    v_existing_result_exception_version,
    v_existing_result_cancelled
  from app_private.calendar_occurrence_exception_command_requests as request
  where request.authenticated_user_id = v_authenticated_user_id
    and request.idempotency_key = p_idempotency_key;

  if found then
    if v_existing_command_name <> 'cancel_occurrence'
      or v_existing_request_hash <> v_request_hash
      or v_existing_household_id <> p_household_id
      or v_existing_series_id <> p_series_id
      or v_existing_occurrence_id <> p_occurrence_id then
      raise exception using
        errcode = 'KFE04',
        message = 'idempotency key reused with different calendar input';
    end if;

    return query select
      v_existing_household_id,
      v_existing_series_id,
      v_existing_occurrence_id,
      v_existing_result_revision_id,
      v_existing_result_occurrence_version,
      v_existing_result_exception_version,
      v_existing_result_cancelled,
      false;
    return;
  end if;

  if exists (
      select 1
      from app_private.calendar_command_requests as request
      where request.authenticated_user_id = v_authenticated_user_id
        and request.idempotency_key = p_idempotency_key
    )
    or exists (
      select 1
      from app_private.calendar_recurring_command_requests as request
      where request.authenticated_user_id = v_authenticated_user_id
        and request.idempotency_key = p_idempotency_key
    ) then
    raise exception using
      errcode = 'KFE04',
      message = 'idempotency key reused with different calendar input';
  end if;

  select
    series.version,
    active_revision.recurrence_rule,
    occurrence.version,
    occurrence.status,
    exception.id,
    exception.exception_revision_id,
    exception.cancelled
  into
    v_series_version,
    v_active_recurrence_rule,
    v_current_occurrence_version,
    v_current_occurrence_status,
    v_exception_id,
    v_exception_revision_id,
    v_exception_cancelled
  from public.event_series as series
  join public.event_series_revisions as active_revision
    on active_revision.household_id = series.household_id
   and active_revision.series_id = series.id
   and active_revision.id = series.active_revision_id
  join public.event_occurrences as occurrence
    on occurrence.household_id = series.household_id
   and occurrence.series_id = series.id
   and occurrence.id = p_occurrence_id
  left join public.event_occurrence_exceptions as exception
    on exception.household_id = occurrence.household_id
   and exception.series_id = occurrence.series_id
   and exception.occurrence_id = occurrence.id
  where series.household_id = p_household_id
    and series.id = p_series_id
    and series.deleted_at is null
  for update of series, occurrence;

  if not found then
    raise exception using
      errcode = 'KFE03',
      message = 'calendar occurrence not found or forbidden';
  end if;

  if v_active_recurrence_rule is null
    or v_current_occurrence_status <> 'scheduled'
    or coalesce(v_exception_cancelled, false) then
    raise exception using
      errcode = 'KFE08',
      message = 'calendar occurrence transition not allowed';
  end if;

  if v_current_occurrence_version <> p_expected_occurrence_version then
    raise exception using
      errcode = 'KFE05',
      message = 'stale calendar occurrence version';
  end if;

  if v_exception_id is null then
    v_exception_id := extensions.gen_random_uuid();
    insert into public.event_occurrence_exceptions (
      id,
      household_id,
      series_id,
      occurrence_id,
      exception_revision_id,
      cancelled,
      created_by_user_id,
      updated_by_user_id
    ) values (
      v_exception_id,
      p_household_id,
      p_series_id,
      p_occurrence_id,
      null,
      true,
      v_authenticated_user_id,
      v_authenticated_user_id
    )
    returning version into v_result_exception_version;
  else
    update public.event_occurrence_exceptions as exception
    set
      cancelled = true,
      updated_by_user_id = v_authenticated_user_id
    where exception.household_id = p_household_id
      and exception.id = v_exception_id
    returning exception.version into v_result_exception_version;
  end if;

  update public.event_occurrences as occurrence
  set status = 'cancelled'
  where occurrence.household_id = p_household_id
    and occurrence.series_id = p_series_id
    and occurrence.id = p_occurrence_id
  returning occurrence.version into v_result_occurrence_version;

  insert into
    app_private.calendar_occurrence_exception_command_requests (
      authenticated_user_id,
      idempotency_key,
      command_name,
      request_hash,
      household_id,
      series_id,
      occurrence_id,
      exception_id,
      result_revision_id,
      result_occurrence_version,
      result_exception_version,
      result_cancelled
    ) values (
      v_authenticated_user_id,
      p_idempotency_key,
      'cancel_occurrence',
      v_request_hash,
      p_household_id,
      p_series_id,
      p_occurrence_id,
      v_exception_id,
      v_exception_revision_id,
      v_result_occurrence_version,
      v_result_exception_version,
      true
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
    'calendar.occurrence_cancelled',
    p_series_id,
    p_occurrence_id,
    v_authenticated_user_id,
    v_actor_member_id,
    p_idempotency_key,
    v_series_version,
    v_result_occurrence_version
  );

  return query select
    p_household_id,
    p_series_id,
    p_occurrence_id,
    v_exception_revision_id,
    v_result_occurrence_version,
    v_result_exception_version,
    true,
    true;
end;
$$;

revoke all on function public.cancel_recurring_calendar_occurrence(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) from public, anon, authenticated, service_role;

grant execute on function public.cancel_recurring_calendar_occurrence(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) to authenticated;

comment on table public.event_occurrence_exceptions is
  'Single recurring occurrence overrides/cancellations. Content is normalized into immutable revisions.';

comment on function public.update_recurring_calendar_occurrence(
  uuid,
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
) is
  'Versioned idempotent edit of one recurring Calendar occurrence.';

comment on function public.cancel_recurring_calendar_occurrence(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) is
  'Versioned idempotent cancellation of one recurring Calendar occurrence.';
