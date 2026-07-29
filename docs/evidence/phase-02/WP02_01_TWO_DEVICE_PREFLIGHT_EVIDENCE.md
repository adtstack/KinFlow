# Phase 02 WP02-01 Two-Device Preflight Evidence

- 검증일: 2026-07-29
- implementation commit: `148b02c3e51a4f5fa11979cd4be532a32118aae1`
- 상태: **AUTOMATED PREFLIGHT PASS / LIVE TWO-DEVICE E2E NOT RUN**
- 범위: dev Android 기기 2대의 package/signing/App Link 사전조건을 계정 정보 없이 검사하는 reusable gate

## Requirement Trace

| 요구사항 | 결과 |
|---|---|
| WP02-01 / Phase 02 manual gate | PASS — 서로 다른 explicit ADB serial 2개를 요구하고 각 target의 online/boot/API/package/signer/App Link를 검사한다. |
| FR-AUTH-003 / FR-AUTH-004 | PASS — API 24+, dev package 설치, 현재 dev signer와 `adtstack.github.io: verified`가 아니면 로그인 단계 전에 실패한다. |
| FR-AUTH-005 / D-049 | PASS — 같은 serial 2회 지정은 ADB 실행 전에 거부해 이후 account-switch 검증이 두 target을 전제로 하게 했다. |
| Security / Privacy | PASS — 결과에는 `Device A` / `Device B`, API와 boolean 상태만 남고 serial, raw ADB output, 계정·token·invite 값은 포함하지 않는다. |

## Implemented Artifacts

- `scripts/ci/android-two-device-preflight.mjs`
  - shell을 거치지 않는 `execFile` argument boundary
  - 명시적이며 서로 다른 두 serial 요구
  - command timeout과 256 KiB output upper bound
  - `get-state`, boot completion, API level, `pm path`, `pm get-app-links`의 read-only 검사
  - subprocess 오류 원문을 버리고 stable `Device A/B` 오류만 반환
- `scripts/ci/android-two-device-preflight.test.mjs`
  - exact package/signer/host parser
  - 두 target의 exact command sequence와 redacted result
  - invalid/same serial, offline, unbooted, API 미달, 미설치와 raw failure masking
- `GOOGLE_ANDROID_TWO_ADULT_RUNBOOK.md`
  - 실제 로그인 전 실행 명령, PASS 조건, stop condition과 evidence redaction 규칙
- `WP02_01_TWO_DEVICE_PREFLIGHT_WORKPLAN.md`
  - scope/non-scope, security boundary, rollback과 completion boundary

## Local Validation

| 검증 | 결과 |
|---|---|
| `node --check` implementation/test | PASS |
| focused Node test | PASS, 5/5 |
| `npm run ci:test` | PASS, 31/31 |
| `npm run ci:workflow` | PASS, 5 jobs / pinned actions / `contents: read` |
| `git diff --check` | PASS |
| high-confidence secret scan | PASS, finding 0 |
| ADB target 비식별 집계 | PASS command, online 0 / unauthorized 0 / offline 0 |

첫 secret scan 시도는 sandbox 밖 Dart telemetry session 파일 쓰기가 거부되어 도구 시작 전에 중단됐다. `CI=true`, `DART_SUPPRESS_ANALYTICS=true`, `FLUTTER_SUPPRESS_ANALYTICS=true`로 재실행한 실제 repository scan은 finding 0으로 통과했다.

## Remote Validation

GitHub Actions [run `30414815240`](https://github.com/adtstack/KinFlow/actions/runs/30414815240)은 implementation commit에서 최종 PASS했다.

| job | 결과 |
|---|---|
| dependency vulnerability and license audit | PASS, 1m20s |
| Supabase DB, RLS, and contract | PASS, 2m43s |
| quality and tests | PASS, 3m40s |
| Android prod debug | PASS, 4m27s |
| Android dev debug | PASS, 5m08s |
| final CI gate | PASS, 2s |

## Manual / Deferred Validation

- 검증 시점 online Android target은 0대였으므로 live two-device preflight 명령은 **NOT RUN**이다.
- actual Google account chooser, Supabase session 발급과 protected route 진입은 이번 slice에서 **NOT RUN**이다.
- 성인 A의 household 생성, B의 cold-start invite continuation/accept, 양쪽 membership 확인과 logout/account-switch purge는 **NOT RUN**이다.
- production provider, Play App Signing과 두 prod 설치물 검증은 **NOT RUN**이다.

자동 fixture 2개는 command/parser/privacy contract만 검증하며 서로 다른 실제 성인 계정과 Android 기기 2대의 결과를 대체하지 않는다.

## Data / API / Security / Privacy

- DB migration, RLS, RPC, Edge/API와 remote provider 설정 변경 없음.
- Android app binary/runtime source 변경 없음. repository 검증 도구와 evidence/runbook만 변경했다.
- ADB serial은 입력에만 사용하고 반환 object, stdout, stderr와 evidence에 저장하지 않는다.
- subprocess stdout/stderr는 판정에만 사용하며 command 실패 시 원문을 재출력하지 않는다.
- Google 이메일, ID/access/refresh token, Supabase session과 실제 invite token은 수집하거나 저장하지 않았다.

## Remaining Risks / Completion Boundary

1. OEM 또는 Android version별 `pm get-app-links` 출력 형식 차이는 실제 두 기기에서 아직 확인하지 않았다.
2. package/signing/App Link PASS는 Google OAuth package/SHA binding이나 Supabase token exchange 성공을 증명하지 않는다.
3. 두 기기 모두 같은 emulator snapshot/account state를 공유하지 않는지 실제 manual setup에서 별도로 확인해야 한다.
4. WP02-01과 Phase 02 Exit Gate는 two-adult/two-device account/session/invite/logout evidence 전까지 미완료다.

## Rollback

- implementation commit `148b02c`을 revert하면 preflight script/test와 runbook/workplan 변경이 함께 제거된다.
- DB/API/provider mutation이 없어 migration 또는 remote rollback은 없다.

## Next Entry Condition

1. 서로 다른 online Android target 2대에 current dev APK 설치
2. 두 target에서 dev package의 App Link re-verification 완료
3. Google external testing audience에 포함된 서로 다른 성인 계정 2개
4. redacted preflight PASS 후 `GOOGLE_ANDROID_TWO_ADULT_RUNBOOK.md` 7절의 login/session/invite/cold-start/account-switch 시나리오 실행

위 조건이 준비되면 raw serial과 계정 식별자를 evidence에 남기지 않은 채 실제 `4-3b` gate로 진행한다.
