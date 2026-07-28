import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/household/application/invite_flow_controller.dart';
import 'package:kinflow_app/features/household/application/invite_flow_state.dart';
import 'package:kinflow_app/features/household/data/services/ephemeral_pending_invite_store.dart';
import 'package:kinflow_app/features/household/domain/failures/invite_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/invite_repository.dart';

import '../../support/fakes/fake_invite_dependencies.dart';

void main() {
  test('captures an opaque token and exposes only a minimal preview', () async {
    final FakeInviteRepository repository = FakeInviteRepository();
    final EphemeralPendingInviteStore store = EphemeralPendingInviteStore();
    final InviteFlowController controller = InviteFlowController(
      repository: repository,
      idGenerator: FakeInviteCommandIdGenerator(),
      pendingInviteStore: store,
    );
    addTearDown(controller.dispose);

    expect(controller.capture(inviteTokenValue), isTrue);
    await controller.loadPreview();

    final InviteFlowPreviewReady ready =
        controller.state as InviteFlowPreviewReady;
    expect(ready.preview.householdDisplayName, 'Kim Home');
    expect(ready.preview.inviterDisplayName, 'Alex');
    expect(repository.previewTokens.single.value, inviteTokenValue);
    expect(
      repository.previewTokens.single.toString(),
      isNot(contains(inviteTokenValue)),
    );
  });

  test(
    'transient accept retry reuses one command ID then clears token',
    () async {
      final FakeInviteRepository repository = FakeInviteRepository(
        acceptResults: <AcceptHouseholdInviteResult>[
          const AcceptHouseholdInviteFailed(
            InviteFailure(InviteFailureKind.temporarilyUnavailable),
          ),
          HouseholdInviteAccepted(acceptedHouseholdInviteFixture()),
        ],
      );
      final FakeInviteCommandIdGenerator generator =
          FakeInviteCommandIdGenerator();
      final EphemeralPendingInviteStore store = EphemeralPendingInviteStore();
      final InviteFlowController controller = InviteFlowController(
        repository: repository,
        idGenerator: generator,
        pendingInviteStore: store,
      );
      addTearDown(controller.dispose);
      controller.capture(inviteTokenValue);
      await controller.loadPreview();

      await controller.accept(setActiveHousehold: true);
      expect(controller.state, isA<InviteFlowFailed>());
      expect(store.read(), isNotNull);
      await controller.accept(setActiveHousehold: true);

      expect(controller.state, isA<InviteFlowAccepted>());
      expect(store.read(), isNull);
      expect(generator.generateCount, 1);
      expect(
        repository.acceptRequests.first.idempotencyKey,
        repository.acceptRequests.last.idempotencyKey,
      );
    },
  );

  test('changing active-household choice gets a fresh command ID', () async {
    final FakeInviteRepository repository = FakeInviteRepository(
      acceptResults: const <AcceptHouseholdInviteResult>[
        AcceptHouseholdInviteFailed(
          InviteFailure(InviteFailureKind.temporarilyUnavailable),
        ),
        AcceptHouseholdInviteFailed(
          InviteFailure(InviteFailureKind.temporarilyUnavailable),
        ),
      ],
    );
    final FakeInviteCommandIdGenerator generator =
        FakeInviteCommandIdGenerator();
    final InviteFlowController controller = InviteFlowController(
      repository: repository,
      idGenerator: generator,
      pendingInviteStore: EphemeralPendingInviteStore(),
    );
    addTearDown(controller.dispose);
    controller.capture(inviteTokenValue);
    await controller.loadPreview();

    await controller.accept(setActiveHousehold: false);
    await controller.accept(setActiveHousehold: true);

    expect(generator.generateCount, 2);
    expect(
      repository.acceptRequests.first.idempotencyKey,
      isNot(repository.acceptRequests.last.idempotencyKey),
    );
  });

  test('terminal preview failure drops the capability token', () async {
    final EphemeralPendingInviteStore store = EphemeralPendingInviteStore();
    final InviteFlowController controller = InviteFlowController(
      repository: FakeInviteRepository(
        previewResults: const <PreviewHouseholdInviteResult>[
          PreviewHouseholdInviteFailed(
            InviteFailure(InviteFailureKind.expired),
          ),
        ],
      ),
      idGenerator: FakeInviteCommandIdGenerator(),
      pendingInviteStore: store,
    );
    addTearDown(controller.dispose);
    controller.capture(inviteTokenValue);

    await controller.loadPreview();

    expect(
      (controller.state as InviteFlowFailed).failure.kind,
      InviteFailureKind.expired,
    );
    expect(store.read(), isNull);
  });

  test('invalid capture fails closed without retaining input', () async {
    final EphemeralPendingInviteStore store = EphemeralPendingInviteStore();
    final InviteFlowController controller = InviteFlowController(
      repository: FakeInviteRepository(),
      idGenerator: FakeInviteCommandIdGenerator(),
      pendingInviteStore: store,
    );
    addTearDown(controller.dispose);

    expect(controller.capture('short raw secret'), isFalse);
    expect(controller.state, isA<InviteFlowMissing>());
    expect(store.read(), isNull);
  });

  test(
    'coalesces preview requests while the network call is pending',
    () async {
      final Completer<PreviewHouseholdInviteResult> response =
          Completer<PreviewHouseholdInviteResult>();
      final FakeInviteRepository repository = FakeInviteRepository(
        previewCallback: (_) => response.future,
      );
      final InviteFlowController controller = InviteFlowController(
        repository: repository,
        idGenerator: FakeInviteCommandIdGenerator(),
        pendingInviteStore: EphemeralPendingInviteStore(),
      );
      addTearDown(controller.dispose);
      controller.capture(inviteTokenValue);

      final Future<void> first = controller.loadPreview();
      final Future<void> duplicate = controller.loadPreview();
      expect(identical(first, duplicate), isTrue);
      expect(repository.previewTokens, hasLength(1));

      response.complete(
        HouseholdInvitePreviewed(householdInvitePreviewFixture()),
      );
      await first;
      expect(controller.state, isA<InviteFlowPreviewReady>());
    },
  );

  test('account-bound purge removes pending invitation authority', () async {
    final EphemeralPendingInviteStore store = EphemeralPendingInviteStore();
    expect(store.capture(inviteTokenValue), isTrue);

    await store.purgeSensitiveLocalState();

    expect(store.read(), isNull);
  });
}
