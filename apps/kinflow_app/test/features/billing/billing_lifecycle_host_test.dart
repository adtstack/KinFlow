import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/domain/entities/auth_session.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/billing/presentation/widgets/billing_lifecycle_host.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

void main() {
  test('billing lifecycle exposes only a complete user-household context', () {
    final AuthSession session = AuthSession(userId: _userId);
    final ActiveHousehold household = ActiveHousehold(
      householdId: _householdId,
      memberId: _memberId,
    );

    expect(billingContextForAuthState(const AuthBootstrapping()), isNull);
    expect(
      billingContextForAuthState(AuthAuthenticatedNoHousehold(session)),
      isNull,
    );
    final active = billingContextForAuthState(
      AuthAuthenticatedActiveHousehold(session, household),
    );
    expect(active?.userId, _userId);
    expect(active?.householdId, _householdId);
    final refreshing = billingContextForAuthState(
      AuthRefreshing(session, activeHousehold: household),
    );
    expect(refreshing?.userId, _userId);
    expect(refreshing?.householdId, _householdId);
    expect(billingContextForAuthState(const AuthUnauthenticated()), isNull);
  });
}

final AuthUserId _userId = AuthUserId.tryParse(
  '11111111-1111-4111-8111-111111111111',
)!;
final HouseholdId _householdId = HouseholdId.tryParse(
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
)!;
final HouseholdMemberId _memberId = HouseholdMemberId.tryParse(
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
)!;
