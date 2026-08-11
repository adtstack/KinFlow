import 'package:kinflow_app/app/router/app_routes.dart';
import 'package:kinflow_app/app/router/auth_route_guard.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';

/// Converts browser locations into privacy-safe authentication continuations.
///
/// Exact resource identifiers are retained only in the in-memory [AuthRouteIntent].
/// The browser-visible continuation is always one of the fixed markers below.
final class AppRouteRecoveryPolicy {
  const AppRouteRecoveryPolicy();

  static const String todayMarker = 'today';
  static const String choresMarker = 'chores';
  static const String calendarMarker = 'calendar';
  static const String familyMarker = 'family';
  static const String settingsMarker = 'settings';
  static const String notificationsMarker = 'notifications';
  static const String notFoundMarker = 'not-found';

  AuthRouteIntent intentFor(Uri location) {
    final String path = location.path;

    if (path == AppRoutes.today || path == AppRoutes.home) {
      return _static(AppRoutes.today, todayMarker);
    }
    if (path == AppRoutes.guidedChoreSetup) {
      return _static(path, choresMarker);
    }
    if (path == AppRoutes.chores || path == AppRoutes.choreTrash) {
      return _static(path, choresMarker);
    }
    if (path == AppRoutes.choreCreate) {
      return _choreCreationIntent(location);
    }
    if (_matchesPrefix(path, '/chores/occurrence/')) {
      return _choreOccurrenceIntent(location);
    }
    if (path == AppRoutes.calendar) {
      return _static(path, calendarMarker);
    }
    if (path == AppRoutes.calendarImport) {
      // Import routes require an in-memory route context and cannot be replayed.
      return AuthRouteIntent(
        location: Uri(path: AppRoutes.calendar),
        continuationMarker: calendarMarker,
        canonicalizeWhenAuthenticated: false,
      );
    }
    if (_matchesPrefix(path, '/calendar/event/')) {
      return _calendarOccurrenceIntent(location);
    }
    if (path == AppRoutes.family ||
        path == AppRoutes.inviteCreate ||
        path == AppRoutes.householdMembers) {
      return _static(path, familyMarker);
    }
    if (path == AppRoutes.notifications) {
      return _static(path, notificationsMarker);
    }
    if (_settingsPaths.contains(path)) {
      return _static(path, settingsMarker);
    }
    if (path == AppRoutes.routeNotFound) {
      return _static(path, notFoundMarker);
    }
    return _static(AppRoutes.routeNotFound, notFoundMarker);
  }

  AuthRouteIntent? intentForContinuationMarker(String marker) {
    return switch (marker) {
      todayMarker => _static(AppRoutes.today, todayMarker),
      choresMarker => _static(AppRoutes.chores, choresMarker),
      calendarMarker => _static(AppRoutes.calendar, calendarMarker),
      familyMarker => _static(AppRoutes.family, familyMarker),
      settingsMarker => _static(AppRoutes.settings, settingsMarker),
      notificationsMarker => _static(
        AppRoutes.notifications,
        notificationsMarker,
      ),
      notFoundMarker => _static(AppRoutes.routeNotFound, notFoundMarker),
      _ => null,
    };
  }

  AuthRouteIntent _choreCreationIntent(Uri location) {
    final List<String>? dueValues = location.queryParametersAll['due'];
    if (dueValues == null || dueValues.length != 1) {
      return _static(AppRoutes.routeNotFound, notFoundMarker);
    }
    final ChoreLocalDate? dueDate = ChoreLocalDate.tryParse(dueValues.single);
    if (dueDate == null) {
      return _static(AppRoutes.routeNotFound, notFoundMarker);
    }
    return AuthRouteIntent(
      location: Uri(
        path: AppRoutes.choreCreate,
        queryParameters: <String, String>{'due': dueDate.value},
      ),
      continuationMarker: choresMarker,
    );
  }

  AuthRouteIntent _choreOccurrenceIntent(Uri location) {
    final List<String> segments = location.pathSegments;
    if (segments.length != 3) {
      return _static(AppRoutes.routeNotFound, notFoundMarker);
    }
    final ChoreOccurrenceId? occurrenceId = ChoreOccurrenceId.tryParse(
      segments.last,
    );
    return occurrenceId == null
        ? _static(AppRoutes.routeNotFound, notFoundMarker)
        : _static(
            AppRoutes.choreOccurrenceLocation(occurrenceId),
            notificationsMarker,
          );
  }

  AuthRouteIntent _calendarOccurrenceIntent(Uri location) {
    final List<String> segments = location.pathSegments;
    if (segments.length != 3) {
      return _static(AppRoutes.routeNotFound, notFoundMarker);
    }
    final CalendarEventOccurrenceId? occurrenceId =
        CalendarEventOccurrenceId.tryParse(segments.last);
    return occurrenceId == null
        ? _static(AppRoutes.routeNotFound, notFoundMarker)
        : _static(
            AppRoutes.calendarEventLocation(occurrenceId),
            calendarMarker,
          );
  }

  AuthRouteIntent _static(String path, String marker) {
    return AuthRouteIntent(
      location: Uri(path: path),
      continuationMarker: marker,
    );
  }

  bool _matchesPrefix(String path, String prefix) {
    return path.startsWith(prefix);
  }

  static const Set<String> _settingsPaths = <String>{
    AppRoutes.settings,
    AppRoutes.householdSwitch,
    AppRoutes.subscription,
    AppRoutes.accountDeletion,
    AppRoutes.analyticsPrivacy,
    AppRoutes.dataExport,
    AppRoutes.diagnostics,
    AppRoutes.deviceCapabilities,
    AppRoutes.householdPrivacy,
    AppRoutes.legalSupport,
    AppRoutes.profilePreferences,
  };
}
