begin;

select plan(71);

-- 01-10: schema and command surface.
select has_type('public', 'invite_status', 'invite status enum exists');
select has_table('public', 'household_invites', 'invite metadata table exists');
select has_table('app_private', 'invite_create_requests', 'create idempotency table exists');
select has_table('app_private', 'invite_accept_requests', 'accept idempotency table exists');
select has_table('app_private', 'invite_rate_limits', 'private rate-limit table exists');
select has_function(
  'public',
  'create_household_invite',
  array['uuid', 'uuid', 'text', 'text', 'text', 'text', 'integer'],
  'create invite command exists'
);
select has_function(
  'public',
  'preview_household_invite',
  array['text'],
  'preview invite command exists'
);
select has_function(
  'public',
  'accept_household_invite',
  array['uuid', 'text', 'text', 'boolean'],
  'accept invite command exists'
);
select has_function(
  'public',
  'revoke_household_invite',
  array['uuid', 'uuid', 'uuid', 'text'],
  'revoke invite command exists'
);
select has_function(
  'public',
  'consume_invite_rate_limit',
  array['text', 'text'],
  'rate-limit command exists'
);

-- 11-18: least privilege, forced RLS, and no raw secrets.
select ok(
  (
    select bool_and(pg_proc.prosecdef)
      and bool_and(pg_proc.proconfig @> array['search_path=""']::text[])
    from pg_proc
    join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname in (
        'consume_invite_rate_limit',
        'create_household_invite',
        'preview_household_invite',
        'accept_household_invite',
        'revoke_household_invite'
      )
  ),
  'invite commands are security-definer with an empty search path'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.preview_household_invite(text)',
    'execute'
  ) and has_function_privilege(
    'service_role',
    'public.accept_household_invite(uuid,text,text,boolean)',
    'execute'
  ),
  'service role can execute mediated invite commands'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.preview_household_invite(text)',
    'execute'
  ) and not has_function_privilege(
    'authenticated',
    'public.accept_household_invite(uuid,text,text,boolean)',
    'execute'
  ),
  'client roles cannot bypass Edge mediation'
);
select ok(
  not has_table_privilege('authenticated', 'public.household_invites', 'insert')
    and not has_table_privilege('authenticated', 'public.household_invites', 'update')
    and not has_table_privilege('authenticated', 'public.household_invites', 'delete'),
  'authenticated clients have no invite mutation grants'
);
select ok(
  not has_table_privilege('anon', 'public.household_invites', 'select')
    and not has_table_privilege('anon', 'public.household_invites', 'insert'),
  'anonymous clients have no invite table grants'
);
select ok(
  (
    select pg_class.relrowsecurity and pg_class.relforcerowsecurity
    from pg_class
    join pg_namespace on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'household_invites'
  ),
  'invite metadata has enabled and forced RLS'
);
select hasnt_column(
  'public',
  'household_invites',
  'raw_token',
  'invite table has no raw token column'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'app_private.invite_accept_requests',
    'select'
  ) and not has_table_privilege(
    'authenticated',
    'app_private.invite_rate_limits',
    'insert'
  ),
  'private command records are inaccessible to clients'
);

-- 19-27: create validation and authority.
select throws_ok(
  $$
    select * from public.create_household_invite(
      '00000000-0000-4000-8000-000000009999',
      '20000000-0000-4000-8000-000000000101',
      'wp02-04-create-auth',
      repeat('01', 32),
      'member',
      null,
      168
    )
  $$,
  'KFI01',
  'authentication required',
  'create rejects an unverified identity'
);
select throws_ok(
  $$
    select * from public.create_household_invite(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'wp02-04-create-hash',
      'not-a-hash',
      'member',
      null,
      168
    )
  $$,
  'KFI02',
  'invalid invite input',
  'create rejects a malformed token hash'
);
select throws_ok(
  $$
    select * from public.create_household_invite(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'wp02-04-create-role',
      repeat('02', 32),
      'owner',
      null,
      168
    )
  $$,
  'KFI02',
  'invalid invite input',
  'create cannot mint an Owner invite'
);
select throws_ok(
  $$
    select * from public.create_household_invite(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'wp02-04-create-expiry',
      repeat('03', 32),
      'member',
      null,
      721
    )
  $$,
  'KFI02',
  'invalid invite input',
  'create enforces the expiry bound'
);
select throws_ok(
  $$
    select * from public.create_household_invite(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'wp02-04-create-email',
      repeat('04', 32),
      'member',
      'invalid email',
      168
    )
  $$,
  'KFI02',
  'invalid invite input',
  'create rejects an invalid target email'
);
select throws_ok(
  $$
    select * from public.create_household_invite(
      '00000000-0000-4000-8000-000000000102',
      '20000000-0000-4000-8000-000000000101',
      'wp02-04-create-member',
      repeat('05', 32),
      'member',
      null,
      168
    )
  $$,
  'KFI03',
  'invite permission denied',
  'ordinary member cannot create an invite'
);
select throws_ok(
  $$
    select * from public.create_household_invite(
      '00000000-0000-4000-8000-000000000201',
      '20000000-0000-4000-8000-000000000101',
      'wp02-04-create-outsider',
      repeat('06', 32),
      'member',
      null,
      168
    )
  $$,
  'KFI03',
  'invite permission denied',
  'other-household Owner cannot inject a household ID'
);
select lives_ok(
  $$
    select * from public.create_household_invite(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'wp02-04-create-valid',
      repeat('11', 32),
      'member',
      'ADULT-B@LOCAL.KINFLOW.INVALID',
      168
    )
  $$,
  'Owner creates a valid target-email invite'
);
select is(
  (
    select count(*)
    from public.household_invites as invite
    where invite.token_hash = decode(repeat('11', 32), 'hex')
      and invite.target_email_hash = extensions.digest(
        convert_to('adult-b@local.kinflow.invalid', 'UTF8'),
        'sha256'
      )
      and invite.status = 'active'
      and invite.max_uses = 1
      and invite.used_count = 0
  ),
  1::bigint,
  'create stores only normalized hashes and single-use metadata'
);

