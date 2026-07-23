# 원본 파일 문서화: `matrices/RISK_REGISTER.csv`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `matrices/RISK_REGISTER.csv`
- 원본 형식: `csv`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.
- 데이터 행 수(헤더 제외): `30`

```csv
﻿risk_id,title,likelihood_1_5,impact_1_5,detectability_1_3,priority_score,prevention_mitigation,trigger_detection,contingency,phase_gate,owner,due_date,status,acceptance_notes,evidence
RISK-001,Cross-household data exposure,2,5,3,30,"RLS, composite integrity, deny tests",Auth anomaly/support,Deny/kill switch; privacy incident,All,,,OPEN,,
RISK-002,Managed Child adult-action bypass,3,5,3,45,Server allowlist + parental gate,Bypass test/audit,Disable child mode,P1 child gate,,,DEFERRED,,Reopen only when P1 child scope is approved
RISK-003,Purchaser-household entitlement corruption,3,5,3,45,Separated model/reconcile/matrix,Mismatch alert,Purchase kill switch/recompute,06,,,OPEN,,
RISK-004,Wrong age/Families classification,2,5,3,30,Phase00 official/legal review,Policy audit,Delay market/features,00/07/09,,,OPEN,,
RISK-005,DST/recurrence wrong occurrence,4,4,2,32,Typed time/revision/matrix,Support/materialization diff,Pause recurrence/repair,04/05,,,OPEN,,
RISK-006,Invite token abuse,3,4,2,24,Entropy/hash/expiry/rate limit,Rate/security logs,Revoke/rotate/block,02,,,OPEN,,
RISK-007,Shared-device cache leakage,3,5,3,45,Namespace/purge/forensic tests,Account switch test,Force logout/cache clear,02/07/10,,,OPEN,,
RISK-008,Notification duplicate storm,3,4,2,24,Outbox/dedupe/kill switch,Queue/provider metrics,Pause worker/quarantine,05,,,OPEN,,
RISK-009,Push token bound to wrong user,2,5,3,30,Installation/user binding purge,Delivery audit,Revoke all tokens,05,,,OPEN,,
RISK-010,Store success but entitlement delayed,4,3,2,24,Pending UI/webhook SLO/refresh,Mismatch metric,Support/reconcile,06,,,OPEN,,
RISK-011,Restore transfers wrong identity,3,5,3,45,Explicit conflict policy,Restore matrix,Lock/manual verify,06,,,OPEN,,
RISK-012,Account delete removes shared data,2,5,3,30,Separate identity/household delete,Delete E2E,Pause job/restore,07,,,OPEN,,
RISK-013,Deletion leaves token/cache/data,3,5,3,45,Purge checklist/state machine,Forensic test,Revoke/backfill,07,,,OPEN,,
RISK-014,PII/child data in logs,3,5,3,45,Allowlist/redaction/test,Log scan,Disable sink/delete records,01/07,,,OPEN,,
RISK-015,Flutter/plugin platform incompatibility,3,4,2,24,PoC/dependency Gate/adapter,Build/device CI,Replace/defer capability,01 onward,,,OPEN,,
RISK-016,Signing credential compromise,2,5,3,30,Protected secrets/rotation,Audit alert,Revoke/rotate/incident,08/09,,,OPEN,,
RISK-017,Store SDK/target deadline missed,3,4,2,24,RC official policy check,Calendar/checklist,Upgrade/delay submit,08/09,,,OPEN,,
RISK-018,DB migration breaks old app,3,5,3,45,Expand/contract/compat tests,Error/SLO,Feature off/forward fix,08/09,,,OPEN,,
RISK-019,Backup cannot restore,2,5,3,30,Regular restore drill,Drill failure,Provider escalation/recovery,08,,,OPEN,,
RISK-020,Realtime stale/inconsistent state,3,3,2,18,Refetch on reconnect/version,Conflict/support,Disable realtime/poll resume,03-05,,,OPEN,,
RISK-021,Offline outbox replays unauthorized action,2,5,3,30,Auth/version/TTL revalidation,Security test,Disable/purge outbox,05,,,OPEN,,
RISK-022,Scope explosion across platforms,4,4,2,32,Mobile-first independent Gates,Roadmap drift,Defer Web/Desktop,All,,,OPEN,,
RISK-023,AI-generated unverified code,4,4,2,32,Small WP + mandatory evidence,Missing tests/review,Revert/reimplement,All,,,OPEN,,
RISK-024,Low family activation/retention,4,5,2,40,Discovery/Beta thresholds,Product metrics,Change scope/value loop,00/08,,,OPEN,,
RISK-025,Subscription value/price rejected,3,4,2,24,Price research/trial metrics,Conversion/refund,Revise limits/price,00/06/09,,,OPEN,,
RISK-026,Support cannot resolve billing conflicts,3,4,2,24,Runbook/read-only tools/audit,Ticket aging,Manual escalation,06/09,,,OPEN,,
RISK-027,Low-memory Android instability,3,3,2,18,Representative device/profile,Crash/ANR,Optimize/raise min if justified,08,,,OPEN,,
RISK-028,Accessibility blocks core task,3,4,2,24,Early semantics/device testing,Audit/support,Fix before Gate,07,,,OPEN,,
RISK-029,Localization/timezone misunderstanding,3,3,2,18,EN/KO/pseudo/time UX,Support,Copy/UI correction,04/07,,,OPEN,,
RISK-030,Web Companion expands before mobile stability,3,4,2,24,Phase10 entry Gate,Roadmap audit,Stop Web work,09/10,,,OPEN,,
```
