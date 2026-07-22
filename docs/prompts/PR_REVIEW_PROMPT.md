# KinFlow Flutter PR Review Prompt

이 PR을 제품 요구사항, Flutter 아키텍처, Supabase/RLS, 보안·개인정보, 결제·시간대·동시성, 접근성, 테스트 증거 관점에서 검토하라.

우선순위 순서:

1. household 간 데이터 노출 또는 authz 우회
2. child/parental gate 우회와 PII/logging
3. billing entitlement/restore/mapping 오류
4. recurrence/timezone/data loss
5. migration/old client compatibility
6. SDK를 Widget/Provider에서 직접 호출하거나 domain boundary 위반
7. async lifecycle/idempotency/conflict/offline 문제
8. 접근성/localization/adaptive layout
9. 누락된 테스트/evidence/docs

각 발견에는 severity, 파일/위치, 재현 또는 근거, 사용자 영향, 구체 수정안을 적는다. 스타일 선호만으로 blocker를 만들지 않는다. 실행하지 못한 검증은 명시한다.
