# Phase 09 — Store 출시와 출시 후 운영

## 목표

iOS/Android 앱을 정책에 맞게 제출하고 점진 배포하며, 초기 30일 동안 제품·신뢰성·구독 지표를 안정화한다.

## Entry

Beta Exit Gate와 release decision 승인.

## Work Packages

### WP09-01 Production readiness

- production secrets/projects/products
- DB migration/backup
- dashboards/alerts/on-call
- feature flags/kill switch

### WP09-02 Signed build/submission

- clean reproducible IPA/AAB
- checksum/SBOM/provenance
- metadata/screenshots/review account
- Apple/Google policy current check
- Fastlane upload + human review

### WP09-03 Review handling

- reviewer notes
- auth/purchase/delete test path
- rejection evidence and narrow fix
- no unreviewed production behavior

### WP09-04 Staged rollout

- internal/1-5%/10-25%/50%/100%
- crash/auth/Today/mutation/push/billing/support check
- pause/rollback criteria

### WP09-05 72-hour review

- severe incident/security/privacy
- Store reviews/support
- entitlement/notification mismatch
- emergency fix decision

### WP09-06 2-week/30-day review

- activation/retention/paid conversion/refund
- top friction and defect
- SLO/cost/capacity
- roadmap and Web Companion decision

## 자동 검증

production smoke/synthetic, rollout dashboards, store receipt/webhook, migration compatibility.

## 수동 검증

production purchase/restore controlled account, deep link/invite, push, delete/export, support flow, Store listing.

## Exit Gate

30-day review에서 모바일 제품과 운영이 안정화되고, 후속 제품 투자와 Web Companion Gate를 데이터로 결정한다.

## Rollback

rollout pause, server feature flags, previous compatible binary, worker/webhook controls, customer communication과 remediation.
