# Phase 01 — Flutter 기반 구축

## 목표

기능 개발 전에 재현 가능한 Android Flutter 프로젝트, dev/prod 환경 분리, 코드 경계, Supabase local, CI, 테스트, 디자인·i18n 기반을 완성한다.

## Entry

원칙적으로 Phase 00 Gate 통과가 필요하다. ADR-0002에 따라 G0 전체 통과 전에는 승인된 식별자와 toolchain을 사용하는 로컬·가역적 WP01-01만 조건부 허용하며 외부 production provider 연결은 금지한다.

## Work Packages

### WP01-01 저장소와 Toolchain

- Flutter SDK 3.44.7 exact pin
- apps/kinflow_app, apps/public_site, supabase, contracts, docs 구조
- `pubspec.lock`, `.fvmrc`, analysis options, machine-readable toolchain contract
- Android dev/prod flavor와 별도 application ID
- README bootstrap 명령

### WP01-02 App Shell

- `main_dev/prod.dart`
- bootstrap과 dependency initialization
- MaterialApp.router/go_router shell
- loading/fatal recovery/environment banner
- theme/locale skeleton

### WP01-03 Architecture Boundary

- domain/application/data/presentation sample slice
- Riverpod override/DI
- repository port와 fake adapter
- architecture import test
- generated model/codegen drift test

### WP01-04 Supabase Local

- CLI pin, config, reset
- baseline migrations/RLS default deny
- seed/test users/households
- Edge Function hello/health contract
- Flutter dev client connectivity

### WP01-05 Design/i18n/a11y

- design tokens
- responsive scaffold compact/medium/expanded
- EN/KO ARB + pseudo locale
- semantics/text-scale smoke

### WP01-06 Observability/config

- structured logger와 redaction
- Sentry dev/prod
- public configuration loader/validator
- no-secret scan

### WP01-07 CI

- format/analyze/test/codegen
- DB/RLS/contract
- Android dev/prod build
- artifact/test reports

### WP01-08 Android Platform Capability Registry (follow-on)

- 알림·Store 결제·암호화 저장소·외부 링크·background exact capability registry
- production/unavailable composition의 provider·fallback snapshot
- 알림 권한 미결정·거부·일시 실패를 포함한 deterministic local 상태 해석
- Settings의 localized 기기 기능 상태와 기존 안전 대안 route
- Web/iOS와 실제 provider·실기기 health 검증은 각 후속 Gate로 유지

### WP01-09 Android Capability Self-Check and Recovery (follow-on)

- exact five capability의 준비됨·조치 필요·대안/제한 집계와 stable recovery priority
- 시스템 prompt 없이 기존 notification coordinator로 현재 로컬 권한만 명시적으로 재확인
- single-flight 점검 결과와 즉시 재계산되는 localized recovery plan
- 별도 provider health/Store probe 없이 기존 notification coordinator와 notification·subscription·diagnostics route만 사용
- 실제 Android settings 왕복, provider health, 실계정·다중기기·실기기는 마지막 통합 Gate로 유지

### WP01-10 Privacy-safe Analytics Governance (follow-on)

- exact six typed usage event allowlist와 arbitrary event/attribute 차단
- 기본 OFF `analytics-usage-v1` device/environment-local preference와 policy change fail-closed reset
- Managed Child 선차단, unavailable/throwing sink 비전파와 authenticated-entry lifecycle 연결
- Settings의 collection 상태·child policy·SDK inventory·never-collected 공개 화면
- 외부 behavioral analytics SDK, DB/API/server consent record와 새 permission은 추가하지 않음
- hosted provider·법률 동의·실계정·다중기기·실기기는 마지막 통합 Gate로 유지

### WP01-11 Core Primary Navigation and Chores Hub (follow-on)

- authenticated adult core surface에 Today, Calendar, Family, Settings exact four destination과 route-selected state를 제공하고 Chores는 Today 소유 보조 흐름으로 유지
- compact bottom NavigationBar, medium collapsed NavigationRail, expanded extended NavigationRail을 같은 순서로 구현
- `/chores`는 upcoming, overdue, completed와 Everyone/Me만 제공하고 Today Calendar composition은 불러오지 않음
- `/family` primary route와 기존 `/family/members` compatibility alias를 동일 authorization 화면에 연결
- 작성·확인·privacy 등 subflow는 primary navigation을 숨기고 별도 state·storage·analytics·DB/API를 추가하지 않음
- EN/KO/EN-XA compact 200%, RTL, 48dp와 route traversal은 로컬 자동화하고 실제 계정·TalkBack·phone/tablet 실기기는 마지막 통합 Gate로 유지

### WP01-12 Web Companion Build and Safe Capability Baseline (follow-on)

- Android와 독립된 Flutter Web dev/prod release build, exact public config/version audit와 CI artifact Gate
- path URL strategy, no-referrer/noindex shell과 PWA manifest·Flutter service worker·persistent API cache 비활성화
- email OTP 우선 sign-in과 native Google unavailable 상태, purge 가능한 auth session 외 Web persistent app state 비활성화
- inbox+configured email, server entitlement read, re-auth, browser external link와 server notification/inbox exact-five fallback composition
- package `kinflow_app`, platform `web` exact runtime header와 dev/prod global·six-feature server policy/enforcement
- local browser sign-in/capability smoke는 자동·도구 검증하고 hosted HTTPS/CSP/SPA rewrite·OAuth callback·실계정·browser matrix는 독립 Web Gate로 유지

## 자동 검증

- clean checkout bootstrap
- analyzer warning 0
- tests/codegen diff 0
- Supabase reset + RLS smoke
- dev/prod Android APK build
- dependency boundary import 0

## 수동 검증

- Android shell 실제 실행
- EN/KO/pseudo/dark/large text
- dev/prod visual separation
- Sentry redaction 확인

## Exit Gate

- onboarding 전 shell이 Android 실제 기기에서 실행
- CI green and reproducible
- environment isolation 확인
- domain이 Flutter/SDK에 의존하지 않음
- evidence와 Phase 02 handoff

## Rollback

기능 데이터가 없으므로 깨끗한 scaffold commit으로 되돌린다. toolchain·플랫폼·환경 변경은 ADR 없이 cherry-pick하지 않는다. iOS/staging 재도입은 ADR-0002 재검토 조건을 따른다.
