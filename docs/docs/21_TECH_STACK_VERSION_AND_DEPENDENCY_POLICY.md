# 21. 기술 스택, 버전, 의존성 정책

- 상태: ACCEPTED
- 기준일: 2026-07-21

## 1. Toolchain baseline

| 항목 | 기준 |
|---|---|
| Flutter SDK | 3.44.7 stable exact |
| Dart | Flutter에 포함된 3.12 계열 |
| iOS build | Xcode 26, current App Store SDK requirement 재검증 |
| Android | min API 24, target API 36, current Play deadline 재검증 |
| Java | Flutter/Android Gradle Plugin 호환 LTS |
| CocoaPods | locked CI bootstrap version 또는 Bundler policy |
| Supabase CLI | repository에서 고정 |
| GitHub Actions | commit SHA pin 또는 승인된 major |

`contracts/toolchain.json`이 기계 판독 기준이다.

## 2. Flutter package baseline

| 범주 | 선택 | 역할 |
|---|---|---|
| State/DI | `flutter_riverpod`, `riverpod_annotation` | 상태 소유권과 dependency injection |
| Routing | `go_router` | declarative routes/deep links |
| Models | `freezed_annotation`, `json_annotation` | immutable DTO/state |
| Codegen | `build_runner`, `freezed`, `json_serializable`, `riverpod_generator` | 생성 코드 |
| Backend | `supabase_flutter` | Auth/PostgREST/Realtime/Storage |
| Billing | `purchases_flutter` | App Store/Play purchase |
| Push | `firebase_core`, `firebase_messaging` | FCM/APNs bridge |
| Local notification | `flutter_local_notifications` | foreground/local presentation |
| Secure storage | `flutter_secure_storage` | token/secret |
| Connectivity | platform-approved connectivity package | UX hint; truth source 아님 |
| Error | `sentry_flutter` | crash/error |
| Localization | Flutter `gen_l10n`, `intl` | ARB/i18n |
| Testing | `flutter_test`, `integration_test`, `mocktail` | automated tests |

패키지 정확한 patch 버전은 Phase 01에서 Flutter SDK 3.44.7과 공식 호환성을 확인한 뒤 `pubspec.yaml`과 `pubspec.lock`에 고정한다.

## 3. Dependency 추가 Gate

PR 설명에 다음을 포함한다.

- 해결하는 문제와 사용 범위
- 표준 SDK로 해결하지 못하는 이유
- iOS/Android/Web/Desktop support
- 최근 유지보수와 issue 상태
- license와 transitive dependency
- binary size/native permission 영향
- 대체/제거 전략
- testability와 mocking 방법

단일 convenience 함수 때문에 큰 package를 추가하지 않는다.

## 4. Version 정책

- toolchain exact pin
- runtime package는 compatible range + lockfile
- production build는 lockfile 변경 금지
- bot 자동 upgrade는 PR과 CI를 통과해야 함
- major upgrade는 별도 ADR와 migration branch
- Flutter stable upgrade는 RC 중 수행하지 않음
- security advisory는 예외 expedited path

## 5. Generated code

- 생성 파일 commit
- 생성 파일 직접 편집 금지
- CI에서 codegen 후 diff 0
- generator version lock
- DTO 변경 시 mapper/domain/contract test 동시 수정

## 6. Platform plugin 정책

- 최소 지원 OS에서 실제 검증
- 권한/Info.plist/Manifest 변경 문서화
- background handler의 isolate/entry-point 요구 검증
- web/desktop unsupported일 때 compile-safe fallback
- plugin이 abandoned되면 adapter 뒤에서 교체 가능

## 7. Dependency 보안

- dependency audit와 license inventory
- GitHub Action SHA pinning 권장
- signing/build secret을 package script에 노출 금지
- package post-install/code generation 검토
- unknown binary download 금지
- SBOM을 RC artifact에 포함

## 8. Public website

별도 `apps/public_site`는 Astro + TypeScript를 권장한다. Flutter app dependency와 release cadence를 분리하고, 법률·지원 페이지가 JavaScript 없이도 읽히도록 정적 출력한다.

## 9. 업그레이드 절차

1. release notes/security advisory 검토
2. compatibility branch
3. codegen/format/analyze/unit/DB test
4. iOS/Android build와 실제 기기 smoke
5. billing/push/deep link regression
6. Web 영향 시 browser matrix
7. binary size/startup 비교
8. ADR/changelog/toolchain update
