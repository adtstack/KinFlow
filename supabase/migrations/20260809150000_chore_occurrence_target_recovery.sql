-- KinFlow WP05-08 authenticated Chore occurrence target recovery.
-- A target read is authoritative and never falls back to a client cache.

create function public.get_chore_occurrence_target(
  p_household_id uuid,
  p_occurrence_id uuid
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
  v_actor_role public.household_role;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFC01',
      message = 'authentication required';
  end if;

  if p_household_id is null or p_occurrence_id is null then
    raise exception using
      errcode = 'KFC02',
      message = 'invalid chore input';
  end if;

  select caller.role
  into v_actor_role
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

  return query
  select
    occurrence.household_id,
    series.id,
    occurrence.id,
    display_revision.title,
    display_revision.description,
    occurrence.assignee_member_id,
    assignee.display_name,
    occurrence.due_local_date,
    case
      when occurrence.due_at is null then null
      else (occurrence.due_at at time zone occurrence.timezone)::time
    end,
    occurrence.due_at,
    occurrence.status::text,
    occurrence.version,
    case
      when display_revision.recurrence_rule->>'frequency' in (
        'daily', 'weekly', 'monthly'
      ) then display_revision.recurrence_rule->>'frequency'
      else null
    end,
    series.version,
    case
      when occurrence.status = 'scheduled' and series.deleted_at is null
        then active_revision.default_assignee_member_id
      else display_revision.default_assignee_member_id
    end,
    case
      when occurrence.status = 'scheduled' and series.deleted_at is null
        then active_revision.due_local_time
      else display_revision.due_local_time
    end,
    case
      when occurrence.status = 'scheduled'
        and series.deleted_at is null
        and active_revision.recurrence_rule <> '{"type":"once"}'::jsonb
        then active_revision.recurrence_rule
      when (
        occurrence.status <> 'scheduled'
        or series.deleted_at is not null
      ) and display_revision.recurrence_rule <> '{"type":"once"}'::jsonb
        then display_revision.recurrence_rule
      else null
    end,
    (
      v_actor_role in ('owner', 'admin')
      and occurrence.status = 'scheduled'
      and series.deleted_at is null
      and active_revision.recurrence_rule <> '{"type":"once"}'::jsonb
    )
  from public.chore_occurrences as occurrence
  join public.chore_series as series
    on series.household_id = occurrence.household_id
   and series.id = occurrence.series_id
  join public.chore_series_revisions as display_revision
    on display_revision.household_id = occurrence.household_id
   and display_revision.id = occurrence.revision_id
  join public.chore_series_revisions as active_revision
    on active_revision.household_id = series.household_id
   and active_revision.id = series.active_revision_id
  join public.household_members as assignee
    on assignee.household_id = occurrence.household_id
   and assignee.id = occurrence.assignee_member_id
  where occurrence.household_id = p_household_id
    and occurrence.id = p_occurrence_id
    and occurrence.status in ('scheduled', 'completed')
    and (
      occurrence.status = 'completed'
      or series.deleted_at is null
    );

  if not found then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;
end;
$$;

revoke all on function public.get_chore_occurrence_target(
  uuid,
  uuid
) from public, anon, authenticated, service_role;
grant execute on function public.get_chore_occurrence_target(
  uuid,
  uuid
) to authenticated;

comment on function public.get_chore_occurrence_target(uuid, uuid) is
  'WP05-08 active-member authoritative Chore occurrence target projection.';

create or replace function public.resolve_notification_push_target(
  p_delivery_id uuid,
  p_household_id uuid,
  p_subject_id uuid
)
returns table (
  delivery_id uuid,
  household_id uuid,
  category text,
  subject_type text,
  subject_id uuid,
  inbox_item_id uuid,
  safe_destination text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_delivery app_private.notification_push_deliveries%rowtype;
  v_latest record;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KPS02',
      message = 'authentication required';
  end if;
  if p_delivery_id is null
    or p_household_id is null
    or p_subject_id is null then
    raise exception using
      errcode = 'KPS01',
      message = 'invalid notification push input';
  end if;

  select delivery.*
  into v_delivery
  from app_private.notification_push_deliveries as delivery
  where delivery.id = p_delivery_id
    and delivery.recipient_user_id = v_authenticated_user_id
    and delivery.household_id = p_household_id
    and delivery.subject_id = p_subject_id
    and delivery.processing_status in ('leased', 'retry_wait', 'succeeded')
    and app_private.is_active_household_member(delivery.household_id);

  if not found then
    return;
  end if;

  select latest.*
  into v_latest
  from app_private.resolve_notification_event(
    v_delivery.source_event_id
  ) as latest;

  if not found
    or not v_latest.should_create_intent
    or v_latest.recipient_user_id <> v_authenticated_user_id
    or v_latest.household_id <> v_delivery.household_id
    or v_latest.notification_category <> v_delivery.category
    or v_latest.subject_type <> v_delivery.subject_type
    or v_latest.occurrence_id <> v_delivery.subject_id
    or v_delivery.inbox_item_id is not null and not exists (
      select 1
      from public.notification_inbox_items as item
      where item.id = v_delivery.inbox_item_id
        and item.recipient_user_id = v_authenticated_user_id
        and item.household_id = v_delivery.household_id
        and item.category = v_delivery.category
        and item.subject_type = v_delivery.subject_type
        and item.subject_id = v_delivery.subject_id
        and item.cancelled_at is null
    ) then
    return;
  end if;

  return query select
    v_delivery.id,
    v_delivery.household_id,
    v_delivery.category,
    v_delivery.subject_type,
    v_delivery.subject_id,
    v_delivery.inbox_item_id,
    case v_delivery.subject_type
      when 'chore_occurrence' then 'chore_occurrence'::text
      when 'calendar_occurrence' then 'calendar_event'::text
    end;
end;
$$;

revoke all on function public.resolve_notification_push_target(
  uuid,
  uuid,
  uuid
) from public, anon, authenticated, service_role;
grant execute on function public.resolve_notification_push_target(
  uuid,
  uuid,
  uuid
) to authenticated;

comment on function public.resolve_notification_push_target(uuid, uuid, uuid)
  is 'WP05-08 latest-state notification target with subject-specific safe destination.';
