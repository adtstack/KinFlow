# 원본 파일 문서화: `matrices/RELEASE_GATE_CHECKLIST.csv`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `matrices/RELEASE_GATE_CHECKLIST.csv`
- 원본 형식: `csv`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.
- 데이터 행 수(헤더 제외): `12`

```csv
﻿Gate_ID,Gate,Condition,Phase,Evidence,Policy,Owner,Status,Notes
G0,Decision Gate,"Launch-blocking product, age, market, price/toolchain decisions accepted",00,decision review; PoC; console ownership,BLOCK,,NOT_STARTED,
G1,Foundation Gate,Flutter/Supabase/CI/flavor/architecture baseline green,01,"CI, build, device shell, RLS smoke",BLOCK,,NOT_STARTED,
G2,Household Alpha,Two adults auth/invite/roles/managed child boundary,02,RLS matrix; iOS/Android link E2E,BLOCK,,NOT_STARTED,
G3,Chores Value,Two-device recurring chore and Today loop,03,domain/RLS/E2E/device evidence,BLOCK,,NOT_STARTED,
G4,Calendar Value,All-day/timed/recurrence/DST and Today integration,04,time matrix; device timezone evidence,BLOCK,,NOT_STARTED,
G5,Reliability Gate,"Inbox, mobile push, worker, cache/offline scope",05,queue/push actual device/forensic purge,BLOCK,,NOT_STARTED,
G6,Billing Gate,Store sandbox lifecycle and household entitlement,06,billing matrix; webhook; iOS/Android sandbox,BLOCK,,NOT_STARTED,
G7,Compliance Gate,Deletion/export/security/child/a11y/EN-KO/public pages,07,privacy/security/a11y/legal evidence,BLOCK,,NOT_STARTED,
G8,Beta Exit/RC,"Real-family value, full regression, restore/rollback, signed RC",08,RC audit; SLO; restore; risk review,BLOCK,,NOT_STARTED,
G9,Mobile Store Launch,Apple/Google submission and staged rollout,09,store records; rollout dashboard,DECISION,,NOT_STARTED,
G10,Web Companion Beta,Independent browser security/a11y/ops Gate,10,Playwright/browser/manual evidence,DECISION,,NOT_STARTED,
G11,Native Desktop Review,"Demand, plugin, ROI, signing/update ADR",10,usage data and PoC decision,DECISION,,NOT_STARTED,
```
