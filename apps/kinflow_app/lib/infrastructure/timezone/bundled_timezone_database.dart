import 'package:timezone/data/latest.dart' as timezone_data;

abstract final class BundledTimezoneDatabase {
  static const String version = '2025c';
  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;
    timezone_data.initializeTimeZones();
    _initialized = true;
  }
}
