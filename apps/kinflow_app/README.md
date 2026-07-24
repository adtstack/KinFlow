# KinFlow Android app

Phase 01 WP01-05 Design/i18n/a11y foundation. Flutter SDK 3.44.7/Dart 3.12.2로만 실행한다.

현재 포함 범위:

- Riverpod 기반 environment/bootstrap dependency 조립
- go_router 기반 home/not-found shell
- 초기화 loading/fatal recovery/retry
- dev 전용 environment banner
- Material 3 light/dark theme와 color/spacing/radius/elevation/touch/motion token
- available width 기반 compact(`<600`)/medium(`600..<840`)/expanded(`>=840`) shell
- Flutter gen_l10n 영어·한국어 ARB와 test-only `en_XA` 30% expansion pseudo locale
- heading/navigation/action semantics, 48dp touch target, reduced-motion와 200% text-scale smoke
- 지원 locale과 별개로 강제 RTL Directionality mirror test
- `features/foundation` domain/application/data/presentation sample slice
- repository port와 app composition의 Riverpod override/DI
- Freezed/json_serializable DTO, architecture import test, codegen drift verifier
- `infrastructure/supabase`의 SDK 격리 adapter와 exact health response mapper
- local Supabase를 실제 호출하는 opt-in Flutter connectivity test

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

전체 테스트에서 connectivity test는 local URL/key가 없으면 skip된다. 저장소 루트의 `npm run supabase:flutter-health`는 실행 중인 local stack의 공개 URL/publishable key를 주입해 그 테스트를 실제 실행한다.

`en_XA`는 번역·overflow 검증용 pseudo locale이며 Store 지원 언어는 영어와 한국어다. Arabic locale은 지원 목록에 선언하지 않는다. shell은 `LayoutBuilder`가 제공한 영역 너비를 사용하므로 tablet, 회전, split view에도 같은 breakpoint를 적용한다.

Android `dev` flavor만 emulator loopback(`10.0.2.2`)과 localhost cleartext를 허용하고 `prod`에는 cleartext 예외가 없다. 현재 foundation은 실제 로그인·세션을 만들지 않으며 health payload에도 개인정보가 없다. Google/Supabase 로그인은 별도 후속 Work Package에서 세션 제거 테스트와 함께 구현한다. release signing에 debug key를 사용하지 않으며 실제 signing 설정은 저장소 밖에서 공급한다.
