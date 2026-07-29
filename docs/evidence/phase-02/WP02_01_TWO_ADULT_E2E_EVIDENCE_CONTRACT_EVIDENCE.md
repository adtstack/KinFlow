# Phase 02 WP02-01 Two-Adult E2E Evidence Contract Evidence

- 검증일: 2026-07-29
- implementation commit: `4792dfdaed1f4212fe5285e006795a07cc582299`
- 상태: **AUTOMATED EVIDENCE CONTRACT PASS / PROVENANCE AND SESSION CAPTURE HARDENED BY FOLLOW-UP / LIVE TWO-ADULT E2E NOT RUN**
- 범위: 실제 dev Google Android 성인 2인 완료 결과의 completeness, build binding과 privacy shape

## Requirement Trace

| 요구사항 | 결과 |
|---|---|
| WP02-01 / Phase 02 manual gate | PASS — 두 device preflight와 exact 27개 E2E check가 모두 `pass`인 경우에만 completion을 수용한다. |
| FR-AUTH-003 / FR-AUTH-004 | PASS — A/B Google login, Supabase session, pre-session protected route 차단과 cold-start invite continuation을 개별 필수 check로 고정했다. |
| FR-AUTH-005 / D-049 | PASS — logout purge, account chooser 재진입과 account-switch household isolation을 필수 check로 고정했다. |
| WP02-04 / D-055 | PASS — one-time invite, preview/accept, replay와 concurrent accept idempotency를 필수 check로 고정했다. |
| Build identity | HISTORICAL PARTIAL — `4792dfd`에서는 40-hex commit 존재와 APK SHA-256을 각각 확인했지만 APK 내부 source commit은 확인하지 않았다. 후속 `WP02_01_LIVE_EVIDENCE_PROVENANCE_EVIDENCE.md`가 이 간극을 fail-closed로 보강했다. |
| Security / Privacy | PASS — exact schema에는 이메일, token, invite URL/token, UUID, ADB serial과 free-form note를 저장할 위치가 없다. |

## Implemented Artifacts

- `scripts/ci/android-two-adult-e2e-evidence.mjs`
  - 32 KiB evidence upper bound와 fatal UTF-8/JSON parsing
  - environment/package, commit, APK digest, UTC timestamp와 device A/B/API/preflight exact validation
  - repository commit object verification과 최대 1 GiB APK streaming SHA-256 검사; 이 구현 시점에는 두 값의 APK 내부 provenance 대조가 없었음
  - exact 27-check allowlist와 all-pass completion gate
  - input path/hash/time과 subprocess failure 원문을 재출력하지 않는 redacted summary/error
- `scripts/ci/android-two-adult-e2e-evidence.test.mjs`
  - template incomplete boundary, complete fixture, commit/APK binding, verifier failure masking
  - incomplete, drift, unknown identity/secret-shaped field, malformed/oversized rejection
- `docs/evidence/phase-02/templates/GOOGLE_ANDROID_TWO_ADULT_E2E_TEMPLATE.json`
  - 모든 결과가 `not_run`인 tracked template; completion으로 사용할 수 없음
- `GOOGLE_ANDROID_TWO_ADULT_RUNBOOK.md`
  - 이 implementation 시점에는 ignored template working copy를 hand-edit했다. 현재 절차는 후속 `WP02_01_LIVE_EVIDENCE_SESSION_EVIDENCE.md`의 APK-derived `init`, allowlisted `record`와 redacted `status`로 교체됐다.

## Local Validation

| 검증 | 결과 |
|---|---|
| focused evidence contract | PASS, 8/8 |
| `npm run ci:test` | PASS, 39/39 |
| `npm run ci:workflow` | PASS, 5 jobs / 17 pinned action uses / `contents: read` |
| Node syntax check | PASS |
| `git diff --check` | PASS |
| high-confidence secret scan | PASS, finding 0 |

Tracked template는 `requireComplete: false` 구조 검증에서 `completed: false`이며, 기본 completion mode에서는 placeholder commit 단계에서 실패한다. 자동 fixture의 all-pass 데이터는 validator branch coverage만 제공하며 실제 E2E 성공 증거로 저장하거나 사용하지 않았다.

## Remote Validation

GitHub Actions [run `30415718065`](https://github.com/adtstack/KinFlow/actions/runs/30415718065)은 implementation commit에서 최종 PASS했다.

| job | 결과 |
|---|---|
| dependency vulnerability and license audit | PASS, 1m11s |
| Supabase DB, RLS, and contract | PASS, 2m46s |
| quality and tests | PASS, 3m28s |
| Android prod debug | PASS, 4m30s |
| Android dev debug | PASS, 4m35s |
| final CI gate | PASS, 4s |

## Manual / Deferred Validation

- 실제 두 Android target preflight는 이번 slice에서 **NOT RUN**이다.
- actual Google account chooser와 A/B Supabase session은 **NOT RUN**이다.
- household 생성, HTTPS cold-start invite, preview/accept와 양쪽 membership 관찰은 **NOT RUN**이다.
- cold restore, logout/account switch, expired/revoked/offline/replay/concurrent negative paths는 **NOT RUN**이다.
- 실제 completion JSON은 생성하지 않았으며 tracked template는 모두 `not_run` 상태다.

## Data / API / Security / Privacy

- DB migration, RLS, RPC, Edge/API, Flutter runtime와 remote provider 변경 없음.
- validator와 template/runbook/evidence만 변경했다.
- completion file은 exact enum/hash/time/build metadata만 허용한다. account/device/household identifier와 free-form string은 unknown key로 거부한다.
- commit verifier와 APK hasher가 실패해도 raw process/file error는 stable error로 치환한다.
- test의 synthetic all-pass fixture와 synthetic APK bytes는 temporary directory 안에서만 생성되고 테스트 종료 시 제거된다.

## Remaining Risks / Completion Boundary

1. exact schema와 후속 session recorder는 입력 범위, completeness와 privacy를 보장하지만 운영자가 실제 화면을 관찰했는지는 자동 증명하지 못한다.
2. 이 구현 시점의 commit 존재 검사와 APK digest 검사는 서로 독립적이었다. 후속 provenance slice가 APK manifest의 source commit/clean state를 대조하지만, 두 기기에 정확히 같은 bytes가 설치됐는지는 Android package state만으로 직접 증명하지 않는다.
3. OEM/Android version별 Google Credential Manager와 `pm get-app-links` 실제 동작은 live 두 기기에서 남아 있다.
4. WP02-01과 Phase 02 Exit Gate는 실제 completion JSON과 manual observation evidence 전까지 미완료다.

## Rollback

- implementation commit `4792dfd`을 revert하면 validator/test/template/runbook/workplan 변경이 함께 제거된다.
- DB/API/provider mutation이 없어 migration 또는 remote rollback은 없다.

## Next Entry Condition

1. 서로 다른 online Android target 2대와 성인 Google test account 2개 준비
2. current dev APK 설치 및 two-device preflight PASS
3. runbook의 `session.mjs init`으로 actual APK와 A/B API level에 결속된 ignored session 신규 생성
4. runbook 7절 27개 check를 직접 실행하고 allowlisted `record` command로 stable result만 기록
5. completion validator에 working JSON과 실제 dev APK를 함께 전달해 commit/APK binding 포함 PASS

위 결과 전에는 자동 fixture나 template를 `4-3b-2` 완료 증거로 사용하지 않는다.
