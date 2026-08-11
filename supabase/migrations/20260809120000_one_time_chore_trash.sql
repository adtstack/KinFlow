-- KinFlow WP03-13 scheduled one-time chore trash and restore lifecycle.
--
-- Existing WP03-09 soft-deleted rows remain the authority. This migration
-- adds an active-member trash projection and an idempotent forward restore;
-- it does not expose direct mutation or physically delete preserved history.

create index chore_series_deleted_list_idx
  on public.chore_series(household_id, deleted_at desc, id desc)
  where deleted_at is not null;

alter table public.one_time_chore_change_events
  drop constraint one_time_chore_change_events_operation_check,
  drop constraint one_time_chore_change_event_shape_ck,
  drop constraint one_time_chore_change_new_time_ck;

alter table public.one_time_chore_change_events
  add constraint one_time_chore_change_events_operation_check check (
    operation in ('updated', 'deleted', 'restored')
  ),
  add constraint one_time_chore_change_event_shape_ck check (
    (
      operation = 'updated'
      and new_revision_id is not null
      and new_due_local_date is not null
      and new_assignee_member_id is not null
    )
    or (
      operation = 'deleted'
      and new_revision_id is null
      and new_due_local_date is null
      and new_due_local_time is null
      and new_due_at is null
      and new_assignee_member_id is null
    )
    or (
      operation = 'restored'
      and new_revision_id = previous_revision_id
      and new_due_local_date = previous_due_local_date
      and new_due_local_time is not distinct from previous_due_local_time
      and new_due_at is not distinct from previous_due_at
      and new_assignee_member_id = previous_assignee_member_id
    )
  ),
  add constraint one_time_chore_change_new_time_ck check (
    operation = 'deleted'
    or (new_due_local_time is null) = (new_due_at is null)
  );

alter table app_private.one_time_chore_change_command_requests
  drop constraint one_time_chore_change_command_requests_operation_check;

alter table app_private.one_time_chore_change_command_requests
  add constraint one_time_chore_change_command_requests_operation_check check (
    operation in ('updated', 'deleted', 'restored')
  );

