# KinFlow Android app

Phase 01 WP01-03 Architecture Boundary foundation. Flutter SDK 3.44.7/Dart 3.12.2로만 실행한다.

현재 포함 범위:

- Riverpod 기반 environment/bootstrap dependency 조립
- go_router 기반 home/not-found shell
- 초기화 loading/fatal recovery/retry
- dev 전용 environment banner
- Material 3 light/dark theme skeleton
- Flutter gen_l10n 영어·한국어 ARB
- `features/foundation` domain/application/data/presentation sample slice
- repository port와 app composition의 Riverpod override/DI
- Freezed/json_serializable DTO, architecture import test, codegen drift verifier

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
dart run tool/verify_codegen.dart
flutter build apk --debug --flavor dev --target lib/main_dev.dart --dart-define-from-file=config/dev.example.json
flutter build apk --debug --flavor prod --target lib/main_prod.dart --dart-define-from-file=config/prod.example.json
```

현재 foundation sample은 실제 가구·인증 기능이 아닌 architecture 검증용 local fixture다. 외부 SDK나 개인정보를 사용하지 않는다. Google/Supabase 로그인은 별도 후속 Work Package에서 adapter 경계와 세션 제거 테스트를 포함해 구현한다. release signing에 debug key를 사용하지 않으며 실제 signing 설정은 저장소 밖에서 공급한다.
