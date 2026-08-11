import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_invite_link.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';

void main() {
  group('HouseholdInviteLink', () {
    test('builds one exact HTTPS invite URL and redacts diagnostics', () {
      final InviteToken token = InviteToken.tryParse(
        'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG',
      )!;

      final HouseholdInviteLink? link = HouseholdInviteLink.tryCreate(
        host: 'AUTH.Example.Invalid',
        token: token,
      );

      expect(
        link?.value,
        'https://auth.example.invalid/invite/'
        'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG',
      );
      expect(link.toString(), 'HouseholdInviteLink(redacted)');
      expect(link.toString(), isNot(contains(token.value)));
    });

    test('rejects host material that could alter URL authority or path', () {
      final InviteToken token = InviteToken.tryParse(
        'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG',
      )!;

      for (final String host in <String>[
        ' auth.example.invalid',
        'auth.example.invalid/path',
        'auth.example.invalid:443',
        'user@auth.example.invalid',
        '*.example.invalid',
        'single-label',
      ]) {
        expect(
          HouseholdInviteLink.tryCreate(host: host, token: token),
          isNull,
          reason: host,
        );
      }
    });
  });

  group('InviteShortCode', () {
    test('normalizes human input and provides one display format', () {
      final InviteShortCode? code = InviteShortCode.tryParse(' 2345 abcd ');

      expect(code?.value, '2345ABCD');
      expect(code?.formatted, '2345-ABCD');
      expect(code.toString(), isNot(contains('2345ABCD')));
    });

    test('rejects ambiguous and incorrectly sized symbols', () {
      expect(InviteShortCode.tryParse('1234-ABCD'), isNull);
      expect(InviteShortCode.tryParse('2345-ABCI'), isNull);
      expect(InviteShortCode.tryParse('2345-ABCD-EFGH'), isNull);
    });
  });
}
