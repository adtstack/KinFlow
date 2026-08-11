import 'package:kinflow_app/features/platform_capabilities/domain/entities/platform_capability_registry.dart';

const String platformCapabilitySelfCheckContractVersion = '2026-08-09-wp01-09';

final class PlatformCapabilityRecoveryStep {
  const PlatformCapabilityRecoveryStep({
    required this.position,
    required this.status,
  });

  final int position;
  final PlatformCapabilityStatus status;
}

final class PlatformCapabilityRecoveryPlan {
  PlatformCapabilityRecoveryPlan._({
    required this.readyCount,
    required this.actionRequiredCount,
    required this.temporaryIssueCount,
    required this.fallbackOnlyCount,
    required this.limitedCount,
    required List<PlatformCapabilityRecoveryStep> steps,
  }) : steps = List<PlatformCapabilityRecoveryStep>.unmodifiable(steps);

  final int readyCount;
  final int actionRequiredCount;
  final int temporaryIssueCount;
  final int fallbackOnlyCount;
  final int limitedCount;
  final List<PlatformCapabilityRecoveryStep> steps;

  int get attentionCount => actionRequiredCount + temporaryIssueCount;

  int get alternativeCount => fallbackOnlyCount + limitedCount;

  bool get hasAttentionItems => attentionCount > 0;

  static PlatformCapabilityRecoveryPlan fromSnapshot(
    PlatformCapabilitySnapshot snapshot,
  ) {
    final List<PlatformCapabilityStatus> nonReady =
        snapshot.entries
            .where(
              (PlatformCapabilityStatus status) =>
                  status.state != PlatformCapabilitySupportState.available,
            )
            .toList(growable: false)
          ..sort(_compareStatus);
    return PlatformCapabilityRecoveryPlan._(
      readyCount: _count(snapshot, PlatformCapabilitySupportState.available),
      actionRequiredCount: _count(
        snapshot,
        PlatformCapabilitySupportState.actionRequired,
      ),
      temporaryIssueCount: _count(
        snapshot,
        PlatformCapabilitySupportState.temporaryIssue,
      ),
      fallbackOnlyCount: _count(
        snapshot,
        PlatformCapabilitySupportState.fallbackOnly,
      ),
      limitedCount: _count(snapshot, PlatformCapabilitySupportState.limited),
      steps: <PlatformCapabilityRecoveryStep>[
        for (int index = 0; index < nonReady.length; index++)
          PlatformCapabilityRecoveryStep(
            position: index + 1,
            status: nonReady[index],
          ),
      ],
    );
  }

  static int _count(
    PlatformCapabilitySnapshot snapshot,
    PlatformCapabilitySupportState state,
  ) {
    return snapshot.entries
        .where((PlatformCapabilityStatus status) => status.state == state)
        .length;
  }

  static int _compareStatus(
    PlatformCapabilityStatus left,
    PlatformCapabilityStatus right,
  ) {
    final int priority = _priority(
      left.state,
    ).compareTo(_priority(right.state));
    return priority != 0 ? priority : left.id.index.compareTo(right.id.index);
  }

  static int _priority(PlatformCapabilitySupportState state) {
    return switch (state) {
      PlatformCapabilitySupportState.temporaryIssue => 0,
      PlatformCapabilitySupportState.actionRequired => 1,
      PlatformCapabilitySupportState.fallbackOnly => 2,
      PlatformCapabilitySupportState.limited => 3,
      PlatformCapabilitySupportState.available => 4,
    };
  }
}
