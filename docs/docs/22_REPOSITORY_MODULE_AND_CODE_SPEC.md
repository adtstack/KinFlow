# 22. 저장소, 모듈, 코드 구조 스펙

- 상태: ACCEPTED

## 1. 권장 저장소

```text
kinflow/
├─ apps/
│  ├─ kinflow_app/
│  │  ├─ lib/
│  │  ├─ test/
│  │  ├─ integration_test/
│  │  ├─ ios/
│  │  ├─ android/
│  │  └─ web/
│  └─ public_site/
├─ packages/
│  ├─ kinflow_domain/
│  ├─ kinflow_design_system/
│  ├─ kinflow_api_contracts/
│  └─ kinflow_test_support/
├─ supabase/
│  ├─ migrations/
│  ├─ functions/
│  ├─ tests/
│  └─ seed.sql
├─ contracts/
├─ docs/
├─ phases/
├─ e2e/
│  ├─ maestro/
│  └─ playwright/
├─ scripts/
└─ evidence/
```

초기 팀이 작으면 Flutter packages를 앱 내부에서 시작할 수 있지만 domain/design/contracts 경계는 유지한다. 실제 분리는 Phase 01 ADR로 확정한다.

## 2. Feature 구조

```text
lib/features/chores/
├─ domain/
│  ├─ entities/
│  ├─ value_objects/
│  ├─ policies/
│  └─ repositories/
├─ application/
│  ├─ use_cases/
│  ├─ commands/
│  └─ queries/
├─ data/
│  ├─ dto/
│  ├─ mappers/
│  ├─ datasources/
│  └─ repositories/
└─ presentation/
   ├─ screens/
   ├─ widgets/
   ├─ controllers/
   └─ providers/
```

공통 `core/`는 dumping ground가 아니다. 둘 이상의 feature가 안정된 의미로 공유할 때만 이동한다.

## 3. 파일과 이름

- Dart standard snake_case file
- class/enum PascalCase
- provider는 역할이 드러나는 이름
- DTO suffix, domain entity에는 DTO suffix 금지
- `Manager`, `Helper`, `Utils` 같은 모호한 이름 제한
- command/query/use case에 행동 동사 사용

## 4. Domain model

- ID는 raw String 남용 대신 value object/typedef wrapper
- money, timezone, local date, recurrence, role을 type으로 표현
- invalid state는 constructor/factory에서 거부
- domain error는 stable sealed type
- equality와 serialization 책임을 분리

예:

```dart
sealed class CompleteChoreFailure {}
final class VersionConflict extends CompleteChoreFailure { ... }
final class PermissionDenied extends CompleteChoreFailure { ... }
```

## 5. Repository 계약

Repository는 사용자 task 관점의 port다. Supabase table 이름을 그대로 노출하지 않는다.

```dart
abstract interface class ChoreRepository {
  Future<Result<TodayChores, ChoreFailure>> loadToday(...);
  Future<Result<ChoreOccurrence, ChoreFailure>> complete(...);
}
```

SDK exception은 data layer에서 domain/application failure로 변환한다.

## 6. Riverpod 코드

- provider definition과 UI를 과도하게 같은 파일에 두지 않는다.
- `ref.watch`는 rendering dependency, `ref.read`는 command에 제한
- async cancellation/dispose 처리
- autoDispose 여부를 데이터 생명주기에 맞춤
- family provider key에 household/user context 포함
- provider override로 test double 주입

## 7. UI component

- design token 사용, 임의 숫자/색상 최소화
- business rule을 component에 넣지 않음
- empty/loading/error/offline/permission-denied 상태를 명시
- destructive action 확인과 undo 정책
- screen reader semantics와 test key

## 8. Serialization

- API/DB DTO는 snake_case 매핑 명시
- unknown enum forward compatibility 정책
- timezone/date/instant 형식을 계약에 고정
- optional과 nullable 의미를 구분
- generated serializer + negative fixture test

## 9. 오류와 Result

expected business failure는 Result/sealed failure로 처리하고 programmer invariant violation은 exception/assert로 구분한다. UI는 stable failure를 localized presentation model로 변환한다.

## 10. Commit/PR 단위

권장 vertical slice:

```text
migration/RLS
→ API/RPC contract
→ Dart DTO/repository
→ use case/provider
→ screen
→ automated tests
→ evidence/docs
```

한 PR에서 여러 Phase를 섞지 않는다.
