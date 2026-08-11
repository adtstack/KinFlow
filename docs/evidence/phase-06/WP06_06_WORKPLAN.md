# Phase 06 WP06-06 Lifecycle and Feature Enforcement Workplan

- 상태: `LOCAL IMPLEMENTED (2026-08-08)`
- 범위: entitlement lifecycle client policy, versioned feature-enforcement activation, safe household gate projection, active member와 recurring chore/calendar capacity의 authoritative mutation wiring, downgrade data preservation
- 제외: D-027 실제 Free/Plus 숫자 결정, 가격·trial·annual discount, Store/RevenueCat 계정, paywall, hosted policy rollout, sandbox/실기기

## Entry Decision

- WP06-01은 lifecycle materialization과 fail-closed capacity primitive를 제공하지만 downstream mutation은 아직 제한하지 않는다. WP06-06은 그 authority를 실제 member/recurring creation에 연결한다.
- D-027은 OPEN이다. migration/Flutter에는 수치 한도를 추가하지 않으며 service가 Free와 Plus 정책을 모두 finalized한 뒤 별도 versioned command로 activation해야만 mutation enforcement가 켜진다.
- activation 전 client gate는 `policy_unavailable`로 fail closed해 임의 숫자를 표시하지 않는다. 기존 기능 개발을 막지 않도록 server mutation enforcement 자체는 비활성 상태이며 billing ingestion도 기존대로 disabled다.
- activation 후 member/recurring creation은 household+feature advisory transaction lock으로 직렬화한다. client-side count와 cached Plus 상태는 authority가 아니다.
- downgrade/expiry/refund/revoke는 기존 shared data를 삭제하지 않는다. limit은 새 member와 새/reactivated recurring series만 막고 read/update/cancel/delete 및 one-time creation은 보존한다.

## Acceptance Contract

- service-only activation은 expected runtime version과 correlation ID를 요구하고 immutable billing policy audit를 남긴다.
- activation은 active Free/Plus catalog가 모두 finalized이고 `members`, `activeSeries`를 포함하며 member capacity가 최소 1일 때만 허용한다.
- enabled 상태에서 plan을 unfinalized하거나 필수 key를 제거할 수 없다. emergency disable은 허용한다.
- authenticated active member는 `get_household_feature_gate(household, feature, requestedDelta)`의 aggregate projection만 읽는다.
- gate outcome은 `allowed | policy_unavailable | feature_unconfigured | limit_reached`이고 provider/customer/transaction/owner/member identity 또는 family content를 포함하지 않는다.
- `members` usage는 removed member를 제외한다. `activeSeries` usage는 active revision이 recurring인 chore/event series만 합산하며 one-time series는 제외한다.
- actual member insert와 first recurring revision insert/reactivation은 같은 server capacity function을 호출한다. concurrent requests도 최종 limit을 초과할 수 없다.
- Flutter는 exact gate payload를 provider-neutral domain으로 매핑하고 unfinalized/missing/limit 상태를 fail closed한다.
- lifecycle policy는 trialing/active/grace/billing_issue/expired/revoked를 구분하고 plan과 server limit projection을 넘어서 권한을 추정하지 않는다.
- chore/calendar/invite mutation은 server `KFB10/KFB11/KFB12`를 stable policy-unavailable/limit-reached UX failure로 표시한다.

## Test Plan

- default disabled/unfinalized projection, invalid feature/delta/auth/membership denial
- activation version conflict, incomplete plan rejection, immutable audit, enabled-policy downgrade protection, emergency disable
- one-time rows excluded, recurring chore/event usage exact, removed members excluded
- actual member/recurring mutation at capacity, safe update/delete/cancel behavior, existing over-limit data preservation
- advisory-lock concurrency one-winner at the last capacity slot
- Flutter lifecycle policy for every status, strict gate parser/repository/failure mapping and localized UX mapping
- focused/full pgTAP, Flutter, JavaScript, analyzer/formatter/lint/config/secret/codegen/YAML/matrix/whitespace gates

## Completion Boundary

- policy-neutral activation → aggregate gate projection → server-enforced member/recurring mutation → stable client failure/lifecycle policy가 local automation으로 실행되면 `WP06-06 LOCAL IMPLEMENTED`다.
- D-027 numeric policy와 provider/Store/account/device validation이 없으므로 Phase 06 Exit Gate와 FR-SUB-006은 계속 `PARTIAL`이다.
