# Phase 02 WP02-03 Evidence

- Work Package: WP02-03 First household onboarding
- 기준 commit: base `ddbf16d`; implementation `ce6112f`
- 검증일: 2026-07-28
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 28.3.2
- 결과: **LOCAL + REMOTE AUTOMATED PASS / GOOGLE·ANDROID DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP02-03 | PASS | transactional first-household RPC, Owner membership, profile/timezone, active selection, onboarding form과 empty Today route를 구현했다. |
| FR-HH-001 | PASS FOR FIRST HOUSEHOLD | profile, household, 정확히 한 Owner, Owner pointer, active selection과 idempotency result가 한 transaction에서 생성된다. |
| FR-HH-002 | PARTIAL | onboarding에서 IANA timezone을 확인하며 server validator가 최종 거부한다. 기존 반복 항목 영향 설명은 후속 Settings 범위다. |
| FR-SET-001 | PARTIAL | 첫 성인 display name, locale, timezone을 profile bootstrap에 반영한다. avatar와 후속 편집은 non-scope다. |
| D-016 | PASS | 이미 active membership이 있으면 `KFH03`으로 추가 first-household 생성을 거부하며 자동 전환·탈퇴하지 않는다. |
| D-047 | PASS | household domain/application은 Flutter, Riverpod, Supabase SDK를 import하지 않으며 architecture test가 경계를 검증한다. |
| D-048 | PASS | client UUID idempotency key와 server SHA-256 normalized request hash로 same-request retry를 재사용한다. |
| D-049 | PASS | cold restore와 account change가 server active selection을 조회하며 조회 실패를 “가구 없음”으로 취급하지 않는다. |

## Implementation

- `20260728010000_first_household_onboarding.sql` forward migration이 private idempotency record와 authenticated-only `create_first_household` RPC를 추가한다.
- RPC 입력에는 user, role, household ID와 member ID가 없고 caller identity는 `auth.uid()`에서, Owner role과 IDs는 server에서 정한다.
- profile row lock이 같은 사용자의 concurrent request를 직렬화하고, 같은 key/request는 최초 결과를 반환하며 key 재사용·active household·invalid input·unauthenticated를 stable SQLSTATE로 분리한다.
- Flutter household slice는 SDK-independent domain/application, provider mapping, Supabase adapter, secure UUIDv4 generator와 auto-disposed onboarding state로 구성된다.
- auth lifecycle은 active selection의 `loaded`/`absent`/`failed`를 분리한다. 실패 상태에서는 product route를 닫고 안전한 재시도·로그아웃만 제공한다.
- `/onboarding/household`은 display name, household name, locale, IANA timezone을 확인하고 같은 normalized form retry에 같은 key를 사용한다. 성공하면 active state를 갱신하고 `/today` empty state로 이동한다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean `supabase db reset` | PASS, ordered forward migrations 3개와 synthetic seed 적용 |
| schema lint warning gate | PASS, application schema error 0 |
| pgTAP/RLS | PASS, WP02-03 37 + foundation 37 + WP02-02 62 = 136 tests |
| first-household transaction | PASS, profile/household/Owner/pointer/active selection/idempotency result exactness |
| idempotency/attack matrix | PASS, same-key retry stable; changed request/new key/active user/anon/direct write/outsider deny |
| Edge health + Flutter live adapter | PASS |
| repository quality | PASS, 127 Flutter tests + 1 opt-in skip, analyze issue 0, coverage 1,629/1,958 (83.2%) |
| route/widget/accessibility | PASS, active/none/failure routing, EN/KO/pseudo, 200% text, 48dp action |
| config / secret / codegen | PASS, high-confidence secret 0, generated drift 0 |
| dependency license / OSV | PASS, Pub 143 / npm 15, 163 packages, known vulnerability 0 |
| Android APK audit | PASS, dev/prod package IDs, API 24/36, backup disabled, exact permission allowlist |
| GitHub Actions CI | PASS, run `30372425851`; quality, dependency, backend, dev/prod Android와 final gate 성공 |

상세 실행 요약은 `logs/wp02-03-first-household-onboarding.log`에 있다. CI report, APK와 coverage 원본은 ignored local artifact다.

Remote run: <https://github.com/adtstack/KinFlow/actions/runs/30372425851>

## Data / API / Privacy

- production Supabase project에는 link/push하지 않았고 실제 사용자·household·credential을 사용하지 않았다.
- pgTAP은 deterministic UUID와 `.invalid` synthetic identity만 사용한다. evidence에는 token, JWT, publishable key와 raw provider message를 저장하지 않았다.
- idempotency table은 raw form 대신 32-byte request hash와 generated result IDs만 저장하며 client role은 table을 읽거나 쓸 수 없다.
- 새 runtime dependency, Android permission, notification prompt와 telemetry event를 추가하지 않았다.

## Manual / Deferred Validation

- 사용자 결정에 따라 Google provider 설정, 실제 Supabase session, Android device와 실제 성인 2인 검증은 Phase 02 마지막 통합 단계까지 **DEFERRED**다.
- remote project migration rehearsal, backup/restore와 production query plan은 **NOT RUN**이다.
- 로컬/CI debug APK는 통과했지만 실제 기기 interaction·키보드·process death 검증을 대신하지 않는다.

## Remaining Risks / Completion Boundary

1. 초대 token/create/preview/accept/deep-link continuation은 WP02-04에서 구현해야 두 번째 성인이 가구에 참여할 수 있다.
2. 역할 변경·제거·Owner transfer는 WP02-05, adult activation handoff와 end-to-end authorization은 WP02-06~07 범위다.
3. Google 계정과 Android 실제 기기를 사용하지 않았으므로 Phase 02 Exit Gate는 아직 통과하지 않았다.
4. production remote에 migration을 적용하지 않았으므로 실제 backup/rollback rehearsal 증거는 없다.

## Rollback

- remote 적용 전에는 implementation commit을 revert하고 clean reset으로 WP02-02 상태를 확인한다.
- remote 적용 후에는 이 migration을 수정·삭제하지 않고 function/constraint를 교정하는 forward migration을 추가한다.

## Next Entry Condition

- implementation commit `ce6112f`의 GitHub Actions 5개 foundation job과 final gate가 모두 green이다.
- 다음 순차 작업은 WP02-04 invite token, preview/accept와 login 전후 continuation이다.
- Google provider/device는 계속 deferred이며 이를 WP02-03 또는 Phase 02 전체 완료로 간주하지 않는다.
