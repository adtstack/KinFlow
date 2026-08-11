# Phase 02 WP02-10 Google Identity Conflict Safe Recovery Evidence

## Result

- 상태: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-09)**
- 사용자 기능: Google 로그인 identity 충돌을 일반 provider 장애와 구분하고, 계정을 자동 병합하지 않은 채 다른 Google 계정 재선택과 고정 지원 경로를 제공한다.
- 범위: Android Google + Supabase Auth client 경계만 변경한다. DB/API/storage schema, identity link mutation, OTP/Apple UI와 새 SDK는 추가하지 않는다.

## Implemented contract

- `AuthException.code`가 exact `email_exists`, `identity_already_exists`, `user_already_exists`일 때만 data/domain `identityConflict`와 stable `IDENTITY_CONFLICT`로 매핑한다.
- provider message, status 또는 substring은 identity conflict 판단에 사용하지 않는다. 그 밖의 `AuthException`은 기존 provider-unavailable 경계로 유지한다.
- conflict 뒤 Google SDK의 process-local account selection만 정확히 한 번 best-effort sign-out한다. 실패해도 conflict를 generic/unknown으로 덮지 않으며 Supabase session/link/merge mutation은 만들지 않는다.
- 로그인 화면은 no-auto-merge 설명과 기존 auth-controller single-flight 재시도, enum-only fixed support launcher를 제공한다.
- support는 single-flight이며 opened/unavailable stable localized live region만 표시한다. email, provider identity, token, raw exception 또는 contextual URI를 렌더링하거나 추가로 기록하지 않는다.
- EN/KO/EN-XA와 compact 320×568 200% text에서 scroll 및 48dp recovery action을 유지한다.

## Changed surfaces

- 계약·계획: `docs/contracts/auth-identity-conflict-recovery.yaml.md`, `docs/contracts/error-catalog.yaml.md`, `docs/evidence/phase-02/WP02_10_WORKPLAN.md`
- data/domain: `auth_sign_in_data_source.dart`, `provider_auth_sign_in_launcher.dart`, `auth_failure.dart`
- provider boundary: `supabase_google_token_exchange.dart`, `google_supabase_auth_sign_in_data_source.dart`, `google_supabase_recent_authentication_service.dart`
- UI/localization: `sign_in_screen.dart`, EN/KO/EN-XA ARB와 generated localization files
- tests: exact provider-code, data/domain mapping, selection reset isolation, recent-auth fallback, recovery widget/support/a11y tests
- traceability: Phase 02, contract index, changelog, requirements/test/platform matrices
- 변경 없음: migration, PostgreSQL, RLS, RPC, Edge Function, remote DTO, persistent storage, runtime dependency, provider configuration

## Automated evidence

### Focused and impact Flutter tests

- Supabase exchange, Google data source, provider-neutral launcher, recent auth와 conflict recovery widget focused set: **22 passed**
- auth/session/router/bootstrap/support/accessibility/localization/architecture impact set: **126 passed**
- 주요 증명:
  - 세 exact lowercase code만 conflict이고 message-only, generic `conflict`, uppercase 유사 code는 provider-unavailable
  - conflict에서만 Google account selection 1회 clear, clear 실패 격리, 다른 failure에서는 clear 0회
  - stable data/domain failure와 `IDENTITY_CONFLICT` code, recent-auth의 safe account-changed fallback
  - retry와 support single-flight, auto merge/OTP/Apple UI 부재, raw email/provider detail 비노출
  - support fixed enum destination과 opened/unavailable stable result
  - EN-XA compact 200% scroll, recovery action 48dp 이상

### Full local regression

- Flutter full suite: **1,078 passed + 1 explicit live opt-in skipped, 0 failed**
- Flutter analyzer `--fatal-infos --fatal-warnings`: **0 issues**
- Dart format gate: **615 files checked, 0 changed**
- generated code drift: **8 files checked, 0 outputs, passed**
- root `npm run ci:test`: **141 passed, 0 failed, 0 skipped**
- public configuration allowlist: **passed**
- high-confidence secret scan: **passed**

### Contract and documentation gates

- embedded YAML: conflict exact-code allowlist **3/3 matched**, error catalog **64 unique codes** with `IDENTITY_CONFLICT`
- CSV matrices: requirements **116×18**, platform capabilities **20×12**, test matrix **80×11**
- localization source: EN/KO/EN-XA 각각 recovery key **8/8 present** and valid JSON
- scoped references: **16/16 present**, trailing whitespace **0**, evidence placeholders **0**, Flutter crash logs **0**
- repository diff whitespace/error marker check: **passed**

## Security and privacy evidence

- conflict 판단은 provider stable code allowlist만 소비하며 message/email을 파싱하지 않는다.
- user-facing copy는 현재 제출한 Google identity가 자동 연결되지 않았다는 사실만 알리고 기존 계정·provider·email의 존재나 값을 밝히지 않는다.
- provider account selection clear와 support launcher 실패는 catch 경계 안에서 stable result로 축약되며 raw exception은 UI/log에 추가되지 않는다.
- support destination은 기존 configured enum-only HTTPS launcher를 재사용하고 identity/account query 또는 body를 만들지 않는다.

## Manual and deferred evidence

- hosted Supabase automatic-linking/provider policy와 실제 `email_exists`/identity conflict 동작
- 실제 Google chooser reset, configured support browser handoff와 Android back/resume
- 실계정·다중기기·실기기
- email OTP, Apple, 추가 provider와 실제 identity linking 지원 절차

사용자 지시에 따라 위 live 검증은 마지막 통합 Gate까지 미룬다. 따라서 `FR-AUTH-007`은 로컬 복구 기능을 갖췄지만 provider/account policy 전체 완료가 아닌 `PARTIAL`이다.

## Rollback

- identity conflict enums/mapping, conflict-only Google selection clear와 로그인 recovery UI를 제거하면 기존 generic provider-unavailable 경계로 돌아간다.
- DB/API/storage/provider configuration이 바뀌지 않았으므로 rollback migration, data backfill, identity unlink 또는 account cleanup은 필요 없다.

## Next Entry Condition

- 다음 Store-MVP local 기능 slice는 남은 `FR-PLAT-003` analytics governance 또는 별도 승인된 auth gap 중 하나를 계약화해 진행할 수 있다.
- hosted provider policy와 실제 계정 검증은 사용자 지시에 따라 마지막 통합 Gate에 유지한다.
