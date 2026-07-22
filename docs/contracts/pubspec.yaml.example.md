# 원본 파일 문서화: `contracts/pubspec.yaml.example`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/pubspec.yaml.example`
- 원본 형식: `yaml`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.

```yaml
name: kinflow_app
publish_to: none
version: 0.0.0+1

environment:
  sdk: ">=3.12.0 <4.0.0"

# Scaffold example only. In Phase 01 use `flutter pub add` to resolve packages
# compatible with Flutter SDK 3.44.7, then commit exact pubspec.lock.
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  flutter_riverpod: any
  riverpod_annotation: any
  go_router: any
  freezed_annotation: any
  json_annotation: any
  supabase_flutter: any
  purchases_flutter: any
  firebase_core: any
  firebase_messaging: any
  flutter_local_notifications: any
  flutter_secure_storage: any
  sentry_flutter: any
  intl: any

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  flutter_lints: any
  build_runner: any
  freezed: any
  json_serializable: any
  riverpod_generator: any
  mocktail: any

flutter:
  uses-material-design: true
  generate: true
```
