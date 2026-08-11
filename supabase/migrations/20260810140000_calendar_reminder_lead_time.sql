-- KinFlow WP05-11 per-user Calendar reminder lead time.
-- Existing v1 preference RPCs remain byte-for-byte shape compatible. The
-- source event keeps the base Calendar schedule; only the per-recipient
-- latest-state reminder instant is lead-adjusted.

alter table public.notification_preferences
  add column reminder_lead_minutes integer not null default 0;

alter table public.notification_preferences
  add constraint notification_preferences_reminder_lead_minutes_ck check (
    reminder_lead_minutes in (0, 5, 10, 15, 30, 60)
    and (
      category = 'calendar_event'
      or reminder_lead_minutes = 0
    )
  );

create or replace function app_private.calendar_notification_lead_minutes(
  p_household_id uuid,
  p_audience_member_id uuid
)
returns integer
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (
      select preference.reminder_lead_minutes
      from public.household_members as member
      left join public.notification_preferences as preference
        on preference.auth_user_id = member.auth_user_id
       and preference.household_id = member.household_id
       and preference.category = 'calendar_event'
      where member.household_id = p_household_id
        and member.id = p_audience_member_id
        and member.removed_at is null
      limit 1
    ),
    0
  )
$$;

revoke all on function app_private.calendar_notification_lead_minutes(
  uuid,
  uuid
) from public, anon, authenticated, service_role;

create or replace function app_private.calendar_notification_reminder_at(
  p_household_id uuid,
  p_occurrence_id uuid,
  p_audience_member_id uuid,
  p_source_event_id uuid
)
returns timestamptz
language sql
stable
set search_path = ''
as $$
  with base_schedule as (
    select schedule.scheduled_at
    from app_private.calendar_notification_schedule(
      p_household_id,
      p_occurrence_id
    ) as schedule
  ),
  existing_resolution as (
    select
      resolution.scheduled_at,
      (
        exists (
          select 1
          from app_private.notification_inbox_evaluations as evaluation
          where evaluation.source_event_id = resolution.source_event_id
        )
        or exists (
          select 1
          from app_private.notification_push_evaluations as evaluation
          where evaluation.source_event_id = resolution.source_event_id
            and evaluation.processing_status <> 'pending'
        )
      ) as schedule_is_frozen
    from app_private.notification_event_resolutions as resolution
    where resolution.source_event_id = p_source_event_id
      and resolution.household_id = p_household_id
      and resolution.subject_type = 'calendar_occurrence'
      and resolution.subject_id = p_occurrence_id
  )
  select case
    when coalesce(existing_resolution.schedule_is_frozen, false)
      then existing_resolution.scheduled_at
    else base_schedule.scheduled_at - pg_catalog.make_interval(
      mins => app_private.calendar_notification_lead_minutes(
        p_household_id,
        p_audience_member_id
      )
    )
  end
  from base_schedule
  left join existing_resolution on true
$$;

revoke all on function app_private.calendar_notification_reminder_at(
  uuid,
  uuid,
  uuid,
  uuid
) from public, anon, authenticated, service_role;

