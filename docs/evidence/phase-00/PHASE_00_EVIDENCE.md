# Phase 00 Evidence

- Phase: 00
- Commit/tag 기준: base `7fd5729`; activation prototype change
- App version/build/runtime: disposable prototype 0.0.1+1; isolated Flutter 3.44.7/Dart 3.12.2
- DB schema/migration head: no production migration; isolated PostgreSQL 16 RLS PoC
- Environment: local macOS 26.4.1 arm64
- 검증일: 2026-07-23
- 검증자/reviewer: Codex local audit / Product scope DG00-01~03 approved / remaining sign-off pending

## Scope / Requirements

| ID | 결과 | 증거 |
|---|---|---|
| WP00-01 사용자 문제 인터뷰 | NOT RUN | `../discovery/RESEARCH_RUNBOOK.md`, `../discovery/hypothesis-scorecard.md` |
| WP00-02 MVP와 성공 기준 | ACCEPTED | `../../adr/ADR-0001-mvp-scope.md`, D-051 |
| WP00-03 출시 시장과 아동 분류 | PARTIAL | D-013/D-039 제품 승인; 법률·Store questionnaire와 보관 정책 미완료 |
| WP00-04 가격과 구독 정책 | PARTIAL | 경쟁 가격 참고 및 smoke-test 셀 정의, H-06/H-07 미실행 |
| WP00-05 기술·계정 준비 | PARTIAL | `MANUAL_SETUP_STATUS.md` |
| WP00-06 위험 PoC | PARTIAL | `TECHNICAL_POC.md`; RLS/analyze/test/Android APK PASS, provider/device boot NOT RUN |

## Automated Commands

| 명령 | 결과 | 로그 파일 |
|---|---|---|
| Markdown fence balance 검사 | PASS | `logs/document-validation.log` |
| DECISIONS ID 중복/OPEN 수 검사 | PASS — duplicate 0, OPEN 1 | `logs/document-validation.log` |
| Package manifest SHA-256 105개 검사 | PASS | `logs/document-validation.log` |
| `/private/tmp/kinflow-flutter-3.44.7/bin/flutter --version --machine` | PASS — Flutter 3.44.7, Dart 3.12.2 | `TECHNICAL_POC.md` |
| Activation prototype `flutter analyze --fatal-infos --fatal-warnings` | PASS — issue 0 | `logs/activation-prototype.log` |
| Activation prototype `flutter test` | PASS — 4/4 | `logs/activation-prototype.log` |
| PostgreSQL household RLS test | PASS | `logs/rls-poc.log` |
| Activation prototype `flutter build apk --debug` | PASS — APK 146,166,848 bytes | `logs/activation-prototype.log` |
| Flutter iOS build/boot | NOT RUN — runtime/CocoaPods 없음 | `TECHNICAL_POC.md` |

## Database / Authorization

- migration reset: NOT RUN — production/Supabase project 없음
- RLS allow/deny: PASS for minimal household read isolation
- same-household invariant: PASS for minimal PoC
- concurrency/idempotency: NOT RUN — Phase 00 RLS spike 비범위

## Device / Manual Validation

| 기기/OS | 흐름 | 결과 | 증거 |
|---|---|---|---|
| iOS | Flutter boot/auth callback/push | NOT RUN | Simulator runtime와 실제 기기 없음 |
| Android | Flutter boot/push | NOT RUN | AVD와 실제 기기 없음 |
| Store sandbox | RevenueCat catalog | NOT RUN | Store/RevenueCat project와 SKU 없음 |

## Accessibility / Localization

- en: NOT RUN — prototype build 없음
- ko: BUILD PRESENT — 수동 검증 NOT RUN
- pseudo/long text: NOT RUN
- VoiceOver/TalkBack: NOT RUN
- large text: NOT RUN

## Observability

- logs/metrics/alerts: 연구용 최소 event 목록만 ADR-0001에 정의
- PII check: 새 evidence에 이름, 이메일, 전화번호, 자녀 실명, secret 없음

## Store / Console Manual Work

- 외부 console 변경 없음.
- 계정과 owner는 모두 UNVERIFIED로 기록했다.

## Known Issues / Risks

| Severity | 내용 | Owner | Due/Acceptance |
|---|---|---|---|
| Critical | H-02 실제 가족 참여 증거 없음 | Product Research | G0 |
| Critical | H-07 반복 지불 가치 증거 없음 | Product/Growth | G0 hypothesis / G6 price |
| High | 성인 대상 Store questionnaire와 법률 검토 미완료 | Legal/Privacy | G0 / Store RC |
| High | 앱 식별자와 production console named owner 미지정 | Product/Engineering | production project 전 |
| High | iOS/Android 실제 기기 PoC 불가 | Mobile Platform | G0 |
| Medium | 가격·보관·console ownership 결정 미완료 | Product/Legal/Operations | 관련 Gate 전 |

## Rollback Evidence

- RLS PostgreSQL container는 중지 후 `--rm`으로 제거됨.
- 격리 Flutter SDK는 `/private/tmp/kinflow-flutter-3.44.7`에 있으며 공용 Flutter SDK 3.32.8은 업그레이드하지 않음.
- Android debug APK는 prototype의 ignored `build/` 아래에 생성됐고 공유 Gradle cache에 의존성이 추가됨.
- production project, 사용자, 결제, token, secret을 생성하지 않음.

## Sign-off

- Engineering: PENDING
- Product: PARTIAL — DG00-01~03 approved; remaining G0 items pending
- Security/Privacy: PENDING
- Release: N/A for Phase 00

## Platform / Release Gate Evidence

- 대상 Gate: G0 Decision Gate
- target platforms: iOS/Android risk PoC
- web release ID/URL: N/A
- iOS build: NOT RUN
- Android build: PASS, debug APK 생성

| Platform | Build/export | E2E | 수동 환경 | 결과 | Evidence |
|---|---|---|---|---|---|
| iOS | NOT RUN | N/A | runtime 없음 | BLOCKED | `TECHNICAL_POC.md` |
| Android | PASS, debug APK | N/A | AVD/device 없음 | PARTIAL | `TECHNICAL_POC.md` |
| Web | 비범위 | N/A | N/A | N/A | ADR-0001 |
| Web Companion | 비범위 | N/A | N/A | N/A | ADR-0001 |

### Capability/Fallback

| Capability | Provider | Unsupported/Denied State | Fallback Verified | Evidence |
|---|---|---|---|---|
| Auth deep link | Supabase | project/identifier 미결정 | 아니오 | `TECHNICAL_POC.md` |
| Push | FCM/APNs | project/device 미준비 | 아니오 | `TECHNICAL_POC.md` |
| Billing catalog | RevenueCat | project/SKU 미준비 | production OFF | `DECISION_GATE_REVIEW.md` |
