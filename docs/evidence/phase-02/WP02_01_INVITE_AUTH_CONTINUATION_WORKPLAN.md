# Phase 02 WP02-01 Invite/Auth Continuation Work Plan

- 작성일: 2026-07-29
- 기준 commit: `42c2ab6`
- Work Package: WP02-01 — Google sign-in 전후 invitation continuation
- 상태: IMPLEMENTED — LOCAL + REMOTE AUTOMATED PASS / LIVE E2E PENDING

## Requirements

| ID | 이번 vertical slice |
|---|---|
| FR-AUTH-003 / FR-AUTH-004 | Google sign-in 요청 뒤 provider session event가 들어오면 active household를 다시 해석하고 안전한 continuation route로 이동한다. |
| WP02-04 / Household invite | HTTPS invite token을 URL에서 즉시 제거하고 app-process memory에만 보관한 뒤 로그인 후 preview와 accept를 계속한다. |
| Security / Privacy | raw invite token을 query, route, log 또는 evidence에 남기지 않고 terminal accept 뒤 pending state를 제거한다. |

## Scope

1. unauthenticated 상태에서 `/invite/:token`을 열어 token capture와 `/invite` scrub을 확인한다.
2. invitation 화면의 sign-in action이 raw token 없는 `/sign-in?continue=invite`로 이동하는지 확인한다.
3. Google sign-in launcher 요청 뒤 provider의 authenticated session event를 주입한다.
4. no-household 해석 뒤 onboarding이 아니라 `/invite`로 복귀하고 preview/accept가 재개되는지 확인한다.
5. accept가 active household를 설정하고 Today로 이동하며 pending token을 제거하는지 확인한다.

## Explicit Non-scope

- 실제 Google account chooser, OAuth token 또는 Supabase session 발급
- ADB target 연결, APK 설치, App Link 클릭 또는 process-death 복원
- raw token, 이메일, device serial, household/member UUID의 evidence 저장
- production provider 또는 Play App Signing 검증

## Validation

- focused Flutter widget test
- complete Flutter test suite
- Flutter analyze
- repository self-test, workflow contract, secret scan
- remote GitHub Actions

## Stop / Rollback

- token이 URI/query/log에 다시 나타나거나 영구 storage가 필요해지면 구현을 중단하고 D/FR 계약을 재검토한다.
- 통합 테스트가 wiring 결함을 드러내면 가장 작은 runtime fix와 회귀 테스트만 포함한다.
- rollback은 이 work plan, 관련 test/runtime 변경과 evidence를 함께 revert한다. DB/API/provider 변경은 없다.

## Completion Boundary

- 이 검증은 실제 Google 및 두 기기 E2E를 대체하지 않는다.
- 실제 성인 A/B가 두 Android 기기에서 preflight, Google session, invite accept, cold restore와 account-switch purge를 통과해야 WP02-01 전체가 완료된다.

## Current Result

- implementation commit `f8b1764`에서 invitation/auth continuation 통합 widget test를 추가했다.
- focused test 7개, 전체 Flutter test 177개와 repository self-test 39개가 통과했다. 1개 opt-in live test는 의도대로 skip했다.
- analyzer issue 0, coverage 77.52%, secret finding 0, generated drift 0이다.
- GitHub Actions run `30416587279`의 foundation job 5개와 final gate가 모두 통과했다.
- 실제 Google account, Supabase live session과 두 Android 기기는 사용하지 않았으므로 live E2E는 pending이다.
