# 원본 파일 문서화: `matrices/TEST_MATRIX.csv`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `matrices/TEST_MATRIX.csv`
- 원본 형식: `csv`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.
- 데이터 행 수(헤더 제외): `61`

```csv
﻿Test_ID,Type,Scenario,Platform,Cadence_or_Gate,Pass_Criteria,Phase,Automation,Evidence_Path,Owner,Status
T-STATIC-01,Static,Dart format,All,PR,No diff,01-10,Automated,evidence/test/T-STATIC-01/,,NOT_RUN
T-STATIC-02,Static,Flutter analyze fatal warnings,All,PR,Green,01-10,Automated,evidence/test/T-STATIC-02/,,NOT_RUN
T-STATIC-03,Static,Codegen drift,All,PR,Regenerate then git diff 0,01-10,Automated,evidence/test/T-STATIC-03/,,NOT_RUN
T-STATIC-04,Security,Secret/dependency/license scan,All,PR/RC,No exposed secret; critical issue resolved,01-10,Automated,evidence/test/T-STATIC-04/,,NOT_RUN
T-ARCH-01,Architecture,Domain forbidden imports,Flutter,PR,0 violations,01-10,Automated,evidence/test/T-ARCH-01/,,NOT_RUN
T-BUILD-01,Build,Android dev build,Android,PR,APK build,01-10,Automated,evidence/test/T-BUILD-01/,,NOT_RUN
T-BUILD-02,Build,iOS simulator build,iOS,Main/nightly,Build success,01-10,Automated,evidence/test/T-BUILD-02/,,NOT_RUN
T-BUILD-03,Build,Signed AAB/IPA,Mobile,RC,Installable/provenance,08-09,Mixed,evidence/test/T-BUILD-03/,,NOT_RUN
T-DB-01,DB/RLS,Clean migration/reset,Server,DB change,Success,01-10,Automated,evidence/test/T-DB-01/,,NOT_RUN
T-DB-02,DB/RLS,Full authorization matrix,Server,DB change/RC,All allow/deny pass,02-09,Automated,evidence/test/T-DB-02/,,NOT_RUN
T-DB-03,DB,Cross-household FK injection,Server,DB change,Rejected,02-09,Automated,evidence/test/T-DB-03/,,NOT_RUN
T-DB-04,DB,Removed member old token,Server,Phase02+,Denied,02-09,Automated,evidence/test/T-DB-04/,,NOT_RUN
T-CONTRACT-01,Contract,OpenAPI positive/negative,Server,API change,Schema/error pass,02-10,Automated,evidence/test/T-CONTRACT-01/,,NOT_RUN
T-CONTRACT-02,Contract,Stable error catalog coverage,All,API change,All returned codes declared,02-10,Automated,evidence/test/T-CONTRACT-02/,,NOT_RUN
T-AUTH-01,Integration,Sign-in/session/logout,iOS/Android,G2,Core lifecycle pass,02,Mixed,evidence/test/T-AUTH-01/,,NOT_RUN
T-AUTH-02,Security,Session expiry/account switch purge,Mobile,G2/G7,No stale access/data,02/07,Mixed,evidence/test/T-AUTH-02/,,NOT_RUN
T-LINK-01,E2E,Auth cold-start link,iOS/Android,G2,Callback and safe continuation,02,Manual,evidence/test/T-LINK-01/,,NOT_RUN
T-LINK-02,E2E,Invite cold/warm link,iOS/Android,G2,Token safe; accept/reject states,02,Mixed,evidence/test/T-LINK-02/,,NOT_RUN
T-LINK-03,Security,Open redirect/token log,All,G2,Blocked/no raw token,02,Automated,evidence/test/T-LINK-03/,,NOT_RUN
T-CHILD-01,Security,Child restricted routes/actions,Mobile/Server,P1 child gate,All blocked server-side,P1,Mixed,evidence/p1-child/T-CHILD-01/,,DEFERRED
T-CHILD-02,Security,PIN brute force/recovery,Mobile,P1 child gate,Backoff/recovery policy,P1,Mixed,evidence/p1-child/T-CHILD-02/,,DEFERRED
T-CHORE-01,E2E,Create/assign/complete two devices,Mobile,G3,Consistent Today,03,Mixed,evidence/test/T-CHORE-01/,,NOT_RUN
T-CHORE-02,Concurrency,Duplicate complete/version conflict,All,G3,Idempotent/conflict UI,03,Automated,evidence/test/T-CHORE-02/,,NOT_RUN
T-TIME-01,Domain,DST/month-end/leap/all-day matrix,All,G4,All fixtures pass,04,Automated,evidence/test/T-TIME-01/,,NOT_RUN
T-CAL-01,E2E,One-time/recurring/single exception,Mobile,G4,Correct views/Today,04,Mixed,evidence/test/T-CAL-01/,,NOT_RUN
T-JOB-01,Reliability,Worker lease/crash/retry/dead letter,Server,G5,No loss/duplicate side effect,05,Automated,evidence/test/T-JOB-01/,,NOT_RUN
T-NOTIF-01,Integration,Inbox/dedupe/quiet hours,Server/Mobile,G5,Correct durable state,05,Automated,evidence/test/T-NOTIF-01/,,NOT_RUN
T-PUSH-01,Device,Permission authorized/denied,iOS/Android,G5,Correct UX/fallback,05,Manual,evidence/test/T-PUSH-01/,,NOT_RUN
T-PUSH-02,Device,Foreground push/local display,iOS/Android,G5,No duplicate; tap route,05,Manual,evidence/test/T-PUSH-02/,,NOT_RUN
T-PUSH-03,Device,Background push,iOS/Android,G5,Delivery/tap/refetch,05,Manual,evidence/test/T-PUSH-03/,,NOT_RUN
T-PUSH-04,Device,Terminated push,iOS/Android,G5,Bootstrap then safe route,05,Manual,evidence/test/T-PUSH-04/,,NOT_RUN
T-PUSH-05,Integration,Token rotation/invalid cleanup,All,G5,Binding updated/revoked,05,Mixed,evidence/test/T-PUSH-05/,,NOT_RUN
T-PUSH-06,Security,Payload privacy/stale resource,All,G5,Minimal content/authz recheck,05,Mixed,evidence/test/T-PUSH-06/,,NOT_RUN
T-CACHE-01,Security,Logout purge,Mobile/Web,G2/G7/G10,No previous family data,02/07/10,Mixed,evidence/test/T-CACHE-01/,,NOT_RUN
T-CACHE-02,Security,Account switch purge,Mobile/Web,G2/G7/G10,No cross-account residue,02/07/10,Mixed,evidence/test/T-CACHE-02/,,NOT_RUN
T-CACHE-03,Security,Household switch/removed member,Mobile/Web,G2/G7/G10,No stale access,02/07/10,Mixed,evidence/test/T-CACHE-03/,,NOT_RUN
T-CACHE-04,Reliability,Offline stale read,Mobile/Web,G5/G10,Clear stale state; no unsafe action,05/10,Mixed,evidence/test/T-CACHE-04/,,NOT_RUN
T-SYNC-01,Reliability,Outbox TTL/auth binding,Mobile,G5 optional,Unsafe replay blocked,05,Automated,evidence/test/T-SYNC-01/,,NOT_RUN
T-SYNC-02,Reliability,Realtime reconnect/full refetch,All,G3-G5,Consistent state,03-05,Automated,evidence/test/T-SYNC-02/,,NOT_RUN
T-BILL-01,Sandbox,App Store purchase/restore,iOS,G6,Server entitlement matches,06,Manual,evidence/test/T-BILL-01/,,NOT_RUN
T-BILL-02,Sandbox,Play purchase/restore,Android,G6,Server entitlement matches,06,Manual,evidence/test/T-BILL-02/,,NOT_RUN
T-BILL-03,Billing,Webhook duplicate/out-of-order,Server,G6,Idempotent final state,06,Automated,evidence/test/T-BILL-03/,,NOT_RUN
T-BILL-04,Billing,Reinstall/account/household conflict,Mobile/Server,G6,No entitlement leakage/duplicate purchase,06,Mixed,evidence/test/T-BILL-04/,,NOT_RUN
T-BILL-05,Billing,Expiry/refund/grace/billing issue,All,G6,Policy state correct,06,Mixed,evidence/test/T-BILL-05/,,NOT_RUN
T-PRIV-01,E2E,Account deletion,All,G7,Shared data policy/purge/status,07,Mixed,evidence/test/T-PRIV-01/,,NOT_RUN
T-PRIV-02,E2E,Household delete/last owner,All,G7,Invariant and purge,07,Mixed,evidence/test/T-PRIV-02/,,NOT_RUN
T-PRIV-03,Privacy,PII/log/child analytics,All,G7,Forbidden fields absent,07,Automated,evidence/test/T-PRIV-03/,,NOT_RUN
T-PRIV-04,E2E,Data export/link expiry,All,G7,Authorized/short-lived,07,Mixed,evidence/test/T-PRIV-04/,,NOT_RUN
T-A11Y-01,Accessibility,VoiceOver core journey,iOS,G7,Task success,07,Manual,evidence/test/T-A11Y-01/,,NOT_RUN
T-A11Y-02,Accessibility,TalkBack core journey,Android,G7,Task success,07,Manual,evidence/test/T-A11Y-02/,,NOT_RUN
T-A11Y-03,Accessibility,200% text/tablet/split,Mobile,G7,No blocker clipping,07,Mixed,evidence/test/T-A11Y-03/,,NOT_RUN
T-I18N-01,Localization,EN/KO/pseudo key/layout,All,G7,100% coverage/no overflow blocker,07,Mixed,evidence/test/T-I18N-01/,,NOT_RUN
T-PERF-01,Performance,Startup/Today profile,Mobile,G8,Budget pass or accepted risk,08,Mixed,evidence/test/T-PERF-01/,,NOT_RUN
T-RECOV-01,Recovery,Backup restore/data integrity,Server,G8,RPO/RTO and checks pass,08,Manual,evidence/test/T-RECOV-01/,,NOT_RUN
T-REL-01,Release,Previous build to RC upgrade,Mobile,G8,No auth/cache/data loss,08,Manual,evidence/test/T-REL-01/,,NOT_RUN
T-REL-02,Release,Feature kill switch,All,G8,Risk feature disabled safely,08,Manual,evidence/test/T-REL-02/,,NOT_RUN
T-REL-03,Release,Staged rollout pause,Stores,G9,Procedure demonstrated,09,Manual,evidence/test/T-REL-03/,,NOT_RUN
T-WEB-01,Web,Core Playwright journey,Web,G10,Browser matrix pass,10,Automated,evidence/test/T-WEB-01/,,NOT_RUN
T-WEB-02,Web Security,CSP/session/BFCache/account switch,Web,G10,No unsafe persistence,10,Mixed,evidence/test/T-WEB-02/,,NOT_RUN
T-WEB-03,Accessibility,Keyboard/zoom/screen reader,Web,G10,Core task success,10,Mixed,evidence/test/T-WEB-03/,,NOT_RUN
T-DESK-01,Decision,Desktop plugin/demand PoC,Desktop,G11,"Explicit ADR, no implied support",10,Manual,evidence/test/T-DESK-01/,,NOT_RUN
```
