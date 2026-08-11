import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';

final RegExp _householdInviteHostPattern = RegExp(
  r'^(?=.{1,253}$)(localhost|(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63})$',
);

final class HouseholdInviteLink {
  const HouseholdInviteLink._(this.uri);

  final Uri uri;

  String get value => uri.toString();

  static HouseholdInviteLink? tryCreate({
    required String host,
    required InviteToken token,
  }) {
    if (host != host.trim() || !_householdInviteHostPattern.hasMatch(host)) {
      return null;
    }
    final Uri uri = Uri(
      scheme: 'https',
      host: host.toLowerCase(),
      pathSegments: <String>['invite', token.value],
    );
    if (uri.scheme != 'https' ||
        uri.host != host.toLowerCase() ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments.first != 'invite' ||
        uri.pathSegments.last != token.value) {
      return null;
    }
    return HouseholdInviteLink._(uri);
  }

  @override
  bool operator ==(Object other) {
    return other is HouseholdInviteLink && other.uri == uri;
  }

  @override
  int get hashCode => uri.hashCode;

  @override
  String toString() => 'HouseholdInviteLink(redacted)';
}
