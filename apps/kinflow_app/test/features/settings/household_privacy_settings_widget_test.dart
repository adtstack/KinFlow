import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/settings/presentation/providers/household_privacy_providers.dart';
import 'package:kinflow_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

void main() {
  testWidgets('settings shows household controls after Owner preflight', (
    WidgetTester tester,
  ) async {
    await _pumpSettings(tester, ownerAuthorized: true);

    expect(
      find.byKey(const Key('settings.profilePreferences')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('settings.subscription')), findsOneWidget);
    expect(find.byKey(const Key('settings.householdSwitch')), findsOneWidget);
    expect(find.byKey(const Key('settings.legalSupport')), findsOneWidget);
    expect(find.text('Subscription and Plus'), findsOneWidget);
    expect(find.text('Legal, privacy, and support'), findsOneWidget);
    expect(find.text('Profile and regional settings'), findsOneWidget);
    expect(find.byKey(const Key('settings.householdPrivacy')), findsOneWidget);
    expect(find.text('Household data and deletion'), findsOneWidget);
  });

  testWidgets('settings hides household controls when preflight fails closed', (
    WidgetTester tester,
  ) async {
    await _pumpSettings(tester, ownerAuthorized: false);

    expect(find.byKey(const Key('settings.householdPrivacy')), findsNothing);
  });
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required bool ownerAuthorized,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        householdPrivacyOwnerVisibilityProvider.overrideWith(
          (ref) async => ownerAuthorized,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
