# Phase 01 WP01-05 Evidence

- Work Package: WP01-05 Design/i18n/a11y
- 기준 commit: base `b89538d`; WP01-05 change
- 검증일: 2026-07-24
- 환경: macOS arm64, Flutter 3.44.7 stable, Dart 3.12.2, Android SDK/target 36
- 결과: **AUTOMATED PASS / ANDROID DEVICE·TALKBACK PENDING**
- 범위 제한: 제품 feature UI, 실제 locale date/number formatting, 사용자 언어 저장, 전면 WCAG audit는 포함하지 않음

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP01-05 design tokens | PASS | Material 3 color/spacing/radius/elevation/touch/motion/breakpoint token과 light/dark theme |
| WP01-05 responsive scaffold | PASS | available width 기반 compact/medium/expanded widget tests |
| WP01-05 EN/KO/pseudo locale | PASS | exact ARB key coverage, generated output, ICU plural, per-message `en_XA` 30% expansion |
| WP01-05 semantics/text scale | PASS | heading/navigation/status/action semantics, 48dp action, 200% text smoke |
| D-036 / FR-PLAT-001 | PASS | 영어·한국어 Store locale와 test-only pseudo locale contract materialized |
| FR-PLAT-002 / NFR-A11Y-01 | AUTOMATED PASS | non-color status cue, contrast, semantics, touch target, reduced-motion smoke; TalkBack pending |
| FR-PLAT-009 | PASS | `<600`, `600..<840`, `>=840` exact breakpoint boundary |
| NFR-I18N-01 / T-I18N-01 | PASS | EN/KO/en_XA key 100%, ICU output, forced RTL mirror와 blocker overflow 0 |
| T-A11Y-03 / NFR-011 / NFR-012 | PASS | 320px compact와 medium/expanded에서 200% text blocker clipping 0 |

## Implementation

- `AppBreakpoints`, spacing, radius, elevation, touch, layout, icon, typography, motion과 semantic color를 중앙 token으로 만들었다.
- light/dark Material 3 theme에 semantic color extension, 48x48dp button/icon target, padded tap target, navigation rail 치수를 적용했다.
- shell은 `LayoutBuilder`의 available width를 사용한다. compact는 top header, medium은 compact rail, expanded는 extended persistent rail을 사용한다.
- 공통 status layout은 bounded content와 vertical scroll fallback을 제공해 좁은 화면과 200% text에서도 action 접근을 유지한다.
- ready/error는 icon과 text를 함께 제공하며 decorative icon은 semantics tree에서 제외했다. heading, navigation region, live status, retry label/hint를 명시했다.
- 영어·한국어 ARB에 navigation, retry hint, ICU plural을 추가하고 `en_XA` pseudo locale을 각 source message 대비 30% 이상 확장했다.
- 지원하지 않는 Arabic locale을 거짓 선언하지 않는다. RTL 구조는 forced `Directionality.rtl` widget test로 rail 위치와 directional alignment를 검증했다.
- l10n 생성 파일도 codegen drift verifier에 포함했다.

## Contract Integrity

| File | SHA-256 |
|---|---|
| `lib/app/theme/app_tokens.dart` | `7175eb97aac849eea1c803ec47721c81c325d93fb8df5a26a6e4942b533d7ad5` |
| `lib/l10n/app_en.arb` | `0020974f3a43d2fd81d97b236eead87b30294fe32f0ccaefebd7948ea1a99ab6` |
| `lib/l10n/app_ko.arb` | `f360c13daba5cbc48906e6c40ad97a89314fbef646603a384bcdcd795a028ff6` |
| `lib/l10n/app_en_XA.arb` | `bbccd084ed59fe8d3ceb35f96b16aa1bacb0cc7b8625cac89b96cba508088cf1` |
| `contracts/toolchain.json` | `9ac15ca19d805ea4ef02083a7c1b076635073c51587256f93b700e62899e75a1` |
| `pubspec.lock` | `8561ec37fb36a843723232293a3b6e89c5c950d740b3a1e7a3084be3cc7ee6d9` (unchanged) |

## Dependency / Data / API Review

- runtime/dev dependency 추가·업그레이드가 없고 `pubspec.lock`은 base와 동일하다.
- DB migration, seed, RLS, Edge/API schema 변경이 없다.
- native platform code, application ID, permission, network behavior, authentication/session, 개인정보 수집·저장 변화가 없다.
- Material, gen_l10n, flutter_test 등 exact-pinned Flutter SDK와 기존 dependency만 사용한다.

## Automated Validation

