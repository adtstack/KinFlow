# Phase 02 WP02-12 Email OTP Authentication Evidence

- Work Package: WP02-12 — Android email OTP sign-up/sign-in
- 기준 commit: base `a85f262`; implementation은 2026-08-09 현재 연속 workspace
- 검증일: 2026-08-09
- 환경: macOS arm64, Flutter SDK 3.44.7 stable, Dart 3.12.2, Supabase CLI 2.109.1, local Supabase Auth + Mailpit
- 결과: **WP02-12 LOCAL AUTOMATED PASS / HOSTED·REAL-MAILBOX·REAL-ACCOUNT·REAL-DEVICE GATE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| FR-AUTH-001 / T-AUTH-04 | PASS FOR LOCAL FEATURE SLICE / OVERALL IN PROGRESS | normalized email request부터 exact 6자리 code 검증, 10분 local expiry, 60초 resend 제한, 성공 뒤 reuse 차단과 stable localized failure까지 구현했다. local synthetic Auth/Mailpit session 발급은 통과했고 hosted SMTP와 실계정은 남았다. |
| FR-AUTH-004 | PASS FOR LOCAL SESSION HANDOFF / OVERALL IN PROGRESS | Supabase verify 응답에서 session/user UUID 존재·형식·일치를 strict mapper가 검증하고, SDK auth-state event를 기존 session repository/router가 소비한다. remote cold restore·refresh·revoke 실계정 검증은 남았다. |
| NFR-PRIV-01 / T-PRIV-03 | PASS FOR NEW SURFACE | email/code/challenge를 process memory 밖에 저장하지 않고 logger·analytics·diagnostics에 전달하지 않는다. request 결과는 계정 존재 여부와 exact conflict code를 generic accepted로 축약하며 UI에는 masked destination만 표시한다. |
| NFR-A11Y-01 / NFR-I18N-01 | PASS FOR LOCAL AUTOMATION / OVERALL PARTIAL | email/one-time-code autofill, live region, 48dp action, scrollable compact 200%와 EN/KO/EN-XA exact ARB coverage를 통과했다. physical Android TalkBack·IME·autofill은 남았다. |

## Implemented Vertical Slice

- Domain value objects는 email을 trim 후 lowercase하고 254자·exact one-`@`·whitespace 금지 규칙을 적용한다. OTP는 ASCII 숫자 정확히 6자리만 허용하며 두 객체의 문자열 표현은 값을 redaction한다.
- process-memory challenge는 request 시각, 60초 resend 가능 시각, 10분 만료 시각과 generation을 UTC로 보존한다. persistence schema, cache와 analytics event는 추가하지 않았다.
- application controller는 request/resend/verify를 single-flight로 합치고 malformed code, early resend, local expiry와 local reuse를 provider I/O 전에 차단한다. dispose 또는 superseded scope의 late response는 무시한다.
- Supabase adapter는 `signInWithOtp(shouldCreateUser: true)`와 `verifyOTP(type: email)`만 호출한다. raw message를 읽지 않고 exact stable code 또는 retryable transport type만 provider-neutral failure로 바꾼다.
- provider service는 response session과 user의 유효한 UUID가 정확히 일치할 때만 `AuthSession`을 반환한다. 성공 세션은 별도 local write 없이 기존 Supabase auth-state stream으로 인계한다.
- 로그인 화면은 Google fallback과 함께 email request, generic delivery 안내, masked destination, OTP verify, resend와 email 변경을 제공한다. Google identity conflict 전용 복구 화면에는 email flow를 섞지 않는다.
- local Supabase Auth는 project/email signup, 6자리 OTP, 600초 expiry, 60초 frequency와 bilingual token-only confirmation/magic-link template를 사용한다. manual identity linking은 계속 disabled다.

## Local Synthetic Auth and Mail Validation

실제 mailbox나 계정을 사용하지 않고 unique `example.test` 합성 주소와 local Docker volume만 사용했다. secret, email과 OTP 값은 검증 출력에 포함하지 않았다.

| 검증 | 결과 |
|---|---|
| local Auth와 Mailpit health | PASS — Auth `54321`, Mailpit `54324` local endpoints reachable |
| first OTP request | PASS — HTTP 200 |
| immediate same-address resend | PASS — HTTP 429 / exact `over_email_send_rate_limit` |
| bilingual template | PASS — English and Korean instructions present; one distinct six-digit token; HTTP/anchor link absent |
| wrong code in current local window | PASS — HTTP 403 / exact `otp_expired`; app contract maps this provider code to retryable invalid code |
| valid code | PASS — HTTP 200 with session material and user identifier; strict response identity matching is separately automated in the provider mapper |
| consumed-code reuse | PASS — HTTP 403 / exact `otp_expired` |

Local config parsing was exercised by a successful stack start and the live request/verify sequence. Database reset, hosted mutation and real identity creation were not performed. Synthetic Mailpit messages and local Auth users remain non-production local test data in the existing Docker volume.

## Automated Validation

