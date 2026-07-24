# KinFlow

KinFlow는 성인 2인이 가구를 만들고 집안일을 나누어 완료하는 Android-first 가족 협업 앱이다.

현재 구현 범위는 Phase 01 WP01-06 Observability/config까지의 로컬 foundation이다. G0 연구·법률 Gate 전체 통과나 production provider 연결을 의미하지 않는다.

## Accepted baseline

- Flutter SDK 3.44.7 / Dart SDK 3.12.2 exact pin
- Android Store MVP only
- production: `me.newlines.kinflow`
- dev: `me.newlines.kinflow.dev`
- dev/prod two environments
- Riverpod/go_router App Shell with safe startup recovery
- domain/application/data/presentation feature boundary with repository port/adapter DI
- Freezed/json_serializable DTO generation and drift verification
- Material 3 design token과 available-width 기반 compact/medium/expanded shell
- English/Korean Flutter gen_l10n과 test-only `en_XA` pseudo locale
- 48dp touch target, semantics, reduced-motion, RTL mirror, 200% text-scale smoke
- adult two-person activation slice
- exact allowlist 기반 공개 client config loader/validator
- PII-safe structured logger와 optional Sentry error boundary
- repository high-confidence secret scanner
- project-scoped Supabase CLI와 local PostgreSQL/RLS/Edge Function baseline
- 성인 2인 seed와 별도 household를 이용한 cross-household 격리 검증
- Flutter Supabase infrastructure adapter와 local health connectivity test
- Google 로그인은 후속 Work Package로 연기

자세한 변경 근거는 `docs/adr/ADR-0002-android-first-release.md`를 따른다.

## Bootstrap

FVM을 사용하는 경우:

```bash
fvm install
fvm flutter --version
cd apps/kinflow_app
fvm flutter pub get
```

직접 설치한 SDK를 사용하는 경우 `KINFLOW_FLUTTER_BIN`에 Flutter 3.44.7 실행 파일을 지정한다.

```bash
export KINFLOW_FLUTTER_BIN=/absolute/path/to/flutter-3.44.7/bin/flutter
"$KINFLOW_FLUTTER_BIN" --version
cd apps/kinflow_app
"$KINFLOW_FLUTTER_BIN" pub get
```

버전 출력은 Flutter 3.44.7과 Dart 3.12.2여야 한다.

로컬 Supabase foundation을 실행하는 경우 Docker가 필요하다.

```bash
npm ci
npx supabase start
npm run supabase:reset
npm run supabase:test
npm run supabase:health
npm run supabase:flutter-health
```

마지막 명령은 `flutter`가 PATH에 있어야 한다. 다른 위치의 SDK는 `KINFLOW_FLUTTER_BIN=/absolute/path/to/flutter`로 지정할 수 있다. 로컬 publishable key는 실행 중인 stack에서 읽고 출력하거나 파일에 저장하지 않는다.

## Verify

```bash
cd apps/kinflow_app
fvm dart format --output=none --set-exit-if-changed lib test tool
fvm flutter analyze --fatal-infos --fatal-warnings
fvm flutter test
fvm dart run tool/verify_codegen.dart
fvm dart run tool/validate_public_config.dart
fvm dart run tool/scan_secrets.dart
fvm flutter build apk --debug --flavor dev --target lib/main_dev.dart --dart-define-from-file=config/dev.example.json
fvm flutter build apk --debug --flavor prod --target lib/main_prod.dart --dart-define-from-file=config/prod.example.json
```

예제 config는 공개 client 값만 정의한다. placeholder Supabase publishable key는 정적 예제 검증에는 허용되지만 runtime에서는 fail-closed 한다. `SENTRY_DSN`이 비어 있으면 Sentry SDK와 네트워크 전송은 시작하지 않는다.

실제 환경 파일, OAuth client secret, Supabase service role key, Sentry auth token, signing key는 커밋하지 않는다.
