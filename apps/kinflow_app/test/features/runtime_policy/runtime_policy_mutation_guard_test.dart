import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/billing/application/billing_flow_state.dart';
import 'package:kinflow_app/features/billing/presentation/providers/billing_providers.dart';
import 'package:kinflow_app/features/calendar/application/calendar_events_state.dart';
import 'package:kinflow_app/features/calendar/application/calendar_import_state.dart';
import 'package:kinflow_app/features/calendar/application/ports/calendar_import_file_gateway.dart';
import 'package:kinflow_app/features/calendar/data/services/timezone_calendar_time_resolver.dart';
import 'package:kinflow_app/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:kinflow_app/features/chores/application/today_chores_state.dart';
import 'package:kinflow_app/features/chores/application/one_time_chore_trash_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_trash.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/chores/presentation/providers/chore_providers.dart';
import 'package:kinflow_app/features/household/application/first_household_onboarding_state.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/features/notifications/application/notification_center_controller.dart';
import 'package:kinflow_app/features/notifications/application/notification_center_state.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_models.dart';
import 'package:kinflow_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';
import 'package:kinflow_app/features/settings/application/profile_preferences_state.dart';
import 'package:kinflow_app/features/settings/domain/entities/profile_preferences.dart';
import 'package:kinflow_app/features/settings/presentation/providers/profile_preferences_providers.dart';

import '../../support/fakes/fake_calendar_dependencies.dart';
import '../../support/fakes/fake_chore_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';
import '../../support/fakes/fake_notification_dependencies.dart';
import '../../support/fakes/fake_profile_preferences_dependencies.dart';
import '../../support/fakes/fake_subscription_dependencies.dart';

