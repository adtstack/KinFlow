import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';
import 'package:kinflow_app/l10n/app_localizations_en.dart';
import 'package:kinflow_app/l10n/app_localizations_ko.dart';

void main() {
  final Map<String, Object?> english = _readArb('lib/l10n/app_en.arb');
  final Map<String, Object?> korean = _readArb('lib/l10n/app_ko.arb');
  final Map<String, Object?> pseudo = _readArb('lib/l10n/app_en_XA.arb');
  final Set<String> sourceKeys = _messageKeys(english);

  test('source, Korean, and pseudo ARBs have exact message coverage', () {
    expect(_messageKeys(korean), sourceKeys);
    expect(_messageKeys(pseudo), sourceKeys);

    for (final String key in sourceKeys) {
      expect(english['@$key'], isA<Map<String, Object?>>());
      expect((english[key]! as String).trim(), isNotEmpty);
      expect((korean[key]! as String).trim(), isNotEmpty);
      expect((pseudo[key]! as String).trim(), isNotEmpty);
    }
  });

  test('LTR pseudo messages expand every English source by at least 30%', () {
    for (final String key in sourceKeys) {
      final String source = english[key]! as String;
      final String expanded = pseudo[key]! as String;

      expect(
        expanded.runes.length,
        greaterThanOrEqualTo((source.runes.length * 1.3).ceil()),
        reason: '$key must exercise long-copy layout pressure',
      );
    }
  });

  test('generated locale list exposes only approved and pseudo locales', () {
    expect(AppLocalizations.supportedLocales, const <Locale>[
      Locale('en'),
      Locale('en', 'XA'),
      Locale('ko'),
    ]);
  });

  test('generated ICU plural output is localized', () {
    final AppLocalizationsEn englishLocalizations = AppLocalizationsEn();
    final AppLocalizationsEnXa pseudoLocalizations = AppLocalizationsEnXa();
    final AppLocalizationsKo koreanLocalizations = AppLocalizationsKo();

    expect(
      englishLocalizations.foundationLayoutCount(1),
      '1 adaptive layout is ready.',
    );
    expect(
      englishLocalizations.foundationLayoutCount(3),
      '3 adaptive layouts are ready.',
    );
    expect(
      koreanLocalizations.foundationLayoutCount(3),
      '반응형 레이아웃 3개를 사용할 수 있습니다.',
    );
    expect(
      pseudoLocalizations.foundationLayoutCount(3),
      contains('3 expanded adaptive layouts'),
    );
  });
}

Map<String, Object?> _readArb(String path) {
  final Object? decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw StateError('$path must contain a JSON object.');
  }
  return decoded;
}

Set<String> _messageKeys(Map<String, Object?> arb) {
  return arb.keys.where((String key) => !key.startsWith('@')).toSet();
}
