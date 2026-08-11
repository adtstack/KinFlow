# Phase 07 WP07-03A Secure Invite Short Code Evidence

## 결과

- 상태: **LOCAL IMPLEMENTED (2026-08-08)** — WP07-03 전체와 G7 완료는 아님
- 구현 요구사항: `FR-AUTH-004`, `FR-HH-004`, `FR-HH-005`
- 유지 결정: `D-015` primary 256-bit HTTPS link, `D-017` online-only accept
- 완료 수직 조각: Owner/Admin 발급 → raw-once link/code 표시 → public generic preview → 로그인 process-memory continuation → authenticated transactional accept → active-household 전환 → credential purge

## 구현 범위

### Database와 Edge

- `supabase/migrations/20260808130000_secure_invite_short_codes.sql`
  - `household_invites.short_code_expires_at`와 hash/expiry 동시 존재 제약
  - short code 최대 24시간 및 primary invite 이내 TTL
  - `preview_short_code`, `accept_short_code` 각각 `10 / 10분` fixed window
  - service-only create/preview/accept RPC와 client role execute 차단
  - unknown/expired/revoked/consumed code를 `KFI05`/`INVITE_INVALID` 하나로 축약
- `supabase/functions/_shared/invite_contract.mjs`, `invite_runtime.mjs`
  - 30-symbol alphabet에서 rejection sampling으로 8-symbol code 생성
  - raw token/code는 create 최초 응답에만 포함하고 PostgreSQL에는 SHA-256 hash만 전달
  - preview는 trusted client-address material, accept는 authenticated user ID material을 hash한 rate key 사용
  - request body는 `token` 또는 `shortCode` 정확히 하나만 허용
- 기존 link create/preview/accept/revoke RPC와 URL scrub 흐름은 유지했다.

### Flutter

- domain: normalized/redacted `InviteShortCode`, code-specific accept request와 repository port
- data: exact raw-token/code/expiry 동시 응답 검사, code-specific Supabase preview/accept body
- application: token/code 상호 배타적 process-memory store, retry idempotency, account switch/terminal failure/accept/explicit clear purge
- UI: 발급 화면의 24시간 code·명시적 copy, `/invite` 수동 입력, sign-in 및 first-household onboarding 진입, 로그인 후 이어하기
- localization: EN/KO/EN-XA와 200% text/scroll 검증

주요 앱 파일:

- `apps/kinflow_app/lib/features/household/domain/value_objects/invite_identifiers.dart`
- `apps/kinflow_app/lib/features/household/domain/entities/household_invite.dart`
- `apps/kinflow_app/lib/features/household/domain/entities/household_invite_request.dart`
- `apps/kinflow_app/lib/features/household/domain/repositories/invite_repository.dart`
- `apps/kinflow_app/lib/features/household/data/datasources/invite_data_source.dart`
- `apps/kinflow_app/lib/features/household/data/repositories/provider_invite_repository.dart`
- `apps/kinflow_app/lib/features/household/data/services/ephemeral_pending_invite_store.dart`
- `apps/kinflow_app/lib/features/household/application/invite_flow_controller.dart`
- `apps/kinflow_app/lib/infrastructure/supabase/supabase_invite_data_source.dart`
- `apps/kinflow_app/lib/features/household/presentation/screens/household_invite_creation_screen.dart`
- `apps/kinflow_app/lib/features/household/presentation/screens/household_invite_screen.dart`
- `apps/kinflow_app/lib/features/auth/presentation/screens/sign_in_screen.dart`
- `apps/kinflow_app/lib/features/household/presentation/screens/household_onboarding_screen.dart`

## 계약과 문서

- `docs/contracts/invite-short-code.yaml.md`
- `docs/contracts/openapi-edge.yaml.md` contract version `2026-08-08-wp07-03a`
- `docs/contracts/database-schema.sql.md`, `docs/contracts/README.md`
- `docs/matrices/REQUIREMENTS_TRACEABILITY.csv.md`, `docs/matrices/TEST_MATRIX.csv.md`
- `docs/phases/PHASE_07_PRIVACY_SECURITY_ACCESSIBILITY_AND_GLOBAL.md`

## 자동 검증 결과

