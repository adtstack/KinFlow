# Phase 02 WP02-01 Evidence

- Work Package: WP02-01 Auth lifecycle — provider-independent local foundation
- 기준 commit: base `7493c32`; implementation commit은 이 문서가 포함된 commit
- 검증일: 2026-07-28
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0
- 결과: **LOCAL FOUNDATION PASS / GOOGLE·SECURE STORAGE·ANDROID DEVICE PENDING**
- 범위 근거: Phase 01 Completion Report의 `CONDITIONAL GO`만 사용

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP02-01 explicit lifecycle | FOUNDATION PASS | 8개 auth 상태 타입, serialized coordinator, restore/refresh/sign-out/event port |
| FR-AUTH-003 / D-054 | UI CONTRACT PASS / PROVIDER PENDING | Google action만 존재하며 runtime provider 미조립 시 disabled/fail-closed; 실제 SDK·token exchange 없음 |
| FR-AUTH-004 | LOCAL PASS / DEVICE PENDING | session 없음·복원·refresh·offline 판정 불가·expired·revoked typed transition과 route 차단 테스트 |
| FR-AUTH-005 | LOCAL PASS / PROVIDER PENDING | provider sign-out 실패와 무관한 purge, 반복 logout, purge 실패 잠금 테스트; 실제 device/FCM provider는 없음 |
| D-047 | PASS | auth domain/application에 Flutter·Riverpod·Supabase import 0; architecture suite PASS |
| D-049 | LOCAL PASS | A→B에서 즉시 `AuthLocked`, purge 완료 뒤에만 B 공개; 실패 시 잠금 유지; A→A purge 0 |
| T-AUTH-01 | AUTOMATED FOUNDATION PASS | restore/refresh/logout/request/event/controller, repository, SDK boundary와 widget tests |
| T-AUTH-02 | AUTOMATED LOCAL PASS / MANUAL PENDING | expired/revoked/account switch protected-route deny와 stale-state purge 테스트 |
| T-CACHE-01 / T-CACHE-02 | AUTOMATED PORT PASS | logout/account switch composite purge 호출·순서·실패·전체 participant 시도 테스트 |
| CAP-001 / CAP-008 / CAP-011 | PARTIAL | domain ports와 Supabase adapter boundary만 구현; secure storage와 실제 user-scoped persistence는 미조립 |

## Implementation

- `features/auth/domain`: UUID 형식의 opaque adult auth user ID, token을 포함하지 않는 session, typed failure/result/event, session repository와 sign-in launcher port
- `features/auth/application`: nullable user를 대체하는 8개 lifecycle 상태, 순차 실행 coordinator, composite sensitive-state purge 계약
- `features/auth/data`: provider-neutral record/error mapper, Supabase를 조립하지 않는 unavailable repository/launcher fallback
- `infrastructure/supabase`: 주입된 `SupabaseClient`의 restore/refresh/sign-out/event를 provider-neutral data result로 바꾸는 adapter. exception message나 session token은 외부로 전달하지 않음
- `app/router`: bootstrap/sign-in/protected route guard와 refresh bridge. 보호 경로 intent는 path만 최대 512자로 보존하고 query/fragment는 폐기
- `presentation`: auth loading, Google-only sign-in, provider 미연결 disabled 상태, expired/revoked/local-purge failure의 안전한 EN/KO/pseudo copy, 보호 home의 logout action
- runtime composition은 unavailable repository와 sign-in launcher, participant 0개의 composite purger를 사용한다. 현재 user-scoped persistent cache가 없으므로 지울 실제 payload도 없다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| exact toolchain | Flutter 3.44.7 / Dart 3.12.2 / Node 24.15.0 확인 |
| `npm run ci:test` | PASS 9/9 |
| `npm run ci:workflow` + actionlint | PASS, 5 jobs / pinned action 17 / `contents:read` |
| `dart format --output=none --set-exit-if-changed lib test tool` | PASS, 89 files / drift 0 |
| `flutter analyze --no-pub --fatal-infos --fatal-warnings` | PASS, issue 0 |
| `flutter test --no-pub --coverage` | PASS, 90 tests + local connectivity opt-in 1 skip |
| coverage summary | 1,170/1,382 lines, 84.66% |
| public config validator | PASS, example allowlist 유지 |
| secret scanner | PASS, high-confidence secret 0 |
| codegen validator | PASS, generated localization/Freezed/JSON drift 0, generated files 5 |
| architecture boundary | PASS, feature dependency direction과 provider SDK 격리 |

