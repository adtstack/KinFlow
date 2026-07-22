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
