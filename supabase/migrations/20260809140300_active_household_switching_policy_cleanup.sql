drop policy if exists active_household_update_self
  on public.user_active_households;

revoke update on table public.user_active_households from authenticated;
revoke update (household_id, member_id)
  on table public.user_active_households from authenticated;

comment on table public.user_active_households is
  'WP02-08 self-readable active selection; all writes use mediated commands.';
