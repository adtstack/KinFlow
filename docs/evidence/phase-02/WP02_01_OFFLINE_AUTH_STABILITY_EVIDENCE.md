# Phase 02 WP02-01 Offline Auth Stability Evidence

- 검증일: 2026-07-29
- implementation commit: `914f19e65f5e4d3cb8d2ed9a47acfdf2cc9fbad4`
- 상태: **LOCAL + REMOTE AUTOMATED PASS / LIVE ANDROID NETWORK CONDITIONS NOT RUN**
- 범위: Google sign-in temporary failure와 startup session restore uncertainty의 presentation/route boundary

## Requirement Trace

| E2E check | 자동 결과 | live 결과 |
|---|---|---|
| `google_offline_stable` | PASS — temporary sign-in failure는 generic localized status를 표시하고 retry action을 다시 활성화하며 Today를 열지 않는다. | NOT RUN — 실제 chooser 중 network 차단 필요 |
| `offline_launch_stable` | PASS — session restore가 temporarily unavailable이면 locked sign-in route에 남고 Today/onboarding을 모두 차단한다. | NOT RUN — 실제 Android offline cold launch 필요 |
| Security / Privacy | PASS — failure kind만 UI contract에 전달하며 provider exception, token, email과 network detail을 표시하지 않는다. | 실제 provider/log 관찰 pending |

## Automated Scenarios

### Temporary Google/Supabase failure

1. unauthenticated sign-in 화면에서 enabled Google action을 실행한다.
2. launcher boundary가 `temporarilyUnavailable`을 반환한다.
3. 화면은 generic retry-later 문구를 표시하고 Google action을 다시 활성화한다.
4. 두 번째 action은 launcher를 다시 호출하지만 session event 전에는 Today가 열리지 않는다.

### Offline startup restore uncertainty

1. app startup session restore가 `temporarilyUnavailable`을 반환한다.
2. auth lifecycle은 absent session이나 no-household로 추정하지 않고 `AuthLocked`를 유지한다.
3. router는 sign-in status만 표시하고 Today와 first-household onboarding을 모두 숨긴다.

기존 gateway/data source/repository/controller tests는 Google plugin error, Supabase exchange error와 session failure를 provider-neutral kind로 매핑한다. 이번 widget tests는 그 결과가 실제 route/UI에서 fail-closed임을 연결한다.

## Local Validation

| 검증 | 결과 |
|---|---|
| focused app-shell widget suite | PASS, 13/13 |
| Flutter full suite | PASS, 182 passed / 1 opt-in live skipped |
| Flutter analyze | PASS, issue 0 |
| Flutter format | PASS, 158 files / final change 0 |
| repository self-test | PASS, 39/39 |
| workflow/action lint | PASS, 5 jobs / 17 pinned action uses / `contents: read` |
| public config / secret / codegen | PASS, high-confidence secret 0 / generated drift 0 |
| coverage | PASS, 2,446/3,115 lines (78.52%) |
| `git diff --check` | PASS |

Toolchain은 Flutter 3.44.7, Dart 3.12.2 exact pin을 사용했다.

## Remote Validation

GitHub Actions [run `30418063029`](https://github.com/adtstack/KinFlow/actions/runs/30418063029)은 implementation commit에서 최종 PASS했다.

| job | 결과 |
|---|---|
| dependency vulnerability and license audit | PASS, 1m04s |
| Supabase DB, RLS, and contract | PASS, 2m43s |
| quality and tests | PASS, 3m47s |
| Android dev debug | PASS, 4m29s |
| Android prod debug | PASS, 4m37s |
| final CI gate | PASS, 4s |

## Data / API / Security / Privacy

- production runtime, DB migration, RLS, RPC, Edge/API, Android manifest, provider/config와 dependency 변경 없음.
- synthetic launcher/repository failure만 test process에 주입했다. 실제 token, email, account와 network endpoint는 사용하지 않았다.
- status는 stable localization만 검사하며 raw exception이나 provider description을 test fixture에도 넣지 않았다.
- repository secret scan은 finding 0으로 통과했다.

## Manual / Deferred Validation

- Google account chooser가 열린 동안 airplane mode 또는 network 차단: **NOT RUN**
- Supabase token exchange 중 DNS/TLS/network 실패: **NOT RUN**
- secure session이 있는 Android app의 offline force-stop/cold launch: **NOT RUN**
- connectivity 복구 후 retry와 session establishment: **NOT RUN**
- OEM별 Google Play Services error surface와 log redaction: **NOT RUN**

## Remaining Risks / Completion Boundary

1. actual plugin이 기기·Play Services 버전에 따라 temporary failure가 아닌 다른 error code를 반환할 수 있다.
2. secure storage에 valid session이 남은 offline launch에서는 Supabase SDK restore/refresh ordering을 실제 기기에서 확인해야 한다.
3. retry는 명시적 사용자 action이며 자동 retry/backoff를 추가하지 않았다.
4. 두 E2E check는 actual network condition을 관찰해 privacy-safe completion JSON에 `pass`를 기록할 때만 최종 완료다.

## Rollback

- implementation commit `914f19e`을 revert하면 widget tests와 workplan만 제거된다.
- runtime/data/provider mutation이 없어 별도 rollback은 없다.

## Next Entry Condition

1. dev APK가 설치되고 two-device preflight가 통과한 Android target 준비
2. chooser/exchange 진행 중 network 차단 후 generic retry UI와 protected-route 차단 관찰
3. authenticated B 기기를 force-stop하고 offline cold launch해 이전 household 노출 여부 관찰
4. network 복구 후 명시적 retry/restore 성공 확인
5. 두 결과를 식별정보 없이 completion JSON에 `pass`로 기록

위 live 관찰 전에는 synthetic failure test를 전체 `google_offline_stable` 또는 `offline_launch_stable` 완료 증거로 사용하지 않는다.
