# Phase 02 WP02-01 Dev Asset Links Evidence

- Work Package: WP02-01 / WP02-04 — deployable dev Digital Asset Links contract
- 기준 commit: base `ac3098d`; implementation `25f81f6`
- 검증일: 2026-07-29
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Android build-tools 36.0.0
- 결과: **LOCAL + REMOTE DEV ASSOCIATION SLICE PASS / OWNED HOST·OS VERIFIED LINK·REAL PROVIDER PENDING**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| FR-AUTH-004 / FR-FLT-006 | DEPLOYMENT INPUT PASS | Astro public asset 경로에 dev package와 현재 설치 APK signer가 정확히 일치하는 `/.well-known/assetlinks.json`을 준비했다. |
| WP02-04 / T-LINK-01 / T-LINK-02 | AUTOMATED CONTRACT PASS | relation, namespace, package, SHA-256 형식·중복·추가 association을 exact validator로 검사한다. |
| Android intent filter | PASS | dev/prod binary manifest audit가 `VIEW`, `DEFAULT`, `BROWSABLE`, HTTPS, exact host와 `/invite/`를 고정한다. |
| Production signing safety | PASS | prod debuggable APK는 production association 검증 입력으로 거부한다. Play-delivered signing certificate 전에는 prod file을 만들지 않는다. |
| Security | PASS | certificate fingerprint만 공개하고 keystore, private key, password, token과 실제 identity는 추가하지 않았다. |

## Implementation

- `apps/public_site/public/.well-known/assetlinks.json`은 dev 전용 statement 한 개만 포함한다.
  - package: `me.newlines.kinflow.dev`
  - relation: `delegate_permission/common.handle_all_urls`
  - namespace: `android_app`
  - signing SHA-256: `6A:C5:22:6C:F7:1B:20:1C:99:49:E8:1F:75:14:49:AD:94:53:64:A9:46:5C:ED:0C:69:19:00:51:C5:6E:C7:D5`
- Node validator는 JSON root와 statement/target의 exact keys, 환경별 package, uppercase colon-delimited SHA-256, unique fingerprint와 단일 환경 association을 fail-closed로 검사한다.
- checked-in 정적 파일 자체를 Node test가 읽어 현재 dev 계약과 비교한다.
- APK wrapper는 `aapt`로 package/debuggable 상태를, `apksigner`로 current signer를 읽고 정적 statement와 대조한다. signer 값은 command argument로만 validator에 전달하며 private signing material은 읽지 않는다.
- prod 선택 시 `application-debuggable` APK를 statement source로 쓰지 못하게 먼저 차단한다.
- Android APK gate가 기존 App Link 검사에 `android.intent.category.DEFAULT`를 추가했다.
- public site README와 실제 provider runbook에 dev/prod 배포 경계 및 HTTPS 200, JSON content type, no-redirect 계약을 기록했다.
- DB migration, RLS, RPC, Edge/API, Flutter runtime와 dependency/lockfile는 변경하지 않았다.

## Validation

| 검증 | 결과 |
|---|---|
| repository Node tests | PASS, 18/18; Asset Links 5개 포함 |
| checked-in dev statement | PASS, exact one statement/package/fingerprint |
| current dev APK → statement | PASS, package와 APK signer SHA-256 일치 |
| prod debug APK → production association | EXPECTED FAIL, debuggable artifact 차단 |
| Dart format / fatal analyze | PASS, 158 files drift 0 / analyzer issue 0 |
| full Flutter suite | PASS, 176 tests + 1 opt-in local connectivity skip |
| coverage | PASS, 2,393/3,091 lines (77.42%) |
| public config / secret / codegen | PASS, high-confidence secret 0 / generated drift 0 |
| dev APK audit | PASS, 216,120,695 bytes, SHA-256 `50348407a63b1c535f350ccec4082919b6a3788ecb8a3024d75d98f1e0cfcc4d` |
| prod debug APK audit | PASS, 216,120,615 bytes, SHA-256 `6a54dbd776e2906a6efe99f0fdc2f197b0ef08ca44c894556fd35ecfb6be55b0` |
| GitHub Actions CI | PASS, run `30386059527`; all required jobs and final gate passed |

