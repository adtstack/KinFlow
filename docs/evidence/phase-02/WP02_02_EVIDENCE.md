# Phase 02 WP02-02 Evidence

- Work Package: WP02-02 Household schema/RLS
- 기준 commit: base `e27b4a8`; implementation `3016979`
- 검증일: 2026-07-28
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 28.3.2
- 결과: **LOCAL + REMOTE AUTOMATED PASS / GOOGLE·ANDROID DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP02-02 | LOCAL PASS | forward migration, authorization helpers, deferred Owner invariant와 full actor matrix를 materialize했다. |
| FR-HH-001 | PARTIAL | household당 정확히 한 active Owner와 pointer 일치를 DB가 보장한다. 실제 atomic creation command/UI는 WP02-03이다. |
| FR-HH-002 | PARTIAL | profile/household에는 PostgreSQL이 아는 IANA timezone만 저장된다. 변경 영향 UX는 후속이다. |
| NFR-SEC-01 | LOCAL PASS FOR HOUSEHOLD FOUNDATION | Owner/Admin/Member/removed/other-household/anon의 read 및 direct-write/cross-household 공격을 검증했다. 후속 feature table은 각 WP에서 추가 검증한다. |
| D-010 / D-013 | PASS | 역할 enum은 성인 `owner`, `admin`, `member`만 포함하며 Managed Child table은 없다. |
| D-016 / D-049 | PASS | active selection은 auth user/member/household composite binding을 유지하며 removed member에게 stale row를 숨긴다. |

## Implementation

- `20260728000000_household_authorization.sql` forward migration이 IANA timezone validator와 validated check constraints를 추가한다.
- `current_user_member_id`, `is_active_household_member`, `has_household_role`은 `security definer`, empty search path, active membership 기준으로 동작한다.
- partial unique index의 “최대 한 Owner”와 deferred constraint trigger의 “정확히 한 Owner + pointer 일치”를 결합한다. 유효한 atomic Owner transfer는 transaction 안에서 허용한다.
- `user_active_households` select/update policy는 현재 active membership의 정확한 member ID까지 일치해야 한다.
- household/member direct mutation grant는 계속 없으며 후속 RPC가 생기기 전 client write는 fail-closed다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean `supabase db reset` | PASS, ordered forward migrations 2개와 synthetic seed 적용 |
| schema lint warning gate | PASS, application schema error 0 |
| pgTAP/RLS | PASS, foundation 37 + WP02-02 62 = 99 tests |
| actor/role matrix | PASS, Owner/Admin/Member/removed/other-household/anon |
| invariant attacks | PASS, only Owner demotion/removal, second Owner, invalid/cross-household pointer 거부; atomic transfer 허용 |
| timezone matrix | PASS, UTC/Asia/Seoul/America/New_York 허용; unknown/posix/right zone 거부 |
| Edge health contract | PASS |
| Flutter live Supabase adapter | PASS |
| repository quality | PASS, 101 Flutter tests + 1 opt-in skip, analyze issue 0, coverage 1,271/1,499 (84.79%) |
| config / secret / codegen | PASS, high-confidence secret 0, generated drift 0 |
| dependency license / OSV | PASS, Pub 143 / npm 15, lockfile offline vulnerability scan |
| GitHub Actions CI | PASS, run `30367899904`; quality, dependency, backend, dev/prod Android와 final gate 성공 |

상세 실행 요약은 `logs/wp02-02-household-authorization.log`에 있다. CI report와 coverage 원본은 ignored local artifact다.

Remote run: <https://github.com/adtstack/KinFlow/actions/runs/30367899904>

## Data / API / Privacy

- production Supabase project에는 link/push하지 않았고 실제 사용자 데이터나 credential을 사용하지 않았다.
- deterministic UUID와 `.invalid` synthetic identity만 사용했다. token, local JWT, key와 이메일 payload는 evidence에 저장하지 않았다.
- 기존 foundation migration은 수정하지 않았고 새 forward migration만 추가했다.
- Edge/OpenAPI/Flutter UI/runtime dependency와 Android permission은 변경하지 않았다.

## Manual / Deferred Validation

- Google provider, 실제 Supabase session, Android device와 실제 성인 2인 검증은 사용자 결정에 따라 Phase 02 마지막 통합 단계까지 **DEFERRED**다.
- remote project migration rehearsal, backup/restore, production query plan은 **NOT RUN**이다.
- dev/prod APK와 final CI gate는 implementation run `30367899904`에서 통과했다.

## Remaining Risks / Completion Boundary

1. WP02-02 local authorization foundation만 통과했으며 가구 생성 command/UI는 아직 없다.
2. 실제 Google 계정이나 Android 기기를 사용하지 않았으므로 Phase 02 Exit Gate는 통과하지 않았다.
3. 이후 invite/chore/event 등 household-owned table마다 composite integrity와 RLS matrix를 별도로 확장해야 한다.
4. remote migration은 적용하지 않았으므로 실제 project backup/rollback rehearsal 증거는 없다.

## Rollback

- remote 적용 전에는 새 migration/test/doc alignment commit을 revert하고 clean reset으로 foundation 상태를 확인한다.
- remote 적용 후에는 migration을 삭제·수정하지 않고 trigger/policy/constraint를 교정하는 forward migration을 추가한다.

## Next Entry Condition

- implementation commit `3016979`의 GitHub Actions quality, dependency, backend, dev/prod Android build와 final gate가 모두 green이다.
- 다음 순차 작업은 WP02-03 first-household onboarding이다.
- Google provider/device는 계속 deferred이며 이를 WP02-02 또는 Phase 02 전체 완료로 간주하지 않는다.
