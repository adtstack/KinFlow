-- KinFlow WP04-16 immediate Undo for selected-boundary recurring Calendar
-- cancellation. The WP04-15 public cancellation contract stays compatible;
-- a private metadata-only ledger enables one actor/version-bound resume.

alter table public.event_series_change_events
  drop constraint event_series_change_events_operation_check,
  add constraint event_series_change_events_operation_check check (
    operation in ('updated', 'cancelled', 'resumed')
  ),
  drop constraint event_series_change_event_revision_shape_ck,
  add constraint event_series_change_event_revision_shape_ck check (
    (
      operation in ('updated', 'resumed')
      and new_revision_id is not null
      and materialized_through is not null
    )
    or (
      operation = 'cancelled'
      and (
        new_revision_id is null and materialized_through is null
        or new_revision_id is not null and materialized_through is not null
      )
    )
  );

alter table app_private.calendar_series_change_command_requests
  drop constraint calendar_series_change_command_requests_operation_check,
  add constraint calendar_series_change_command_requests_operation_check
    check (operation in ('updated', 'cancelled', 'resumed')),
  drop constraint calendar_series_change_request_revision_shape_ck,
  add constraint calendar_series_change_request_revision_shape_ck check (
    (
      operation in ('updated', 'resumed')
      and result_revision_id is not null
      and result_revision_number is not null
      and result_revision_number > 0
      and result_materialized_through is not null
    )
    or (
      operation = 'cancelled'
      and (
        result_revision_id is null
        and result_revision_number is null
        and result_materialized_through is null
        or result_revision_id is not null
        and result_revision_number is not null
        and result_revision_number > 0
        and result_materialized_through is not null
      )
    )
  );

alter table app_private.calendar_audit_events
  drop constraint calendar_audit_events_action_check,
  add constraint calendar_audit_events_action_check check (
    action in (
      'calendar.created',
      'calendar.updated',
      'calendar.deleted',
      'calendar.occurrence_updated',
      'calendar.occurrence_cancelled',
      'calendar.series_updated',
      'calendar.series_cancelled',
      'calendar.series_resumed'
    )
  );

create table app_private.calendar_series_cancellation_undo_items (
  authenticated_user_id uuid not null,
  cancellation_idempotency_key uuid not null,
  household_id uuid not null,
  series_id uuid not null,
  occurrence_id uuid not null,
  mutation_kind text not null check (
    mutation_kind in ('cancelled_status', 'terminal_repoint')
  ),
  previous_status public.occurrence_status not null,
  previous_revision_id uuid not null,
  previous_version bigint not null check (previous_version > 0),
  post_status public.occurrence_status not null,
  post_revision_id uuid not null,
  post_version bigint not null check (post_version = previous_version + 1),
  created_at timestamptz not null default pg_catalog.statement_timestamp(),
  primary key (
    authenticated_user_id,
    cancellation_idempotency_key,
    occurrence_id
  ),
  constraint calendar_series_cancellation_undo_shape_ck check (
    mutation_kind = 'cancelled_status'
      and previous_status in ('scheduled', 'completed', 'skipped')
      and post_status = 'cancelled'
      and previous_revision_id = post_revision_id
    or mutation_kind = 'terminal_repoint'
      and previous_status = 'scheduled'
      and post_status = 'scheduled'
      and previous_revision_id <> post_revision_id
  ),
  constraint calendar_series_cancellation_undo_request_fk
    foreign key (authenticated_user_id, cancellation_idempotency_key)
    references app_private.calendar_series_change_command_requests(
      authenticated_user_id,
      idempotency_key
    ) on delete cascade,
  constraint calendar_series_cancellation_undo_series_fk
    foreign key (household_id, series_id)
    references public.event_series(household_id, id)
    on delete cascade,
  constraint calendar_series_cancellation_undo_occurrence_fk
    foreign key (household_id, occurrence_id)
    references public.event_occurrences(household_id, id)
    on delete cascade,
  constraint calendar_series_cancellation_undo_previous_revision_fk
    foreign key (household_id, series_id, previous_revision_id)
    references public.event_series_revisions(household_id, series_id, id),
  constraint calendar_series_cancellation_undo_post_revision_fk
    foreign key (household_id, series_id, post_revision_id)
    references public.event_series_revisions(household_id, series_id, id)
);

