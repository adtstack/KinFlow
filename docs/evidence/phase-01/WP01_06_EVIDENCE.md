# Phase 01 WP01-06 Evidence

- Work Package: WP01-06 Observability/config
- 기준 commit: base `c9d92f8`; WP01-06 change
- 검증일: 2026-07-25
- 환경: macOS arm64, Flutter 3.44.7 stable, Dart 3.12.2, Android SDK/target 36
- 결과: **AUTOMATED PASS / ANDROID DEVICE·REMOTE SENTRY PENDING**
- 범위 제한: production Sentry project/alert, analytics, tracing, replay, remote config와 Google 로그인은 포함하지 않음

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP01-06 structured logger/redaction | PASS | exact attribute allowlist, stable event/error code, bounded scalar, sink failure isolation, dev-only JSON console |
| WP01-06 Sentry dev/prod boundary | AUTOMATED PASS | 공통 adapter와 per-flavor DSN/environment/release/contract 설정, privacy-first options/filter; 실제 remote 수신은 pending |
| WP01-06 public config loader/validator | PASS | 14개 exact public key, dev/prod identity, URI/transport/format, placeholder runtime fail-closed |
| D-033 / NFR-SEC-02 | PASS | server-only key가 값 유무와 관계없이 거부되고 schema/example/runtime allowlist가 일치 |
| D-034 / NFR-PRIV-01 | AUTOMATED PASS | `sendDefaultPii=false`, user/request/content 제거, screenshot/view hierarchy/tracing/replay 비활성화 |
| NFR-OBS-01 | PASS | UTC timestamp, environment, `APP_ID@APP_VERSION`, contract version, Android correlation |
| FR-SET-007 | PASS | 향후 진단 화면이 소비 가능한 app/build/environment/incident-safe record 기반 마련 |
| T-STATIC-04 | PASS | repository high-confidence secret scan finding 0과 positive scanner fixture |
| T-PRIV-03 | PASS | email/bearer/JWT/query/credential 유사 값 redaction과 Sentry serialized payload 금지값 0 |
| RISK-014 / GAP-017 | MITIGATED | allowlist-first logging, before-send scrubber, public config schema, no-secret scan |

## Implementation

- compile-time `String.fromEnvironment`만 읽는 공개 설정 loader를 만들고 `APP_ENV`와 flavor application ID를 함께 검증한다.
- client 허용 key 14개를 `contracts/client-public-config.schema.json`, runtime key 상수, dev/prod example에 동일하게 고정했다. unknown/server-only key는 빈 값이어도 거부한다.
- production URL은 HTTPS만 허용한다. dev는 Supabase/Sentry의 emulator 또는 localhost origin만 HTTP를 허용한다.
- example의 Supabase placeholder는 정적 검증만 통과하고 runtime에서는 raw value를 노출하지 않는 stable issue code와 함께 fail-closed 한다.
- structured logger는 UTC timestamp, level, stable event, environment/release/contract/platform과 allowlisted scalar attributes만 출력한다. unknown/nested/free-form 값은 drop 또는 redaction한다.
- startup/init 성공·실패를 stable event로 기록하고 raw exception/message/stack을 logger에 전달하지 않는다. sink 실패는 app 동작을 중단하지 않는다.
- dev는 JSON console sink를 사용하고 prod는 verbose console sink를 만들지 않는다. DSN이 있을 때만 Sentry sink를 추가한다.
- Sentry SDK import는 `infrastructure/observability`에 격리했다. DSN이 비어 있으면 SDK/network를 초기화하지 않는다.
- Sentry before-send는 user, request, extra, contexts, tags, transaction, local variable, absolute path와 raw exception/message를 제거한다. KinFlow structured breadcrumb 외 자동 breadcrumb는 폐기한다.
- repository scanner는 private key, 주요 provider token, JWT와 server-only secret assignment를 감지하되 발견 value는 출력하지 않는다.

## Contract Integrity

