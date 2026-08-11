# Phase 02 WP02-09 Household Departure Handoff Evidence

- Work Package: WP02-09 Household departure handoff
- 기준 commit: base `a85f262`; implementation은 2026-08-09 현재 workspace
- 검증일: 2026-08-09
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, local PostgreSQL/Docker stack
- 결과: **LOCAL AUTOMATED PASS / HOSTED·REAL-ACCOUNT·MULTI-DEVICE·PHYSICAL-DEVICE PENDING**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP02-09 | PASS FOR LOCAL AUTOMATED SLICE | 기존 원자적 leave 결과의 authoritative fallback을 strict client result로 보존하고, 로컬 가구 경계 정리 뒤 auth 상태와 route에 직접 인계한다. |
| D-017 | PASS FOR LOCAL SLICE | 탈퇴한 membership은 즉시 tombstone되고 기존 transaction이 선택한 fallback 또는 no-household만 client가 소비한다. |
| D-048 / D-049 | PASS | actor member ID, expected member version과 idempotency key가 exact correlation되며 response replay의 fallback pair를 변경하지 않는다. |
| FR-HH-007 | PARTIAL | non-Owner leave, invite revoke, fallback/no-household handoff와 stale local-content 차단은 자동화됐다. assignment/provider ownership과 실제 계정·기기 전파는 남아 있다. |
| NFR-SEC-01 / NFR-PRIV-01 | PASS FOR LOCAL SLICE | client가 fallback을 선택하지 않고, 이전 household cache·guided resume·pending invite를 노출 전에 정리하며 raw provider 오류를 표시하지 않는다. |
| NFR-REL-01 | PASS FOR LOCAL SLICE | server-first single-flight, exact nullable pair, refresh-free auth commit와 local failure lock을 자동 검증했다. |
| NFR-A11Y-01 / NFR-I18N-01 | PASS FOR LOCAL WIDGETS | 기존 EN/KO/EN-XA 계약을 유지하고 320×568·200% pseudo text에서 destructive confirmation 전체가 scrollable하다. |

## Implemented Boundary

### Existing server transaction retained

- `public.leave_household`와 `manage-household-members`의 기존 계약을 변경하지 않았다.
- 기존 transaction은 actor membership tombstone, actor-created active invite revoke와 deterministic fallback selection을 함께 수행한다.
- response는 departed household/member/version/removal time과 `activeHouseholdId`/`activeMemberId` nullable pair를 반환한다.
- Owner는 기존 transfer-first invariant 때문에 leave action과 RPC 실행이 계속 금지된다.

### Strict client mapping and orchestration

- `LeaveHouseholdCommand`는 roster에서 얻은 actor member ID를 포함하고 repository는 response household/member/version/UTC removal time을 exact correlation한다.
- fallback 두 값이 모두 null이면 `HouseholdLeaveCompleted(null)`, 둘 다 valid UUID이면 하나의 `ActiveHousehold`로 변환한다.
- partial null, malformed UUID, mismatched actor 또는 generic member-command success는 invalid contract로 fail closed한다.
- controller는 server success 뒤 departure committer가 성공하기 전 `HouseholdMembersLeft`를 emit하지 않는다.

### Local isolation and auth handoff

- fallback이 있으면 encrypted read cache, submitted guided-setup resume와 pending invite continuation을 순서대로 purge한 뒤 authoritative fallback snapshot을 쓴다.
- fallback이 없으면 동일 participant를 purge한 뒤 active-household snapshot을 명시적으로 clear한다.
- auth credential, notification installation identity와 RevenueCat authenticated identity는 household-bound가 아니므로 유지한다.
- purge/write/clear가 실패하거나 auth session이 바뀌면 auth lifecycle은 `localPurgeFailed`로 잠기고 controller는 roster 없는 terminal failure를 emit한다.
- 성공 시 auth lifecycle은 별도 session/household refresh 없이 active-household 또는 no-household 상태를 직접 emit한다.

### UI and accessibility

