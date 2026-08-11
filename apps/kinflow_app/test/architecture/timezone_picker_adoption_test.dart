import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every Store MVP timezone editor uses the shared selection field', () {
    const Map<String, int> expectedFieldCounts = <String, int>{
      'lib/features/household/presentation/screens/household_onboarding_screen.dart':
          1,
      'lib/features/notifications/presentation/screens/notification_center_screen.dart':
          1,
      'lib/features/settings/presentation/screens/profile_preferences_screen.dart':
          2,
    };

    for (final MapEntry<String, int> expectation
        in expectedFieldCounts.entries) {
      final String source = File(expectation.key).readAsStringSync();
      expect(
        'TimezoneSelectionFormField('.allMatches(source),
        hasLength(expectation.value),
        reason: expectation.key,
      );
    }
  });

  test('feature presentation has no editable timezone controller field', () {
    final RegExp rawTimezoneField = RegExp(
      r'(?:TextFormField|TextField)\s*\([\s\S]{0,1000}?controller:\s*_[A-Za-z]*[Tt]imezoneController',
    );
    final List<String> violations = <String>[];
    for (final File file
        in Directory('lib/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (File value) =>
                  value.path.contains('/presentation/') &&
                  value.path.endsWith('.dart'),
            )) {
      if (rawTimezoneField.hasMatch(file.readAsStringSync())) {
        violations.add(file.path.replaceAll('\\', '/'));
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('shared timezone field is read-only and has no keyboard fallback', () {
    final String source = File(
      'lib/app/presentation/widgets/timezone_picker_sheet.dart',
    ).readAsStringSync();

    expect(source, contains('readOnly: true'));
    expect(source, contains('enableInteractiveSelection: false'));
    expect(source, isNot(contains('onFieldSubmitted:')));
    expect(source, contains('showTimezonePickerSheet('));
  });
}
