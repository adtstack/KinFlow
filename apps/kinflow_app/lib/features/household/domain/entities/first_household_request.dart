import 'dart:convert';

import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final RegExp _controlCharacterPattern = RegExp(r'[\x00-\x1f\x7f]');
final RegExp _timezonePattern = RegExp(
  r'^[A-Za-z0-9_+.-]+(?:/[A-Za-z0-9_+.-]+)+$',
);

final class FirstHouseholdDraft {
  const FirstHouseholdDraft._({
    required this.householdName,
    required this.ownerDisplayName,
    required this.locale,
    required this.timezone,
  });

  final String householdName;
  final String ownerDisplayName;
  final String locale;
  final String timezone;

  String get fingerprint =>
      jsonEncode(<String>[householdName, ownerDisplayName, locale, timezone]);

  static FirstHouseholdDraft? tryCreate({
    required String householdName,
    required String ownerDisplayName,
    required String locale,
    required String timezone,
  }) {
    final String normalizedHouseholdName = householdName.trim();
    final String normalizedOwnerDisplayName = ownerDisplayName.trim();
    final String normalizedLocale = locale.trim().toLowerCase();
    final String normalizedTimezone = timezone.trim();

    if (!_isValidName(normalizedHouseholdName) ||
        !_isValidName(normalizedOwnerDisplayName) ||
        !const <String>{'en', 'ko'}.contains(normalizedLocale) ||
        !_isValidTimezone(normalizedTimezone)) {
      return null;
    }

    return FirstHouseholdDraft._(
      householdName: normalizedHouseholdName,
      ownerDisplayName: normalizedOwnerDisplayName,
      locale: normalizedLocale,
      timezone: normalizedTimezone,
    );
  }

  CreateFirstHouseholdRequest withId(HouseholdCreationId idempotencyKey) {
    return CreateFirstHouseholdRequest._(
      idempotencyKey: idempotencyKey,
      householdName: householdName,
      ownerDisplayName: ownerDisplayName,
      locale: locale,
      timezone: timezone,
    );
  }

  static bool _isValidName(String value) {
    return value.isNotEmpty &&
        value.length <= 80 &&
        !_controlCharacterPattern.hasMatch(value);
  }

  static bool _isValidTimezone(String value) {
    if (value == 'UTC') {
      return true;
    }
    return value.length <= 100 &&
        !value.startsWith('posix/') &&
        !value.startsWith('right/') &&
        _timezonePattern.hasMatch(value);
  }
}

final class CreateFirstHouseholdRequest {
  const CreateFirstHouseholdRequest._({
    required this.idempotencyKey,
    required this.householdName,
    required this.ownerDisplayName,
    required this.locale,
    required this.timezone,
  });

  final HouseholdCreationId idempotencyKey;
  final String householdName;
  final String ownerDisplayName;
  final String locale;
  final String timezone;
}
