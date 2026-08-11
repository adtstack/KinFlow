import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/features/settings/application/ports/profile_locale_preference_sink.dart';
import 'package:kinflow_app/features/settings/presentation/providers/profile_preferences_providers.dart';

void main() {
  test('profile locale sink applies supported locale and restores system', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final ProfileLocalePreferenceSink sink = container.read(
      profileLocalePreferenceSinkProvider,
    );

    expect(container.read(appLocaleProvider), isNull);

    sink.apply('ko');
    expect(container.read(appLocaleProvider), const Locale('ko'));

    sink.apply('en');
    expect(container.read(appLocaleProvider), const Locale('en'));

    sink.apply(null);
    expect(container.read(appLocaleProvider), isNull);
  });
}
