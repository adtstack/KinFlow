# Phase 02 WP02-01 Account-Switch Invite Isolation Work Plan

- 작성일: 2026-07-29
- 기준 commit: `73eb28b`
- Work Package: WP02-01 — live 27-check traceability / account-switch isolation
- 상태: IMPLEMENTED — LOCAL + REMOTE AUTOMATED PASS / LIVE ACCOUNT SWITCH PENDING

## Requirements

| ID | 이번 vertical slice |
|---|---|
| FR-AUTH-005 / D-049 | authenticated identity가 사라지거나 바뀌는 즉시 이전 account의 pending invite, preview와 in-flight result를 무효화한다. |
| WP02-04 / D-048 | 이미 시작된 preview/accept 응답이 늦게 도착해도 새 identity의 state 또는 active household를 변경하지 못한다. |
| E2E `device_b_account_switch_isolated` | account switch 중 protected Today가 노출되지 않고 이전 invite UI/accept result가 새 account로 넘어가지 않는다. |

## Finding

`EphemeralPendingInviteStore`는 logout/account switch purge에 포함되지만 `InviteFlowController`는 preview와 in-flight operation을 별도로 보유한다. invitation route가 public이라 route disposal이 보장되지 않으며, 기존 auth listener는 purge 완료 전 `loadPreview()`를 다시 호출한다. 따라서 이전 preview가 남거나 늦은 accept 성공이 새 session에서 처리될 수 있다.

## Scope

1. invite controller operation에 identity-independent revision을 부여해 superseded preview/accept 결과를 폐기한다.
2. valid/invalid 새 link capture와 explicit clear가 진행 중 operation을 즉시 무효화하고 화면 state를 초기화하게 한다.
3. authenticated user loss/change 시 invite screen이 preview를 reload하지 않고 synchronous clear를 실행한다.
4. in-flight preview replacement와 in-flight accept/account-switch race를 controller/widget test로 고정한다.
5. 실제 production purger와 같게 widget harness에서 pending store purge participant를 사용한다.

## Explicit Non-scope

- 실제 Google account chooser, Supabase live session 또는 Android 기기 조작
- invite token 영구 저장 또는 process-death 복원
- DB/RLS/RPC/Edge/provider/config/dependency 변경
- household/member/account 식별자의 log 또는 evidence 저장

## Validation

- focused invite controller/widget tests
- full Flutter quality gate
- repository self-test, workflow contract, secret scan
- GitHub Actions

## Stop / Rollback

- superseded response가 state를 다시 변경하거나 clear 뒤 token/preview가 남으면 실패다.
- current operation의 duplicate coalescing과 transient retry idempotency가 깨지면 실패다.
- rollback은 controller/screen/test/workplan/evidence 변경을 함께 revert한다. data/provider rollback은 없다.

## Completion Boundary

- 이 fix는 account-switch isolation의 device-independent race를 닫지만 실제 Google chooser와 OEM lifecycle을 증명하지 않는다.
- 실제 두 account·두 Android device의 live logout/switch observation과 completion JSON은 계속 필요하다.

## Current Result

- implementation commit `faa4eac`에서 account identity boundary가 이전 invite operation을 즉시 무효화하도록 수정했다.
- focused controller/widget test 17개, 전체 Flutter test 180개와 repository self-test 39개가 통과했다. 1개 opt-in live test는 의도대로 skip했다.
- analyzer issue 0, coverage 78.33%, secret finding 0, generated drift 0이다.
- GitHub Actions run `30417534567`의 foundation job 5개와 final gate가 모두 통과했다.
- 실제 Google chooser/account switch와 두 Android 기기는 사용하지 않았으므로 live check는 pending이다.
