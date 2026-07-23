# Phase 02 — 인증, 가구, 성인 구성원

## 목표

성인 사용자가 로그인하고 가구를 만들거나 안전한 초대로 가입하며, 역할·Owner 경계를 RLS와 서버 transaction으로 보호한다.

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

### WP02-06 Adult activation handoff

- 초대 수락 후 성인 membership과 active household 확정
- 빈 Today와 첫 집안일 생성으로 이어지는 handoff
- 두 번째 성인의 첫 독립 행동 event 계약
- Managed Child table/route/acting context는 만들지 않고 `FR-CHILD-*`를 P1로 유지

### WP02-07 End-to-end authorization

- outsider/different household/removed/service-role tests
- body/path household injection
- direct CRUD RPC bypass

## 자동 검증

- full Phase 02 RLS matrix
- auth repository/use case/widget tests
- invite concurrency/idempotency/rate limit
- route guard와 account/household switch purge
- migration clean reset

## 수동 검증

- two real accounts/two devices create-invite-accept
- cold-start invite link iOS/Android
- owner transfer/removal
- 두 번째 성인의 초대 수락 후 독립 재진입
- account switch data purge

## Exit Gate

- 두 성인이 같은 가구에 참여 가능
- household isolation 공격 test pass
- 마지막 Owner invariant
- auth/invite deep links 실제 기기 pass

## Stop/Rollback

권한 누출, token replay, cache 잔존 시 다음 Phase 금지. feature flag로 invite를 비활성화하고 migration은 forward fix한다. P1 child surface는 Store MVP에서 존재하지 않아야 한다.
