# Phase 01 package resolution commands

Flutter SDK 3.44.7을 활성화한 clean branch에서 실행하고 결과 `pubspec.yaml`과 `pubspec.lock`을 review한다.

```bash
flutter pub add flutter_riverpod riverpod_annotation go_router \
  freezed_annotation json_annotation supabase_flutter purchases_flutter \
  firebase_core firebase_messaging flutter_local_notifications \
  flutter_secure_storage sentry_flutter intl

flutter pub add --dev flutter_lints build_runner freezed json_serializable \
  riverpod_generator mocktail
```

그 다음 플랫폼 지원, license, transitive dependency, binary/permission 영향을 기록한다. `any` constraint를 production `pubspec.yaml`에 남기지 않는다.
