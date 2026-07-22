# KinFlow Flutter 앱 구현 계획 v1.0

> **Markdown 전용판 안내:** 비-Markdown 원본 계약과 검증표는 `<원본명>.md`의 코드 블록에 있습니다. 실제 구현 전에 `MD_ONLY_FORMAT_GUIDE.md`에 따라 원본 파일로 추출하고 검증합니다.


- 상태: ACCEPTED
- 원칙: 한 Phase 안에서도 한 번에 하나의 vertical Work Package만 구현한다.

## 1. Phase 지도

| Phase | 목표 | 주요 Gate |
|---|---|---|
| 00 | 제품·연령·국가·가격·기술 차단 결정 | Decision Gate |
| 01 | Flutter/Supabase/CI 기반 | Foundation Gate |
| 02 | 인증·가구·초대·역할·Managed Child | Household Alpha Gate |
| 03 | 집안일·반복·완료·Today | Chores Value Gate |
| 04 | 공유 일정·반복·예외·시간대 | Calendar Value Gate |
| 05 | 알림·작업 큐·신뢰성·제한된 오프라인 | Reliability Gate |
| 06 | RevenueCat·Store·Household Entitlement | Billing Gate |
| 07 | 삭제·내보내기·보안·접근성·글로벌 | Compliance Gate |
| 08 | 실제 가족 Beta·성능·복구·RC 감사 | Beta Exit Gate |
| 09 | Store 제출·점진 출시·30일 운영 | Mobile Launch Gate |
| 10 | Web Companion Beta와 Desktop 수요 검토 | Independent Expansion Gate |

## 2. 선행 의존성

```text
00 → 01 → 02 → 03 → 04
                  ├→ 05
                  ├→ 06
                  └→ 07
05 + 06 + 07 → 08 → 09 → 10
```

Phase 03과 04의 내부 설계는 병렬 검토 가능하지만, 공통 recurrence/time model을 먼저 합의한다. Billing UI는 Phase 06 전 prototype할 수 있으나 production purchase를 열지 않는다.

## 3. Work Package 규칙

각 Work Package는 다음 산출물을 가진다.

- 요구사항/비범위
- data/RLS/API 영향
- Flutter domain/application/presentation 변경
- automated test
- 실제 기기 또는 수동 검증
- evidence
- rollback/recovery
- traceability 업데이트

권장 크기는 하나의 사용자 task 또는 한 개의 보안 경계다.

## 4. 전 Phase 공통 명령

```text
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos --fatal-warnings
flutter test --coverage
dart run build_runner build --delete-conflicting-outputs
git diff --exit-code
supabase db reset
DB/RLS/contract tests
```

플랫폼 변경은 관련 iOS/Android build와 실제 기기 smoke를 추가한다.

## 5. Gate 원칙

- 자동 테스트 결과만으로 UX/Store/permission 완료를 주장하지 않는다.
- 수동 console 작업은 evidence가 있어야 통과한다.
- blocker/critical defect 0.
- OPEN decision과 production secret 미준비는 관련 기능을 비활성화한다.
- 다음 Phase를 시작하기 전에 completion report를 작성한다.

## 6. 문서

상세 실행은 `phases/PHASE_XX_*.md`를 따른다. 요구사항 변경은 `DECISIONS.md`, 관련 contract, matrix, Phase 문서를 함께 수정한다.
