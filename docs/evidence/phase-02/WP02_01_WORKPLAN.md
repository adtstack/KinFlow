# Phase 02 WP02-01 Work Plan

- 작성일: 2026-07-28
- 기준 commit: `7493c32`
- Work Package: WP02-01 Auth lifecycle — provider-independent local foundation
- 상태: COMPLETE — provider-independent local foundation slice; WP02-01 provider/device completion은 PENDING
- Phase 01 진입 판단: `CONDITIONAL GO` 범위만 사용

## Requirements

| ID | 이번 vertical slice |
|---|---|
| WP02-01 | nullable user 대신 명시적 인증 상태, session restore/refresh/logout port, route guard, expired/revoked 처리와 account-switch purge 기반 구현 |
| FR-AUTH-003 / D-054 | Android 로그인 UI는 Google 한 종류만 표현하되 provider가 연결되기 전에는 fail-closed. 실제 Google SDK, ID-token 교환과 callback은 비범위 |
| FR-AUTH-004 | 기존 세션 복원, refresh, 만료·회수·판정 불가 상태를 typed result로 처리하고 보호 route 접근 차단 |
| FR-AUTH-005 | logout 결과와 무관하게 app-local sensitive state purge를 시도하며 purge 실패 시 잠금 유지 |
| D-047 | domain/application은 Flutter, Riverpod와 provider SDK를 import하지 않음 |
| D-049 | 사용자 A에서 B로 바뀌면 즉시 route를 잠그고 purge 완료 뒤에만 B 상태를 공개 |
| T-AUTH-01 | restore, sign-in request 상태 전이, refresh, logout 자동 테스트 |
| T-AUTH-02 | expired/revoked와 account switch가 stale protected access를 허용하지 않는지 자동 테스트 |
| T-CACHE-01 / T-CACHE-02 | logout/account switch purge 호출 순서, 실패 잠금, 중복 동일 사용자 무해성 자동 테스트 |
| CAP-001 / CAP-008 / CAP-011 | provider-neutral ports와 Supabase adapter boundary만 구현. 승인된 secure storage 조립과 실제 user cache provider는 후속 Gate까지 미완료로 유지 |

## State / Routing Contract

- 상태는 `bootstrapping`, `unauthenticated`, `authenticating`, `authenticated-no-household`, `authenticated-active-household`, `refreshing`, `locked/re-auth-required`, `deleting`을 각각 타입으로 표현한다.
- `authenticated-*`와 유효 session을 가진 `refreshing`만 보호 route를 통과한다.
- bootstrap 중에는 전용 loading route, 비인증·잠금 상태에는 sign-in route로 이동한다.
- provider가 미연결인 현재 조립에서는 Google 외 로그인 수단을 노출하지 않고 Google action을 비활성화한다.
- raw access/refresh/ID token, 이메일, provider payload와 예외 message는 domain state, UI, log, test evidence에 넣지 않는다.

## Planned Implementation

1. auth domain에 opaque user ID/session, typed failure/result/event, session repository와 sign-in launcher port를 추가한다.
2. application에 인증 상태와 serialized lifecycle coordinator, composite sensitive-state purge port를 추가한다.
3. data에 provider-neutral session data source mapper/repository와 provider-unavailable fallback을 추가한다.
4. infrastructure에 주입된 `SupabaseClient`만 감싸는 auth data source를 추가하되 앱에는 아직 조립하지 않는다.
5. Riverpod 조립과 router refresh/redirect, auth loading/sign-in UI, 기존 보호 home의 logout action을 연결한다.
6. domain/application/data/infrastructure/router/widget/localization/architecture 테스트를 추가하고 전체 CI gate로 검증한다.

## Data / API / Dependency Impact

- DB migration, seed, RLS, RPC, Edge/API contract 변경 없음.
- Flutter/npm runtime dependency와 lockfile 변경 없음. 이미 고정된 `supabase_flutter`만 infrastructure boundary에서 사용한다.
- 현재 production composition은 `UnavailableAuthSessionRepository`, 비활성 sign-in launcher와 빈 composite purger를 사용한다. 앱에 user-scoped persistent cache가 아직 없으므로 purge participant도 0개다.
- Supabase adapter는 승인된 Android Keystore-backed secure auth storage가 구성된 client를 받을 때까지 runtime에 연결하지 않는다. SharedPreferences token persistence를 secure storage 완료로 간주하지 않는다.

## Automated Tests

- session 없음/복원 성공/오프라인·invalid 결과와 explicit state 전이
- refresh 성공, expired/revoked 시 purge 후 비인증, purge 실패 시 잠금
- logout provider 실패에도 purge, logout idempotency
- A→B account switch는 purge 중 보호 route 차단, purge 완료 뒤 B 공개; A→A는 purge 없음
- provider data mapping과 invalid UUID fail-closed
- Supabase SDK event/error를 token·message 없이 neutral data result로 매핑
- unauthenticated/bootstrapping/authenticated router guard와 Google-only fail-closed screen
- 기존 adaptive/i18n/a11y, architecture, secret/codegen/coverage regression

## Manual / Deferred Validation

- Google Cloud/Supabase provider, exact Android package/SHA, nonce/ID-token exchange, redirect/App Link, 실제 성인 계정 2개는 사용자 결정대로 후속 작업이다.
- Android 실제 기기가 연결될 때 cold/warm restore, process death, offline, revoked session과 account-switch forensic check를 수행한다.
- secure storage backup/restore 동작과 실제 cache/device/RevenueCat/FCM purge participant는 해당 provider가 도입될 때 Gate를 다시 연다.

## Stop / Rollback

- purge 완료 전에 새 사용자 route가 노출되거나 expired/revoked session이 보호 route를 통과하면 구현을 중단하고 다음 WP로 진행하지 않는다.
- auth feature, auth composition, router redirect, auth UI/l10n과 관련 테스트를 함께 revert하면 기존 foundation home 직행 상태로 복귀한다.
- DB/API/remote provider 설정을 변경하지 않으므로 migration rollback이나 remote credential 폐기는 없다.

## Next Entry Condition

- 이 slice의 자동 gate가 green이어도 WP02-01 전체 완료를 주장하지 않는다.
- 실제 Google 로그인 구현은 dev provider, Android OAuth client package/SHA, approved secure storage, redirect/domain과 실제 기기 준비 후 별도 vertical slice로 시작한다.
