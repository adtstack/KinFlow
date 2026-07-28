# Phase 02 WP02-01 Live App Link Probe Evidence

- Work Package: WP02-01 / WP02-04 — deployed Digital Asset Links HTTP contract probe
- 기준 commit: base `3082c04`; implementation `76013e5`
- 검증일: 2026-07-29
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Android build-tools 36.0.0
- 결과: **LOCAL + REMOTE PROBE SLICE PASS / OWNED HOST·OS VERIFIED LINK·REAL PROVIDER PENDING**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| FR-AUTH-004 / FR-FLT-006 | AUTOMATED PROBE PASS | exact `https://<host>/.well-known/assetlinks.json`만 GET하고 HTTPS failure를 fail-closed 처리한다. |
| WP02-04 / T-LINK-01 / T-LINK-02 | CONTRACT PASS | 200, no redirect, `application/json`, valid UTF-8 JSON과 exact relation/package/signing fingerprint를 검사한다. |
| Security | PASS | scheme/port/path/wildcard/IP/localhost host를 거부하고 10초 timeout과 64 KiB streaming cap을 적용하며 response body를 출력하지 않는다. |

## Implementation

- `scripts/ci/android-live-asset-links.mjs`가 owned DNS host를 검증한 뒤 exact well-known HTTPS URL을 redirect manual 모드로 요청한다.
- `Content-Length`가 없거나 거짓이어도 response stream을 64 KiB까지만 읽으며, oversized/malformed body와 unexpected deployed association을 거부한다.
- 기존 static validator를 재사용해 remote statement의 relation, namespace, dev package와 실제 APK signer SHA-256을 exact 비교한다.
- `scripts/verify-android-app-links.sh`의 optional fourth argument가 local APK/package/signer 검증 성공 뒤 live probe를 연속 실행한다.
- public config의 host validator를 재사용 가능한 함수로 분리하면서 기존 `AUTH_REDIRECT_HOST` 오류 진단 계약을 보존했다.
- public site README와 two-adult runbook에 배포 전 local gate와 배포 후 live gate를 구분해 기록했다.
- DB migration, RLS, RPC, Edge/API, Flutter runtime, dependency와 lockfile 변경은 없다.

## Validation

| 검증 | 결과 |
|---|---|
| repository Node tests | PASS, 22/22; live probe success/failure 4개 포함 |
| live HTTP contract unit cases | PASS; exact URL/options, non-200, redirect, wrong content type, declared/streamed oversized body, malformed JSON, unsafe host와 statement drift 검사 |
| shell syntax | PASS |
| current dev APK → checked-in statement | PASS, package와 signer SHA-256 일치 |
| prod debug APK → production association | EXPECTED FAIL, debuggable artifact 차단 |
| Dart format / fatal analyze | PASS, 158 files drift 0 / analyzer issue 0 |
| full Flutter suite | PASS, 176 tests + 1 opt-in local connectivity skip |
| coverage | PASS, 2,393/3,091 lines (77.42%) |
| public config / secret / codegen | PASS, high-confidence secret 0 / generated drift 0 |
| dev APK audit | PASS, 216,120,695 bytes, SHA-256 `50348407a63b1c535f350ccec4082919b6a3788ecb8a3024d75d98f1e0cfcc4d` |
| prod debug APK audit | PASS, 216,120,615 bytes, SHA-256 `6a54dbd776e2906a6efe99f0fdc2f197b0ef08ca44c894556fd35ecfb6be55b0` |
| GitHub Actions CI | PASS, run `30387565194`; all required jobs and final gate passed |

Remote run: <https://github.com/adtstack/KinFlow/actions/runs/30387565194>

Remote durations were dependency 56s, quality 3m39s, backend 2m42s, dev Android 4m40s, prod Android 4m50s and final gate 3s. Detailed command summary is in `logs/wp02-01-live-app-link-probe.log`; APK, coverage and raw reports remain ignored artifacts.

## Live Hosting / Device Boundary

- owned HTTPS host와 배포물이 아직 없으므로 실제 live probe 호출, Google Digital Asset Links API와 Android `pm get-app-links`의 `verified` 판정은 **NOT RUN**이다.
- Google Cloud와 Supabase browser tabs는 로그인 화면이어서 provider/project를 생성하거나 변경하지 않았다.
- production association은 Play App Signing delivery certificate 확정 전까지 의도적으로 만들지 않는다.
- 실제 성인 Google 계정 2개와 Android 기기 2대의 create-invite-accept, cold-start continuation과 account-switch purge는 **NOT RUN**이다.

공식 계약 근거:

- <https://developer.android.com/training/app-links/configure-assetlinks>
- <https://developer.android.com/training/app-links/verify-applinks>

## Security / Privacy / External State

- probe는 공개 association JSON만 읽고 credential, cookie, invite token 또는 사용자 식별자를 보내지 않는다.
- 응답 본문, Google token, 이메일, Supabase key와 production/customer data를 log/evidence에 저장하지 않았다.
- timeout, response size, media type, redirect와 exact statement mismatch는 모두 성공으로 완화하지 않는다.
- Google Cloud, Supabase, DNS, hosting, Play Console과 production environment를 생성·수정하지 않았다.

## Remaining Risks / Completion Boundary

1. mocked HTTP tests는 deployed CDN/DNS/TLS 동작이나 Android OS verification을 증명하지 않는다.
2. dev debug keystore가 바뀌면 checked-in fingerprint가 stale이 되며 wrapper 재실행과 명시적 rotation이 필요하다.
3. Android verification cache와 CDN cache 때문에 올바른 배포 뒤에도 재검증 지연이 생길 수 있다.
4. 실제 provider token exchange, remote session restore, two-adult authorization과 cold-start invite는 아직 미검증이다.

This evidence completes only the reusable live-probe slice. WP02-01 overall and Phase 02 Exit Gate remain incomplete until an owned host serves the statement, Android reports verified, Google/Supabase login succeeds and two adults complete the two-device scenario.

## Rollback

- implementation commit `76013e5`를 revert하면 live probe, tests, optional wrapper host와 관련 문서만 제거된다.
- 외부 배포나 DB/API/provider 변경이 없어 remote rollback 또는 migration rollback은 없다.

## Next Entry Condition

1. Google Cloud와 Supabase dashboard에 운영자가 직접 로그인한다.
2. 기존 dev project를 선택하거나 새 project 생성 범위를 승인한다.
3. owned dev HTTPS host를 제공하고 checked-in `assetlinks.json`을 exact well-known path에 배포한다.
4. optional-host wrapper, Digital Asset Links API와 Android OS `verified`를 통과한다.
5. 성인 Google 계정 2개와 Android 기기 2대로 runbook의 create-invite-accept/cold-start/account-switch 시나리오를 실행한다.
