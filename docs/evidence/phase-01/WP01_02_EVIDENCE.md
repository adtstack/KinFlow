# Phase 01 WP01-02 Evidence

- Work Package: WP01-02 App Shell
- 기준 commit: base `51aac4f`; WP01-02 change
- 검증일: 2026-07-24
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Android SDK/compile/target 36, NDK 28.2.13676358
- 결과: **LOCAL AUTOMATED PASS / DEVICE BOOT PENDING**
- 범위 제한: G0 전체 통과나 Phase 01 완료가 아니며 외부 provider는 연결하지 않음

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP01-02 dev/prod entrypoint/bootstrap | PASS | `lib/main_dev.dart`, `lib/main_prod.dart`, `lib/app/bootstrap.dart` |
| WP01-02 MaterialApp.router/go_router | PASS | home/not-found route widget test |
| WP01-02 loading/fatal recovery | PASS | pending, failure redaction, retry recovery widget tests |
| WP01-02 environment banner | PASS | dev visible/prod absent widget test |
| WP01-02 theme/locale skeleton | PASS | Material 3 light/dark, EN/KO ARB/gen_l10n, locale override test |
| D-006 Riverpod/go_router | PASS | resolved and locked direct dependencies |
| D-032 environment isolation | PASS | native identifiers preserved, custom dev banner only |
| D-036 localization skeleton | PASS | English/Korean generated localization |

## Implementation

- `ProviderScope`가 environment와 startup initializer를 조립한다.
- `MaterialApp.router`가 Riverpod으로 소유한 `GoRouter`를 사용한다.
- bootstrap state는 route와 분리된 `AppBootstrapGate`가 처리한다.
- startup exception/stack은 UI에 전달하지 않고 generic localized failure와 retry만 노출한다.
- dev는 custom banner를 표시하고 prod는 debug banner를 포함해 환경 표식을 노출하지 않는다.
- locale provider가 `null`이면 system locale, 값이 있으면 명시 locale을 사용한다.
- 사용자 표시 문자열은 EN/KO ARB에서 생성하며 generated localization source를 커밋한다.

## Dependency Review

| Dependency | Locked version | License | Native permission/network/PII |
|---|---:|---|---|
| flutter_riverpod | 3.3.2 | MIT | 없음 |
| go_router | 17.3.0 | BSD-3-Clause | 없음 |
| flutter_localizations | Flutter SDK | BSD-3-Clause | 없음 |
| intl | 0.20.2 | BSD-3-Clause | 없음 |

`intl 0.20.3` 단독 해석 후 Flutter SDK의 `flutter_localizations` pin과 충돌해, SDK가 요구하는 0.20.2로 고정했다. Firebase/Supabase/Google/Sentry 같은 외부 SDK는 추가하지 않았다.

## Automated Validation

| 명령 | 결과 |
|---|---|
| `flutter pub add ...` / `flutter pub get` | PASS, direct dependency와 lockfile 고정 |
| `flutter gen-l10n` | PASS, EN/KO generated source |
| `dart format --output=none --set-exit-if-changed lib test` | PASS, 19 files, 0 changed |
| `flutter analyze --fatal-infos --fatal-warnings` | PASS, issue 0 |
| `flutter test --coverage` | PASS, 7/7; line 161/171, 94.2% |
| dev `flutter build apk --debug --flavor dev ...` | PASS |
| prod `flutter build apk --debug --flavor prod ...` | PASS |
| `aapt dump badging` dev/prod | PASS, identifier/API 계약 유지 |
| staged-index clean bootstrap/analyze/test/build | PASS, offline restore + generated source byte match + issue 0 + 7/7 + dev APK |
| `adb devices -l` | PASS command / connected device 0 |

상세 로그는 `logs/wp01-02-app-shell.log`에 있다.

## Artifacts

빌드 산출물은 `.gitignore` 대상이며 저장소에 커밋하지 않는다.

| Flavor | package | bytes | SHA-256 |
|---|---|---:|---|
| dev | `me.newlines.kinflow.dev` | 165,172,630 | `5d4ad8889b321ae72ee6590bfd3eef46228e1bac3c0d0c8f12aee9c662f6ad8a` |
| prod | `me.newlines.kinflow` | 165,172,682 | `e1b78b3e0a296ebd3a7032c6ae255c6962fe2e9926a4ac30b696c4f8f1770b5a` |

두 APK 모두 min API 24, target/compile API 36이다. debug APK는 release signing이나 Play artifact 검증이 아니다.

### Clean staged-index reproduction

- 스테이징된 index만 새 `/private/tmp` 디렉터리에 export했다.
- `flutter pub get --offline`, `flutter gen-l10n`, analyzer, widget test, dev APK build를 순서대로 실행해 모두 PASS했다.
- 재생성된 localization 3개 파일과 `pubspec.lock`은 작업 트리 파일과 byte-identical이다.
- clean dev APK는 package `me.newlines.kinflow.dev`, 150,683,666 bytes, SHA-256 `539a4f187c46fe56a5c94b1678729f63cedf320dfc1a575e0a676af8a03026a0`이다.

## Data / Security / Privacy

- DB migration, API, RLS, Edge Function 변경 없음
- Google/Supabase/Firebase/RevenueCat/Sentry project·SDK·secret 없음
- startup raw exception과 stack trace를 사용자 UI에 노출하지 않음
- test key와 route에 사용자 개인정보 없음
- environment config placeholder와 기존 no-secret 규칙 유지

## Manual Validation

- 검증 시점 `adb devices -l`의 연결 기기는 0대였다.
- 실제 Android에서 loading/home, dev banner, dark mode, EN/KO와 retry UI 확인은 아직 NOT RUN이다.
- WP01-05에서 pseudo locale, 200% text scale, TalkBack과 responsive class를 정식 검증한다.

## Remaining Risks / Next Entry

- App initializer는 현재 외부 dependency가 없어 정상 no-op이며, 후속 SDK는 initializer port를 통해 추가해야 한다.
- home 화면은 foundation 상태 확인용이며 제품 navigation/onboarding이 아니다.
- G0 사용자 연구·법률/Store·console recovery 증거는 미완료다.
- 다음 Work Package는 WP01-03 Architecture Boundary다. domain/application/data sample slice와 repository port/fake adapter/import test를 한 단위로 구현한다.

## Rollback

- 이 change를 되돌리면 `51aac4f`의 WP01-01 blank foundation으로 복귀한다.
- 새 runtime dependency, app shell, ARB/generated localization과 관련 테스트를 함께 제거한다.
- DB/provider/사용자 데이터가 없어 data rollback은 없다.
