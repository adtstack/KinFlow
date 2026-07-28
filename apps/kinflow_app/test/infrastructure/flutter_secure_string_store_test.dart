import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/infrastructure/secure_storage/flutter_secure_string_store.dart';

void main() {
  test(
    'secure string driver delegates readiness and CRUD without fallback',
    () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      const FlutterSecureStringStore store = FlutterSecureStringStore(
        FlutterSecureStorage(),
        'readiness-probe',
      );

      await store.initialize();
      expect(await store.containsKey('session'), isFalse);

      await store.write('session', 'opaque-session-fixture');
      expect(await store.containsKey('session'), isTrue);
      expect(await store.read('session'), 'opaque-session-fixture');

      await store.write('pkce', 'opaque-verifier-fixture');
      await store.delete('session');
      expect(await store.read('session'), isNull);
      expect(await store.read('pkce'), 'opaque-verifier-fixture');

      await store.deleteAll();
      expect(await store.read('pkce'), isNull);
    },
  );
}
