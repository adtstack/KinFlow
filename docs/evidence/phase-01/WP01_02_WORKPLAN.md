# Phase 01 WP01-02 Work Plan

- 작성일: 2026-07-24
- 기준 commit: `51aac4f`
- Work Package: WP01-02 App Shell
- 상태: COMPLETE

## Requirements

| ID | 구현 범위 |
|---|---|
| WP01-02 | dev/prod entrypoint, bootstrap, MaterialApp.router, loading/fatal recovery, environment banner, theme/locale skeleton |
| D-001 | Flutter SDK 3.44.7 / Dart 3.12.2 유지 |
| D-006 | Riverpod dependency assembly와 go_router 사용 |
| D-032 | dev/prod 환경 시각 분리, prod debug surface 미노출 |
| D-036 | 영어·한국어 ARB 기반 locale skeleton |
| D-047 | 이 WP에는 domain을 만들지 않으며 Flutter/Riverpod 결합을 app/presentation에 제한 |

## Data / API Impact

- DB migration: 없음
- RLS/API/RPC/Edge Function: 없음
- Supabase/Firebase/RevenueCat/Google provider 초기화: 없음
- 실제 계정, 사용자 데이터, secret: 없음

## Runtime Dependencies

| Dependency | Version/license | 목적 | 대안 | 플랫폼/권한/개인정보 | Rollback |
|---|---|---|---|---|---|
| `flutter_riverpod` | 3.3.2 / MIT | environment와 bootstrap dependency 조립/override | 직접 InheritedWidget | Dart/Flutter 전용, native permission·network·PII 없음 | ProviderScope와 provider 제거 |
| `go_router` | 17.3.0 / BSD-3-Clause | Router API, deep-link 확장 가능한 route shell | Navigator 2.0 직접 구현 | Dart/Flutter 전용, native permission·network·PII 없음 | MaterialApp routes/Navigator로 교체 |
| `flutter_localizations` | Flutter SDK / BSD-3-Clause | Flutter 공식 locale delegate | 직접 delegate 구현 | Flutter SDK, native permission·network·PII 없음 | 단일 locale로 축소 |
| `intl` | 0.20.2 / BSD-3-Clause | gen_l10n locale/format 기반 | 직접 문자열/format 구현 금지 | Dart 전용, native permission·network·PII 없음 | gen_l10n 호환 버전으로 재고정 |

버전은 Flutter SDK 3.44.7에서 `flutter pub add`로 해석하고 `pubspec.lock`에 고정했다. `flutter_localizations`가 고정하는 `intl 0.20.2`를 SDK 호환 기준으로 사용한다. major 업그레이드는 이 Work Package 범위가 아니다.

## Planned Tests

1. dev/prod environment provider와 custom banner 노출 분리
2. bootstrap pending 상태의 localized loading UI
3. bootstrap failure에서 raw exception 미노출, retry 후 복구
4. 영어·한국어 locale delegate와 ARB 문자열
5. go_router home/not-found route
6. analyzer warning 0, unit/widget test, dev/prod APK build
7. staged-index clean bootstrap 검증

## Non-scope

- Google/Supabase 로그인
- household/chore domain과 repository
- pseudo locale, responsive breakpoint, 200% text-scale 정식 Gate
- Sentry/logger/config validator
- production signing/Play upload

## Rollback

- 새 dependency와 `lib/app` shell, ARB/generated localization, 관련 테스트를 제거하면 WP01-01 blank foundation으로 돌아간다.
- DB/API/provider/사용자 데이터가 없어 data rollback은 없다.
- startup failure가 발생하면 기존 `51aac4f` APK로 되돌릴 수 있다.