create or replace function app_private.resolve_notification_event(
  p_event_id uuid
)
returns table (
  event_id uuid,
  event_type text,
  event_version integer,
  event_occurred_at timestamptz,
  household_id uuid,
  actor_member_id uuid,
  occurrence_id uuid,
  event_occurrence_version bigint,
  current_occurrence_version bigint,
  notification_category text,
  subject_type text,
  recipient_member_id uuid,
  recipient_user_id uuid,
  due_local_date date,
  due_at timestamptz,
  timezone text,
  occurrence_status text,
  is_current boolean,
  should_create_intent boolean,
  suppression_reason text
)
language sql
stable
set search_path = ''
as $$
  with source as (
    select event.*
    from app_private.chore_notification_outbox as event
    where event.event_id = p_event_id
  ),
  resolved as (
    select
      event.event_id,
      event.event_type,
      event.event_version,
      event.occurred_at,
      event.household_id,
      event.actor_member_id,
      occurrence.id as occurrence_id,
      event.aggregate_version as event_occurrence_version,
      occurrence.version as current_occurrence_version,
      case
        when event.event_type = 'chore.occurrence_due_changed'
          then 'chore_due'
        else 'chore_assignment'
      end as notification_category,
      'chore_occurrence'::text as subject_type,
      event.audience_member_id as recipient_member_id,
      occurrence.due_local_date,
      occurrence.due_at,
      occurrence.timezone,
      occurrence.status::text as occurrence_status,
      series.deleted_at is not null as series_inactive,
      event.event_type = 'chore.occurrence_due_changed'
        and occurrence.due_at is null as schedule_unresolved,
      (
        event.aggregate_version = (
          select pg_catalog.max(candidate.aggregate_version)
          from app_private.chore_notification_outbox as candidate
          where candidate.household_id = event.household_id
            and candidate.event_type = event.event_type
            and candidate.aggregate_id = event.aggregate_id
            and candidate.audience_member_id = event.audience_member_id
        )
        and occurrence.version >= event.aggregate_version
        and occurrence.assignee_member_id = event.audience_member_id
        and (
          event.event_type = 'chore.occurrence_due_changed'
          and occurrence.due_local_date =
            (event.payload->>'dueLocalDate')::date
          and occurrence.due_at is not distinct from case
            when pg_catalog.jsonb_typeof(event.payload->'dueAt') = 'null'
              then null
            else (event.payload->>'dueAt')::timestamptz
          end
          and occurrence.timezone = event.payload->>'timezone'
          and occurrence.status::text = event.payload->>'status'
          or event.event_type = 'chore.occurrence_assigned'
          and occurrence.assignee_member_id =
            (event.payload->>'assigneeMemberId')::uuid
          and occurrence.status::text = event.payload->>'status'
        )
      ) as is_current
    from source as event
    join public.chore_occurrences as occurrence
      on occurrence.household_id = event.household_id
     and occurrence.id = event.aggregate_id
    join public.chore_series as series
      on series.household_id = occurrence.household_id
     and series.id = occurrence.series_id
    where event.aggregate_type = 'chore_occurrence'

    union all

    select
      event.event_id,
      event.event_type,
      event.event_version,
      event.occurred_at,
      event.household_id,
      event.actor_member_id,
      occurrence.id as occurrence_id,
      event.aggregate_version as event_occurrence_version,
      occurrence.version as current_occurrence_version,
      'calendar_event'::text as notification_category,
      'calendar_occurrence'::text as subject_type,
      event.audience_member_id as recipient_member_id,
      occurrence.local_start_date as due_local_date,
      app_private.calendar_notification_reminder_at(
        occurrence.household_id,
        occurrence.id,
        event.audience_member_id,
        event.event_id
      ) as due_at,
      schedule.timezone,
      occurrence.status::text as occurrence_status,
      series.deleted_at is not null
        or series.ended_at is not null as series_inactive,
      schedule.scheduled_at is null as schedule_unresolved,
      (
        event.aggregate_version = (
          select pg_catalog.max(candidate.aggregate_version)
          from app_private.chore_notification_outbox as candidate
          where candidate.household_id = event.household_id
            and candidate.event_type = event.event_type
            and candidate.aggregate_id = event.aggregate_id
            and candidate.audience_member_id = event.audience_member_id
        )
        and occurrence.version >= event.aggregate_version
        and occurrence.local_start_date =
          (event.payload->>'localStartDate')::date
        and schedule.scheduled_at =
          (event.payload->>'scheduledAt')::timestamptz
        and schedule.timezone = event.payload->>'timezone'
        and occurrence.status::text = event.payload->>'status'
        and event.audience_member_id =
          (event.payload->>'recipientMemberId')::uuid
        and exists (
          select 1
          from app_private.calendar_notification_participants(
            occurrence.household_id,
            occurrence.series_id,
            occurrence.revision_id
          ) as participant
          where participant.member_id = event.audience_member_id
        )
      ) as is_current
    from source as event
    join public.event_occurrences as occurrence
      on occurrence.household_id = event.household_id
     and occurrence.id = event.aggregate_id
    join public.event_series as series
      on series.household_id = occurrence.household_id
     and series.id = occurrence.series_id
    left join lateral app_private.calendar_notification_schedule(
      occurrence.household_id,
      occurrence.id
    ) as schedule on true
    where event.aggregate_type = 'calendar_occurrence'
  ),
  with_recipient as (
    select
      resolved.*,
      recipient.auth_user_id as recipient_user_id,
      recipient.removed_at as recipient_removed_at
    from resolved
    left join public.household_members as recipient
      on recipient.household_id = resolved.household_id
     and recipient.id = resolved.recipient_member_id
  ),
  evaluated as (
    select
      with_recipient.*,
      case
        when not with_recipient.is_current then 'stale_event'
        when with_recipient.series_inactive then 'inactive_series'
        when with_recipient.occurrence_status <> 'scheduled'
          then 'occurrence_not_scheduled'
        when with_recipient.recipient_user_id is null
          or with_recipient.recipient_removed_at is not null
          then 'inactive_recipient'
        when with_recipient.schedule_unresolved then 'schedule_unresolved'
        else null
      end as suppression_reason
    from with_recipient
  )
  select
    evaluated.event_id,
    evaluated.event_type,
    evaluated.event_version,
    evaluated.occurred_at,
    evaluated.household_id,
    evaluated.actor_member_id,
    evaluated.occurrence_id,
    evaluated.event_occurrence_version,
    evaluated.current_occurrence_version,
    evaluated.notification_category,
    evaluated.subject_type,
    evaluated.recipient_member_id,
    evaluated.recipient_user_id,
    evaluated.due_local_date,
    evaluated.due_at,
    evaluated.timezone,
    evaluated.occurrence_status,
    evaluated.is_current,
    evaluated.suppression_reason is null,
    evaluated.suppression_reason
  from evaluated