-- 28-34: create idempotency, admin authority, and direct-write denial.
select is(
  (
    select created
    from public.create_household_invite(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'wp02-04-create-valid',
      repeat('12', 32),
      'member',
      'adult-b@local.kinflow.invalid',
      168
    )
  ),
  false,
  'same create key and request returns the original result without a new token'
);
select is(
  (
    select count(*)
    from app_private.invite_create_requests
    where idempotency_key = 'wp02-04-create-valid'
  ),
  1::bigint,
  'create retry writes one idempotency result'
);
select throws_ok(
  $$
    select * from public.create_household_invite(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'wp02-04-create-valid',
      repeat('13', 32),
      'admin',
      'adult-b@local.kinflow.invalid',
      168
    )
  $$,
  'KFI04',
  'idempotency key reused with different invite input',
  'create key reuse with a changed request conflicts'
);
update public.household_members
set role = 'admin'
where id = '30000000-0000-4000-8000-000000000102';
select lives_ok(
  $$
    select * from public.create_household_invite(
      '00000000-0000-4000-8000-000000000102',
      '20000000-0000-4000-8000-000000000101',
      'wp02-04-create-admin',
      repeat('14', 32),
      'member',
      null,
      24
    )
  $$,
  'Admin can create a member invite'
);
update public.household_members
set role = 'member'
where id = '30000000-0000-4000-8000-000000000102';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select throws_ok(
  $$
    update public.household_invites
    set expires_at = now() + interval '1 day'
  $$,
  '42501',
  'permission denied for table household_invites',
  'Owner cannot bypass the server command with direct update'
);
reset role;
select is(
  (
    select count(*)
    from public.household_invites
    where household_id = '20000000-0000-4000-8000-000000000101'
  ),
  2::bigint,
  'only the two successful create commands produced invites'
);
select is(
  (
    select octet_length(request_hash)
    from app_private.invite_create_requests
    where idempotency_key = 'wp02-04-create-valid'
  ),
  32,
  'create idempotency stores a request hash instead of request PII'
);
select ok(
  (
    select expires_at > created_at
      and expires_at <= created_at + interval '169 hours'
    from public.household_invites
    where token_hash = decode(repeat('11', 32), 'hex')
  ),
  'created invite has a bounded server expiry'
);

-- 35-39: committed fixed-window rate limiting.
select ok(
  (
    select bool_and(public.consume_invite_rate_limit('create', repeat('21', 32)))
    from generate_series(1, 10)
  ),
  'first ten create attempts fit the fixed rate window'
);
select is(
  public.consume_invite_rate_limit('create', repeat('21', 32)),
  false,
  'the next create attempt is rate limited'
);
select is(
  (
    select request_count
    from app_private.invite_rate_limits
    where scope = 'create'
      and key_hash = decode(repeat('21', 32), 'hex')
  ),
  11,
  'rate limit stores only a 32-byte key fingerprint and count'
);
select throws_ok(
  $$ select public.consume_invite_rate_limit('unknown', repeat('22', 32)) $$,
  'KFI02',
  'invalid invite input',
  'unknown rate-limit scope is rejected'
);
select throws_ok(
  $$ select public.consume_invite_rate_limit('preview', 'raw-client-address') $$,
  'KFI02',
  'invalid invite input',
  'rate limit refuses a raw unhashed key'
);

