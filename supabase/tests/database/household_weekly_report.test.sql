begin;
set constraints all deferred;

select plan(53);

-- Schema and least-privilege aggregate boundary.
select has_function(
  'public',
  'get_household_weekly_report',
  array['uuid', 'integer'],
  'weekly report RPC exists'
);
select ok(
  (
    select pg_proc.prosecdef
      and pg_proc.provolatile = 's'
      and pg_proc.proconfig @> array['search_path=""']::text[]
    from pg_catalog.pg_proc
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname = 'get_household_weekly_report'
  ),
  'weekly report is stable security-definer with an empty search path'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.get_household_weekly_report(uuid,integer)',
    'execute'
  ),
  'authenticated clients can execute the mediated weekly read'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.get_household_weekly_report(uuid,integer)',
    'execute'
  ),
  'anonymous clients cannot execute the weekly read'
);
select has_index(
  'public',
  'chore_occurrences',
  'chore_occurrences_weekly_report_idx',
  'weekly report has a bounded household/date/status index'
);
select throws_ok(
  $$select * from public.get_household_weekly_report(
    '20000000-0000-4000-8000-000000000101', 0
  )$$,
  'KFC01',
  'authentication required',
  'weekly report derives caller identity from JWT'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$select * from public.get_household_weekly_report(null, 0)$$,
  'KFC02',
  'invalid chore input',
  'weekly report rejects a missing household id'
);
select throws_ok(
  $$select * from public.get_household_weekly_report(
    '20000000-0000-4000-8000-000000000101', null
  )$$,
  'KFC02',
  'invalid chore input',
  'weekly report rejects a missing week offset'
);
select throws_ok(
  $$select * from public.get_household_weekly_report(
    '20000000-0000-4000-8000-000000000101', -1
  )$$,
  'KFC02',
  'invalid chore input',
  'weekly report rejects a future or partial week offset'
);
select throws_ok(
  $$select * from public.get_household_weekly_report(
    '20000000-0000-4000-8000-000000000101', 12
  )$$,
  'KFC02',
  'invalid chore input',
  'weekly report caps history at twelve closed weeks'
);
select throws_ok(
  $$select * from public.get_household_weekly_report(
    '20000000-0000-4000-8000-000000000201', 0
  )$$,
  'KFC03',
  'chore not found or forbidden',
  'weekly report does not disclose another household'
);

