abstract interface class SensitiveLocalStatePurgeParticipant {
  Future<void> purgeSensitiveLocalState();
}

abstract interface class SensitiveLocalStatePurger {
  Future<SensitiveLocalStatePurgeResult> purge();
}

sealed class SensitiveLocalStatePurgeResult {
  const SensitiveLocalStatePurgeResult();
}

final class SensitiveLocalStatePurged extends SensitiveLocalStatePurgeResult {
  const SensitiveLocalStatePurged();
}

final class SensitiveLocalStatePurgeFailed
    extends SensitiveLocalStatePurgeResult {
  const SensitiveLocalStatePurgeFailed({required this.failedParticipantCount});

  final int failedParticipantCount;
}

final class CompositeSensitiveLocalStatePurger
    implements SensitiveLocalStatePurger {
  CompositeSensitiveLocalStatePurger(
    Iterable<SensitiveLocalStatePurgeParticipant> participants,
  ) : _participants = List<SensitiveLocalStatePurgeParticipant>.unmodifiable(
        participants,
      );

  final List<SensitiveLocalStatePurgeParticipant> _participants;

  @override
  Future<SensitiveLocalStatePurgeResult> purge() async {
    var failedParticipantCount = 0;
    for (final SensitiveLocalStatePurgeParticipant participant
        in _participants) {
      try {
        await participant.purgeSensitiveLocalState();
      } on Object {
        failedParticipantCount += 1;
      }
    }

    if (failedParticipantCount > 0) {
      return SensitiveLocalStatePurgeFailed(
        failedParticipantCount: failedParticipantCount,
      );
    }
    return const SensitiveLocalStatePurged();
  }
}
