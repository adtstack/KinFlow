# 30. 엔지니어링 표준과 코딩 에이전트 규칙

- 상태: ACCEPTED

## 1. 구현 원칙

- 작은 vertical slice
- secure by default
- server-authoritative authz/entitlement
- explicit state와 stable error
- codegen/contract/migration 동기화
- 증거 없는 완료 금지

## 2. Dart/Flutter

- sound null safety
- analyzer fatal warnings
- immutable model 선호
- `dynamic`/unchecked cast 최소화
- BuildContext를 async gap 뒤 무검증 사용 금지
- Widget에 business logic 금지
- provider를 service locator처럼 무분별하게 사용 금지
- error를 catch 후 무시하지 않음
- mounted/cancellation/lifecycle 처리

## 3. Async와 concurrency

- duplicate submit guard
- cancellation과 stale response
- idempotency key
- latest request wins가 안전한 경우만 적용
- stream subscription dispose
- background isolate에서 지원되는 API만 사용
- server timestamp 권위

## 4. Security

- secret/token/PII log 금지
- client role/isPlus 신뢰 금지
- RLS 없는 table 금지
- raw SQL string interpolation 금지
- deep link allowlist
- Webhook 검증
- admin/service role 최소화

## 5. 테스트

새 behavior는 정상/실패/권한/동시성/오프라인 또는 lifecycle 상태 중 관련 항목을 포함한다. mock passing만으로 외부 provider 통합 완료를 주장하지 않는다.

## 6. 문서

변경 시 다음을 함께 갱신한다.

- requirement/decision
- contract/type/schema
- migration
- test matrix
- phase plan/evidence
- changelog/ADR

## 7. 에이전트 실행 규칙

1. 작업 전 관련 문서와 contract를 읽는다.
2. 현재 Phase와 Work Package 범위를 명시한다.
3. 모순/누락은 DECISIONS에 OPEN으로 기록한다.
4. 먼저 테스트/contract 영향 분석을 작성한다.
5. 최소 변경으로 구현한다.
6. 실제 명령을 실행한다.
7. 실패를 해결하거나 정직하게 blocker로 남긴다.
8. 수동 설정을 가짜 값으로 성공 처리하지 않는다.
9. 사용하지 않는 scaffold나 TODO를 대량 생성하지 않는다.
10. 다음 Phase 기능을 선행 구현하지 않는다.

## 8. 금지된 완료 보고

- “코드상 문제 없어 보임”
- “테스트는 실행하지 않았지만 통과할 것”
- “스토어 설정은 나중에”를 완료로 표시
- RLS를 UI 테스트로 대체
- sandbox 없이 결제 완료
- 실제 기기 없이 notification/deep link 완료
- Open decision을 추측해 production default 생성

## 9. PR 설명 형식

- 목적/범위/비범위
- 요구사항/Phase ID
- architecture/security/data impact
- migrations/contracts
- screenshots/evidence
- commands/results
- manual setup
- rollback/recovery
- residual risk

## 10. 코드 리뷰 체크

- household/actor authority
- domain boundary
- error/idempotency/concurrency
- local cache purge
- localization/accessibility
- performance/lifecycle
- package/plugin impact
- observability without PII
- test quality and evidence
