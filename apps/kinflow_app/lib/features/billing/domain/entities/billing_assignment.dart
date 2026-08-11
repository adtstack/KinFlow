import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

final class BillingAssignmentCommandId {
  const BillingAssignmentCommandId._(this.value);

  final String value;

  static BillingAssignmentCommandId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _uuidPattern.hasMatch(normalized)
        ? BillingAssignmentCommandId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) {
    return other is BillingAssignmentCommandId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

enum BillingAssignmentPrepareOutcome {
  ready('ready'),
  alreadyReady('already_ready'),
  customerConflict('customer_conflict'),
  householdConflict('household_conflict');

  const BillingAssignmentPrepareOutcome(this.wireValue);

  final String wireValue;

  static BillingAssignmentPrepareOutcome? tryParse(String value) {
    for (final BillingAssignmentPrepareOutcome outcome in values) {
      if (outcome.wireValue == value) return outcome;
    }
    return null;
  }

  bool get isReady =>
      this == BillingAssignmentPrepareOutcome.ready ||
      this == BillingAssignmentPrepareOutcome.alreadyReady;
}

enum BillingAssignmentBindingState {
  provisional('provisional'),
  confirmed('confirmed');

  const BillingAssignmentBindingState(this.wireValue);

  final String wireValue;

  static BillingAssignmentBindingState? tryParse(String value) {
    for (final BillingAssignmentBindingState state in values) {
      if (state.wireValue == value) return state;
    }
    return null;
  }
}

final class BillingAssignmentPreparation {
  const BillingAssignmentPreparation._({
    required this.intentId,
    required this.outcome,
    required this.bindingState,
    required this.assignmentVersion,
    required this.intentExpiresAt,
    required this.requeuedJobCount,
    required this.duplicate,
  });

  final String intentId;
  final BillingAssignmentPrepareOutcome outcome;
  final BillingAssignmentBindingState? bindingState;
  final int? assignmentVersion;
  final DateTime? intentExpiresAt;
  final int requeuedJobCount;
  final bool duplicate;

  static BillingAssignmentPreparation? tryCreate({
    required String intentId,
    required BillingAssignmentPrepareOutcome outcome,
    required BillingAssignmentBindingState? bindingState,
    required int? assignmentVersion,
    required DateTime? intentExpiresAt,
    required int requeuedJobCount,
    required bool duplicate,
  }) {
    final String normalizedIntentId = intentId.trim().toLowerCase();
    if (!_uuidPattern.hasMatch(normalizedIntentId) ||
        requeuedJobCount < 0 ||
        requeuedJobCount > 1000) {
      return null;
    }
    if (outcome.isReady) {
      if (bindingState == null ||
          assignmentVersion == null ||
          assignmentVersion < 1 ||
          (bindingState == BillingAssignmentBindingState.provisional) !=
              (intentExpiresAt != null) ||
          intentExpiresAt != null && !intentExpiresAt.isUtc) {
        return null;
      }
    } else if (bindingState != null ||
        assignmentVersion != null ||
        intentExpiresAt != null) {
      return null;
    }
    return BillingAssignmentPreparation._(
      intentId: normalizedIntentId,
      outcome: outcome,
      bindingState: bindingState,
      assignmentVersion: assignmentVersion,
      intentExpiresAt: intentExpiresAt,
      requeuedJobCount: requeuedJobCount,
      duplicate: duplicate,
    );
  }
}

enum BillingAssignmentState {
  none('none'),
  provisional('provisional'),
  confirmed('confirmed');

  const BillingAssignmentState(this.wireValue);

  final String wireValue;

  static BillingAssignmentState? tryParse(String value) {
    for (final BillingAssignmentState state in values) {
      if (state.wireValue == value) return state;
    }
    return null;
  }
}

enum BillingAssignmentOwnershipState {
  unassigned('unassigned'),
  currentUser('current_user'),
  anotherUser('another_user');

  const BillingAssignmentOwnershipState(this.wireValue);

  final String wireValue;

  static BillingAssignmentOwnershipState? tryParse(String value) {
    for (final BillingAssignmentOwnershipState state in values) {
      if (state.wireValue == value) return state;
    }
    return null;
  }
}

enum BillingAssignmentOwnerMembershipState {
  none('none'),
  active('active'),
  removed('removed');

  const BillingAssignmentOwnerMembershipState(this.wireValue);

  final String wireValue;

  static BillingAssignmentOwnerMembershipState? tryParse(String value) {
    for (final BillingAssignmentOwnerMembershipState state in values) {
      if (state.wireValue == value) return state;
    }
    return null;
  }
}

final class BillingHouseholdAssignmentStatus {
  const BillingHouseholdAssignmentStatus._({
    required this.householdId,
    required this.assignmentState,
    required this.ownershipState,
    required this.ownerMembershipState,
    required this.canPrepare,
    required this.requiresSupport,
    required this.assignmentVersion,
    required this.intentExpiresAt,
  });

  final HouseholdId householdId;
  final BillingAssignmentState assignmentState;
  final BillingAssignmentOwnershipState ownershipState;
  final BillingAssignmentOwnerMembershipState ownerMembershipState;
  final bool canPrepare;
  final bool requiresSupport;
  final int? assignmentVersion;
  final DateTime? intentExpiresAt;

  static BillingHouseholdAssignmentStatus? tryCreate({
    required HouseholdId householdId,
    required BillingAssignmentState assignmentState,
    required BillingAssignmentOwnershipState ownershipState,
    required BillingAssignmentOwnerMembershipState ownerMembershipState,
    required bool canPrepare,
    required bool requiresSupport,
    required int? assignmentVersion,
    required DateTime? intentExpiresAt,
  }) {
    if (assignmentState == BillingAssignmentState.none) {
      if (ownershipState != BillingAssignmentOwnershipState.unassigned ||
          ownerMembershipState != BillingAssignmentOwnerMembershipState.none ||
          assignmentVersion != null ||
          intentExpiresAt != null ||
          requiresSupport) {
        return null;
      }
    } else {
      if (ownershipState == BillingAssignmentOwnershipState.unassigned ||
          ownerMembershipState == BillingAssignmentOwnerMembershipState.none ||
          assignmentVersion == null ||
          assignmentVersion < 1 ||
          (assignmentState == BillingAssignmentState.provisional) !=
              (intentExpiresAt != null) ||
          intentExpiresAt != null && !intentExpiresAt.isUtc ||
          requiresSupport !=
              (ownerMembershipState ==
                  BillingAssignmentOwnerMembershipState.removed)) {
        return null;
      }
    }
    if (canPrepare &&
        ownershipState == BillingAssignmentOwnershipState.anotherUser) {
      return null;
    }
    return BillingHouseholdAssignmentStatus._(
      householdId: householdId,
      assignmentState: assignmentState,
      ownershipState: ownershipState,
      ownerMembershipState: ownerMembershipState,
      canPrepare: canPrepare,
      requiresSupport: requiresSupport,
      assignmentVersion: assignmentVersion,
      intentExpiresAt: intentExpiresAt,
    );
  }
}

enum BillingAssignmentReleaseOutcome {
  released('released'),
  alreadyReleased('already_released'),
  supportRequired('support_required');

  const BillingAssignmentReleaseOutcome(this.wireValue);

  final String wireValue;

  static BillingAssignmentReleaseOutcome? tryParse(String value) {
    for (final BillingAssignmentReleaseOutcome outcome in values) {
      if (outcome.wireValue == value) return outcome;
    }
    return null;
  }
}

final class BillingAssignmentRelease {
  const BillingAssignmentRelease({
    required this.outcome,
    required this.assignmentVersion,
    required this.duplicate,
  });

  final BillingAssignmentReleaseOutcome outcome;
  final int? assignmentVersion;
  final bool duplicate;
}

enum BillingAssignmentRemediationIssue {
  customerConflict('customer_conflict'),
  householdConflict('household_conflict'),
  ownerMembershipChanged('owner_membership_changed'),
  restoreConflict('restore_conflict');

  const BillingAssignmentRemediationIssue(this.wireValue);

  final String wireValue;

  static BillingAssignmentRemediationIssue? tryParse(String value) {
    for (final BillingAssignmentRemediationIssue issue in values) {
      if (issue.wireValue == value) return issue;
    }
    return null;
  }
}

enum BillingAssignmentRemediationStatus {
  open('open'),
  resolved('resolved'),
  rejected('rejected');

  const BillingAssignmentRemediationStatus(this.wireValue);

  final String wireValue;

  static BillingAssignmentRemediationStatus? tryParse(String value) {
    for (final BillingAssignmentRemediationStatus status in values) {
      if (status.wireValue == value) return status;
    }
    return null;
  }
}

final class BillingAssignmentRemediationRequest {
  const BillingAssignmentRemediationRequest._({
    required this.requestId,
    required this.status,
    required this.issue,
    required this.duplicate,
  });

  final String requestId;
  final BillingAssignmentRemediationStatus status;
  final BillingAssignmentRemediationIssue issue;
  final bool duplicate;

  static BillingAssignmentRemediationRequest? tryCreate({
    required String requestId,
    required BillingAssignmentRemediationStatus status,
    required BillingAssignmentRemediationIssue issue,
    required bool duplicate,
  }) {
    final String normalized = requestId.trim().toLowerCase();
    return _uuidPattern.hasMatch(normalized)
        ? BillingAssignmentRemediationRequest._(
            requestId: normalized,
            status: status,
            issue: issue,
            duplicate: duplicate,
          )
        : null;
  }
}
