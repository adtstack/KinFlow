# Phase 02 WP02-01 Two-Adult E2E Evidence Contract Work Plan

- 작성일: 2026-07-29
- 기준 commit: `54f0cbd`
- Work Package: WP02-01 — real dev Google Android / two-adult completion evidence
- 상태: IMPLEMENTED — LOCAL AUTOMATED PASS / LIVE E2E PENDING
- 선행 결과: provider/App Link configured, two-device preflight automated, live account/device E2E pending

## Requirements

| ID | 이번 vertical slice |
|---|---|
| WP02-01 / Phase 02 manual gate | 실제 성인 2인·두 기기 실행이 필수 단계 전부를 통과한 경우에만 machine-checkable completion evidence를 수용한다. |
| FR-AUTH-003 / FR-AUTH-004 | A/B Google login, Supabase session 전 protected route 차단, cold-start invite continuation을 각각 명시적으로 기록한다. |
| FR-AUTH-005 / D-049 | B logout, account chooser 재진입과 이전 household route/cache 격리를 필수 PASS로 요구한다. |
| WP02-04 / D-055 | invite 1회 발급, preview/accept, replay/concurrent accept idempotency를 필수 PASS로 요구한다. |
| Security / Privacy | 이메일, token, invite URL/token, ADB serial, UUID prefix와 free-form note를 schema상 저장할 수 없게 한다. |

## Scope

1. exact-key JSON 계약과 tracked `not_run` template를 추가한다.
2. 환경/package, 40-hex commit, 64-hex APK digest, UTC timestamp와 두 device alias/API/preflight 결과를 검증한다.
3. completion CLI는 commit이 현재 repository에 존재하는지 확인하고 전달받은 APK를 직접 SHA-256 hashing해 evidence digest와 대조한다.
4. login/session/household/invite/cold-start/logout/account-switch/negative-path의 exact check set을 고정한다.
5. CLI completion gate는 모든 check와 두 device preflight가 `pass`인 경우에만 성공한다.
6. 결과 출력은 check 수와 환경/package만 포함하고 입력 경로, hash 또는 임의 문자열을 재출력하지 않는다.
7. template mode는 `not_run`과 명시적 hash placeholder를 허용하지만 completion mode에서는 거부한다.

## Explicit Non-scope

- 실제 Google account chooser 또는 Supabase session 실행
- ADB target 연결, APK 설치, App Link re-verification
- 사용자의 이메일, provider client ID, household/member UUID 또는 invite token 수집
- screen recording/screenshot 원본 저장 또는 자동 업로드
- production provider, Play App Signing과 prod rollout

## Planned Contract

- root: contract version, environment/application ID, commit/APK digest, UTC time, two devices, exact checks
- devices: `Device A` / `Device B`, API level, preflight result only
- checks: stable `pass` / `not_run` only; free-form description 없음
- completion: 모든 field production-shaped + 모든 result `pass`
- template: structurally valid but intentionally incomplete; 완료 증거로 사용할 수 없음

## Validation

- tracked template structural validation
- complete fixture PASS and redacted summary
- any `not_run`, wrong environment/package/hash/time/device alias/API rejection
- unknown root/device/check key rejection, including email/token/serial/note-shaped additions
- oversized/malformed/non-object file rejection
- `npm run ci:test`, workflow contract, secret scan and remote CI

## Stop / Rollback

- schema가 free-form string이나 account/device identifier를 허용하면 구현을 중단하고 exact allowlist를 축소한다.
- template가 completion gate를 통과하면 실패다.
- rollback은 validator/test/template/runbook 변경을 함께 revert한다. DB/API/provider 변경은 없다.

## Completion Boundary

- validator PASS는 입력된 manual 결과의 완전성과 privacy shape만 증명하며 실제 관찰의 진위를 대신하지 않는다.
- live 두 기기에서 preflight를 통과하고 운영자가 각 check를 직접 실행한 뒤 생성한 completion JSON이 validator를 통과해야 `4-3b` evidence로 사용할 수 있다.

## Current Result

- exact JSON template, completion validator, repository commit existence와 APK SHA-256 binding을 구현했다.
- focused contract test 8개와 repository self-test 39개, workflow contract와 secret scan이 통과했다.
- implementation commit `4792dfd`의 GitHub Actions run `30415718065`에서 모든 job과 final gate가 통과했다.
- tracked template는 구조 검증만 통과하고 completion mode에서는 의도대로 실패한다.
- 실제 계정/기기 시나리오는 실행하지 않았으므로 `4-3b-2`와 Phase 02 Exit Gate는 pending이다.
