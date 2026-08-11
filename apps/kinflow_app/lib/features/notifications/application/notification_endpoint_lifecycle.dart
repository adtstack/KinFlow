import 'dart:async';

import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/notifications/application/ports/notification_endpoint_material_generator.dart';
import 'package:kinflow_app/features/notifications/application/ports/notification_installation_store.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_endpoint_models.dart';
import 'package:kinflow_app/features/notifications/domain/failures/notification_endpoint_failure.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_endpoint_repository.dart';

abstract interface class NotificationEndpointLifecycleService
    implements SensitiveLocalStatePurgeParticipant {
  Future<NotificationEndpointResult<NotificationEndpointMetadata>> register(
    NotificationEndpointRegistrationIntent intent,
  );
}

final class NotificationEndpointLifecycle
    implements NotificationEndpointLifecycleService {
  NotificationEndpointLifecycle(
    this._repository,
    this._installationStore,
    this._materialGenerator,
  );

  final NotificationEndpointRepository _repository;
  final NotificationInstallationStore _installationStore;
  final NotificationEndpointMaterialGenerator _materialGenerator;
  Future<void> _operationTail = Future<void>.value();

  @override
  Future<NotificationEndpointResult<NotificationEndpointMetadata>> register(
    NotificationEndpointRegistrationIntent intent,
  ) {
    return _enqueue(() async {
      try {
        return await _register(intent);
      } on Object {
        return const NotificationEndpointFailed<NotificationEndpointMetadata>(
          NotificationEndpointFailure(NotificationEndpointFailureKind.internal),
        );
      }
    });
  }

  @override
  Future<void> purgeSensitiveLocalState() {
    return _enqueue(() async {
      final ActiveNotificationEndpointBinding? active = await _installationStore
          .readActiveBinding();
      final PendingNotificationEndpointBinding? pending =
          await _installationStore.readPendingBinding();
      final Map<String, NotificationEndpointBindingProof> proofs =
          <String, NotificationEndpointBindingProof>{};
      if (active != null) {
        proofs['${active.installationId.value}:${active.registrationId.value}'] =
            active.proof;
      }
      if (pending != null) {
        proofs['${pending.installationId.value}:${pending.registrationId.value}'] =
            pending.proof;
      }
      for (final NotificationEndpointBindingProof proof in proofs.values) {
        final NotificationEndpointResult<void> result = await _repository
            .revoke(proof);
        if (result is NotificationEndpointFailed<void>) {
          throw StateError('Notification endpoint revocation failed.');
        }
      }
      await _installationStore.clearAccountBindings();
    });
  }

  Future<NotificationEndpointResult<NotificationEndpointMetadata>> _register(
    NotificationEndpointRegistrationIntent intent,
  ) async {
    final NotificationInstallationId installationId = await _installationStore
        .getOrCreateInstallationId();
    final PendingNotificationEndpointBinding? existingPending =
        await _installationStore.readPendingBinding();
    final NotificationEndpointResult<NotificationEndpointMetadata?>
    statusResult = await _repository.loadStatus(installationId);
    if (statusResult
        case NotificationEndpointFailed<NotificationEndpointMetadata?>(
          :final failure,
        )) {
      return NotificationEndpointFailed<NotificationEndpointMetadata>(failure);
    }
    final NotificationEndpointMetadata? status =
        (statusResult
                as NotificationEndpointSucceeded<NotificationEndpointMetadata?>)
            .value;
    if (existingPending != null &&
        existingPending.installationId == installationId &&
        status != null &&
        existingPending.matchesMetadata(status)) {
      return _recoverPendingRegistration(
        intent,
        installationId,
        existingPending,
        status,
      );
    }

    final int expectedVersion = status?.version ?? 0;
    final PendingNotificationEndpointBinding pending =
        existingPending != null &&
            existingPending.installationId == installationId &&
            existingPending.matchesIntent(intent, expectedVersion)
        ? existingPending
        : _newPending(intent, installationId, expectedVersion);
    await _installationStore.writePendingBinding(pending);
    final NotificationEndpointResult<NotificationEndpointMetadata> result =
        await _registerPending(intent, pending);
    if (result case NotificationEndpointSucceeded<NotificationEndpointMetadata>(
      :final value,
    )) {
      return _promotedResult(pending, value);
    }
    final NotificationEndpointFailure failure =
        (result as NotificationEndpointFailed<NotificationEndpointMetadata>)
            .failure;
    if (failure.kind != NotificationEndpointFailureKind.idempotencyConflict &&
        failure.kind != NotificationEndpointFailureKind.versionConflict) {
      return result;
    }
    return _reconcileOrRetry(intent, installationId, pending, failure);
  }

  Future<NotificationEndpointResult<NotificationEndpointMetadata>>
  _recoverPendingRegistration(
    NotificationEndpointRegistrationIntent intent,
    NotificationInstallationId installationId,
    PendingNotificationEndpointBinding pending,
    NotificationEndpointMetadata status,
  ) async {
    final NotificationEndpointResult<NotificationEndpointMetadata> replay =
        await _registerPending(intent, pending);
    if (replay case NotificationEndpointFailed<NotificationEndpointMetadata>(
      :final failure,
    )) {
      if (failure.kind != NotificationEndpointFailureKind.idempotencyConflict) {
        return replay;
      }
      await _writeActive(pending, status);
      return _registerReplacement(intent, installationId, status.version);
    }

    final NotificationEndpointMetadata replayedMetadata =
        (replay as NotificationEndpointSucceeded<NotificationEndpointMetadata>)
            .value;
    if (!pending.matchesMetadata(replayedMetadata)) {
      return const NotificationEndpointFailed<NotificationEndpointMetadata>(
        NotificationEndpointFailure(
          NotificationEndpointFailureKind.invalidPayload,
        ),
      );
    }
    if (pending.matchesIntent(intent, pending.expectedVersion)) {
      await _promote(pending, replayedMetadata);
      return NotificationEndpointSucceeded<NotificationEndpointMetadata>(
        replayedMetadata,
      );
    }
    await _writeActive(pending, replayedMetadata);
    return _registerReplacement(
      intent,
      installationId,
      replayedMetadata.version,
    );
  }

  Future<NotificationEndpointResult<NotificationEndpointMetadata>>
  _registerReplacement(
    NotificationEndpointRegistrationIntent intent,
    NotificationInstallationId installationId,
    int expectedVersion,
  ) async {
    final PendingNotificationEndpointBinding replacement = _newPending(
      intent,
      installationId,
      expectedVersion,
    );
    await _installationStore.writePendingBinding(replacement);
    final NotificationEndpointResult<NotificationEndpointMetadata> result =
        await _registerPending(intent, replacement);
    if (result case NotificationEndpointSucceeded<NotificationEndpointMetadata>(
      :final value,
    )) {
      return _promotedResult(replacement, value);
    }
    return result;
  }

  Future<NotificationEndpointResult<NotificationEndpointMetadata>>
  _reconcileOrRetry(
    NotificationEndpointRegistrationIntent intent,
    NotificationInstallationId installationId,
    PendingNotificationEndpointBinding pending,
    NotificationEndpointFailure originalFailure,
  ) async {
    final NotificationEndpointResult<NotificationEndpointMetadata?>
    statusResult = await _repository.loadStatus(installationId);
    if (statusResult
        case NotificationEndpointFailed<NotificationEndpointMetadata?>(
          :final failure,
        )) {
      return NotificationEndpointFailed<NotificationEndpointMetadata>(failure);
    }
    final NotificationEndpointMetadata? status =
        (statusResult
                as NotificationEndpointSucceeded<NotificationEndpointMetadata?>)
            .value;
    if (status != null && pending.matchesMetadata(status)) {
      await _promote(pending, status);
      return NotificationEndpointSucceeded<NotificationEndpointMetadata>(
        status,
      );
    }
    final int expectedVersion = status?.version ?? 0;
    if (originalFailure.kind ==
            NotificationEndpointFailureKind.idempotencyConflict ||
        expectedVersion != pending.expectedVersion) {
      final PendingNotificationEndpointBinding replacement = _newPending(
        intent,
        installationId,
        expectedVersion,
      );
      await _installationStore.writePendingBinding(replacement);
      final NotificationEndpointResult<NotificationEndpointMetadata> retry =
          await _registerPending(intent, replacement);
      if (retry
          case NotificationEndpointSucceeded<NotificationEndpointMetadata>(
            :final value,
          )) {
        return _promotedResult(replacement, value);
      }
      return retry;
    }
    return NotificationEndpointFailed<NotificationEndpointMetadata>(
      originalFailure,
    );
  }

  Future<NotificationEndpointResult<NotificationEndpointMetadata>>
  _registerPending(
    NotificationEndpointRegistrationIntent intent,
    PendingNotificationEndpointBinding pending,
  ) {
    return _repository.register(
      NotificationEndpointRegistrationCommand(
        householdId: pending.householdId,
        installationId: pending.installationId,
        registrationId: pending.registrationId,
        platform: pending.platform,
        providerToken: intent.providerToken,
        revocationSecret: pending.revocationSecret,
        locale: pending.locale,
        timezone: pending.timezone,
        appVersion: pending.appVersion,
        runtimeVersion: pending.runtimeVersion,
        expectedVersion: pending.expectedVersion,
      ),
    );
  }

  PendingNotificationEndpointBinding _newPending(
    NotificationEndpointRegistrationIntent intent,
    NotificationInstallationId installationId,
    int expectedVersion,
  ) {
    return PendingNotificationEndpointBinding(
      householdId: intent.householdId,
      installationId: installationId,
      registrationId: _materialGenerator.generateRegistrationId(),
      revocationSecret: _materialGenerator.generateRevocationSecret(),
      platform: intent.platform,
      locale: intent.locale,
      timezone: intent.timezone,
      appVersion: intent.appVersion,
      runtimeVersion: intent.runtimeVersion,
      expectedVersion: expectedVersion,
    );
  }

  Future<NotificationEndpointResult<NotificationEndpointMetadata>>
  _promotedResult(
    PendingNotificationEndpointBinding pending,
    NotificationEndpointMetadata metadata,
  ) async {
    if (!pending.matchesMetadata(metadata)) {
      return const NotificationEndpointFailed<NotificationEndpointMetadata>(
        NotificationEndpointFailure(
          NotificationEndpointFailureKind.invalidPayload,
        ),
      );
    }
    await _promote(pending, metadata);
    return NotificationEndpointSucceeded<NotificationEndpointMetadata>(
      metadata,
    );
  }

  Future<void> _promote(
    PendingNotificationEndpointBinding pending,
    NotificationEndpointMetadata metadata,
  ) async {
    await _writeActive(pending, metadata);
    await _installationStore.deletePendingBinding();
  }

  Future<void> _writeActive(
    PendingNotificationEndpointBinding pending,
    NotificationEndpointMetadata metadata,
  ) async {
    await _installationStore.writeActiveBinding(
      ActiveNotificationEndpointBinding(
        endpointId: metadata.endpointId,
        householdId: metadata.householdId,
        installationId: metadata.installationId,
        registrationId: metadata.registrationId,
        revocationSecret: pending.revocationSecret,
        version: metadata.version,
      ),
    );
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final Completer<T> completer = Completer<T>();
    _operationTail = _operationTail.then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

final class UnavailableNotificationEndpointLifecycle
    implements NotificationEndpointLifecycleService {
  const UnavailableNotificationEndpointLifecycle();

  @override
  Future<NotificationEndpointResult<NotificationEndpointMetadata>> register(
    NotificationEndpointRegistrationIntent intent,
  ) async => const NotificationEndpointFailed<NotificationEndpointMetadata>(
    NotificationEndpointFailure(
      NotificationEndpointFailureKind.temporarilyUnavailable,
    ),
  );

  @override
  Future<void> purgeSensitiveLocalState() async {}
}
