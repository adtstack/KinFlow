begin;

select no_plan();

select has_column(
  'public',
  'household_invites',
  'short_code_expires_at',
  'short-code expiry is stored separately from the primary invite expiry'
);
select hasnt_column(
  'public',
  'household_invites',
  'raw_short_code',
  'raw short codes have no database column'
);
select has_function(
  'public',
  'create_household_invite_with_short_code',
  array['uuid', 'uuid', 'text', 'text', 'text', 'text', 'text', 'integer', 'integer'],
  'hash-only short-code create command exists'
);
select has_function(
  'public',
  'preview_household_invite_short_code',
  array['text'],
  'generic short-code preview command exists'
);
select has_function(
  'public',
  'accept_household_invite_short_code',
  array['uuid', 'text', 'text', 'boolean'],
  'short-code accept command exists'
);
select ok(
  (
    select pg_catalog.bool_and(pg_proc.prosecdef)
      and pg_catalog.bool_and(
        pg_proc.proconfig @> array['search_path=""']::text[]
      )
    from pg_catalog.pg_proc
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_proc.pronamespace
    where pg_namespace.nspname = 'public'
      and pg_proc.proname in (
        'create_household_invite_with_short_code',
        'preview_household_invite_short_code',
        'accept_household_invite_short_code'
      )
  ),
  'short-code commands are security-definer with an empty search path'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.preview_household_invite_short_code(text)',
    'execute'
  ) and has_function_privilege(
    'service_role',
    'public.accept_household_invite_short_code(uuid,text,text,boolean)',
    'execute'
  ),
  'service role can mediate short-code preview and accept'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.preview_household_invite_short_code(text)',
    'execute'
  ) and not has_function_privilege(
    'authenticated',
    'public.accept_household_invite_short_code(uuid,text,text,boolean)',
    'execute'
  ),
  'client roles cannot bypass the rate-limited Edge surface'
);

select ok(
  (
    select pg_catalog.bool_and(
      public.consume_invite_rate_limit(
        'preview_short_code',
        pg_catalog.repeat('81', 32)
      )
    )
    from pg_catalog.generate_series(1, 10)
  ),
  'first ten public code previews fit the ten-minute window'
);
select is(
  public.consume_invite_rate_limit(
    'preview_short_code',
    pg_catalog.repeat('81', 32)
  ),
  false,
  'the eleventh public code preview is locked out'
);
select ok(
  (
    select pg_catalog.bool_and(
      public.consume_invite_rate_limit(
        'accept_short_code',
        pg_catalog.repeat('82', 32)
      )
    )
    from pg_catalog.generate_series(1, 10)
  ),
  'first ten authenticated code attempts fit the ten-minute window'
);
select is(
  public.consume_invite_rate_limit(
    'accept_short_code',
    pg_catalog.repeat('82', 32)
  ),
  false,
  'the eleventh authenticated code attempt is locked out'
);
update app_private.invite_rate_limits
set window_started_at = pg_catalog.clock_timestamp() - interval '11 minutes'
where scope = 'accept_short_code'
  and key_hash = pg_catalog.decode(pg_catalog.repeat('82', 32), 'hex');
select is(
  public.consume_invite_rate_limit(
    'accept_short_code',
    pg_catalog.repeat('82', 32)
  ),
  true,
  'a completed ten-minute lockout starts a new bounded window'
);
select is(
  (
    select request_count
    from app_private.invite_rate_limits
    where scope = 'accept_short_code'
      and key_hash = pg_catalog.decode(pg_catalog.repeat('82', 32), 'hex')
  ),
  1,
  'new rate window resets to one without storing raw address or user material'
);

