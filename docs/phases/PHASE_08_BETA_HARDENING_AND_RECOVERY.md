# Phase 08 — 실제 가족 Beta, Hardening, 복구

## 목표

실제 가족 사용으로 제품 가치와 운영 안정성을 검증하고, 성능·업그레이드·백업·장애 대응을 Release Candidate 수준으로 만든다.

## Entry

Compliance Gate 통과, TestFlight/Play closed testing 준비.

## Work Packages

### WP08-01 Beta cohort

- 다양한 가족 형태/기기/timezone
- consent/support channel
- activation/retention/task success
- qualitative interview

### WP08-02 Defect/UX hardening

- support/analytics/crash top issues
- onboarding/invite/reminder friction
- no uncontrolled scope expansion

### WP08-03 Performance/capacity

- representative/large seed
- Today/query/index/profile
- low-memory/startup/binary size
- queue/webhook burst

### WP08-04 Upgrade/migration

- previous build → RC update
- local cache schema
- old/new client with migrated DB
- mandatory update/kill switch

#### WP08-04A Android server-authoritative runtime policy — PARTIAL (2026-08-09)

- dev/prod Android 최소 build·contract와 emergency 전역 non-privacy mutation switch를 private policy, exact public read, service-only versioned audit mutation으로 구현
- direct authenticated mutation과 allowlisted compatibility header를 전달하는 Edge user operation을 DB trigger가 권위 있게 차단하고, 읽기·offline cache·export/delete/legal/support/diagnostics는 유지
- 앱 initial/retry/foreground refresh, EN/KO/EN-XA read-only/update banner와 provider/network/store I/O 전 advisory guard를 로컬 자동 검증
- hosted dev/prod propagation, N-1 signed binary, Play staged rollout·rollback, 실제 계정·다중기기·실기기는 **NOT RUN**이며 WP08-04/G8 완료가 아님

#### WP08-04B Capability-specific runtime mutation policy — PARTIAL (2026-08-09)

- household, chores, calendar, notifications, profile, billing을 exact six-row policy와 30개 명시적 table→feature trigger로 독립 제어하고 compatibility-open seed·expected-version·correlation replay·immutable audit를 구현
- global update/read-only 우선순위, direct/Edge-forwarded user operation의 DB-authoritative `KFR06`, markerless service/worker와 privacy/export/delete 보존, transaction 내 기능 간 cache 격리를 로컬 검증
- Flutter strict six-feature snapshot, 모든 mutation notifier의 exact family guard, 다른 기능과 읽기를 유지하는 EN/KO/EN-XA partial-read-only banner를 구현
- cohort/percentage/per-account targeting, hosted operator 전파·모니터링·rollback drill, 실제 계정·다중기기·실기기는 **NOT RUN**이며 WP08-04/G8 완료가 아님

### WP08-05 Backup/recovery

- isolated restore
- RPO/RTO measurement
- recurrence/entitlement/RLS integrity
- worker replay

### WP08-06 Security/incident audit

- threat review
- incident tabletop
- notification/billing/RLS drills
- support access audit

### WP08-07 RC audit

- traceability/evidence
- known issue/risk acceptance
- Store metadata/privacy screenshots
- signed staging candidate

## 자동 검증

full regression matrices, load/performance scripts, upgrade tests, restore verification, dependency/security scan.

## 수동 검증

real family end-to-end, actual devices/tablets, sandbox billing, push, accessibility, recovery/tabletop.

## Exit Gate

- Beta success threshold 충족
- blocker/critical 0
- SLO/alert/runbook 준비
- signed RC candidate
- backup/restore and rollback drill
- launch decision review 승인

## Stop

retention/value 기준 미달, privacy/security risk, entitlement mismatch, unrecoverable migration이면 출시하지 않고 제품/기술 decision으로 돌아간다.