| File | SHA-256 |
|---|---|
| `lib/app/config/app_public_configuration.dart` | `746d20199064c016f3749399b1d92cbd0f1d850561345c106265b46153eb64eb` |
| `lib/app/observability/app_telemetry_sanitizer.dart` | `19c775a06463dc15afd8cc36dc0ede6fe254387a16e766d5a5d9217258ecbbd9` |
| `lib/infrastructure/observability/sentry_privacy_filter.dart` | `c9f18a8fd20f4c6b11ae42a900ba8d43d1b453baae2960b354ca8e47763e84f5` |
| `tool/security/secret_scanner.dart` | `c4bc0d110564dd515ce4aed6919c002d8e921091daff9d7ab77b07fc06e51468` |
| `contracts/client-public-config.schema.json` | `e9bb04a2603707ca2c0d4534c956c8cc9e82b8e5bdb05479bf2f7fab7bbb404f` |
| `contracts/toolchain.json` | `0f66fa753f323912be57f1b9723e0e4cf4b32b9f17441a7a28f2c020e477e6ba` |
| `pubspec.lock` | `1d733753db145eb8e08e9697df31e6e8dc5ac7f4a3b768766f54024af33f3950` |

## Dependency / Data / API Review

- runtime dependency로 `sentry_flutter 9.25.0`을 exact pin했다. package의 Flutter/Dart minimum은 현재 toolchain과 호환되고 로컬 license는 MIT로 확인했다.
- lockfile은 `sentry 9.25.0`, `jni 0.14.2`, `package_info_plus 10.2.1`, `win32 6.3.0`, `ffi_leak_tracker 0.1.2` 등 transitive resolution을 고정한다.
- APK에 Sentry Android/native library가 포함되는 것을 확인했다. 현재 Flutter 3.44.7 build는 성공하지만 `sentry_flutter`의 Kotlin Gradle Plugin 적용 방식이 미래 Flutter built-in Kotlin에서 실패할 수 있다는 warning을 남긴다.
- 새 dangerous runtime permission은 없다. 네트워크 권한은 기존 `INTERNET`이며 package-scoped receiver 보호 권한만 생성된다.
- DB migration, seed, RLS, Edge/API/domain contract 변경은 없다.
- DSN이 설정되면 privacy-filtered error envelope가 Sentry로 전송될 수 있다. 이번 WP는 user/household/content identity를 scope에 설정하지 않는다.

## Automated Validation

