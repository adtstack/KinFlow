import 'dart:collection';

abstract interface class BillingConfirmationDelay {
  Future<void> wait(Duration duration);
}

final class SystemBillingConfirmationDelay implements BillingConfirmationDelay {
  const SystemBillingConfirmationDelay();

  @override
  Future<void> wait(Duration duration) => Future<void>.delayed(duration);
}

final class BillingConfirmationPolicy {
  BillingConfirmationPolicy._(List<Duration> delays)
    : delays = UnmodifiableListView<Duration>(delays);

  final List<Duration> delays;

  int get attempts => delays.length + 1;

  static BillingConfirmationPolicy? tryCreate(List<Duration> delays) {
    if (delays.length > 7 ||
        delays.any(
          (Duration delay) =>
              delay.isNegative || delay > const Duration(seconds: 30),
        ) ||
        delays.fold<Duration>(Duration.zero, (sum, delay) => sum + delay) >
            const Duration(minutes: 2)) {
      return null;
    }
    return BillingConfirmationPolicy._(List<Duration>.of(delays));
  }
}
