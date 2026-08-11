-- KinFlow WP03-18 read-only household weekly report.
-- The server owns the closed ISO-week boundary and returns content-free sums.

create index chore_occurrences_weekly_report_idx
  on public.chore_occurrences(household_id, due_local_date, status)
  include (completed_by_member_id, completed_at)
  where status in ('scheduled', 'completed', 'skipped');

create or replace function public.get_household_weekly_report(
  p_household_id uuid,
  p_week_offset integer
)
returns table (
  household_id uuid,
  household_timezone text,
  generated_at timestamptz,
  week_offset integer,
  week_start date,
  week_end date,
  due_count bigint,
  completed_count bigint,
  completed_by_week_end_count bigint,
  completed_after_week_end_count bigint,
  open_count bigint,
  skipped_count bigint,
  viewer_completed_count bigint,
  member_breakdown jsonb,
  other_member_completed_count bigint,
  member_breakdown_truncated boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_authenticated_user_id uuid := (select auth.uid());
  v_generated_at timestamptz := statement_timestamp();
  v_household_timezone text;
  v_caller_member_id uuid;
  v_household_local_today date;
  v_current_week_start date;
  v_week_start date;
  v_week_end date;
  v_week_end_exclusive timestamptz;
begin
  if v_authenticated_user_id is null then
    raise exception using
      errcode = 'KFC01',
      message = 'authentication required';
  end if;

  if p_household_id is null
    or p_week_offset is null
    or p_week_offset not between 0 and 11 then
    raise exception using
      errcode = 'KFC02',
      message = 'invalid chore input';
  end if;

  select household.timezone, caller.id
  into v_household_timezone, v_caller_member_id
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

  v_household_local_today :=
    (v_generated_at at time zone v_household_timezone)::date;
  v_current_week_start := v_household_local_today
    - (extract(isodow from v_household_local_today)::integer - 1);
  v_week_start := v_current_week_start - ((p_week_offset + 1) * 7);
  v_week_end := v_week_start + 6;
  v_week_end_exclusive :=
    ((v_week_end + 1)::timestamp without time zone
      at time zone v_household_timezone);

  return query
  with selected_occurrences as materialized (
    select
      occurrence.status,
      occurrence.completed_by_member_id,
      occurrence.completed_at
    from public.chore_occurrences as occurrence
    where occurrence.household_id = p_household_id
      and occurrence.due_local_date between v_week_start and v_week_end
      and occurrence.status in ('scheduled', 'completed', 'skipped')
  ),
  totals as materialized (
    select
      count(*) filter (
        where selected.status in ('scheduled', 'completed')
      ) as due_count,
      count(*) filter (
        where selected.status = 'completed'
      ) as completed_count,
      count(*) filter (
        where selected.status = 'completed'
          and selected.completed_at < v_week_end_exclusive
      ) as completed_by_week_end_count,
      count(*) filter (
        where selected.status = 'completed'
          and selected.completed_at >= v_week_end_exclusive
      ) as completed_after_week_end_count,
      count(*) filter (
        where selected.status = 'scheduled'
      ) as open_count,
      count(*) filter (
        where selected.status = 'skipped'
      ) as skipped_count,
      count(*) filter (
        where selected.status = 'completed'
          and selected.completed_by_member_id = v_caller_member_id
      ) as viewer_completed_count
    from selected_occurrences as selected
  ),
  active_contributors as materialized (
    select
      member.id as member_id,
      member.display_name,
      count(*) as completed_count,
      count(*) filter (
        where selected.completed_at < v_week_end_exclusive
      ) as completed_by_week_end_count
    from selected_occurrences as selected
    join public.household_members as member
      on member.household_id = p_household_id
     and member.id = selected.completed_by_member_id
     and member.removed_at is null
    where selected.status = 'completed'
    group by member.id, member.display_name
  ),
  ranked_contributors as materialized (
    select
      contributor.*,
      row_number() over (
        order by lower(contributor.display_name), contributor.member_id
      ) as contributor_rank
    from active_contributors as contributor
  ),
  member_projection as (
    select
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'memberId', contributor.member_id,
            'displayName', contributor.display_name,
            'completedCount', contributor.completed_count,
            'completedByWeekEndCount',
              contributor.completed_by_week_end_count,
            'isViewer', contributor.member_id = v_caller_member_id
          )
          order by contributor.contributor_rank
        ) filter (where contributor.contributor_rank <= 20),
        '[]'::jsonb
      ) as member_breakdown,
      coalesce(
        sum(contributor.completed_count) filter (
          where contributor.contributor_rank <= 20
        ),
        0::numeric
      )::bigint as named_completed_count,
      coalesce(
        bool_or(contributor.contributor_rank > 20),
        false
      ) as member_breakdown_truncated
    from ranked_contributors as contributor
  )
  select
    p_household_id,
    v_household_timezone,
    v_generated_at,
    p_week_offset,
    v_week_start,
    v_week_end,
    totals.due_count,
    totals.completed_count,
    totals.completed_by_week_end_count,
    totals.completed_after_week_end_count,
    totals.open_count,
    totals.skipped_count,
    totals.viewer_completed_count,
    member_projection.member_breakdown,
    totals.completed_count - member_projection.named_completed_count,
    member_projection.member_breakdown_truncated
  from totals
  cross join member_projection;
end;
$$;

comment on function public.get_household_weekly_report(uuid, integer) is
  'Returns one content-free aggregate for a server-derived closed household ISO week to an active member.';

revoke all on function public.get_household_weekly_report(uuid, integer)
  from public, anon;
grant execute on function public.get_household_weekly_report(uuid, integer)
  to authenticated;