- 기존 Family Members 화면의 destructive confirmation 뒤 leave command를 실행한다.
- 성공 시 root로 이동하고 auth route guard가 fallback이면 Today, no-household이면 onboarding을 선택한다.
- local handoff 실패는 sign-in recovery로 이동하며 departed roster를 다시 표시하지 않는다.
- confirmation title, body와 actions를 하나의 scrollable 영역에 배치하고 narrow width에서는 actions가 세로 overflow layout을 사용한다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| member lifecycle Edge contract | PASS, 22 tests / failure 0; exact paired nullable leave fallback 포함 |
| focused leave pgTAP/RLS | PASS, 1 file / 64 tests / failure 0 |
| full local pgTAP/RLS | PASS, 54 files / 2,701 tests / failure 0 |
| focused Flutter slice | PASS, repository/controller/local transition/auth lifecycle/member widget 48 tests / failure 0 |
| full Flutter regression | PASS, 1,032 tests; existing opt-in local Supabase HTTP adapter test 1 skipped; failure/error 0 |
| localization contract | PASS in full regression, EN/KO/EN-XA exact key coverage and pseudo expansion unchanged |
| exact analyzer | PASS, Flutter 3.44.7 / Dart 3.12.2 issue 0 |
| exact formatter | PASS, `lib` and `test` 592 files checked, changed 0 |
| workspace whitespace gates | PASS, targeted diff check and WP02-09 trailing-whitespace scan issue 0 |

## Security and Privacy Findings

1. fallback household/member는 client input이나 후속 목록 조회가 아니라 leave transaction response만 authority로 사용한다.
2. departed actor correlation과 nullable pair validation이 실패하면 no-household 성공으로 축소하지 않는다.
3. server leave 성공 뒤 local state transition이 실패하면 이전 roster와 protected content를 모두 닫고 재인증 recovery가 필요하다.
4. household transition participant에는 household-scoped cache와 continuation만 포함하며 계정 credential과 device installation identity는 보존한다.
5. UI와 domain failure는 stable localized message만 사용하고 SQL, SDK, token, household name 또는 member display name을 오류에 반영하지 않는다.

## Manual and Deferred Validation

- 실제 Google 계정 하나가 둘 이상의 household에 가입한 상태에서 current household를 나가고 fallback Today로 이동하는 hosted 검증은 **NOT RUN**이다.
- fallback이 없는 실제 계정의 onboarding 전환과 동일 기기의 secure-storage process-death recovery는 **NOT RUN**이다.
- 두 기기에서 leave와 active-household switch가 동시에 발생하는 propagation/concurrency 검증은 **NOT RUN**이다.
- hosted Edge/RPC, production migration, Android/iOS physical device, TalkBack/VoiceOver와 encrypted-storage forensic은 **NOT RUN**이다.
- Store purchase/entitlement owner와 leave가 결합된 provider ownership 검증은 **NOT RUN**이다.

## Remaining Risks and Completion Boundary

1. 로컬 자동화는 green이지만 hosted JWT/role/Edge propagation과 실제 계정 증거가 없으므로 Phase 02/G2를 완료로 전환하지 않는다.
2. local transition 실패는 의도적으로 auth lock을 유발한다. 실제 secure-storage 장애와 사용자의 재로그인 recovery UX는 기기 Gate가 남아 있다.
3. server fallback 선택과 별도의 active switch가 서로 경쟁하는 다중기기 ordering protocol은 이번 client-consumption 조각의 범위가 아니다.
4. assignment 재배정, billing provider ownership, household deletion과 Managed Child acting context는 변경하지 않았다.

## Rollback

- server schema/RPC 변경은 없으므로 database rollback은 필요하지 않다.
- client rollback은 persistent household cache와 guided/pending continuation도 함께 비활성화할 때만 이전 refresh handoff로 되돌릴 수 있다.
- local isolation을 유지한 채 UI만 숨겨야 하면 leave action을 runtime household capability로 차단하고 기존 Owner transfer/roster read는 유지한다.

## Next Entry Condition

- 기능 우선순위는 Phase 02의 남은 실제 권한 조각 또는 다음 미완성 product slice로 계속 진행할 수 있다.
- 실제 계정 검증은 사용자 지시에 따라 hosted·Store·다중기기·physical-device Gate와 함께 가장 마지막에 수행한다.
