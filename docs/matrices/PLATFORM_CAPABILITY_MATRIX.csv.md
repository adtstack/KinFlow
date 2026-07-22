# 원본 파일 문서화: `matrices/PLATFORM_CAPABILITY_MATRIX.csv`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `matrices/PLATFORM_CAPABILITY_MATRIX.csv`
- 원본 형식: `csv`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.
- 데이터 행 수(헤더 제외): `20`

```csv
﻿Capability_ID,Capability,Domain_Interface,iOS_Provider,Android_Provider,Web_Provider,Fallback,Required_Gate,Primary_Test_IDs,Security_Privacy_Notes,Status,Evidence
CAP-001,Authentication session,AuthSessionRepository,Supabase Auth + secure storage,Supabase Auth + secure storage,Supabase browser session,re-auth/read-only public path,G2/G10,T-AUTH-01;T-SEC-04,token redaction; identity switch purge,NOT_STARTED,
CAP-002,Deep links,DeepLinkSource,Universal Links,Android App Links,HTTPS routes,copy safe link,G2/G10,T-LINK-01;T-LINK-02,exact allowlist; invite token scrub,NOT_STARTED,
CAP-003,Push notifications,NotificationService,FCM/APNs,FCM,Deferred Web Push,in-app inbox/email,G5,T-PUSH-01..06,payload minimization; token cleanup,NOT_STARTED,
CAP-004,Local notification display,LocalNotificationService,flutter_local_notifications,flutter_local_notifications,Browser notification deferred,in-app banner,G5,T-PUSH-02;T-PUSH-03,foreground duplicate prevention,NOT_STARTED,
CAP-005,In-app inbox,NotificationInboxRepository,Shared server API,Shared server API,Shared server API,none,G5/G10,T-NOTIF-01,RLS and content minimization,NOT_STARTED,
CAP-006,Billing purchase,BillingService,RevenueCat App Store,RevenueCat Play,Unavailable in initial Beta,mobile purchase route,G6,T-BILL-01..12,server household entitlement,NOT_STARTED,
CAP-007,Entitlement read,EntitlementRepository,Server snapshot,Server snapshot,Server snapshot,Free limits,G6/G10,T-BILL-08,never trust local SDK state,NOT_STARTED,
CAP-008,Secure storage,SecureStorage,Keychain-backed,Keystore-backed,Browser strategy,memory + re-auth,G1,T-SEC-03,no secret in preferences,NOT_STARTED,
CAP-009,Parental gate,ParentalGate,OS auth/PIN,OS auth/PIN,recent auth/PIN,adult re-auth,G2/G7,T-CHILD-01..04,server allowlist remains authority,NOT_STARTED,
CAP-010,Background execution,BackgroundScheduler,Best-effort,Best-effort,Foreground only baseline,server worker,G5,T-JOB-01,not source of notification truth,NOT_STARTED,
CAP-011,Offline read cache,OfflineCache,Scoped cache,Scoped cache,Memory/minimal browser storage,stale + retry,G3/G4/G10,T-CACHE-01..04,user+household namespace/purge,NOT_STARTED,
CAP-012,Safe offline mutation,MutationOutbox,Chore completion candidate,Chore completion candidate,Disabled initially,online-only,G5 optional,T-SYNC-01..05,auth/version/TTL/idempotency binding,PROVISIONAL,
CAP-013,Realtime,RealtimeSubscription,Supabase Realtime,Supabase Realtime,Supabase Realtime,resume refetch,G3/G4,T-SYNC-06,RLS; reconnect full validation,NOT_STARTED,
CAP-014,Analytics,AnalyticsSink,Approved mobile sink,Approved mobile sink,Approved web sink,first-party aggregate,G1/G7,T-PRIV-03,child mode disabled; no content,NOT_STARTED,
CAP-015,Crash reporting,ErrorReporter,Sentry Flutter,Sentry Flutter,Sentry Flutter,redacted local logs,G1/G8,T-OBS-01,before-send PII scrub,NOT_STARTED,
CAP-016,Share,ShareService,Native share,Native share,Web Share/clipboard,copy button,G2,T-LINK-03,safe URL; raw token lifecycle,NOT_STARTED,
CAP-017,Export delivery,ExportDelivery,secure download/share,secure download/share,short-lived HTTPS download,support path,G7,T-PRIV-06,expiry; browser residue check,NOT_STARTED,
CAP-018,Update,AppUpdatePolicy,App Store,Play Store,atomic web deploy,feature kill switch,G8/G9/G10,T-REL-01..04,minimum version and compatibility,NOT_STARTED,
CAP-019,Native calendar integration,CalendarIntegration,Deferred,Deferred,Unsupported,ICS/share future,Post-MVP,T-DEFER-01,no broad calendar permission,DEFERRED,
CAP-020,Desktop native shell,DesktopCapability,N/A,N/A,N/A,Web Companion,Phase 10 demand review,T-DESK-01,no support promise before Gate,DEFERRED,
```
