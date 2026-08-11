import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/domain/entities/auth_session.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/settings/presentation/widgets/profile_preferences_lifecycle_host.dart';

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

  test('scope exists only for an authenticated active household', () {
    expect(
      profilePreferencesScopeKeyForAuthState(
        AuthAuthenticatedActiveHousehold(session, household),
      ),
      '70000000-0000-4000-8000-000000000001|72000000-0000-4000-8000-000000000001',
    );
    expect(
      profilePreferencesScopeKeyForAuthState(
        AuthRefreshing(session, activeHousehold: household),
      ),
      isNotNull,
    );
    expect(
      profilePreferencesScopeKeyForAuthState(
        AuthAuthenticatedNoHousehold(session),
      ),
      isNull,
    );
    expect(
      profilePreferencesScopeKeyForAuthState(const AuthUnauthenticated()),
      isNull,
    );
  });
}
