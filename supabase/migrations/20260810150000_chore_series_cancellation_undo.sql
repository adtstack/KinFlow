-- KinFlow WP03-22 immediate Undo for selected-boundary repeating chore
-- cancellation. The legacy cancellation RPC keeps its exact public shape;
-- a private metadata-only ledger makes a version-bound resume deterministic.

alter table public.chore_series_change_events
  drop constraint chore_series_change_events_operation_check,
  add constraint chore_series_change_events_operation_check check (
    operation in ('updated', 'cancelled', 'resumed')
  ),
  drop constraint chore_series_change_event_revision_shape_ck,
  add constraint chore_series_change_event_revision_shape_ck check (
    operation in ('updated', 'resumed') and new_revision_id is not null
    or operation = 'cancelled'
  );

alter table app_private.chore_series_change_command_requests
  drop constraint chore_series_change_command_requests_operation_check,
  add constraint chore_series_change_command_requests_operation_check check (
    operation in ('updated', 'cancelled', 'resumed')
  ),
  drop constraint chore_series_change_request_revision_shape_ck,
  add constraint chore_series_change_request_revision_shape_ck check (
    operation in ('updated', 'resumed') and result_revision_id is not null
    or operation = 'cancelled'
  );

create table app_private.chore_series_cancellation_undo_items (
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
  created_at timestamptz not null default statement_timestamp(),
  primary key (
    authenticated_user_id,
    cancellation_idempotency_key,
    occurrence_id
  ),
  constraint chore_series_cancellation_undo_shape_ck check (
    mutation_kind = 'cancelled_status'
      and previous_status in ('scheduled', 'skipped')
      and post_status = 'cancelled'
      and previous_revision_id = post_revision_id
    or mutation_kind = 'terminal_repoint'
      and previous_status = 'scheduled'
      and post_status = 'scheduled'
      and previous_revision_id <> post_revision_id
  ),
  constraint chore_series_cancellation_undo_request_fk
    foreign key (authenticated_user_id, cancellation_idempotency_key)
    references app_private.chore_series_change_command_requests(
      authenticated_user_id,
      idempotency_key
    ) on delete cascade,
  constraint chore_series_cancellation_undo_series_fk
    foreign key (household_id, series_id)
    references public.chore_series(household_id, id)
    on delete cascade,
  constraint chore_series_cancellation_undo_occurrence_fk
    foreign key (household_id, occurrence_id)
    references public.chore_occurrences(household_id, id)
    on delete cascade,
  constraint chore_series_cancellation_undo_previous_revision_fk
    foreign key (household_id, previous_revision_id)
    references public.chore_series_revisions(household_id, id),
  constraint chore_series_cancellation_undo_post_revision_fk
    foreign key (household_id, post_revision_id)
    references public.chore_series_revisions(household_id, id)
);

create index chore_series_cancellation_undo_series_idx
  on app_private.chore_series_cancellation_undo_items(
    household_id,
    series_id,
    cancellation_idempotency_key
  );

revoke all on table app_private.chore_series_cancellation_undo_items
  from public, anon, authenticated, service_role;

create function app_private.reject_chore_series_cancellation_undo_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'chore series cancellation undo items are immutable';
end;
$$;

revoke all on function app_private.reject_chore_series_cancellation_undo_mutation()
  from public, anon, authenticated, service_role;

create trigger chore_series_cancellation_undo_items_immutable
before update or delete on app_private.chore_series_cancellation_undo_items
for each row
execute function app_private.reject_chore_series_cancellation_undo_mutation();

-- Keep the WP03-21 implementation as a private engine so the wrapper can
-- capture exact pre-state while preserving the old public signature/result.
alter function public.cancel_repeating_chore_series_from_occurrence(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) rename to cancel_repeating_chore_series_from_occurrence_wp03_21;

alter function public.cancel_repeating_chore_series_from_occurrence_wp03_21(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) set schema app_private;

revoke all on function app_private.cancel_repeating_chore_series_from_occurrence_wp03_21(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) from public, anon, authenticated, service_role;

