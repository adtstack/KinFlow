# Phase 07 WP07-03A Secure Invite Short Code Workplan

## Status

- 상태: **LOCAL IMPLEMENTED (2026-08-08)** — hosted/실계정/실기기 Gate 제외
- 시작일: 2026-08-08
- 수직 조각: Owner/Admin create → one-time raw short code → public generic preview → authenticated accept → active-household confirmation → terminal credential purge

## Requirements and decisions

- `FR-HH-004`: 짧은 초대 코드는 link token의 보조 수단이며 rate limit, lockout, generic invalid error와 더 짧은 만료를 사용한다.
- `FR-HH-005`: 코드 preview는 최소 가구/초대자/역할/만료 정보만 반환하고 accept는 기존 membership transaction과 idempotency를 재사용한다.
- `FR-AUTH-004`: 로그인 전 입력한 코드는 URL/query에 넣지 않고 process-memory continuation으로만 보존하며 인증 후 동일 흐름을 재개한다.
- `D-015`: 256-bit high-entropy link token은 계속 primary capability이고 short code는 대체 권한 체계가 아니다.
- `D-017`: accept와 active-household 변경은 online-only다.

## Security boundary

- 코드는 혼동 문자를 제외한 30자 alphabet의 8-symbol 값이며 표시 형식은 `XXXX-XXXX`다. 입력은 대소문자와 공백/하이픈만 정규화한다.
- 원문 코드는 create 성공 응답과 앱 process memory/사용자 명시적 clipboard에만 존재한다. PostgreSQL에는 normalized code의 SHA-256 hash와 만료 시각만 저장한다.
- 기본/최대 short-code TTL은 24시간이며 항상 primary link invite 만료보다 짧거나 같다.
- 공개 preview는 client address fingerprint 단위 `10 / 10분`, authenticated accept는 user fingerprint 단위 `10 / 10분` fixed-window lockout을 적용한다.
- unknown, expired, revoked, consumed short code는 모두 `INVITE_INVALID`로 응답한다. `RATE_LIMITED` 외에는 존재 여부나 상태를 구분하지 않는다.
- create idempotency replay는 기존 invite만 반환하며 새 raw link token이나 short code를 다시 노출하지 않는다.
- code는 URL, route state, logger, analytics, Sentry, DB audit/idempotency payload와 local persistent storage에 넣지 않는다.

## Database and API impact

- forward migration으로 `household_invites.short_code_expires_at`와 hash/expiry shape constraint를 추가한다.
- `consume_invite_rate_limit`에 `preview_short_code`와 `accept_short_code` scope를 추가한다.
- service-only `create_household_invite_with_short_code`, `preview_household_invite_short_code`, `accept_household_invite_short_code` RPC를 추가하고 client execute grant는 부여하지 않는다.
- 기존 create/preview/accept/revoke endpoint와 link-token RPC는 그대로 유지한다.
- create 응답에 생성 시 한 번만 `shortCode`를 추가하고 preview/accept body는 `token` 또는 `shortCode` 정확히 하나만 허용한다.
- invite Edge contract version은 `2026-08-08-wp07-03a`로 갱신한다.

## Flutter impact

- domain에 normalized `InviteShortCode` value object를 추가하고 raw code를 redacted `toString`으로 보호한다.
- repository/data source는 token과 short-code preview/accept를 분리된 typed method로 전달한다.
- pending invite store는 token 또는 code 하나만 process memory에 보관하고 account switch, terminal failure, accept와 explicit clear에서 제거한다.
- invite 생성 결과는 link와 24시간 code를 함께 표시하고 각각 명시적 copy action을 제공한다.
- `/invite` missing 상태는 code 입력 폼이 되며 sign-in과 first-household onboarding에서 진입할 수 있다.
- EN/KO/EN-XA ARB와 200% text widget을 함께 검증한다.

## Automated evidence plan

- pgTAP: column/constraint/least privilege, hash-only create, short TTL, replay non-disclosure, generic state errors, preview minimality, accept identity/idempotency, rate windows와 link compatibility.
- Node: unbiased generator shape, create raw-once/hash-only RPC, token-or-code exact body, generic error mapping, code-specific rate keys와 no raw reflection.
- Flutter: value object normalization, repository/data-source exact shape, process-memory continuation/purge, generation result, manual entry, sign-in/onboarding entry와 200% pseudo layout.
- focused suites 후 DB lint/full pgTAP, Node contract regression, Flutter analyzer/format/full regression, secret/codegen/YAML/CSV/whitespace를 실행한다.

## Manual and deferred evidence

- 실제 Google/Supabase 계정과 두 사용자 accept, hosted Edge/WAF rate limiting, NAT/proxy address semantics와 Android clipboard/keyboard residue는 사용자 요청대로 마지막 Gate에 둔다.
- email/SMS code delivery, operator invite list와 WAF/global abuse control은 이 local slice에 포함하지 않는다.

## Rollback

- Flutter code entry와 code display를 제거하고 Edge create를 기존 link-token RPC로 되돌리면 primary invite 기능은 유지된다.
- short-code preview/accept branch를 비활성화해 신규 code 사용을 중단할 수 있다. 기존 link preview/accept/revoke는 영향받지 않는다.
- migration은 forward-only다. 사용하지 않는 hash/expiry와 service RPC를 남기거나 후속 migration에서 capability를 null 처리하며 invite/idempotency 이력은 삭제하지 않는다.

## Entry to WP07-03B

- hash-only 발급, 24시간 TTL, generic failure, fixed-window lockout와 Flutter continuation이 local automation으로 증명되어야 한다.
- primary link invite regression과 전체 DB/Node/Flutter 회귀가 통과해야 한다.
- hosted/real-account/device abuse 검증은 마지막 Gate로 명시한다.
