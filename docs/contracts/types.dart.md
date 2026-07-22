# 원본 파일 문서화: `contracts/types.dart`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/types.dart`
- 원본 형식: `dart`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.

```dart
// Normative examples. Generate concrete DTOs from the accepted API contract.

typedef UserId = String;
typedef HouseholdId = String;
typedef MembershipId = String;
typedef ManagedMemberId = String;
typedef OccurrenceId = String;
typedef RequestId = String;

enum HouseholdRole { owner, admin, member }
enum MembershipStatus { active, invited, removed, suspended }
enum EntitlementStatus {
  inactive,
  trialing,
  active,
  gracePeriod,
  billingIssue,
  expired,
  revoked,
}

sealed class KinFlowFailure {
  const KinFlowFailure({required this.code, this.requestId});
  final String code;
  final RequestId? requestId;
}

final class ValidationFailure extends KinFlowFailure {
  const ValidationFailure({required super.code, super.requestId, this.fields = const {}});
  final Map<String, String> fields;
}

final class AuthorizationFailure extends KinFlowFailure {
  const AuthorizationFailure({required super.code, super.requestId});
}

final class VersionConflictFailure extends KinFlowFailure {
  const VersionConflictFailure({required super.code, super.requestId, required this.latestVersion});
  final int latestVersion;
}

sealed class Result<T, F> {
  const Result();
}

final class Success<T, F> extends Result<T, F> {
  const Success(this.value);
  final T value;
}

final class Failure<T, F> extends Result<T, F> {
  const Failure(this.error);
  final F error;
}

final class HouseholdEntitlementSnapshot {
  const HouseholdEntitlementSnapshot({
    required this.householdId,
    required this.key,
    required this.status,
    required this.verifiedAt,
    this.validUntil,
  });
  final HouseholdId householdId;
  final String key;
  final EntitlementStatus status;
  final DateTime verifiedAt;
  final DateTime? validUntil;
}
```
