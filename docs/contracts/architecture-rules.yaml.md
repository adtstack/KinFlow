# 원본 파일 문서화: `contracts/architecture-rules.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/architecture-rules.yaml`
- 원본 형식: `yaml`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.

```yaml
version: 1
layers:
  presentation:
    may_import: [application, domain, design_system]
    forbidden_direct_imports: [supabase_flutter, purchases_flutter, firebase_messaging]
  application:
    may_import: [domain]
    forbidden_imports: [flutter_widgets, supabase_flutter, purchases_flutter, firebase_messaging]
  domain:
    may_import: [dart_core]
    forbidden_imports: [flutter, riverpod, supabase_flutter, purchases_flutter, firebase_core, dart_html]
  data:
    may_import: [application, domain, approved_sdk_adapters]
policies:
  dto_must_not_escape_data_layer: true
  widget_must_not_call_sdk_directly: true
  server_authoritative_household_and_entitlement: true
  generated_files_committed: true
```
