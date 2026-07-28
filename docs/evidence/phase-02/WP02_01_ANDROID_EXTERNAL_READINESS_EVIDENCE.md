# Phase 02 WP02-01 Android External Readiness Evidence

- Work Package: WP02-01 Auth lifecycle — owned App Link build input and Android integration readiness
- 기준 commit: base `8882cd0`; implementation `b4ac48b`
- 검증일: 2026-07-29
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Android 16 / API 36 Google Play AVD
- 결과: **LOCAL + REMOTE READINESS SLICE PASS / REAL PROVIDER·OWNED DOMAIN·TWO ADULT ACCOUNTS AND DEVICES PENDING**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP02-01 / FR-AUTH-004 | READINESS SLICE PASS | 한 public config의 `AUTH_REDIRECT_HOST`를 Dart runtime과 Android merged manifest에 함께 전달하는 build/run 경로를 만들었다. |
| WP02-04 / D-055 | PASS FOR BUILD CONTRACT | example host와 non-placeholder synthetic host 모두 exact APK audit를 통과했고 host 불일치와 unsafe host를 fail-closed로 차단한다. |
| Phase 02 Android manual gate | PARTIAL PASS | Android 16 Google Play AVD에 dev APK를 설치해 foreground activity, fail-closed startup UI, package/signing과 placeholder App Link 실패 상태를 확인했다. 실제 provider와 두 기기 시나리오는 실행하지 않았다. |
| Security | PASS | public config는 exact 14-key allowlist만 허용하며 client secret, service-role key, token, 이메일과 signing private material을 Git·로그·evidence에 기록하지 않았다. |

## Implementation

- `android-public-config.mjs`가 JSON object, string-only value, exact public key allowlist, flavor별 `APP_ENV`/`APP_ID`와 DNS-only `AUTH_REDIRECT_HOST`를 검증한다.
- scheme, path, port, wildcard, whitespace, localhost와 IP host는 Flutter/Gradle 실행 전에 거부한다.
- Android Gradle은 `kinflowAuthRedirectHost` project property를 다시 검증하고 dev/prod manifest placeholder에 사용한다. property가 없는 기존 reproducible CI 경로는 `auth.example.invalid`로 안전하게 유지한다.
- `android-build.sh`는 선택한 public config에서 host를 한 번 읽어 Dart define과 Gradle property에 동시에 전달하고, 최종 APK binary manifest에서 동일 host와 `/invite/`, HTTPS, `autoVerify=true`를 검사한다.
- `run-android.sh`는 실제 dev/prod 기기 실행에서도 같은 single-source 입력 경로를 사용한다.
- direct Gradle 검증이 생성하는 `android/build/` 진단 report는 source tree에 포함되지 않도록 ignore했다.
- DB migration, RLS, RPC, Edge/API, Flutter runtime dependency와 public config schema는 변경하지 않았다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| public config unit/CI self-tests | PASS, 13/13 |
| shell syntax / executable / diff whitespace | PASS |
| Dart format / fatal Flutter analyze | PASS, format drift 0 / analyzer issue 0 |
| full Flutter suite | PASS, 176 tests + 1 opt-in local connectivity skip |
| coverage | PASS, 2,393/3,091 lines (77.42%) |
| public config / secret / codegen | PASS, high-confidence secret 0 / generated drift 0 |
| default dev APK audit | PASS, 216,120,695 bytes, SHA-256 `50348407a63b1c535f350ccec4082919b6a3788ecb8a3024d75d98f1e0cfcc4d` |
| default prod APK audit | PASS, 216,120,615 bytes, SHA-256 `6a54dbd776e2906a6efe99f0fdc2f197b0ef08ca44c894556fd35ecfb6be55b0` |
| synthetic host dev APK | PASS, merged manifest `https://auth.dev.kinflow.example/invite/*`, 216,121,894 bytes, SHA-256 `78de094d48938e420fea3baf3617474f273e29787b891e0b10d96d4c748d234e` |
| unsafe Gradle host | EXPECTED FAIL, `https://bad.example.com` rejected during project configuration |
| GitHub Actions CI | PASS, run `30383852574`; all five required jobs and final gate passed |

Remote run: <https://github.com/adtstack/KinFlow/actions/runs/30383852574>

Remote durations were dependency 58s, backend 3m01s, quality 3m54s, prod Android 8m55s, dev Android 11m43s and final gate 4s. Detailed local execution summary is in `logs/wp02-01-android-external-readiness.log`; APK, coverage, screenshot and raw CI reports remain ignored artifacts.

