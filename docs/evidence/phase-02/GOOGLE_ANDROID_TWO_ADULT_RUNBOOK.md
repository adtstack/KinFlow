# Google Android Two-Adult Integration Runbook

- 대상: Android only, 성인 2인, `dev` / `prod`
- package: `me.newlines.kinflow.dev` / `me.newlines.kinflow`
- 적용 범위: Google native sign-in, Supabase Auth, HTTPS invite App Link
- 금지: client secret, service-role key, signing key/password, 실제 Google token 또는 이메일의 Git/log/evidence 저장

## 1. Environment Inventory

아래 값은 환경별로 분리해 비공개 운영 기록에 보관한다. 저장소의 example config는 교체하지 않는다.

| 값 | dev | prod |
|---|---|---|
| Supabase project ref / URL | 준비 필요 | 준비 필요 |
| Supabase publishable key | 준비 필요 | 준비 필요 |
| Google Auth Platform project | 준비 필요 | 준비 필요 |
| Web OAuth client ID | 준비 필요 | 준비 필요 |
| Web OAuth client secret | Supabase server-side only | Supabase server-side only |
| Android OAuth package | `me.newlines.kinflow.dev` | `me.newlines.kinflow` |
| Android signing SHA-1 | debug/internal signing | Play App Signing 또는 배포 signing |
| App Link signing SHA-256 | debug/internal signing | Play App Signing |
| invite host | owned dev HTTPS host | owned prod HTTPS host |

권장 기본값은 dev/prod Google project와 Supabase project를 각각 분리하는 것이다. 같은 Google project를 사용해야 한다면 Web/Android OAuth client는 환경별로 반드시 분리한다.

## 2. Collect Android Signing Fingerprints

로컬 debug/internal build의 실제 variant fingerprint를 확인한다.

```bash
cd apps/kinflow_app/android
./gradlew :app:signingReport
```

기록 대상은 `devDebug`, `prodDebug`와 실제 release variant의 package, SHA-1, SHA-256이다. prod가 Google Play App Signing을 사용하면 설치 사용자에게 전달되는 APK/AAB의 인증서는 Play Console `App integrity`에 있는 App signing certificate이므로, 해당 SHA-1을 prod Android OAuth client에 사용하고 SHA-256을 `assetlinks.json`에 사용한다. Upload certificate만 등록해 실제 배포 인증서를 빠뜨리지 않는다.

## 3. Configure Google Auth Platform Per Environment

1. Branding에서 앱 이름, 지원 이메일, 개인정보처리방침/홈페이지의 owned HTTPS URL을 설정한다.
2. Audience를 정한다. 테스트 상태라면 성인 테스트 계정 2개를 test users에 추가한다.
3. Data Access scopes는 `openid`, `userinfo.email`, `userinfo.profile`만 사용한다. 불필요한 People API scope는 추가하지 않는다.
4. Web application OAuth client를 만든다.
5. Authorized redirect URI에 해당 Supabase Google provider 화면이 제시하는 callback을 추가한다. local Supabase는 `http://127.0.0.1:54321/auth/v1/callback`이다.
6. Android OAuth client를 만든다.
   - dev: package `me.newlines.kinflow.dev` + dev 설치물을 서명한 SHA-1
   - prod: package `me.newlines.kinflow` + 실제 배포물을 서명한 SHA-1
7. Web client ID는 앱의 `GOOGLE_WEB_CLIENT_ID`에 공개 값으로 주입한다. Web client secret은 앱 config, CI artifact, Dart define 또는 Git에 넣지 않는다.

KinFlow는 `google-services.json` 없이 `serverClientId`를 runtime에 전달한다. 따라서 Google Services Gradle plugin이나 Firebase 등록 파일은 필요하지 않다.

## 4. Configure Supabase Google Provider

각 Supabase project의 Authentication → Providers → Google에서 다음을 설정한다.

1. Google provider enabled
2. 해당 환경의 Web OAuth client ID가 첫 번째 client ID
3. 해당 Web client secret은 Supabase server-side 설정에만 저장
4. 추가 Android client ID를 허용 목록에 넣어야 한다면 Supabase 안내대로 Web client ID 다음에 comma-separated로 추가
5. `skip_nonce_check`는 `false` 유지
6. Site URL/redirect allowlist에는 실제 owned HTTPS URL만 사용하고 prod에서 localhost/example.invalid를 제거

앱은 Google ID/access token을 `signInWithIdToken`으로 보내며, Google token의 issuer/audience/signature를 직접 신뢰 판정하지 않는다. Supabase가 검증해 발급한 session이 존재할 때만 로그인 성공이다.

## 5. Prepare Local Runtime Config Without Committing It

`config/*.example.json`을 원본으로 Git ignored 로컬 파일을 만들고 아래 공개 값만 교체한다.

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- `GOOGLE_WEB_CLIENT_ID`
- `PUBLIC_SITE_URL`
- `AUTH_REDIRECT_HOST`
- `SUPPORT_URL`
- `PRIVACY_REQUEST_URL`

실행 전 config validator를 통과시킨다. `AUTH_REDIRECT_HOST`는 DNS host만 넣고 scheme, port와 path는 넣지 않는다. 아래 wrapper는 같은 JSON에서 host를 읽어 Dart runtime과 Android merged manifest에 동시에 주입하므로 두 값이 어긋나지 않는다.

```bash
KINFLOW_FLUTTER_BIN=/private/tmp/kinflow-flutter-src-3.44.7/bin/flutter \
  scripts/run-android.sh dev config/dev.local.json --device-id <android-device-id>
```