create index calendar_series_cancellation_undo_series_idx
  on app_private.calendar_series_cancellation_undo_items(
    household_id,
    series_id,
    cancellation_idempotency_key
  );

revoke all on table app_private.calendar_series_cancellation_undo_items
  from public, anon, authenticated, service_role;

create function app_private.reject_calendar_series_cancellation_undo_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'calendar series cancellation undo items are immutable';
end;
$$;

revoke all on function app_private.reject_calendar_series_cancellation_undo_mutation()
  from public, anon, authenticated, service_role;

create trigger calendar_series_cancellation_undo_items_immutable
before update or delete
on app_private.calendar_series_cancellation_undo_items
for each row
execute function
  app_private.reject_calendar_series_cancellation_undo_mutation();

-- Preserve the WP04-15 implementation as a grant-free private engine. The
-- compatible wrapper records exact pre-state only for the first successful
-- selected-boundary cancellation.
alter function public.cancel_recurring_calendar_series_from_occurrence(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) rename to cancel_recurring_calendar_series_from_occurrence_wp04_15;

alter function public.cancel_recurring_calendar_series_from_occurrence_wp04_15(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) set schema app_private;

revoke all on function app_private.cancel_recurring_calendar_series_from_occurrence_wp04_15(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) from public, anon, authenticated, service_role;

