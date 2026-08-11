-- KinFlow WP05-02 notification preferences, quiet hours, and durable inbox.
-- Inbox persistence is independent from provider delivery. Quiet hours only
-- calculate the earliest future delivery instant for later push work.

create table public.notification_preferences (
  auth_user_id uuid not null
    references auth.users(id) on delete cascade,
  household_id uuid not null
    references public.households(id) on delete cascade,
  category text not null check (
    category in ('chore_due', 'chore_assignment')
  ),
  native_push boolean not null default true,
  web_push boolean not null default false,
  email boolean not null default false,
  in_app boolean not null default true,
  quiet_start time without time zone,
  quiet_end time without time zone,
  timezone text not null check (
    app_private.is_valid_iana_timezone(timezone)
  ),
  updated_at timestamptz not null default pg_catalog.now(),
  version bigint not null default 1 check (version > 0),
  primary key (auth_user_id, household_id, category),
  constraint notification_preferences_quiet_hours_ck check (
    (
      quiet_start is null
      and quiet_end is null
    )
    or (
      quiet_start is not null
      and quiet_end is not null
      and quiet_start <> quiet_end
      and extract(second from quiet_start) = 0
      and extract(second from quiet_end) = 0
    )
  )
);

create trigger notification_preferences_set_updated_at_and_version
before update on public.notification_preferences
for each row execute function app_private.set_updated_at_and_version();

create table public.notification_inbox_items (
  id uuid primary key default extensions.gen_random_uuid(),
  item_version bigint not null default 1 check (item_version > 0),
  source_event_id uuid not null
    references app_private.notification_event_resolutions(source_event_id)
    on delete cascade,
  source_aggregate_version bigint not null check (
    source_aggregate_version > 0
  ),
  recipient_user_id uuid not null
    references auth.users(id) on delete cascade,
  recipient_member_id uuid not null,
  household_id uuid not null
    references public.households(id) on delete cascade,
  category text not null check (
    category in ('chore_due', 'chore_assignment')
  ),
  subject_type text not null check (subject_type = 'chore_occurrence'),
  subject_id uuid not null,
  scheduled_at timestamptz not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  read_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text check (
    cancellation_reason is null
    or cancellation_reason in ('superseded', 'state_inactive')
  ),
  payload jsonb not null,
  unique (recipient_user_id, source_event_id, category),
  constraint notification_inbox_recipient_fk
    foreign key (household_id, recipient_member_id, recipient_user_id)
    references public.household_members(household_id, id, auth_user_id),
  constraint notification_inbox_subject_fk
    foreign key (household_id, subject_id)
    references public.chore_occurrences(household_id, id)
    on delete cascade,
  constraint notification_inbox_payload_ck check (
    jsonb_typeof(payload) = 'object'
    and payload ?& array['householdId', 'occurrenceId']
    and payload - array['householdId', 'occurrenceId'] = '{}'::jsonb
    and jsonb_typeof(payload->'householdId') = 'string'
    and payload->>'householdId' = household_id::text
    and jsonb_typeof(payload->'occurrenceId') = 'string'
    and payload->>'occurrenceId' = subject_id::text
  ),
  constraint notification_inbox_timestamps_ck check (
    updated_at >= created_at
    and (read_at is null or read_at >= created_at)
    and (cancelled_at is null or cancelled_at >= created_at)
  ),
  constraint notification_inbox_cancellation_ck check (
    (cancelled_at is null) = (cancellation_reason is null)
  )
);

create index notification_inbox_recipient_page_idx
  on public.notification_inbox_items(
    recipient_user_id,
    household_id,
    created_at desc,
    id desc
  )
  where cancelled_at is null;

create index notification_inbox_recipient_unread_idx
  on public.notification_inbox_items(recipient_user_id, household_id)
  where read_at is null and cancelled_at is null;

create index notification_inbox_subject_active_idx
  on public.notification_inbox_items(
    household_id,
    category,
    subject_type,
    subject_id,
    source_aggregate_version
  )
  where cancelled_at is null;

