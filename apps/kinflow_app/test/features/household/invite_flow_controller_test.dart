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
    'normalizes an ephemeral short code and uses code-specific preview and accept',
    () async {
      final FakeInviteRepository repository = FakeInviteRepository();
      final EphemeralPendingInviteStore store = EphemeralPendingInviteStore();
      final InviteFlowController controller = InviteFlowController(
        repository: repository,
        idGenerator: FakeInviteCommandIdGenerator(),
        pendingInviteStore: store,
      );
      addTearDown(controller.dispose);

      expect(controller.captureShortCode(' 2345 abcd '), isTrue);
      expect(store.read(), isNull);
      expect(store.readShortCode()?.value, '2345ABCD');
      await controller.loadPreview();

      expect(controller.state, isA<InviteFlowPreviewReady>());
      expect(repository.previewTokens, isEmpty);
      expect(repository.previewShortCodes.single.value, '2345ABCD');

      await controller.accept(setActiveHousehold: true);

      expect(controller.state, isA<InviteFlowAccepted>());
      expect(repository.acceptRequests, isEmpty);
      expect(repository.acceptShortCodeRequests, hasLength(1));
      expect(
        repository.acceptShortCodeRequests.single.shortCode.value,
        '2345ABCD',
      );
      expect(store.readShortCode(), isNull);
    },
  );

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

    expect(controller.capture(inviteTokenValue), isTrue);
    expect(store.read(), isNotNull);
    expect(controller.capture('short raw secret'), isFalse);
    expect(controller.state, isA<InviteFlowMissing>());
    expect(store.read(), isNull);
  });

  test('token and short-code captures replace each other in memory', () async {
    final EphemeralPendingInviteStore store = EphemeralPendingInviteStore();

    expect(store.capture(inviteTokenValue), isTrue);
    expect(store.captureShortCode(inviteShortCodeValue), isTrue);
    expect(store.read(), isNull);
    expect(store.readShortCode()?.formatted, inviteShortCodeValue);

    expect(store.capture(inviteTokenValue), isTrue);
    expect(store.read()?.value, inviteTokenValue);
    expect(store.readShortCode(), isNull);

    expect(store.captureShortCode('ambiguous-I'), isFalse);
    expect(store.read(), isNull);
    expect(store.readShortCode(), isNull);
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

  test('clear discards a superseded in-flight preview result', () async {
    final Completer<PreviewHouseholdInviteResult> firstResponse =
        Completer<PreviewHouseholdInviteResult>();
    final Completer<PreviewHouseholdInviteResult> secondResponse =
        Completer<PreviewHouseholdInviteResult>();
    var previewCallCount = 0;
    final FakeInviteRepository repository = FakeInviteRepository(
      previewCallback: (_) {
        final int callIndex = previewCallCount;
        previewCallCount += 1;
        return callIndex == 0 ? firstResponse.future : secondResponse.future;
      },
    );
    final EphemeralPendingInviteStore store = EphemeralPendingInviteStore();
    final InviteFlowController controller = InviteFlowController(
      repository: repository,
      idGenerator: FakeInviteCommandIdGenerator(),
      pendingInviteStore: store,
    );
    addTearDown(controller.dispose);

    controller.capture(inviteTokenValue);
    final Future<void> first = controller.loadPreview();
    controller.clear();
    expect(controller.state, isA<InviteFlowMissing>());

    const String replacementToken =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefg';
    controller.capture(replacementToken);
    final Future<void> second = controller.loadPreview();
    expect(repository.previewTokens, hasLength(2));

    secondResponse.complete(
      HouseholdInvitePreviewed(householdInvitePreviewFixture()),
    );
    await second;
    expect(controller.state, isA<InviteFlowPreviewReady>());

    firstResponse.complete(
      const PreviewHouseholdInviteFailed(
        InviteFailure(InviteFailureKind.temporarilyUnavailable),
      ),
    );
    await first;
    expect(controller.state, isA<InviteFlowPreviewReady>());
    expect(store.read()?.value, replacementToken);
  });

  test('clear discards a superseded in-flight accept result', () async {
    final Completer<AcceptHouseholdInviteResult> response =
        Completer<AcceptHouseholdInviteResult>();
    final EphemeralPendingInviteStore store = EphemeralPendingInviteStore();
    final InviteFlowController controller = InviteFlowController(
      repository: FakeInviteRepository(acceptCallback: (_) => response.future),
      idGenerator: FakeInviteCommandIdGenerator(),
      pendingInviteStore: store,
    );
    addTearDown(controller.dispose);
    controller.capture(inviteTokenValue);
    await controller.loadPreview();

    final Future<void> acceptance = controller.accept(setActiveHousehold: true);
    controller.clear();
    expect(controller.state, isA<InviteFlowMissing>());
    expect(store.read(), isNull);

    response.complete(
      HouseholdInviteAccepted(acceptedHouseholdInviteFixture()),
    );
    await acceptance;

    expect(controller.state, isA<InviteFlowMissing>());
    expect(store.read(), isNull);
  });

  test('account-bound purge removes pending invitation authority', () async {
    final EphemeralPendingInviteStore store = EphemeralPendingInviteStore();
    expect(store.captureShortCode(inviteShortCodeValue), isTrue);

    await store.purgeSensitiveLocalState();

    expect(store.read(), isNull);
    expect(store.readShortCode(), isNull);
  });
}