Remote run: <https://github.com/adtstack/KinFlow/actions/runs/30386059527>

Remote durations were dependency 1m09s, quality 3m20s, backend 4m08s, dev Android 5m00s, prod Android 5m25s and final gate 3s. Detailed command summary is in `logs/wp02-01-dev-asset-links.log`; APK, coverage and raw reports remain ignored artifacts.

## Hosting / Device Boundary

- Android requires the statement at `https://<owned-host>/.well-known/assetlinks.json`, served as `application/json` over HTTPS without a redirect.
- 이번 slice에서는 owned host, DNS와 hosting provider를 선택하거나 변경하지 않았다. 따라서 HTTP fetch, Digital Asset Links API 확인과 `pm get-app-links`의 `verified` 판정은 **NOT RUN**이다.
- checked-in file은 현재 운영자 dev debug signer와 일치한다. 다른 machine/operator signing key로 빌드하면 wrapper가 실패하며 명시적 fingerprint rotation이 필요하다.
- 이 dev file을 prod host에 배포하지 않는다. prod는 Google Play가 실제 사용자에게 전달하는 App Signing certificate를 사용해야 한다.

공식 계약 근거:

- <https://developer.android.com/training/app-links/configure-assetlinks>
- <https://developer.android.com/training/app-links/verify-applinks>

## Security / Privacy / External State

- SHA-256 certificate fingerprint와 package name은 공개 association 식별자다. debug keystore 파일, key password와 private key는 Git/evidence에 포함하지 않았다.
- statement는 unknown relation, web namespace, prod package, 추가 app statement와 unexpected field를 거부한다.
- raw invite token, Google token, email, Supabase key와 production/customer data를 사용하지 않았다.
- Google Cloud, Supabase, DNS, hosting, Play Console과 production environment를 생성·수정하지 않았다.

## Remaining Risks / Completion Boundary

1. 정적 파일은 아직 인터넷에서 제공되지 않으므로 Android domain ownership을 증명하지 않는다.
2. dev debug keystore를 교체하면 현재 fingerprint가 즉시 stale이 된다. 배포 전 APK wrapper 재실행이 필수다.
3. 실제 host가 redirect, 잘못된 content type, CDN cache 또는 접근 제한을 사용하면 OS verification이 실패할 수 있다.
4. prod Play App Signing fingerprint가 없으므로 prod association은 의도적으로 존재하지 않는다.
5. real Google/Supabase provider와 invite cold-start/account-switch 흐름은 여전히 미실행이다.

This evidence completes only the dev association artifact/verification slice. WP02-01 overall and Phase 02 Exit Gate remain incomplete until an owned host serves it, Android reports verified, provider login succeeds and two adults complete the two-device scenario.

## Rollback

- implementation commit `25f81f6`을 revert하면 dev statement, validator/wrapper, README/runbook 보강과 `DEFAULT` category audit가 함께 제거된다.
- 외부 host에 배포한 뒤 rollback한다면 먼저 해당 `assetlinks.json`을 제거하거나 이전 승인 statement로 복원하고 OS cache/re-verification 지연을 고려한다.
- DB/API/provider 변경이 없어 migration 또는 remote provider rollback은 없다.

## Next Entry Condition

1. Google Cloud와 Supabase dashboard에 운영자 로그인이 완료된다.
2. dev provider project를 기존 항목에서 선택하거나 새로 생성하도록 승인한다.
3. owned dev HTTPS invite host를 결정하고 정적 file을 정확한 well-known 경로에 배포한다.
4. host fetch/Digital Asset Links API/Android `pm get-app-links` verified 결과를 통과한 뒤 Google login과 two-adult scenario로 진행한다.
