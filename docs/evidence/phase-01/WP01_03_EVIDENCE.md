# Phase 01 WP01-03 Evidence

- Work Package: WP01-03 Architecture Boundary
- 기준 commit: base `bd1f535`; WP01-03 change
- 검증일: 2026-07-24
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Android SDK/compile/target 36
- 결과: **LOCAL AUTOMATED PASS / DEVICE BOOT PENDING**
- 범위 제한: 실제 가구·인증 기능, 외부 provider 연결, Phase 01 전체 Gate 통과가 아님

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP01-03 four-layer sample slice | PASS | `lib/features/foundation/{domain,application,data,presentation}` |
| WP01-03 Riverpod override/DI | PASS | app composition override와 failure→retry widget test |
| WP01-03 repository port/fake adapter | PASS | domain port, fixture adapter, test fake, delegation tests |
| WP01-03 architecture import test | PASS | current tree 검사와 synthetic forbidden-import negative test |
| D-006 Riverpod boundary | PASS | Provider는 use case 조립과 presentation async state만 소유 |
| D-007 generated DTO | PASS | Freezed/json_serializable DTO와 committed generated source |
| D-047 pure domain/application | PASS | Flutter/Riverpod/provider SDK forbidden import 0 |
| FR-FLT-005 generated drift | PASS | byte snapshot 기반 generator rerun, drift 0 |
| SPEC-002 repository/layer boundary | PASS | machine-readable contract와 automated dependency direction 검사 |

## Implementation

- `FoundationSampleId`, entity, stable failure/result와 `FoundationRepository` port는 pure Dart domain에 있다.
- `LoadFoundationStatus` application use case는 repository port만 호출한다.
- data layer는 개인정보가 없는 local fixture를 generated DTO로 parse하고 mapper로 domain entity를 만든다.
- app composition root가 fixture adapter를 Riverpod repository provider에 override한다.
- presentation은 repository DTO를 알지 못하며 loading/ready/generic failure/retry 상태만 표시한다.
- test fake가 repository port를 구현하고 provider override로 failure→success 순서를 주입한다.
- `contracts/architecture-rules.yaml`을 materialize하고 feature layer import test가 직접 검증한다.
- `tool/verify_codegen.dart`는 생성 전후 `.g.dart`/`.freezed.dart` byte를 비교한다.

## Dependency Review

| Dependency | Locked version | License | Native permission/network/PII |
|---|---:|---|---|
| freezed_annotation | 3.1.0 | MIT | 없음 |
| json_annotation | 4.12.0 | BSD-3-Clause | 없음 |
| build_runner | 2.15.1 | BSD-3-Clause | dev only, 앱 runtime 영향 없음 |
| freezed | 3.2.5 | MIT | dev only, 앱 runtime 영향 없음 |
| json_serializable | 6.14.0 | BSD-3-Clause | dev only, 앱 runtime 영향 없음 |

수기 immutable DTO/parser는 D-007과 generated drift 계약을 충족하지 못해 채택하지 않았다. resolver가 처음 선택한 Freezed prerelease는 사용하지 않고 공식 stable 3.2.5를 exact pin했다. package는 모두 Dart source/codegen이며 native plugin·permission·network·PII 처리가 없다.

`build_runner 2.15.1`은 기존 `--delete-conflicting-outputs` option을 제거했으므로 verifier는 `build`를 실행하고 생성 전후 byte snapshot을 직접 비교한다.

## Automated Validation

| 명령 | 결과 |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test tool` | PASS |
| `flutter analyze --fatal-infos --fatal-warnings` | PASS, issue 0 |
| `flutter test --coverage` | PASS, 18/18; line 243/266, 91.4% |
| `dart run tool/verify_codegen.dart` | PASS, generated 2 files, byte drift 0 |
| architecture dependency/import tests | PASS, forbidden import 0; detector negative fixture PASS |
| dev `flutter build apk --debug --flavor dev ...` | PASS |
| prod `flutter build apk --debug --flavor prod ...` | PASS |
| `aapt dump badging` dev/prod | PASS, identifiers and API contract preserved |
| staged-index clean restore/codegen/analyze/test/build | PASS, offline restore + byte-identical generation + issue 0 + 18/18 + dev APK |
| `adb devices -l` | PASS command / connected device 0 |

상세 로그는 `logs/wp01-03-architecture-boundary.log`에 있다.

## Artifacts

빌드 산출물은 `.gitignore` 대상이며 저장소에 커밋하지 않는다.

| Flavor | package | bytes | SHA-256 |
|---|---|---:|---|
| dev | `me.newlines.kinflow.dev` | 165,234,113 | `15b5e6f5a5838eb06bbe318bbd29f0bad83ca18237d17272514d9781a7287d55` |
| prod | `me.newlines.kinflow` | 165,234,179 | `e0a342f3707d9aa9ed3873ebe85428922619c4b138cee3978fb4bcd6912b66f8` |

두 APK 모두 min API 24, target/compile API 36이다. debug APK는 release signing이나 Play artifact 검증이 아니다.

### Clean staged-index reproduction

- 스테이징된 index만 새 `/private/tmp` 디렉터리에 export했다.
- `flutter pub get --offline`, `flutter gen-l10n`, codegen verifier, analyzer, 전체 test, dev APK build를 순서대로 실행해 모두 PASS했다.
- 재생성된 Freezed/JSON 2개와 localization 3개 파일, `pubspec.lock`은 작업 트리 파일과 byte-identical이다.
- clean dev APK는 package `me.newlines.kinflow.dev`, 150,747,190 bytes, SHA-256 `862fce985e74c1c8b7400384e0d7bf30234ff49101b8f80bb6d75617085c4d82`다.

## Data / Security / Privacy

- DB migration, API, RLS, Edge Function 변경 없음
- Google/Supabase/Firebase/RevenueCat/Sentry SDK·project·secret 없음
- local fixture는 `sample_id`와 readiness status만 포함하며 사용자·가구·계정 정보 없음
- lower layer failure와 unexpected exception detail은 사용자 UI에 노출하지 않음
- DTO는 data layer 밖으로 노출되지 않음
- dependency 추가로 native Android permission 변화 없음

## Manual Validation

- 검증 시점 `adb devices -l`의 연결 기기는 0대였다.
- 실제 Android에서 foundation loading/ready/failure/retry를 확인하는 수동 boot smoke는 NOT RUN이다.
- 기존 dev/prod 식별자와 API level은 APK metadata로 자동 검증했다.

## Remaining Risks / Next Entry

- foundation local fixture는 architecture 검증용이며 제품 기능이나 offline cache가 아니다.
- import test는 Dart import 방향을 검사하지만 runtime authorization을 보장하지 않는다.
- production provider, RLS, session purge는 후속 Work Package에서 별도 검증해야 한다.
- 다음 Work Package는 WP01-04 Supabase Local이다. Google 로그인 없이 local CLI/config, baseline migration/default-deny RLS와 health contract부터 진행한다.

## Rollback

- 이 change를 되돌리면 `bd1f535`의 WP01-02 App Shell로 복귀한다.
- `features/foundation`, architecture contract/test/tool, generated DTO, 새 dependency를 함께 제거한다.
- router/home을 기존 정적 foundation screen으로 복원하고 bootstrap의 repository override를 제거한다.
- DB/provider/사용자 데이터가 없어 data rollback은 없다.
