# Phase 02 WP02-01 Google Android Integration Evidence

- Work Package: WP02-01 Auth lifecycle — Google native sign-in and Android two-adult integration foundation
- 기준 commit: base `a94ae55`; implementation `a9de8a8`
- 검증일: 2026-07-28
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 28.3.2
- 결과: **LOCAL + REMOTE AUTOMATED PASS / GOOGLE PROVIDER·OWNED DOMAIN·ANDROID DEVICE·TWO ADULT ACCOUNTS PENDING**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP02-01 | AUTOMATED INTEGRATION READY | Android Google SDK adapter, Supabase token exchange, runtime composition과 logout purge를 구현하고 local/remote gate를 통과했다. 외부 provider와 실기기는 완료 범위가 아니다. |
| FR-AUTH-003 / D-054 | PASS FOR CREDENTIAL-INDEPENDENT SLICE | Google ID/access token을 Supabase `signInWithIdToken`에 전달하고 Supabase session과 user가 모두 존재할 때만 성공으로 처리한다. |
| FR-AUTH-004 | PASS WITH FAKES | 기존 auth lifecycle에 started/cancelled/typed failure/session event를 연결하고 취소 시 protected route를 열지 않는다. |
| FR-AUTH-005 / D-049 | PASS WITH FAKES | logout/account switch composite purge에 Google local sign-out을 포함하고 한 participant라도 실패하면 purge를 실패로 반환한다. |
| D-047 / CAP-001 | PASS | Google/Supabase SDK import는 infrastructure에 격리되고 feature data/domain 경계에는 provider token/type이 노출되지 않는다. |
| T-AUTH-01 / T-AUTH-02 | PASS | 초기화 1회, token 누락, 취소, 설정/일시 장애, Supabase 거절, purge와 runtime composition을 자동 검증했다. |
| Phase 02 manual gate | NOT RUN | 실제 Google/Supabase provider, owned App Link, 성인 2계정과 Android 기기 2대가 없어 실행하지 않았다. |

## Implementation

- `google_sign_in` 7.2.0을 추가하고 Android implementation 7.2.15를 lockfile에 고정했다.
- process-wide Google singleton을 `initialize(serverClientId)` 한 번만 호출한 뒤 user gesture에서 `authenticate()`한다. 지원하지 않는 플랫폼과 SDK 오류는 stable failure로 변환한다.
- ID token과 access token을 모두 얻은 경우에만 Supabase exchange를 호출한다. token container의 문자열 표현은 항상 redacted이며 token, account email과 raw provider exception은 log/domain/UI로 전달하지 않는다.
- Supabase exchange는 `OAuthProvider.google`과 두 token을 전송하고 session/user가 없는 응답을 invalid provider response로 거부한다.
- 공개 `GOOGLE_WEB_CLIENT_ID`가 비어 있거나 placeholder이면 기존 unavailable launcher를 유지한다. 유효한 client ID가 있을 때만 Google launcher와 purge participant를 runtime에 조립한다.
- secure auth storage, pending invite와 Google local state를 하나의 composite purge로 실행한다. 실패한 participant 수만 반환하며 원문 오류는 노출하지 않는다.
- architecture contract는 feature presentation/application/domain/data에서 `google_sign_in` 직접 import를 금지한다.
- Android manifest audit는 Credential Manager 전이 의존성의 `USE_BIOMETRIC`, API 24 호환용 `USE_FINGERPRINT`와 기존 exact permission set을 고정한다. 둘 다 Android normal permission이며 dangerous/runtime permission은 추가되지 않았다.
- dev/prod provider, signing, App Link와 두 성인 시나리오는 `GOOGLE_ANDROID_TWO_ADULT_RUNBOOK.md`에 분리했다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| repository CI self-tests | PASS, 9/9 |
| Dart format / fatal analyze | PASS, analyzer issue 0 |
| full Flutter suite | PASS, 176 tests + 1 opt-in local connectivity skip |
| Google/Supabase auth contract | PASS, token redaction·초기화 1회·성공/취소/실패·session requirement·purge·composition |
| coverage | PASS, 2,393/3,091 lines (77.42%) |
| config / secret / codegen / architecture | PASS, high-confidence secret 0, generated drift 0, provider SDK boundary PASS |
| dependency license / OSV | PASS, Pub 149 / npm 15, Google packages BSD-3-Clause, known vulnerability 0 |
| backend regression | PASS, clean migration 4개, schema lint issue 0, pgTAP 207, invite Edge 22와 live contracts |
| Android dev APK | PASS, 216,120,695 bytes, `me.newlines.kinflow.dev`, SHA-256 `b7bd0486687fc2aaf23578db18b7b31aaf7494ea0ae0dbdd5168d3d1ca7d5e31` |
| Android prod APK | PASS, 216,121,216 bytes, `me.newlines.kinflow`, SHA-256 `a08696ca620086ff157ba0e50f48abd3749f54a8114ab74d6471a2710ea91542` |
| APK policy | PASS, API 24/36/36, backup disabled, exact normal permission allowlist, placeholder `/invite/*` App Link contract |
| GitHub Actions CI | PASS, run `30380934560`; backend 2m45s, dependency 1m16s, quality 3m59s, prod 4m59s, dev 5m10s, final gate 2s |

