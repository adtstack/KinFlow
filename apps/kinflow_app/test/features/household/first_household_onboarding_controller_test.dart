import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/household/application/first_household_onboarding_controller.dart';
import 'package:kinflow_app/features/household/application/first_household_onboarding_state.dart';
import 'package:kinflow_app/features/household/domain/entities/first_household_request.dart';
import 'package:kinflow_app/features/household/domain/failures/household_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

import '../../support/fakes/fake_household_dependencies.dart';

void main() {
  group('first household domain', () {
    test(
      'UUID value objects normalize and reject provider-controlled text',
      () {
        expect(
          HouseholdId.tryParse(' 22222222-2222-4222-8222-222222222222 ')?.value,
          '22222222-2222-4222-8222-222222222222',
        );
        expect(HouseholdId.tryParse('not-a-household'), isNull);
        expect(
          HouseholdMemberId.tryParse('33333333-3333-4333-8333-333333333333'),
          isNotNull,
        );
        expect(HouseholdCreationId.tryParse(''), isNull);
      },
    );

    test('draft normalizes accepted command fields', () {
      final FirstHouseholdDraft? draft = FirstHouseholdDraft.tryCreate(
        householdName: '  Kim Home ',
        ownerDisplayName: ' Alex  ',
        locale: ' KO ',
        timezone: ' Asia/Seoul ',
      );

      expect(draft?.householdName, 'Kim Home');
      expect(draft?.ownerDisplayName, 'Alex');
      expect(draft?.locale, 'ko');
      expect(draft?.timezone, 'Asia/Seoul');
    });

    test('draft rejects invalid names, locale, and approximate timezone', () {
      expect(_draft(householdName: ''), isNull);
      expect(_draft(ownerDisplayName: 'Alex\nInjected'), isNull);
      expect(_draft(locale: 'fr'), isNull);
      expect(_draft(timezone: 'local-time'), isNull);
      expect(_draft(timezone: 'posix/Asia/Seoul'), isNull);
      expect(_draft(timezone: 'UTC'), isNotNull);
    });
  });

  group('FirstHouseholdOnboardingController', () {
    test(
      'rejects invalid drafts before generating IDs or calling data',
      () async {
        final FakeHouseholdRepository repository = FakeHouseholdRepository();
        final FakeHouseholdCreationIdGenerator generator =
            FakeHouseholdCreationIdGenerator();
        final FirstHouseholdOnboardingController controller =
            FirstHouseholdOnboardingController(
              repository: repository,
              idGenerator: generator,
            );
        addTearDown(controller.dispose);

        await controller.submit(
          householdName: '',
          ownerDisplayName: 'Alex',
          locale: 'en',
          timezone: 'Asia/Seoul',
        );

        expect(controller.state, isA<FirstHouseholdOnboardingFailed>());
        expect(
          (controller.state as FirstHouseholdOnboardingFailed).failure.kind,
          HouseholdFailureKind.invalidInput,
        );
        expect(repository.createCount, 0);
        expect(generator.generateCount, 0);
      },
    );

    test('coalesces duplicate taps while one command is in flight', () async {
      final Completer<CreateFirstHouseholdResult> pending =
          Completer<CreateFirstHouseholdResult>();
      final FakeHouseholdRepository repository = FakeHouseholdRepository(
        createCallback: (_) => pending.future,
      );
      final FirstHouseholdOnboardingController controller =
          FirstHouseholdOnboardingController(
            repository: repository,
            idGenerator: FakeHouseholdCreationIdGenerator(),
          );
      addTearDown(() async {
        if (!pending.isCompleted) {
          pending.complete(FirstHouseholdCreated(activeHouseholdFixture()));
        }
        await controller.dispose();
      });

      final Future<void> first = _submit(controller);
      final Future<void> duplicate = _submit(controller);
      await Future<void>.delayed(Duration.zero);

      expect(identical(first, duplicate), isTrue);
      expect(repository.createCount, 1);
      expect(controller.state, isA<FirstHouseholdOnboardingSubmitting>());

      pending.complete(FirstHouseholdCreated(activeHouseholdFixture()));
      await first;

      expect(controller.state, isA<FirstHouseholdOnboardingSucceeded>());
    });

    test('same normalized retry reuses its idempotency key', () async {
      final FakeHouseholdRepository repository = FakeHouseholdRepository(
        createResults: <CreateFirstHouseholdResult>[
          const CreateFirstHouseholdFailed(
            HouseholdFailure(HouseholdFailureKind.temporarilyUnavailable),
          ),
          FirstHouseholdCreated(activeHouseholdFixture()),
        ],
      );
      final FakeHouseholdCreationIdGenerator generator =
          FakeHouseholdCreationIdGenerator();
      final FirstHouseholdOnboardingController controller =
          FirstHouseholdOnboardingController(
            repository: repository,
            idGenerator: generator,
          );
      addTearDown(controller.dispose);

      await _submit(controller);
      await controller.submit(
        householdName: ' Kim Home ',
        ownerDisplayName: ' Alex ',
        locale: 'EN',
        timezone: 'Asia/Seoul',
      );

      expect(repository.createCount, 2);
      expect(generator.generateCount, 1);
      expect(
        repository.createRequests.first.idempotencyKey,
        repository.createRequests.last.idempotencyKey,
      );
      expect(controller.state, isA<FirstHouseholdOnboardingSucceeded>());
    });

    test('changed command fields receive a new idempotency key', () async {
      final FakeHouseholdRepository repository = FakeHouseholdRepository(
        defaultCreateResult: const CreateFirstHouseholdFailed(
          HouseholdFailure(HouseholdFailureKind.temporarilyUnavailable),
        ),
      );
      final FakeHouseholdCreationIdGenerator generator =
          FakeHouseholdCreationIdGenerator(
            values: const <String>[
              'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
              'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            ],
          );
      final FirstHouseholdOnboardingController controller =
          FirstHouseholdOnboardingController(
            repository: repository,
            idGenerator: generator,
          );
      addTearDown(controller.dispose);

      await _submit(controller);
      await controller.submit(
        householdName: 'Lee Home',
        ownerDisplayName: 'Alex',
        locale: 'en',
        timezone: 'Asia/Seoul',
      );

      expect(generator.generateCount, 2);
      expect(
        repository.createRequests.first.idempotencyKey,
        isNot(repository.createRequests.last.idempotencyKey),
      );
    });

    test(
      'unexpected repository exceptions become safe internal failures',
      () async {
        final FakeHouseholdRepository repository = FakeHouseholdRepository(
          createCallback: (_) async {
            throw StateError('raw-provider-detail');
          },
        );
        final FirstHouseholdOnboardingController controller =
            FirstHouseholdOnboardingController(
              repository: repository,
              idGenerator: FakeHouseholdCreationIdGenerator(),
            );
        addTearDown(controller.dispose);

        await _submit(controller);

        expect(controller.state, isA<FirstHouseholdOnboardingFailed>());
        expect(
          (controller.state as FirstHouseholdOnboardingFailed).failure.kind,
          HouseholdFailureKind.internal,
        );
        expect(
          controller.state.toString(),
          isNot(contains('raw-provider-detail')),
        );
      },
    );
  });
}

FirstHouseholdDraft? _draft({
  String householdName = 'Kim Home',
  String ownerDisplayName = 'Alex',
  String locale = 'en',
  String timezone = 'Asia/Seoul',
}) {
  return FirstHouseholdDraft.tryCreate(
    householdName: householdName,
    ownerDisplayName: ownerDisplayName,
    locale: locale,
    timezone: timezone,
  );
}

Future<void> _submit(FirstHouseholdOnboardingController controller) {
  return controller.submit(
    householdName: 'Kim Home',
    ownerDisplayName: 'Alex',
    locale: 'en',
    timezone: 'Asia/Seoul',
  );
}
