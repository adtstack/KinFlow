# Phase 02 WP02-05 Evidence

- Work Package: WP02-05 Role/Owner lifecycle
- 기준 commit: base `2b68351`; implementation `c6dc075`
- 기록일: 2026-07-29
- 결과: **IMPLEMENTATION PRESENT / ALL VALIDATION DEFERRED BY USER / NOT PASS**

## Requirement Status

| ID | 상태 | 현재 증거 |
|---|---|---|
| FR-AUTH-006 | IN PROGRESS | Google 재인증 service와 Supabase JWT `amr` OAuth timestamp 검증 경계를 구현했다. account deletion/payment 적용과 실제 계정 검증은 남아 있다. |
| FR-HH-006 | IN PROGRESS | Owner/Admin 역할 matrix, expected member version, 멱등 command와 immutable audit 구현이 존재한다. 실행 검증은 하지 않았다. |
| FR-HH-007 | IN PROGRESS | remove/leave tombstone, RLS 차단 기반, active household fallback과 생성자 invite revoke를 한 transaction에 구현했다. device registration은 아직 schema가 없어 Phase 05 범위다. |
| FR-HH-008 | IN PROGRESS | 현재 Owner→Admin, 대상 성인→Owner, owner pointer를 한 transaction에서 변경하고 기존 deferred invariant를 재확인한다. 실행 검증은 하지 않았다. |
| API-009/010 | IN PROGRESS | same-household/role/version/idempotency 검사와 stable Edge error mapping이 코드에 있다. DB·RLS integration test는 NOT RUN이다. |

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

## Commands Run This Turn

구현에 필요한 source generation/format만 실행했다.

- `dart format` — 새·수정 Dart source 정렬
- `flutter gen-l10n` — ARB generated localization 갱신
- pinned Dart 3.12.2 `build_runner build` — json_serializable DTO 생성

아래 검증 명령은 사용자 요청에 따라 **전부 NOT RUN**이다.

- Flutter test / analyze / coverage
- Supabase reset / migration apply / schema lint / pgTAP
- Edge unit/live contract
- dependency/security scan
- Android dev/prod build
- GitHub Actions CI
- 실제 Google 계정 로그인, 성인 2인·2기기 Owner 이전/제거

## Security / Privacy Boundary

- 최근 인증 JWT는 전용 value object와 request header에서만 사용하며 log, audit, DTO 결과와 오류에 넣지 않는다.
- roster는 auth user ID를 반환하지 않고 active 구성원의 display name, role, version과 self marker만 반환한다.
- audit는 UUID actor/target/correlation, action/result/version/time만 저장하며 email, token, JWT와 자유문장을 저장하지 않는다.
- removed/left membership은 삭제하지 않아 미래 공동 기록의 historical FK를 보존하되, `removed_at` 즉시 RLS 접근 근거에서 제외한다.
- 현재 persistent household cache와 device registration table은 없다. remote device-token cleanup은 해당 table을 도입하는 Phase 05에서 이 lifecycle에 연결해야 한다.

## Remaining Risks

1. migration을 실제 PostgreSQL에 적용하지 않아 SQL syntax, grant, trigger와 deferred constraint 동작이 아직 증명되지 않았다.
2. Edge recent-auth의 실제 hosted Supabase JWT `amr` shape와 Google 재로그인 UX가 실제 계정에서 확인되지 않았다.
3. Flutter analyzer/widget/a11y/200% text와 account-switch race를 실행하지 않았다.
4. removal 직후 이미 그려진 원격 기기의 메모리 화면은 다음 navigation/network refresh 전까지 남을 수 있다. 권위적 서버 read/write는 RLS에서 즉시 차단하도록 설계했지만 실기기 증거가 필요하다.
5. chore/calendar assignment table이 아직 없으므로 향후 schema는 removed member historical reference 보존과 active-only 새 assignment 정책을 별도로 검증해야 한다.

## Rollback

- remote 적용 전: WP02-05 implementation commit을 revert한다.
- remote 적용 후: migration을 수정·삭제하지 않고 command/helper/constraint를 교정하는 forward migration과 Edge rollback deploy를 사용한다.

## Completion Boundary

이 문서는 구현 존재만 기록한다. `WP02_05_WORKPLAN.md`의 deferred validation batch가 green이고 실제 결과가 이 문서에 추가될 때만 WP02-05를 COMPLETE/PASS로 바꾼다.