create function public.cancel_recurring_calendar_series_from_occurrence(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_effective_occurrence_id uuid,
  p_expected_version bigint
)
returns table (
  household_id uuid,
  household_timezone text,
  household_local_date date,
  series_id uuid,
  effective_local_date date,
  version bigint,
  cancelled_count integer,
  preserved_past_count integer,
  terminal_revision_id uuid,
  terminal_revision_number integer,
  changed boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_is_replay boolean := false;
  v_household_timezone text;
  v_household_local_date date;
  v_effective_local_date date;
  v_terminal_source_revision_id uuid;
  v_prestate jsonb := '[]'::jsonb;
  v_result_household_id uuid;
  v_result_household_timezone text;
  v_result_household_local_date date;
  v_result_series_id uuid;
  v_result_effective_local_date date;
  v_result_version bigint;
  v_result_cancelled_count integer;
  v_result_preserved_past_count integer;
  v_result_terminal_revision_id uuid;
  v_result_terminal_revision_number integer;
  v_result_changed boolean;
  v_recorded_cancelled_count integer;
begin
  if v_authenticated_user_id is not null
    and p_idempotency_key is not null then
    select exists (
      select 1
      from app_private.calendar_series_change_command_requests as request
      where request.authenticated_user_id = v_authenticated_user_id
        and request.idempotency_key = p_idempotency_key
    ) into v_is_replay;
  end if;

  if not v_is_replay then
    select occurrence.recurrence_local_start_date, household.timezone
    into v_effective_local_date, v_household_timezone
    from public.event_occurrences as occurrence
    join public.event_series as series
      on series.household_id = occurrence.household_id
     and series.id = occurrence.series_id
     and series.active_revision_id = occurrence.revision_id
    join public.households as household
      on household.id = occurrence.household_id
     and household.deleted_at is null
    where occurrence.household_id = p_household_id
      and occurrence.series_id = p_series_id
      and occurrence.id = p_effective_occurrence_id
      and occurrence.status = 'scheduled'
      and not exists (
        select 1
        from public.event_occurrence_exceptions as exception
        where exception.household_id = occurrence.household_id
          and exception.series_id = occurrence.series_id
          and exception.occurrence_id = occurrence.id
      );

    if found then
      v_household_local_date := (
        pg_catalog.statement_timestamp() at time zone v_household_timezone
      )::date;

      select occurrence.revision_id
      into v_terminal_source_revision_id
      from public.event_occurrences as occurrence
      join public.event_series_revisions as revision
        on revision.household_id = occurrence.household_id
       and revision.series_id = occurrence.series_id
       and revision.id = occurrence.revision_id
       and revision.recurrence_rule is not null
      where occurrence.household_id = p_household_id
        and occurrence.series_id = p_series_id
        and occurrence.status = 'scheduled'
        and occurrence.recurrence_local_start_date >= v_household_local_date
        and occurrence.recurrence_local_start_date < v_effective_local_date
        and not exists (
          select 1
          from public.event_occurrence_exceptions as exception
          where exception.household_id = occurrence.household_id
            and exception.series_id = occurrence.series_id
            and exception.occurrence_id = occurrence.id
        )
      order by occurrence.recurrence_local_start_date desc, occurrence.id
      limit 1;

      select coalesce(
        pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'occurrence_id', candidate.occurrence_id,
            'mutation_kind', candidate.mutation_kind,
            'previous_status', candidate.previous_status,
            'previous_revision_id', candidate.previous_revision_id,
            'previous_version', candidate.previous_version
          )
          order by candidate.occurrence_id
        ),
        '[]'::jsonb
      )
      into v_prestate
      from (
        select
          occurrence.id as occurrence_id,
          'cancelled_status'::text as mutation_kind,
          occurrence.status::text as previous_status,
          occurrence.revision_id as previous_revision_id,
          occurrence.version as previous_version
        from public.event_occurrences as occurrence
        where occurrence.household_id = p_household_id
          and occurrence.series_id = p_series_id
          and occurrence.recurrence_local_start_date >= v_effective_local_date
          and occurrence.status <> 'cancelled'

        union all

        select
          occurrence.id,
          'terminal_repoint'::text,
          occurrence.status::text,
          occurrence.revision_id,
          occurrence.version
        from public.event_occurrences as occurrence
        where v_terminal_source_revision_id is not null
          and occurrence.household_id = p_household_id
          and occurrence.series_id = p_series_id
          and occurrence.revision_id = v_terminal_source_revision_id
          and occurrence.status = 'scheduled'
          and occurrence.recurrence_local_start_date >= v_household_local_date
          and occurrence.recurrence_local_start_date < v_effective_local_date
          and not exists (
            select 1
            from public.event_occurrence_exceptions as exception
            where exception.household_id = occurrence.household_id
              and exception.series_id = occurrence.series_id
              and exception.occurrence_id = occurrence.id
          )
      ) as candidate;
    end if;
  end if;

  select engine.*
  into
    v_result_household_id,
    v_result_household_timezone,
    v_result_household_local_date,
    v_result_series_id,
    v_result_effective_local_date,
    v_result_version,
    v_result_cancelled_count,
    v_result_preserved_past_count,
    v_result_terminal_revision_id,
    v_result_terminal_revision_number,
    v_result_changed
  from app_private.cancel_recurring_calendar_series_from_occurrence_wp04_15(
    p_idempotency_key,
    p_household_id,
    p_series_id,
    p_effective_occurrence_id,
    p_expected_version
  ) as engine;

  if v_result_changed then
    insert into app_private.calendar_series_cancellation_undo_items (
      authenticated_user_id,
      cancellation_idempotency_key,
      household_id,
      series_id,
      occurrence_id,
      mutation_kind,
      previous_status,
      previous_revision_id,
      previous_version,
      post_status,
      post_revision_id,
      post_version
    )
    select
      v_authenticated_user_id,
      p_idempotency_key,
      p_household_id,
      p_series_id,
      occurrence.id,
      item.mutation_kind,
      item.previous_status::public.occurrence_status,
      item.previous_revision_id,
      item.previous_version,
      occurrence.status,
      occurrence.revision_id,
      occurrence.version
    from pg_catalog.jsonb_to_recordset(v_prestate) as item(
      occurrence_id uuid,
      mutation_kind text,
      previous_status text,
      previous_revision_id uuid,
      previous_version bigint
    )
    join public.event_occurrences as occurrence
      on occurrence.household_id = p_household_id
     and occurrence.series_id = p_series_id
     and occurrence.id = item.occurrence_id
    where occurrence.status is distinct from
          item.previous_status::public.occurrence_status
       or occurrence.revision_id is distinct from item.previous_revision_id;

    select pg_catalog.count(*)::integer
    into v_recorded_cancelled_count
    from app_private.calendar_series_cancellation_undo_items as item
    where item.authenticated_user_id = v_authenticated_user_id
      and item.cancellation_idempotency_key = p_idempotency_key
      and item.mutation_kind = 'cancelled_status';

    if v_recorded_cancelled_count <> v_result_cancelled_count then
      raise exception using
        errcode = 'KFE08',
        message = 'calendar series transition not allowed';
    end if;
  end if;

  return query select
    v_result_household_id,
    v_result_household_timezone,
    v_result_household_local_date,
    v_result_series_id,
    v_result_effective_local_date,
    v_result_version,
    v_result_cancelled_count,
    v_result_preserved_past_count,
    v_result_terminal_revision_id,
    v_result_terminal_revision_number,
    v_result_changed;
