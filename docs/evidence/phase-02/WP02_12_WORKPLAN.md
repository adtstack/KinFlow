# Phase 02 WP02-12 Email OTP Authentication Workplan

## Goal

Android Store MVP의 남은 `MUST / NOT_STARTED` 사용자 기능인 이메일 OTP 가입·로그인을 provider-neutral Flutter 계층과 Supabase Auth adapter로 구현한다. 실제 메일 계정·hosted SMTP·실기기는 마지막 통합 Gate로 유지하되, 요청부터 세션 인계까지 로컬 자동화 가능한 상태로 만든다.

## Traceability

- Requirements: `FR-AUTH-001`, `FR-AUTH-004`
- Contract: `docs/contracts/email-otp-auth.yaml.md`
- Tests: `T-AUTH-04`, `T-PRIV-03`, `T-A11Y-03`, `T-I18N-01`
- Decisions: `D-002`, `D-008`, `D-013`, `D-036`, `D-047`, `D-049`

## Scope

1. email과 6자리 OTP value object, provider-neutral request/verify result와 stable failure를 추가한다.
2. 요청·재전송·검증 single-flight, 60초 재전송 제한, 10분 local expiry, 성공 뒤 재사용 차단을 application controller로 구현한다.
3. pinned Supabase SDK의 exact error code만 rate limit/provider unavailable/invalid-code로 매핑하고 raw message를 사용하지 않는다.
4. 성공 응답의 session/user UUID 일치를 검증하고 기존 auth session event stream이 household resolution과 route 전환을 담당하게 한다.
5. 로그인 화면에 email 입력, generic delivery 안내, OTP 입력, 검증, 재전송, 이메일 변경을 EN/KO/EN-XA로 추가한다.
6. local Supabase mail catcher와 Auth의 email signup, 6자리/10분 OTP, 60초 send limit와 token-only email template를 구성한다.
7. 계정 존재 여부 preflight, client identity link/merge, 이메일·코드 persistence/logging/analytics를 추가하지 않는다.

## DB / API / storage impact

- PostgreSQL public schema, RLS, RPC, Edge Function, application OpenAPI: **변경 없음**
- Supabase Auth public endpoint: SDK `signInWithOtp`와 `verifyOTP(type: email)` 사용
- Local Auth config/template: email signup enabled, OTP length `6`, expiry `600s`, max frequency `60s`, `{{ .Token }}` only
- App persistent storage schema: **변경 없음**. email/code/challenge는 process memory only다.
- Runtime dependency/permission: **변경 없음**

## Verification

- Domain: email/code validation, redacted string representation, exact challenge timing
- Data: exact SDK error-code mapping, retryable mapping, conflict generic acceptance, strict success payload
- Application: request/resend/verify duplicate coalescing, cooldown/expiry/reuse no-I/O, throw safety, disposed/superseded response isolation
- Widget: request→code→verify, invalid/expired/rate-limit messages, generic anti-enumeration copy, Google fallback, EN/KO/EN-XA compact 200%, 48dp targets
- Integration: local Supabase Inbucket synthetic address request/template/code/session handoff; real mailbox is excluded
- Regression: full Flutter tests, analyzer fatal infos/warnings, format, codegen drift, privacy/architecture checks

## Security and privacy

- email과 OTP를 logger, analytics, diagnostics, persistence 또는 raw exception UI에 넣지 않는다.
- request 성공 문구는 계정 존재 여부와 무관하게 동일하다.
- exact identity conflict provider code도 request 단계에서는 generic accepted로 축약한다.
- client는 identity link/merge API를 호출하지 않는다.
- Google→email/email→Google의 hosted automatic linking 실제 정책은 기존 `FR-AUTH-007` 마지막 Gate에서 별도로 감사한다.

## Rollback

- Email OTP provider/controller/UI override를 제거하면 기존 Google 로그인만 남는다.
- local config의 email signup을 다시 끄고 token-only template를 제거한다.
- DB migration이나 stored-data backfill/cleanup은 없다.

## Deferred final Gate

- hosted SMTP/sender domain/template/rate-limit/abuse 설정
- 실제 기존 Google identity와 email identity 충돌·자동 linking 정책
- 실제 mailbox 전달, spam, email prefetch, 다중기기, process death
- 실제 Android OTP autofill/keyboard/TalkBack와 실계정 로그인
