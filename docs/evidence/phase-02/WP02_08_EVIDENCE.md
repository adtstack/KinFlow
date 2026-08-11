# Phase 02 WP02-08 Active Household Switching Evidence

- Work Package: WP02-08 Active household switching
- 기준 commit: base `a85f262`; implementation은 2026-08-09 현재 workspace
- 검증일: 2026-08-09
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, local PostgreSQL/Docker stack
- 결과: **LOCAL AUTOMATED PASS / HOSTED·REAL-ACCOUNT·MULTI-DEVICE·PHYSICAL-DEVICE PENDING**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP02-08 | PASS FOR LOCAL AUTOMATED SLICE | 본인 가구 최소 목록, optimistic version 전환, local household 경계 정리, Settings 확인 UI와 authoritative Today 재진입이 구현·검증됐다. 실제 계정과 원격 환경은 남아 있다. |
| D-016 / D-017 | PASS | 한 사용자당 zero-or-one active selection을 유지하며 이미 가입한 다른 active adult household로만 전환한다. |
| D-048 / D-049 | PASS | 다른 target은 exact expected version에서 한 번만 변경되고 same-target 재요청은 version을 올리지 않는 no-op이다. unavailable target과 stale version은 stable generic code로 닫힌다. |
| FR-HH-005 | PARTIAL | 초대 후 다른 가입 가구로 되돌아가는 Settings 경로가 생겼다. hosted 초대·전환 propagation과 실제 성인 2인 검증은 남아 있다. |
| NFR-SEC-01 / NFR-PRIV-01 | PASS FOR LOCAL SLICE | target member와 caller는 서버가 파생한다. direct table update policy/grant는 없고 목록·audit은 최소 projection이다. |
| NFR-REL-01 | PASS FOR LOCAL SLICE | selection version, row/advisory lock, response-loss no-op, single-flight client와 local transition fail-closed가 자동화됐다. |
| NFR-A11Y-01 / NFR-I18N-01 | PASS FOR LOCAL WIDGETS | EN/KO/EN-XA exact key coverage, 30% pseudo expansion, 320×568·200% text와 scrollable confirmation dialog가 통과했다. |

## Implemented Boundary

### Server and authorization

- `20260809140000_active_household_switching.sql`은 `user_active_households.version`, version trigger, private content-free audit, `list_my_households()`와 `switch_active_household(uuid,bigint)`을 추가한다.
- `20260809140100_active_household_switching_list_fix.sql`과 `20260809140200_active_household_switching_null_active_fix.sql`은 exact list projection과 active pointer가 없는 최초 선택의 `false`/version `0` 의미를 순방향으로 교정한다.
- `20260809140300_active_household_switching_policy_cleanup.sql`은 남아 있던 direct update policy를 제거한다. authenticated client에는 select와 두 RPC execute만 열리고 active selection mutation은 RPC 전용이다.
- 목록은 household ID/name, 본인 member ID/role/version, active 여부와 selection version의 exact 7-key row만 반환한다. roster, owner, member count, invite, billing과 profile 정보는 포함하지 않는다.
- switch input은 target household ID와 expected selection version뿐이다. target member는 `auth.uid()`의 active membership에서 파생하며 unrelated, removed 또는 deleted target은 동일한 `KFH06`으로 거부한다.
- private audit은 auth user, 이전/다음 household ID, 이전/다음 selection version과 시각만 기록하고 client/service direct read grant를 갖지 않는다.

### Flutter and local isolation

