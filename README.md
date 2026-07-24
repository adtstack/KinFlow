# KinFlow

KinFlow는 성인 2인이 가구를 만들고 집안일을 나누어 완료하는 Android-first 가족 협업 앱이다.

현재 구현 범위는 Phase 01 WP01-02 App Shell까지의 로컬 foundation이다. G0 연구·법률 Gate 전체 통과나 production provider 연결을 의미하지 않는다.

## Accepted baseline

- Flutter SDK 3.44.7 / Dart SDK 3.12.2 exact pin
- Android Store MVP only
- production: `me.newlines.kinflow`
- dev: `me.newlines.kinflow.dev`
- dev/prod two environments
- Riverpod/go_router App Shell with safe startup recovery
- English/Korean Flutter gen_l10n skeleton
- adult two-person activation slice
- Google login through Supabase Auth in Phase 02

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

## Verify

```bash
cd apps/kinflow_app
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze --fatal-infos --fatal-warnings
fvm flutter test
fvm flutter build apk --debug --flavor dev --target lib/main_dev.dart --dart-define-from-file=config/dev.example.json
fvm flutter build apk --debug --flavor prod --target lib/main_prod.dart --dart-define-from-file=config/prod.example.json
```

실제 환경 파일, OAuth client secret, Supabase service role key, signing key는 커밋하지 않는다.
