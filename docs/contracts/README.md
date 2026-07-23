# KinFlow 계약 문서 — Markdown 전용판

이 디렉터리는 구현 계약의 원문을 Markdown 코드 블록으로 보존합니다. 충돌 시 `DECISIONS.md` → `SPEC_BASELINE.md` → 이 계약 문서 → 상세 문서 순으로 해석합니다.

실제 구현에서는 `MD_ONLY_FORMAT_GUIDE.md`에 따라 코드 블록을 원본 파일로 추출하고 parser/validator를 실행합니다.

범위 예외: `managed_child`, `member_guardians`, `acting_contexts`, parental gate, child 전용 event/RLS/API는 P1 참조 계약이다. D-013의 별도 승인 전에는 Store MVP migration/API/client로 추출하거나 활성화하지 않는다.

| Markdown 문서 | 구현 시 생성할 원본 파일 | 역할 |
|---|---|---|
| `analysis_options.yaml.md` | `analysis_options.yaml` | analyzer/lint 최소 기준 |
| `architecture-rules.yaml.md` | `architecture-rules.yaml` | 계층 의존 규칙 |
| `database-schema.sql.md` | `database-schema.sql` | 핵심 PostgreSQL schema 골격 |
| `domain-events.yaml.md` | `domain-events.yaml` | outbox/domain event 계약 |
| `edge-types.ts.md` | `edge-types.ts` | Edge Function TypeScript 의미 타입 |
| `env.example.md` | `env.example` | client public config와 server secret 경계 |
| `error-catalog.yaml.md` | `error-catalog.yaml` | 안정 오류 코드 |
| `openapi-edge.yaml.md` | `openapi-edge.yaml` | Edge Function HTTP 계약 |
| `pubspec.yaml.example.md` | `pubspec.yaml.example` | dependency category 예시 |
| `rls-contract.sql.md` | `rls-contract.sql` | RLS helper/대표 policy 계약 |
| `toolchain.json.md` | `toolchain.json` | Flutter/Dart/플랫폼/품질 기준 |
| `types.dart.md` | `types.dart` | Dart 의미 타입·오류·DTO 예시 |

## 변경 규칙

1. 계약 변경은 요구사항·결정·migration·test와 같은 PR에서 수행합니다.
2. 출시된 field/enum/error 의미를 바꾸지 않고 additive/deprecation 절차를 사용합니다.
3. 추출된 Dart/DB client와 OpenAPI/SQL drift를 CI에서 검사합니다.
4. 예시는 실제 secret, token, 이메일, 가족 콘텐츠를 포함하지 않습니다.
5. Flutter package patch 버전은 Phase 01에서 호환성 확인 후 lockfile에 고정합니다.
6. SQL/OpenAPI 계약은 클라이언트 편의를 위해 약화하지 않습니다.
7. Markdown 래퍼와 추출된 원본 파일의 내용이 다르면 Gate를 통과할 수 없습니다.