| 영역 | 명령/검사 | 결과 |
|---|---|---|
| Clean migration | `supabase db reset --local` | PASS, migration 38개 적용 |
| Focused pgTAP | `supabase test db supabase/tests/database/secure_invite_short_codes.test.sql` | PASS, 36 tests |
| DB lint | `supabase db lint --local --level warning` | PASS, schema error 0 |
| Full pgTAP | `supabase test db` | PASS, 45 files / 2347 tests / 347s |
| Invite Edge | `node --test supabase/tests/invite-edge-contract.test.mjs` | PASS, 28/28 |
| Flutter focused | invite identifiers/controller/repository/data-source/widget/onboarding suites | PASS after final layout adjustment |
| Flutter full | `flutter test` | PASS, 730 tests + opt-in live 1 skip |
| Analyzer | `flutter analyze` | PASS, issue 0 |
| Format | `dart format --output=none --set-exit-if-changed lib test` | PASS, 444 files / drift 0 |
| Codegen | `dart run build_runner build --delete-conflicting-outputs` | PASS, output write 0 |
| Localization | ARB exact coverage, pseudo 30% expansion, invite/onboarding 200% widget | PASS, focused 19 tests |
| Contract parse | OpenAPI/short-code fenced YAML + 3 ARB JSON | PASS |
| Matrix parse | fenced CSV matrix 13개 column/declared-row 검사 | PASS |
| Secret scan | `dart run tool/scan_secrets.dart` | PASS, high-confidence finding 0 |
| Whitespace | `git diff --check` | PASS |

초기 집중 검증에서 PostgreSQL `LEAST` 특수식 qualification과 pseudo copy 확장 부족을 각각 탐지했고 수정했다. 위 표는 수정 후 최종 결과다.

## 수동·실환경 검증

사용자 우선순위에 따라 다음 항목은 **NOT RUN / 마지막 Gate**로 유지한다.

- 실제 Google/Supabase 성인 2계정 link/code 발급·로그인·수락
- hosted Edge/WAF의 분산 rate limit과 proxy/NAT client-address 의미
- 실제 Android keyboard suggestion 및 clipboard 잔존 forensic
- 두 기기 동시 consume와 실제 네트워크 장애/복구

로컬 자동 검증 결과를 실계정·hosted·실기기 완료로 해석하지 않는다.

## 보안·개인정보 영향

- code entropy는 약 39.3 bit이며 단독 고엔트로피 권한으로 취급하지 않고 더 짧은 TTL과 강한 rate limit을 결합했다.
- raw token/code의 DB column, log, analytics, URL/query, persistent storage 저장 경로를 만들지 않았다.
- create replay는 raw credential을 다시 노출하지 않는다.
- public code terminal state는 하나의 generic 오류로 축약해 존재·상태 oracle을 줄였다.
- client는 외부 JSON을 DTO/record → mapper → domain 순서로 검증하고 partial credential payload를 fail closed 처리한다.

## 남은 위험과 OPEN 항목

- trusted proxy header 및 다수 사용자가 같은 NAT를 공유할 때의 lockout UX는 hosted 환경에서 확인해야 한다.
- DB fixed-window 외 WAF/global abuse control과 운영 경보·kill switch는 WP07-03B 후보로 남는다.
- clipboard는 사용자 명시적 action에서만 쓰지만 OS 수준 잔존은 실기기 forensic 전까지 미확인이다.
- email/SMS 자동 전달과 운영자용 초대 목록·재발급 UI는 이 조각에 포함하지 않았다.

## Rollback

- Flutter 수동 code 진입과 발급 code 표시를 제거해도 primary link 흐름은 유지된다.
- Edge short-code branch와 신규 code 발급을 비활성화할 수 있고 기존 link preview/accept/revoke는 계속 동작한다.
- migration은 forward-only다. 후속 migration에서 신규 hash/expiry를 null 처리하거나 service RPC execute를 revoke하며 invite/idempotency 이력은 삭제하지 않는다.

## 다음 진입 조건

- WP07-03B는 PII 없는 abuse aggregate/운영 kill switch와 broader threat-model·log scrub을 우선 후보로 삼는다.
- hosted/실계정/실기기 검증은 사용자 지시대로 기능 조각들을 먼저 개발한 뒤 마지막 통합 Gate에서 수행한다.
