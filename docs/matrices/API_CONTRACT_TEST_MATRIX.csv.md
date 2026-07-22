# 원본 파일 문서화: `matrices/API_CONTRACT_TEST_MATRIX.csv`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `matrices/API_CONTRACT_TEST_MATRIX.csv`
- 원본 형식: `csv`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.
- 데이터 행 수(헤더 제외): `34`

```csv
﻿ID,Operation,Scenario,Expected result,Automation,Phase
API-001,POST /households,valid user + idempotency,201 household + owner member,"unit, integration, DB transaction",P01/P02
API-002,POST /households,same key/same payload,"same response, no duplicate",integration,P02
API-003,POST /households,same key/different payload,409 IDEMPOTENCY_KEY_REUSED,integration,P02
API-004,POST /invites/preview,valid raw token,minimal preview only,"contract, integration",P02
API-005,POST /invites/preview,expired/revoked token,410 stable error,"contract, integration",P02
API-006,POST /invites/preview,brute-force rate,429 RATE_LIMITED,security test,P02
API-007,POST /invites/accept,concurrent double accept,"one membership, idempotent result","integration, concurrency",P02
API-008,POST /invites/accept,wrong target email,403 INVITE_EMAIL_MISMATCH,integration,P02
API-009,POST owner-transfer,last owner/new invalid member,"409/403, invariant preserved","DB, RLS, integration",P02
API-010,PUT member role,outsider UUID injection,"404/403, no leak","RLS, integration",P02
API-011,POST acting-context,non-guardian child,403 ACTING_CONTEXT_INVALID,"DB, security",P02
API-012,POST chore complete,valid expected version,200 completed + audit/outbox,"unit, DB, integration",P03
API-013,POST chore complete,stale expected version,409 VERSION_CONFLICT,integration,P03
API-014,POST chore complete,different household occurrence,"404/403, no mutation","RLS, integration",P03
API-015,PUT chore series,invalid recurrence interval/count,400 RECURRENCE_RULE_INVALID,"contract, unit",P03
API-016,PUT event series,DST gap local time,deterministic adjusted occurrence,"unit, integration",P04
API-017,PUT event series,thisOccurrence scope,"exception only, series unchanged","DB, integration",P04
API-018,PUT event series,entireSeries scope,"new revision, past completion/history preserved","DB, integration",P04
API-019,GET /today,household timezone date,bounded stable aggregate,"contract, performance",P03/P04
API-020,GET /today,limit > 500,400 validation,contract,P03
API-021,POST notification endpoint,token rotation same installation,upsert one active endpoint,integration,P05
API-022,POST notification endpoint,logout/account switch,old binding revoked/removed,"E2E, integration",P05
API-023,POST billing sync,verified purchase + eligible household,server entitlement active,"sandbox, integration",P06
API-024,POST billing sync,provider timeout,"503 retryable, no premature unlock",integration,P06
API-025,POST billing assignment,customer already assigned elsewhere,409 BILLING_ASSIGNMENT_CONFLICT,integration,P06
API-026,POST RevenueCat webhook,duplicate provider event,single receipt/effect,integration,P06
API-027,POST RevenueCat webhook,out-of-order event,authoritative reconcile prevents rollback,integration,P06
API-028,POST privacy request,duplicate pending request,409 PRIVACY_REQUEST_ALREADY_PENDING,integration,P07
API-029,GET privacy request,other user request ID,"404/403, no metadata leak","RLS, integration",P07
API-030,all endpoints,invalid/unknown body fields,400 stable envelope,contract fuzz,all
API-031,all endpoints,expired JWT,401 SESSION_EXPIRED,"contract, integration",all
API-032,all endpoints,provider/SQL exception,"safe INTERNAL_ERROR, no raw details","security, contract",all
API-033,mutation endpoints,missing idempotency key,400 IDEMPOTENCY_KEY_REQUIRED,contract,all
API-034,all responses,contract version/request ID,present and schema-valid,contract,all
```
