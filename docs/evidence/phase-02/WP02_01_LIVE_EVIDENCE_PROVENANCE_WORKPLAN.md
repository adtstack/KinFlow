# Phase 02 WP02-01 Live Evidence APK Provenance Work Plan

- 작성일: 2026-07-29
- 기준 commit: `0325c10`
- Work Package: WP02-01 — two-adult completion APK/source provenance
- 상태: IN PROGRESS

## Problem

현재 completion validator는 evidence의 commit이 repository에 존재하는지와 APK의 SHA-256이 evidence와 일치하는지를 각각 확인한다. 그러나 APK 자체에 source commit이 들어 있지 않아 임의의 기존 commit과 stale APK를 함께 제출해도 두 검사가 독립적으로 통과할 수 있다. 실제 성인 2인·두 기기 결과를 특정 source 상태에 귀속하려면 이 간극을 fail-closed로 닫아야 한다.

## Requirements

1. Android APK는 build-time manifest metadata로 exact 40-hex source commit과 `clean`/`dirty` source state를 포함한다.
2. repository Android build/run wrapper는 현재 `HEAD`를 사용하고 tracked/untracked source 변경 여부로 state를 계산한다.
3. 일반 개발용 dirty build는 허용하되 Android build report에 state를 명시한다.
4. two-adult completion validator는 APK manifest의 commit이 evidence commit과 exact match이고 source state가 `clean`일 때만 성공한다.
5. APK metadata reader/aapt failure, malformed/duplicate metadata와 mismatch는 provider/tool detail을 노출하지 않는 stable error로 거부한다.
6. account, device serial, token, email, invite URL과 household/member 식별자는 새 metadata·report·test evidence에 포함하지 않는다.

## Scope

- Gradle manifest placeholder와 Android application metadata
- `scripts/ci/android-build.sh`, `scripts/run-android.sh`의 provenance 입력
- APK manifest provenance parser와 completion verifier
- parser, mismatch, dirty, masking, build-contract 회귀 테스트
- two-adult runbook과 evidence contract 설명 정정

## Explicit Non-scope

- 실제 APK 설치, Google account 또는 Supabase session 실행
- 실제 두 기기 27-check 결과 생성·변경
- signing key, OAuth/Supabase credential 또는 runtime config를 metadata에 포함
- Git commit 서명/attestation, Play Integrity 또는 release signing 승격
- WP02-05~07 역할/Owner/authorization 후속 Work Package

## Validation

- focused Node evidence/parser tests
- Flutter Android manifest/build wiring contract test
- dev/prod Android build에서 embedded metadata와 build report 일치
- full repository quality/backend/dependency/dev/prod gate
- secret scan, `git diff --check`, GitHub Actions final gate

## Stop / Rollback

- commit이 APK에서 추출되지 않거나 dirty/mismatch APK가 completion을 통과하면 중단한다.
- metadata가 account/device/runtime credential을 포함하거나 raw `aapt` failure가 출력되면 중단한다.
- rollback은 manifest/Gradle/build wrapper/validator/test/docs 변경을 함께 revert한다. DB/API/provider migration은 없다.

## Completion Boundary

- provenance PASS는 live 관찰의 출처를 강화할 뿐 실제 관찰을 대신하지 않는다.
- 성인 2인·Android 2기기 preflight와 exact 27개 check가 모두 실제로 `pass`인 completion JSON 전에는 4단계 live gate가 pending이다.
