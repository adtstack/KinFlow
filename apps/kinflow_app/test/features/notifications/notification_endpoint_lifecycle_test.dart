import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/notifications/application/notification_endpoint_lifecycle.dart';
import 'package:kinflow_app/features/notifications/application/ports/notification_endpoint_material_generator.dart';
import 'package:kinflow_app/features/notifications/application/ports/notification_installation_store.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_endpoint_models.dart';
import 'package:kinflow_app/features/notifications/domain/failures/notification_endpoint_failure.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_endpoint_repository.dart';

const String _householdId = '22222222-2222-4222-8222-222222222222';
const String _memberId = '33333333-3333-4333-8333-333333333333';
const String _endpointId = '52000000-0000-4000-8000-000000000001';
const String _installationId = '53000000-0000-4000-8000-000000000001';
const String _registrationA = '53010000-0000-4000-8000-000000000001';
const String _registrationB = '53010000-0000-4000-8000-000000000002';
const String _secretA = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const String _secretB = 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';
const String _providerToken = 'fcm:provider-token-value-0123456789';
const String _rotatedProviderToken = 'fcm:rotated-token-value-9876543210';

void main() {
  test(
    'registration persists proof before network and promotes success',
    () async {
      final _MemoryInstallationStore store = _MemoryInstallationStore();
      late _RecordingEndpointRepository repository;
      repository = _RecordingEndpointRepository(
        statusResults:
            <NotificationEndpointResult<NotificationEndpointMetadata?>>[
              const NotificationEndpointSucceeded<
                NotificationEndpointMetadata?
              >(null),
            ],
        registerHandler:
            (NotificationEndpointRegistrationCommand command) async {
              expect(store.pending?.registrationId, command.registrationId);
              expect(store.pending?.revocationSecret, command.revocationSecret);
              expect(command.toString(), isNot(contains(_providerToken)));
              expect(command.toString(), isNot(contains(_secretA)));
              return NotificationEndpointSucceeded<
                NotificationEndpointMetadata
              >(_metadata(registrationId: _registrationA, version: 1));
            },
      );
      final NotificationEndpointLifecycle lifecycle =
          NotificationEndpointLifecycle(
            repository,
            store,
            _SequenceMaterialGenerator(
              registrationIds: <String>[_registrationA],
              secrets: <String>[_secretA],
            ),
          );

      final NotificationEndpointResult<NotificationEndpointMetadata> result =
          await lifecycle.register(_intent());

      expect(
        result,
        isA<NotificationEndpointSucceeded<NotificationEndpointMetadata>>(),
      );
      expect(store.pending, isNull);
      expect(store.active?.registrationId.value, _registrationA);
      expect(store.active?.revocationSecret.value, _secretA);
      expect(repository.registerCommands, hasLength(1));
      expect(repository.registerCommands.single.expectedVersion, 0);
    },
  );

  test(
    'response-loss retry replays exactly without rotating proof or version',
    () async {
      final _MemoryInstallationStore store = _MemoryInstallationStore();
      var registerCall = 0;
      final _RecordingEndpointRepository repository =
          _RecordingEndpointRepository(
            statusResults:
                <NotificationEndpointResult<NotificationEndpointMetadata?>>[
                  const NotificationEndpointSucceeded<
                    NotificationEndpointMetadata?
                  >(null),
                  NotificationEndpointSucceeded<NotificationEndpointMetadata?>(
                    _metadata(registrationId: _registrationA, version: 1),
                  ),
                ],
            registerHandler:
                (NotificationEndpointRegistrationCommand command) async {
                  registerCall += 1;
                  if (registerCall == 1) {
                    return const NotificationEndpointFailed<
                      NotificationEndpointMetadata
                    >(
                      NotificationEndpointFailure(
                        NotificationEndpointFailureKind.temporarilyUnavailable,
                      ),
                    );
                  }
                  return NotificationEndpointSucceeded<
                    NotificationEndpointMetadata
                  >(_metadata(registrationId: _registrationA, version: 1));
                },
          );
      final NotificationEndpointLifecycle lifecycle =
          NotificationEndpointLifecycle(
            repository,
            store,
            _SequenceMaterialGenerator(
              registrationIds: <String>[_registrationA],
              secrets: <String>[_secretA],
            ),
          );

      final NotificationEndpointResult<NotificationEndpointMetadata> first =
          await lifecycle.register(_intent());
      expect(
        first,
        isA<NotificationEndpointFailed<NotificationEndpointMetadata>>(),
      );
      expect(store.pending?.registrationId.value, _registrationA);

      final NotificationEndpointResult<NotificationEndpointMetadata> second =
          await lifecycle.register(_intent());
      expect(
        second,
        isA<NotificationEndpointSucceeded<NotificationEndpointMetadata>>(),
      );
      expect(repository.registerCommands, hasLength(2));
      expect(
        repository.registerCommands.map(
          (NotificationEndpointRegistrationCommand command) =>
              command.registrationId.value,
        ),
        <String>[_registrationA, _registrationA],
      );
      expect(store.active?.registrationId.value, _registrationA);
      expect(store.pending, isNull);
    },
  );

  test(
    'response-loss recovery does not drop a concurrent provider token rotation',
    () async {
      final _MemoryInstallationStore store = _MemoryInstallationStore();
      var registerCall = 0;
      final _RecordingEndpointRepository repository =
          _RecordingEndpointRepository(
            statusResults:
                <NotificationEndpointResult<NotificationEndpointMetadata?>>[
                  const NotificationEndpointSucceeded<
                    NotificationEndpointMetadata?
                  >(null),
                  NotificationEndpointSucceeded<NotificationEndpointMetadata?>(
                    _metadata(registrationId: _registrationA, version: 1),
                  ),
                ],
            registerHandler:
                (NotificationEndpointRegistrationCommand command) async {
                  registerCall += 1;
                  if (registerCall == 1) {
                    return const NotificationEndpointFailed<
                      NotificationEndpointMetadata
                    >(
                      NotificationEndpointFailure(
                        NotificationEndpointFailureKind.temporarilyUnavailable,
                      ),
                    );
                  }
                  if (registerCall == 2) {
                    expect(command.registrationId.value, _registrationA);
                    expect(command.providerToken.value, _rotatedProviderToken);
                    return const NotificationEndpointFailed<
                      NotificationEndpointMetadata
                    >(
                      NotificationEndpointFailure(
                        NotificationEndpointFailureKind.idempotencyConflict,
                      ),
                    );
                  }
                  expect(store.active?.registrationId.value, _registrationA);
                  expect(store.pending?.registrationId.value, _registrationB);
                  return NotificationEndpointSucceeded<
                    NotificationEndpointMetadata
                  >(_metadata(registrationId: _registrationB, version: 2));
                },
          );
      final NotificationEndpointLifecycle lifecycle =
          NotificationEndpointLifecycle(
            repository,
            store,
            _SequenceMaterialGenerator(
              registrationIds: <String>[_registrationA, _registrationB],
              secrets: <String>[_secretA, _secretB],
            ),
          );

      final NotificationEndpointResult<NotificationEndpointMetadata> first =
          await lifecycle.register(_intent());
      expect(
        first,
        isA<NotificationEndpointFailed<NotificationEndpointMetadata>>(),
      );

      final NotificationEndpointResult<NotificationEndpointMetadata> second =
          await lifecycle.register(
            _intent(providerToken: _rotatedProviderToken),
          );

      expect(
        second,
        isA<NotificationEndpointSucceeded<NotificationEndpointMetadata>>(),
      );
      expect(
        repository.registerCommands.map(
          (NotificationEndpointRegistrationCommand command) =>
              command.registrationId.value,
        ),
        <String>[_registrationA, _registrationA, _registrationB],
      );
      expect(store.active?.registrationId.value, _registrationB);
      expect(store.active?.revocationSecret.value, _secretB);
      expect(store.active?.version, 2);
      expect(store.pending, isNull);
    },
  );

  test(
    'response-loss recovery applies newer metadata after exact token replay',
    () async {
      const String updatedAppVersion = '0.2.0+2';
      final _MemoryInstallationStore store = _MemoryInstallationStore();
      var registerCall = 0;
      final _RecordingEndpointRepository repository =
          _RecordingEndpointRepository(
            statusResults:
                <NotificationEndpointResult<NotificationEndpointMetadata?>>[
                  const NotificationEndpointSucceeded<
                    NotificationEndpointMetadata?
                  >(null),
                  NotificationEndpointSucceeded<NotificationEndpointMetadata?>(
                    _metadata(registrationId: _registrationA, version: 1),
                  ),
                ],
            registerHandler:
                (NotificationEndpointRegistrationCommand command) async {
                  registerCall += 1;
                  if (registerCall == 1) {
                    return const NotificationEndpointFailed<
                      NotificationEndpointMetadata
                    >(
                      NotificationEndpointFailure(
                        NotificationEndpointFailureKind.temporarilyUnavailable,
                      ),
                    );
                  }
                  if (registerCall == 2) {
                    expect(command.registrationId.value, _registrationA);
                    expect(command.appVersion, '0.1.0+1');
                    return NotificationEndpointSucceeded<
                      NotificationEndpointMetadata
                    >(_metadata(registrationId: _registrationA, version: 1));
                  }
                  expect(command.registrationId.value, _registrationB);
                  expect(command.expectedVersion, 1);
                  expect(command.appVersion, updatedAppVersion);
                  expect(store.active?.registrationId.value, _registrationA);
                  expect(store.pending?.registrationId.value, _registrationB);
                  return NotificationEndpointSucceeded<
                    NotificationEndpointMetadata
                  >(
                    _metadata(
                      registrationId: _registrationB,
                      version: 2,
                      appVersion: updatedAppVersion,
                    ),
                  );
                },
          );
      final NotificationEndpointLifecycle lifecycle =
          NotificationEndpointLifecycle(
            repository,
            store,
            _SequenceMaterialGenerator(
              registrationIds: <String>[_registrationA, _registrationB],
              secrets: <String>[_secretA, _secretB],
            ),
          );

      expect(
        await lifecycle.register(_intent()),
        isA<NotificationEndpointFailed<NotificationEndpointMetadata>>(),
      );
      final NotificationEndpointResult<NotificationEndpointMetadata> result =
          await lifecycle.register(_intent(appVersion: updatedAppVersion));

      expect(
        result,
        isA<NotificationEndpointSucceeded<NotificationEndpointMetadata>>(),
      );
      expect(
        (result as NotificationEndpointSucceeded<NotificationEndpointMetadata>)
            .value
            .appVersion,
        updatedAppVersion,
      );
      expect(store.active?.registrationId.value, _registrationB);
      expect(store.pending, isNull);
    },
  );

  test(
    'idempotency conflict replaces proof once after status reconciliation',
    () async {
      final _MemoryInstallationStore store = _MemoryInstallationStore();
      var registerCall = 0;
      final _RecordingEndpointRepository
      repository = _RecordingEndpointRepository(
        statusResults:
            const <NotificationEndpointResult<NotificationEndpointMetadata?>>[
              NotificationEndpointSucceeded<NotificationEndpointMetadata?>(
                null,
              ),
              NotificationEndpointSucceeded<NotificationEndpointMetadata?>(
                null,
              ),
            ],
        registerHandler:
            (NotificationEndpointRegistrationCommand command) async {
              registerCall += 1;
              if (registerCall == 1) {
                return const NotificationEndpointFailed<
                  NotificationEndpointMetadata
                >(
                  NotificationEndpointFailure(
                    NotificationEndpointFailureKind.idempotencyConflict,
                  ),
                );
              }
              return NotificationEndpointSucceeded<
                NotificationEndpointMetadata
              >(_metadata(registrationId: _registrationB, version: 1));
            },
      );
      final NotificationEndpointLifecycle lifecycle =
          NotificationEndpointLifecycle(
            repository,
            store,
            _SequenceMaterialGenerator(
              registrationIds: <String>[_registrationA, _registrationB],
              secrets: <String>[_secretA, _secretB],
            ),
          );

      final NotificationEndpointResult<NotificationEndpointMetadata> result =
          await lifecycle.register(_intent());

      expect(
        result,
        isA<NotificationEndpointSucceeded<NotificationEndpointMetadata>>(),
      );
      expect(
        repository.registerCommands.map(
          (command) => command.registrationId.value,
        ),
        <String>[_registrationA, _registrationB],
      );
      expect(store.active?.registrationId.value, _registrationB);
      expect(store.active?.revocationSecret.value, _secretB);
    },
  );

  test(
    'purge revokes active and uncertain pending proofs then clears bindings',
    () async {
      final _MemoryInstallationStore store = _MemoryInstallationStore(
        active: _active(_registrationA, _secretA),
        pending: _pending(_registrationB, _secretB),
      );
      final _RecordingEndpointRepository repository =
          _RecordingEndpointRepository();
      final NotificationEndpointLifecycle lifecycle =
          NotificationEndpointLifecycle(
            repository,
            store,
            _SequenceMaterialGenerator(
              registrationIds: const <String>[],
              secrets: const <String>[],
            ),
          );

      await lifecycle.purgeSensitiveLocalState();

      expect(
        repository.revokedProofs.map((proof) => proof.registrationId.value),
        <String>[_registrationA, _registrationB],
      );
      expect(store.active, isNull);
      expect(store.pending, isNull);
      expect(store.installationId.value, _installationId);
      expect(store.clearCount, 1);
    },
  );

  test(
    'failed remote revoke preserves proof and fails auth purge closed',
    () async {
      final ActiveNotificationEndpointBinding active = _active(
        _registrationA,
        _secretA,
      );
      final _MemoryInstallationStore store = _MemoryInstallationStore(
        active: active,
      );
      final _RecordingEndpointRepository repository =
          _RecordingEndpointRepository(
            revokeResult: const NotificationEndpointFailed<void>(
              NotificationEndpointFailure(
                NotificationEndpointFailureKind.temporarilyUnavailable,
              ),
            ),
          );
      final NotificationEndpointLifecycle lifecycle =
          NotificationEndpointLifecycle(
            repository,
            store,
            _SequenceMaterialGenerator(
              registrationIds: const <String>[],
              secrets: const <String>[],
            ),
          );

      await expectLater(
        lifecycle.purgeSensitiveLocalState(),
        throwsA(isA<StateError>()),
      );
      expect(store.active, same(active));
      expect(store.clearCount, 0);
    },
  );
}