| 명령 | 결과 |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test tool` | PASS, 66 files, changed 0 |
| `flutter analyze --fatal-infos --fatal-warnings` | PASS, issue 0 |
| WP01-06 targeted Flutter tests | PASS, 28/28 |
| `flutter test --coverage` | PASS, 59 passed + local connectivity opt-in 1 skipped; 767/862 lines, 88.98% |
| `dart run tool/validate_public_config.dart` | PASS, dev/prod examples valid and exact-allowlisted |
| `dart run tool/scan_secrets.dart` | PASS, high-confidence finding 0 |
| `dart run tool/verify_codegen.dart` | PASS, l10n/build_runner generated drift 0 (5 files) |
| dev/prod debug APK build | PASS |
| staged-index clean offline reproduction | PASS; 아래 재현 결과 참조 |

상세 명령과 핵심 output은 `logs/wp01-06-observability-config.log`에 있다.

## Android Artifacts

빌드 산출물은 `.gitignore` 대상이며 저장소에 커밋하지 않는다. debug universal APK는 release signing이나 Play artifact 크기 검증이 아니다.

| Flavor | package | API | bytes | SHA-256 |
|---|---|---|---:|---|
| dev | `me.newlines.kinflow.dev` | min 24 / target 36 / compile 36 | 184,883,497 | `7404dd0dc2ab71b2cb215bd3dcd974dfeb08be4363ab1d3e88e1a4206a12fb1f` |
| prod | `me.newlines.kinflow` | min 24 / target 36 / compile 36 | 184,883,416 | `607b2bad6b8018e9e337188a640bd14afa46fe23e7419045b27c721af8b8c1d8` |

두 APK 모두 `INTERNET`과 package-scoped `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`만 가진다. dangerous runtime permission 추가는 0이다.

## Clean staged-index reproduction

- 최종 스테이징 index만 새 `/private/tmp/kinflow-wp01-06-final.nlNEUc`에 export했다.
- `flutter pub get --offline`이 성공했고 `pubspec.lock` SHA-256은 원본과 동일한 `1d733753db145eb8e08e9697df31e6e8dc5ac7f4a3b768766f54024af33f3950`였다.
- format은 66 files changed 0, analyzer는 issue 0이었다.
- full Flutter test는 59 passed + opt-in local connectivity 1 skipped, coverage 767/862 lines(88.98%)였다.
- public config validator와 repository secret scan이 통과했고 high-confidence finding은 0이었다.
- l10n/build_runner drift verifier는 5개 generated file의 재생성 전후 byte equality를 확인했다.
- clean dev APK는 package `me.newlines.kinflow.dev`, min/target/compile API 24/36/36, 165,445,321 bytes, SHA-256 `44b3cbf649d03533e79e4a2da5451b97ed0809cae25c037ec4837682ddac00d9`였다. permission audit 결과는 workspace build와 동일했다.

## Manual Validation

- `adb devices -l`은 성공했고 연결 Android device/emulator는 0대였다.
- 실제 Android boot, invalid-config recovery와 lifecycle crash smoke는 **NOT RUN**이다.
- 승인된 dev/prod Sentry project와 DSN이 없어 synthetic event 수신, environment/release tag, server-side scrubber/retention 확인은 **NOT RUN**이다.
- 자동 options/filter/serialization 테스트와 APK metadata/permission audit만 PASS로 기록하며 수동 항목 전에는 remote observability 운영 승인으로 간주하지 않는다.

## Security / Privacy

- public config에는 publishable key와 DSN만 허용하며 provider secret, DB credential, signing credential, Sentry auth token은 server-only 목록으로 거부한다.
- config exception과 scanner finding은 key/rule/path/line 또는 stable code만 출력하고 발견한 value를 출력하지 않는다.
- logger attribute는 exact allowlist이고 nested object, email, token, URL/query, user/household/content field는 전송하지 않는다.
- Sentry screenshot, view hierarchy, request capture, tracing, profiling, replay, user interaction/HTTP/print/native breadcrumb를 비활성화했다.
- 실제 provider 설정 전에는 Sentry organization의 server-side scrubber, retention, region, access role과 incident response를 별도 검토해야 한다.

## Remaining Risks / OPEN Decisions

- 실제 Sentry project/DSN, server-side data scrubbing, retention, alert/dashboard/on-call은 구성되지 않았다.
- native crash envelope가 provider backend에서 최종 저장되는 형태는 실제 dev project smoke 전까지 자동 filter 계약만 검증된 상태다.
- Sentry plugin의 legacy Kotlin Gradle Plugin warning은 현재 build blocker가 아니지만 Flutter upgrade 전에 최신 plugin과 built-in Kotlin 호환성을 재검증해야 한다.
- example Supabase key는 의도적으로 runtime-invalid라 example 그대로 실행하면 safe startup failure를 표시한다. 실제 dev 실행에는 실행 중인 local stack의 publishable key가 필요하다.
- 연결 기기가 없어 lifecycle/ANR/native crash와 offline/reconnect 동작은 검증되지 않았다.

## Rollback

- 이 change를 되돌리면 `c9d92f8`의 WP01-05 상태로 복귀한다.
- observability/config infrastructure, bootstrap/provider wiring, config keys/schema, scanner/validator/tests/docs와 `sentry_flutter` dependency/lock 변경을 함께 제거한다.
- remote Sentry project와 DB/API/data 변경이 없어 remote/data rollback은 없다. DSN을 빈 값으로 배포해도 SDK/network initialization은 비활성화된다.

## Next Entry

- 다음은 Phase 01 WP01-07 CI다.
- format/analyzer/test/codegen/config-validator/secret-scan과 Android build를 CI gate로 연결하고 artifact retention/branch protection 기준을 고정한다.
- remote Sentry와 Android device smoke는 필요한 계정·기기가 준비되면 G1 전에 별도로 닫는다.
