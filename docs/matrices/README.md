# KinFlow 검증 매트릭스 — Markdown 전용판

각 문서는 원본 CSV를 fenced `csv` 코드 블록으로 보존합니다. 구현 저장소에서 원본 CSV가 필요하면 `MD_ONLY_FORMAT_GUIDE.md`의 경로로 추출합니다.

| Markdown 문서 | 원본 CSV | 데이터 행 |
|---|---|---:|
| `API_CONTRACT_TEST_MATRIX.csv.md` | `API_CONTRACT_TEST_MATRIX.csv` | 56 |
| `BILLING_TEST_MATRIX.csv.md` | `BILLING_TEST_MATRIX.csv` | 38 |
| `NFR_BUDGETS.csv.md` | `NFR_BUDGETS.csv` | 20 |
| `PLATFORM_CAPABILITY_MATRIX.csv.md` | `PLATFORM_CAPABILITY_MATRIX.csv` | 20 |
| `PLATFORM_DEFINITION_OF_DONE.csv.md` | `PLATFORM_DEFINITION_OF_DONE.csv` | 55 |
| `RELEASE_CHECKLIST.csv.md` | `RELEASE_CHECKLIST.csv` | 23 |
| `RELEASE_GATE_CHECKLIST.csv.md` | `RELEASE_GATE_CHECKLIST.csv` | 12 |
| `REQUIREMENTS_TRACEABILITY.csv.md` | `REQUIREMENTS_TRACEABILITY.csv` | 127 |
| `RISK_REGISTER.csv.md` | `RISK_REGISTER.csv` | 33 |
| `RLS_AUTHORIZATION_MATRIX.csv.md` | `RLS_AUTHORIZATION_MATRIX.csv` | 266 |
| `SPEC_TRACEABILITY.csv.md` | `SPEC_TRACEABILITY.csv` | 12 |
| `TEST_MATRIX.csv.md` | `TEST_MATRIX.csv` | 99 |
| `TIME_RECURRENCE_TEST_MATRIX.csv.md` | `TIME_RECURRENCE_TEST_MATRIX.csv` | 48 |

## 사용 규칙

- RLS, billing, time/recurrence matrix는 해당 Gate에서 100% 실행합니다.
- 플랫폼 Definition of Done은 자동화와 실제 기기/브라우저 증거를 함께 요구합니다.
- 행을 삭제해 실패를 숨기지 않습니다. 비범위는 status와 승인 근거를 기록합니다.
- 요구사항/결정 변경 시 traceability와 risk를 같은 PR에서 갱신합니다.
- Markdown 코드 블록과 추출된 CSV의 행 수·checksum이 일치해야 합니다.
