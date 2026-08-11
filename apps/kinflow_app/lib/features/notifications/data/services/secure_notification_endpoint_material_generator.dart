import 'dart:convert';
import 'dart:math';

import 'package:kinflow_app/features/notifications/application/ports/notification_endpoint_material_generator.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_endpoint_models.dart';

final class SecureNotificationEndpointMaterialGenerator
    implements NotificationEndpointMaterialGenerator {
  SecureNotificationEndpointMaterialGenerator({Random? random})
    : _random = random ?? Random.secure();

  final Random _random;

  @override
  NotificationInstallationId generateInstallationId() {
    final NotificationInstallationId? id = NotificationInstallationId.tryParse(
      _generateUuidV4(),
    );
    if (id == null) {
      throw StateError('Secure notification installation UUID failed.');
    }
    return id;
  }

  @override
  NotificationRegistrationId generateRegistrationId() {
    final NotificationRegistrationId? id = NotificationRegistrationId.tryParse(
      _generateUuidV4(),
    );
    if (id == null) {
      throw StateError('Secure notification registration UUID failed.');
    }
    return id;
  }

  @override
  NotificationRevocationSecret generateRevocationSecret() {
    final List<int> bytes = List<int>.generate(
      32,
      (_) => _random.nextInt(256),
      growable: false,
    );
    final String encoded = base64Url.encode(bytes).replaceAll('=', '');
    final NotificationRevocationSecret? secret =
        NotificationRevocationSecret.tryParse(encoded);
    if (secret == null) {
      throw StateError('Secure notification revocation secret failed.');
    }
    return secret;
  }

  String _generateUuidV4() {
    final List<int> bytes = List<int>.generate(
      16,
      (_) => _random.nextInt(256),
      growable: false,
    );
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final String hex = bytes
        .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
