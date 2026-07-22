# KinFlow Markdown 전용 문서팩 사용 가이드

- 문서팩 버전: `v1.2`
- 스펙 기준선: `KinFlow 앱 스펙 v1.0`
- 목적: DOCX 및 비-Markdown 파일 없이 하나의 압축 문서팩으로 전달

## 1. 기본 원칙

이 압축 파일에는 `.md` 파일만 있습니다. SQL, YAML, JSON, CSV, Dart, TypeScript, 환경 변수 예시와 검증 스크립트는 삭제하지 않고 Markdown 코드 블록으로 보존했습니다.

구현 단계에서는 각 래퍼 문서 상단의 **구현 시 생성할 원본 경로**를 확인하고, 코드 블록 내용만 해당 경로로 추출합니다. 래퍼 문서는 설계 증거로 계속 보존합니다.

## 2. 추출 시 주의사항

1. 코드 블록의 언어 표식과 바깥 설명은 원본 파일에 포함하지 않습니다.
2. SQL·OpenAPI·오류 카탈로그·RLS 계약은 임의로 축약하지 않습니다.
3. CSV 검증표는 헤더와 모든 행을 그대로 보존합니다.
4. `.env` 예시는 변수명과 설명만 사용하며 비밀값을 입력해 문서에 커밋하지 않습니다.
5. 추출 후 formatter, parser, OpenAPI validator, PostgreSQL parser와 테스트를 실행합니다.
6. 추출된 실행 파일과 이 Markdown 문서팩은 역할이 다릅니다. 실행 파일은 코드 저장소에, 문서팩은 `docs/spec-pack/` 등에 보존합니다.

## 3. 변환 파일 매핑

| Markdown 문서 | 구현 시 원본 경로 |
|---|---|
| `ENV_EXAMPLE.md` | `.env.example` |
| `contracts/analysis_options.yaml.md` | `contracts/analysis_options.yaml` |
| `contracts/architecture-rules.yaml.md` | `contracts/architecture-rules.yaml` |
| `contracts/database-schema.sql.md` | `contracts/database-schema.sql` |
| `contracts/domain-events.yaml.md` | `contracts/domain-events.yaml` |
| `contracts/edge-types.ts.md` | `contracts/edge-types.ts` |
| `contracts/env.example.md` | `contracts/env.example` |
| `contracts/error-catalog.yaml.md` | `contracts/error-catalog.yaml` |
| `contracts/openapi-edge.yaml.md` | `contracts/openapi-edge.yaml` |
| `contracts/pubspec.yaml.example.md` | `contracts/pubspec.yaml.example` |
| `contracts/rls-contract.sql.md` | `contracts/rls-contract.sql` |
| `contracts/toolchain.json.md` | `contracts/toolchain.json` |
| `contracts/types.dart.md` | `contracts/types.dart` |
| `matrices/API_CONTRACT_TEST_MATRIX.csv.md` | `matrices/API_CONTRACT_TEST_MATRIX.csv` |
| `matrices/BILLING_TEST_MATRIX.csv.md` | `matrices/BILLING_TEST_MATRIX.csv` |
| `matrices/NFR_BUDGETS.csv.md` | `matrices/NFR_BUDGETS.csv` |
| `matrices/PLATFORM_CAPABILITY_MATRIX.csv.md` | `matrices/PLATFORM_CAPABILITY_MATRIX.csv` |
| `matrices/PLATFORM_DEFINITION_OF_DONE.csv.md` | `matrices/PLATFORM_DEFINITION_OF_DONE.csv` |
| `matrices/RELEASE_CHECKLIST.csv.md` | `matrices/RELEASE_CHECKLIST.csv` |
| `matrices/RELEASE_GATE_CHECKLIST.csv.md` | `matrices/RELEASE_GATE_CHECKLIST.csv` |
| `matrices/REQUIREMENTS_TRACEABILITY.csv.md` | `matrices/REQUIREMENTS_TRACEABILITY.csv` |
| `matrices/RISK_REGISTER.csv.md` | `matrices/RISK_REGISTER.csv` |
| `matrices/RLS_AUTHORIZATION_MATRIX.csv.md` | `matrices/RLS_AUTHORIZATION_MATRIX.csv` |
| `matrices/SPEC_TRACEABILITY.csv.md` | `matrices/SPEC_TRACEABILITY.csv` |
| `matrices/TEST_MATRIX.csv.md` | `matrices/TEST_MATRIX.csv` |
| `matrices/TIME_RECURRENCE_TEST_MATRIX.csv.md` | `matrices/TIME_RECURRENCE_TEST_MATRIX.csv` |
| `scripts/validate_docs.py.md` | `scripts/validate_docs.py` |

## 4. DOCX 처리

기존 사람 검토용 DOCX와 그 전용 checksum 파일은 이 문서팩에서 완전히 제거했습니다. 필요한 내용은 `MASTER_SPEC.md`, `IMPLEMENTATION_SPEC.md`, 개별 `docs/` 문서에 포함되어 있습니다.

## 5. 코딩 에이전트 최초 지시문에 추가할 문장

```text
이 저장소의 스펙 문서팩은 Markdown 전용이다.
contracts와 matrices의 비-Markdown 원본은 <원본명>.md 코드 블록 안에 있다.
Phase 01에서 필요한 원본 파일을 지정된 경로로 정확히 추출하고 parser/validator로 검증하라.
Markdown 래퍼 문서는 삭제하지 말고 설계 기준 문서로 유지하라.
```