`config/dev.local.json`은 app root 기준 경로다. build artifact만 필요하면 같은 config를 사용해 아래 gate를 실행한다.

```bash
KINFLOW_FLUTTER_BIN=/private/tmp/kinflow-flutter-src-3.44.7/bin/flutter \
KINFLOW_PUBLIC_CONFIG=config/dev.local.json \
  scripts/ci/android-build.sh dev
```

실제 실행 명령은 Flutter version과 현재 app bootstrap의 define 계약에 맞춰 pinned toolchain을 사용한다. 명령 출력과 screenshot에 publishable key 이외의 credential 또는 Google token이 없는지 확인한다. wrapper와 build gate는 exact public key allowlist만 허용하므로 client secret 또는 service-role key가 local JSON에 들어가면 실행 전에 실패한다.

## 6. Publish And Verify Invite App Link

owned HTTPS host에 `/.well-known/assetlinks.json`을 배포한다. dev/prod를 같은 host에서 허용한다면 두 package와 각각의 실제 signing SHA-256을 별도 statement로 둔다.

현재 dev 설치물과 일치하는 dev-only 정적 source는 `apps/public_site/public/.well-known/assetlinks.json`이다. 배포 직전에 APK package와 signer를 source에 다시 대조한다.

```bash
scripts/verify-android-app-links.sh \
  dev \
  apps/kinflow_app/build/app/outputs/flutter-apk/app-dev-debug.apk \
  apps/public_site/public/.well-known/assetlinks.json
```

이 dev source를 prod host에 배포하지 않는다. prod는 Play App Signing으로 실제 사용자에게 전달되는 인증서가 확정된 뒤 non-debuggable delivered APK와 별도 statement를 검증한다.

필수 관계는 `delegate_permission/common.handle_all_urls`이고 대상 namespace는 `android_app`이다. Content-Type은 JSON이며 redirect 없이 HTTPS 200으로 응답해야 한다.

기기에서 확인한다.

```bash
adb shell pm verify-app-links --re-verify me.newlines.kinflow.dev
adb shell pm get-app-links me.newlines.kinflow.dev
adb shell am start -W -a android.intent.action.VIEW -d "https://<owned-host>/invite/<test-token>"
```

prod는 package만 `me.newlines.kinflow`로 바꾼다. `auth.example.invalid`은 placeholder이므로 실제 검증 성공 증거로 사용할 수 없다.

## 7. Two-Adult / Two-Device Scenario

실제 token·이메일·초대 원문은 evidence에 복사하지 않고 opaque Supabase UUID와 stable result code만 기록한다.

1. 기기 A에서 성인 계정 A로 Google 로그인한다.
2. 첫 가구를 만들고 빈 Today에 진입한다.
3. A가 invite를 한 번 발급한다.
4. 앱이 설치됐지만 실행 중이지 않은 기기 B에서 HTTPS invite link를 연다.
5. B가 성인 계정 B로 Google 로그인한다.
6. login 전 capture한 invite가 복원되어 preview 후 accept되는지 확인한다.
7. A/B 양쪽에서 같은 household UUID와 서로 다른 adult member UUID가 보이는지 확인한다.
8. B 앱을 force-stop/cold start하고 secure Supabase session으로 재진입하는지 확인한다.
9. B logout 후 Google action이 account chooser를 다시 열고, A 또는 다른 계정으로 전환하는 동안 이전 household route/cache가 보이지 않는지 확인한다.
10. expired/revoked session, offline launch, invite replay, concurrent accept를 다시 실행해 기존 automated contract와 실제 동작이 일치하는지 확인한다.

## 8. Evidence Checklist

- app version/commit, Android OS/device model, build flavor/package
- Google/Supabase environment 이름과 OAuth client의 식별 가능한 끝 6자만 기록
- 설치 artifact SHA-256과 signing certificate SHA-1/SHA-256
- Google 로그인 성공/취소/오프라인/잘못된 SHA 시 stable UI 결과
- two-adult household/member UUID는 필요하면 앞 8자만 기록
- cold-start invite link, accept idempotency, logout/account switch purge 결과
- `adb pm get-app-links`의 verified 상태
- raw ID/access/refresh token, 이메일, client secret, invite token은 기록하지 않음

## 9. Stop Conditions

- 계정 A의 household가 B 전환 중 노출됨
- Supabase session 발급 전에 protected route가 열림
- Google/Supabase token 또는 이메일이 log/crash report/evidence에 남음
- invite link가 browser fallback 또는 다른 앱으로 열리는데 success로 기록됨
- prod package가 debug/upload-only SHA에만 의존함
- logout/purge 실패 뒤 새 로그인 action이 그대로 진행됨

하나라도 발생하면 Phase 02 Exit Gate는 실패다. provider를 비활성화하고 자격증명 노출이 있었다면 즉시 폐기·교체한 뒤 원인 수정과 전체 시나리오 재실행이 필요하다.

## Official References

- [Android App Links website association](https://developer.android.com/training/app-links/configure-assetlinks)
- [Android App Links verification](https://developer.android.com/training/app-links/verify-applinks)
- [Flutter `google_sign_in` 7.x](https://pub.dev/packages/google_sign_in)
- [Flutter Android integration and troubleshooting](https://pub.dev/packages/google_sign_in_android)
- [Supabase Google provider setup](https://supabase.com/docs/guides/auth/social-login/auth-google)
- [Supabase Flutter `signInWithIdToken`](https://supabase.com/docs/reference/dart/auth-signinwithidtoken)
