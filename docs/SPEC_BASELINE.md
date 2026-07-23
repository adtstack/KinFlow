# KinFlow 앱 구현 스펙 기준선 v1.0 — Flutter SDK 3.44.7

> **버전 주의:** 이 문서의 `v1.0`은 KinFlow 앱 스펙 버전이다. Flutter 프레임워크 기준선은 `Flutter SDK 3.44.7 stable`, 포함 Dart는 `Dart SDK 3.12.2`다. 자세한 규칙은 `VERSIONING_CONVENTIONS.md`를 따른다.


> **Markdown 전용판 안내:** 비-Markdown 원본 계약과 검증표는 `<원본명>.md`의 코드 블록에 있습니다. 실제 구현 전에 `MD_ONLY_FORMAT_GUIDE.md`에 따라 원본 파일로 추출하고 검증합니다.


- 상태: `ACCEPTED — IMPLEMENTATION BASELINE`
- 기준일: 2026-07-21
- 변경 방식: ADR + 영향 분석 + 회귀 검증 계획

## 1. 기준선 우선순위

1. `DECISIONS.md`의 ACCEPTED 결정
2. 이 문서
3. `contracts/`의 기계 판독 계약
4. `docs/20_*`~`docs/30_*` 구현 스펙
5. 제품·도메인 문서
6. Phase 계획

OPEN 결정은 구현자가 임의로 확정하지 않는다. 해당 기능은 안전한 기본값, feature flag 또는 미구현 adapter로 남긴다.

## 2. 확정 기술 기준

| 영역 | 기준 |
|---|---|
| Flutter SDK | 3.44.7 stable exact pin |
| Dart SDK | Flutter SDK 3.44.7에 포함된 Dart SDK 3.12.2, 독립 업그레이드 금지 |
| 앱 언어 | Dart sound null safety |
| 모바일 | iOS/iPadOS 16.0+, Android API 24+, target API 36 |
| Web Companion | Chrome/Edge/Firefox 최신 2개 major, Safari 16.4+ |
| 상태·DI | Riverpod 3 stable 계열 |
| 라우팅 | go_router stable 계열 |
| 모델·직렬화 | Freezed + json_serializable |
| 백엔드 | Supabase Auth, PostgreSQL, RLS, Edge Functions |
| 서버 함수 언어 | TypeScript/Deno |
| 구독 | RevenueCat Flutter SDK + 서버 household entitlement |
| 원격 알림 | Firebase Cloud Messaging, APNs 연동 |
| 로컬 알림 | flutter_local_notifications |
| 오류 추적 | Sentry Flutter |
| 배포 | GitHub Actions + Fastlane; Web immutable deployment |
| 테스트 | flutter_test, integration_test, Maestro, Playwright, pgTAP |

패키지 patch 버전은 Phase 01에서 최신 안정 호환성을 검증한 뒤 `pubspec.lock`으로 exact 고정한다. Flutter SDK만 독립적으로 자동 업그레이드하지 않는다.

## 3. 플랫폼 전략

### Tier 1: Store MVP

- iPhone 및 iPad
- Android phone 및 tablet
- 성인 가구 생성·초대·집안일·일정·Today·알림·구독·삭제 지원
- Managed Child와 child mode는 P1 계약으로 보존하되 Store MVP에는 구현·노출하지 않음(D-013)

### Tier 2: Web Companion

- 모바일 Store MVP 이후 독립 Beta
- PC에서 Today, 집안일, 일정, 가족 관리
- 설치형 Web Companion를 핵심 KPI로 두지 않음
- 광범위한 offline cache와 Web Push는 별도 Gate

### Deferred: Native desktop

Flutter가 Windows/macOS/Linux를 지원하더라도 첫 출시 범위가 아니다. 월간 데스크톱 사용량, OS 알림, 오프라인, 메뉴바·트레이·키오스크 수요를 측정한 뒤 Phase 10 Gate에서 결정한다.

## 4. 저장소 구조

