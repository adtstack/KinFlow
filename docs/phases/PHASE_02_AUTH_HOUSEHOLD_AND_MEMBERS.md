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

### WP02-08 Active household switching

- 본인 current adult membership만 반환하는 최소 가구 목록
- server-derived target member와 optimistic selection version 기반 전환
- Settings 확인 UI와 성공 후 authoritative Today reload
- 전환 전 encrypted read cache, guided resume, pending invite 정리
- local purge/write 실패 시 `localPurgeFailed`로 content fail closed
- Managed Child/acting context는 추가하지 않음

### WP02-09 Household departure handoff

- 기존 leave transaction의 nullable fallback household/member pair를 strict domain result로 보존
- fallback/no-household 모두 이전 가구 read cache, guided resume와 pending invite를 먼저 정리
- 별도 refresh 없이 auth active-household 또는 no-household 상태를 직접 commit
- local purge/write/clear 실패 시 departed roster와 protected content를 `localPurgeFailed`로 닫음
- 기존 Owner transfer-first와 Managed Child 비범위를 유지

### WP02-10 Google identity conflict safe recovery

- 상태: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-09)**
- Supabase Auth의 exact `email_exists`, `identity_already_exists`, `user_already_exists` 코드만 provider-neutral `IDENTITY_CONFLICT`로 분류
- 자동 identity link/merge 없이 conflict 뒤 Google local account selection만 best-effort 초기화
- 로그인 화면에서 다른 Google 계정 명시적 재시도와 fixed configured support 경로 제공
- raw provider/email/identity 비노출, EN/KO/EN-XA와 compact 200% text 자동 검증
- hosted identity policy, 실제 충돌 계정·다중기기·실기기는 마지막 통합 Gate로 유지

### WP02-11 Privacy-safe invite sharing

- 상태: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-09)**
- raw-once invite token을 redacted value object의 exact configured HTTPS `/invite/{token}`으로만 구성
- 사용자 명시 동작 뒤 Android `ACTION_SEND` `text/plain` chooser를 열고 native에서도 host/path/token canonical URL을 재검증
- 공유 성공은 전달 완료가 아니라 chooser-open으로만 표현하며 unavailable/failure 뒤 자동 복사 없이 별도 write-only 링크 복구 제공
- 링크·보조 코드 copy single-flight, clipboard retention 고지, stable live region과 EN/KO/EN-XA compact 200% 자동 검증
- DB/API/storage/permission/새 SDK 변경 없음; 실제 share sheet·recipient·verified App Link·다중기기·실기기는 마지막 통합 Gate로 유지

### WP02-12 Email OTP authentication

- 상태: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-09)**
- trim·lowercase한 email과 exact 6자리 ASCII OTP, 10분 만료·60초 재전송 제한·성공 후 재사용 차단을 process-memory challenge로 구현
- Supabase `signInWithOtp(shouldCreateUser: true)`와 `verifyOTP(type: email)`을 provider-neutral 계층에 연결하고 strict matching session/user UUID를 기존 auth state stream으로 인계
- 계정 존재 여부·identity conflict는 request 단계에서 generic accepted로 축약하고 client link/merge, email/code persistence·logging·analytics와 raw provider 오류 노출을 금지
- EN/KO/EN-XA compact 200%, autofill, 48dp action과 local Mailpit bilingual token-only template·synthetic session/reuse/rate-limit을 검증
- hosted SMTP·identity policy, 실제 mailbox/account·다중기기·Android autofill/TalkBack은 마지막 통합 Gate로 유지

### WP02-13 App-shell session resume revalidation

- 상태: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)**
- authenticated app shell root 하나가 Android/Web foreground resume에서만 provider session을 single-flight로 재검증하고, flight 중 중복 resume은 최대 한 번의 trailing refresh로 합침
- 동일 사용자·동일 active household·동일 cache provenance는 transient auth state를 발행하지 않아 화면별 resume refresh와 repository 구독을 중복 재시작하지 않음
- authoritative household 변경·탈퇴·신규 선택은 household-bound local state를 purge/replace한 뒤에만 새 context를 노출하고, transition 실패는 `localPurgeFailed`로 잠금
- 만료·회수·세션 부재·provider failure와 account switch는 기존 full sensitive-state purge 및 route fail-close 계약을 재사용
- DB/API/storage/dependency/permission/telemetry 변경 없음; hosted Supabase·실계정·다중 tab/device·Android process·Web BFCache·실기기는 마지막 통합 Gate로 유지

## 자동 검증

- full Phase 02 RLS matrix
- auth repository/use case/widget tests
- invite concurrency/idempotency/rate limit
- route guard와 account/household switch purge
- root foreground session single-flight, unchanged-context 무중단 유지와 authoritative household drift 격리
- active household same-target replay, stale conflict와 switch-back
- migration clean reset

## 수동 검증

- two real accounts/two devices create-invite-accept
- cold-start invite link Android
- owner transfer/removal
- 두 번째 성인의 초대 수락 후 독립 재진입
- account switch data purge
- 실제 session expiration/revocation, 다중 tab/device와 background/BFCache resume

## Exit Gate

- 두 성인이 같은 가구에 참여 가능
- household isolation 공격 test pass
- 마지막 Owner invariant
- auth/invite deep links 실제 기기 pass

## Stop/Rollback

권한 누출, token replay, cache 잔존 시 다음 Phase 금지. feature flag로 invite를 비활성화하고 migration은 forward fix한다. P1 child surface는 Store MVP에서 존재하지 않아야 한다.
