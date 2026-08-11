import 'package:kinflow_app/app/router/app_primary_destination.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';

abstract final class AppRoutes {
  static const String home = '/';
  static const String authLoading = '/auth/loading';
  static const String householdOnboarding = '/onboarding/household';
  static const String guidedChoreSetup = '/onboarding/chores';
  static const String invite = '/invite';
  static const String inviteCapture = '/invite/:token';
  static const String inviteCreate = '/family/invite';
  static const String householdMembers = '/family/members';
  static const String signIn = '/sign-in';
  static const String today = '/today';
  static const String chores = '/chores';
  static const String calendar = '/calendar';
  static const String calendarImport = '/calendar/import';
  static const String family = '/family';
  static const String calendarEvent = '/calendar/event/:occurrenceId';
  static const String choreOccurrence = '/chores/occurrence/:occurrenceId';
  static const String choreCreate = '/chores/new';
  static const String choreTrash = '/chores/trash';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String householdSwitch = '/settings/households';
  static const String subscription = '/settings/subscription';
  static const String accountDeletion = '/settings/account-deletion';
  static const String analyticsPrivacy = '/settings/analytics-privacy';
  static const String dataExport = '/settings/data-export';
  static const String diagnostics = '/settings/diagnostics';
  static const String deviceCapabilities = '/settings/device-capabilities';
  static const String householdPrivacy = '/settings/household-privacy';
  static const String legalSupport = '/settings/legal-support';
  static const String profilePreferences = '/settings/profile-preferences';
  static const String routeNotFound = '/route-recovery/not-found';

  static String calendarEventLocation(CalendarEventOccurrenceId occurrenceId) =>
      '/calendar/event/${occurrenceId.value}';

  static String choreOccurrenceLocation(ChoreOccurrenceId occurrenceId) =>
      '/chores/occurrence/${occurrenceId.value}';

  static String primaryLocation(AppPrimaryDestination destination) =>
      switch (destination) {
        AppPrimaryDestination.today => today,
        AppPrimaryDestination.calendar => calendar,
        AppPrimaryDestination.family => family,
        AppPrimaryDestination.settings => settings,
      };
}
