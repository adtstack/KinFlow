# Phase 01 — Flutter 기반 구축

## 목표

기능 개발 전에 재현 가능한 Flutter 프로젝트, 환경 분리, 코드 경계, Supabase local, CI, 테스트, 디자인·i18n 기반을 완성한다.

## Entry

Phase 00 Gate 통과, 식별자와 toolchain 승인.

## Work Packages

### WP01-01 저장소와 Toolchain

- Flutter SDK 3.44.7 exact pin
- app/public_site/supabase/contracts/docs 구조
- `pubspec.lock`, analysis options
- dev/staging/prod flavor
- README bootstrap 명령

### WP01-02 App Shell

- `main_dev/staging/prod.dart`
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
- Sentry dev/staging
- public configuration loader/validator
- no-secret scan

### WP01-07 CI

- format/analyze/test/codegen
- DB/RLS/contract
- Android build
- iOS simulator build
- scheduled Web build
- artifact/test reports

## 자동 검증

- clean checkout bootstrap
- analyzer warning 0
- tests/codegen diff 0
- Supabase reset + RLS smoke
- dev Android APK and iOS simulator build
- dependency boundary import 0

## 수동 검증

- iOS/Android shell 실제 실행
- EN/KO/pseudo/dark/large text
- dev/staging visual separation
- Sentry redaction 확인

## Exit Gate

- onboarding 전 shell이 두 모바일 플랫폼에서 실행
- CI green and reproducible
- environment isolation 확인
- domain이 Flutter/SDK에 의존하지 않음
- evidence와 Phase 02 handoff

## Rollback

기능 데이터가 없으므로 깨끗한 scaffold commit으로 되돌린다. toolchain 변경은 ADR 없이 cherry-pick하지 않는다.
