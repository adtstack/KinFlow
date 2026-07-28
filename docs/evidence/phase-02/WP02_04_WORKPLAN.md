# Phase 02 WP02-04 Work Plan

- 작성일: 2026-07-28
- 기준 commit: `0efd97a`
- Work Package: WP02-04 Invite
- 상태: COMPLETE
- 선행 결과: WP02-03 implementation run `30372425851`와 evidence run `30373219128` 모두 final CI gate PASS

## Requirements

| ID | 이번 vertical slice |
|---|---|
| WP02-04 | random token hash, expiry/revoke/use/rate limit, Android App Link route, login 전후 continuation과 concurrent/idempotent accept를 구현한다. |
| FR-HH-003 | 최소 256-bit random link token을 생성 응답에서만 제공하고 DB에는 SHA-256 hash, expiry, revoke와 single-use 상태만 저장한다. |
| FR-HH-004 | 짧은 코드는 선택 기능으로 보존한다. 이번 Android 성인 2인 slice에서는 link token이 권위자이며 nullable short-code schema만 유지한다. |
| FR-HH-005 | 로그인 전 최소 preview와 로그인 후 transaction/idempotent accept를 제공한다. |
| FR-AUTH-004 | invite intent를 process memory에만 보관하고 인증 전후 원래 초대로 복귀한다. |
| API-004~008 | valid/minimal preview, expired/revoked, brute-force rate limit, concurrent accept와 target-email mismatch를 자동 검증한다. |
| D-015/D-017 | 고엔트로피 링크를 사용하고 create/preview/accept/revoke는 온라인 전용이다. |
| D-016/D-048/D-049 | 기존 active household가 있으면 명시적 전환 확인을 요구하고 mutation 멱등성 및 account/logout purge를 보장한다. |

## Server Contract

1. forward-only migration에 `household_invites`, private idempotency/rate-limit record와 service-only command RPC를 추가한다.
2. raw token은 Edge의 Web Crypto CSPRNG로 만들고 SHA-256 hash만 RPC/DB에 전달한다. token, email과 client IP 원문은 table·log·error에 남기지 않는다.
3. create는 access token을 서버에서 검증하고 DB에서 Owner/Admin membership을 다시 계산한다. client role과 creator/member ID는 받지 않는다.
4. preview는 unauthenticated Edge endpoint만 공개하며 IP fingerprint rate limit 후 household name, inviter display name, role과 expiry만 반환한다.
5. accept는 invite row를 lock하고 auth identity/target-email/profile을 확인한 뒤 membership, use count/status와 active selection을 한 transaction으로 변경한다.
6. 동일 idempotency key/request와 동일 수락자의 replay는 같은 invite/member 결과를 반환한다. key 재사용, 다른 사용자의 double accept와 동시 race는 stable conflict다.
7. revoke는 Owner/Admin server command로 active invite만 회수하며 이후 preview/accept가 `INVITE_REVOKED`로 실패한다.
8. public/anon/authenticated에는 direct insert/update/delete 또는 command RPC execute를 허용하지 않는다. invite metadata select는 Owner/Admin만 허용한다.

## Edge Contract

- `create-invite`, `preview-invite`, `accept-invite`, `revoke-invite`를 pinned Deno runtime에서 제공한다.
- exact CORS allowlist, POST JSON/body limit, UUID request ID, auth verification, idempotency header, stable success/error envelope와 `no-store`를 공통 적용한다.
- service-role credential은 Edge environment에서만 읽고 client response, Flutter config와 test artifact에 포함하지 않는다.
- endpoint core는 dependency-injected contract test로 malformed body, auth, redaction, raw-token one-time response와 SQLSTATE mapping을 검증한다.
- local Edge live test는 공개 invalid preview를 호출해 배포 경로와 DB adapter가 실제로 연결되는지 확인한다.

## Flutter Vertical Slice

1. household invite domain/application/data/presentation을 SDK-independent 경계로 추가한다.
2. external Edge JSON은 generated DTO로 parse한 뒤 domain entity로 변환하며 malformed payload는 fail-closed 한다.
3. `/family/invite`에서 Owner가 single-use member invite를 만들고 copyable HTTPS link를 한 번 표시한다.
4. `/invite/:token`은 token을 ephemeral store에 캡처한 즉시 주소를 `/invite`로 scrub하고 public preview를 불러온다.
5. 미로그인 수신자는 safe continuation marker로 sign-in에 갔다가 `/invite`로 돌아온다. raw token은 query parameter, persistent storage, analytics와 logs에 넣지 않는다.
6. 로그인 사용자는 수락한다. 이미 active household가 있으면 명시적 switch confirmation 없이는 mutation을 보내지 않는다.
7. 성공 시 server result로 active household를 갱신하고 token을 clear한 뒤 `/today`로 이동한다.
8. logout/account switch purge participant가 pending invite memory를 제거한다.

## Android Link Surface

- HTTPS `/invite/*` intent filter와 `singleTop` cold/warm route surface를 추가한다.
- 현재 설정의 `AUTH_REDIRECT_HOST` placeholder를 build-time manifest placeholder와 일치시킨다.
- 실제 소유 도메인, `assetlinks.json`, prod signing SHA와 실제 기기 verified-link 증거는 4단계 통합 전까지 완료로 선언하지 않는다.

## Validation

- clean reset, schema lint와 기존 136개 DB test 회귀
- invite table RLS/grants, service-only commands, token/hash/email/IP redaction
- create role/injection/idempotency/rate limit/expiry bounds/revoke
- preview valid/minimal/invalid/expired/revoked/rate limit
- accept target email/profile, atomic membership/use/selection, replay/concurrent winner
- Edge middleware/error-envelope/unit contract와 local live preview
- Flutter repository/controller/route/link capture/continuation/purge/widget/a11y/localization tests
- 200% text, EN/KO/pseudo, raw provider error 미노출
- full Flutter quality, dependency audit, backend gate, dev/prod APK와 GitHub final gate

## Explicit Non-scope

- short-code 사용자 UI와 short-code 발급
- invite 관리 목록, resend, bulk/multi-use invite와 email delivery
- role change/removal/leave/Owner transfer — WP02-05
- real Google provider/account, owned HTTPS domain/assetlinks, signed release와 Android physical-device verification — 4단계 통합
- production Supabase migration/deploy와 real customer data
- Managed Child, guardian, acting context — P1

## Stop / Rollback

- raw token/email/IP가 DB·log·telemetry에 남거나 direct client RPC/CRUD bypass가 가능하면 다음 단계로 진행하지 않는다.
- concurrent accept가 두 membership/use side effect를 만들거나 revoked/expired invite가 수락되면 중단한다.
- invite intent가 logout/account switch 뒤 남거나 active household가 사용자 확인 없이 바뀌면 중단한다.
- remote 적용 전 rollback은 WP02-04 feature commit revert와 clean reset이다. remote 적용 후 migration은 수정·삭제하지 않고 forward fix한다.

## Next Entry Condition

- local/remote automated gates와 evidence가 green이어야 4단계 Google 로그인/Android 성인 2인 통합으로 진입한다.
- 실제 도메인·provider·device 증거가 없으면 WP02-04 automated completion과 Phase 02 Exit Gate를 구분한다.