## Android 16 Google Play AVD

- AVD: `kinflow_api36_play`, Android 16 / API 36, Google Play system image, model `sdk_gphone64_arm64`.
- final default dev APK package `me.newlines.kinflow.dev` reinstallation: PASS.
- launcher resolution: `me.newlines.kinflow.dev/me.newlines.kinflow.MainActivity`.
- explicit cold start command reached the activity but `am start -W` returned `Status: timeout` after about 12.4s. After the timeout the app process remained alive and `MainActivity` was the visible top-resumed activity.
- rendered UI showed the stable `KinFlow couldn't start` retry screen because the example Supabase endpoint/provider is not live. No protected household route or false login success was exposed.
- APK/debug keystore SHA-1: `A2:12:1B:14:AA:68:34:21:B5:C5:81:B7:61:F1:B1:3C:AF:DC:24:8D`.
- APK/debug keystore SHA-256: `6A:C5:22:6C:F7:1B:20:1C:99:49:E8:1F:75:14:49:AD:94:53:64:A9:46:5C:ED:0C:69:19:00:51:C5:6E:C7:D5`.
- `pm get-app-links` reported the same SHA-256 and `auth.example.invalid` state `1024` (`legacy_failure`). This is the expected placeholder failure, not verified App Link evidence.
- no real Google account, Supabase session, invite token, email or user data was used on the AVD.

## Security / Privacy / External State

- config validation errors do not print config values. Build reports contain only public host/package metadata, artifact size/hash and policy results.
- OAuth Web client secret remains server-side-only. Supabase service-role key, database password, Google token and signing private key are forbidden from public config and evidence.
- debug certificate fingerprints are public registration inputs; the keystore and passwords were not copied or committed.
- no Google Cloud, Supabase, DNS, web hosting, Play Console or production environment was created or modified.
- no migration, remote deploy, production data or customer identity was touched.

## Manual / Deferred Validation

- real dev Supabase project URL/publishable key and Google provider: **NOT CONFIGURED**.
- real Google Auth Platform Web/Android OAuth clients and `me.newlines.kinflow.dev` package/SHA registration: **NOT CONFIGURED**.
- owned HTTPS invite host, `assetlinks.json` deployment and OS `verified` App Link: **NOT RUN**.
- two distinct adult Google accounts on two Android devices, create-invite-accept, cold-start continuation and account-switch purge: **NOT RUN**.
- physical-device Keystore/session restore and production Play App Signing certificate: **NOT RUN**.

The synthetic `.example` host proves build-input propagation only. It is reserved, not owned, not reachable and cannot satisfy the Phase 02 App Link gate.

## Remaining Risks / Completion Boundary

1. A fresh API 36 AVD exceeded the `am start -W` wait window while the example backend was unreachable; real provider configuration needs launch-time and retry observation on actual devices.
2. Android Credential Manager may classify package/SHA/client mismatch as cancellation, so the real dev OAuth registration must test cancellation and configuration failure separately.
3. `AUTH_REDIRECT_HOST` consistency is enforced only when the documented wrapper/build gate is used; ad-hoc raw `flutter run` commands must not be used for provider evidence.
4. placeholder domain failure demonstrates safe non-verification but does not exercise verified cold-start invite routing.
5. the existing `sentry_flutter` legacy Kotlin Gradle Plugin warning remains a future Flutter-upgrade maintenance risk.

This evidence completes only the external-readiness vertical slice. WP02-01 overall and the Phase 02 Exit Gate remain incomplete until the real provider, owned verified domain and two-adult/two-device evidence exist.

## Rollback

- revert implementation commit `b4ac48b` to restore the fixed `auth.example.invalid` manifest placeholder and previous Android build/run flow.
- no DB/API/remote-console rollback is required because this slice changed none of them.
- if a future real provider rollout is rolled back, disable the environment provider/OAuth clients separately and rotate any exposed server credential.

## Next Entry Condition

1. choose or create the dev Supabase and Google Cloud projects, then configure the Google provider without placing secrets in Git;
2. choose an owned dev HTTPS invite host and deploy exact `assetlinks.json` for `me.newlines.kinflow.dev` plus the active signing SHA-256;
3. prepare two distinct adult Google test accounts and two Android devices or emulators;
4. run `GOOGLE_ANDROID_TWO_ADULT_RUNBOOK.md` from provider login through cold-start invite and account-switch purge.
