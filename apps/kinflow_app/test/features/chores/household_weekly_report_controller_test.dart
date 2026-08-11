import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/application/household_weekly_report_controller.dart';
import 'package:kinflow_app/features/chores/application/household_weekly_report_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/household_weekly_report.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

import '../../support/fakes/fake_chore_dependencies.dart';

void main() {
  final HouseholdId householdId = HouseholdId.tryParse(
    '22222222-2222-4222-8222-222222222222',
  )!;

  test('coalesces duplicate loads and publishes the requested week', () async {
    final Completer<LoadHouseholdWeeklyReportResult> response =
        Completer<LoadHouseholdWeeklyReportResult>();
    final FakeChoreRepository repository = FakeChoreRepository(
      weeklyReportCallback: (_) => response.future,
    );
    final HouseholdWeeklyReportController controller =
        HouseholdWeeklyReportController(repository: repository);
    addTearDown(controller.dispose);
    final HouseholdWeeklyReportRequest request =
        HouseholdWeeklyReportRequest.tryCreate(
          householdId: householdId,
          weekOffset: 0,
        )!;

    final Future<void> first = controller.load(request);
    final Future<void> duplicate = controller.load(request);

    expect(identical(first, duplicate), isTrue);
    expect(repository.weeklyReportRequests, <HouseholdWeeklyReportRequest>[
      request,
    ]);
    expect(controller.state, isA<HouseholdWeeklyReportLoading>());
    response.complete(
      HouseholdWeeklyReportLoaded(
        householdWeeklyReportFixture(householdId: householdId),
      ),
    );
    await first;

    expect(
      (controller.state as HouseholdWeeklyReportReady).report.weekOffset,
      0,
    );
  });

  test('preserves ready content during an explicit refresh', () async {
    final Completer<LoadHouseholdWeeklyReportResult> refresh =
        Completer<LoadHouseholdWeeklyReportResult>();
    var calls = 0;
    final FakeChoreRepository repository = FakeChoreRepository(
      weeklyReportCallback: (HouseholdWeeklyReportRequest request) {
        calls += 1;
        return calls == 1
            ? Future<LoadHouseholdWeeklyReportResult>.value(
                HouseholdWeeklyReportLoaded(
                  householdWeeklyReportFixture(
                    householdId: request.householdId,
                    weekOffset: request.weekOffset,
                  ),
                ),
              )
            : refresh.future;
      },
    );
    final HouseholdWeeklyReportController controller =
        HouseholdWeeklyReportController(repository: repository);
    addTearDown(controller.dispose);
    final HouseholdWeeklyReportRequest request =
        HouseholdWeeklyReportRequest.tryCreate(
          householdId: householdId,
          weekOffset: 0,
        )!;
    await controller.load(request);

    final Future<void> pending = controller.load(
      request,
      preserveContent: true,
    );
    expect((controller.state as HouseholdWeeklyReportReady).refreshing, isTrue);
    refresh.complete(
      HouseholdWeeklyReportLoaded(
        householdWeeklyReportFixture(householdId: householdId),
      ),
    );
    await pending;
    expect(
      (controller.state as HouseholdWeeklyReportReady).refreshing,
      isFalse,
    );
  });

  test('keeps the newer week when an older request finishes last', () async {
    final Completer<LoadHouseholdWeeklyReportResult> latest =
        Completer<LoadHouseholdWeeklyReportResult>();
    final Completer<LoadHouseholdWeeklyReportResult> older =
        Completer<LoadHouseholdWeeklyReportResult>();
    final FakeChoreRepository repository = FakeChoreRepository(
      weeklyReportCallback: (HouseholdWeeklyReportRequest request) =>
          request.weekOffset == 0 ? latest.future : older.future,
    );
    final HouseholdWeeklyReportController controller =
        HouseholdWeeklyReportController(repository: repository);
    addTearDown(controller.dispose);
    final HouseholdWeeklyReportRequest latestRequest =
        HouseholdWeeklyReportRequest.tryCreate(
          householdId: householdId,
          weekOffset: 0,
        )!;
    final HouseholdWeeklyReportRequest olderRequest =
        HouseholdWeeklyReportRequest.tryCreate(
          householdId: householdId,
          weekOffset: 1,
        )!;

    final Future<void> first = controller.load(olderRequest);
    final Future<void> second = controller.load(latestRequest);
    latest.complete(
      HouseholdWeeklyReportLoaded(
        householdWeeklyReportFixture(householdId: householdId),
      ),
    );
    await second;
    older.complete(
      HouseholdWeeklyReportLoaded(
        householdWeeklyReportFixture(householdId: householdId, weekOffset: 1),
      ),
    );
    await first;

    expect(
      (controller.state as HouseholdWeeklyReportReady).report.weekOffset,
      0,
    );
  });

  test('fails closed on mismatched rows and thrown provider detail', () async {
    final HouseholdWeeklyReportRequest request =
        HouseholdWeeklyReportRequest.tryCreate(
          householdId: householdId,
          weekOffset: 0,
        )!;
    final FakeChoreRepository mismatchedRepository = FakeChoreRepository(
      weeklyReportResults: <LoadHouseholdWeeklyReportResult>[
        HouseholdWeeklyReportLoaded(
          householdWeeklyReportFixture(householdId: householdId, weekOffset: 1),
        ),
      ],
    );
    final HouseholdWeeklyReportController mismatched =
        HouseholdWeeklyReportController(repository: mismatchedRepository);
    addTearDown(mismatched.dispose);
    await mismatched.load(request);
    expect(
      (mismatched.state as HouseholdWeeklyReportFailed).failure.kind,
      ChoreFailureKind.invalidPayload,
    );

    final FakeChoreRepository throwingRepository = FakeChoreRepository(
      weeklyReportCallback: (_) => throw StateError('provider secret'),
    );
    final HouseholdWeeklyReportController throwing =
        HouseholdWeeklyReportController(repository: throwingRepository);
    addTearDown(throwing.dispose);
    await throwing.load(request);
    expect(
      (throwing.state as HouseholdWeeklyReportFailed).failure.kind,
      ChoreFailureKind.internal,
    );
  });
}