-- Empty report shape and server-owned closed ISO-week boundary.
select is(
  (
    select pg_catalog.array_agg(field.key order by field.key)::text
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
    cross join lateral pg_catalog.jsonb_object_keys(
      pg_catalog.to_jsonb(report)
    ) as field(key)
  ),
  '{completed_after_week_end_count,completed_by_week_end_count,completed_count,due_count,generated_at,household_id,household_timezone,member_breakdown,member_breakdown_truncated,open_count,other_member_completed_count,skipped_count,viewer_completed_count,week_end,week_offset,week_start}',
  'weekly projection exposes only the exact aggregate allowlist'
);
select is(
  (
    select report.household_timezone
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  'Asia/Seoul',
  'weekly report returns the authoritative household timezone'
);
select is(
  (
    select report.week_offset
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  0,
  'latest closed week uses offset zero'
);
select is(
  (
    select extract(isodow from report.week_start)::integer
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  1,
  'the selected week always starts on ISO Monday'
);
select is(
  (
    select report.week_end - report.week_start
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  6,
  'the selected week contains exactly seven local dates'
);
select ok(
  (
    select report.week_end <
      (report.generated_at at time zone report.household_timezone)::date
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  'the selected week is fully closed in the household timezone'
);
select is(
  (
    select latest.week_start - older.week_start
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as latest
    cross join public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 1
    ) as older
  ),
  7,
  'adjacent offsets differ by exactly one week'
);
select is(
  (
    select report.due_count
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  0::bigint,
  'an empty closed week has zero due chores'
);
select is(
  (
    select report.member_breakdown
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  '[]'::jsonb,
  'an empty closed week has an exact empty member array'
);
select is(
  (
    select report.other_member_completed_count
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  0::bigint,
  'an empty closed week has no unnamed contribution'
);

-- Create mixed one-time occurrences inside the server-selected week.
select lives_ok(
  $$select * from public.create_one_time_chore(
    '74000000-0000-4000-8000-000000000101',
    '20000000-0000-4000-8000-000000000101',
    'Weekly owner completed',
    null,
    '30000000-0000-4000-8000-000000000101',
    (
      select report.week_start + 1
      from public.get_household_weekly_report(
        '20000000-0000-4000-8000-000000000101', 0
      ) as report
    ),
    null
  )$$,
  'owner weekly fixture is created'
);
select lives_ok(
  $$select * from public.create_one_time_chore(
    '74000000-0000-4000-8000-000000000102',
    '20000000-0000-4000-8000-000000000101',
    'Weekly member completed',
    null,
    '30000000-0000-4000-8000-000000000102',
    (
      select report.week_start + 2
      from public.get_household_weekly_report(
        '20000000-0000-4000-8000-000000000101', 0
      ) as report
    ),
    null
  )$$,
  'member weekly fixture is created'
);
select lives_ok(
  $$select * from public.create_one_time_chore(
    '74000000-0000-4000-8000-000000000103',
    '20000000-0000-4000-8000-000000000101',
    'Weekly still open',
    null,
    '30000000-0000-4000-8000-000000000101',
    (
      select report.week_start + 3
      from public.get_household_weekly_report(
        '20000000-0000-4000-8000-000000000101', 0
      ) as report
    ),
    null
  )$$,
  'open weekly fixture is created'
);
select lives_ok(
  $$select * from public.create_one_time_chore(
    '74000000-0000-4000-8000-000000000104',
    '20000000-0000-4000-8000-000000000101',
    'Weekly skipped',
    null,
    '30000000-0000-4000-8000-000000000101',
    (
      select report.week_start + 4
      from public.get_household_weekly_report(
        '20000000-0000-4000-8000-000000000101', 0
      ) as report
    ),
    null
  )$$,
  'skipped weekly fixture is created'
);
select lives_ok(
  $$select * from public.set_chore_occurrence_completion(
    '75000000-0000-4000-8000-000000000101',
    '20000000-0000-4000-8000-000000000101',
    (
      select occurrence.id
      from public.chore_occurrences as occurrence
      join public.chore_series as series on series.id = occurrence.series_id
      where series.title = 'Weekly owner completed'
    ),
    1,
    true
  )$$,
  'owner completes their selected-week occurrence'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select lives_ok(
  $$select * from public.set_chore_occurrence_completion(
    '75000000-0000-4000-8000-000000000102',
    '20000000-0000-4000-8000-000000000101',
    (
      select occurrence.id
      from public.chore_occurrences as occurrence
      join public.chore_series as series on series.id = occurrence.series_id
      where series.title = 'Weekly member completed'
    ),
    1,
    true
  )$$,
  'member completes their selected-week occurrence'
);
reset role;

-- One completion happened by the closed-week boundary; the other is late.
update public.chore_occurrences as occurrence
set completed_at = (
  select ((report.week_end + 1)::timestamp
    at time zone report.household_timezone) - interval '1 day'
  from public.get_household_weekly_report(
    '20000000-0000-4000-8000-000000000101', 0
  ) as report
)
from public.chore_series as series
where series.id = occurrence.series_id
  and series.title = 'Weekly owner completed';

update public.chore_occurrences as occurrence
set status = 'skipped'
from public.chore_series as series
where series.id = occurrence.series_id
  and series.title = 'Weekly skipped';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select report.due_count
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  3::bigint,
  'scheduled plus completed rows form the due count'
);
select is(
  (
    select report.completed_count
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  2::bigint,
  'both completed rows contribute to completed count'
);
select is(
  (
    select report.completed_by_week_end_count
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  1::bigint,
  'only the boundary-adjusted completion finished by week end'
);
select is(
  (
    select report.completed_after_week_end_count
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  1::bigint,
  'the current-time completion is classified after week end'
);
select is(
  (
    select report.open_count
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  1::bigint,
  'one selected-week row remains open'
);
select is(
  (
    select report.skipped_count
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  1::bigint,
  'skipped work is reported separately from due work'
);
select is(
  (
    select report.viewer_completed_count
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  1::bigint,
  'the server derives the owner viewer completion count'
);
select is(
  (
    select pg_catalog.jsonb_array_length(report.member_breakdown)
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  2,
  'both active contributors appear without a leaderboard rank'
);
select is(
  (
    select pg_catalog.array_agg(field.key order by field.key)::text
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
    cross join lateral pg_catalog.jsonb_object_keys(
      report.member_breakdown->0
    ) as field(key)
  ),
  '{completedByWeekEndCount,completedCount,displayName,isViewer,memberId}',
  'member rows expose only the exact contribution allowlist'
);
select is(
  (
    select report.member_breakdown->0->>'displayName'
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  'Adult A',
  'member rows use deterministic case-folded display-name order'
);
select is(
  (
    select report.member_breakdown->1->>'displayName'
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  'Adult B',
  'the second active contributor follows deterministically'
);
select is(
  (
    select report.other_member_completed_count
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  0::bigint,
  'all active contributions are named while below the cap'
);
select is(
  (
    select report.member_breakdown_truncated
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  false,
  'a two-member breakdown is not truncated'
);
select is(
  (
    select report.due_count
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 1
    ) as report
  ),
  0::bigint,
  'older offset does not leak selected-week occurrences'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (
    select report.viewer_completed_count
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  1::bigint,
  'the same aggregate derives the member viewer count independently'
);
select is(
  (
    select (contributor.value->>'isViewer')::boolean
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
    cross join lateral pg_catalog.jsonb_array_elements(
      report.member_breakdown
    ) as contributor(value)
    where contributor.value->>'memberId' =
      '30000000-0000-4000-8000-000000000102'
  ),
  true,
  'isViewer is server-derived for the authenticated member row'
);
reset role;

-- Removed identities become count-only and cannot read the report.
update public.household_members
set removed_at = pg_catalog.clock_timestamp()
where id = '30000000-0000-4000-8000-000000000102';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select pg_catalog.jsonb_array_length(report.member_breakdown)
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  1,
  'a removed contributor disappears from named rows'
);
select is(
  (
    select report.other_member_completed_count
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  1::bigint,
  'a removed contributor remains only in the count-only bucket'
);
select ok(
  pg_catalog.strpos(
    (
      select report.member_breakdown::text
      from public.get_household_weekly_report(
        '20000000-0000-4000-8000-000000000101', 0
      ) as report
    ),
    'Adult B'
  ) = 0,
  'the named breakdown does not retain a removed display name'
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select throws_ok(
  $$select * from public.get_household_weekly_report(
    '20000000-0000-4000-8000-000000000101', 0
  )$$,
  'KFC03',
  'chore not found or forbidden',
  'a removed member cannot read the weekly report'
);
reset role;

-- More than twenty active contributors are bounded and folded into other.
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
create temporary table weekly_extra_contributors (
  ordinal integer primary key,
  user_id uuid not null,
  member_id uuid not null,
  series_id uuid not null,
  revision_id uuid not null
) on commit drop;

insert into weekly_extra_contributors (
  ordinal,
  user_id,
  member_id,
  series_id,
  revision_id
)
select
  value,
  extensions.gen_random_uuid(),
  extensions.gen_random_uuid(),
  extensions.gen_random_uuid(),
  extensions.gen_random_uuid()
from pg_catalog.generate_series(1, 21) as value;

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
select
  '00000000-0000-0000-0000-000000000000',
  extra.user_id,
  'authenticated',
  'authenticated',
  pg_catalog.format('weekly-%s@local.kinflow.invalid', extra.ordinal),
  pg_catalog.clock_timestamp(),
  '{"provider":"local_fixture","providers":["local_fixture"]}'::jsonb,
  '{}'::jsonb,
  pg_catalog.clock_timestamp(),
  pg_catalog.clock_timestamp()
from weekly_extra_contributors as extra;

insert into public.household_members (
  id,
  household_id,
  auth_user_id,
  display_name,
  role,
  created_by_user_id
)
select
  extra.member_id,
  '20000000-0000-4000-8000-000000000101',
  extra.user_id,
  pg_catalog.format('Weekly %s', pg_catalog.lpad(extra.ordinal::text, 2, '0')),
  'member'::public.household_role,
  '00000000-0000-4000-8000-000000000101'
from weekly_extra_contributors as extra;

insert into public.chore_series (
  id,
  household_id,
  title,
  description,
  timezone,
  active_revision_id,
  created_by_user_id
)
select
  extra.series_id,
  '20000000-0000-4000-8000-000000000101',
  pg_catalog.format('Weekly extra series %s', extra.ordinal),
  null,
  report.household_timezone,
  extra.revision_id,
  '00000000-0000-4000-8000-000000000101'
from weekly_extra_contributors as extra
cross join lateral public.get_household_weekly_report(
  '20000000-0000-4000-8000-000000000101', 0
) as report;

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
)
select
  extra.revision_id,
  '20000000-0000-4000-8000-000000000101',
  extra.series_id,
  1,
  report.week_start + 5,
  null,
  '{"type":"once"}'::jsonb,
  extra.member_id,
  '00000000-0000-4000-8000-000000000101',
  pg_catalog.format('Weekly extra series %s', extra.ordinal),
  null
from weekly_extra_contributors as extra
cross join lateral public.get_household_weekly_report(
  '20000000-0000-4000-8000-000000000101', 0
) as report;

insert into public.chore_occurrences (
  household_id,
  series_id,
  revision_id,
  occurrence_key,
  due_local_date,
  due_at,
  timezone,
  status,
  assignee_member_id,
  completed_by_member_id,
  completed_by_user_id,
  completed_at
)
select
  '20000000-0000-4000-8000-000000000101',
  extra.series_id,
  extra.revision_id,
  extra.series_id::text || ':once',
  report.week_start + 5,
  null,
  report.household_timezone,
  'completed'::public.occurrence_status,
  extra.member_id,
  extra.member_id,
  extra.user_id,
  ((report.week_end + 1)::timestamp
    at time zone report.household_timezone) - interval '1 day'
from weekly_extra_contributors as extra
cross join lateral public.get_household_weekly_report(
  '20000000-0000-4000-8000-000000000101', 0
) as report;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select is(
  (
    select pg_catalog.jsonb_array_length(report.member_breakdown)
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  20,
  'named member rows are capped at twenty'
);
select is(
  (
    select report.member_breakdown_truncated
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  true,
  'omitted active contributors mark the breakdown truncated'
);
select is(
  (
    select report.other_member_completed_count
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  3::bigint,
  'other combines one removed and two overflow contributions without identity'
);
select is(
  (
    select report.completed_count
      - report.completed_by_week_end_count
      - report.completed_after_week_end_count
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  0::bigint,
  'completion classifications preserve the exact aggregate equation'
);
select is(
  (
    select report.due_count - report.completed_count - report.open_count
    from public.get_household_weekly_report(
      '20000000-0000-4000-8000-000000000101', 0
    ) as report
  ),
  0::bigint,
  'due count preserves completed plus open equation'
);
reset role;

-- Deleted households remain fail-closed.
update public.households
set deleted_at = pg_catalog.clock_timestamp()
where id = '20000000-0000-4000-8000-000000000201';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000201',
  true
);
select throws_ok(
  $$select * from public.get_household_weekly_report(
    '20000000-0000-4000-8000-000000000201', 0
  )$$,
  'KFC03',
  'chore not found or forbidden',
  'a deleted household cannot read the weekly report'
);
reset role;

select * from finish();
rollback;
