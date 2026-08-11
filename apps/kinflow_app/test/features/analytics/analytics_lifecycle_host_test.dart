import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/analytics/presentation/widgets/analytics_lifecycle_host.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/domain/entities/auth_session.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

void main() {
  final AuthSession session = AuthSession(
    userId: AuthUserId.tryParse('70000000-0000-4000-8000-000000000001')!,
  );
  final ActiveHousehold household = ActiveHousehold(
    householdId: HouseholdId.tryParse('72000000-0000-4000-8000-000000000001')!,
    memberId: HouseholdMemberId.tryParse(
      '73000000-0000-4000-8000-000000000001',
    )!,
  );

  test('analytics entry exists only with session and active household', () {
    expect(
      analyticsAuthenticatedEntryForAuthState(
        AuthAuthenticatedActiveHousehold(session, household),
      ),
      isTrue,
    );
    expect(
      analyticsAuthenticatedEntryForAuthState(
        AuthRefreshing(session, activeHousehold: household),
      ),
      isTrue,
    );
    expect(
      analyticsAuthenticatedEntryForAuthState(
        AuthAuthenticatedNoHousehold(session),
      ),
      isFalse,
    );
    expect(
      analyticsAuthenticatedEntryForAuthState(const AuthUnauthenticated()),
      isFalse,
    );
  });
}
