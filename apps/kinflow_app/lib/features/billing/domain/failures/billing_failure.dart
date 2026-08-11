enum BillingFailureKind {
  unsupported,
  unauthenticated,
  identityConflict,
  identityClearFailed,
  invalidInput,
  catalogUnavailable,
  storeUnavailable,
  networkUnavailable,
  serverAuthorization,
  serverUnavailable,
  invalidServerState,
  providerRejected,
  unknown,
}

final class BillingFailure {
  const BillingFailure(this.kind);

  final BillingFailureKind kind;

  bool get canRetry => switch (kind) {
    BillingFailureKind.catalogUnavailable ||
    BillingFailureKind.storeUnavailable ||
    BillingFailureKind.networkUnavailable ||
    BillingFailureKind.serverUnavailable ||
    BillingFailureKind.identityClearFailed ||
    BillingFailureKind.unknown => true,
    BillingFailureKind.unsupported ||
    BillingFailureKind.unauthenticated ||
    BillingFailureKind.identityConflict ||
    BillingFailureKind.invalidInput ||
    BillingFailureKind.serverAuthorization ||
    BillingFailureKind.invalidServerState ||
    BillingFailureKind.providerRejected => false,
  };
}
