# Phase 실행 프롬프트

다음 값을 채워 사용한다.

```text
PHASE: <예: 02>
WORK PACKAGE: <예: WP02-04 Invite>
TARGET PLATFORMS: <iOS/Android/Server 등>
```

`START_HERE.md`, `DECISIONS.md`, `SPEC_BASELINE.md`, `IMPLEMENTATION_PLAN.md`, 해당 Phase 문서, 관련 `contracts/`와 matrix를 읽어라.

지금은 지정한 Work Package만 완성하라. 먼저 다음을 출력한다.

1. 수용 기준
2. 비범위
3. 선행 결정과 blocker
4. data/RLS/API/Flutter layer 영향
5. 자동·수동 테스트
6. rollback/recovery

그 다음 작은 reviewable diff로 구현한다.

필수 규칙:

- domain에서 Flutter/SDK import 금지
- server authorization과 RLS 우선
- idempotency/concurrency/error state 명시
- generated code와 migration 동기화
- localization/accessibility/offline/lifecycle 상태 고려
- secret/PII log 금지
- Phase 밖 기능 선행 구현 금지

완료 전 실제 명령을 실행하고 `evidence/phase-<PHASE>/`를 갱신하라. 실패한 검증은 숨기지 말고 원인과 영향, 안전한 다음 조치를 보고하라.
