import 'package:kinflow_app/features/analytics/application/analytics_dispatcher.dart';
import 'package:kinflow_app/features/analytics/domain/entities/analytics_governance.dart';

final class AnalyticsSessionEntryCoordinator {
  AnalyticsSessionEntryCoordinator(this._dispatcher);

  final AnalyticsDispatcher _dispatcher;
  bool _entryActive = false;

  Future<AnalyticsDispatchResult?> synchronize({
    required bool authenticatedEntry,
    AnalyticsActorMode actorMode = AnalyticsActorMode.adult,
  }) {
    if (!authenticatedEntry) {
      _entryActive = false;
      return Future<AnalyticsDispatchResult?>.value();
    }
    if (_entryActive) {
      return Future<AnalyticsDispatchResult?>.value();
    }
    _entryActive = true;
    return _dispatcher.track(
      AnalyticsEventName.applicationSessionStarted,
      actorMode: actorMode,
    );
  }
}
