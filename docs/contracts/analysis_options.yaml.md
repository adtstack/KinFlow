# 원본 파일 문서화: `contracts/analysis_options.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/analysis_options.yaml`
- 원본 형식: `yaml`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
  errors:
    invalid_annotation_target: ignore
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

linter:
  rules:
    always_declare_return_types: true
    always_use_package_imports: true
    avoid_dynamic_calls: true
    avoid_print: true
    cancel_subscriptions: true
    close_sinks: true
    discarded_futures: true
    only_throw_errors: true
    prefer_final_locals: true
    sort_constructors_first: true
    unawaited_futures: true
    use_build_context_synchronously: true
```