상세 실행 요약은 `logs/wp02-01-google-android-integration.log`에 있다. CI report, APK와 coverage 원본은 ignored local artifact다.

Remote run: <https://github.com/adtstack/KinFlow/actions/runs/30380934560>

## Data / API / Security / Privacy

- DB migration, RLS, RPC, Edge/API contract와 production Supabase project는 변경하지 않았다.
- 새 runtime dependency와 lockfile, Android merged-manifest permission set만 변경했다.
- Web OAuth client ID는 공개 식별자다. Web client secret, service-role key, signing material과 실제 provider token은 앱 config, Git, CI artifact와 evidence에 넣지 않는다.
- Google token은 gateway에서 Supabase exchange까지 한 요청의 메모리에만 존재한다. Supabase가 issuer/audience/signature를 검증해 발급한 session만 앱 session authority로 사용한다.
- 새 telemetry는 추가하지 않았다. provider exception description, Google account email/display name과 token은 stable result 경계를 넘지 않는다.
- Google local account state purge 실패는 보호 route와 다음 사용자 전환을 fail-closed 한다.

## Manual / Deferred Validation

- `adb devices -l` 결과 연결된 Android 기기가 없어 실제 설치, Google account chooser, cold start와 logout/account switch는 **NOT RUN**이다.
- dev/prod Google Auth Platform OAuth client, package/SHA 등록과 Supabase Google provider는 생성·수정하지 않았다.
- 실제 Supabase URL/publishable key, Web client ID와 server-side client secret을 주입하지 않았다.
- `AUTH_REDIRECT_HOST`는 아직 `auth.example.invalid`이다. owned HTTPS domain, `assetlinks.json`과 OS verified App Link는 **NOT RUN**이다.
- 서로 다른 성인 Google 계정 2개와 Android 기기 2대의 create-invite-accept/cold-start 시나리오는 **NOT RUN**이다.
- production Supabase deploy와 Google Play App Signing/배포 certificate 검증은 **NOT RUN**이다.

## Remaining Risks / Completion Boundary

1. Android Credential Manager는 일부 package/SHA/client 설정 오류를 사용자 취소로 보고할 수 있어 실제 기기에서 취소와 설정 실패를 구분해 점검해야 한다.
2. placeholder App Link host는 manifest contract만 검증하며 OS verified link를 성립시키지 않는다.
3. 실제 Google token의 audience, Supabase provider 설정과 session event ordering은 provider 연결 전까지 자동 fake 계약으로만 검증됐다.
4. `USE_FINGERPRINT`는 API 28부터 deprecated지만 minSdk 24의 Credential Manager/biometric 전이 호환성 때문에 merged manifest에 존재한다.
5. `sentry_flutter`의 legacy Kotlin Gradle Plugin warning은 build를 막지 않지만 향후 Flutter upgrade 전에 dependency review가 필요하다.

이 evidence는 `AUTOMATED INTEGRATION READY`만 선언한다. 실제 provider/domain/성인 2계정·2기기 evidence 전에는 WP02-01 전체와 Phase 02 Exit Gate를 `COMPLETE`로 선언하지 않는다.

## Rollback

- production provider 연결 전에는 implementation commit `a9de8a8`을 revert해 Google adapter, runtime composition, dependency/lockfile와 permission allowlist를 함께 제거한다.
- DB/API 변경이 없으므로 migration rollback은 없다.
- provider 연결 뒤 rollback하면 해당 환경의 Supabase Google provider와 Google OAuth clients를 비활성화하고 노출 가능성이 있는 자격증명은 폐기한다.

## Next Entry Condition

1. dev Google/Supabase project와 Web/Android OAuth clients
2. dev package `me.newlines.kinflow.dev`의 실제 설치 서명 SHA-1/SHA-256
3. owned dev HTTPS invite host와 `assetlinks.json`
4. 서로 다른 성인 Google 계정 2개와 Android 기기 2대

위 입력이 준비되면 `GOOGLE_ANDROID_TWO_ADULT_RUNBOOK.md` 순서대로 dev 실기기 gate를 먼저 통과하고, 같은 절차를 prod signing/provider로 승격한다.