-- 40-44: minimal preview and stable invalid/expired states.
select is(
  (
    select concat_ws('|', valid, household_display_name, inviter_display_name, role)
    from public.preview_household_invite(repeat('11', 32))
  ),
  't|Primary Local Household|Adult A|member',
  'valid preview returns only the expected display fields'
);
select throws_ok(
  $$ select * from public.preview_household_invite(repeat('99', 32)) $$,
  'KFI05',
  'invite invalid',
  'unknown invite preview is generic'
);
select throws_ok(
  $$ select * from public.preview_household_invite('raw-invite-token') $$,
  'KFI05',
  'invite invalid',
  'preview accepts only a server-side token hash'
);
select lives_ok(
  $$
    select * from public.create_household_invite(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'wp02-04-create-expired',
      repeat('31', 32),
      'member',
      null,
      1
    )
  $$,
  'expiry fixture is created through the command'
);
update public.household_invites
set expires_at = now() - interval '1 second'
where token_hash = decode(repeat('31', 32), 'hex');
select throws_ok(
  $$ select * from public.preview_household_invite(repeat('31', 32)) $$,
  'KFI06',
  'invite expired',
  'expired invite preview has a stable gone state'
);

-- 45-55: target identity, atomic accept, replay, and active-household choice.
select throws_ok(
  $$
    select * from public.accept_household_invite(
      '00000000-0000-4000-8000-000000000201',
      'wp02-04-accept-wrong-email',
      repeat('11', 32),
      false
    )
  $$,
  'KFI10',
  'invite email mismatch',
  'target-email invite rejects another authenticated adult'
);
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
values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-4000-8000-000000000401',
  'authenticated',
  'authenticated',
  'profile-missing@local.kinflow.invalid',
  now(),
  '{"provider":"local_fixture","providers":["local_fixture"]}'::jsonb,
  '{}'::jsonb,
  now(),
  now()
);
select lives_ok(
  $$
    select * from public.create_household_invite(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'wp02-04-create-no-profile',
      repeat('32', 32),
      'member',
      null,
      24
    )
  $$,
  'profile-unavailable fixture invite is created'
);
select throws_ok(
  $$
    select * from public.accept_household_invite(
      '00000000-0000-4000-8000-000000000401',
      'wp02-04-accept-no-profile',
      repeat('32', 32),
      true
    )
  $$,
  'KFI11',
  'invite profile unavailable',
  'accept fails closed when profile bootstrap is unavailable'
);
select lives_ok(
  $$
    select * from public.create_household_invite(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'wp02-04-create-accept',
      repeat('41', 32),
      'admin',
      null,
      24
    )
  $$,
  'untargeted accept fixture is created'
);
select is(
  (
    select concat_ws('|', household_id, role, active_household_set)
    from public.accept_household_invite(
      '00000000-0000-4000-8000-000000000201',
      'wp02-04-accept-valid',
      repeat('41', 32),
      false
    )
  ),
  '20000000-0000-4000-8000-000000000101|admin|f',
  'accept creates the invited role without silently switching an existing household'
);
select is(
  (
    select concat_ws('|', status, used_count, accepted_by_member_id is not null)
    from public.household_invites
    where token_hash = decode(repeat('41', 32), 'hex')
  ),
  'accepted|1|t',
  'accept atomically consumes and binds the single-use invite'
);
select is(
  (
    select household_id
    from public.user_active_households
    where auth_user_id = '00000000-0000-4000-8000-000000000201'
  ),
  '20000000-0000-4000-8000-000000000201'::uuid,
  'existing active household remains unchanged without confirmation'
);
select is(
  (
    select member_id
    from public.accept_household_invite(
      '00000000-0000-4000-8000-000000000201',
      'wp02-04-accept-valid',
      repeat('41', 32),
      false
    )
  ),
  (
    select member.id
    from public.household_members as member
    where member.household_id = '20000000-0000-4000-8000-000000000101'
      and member.auth_user_id = '00000000-0000-4000-8000-000000000201'
      and member.removed_at is null
  ),
  'same accept key and request returns the original membership'
);
select throws_ok(
  $$
    select * from public.accept_household_invite(
      '00000000-0000-4000-8000-000000000201',
      'wp02-04-accept-valid',
      repeat('41', 32),
      true
    )
  $$,
  'KFI04',
  'idempotency key reused with different invite input',
  'accept key reuse cannot change active-household intent'
);
select is(
  (
    select active_household_set
    from public.accept_household_invite(
      '00000000-0000-4000-8000-000000000201',
      'wp02-04-accept-switch',
      repeat('41', 32),
      true
    )
  ),
  true,
  'same accepting adult may explicitly switch on a new idempotent command'
);
select is(
  (
    select household_id
    from public.user_active_households
    where auth_user_id = '00000000-0000-4000-8000-000000000201'
  ),
  '20000000-0000-4000-8000-000000000101'::uuid,
  'explicit switch updates the active household to the accepted membership'
);
select throws_ok(
  $$
    select * from public.accept_household_invite(
      '00000000-0000-4000-8000-000000000102',
      'wp02-04-accept-after-use',
      repeat('41', 32),
      true
    )
  $$,
  'KFI09',
  'invite already used',
  'a different adult cannot replay a consumed invite'
);
select is(
  (
    select count(*)
    from public.household_members
    where household_id = '20000000-0000-4000-8000-000000000101'
      and auth_user_id = '00000000-0000-4000-8000-000000000201'
      and removed_at is null
  ),
  1::bigint,
  'accept replay produces exactly one active membership'
);

