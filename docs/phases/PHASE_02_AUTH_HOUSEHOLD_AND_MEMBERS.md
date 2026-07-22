# Phase 02 — 인증, 가구, 구성원, Managed Child

## 목표

성인 사용자가 로그인하고 가구를 만들거나 안전한 초대로 가입하며, 역할·Owner·Managed Child 경계를 RLS와 서버 transaction으로 보호한다.

## Entry

Foundation Gate 통과, auth provider/redirect/domain 준비.

## Work Packages

### WP02-01 Auth lifecycle

- sign-in/request/callback/logout/session restore
- secure storage
- auth state machine와 router guard
- offline/expired/revoked session
- account switch purge

### WP02-02 Household schema/RLS

- household/membership/profile migration
- Owner/Admin/Member policies
- composite household integrity
- RLS matrix initial automation

### WP02-03 First household onboarding

- transactional household + owner membership
- name/timezone
- active household state
- empty Today route

### WP02-04 Invite

- random token hash, expiry/revoke/use/rate limit
- Universal/App Link
- login 전후 continuation
- concurrent/idempotent accept
- invite abuse tests

### WP02-05 Role/Owner lifecycle

- admin/member changes
- last owner invariant
- owner transfer
- removed member session/cache/device cleanup
- audit events

### WP02-06 Managed Child

- guardian-managed profile
- parental gate and mode
- allowed action skeleton
- acting audit
- restricted routes/analytics

### WP02-07 End-to-end authorization

- outsider/different household/removed/managed/service-role tests
- body/path household injection
- direct CRUD RPC bypass

## 자동 검증

- full Phase 02 RLS matrix
- auth repository/use case/widget tests
- invite concurrency/idempotency/rate limit
- route guard/child mode
- migration clean reset

## 수동 검증

- two real accounts/two devices create-invite-accept
- cold-start invite link iOS/Android
- owner transfer/removal
- child mode entry/timeout/exit
- account switch data purge

## Exit Gate

- 두 성인이 같은 가구에 참여 가능
- household isolation 공격 test pass
- 마지막 Owner invariant
- managed child에 auth identity 없음
- auth/invite deep links 실제 기기 pass

## Stop/Rollback

권한 누출, token replay, cache 잔존 시 다음 Phase 금지. feature flag로 invite/child mode를 비활성화하고 migration은 forward fix한다.
