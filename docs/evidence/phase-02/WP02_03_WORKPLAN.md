# Phase 02 WP02-03 Work Plan

- 작성일: 2026-07-28
- 기준 commit: `ddbf16d`
- Work Package: WP02-03 First household onboarding
- 상태: COMPLETE
- 선행 결과: WP02-02 implementation run `30367899904`와 evidence run `30368412746` 모두 final CI gate PASS

## Requirements

| ID | 이번 vertical slice |
|---|---|
| WP02-03 | transactional household + Owner membership, name/timezone, active household state와 empty Today route를 구현한다. |
| FR-HH-001 | 인증된 성인의 profile bootstrap, household, Owner membership과 active selection을 한 server transaction으로 생성한다. |
| FR-HH-002 partial | IANA timezone을 사용자가 확인·입력하며 server constraint가 최종 검증한다. 기존 반복 항목 변경 영향 설명은 후속 Settings 범위다. |
| FR-SET-001 partial | 첫 onboarding에서 성인 display name과 locale/timezone profile을 최소 정보로 확정한다. avatar/settings 편집은 후속이다. |
| D-016 | 첫 household command는 이미 active membership이 있는 사용자의 추가 생성을 거부하고 자동 탈퇴·자동 전환하지 않는다. |
| D-047 | household domain/application은 Flutter, Riverpod, Supabase SDK에 의존하지 않는다. |
| D-048 | household creation은 client idempotency key와 server request hash를 사용한다. |
| D-049 | cold restore/account change마다 server의 active selection을 다시 확인하며 client boolean이나 household ID를 권한 근거로 신뢰하지 않는다. |

## Server Command Contract

- forward-only migration에 private idempotency record와 `public.create_first_household` RPC를 추가한다.
- 입력은 `idempotency_key`, household name, Owner display name, locale, IANA timezone뿐이다.
- authenticated user ID는 `auth.uid()`에서 얻고 household/member UUID와 `owner` role은 server가 생성한다.
- profile row를 생성 또는 확인하고 row lock으로 같은 사용자의 concurrent create를 serialize한다.
- 같은 idempotency key + 같은 normalized request는 최초 household/member 결과를 반환한다.
- 같은 key + 다른 request, 이미 active membership, unauthenticated, invalid input은 서로 다른 stable SQLSTATE로 거부한다.
- household, Owner member, owner pointer, active selection과 idempotency result는 같은 transaction에서 commit 또는 rollback한다.
- direct household/member write grant는 추가하지 않는다.

## Flutter Vertical Slice

1. household domain value/result/repository와 application onboarding controller를 추가한다.
2. Supabase data source가 self active-selection read와 `create_first_household` RPC만 호출한다.
3. auth restore는 실제 active-household repository 결과를 확인한 뒤 no-household/active-household 상태를 확정한다.
4. 조회 실패는 onboarding으로 오인하지 않고 protected route를 닫은 recovery state로 표시한다.
5. `/onboarding/household` form은 display name, household name, locale과 IANA timezone을 검증한다.
6. 같은 form retry는 같은 idempotency key를 재사용하고 입력이 바뀌면 새 key를 만든다.
7. 성공 시 auth active-household 상태를 갱신하고 `/today`의 localized empty state로 이동한다.
8. Google sign-in launcher는 계속 unavailable이며 tests는 synthetic session/repository override를 사용한다.

## Validation

- clean reset, schema lint와 기존 99개 DB test 회귀
- unauthenticated/anon execute deny와 authenticated execute allow
- invalid name/display name/locale/timezone/key deny 및 partial write 0
- existing active user additional create deny
- household + Owner + pointer + profile + active selection atomic result
- same-key retry same result/count/version, changed payload conflict, new key active conflict
- created Owner same-household read와 outsider deny
- repository DTO/payload/failure mapping, malformed provider response fail-closed
- auth cold restore active/none/failure routing
- onboarding form validation, duplicate tap/retry, safe errors, EN/KO/pseudo와 200% text
- success route `/today`, empty state, logout/protected-route regression
- full Flutter quality, dependency audit, backend gate, dev/prod APK와 GitHub final gate

## Explicit Non-scope

- Google OAuth/provider console, Android real device와 real two-adult account
- invite token/create/preview/accept/deep-link continuation — WP02-04
- role change/removal/leave/Owner transfer — WP02-05
- chore creation/template/navigation — Phase 03
- notification permission prompt, analytics provider event, remote production migration
- Managed Child, guardian, acting context — P1

## Privacy / Operations

- synthetic UUID와 `.invalid` fixture만 사용하며 token, JWT, email 또는 raw provider error를 evidence/log에 넣지 않는다.
- RPC는 free-form input을 log하지 않고 Flutter에도 raw PostgREST message를 노출하지 않는다.
- 새 runtime dependency, Android permission, telemetry와 remote secret은 추가하지 않는다.
- first-household table/function은 production remote에 push하지 않고 local/CI migration으로만 검증한다.

## Stop / Rollback

- partial household/profile/member/selection row가 남거나 중복 create가 성공하면 다음 WP로 진행하지 않는다.
- active household 조회 실패가 onboarding으로 route되거나 client-supplied identity/role/ID가 server authority가 되면 중단한다.
- remote 적용 전 rollback은 WP02-03 migration/feature commit revert와 clean reset이다.
- remote 적용 후에는 migration을 수정·삭제하지 않고 forward fix한다.

## Next Entry Condition

- local/remote automated gates와 evidence가 green이어야 WP02-04 invite로 진입한다.
- Google/provider/device validation은 계속 deferred이며 Phase 02 Exit Gate 완료를 선언하지 않는다.