create table app_private.notification_inbox_evaluations (
  source_event_id uuid primary key
    references app_private.notification_event_resolutions(source_event_id)
    on delete cascade,
  outcome text not null check (
    outcome in ('created', 'disabled', 'stale', 'suppressed')
  ),
  inbox_item_id uuid
    references public.notification_inbox_items(id),
  preference_version bigint check (preference_version >= 0),
  delivery_not_before timestamptz,
  quiet_applied boolean,
  reason_code text check (
    reason_code is null
    or reason_code in (
      'CATEGORY_DISABLED',
      'LATEST_STATE_SUPPRESSED',
      'SOURCE_SUPPRESSED'
    )
  ),
  evaluated_at timestamptz not null,
  constraint notification_inbox_evaluation_outcome_ck check (
    (
      outcome = 'created'
      and inbox_item_id is not null
      and preference_version is not null
      and delivery_not_before is not null
      and quiet_applied is not null
      and reason_code is null
    )
    or (
      outcome = 'disabled'
      and inbox_item_id is null
      and preference_version is not null
      and delivery_not_before is null
      and quiet_applied is null
      and reason_code = 'CATEGORY_DISABLED'
    )
    or (
      outcome = 'stale'
      and inbox_item_id is null
      and preference_version is null
      and delivery_not_before is null
      and quiet_applied is null
      and reason_code = 'LATEST_STATE_SUPPRESSED'
    )
    or (
      outcome = 'suppressed'
      and inbox_item_id is null
      and preference_version is null
      and delivery_not_before is null
      and quiet_applied is null
      and reason_code = 'SOURCE_SUPPRESSED'
    )
  )
);

revoke all on table app_private.notification_inbox_evaluations
  from public, anon, authenticated, service_role;

create or replace function app_private.protect_notification_inbox_item()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id is distinct from old.id
    or new.source_event_id is distinct from old.source_event_id
    or new.source_aggregate_version is distinct from old.source_aggregate_version
    or new.recipient_user_id is distinct from old.recipient_user_id
    or new.recipient_member_id is distinct from old.recipient_member_id
    or new.household_id is distinct from old.household_id
    or new.category is distinct from old.category
    or new.subject_type is distinct from old.subject_type
    or new.subject_id is distinct from old.subject_id
    or new.scheduled_at is distinct from old.scheduled_at
    or new.created_at is distinct from old.created_at
    or new.payload is distinct from old.payload
    or old.read_at is not null and new.read_at is distinct from old.read_at
    or old.cancelled_at is not null
      and new.cancelled_at is distinct from old.cancelled_at
    or old.cancellation_reason is not null
      and new.cancellation_reason is distinct from old.cancellation_reason
    or old.cancelled_at is null and new.cancelled_at is null
      and new.cancellation_reason is not null then
    raise exception using
      errcode = '55000',
      message = 'notification inbox envelope or transition is invalid';
  end if;

  new.item_version := old.item_version + 1;
  new.updated_at := pg_catalog.statement_timestamp();
  return new;
end;
$$;

revoke all on function app_private.protect_notification_inbox_item()
  from public, anon, authenticated, service_role;

create trigger notification_inbox_items_protect
before update on public.notification_inbox_items
for each row execute function app_private.protect_notification_inbox_item();

create or replace function app_private.reject_notification_inbox_evaluation_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'notification inbox evaluations are immutable';
end;
$$;

revoke all on function app_private.reject_notification_inbox_evaluation_mutation()
  from public, anon, authenticated, service_role;

create trigger notification_inbox_evaluations_immutable
before update or delete on app_private.notification_inbox_evaluations
for each row execute function
  app_private.reject_notification_inbox_evaluation_mutation();

create or replace function app_private.resolve_notification_delivery_not_before(
  p_reference_at timestamptz,
  p_quiet_start time without time zone,
  p_quiet_end time without time zone,
  p_timezone text
)
returns table (
  delivery_not_before timestamptz,
  quiet_applied boolean,
  dst_resolution text
)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_local_timestamp timestamp without time zone;
  v_local_date date;
  v_local_time time without time zone;
  v_quiet_end_date date;
  v_quiet_end_local timestamp without time zone;
  v_candidate_count integer;
  v_resolved_at timestamptz;
