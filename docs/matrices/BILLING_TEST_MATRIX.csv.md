# 원본 파일 문서화: `matrices/BILLING_TEST_MATRIX.csv`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `matrices/BILLING_TEST_MATRIX.csv`
- 원본 형식: `csv`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.
- 데이터 행 수(헤더 제외): `38`

```csv
﻿test_id,scenario,platform,preconditions,steps,expected,automated_or_manual,environment,status,evidence,notes
BILL-001,iOS monthly new purchase,iOS/Android/Server as applicable,Free adult Owner,TODO during implementation,Purchase→server Plus,BOTH,Sandbox/Staging,NOT_STARTED,,monthly product
BILL-002,iOS annual new purchase,iOS/Android/Server as applicable,Free adult Owner,TODO during implementation,Purchase→server Plus,BOTH,Sandbox/Staging,NOT_STARTED,,annual product
BILL-003,Android base plan purchase,iOS/Android/Server as applicable,Free adult Owner,TODO during implementation,Purchase→server Plus,BOTH,Sandbox/Staging,NOT_STARTED,,base plan
BILL-004,Purchase cancelled,iOS/Android/Server as applicable,Paywall open,TODO during implementation,No entitlement; non-error UX,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-005,Pending purchase,iOS/Android/Server as applicable,Store pending,TODO during implementation,Show pending; no premature Plus,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-006,Duplicate purchase tap,iOS/Android/Server as applicable,Same idempotency context,TODO during implementation,One transaction/assignment,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-007,Webhook duplicate,iOS/Android/Server as applicable,Same provider event replay,TODO during implementation,One normalized event; no duplicate,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-008,Webhook out of order,iOS/Android/Server as applicable,Expiration before renewal delivery order,TODO during implementation,Final provider-consistent state,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-009,Sandbox event to production,iOS/Android/Server as applicable,Sandbox event,TODO during implementation,Quarantine/deny,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-010,Unknown product/customer,iOS/Android/Server as applicable,Unmapped provider payload,TODO during implementation,Quarantine + alert,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-011,Client entitlement tamper,iOS/Android/Server as applicable,Local Plus forced,TODO during implementation,Server denies premium write,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-012,Explicit refresh after webhook delay,iOS/Android/Server as applicable,Purchase success; webhook delayed,TODO during implementation,Server sync eventually active,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-013,Restore same login/same household,iOS/Android/Server as applicable,Reinstall,TODO during implementation,Plus restored,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-014,Restore same store/different app login,iOS/Android/Server as applicable,Different profile,TODO during implementation,Follow configured restore policy; no silent theft,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-015,Restore purchase assigned to another household,iOS/Android/Server as applicable,Existing active assignment,TODO during implementation,Conflict/choice/support flow,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-016,Billing owner leaves household,iOS/Android/Server as applicable,Active Plus,TODO during implementation,Policy flow; no silent loss,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-017,Household Owner transfer,iOS/Android/Server as applicable,Billing owner unchanged,TODO during implementation,Roles displayed separately,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-018,Paid household transfer,iOS/Android/Server as applicable,Recent auth/cooldown,TODO during implementation,Atomic old Free/new Plus + audit,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-019,Account delete with active subscription,iOS/Android/Server as applicable,Billing owner delete,TODO during implementation,Explain store cancel; apply approved lifecycle,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-020,Grace period,iOS/Android/Server as applicable,Provider grace,TODO during implementation,Plus/grace UI per policy,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-021,Billing issue/account hold,iOS/Android/Server as applicable,Provider issue,TODO during implementation,Policy UI; data preserved,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-022,Expiration,iOS/Android/Server as applicable,Expired,TODO during implementation,Free; data readable; new limits enforced,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-023,Refund/revoke,iOS/Android/Server as applicable,Provider revoke,TODO during implementation,Entitlement removed per policy; data preserved,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-024,Plus→Free over limit,iOS/Android/Server as applicable,Existing items exceed Free,TODO during implementation,No deletion; restrict approved actions,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-025,Child mode purchase attempt,iOS/Android/Server as applicable,Managed Child mode,P1 test only,Blocked client and server,BOTH,Sandbox/Staging,DEFERRED,,P1 child gate
BILL-026,Member tries assignment/transfer,iOS/Android/Server as applicable,Non-authorized member,TODO during implementation,Denied,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-027,RevenueCat outage,iOS/Android/Server as applicable,Existing Plus/new purchase,TODO during implementation,Existing server entitlement preserved; purchase disabled,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-028,Webhook outage and reconciliation,iOS/Android/Server as applicable,Missed events,TODO during implementation,Periodic reconciliation repairs state,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-029,Family Sharing OFF scenario,iOS/Android/Server as applicable,iOS family member device,TODO during implementation,Only app household policy applies,BOTH,Sandbox/Staging,NOT_STARTED,,Decision D-017
BILL-030,Family Sharing ON scenario if accepted,iOS/Android/Server as applicable,Multiple RC customers,TODO during implementation,Documented household behavior; no double assignment,BOTH,Sandbox/Staging,NOT_STARTED,,Only if D-017 ON
BILL-031,iOS purchase reflected on Web,iOS/Web/Server,same auth user and household,purchase iOS; process webhook; refresh Web,Web reads same server Plus,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-032,Android restore reflected on iOS and Web,Android/iOS/Web/Server,prior purchase,restore Android; reconcile; open other clients,all clients same entitlement,BOTH,Sandbox/Staging,NOT_STARTED,,
BILL-033,Web purchase creates household entitlement,Web/Server,D-039 accepted; Free billing owner,checkout; webhook; assign household,verified Plus on all clients,BOTH,Web Sandbox/Staging,NOT_STARTED,,only if Web paid enabled
BILL-034,Web checkout return URL tamper,Web/Server,Web paid enabled,alter return/state/household client values,server rejects or ignores untrusted values,BOTH,Web Sandbox/Staging,NOT_STARTED,,
BILL-035,Duplicate mobile and Web subscription warning,iOS/Android/Web,existing active provider subscription,attempt second provider purchase,clear warning/policy; no double entitlement corruption,MANUAL,Sandbox/Staging,NOT_STARTED,,
BILL-036,Web refund or chargeback,Web/Server,active Web entitlement,provider refund event and reconcile,policy-consistent entitlement on all clients,BOTH,Web Sandbox/Staging,NOT_STARTED,,
BILL-037,Cross-account browser cache after purchase,Web,account A paid account B free,A open paywall/status; logout; B login,B does not see A purchase or household,BOTH,Staging,NOT_STARTED,,
BILL-038,Provider outage cross-platform grace,iOS/Android/Web/Server,verified active entitlement,simulate provider outage/reconcile delay,same grace/read-only policy across clients,BOTH,Staging,NOT_STARTED,,
```
