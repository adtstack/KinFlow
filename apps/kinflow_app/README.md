# KinFlow Android app

Phase 01 WP01-01 foundation. Flutter SDK 3.44.7/Dart 3.12.2로만 실행한다.

## Environments

| Flavor | Entrypoint | applicationId | Config example |
|---|---|---|---|
| dev | `lib/main_dev.dart` | `me.newlines.kinflow.dev` | `config/dev.example.json` |
| prod | `lib/main_prod.dart` | `me.newlines.kinflow` | `config/prod.example.json` |

별도 staging은 운영하지 않는다. Play internal/closed track의 release candidate는 prod application ID를 사용한다.

## Commands

```bash
flutter pub get
flutter analyze --fatal-infos --fatal-warnings
flutter test
flutter build apk --debug --flavor dev --target lib/main_dev.dart --dart-define-from-file=config/dev.example.json
flutter build apk --debug --flavor prod --target lib/main_prod.dart --dart-define-from-file=config/prod.example.json
```

현재 shell은 의도적으로 기능과 provider가 없다. Google/Supabase 로그인은 Phase 02에서 adapter 경계와 세션 제거 테스트를 포함해 구현한다. release signing에 debug key를 사용하지 않으며 실제 signing 설정은 저장소 밖에서 공급한다.