void main() {
  test(
    'disabled chores keep reads while completion stops before repository I/O',
    () async {
      final occurrence = choreOccurrenceFixture();
      final FakeChoreRepository repository = FakeChoreRepository(
        today: todayChoresFixture(occurrences: [occurrence]),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appRuntimePolicyFeatureMutationsBlockedProvider(
            AppRuntimeFeature.chores,
          ).overrideWithValue(true),
          choreRepositoryProvider.overrideWithValue(repository),
          choreCommandIdGeneratorProvider.overrideWithValue(
            FakeChoreCommandIdGenerator(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen<TodayChoresState>(
        todayChoresProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final householdId = activeHouseholdFixture().householdId;

      await container.read(todayChoresProvider.notifier).load(householdId);
      await container
          .read(todayChoresProvider.notifier)
          .setCompleted(
            householdId: householdId,
            occurrenceId: occurrence.id,
            completed: true,
          );

      expect(repository.listRequests, isNotEmpty);
      expect(repository.completionRequests, isEmpty);
    },
  );

  test(
    'disabled calendar keeps reads while create stops before repository I/O',
    () async {
      final FakeCalendarRepository repository = FakeCalendarRepository();
      final FakeCalendarCommandIdGenerator idGenerator =
          FakeCalendarCommandIdGenerator();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appRuntimePolicyFeatureMutationsBlockedProvider(
            AppRuntimeFeature.calendar,
          ).overrideWithValue(true),
          calendarRepositoryProvider.overrideWithValue(repository),
          calendarCommandIdGeneratorProvider.overrideWithValue(idGenerator),
          calendarTimeResolverProvider.overrideWithValue(
            TimezoneCalendarTimeResolver(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen<CalendarEventsState>(
        calendarEventsProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await container
          .read(calendarEventsProvider.notifier)
          .load(calendarHouseholdId());
      await container
          .read(calendarEventsProvider.notifier)
          .create(calendarEventDraftFixture());

      expect(repository.pageRequests, isNotEmpty);
      expect(repository.createRequests, isEmpty);
      expect(idGenerator.callCount, 0);
    },
  );

  test(
    'disabled calendar import stops before native file picker I/O',
    () async {
      final _GuardCalendarImportFileGateway gateway =
          _GuardCalendarImportFileGateway();
      final FakeCalendarRepository repository = FakeCalendarRepository();
      final FakeCalendarCommandIdGenerator idGenerator =
          FakeCalendarCommandIdGenerator();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appRuntimePolicyFeatureMutationsBlockedProvider(
            AppRuntimeFeature.calendar,
          ).overrideWithValue(true),
          calendarImportFileGatewayProvider.overrideWithValue(gateway),
          calendarRepositoryProvider.overrideWithValue(repository),
          calendarCommandIdGeneratorProvider.overrideWithValue(idGenerator),
          calendarTimeResolverProvider.overrideWithValue(
            TimezoneCalendarTimeResolver(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen<CalendarImportState>(
        calendarImportProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await container
          .read(calendarImportProvider.notifier)
          .pickFile(
            householdId: calendarHouseholdId(),
            householdTimeZone: calendarEventListFixture().householdTimeZone,
            currentMemberId: calendarMemberOneId(),
            availableParticipantIds: [calendarMemberOneId()],
          );

      expect(gateway.callCount, 0);
      expect(idGenerator.callCount, 0);
      expect(repository.createRequests, isEmpty);
      expect(
        container.read(calendarImportProvider),
        isA<CalendarImportInitial>(),
      );
    },
  );

  test(
    'disabled chores keep trash reads while restore stops before IDs or I/O',
    () async {
      final householdId = activeHouseholdFixture().householdId;
      final item = DeletedOneTimeChore.tryCreate(
        householdId: householdId,
        seriesId: ChoreSeriesId.tryParse(
          '44444444-4444-4444-8444-444444444499',
        )!,
        occurrenceId: ChoreOccurrenceId.tryParse(
          '55555555-5555-4555-8555-555555555599',
        )!,
        title: 'Return books',
        description: null,
        assigneeMemberId: activeHouseholdFixture().memberId,
        assigneeDisplayName: 'Alex',
        dueLocalDate: ChoreLocalDate.tryParse('2026-08-09')!,
        dueLocalTime: null,
        dueAt: null,
        deletedAt: DateTime.parse('2026-08-09T10:00:00Z'),
        seriesVersion: 2,
        occurrenceVersion: 2,
      )!;
      final FakeChoreRepository repository = FakeChoreRepository(
        deletedOneTimeChoresResults: <LoadDeletedOneTimeChoresResult>[
          DeletedOneTimeChoresLoaded(
            DeletedOneTimeChorePage.tryCreate(
              householdId: householdId,
              householdTimezone: 'Asia/Seoul',
              generatedAt: DateTime.parse('2026-08-09T10:30:00Z'),
              pageLimit: 30,
              hasMore: false,
              nextCursor: null,
              items: <DeletedOneTimeChore>[item],
            )!,
          ),
        ],
      );
      final FakeChoreCommandIdGenerator idGenerator =
          FakeChoreCommandIdGenerator();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appRuntimePolicyFeatureMutationsBlockedProvider(
            AppRuntimeFeature.chores,
          ).overrideWithValue(true),
          choreRepositoryProvider.overrideWithValue(repository),
          choreCommandIdGeneratorProvider.overrideWithValue(idGenerator),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen<OneTimeChoreTrashState>(
        oneTimeChoreTrashProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await container
          .read(oneTimeChoreTrashProvider.notifier)
          .load(householdId);
      await container
          .read(oneTimeChoreTrashProvider.notifier)
          .restore(householdId: householdId, occurrenceId: item.occurrenceId);

      expect(repository.deletedOneTimeChoresRequests, hasLength(1));
      expect(repository.oneTimeRestoreRequests, isEmpty);
      expect(idGenerator.generateCount, 0);
    },
  );

  test(
    'disabled notifications keep reads while mark-all stops before repository I/O',
    () async {
      final FakeNotificationRepository repository =
          FakeNotificationRepository();
      final NotificationCenterController controller =
          NotificationCenterController(
            repository,
            snoozeIdFactory: () => NotificationSnoozeCommandId.tryParse(
              '85000000-0000-4000-8000-000000000001',
            )!,
          );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appRuntimePolicyFeatureMutationsBlockedProvider(
            AppRuntimeFeature.notifications,
          ).overrideWithValue(true),
          notificationRepositoryProvider.overrideWithValue(repository),
          notificationCenterControllerProvider.overrideWithValue(controller),
        ],
      );
      addTearDown(controller.dispose);
      addTearDown(container.dispose);
      final subscription = container.listen<NotificationCenterState>(
        notificationCenterProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final householdId = activeHouseholdFixture().householdId;

      await container
          .read(notificationCenterProvider.notifier)
          .load(householdId);
      await container.read(notificationCenterProvider.notifier).markAllRead();
      final bool snoozed = await container
          .read(notificationCenterProvider.notifier)
          .snoozeCalendar(
            NotificationInboxItemId.tryParse(notificationItemTwoUuid)!,
            10,
          );

      expect(repository.loadedHouseholds, <Object>[householdId]);
      expect(repository.markAllCount, 0);
      expect(repository.snoozeCalls, isEmpty);
      expect(snoozed, isFalse);
    },
  );

  test(
    'disabled profile keeps reads while save stops before repository I/O',
    () async {
      final FakeProfilePreferencesRepository repository =
          FakeProfilePreferencesRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appRuntimePolicyFeatureMutationsBlockedProvider(
            AppRuntimeFeature.profile,
          ).overrideWithValue(true),
          profilePreferencesRepositoryProvider.overrideWithValue(repository),
          profileLocalePreferenceSinkProvider.overrideWithValue(
            FakeProfileLocalePreferenceSink(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen<ProfilePreferencesState>(
        profilePreferencesProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await container
          .read(profilePreferencesProvider.notifier)
          .synchronize('runtime-policy-test');
      await container
          .read(profilePreferencesProvider.notifier)
          .save(
            displayName: 'Adult A',
            avatar: null,
            language: ProfileLanguage.english,
            profileTimezone: 'Asia/Seoul',
            householdTimezone: 'Asia/Seoul',
          );

      expect(repository.loadCount, 1);
      expect(repository.updateCalls, isEmpty);
    },
  );

  test(
    'disabled household stops creation before IDs or repository I/O',
    () async {
      final FakeHouseholdRepository repository = FakeHouseholdRepository();
      final FakeHouseholdCreationIdGenerator idGenerator =
          FakeHouseholdCreationIdGenerator();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appRuntimePolicyFeatureMutationsBlockedProvider(
            AppRuntimeFeature.household,
          ).overrideWithValue(true),
          householdRepositoryProvider.overrideWithValue(repository),
          householdCreationIdGeneratorProvider.overrideWithValue(idGenerator),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen<FirstHouseholdOnboardingState>(
        firstHouseholdOnboardingProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await container
          .read(firstHouseholdOnboardingProvider.notifier)
          .submit(
            householdName: 'Kim family',
            ownerDisplayName: 'Adult A',
            locale: 'en',
            timezone: 'Asia/Seoul',
          );

      expect(repository.createCount, 0);
      expect(idGenerator.generateCount, 0);
    },
  );

  test(
    'disabled billing stops purchase and restore before Store or assignment I/O',
    () async {
      final SubscriptionTestHarness harness = SubscriptionTestHarness();
      await harness.ready();
      addTearDown(harness.dispose);
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appRuntimePolicyFeatureMutationsBlockedProvider(
            AppRuntimeFeature.billing,
          ).overrideWithValue(true),
          billingFlowControllerProvider.overrideWithValue(harness.controller),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen<BillingFlowState>(
        billingFlowProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await container
          .read(billingFlowProvider.notifier)
          .purchase(subscriptionMonthlyPackage.id);
      await container.read(billingFlowProvider.notifier).restore();

      expect(harness.assignmentRepository.prepareCount, 0);
      expect(harness.port.purchaseRequests, isEmpty);
      expect(harness.port.restoreContexts, isEmpty);
    },
  );

  test('disabled chores do not block an unrelated calendar mutation', () async {
    final FakeCalendarRepository repository = FakeCalendarRepository();
    final FakeCalendarCommandIdGenerator idGenerator =
        FakeCalendarCommandIdGenerator();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        appRuntimePolicyFeatureMutationsBlockedProvider(
          AppRuntimeFeature.chores,
        ).overrideWithValue(true),
        calendarRepositoryProvider.overrideWithValue(repository),
        calendarCommandIdGeneratorProvider.overrideWithValue(idGenerator),
        calendarTimeResolverProvider.overrideWithValue(
          TimezoneCalendarTimeResolver(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen<CalendarEventsState>(
      calendarEventsProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container
        .read(calendarEventsProvider.notifier)
        .load(calendarHouseholdId());
    await container
        .read(calendarEventsProvider.notifier)
        .create(calendarEventDraftFixture());

    expect(repository.createRequests, hasLength(1));
    expect(idGenerator.callCount, 1);
  });
}

final class _GuardCalendarImportFileGateway
    implements CalendarImportFileGateway {
  var callCount = 0;

  @override
  Future<CalendarImportFilePickResult> pick() async {
    callCount += 1;
    return const CalendarImportFilePickCancelled();
  }
}
