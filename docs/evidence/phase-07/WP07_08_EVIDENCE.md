# Phase 07 WP07-08 PII-safe Diagnostic Report Evidence

## 결과

- 상태: **LOCAL IMPLEMENTED (2026-08-08)** — G7/출시 완료는 아님
- 범위: `FR-SET-007`, `NFR-PRIV-01`, `NFR-OBS-01`, `NFR-SEC-02`, `FR-PLAT-001`, `FR-PLAT-002`
- 구현 수직 조각: settings tile → authenticated diagnostics route → runtime/config app-build validation → exact safe preview → explicit clipboard write → new incident UUID
- report body DB migration/API/network/background upload: 없음. 무작위 incident ID만 기존 PII-filtered observability가 구성된 경우 correlation을 위해 기록될 수 있음
- 실계정·실기기 사용: 없음

## 수용 기준

| 기준 | 결과 |
|---|---|
| PII 없는 app/build/device/environment/incident 정보 | PASS — schema 포함 exact 9-key JSON이며 device는 coarse platform category만 사용 |
| 실제 설치 build 식별 | PASS — package ID/version/build number를 runtime에서 읽고 configured application ID와 `version+build`가 정확히 일치할 때만 생성 |
| invalid metadata fail closed | PASS — package read 실패, invalid value, config mismatch, invalid contract date는 partial payload 없이 stable failure |
| incident correlation | PASS — 매 report마다 lowercase UUID v4를 `Random.secure()`로 생성하고 stable structured event의 `request_id`로만 기록하며 이 가능성을 UI에 고지 |
| report body logging 차단 | PASS — logger에는 capability/operation/result/request_id만 전달하며 JSON body·account·household·content 없음 |
| 명시적 clipboard copy | PASS — 기존 clipboard를 읽지 않고 사용자 action에서 exact pretty JSON만 write; false/exception은 localized failure |
| 중복 실행과 실패 복구 | PASS — generation/copy single-flight; refresh 실패 시 기존 report와 incident ID 보존; copy 실패 재시도 가능 |
| 인증 경계 | PASS — `/settings/diagnostics`는 settings prefix guard로 비로그인 사용자를 sign-in으로 보내며 household 유무와 무관하게 인증 사용자에게 허용 |
| 접근성·국제화 | PASS — EN/KO/EN-XA exact key coverage, pseudo 30% expansion, live status, selectable values, 48dp action, 320×568 200% overflow 0 |

## Exact report contract

clipboard JSON은 다음 순서를 유지한다.

1. `schemaVersion` = `1`
2. `applicationId`
3. `appVersion`
4. `buildNumber`
5. `environment`
6. `contractVersion`
7. `devicePlatform`
8. `incidentId`
9. `generatedAtUtc`

domain test는 key 수·순서·값과 pretty JSON decode 결과를 고정한다. 허용 platform은 `android`, `ios`, `web`, `macos`, `windows`, `linux`, `fuchsia`, `unknown`이며 model/serial/advertising ID가 아니다.

## 구현 파일

- domain/application:
  - `apps/kinflow_app/lib/features/settings/domain/entities/diagnostic_report.dart`
  - `apps/kinflow_app/lib/features/settings/domain/failures/diagnostic_report_failure.dart`
  - `apps/kinflow_app/lib/features/settings/domain/repositories/diagnostic_report_repository.dart`
  - `apps/kinflow_app/lib/features/settings/domain/services/diagnostic_incident_id_generator.dart`
  - `apps/kinflow_app/lib/features/settings/application/diagnostic_report_controller.dart`
  - `apps/kinflow_app/lib/features/settings/application/diagnostic_report_state.dart`
  - `apps/kinflow_app/lib/features/settings/application/ports/diagnostic_app_build_reader.dart`
  - `apps/kinflow_app/lib/features/settings/application/ports/diagnostic_device_platform_reader.dart`
  - `apps/kinflow_app/lib/features/settings/application/ports/diagnostic_incident_recorder.dart`
  - `apps/kinflow_app/lib/features/settings/application/ports/diagnostic_clipboard.dart`
