# 원본 파일 문서화: `matrices/SPEC_TRACEABILITY.csv`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `matrices/SPEC_TRACEABILITY.csv`
- 원본 형식: `csv`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.
- 데이터 행 수(헤더 제외): `12`

```csv
﻿ID,Specification,Decisions,Artifacts,Phase,Verification
SPEC-001,Flutter/Dart/toolchain/dependency policy,"D-001,D-006,D-007,D-029,D-037,D-038",docs/21_*; contracts/toolchain.json; pubspec example,01,version/build/codegen/lockfile
SPEC-002,Repository and layer boundary,D-047,docs/22_*; architecture-rules.yaml,01,architecture import tests
SPEC-003,Native-first adaptive client and Web/Desktop Gate,"D-002,D-003,D-004,D-005,D-070",docs/20_*; docs/23_*; docs/contracts/web-companion-baseline.yaml.md,01-10,device/browser/desktop demand review
SPEC-004,Database/RLS/API authority,"D-008,D-015,D-042,D-048",docs/09_*; docs/24_*; SQL/OpenAPI,02-08,pgTAP/RLS/contract/concurrency
SPEC-005,Auth/session/invite; Managed Child P1,"D-010-D-016,D-040,D-049",docs/11_*; docs/25_*,02/07; P1,auth/link/security E2E; child E2E at P1 gate
SPEC-006,Chores/calendar recurrence and time,"D-019,D-020,D-046,D-060,D-061,D-062,D-063,D-065,D-066",docs/07_*; docs/26_*,03-05,time matrix/materialization/property tests
SPEC-007,Jobs/notifications/cache/offline,"D-017,D-018,D-021-D-023,D-064,D-067-D-069",docs/10_*; docs/26_*,05,job/push/cache/email provider actual device
SPEC-008,Billing and household entitlement,D-024-D-028,docs/12_*; docs/27_*,06,sandbox/webhook/reconcile matrix
SPEC-009,Privacy/delete/export; child safety P1,"D-011-D-014,D-035,D-040,D-041",docs/11_*; docs/17_*,07; P1,deletion/export/security/a11y; child safety at P1 gate
SPEC-010,CI/CD/store release,"D-029-D-033,D-037,D-038,D-042,D-070",docs/15_*; docs/28_*; scripts/ci/web-build.sh,01/08/09,signed builds/provenance/rollout
SPEC-011,NFR/SLO/operations,"D-034,D-036",docs/13_*; docs/16_*; docs/29_*,08/09,dashboards/load/restore/runbooks
SPEC-012,Remaining open business decisions stay gated,D-027,DECISIONS.md; Phase 00/06,00/06,decision audit and billing disabled
```
