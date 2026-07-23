import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/app_environment.dart';

void main() {
  test('dev and prod have distinct approved application identifiers', () {
    expect(AppEnvironment.dev.applicationId, 'me.newlines.kinflow.dev');
    expect(AppEnvironment.prod.applicationId, 'me.newlines.kinflow');
    expect(
      AppEnvironment.dev.applicationId,
      isNot(AppEnvironment.prod.applicationId),
    );
  });

  test('only prod is production', () {
    expect(AppEnvironment.dev.isProduction, isFalse);
    expect(AppEnvironment.prod.isProduction, isTrue);
  });
}
