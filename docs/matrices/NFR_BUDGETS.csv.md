# 원본 파일 문서화: `matrices/NFR_BUDGETS.csv`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `matrices/NFR_BUDGETS.csv`
- 원본 형식: `csv`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.
- 데이터 행 수(헤더 제외): `20`

```csv
﻿ID,Metric,Target,Scope,Gate,Evidence
NFR-001,Mobile cold Today,p95 <= 3.0s,representative device/network/data,Phase08/G8,Profile trace
NFR-002,Warm shell,p95 <= 1.5s,representative device,Phase08/G8,Profile trace
NFR-003,Today server,p95 <= 800ms,defined region/data volume,Phase08/G8,APM/query
NFR-004,Core mutation,p95 <= 700ms,excluding validation/authz,Phase08/G8,APM
NFR-005,Crash-free sessions,>= 99.7%,mobile release cohort,G8/G9,Sentry/Store
NFR-006,Core read availability,>= 99.9% monthly,authenticated Today/read,G8/G9,SLO dashboard
NFR-007,Critical mutation success,>= 99.5%,excluding user errors,G8/G9,SLO dashboard
NFR-008,Notification submit,95% within scheduled ±5m,provider accepted,G5/G8,job dashboard
NFR-009,Entitlement materialize,99% <= 10m,verified provider event,G6/G8,billing dashboard
NFR-010,RLS matrix,100% pass,all protected resources,Every DB change,CI
NFR-011,EN/KO coverage,100% keys,no fallback leak,G7,localization report
NFR-012,Text scaling,200% core task,no clipped blocker,G7,device evidence
NFR-013,Screen reader,core task success,VoiceOver/TalkBack,G7,video/checklist
NFR-014,Account switch purge,0 prior-household residue,mobile/web scoped storage,G2/G7/G10,forensic test
NFR-015,Backup restore,RPO/RTO approved,isolated restore,G8,drill report
NFR-016,Critical CVE,0 unresolved,release dependencies,G8/G9,scan/SBOM
NFR-017,Generated drift,0 diff,build_runner output,Every PR,CI
NFR-018,Analyzer,0 warnings/info at fatal settings,all Dart code,Every PR,CI
NFR-019,Build reproducibility,same source/config provenance,clean RC checkout,G8/G9,artifact hashes
NFR-020,Web core task,browser matrix pass,post-mobile Beta,G10,Playwright/manual
```
