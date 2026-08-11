import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_sync_signal.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';

sealed class TodayChoresState {
  const TodayChoresState();
}

final class TodayChoresInitial extends TodayChoresState {
  const TodayChoresInitial();
}

final class TodayChoresLoading extends TodayChoresState {
  const TodayChoresLoading();
}

final class TodayChoresReady extends TodayChoresState {
  const TodayChoresReady(
    this.today, {
    this.pendingOccurrenceId,
    this.actionFailure,
    this.undoableSkip,
    this.undoableDeletion,
    this.undoableSeriesCancellation,
    this.restoredDeletionOccurrenceId,
    this.refreshing = false,
    this.refreshFailure,
    this.loadingMore = false,
    this.loadMoreFailure,
    this.cacheMetadata,
    this.completionSync,
    this.syncStatus = ChoreSyncConnectionStatus.disabled,
  });

  final TodayChores today;
  final ChoreOccurrenceId? pendingOccurrenceId;
  final ChoreFailure? actionFailure;
  final UndoableChoreSkip? undoableSkip;
  final UndoableOneTimeChoreDeletion? undoableDeletion;
  final UndoableRepeatingChoreSeriesCancellation? undoableSeriesCancellation;
  final ChoreOccurrenceId? restoredDeletionOccurrenceId;
  final bool refreshing;
  final ChoreFailure? refreshFailure;
  final bool loadingMore;
  final ChoreFailure? loadMoreFailure;
  final ReadCacheMetadata? cacheMetadata;
  final TodayChoreCompletionSync? completionSync;
  final ChoreSyncConnectionStatus syncStatus;

  bool get isReadOnlyCache => cacheMetadata != null;
}

enum TodayChoreCompletionSyncKind {
  queued,
  syncing,
  paused,
  reconciled,
  needsAttention,
  discarded,
  expired,
  queueUnavailable,
  queueOccupied,
}

final class TodayChoreCompletionSync {
  const TodayChoreCompletionSync({required this.kind, this.occurrenceId});

  final TodayChoreCompletionSyncKind kind;
  final ChoreOccurrenceId? occurrenceId;

  bool get hasStoredIntent => switch (kind) {
    TodayChoreCompletionSyncKind.queued ||
    TodayChoreCompletionSyncKind.syncing ||
    TodayChoreCompletionSyncKind.paused ||
    TodayChoreCompletionSyncKind.needsAttention ||
    TodayChoreCompletionSyncKind.queueOccupied => true,
    TodayChoreCompletionSyncKind.reconciled ||
    TodayChoreCompletionSyncKind.discarded ||
    TodayChoreCompletionSyncKind.expired ||
    TodayChoreCompletionSyncKind.queueUnavailable => false,
  };

  bool get canDiscard =>
      hasStoredIntent && kind != TodayChoreCompletionSyncKind.syncing;
}

final class UndoableChoreSkip {
  const UndoableChoreSkip({
    required this.occurrence,
    required this.skippedVersion,
    required this.insertionIndex,
  });

  final ChoreOccurrence occurrence;
  final int skippedVersion;
  final int insertionIndex;
}

final class UndoableOneTimeChoreDeletion {
  const UndoableOneTimeChoreDeletion({
    required this.occurrence,
    required this.deletedSeriesVersion,
    required this.deletedOccurrenceVersion,
  });

  final ChoreOccurrence occurrence;
  final int deletedSeriesVersion;
  final int deletedOccurrenceVersion;
}

final class UndoableRepeatingChoreSeriesCancellation {
  const UndoableRepeatingChoreSeriesCancellation({
    required this.householdId,
    required this.seriesId,
    required this.cancellationIdempotencyKey,
    required this.cancellationVersion,
    required this.effectiveLocalDate,
  });

  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final ChoreCommandId cancellationIdempotencyKey;
  final int cancellationVersion;
  final ChoreLocalDate effectiveLocalDate;
}

final class TodayChoresLoadFailed extends TodayChoresState {
  const TodayChoresLoadFailed(this.failure);

  final ChoreFailure failure;
}