- household selection domain/repository/data source는 exact snake_case DTO key 수, UUID, role, membership version, single active row와 switch version advance를 검증한다.
- controller는 retained list, load/switch single-flight, typed provider/conflict/local-state failure와 authoritative switch result를 표현한다.
- explicit household transition은 encrypted read cache, submitted guided-setup resume와 pending invite continuation을 먼저 정리한 뒤 새 active-household snapshot을 쓴다.
- auth credential, notification installation endpoint와 RevenueCat user identity는 household-bound data가 아니므로 전환 purge 대상에서 제외한다.
- local purge/write가 실패하면 auth lifecycle은 `localPurgeFailed`로 잠겨 이전 또는 새 household content를 노출하지 않는다.
- Settings의 `/settings/households` 화면은 현재 가구를 비활성 표시하고 다른 가구를 확인 dialog 뒤 전환한다. 성공하면 `/today`로 이동해 새 active household 기준 provider를 다시 구성한다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| ordered local migration apply | PASS, `20260809140000`부터 `20260809140300`까지 reset 없이 순방향 적용 |
| focused pgTAP/RLS | PASS, active switch 35 + runtime policy 28 + foundation RLS 37 + household authorization 62 = 162 tests |
| full local pgTAP/RLS | PASS, 54 files / 2,701 tests / failure 0 |
| focused Flutter slice | PASS, DTO/repository/controller/local transition/auth composition/widget/localization/architecture 62 tests |
| full Flutter regression | PASS, 1,022 tests; existing opt-in local Supabase HTTP adapter test 1 skipped; failure/error 0 |
| localization generation and contract | PASS, generated EN/KO/EN-XA coverage exact and pseudo messages at least 30% expanded |
| exact analyzer | PASS, Flutter 3.44.7 / Dart 3.12.2 issue 0 |
| exact formatter | PASS, `lib` and `test` 590 files checked, changed 0 |
| workspace whitespace gates | PASS, tracked diff check and WP02-08 untracked trailing-whitespace scan issue 0 |

## Security and Privacy Findings

1. authenticated direct insert/update bypass는 허용되지 않으며 `active_household_update_self` policy도 제거됐다.
2. security-definer RPC는 empty search path를 사용하고 authenticated role에만 exact execute grant가 있다.
3. caller는 auth user ID나 target member ID를 제출할 수 없다. cross-household와 removed-member probe는 존재 여부를 구분하지 않는 `KFH06`만 반환한다.
4. local household 전환은 server-first다. 서버 성공 뒤 local isolation을 확인할 수 없으면 새 content를 열지 않고 재인증이 필요한 lock 상태로 닫힌다.
5. 새 raw SDK/SQL error, household name, member display name, token 또는 provider identity를 audit/log에 기록하지 않는다.

## Manual and Deferred Validation

- 실제 Google 계정 하나가 두 household에 가입한 뒤 A→B→A 전환하는 hosted 검증은 **NOT RUN**이다.
- 두 실제 성인·두 기기의 동시 stale version, response-loss retry, push installation 재동기화와 Today propagation은 **NOT RUN**이다.
- production/hosted Supabase migration, production-size query plan과 forward rollback rehearsal은 **NOT RUN**이다.
- empty local database에서의 clean reset은 이번 기능 우선 작업에서 **NOT RUN**이다. 기존 local stack에 migration을 순방향 적용한 뒤 전체 pgTAP을 실행했다.
- Android/iOS physical device, TalkBack/VoiceOver, process death와 encrypted storage forensic은 **NOT RUN**이다.

## Remaining Risks and Completion Boundary

1. 로컬 자동화는 green이지만 hosted role/JWT/header 동작과 실제 다중기기 전파가 없으므로 Phase 02/G2를 완료로 전환하지 않는다.
2. server switch 성공 뒤 local purge가 실패하면 의도적으로 content lock과 재인증이 필요하다. 자동화는 안전성을 검증했지만 실제 secure-storage 장애 UX는 기기 검증이 남아 있다.
3. local full pgTAP은 현재 stack의 순방향 upgrade를 검증했으며 fresh-reset migration 재현성은 별도 Gate다.
4. household leave/delete/ownership transfer와 active selection의 결합은 이번 범위가 아니다.
5. multi-household combined Today, automatic/recent household switching과 Managed Child acting context는 추가하지 않았다.

## Rollback

- remote 적용 전에는 Settings entry와 WP02-08 migration/client 변경을 함께 제외할 수 있다.
- remote 적용 후에는 적용 migration을 수정·삭제하지 않는다. Settings entry를 숨기고 switch RPC execute를 revoke하는 순방향 migration으로 mutation을 먼저 닫는다.
- membership과 invite-time initial selection은 유지하며 기존 사용자 데이터를 파괴하는 rollback은 사용하지 않는다.

## Next Entry Condition

- 기능 우선순위를 계속할 때 다음 household slice는 leave/ownership invariant와 active selection 복구를 하나의 작은 계약으로 먼저 고정한다.
- 실제 계정 검증은 사용자 지시에 따라 hosted·Store·다중기기·physical-device Gate와 함께 가장 마지막에 수행한다.
