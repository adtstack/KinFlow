# 14. 테스트와 검증 계획

- 상태: ACCEPTED

## 1. 테스트 피라미드

| 층 | 도구 | 대상 |
|---|---|---|
| Pure domain | `flutter_test` | value object, recurrence policy, state transition |
| Application | `flutter_test`, mocktail | use case, repository port, error mapping |
| Widget | `flutter_test` | 화면 상태, semantics, adaptive layout |
| Data adapter | local Supabase/mock server | DTO, mapper, SDK error, retry |
| DB/RLS | pgTAP/SQL harness | policy, constraint, function, migration |
| Contract | OpenAPI/schema test | Edge Function request/response/errors |
| Mobile integration | `integration_test` | authenticated vertical slice |
| Mobile E2E | Maestro + 실제 기기 | deep link, permission, purchase, notification |
| Web E2E | Playwright | Web Companion와 공개 삭제/약관 |
| Operational | scripted drill | backup/restore, rollback, webhook replay |

## 2. PR 필수 Gate

```text
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos --fatal-warnings
flutter test --coverage
dart run build_runner build --delete-conflicting-outputs
git diff --exit-code
supabase db reset
DB/RLS/contract tests
flutter build apk --debug --flavor dev
flutter build web --release (Web 영향 변경 또는 scheduled CI)
secret/dependency/license scan
```

macOS runner가 필요한 iOS build는 protected branch 또는 nightly/RC에서 수행한다.

## 3. Phase별 테스트 우선순위

- Phase 01: boot, flavor isolation, dependency boundary, codegen
- Phase 02: auth lifecycle, invite abuse, RLS matrix, child acting context
- Phase 03: chore recurrence/complete/conflict/Today
- Phase 04: DST, all-day, exception, series revision
- Phase 05: FCM states, duplicate job, quiet hours, offline purge
- Phase 06: billing lifecycle와 entitlement mismatch
- Phase 07: deletion/export, accessibility, localization, security
- Phase 08: load, recovery, upgrade, chaos, device matrix
- Phase 09: signed Store RC, sandbox, submission, staged rollout

## 4. 기기 매트릭스

최소:

- 최신 iPhone + 지원 최소 iOS 기기/Simulator
- iPad portrait/landscape/split view
- 최신 Pixel/Samsung 계열 + Android API 24 emulator
- Android tablet
- low-memory Android physical device
- large text, dark mode, reduced motion
- slow/unstable network, airplane mode, timezone 변경

## 5. 브라우저 매트릭스

Web Companion Beta 전:

- latest stable Chrome/Edge/Firefox/Safari
- keyboard only
- 200% zoom
- screen reader 대표 조합
- private browsing/storage denial
- logout/account switch/BFCache/tab restore

## 6. 시간과 반복 검증

`matrices/TIME_RECURRENCE_TEST_MATRIX.csv`를 기준으로 다음을 포함한다.

- DST gap/overlap
- 사용자·가구 timezone 차이
- 여행 중 device timezone 변경
- all-day date
- 월말/윤년
- single occurrence edit/cancel
- whole series future revision
- 완료된 과거 occurrence 보존
- materialization job retry/idempotency

## 7. 권한 검증

`matrices/RLS_AUTHORIZATION_MATRIX.csv`의 모든 행을 자동화한다. UI E2E만으로 RLS 검증을 대체하지 않는다. service-role test는 명시적 test helper와 isolated credential을 사용한다.

## 8. 결제 검증

- 실제 sandbox/test store product
- install/reinstall/restore
- account switch
- purchaser leaves household
- owner/billing owner change
- grace/billing issue/expiry/refund
- webhook duplicate/out-of-order/delay
- offline purchase confirmation pending

## 9. 접근성 검증

- semantic labels/roles/state
- focus order와 visible focus
- 200% text scale에서 clipping 없음
- touch target
- color contrast
- screen reader로 가입→Today→완료 task
- iPad/Android tablet orientation
- 키보드 shortcuts는 보조이며 필수 task를 가리지 않음

## 10. 증거

각 Gate는 `evidence/phase-XX/`에 다음을 남긴다.

- command와 exit code
- test report/coverage
- build artifact metadata
- redacted screenshot/video
- DB migration hash
- device/OS/browser version
- known issue와 승인자
- rollback/recovery 결과

## 11. 완료 금지 조건

- skipped/flaky test 원인 미기록
- production-like RLS test 미실행
- SDK mock만으로 결제/푸시 완료 주장
- emulator만으로 Store RC 완료 주장
- generated code drift
- Open decision를 임의 구현
