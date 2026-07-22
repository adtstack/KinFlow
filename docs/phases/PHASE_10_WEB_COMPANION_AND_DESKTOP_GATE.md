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

### WP10-02 Web session/security

- HTTPS auth redirect/PKCE
- account/household switch purge
- browser storage/CSP/BFCache
- public site와 app origin/path 분리

### WP10-03 Responsive/keyboard/a11y

- medium/expanded layout
- keyboard/focus/200% zoom/screen reader
- browser history/deep link/refresh

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