end;
$$;

revoke all on function public.cancel_recurring_calendar_series_from_occurrence(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) from public, anon, authenticated, service_role;

grant execute on function public.cancel_recurring_calendar_series_from_occurrence(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) to authenticated;

create function public.resume_recurring_calendar_series_cancellation(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_cancellation_idempotency_key uuid,
  p_expected_version bigint
)
returns table (
  household_id uuid,
  series_id uuid,
  effective_local_date date,
  version bigint,
  restored_count integer,
  preserved_past_count integer,
  revision_id uuid,
  revision_number integer,
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
  v_existing_request_hash bytea;
  v_result_effective_local_date date;
  v_result_version bigint;
  v_result_restored_count integer;
  v_result_preserved_past_count integer;
  v_result_revision_id uuid;
  v_result_revision_number integer;
  v_result_materialized_through date;
  v_result_event_id uuid;
  v_cancellation_version bigint;
  v_cancellation_cancelled_count integer;
  v_cancellation_preserved_exception_count integer;
  v_cancellation_terminal_revision_id uuid;
  v_source_revision_id uuid;
  v_current_series_version bigint;
  v_current_active_revision_id uuid;
  v_current_deleted_at timestamptz;
  v_current_ended_at timestamptz;
  v_current_ended_effective_local_date date;
  v_source_local_start_date date;
  v_source_local_start_time time without time zone;
  v_source_duration_minutes integer;
  v_source_all_day_end_date_exclusive date;
  v_source_gap_policy text;
  v_source_overlap_policy text;
  v_source_recurrence_rule jsonb;
  v_source_title text;
  v_source_description text;
  v_source_timezone text;
  v_source_is_all_day boolean;
  v_recorded_cancelled_count integer;
  v_audit_occurrence_id uuid;
  v_audit_occurrence_version bigint;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFE01',
      message = 'authentication required';
  end if;

  if p_idempotency_key is null
    or p_household_id is null
    or p_series_id is null
    or p_cancellation_idempotency_key is null
    or p_idempotency_key = p_cancellation_idempotency_key
    or p_expected_version is null
    or p_expected_version < 1 then
    raise exception using
      errcode = 'KFE02',
      message = 'invalid calendar event input';
  end if;

  select actor.id
  into v_actor_member_id
  from public.household_members as actor
  join public.households as household
    on household.id = actor.household_id
   and household.deleted_at is null
  where actor.household_id = p_household_id
    and actor.auth_user_id = v_authenticated_user_id
    and actor.removed_at is null
  for update of actor;

  if not found then
    raise exception using
      errcode = 'KFE03',
      message = 'calendar event not found or forbidden';
  end if;

  v_request_hash := extensions.digest(
    pg_catalog.convert_to(
      pg_catalog.jsonb_build_object(
        'operation', 'resume_recurring_calendar_series_cancellation',
        'household_id', p_household_id,
        'series_id', p_series_id,
        'cancellation_idempotency_key', p_cancellation_idempotency_key,
        'expected_version', p_expected_version
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_authenticated_user_id::text
        || ':calendar-series-change:'
        || p_idempotency_key::text,
      0
    )
  );

  select
    request.request_hash,
    request.result_effective_local_date,
    request.result_version,
    request.result_rebuilt_count,
    request.result_preserved_past_count,
    request.result_revision_id,
    revision.revision_number
  into
    v_existing_request_hash,
    v_result_effective_local_date,
    v_result_version,
    v_result_restored_count,
    v_result_preserved_past_count,
    v_result_revision_id,
    v_result_revision_number
  from app_private.calendar_series_change_command_requests as request
  join public.event_series_revisions as revision
    on revision.household_id = request.household_id
   and revision.series_id = request.series_id
   and revision.id = request.result_revision_id
  where request.authenticated_user_id = v_authenticated_user_id
    and request.idempotency_key = p_idempotency_key
    and request.operation = 'resumed';

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFE04',
        message = 'idempotency key reused with different calendar input';
    end if;

    return query select
      p_household_id,
      p_series_id,
      v_result_effective_local_date,
      v_result_version,
      v_result_restored_count,
      v_result_preserved_past_count,
      v_result_revision_id,
      v_result_revision_number,
      false;
    return;
  end if;

  if exists (
      select 1
      from app_private.calendar_series_change_command_requests as request
      where request.authenticated_user_id = v_authenticated_user_id
        and request.idempotency_key = p_idempotency_key
    )
    or exists (
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
    )
    or exists (
      select 1
      from app_private.calendar_occurrence_exception_command_requests
        as request
      where request.authenticated_user_id = v_authenticated_user_id
        and request.idempotency_key = p_idempotency_key
    ) then
    raise exception using
      errcode = 'KFE04',
      message = 'idempotency key reused with different calendar input';
  end if;

  select
    cancellation.result_effective_local_date,
    cancellation.result_version,
    cancellation.result_cancelled_count,
    cancellation.result_preserved_exception_count,
    cancellation.result_preserved_past_count,
    cancellation.result_revision_id,
    event.previous_revision_id
  into
    v_result_effective_local_date,
    v_cancellation_version,
    v_cancellation_cancelled_count,
    v_cancellation_preserved_exception_count,
    v_result_preserved_past_count,
    v_cancellation_terminal_revision_id,
    v_source_revision_id
  from app_private.calendar_series_change_command_requests as cancellation
  join public.event_series_change_events as event
    on event.household_id = cancellation.household_id
   and event.id = cancellation.result_event_id
  where cancellation.authenticated_user_id = v_authenticated_user_id
    and cancellation.idempotency_key = p_cancellation_idempotency_key
    and cancellation.operation = 'cancelled'
    and cancellation.household_id = p_household_id
    and cancellation.series_id = p_series_id;

  if not found or v_cancellation_cancelled_count < 1 then
    raise exception using
      errcode = 'KFE03',
      message = 'calendar event not found or forbidden';
  end if;

  if v_cancellation_version <> p_expected_version then
    raise exception using
      errcode = 'KFE05',
      message = 'stale calendar event version';
  end if;

  select
    series.version,
    series.active_revision_id,
    series.deleted_at,
    series.ended_at,
    series.ended_effective_local_date
  into
    v_current_series_version,
    v_current_active_revision_id,
    v_current_deleted_at,
    v_current_ended_at,
    v_current_ended_effective_local_date
  from public.event_series as series
  where series.household_id = p_household_id
    and series.id = p_series_id
  for update of series;

  if not found or v_current_deleted_at is not null then
    raise exception using
      errcode = 'KFE03',
      message = 'calendar event not found or forbidden';
  end if;

  if v_current_series_version <> p_expected_version then
    raise exception using
      errcode = 'KFE05',
      message = 'stale calendar event version';
  end if;

  if v_cancellation_terminal_revision_id is null and (
      v_current_active_revision_id <> v_source_revision_id
      or v_current_ended_at is null
      or v_current_ended_effective_local_date <> v_result_effective_local_date
    )
    or v_cancellation_terminal_revision_id is not null and (
      v_current_active_revision_id <> v_cancellation_terminal_revision_id
      or v_current_ended_at is not null
      or v_current_ended_effective_local_date is not null
    ) then
    raise exception using
      errcode = 'KFE08',
      message = 'calendar series transition not allowed';
  end if;

  select
    revision.local_start_date,
    revision.local_start_time,
    revision.duration_minutes,
    revision.all_day_end_date_exclusive,
    revision.gap_policy,
    revision.overlap_policy,
    revision.recurrence_rule,
    revision.snapshot_title,
    revision.snapshot_description,
    revision.snapshot_timezone,
    revision.snapshot_is_all_day
  into
    v_source_local_start_date,
    v_source_local_start_time,
    v_source_duration_minutes,
    v_source_all_day_end_date_exclusive,
    v_source_gap_policy,
    v_source_overlap_policy,
    v_source_recurrence_rule,
    v_source_title,
    v_source_description,
    v_source_timezone,
    v_source_is_all_day
  from public.event_series_revisions as revision
  where revision.household_id = p_household_id
    and revision.series_id = p_series_id
    and revision.id = v_source_revision_id;

  if not found
    or v_source_recurrence_rule is null
    or not app_private.is_valid_calendar_recurrence_rule(
      v_source_recurrence_rule
    ) then
    raise exception using
      errcode = 'KFE08',
      message = 'calendar series transition not allowed';
  end if;

  if exists (
    select 1
    from public.event_revision_participants as participant
    left join public.household_members as member
      on member.household_id = participant.household_id
     and member.id = participant.member_id
     and member.removed_at is null
    where participant.household_id = p_household_id
      and participant.series_id = p_series_id
      and participant.revision_id = v_source_revision_id
      and member.id is null
  ) then
    raise exception using
      errcode = 'KFE08',
      message = 'calendar series transition not allowed';
  end if;

  select pg_catalog.count(*)::integer
  into v_recorded_cancelled_count
  from app_private.calendar_series_cancellation_undo_items as item
  join public.event_occurrences as occurrence
    on occurrence.household_id = item.household_id
   and occurrence.id = item.occurrence_id
  where item.authenticated_user_id = v_authenticated_user_id
    and item.cancellation_idempotency_key = p_cancellation_idempotency_key
    and item.household_id = p_household_id
    and item.series_id = p_series_id
    and item.mutation_kind = 'cancelled_status'
    and occurrence.status = item.post_status
    and occurrence.revision_id = item.post_revision_id
    and occurrence.version = item.post_version;

  if v_recorded_cancelled_count <> v_cancellation_cancelled_count then
    raise exception using
      errcode = 'KFE08',
      message = 'calendar series transition not allowed';
  end if;

  v_result_revision_id := extensions.gen_random_uuid();
  select coalesce(pg_catalog.max(revision.revision_number), 0) + 1
  into v_result_revision_number
  from public.event_series_revisions as revision
  where revision.series_id = p_series_id;

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
    v_result_revision_id,
    p_household_id,
    p_series_id,
    v_result_revision_number,
    v_source_local_start_date,
    v_source_local_start_time,
    v_source_duration_minutes,
    v_source_all_day_end_date_exclusive,
    v_source_gap_policy,
    v_source_overlap_policy,
    v_source_recurrence_rule,
    v_authenticated_user_id,
    v_source_title,
    v_source_description,
    v_source_timezone,
    v_source_is_all_day
  );

  insert into public.event_revision_participants (
    household_id,
    series_id,
    revision_id,
    member_id
  )
  select
    participant.household_id,
    participant.series_id,
    v_result_revision_id,
    participant.member_id
  from public.event_revision_participants as participant
  where participant.household_id = p_household_id
    and participant.series_id = p_series_id
    and participant.revision_id = v_source_revision_id;

  with eligible as (
    select
      item.occurrence_id,
      item.mutation_kind,
      item.previous_status,
      case
        when item.previous_revision_id = v_source_revision_id
          then v_result_revision_id
        else item.previous_revision_id
      end as restored_revision_id
    from app_private.calendar_series_cancellation_undo_items as item
    join public.event_occurrences as occurrence
      on occurrence.household_id = item.household_id
     and occurrence.id = item.occurrence_id
    where item.authenticated_user_id = v_authenticated_user_id
      and item.cancellation_idempotency_key = p_cancellation_idempotency_key
      and item.household_id = p_household_id
      and item.series_id = p_series_id
      and occurrence.status = item.post_status
      and occurrence.revision_id = item.post_revision_id
      and occurrence.version = item.post_version
  ),
  restored as (
    update public.event_occurrences as occurrence
    set
      status = eligible.previous_status,
      revision_id = eligible.restored_revision_id
    from eligible
    where occurrence.household_id = p_household_id
      and occurrence.series_id = p_series_id
      and occurrence.id = eligible.occurrence_id
    returning eligible.mutation_kind
  )
  select pg_catalog.count(*) filter (
    where restored.mutation_kind = 'cancelled_status'
  )::integer
  into v_result_restored_count
  from restored;

  if v_result_restored_count <> v_cancellation_cancelled_count then
    raise exception using
      errcode = 'KFE08',
      message = 'calendar series transition not allowed';
  end if;

  update public.event_series as series
  set
    title = v_source_title,
    description = v_source_description,
    timezone = v_source_timezone,
    is_all_day = v_source_is_all_day,
    active_revision_id = v_result_revision_id,
    ended_at = null,
    ended_effective_local_date = null
  where series.household_id = p_household_id
    and series.id = p_series_id
  returning series.version into v_result_version;

  delete from public.event_participants as participant
  where participant.household_id = p_household_id
    and participant.series_id = p_series_id;

  insert into public.event_participants (
    household_id,
    series_id,
    member_id
  )
  select
    participant.household_id,
    participant.series_id,
    participant.member_id
  from public.event_revision_participants as participant
  where participant.household_id = p_household_id
    and participant.series_id = p_series_id
    and participant.revision_id = v_result_revision_id;

  delete from app_private.calendar_materialization_states as state
  where state.household_id = p_household_id
    and state.series_id = p_series_id;

  select pg_catalog.max(occurrence.recurrence_local_start_date)
  into v_result_materialized_through
  from public.event_occurrences as occurrence
  where occurrence.household_id = p_household_id
    and occurrence.series_id = p_series_id
    and occurrence.revision_id = v_result_revision_id;

  if v_result_materialized_through is null then
    raise exception using
      errcode = 'KFE08',
      message = 'calendar series transition not allowed';
  end if;

  select occurrence.id, occurrence.version
  into v_audit_occurrence_id, v_audit_occurrence_version
  from public.event_occurrences as occurrence
  where occurrence.household_id = p_household_id
    and occurrence.series_id = p_series_id
    and occurrence.revision_id = v_result_revision_id
    and occurrence.recurrence_local_start_date = v_result_effective_local_date
  order by occurrence.id
  limit 1;

  if not found then
    raise exception using
      errcode = 'KFE08',
      message = 'calendar series transition not allowed';
  end if;

  insert into public.event_series_change_events (
    household_id,
    series_id,
    operation,
    previous_revision_id,
    new_revision_id,
    effective_local_date,
    materialized_through,
    actor_user_id,
    actor_member_id,
    rebuilt_count,
    cancelled_count,
    preserved_exception_count,
    preserved_past_count,
    series_version,
    correlation_id
  ) values (
    p_household_id,
    p_series_id,
    'resumed',
    coalesce(v_cancellation_terminal_revision_id, v_source_revision_id),
    v_result_revision_id,
    v_result_effective_local_date,
    v_result_materialized_through,
    v_authenticated_user_id,
    v_actor_member_id,
    v_result_restored_count,
    0,
    v_cancellation_preserved_exception_count,
    v_result_preserved_past_count,
    v_result_version,
    p_idempotency_key
  )
  returning id into v_result_event_id;

  insert into app_private.calendar_series_change_command_requests (
    authenticated_user_id,
    idempotency_key,
    request_hash,
    operation,
    household_id,
    series_id,
    result_revision_id,
    result_revision_number,
    result_effective_local_date,
    result_materialized_through,
    result_version,
    result_rebuilt_count,
    result_cancelled_count,
    result_preserved_exception_count,
    result_preserved_past_count,
    result_event_id
  ) values (
    v_authenticated_user_id,
    p_idempotency_key,
    v_request_hash,
    'resumed',
    p_household_id,
    p_series_id,
    v_result_revision_id,
    v_result_revision_number,
    v_result_effective_local_date,
    v_result_materialized_through,
    v_result_version,
    v_result_restored_count,
    0,
    v_cancellation_preserved_exception_count,
    v_result_preserved_past_count,
    v_result_event_id
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
    'calendar.series_resumed',
    p_series_id,
    v_audit_occurrence_id,
    v_authenticated_user_id,
    v_actor_member_id,
    p_idempotency_key,
    v_result_version,
    v_audit_occurrence_version
  );

  return query select
    p_household_id,
    p_series_id,
    v_result_effective_local_date,
    v_result_version,
    v_result_restored_count,
    v_result_preserved_past_count,
    v_result_revision_id,
    v_result_revision_number,
    true;
end;
$$;

revoke all on function public.resume_recurring_calendar_series_cancellation(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) from public, anon, authenticated, service_role;

grant execute on function public.resume_recurring_calendar_series_cancellation(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) to authenticated;

comment on table app_private.calendar_series_cancellation_undo_items is
  'WP04-16 immutable metadata-only pre/post occurrence state for immediate selected-boundary Calendar cancellation Undo.';
comment on function public.cancel_recurring_calendar_series_from_occurrence(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) is
  'WP04-16 compatible cancellation wrapper that records exact metadata-only Undo state before invoking the private WP04-15 engine.';
comment on function public.resume_recurring_calendar_series_cancellation(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) is
  'Resumes one exact actor-owned selected-boundary Calendar cancellation when its series and occurrence post-state remain compatible.';
