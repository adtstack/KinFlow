# Phase 02 WP02-01 Invite/Auth Continuation Evidence

- 검증일: 2026-07-29
- implementation commit: `f8b17647dae46efe294083f45e14799e89f7d4b2`
- 상태: **LOCAL + REMOTE AUTOMATED PASS / LIVE GOOGLE TWO-DEVICE E2E NOT RUN**
- 범위: HTTPS invitation capture부터 provider session 이후 preview/accept 재개까지의 device-independent runtime wiring

## Requirement Trace

| 요구사항 | 결과 |
|---|---|
| FR-AUTH-003 / FR-AUTH-004 | PASS WITH SYNTHETIC SESSION — sign-in launcher 요청 뒤 authenticated provider event를 받으면 household resolution을 거쳐 safe invitation continuation으로 복귀한다. |
| WP02-04 / Household invite | PASS — raw token capture, route scrub, sign-in 왕복, preview 재생성, accept와 active household 전환을 하나의 widget flow에서 검증했다. |
| Security / Privacy | PASS — sign-in URI에는 `continue=invite`만 있고 raw token/query는 없으며, token은 process-memory store에만 유지되고 성공 직후 제거된다. |

## Automated Scenario

1. unauthenticated app에서 `/invite/:token`을 연다.
2. router가 즉시 raw token 없는 `/invite`로 scrub하고 pending memory store만 유지한다.
3. invitation의 sign-in action으로 `/sign-in?continue=invite`에 이동한다.
4. Google sign-in launcher가 정확히 한 번 호출된다.
5. fake provider가 authenticated session event를 발행한다.
6. active household가 없는 상태를 해석한 뒤 onboarding이 아닌 `/invite`로 복귀한다.
7. preview와 enabled accept action이 다시 나타난다.
8. accept는 `setActiveHousehold=true`로 한 번 실행되고 pending token을 제거한 뒤 Today로 이동한다.

이 시나리오는 production route, notifier, lifecycle controller, invite controller와 ephemeral store wiring을 그대로 사용하며 auth/invite/household repository boundary만 fake로 대체한다.

## Local Validation

| 검증 | 결과 |
|---|---|
| focused invitation widget suite | PASS, 7/7 |
| Flutter full suite | PASS, 177 passed / 1 opt-in live skipped |
| Flutter analyze | PASS, issue 0 |
| Flutter format | PASS, 158 files / change 0 at final gate |
| repository self-test | PASS, 39/39 |
| workflow/action lint | PASS, 5 jobs / 17 pinned action uses / `contents: read` |
| public config / secret / codegen | PASS, high-confidence secret 0 / generated drift 0 |
| coverage | PASS, 2,396/3,091 lines (77.52%) |
| `git diff --check` | PASS |

Toolchain은 Flutter 3.44.7, Dart 3.12.2 exact pin을 사용했다.

## Remote Validation

GitHub Actions [run `30416587279`](https://github.com/adtstack/KinFlow/actions/runs/30416587279)은 implementation commit에서 최종 PASS했다.

| job | 결과 |
|---|---|
| dependency vulnerability and license audit | PASS, 1m20s |
| Supabase DB, RLS, and contract | PASS, 2m59s |
| quality and tests | PASS, 3m33s |
| Android prod debug | PASS, 4m41s |
| Android dev debug | PASS, 4m54s |
| final CI gate | PASS, 5s |

## Data / API / Security / Privacy

- runtime source, DB migration, RLS, RPC, Edge/API, Android manifest, provider 설정과 dependency는 변경하지 않았다.
- test harness가 기존 fake auth repository와 launcher를 노출해 실제 production state transition을 구동하도록 확장했다.
- raw invite token은 route/query/evidence/log에 기록하지 않는다. tracked source의 고정 synthetic fixture는 실제 credential이나 사용자 데이터가 아니다.
- repository secret scan은 finding 0으로 통과했다.

## Manual / Deferred Validation

- 실제 Google account chooser와 Supabase live session은 **NOT RUN**이다.
- 서로 다른 Android target 2대의 APK install/preflight는 **NOT RUN**이다.
- browser에서 HTTPS App Link를 눌러 앱이 꺼진 상태의 cold start를 만드는 절차는 **NOT RUN**이다.
- 실제 성인 A/B household membership, logout/cold restore/account-switch 관찰은 **NOT RUN**이다.

## Remaining Risks / Completion Boundary

1. synthetic provider event는 Google Credential Manager와 Supabase OAuth callback의 OEM별 실제 동작을 증명하지 않는다.
2. ephemeral token은 같은 app process의 로그인 왕복만 보장한다. 스펙상 persistent storage는 금지되어 있으며 OS process kill 시 원래 HTTPS link를 다시 열어야 한다.
3. widget test는 app route/state wiring을 검증하지만 Android OS의 verified-link dispatch는 기존 API 36 probe와 실제 두 기기 실행으로 별도 확인해야 한다.
4. WP02-01과 Phase 02 Exit Gate는 privacy-safe completion JSON이 live 두 기기 관찰로 채워질 때까지 미완료다.

## Rollback

- implementation commit `f8b1764`을 revert하면 통합 test와 work plan이 제거된다.
- runtime/data/provider mutation이 없어 migration 또는 remote rollback은 없다.

## Next Entry Condition

1. 서로 다른 Android target 2대와 성인 Google test account 2개 준비
2. current dev APK 설치 후 two-device preflight PASS
3. HTTPS invitation cold start와 실제 Google/Supabase session으로 동일 continuation 실행
4. logout, cold restore와 account-switch isolation까지 runbook의 exact check를 관찰
5. ignored completion JSON을 actual APK와 함께 validator에 전달해 PASS

위 live 결과 전에는 이 synthetic-session 통합 테스트를 `4-3b-2` 완료 증거로 사용하지 않는다.