| 명령 | 결과 |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test tool` | PASS, 46 files, changed 0 |
| `flutter analyze --fatal-infos --fatal-warnings` | PASS, issue 0 |
| WP01-05 targeted Flutter tests | PASS, 16/16 |
| `flutter test --coverage` | PASS, 37 passed + local connectivity opt-in 1 skipped; 406/454 lines, 89.4% |
| `dart run tool/verify_codegen.dart` | PASS, l10n/build_runner generated drift 0 (5 files) |
| dev/prod debug APK build | PASS |
| staged-index clean bootstrap/analyze/test/dev build | PASS; 아래 재현 결과 참조 |

상세 명령과 핵심 output은 `logs/wp01-05-design-i18n-a11y.log`에 있다.

## Android Artifacts

빌드 산출물은 `.gitignore` 대상이며 저장소에 커밋하지 않는다. debug APK는 release signing이나 Play artifact 검증이 아니다.

| Flavor | package | API | bytes | SHA-256 |
|---|---|---|---:|---|
| dev | `me.newlines.kinflow.dev` | min 24 / target 36 / compile 36 | 184,881,896 | `d82bec9850aaaa0e22d3790d09cdff62778455f3363b9a7f29f3ecd757953abe` |
| prod | `me.newlines.kinflow` | min 24 / target 36 / compile 36 | 184,881,815 | `71fe37f353e561540dd1e0c837cc1a06bc37aaad45f5ea70b54d4825d37358d3` |

두 APK의 일반 permission은 기존 `INTERNET`뿐이다. AndroidX가 package-scoped `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`을 선언하며 dangerous runtime permission은 추가되지 않았다.

## Clean staged-index reproduction

- 스테이징된 index만 새 `/private/tmp` 디렉터리에 export했다.
- `flutter pub get --offline`이 성공했고 `pubspec.lock` SHA-256은 원본과 동일한 `8561ec37fb36a843723232293a3b6e89c5c950d740b3a1e7a3084be3cc7ee6d9`였다.
- format은 46 files changed 0, analyzer는 issue 0이었다.
- full Flutter test는 37 passed + opt-in local connectivity 1 skipped, coverage 407/454 lines(89.6%)였다.
- l10n/build_runner drift verifier는 5개 generated file의 재생성 전후 byte equality를 확인했다.
- clean dev APK는 package `me.newlines.kinflow.dev`, min/target/compile API 24/36/36, 153,611,173 bytes, SHA-256 `63a26623164368c341f2753bd987c17b0a86c5412cb8bcf2fe2a35cc389969df`였다.

## Manual Validation

- `adb devices -l` 결과 연결된 Android device/emulator는 0대였다.
- 실제 Android에서 EN/KO/pseudo, light/dark, 200% font, rotation/split view와 TalkBack focus order 확인은 **NOT RUN**이다.
- widget semantics/layout smoke와 APK metadata/permission audit만 자동 PASS로 기록한다. 실제 기기 검증 전에는 전체 접근성 승인으로 간주하지 않는다.

## Security / Privacy

- 사용자 데이터, 로그, analytics, identifier, credential을 새로 읽거나 전송하지 않는다.
- raw exception 노출 방지와 repository/SDK boundary는 기존 회귀 테스트로 유지했다.
- pseudo locale은 정적 test copy이며 실제 사용자 정보가 없고 Store 지원 언어로 광고하지 않는다.

## Remaining Risks / OPEN Decisions

- 실제 TalkBack announcement/focus order, OEM font rendering, physical tablet/split-screen은 연결 기기에서 검증되지 않았다.
- semantic color contrast는 현재 surface 기준 4.5:1 token test이며 향후 실제 component state/disabled/overlay 조합은 feature별 audit가 필요하다.
- Store locale은 EN/KO로 고정했지만 사용자 언어 override와 persistence 정책은 제품 설정 Work Package에서 결정해야 한다.
- pseudo locale을 production flavor 사용자 설정에 노출하지 않는 packaging 정책은 release hardening 때 재확인한다.

## Rollback

- 이 change를 되돌리면 `b89538d`의 WP01-04 shell로 복귀한다.
- theme/token, responsive/status widgets, screen refactor, ARB/generated localization, tests, toolchain/README/evidence를 함께 제거한다.
- DB/API/dependency/native permission 변경이 없어 data migration 또는 provider rollback은 없다.

## Next Entry

- 다음은 Phase 01 WP01-06 Observability/config다.
- 진입 조건은 WP01-05 automated Gate 유지, logging에서 PII/secret redaction contract 확정, dev/prod config source와 failure policy 작성이다.
- 실제 device/TalkBack smoke는 기기 확보 시 G1 전에 별도로 닫아야 한다.
