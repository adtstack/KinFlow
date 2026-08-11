import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_confirmation_delay.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_port.dart';
import 'package:kinflow_app/features/billing/domain/failures/billing_failure.dart';

void main() {
  group('BillingConfirmationPolicy', () {
    test('copies delays and exposes a bounded immutable schedule', () {
      final List<Duration> input = <Duration>[const Duration(seconds: 1)];
      final BillingConfirmationPolicy policy =
          BillingConfirmationPolicy.tryCreate(input)!;

      input.add(const Duration(seconds: 2));

      expect(policy.delays, const <Duration>[Duration(seconds: 1)]);
      expect(policy.attempts, 2);
      expect(
        () => policy.delays.add(const Duration(seconds: 3)),
        throwsUnsupportedError,
      );
    });

    test('rejects excessive waits, individual delays, and total delay', () {
      expect(
        BillingConfirmationPolicy.tryCreate(
          List<Duration>.filled(8, Duration.zero),
        ),
        isNull,
      );
      expect(
        BillingConfirmationPolicy.tryCreate(const <Duration>[
          Duration(seconds: 31),
        ]),
        isNull,
      );
      expect(
        BillingConfirmationPolicy.tryCreate(const <Duration>[
          Duration(microseconds: -1),
        ]),
        isNull,
      );
      expect(
        BillingConfirmationPolicy.tryCreate(
          List<Duration>.filled(5, const Duration(seconds: 30)),
        ),
        isNull,
      );
    });
  });

  test('client snapshots require an explicit UTC observation time', () {
    expect(
      BillingClientSnapshot.tryCreate(
        boundUserId: null,
        change: BillingClientChange.storeStateChanged,
        observedAt: DateTime.utc(2026, 8, 8),
      ),
      isNotNull,
    );
    expect(
      BillingClientSnapshot.tryCreate(
        boundUserId: null,
        change: BillingClientChange.storeStateChanged,
        observedAt: DateTime(2026, 8, 8),
      ),
      isNull,
    );
  });

  test('failure kinds expose stable retry semantics', () {
    const Set<BillingFailureKind> retryable = <BillingFailureKind>{
      BillingFailureKind.catalogUnavailable,
      BillingFailureKind.storeUnavailable,
      BillingFailureKind.networkUnavailable,
      BillingFailureKind.serverUnavailable,
      BillingFailureKind.identityClearFailed,
      BillingFailureKind.unknown,
    };

    for (final BillingFailureKind kind in BillingFailureKind.values) {
      expect(
        BillingFailure(kind).canRetry,
        retryable.contains(kind),
        reason: '$kind retry contract changed',
      );
    }
  });
}
