import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/features/calendar/presentation/calendar_failure_message.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/presentation/chore_failure_message.dart';
import 'package:kinflow_app/features/household/domain/failures/invite_failure.dart';
import 'package:kinflow_app/features/household/presentation/invite_failure_message.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';
import 'package:kinflow_app/l10n/app_localizations_en.dart';
import 'package:kinflow_app/l10n/app_localizations_ko.dart';

void main() {
  for (final AppLocalizations localizations in <AppLocalizations>[
    AppLocalizationsEn(),
    AppLocalizationsKo(),
  ]) {
    test('${localizations.localeName} uses stable feature policy messages', () {
      expect(
        choreFailureMessage(
          localizations,
          const ChoreFailure(ChoreFailureKind.featurePolicyUnavailable),
        ),
        localizations.featurePolicyUnavailableError,
      );
      expect(
        calendarFailureMessage(
          localizations,
          const CalendarFailure(CalendarFailureKind.featureLimitReached),
        ),
        localizations.featureLimitReachedError,
      );
      expect(
        inviteFailureMessage(
          localizations,
          const InviteFailure(InviteFailureKind.featureLimitReached),
        ),
        localizations.featureLimitReachedError,
      );
    });
  }
}