create or replace function public.get_deleted_one_time_chores(
  p_household_id uuid,
  p_limit integer default 30,
  p_before_cursor text default null
)
returns table (
  household_id uuid,
  household_timezone text,
  generated_at timestamptz,
  page_limit integer,
  has_more boolean,
  page_cursor text,
  occurrence_id uuid,
  series_id uuid,
  title text,
  description text,
  assignee_member_id uuid,
  assignee_display_name text,
  due_local_date date,
  due_local_time time without time zone,
  due_at timestamptz,
  deleted_at timestamptz,
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
  v_timezone text;
  v_generated_at timestamptz := pg_catalog.statement_timestamp();
  v_cursor_json jsonb;
  v_cursor_deleted_at timestamptz;
  v_cursor_series_id uuid;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFC01',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or p_limit is null
    or p_limit not between 1 and 100
    or p_before_cursor is not null
       and (
         pg_catalog.char_length(p_before_cursor) not between 2 and 1000
         or pg_catalog.char_length(p_before_cursor) % 2 <> 0
         or p_before_cursor !~ '^[0-9a-f]+$'
       ) then
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

  if p_before_cursor is not null then
    begin
      v_cursor_json := pg_catalog.convert_from(
        pg_catalog.decode(p_before_cursor, 'hex'),
        'UTF8'
      )::jsonb;

      if pg_catalog.jsonb_typeof(v_cursor_json) <> 'object'
        or (
          select pg_catalog.count(*)
          from pg_catalog.jsonb_object_keys(v_cursor_json)
        ) <> 3
        or not v_cursor_json ?& array['v', 'deleted_at', 'series_id']
        or pg_catalog.jsonb_typeof(v_cursor_json->'v') <> 'number'
        or (v_cursor_json->>'v')::integer <> 1
        or pg_catalog.jsonb_typeof(v_cursor_json->'deleted_at') <> 'string'
        or pg_catalog.jsonb_typeof(v_cursor_json->'series_id') <> 'string' then
        raise exception using
          errcode = 'KFC02',
          message = 'invalid chore input';
      end if;

      v_cursor_deleted_at := (v_cursor_json->>'deleted_at')::timestamptz;
      v_cursor_series_id := (v_cursor_json->>'series_id')::uuid;
    exception
      when sqlstate 'KFC02' then
        raise;
      when others then
        raise exception using
          errcode = 'KFC02',
          message = 'invalid chore input';
    end;
  end if;

  return query
  with candidate as materialized (
    select
      occurrence.id as occurrence_id,
      series.id as series_id,
      revision.title,
      revision.description,
      occurrence.assignee_member_id,
      assignee.display_name as assignee_display_name,
      occurrence.due_local_date,
      revision.due_local_time,
      occurrence.due_at,
      series.deleted_at,
      series.version as series_version,
      occurrence.version as occurrence_version
    from public.chore_series as series
    join public.chore_series_revisions as revision
      on revision.household_id = series.household_id
     and revision.series_id = series.id
     and revision.id = series.active_revision_id
    join public.chore_occurrences as occurrence
      on occurrence.household_id = series.household_id
     and occurrence.series_id = series.id
     and occurrence.revision_id = revision.id
    join public.household_members as assignee
      on assignee.household_id = occurrence.household_id
     and assignee.id = occurrence.assignee_member_id
    where series.household_id = p_household_id
      and series.deleted_at is not null
      and revision.recurrence_rule = '{"type":"once"}'::jsonb
      and occurrence.status = 'cancelled'
      and (
        p_before_cursor is null
        or series.deleted_at < v_cursor_deleted_at
        or series.deleted_at = v_cursor_deleted_at
           and series.id < v_cursor_series_id
      )
    order by series.deleted_at desc, series.id desc
    limit p_limit + 1
  ),
  ranked_page as materialized (
    select
      candidate.*,
      pg_catalog.row_number() over (
        order by candidate.deleted_at desc, candidate.series_id desc
      ) as page_rank
    from candidate
  ),
  metadata as (
    select
      pg_catalog.count(*) > p_limit as has_more,
      case
        when pg_catalog.count(*) > p_limit then (
          select pg_catalog.encode(
            pg_catalog.convert_to(
              pg_catalog.jsonb_build_object(
                'v', 1,
                'deleted_at', cursor_item.deleted_at,
                'series_id', cursor_item.series_id
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
    v_timezone,
    v_generated_at,
    p_limit,
    metadata.has_more,
    metadata.page_cursor,
    item.occurrence_id,
    item.series_id,
    item.title,
    item.description,
    item.assignee_member_id,
    item.assignee_display_name,
    item.due_local_date,
    item.due_local_time,
    item.due_at,
    item.deleted_at,
    item.series_version,
    item.occurrence_version
  from metadata
  left join ranked_page as item
    on item.page_rank <= p_limit
  order by item.page_rank nulls first;
end;
$$;

revoke all on function public.get_deleted_one_time_chores(
  uuid,
  integer,
  text
) from public, anon, authenticated;
grant execute on function public.get_deleted_one_time_chores(
  uuid,
  integer,
  text
) to authenticated;

create or replace function public.restore_one_time_chore(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_occurrence_id uuid,
  p_expected_series_version bigint,
  p_expected_occurrence_version bigint
)
returns table (
  household_id uuid,
  series_id uuid,
  occurrence_id uuid,
  status text,
  series_version bigint,
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
  v_revision_id uuid;
  v_recurrence_rule jsonb;
  v_due_local_date date;
  v_due_local_time time without time zone;
  v_due_at timestamptz;
  v_assignee_member_id uuid;
  v_current_series_version bigint;
  v_current_occurrence_version bigint;
  v_current_status public.occurrence_status;
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_result_event_id uuid;
  v_result_series_version bigint;
  v_result_occurrence_version bigint;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFC01',
      message = 'authentication required';
  end if;

  if p_idempotency_key is null
    or p_household_id is null
    or p_series_id is null
    or p_occurrence_id is null
    or p_expected_series_version is null
    or p_expected_series_version < 1
    or p_expected_occurrence_version is null
    or p_expected_occurrence_version < 1 then
    raise exception using
      errcode = 'KFC02',
      message = 'invalid chore input';
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
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  v_request_hash := extensions.digest(
    pg_catalog.convert_to(
      pg_catalog.jsonb_build_object(
        'operation', 'restore_one_time_chore',
        'household_id', p_household_id,
        'series_id', p_series_id,
        'occurrence_id', p_occurrence_id,
        'expected_series_version', p_expected_series_version,
        'expected_occurrence_version', p_expected_occurrence_version
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_authenticated_user_id::text
        || ':one-time-chore-change:'
        || p_idempotency_key::text,
      0
    )
  );

  select request.request_hash, request.result_event_id
  into v_existing_request_hash, v_result_event_id
  from app_private.one_time_chore_change_command_requests as request
  where request.authenticated_user_id = v_authenticated_user_id
    and request.idempotency_key = p_idempotency_key
    and request.operation = 'restored';

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFC04',
        message = 'idempotency key reused with different chore input';
    end if;

    return query
    select
      event.household_id,
      event.series_id,
      event.occurrence_id,
      'scheduled'::text,
      event.series_version,
      event.occurrence_version,
      false
    from public.one_time_chore_change_events as event
    where event.household_id = p_household_id
      and event.id = v_result_event_id;
    return;
  end if;

  if exists (
    select 1
    from app_private.one_time_chore_change_command_requests as request
    where request.authenticated_user_id = v_authenticated_user_id
      and request.idempotency_key = p_idempotency_key
  ) then
    raise exception using
      errcode = 'KFC04',
      message = 'idempotency key reused with different chore input';
  end if;

  select
    series.version,
    revision.id,
    revision.due_local_time,
    revision.recurrence_rule,
    occurrence.due_local_date,
    occurrence.due_at,
    occurrence.assignee_member_id,
    occurrence.version,
    occurrence.status
  into
    v_current_series_version,
    v_revision_id,
    v_due_local_time,
    v_recurrence_rule,
    v_due_local_date,
    v_due_at,
    v_assignee_member_id,
    v_current_occurrence_version,
    v_current_status
  from public.chore_series as series
  join public.chore_series_revisions as revision
    on revision.household_id = series.household_id
   and revision.series_id = series.id
   and revision.id = series.active_revision_id
  join public.chore_occurrences as occurrence
    on occurrence.household_id = series.household_id
   and occurrence.series_id = series.id
   and occurrence.revision_id = revision.id
  where series.household_id = p_household_id
    and series.id = p_series_id
    and series.deleted_at is not null
    and occurrence.id = p_occurrence_id
    and exists (
      select 1
      from public.one_time_chore_change_events as deletion
      where deletion.household_id = series.household_id
        and deletion.series_id = series.id
        and deletion.occurrence_id = occurrence.id
        and deletion.operation = 'deleted'
        and deletion.series_version = series.version
        and deletion.occurrence_version = occurrence.version
    )
  for update of series, occurrence;

  if not found or v_recurrence_rule <> '{"type":"once"}'::jsonb then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  if v_current_status <> 'cancelled' then
    raise exception using
      errcode = 'KFC06',
      message = 'chore transition not allowed';
  end if;

  if v_current_series_version <> p_expected_series_version
    or v_current_occurrence_version <> p_expected_occurrence_version then
    raise exception using
      errcode = 'KFC05',
      message = 'chore version conflict';
  end if;

  if not exists (
    select 1
    from public.household_members as assignee
    where assignee.household_id = p_household_id
      and assignee.id = v_assignee_member_id
      and assignee.removed_at is null
  ) then
    raise exception using
      errcode = 'KFC06',
      message = 'chore transition not allowed';
  end if;

  update public.chore_series as series
  set deleted_at = null
  where series.household_id = p_household_id
    and series.id = p_series_id
  returning series.version into v_result_series_version;

  update public.chore_occurrences as occurrence
  set status = 'scheduled'
  where occurrence.household_id = p_household_id
    and occurrence.id = p_occurrence_id
  returning occurrence.version into v_result_occurrence_version;

  insert into public.one_time_chore_change_events (
    household_id,
    series_id,
    occurrence_id,
    operation,
    previous_revision_id,
    new_revision_id,
    previous_due_local_date,
    previous_due_local_time,
    previous_due_at,
    previous_assignee_member_id,
    new_due_local_date,
    new_due_local_time,
    new_due_at,
    new_assignee_member_id,
    actor_user_id,
    actor_member_id,
    series_version,
    occurrence_version,
    correlation_id
  ) values (
    p_household_id,
    p_series_id,
    p_occurrence_id,
    'restored',
    v_revision_id,
    v_revision_id,
    v_due_local_date,
    v_due_local_time,
    v_due_at,
    v_assignee_member_id,
    v_due_local_date,
    v_due_local_time,
    v_due_at,
    v_assignee_member_id,
    v_authenticated_user_id,
    v_actor_member_id,
    v_result_series_version,
    v_result_occurrence_version,
    p_idempotency_key
  )
  returning id into v_result_event_id;

  insert into app_private.one_time_chore_change_command_requests (
    authenticated_user_id,
    idempotency_key,
    request_hash,
    operation,
    household_id,
    series_id,
    occurrence_id,
    result_event_id
  ) values (
    v_authenticated_user_id,
    p_idempotency_key,
    v_request_hash,
    'restored',
    p_household_id,
    p_series_id,
    p_occurrence_id,
    v_result_event_id
  );

  return query select
    p_household_id,
    p_series_id,
    p_occurrence_id,
    'scheduled'::text,
    v_result_series_version,
    v_result_occurrence_version,
    true;
end;
$$;

revoke all on function public.restore_one_time_chore(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint,
  bigint
) from public, anon, authenticated;
grant execute on function public.restore_one_time_chore(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint,
  bigint
) to authenticated;

comment on function public.get_deleted_one_time_chores(uuid, integer, text) is
  'WP03-13 active-member exact-household one-time trash projection with bounded opaque pagination.';
comment on function public.restore_one_time_chore(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint,
  bigint
) is
  'WP03-13 active-member dual-version idempotent restoration of a preserved deleted one-time chore.';