- data/infrastructure:
  - `apps/kinflow_app/lib/features/settings/data/repositories/provider_diagnostic_report_repository.dart`
  - `apps/kinflow_app/lib/features/settings/data/services/secure_diagnostic_incident_id_generator.dart`
  - `apps/kinflow_app/lib/infrastructure/package_info/package_info_diagnostic_app_build_reader.dart`
  - `apps/kinflow_app/lib/infrastructure/platform/flutter_diagnostic_device_platform_reader.dart`
  - `apps/kinflow_app/lib/infrastructure/clipboard/flutter_diagnostic_clipboard.dart`
  - `apps/kinflow_app/lib/infrastructure/observability/app_logger_diagnostic_incident_recorder.dart`
- composition/presentation:
  - `apps/kinflow_app/lib/app/providers/diagnostic_dependencies.dart`
  - `apps/kinflow_app/lib/app/bootstrap.dart`
  - `apps/kinflow_app/lib/app/router/app_router.dart`
  - `apps/kinflow_app/lib/features/settings/presentation/providers/diagnostic_report_providers.dart`
  - `apps/kinflow_app/lib/features/settings/presentation/screens/diagnostic_report_screen.dart`
  - `apps/kinflow_app/lib/features/settings/presentation/screens/settings_screen.dart`
- localization/tests/contracts:
  - `apps/kinflow_app/lib/l10n/app_en.arb`
  - `apps/kinflow_app/lib/l10n/app_ko.arb`
  - `apps/kinflow_app/lib/l10n/app_en_XA.arb`
  - `apps/kinflow_app/test/features/settings/diagnostic_report_domain_test.dart`
  - `apps/kinflow_app/test/features/settings/provider_diagnostic_report_repository_test.dart`
  - `apps/kinflow_app/test/features/settings/diagnostic_report_controller_test.dart`
  - `apps/kinflow_app/test/features/settings/diagnostic_report_widget_test.dart`
  - `apps/kinflow_app/test/infrastructure/diagnostic_infrastructure_test.dart`
  - `docs/contracts/diagnostic-report.yaml.md`

## Dependency review

- `package_info_plus 10.2.1`을 기존 Sentry transitive resolution에서 direct runtime dependency로 승격했다. lock version/hash는 바뀌지 않았다.
- 목적은 실제 설치 package의 `packageName`, `version`, `buildNumber`만 읽어 configured build drift를 감지하는 것이다.
- external `PackageInfo`의 app name, signing hash, installer store, install/update timestamp는 mapper가 소비하거나 domain/report로 전달하지 않는다.
- 로컬 license는 BSD-3-Clause로 확인했고 package Android manifest는 empty이며 새 permission이 없다. SDK 자체 network 호출이나 user/account identity 접근도 구성하지 않는다.
- Android dev flavor는 native `applicationIdSuffix=.dev`, `versionNameSuffix=-dev`이므로 configured `me.newlines.kinflow.dev@0.1.0-dev+1`과 runtime package metadata가 일치한다.
- `device_info_plus`는 device fingerprint surface 때문에 추가하지 않았다. 공개 `APP_VERSION`만 표시하는 대안은 설치 artifact drift를 감지하지 못하므로 채택하지 않았다.

## 자동 검증 결과

| 영역 | 명령/검사 | 결과 |
|---|---|---|
| Focused Flutter | domain/repository/controller/widget/infrastructure/architecture | PASS, 36 tests |
| Localization focused | ARB contract + diagnostic widget | PASS, 10 tests |
| Flutter full | `flutter test --no-pub --reporter failures-only` | PASS, 807 tests + opt-in live 1 skip |
| Analyzer | `flutter analyze --no-pub --fatal-infos --fatal-warnings` | PASS, issue 0 |
| Format | `dart format --output=none --set-exit-if-changed lib test tool` | PASS, 512 files / drift 0 |
| Codegen | `dart run tool/verify_codegen.dart` | PASS, 8 generated files / drift 0 |
| Public config | `dart run tool/validate_public_config.dart` | PASS, examples valid/allowlisted |
| Secret scan | `dart run tool/scan_secrets.dart` | PASS, high-confidence finding 0 |
| Contract parse | fenced `diagnostic-report.yaml` exact field/security assertions | PASS, 9 exact fields |
| Matrix parse | fenced CSV matrix 13개 declared-row/column 검사 | PASS, requirements 116×18 / tests 65×11 |
| Dependency/permission | cached license와 plugin Android manifest 검사 | PASS, BSD-3-Clause / permission 0 |
| Whitespace | `git diff --check` | PASS |