$$;

revoke all on function app_private.resolve_notification_event(uuid)
  from public, anon, authenticated, service_role;

create or replace function public.get_notification_preferences_v2(
  p_household_id uuid
)
returns table (
  household_id uuid,
  category text,
  native_push boolean,
  web_push boolean,
  email boolean,
  in_app boolean,
  quiet_start time without time zone,
  quiet_end time without time zone,
  timezone text,
  reminder_lead_minutes integer,
  updated_at timestamptz,
  version bigint,
  is_default boolean
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
      errcode = 'KNP02',
      message = 'authentication required';
  end if;

  if p_household_id is null then
    raise exception using
      errcode = 'KNP01',
      message = 'invalid notification preference input';
  end if;

  select household.timezone
  into v_household_timezone
  from public.households as household
  join public.household_members as member
    on member.household_id = household.id
   and member.auth_user_id = v_authenticated_user_id
   and member.removed_at is null
  where household.id = p_household_id
    and household.deleted_at is null;

  if not found then
    raise exception using
      errcode = 'KNP03',
      message = 'notification household not found or forbidden';
  end if;

  return query
  with categories(category) as (
    values
      ('calendar_event'::text),
      ('chore_assignment'::text),
      ('chore_due'::text)
  )
  select
    p_household_id,
    categories.category,
    coalesce(preference.native_push, true),
    coalesce(preference.web_push, false),
    coalesce(preference.email, false),
    coalesce(preference.in_app, true),
    preference.quiet_start,
    preference.quiet_end,
    coalesce(preference.timezone, v_household_timezone),
    coalesce(preference.reminder_lead_minutes, 0),
    preference.updated_at,
    coalesce(preference.version, 0),
    preference.auth_user_id is null
  from categories
  left join public.notification_preferences as preference
    on preference.auth_user_id = v_authenticated_user_id
   and preference.household_id = p_household_id
   and preference.category = categories.category
  order by categories.category;
end;
$$;

create or replace function public.update_notification_preference_v2(
  p_household_id uuid,
  p_category text,
  p_native_push boolean,
  p_web_push boolean,
  p_email boolean,
  p_in_app boolean,
  p_quiet_start time without time zone,
  p_quiet_end time without time zone,
  p_timezone text,
  p_reminder_lead_minutes integer,
  p_expected_version bigint
)
returns table (
  household_id uuid,
  category text,
  native_push boolean,
  web_push boolean,
  email boolean,
  in_app boolean,
  quiet_start time without time zone,
  quiet_end time without time zone,
  timezone text,
  reminder_lead_minutes integer,
  updated_at timestamptz,
  version bigint,
  is_default boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_existing public.notification_preferences%rowtype;
  v_result public.notification_preferences%rowtype;
  v_changed boolean := false;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KNP02',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or p_category is null
    or p_category not in (
      'chore_due', 'chore_assignment', 'calendar_event'
    )
    or p_native_push is null
    or p_web_push is null
    or p_email is null
    or p_in_app is null
    or p_timezone is null
    or not app_private.is_valid_iana_timezone(p_timezone)
    or p_reminder_lead_minutes is null
    or p_reminder_lead_minutes not in (0, 5, 10, 15, 30, 60)
    or p_category <> 'calendar_event' and p_reminder_lead_minutes <> 0
    or p_expected_version is null
    or p_expected_version < 0
    or (p_quiet_start is null) <> (p_quiet_end is null)
    or p_quiet_start is not null and (
      p_quiet_start = p_quiet_end
      or extract(second from p_quiet_start) <> 0
      or extract(second from p_quiet_end) <> 0
    ) then
    raise exception using
      errcode = 'KNP01',
      message = 'invalid notification preference input';
  end if;

  perform 1
  from public.households as household
  join public.household_members as member
    on member.household_id = household.id
   and member.auth_user_id = v_authenticated_user_id
   and member.removed_at is null
  where household.id = p_household_id
    and household.deleted_at is null;

  if not found then
    raise exception using
      errcode = 'KNP03',
      message = 'notification household not found or forbidden';
  end if;

  select preference.*
  into v_existing
  from public.notification_preferences as preference
  where preference.auth_user_id = v_authenticated_user_id
    and preference.household_id = p_household_id
    and preference.category = p_category
  for update;

  if not found then
    if p_expected_version <> 0 then
      raise exception using
        errcode = 'KNP06',
        message = 'notification preference version conflict';
    end if;

    insert into public.notification_preferences (
      auth_user_id,
      household_id,
      category,
      native_push,
      web_push,
      email,
      in_app,
      quiet_start,
      quiet_end,
      timezone,
      reminder_lead_minutes
    ) values (
      v_authenticated_user_id,
      p_household_id,
      p_category,
      p_native_push,
      p_web_push,
      p_email,
      p_in_app,
      p_quiet_start,
      p_quiet_end,
      p_timezone,
      p_reminder_lead_minutes
    ) returning * into v_result;
    v_changed := true;
  elsif v_existing.native_push = p_native_push
    and v_existing.web_push = p_web_push
    and v_existing.email = p_email
    and v_existing.in_app = p_in_app
    and v_existing.quiet_start is not distinct from p_quiet_start
    and v_existing.quiet_end is not distinct from p_quiet_end
    and v_existing.timezone = p_timezone
    and v_existing.reminder_lead_minutes = p_reminder_lead_minutes then
    v_result := v_existing;
  else
    if v_existing.version <> p_expected_version then
      raise exception using
        errcode = 'KNP06',
        message = 'notification preference version conflict';
    end if;

    update public.notification_preferences as preference
    set native_push = p_native_push,
        web_push = p_web_push,
        email = p_email,
        in_app = p_in_app,
        quiet_start = p_quiet_start,
        quiet_end = p_quiet_end,
        timezone = p_timezone,
        reminder_lead_minutes = p_reminder_lead_minutes
    where preference.auth_user_id = v_authenticated_user_id
      and preference.household_id = p_household_id
      and preference.category = p_category
    returning * into v_result;
    v_changed := true;
  end if;

  if v_changed and p_category = 'calendar_event' then
    with eligible_resolution as (
      select
        resolution.source_event_id,
        schedule.scheduled_at - pg_catalog.make_interval(
          mins => v_result.reminder_lead_minutes
        ) as reminder_at
      from app_private.notification_event_resolutions as resolution
      join lateral app_private.calendar_notification_schedule(
        resolution.household_id,
        resolution.subject_id
      ) as schedule on true
      where resolution.outcome = 'candidate'
        and resolution.notification_category = 'calendar_event'
        and resolution.subject_type = 'calendar_occurrence'
        and resolution.household_id = p_household_id
        and resolution.recipient_user_id = v_authenticated_user_id
        and schedule.scheduled_at > pg_catalog.statement_timestamp()
        and not exists (
          select 1
          from app_private.notification_inbox_evaluations as inbox_evaluation
          where inbox_evaluation.source_event_id = resolution.source_event_id
        )
        and not exists (
          select 1
          from app_private.notification_push_evaluations as push_evaluation
          where push_evaluation.source_event_id = resolution.source_event_id
            and push_evaluation.processing_status <> 'pending'
        )
      for update of resolution
    ),
    updated_resolution as (
      update app_private.notification_event_resolutions as resolution
      set scheduled_at = eligible.reminder_at
      from eligible_resolution as eligible
      where resolution.source_event_id = eligible.source_event_id
      returning resolution.source_event_id, resolution.scheduled_at
    )
    update app_private.notification_push_evaluations as evaluation
    set next_evaluation_at = updated.scheduled_at
    from updated_resolution as updated
    where evaluation.source_event_id = updated.source_event_id
      and evaluation.processing_status = 'pending';
  end if;

  return query
  select
    v_result.household_id,
    v_result.category,
    v_result.native_push,
    v_result.web_push,
    v_result.email,
    v_result.in_app,
    v_result.quiet_start,
    v_result.quiet_end,
    v_result.timezone,
    v_result.reminder_lead_minutes,
    v_result.updated_at,
    v_result.version,
    false;
end;
$$;

revoke all on function public.get_notification_preferences_v2(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.update_notification_preference_v2(
  uuid,
  text,
  boolean,
  boolean,
  boolean,
  boolean,
  time without time zone,
  time without time zone,
  text,
  integer,
  bigint
) from public, anon, authenticated, service_role;
grant execute on function public.get_notification_preferences_v2(uuid)
  to authenticated;
grant execute on function public.update_notification_preference_v2(
  uuid,
  text,
  boolean,
  boolean,
  boolean,
  boolean,
  time without time zone,
  time without time zone,
  text,
  integer,
  bigint
) to authenticated;

comment on column public.notification_preferences.reminder_lead_minutes is
  'WP05-11 per-user Calendar reminder lead in minutes; non-Calendar categories remain zero.';
comment on function app_private.calendar_notification_lead_minutes(uuid, uuid) is
  'Returns the exact active audience member Calendar lead preference or the zero-minute default.';
comment on function app_private.calendar_notification_reminder_at(uuid, uuid, uuid, uuid) is
  'Resolves lead-adjusted Calendar reminder time while freezing schedules after inbox or terminal push evaluation.';
comment on function public.get_notification_preferences_v2(uuid) is
  'Returns exact self-scoped notification preference rows including Calendar reminder lead time.';
comment on function public.update_notification_preference_v2(
  uuid,
  text,
  boolean,
  boolean,
  boolean,
  boolean,
  time without time zone,
  time without time zone,
  text,
  integer,
  bigint
) is
  'Updates one self-scoped preference with optimistic concurrency and reschedules unevaluated future Calendar reminders.';
