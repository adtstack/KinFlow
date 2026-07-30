# Phase 02 WP02-05 Evidence

- Work Package: WP02-05 Role/Owner lifecycle
- 기준 commit: base `2b68351`; implementation `c6dc075`; automated validation `6a23ed9`
- 기록일: 2026-07-30
- 결과: **AUTOMATED PASS / LIVE GOOGLE + TWO-DEVICE GATE PENDING / NOT COMPLETE**

## Requirement Status

| ID | 상태 | 현재 증거 |
|---|---|---|
| FR-AUTH-006 | IN PROGRESS | refresh-only/wrong-user/expired/fresh OAuth `amr`와 credential redaction 자동 계약이 통과했다. hosted Google 실제 계정, account deletion/payment 적용은 남아 있다. |
| FR-HH-006 | IN PROGRESS | Owner/Admin 역할 matrix, expected version, 멱등 replay/reuse와 immutable audit를 DB 64개·Edge 18개·Flutter 테스트에서 검증했다. 실제 성인 2계정 검증은 남아 있다. |
| FR-HH-007 | IN PROGRESS | remove/leave tombstone, 즉시 RLS 차단, active-household fallback과 생성자 invite revoke transaction이 로컬 PostgreSQL에서 통과했다. device registration은 Phase 05 범위다. |
| FR-HH-008 | IN PROGRESS | Owner 왕복 이전에서 정확히 한 Owner, pointer, version, replay를 로컬 PostgreSQL에서 검증했다. 실제 Google re-auth와 2기기 이전은 남아 있다. |
| API-009/010 | IN PROGRESS | outsider/role/version/idempotency 오류와 stable Edge mapping이 clean reset, pgTAP와 Edge unit contract에서 통과했다. hosted Edge 검증은 남아 있다. |

## Implementation Inventory

- `20260729000000_household_member_lifecycle.sql`
  - 최소 roster projection
  - private typed idempotency result와 PII 없는 immutable audit event
  - role change, remove, leave, Owner transfer service-only RPC
  - active household fallback, active invite revoke와 정확히 한 active Owner 확인
- `manage-household-members`
  - exact JSON/body/header validation과 stable response envelope
  - bearer user 재검증과 role/Owner action용 별도 recent-auth JWT 재검증
  - access-token `iat`/`token_refresh`를 인정하지 않고 10분 이내 OAuth `amr`만 허용
- Flutter
  - recent Google authentication service와 account mismatch 차단
  - SDK-independent member domain/repository/controller
  - strict generated DTO parse와 command-response correlation 검증
  - `/family/members` roster, role change, removal, leave와 Owner transfer 확인 UI
  - EN/KO/pseudo ARB와 generated localization

## Automated Validation Results

모든 로컬 명령은 Flutter SDK 3.44.7 / Dart 3.12.2, Node 24.15.0과 잠금파일 기준으로 2026-07-30 실행했다.

| Gate | 실제 결과 |
|---|---|
| `scripts/ci/flutter-quality.sh` | PASS — Node contract 47, Flutter 201 pass/1 live-only skip, analyzer 0, format/codegen drift 0, line coverage 73.47% (2,971/4,044) |
| `scripts/ci/supabase-backend.sh` | PASS — clean DB reset, 5 migrations apply, schema lint 0, pgTAP 271/271, invite Edge 22/22, member lifecycle Edge 18/18, invite live contract와 Flutter local adapter |
| dependency/license | PASS — Pub 149개, npm 15개 license allowlist |
| offline OSV | PASS — lockfile-only actual dependency scan, known vulnerability 0 |
| Android dev debug | PASS — commit `6a23ed9`, source `clean`, 216,192,138 bytes, SHA-256 `f3d8ecfed08b118287953395d4b9a94abb65fcfd9d146767814b5280fcbea349` |
| Android prod debug | PASS — commit `6a23ed9`, source `clean`, 216,192,104 bytes, SHA-256 `e16b074eed3df4f1b535582b41a69bf119ae6b0b25def67c309f29c5c50e555f` |

Android 두 flavor 모두 package/label, compile/target API 36, min API 24, `allowBackup=false`, HTTPS App Link `autoVerify`, 최소 권한 allowlist와 source provenance 감사를 통과했다.

아래 live/release 검증은 기존 합의대로 **NOT RUN**이다.

- 실제 Google 계정 로그인과 hosted Supabase OAuth `amr` shape
- 실제 성인 2계정·Android 2기기 Owner 이전/제거/재진입
- production Supabase migration/Edge 배포
- GitHub Actions 원격 CI — 이 evidence commit을 push한 뒤 별도로 확인한다.

## Security / Privacy Boundary

- 최근 인증 JWT는 전용 value object와 request header에서만 사용하며 log, audit, DTO 결과와 오류에 넣지 않는다.
- roster는 auth user ID를 반환하지 않고 active 구성원의 display name, role, version과 self marker만 반환한다.
- audit는 UUID actor/target/correlation, action/result/version/time만 저장하며 email, token, JWT와 자유문장을 저장하지 않는다.
- removed/left membership은 삭제하지 않아 미래 공동 기록의 historical FK를 보존하되, `removed_at` 즉시 RLS 접근 근거에서 제외한다.
- 현재 persistent household cache와 device registration table은 없다. remote device-token cleanup은 해당 table을 도입하는 Phase 05에서 이 lifecycle에 연결해야 한다.

## Remaining Risks

1. hosted Supabase JWT의 실제 Google OAuth `amr`와 재로그인 UX는 실제 계정에서 확인되지 않았다.
2. removal 직후 원격 기기의 이미 그려진 메모리 화면은 다음 navigation/network refresh 전까지 남을 수 있다. 권위적 read/write의 즉시 RLS 차단은 자동 검증했지만 실기기 화면 잔존은 확인해야 한다.
3. Android 빌드는 미래 Flutter에서 `sentry_flutter`의 Kotlin Gradle Plugin 적용 방식이 차단될 수 있다는 비차단 경고를 냈다. Flutter 업그레이드 전 호환 버전을 재평가한다.
4. chore/calendar assignment table이 아직 없으므로 향후 schema는 removed member historical reference 보존과 active-only 새 assignment 정책을 별도로 검증해야 한다.

## Rollback

- remote 적용 전: WP02-05 implementation commit을 revert한다.
- remote 적용 후: migration을 수정·삭제하지 않고 command/helper/constraint를 교정하는 forward migration과 Edge rollback deploy를 사용한다.

## Completion Boundary

자동 검증 배치는 PASS다. 그러나 Work Plan이 요구한 실제 Google 성인 2계정·Android 2기기 live gate는 남아 있으므로 WP02-05는 IN PROGRESS다. 원격 CI와 live gate가 모두 green이고 그 결과가 추가될 때만 COMPLETE/PASS로 바꾼다.
