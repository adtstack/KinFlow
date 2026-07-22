# 원본 파일 문서화: `matrices/RELEASE_CHECKLIST.csv`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `matrices/RELEASE_CHECKLIST.csv`
- 원본 형식: `csv`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.
- 데이터 행 수(헤더 제외): `23`

```csv
﻿ID,Area,Item,Phase,Gate,Owner,Reviewer,Status,Evidence,Notes
REL-001,Decision,Target countries/age/Families classification accepted,00,G0,,,NOT_STARTED,,
REL-002,Identity,"Production app name, Bundle ID, package, domains owned",00,G0,,,NOT_STARTED,,
REL-003,Toolchain,Flutter/Xcode/Android target current official check,08/09,G8/G9,,,NOT_STARTED,,
REL-004,Backend,"Production Supabase region, migration, RLS, backup ready",08/09,G8/G9,,,NOT_STARTED,,
REL-005,Auth,"Redirects, email/OAuth, Universal/App Links verified",08,G8,,,NOT_STARTED,,
REL-006,Push,APNs/FCM production and permission copy verified,08,G8,,,NOT_STARTED,,
REL-007,Billing,Store products/RevenueCat/webhook/sandbox matrix passed,06/08,G6/G8,,,NOT_STARTED,,
REL-008,Privacy,"Privacy policy, App Privacy, Data Safety approved",07/09,G7/G9,,,NOT_STARTED,,
REL-009,Deletion,In-app and public account deletion end-to-end,07/08,G7/G8,,,NOT_STARTED,,
REL-010,Child Safety,Managed Child and parental gate review passed,07,G7,,,NOT_STARTED,,
REL-011,Accessibility,VoiceOver/TalkBack/large text/tablet journeys,07/08,G7/G8,,,NOT_STARTED,,
REL-012,Localization,EN/KO app and Store metadata complete,07/09,G7/G9,,,NOT_STARTED,,
REL-013,Security,Secret/dependency/RLS/invite/webhook review,08,G8,,,NOT_STARTED,,
REL-014,Recurrence,DST/time matrix and repair procedure,04/08,G4/G8,,,NOT_STARTED,,
REL-015,Reliability,"Queue, notification, entitlement alerts/runbooks",08,G8,,,NOT_STARTED,,
REL-016,Recovery,"Backup restore, migration recovery, kill switches",08,G8,,,NOT_STARTED,,
REL-017,Build,"Clean signed IPA/AAB, checksum, SBOM, provenance",09,G9,,,NOT_STARTED,,
REL-018,Store Assets,"Screenshots, descriptions, support/privacy URLs",09,G9,,,NOT_STARTED,,
REL-019,Review Account,Reviewer journey and notes tested,09,G9,,,NOT_STARTED,,
REL-020,Rollout,"Canary thresholds, owner, pause/rollback",09,G9,,,NOT_STARTED,,
REL-021,Support,"Support channel, escalation, incident communication",09,G9,,,NOT_STARTED,,
REL-022,72h Review,Crash/auth/Today/push/billing/privacy review,09,G9,,,NOT_STARTED,,
REL-023,30d Review,Value/retention/revenue/cost and Web decision,09,G9/G10,,,NOT_STARTED,,
```