NotificationEndpointRegistrationIntent _intent({
  String providerToken = _providerToken,
  String appVersion = '0.1.0+1',
}) {
  return NotificationEndpointRegistrationIntent.tryCreate(
    householdId: HouseholdId.tryParse(_householdId)!,
    platform: NotificationEndpointPlatform.android,
    providerToken: providerToken,
    locale: 'ko-KR',
    timezone: 'Asia/Seoul',
    appVersion: appVersion,
    runtimeVersion: 'Flutter 3.44.7',
  )!;
}

NotificationEndpointMetadata _metadata({
  required String registrationId,
  required int version,
  String appVersion = '0.1.0+1',
}) {
  return NotificationEndpointMetadata.tryCreate(
    endpointId: _endpointId,
    householdId: _householdId,
    memberId: _memberId,
    installationId: _installationId,
    channel: 'native_push',
    platform: 'android',
    permissionState: 'granted',
    locale: 'ko-KR',
    timezone: 'Asia/Seoul',
    appVersion: appVersion,
    runtimeVersion: 'Flutter 3.44.7',
    registrationId: registrationId,
    lastSeenAt: '2030-01-01T00:00:00.000Z',
    revokedAt: null,
    revocationReason: null,
    version: version,
  )!;
}

PendingNotificationEndpointBinding _pending(
  String registrationId,
  String secret,
) {
  return PendingNotificationEndpointBinding(
    householdId: HouseholdId.tryParse(_householdId)!,
    installationId: NotificationInstallationId.tryParse(_installationId)!,
    registrationId: NotificationRegistrationId.tryParse(registrationId)!,
    revocationSecret: NotificationRevocationSecret.tryParse(secret)!,
    platform: NotificationEndpointPlatform.android,
    locale: 'ko-KR',
    timezone: 'Asia/Seoul',
    appVersion: '0.1.0+1',
    runtimeVersion: 'Flutter 3.44.7',
    expectedVersion: 0,
  );
}