첫 full regression은 새 `diagnosticsExcludedBody`, 이후 focused localization은 `diagnosticsInvalidMetadata`와 `diagnosticsClipboardNotice`의 EN-XA가 영어 원문 대비 30% 확장 기준에 부족해 실패했다. 세 pseudo message를 충분히 확장한 뒤 localization/widget 10개와 full 807개를 재실행해 통과했다. 최초 codegen 검사는 병렬 Dart validator가 같은 `.dart_tool` native hook dylib를 동시에 갱신해 충돌했으며, 다른 프로세스 종료 후 단독 재실행해 generated drift 0을 확인했다. 이는 제품 코드 실패로 계산하지 않는다.

## 보안·개인정보 검토

- report allowlist는 compile-time map의 exact 9개 key이고 arbitrary map, provider JSON, user input 또는 localized label을 serialize하지 않는다.
- account/user/household/member ID, email/name/profile, chore/calendar/notification/billing content, token/URL/query, IP/network, locale/timezone, model/name/serial/advertising ID, signing hash와 installer metadata가 report에 없다.
- package adapter 외에 `package_info_plus` import가 없도록 architecture test를 추가했다. feature domain/application은 Flutter/Riverpod/provider SDK를 import하지 않는다.
- clipboard adapter에는 `Clipboard.setData`만 있고 read API 호출이 없다. copy는 explicit tap 전에는 수행되지 않으며 support URL에 자동 첨부하지 않는다.
- incident UUID는 user/account ID가 아니고 영구 저장하지 않는다. logger failure는 generation을 중단하지 않고 report body는 logger/Sentry로 전달하지 않는다.
- invalid metadata와 provider exception detail은 UI/state/log에 반사하지 않으며 partial report도 만들지 않는다.
- report body의 DB/API/network transport가 없고 server secret이나 새 public config key를 추가하지 않았다. incident UUID의 기존 filtered observability 기록 가능성은 사용자 안내와 contract에 분리했다.

## 수동·실환경 검증

다음은 **NOT RUN**이다.

- signed dev/prod APK/AAB에서 실제 package ID/version/build와 configured values 일치 확인
- Android/iOS system clipboard privacy UI, clipboard manager·keyboard history, paste와 manual clear
- TalkBack/VoiceOver live-region announcement, system font 200%, keyboard, tablet/split-screen
- 승인된 remote Sentry에서 incident UUID event 수신·retention·access와 support ticket correlation
- 실제 지원 담당자의 runbook, incident ID 검색 권한과 report paste 처리 절차

로컬 package fixture, fake clipboard/logger와 widget automation 통과를 signed artifact·OS clipboard·remote observability 완료로 해석하지 않는다.

## 남은 위험과 OPEN 항목

- signed artifact versioning이 config와 어긋나면 화면은 의도적으로 unavailable이 된다. build pipeline에서 dev/prod artifact metadata smoke를 마지막 Gate에 추가해야 한다.
- OS와 keyboard clipboard history 보관 시간은 앱이 통제하지 못한다. 기존 clipboard를 읽지 않기 때문에 자동 restore/clear도 하지 않으며 사용자 안내와 실기기 검증이 남는다.
- remote Sentry에 incident UUID가 저장될 경우 retention, region, support access role과 삭제 절차를 운영 승인해야 한다.
- coarse platform도 다른 build metadata와 결합하면 낮은 수준의 fingerprint 요소가 될 수 있어 더 상세한 model/OS version/locale/timezone은 계속 금지한다.
- schema field 변경은 contract versioning과 privacy review가 필요하며 arbitrary debug dump 추가를 허용하지 않는다.

## Rollback

- `AppRoutes.diagnostics`, settings tile, screen/providers/controller/domain/data/infrastructure files와 bootstrap overrides를 함께 제거하면 기존 settings 기능은 유지된다.
- `package_info_plus` direct dependency를 제거하면 Sentry가 사용하는 transitive dependency 상태로 돌아가며 lock resolution version은 유지된다.
- unavailable repository/clipboard fallback으로 바꾸면 route가 partial report를 만들지 않고 fail closed한다.
- DB/API/network/persisted local state가 없어 data rollback은 없다.

## 다음 단계

- 기능 우선순위에 따라 다음 로컬 vertical slice를 계속 구현한다.
- 실계정·signed artifact·remote provider·실기기 검증은 사용자 요청대로 마지막 통합 Gate에 유지한다.
