# Phase 02 WP02-04 Evidence

- Work Package: WP02-04 Secure adult household invitations
- 기준 commit: base `0efd97a`; implementation `1ad1a9c`
- 검증일: 2026-07-28
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 28.3.2
- 결과: **LOCAL + REMOTE AUTOMATED PASS / GOOGLE·OWNED DOMAIN·ANDROID DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP02-04 | PASS FOR AUTOMATED SLICE | hashed single-use invite, create/preview/accept/revoke Edge commands, Android link route와 login continuation을 구현했다. |
| FR-HH-003 | PASS | Web Crypto 256-bit token은 create 응답에서 한 번만 제공하고 DB에는 SHA-256 hash, expiry, revoke와 use 상태만 저장한다. |
| FR-HH-004 | PARTIAL AS PLANNED | nullable short-code hash 계약은 보존하되 link token만 구현했다. short-code 발급·UI는 명시적 non-scope다. |
| FR-HH-005 | PASS WITH SYNTHETIC AUTH | 공개 preview는 최소 display field만 반환하고 authenticated accept는 membership/use/active selection을 한 transaction으로 처리한다. |
| FR-AUTH-004 | PASS WITH SYNTHETIC AUTH | `/invite/:token`을 process-memory store에 캡처한 즉시 `/invite`로 scrub하고 로그인에는 `continue=invite`만 전달한다. |
| API-004~008 | PASS | valid/invalid/expired/revoked/rate-limit, target-email, same-key retry와 concurrent single winner를 자동 검증했다. |
| D-015/D-017 | PASS | 고엔트로피 HTTPS link이며 create/preview/accept/revoke는 online-only다. |
| D-016/D-048/D-049 | PASS | 기존 active household 전환 확인, mutation idempotency, logout/account-bound token purge를 검증했다. |

## Implementation

- `20260728020000_household_invites.sql`은 hash-only invite table, private idempotency/rate-limit table과 service-role-only create/preview/accept/revoke RPC를 추가한다.
- Edge가 bearer session을 Auth에서 검증하고 DB가 membership/role/target email/profile을 다시 계산한다. client user/member/creator role은 권한 근거로 받지 않는다.
- invite row lock과 advisory idempotency lock으로 단일 사용, concurrent winner와 same-key replay를 보장한다. 다른 사용자 replay는 `INVITE_ALREADY_USED`다.
- public preview는 rate-limit 후 household name, inviter display name, role과 expiry만 반환한다. 모든 응답은 stable envelope, `no-store`, exact CORS와 body limit을 사용한다.
- Flutter는 SDK-independent domain/application, generated DTO boundary, Supabase Edge adapter, secure command UUID와 ephemeral token store로 구성된다.
- sender는 `/family/invite`에서 optional target email의 7일 member link를 한 번 확인·복사·취소할 수 있다.
- receiver는 scrubbed `/invite`에서 preview를 보고 로그인 뒤 수락한다. 기존 active household가 있으면 checkbox 확인 전 accept action이 비활성화된다.
- Android manifest는 HTTPS `/invite/*`, `VIEW`, `BROWSABLE`, `autoVerify=true`를 포함하며 dev/prod APK audit가 merged manifest를 확인한다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean `supabase db reset` | PASS, ordered forward migrations 4개와 synthetic seed 적용 |
| schema lint warning gate | PASS, application schema issue 0 |
| pgTAP/RLS | PASS, WP02-04 71 + predecessor 136 = 207 tests |
| Edge unit contract | PASS, 22 tests; auth/idempotency/CORS/body/rate/error/redaction/one-time token |
| Edge live contract | PASS, public minimal preview, invalid 404, two-user concurrent single winner, same-user same-key replay |
| Flutter quality | PASS, 155 tests + 1 opt-in live skip, analyze issue 0, coverage 2,283/2,966 (76.97%) |
| route/widget/accessibility | PASS, token scrub, continuation, no-household accept, explicit switch, create/revoke, EN/KO/pseudo와 200% text |
| config / secret / codegen | PASS, high-confidence secret 0, generated drift 0 |
| dependency license / OSV | PASS, Pub 143 / npm 15, known vulnerability 0 |
| Android APK audit | PASS, dev/prod package IDs, API 24/36, backup disabled, exact permission allowlist와 placeholder App Link |
| GitHub Actions CI | PASS, run `30377570031`; quality, dependency, backend, dev/prod Android와 final gate 성공 |

상세 실행 요약은 `logs/wp02-04-secure-household-invites.log`에 있다. CI report, APK와 coverage 원본은 ignored local artifact다.

Remote run: <https://github.com/adtstack/KinFlow/actions/runs/30377570031>

## Data / API / Privacy

- production Supabase project에는 migration/function을 배포하지 않았고 실제 사용자, email, credential과 customer data를 사용하지 않았다.
- DB에는 raw token, raw email과 client IP가 없으며 token/email/rate keys는 32-byte digest다. idempotency request도 normalized hash만 보관한다.
- raw token은 generated DTO와 error/log payload에서 분리했다. domain/data diagnostic string은 redacted이며 route query, persistent storage와 telemetry에 넣지 않는다.
- anon/authenticated client는 command RPC와 invite mutation table을 직접 실행하거나 수정할 수 없다. metadata read는 same-household Owner/Admin RLS만 허용한다.
- 새 runtime package나 Android permission은 추가하지 않았다.

## Manual / Deferred Validation

- 실제 Google provider/account와 Android 성인 2인 sign-in/accept는 사용자 결정에 따라 Phase 02 마지막 통합 단계까지 **DEFERRED**다.
- `AUTH_REDIRECT_HOST`와 manifest host는 아직 `auth.example.invalid`이다. owned HTTPS domain, `assetlinks.json`, prod signing SHA와 Android verified-link는 **NOT RUN**이다.
- Android cold/warm intent, browser-to-app handoff, process death와 clipboard/share 동작은 실제 기기 증거가 없으므로 **NOT RUN**이다.
- production Supabase migration/function deploy, backup/restore와 remote rate-limit 운영 관측은 **NOT RUN**이다.

## Remaining Risks / Completion Boundary

1. placeholder domain은 APK contract만 검증하며 OS verified App Link를 성립시키지 않는다.
2. Google sign-in launcher가 아직 unavailable이므로 real receiver가 로그인 후 수락하는 end-to-end 경로는 Stage 4에서 닫아야 한다.
3. short-code 발급/UI, invite 관리 목록과 email delivery는 구현하지 않았다.
4. role change/removal/Owner transfer는 WP02-05 계약으로 남아 있다.
5. `sentry_flutter`의 legacy Kotlin Gradle Plugin warning은 현재 build를 막지 않지만 향후 Flutter upgrade 전에 dependency review가 필요하다.

## Rollback

- production 적용 전에는 implementation commit `1ad1a9c`를 revert하고 clean reset으로 WP02-03 상태를 확인한다.
- production 적용 후에는 이 migration을 수정·삭제하지 않고 function/constraint를 교정하는 forward migration을 추가한다.

## Next Entry Condition

- implementation commit `1ad1a9c`의 GitHub Actions 5개 foundation job과 final gate가 모두 green이다.
- 다음 순차 작업은 Stage 4 Google provider + owned Android App Link + 실제 성인 2인 기기 통합이다.
- 실제 provider/domain/device evidence가 없으므로 WP02-04 automated completion을 Phase 02 Exit Gate 완료로 간주하지 않는다.
