# Phase 10 — Web Companion Beta와 Native Desktop 수요 Gate

## 목표

모바일 출시 데이터를 바탕으로 PC 사용 가치가 확인되면 Flutter Web Companion을 제한 공개하고, 네이티브 Desktop은 별도 투자 판단만 수행한다.

## Entry

Mobile 30-day review 완료. Web task/사용자/보안 요구와 owner 승인.

## Work Packages

### WP10-01 Web scope

- login/Today/chores/calendar/family/settings 중 Beta scope
- mobile-only capability와 fallback
- browser/support matrix
- Web paid purchase 여부는 별도 결정

#### WP10-01A Local Web invite sharing — PARTIAL (2026-08-10)

- 기존 성인 초대 결과의 명시적 Share action을 Web `navigator.share`에 연결
- canonical HTTPS invite URL과 localized title만 전달하고 unsupported/rejection은 stable fallback state로 축약
- 실패 뒤 자동 copy 없이 기존 별도 write-only clipboard recovery와 Android native chooser를 보존
- hosted `Permissions-Policy`, 실제 browser 지원·취소, recipient·실계정·App Link 검증은 Web 완료 Gate로 유지
- Contract: `docs/contracts/web-invite-sharing.yaml.md`
- Evidence: `docs/evidence/phase-10/WP10_01A_EVIDENCE.md`

### WP10-02 Web session/security

- HTTPS auth redirect/PKCE
- account/household switch purge
- browser storage/CSP/BFCache
- public site와 app origin/path 분리

### WP10-03 Responsive/keyboard/a11y

- medium/expanded layout
- keyboard/focus/200% zoom/screen reader
- browser history/deep link/refresh

#### WP10-03A Local keyboard/focus baseline — PARTIAL (2026-08-10)

- Web traditional focus highlight와 color-scheme-derived 공용 focus color
- 합성 인증 expanded 화면의 exact-four Tab/Enter navigation과 Today 소유 Chores 보조 흐름
- 앱 소유 dialog 26개와 modal bottom sheet 4개의 request-focus, closed-loop와 opener focus return
- raw Flutter modal call 재도입 architecture guard
- 실제 Chrome/Edge/Firefox/Safari, browser 200% zoom, screen reader, hosted 인증과 실계정은 WP10-03 완료 Gate로 유지
- Contract: `docs/contracts/web-keyboard-focus.yaml.md`
- Evidence: `docs/evidence/phase-10/WP10_03A_EVIDENCE.md`

#### WP10-03B Local route recovery baseline — PARTIAL (2026-08-10)

- browser-visible sign-in URL에는 raw path/UUID/query/fragment 대신 fixed continuation marker만 유지
- same-runtime session expiry/revoke는 검증된 상세 route, sign-in refresh는 상위 기능 destination만 복구
- explicit logout, identity/account와 active-household 전환은 이전 상세 intent를 폐기
- unknown/invalid dynamic route의 공용 404와 기존 Chore/Calendar not-found-or-forbidden 공용 unavailable 상태
- hosted SPA rewrite, 실제 browser back/forward·BFCache와 실계정 expiry/account/household 전환은 WP10-03 완료 Gate로 유지
- Contract: `docs/contracts/web-route-recovery.yaml.md`
- Evidence: `docs/evidence/phase-10/WP10_03B_EVIDENCE.md`

### WP10-04 Deploy/ops

- immutable atomic build
- API contract compatibility
- rollback
- Web SLO/alert/support

### WP10-05 Desktop demand review

- Web desktop active share
- system tray/native notification/offline/kiosk 요구
- plugin support and signing/update cost
- Flutter Windows/macOS/Linux PoC 여부
- explicit build/no-build ADR

## 자동 검증

Flutter Web release build, Playwright core journeys, security headers, logout/cache purge, API compatibility.

## 수동 검증

Chrome/Edge/Firefox/Safari, keyboard/screen reader, shared PC account switch, slow/offline state.

## Exit Gate

Web Companion Beta는 모바일 기능과 독립적으로 운영 가능하고 보안/접근성 기준을 통과한다. Desktop은 데이터가 없으면 명시적으로 보류한다.

## 비범위

- PWA 설치율 KPI
- 초기 Web Push
- 초기 Web paid purchase
- Web SEO/marketing pages
- 자동 Windows/macOS/Linux Store 출시
