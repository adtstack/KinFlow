-- KinFlow WP03-05A repeating chore creation and initial materialization.
-- Store MVP scope: canonical recurrence rules with a bounded first-year window.

create or replace function app_private.is_valid_chore_recurrence_end(
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
  if jsonb_typeof(p_end) <> 'object' then
    return false;
  end if;

  if p_end = '{"type":"never"}'::jsonb then
    return true;
  end if;

  if p_end->>'type' = 'count'
    and (select count(*) from jsonb_object_keys(p_end)) = 2
    and p_end ? 'count'
    and jsonb_typeof(p_end->'count') = 'number'
    and p_end->>'count' ~ '^[0-9]+$' then
    v_count := (p_end->>'count')::integer;
    return v_count between 1 and 1000;
  end if;

  if p_end->>'type' = 'until'
    and (select count(*) from jsonb_object_keys(p_end)) = 2
    and p_end ? 'localDate'
    and jsonb_typeof(p_end->'localDate') = 'string'
    and p_end->>'localDate' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    v_until := pg_catalog.make_date(
      substring(p_end->>'localDate' from 1 for 4)::integer,
      substring(p_end->>'localDate' from 6 for 2)::integer,
      substring(p_end->>'localDate' from 9 for 2)::integer
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

revoke all on function app_private.is_valid_chore_recurrence_end(jsonb)
  from public;

create or replace function app_private.is_valid_chore_recurrence_rule(
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
  if p_rule = '{"type":"once"}'::jsonb then
    return true;
  end if;

  if jsonb_typeof(p_rule) <> 'object'
    or not p_rule ? 'frequency'
    or not p_rule ? 'interval'
    or not p_rule ? 'end'
    or jsonb_typeof(p_rule->'frequency') <> 'string'
    or jsonb_typeof(p_rule->'interval') <> 'number'
    or p_rule->>'interval' !~ '^[0-9]+$'
    or not app_private.is_valid_chore_recurrence_end(p_rule->'end') then
    return false;
  end if;

  v_frequency := p_rule->>'frequency';
  v_interval := (p_rule->>'interval')::integer;
  if v_interval not between 1 and 30 then
    return false;
  end if;

  if v_frequency = 'daily' then
    return (select count(*) from jsonb_object_keys(p_rule)) = 3;
  end if;

  if v_frequency = 'weekly' then
    if (select count(*) from jsonb_object_keys(p_rule)) <> 4
      or not p_rule ? 'weekdays'
      or jsonb_typeof(p_rule->'weekdays') <> 'array'
      or jsonb_array_length(p_rule->'weekdays') not between 1 and 7
      or exists (
        select 1
        from jsonb_array_elements(p_rule->'weekdays') as weekday(value)
        where jsonb_typeof(weekday.value) <> 'string'
          or weekday.value #>> '{}' not in (
            'MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'
          )
      ) then
      return false;
    end if;

    select count(*), count(distinct weekday.value)
    into v_weekday_count, v_distinct_weekday_count
    from jsonb_array_elements_text(p_rule->'weekdays') as weekday(value);
    return v_weekday_count = v_distinct_weekday_count;
  end if;

  if v_frequency = 'monthly' then
    if (select count(*) from jsonb_object_keys(p_rule)) <> 4
      or not p_rule ? 'monthDay'
      or jsonb_typeof(p_rule->'monthDay') <> 'number'
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

revoke all on function app_private.is_valid_chore_recurrence_rule(jsonb)
  from public;

alter table public.chore_series_revisions
  add constraint chore_recurrence_rule_valid_ck
  check (app_private.is_valid_chore_recurrence_rule(recurrence_rule))
  not valid;

alter table public.chore_series_revisions
  validate constraint chore_recurrence_rule_valid_ck;

create table app_private.chore_repeating_command_requests (
  authenticated_user_id uuid not null
    references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  household_id uuid not null,
  series_id uuid not null,
  first_occurrence_id uuid not null,
  result_recurrence_rule jsonb not null check (
    app_private.is_valid_chore_recurrence_rule(result_recurrence_rule)
    and result_recurrence_rule <> '{"type":"once"}'::jsonb
  ),
  result_materialized_through date not null,
  result_materialized_count integer not null check (
    result_materialized_count between 1 and 366
  ),
  created_at timestamptz not null default now(),
  primary key (authenticated_user_id, idempotency_key),
  constraint repeating_request_series_fk
    foreign key (household_id, series_id)
    references public.chore_series(household_id, id)
    on delete cascade,
  constraint repeating_request_occurrence_fk
    foreign key (household_id, first_occurrence_id)
    references public.chore_occurrences(household_id, id)
    on delete cascade
);

revoke all on table app_private.chore_repeating_command_requests
  from public, anon, authenticated;

create or replace function app_private.materialize_chore_revision(
  p_household_id uuid,
  p_series_id uuid,
  p_revision_id uuid,
  p_horizon_end date
)
returns integer
language plpgsql
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
  v_weekdays text[];
  v_month_day integer;
  v_end_type text;
  v_end_count integer;
  v_end_until date;
  v_inserted_count integer;
begin
  if p_household_id is null
    or p_series_id is null
    or p_revision_id is null
    or p_horizon_end is null then
    raise exception using
      errcode = 'KFC07',
      message = 'invalid chore recurrence rule';
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
    or v_rule = '{"type":"once"}'::jsonb
    or p_horizon_end < v_start_date
    or p_horizon_end > v_start_date + 365 then
    raise exception using
      errcode = 'KFC07',
      message = 'invalid chore recurrence rule';
  end if;

  v_frequency := v_rule->>'frequency';
  v_interval := (v_rule->>'interval')::integer;
  v_month_day := nullif(v_rule->>'monthDay', '')::integer;
  v_end_type := v_rule->'end'->>'type';
  v_end_count := nullif(v_rule->'end'->>'count', '')::integer;
  v_end_until := nullif(v_rule->'end'->>'localDate', '')::date;
  if v_frequency = 'weekly' then
    select array_agg(weekday.value order by weekday.ordinality)
    into v_weekdays
    from jsonb_array_elements_text(v_rule->'weekdays')
      with ordinality as weekday(value, ordinality);
  end if;

  with candidate_dates as (
    select generated.due_date::date as due_date
    from generate_series(
      v_start_date::timestamp,
      p_horizon_end::timestamp,
      interval '1 day'
    ) as generated(due_date)
  ),
  matched_dates as (
    select
      candidate.due_date,
      row_number() over (order by candidate.due_date) as occurrence_number
    from candidate_dates as candidate
    where (
      v_end_type <> 'until'
      or candidate.due_date <= v_end_until
    )
      and case v_frequency
        when 'daily' then
          (candidate.due_date - v_start_date) % v_interval = 0
        when 'weekly' then
          (
            (
              candidate.due_date
              - (
                v_start_date
                - (extract(isodow from v_start_date)::integer - 1)
              )
            ) / 7
          ) % v_interval = 0
          and (
            array['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU']
          )[extract(isodow from candidate.due_date)::integer] = any(
            v_weekdays
          )
        when 'monthly' then
          extract(day from candidate.due_date)::integer = v_month_day
          and (
            (
              extract(year from candidate.due_date)::integer
              - extract(year from v_start_date)::integer
            ) * 12
            + extract(month from candidate.due_date)::integer
            - extract(month from v_start_date)::integer
          ) % v_interval = 0
        else false
      end
  ),
  bounded_dates as (
    select matched.due_date
    from matched_dates as matched
    where v_end_type <> 'count'
      or matched.occurrence_number <= v_end_count
  )
  insert into public.chore_occurrences (
    id,
    household_id,
    series_id,
    revision_id,
    occurrence_key,
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
    p_series_id::text || ':' || bounded.due_date::text,
    bounded.due_date,
    case
      when v_due_local_time is null then null
      else (bounded.due_date + v_due_local_time) at time zone v_timezone
    end,
    v_timezone,
    v_assignee_member_id
  from bounded_dates as bounded
  on conflict (household_id, occurrence_key) do nothing;

  get diagnostics v_inserted_count = row_count;
  return v_inserted_count;
end;
$$;

revoke all on function app_private.materialize_chore_revision(
  uuid,
  uuid,
  uuid,
  date
) from public, anon, authenticated;

create or replace function public.create_repeating_chore(
  p_idempotency_key uuid,
  p_household_id uuid,
  p_title text,
  p_description text,
  p_assignee_member_id uuid,
  p_start_local_date date,
  p_due_local_time time without time zone,
  p_recurrence_rule jsonb
)
returns table (
  household_id uuid,
  series_id uuid,
  first_occurrence_id uuid,
  recurrence_rule jsonb,
  materialized_through date,
  materialized_count integer,
  created boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_title text := btrim(p_title);
  v_description text := nullif(btrim(p_description), '');
  v_timezone text;
  v_actor_member_id uuid;
  v_start_weekday text;
  v_request_hash bytea;
  v_existing_request_hash bytea;
  v_series_id uuid;
  v_revision_id uuid;
  v_first_occurrence_id uuid;
  v_materialized_through date;
  v_materialized_count integer;
  v_initial_horizon_end date;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFC01',
      message = 'authentication required';
  end if;

  if p_idempotency_key is null
    or p_household_id is null
    or p_assignee_member_id is null
    or p_start_local_date is null
    or (
      p_due_local_time is not null
      and extract(second from p_due_local_time) <> 0
    )
    or v_title is null
    or char_length(v_title) not between 1 and 160
    or v_title ~ '[[:cntrl:]]'
    or (
      v_description is not null
      and char_length(v_description) > 4000
    )
    or not app_private.is_valid_chore_recurrence_rule(p_recurrence_rule)
    or p_recurrence_rule = '{"type":"once"}'::jsonb then
    raise exception using
      errcode = 'KFC07',
      message = 'invalid chore recurrence rule';
  end if;

  v_start_weekday := (
    array['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU']
  )[extract(isodow from p_start_local_date)::integer];
  if (
    p_recurrence_rule->>'frequency' = 'weekly'
    and not (p_recurrence_rule->'weekdays' ? v_start_weekday)
  ) or (
    p_recurrence_rule->>'frequency' = 'monthly'
    and (p_recurrence_rule->>'monthDay')::integer
      <> extract(day from p_start_local_date)::integer
  ) or (
    p_recurrence_rule->'end'->>'type' = 'until'
    and (p_recurrence_rule->'end'->>'localDate')::date
      < p_start_local_date
  ) then
    raise exception using
      errcode = 'KFC07',
      message = 'invalid chore recurrence rule';
  end if;

  select household.timezone, caller.id
  into v_timezone, v_actor_member_id
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
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
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

  v_request_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'operation', 'create_repeating_chore',
        'household_id', p_household_id,
        'title', v_title,
        'description', v_description,
        'assignee_member_id', p_assignee_member_id,
        'start_local_date', p_start_local_date,
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
        || ':chore-repeating-create:'
        || p_idempotency_key::text,
      0
    )
  );

  select
    request.request_hash,
    request.series_id,
    request.first_occurrence_id,
    request.result_materialized_through,
    request.result_materialized_count
  into
    v_existing_request_hash,
    v_series_id,
    v_first_occurrence_id,
    v_materialized_through,
    v_materialized_count
  from app_private.chore_repeating_command_requests as request
  where request.authenticated_user_id = v_authenticated_user_id
    and request.idempotency_key = p_idempotency_key;

  if found then
    if v_existing_request_hash <> v_request_hash then
      raise exception using
        errcode = 'KFC04',
        message = 'idempotency key reused with different chore input';
    end if;

    return query select
      p_household_id,
      v_series_id,
      v_first_occurrence_id,
      p_recurrence_rule,
      v_materialized_through,
      v_materialized_count,
      false;
    return;
  end if;

  v_series_id := extensions.gen_random_uuid();
  v_revision_id := extensions.gen_random_uuid();
  v_initial_horizon_end := p_start_local_date + 365;
  if p_recurrence_rule->'end'->>'type' = 'until' then
    v_initial_horizon_end := least(
      v_initial_horizon_end,
      (p_recurrence_rule->'end'->>'localDate')::date
    );
  end if;

  insert into public.chore_series (
    id,
    household_id,
    title,
    description,
    timezone,
    active_revision_id,
    created_by_user_id
  )
  values (
    v_series_id,
    p_household_id,
    v_title,
    v_description,
    v_timezone,
    v_revision_id,
    v_authenticated_user_id
  );

  insert into public.chore_series_revisions (
    id,
    household_id,
    series_id,
    revision_number,
    effective_local_date,
    due_local_time,
    recurrence_rule,
    default_assignee_member_id,
    created_by_user_id
  )
  values (
    v_revision_id,
    p_household_id,
    v_series_id,
    1,
    p_start_local_date,
    p_due_local_time,
    p_recurrence_rule,
    p_assignee_member_id,
    v_authenticated_user_id
  );

  perform app_private.materialize_chore_revision(
    p_household_id,
    v_series_id,
    v_revision_id,
    v_initial_horizon_end
  );

  select
    min(occurrence.id::text) filter (
      where occurrence.due_local_date = p_start_local_date
    )::uuid,
    max(occurrence.due_local_date),
    count(*)::integer
  into
    v_first_occurrence_id,
    v_materialized_through,
    v_materialized_count
  from public.chore_occurrences as occurrence
  where occurrence.household_id = p_household_id
    and occurrence.series_id = v_series_id;

  if v_first_occurrence_id is null
    or v_materialized_through is null
    or v_materialized_count not between 1 and 366 then
    raise exception using
      errcode = 'KFC07',
      message = 'invalid chore recurrence rule';
  end if;

  insert into app_private.chore_repeating_command_requests (
    authenticated_user_id,
    idempotency_key,
    request_hash,
    household_id,
    series_id,
    first_occurrence_id,
    result_recurrence_rule,
    result_materialized_through,
    result_materialized_count
  )
  values (
    v_authenticated_user_id,
    p_idempotency_key,
    v_request_hash,
    p_household_id,
    v_series_id,
    v_first_occurrence_id,
    p_recurrence_rule,
    v_materialized_through,
    v_materialized_count
  );

  insert into app_private.chore_domain_events (
    household_id,
    event_name,
    aggregate_id,
    actor_member_id,
    correlation_id,
    aggregate_version
  )
  values (
    p_household_id,
    'chore.series_created',
    v_series_id,
    v_actor_member_id,
    p_idempotency_key,
    1
  );

  insert into app_private.chore_domain_events (
    household_id,
    event_name,
    aggregate_id,
    actor_member_id,
    correlation_id,
    aggregate_version
  )
  select
    p_household_id,
    'activation.adult_first_chore_created',
    v_series_id,
    v_actor_member_id,
    p_idempotency_key,
    1
  where not exists (
    select 1
    from app_private.chore_domain_events as existing
    where existing.household_id = p_household_id
      and existing.actor_member_id = v_actor_member_id
      and existing.event_name = 'activation.adult_first_chore_created'
  );

  return query select
    p_household_id,
    v_series_id,
    v_first_occurrence_id,
    p_recurrence_rule,
    v_materialized_through,
    v_materialized_count,
    true;
end;
$$;

revoke all on function public.create_repeating_chore(
  uuid,
  uuid,
  text,
  text,
  uuid,
  date,
  time without time zone,
  jsonb
) from public, anon, authenticated;

grant execute on function public.create_repeating_chore(
  uuid,
  uuid,
  text,
  text,
  uuid,
  date,
  time without time zone,
  jsonb
) to authenticated;

create or replace function public.get_today_chores_v2(
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
  recurrence_frequency text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_timezone text;
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
    item.recurrence_frequency
  from public.households as household
  left join lateral (
    select
      occurrence.id as occurrence_id,
      series.id as series_id,
      series.title,
      series.description,
      occurrence.assignee_member_id,
      assignee.display_name as assignee_display_name,
      revision.due_local_time,
      occurrence.due_at,
      occurrence.status::text as status,
      occurrence.version,
      case
        when revision.recurrence_rule->>'frequency' in (
          'daily', 'weekly', 'monthly'
        ) then revision.recurrence_rule->>'frequency'
        else null
      end as recurrence_frequency
    from public.chore_occurrences as occurrence
    join public.chore_series as series
      on series.household_id = occurrence.household_id
     and series.id = occurrence.series_id
     and series.deleted_at is null
    join public.chore_series_revisions as revision
      on revision.household_id = occurrence.household_id
     and revision.id = occurrence.revision_id
    join public.household_members as assignee
      on assignee.household_id = occurrence.household_id
     and assignee.id = occurrence.assignee_member_id
    where occurrence.household_id = household.id
      and occurrence.due_local_date = v_local_date
      and occurrence.status in ('scheduled', 'completed')
    order by
      occurrence.due_at nulls last,
      lower(series.title),
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
