# Phase 02 WP02-01 Google Android Integration Work Plan

- 작성일: 2026-07-28
- 기준 commit: `a94ae55`
- Work Package: WP02-01 Auth lifecycle — Google native sign-in and Android two-adult integration
- 상태: IMPLEMENTED — LOCAL + REMOTE AUTOMATED PASS / PROVIDER·DEVICE PENDING
- 선행 결과: WP02-02~04 local/remote automated gate PASS, secure auth storage runtime composition PASS

## Requirements

| ID | 이번 vertical slice |
|---|---|
| WP02-01 / FR-AUTH-003 / D-054 | Android 로그인 수단을 Google 하나로 유지하고, Google ID/access token을 Supabase Auth의 `signInWithIdToken`으로 교환한다. Supabase session만 앱의 session authority로 사용한다. |
| FR-AUTH-004 | 로그인 성공 event를 기존 lifecycle state machine과 secure session restore에 연결하고 취소·provider 설정 오류·일시 장애를 typed failure로 처리한다. |
| FR-AUTH-005 / D-049 | logout/account switch purge에 Google SDK의 로컬 account state sign-out을 포함하고 실패 시 보호 route를 열지 않는다. |
| D-047 / CAP-001 | Google/Supabase SDK import를 infrastructure에 격리하고 feature domain/application에는 provider token/type을 노출하지 않는다. |
| D-055 | WP02-04 완료 뒤 credential-independent provider adapter와 자동 gate를 구현한다. 실제 Google/Supabase 설정과 Android 기기 검증은 별도 증거로 남긴다. |
| T-AUTH-01 / T-AUTH-02 | 성공, 사용자 취소, 설정 오류, 일시 장애, token 누락, Supabase 거절, sign-out purge와 runtime composition을 자동 테스트한다. |
| Phase 02 manual gate | dev/prod 패키지·서명 등록, 실제 성인 Google 계정 2개, 두 Android 기기와 owned HTTPS App Link가 준비되면 create-invite-accept/cold start/account switch를 실행한다. |

## Scope

1. `google_sign_in` 7.x를 추가하고 lockfile, license, Android SDK 호환성을 검증한다.
2. feature data layer에 provider-neutral sign-in data source/result와 domain launcher mapper를 추가한다.
3. infrastructure에 최신 `initialize` → `authenticate` 흐름을 감싸는 Google identity gateway와 Supabase ID-token exchange adapter를 추가한다.
4. ID token과 access token은 한 요청의 메모리 안에서만 전달하고 log, domain state, evidence, local storage에 기록하지 않는다.
5. 실제 형식의 `GOOGLE_WEB_CLIENT_ID`가 있을 때만 Google action을 활성화한다. placeholder/빈 값은 기존 fail-closed launcher를 유지한다.
6. Google local account sign-out participant를 secure auth storage 및 pending invite purge와 함께 조립한다.
7. Google SDK를 feature layer에서 직접 import하지 못하도록 architecture contract를 강화한다.
8. provider adapter, mapper, composition, purge, UI/lifecycle 회귀 테스트와 전체 CI gate를 실행한다.
9. dev/prod Google Cloud·Supabase 설정, Android signing fingerprint, App Link와 두 성인 실기기 절차를 실행 가능한 runbook으로 남긴다.

## Explicit Non-scope Until External Inputs Exist

- Google Cloud OAuth client 또는 Supabase project/provider의 생성·수정
- 실제 Web client ID, client secret, remote Supabase URL/key, signing keystore를 repository에 저장
- `google-services.json` 또는 Google Services Gradle plugin 도입
- owned HTTPS domain, `assetlinks.json` 배포와 Android verified-link 판정
- 실제 성인 Google 계정 2개 및 실제 Android 기기 2대 실행 결과를 자동 성공으로 대체
- WP02-05 role/Owner lifecycle, WP02-06 activation handoff, WP02-07 전체 authorization 확장

## Dependency Review

| 항목 | 결정 |
|---|---|
| package | `google_sign_in` `^7.2.0`, lockfile에서 정확한 package와 Android implementation patch 고정 |
| 목적 | Android Credential Manager 기반 Google native authentication 및 Google identity/access token 획득 |
| 표준 SDK 대안 | Flutter/Dart 표준 library에는 Android Google identity API가 없다. 브라우저 OAuth redirect는 Google-only native Android UX와 account chooser 요구에 비해 불필요한 callback surface를 만든다. |
| Android 등록 | Gradle `google-services.json` 대신 runtime `serverClientId`를 사용한다. Android OAuth clients는 `me.newlines.kinflow.dev`와 `me.newlines.kinflow` 각각에 서명 SHA를 등록한다. |
| server 설정 | Web OAuth client ID는 app의 공개 설정과 Supabase Google provider audience에 동일하게 사용한다. client secret은 Supabase/Google server-side 설정에만 존재한다. |
| 호환성 | package는 Android API 21+를 지원하며 앱 minSdk 24와 호환된다. 현재 Flutter 3.44.7/Dart 3.12.2/Java 17에서 dev/prod APK를 다시 빌드한다. |
| license | Flutter team publisher, BSD-3-Clause. dependency/license 및 offline vulnerability gate 결과를 evidence에 기록한다. |
| privacy/network | Google 및 Supabase 인증 endpoint 외 새 telemetry를 추가하지 않는다. token/이메일/provider exception message를 log에 남기지 않는다. |
| Android permissions | Credential Manager의 `androidx.biometric` 전이 의존성이 `USE_BIOMETRIC`과 API 24 호환용 deprecated `USE_FINGERPRINT`를 선언한다. 둘 다 Android `normal` 권한이며 dangerous/runtime permission은 추가하지 않는다. APK exact allowlist로 고정한다. |
| testability | plugin과 Supabase token exchange 뒤에 infrastructure gateway를 두고 token이 redacted되는 fake/result로 모든 분기를 검증한다. |
| rollback | launcher/data source/gateway/purge participant와 dependency/lockfile을 함께 revert하면 기존 Google action disabled 상태로 돌아간다. DB rollback은 없다. |