ActiveNotificationEndpointBinding _active(
  String registrationId,
  String secret,
) {
  return ActiveNotificationEndpointBinding(
    endpointId: NotificationEndpointId.tryParse(_endpointId)!,
    householdId: HouseholdId.tryParse(_householdId)!,
    installationId: NotificationInstallationId.tryParse(_installationId)!,
    registrationId: NotificationRegistrationId.tryParse(registrationId)!,
    revocationSecret: NotificationRevocationSecret.tryParse(secret)!,
    version: 1,
  );
}

final class _SequenceMaterialGenerator
    implements NotificationEndpointMaterialGenerator {
  _SequenceMaterialGenerator({
    required List<String> registrationIds,
    required List<String> secrets,
  }) : _registrationIds = List<String>.from(registrationIds),
       _secrets = List<String>.from(secrets);

  final List<String> _registrationIds;
  final List<String> _secrets;

  @override
  NotificationInstallationId generateInstallationId() =>
      NotificationInstallationId.tryParse(_installationId)!;

  @override
  NotificationRegistrationId generateRegistrationId() =>
      NotificationRegistrationId.tryParse(_registrationIds.removeAt(0))!;

  @override
  NotificationRevocationSecret generateRevocationSecret() =>
      NotificationRevocationSecret.tryParse(_secrets.removeAt(0))!;
}