상세 실행 요약은 `logs/wp02-01-auth-foundation.log`에 있다. CI report와 coverage 원본은 ignored local artifact이며 repository에는 token, provider payload, crash log를 추가하지 않았다.

## Data / API / Dependency Review

- DB migration, seed, RLS, RPC, Edge/API contract 변경 없음.
- Flutter/npm runtime dependency와 `pubspec.lock`/`package-lock.json` 변경 없음.
- production Supabase/Google console, remote redirect, GitHub setting과 signing material 변경 없음.
- 현재 Supabase adapter는 approved Android Keystore-backed auth storage가 주입된 client만 받도록 문서화했으며 runtime에는 연결하지 않았다. `supabase_flutter` 기본 persistence를 secure storage 완료 증거로 사용하지 않는다.

## Security / Privacy

- access/refresh/Google ID token과 이메일은 domain state, UI, log와 evidence에 없다.
- `AuthUserId`와 `AuthSession` 문자열 표현은 식별자를 redacted 처리한다.
- provider exception은 stable failure kind/code로만 변환하며 raw message를 보존하지 않는다.
- session 없음, expired/revoked, offline 판정 불가, logout과 A→B 전환은 보호 route를 먼저 닫고 local purge를 수행한다.
- purge participant 하나가 실패해도 나머지를 모두 시도하며, 하나라도 실패하면 새 account route를 열지 않는다.

## Manual / Device Validation

- `adb devices -l`: 연결 기기 0대. 실제 process death, cold restore, offline, revoked session, logout/account switch forensic validation은 **NOT RUN**이다.
- 실제 Google 계정, Android OAuth client package/SHA, Supabase Google provider, nonce/ID-token exchange와 redirect/App Link는 사용자 결정에 따라 **PENDING**이다.
- 실제 secure storage backup/restore, FCM unlink, RevenueCat identity와 user/household cache participant는 provider/기능 도입 전까지 **PENDING**이다.

## Remaining Risks / Completion Boundary

1. 이 결과는 WP02-01 전체 완료가 아니라 provider-independent local foundation 완료다.
2. runtime은 의도적으로 sign-in할 수 없다. disabled Google action은 성공 mock이 아니며 다른 로그인 방식도 노출하지 않는다.
3. Supabase adapter를 secure storage 없이 조립하면 모바일 저장 요구사항을 위반한다. composition 변경은 별도 review와 device evidence가 필요하다.
4. Android 기기가 없어 secure store, process restore, network transition과 화면 접근성의 실제 동작을 검증하지 못했다.
5. participant 0개인 현재 purger는 user-scoped persistence가 아직 없다는 사실만 반영한다. 이후 cache/device/billing provider 추가 시 participant 등록과 T-CACHE 회귀가 필수다.

## Rollback

- auth feature/infrastructure adapter, auth composition, router guard/routes, sign-in/loading UI, home logout action, auth l10n과 관련 테스트를 함께 revert한다.
- 기존 router의 `/` foundation home 직행과 기존 responsive scaffold header로 복귀한다.
- DB/API/remote provider/credential을 변경하지 않았으므로 migration rollback, provider disable 또는 token 폐기 절차는 없다.

## Next Entry Condition

- 다음 안전한 작업은 WP02-01의 Android secure auth storage adapter와 Supabase client initialization을 먼저 확정하는 것이다.
- 실제 Google sign-in slice는 dev Google/Supabase provider, exact `me.newlines.kinflow.dev` package/SHA, approved redirect/domain, Android device와 테스트용 성인 계정이 준비된 뒤 시작한다.
- 이 조건 전에는 WP02-02 schema/RLS로 넘어가거나 WP02-01 전체 PASS를 선언하지 않는다.
