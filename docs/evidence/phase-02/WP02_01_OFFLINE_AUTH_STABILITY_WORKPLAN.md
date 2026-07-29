# Phase 02 WP02-01 Offline Auth Stability Work Plan

- 작성일: 2026-07-29
- 기준 commit: `f207207`
- Work Package: WP02-01 — live 27-check traceability / offline auth UI boundary
- 상태: IMPLEMENTED — LOCAL + REMOTE AUTOMATED PASS / LIVE NETWORK CHECKS PENDING

## Requirements

| ID | 이번 vertical slice |
|---|---|
| `google_offline_stable` | Google/Supabase sign-in이 일시적으로 실패하면 generic retryable sign-in UI에 남고 protected route를 열지 않는다. |
| `offline_launch_stable` | startup session restore가 network 상태 때문에 확정되지 않으면 no-session/onboarding으로 추정하지 않고 fail-closed auth state를 표시한다. |
| Security / Privacy | provider exception, token, email과 network detail을 UI/log/evidence에 노출하지 않는다. |

## Scope

1. sign-in request가 `temporarilyUnavailable`로 실패하면 stable localized message와 enabled retry action을 확인한다.
2. retry가 동일한 launcher boundary를 다시 호출하고 Supabase session event 전에는 protected route를 열지 않는지 확인한다.
3. startup restore가 `temporarilyUnavailable`이면 Today/onboarding이 아니라 locked sign-in route를 표시하는지 확인한다.
4. provider/data-source/controller의 기존 failure mapping과 widget route를 함께 추적한다.

## Explicit Non-scope

- 실제 airplane mode, DNS/TLS failure, Google Play Services 또는 Supabase outage
- 실제 Google account chooser와 Android 기기 조작
- provider retry/backoff 정책 변경
- DB/API/config/dependency 변경

## Validation

- focused app-shell widget tests
- full Flutter quality gate
- repository contract/secret scan
- GitHub Actions

## Stop / Rollback

- temporary failure 뒤 Today/onboarding이 열리거나 retry action이 영구 비활성화되면 실패다.
- raw provider detail이 status, exception string 또는 logger evidence에 나타나면 실패다.
- rollback은 widget tests/workplan/evidence 변경을 함께 revert한다. runtime/data/provider rollback은 없다.

## Completion Boundary

- synthetic failure는 deterministic UI/state contract만 증명한다.
- 실제 Android 기기에서 Google chooser 중 network 차단과 offline cold launch를 관찰해야 두 live check가 최종 PASS다.

## Current Result

- implementation commit `914f19e`에서 temporary Google failure와 offline restore widget contract를 추가했다.
- focused app-shell test 13개, 전체 Flutter test 182개와 repository self-test 39개가 통과했다. 1개 opt-in live test는 의도대로 skip했다.
- analyzer issue 0, coverage 78.52%, secret finding 0, generated drift 0이다.
- GitHub Actions run `30418063029`의 foundation job 5개와 final gate가 모두 통과했다.
- 실제 network 차단, Google chooser와 Android cold launch는 실행하지 않았으므로 두 live check는 pending이다.