final class _MemoryInstallationStore implements NotificationInstallationStore {
  _MemoryInstallationStore({this.pending, this.active});

  final NotificationInstallationId installationId =
      NotificationInstallationId.tryParse(_installationId)!;
  PendingNotificationEndpointBinding? pending;
  ActiveNotificationEndpointBinding? active;
  var clearCount = 0;

  @override
  Future<NotificationInstallationId> getOrCreateInstallationId() async =>
      installationId;

  @override
  Future<PendingNotificationEndpointBinding?> readPendingBinding() async =>
      pending;

  @override
  Future<void> writePendingBinding(
    PendingNotificationEndpointBinding binding,
  ) async {
    pending = binding;
  }

  @override
  Future<void> deletePendingBinding() async {
    pending = null;
  }

  @override
  Future<ActiveNotificationEndpointBinding?> readActiveBinding() async =>
      active;

  @override
  Future<void> writeActiveBinding(
    ActiveNotificationEndpointBinding binding,
  ) async {
    active = binding;
  }

  @override
  Future<void> clearAccountBindings() async {
    clearCount += 1;
    active = null;
    pending = null;
  }
}

final class _RecordingEndpointRepository
    implements NotificationEndpointRepository {
  _RecordingEndpointRepository({
    List<NotificationEndpointResult<NotificationEndpointMetadata?>>?
    statusResults,
    this.registerHandler,
    this.revokeResult = const NotificationEndpointSucceeded<void>(null),
  }) : statusResults =
           List<NotificationEndpointResult<NotificationEndpointMetadata?>>.from(
             statusResults ??
                 <NotificationEndpointResult<NotificationEndpointMetadata?>>[
                   const NotificationEndpointSucceeded<
                     NotificationEndpointMetadata?
                   >(null),
                 ],
           );

  final List<NotificationEndpointResult<NotificationEndpointMetadata?>>
  statusResults;
  final Future<NotificationEndpointResult<NotificationEndpointMetadata>>
  Function(NotificationEndpointRegistrationCommand command)?
  registerHandler;
  final NotificationEndpointResult<void> revokeResult;
  final List<NotificationEndpointRegistrationCommand> registerCommands =
      <NotificationEndpointRegistrationCommand>[];
  final List<NotificationEndpointBindingProof> revokedProofs =
      <NotificationEndpointBindingProof>[];

  @override
  Future<NotificationEndpointResult<NotificationEndpointMetadata?>> loadStatus(
    NotificationInstallationId installationId,
  ) async => statusResults.removeAt(0);

  @override
  Future<NotificationEndpointResult<NotificationEndpointMetadata>> register(
    NotificationEndpointRegistrationCommand command,
  ) async {
    registerCommands.add(command);
    return registerHandler?.call(command) ??
        NotificationEndpointSucceeded<NotificationEndpointMetadata>(
          _metadata(registrationId: command.registrationId.value, version: 1),
        );
  }

  @override
  Future<NotificationEndpointResult<void>> revoke(
    NotificationEndpointBindingProof proof,
  ) async {
    revokedProofs.add(proof);
    return revokeResult;
  }
}