begin
  if p_reference_at is null
    or p_timezone is null
    or not app_private.is_valid_iana_timezone(p_timezone)
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

  if p_quiet_start is null then
    return query select p_reference_at, false, 'not_applicable'::text;
    return;
  end if;

  v_local_timestamp := p_reference_at at time zone p_timezone;
  v_local_date := v_local_timestamp::date;
  v_local_time := v_local_timestamp::time;

  if p_quiet_start < p_quiet_end then
    if not (v_local_time >= p_quiet_start and v_local_time < p_quiet_end) then
      return query select p_reference_at, false, 'not_applicable'::text;
      return;
    end if;
    v_quiet_end_date := v_local_date;
  else
    if not (v_local_time >= p_quiet_start or v_local_time < p_quiet_end) then
      return query select p_reference_at, false, 'not_applicable'::text;
      return;
    end if;
    v_quiet_end_date := case
      when v_local_time >= p_quiet_start then v_local_date + 1
      else v_local_date
    end;
  end if;

  v_quiet_end_local := v_quiet_end_date + p_quiet_end;

  select
    pg_catalog.count(*)::integer,
    pg_catalog.max(candidate.instant)
  into v_candidate_count, v_resolved_at
  from pg_catalog.generate_series(
    v_quiet_end_local at time zone 'UTC' - interval '16 hours',
    v_quiet_end_local at time zone 'UTC' + interval '16 hours',
    interval '1 minute'
  ) as candidate(instant)
  where candidate.instant at time zone p_timezone = v_quiet_end_local;

  if v_candidate_count = 0 then
    select candidate.instant
    into v_resolved_at
    from pg_catalog.generate_series(
      v_quiet_end_local at time zone 'UTC' - interval '16 hours',
      v_quiet_end_local at time zone 'UTC' + interval '16 hours',
      interval '1 minute'
    ) as candidate(instant)
    where candidate.instant at time zone p_timezone > v_quiet_end_local
      and candidate.instant at time zone p_timezone
        <= v_quiet_end_local + interval '4 hours'
    order by
      candidate.instant at time zone p_timezone,
      candidate.instant desc
    limit 1;

    if v_resolved_at is null then
      raise exception using
        errcode = 'KNP07',
        message = 'notification quiet end could not be resolved';
    end if;

    return query select v_resolved_at, true, 'gap_forward'::text;
    return;
  end if;

  return query
  select
    v_resolved_at,
    true,
    case
      when v_candidate_count = 1 then 'normal'
      else 'overlap_later'
    end;
end;
$$;

revoke all on function app_private.resolve_notification_delivery_not_before(
  timestamptz,
  time without time zone,
  time without time zone,
  text
) from public, anon, authenticated, service_role;

alter table public.notification_preferences enable row level security;
alter table public.notification_preferences force row level security;
alter table public.notification_inbox_items enable row level security;
alter table public.notification_inbox_items force row level security;

create policy notification_preferences_select_self
on public.notification_preferences
for select
to authenticated
using (
  auth_user_id = (select auth.uid())
  and app_private.is_active_household_member(household_id)
);

create policy notification_inbox_select_recipient
on public.notification_inbox_items
for select
to authenticated
using (
  recipient_user_id = (select auth.uid())
  and app_private.is_active_household_member(household_id)
);

revoke all on table public.notification_preferences
  from public, anon, authenticated, service_role;
revoke all on table public.notification_inbox_items
  from public, anon, authenticated, service_role;
grant select on table public.notification_preferences to authenticated;
grant select on table public.notification_inbox_items to authenticated;

