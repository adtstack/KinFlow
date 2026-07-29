# Phase 02 WP02-01 Account-Switch Invite Isolation Evidence

- 검증일: 2026-07-29
- implementation commit: `faa4eacd281f316acfe938bde4c70ddb61d27664`
- 상태: **LOCAL + REMOTE AUTOMATED PASS / LIVE GOOGLE ACCOUNT SWITCH NOT RUN**
- 범위: invitation preview/accept와 authenticated identity 전환 사이의 asynchronous race isolation

## Requirement Trace

| 요구사항 | 결과 |
|---|---|
| FR-AUTH-005 / D-049 | PASS WITH SYNTHETIC IDENTITIES — 이전 authenticated user가 사라지거나 바뀌는 즉시 pending token과 invitation 화면 state를 제거한다. |
| WP02-04 / D-048 | PASS — superseded preview/accept 응답은 완료 순서와 관계없이 current state 또는 active household를 변경하지 못한다. |
| `device_b_account_switch_isolated` | AUTOMATED PORTION PASS — account switch 중 이전 preview가 사라지고 늦은 accept 성공도 Today route를 열지 않는다. 실제 Google chooser/device 관찰은 pending이다. |
| Security / Privacy | PASS — invalid replacement link도 이전 capability token을 제거하며 raw token/account/household/member 식별자는 log나 evidence에 추가하지 않았다. |

## Reproduced Failure

기존 runtime은 pending store를 purge했지만 public `/invite` route의 auto-dispose를 보장하지 않았다. 화면의 auth listener는 user loss/change를 감지하면 clear 대신 purge 완료 전 `loadPreview()`를 다시 호출했다.

그 결과 다음 순서가 가능했다.

1. account A가 invitation preview를 열고 accept RPC를 시작한다.
2. provider가 account B session을 전달해 auth lifecycle이 lock/purge를 시작한다.
3. invite controller는 in-flight accept와 preview state를 계속 보유한다.
4. account A의 늦은 accept 성공이 account B session 확립 뒤 도착한다.
5. stale acceptance가 화면 listener로 전달되어 account B의 Today route 전환을 시도한다.

회귀 테스트는 fix 전 `clear()` 뒤에도 `InviteFlowLoading`이 남는 것을 재현했고, account-switch widget flow가 stale accept를 보존하는 경계를 고정했다.

## Implementation

- `InviteFlowController`
  - capture/clear마다 monotonically increasing operation revision을 부여한다.
  - current revision의 duplicate request만 coalesce한다.
  - 여러 in-flight operation을 추적하되 superseded revision의 success/failure는 state에 반영하지 않는다.
  - clear는 busy 여부와 관계없이 token, preview, accept command state를 즉시 무효화한다.
  - dispose는 추적 중인 operation을 기다리고 이후 emit을 차단한다.
- `EphemeralPendingInviteStore`
  - invalid replacement capture가 기존 valid token을 남기지 않도록 fail-closed clear한다.
- invitation presentation
  - authenticated user loss/change 시 preview reload가 아니라 synchronous clear를 수행한다.
  - deep-link capture와 route scrub을 같은 microtask로 실행해 Riverpod build-time mutation을 피한다.
- tests
  - in-flight preview replacement, in-flight accept clear, prior-token invalid replacement를 controller level에서 검증한다.
  - account A accept 진행 중 account B session으로 전환한 뒤 pending/preview/Today가 모두 격리되는지 widget level에서 검증한다.
  - widget harness는 production과 동일하게 pending store를 composite purge participant로 사용한다.

## Local Validation

| 검증 | 결과 |
|---|---|
| focused invite controller + widget suite | PASS, 17/17 |
| Flutter full suite | PASS, 180 passed / 1 opt-in live skipped |
| Flutter analyze | PASS, issue 0 |
| Flutter format | PASS, 158 files / final change 0 |
| repository self-test | PASS, 39/39 |
| workflow/action lint | PASS, 5 jobs / 17 pinned action uses / `contents: read` |
| public config / secret / codegen | PASS, high-confidence secret 0 / generated drift 0 |
| coverage | PASS, 2,440/3,115 lines (78.33%) |
| `git diff --check` | PASS |

Toolchain은 Flutter 3.44.7, Dart 3.12.2 exact pin을 사용했다.

## Remote Validation

GitHub Actions [run `30417534567`](https://github.com/adtstack/KinFlow/actions/runs/30417534567)은 implementation commit에서 최종 PASS했다.

| job | 결과 |
|---|---|
| dependency vulnerability and license audit | PASS, 1m12s |
| Supabase DB, RLS, and contract | PASS, 2m37s |
| quality and tests | PASS, 3m48s |
| Android dev debug | PASS, 4m22s |
| Android prod debug | PASS, 4m28s |
| final CI gate | PASS, 5s |

## Data / API / Security / Privacy

- DB migration, RLS, RPC, Edge/API, Android permission, provider/config와 dependency 변경 없음.
- 네트워크에서 이미 승인·전송된 old accept request 자체를 취소하지는 않는다. 서버 mutation은 original bearer identity와 idempotency contract로 처리되며, client는 그 늦은 결과를 새 identity에 적용하지 않는다.
- pending invite는 계속 app-process memory에만 존재하고 persistent storage로 승격하지 않았다.
- account/user/household/member 식별자와 raw invite token을 telemetry, error, evidence에 추가하지 않았다.

## Manual / Deferred Validation

- 실제 Google account chooser 재진입은 **NOT RUN**이다.
- 실제 account A→B 전환 중 이전 route/cache 관찰은 **NOT RUN**이다.
- Android process/background/force-stop과 OEM별 callback 순서는 **NOT RUN**이다.
- 실제 two-device completion JSON은 생성하지 않았다.

## Remaining Risks / Completion Boundary

1. Dart Future는 이미 전송된 network mutation을 취소하지 않으므로 old account의 authorized accept가 server에서 완료될 수 있다. 새 account client state에는 적용되지 않는다.
2. Google plugin이 emit하는 실제 session ordering과 Android activity lifecycle은 synthetic provider event보다 다양할 수 있다.
3. invitation route가 public인 설계는 최소 preview 접근을 허용하며 abuse/rate-limit은 server contract에 의존한다.
4. `device_b_account_switch_isolated`의 최종 PASS는 실제 두 계정·두 기기에서 previous household UI가 한 frame도 노출되지 않는지 관찰해야 한다.

## Rollback

- implementation commit `faa4eac`을 revert하면 controller revision, presentation clear와 회귀 테스트가 함께 제거된다.
- data/provider mutation이 없어 migration 또는 remote credential rollback은 없다.

## Next Entry Condition

1. 서로 다른 Android target 2대의 preflight PASS
2. account B의 invite accept와 cold session restore 완료
3. B logout 후 Google chooser에서 다른 test account 선택
4. switch 전 과정에서 previous invite/household/Today가 노출되지 않는지 직접 관찰
5. stable PASS만 privacy-safe completion JSON에 기록하고 validator 실행

위 live 결과 전에는 automated synthetic identity test를 전체 `device_b_account_switch_isolated` 완료 증거로 사용하지 않는다.
