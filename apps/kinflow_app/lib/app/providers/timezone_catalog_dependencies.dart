import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/settings/data/repositories/bundled_timezone_catalog_repository.dart';
import 'package:kinflow_app/features/settings/domain/repositories/timezone_catalog_repository.dart';

typedef TimezonePreviewClock = DateTime Function();

final timezoneCatalogRepositoryProvider = Provider<TimezoneCatalogRepository>(
  (ref) => BundledTimezoneCatalogRepository(),
);

final timezonePreviewClockProvider = Provider<TimezonePreviewClock>(
  (ref) => DateTime.now,
);