-- 56-63: revoke and terminal-state enforcement.
select lives_ok(
  $$
    select * from public.create_household_invite(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'wp02-04-create-revoke',
      repeat('51', 32),
      'member',
      null,
      24
    )
  $$,
  'revocation fixture is created'
);
select is(
  (
    select status
    from public.revoke_household_invite(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      (
        select id
        from public.household_invites
        where token_hash = decode(repeat('51', 32), 'hex')
      ),
      'wp02-04-revoke-valid'
    )
  ),
  'revoked',
  'Owner revokes an active invite through the command'
);
select ok(
  (
    select status = 'revoked' and revoked_at is not null
    from public.household_invites
    where token_hash = decode(repeat('51', 32), 'hex')
  ),
  'revoked invite records its terminal state without exposing the token'
);
select is(
  (
    select status
    from public.revoke_household_invite(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      (
        select id
        from public.household_invites
        where token_hash = decode(repeat('51', 32), 'hex')
      ),
      'wp02-04-revoke-valid'
    )
  ),
  'revoked',
  'same revoke key replays the terminal result'
);
select throws_ok(
  $$ select * from public.preview_household_invite(repeat('51', 32)) $$,
  'KFI08',
  'invite revoked',
  'revoked invite cannot be previewed as active'
);
select throws_ok(
  $$
    select * from public.accept_household_invite(
      '00000000-0000-4000-8000-000000000102',
      'wp02-04-accept-revoked',
      repeat('51', 32),
      true
    )
  $$,
  'KFI08',
  'invite revoked',
  'revoked invite cannot be accepted'
);
select throws_ok(
  $$
    select * from public.revoke_household_invite(
      '00000000-0000-4000-8000-000000000102',
      '20000000-0000-4000-8000-000000000101',
      (
        select id
        from public.household_invites
        where token_hash = decode(repeat('11', 32), 'hex')
      ),
      'wp02-04-revoke-member'
    )
  $$,
  'KFI03',
  'invite permission denied',
  'ordinary member cannot revoke an invite'
);
select throws_ok(
  $$
    select * from public.revoke_household_invite(
      '00000000-0000-4000-8000-000000000401',
      '20000000-0000-4000-8000-000000000101',
      (
        select id
        from public.household_invites
        where token_hash = decode(repeat('11', 32), 'hex')
      ),
      'wp02-04-revoke-outsider'
    )
  $$,
  'KFI03',
  'invite permission denied',
  'non-member cannot revoke by injected IDs'
);
select throws_ok(
  $$
    select * from public.revoke_household_invite(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      (
        select id
        from public.household_invites
        where token_hash = decode(repeat('41', 32), 'hex')
      ),
      'wp02-04-revoke-used'
    )
  $$,
  'KFI09',
  'invite already used',
  'accepted invite cannot be revoked retroactively'
);

-- 64-67: invite metadata RLS matrix.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
select ok(
  (select count(*) > 0 from public.household_invites),
  'same-household Owner can read invite metadata'
);
reset role;
update public.household_members
set role = 'admin'
where id = '30000000-0000-4000-8000-000000000102';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select ok(
  (select count(*) > 0 from public.household_invites),
  'same-household Admin can read invite metadata'
);
reset role;
update public.household_members
set role = 'member'
where id = '30000000-0000-4000-8000-000000000102';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
select is(
  (select count(*) from public.household_invites),
  0::bigint,
  'ordinary Member cannot inspect invitation metadata'
);
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000401',
  true
);
select is(
  (select count(*) from public.household_invites),
  0::bigint,
  'non-member cannot inspect invitation metadata'
);

select * from finish();
rollback;
