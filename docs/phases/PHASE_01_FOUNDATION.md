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
