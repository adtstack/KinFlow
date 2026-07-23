# Phase 01 WP01-01 Evidence

- Work Package: WP01-01 저장소와 Toolchain
- 기준 commit: base `d28eb08`; WP01-01 change
- 검증일: 2026-07-23
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Android SDK/compile/target 36, NDK 28.2.13676358
- 결과: **LOCAL AUTOMATED PASS / DEVICE BOOT PENDING**
- 범위 제한: G0 전체 통과나 Phase 01 완료가 아니며 production provider는 연결하지 않음

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| D-001 exact Flutter/Dart | PASS | `.fvmrc`, `contracts/toolchain.json`, `flutter --version` |
| D-002 Android Store MVP | PASS | Android-only Flutter platform scaffold |
| D-032 dev/prod 환경 | PASS | native product flavors + Dart entrypoints |
| D-052 application IDs | PASS | APK manifest의 dev/prod package 검사 |
| D-053 개인 운영 owner | DECISION PASS / CONSOLE PENDING | ADR-0002, Phase 00 manual setup |
| D-054 Google 로그인 | CONTRACT ONLY | config key와 Phase 02 진입 계약; SDK/provider 미연결 |
| WP01-01 저장소 구조 | PASS | `apps/kinflow_app`, `apps/public_site`, `supabase`, `contracts`, `docs` |
| WP01-01 bootstrap 문서 | PASS | root/app README |

## Automated Validation

| 명령 | 결과 |
|---|---|
| `flutter pub get` | PASS, `pubspec.lock` 갱신 |
| `dart format --output=none --set-exit-if-changed lib test` | PASS, 0 changed |
| `flutter analyze --fatal-infos --fatal-warnings` | PASS, issue 0 |
| `flutter test` | PASS, 2/2 |
| dev `flutter build apk --debug --flavor dev ...` | PASS |
| prod `flutter build apk --debug --flavor prod ...` | PASS |
| `aapt dump badging` dev/prod | PASS, identifier/label/API 계약 일치 |
| staged index clean export → offline pub get/analyze/test/dev build | PASS, 로컬 ignored 파일 의존 없음 |
| `adb devices -l` | PASS command / connected device 0 |

상세 로그는 `logs/wp01-01-foundation.log`에 있다.

Clean bootstrap은 스테이징된 index만 `/private/tmp/kinflow-wp01-index.4YJTTk`에 내보내 `.dart_tool`, `build`, `local.properties`, Gradle wrapper 실행 파일과 사용자 설정이 없는 상태에서 수행했다. Flutter tool이 필요한 로컬 파일을 재생성했고 dev APK build가 통과했다.

## Artifacts

빌드 산출물은 `.gitignore` 대상이며 저장소에 커밋하지 않는다.

| Flavor | package/label | API | bytes | SHA-256 |
|---|---|---|---:|---|
| dev | `me.newlines.kinflow.dev` / KinFlow Dev | min 24, target/compile 36 | 146,011,378 | `9bd0def788e1e26d277e4c47cf6b7dceaad620496f3bb265dbaf9bab2fd5166a` |
| prod | `me.newlines.kinflow` / KinFlow | min 24, target/compile 36 | 146,011,406 | `168468ae40436c8006449a5119509df53176fa15b801c080a7e3002740ff34de` |

debug APK는 release artifact가 아니며 production signing을 검증하지 않는다.

## Toolchain Repair

공용 Android SDK의 NDK 28.2.13676358이 `.installer`만 있고 `source.properties`가 없어 최초 build가 실패했다.

1. 불완전 디렉터리를 `/private/tmp/kinflow-ndk-28.2.13676358-incomplete-20260723`으로 보존 이동했다.
2. 공식 `sdkmanager --install "ndk;28.2.13676358"`로 다시 설치했다.
3. `source.properties`, `ndk-build`, toolchain과 2.8GB 설치 크기를 확인했다.
4. production Gradle은 구형 NDK pin 없이 `flutter.ndkVersion`을 유지했고 dev/prod build가 통과했다.

Android SDK `.temp`에는 SDK Manager가 만든 이전 설치 작업 잔여물이 남을 수 있으며 이 작업에서는 삭제하지 않았다.

## Security / Privacy

- 외부 console, OAuth client, Supabase project와 실제 사용자 데이터 생성 없음
- config에는 공개 client 설정의 placeholder만 존재
- Google client secret, service role key, signing key를 저장소와 APK config에 넣지 않음
- release build에 debug signing fallback을 두지 않음

## Manual Validation

- Product owner는 Android 실기기를 보유한다고 확인했다.
- 검증 시점 `adb devices -l`의 연결 기기는 0대였다.
- dev APK install/boot와 화면 확인은 기기 USB debugging 연결 후 수행해야 한다.
- Google 로그인은 Phase 02에서 dev Google/Supabase 설정과 함께 실제 기기 검증한다.

## Remaining Risks / Entry Condition

- G0 사용자 연구·법률/Store·보관/가격 결정은 미완료다.
- 개인 console 접근, 2단계 인증, recovery와 Play 계정 생성일은 미검증이다.
- WP01-02 App Shell 전에는 ARB/i18n, router, Riverpod, 환경 배너가 없다. 현재 blank shell은 foundation build target일 뿐 사용자 기능이 아니다.
- 다음 허용 작업은 WP01-02이며, production provider 생성은 G0 closure 뒤에만 허용한다.

## Rollback

- `apps/kinflow_app`, `.fvmrc`, runtime `contracts/`, 예약 디렉터리와 ADR-0002 적용 변경을 되돌리면 된다.
- DB migration, production console, 사용자 데이터가 없어 데이터 rollback은 없다.
- Android NDK repair는 workspace rollback과 무관하며, 원래 불완전 디렉터리는 `/private/tmp`에 보존돼 있다.