공식 구현 기준은 Flutter team의 [`google_sign_in` 7.x 문서](https://pub.dev/packages/google_sign_in), [Android integration 문서](https://pub.dev/packages/google_sign_in_android), Supabase의 [`signInWithIdToken` 문서](https://supabase.com/docs/reference/dart/auth-signinwithidtoken)다.

## Security Contract

- 앱은 Google token의 issuer/audience를 자체 신뢰 판정하지 않는다. Google이 발급한 token을 TLS로 Supabase Auth에 보내고 Supabase provider 설정이 issuer/audience/signature를 검증한 뒤 발급한 session만 수용한다.
- ID/access token은 provider gateway → Supabase exchange 사이의 일시 객체에만 존재하며 문자열 표현은 항상 redacted한다.
- Google/Supabase의 raw exception, account email/display name/provider payload는 domain/UI/log/evidence로 전달하지 않는다.
- ID token 또는 access token이 비어 있으면 exchange하지 않고 invalid provider response로 실패한다.
- 사용자 취소는 오류 banner 없이 unauthenticated 상태로 복귀한다. 설정 오류와 Android Credential Manager의 취소 오분류 가능성은 실제 기기 runbook에서 별도로 점검한다.
- sign-out participant 실패는 composite purge failure로 처리해 새로운 사용자/보호 route 공개를 차단한다.
- dev/prod는 Supabase project, Web OAuth client, Android package/client와 signing material을 분리한다.

## Automated Validation

- Google gateway 초기화 1회, ID/access token 획득, token 누락, 취소와 typed failure mapping
- Supabase Google exchange가 두 token을 전달하고 성공/일시 장애/provider 거절/invalid response를 stable result로 매핑
- provider-neutral data result → domain launcher result mapping과 raw payload 비노출
- 빈/placeholder Google client ID는 disabled, 유효한 client ID와 지원 플랫폼은 enabled
- logout/account switch composite purge가 Google sign-out을 시도하고 실패 시 fail-closed
- auth lifecycle의 authenticating → cancel/failure/session-established 회귀
- Google/Supabase SDK import가 infrastructure 밖에 없는 architecture scan
- format, fatal analyze, full Flutter suite/coverage, secret/config/codegen, dependency/license/offline vulnerability gate
- Android dev/prod debug APK build, package/manifest/permission/App Link audit

GitHub Actions run [`30380934560`](https://github.com/adtstack/KinFlow/actions/runs/30380934560)에서 quality, dependency, backend, dev/prod Android와 final gate가 모두 통과했다.

## Data / API Impact

- DB migration, seed, RLS, RPC, Edge/API contract 변경 없음.
- 앱 runtime dependency와 `pubspec.lock`은 변경한다.
- 기존 공개 config key `GOOGLE_WEB_CLIENT_ID`만 사용하며 새 secret/config key는 추가하지 않는다.
- remote Google/Supabase provider와 GitHub setting은 이 credential-independent implementation에서 변경하지 않는다.

## Manual Integration Inputs And Procedure

필요 입력은 repository에 commit하지 않고 로컬/remote secret 관리 영역에서 주입한다.

1. dev/prod Google Auth Platform project 또는 명시적으로 분리된 client set
2. 각 환경의 Web OAuth client ID와 Supabase Google provider의 같은 client ID/server-only secret
3. Android OAuth client: `me.newlines.kinflow.dev`, `me.newlines.kinflow`와 각 debug/release 또는 Play App Signing SHA-1/SHA-256
4. 실제 dev/prod Supabase URL과 publishable key
5. owned HTTPS invite host, 두 package 및 실제 signing SHA-256을 포함한 `/.well-known/assetlinks.json`
6. 서로 다른 성인 Google 계정 2개와 Android 기기 2대

실행 순서는 A 로그인·가구 생성 → invite 발급 → B 기기의 cold-start HTTPS link → B Google 로그인 → invite continuation/accept → 두 기기 재진입 → logout/account switch purge다. 각 단계에서 Supabase user/membership UUID만 확인하고 Google token·이메일은 증거에 저장하지 않는다.

## Stop / Rollback

- token, client secret, service key, signing credential이 Git/log/evidence에 나타나면 즉시 중단하고 노출 자격증명을 폐기한다.
- Google token exchange 성공 없이 authenticated route가 열리거나 purge 실패 뒤 다른 account data가 보이면 다음 작업으로 진행하지 않는다.
- provider adapter, composition, dependency와 관련 테스트를 함께 revert하면 기존 fail-closed Google UI로 복귀한다.
- DB/API 변경이 없으므로 migration rollback은 없다. remote provider 설정을 시작한 뒤 rollback하면 해당 환경의 Google provider와 OAuth client를 비활성화/폐기한다.

## Completion Boundary

- 자격증명 없이 가능한 구현·자동 gate·APK가 green이면 `AUTOMATED INTEGRATION READY`로만 기록한다.
- 실제 dev Google/Supabase provider, package/SHA, 성인 2계정/2기기와 owned App Link를 모두 통과하기 전에는 WP02-01 또는 Phase 02 Exit Gate를 `COMPLETE`로 선언하지 않는다.