select lives_ok(
  $$
    select * from public.create_household_invite_with_short_code(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'wp07-03a-create-valid',
      repeat('91', 32),
      repeat('a1', 32),
      'member',
      null,
      168,
      24
    )
  $$,
  'Owner creates one hash-only short-code companion'
);
select is(
  (
    select pg_catalog.concat_ws(
      '|',
      pg_catalog.encode(invite.short_code_hash, 'hex'),
      invite.short_code_expires_at is not null,
      invite.short_code_expires_at <= invite.expires_at,
      invite.short_code_expires_at <= invite.created_at + interval '24 hours 1 minute'
    )
    from public.household_invites as invite
    where invite.token_hash = pg_catalog.decode(pg_catalog.repeat('91', 32), 'hex')
  ),
  pg_catalog.concat_ws('|', pg_catalog.repeat('a1', 32), true, true, true),
  'create stores only the code hash and a primary-bounded 24-hour expiry'
);
select is(
  (
    select pg_catalog.concat_ws(
      '|',
      preview.valid,
      preview.household_display_name,
      preview.inviter_display_name,
      preview.role
    )
    from public.preview_household_invite_short_code(
      pg_catalog.repeat('a1', 32)
    ) as preview
  ),
  't|Primary Local Household|Adult A|member',
  'short-code preview returns the same minimal identity-safe projection'
);
select ok(
  (
    select preview.expires_at = invite.short_code_expires_at
    from public.preview_household_invite_short_code(
      pg_catalog.repeat('a1', 32)
    ) as preview
    join public.household_invites as invite
      on invite.short_code_hash = pg_catalog.decode(
        pg_catalog.repeat('a1', 32),
        'hex'
      )
  ),
  'preview exposes the shorter code expiry instead of the link expiry'
);
select is(
  (
    select created
    from public.create_household_invite_with_short_code(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'wp07-03a-create-valid',
      repeat('92', 32),
      repeat('a2', 32),
      'member',
      null,
      168,
      24
    )
  ),
  false,
  'idempotent create replay does not mint a second capability'
);
select is(
  (
    select pg_catalog.encode(invite.short_code_hash, 'hex')
    from public.household_invites as invite
    where invite.token_hash = pg_catalog.decode(pg_catalog.repeat('91', 32), 'hex')
  ),
  pg_catalog.repeat('a1', 32),
  'idempotent replay cannot replace the original code hash'
);
select throws_ok(
  $$
    select * from public.create_household_invite_with_short_code(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'wp07-03a-create-invalid-hash',
      repeat('93', 32),
      'raw-code',
      'member',
      null,
      24,
      24
    )
  $$,
  'KFI02',
  'invalid invite input',
  'create accepts only a SHA-256-shaped code hash'
);
select throws_ok(
  $$
    select * from public.create_household_invite_with_short_code(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'wp07-03a-create-long-expiry',
      repeat('94', 32),
      repeat('a4', 32),
      'member',
      null,
      168,
      25
    )
  $$,
  'KFI02',
  'invalid invite input',
  'short-code capability cannot exceed 24 hours'
);
select throws_ok(
  $$
    select * from public.create_household_invite_with_short_code(
      '00000000-0000-4000-8000-000000000102',
      '20000000-0000-4000-8000-000000000101',
      'wp07-03a-create-member',
      repeat('95', 32),
      repeat('a5', 32),
      'member',
      null,
      24,
      24
    )
  $$,
  'KFI03',
  'invite permission denied',
  'ordinary member cannot create a short code'
);
select lives_ok(
  $$
    select * from public.preview_household_invite(repeat('91', 32))
  $$,
  'primary high-entropy link remains compatible'
);

select throws_ok(
  $$ select * from public.preview_household_invite_short_code(repeat('ff', 32)) $$,
  'KFI05',
  'invite invalid',
  'unknown code preview is generic'
);
select throws_ok(
  $$ select * from public.preview_household_invite_short_code('raw-short-code') $$,
  'KFI05',
  'invite invalid',
  'malformed code material is also generic'
);

select lives_ok(
  $$
    select * from public.create_household_invite_with_short_code(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'wp07-03a-create-expired',
      repeat('96', 32),
      repeat('a6', 32),
      'member',
      null,
      168,
      24
    )
  $$,
  'expiry fixture is created through the mediated command'
);
update public.household_invites
set created_at = pg_catalog.clock_timestamp() - interval '25 hours',
    short_code_expires_at = pg_catalog.clock_timestamp() - interval '1 hour 1 second'
where short_code_hash = pg_catalog.decode(pg_catalog.repeat('a6', 32), 'hex');
select throws_ok(
  $$ select * from public.preview_household_invite_short_code(repeat('a6', 32)) $$,
  'KFI05',
  'invite invalid',
  'expired short code does not reveal that the primary link remains active'
);

select lives_ok(
  $$
    select * from public.create_household_invite_with_short_code(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'wp07-03a-create-revoke',
      repeat('97', 32),
      repeat('a7', 32),
      'member',
      null,
      24,
      24
    )
  $$,
  'revoke fixture is created'
);
select lives_ok(
  $$
    select * from public.revoke_household_invite(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      (
        select invite.id
        from public.household_invites as invite
        where invite.short_code_hash = decode(repeat('a7', 32), 'hex')
      ),
      'wp07-03a-revoke-code'
    )
  $$,
  'Owner revokes the shared invite through the existing command'
);
select throws_ok(
  $$ select * from public.preview_household_invite_short_code(repeat('a7', 32)) $$,
  'KFI05',
  'invite invalid',
  'revoked code preview remains generic'
);

select lives_ok(
  $$
    select * from public.create_household_invite_with_short_code(
      '00000000-0000-4000-8000-000000000101',
      '20000000-0000-4000-8000-000000000101',
      'wp07-03a-create-accept',
      repeat('98', 32),
      repeat('a8', 32),
      'admin',
      null,
      24,
      24
    )
  $$,
  'accept fixture is created'
);
select is(
  (
    select pg_catalog.concat_ws('|', household_id, role, active_household_set)
    from public.accept_household_invite_short_code(
      '00000000-0000-4000-8000-000000000201',
      'wp07-03a-accept-valid',
      repeat('a8', 32),
      false
    )
  ),
  '20000000-0000-4000-8000-000000000101|admin|f',
  'authenticated code accept reuses the atomic membership transaction'
);
select throws_ok(
  $$ select * from public.preview_household_invite_short_code(repeat('a8', 32)) $$,
  'KFI05',
  'invite invalid',
  'consumed code preview does not reveal its state'
);
select is(
  (
    select member_id
    from public.accept_household_invite_short_code(
      '00000000-0000-4000-8000-000000000201',
      'wp07-03a-accept-valid',
      repeat('a8', 32),
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
  'same-user idempotent accept replay returns the original membership'
);
select throws_ok(
  $$
    select * from public.accept_household_invite_short_code(
      '00000000-0000-4000-8000-000000000102',
      'wp07-03a-accept-consumed-other',
      repeat('a8', 32),
      false
    )
  $$,
  'KFI05',
  'invite invalid',
  'another user sees only the generic invalid result for a consumed code'
);

select * from finish();
rollback;