```text
/
├─ apps/
│  ├─ kinflow_app/              # Flutter: ios/android/web 우선
│  └─ public_site/              # Astro: marketing/legal/delete/support
├─ supabase/
│  ├─ migrations/
│  ├─ functions/
│  ├─ tests/
│  └─ seed.sql
├─ contracts/
├─ docs/
├─ phases/
├─ e2e/
│  ├─ maestro/
│  └─ playwright/
├─ scripts/
└─ evidence/
```

초기 Flutter 앱 내부:

```text
lib/
├─ app/                         # bootstrap, router, theme, localization
├─ core/                        # 공통 error, result, clock, IDs, platform ports
├─ features/
│  └─ <feature>/
│     ├─ domain/
│     ├─ application/
│     ├─ data/
│     └─ presentation/
└─ main_{dev,staging,prod}.dart
```

## 5. 비협상 아키텍처 규칙

1. domain은 Flutter, Riverpod, Supabase, RevenueCat, Firebase를 import하지 않는다.
2. Widget과 Provider는 공급자 SDK를 직접 호출하지 않는다.
3. Riverpod Notifier는 도메인 규칙 저장소가 아니라 use case 조정자다.
4. 외부 JSON은 Freezed/json_serializable DTO로 파싱하고 domain entity로 변환한다.
5. 모든 가구 소유 row는 `household_id`, RLS, 교차 가구 제약을 가진다.
6. 초대 수락·Owner 이전·역할·Managed Child acting·삭제·구독은 RPC/Edge transaction이다.
7. 서버가 membership, role, acting context, entitlement를 재계산한다.
8. 날짜는 UTC instant, local date/time, IANA timezone을 구분한다.
9. 반복 occurrence는 서버가 materialize하며 클라이언트 계산은 preview다.
10. 푸시 알림은 서버 작업 큐가 권위자이며 기기 예약은 보조다.
11. 기능 권한은 RevenueCat client snapshot이 아니라 서버 household entitlement가 최종 근거다.
12. 비밀은 앱 bundle, `--dart-define`, 로그, 분석 이벤트에 포함하지 않는다.
13. 로그아웃·가구 변경·구성원 제거 시 사용자 범위 cache와 provider identity를 제거한다.
14. DB migration은 forward-only expand/contract다.
15. 런타임 코드 패치 도구는 MVP baseline이 아니다.

## 6. Capability ports

- AuthSessionPort
- NotificationPort
- BillingPort
- EntitlementPort
- SecureStoragePort
- DeepLinkPort
- AnalyticsPort
- ErrorReporterPort
- ConnectivityHintPort
- LocalCachePort
- AppVersionPort
- ParentalGatePort

미지원 기능은 성공 no-op이 아니라 `unsupported(reason, fallback)` 결과를 반환한다.

## 7. Flutter 코드 규칙

- `dart format` 결과를 커밋한다.
- analyzer warning 0, `implicit-casts: false`, `strict-casts: true`에 준하는 엄격도.
- `dynamic`과 `!` 사용은 경계 검증 직후 외에는 금지.
- `BuildContext`를 async gap 너머로 보관하지 않는다.
- Widget에 비즈니스 mutation을 작성하지 않는다.
- generated `.g.dart`, `.freezed.dart`는 커밋하고 CI에서 재생성 drift를 검사한다.
- 화면 문자열·날짜 형식·plural은 ARB/gen_l10n을 사용한다.
- 테스트에서 실제 시간·UUID·네트워크를 직접 사용하지 않는다.

## 8. 필수 PR 검증

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
flutter test integration_test -d <configured-device>
dart run build_runner build --delete-conflicting-outputs
supabase db reset
supabase test db
flutter build appbundle --flavor staging
flutter build web --release --dart-define-from-file=config/staging.json
```

모든 PR에서 iOS archive를 만들 필요는 없지만 RC에서는 macOS runner에서 `flutter build ipa`가 필수다.

## 9. 출시 Gate

- G0 Decision Gate
- G1 Foundation Gate
- G2 Household Alpha
- G3 Chores Value
- G4 Calendar Value
- G5 Reliability Gate
- G6 Billing Gate
- G7 Compliance Gate
- G8 Beta Exit / Mobile RC
- G9 Mobile Store Launch
- G10 Web Companion Beta
- G11 Native Desktop Review