create or replace function public.get_notification_preferences(
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
    values ('chore_due'::text), ('chore_assignment'::text)
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

create or replace function public.update_notification_preference(
  p_household_id uuid,
  p_category text,
  p_native_push boolean,
  p_web_push boolean,
  p_email boolean,
  p_in_app boolean,
  p_quiet_start time without time zone,
  p_quiet_end time without time zone,
  p_timezone text,
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
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KNP02',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or p_category is null
    or p_category not in ('chore_due', 'chore_assignment')
    or p_native_push is null
    or p_web_push is null
    or p_email is null
    or p_in_app is null
    or p_timezone is null
    or not app_private.is_valid_iana_timezone(p_timezone)
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
      timezone
    )
    values (
      v_authenticated_user_id,
      p_household_id,
      p_category,
      p_native_push,
      p_web_push,
      p_email,
      p_in_app,
      p_quiet_start,
      p_quiet_end,
      p_timezone
    )
    returning * into v_result;
  elsif v_existing.native_push = p_native_push
    and v_existing.web_push = p_web_push
    and v_existing.email = p_email
    and v_existing.in_app = p_in_app
    and v_existing.quiet_start is not distinct from p_quiet_start
    and v_existing.quiet_end is not distinct from p_quiet_end
    and v_existing.timezone = p_timezone then
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
        timezone = p_timezone
    where preference.auth_user_id = v_authenticated_user_id
      and preference.household_id = p_household_id
      and preference.category = p_category
    returning * into v_result;
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
    v_result.updated_at,
    v_result.version,
    false;
end;
$$;

create or replace function public.list_notification_inbox_items(
  p_household_id uuid,
  p_limit integer default 30,
  p_before_created_at timestamptz default null,
  p_before_id uuid default null
)
returns table (
  inbox_item_id uuid,
  item_version bigint,
  source_event_id uuid,
  household_id uuid,
  category text,
  subject_type text,
  subject_id uuid,
  scheduled_at timestamptz,
  created_at timestamptz,
  read_at timestamptz,
  payload jsonb,
  has_more boolean,
  next_before_created_at timestamptz,
  next_before_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KNP02',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or p_limit is null
    or p_limit not between 1 and 100
    or (p_before_created_at is null) <> (p_before_id is null) then
    raise exception using
      errcode = 'KNP01',
      message = 'invalid notification inbox query';
  end if;

  if not app_private.is_active_household_member(p_household_id) then
    raise exception using
      errcode = 'KNP03',
      message = 'notification household not found or forbidden';
  end if;

  return query
  with fetched as (
    select item.*
    from public.notification_inbox_items as item
    where item.household_id = p_household_id
      and item.recipient_user_id = v_authenticated_user_id
      and item.cancelled_at is null
      and (
        p_before_created_at is null
        or (item.created_at, item.id) < (p_before_created_at, p_before_id)
      )
    order by item.created_at desc, item.id desc
    limit p_limit + 1
  ), page as (
    select fetched.*
    from fetched
    order by fetched.created_at desc, fetched.id desc
    limit p_limit
  ), metadata as (
    select count(*) > p_limit as has_more
    from fetched
  )
  select
    page.id,
    page.item_version,
    page.source_event_id,
    page.household_id,
    page.category,
    page.subject_type,
    page.subject_id,
    page.scheduled_at,
    page.created_at,
    page.read_at,
    page.payload,
    metadata.has_more,
    case when metadata.has_more then last_value.created_at else null end,
    case when metadata.has_more then last_value.id else null end
  from page
  cross join metadata
  cross join lateral (
    select tail.created_at, tail.id
    from page as tail
    order by tail.created_at, tail.id
    limit 1
  ) as last_value
  order by page.created_at desc, page.id desc;
end;
$$;

create or replace function public.get_notification_unread_count(
  p_household_id uuid
)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_count integer;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KNP02',
      message = 'authentication required';
  end if;

  if p_household_id is null then
    raise exception using
      errcode = 'KNP01',
      message = 'invalid notification inbox query';
  end if;

  if not app_private.is_active_household_member(p_household_id) then
    raise exception using
      errcode = 'KNP03',
      message = 'notification household not found or forbidden';
  end if;

  select count(*)::integer
  into v_count
  from public.notification_inbox_items as item
  where item.household_id = p_household_id
    and item.recipient_user_id = v_authenticated_user_id
    and item.read_at is null
    and item.cancelled_at is null;

  return v_count;
end;
$$;

create or replace function public.mark_notification_inbox_items_read(
  p_household_id uuid,
  p_item_ids uuid[]
)
returns table (
  marked_count integer,
  unread_count integer,
  marked_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_marked_at timestamptz := pg_catalog.statement_timestamp();
  v_marked_count integer;
  v_unread_count integer;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KNP02',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or p_item_ids is null
    or pg_catalog.cardinality(p_item_ids) > 100
    or array_position(p_item_ids, null) is not null then
    raise exception using
      errcode = 'KNP01',
      message = 'invalid notification read command';
  end if;

  if not app_private.is_active_household_member(p_household_id) then
    raise exception using
      errcode = 'KNP03',
      message = 'notification household not found or forbidden';
  end if;

  update public.notification_inbox_items as item
  set read_at = v_marked_at
  where item.id = any(p_item_ids)
    and item.household_id = p_household_id
    and item.recipient_user_id = v_authenticated_user_id
    and item.read_at is null
    and item.cancelled_at is null;
  get diagnostics v_marked_count = row_count;

  select count(*)::integer
  into v_unread_count
  from public.notification_inbox_items as item
  where item.household_id = p_household_id
    and item.recipient_user_id = v_authenticated_user_id
    and item.read_at is null
    and item.cancelled_at is null;

  return query select v_marked_count, v_unread_count, v_marked_at;
end;
$$;

create or replace function public.mark_all_notification_inbox_read(
  p_household_id uuid,
  p_through_created_at timestamptz default null
)
returns table (
  marked_count integer,
  unread_count integer,
  marked_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_marked_at timestamptz := pg_catalog.statement_timestamp();
  v_through_created_at timestamptz;
  v_marked_count integer;
  v_unread_count integer;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KNP02',
      message = 'authentication required';
  end if;

  if p_household_id is null then
    raise exception using
      errcode = 'KNP01',
      message = 'invalid notification read command';
  end if;

  if not app_private.is_active_household_member(p_household_id) then
    raise exception using
      errcode = 'KNP03',
      message = 'notification household not found or forbidden';
  end if;

  v_through_created_at := coalesce(p_through_created_at, v_marked_at);
  if v_through_created_at > v_marked_at then
    raise exception using
      errcode = 'KNP01',
      message = 'invalid notification read command';
  end if;

  update public.notification_inbox_items as item
  set read_at = v_marked_at
  where item.household_id = p_household_id
    and item.recipient_user_id = v_authenticated_user_id
    and item.created_at <= v_through_created_at
    and item.read_at is null
    and item.cancelled_at is null;
  get diagnostics v_marked_count = row_count;

  select count(*)::integer
  into v_unread_count
  from public.notification_inbox_items as item
  where item.household_id = p_household_id
    and item.recipient_user_id = v_authenticated_user_id
    and item.read_at is null
    and item.cancelled_at is null;

  return query select v_marked_count, v_unread_count, v_marked_at;
end;
$$;

create or replace function public.materialize_chore_notification_inbox(
  p_batch_size integer,
  p_as_of timestamptz
)
returns table (
  captured_at timestamptz,
  claimed_count integer,
  created_count integer,
  disabled_count integer,
  stale_count integer,
  suppressed_count integer,
  cancelled_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_resolution record;
  v_latest record;
  v_inbox_item_id uuid;
  v_preference_version bigint;
  v_in_app boolean;
  v_quiet_start time without time zone;
  v_quiet_end time without time zone;
  v_preference_timezone text;
  v_delivery record;
  v_latest_found boolean;
  v_scheduled_at timestamptz;
  v_row_count integer;
  v_claimed_count integer := 0;
  v_created_count integer := 0;
  v_disabled_count integer := 0;
  v_stale_count integer := 0;
  v_suppressed_count integer := 0;
  v_cancelled_count integer := 0;
  v_paused boolean;
begin
  if p_batch_size is null
    or p_batch_size not between 1 and 100
    or p_as_of is null then
    raise exception using
      errcode = 'KNP01',
      message = 'invalid notification materializer input';
  end if;

  select control.paused
  into v_paused
  from app_private.notification_worker_control as control
  where control.worker_key = 'chore_notification_outbox';

  if coalesce(v_paused, true) then
    return query select
      p_as_of, 0, 0, 0, 0, 0, 0;
    return;
  end if;

  for v_resolution in
    select
      resolution.*,
      event.aggregate_version as source_aggregate_version,
      event.occurred_at as source_occurred_at
    from app_private.notification_event_resolutions as resolution
    join app_private.chore_notification_outbox as event
      on event.event_id = resolution.source_event_id
    left join app_private.notification_inbox_evaluations as evaluation
      on evaluation.source_event_id = resolution.source_event_id
    where evaluation.source_event_id is null
    order by event.occurred_at, event.event_id
    for update of resolution skip locked
    limit p_batch_size
  loop
    v_claimed_count := v_claimed_count + 1;

    select latest.*
    into v_latest
    from app_private.resolve_chore_notification_event(
      v_resolution.source_event_id
    ) as latest;
    v_latest_found := found;

    update public.notification_inbox_items as item
    set cancelled_at = p_as_of,
        cancellation_reason = case
          when v_resolution.outcome = 'candidate' then 'superseded'
          else 'state_inactive'
        end
    where item.household_id = v_resolution.household_id
      and item.category = v_resolution.notification_category
      and item.subject_type = v_resolution.subject_type
      and item.subject_id = v_resolution.subject_id
      and item.source_event_id <> v_resolution.source_event_id
      and item.source_aggregate_version
        <= v_resolution.source_aggregate_version
      and item.cancelled_at is null;
    get diagnostics v_row_count = row_count;
    v_cancelled_count := v_cancelled_count + v_row_count;

    if v_resolution.outcome = 'suppressed' then
      insert into app_private.notification_inbox_evaluations (
        source_event_id,
        outcome,
        reason_code,
        evaluated_at
      ) values (
        v_resolution.source_event_id,
        'suppressed',
        'SOURCE_SUPPRESSED',
        p_as_of
      );
      v_suppressed_count := v_suppressed_count + 1;
      continue;
    end if;

    if not v_latest_found
      or not v_latest.should_create_intent
      or v_latest.household_id <> v_resolution.household_id
      or v_latest.notification_category
        <> v_resolution.notification_category
      or v_latest.occurrence_id <> v_resolution.subject_id
      or v_latest.recipient_user_id
        is distinct from v_resolution.recipient_user_id then
      insert into app_private.notification_inbox_evaluations (
        source_event_id,
        outcome,
        reason_code,
        evaluated_at
      ) values (
        v_resolution.source_event_id,
        'stale',
        'LATEST_STATE_SUPPRESSED',
        p_as_of
      );
      v_stale_count := v_stale_count + 1;
      continue;
    end if;

    select
      preference.in_app,
      preference.quiet_start,
      preference.quiet_end,
      preference.timezone,
      preference.version
    into
      v_in_app,
      v_quiet_start,
      v_quiet_end,
      v_preference_timezone,
      v_preference_version
    from public.notification_preferences as preference
    where preference.auth_user_id = v_latest.recipient_user_id
      and preference.household_id = v_latest.household_id
      and preference.category = v_latest.notification_category;

    if not found then
      v_in_app := true;
      v_quiet_start := null;
      v_quiet_end := null;
      v_preference_timezone := v_latest.timezone;
      v_preference_version := 0;
    end if;

    if not v_in_app then
      insert into app_private.notification_inbox_evaluations (
        source_event_id,
        outcome,
        preference_version,
        reason_code,
        evaluated_at
      ) values (
        v_resolution.source_event_id,
        'disabled',
        v_preference_version,
        'CATEGORY_DISABLED',
        p_as_of
      );
      v_disabled_count := v_disabled_count + 1;
      continue;
    end if;

    v_scheduled_at := case
      when v_latest.notification_category = 'chore_due'
        then v_latest.due_at
      else v_latest.event_occurred_at
    end;

    select delivery.*
    into v_delivery
    from app_private.resolve_notification_delivery_not_before(
      greatest(v_scheduled_at, p_as_of),
      v_quiet_start,
      v_quiet_end,
      v_preference_timezone
    ) as delivery;

    insert into public.notification_inbox_items (
      source_event_id,
      source_aggregate_version,
      recipient_user_id,
      recipient_member_id,
      household_id,
      category,
      subject_type,
      subject_id,
      scheduled_at,
      created_at,
      updated_at,
      payload
    ) values (
      v_resolution.source_event_id,
      v_resolution.source_aggregate_version,
      v_latest.recipient_user_id,
      v_latest.recipient_member_id,
      v_latest.household_id,
      v_latest.notification_category,
      'chore_occurrence',
      v_latest.occurrence_id,
      v_scheduled_at,
      p_as_of,
      p_as_of,
      pg_catalog.jsonb_build_object(
        'householdId', v_latest.household_id,
        'occurrenceId', v_latest.occurrence_id
      )
    )
    returning id into v_inbox_item_id;

    insert into app_private.notification_inbox_evaluations (
      source_event_id,
      outcome,
      inbox_item_id,
      preference_version,
      delivery_not_before,
      quiet_applied,
      evaluated_at
    ) values (
      v_resolution.source_event_id,
      'created',
      v_inbox_item_id,
      v_preference_version,
      v_delivery.delivery_not_before,
      v_delivery.quiet_applied,
      p_as_of
    );
    v_created_count := v_created_count + 1;
  end loop;

  return query select
    p_as_of,
    v_claimed_count,
    v_created_count,
    v_disabled_count,
    v_stale_count,
    v_suppressed_count,
    v_cancelled_count;
end;
$$;

revoke all on function public.get_notification_preferences(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.update_notification_preference(
  uuid,
  text,
  boolean,
  boolean,
  boolean,
  boolean,
  time without time zone,
  time without time zone,
  text,
  bigint
) from public, anon, authenticated, service_role;
revoke all on function public.list_notification_inbox_items(
  uuid,
  integer,
  timestamptz,
  uuid
) from public, anon, authenticated, service_role;
revoke all on function public.get_notification_unread_count(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.mark_notification_inbox_items_read(uuid, uuid[])
  from public, anon, authenticated, service_role;
revoke all on function public.mark_all_notification_inbox_read(
  uuid,
  timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.materialize_chore_notification_inbox(
  integer,
  timestamptz
) from public, anon, authenticated, service_role;

grant execute on function public.get_notification_preferences(uuid)
  to authenticated;
grant execute on function public.update_notification_preference(
  uuid,
  text,
  boolean,
  boolean,
  boolean,
  boolean,
  time without time zone,
  time without time zone,
  text,
  bigint
) to authenticated;
grant execute on function public.list_notification_inbox_items(
  uuid,
  integer,
  timestamptz,
  uuid
) to authenticated;
grant execute on function public.get_notification_unread_count(uuid)
  to authenticated;
grant execute on function public.mark_notification_inbox_items_read(uuid, uuid[])
  to authenticated;
grant execute on function public.mark_all_notification_inbox_read(
  uuid,
  timestamptz
) to authenticated;
grant execute on function public.materialize_chore_notification_inbox(
  integer,
  timestamptz
) to service_role;

comment on table public.notification_preferences is
  'WP05-02 per-user, per-household, per-category channel and quiet-hour settings.';
comment on table public.notification_inbox_items is
  'WP05-02 durable content-free in-app notification inbox; recipient read-only except mediated read commands.';
comment on table app_private.notification_inbox_evaluations is
  'WP05-02 immutable source-event materialization outcome and future-delivery timing snapshot.';
comment on function app_private.resolve_notification_delivery_not_before(
  timestamptz,
  time without time zone,
  time without time zone,
  text
) is
  'WP05-02 quiet-hours resolver: DST gaps advance to the first valid minute and overlaps choose the later instant.';