| 검증 | 결과 |
|---|---|
| focused email OTP + identity-conflict regression | PASS — 74 tests across value objects, controller, provider service, Supabase mapping and widget behavior |
| auth/app/architecture impact regression | PASS — 74 tests including composition, session lifecycle, app shell, adaptive accessibility and dependency direction |
| full Flutter regression | PASS — 1,227 tests; existing local-connectivity opt-in 1 skip; all others passed |
| Flutter analyzer | PASS — fatal infos/warnings, issue 0 |
| Dart formatter | PASS — 670 files checked, drift 0 |
| localization and generated code | PASS — build runner wrote 0 outputs; 8 generated files current |
| public config and secret scan | PASS — allowlist valid; high-confidence secret finding 0 |
| repository Node contracts | PASS — 141/141; workflow/supply-chain contract also passed |
| documentation structure | PASS — 380 Markdown files balanced; email OTP YAML parses; 13 matrices rectangular and declared counts match; requirements 116×18, tests 85×11, API 45×6, platform 20×12 |
| privacy static inventory | PASS — new OTP domain/application/data/presentation paths contain no logger, analytics, debug print or persistent-storage call |
| whitespace | PASS — `git diff --check` output 0 before final evidence write; final check repeated at handoff |

No PostgreSQL schema, RLS, RPC, Edge Function, application OpenAPI, runtime dependency or native permission changed, so a database regression/reset was not a WP02-12 impact gate.

## Files and Configuration

- Contract/work package: `docs/contracts/email-otp-auth.yaml.md`, `docs/evidence/phase-02/WP02_12_WORKPLAN.md`
- Flutter domain/application: `apps/kinflow_app/lib/features/auth/domain/`, `apps/kinflow_app/lib/features/auth/application/auth_email_otp_controller.dart`, `apps/kinflow_app/lib/features/auth/application/auth_email_otp_state.dart`
- Flutter data/infrastructure: `apps/kinflow_app/lib/features/auth/data/datasources/auth_email_otp_data_source.dart`, `apps/kinflow_app/lib/features/auth/data/services/provider_auth_email_otp_service.dart`, `apps/kinflow_app/lib/infrastructure/supabase/supabase_auth_email_otp_data_source.dart`
- Runtime/UI: auth dependency composition, Riverpod override and `apps/kinflow_app/lib/features/auth/presentation/screens/sign_in_screen.dart`
- Localization: source EN/KO/EN-XA ARB plus generated localizations
- Local Auth: `supabase/config.toml`, `supabase/templates/email_otp.html`
- Tests: OTP controller, provider service, Supabase data source, widget, auth composition/shell/session and architecture coverage
- Governance: Phase 02, contract index, test/requirements/platform matrices and changelog
- Migration: **none**

## Security and Privacy Boundary

1. Account-existence preflight and client identity link/merge mutation are forbidden.
2. `email_exists`, `identity_already_exists` and `user_already_exists` request responses are indistinguishable from accepted requests in the app.
3. email, code and challenge are not written to secure storage, preferences, database, cache, diagnostics, logs or analytics.
4. raw provider exception text is never rendered or used for classification; only exact stable codes and retryable exception type are consumed.
5. OTP email intentionally renders `{{ .Token }}` while the app never echoes the code outside the explicit input field. The template contains no magic link.
6. unavailable composition disables both Google and email actions and fails closed.

## Manual and Deferred Validation

- hosted Supabase email provider, custom SMTP sender/domain, template deployment, rate/abuse controls and delivery observability are **NOT RUN**이다.
- 실제 mailbox delivery, spam placement, scanner/prefetch behavior와 email change lifecycle은 **NOT RUN**이다.
- 실제 기존 Google identity와 email sign-up의 hosted automatic-link/conflict policy 및 support recovery는 **NOT RUN**이다.
- 실제 성인 계정 session restore/refresh/revoke, 두 계정·다중기기와 process death는 **NOT RUN**이다.
- physical Android keyboard, one-time-code autofill, TalkBack, 200% font와 phone/tablet journey는 **NOT RUN**이다.
- iOS Sign in with Apple과 Web authentication은 기존 결정대로 Store MVP 이후 범위다.

## Remaining Risks and Next Entry Condition

1. local Mailpit 성공은 production SMTP deliverability, sender reputation, provider throttling과 abuse resistance를 증명하지 않는다.
2. Supabase hosted automatic identity linking 동작은 project 설정과 provider 상태에 의존하므로 실제 기존 Google/email 계정 조합을 마지막 Gate에서 확인해야 한다.
3. process-memory challenge는 process death 뒤 의도적으로 복원되지 않는다. 사용자는 email을 다시 입력해 새 code를 요청해야 한다.
4. 이 local vertical slice가 green이므로 다음 기능 Work Package에 진입할 수 있다. Phase 02 전체 Exit Gate는 hosted·실계정·다중기기·실기기 evidence가 없어 계속 `PARTIAL`이다.

사용자 지시에 따라 실계정·실메일·실기기 Gate는 기능 개발 대부분이 끝난 뒤 수행한다.

## Rollback

- auth dependency의 email OTP service override와 sign-in email section을 제거하면 기존 Google login 흐름을 유지하면서 email 진입만 닫을 수 있다.
- local config의 project/email signup을 다시 disabled로 바꾸고 confirmation/magic-link template override를 제거한다.
- database migration, persisted app challenge, backfill과 device local purge가 없어 data rollback은 필요 없다.
