-- KinFlow WP03-06 chore agenda filters and bounded pagination.
-- Store MVP scope: adult active-household members, online authoritative reads.

create index chore_occurrences_list_idx
  on public.chore_occurrences(
    household_id,
    status,
    due_local_date,
    due_at,
    id
  );

create index chore_occurrences_assignee_list_idx
  on public.chore_occurrences(
    household_id,
    assignee_member_id,
    status,
    due_local_date,
    due_at,
    id
  );

create function public.get_chore_list(
  p_household_id uuid,
  p_view text default 'today',
  p_assignee_member_id uuid default null,
  p_limit integer default 30,
  p_after_cursor text default null
)
returns table (
  household_id uuid,
  household_timezone text,
  household_local_date date,
  generated_at timestamptz,
  list_view text,
  assignee_filter_member_id uuid,
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
  v_timezone text;
  v_local_date date;
  v_generated_at timestamptz := statement_timestamp();
  v_view text := lower(trim(coalesce(p_view, '')));
  v_cursor_json jsonb;
  v_cursor_date date;
  v_cursor_due_at timestamptz;
  v_cursor_occurrence_id uuid;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFC01',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or v_view not in ('today', 'upcoming', 'overdue', 'completed')
    or p_limit is null
    or p_limit not between 1 and 100
    or p_after_cursor is not null
       and (
         char_length(p_after_cursor) not between 2 and 1000
         or char_length(p_after_cursor) % 2 <> 0
         or p_after_cursor !~ '^[0-9a-f]+$'
       ) then
    raise exception using
      errcode = 'KFC02',
      message = 'invalid chore input';
  end if;

  select household.timezone, caller.role
  into v_timezone, v_actor_role
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

  if p_assignee_member_id is not null
    and not exists (
      select 1
      from public.household_members as filtered_member
      where filtered_member.household_id = p_household_id
        and filtered_member.id = p_assignee_member_id
        and filtered_member.removed_at is null
    ) then
    raise exception using
      errcode = 'KFC03',
      message = 'chore not found or forbidden';
  end if;

  v_local_date := (v_generated_at at time zone v_timezone)::date;

  if p_after_cursor is not null then
    begin
      v_cursor_json := convert_from(
        decode(p_after_cursor, 'hex'),
        'UTF8'
      )::jsonb;

      if jsonb_typeof(v_cursor_json) <> 'object'
        or (
          select count(*)
          from jsonb_object_keys(v_cursor_json)
        ) <> 6
        or not v_cursor_json ?& array[
          'v', 'view', 'assignee', 'date', 'due_at', 'id'
        ]
        or jsonb_typeof(v_cursor_json->'v') <> 'number'
        or (v_cursor_json->>'v')::integer <> 1
        or jsonb_typeof(v_cursor_json->'view') <> 'string'
        or v_cursor_json->>'view' <> v_view
        or jsonb_typeof(v_cursor_json->'assignee') not in ('null', 'string')
        or (v_cursor_json->>'assignee') is distinct from
           p_assignee_member_id::text
        or jsonb_typeof(v_cursor_json->'date') <> 'string'
        or jsonb_typeof(v_cursor_json->'due_at') not in ('null', 'string')
        or jsonb_typeof(v_cursor_json->'id') <> 'string' then
        raise exception using
          errcode = 'KFC02',
          message = 'invalid chore input';
      end if;

      v_cursor_date := (v_cursor_json->>'date')::date;
      v_cursor_occurrence_id := (v_cursor_json->>'id')::uuid;
      v_cursor_due_at := case
        when jsonb_typeof(v_cursor_json->'due_at') = 'null' then null
        else (v_cursor_json->>'due_at')::timestamptz
      end;
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
  with candidate as (
    select
      occurrence.id as occurrence_id,
      series.id as series_id,
      display_revision.title,
      display_revision.description,
      occurrence.assignee_member_id,
      assignee.display_name as assignee_display_name,
      occurrence.due_local_date,
      case
        when occurrence.due_at is null then null
        else (occurrence.due_at at time zone occurrence.timezone)::time
      end as due_local_time,
      occurrence.due_at,
      occurrence.status::text as status,
      occurrence.version,
      case
        when display_revision.recurrence_rule->>'frequency' in (
          'daily', 'weekly', 'monthly'
        ) then display_revision.recurrence_rule->>'frequency'
        else null
      end as recurrence_frequency,
      series.version as series_version,
      case
        when occurrence.status = 'scheduled' and series.deleted_at is null
          then active_revision.default_assignee_member_id
        else display_revision.default_assignee_member_id
      end as series_default_assignee_member_id,
      case
        when occurrence.status = 'scheduled' and series.deleted_at is null
          then active_revision.due_local_time
        else display_revision.due_local_time
      end as series_due_local_time,
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
      end as recurrence_rule,
      (
        v_actor_role in ('owner', 'admin')
        and occurrence.status = 'scheduled'
        and series.deleted_at is null
        and active_revision.recurrence_rule <> '{"type":"once"}'::jsonb
      ) as can_manage_series
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
      and (
        p_assignee_member_id is null
        or occurrence.assignee_member_id = p_assignee_member_id
      )
      and (
        v_view = 'today'
        and occurrence.due_local_date = v_local_date
        and occurrence.status in ('scheduled', 'completed')
        and (
          occurrence.status = 'completed'
          or series.deleted_at is null
        )
        or v_view = 'upcoming'
        and occurrence.due_local_date > v_local_date
        and occurrence.status = 'scheduled'
        and series.deleted_at is null
        or v_view = 'overdue'
        and occurrence.due_local_date < v_local_date
        and occurrence.status = 'scheduled'
        and series.deleted_at is null
        or v_view = 'completed'
        and occurrence.status = 'completed'
      )
      and (
        p_after_cursor is null
        or v_view <> 'completed'
        and (
          occurrence.due_local_date > v_cursor_date
          or occurrence.due_local_date = v_cursor_date
          and (
            v_cursor_due_at is not null
            and (
              occurrence.due_at is null
              or occurrence.due_at > v_cursor_due_at
              or occurrence.due_at = v_cursor_due_at
                 and occurrence.id > v_cursor_occurrence_id
            )
            or v_cursor_due_at is null
            and occurrence.due_at is null
            and occurrence.id > v_cursor_occurrence_id
          )
        )
        or v_view = 'completed'
        and (
          occurrence.due_local_date < v_cursor_date
          or occurrence.due_local_date = v_cursor_date
          and (
            v_cursor_due_at is not null
            and (
              occurrence.due_at is null
              or occurrence.due_at < v_cursor_due_at
              or occurrence.due_at = v_cursor_due_at
                 and occurrence.id < v_cursor_occurrence_id
            )
            or v_cursor_due_at is null
            and occurrence.due_at is null
            and occurrence.id < v_cursor_occurrence_id
          )
        )
      )
  ),
  page_plus as materialized (
    select candidate.*
    from candidate
    order by
      case when v_view <> 'completed' then candidate.due_local_date end,
      case when v_view = 'completed' then candidate.due_local_date end desc,
      case when v_view <> 'completed' then candidate.due_at end
        asc nulls last,
      case when v_view = 'completed' then candidate.due_at end
        desc nulls last,
      case when v_view <> 'completed' then candidate.occurrence_id end,
      case when v_view = 'completed' then candidate.occurrence_id end desc
    limit p_limit + 1
  ),
  ranked_page as materialized (
    select
      page_plus.*,
      row_number() over (
        order by
          case when v_view <> 'completed' then page_plus.due_local_date end,
          case when v_view = 'completed' then page_plus.due_local_date end desc,
          case when v_view <> 'completed' then page_plus.due_at end
            asc nulls last,
          case when v_view = 'completed' then page_plus.due_at end
            desc nulls last,
          case when v_view <> 'completed' then page_plus.occurrence_id end,
          case when v_view = 'completed' then page_plus.occurrence_id end desc
      ) as page_rank
    from page_plus
  ),
  metadata as (
    select
      count(*) > p_limit as has_more,
      case
        when count(*) > p_limit then (
          select encode(
            convert_to(
              jsonb_build_object(
                'v', 1,
                'view', v_view,
                'assignee', p_assignee_member_id,
                'date', cursor_item.due_local_date,
                'due_at', cursor_item.due_at,
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
    v_timezone,
    v_local_date,
    v_generated_at,
    v_view,
    p_assignee_member_id,
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
    item.status,
    item.version,
    item.recurrence_frequency,
    item.series_version,
    item.series_default_assignee_member_id,
    item.series_due_local_time,
    item.recurrence_rule,
    item.can_manage_series
  from metadata
  left join ranked_page as item
    on item.page_rank <= p_limit
  order by item.page_rank nulls first;
end;
$$;

revoke all on function public.get_chore_list(
  uuid,
  text,
  uuid,
  integer,
  text
) from public, anon, authenticated;

grant execute on function public.get_chore_list(
  uuid,
  text,
  uuid,
  integer,
  text
) to authenticated;
