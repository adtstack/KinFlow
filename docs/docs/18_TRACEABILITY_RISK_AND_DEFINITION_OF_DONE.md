# 18. 추적성, 위험, Definition of Done

- 상태: ACCEPTED

## 1. 추적 체계

각 요구사항은 다음 연결을 가져야 한다.

```text
Requirement ID
→ Decision/ADR
→ Phase/Work Package
→ Code module/API/DB migration
→ Automated test
→ Manual evidence
→ Release Gate
→ Risk item
```

`matrices/REQUIREMENTS_TRACEABILITY.csv`, `SPEC_TRACEABILITY.csv`, `RISK_REGISTER.csv`가 인덱스 역할을 한다.

## 2. 변경 규칙

- 제품·보안·결제·아동·삭제 결정은 ADR 없이 변경 금지
- contract 변경은 schema/type/test/migration/docs를 같은 PR에 포함
- 새로운 dependency는 목적, 대안, license, platform support, maintenance 평가
- Phase 범위 밖 구현은 feature flag 또는 별도 change request

## 3. Work Package Definition of Ready

- 요구사항과 제외 범위가 식별됨
- 선행 decision이 ACCEPTED
- 데이터/권한 영향 분석
- 테스트와 증거 위치 정의
- rollback/recovery 경로 정의
- 외부 console dependency 준비

## 4. Work Package Definition of Done

- acceptance criteria 구현
- format/analyze/test/codegen 성공
- DB/RLS/contract test 성공
- iOS/Android 관련 build 또는 실기기 검증
- accessibility/localization/error/offline 상태 검토
- security/privacy review
- evidence 저장
- 문서/traceability 업데이트
- known issue와 owner 기록

## 5. Phase Definition of Done

- Phase scope 100% 또는 승인된 deferral
- exit Gate 전부 통과
- blocker/critical defect 0
- migration/recovery 검증
- performance budget 확인
- 수동 setup 미완료가 다음 Phase를 차단하는지 명시
- 다음 Phase handoff report

## 6. Release Definition of Done

- signed production candidate
- store sandbox purchase/restore
- RLS/billing/time matrices
- deletion/export end-to-end
- privacy/legal/store metadata 승인
- backup/restore 및 incident tabletop
- rollout/rollback owner
- SLO dashboard/alerts
- release notes/support brief

## 7. 주요 위험 범주

- household isolation failure
- child privacy/mixed-audience misclassification
- recurrence/DST corruption
- store entitlement mismatch
- shared-device cache leakage
- plugin platform incompatibility
- signing credential compromise
- Store SDK/target policy 변화
- scope explosion across mobile/web/desktop
- AI-generated code with unverified behavior

각 위험에는 likelihood, impact, owner, mitigation, trigger, residual risk를 기록한다.

## 8. AI/Vibe-coding 품질 규칙

- “완료”는 실행 로그와 artifact로 증명한다.
- 존재하지 않는 SDK/API를 추측하지 않는다.
- generated code와 migration을 생략하지 않는다.
- TODO를 silent success로 처리하지 않는다.
- 사용자 요청과 문서가 충돌하면 상위 결정과 보안 원칙을 우선하고 DECISIONS에 기록한다.
- 대규모 일괄 생성보다 작은 vertical slice와 reviewable diff를 사용한다.
