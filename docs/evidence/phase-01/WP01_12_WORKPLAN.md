# Phase 01 WP01-12 Web Companion Baseline Workplan

## Status

- **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)**
- Vertical slice: Flutter Web release build → Web runtime identity/policy → email-first sign-in → explicit capability fallbacks → independent CI artifact
- Requirements: FR-AUTH-010, FR-AUTH-011, FR-NOTIF-008, FR-SUB-011, FR-SET-008, FR-PLAT-007~009, FR-PLAT-011~016, NFR-PLAT-001~003, NFR-WEB-001~004, NFR-REL-001~002
- Decision: D-070
- Contract: `docs/contracts/web-companion-baseline.yaml.md`
- Test ID: T-WEB-BASELINE

## Product boundary

1. Android Store MVP와 독립된 Web Companion dev/prod release build를 같은 Flutter repository에서 만든다.
2. Web 로그인은 기존 email OTP를 우선 노출하고 Android native Google launcher는 명시적으로 unavailable 처리한다.
3. 가구·집안일·Calendar·알림 inbox·entitlement read 등 서버 권위 repository는 공유하되 Web 구매, Web Push, notification endpoint binding, 영속 read cache, guided resume와 completion outbox는 활성화하지 않는다.
4. Web exact-five capability는 inbox+configured email, server entitlement read, re-auth, browser link, server notification/inbox fallback을 안정적으로 설명한다.
5. Web runtime은 package `kinflow_app`, platform `web`, dev/prod 환경과 exact build/contract header로 별도 global·six-feature server policy를 읽는다.
6. PWA 설치 surface와 Flutter service worker를 만들지 않고 broad persistent API cache를 금지한다.
7. path URL을 사용하되 production hosting provider와 rewrite가 정해지기 전에는 direct-refresh 요구를 완료 처리하지 않는다.

## DB, API and dependency impact

- `app_runtime_policies`, `app_runtime_feature_policies`와 immutable audit의 platform constraint를 `android|web`으로 확장한다.
- dev/prod Web global policy 두 행과 환경별 exact six feature policy 열두 행을 compatibility-open으로 seed한다.
- 기존 runtime-policy read/configure/enforcement 함수의 signature, grant, stable error와 Android semantics를 유지하면서 Web을 허용한다.
- Web build를 위해 SDK `flutter_web_plugins`를 direct dependency로 선언하며 Flutter/Dart exact pin은 바꾸지 않는다.
- 새 server secret, client config key, native permission, provider SDK 또는 analytics event는 추가하지 않는다.

## Security, privacy and accessibility

- `web/index.html`은 no-referrer와 noindex/nofollow/noarchive를 선언하며 PWA manifest를 참조하지 않는다.
- Flutter service worker와 persistent API read cache를 비활성화하고, 허용되는 browser persistence는 purge 가능한 인증 session으로 제한한다.
- Web Push와 Store purchase를 시도하지 않으며 capability fallback에 account, household, device, payment 또는 provider identifier를 넣지 않는다.
- runtime header는 build/environment/platform/contract만 포함하고 family content는 포함하지 않는다.
- sign-in의 localized heading, disabled Google action, enabled email/OTP request semantics를 local browser에서 확인한다.

## Automated verification

1. Web scaffold, path URL strategy와 non-PWA baseline architecture test
2. Web auth composition, logout purge와 persistent cache/outbox/resume 비활성화
3. exact-five Web capability registry and fallback snapshot
4. exact Web runtime identity header and strict UTC `Z|+00:00` policy mapping
5. clean reset 후 Web policy seed, anon read, service configure/replay/audit와 mutation enforcement pgTAP
6. exact public config version split/rejection and CI workflow contract
7. dev/prod release build, output metadata, disabled service worker, no manifest and bundle hash audit
8. focused/impact/full Flutter, analyzer, format, codegen, config, secret, Node, full DB/lint, docs and whitespace regression

## Local browser verification

- local Supabase public endpoint를 사용하는 임시 dev Web build로 `/`가 `/sign-in`에 도달하는지 확인한다.
- runtime policy RPC가 성공하고 unavailable banner가 없는지 확인한다.
- Google action은 disabled이고 email과 OTP request control은 visible/enabled인지 접근성 tree와 locator로 확인한다.
- generic static server에서 `/sign-in` direct reload가 404임을 기록해 hosting SPA rewrite를 후속 항목으로 유지한다.

## Manual and deferred verification

- owned HTTPS origin, CSP, SPA rewrite와 atomic deploy/rollback
- OAuth PKCE callback, allowlisted redirect와 callback URL scrub
- 실제 email OTP/account, logout·account-switch·removal browser residue
- authenticated core keyboard-only, screen reader, zoom, BFCache와 browser matrix
- hosted policy propagation, Web/mobile entitlement parity, Web Push와 Web purchase
- 실계정·다중기기·실기기는 사용자 지시에 따라 마지막 통합 Gate

## Rollback

- Web scaffold, conditional URL strategy와 independent Web CI job을 제거하면 Android build/composition은 유지된다.
- runtime policy Web rows/constraint는 forward-only migration으로 되돌리고 Android rows와 함수 signature를 보존한다.
- PWA/cache/user data migration이 없으므로 service-worker unregister나 browser cache data backfill은 필요 없다.