create function public.cancel_repeating_chore_series_from_occurrence(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_series_id uuid,
  p_effective_occurrence_id uuid,
  p_expected_version bigint
)
returns table (
  household_id uuid,
  series_id uuid,
  effective_local_date date,
  version bigint,
  cancelled_count integer,
  preserved_completed_count integer,
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
  v_effective_local_date date;
  v_terminal_source_revision_id uuid;
  v_prestate jsonb := '[]'::jsonb;
  v_result_household_id uuid;
  v_result_series_id uuid;
  v_result_effective_local_date date;
  v_result_version bigint;
  v_result_cancelled_count integer;
  v_result_preserved_completed_count integer;
  v_result_terminal_revision_id uuid;
  v_result_terminal_revision_number integer;
  v_result_changed boolean;
  v_recorded_cancelled_count integer;
begin
  if v_authenticated_user_id is not null
    and p_idempotency_key is not null then
    select exists (
      select 1
      from app_private.chore_series_change_command_requests as request
      where request.authenticated_user_id = v_authenticated_user_id
        and request.idempotency_key = p_idempotency_key
    ) into v_is_replay;
  end if;

  if not v_is_replay then
    select occurrence.recurrence_local_date
    into v_effective_local_date
    from public.chore_occurrences as occurrence
    join public.chore_series as series
      on series.household_id = occurrence.household_id
     and series.id = occurrence.series_id
     and series.active_revision_id = occurrence.revision_id
    where occurrence.household_id = p_household_id
      and occurrence.series_id = p_series_id
      and occurrence.id = p_effective_occurrence_id
      and occurrence.status = 'scheduled';

    if found then
      select occurrence.revision_id
      into v_terminal_source_revision_id
      from public.chore_occurrences as occurrence
      where occurrence.household_id = p_household_id
        and occurrence.series_id = p_series_id
        and occurrence.recurrence_local_date < v_effective_local_date
        and occurrence.status = 'scheduled'
      order by occurrence.recurrence_local_date desc, occurrence.id
      limit 1;

      select coalesce(
        jsonb_agg(
          jsonb_build_object(
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
        from public.chore_occurrences as occurrence
        where occurrence.household_id = p_household_id
          and occurrence.series_id = p_series_id
          and occurrence.recurrence_local_date >= v_effective_local_date
          and occurrence.status not in ('completed', 'cancelled')

        union all

        select
          occurrence.id,
          'terminal_repoint'::text,
          occurrence.status::text,
          occurrence.revision_id,
          occurrence.version
        from public.chore_occurrences as occurrence
        where v_terminal_source_revision_id is not null
          and occurrence.household_id = p_household_id
          and occurrence.series_id = p_series_id
          and occurrence.recurrence_local_date < v_effective_local_date
          and occurrence.revision_id = v_terminal_source_revision_id
          and occurrence.status = 'scheduled'
      ) as candidate;
    end if;
  end if;

  select engine.*
  into
    v_result_household_id,
    v_result_series_id,
    v_result_effective_local_date,
    v_result_version,
    v_result_cancelled_count,
    v_result_preserved_completed_count,
    v_result_terminal_revision_id,
    v_result_terminal_revision_number,
    v_result_changed
  from app_private.cancel_repeating_chore_series_from_occurrence_wp03_21(
    p_idempotency_key,
    p_household_id,
    p_series_id,
    p_effective_occurrence_id,
    p_expected_version
  ) as engine;

  if v_result_changed then
    insert into app_private.chore_series_cancellation_undo_items (
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
    from jsonb_to_recordset(v_prestate) as item(
      occurrence_id uuid,
      mutation_kind text,
      previous_status text,
      previous_revision_id uuid,
      previous_version bigint
    )
    join public.chore_occurrences as occurrence
      on occurrence.household_id = p_household_id
     and occurrence.series_id = p_series_id
     and occurrence.id = item.occurrence_id
    where occurrence.status is distinct from
          item.previous_status::public.occurrence_status
       or occurrence.revision_id is distinct from item.previous_revision_id;

    select count(*)::integer
    into v_recorded_cancelled_count
    from app_private.chore_series_cancellation_undo_items as item
    where item.authenticated_user_id = v_authenticated_user_id
      and item.cancellation_idempotency_key = p_idempotency_key
      and item.mutation_kind = 'cancelled_status';

    if v_recorded_cancelled_count <> v_result_cancelled_count then
      raise exception using
        errcode = 'KFC06',
        message = 'chore series transition not allowed';
    end if;
  end if;

  return query select
    v_result_household_id,
    v_result_series_id,
    v_result_effective_local_date,
    v_result_version,
    v_result_cancelled_count,
    v_result_preserved_completed_count,
    v_result_terminal_revision_id,
    v_result_terminal_revision_number,
    v_result_changed;
end;
$$;

revoke all on function public.cancel_repeating_chore_series_from_occurrence(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) from public, anon, authenticated, service_role;

grant execute on function public.cancel_repeating_chore_series_from_occurrence(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) to authenticated;

create function public.resume_repeating_chore_series_cancellation(
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
  preserved_completed_count integer,
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
  v_actor_role public.household_role;
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_result_effective_local_date date;
  v_result_version bigint;
  v_result_restored_count integer;
  v_result_preserved_completed_count integer;
  v_result_revision_id uuid;
  v_result_revision_number integer;
  v_result_event_id uuid;
  v_cancellation_version bigint;
  v_cancellation_cancelled_count integer;
  v_cancellation_terminal_revision_id uuid;
  v_source_revision_id uuid;
  v_current_series_version bigint;
  v_current_active_revision_id uuid;
  v_current_deleted_at timestamptz;
  v_source_title text;
  v_source_description text;
  v_source_effective_local_date date;
  v_source_due_local_time time without time zone;
  v_source_recurrence_rule jsonb;
  v_source_assignee_member_id uuid;
  v_recorded_cancelled_count integer;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFC01',
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
        'operation', 'resume_repeating_chore_series_cancellation',
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
        || ':chore-series-change:'
        || p_idempotency_key::text,
      0
    )
  );

  select
    request.request_hash,
    request.result_effective_local_date,
    request.result_version,
    request.result_rebuilt_count,
    request.result_preserved_completed_count,
    request.result_revision_id,
    revision.revision_number
  into
    v_existing_request_hash,
    v_result_effective_local_date,
    v_result_version,
    v_result_restored_count,
    v_result_preserved_completed_count,
    v_result_revision_id,
    v_result_revision_number
  from app_private.chore_series_change_command_requests as request
  join public.chore_series_revisions as revision
    on revision.household_id = request.household_id
   and revision.id = request.result_revision_id
  where request.authenticated_user_id = v_authenticated_user_id
    and request.idempotency_key = p_idempotency_key
    and request.operation = 'resumed';

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
      v_result_restored_count,
      v_result_preserved_completed_count,
      v_result_revision_id,
      v_result_revision_number,
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
    cancellation.result_effective_local_date,
    cancellation.result_version,
    cancellation.result_cancelled_count,
    cancellation.result_preserved_completed_count,
    cancellation.result_revision_id,
    event.previous_revision_id
  into
    v_result_effective_local_date,
    v_cancellation_version,
    v_cancellation_cancelled_count,
    v_result_preserved_completed_count,
    v_cancellation_terminal_revision_id,
    v_source_revision_id
  from app_private.chore_series_change_command_requests as cancellation
  join public.chore_series_change_events as event
    on event.household_id = cancellation.household_id
   and event.id = cancellation.result_event_id
  where cancellation.authenticated_user_id = v_authenticated_user_id
    and cancellation.idempotency_key = p_cancellation_idempotency_key
    and cancellation.operation = 'cancelled'
    and cancellation.household_id = p_household_id
    and cancellation.series_id = p_series_id;

  if not found or v_cancellation_cancelled_count < 1 then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  if v_cancellation_version <> p_expected_version then
    raise exception using
      errcode = 'KFC05',
      message = 'chore series version conflict';
  end if;

  select series.version, series.active_revision_id, series.deleted_at
  into
    v_current_series_version,
    v_current_active_revision_id,
    v_current_deleted_at
  from public.chore_series as series
  where series.household_id = p_household_id
    and series.id = p_series_id
  for update of series;

  if not found then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  if v_current_series_version <> p_expected_version then
    raise exception using
      errcode = 'KFC05',
      message = 'chore series version conflict';
  end if;

  if v_cancellation_terminal_revision_id is null and v_current_deleted_at is null
    or v_cancellation_terminal_revision_id is not null and (
      v_current_deleted_at is not null
      or v_current_active_revision_id <> v_cancellation_terminal_revision_id
    ) then
    raise exception using
      errcode = 'KFC06',
      message = 'chore series transition not allowed';
  end if;

  select
    revision.title,
    revision.description,
    revision.effective_local_date,
    revision.due_local_time,
    revision.recurrence_rule,
    revision.default_assignee_member_id
  into
    v_source_title,
    v_source_description,
    v_source_effective_local_date,
    v_source_due_local_time,
    v_source_recurrence_rule,
    v_source_assignee_member_id
  from public.chore_series_revisions as revision
  where revision.household_id = p_household_id
    and revision.series_id = p_series_id
    and revision.id = v_source_revision_id;

  if not found
    or v_source_recurrence_rule = '{"type":"once"}'::jsonb
    or not app_private.is_valid_chore_recurrence_rule(
      v_source_recurrence_rule
    ) then
    raise exception using
      errcode = 'KFC06',
      message = 'chore series transition not allowed';
  end if;

  perform 1
  from public.household_members as assignee
  where assignee.household_id = p_household_id
    and assignee.id = v_source_assignee_member_id
    and assignee.removed_at is null;

  if not found then
    raise exception using
      errcode = 'KFC06',
      message = 'chore series transition not allowed';
  end if;

  select count(*)::integer
  into v_recorded_cancelled_count
  from app_private.chore_series_cancellation_undo_items as item
  join public.chore_occurrences as occurrence
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
      errcode = 'KFC06',
      message = 'chore series transition not allowed';
  end if;

  v_result_revision_id := extensions.gen_random_uuid();
  select coalesce(max(revision.revision_number), 0) + 1
  into v_result_revision_number
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
  ) values (
    v_result_revision_id,
    p_household_id,
    p_series_id,
    v_result_revision_number,
    v_source_effective_local_date,
    v_source_due_local_time,
    v_source_recurrence_rule,
    v_source_assignee_member_id,
    v_authenticated_user_id,
    v_source_title,
    v_source_description
  );

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
    from app_private.chore_series_cancellation_undo_items as item
    join public.chore_occurrences as occurrence
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
    update public.chore_occurrences as occurrence
    set
      status = eligible.previous_status,
      revision_id = eligible.restored_revision_id
    from eligible
    where occurrence.household_id = p_household_id
      and occurrence.series_id = p_series_id
      and occurrence.id = eligible.occurrence_id
    returning eligible.mutation_kind
  )
  select count(*) filter (
    where restored.mutation_kind = 'cancelled_status'
  )::integer
  into v_result_restored_count
  from restored;

  if v_result_restored_count <> v_cancellation_cancelled_count then
    raise exception using
      errcode = 'KFC06',
      message = 'chore series transition not allowed';
  end if;

  update public.chore_series as series
  set
    title = v_source_title,
    description = v_source_description,
    active_revision_id = v_result_revision_id,
    deleted_at = null
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
  ) values (
    p_household_id,
    p_series_id,
    'resumed',
    coalesce(v_cancellation_terminal_revision_id, v_source_revision_id),
    v_result_revision_id,
    v_result_effective_local_date,
    v_authenticated_user_id,
    v_actor_member_id,
    v_result_restored_count,
    0,
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
  ) values (
    v_authenticated_user_id,
    p_idempotency_key,
    v_request_hash,
    'resumed',
    p_household_id,
    p_series_id,
    v_result_revision_id,
    v_result_effective_local_date,
    v_result_version,
    v_result_restored_count,
    0,
    v_result_preserved_completed_count,
    v_result_event_id
  );

  return query select
    p_household_id,
    p_series_id,
    v_result_effective_local_date,
    v_result_version,
    v_result_restored_count,
    v_result_preserved_completed_count,
    v_result_revision_id,
    v_result_revision_number,
    true;
end;
$$;

revoke all on function public.resume_repeating_chore_series_cancellation(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) from public, anon, authenticated, service_role;

grant execute on function public.resume_repeating_chore_series_cancellation(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) to authenticated;

comment on table app_private.chore_series_cancellation_undo_items is
  'WP03-22 immutable metadata-only pre/post occurrence state for immediate selected-boundary cancellation Undo.';
comment on function public.cancel_repeating_chore_series_from_occurrence(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) is
  'WP03-22 compatible cancellation wrapper that records exact metadata-only Undo state before invoking the private WP03-21 engine.';
comment on function public.resume_repeating_chore_series_cancellation(
  uuid,
  uuid,
  uuid,
  uuid,
  bigint
) is
  'Resumes one exact actor-owned selected-boundary cancellation when its series and occurrence post-state remain compatible.';
