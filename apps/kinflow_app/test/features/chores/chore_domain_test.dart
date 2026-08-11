import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_completion_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_list_query.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_history.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_reassignment_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_restore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_reschedule_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_skip_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_template.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_change.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/repeating_chore_series_change.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

void main() {
  group('ChoreTemplateCatalog', () {
    test('exposes the exact PII-free immutable catalog', () {
      expect(ChoreTemplateCatalog.version, '2026-08-09-wp03-19');
      expect(ChoreTemplateCatalog.categories, const <ChoreTemplateCategory>[
        ChoreTemplateCategory.kitchen,
        ChoreTemplateCategory.cleaning,
        ChoreTemplateCategory.laundry,
        ChoreTemplateCategory.homeCare,
        ChoreTemplateCategory.petCare,
      ]);
      expect(ChoreTemplateCatalog.templates, const <ChoreTemplatePreset>[
        ChoreTemplatePreset.dishes,
        ChoreTemplatePreset.kitchenReset,
        ChoreTemplatePreset.laundry,
        ChoreTemplatePreset.vacuuming,
        ChoreTemplatePreset.bathroomCleaning,
        ChoreTemplatePreset.trashAndRecycling,
        ChoreTemplatePreset.wipeCounters,
        ChoreTemplatePreset.fridgeCleanout,
        ChoreTemplatePreset.mopFloors,
        ChoreTemplatePreset.dusting,
        ChoreTemplatePreset.changeBedLinen,
        ChoreTemplatePreset.foldClothes,
        ChoreTemplatePreset.makeBeds,
        ChoreTemplatePreset.waterPlants,
        ChoreTemplatePreset.feedPets,
        ChoreTemplatePreset.cleanPetArea,
      ]);
      expect(ChoreTemplateCatalog.templates, hasLength(16));
      expect(
        ChoreTemplateCatalog.templates
            .map((ChoreTemplatePreset template) => template.stableKey)
            .toSet(),
        hasLength(ChoreTemplateCatalog.templates.length),
      );
      for (final ChoreTemplatePreset template
          in ChoreTemplateCatalog.templates) {
        expect(template.stableKey, matches(RegExp(r'^[a-z]+(?:_[a-z]+)*$')));
        expect(
          template.suggestedCadence,
          isIn(const <ChoreTemplateCadence>[
            ChoreTemplateCadence.daily,
            ChoreTemplateCadence.weekly,
          ]),
        );
        expect(
          ChoreTemplatePreset.tryParseStableKey(template.stableKey),
          template,
        );
        expect(
          ChoreTemplateCategory.tryParseStableKey(template.category.stableKey),
          template.category,
        );
      }
      for (final ChoreTemplateCategory category
          in ChoreTemplateCatalog.categories) {
        expect(category.stableKey, matches(RegExp(r'^[a-z]+(?:_[a-z]+)*$')));
        expect(
          ChoreTemplateCatalog.templates.where(
            (ChoreTemplatePreset template) => template.category == category,
          ),
          isNotEmpty,
        );
      }
      expect(
        () => ChoreTemplateCatalog.templates.add(ChoreTemplatePreset.dishes),
        throwsUnsupportedError,
      );
      expect(
        () =>
            ChoreTemplateCatalog.categories.add(ChoreTemplateCategory.kitchen),
        throwsUnsupportedError,
      );
    });

    test('rejects normalized and unknown template keys', () {
      expect(ChoreTemplatePreset.tryParseStableKey('DISHES'), isNull);
      expect(ChoreTemplatePreset.tryParseStableKey(' dishes '), isNull);
      expect(ChoreTemplatePreset.tryParseStableKey('custom_chore'), isNull);
      expect(ChoreTemplatePreset.tryParseStableKey(''), isNull);
      expect(ChoreTemplateCategory.tryParseStableKey('KITCHEN'), isNull);
      expect(ChoreTemplateCategory.tryParseStableKey(' kitchen '), isNull);
      expect(ChoreTemplateCategory.tryParseStableKey('outdoors'), isNull);
      expect(ChoreTemplateCategory.tryParseStableKey(''), isNull);
    });
  });

  group('chore value objects', () {
    test('accepts real calendar dates and rejects normalized overflow', () {
      expect(ChoreLocalDate.tryParse('2028-02-29')?.value, '2028-02-29');
      expect(ChoreLocalDate.tryParse('2027-02-29'), isNull);
      expect(ChoreLocalDate.tryParse('2026-2-01'), isNull);
    });

    test('normalizes minute precision and rejects non-zero seconds', () {
      expect(ChoreLocalTime.tryParse('09:05')?.value, '09:05');
      expect(ChoreLocalTime.tryParse('09:05:00')?.value, '09:05');
      expect(ChoreLocalTime.tryParse('09:05:00.000000')?.value, '09:05');
      expect(ChoreLocalTime.tryParse('09:05:00.5'), isNull);
      expect(ChoreLocalTime.tryParse('09:05:01'), isNull);
      expect(ChoreLocalTime.tryParse('24:00'), isNull);
    });
  });

  group('ChoreListQuery', () {
    test('bounds requests and accepts only normalized opaque cursors', () {
      final ChoreListCursor cursor = ChoreListCursor.tryParse('7b7d')!;
      final ChoreListRequest request = ChoreListRequest.tryCreate(
        householdId: _householdId(),
        view: ChoreListView.upcoming,
        assigneeMemberId: _memberId(),
        limit: 25,
        cursor: cursor,
      )!;

      expect(request.view.wireName, 'upcoming');
      expect(request.firstPage.cursor, isNull);
      expect(request.continuation(cursor)?.cursor, cursor);
      expect(ChoreListView.tryParse('completed'), ChoreListView.completed);
      expect(ChoreListView.tryParse('tomorrow'), isNull);
      expect(ChoreListCursor.tryParse('ABC0'), isNull);
      expect(ChoreListCursor.tryParse('abc'), isNull);
      expect(
        ChoreListRequest.tryCreate(householdId: _householdId(), limit: 0),
        isNull,
      );
      expect(
        ChoreListRequest.tryCreate(householdId: _householdId(), limit: 101),
        isNull,
      );
    });

    test('evaluates view and Me membership after optimistic changes', () {
      final ChoreOccurrence scheduled = _occurrence(_occurrenceId());
      final TodayChores today = TodayChores(
        householdId: _householdId(),
        householdTimezone: 'Asia/Seoul',
        localDate: _date(),
        occurrences: <ChoreOccurrence>[scheduled],
        assigneeFilterMemberId: _memberId(),
      );
      final TodayChores upcoming = TodayChores(
        householdId: _householdId(),
        householdTimezone: 'Asia/Seoul',
        localDate: _date(),
        occurrences: const <ChoreOccurrence>[],
        view: ChoreListView.upcoming,
        assigneeFilterMemberId: _memberId(),
      );
      final ChoreOccurrence tomorrow = scheduled.rescheduled(
        dueLocalDate: ChoreLocalDate.tryParse('2026-08-07')!,
        dueLocalTime: null,
        dueAt: null,
      );

      expect(today.matches(scheduled), isTrue);
      expect(
        today
            .applyOccurrence(
              scheduled.copyWith(status: ChoreOccurrenceStatus.completed),
            )
            .occurrences,
        hasLength(1),
      );
      expect(upcoming.matches(tomorrow), isTrue);
      expect(
        upcoming
            .applyOccurrence(tomorrow)
            .applyOccurrence(
              tomorrow.copyWith(status: ChoreOccurrenceStatus.completed),
            )
            .occurrences,
        isEmpty,
      );
      expect(
        upcoming.matches(
          tomorrow.reassigned(
            assigneeMemberId: _otherMemberId(),
            assigneeDisplayName: 'Sam',
          ),
        ),
        isFalse,
      );
    });

    test('merges only compatible strictly advancing pages', () {
      final ChoreOccurrence first =
          _occurrence(
            ChoreOccurrenceId.tryParse('55555555-5555-4555-8555-555555555551')!,
          ).rescheduled(
            dueLocalDate: ChoreLocalDate.tryParse('2026-08-07')!,
            dueLocalTime: null,
            dueAt: null,
          );
      final ChoreOccurrence second =
          _occurrence(
            ChoreOccurrenceId.tryParse('55555555-5555-4555-8555-555555555552')!,
          ).rescheduled(
            dueLocalDate: ChoreLocalDate.tryParse('2026-08-08')!,
            dueLocalTime: null,
            dueAt: null,
          );
      final TodayChores firstPage = TodayChores(
        householdId: _householdId(),
        householdTimezone: 'Asia/Seoul',
        localDate: _date(),
        occurrences: <ChoreOccurrence>[first],
        view: ChoreListView.upcoming,
        generatedAt: DateTime.parse('2026-08-06T10:30:00Z'),
        pageLimit: 1,
        hasMore: true,
        nextCursor: ChoreListCursor.tryParse('7b7d'),
      );
      final TodayChores secondPage = TodayChores(
        householdId: _householdId(),
        householdTimezone: 'Asia/Seoul',
        localDate: _date(),
        occurrences: <ChoreOccurrence>[second],
        view: ChoreListView.upcoming,
        generatedAt: DateTime.parse('2026-08-06T10:31:00Z'),
        pageLimit: 1,
      );

      expect(firstPage.appendPage(secondPage)?.occurrences, <ChoreOccurrence>[
        first,
        second,
      ]);
      expect(firstPage.appendPage(firstPage), isNull);
      expect(
        firstPage.appendPage(
          TodayChores(
            householdId: _householdId(),
            householdTimezone: 'Asia/Seoul',
            localDate: _date(),
            occurrences: <ChoreOccurrence>[second],
            view: ChoreListView.overdue,
            pageLimit: 1,
          ),
        ),
        isNull,
      );
    });
  });

  group('OneTimeChoreDraft', () {
    test('normalizes user text and produces a stable fingerprint', () {
      final OneTimeChoreDraft? first = OneTimeChoreDraft.tryCreate(
        householdId: _householdId(),
        title: '  Take out recycling  ',
        description: '  Blue bin  ',
        assigneeMemberId: _memberId(),
        dueLocalDate: _date(),
        dueLocalTime: ChoreLocalTime.tryParse('19:30'),
      );
      final OneTimeChoreDraft? retry = OneTimeChoreDraft.tryCreate(
        householdId: _householdId(),
        title: 'Take out recycling',
        description: 'Blue bin',
        assigneeMemberId: _memberId(),
        dueLocalDate: _date(),
        dueLocalTime: ChoreLocalTime.tryParse('19:30:00'),
      );

      expect(first?.title, 'Take out recycling');
      expect(first?.description, 'Blue bin');
      expect(first?.fingerprint, retry?.fingerprint);
    });

    test('rejects empty, oversized, and control-character titles', () {
      for (final String title in <String>[
        ' ',
        'Wash\ncar',
        List<String>.filled(161, 'x').join(),
      ]) {
        expect(
          OneTimeChoreDraft.tryCreate(
            householdId: _householdId(),
            title: title,
            description: '',
            assigneeMemberId: _memberId(),
            dueLocalDate: _date(),
            dueLocalTime: null,
          ),
          isNull,
          reason: title.length.toString(),
        );
      }
    });
  });

  group('OneTimeChoreChangeDrafts', () {
    test('normalizes an update and preserves both optimistic versions', () {
      final OneTimeChoreUpdateDraft first = OneTimeChoreUpdateDraft.tryCreate(
        householdId: _householdId(),
        seriesId: _seriesId(),
        occurrenceId: _occurrenceId(),
        expectedSeriesVersion: 4,
        expectedOccurrenceVersion: 7,
        title: '  Updated recycling  ',
        description: '  Use the blue bin  ',
        assigneeMemberId: _otherMemberId(),
        dueLocalDate: ChoreLocalDate.tryParse('2026-08-07')!,
        dueLocalTime: ChoreLocalTime.tryParse('18:30:00'),
      )!;
      final OneTimeChoreUpdateDraft retry = OneTimeChoreUpdateDraft.tryCreate(
        householdId: _householdId(),
        seriesId: _seriesId(),
        occurrenceId: _occurrenceId(),
        expectedSeriesVersion: 4,
        expectedOccurrenceVersion: 7,
        title: 'Updated recycling',
        description: 'Use the blue bin',
        assigneeMemberId: _otherMemberId(),
        dueLocalDate: ChoreLocalDate.tryParse('2026-08-07')!,
        dueLocalTime: ChoreLocalTime.tryParse('18:30'),
      )!;
      final UpdateOneTimeChoreRequest request = first.withId(_commandId());

      expect(first.title, 'Updated recycling');
      expect(first.description, 'Use the blue bin');
      expect(first.fingerprint, retry.fingerprint);
      expect(request.idempotencyKey, _commandId());
      expect(request.expectedSeriesVersion, 4);
      expect(request.expectedOccurrenceVersion, 7);
      expect(request.dueLocalTime?.value, '18:30');
      expect(
        first.fingerprint,
        isNot(
          OneTimeChoreUpdateDraft.tryCreate(
            householdId: _householdId(),
            seriesId: _seriesId(),
            occurrenceId: _occurrenceId(),
            expectedSeriesVersion: 4,
            expectedOccurrenceVersion: 7,
            title: 'Updated recycling again',
            description: 'Use the blue bin',
            assigneeMemberId: _otherMemberId(),
            dueLocalDate: ChoreLocalDate.tryParse('2026-08-07')!,
            dueLocalTime: ChoreLocalTime.tryParse('18:30'),
          )?.fingerprint,
        ),
      );
    });

    test('rejects unsafe update input and versions', () {
      for (final OneTimeChoreUpdateDraft? draft in <OneTimeChoreUpdateDraft?>[
        _oneTimeUpdateDraft(expectedSeriesVersion: 0),
        _oneTimeUpdateDraft(expectedOccurrenceVersion: 0),
        _oneTimeUpdateDraft(title: ' '),
        _oneTimeUpdateDraft(title: 'Wash\ncar'),
        _oneTimeUpdateDraft(description: List<String>.filled(4001, 'x').join()),
      ]) {
        expect(draft, isNull);
      }
    });

    test('binds deletion to the same resource and a distinct operation', () {
      final OneTimeChoreDeletionDraft deletion =
          OneTimeChoreDeletionDraft.tryCreate(
            householdId: _householdId(),
            seriesId: _seriesId(),
            occurrenceId: _occurrenceId(),
            expectedSeriesVersion: 4,
            expectedOccurrenceVersion: 7,
          )!;
      final DeleteOneTimeChoreRequest request = deletion.withId(_commandId());

      expect(request.seriesId, _seriesId());
      expect(request.occurrenceId, _occurrenceId());
      expect(request.expectedSeriesVersion, 4);
      expect(request.expectedOccurrenceVersion, 7);
      expect(deletion.fingerprint, contains('deleteOneTimeChore'));
      expect(
        OneTimeChoreDeletionDraft.tryCreate(
          householdId: _householdId(),
          seriesId: _seriesId(),
          occurrenceId: _occurrenceId(),
          expectedSeriesVersion: 0,
          expectedOccurrenceVersion: 7,
        ),
        isNull,
      );
    });

    test('allows management only for scheduled non-recurring occurrences', () {
      final ChoreOccurrence scheduled = _occurrence(_occurrenceId());
      final ChoreOccurrence completed = scheduled.copyWith(
        status: ChoreOccurrenceStatus.completed,
      );
      final ChoreOccurrence recurring = ChoreOccurrence(
        id: _occurrenceId(),
        seriesId: _seriesId(),
        title: 'Take out recycling',
        assigneeMemberId: _memberId(),
        assigneeDisplayName: 'Alex',
        dueLocalDate: _date(),
        recurrenceFrequency: ChoreRecurrenceFrequency.daily,
        status: ChoreOccurrenceStatus.scheduled,
        version: 1,
      );

      expect(scheduled.canManageOneTime, isTrue);
      expect(completed.canManageOneTime, isFalse);
      expect(recurring.canManageOneTime, isFalse);
    });
  });

  group('ChoreCompletionDraft', () {
    test('produces a stable request fingerprint and preserves its fields', () {
      final ChoreCompletionDraft? first = ChoreCompletionDraft.tryCreate(
        householdId: _householdId(),
        occurrenceId: _occurrenceId(),
        expectedVersion: 4,
        completed: true,
      );
      final ChoreCompletionDraft? retry = ChoreCompletionDraft.tryCreate(
        householdId: _householdId(),
        occurrenceId: _occurrenceId(),
        expectedVersion: 4,
        completed: true,
      );
      final SetChoreCompletionRequest request = first!.withId(_commandId());

      expect(first.fingerprint, retry?.fingerprint);
      expect(request.idempotencyKey, _commandId());
      expect(request.householdId, _householdId());
      expect(request.occurrenceId, _occurrenceId());
      expect(request.expectedVersion, 4);
      expect(request.completed, isTrue);
    });

    test(
      'changes the fingerprint with intent and rejects invalid versions',
      () {
        final ChoreCompletionDraft complete = ChoreCompletionDraft.tryCreate(
          householdId: _householdId(),
          occurrenceId: _occurrenceId(),
          expectedVersion: 1,
          completed: true,
        )!;
        final ChoreCompletionDraft reopen = ChoreCompletionDraft.tryCreate(
          householdId: _householdId(),
          occurrenceId: _occurrenceId(),
          expectedVersion: 2,
          completed: false,
        )!;

        expect(complete.fingerprint, isNot(reopen.fingerprint));
        expect(
          ChoreCompletionDraft.tryCreate(
            householdId: _householdId(),
            occurrenceId: _occurrenceId(),
            expectedVersion: 0,
            completed: true,
          ),
          isNull,
        );
      },
    );
  });

  group('ChoreRecurrenceRule', () {
    test('anchors daily, weekly, and monthly rules to the first date', () {
      final ChoreLocalDate start = _date();
      final Map<ChoreRecurrenceFrequency, Map<String, Object?>> expected =
          <ChoreRecurrenceFrequency, Map<String, Object?>>{
            ChoreRecurrenceFrequency.daily: <String, Object?>{
              'frequency': 'daily',
              'interval': 1,
              'end': <String, Object?>{'type': 'never'},
            },
            ChoreRecurrenceFrequency.weekly: <String, Object?>{
              'frequency': 'weekly',
              'interval': 1,
              'weekdays': <String>['TH'],
              'end': <String, Object?>{'type': 'never'},
            },
            ChoreRecurrenceFrequency.monthly: <String, Object?>{
              'frequency': 'monthly',
              'interval': 1,
              'monthDay': 6,
              'end': <String, Object?>{'type': 'never'},
            },
          };

      for (final MapEntry<ChoreRecurrenceFrequency, Map<String, Object?>> entry
          in expected.entries) {
        final ChoreRecurrenceRule rule = ChoreRecurrenceRule.anchored(
          frequency: entry.key,
          startLocalDate: start,
        );

        expect(rule.toJson(), entry.value, reason: entry.key.name);
        expect(rule.startsOn(start), isTrue, reason: entry.key.name);
        expect(
          ChoreRecurrenceRule.tryParse(rule.toJson())?.fingerprint,
          rule.fingerprint,
          reason: entry.key.name,
        );
      }
    });

    test('builds bounded advanced rules anchored to the first date', () {
      final ChoreRecurrenceRule? rule = ChoreRecurrenceRule.tryAnchored(
        frequency: ChoreRecurrenceFrequency.weekly,
        startLocalDate: _date(),
        interval: 2,
        end: const ChoreRecurrenceCountEnd(6),
      );

      expect(rule?.toJson(), <String, Object?>{
        'frequency': 'weekly',
        'interval': 2,
        'weekdays': <String>['TH'],
        'end': <String, Object?>{'type': 'count', 'count': 6},
      });
      for (final ChoreRecurrenceRule? invalid in <ChoreRecurrenceRule?>[
        ChoreRecurrenceRule.tryAnchored(
          frequency: ChoreRecurrenceFrequency.daily,
          startLocalDate: _date(),
          interval: 0,
          end: const ChoreRecurrenceNeverEnds(),
        ),
        ChoreRecurrenceRule.tryAnchored(
          frequency: ChoreRecurrenceFrequency.daily,
          startLocalDate: _date(),
          interval: 31,
          end: const ChoreRecurrenceNeverEnds(),
        ),
        ChoreRecurrenceRule.tryAnchored(
          frequency: ChoreRecurrenceFrequency.daily,
          startLocalDate: _date(),
          interval: 1,
          end: const ChoreRecurrenceCountEnd(1001),
        ),
        ChoreRecurrenceRule.tryAnchored(
          frequency: ChoreRecurrenceFrequency.daily,
          startLocalDate: _date(),
          interval: 1,
          end: ChoreRecurrenceUntilEnd(ChoreLocalDate.tryParse('2026-08-05')!),
        ),
      ]) {
        expect(invalid, isNull);
      }
    });

    test('changes interval and end without losing existing anchors', () {
      final ChoreRecurrenceRule weekly = ChoreRecurrenceRule.tryParse(
        <String, Object?>{
          'frequency': 'weekly',
          'interval': 1,
          'weekdays': <String>['MO', 'FR'],
          'end': <String, Object?>{'type': 'never'},
        },
      )!;
      final ChoreRecurrenceRule monthly = ChoreRecurrenceRule.tryParse(
        <String, Object?>{
          'frequency': 'monthly',
          'interval': 1,
          'monthDay': 31,
          'end': <String, Object?>{'type': 'never'},
        },
      )!;
      final ChoreRecurrenceEnd until = ChoreRecurrenceUntilEnd(
        ChoreLocalDate.tryParse('2026-09-30')!,
      );

      expect(
        weekly
            .tryWithIntervalAndEnd(
              interval: 3,
              end: until,
              minimumLocalDate: _date(),
            )
            ?.toJson(),
        <String, Object?>{
          'frequency': 'weekly',
          'interval': 3,
          'weekdays': <String>['MO', 'FR'],
          'end': <String, Object?>{'type': 'until', 'localDate': '2026-09-30'},
        },
      );
      expect(
        monthly
            .tryWithIntervalAndEnd(
              interval: 2,
              end: const ChoreRecurrenceCountEnd(12),
              minimumLocalDate: _date(),
            )
            ?.monthDay,
        31,
      );
      expect(
        weekly.tryWithIntervalAndEnd(
          interval: 1,
          end: ChoreRecurrenceUntilEnd(ChoreLocalDate.tryParse('2026-08-05')!),
          minimumLocalDate: _date(),
        ),
        isNull,
      );
    });

    test('selects and canonicalizes bounded weekly weekdays', () {
      final ChoreRecurrenceRule weekly = ChoreRecurrenceRule.anchored(
        frequency: ChoreRecurrenceFrequency.weekly,
        startLocalDate: _date(),
      );
      final ChoreRecurrenceRule? creationRule = weekly.tryWithWeeklyWeekdays(
        weekdays: const <ChoreWeekday>[
          ChoreWeekday.sunday,
          ChoreWeekday.thursday,
          ChoreWeekday.monday,
        ],
        interval: 2,
        end: const ChoreRecurrenceCountEnd(8),
        minimumLocalDate: _date(),
        requiredStartLocalDate: _date(),
      );
      final ChoreRecurrenceRule? futureSeriesRule = weekly
          .tryWithWeeklyWeekdays(
            weekdays: const <ChoreWeekday>[
              ChoreWeekday.friday,
              ChoreWeekday.monday,
            ],
            interval: 1,
            end: const ChoreRecurrenceNeverEnds(),
            minimumLocalDate: _date(),
          );
      final ChoreRecurrenceRule? everyDayRule = weekly.tryWithWeeklyWeekdays(
        weekdays: ChoreWeekday.values.reversed,
        interval: 1,
        end: const ChoreRecurrenceNeverEnds(),
        minimumLocalDate: _date(),
      );

      expect(creationRule?.toJson(), <String, Object?>{
        'frequency': 'weekly',
        'interval': 2,
        'weekdays': <String>['MO', 'TH', 'SU'],
        'end': <String, Object?>{'type': 'count', 'count': 8},
      });
      expect(futureSeriesRule?.weekdays, const <ChoreWeekday>[
        ChoreWeekday.monday,
        ChoreWeekday.friday,
      ]);
      expect(everyDayRule?.weekdays, ChoreWeekday.values);
    });

    test('rejects invalid weekly weekday selections before a request', () {
      final ChoreRecurrenceRule weekly = ChoreRecurrenceRule.anchored(
        frequency: ChoreRecurrenceFrequency.weekly,
        startLocalDate: _date(),
      );
      final ChoreRecurrenceRule daily = ChoreRecurrenceRule.anchored(
        frequency: ChoreRecurrenceFrequency.daily,
        startLocalDate: _date(),
      );

      for (final ChoreRecurrenceRule? invalid in <ChoreRecurrenceRule?>[
        weekly.tryWithWeeklyWeekdays(
          weekdays: const <ChoreWeekday>[],
          interval: 1,
          end: const ChoreRecurrenceNeverEnds(),
          minimumLocalDate: _date(),
        ),
        weekly.tryWithWeeklyWeekdays(
          weekdays: const <ChoreWeekday>[
            ChoreWeekday.monday,
            ChoreWeekday.monday,
          ],
          interval: 1,
          end: const ChoreRecurrenceNeverEnds(),
          minimumLocalDate: _date(),
        ),
        weekly.tryWithWeeklyWeekdays(
          weekdays: const <ChoreWeekday>[ChoreWeekday.monday],
          interval: 1,
          end: const ChoreRecurrenceNeverEnds(),
          minimumLocalDate: _date(),
          requiredStartLocalDate: _date(),
        ),
        daily.tryWithWeeklyWeekdays(
          weekdays: const <ChoreWeekday>[ChoreWeekday.thursday],
          interval: 1,
          end: const ChoreRecurrenceNeverEnds(),
          minimumLocalDate: _date(),
        ),
      ]) {
        expect(invalid, isNull);
      }
    });

    test('changes a bounded monthly day without losing rule bounds', () {
      final ChoreRecurrenceRule monthly = ChoreRecurrenceRule.anchored(
        frequency: ChoreRecurrenceFrequency.monthly,
        startLocalDate: _date(),
      );
      final ChoreRecurrenceRule? changed = monthly.tryWithMonthlyDay(
        monthDay: 31,
        interval: 2,
        end: const ChoreRecurrenceCountEnd(12),
        minimumLocalDate: _date(),
      );

      expect(changed?.toJson(), <String, Object?>{
        'frequency': 'monthly',
        'interval': 2,
        'monthDay': 31,
        'end': <String, Object?>{'type': 'count', 'count': 12},
      });
      expect(changed?.fingerprint, isNot(monthly.fingerprint));
      expect(
        monthly
            .tryWithMonthlyDay(
              monthDay: 1,
              interval: 1,
              end: const ChoreRecurrenceNeverEnds(),
              minimumLocalDate: _date(),
            )
            ?.monthDay,
        1,
      );

      final ChoreRecurrenceRule daily = ChoreRecurrenceRule.anchored(
        frequency: ChoreRecurrenceFrequency.daily,
        startLocalDate: _date(),
      );
      for (final ChoreRecurrenceRule? invalid in <ChoreRecurrenceRule?>[
        monthly.tryWithMonthlyDay(
          monthDay: 0,
          interval: 1,
          end: const ChoreRecurrenceNeverEnds(),
          minimumLocalDate: _date(),
        ),
        monthly.tryWithMonthlyDay(
          monthDay: 32,
          interval: 1,
          end: const ChoreRecurrenceNeverEnds(),
          minimumLocalDate: _date(),
        ),
        monthly.tryWithMonthlyDay(
          monthDay: 15,
          interval: 31,
          end: const ChoreRecurrenceNeverEnds(),
          minimumLocalDate: _date(),
        ),
        daily.tryWithMonthlyDay(
          monthDay: 15,
          interval: 1,
          end: const ChoreRecurrenceNeverEnds(),
          minimumLocalDate: _date(),
        ),
      ]) {
        expect(invalid, isNull);
      }
    });

    test('strictly parses bounded end rules and rejects malformed input', () {
      final ChoreRecurrenceRule? countRule = ChoreRecurrenceRule.tryParse(
        <String, Object?>{
          'frequency': 'weekly',
          'interval': 2,
          'weekdays': <String>['MO', 'FR'],
          'end': <String, Object?>{'type': 'count', 'count': 8},
        },
      );
      final ChoreRecurrenceRule? untilRule = ChoreRecurrenceRule.tryParse(
        <String, Object?>{
          'frequency': 'monthly',
          'interval': 1,
          'monthDay': 31,
          'end': <String, Object?>{'type': 'until', 'localDate': '2027-12-31'},
        },
      );

      expect((countRule?.end as ChoreRecurrenceCountEnd).count, 8);
      expect(
        (untilRule?.end as ChoreRecurrenceUntilEnd).localDate.value,
        '2027-12-31',
      );
      for (final Object? value in <Object?>[
        <String, Object?>{
          'frequency': 'daily',
          'interval': 0,
          'end': <String, Object?>{'type': 'never'},
        },
        <String, Object?>{
          'frequency': 'daily',
          'interval': 1,
          'weekdays': <String>['TH'],
          'end': <String, Object?>{'type': 'never'},
        },
        <String, Object?>{
          'frequency': 'weekly',
          'interval': 1,
          'weekdays': <String>['TH', 'TH'],
          'end': <String, Object?>{'type': 'never'},
        },
        <String, Object?>{
          'frequency': 'monthly',
          'interval': 1,
          'monthDay': 32,
          'end': <String, Object?>{'type': 'never'},
        },
        <String, Object?>{
          'frequency': 'daily',
          'interval': 1,
          'end': <String, Object?>{'type': 'count', 'count': 0},
        },
      ]) {
        expect(ChoreRecurrenceRule.tryParse(value), isNull);
      }
    });
  });

  group('RecurringChoreDraft', () {
    test('normalizes text and produces a stable request fingerprint', () {
      final ChoreRecurrenceRule rule = ChoreRecurrenceRule.anchored(
        frequency: ChoreRecurrenceFrequency.daily,
        startLocalDate: _date(),
      );
      final RecurringChoreDraft? first = RecurringChoreDraft.tryCreate(
        householdId: _householdId(),
        title: '  Take out recycling  ',
        description: '  Blue bin  ',
        assigneeMemberId: _memberId(),
        startLocalDate: _date(),
        dueLocalTime: ChoreLocalTime.tryParse('19:30'),
        recurrenceRule: rule,
      );
      final RecurringChoreDraft? retry = RecurringChoreDraft.tryCreate(
        householdId: _householdId(),
        title: 'Take out recycling',
        description: 'Blue bin',
        assigneeMemberId: _memberId(),
        startLocalDate: _date(),
        dueLocalTime: ChoreLocalTime.tryParse('19:30:00'),
        recurrenceRule: rule,
      );
      final CreateRecurringChoreRequest request = first!.withId(_commandId());

      expect(first.title, 'Take out recycling');
      expect(first.description, 'Blue bin');
      expect(first.fingerprint, retry?.fingerprint);
      expect(request.recurrenceRule.fingerprint, rule.fingerprint);
    });

    test('rejects a rule that does not start on the first date', () {
      final ChoreRecurrenceRule rule = ChoreRecurrenceRule.tryParse(
        <String, Object?>{
          'frequency': 'weekly',
          'interval': 1,
          'weekdays': <String>['FR'],
          'end': <String, Object?>{'type': 'never'},
        },
      )!;

      expect(
        RecurringChoreDraft.tryCreate(
          householdId: _householdId(),
          title: 'Take out recycling',
          description: '',
          assigneeMemberId: _memberId(),
          startLocalDate: _date(),
          dueLocalTime: null,
          recurrenceRule: rule,
        ),
        isNull,
      );
    });
  });

  group('ChoreOccurrenceSkipDraft', () {
    test('produces a stable versioned request fingerprint', () {
      final ChoreOccurrenceSkipDraft? first =
          ChoreOccurrenceSkipDraft.tryCreate(
            householdId: _householdId(),
            occurrenceId: _occurrenceId(),
            expectedVersion: 4,
          );
      final ChoreOccurrenceSkipDraft? retry =
          ChoreOccurrenceSkipDraft.tryCreate(
            householdId: _householdId(),
            occurrenceId: _occurrenceId(),
            expectedVersion: 4,
          );
      final SkipChoreOccurrenceRequest request = first!.withId(_commandId());

      expect(first.fingerprint, retry?.fingerprint);
      expect(request.householdId, _householdId());
      expect(request.occurrenceId, _occurrenceId());
      expect(request.expectedVersion, 4);
      expect(request.idempotencyKey, _commandId());
    });

    test('rejects invalid versions and removes only the target occurrence', () {
      expect(
        ChoreOccurrenceSkipDraft.tryCreate(
          householdId: _householdId(),
          occurrenceId: _occurrenceId(),
          expectedVersion: 0,
        ),
        isNull,
      );
      final ChoreOccurrence first = _occurrence(_occurrenceId());
      final ChoreOccurrence second = _occurrence(
        ChoreOccurrenceId.tryParse('66666666-6666-4666-8666-666666666666')!,
      );
      final TodayChores today = TodayChores(
        householdId: _householdId(),
        householdTimezone: 'Asia/Seoul',
        localDate: _date(),
        occurrences: <ChoreOccurrence>[first, second],
      );

      final TodayChores removed = today.removeOccurrence(first.id);

      expect(removed.occurrences, <ChoreOccurrence>[second]);
      expect(today.occurrences, hasLength(2));
    });
  });

  group('ChoreOccurrenceRestoreDraft', () {
    test('produces a stable operation-specific request fingerprint', () {
      final ChoreOccurrenceRestoreDraft? first =
          ChoreOccurrenceRestoreDraft.tryCreate(
            householdId: _householdId(),
            occurrenceId: _occurrenceId(),
            expectedVersion: 5,
          );
      final ChoreOccurrenceRestoreDraft? retry =
          ChoreOccurrenceRestoreDraft.tryCreate(
            householdId: _householdId(),
            occurrenceId: _occurrenceId(),
            expectedVersion: 5,
          );
      final RestoreSkippedChoreOccurrenceRequest request = first!.withId(
        _commandId(),
      );
      final ChoreOccurrenceSkipDraft skip = ChoreOccurrenceSkipDraft.tryCreate(
        householdId: _householdId(),
        occurrenceId: _occurrenceId(),
        expectedVersion: 5,
      )!;

      expect(first.fingerprint, retry?.fingerprint);
      expect(first.fingerprint, isNot(skip.fingerprint));
      expect(request.householdId, _householdId());
      expect(request.occurrenceId, _occurrenceId());
      expect(request.expectedVersion, 5);
      expect(request.idempotencyKey, _commandId());
    });

    test('rejects invalid versions and reinserts at the original index', () {
      expect(
        ChoreOccurrenceRestoreDraft.tryCreate(
          householdId: _householdId(),
          occurrenceId: _occurrenceId(),
          expectedVersion: 0,
        ),
        isNull,
      );
      final ChoreOccurrence first = _occurrence(_occurrenceId());
      final ChoreOccurrence second = _occurrence(
        ChoreOccurrenceId.tryParse('66666666-6666-4666-8666-666666666666')!,
      );
      final TodayChores skipped = TodayChores(
        householdId: _householdId(),
        householdTimezone: 'Asia/Seoul',
        localDate: _date(),
        occurrences: <ChoreOccurrence>[second],
      );

      final TodayChores restored = skipped.insertOccurrenceAt(first, index: 0);
      final TodayChores deDuplicated = restored.insertOccurrenceAt(
        first.copyWith(version: 3),
        index: 99,
      );

      expect(restored.occurrences, <ChoreOccurrence>[first, second]);
      expect(deDuplicated.occurrences, hasLength(2));
      expect(deDuplicated.occurrences.last.id, first.id);
      expect(deDuplicated.occurrences.last.version, 3);
      expect(skipped.occurrences, <ChoreOccurrence>[second]);
    });
  });

  group('ChoreOccurrenceRescheduleDraft', () {
    test('binds the target schedule into a stable operation fingerprint', () {
      final ChoreOccurrenceRescheduleDraft first =
          ChoreOccurrenceRescheduleDraft.tryCreate(
            householdId: _householdId(),
            occurrenceId: _occurrenceId(),
            expectedVersion: 3,
            dueLocalDate: ChoreLocalDate.tryParse('2026-08-07')!,
            dueLocalTime: ChoreLocalTime.tryParse('18:30'),
          )!;
      final ChoreOccurrenceRescheduleDraft retry =
          ChoreOccurrenceRescheduleDraft.tryCreate(
            householdId: _householdId(),
            occurrenceId: _occurrenceId(),
            expectedVersion: 3,
            dueLocalDate: ChoreLocalDate.tryParse('2026-08-07')!,
            dueLocalTime: ChoreLocalTime.tryParse('18:30:00'),
          )!;
      final RescheduleChoreOccurrenceRequest request = first.withId(
        _commandId(),
      );

      expect(first.fingerprint, retry.fingerprint);
      expect(request.householdId, _householdId());
      expect(request.occurrenceId, _occurrenceId());
      expect(request.expectedVersion, 3);
      expect(request.dueLocalDate.value, '2026-08-07');
      expect(request.dueLocalTime?.value, '18:30');
      expect(
        first.fingerprint,
        isNot(
          ChoreOccurrenceRescheduleDraft.tryCreate(
            householdId: _householdId(),
            occurrenceId: _occurrenceId(),
            expectedVersion: 3,
            dueLocalDate: ChoreLocalDate.tryParse('2026-08-07')!,
            dueLocalTime: null,
          )?.fingerprint,
        ),
      );
      expect(
        ChoreOccurrenceRescheduleDraft.tryCreate(
          householdId: _householdId(),
          occurrenceId: _occurrenceId(),
          expectedVersion: 0,
          dueLocalDate: _date(),
          dueLocalTime: null,
        ),
        isNull,
      );
    });

    test('reorders same-day changes and removes an occurrence moved away', () {
      final ChoreOccurrence target = _occurrence(_occurrenceId()).rescheduled(
        dueLocalDate: _date(),
        dueLocalTime: ChoreLocalTime.tryParse('20:00'),
        dueAt: DateTime.parse('2026-08-06T11:00:00Z'),
      );
      final ChoreOccurrence sibling =
          _occurrence(
            ChoreOccurrenceId.tryParse('66666666-6666-4666-8666-666666666666')!,
          ).rescheduled(
            dueLocalDate: _date(),
            dueLocalTime: ChoreLocalTime.tryParse('10:00'),
            dueAt: DateTime.parse('2026-08-06T01:00:00Z'),
          );
      final TodayChores today = TodayChores(
        householdId: _householdId(),
        householdTimezone: 'Asia/Seoul',
        localDate: _date(),
        occurrences: <ChoreOccurrence>[sibling, target],
      );
      final ChoreOccurrence earlier = target.rescheduled(
        dueLocalDate: _date(),
        dueLocalTime: ChoreLocalTime.tryParse('08:00'),
        dueAt: DateTime.parse('2026-08-05T23:00:00Z'),
        version: 2,
      );

      final TodayChores reordered = today.applyReschedule(earlier);
      final TodayChores movedAway = reordered.applyReschedule(
        earlier.rescheduled(
          dueLocalDate: ChoreLocalDate.tryParse('2026-08-07')!,
          dueLocalTime: null,
          dueAt: null,
          version: 3,
        ),
      );

      expect(
        reordered.occurrences.map((ChoreOccurrence item) => item.id),
        <ChoreOccurrenceId>[target.id, sibling.id],
      );
      expect(reordered.occurrences.first.version, 2);
      expect(movedAway.occurrences, <ChoreOccurrence>[sibling]);
      expect(today.occurrences, <ChoreOccurrence>[sibling, target]);
      expect(
        () => target.rescheduled(
          dueLocalDate: _date(),
          dueLocalTime: ChoreLocalTime.tryParse('09:00'),
          dueAt: null,
        ),
        throwsArgumentError,
      );
    });
  });

  group('ChoreOccurrenceReassignmentDraft', () {
    test('binds target assignee into a stable operation fingerprint', () {
      final ChoreOccurrenceReassignmentDraft first =
          ChoreOccurrenceReassignmentDraft.tryCreate(
            householdId: _householdId(),
            occurrenceId: _occurrenceId(),
            expectedVersion: 3,
            assigneeMemberId: _otherMemberId(),
          )!;
      final ChoreOccurrenceReassignmentDraft retry =
          ChoreOccurrenceReassignmentDraft.tryCreate(
            householdId: _householdId(),
            occurrenceId: _occurrenceId(),
            expectedVersion: 3,
            assigneeMemberId: _otherMemberId(),
          )!;
      final ReassignChoreOccurrenceRequest request = first.withId(_commandId());

      expect(first.fingerprint, retry.fingerprint);
      expect(request.householdId, _householdId());
      expect(request.occurrenceId, _occurrenceId());
      expect(request.expectedVersion, 3);
      expect(request.assigneeMemberId, _otherMemberId());
      expect(
        first.fingerprint,
        isNot(
          ChoreOccurrenceReassignmentDraft.tryCreate(
            householdId: _householdId(),
            occurrenceId: _occurrenceId(),
            expectedVersion: 3,
            assigneeMemberId: _memberId(),
          )?.fingerprint,
        ),
      );
      expect(
        ChoreOccurrenceReassignmentDraft.tryCreate(
          householdId: _householdId(),
          occurrenceId: _occurrenceId(),
          expectedVersion: 0,
          assigneeMemberId: _otherMemberId(),
        ),
        isNull,
      );
    });

    test('changes only effective assignee and preserves the original', () {
      final ChoreOccurrence original = _occurrence(_occurrenceId()).rescheduled(
        dueLocalDate: _date(),
        dueLocalTime: ChoreLocalTime.tryParse('19:30'),
        dueAt: DateTime.parse('2026-08-06T10:30:00Z'),
      );

      final ChoreOccurrence reassigned = original.reassigned(
        assigneeMemberId: _otherMemberId(),
        assigneeDisplayName: 'Sam',
        version: 2,
      );

      expect(reassigned.assigneeMemberId, _otherMemberId());
      expect(reassigned.assigneeDisplayName, 'Sam');
      expect(reassigned.version, 2);
      expect(reassigned.seriesId, original.seriesId);
      expect(reassigned.dueLocalDate, original.dueLocalDate);
      expect(reassigned.dueLocalTime, original.dueLocalTime);
      expect(reassigned.dueAt, original.dueAt);
      expect(reassigned.status, original.status);
      expect(original.assigneeMemberId, _memberId());
      expect(original.version, 1);
      expect(
        () => original.reassigned(
          assigneeMemberId: _otherMemberId(),
          assigneeDisplayName: ' Sam ',
        ),
        throwsArgumentError,
      );
    });
  });

  group('RepeatingChoreSeriesChangeDrafts', () {
    test('normalizes and binds every whole-series update field', () {
      final ChoreRecurrenceRule rule = ChoreRecurrenceRule.anchored(
        frequency: ChoreRecurrenceFrequency.weekly,
        startLocalDate: _date(),
      );
      final RepeatingChoreSeriesUpdateDraft draft =
          RepeatingChoreSeriesUpdateDraft.tryCreate(
            householdId: _householdId(),
            seriesId: _occurrence(_occurrenceId()).seriesId,
            expectedVersion: 3,
            effectiveLocalDate: _date(),
            title: '  Weekly recycling  ',
            description: '  Blue bin  ',
            assigneeMemberId: _otherMemberId(),
            dueLocalTime: ChoreLocalTime.tryParse('20:00'),
            recurrenceRule: rule,
          )!;
      final UpdateRepeatingChoreSeriesRequest request = draft.withId(
        _commandId(),
      );

      expect(draft.title, 'Weekly recycling');
      expect(draft.description, 'Blue bin');
      expect(request.expectedVersion, 3);
      expect(request.effectiveLocalDate, _date());
      expect(request.assigneeMemberId, _otherMemberId());
      expect(request.dueLocalTime?.value, '20:00');
      expect(request.recurrenceRule.fingerprint, rule.fingerprint);
      expect(
        draft.fingerprint,
        isNot(
          RepeatingChoreSeriesUpdateDraft.tryCreate(
            householdId: _householdId(),
            seriesId: _occurrence(_occurrenceId()).seriesId,
            expectedVersion: 4,
            effectiveLocalDate: _date(),
            title: 'Weekly recycling',
            description: 'Blue bin',
            assigneeMemberId: _otherMemberId(),
            dueLocalTime: ChoreLocalTime.tryParse('20:00'),
            recurrenceRule: rule,
          )?.fingerprint,
        ),
      );
    });

    test('rejects invalid versions, content, and expired recurrence', () {
      final ChoreSeriesId seriesId = _occurrence(_occurrenceId()).seriesId;
      final ChoreRecurrenceRule validRule = ChoreRecurrenceRule.anchored(
        frequency: ChoreRecurrenceFrequency.daily,
        startLocalDate: _date(),
      );
      final ChoreRecurrenceRule expiredRule = ChoreRecurrenceRule.tryParse(
        <String, Object?>{
          'frequency': 'daily',
          'interval': 1,
          'end': <String, Object?>{'type': 'until', 'localDate': '2026-08-05'},
        },
      )!;

      for (final RepeatingChoreSeriesUpdateDraft? draft
          in <RepeatingChoreSeriesUpdateDraft?>[
            RepeatingChoreSeriesUpdateDraft.tryCreate(
              householdId: _householdId(),
              seriesId: seriesId,
              expectedVersion: 0,
              effectiveLocalDate: _date(),
              title: 'Daily recycling',
              description: '',
              assigneeMemberId: _memberId(),
              dueLocalTime: null,
              recurrenceRule: validRule,
            ),
            RepeatingChoreSeriesUpdateDraft.tryCreate(
              householdId: _householdId(),
              seriesId: seriesId,
              expectedVersion: 1,
              effectiveLocalDate: _date(),
              title: '   ',
              description: '',
              assigneeMemberId: _memberId(),
              dueLocalTime: null,
              recurrenceRule: validRule,
            ),
            RepeatingChoreSeriesUpdateDraft.tryCreate(
              householdId: _householdId(),
              seriesId: seriesId,
              expectedVersion: 1,
              effectiveLocalDate: _date(),
              title: 'Daily recycling',
              description: '',
              assigneeMemberId: _memberId(),
              dueLocalTime: null,
              recurrenceRule: expiredRule,
            ),
          ]) {
        expect(draft, isNull);
      }
      expect(
        RepeatingChoreSeriesCancellationDraft.tryCreate(
          householdId: _householdId(),
          seriesId: seriesId,
          expectedVersion: 0,
        ),
        isNull,
      );
      final RepeatingChoreSeriesCancellationDraft cancellation =
          RepeatingChoreSeriesCancellationDraft.tryCreate(
            householdId: _householdId(),
            seriesId: seriesId,
            expectedVersion: 3,
          )!;
      expect(cancellation.withId(_commandId()).expectedVersion, 3);
      expect(cancellation.fingerprint, contains('cancelRepeatingChoreSeries'));
    });

    test('binds the selected occurrence without trusting a boundary date', () {
      final ChoreOccurrenceId targetId = _occurrenceId();
      final ChoreLocalDate minimumDate = ChoreLocalDate.tryParse('2026-08-12')!;
      final ChoreRecurrenceRule rule = ChoreRecurrenceRule.anchored(
        frequency: ChoreRecurrenceFrequency.weekly,
        startLocalDate: minimumDate,
      );
      final RepeatingChoreSeriesFromOccurrenceUpdateDraft draft =
          RepeatingChoreSeriesFromOccurrenceUpdateDraft.tryCreate(
            householdId: _householdId(),
            seriesId: _occurrence(targetId).seriesId,
            effectiveOccurrenceId: targetId,
            expectedVersion: 3,
            minimumLocalDate: minimumDate,
            title: '  Recycling from here  ',
            description: '  Blue bin  ',
            assigneeMemberId: _otherMemberId(),
            dueLocalTime: ChoreLocalTime.tryParse('20:00'),
            recurrenceRule: rule,
          )!;
      final UpdateRepeatingChoreSeriesFromOccurrenceRequest request = draft
          .withId(_commandId());

      expect(draft.title, 'Recycling from here');
      expect(draft.description, 'Blue bin');
      expect(request.effectiveOccurrenceId, targetId);
      expect(request.expectedVersion, 3);
      expect(draft.fingerprint, contains(targetId.value));
      expect(draft.fingerprint, isNot(contains('effectiveLocalDate')));
    });

    test('rejects an expired selected-occurrence recurrence locally', () {
      final ChoreLocalDate minimumDate = ChoreLocalDate.tryParse('2026-08-12')!;
      final ChoreRecurrenceRule expiredRule = ChoreRecurrenceRule.tryParse(
        <String, Object?>{
          'frequency': 'daily',
          'interval': 1,
          'end': <String, Object?>{'type': 'until', 'localDate': '2026-08-11'},
        },
      )!;

      expect(
        RepeatingChoreSeriesFromOccurrenceUpdateDraft.tryCreate(
          householdId: _householdId(),
          seriesId: _occurrence(_occurrenceId()).seriesId,
          effectiveOccurrenceId: _occurrenceId(),
          expectedVersion: 1,
          minimumLocalDate: minimumDate,
          title: 'Recycling',
          description: '',
          assigneeMemberId: _memberId(),
          dueLocalTime: null,
          recurrenceRule: expiredRule,
        ),
        isNull,
      );
    });

    test('binds selected-occurrence cancellation to the immutable target', () {
      final ChoreOccurrenceId targetId = _occurrenceId();
      final RepeatingChoreSeriesFromOccurrenceCancellationDraft draft =
          RepeatingChoreSeriesFromOccurrenceCancellationDraft.tryCreate(
            householdId: _householdId(),
            seriesId: _occurrence(targetId).seriesId,
            effectiveOccurrenceId: targetId,
            expectedVersion: 3,
          )!;
      final CancelRepeatingChoreSeriesFromOccurrenceRequest request = draft
          .withId(_commandId());

      expect(request.effectiveOccurrenceId, targetId);
      expect(request.expectedVersion, 3);
      expect(
        draft.fingerprint,
        contains('cancelRepeatingChoreSeriesFromOccurrence'),
      );
      expect(draft.fingerprint, contains(targetId.value));
      expect(draft.fingerprint, isNot(contains('effectiveLocalDate')));
      expect(
        RepeatingChoreSeriesFromOccurrenceCancellationDraft.tryCreate(
          householdId: _householdId(),
          seriesId: request.seriesId,
          effectiveOccurrenceId: targetId,
          expectedVersion: 0,
        ),
        isNull,
      );
    });

    test('binds cancellation resume to the exact cancellation command', () {
      final ChoreCommandId cancellationId = ChoreCommandId.tryParse(
        'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      )!;
      final ResumeRepeatingChoreSeriesCancellationDraft draft =
          ResumeRepeatingChoreSeriesCancellationDraft.tryCreate(
            householdId: _householdId(),
            seriesId: _occurrence(_occurrenceId()).seriesId,
            cancellationIdempotencyKey: cancellationId,
            expectedVersion: 4,
          )!;
      final ResumeRepeatingChoreSeriesCancellationRequest request = draft
          .withId(_commandId());

      expect(request.cancellationIdempotencyKey, cancellationId);
      expect(request.expectedVersion, 4);
      expect(
        draft.fingerprint,
        contains('resumeRepeatingChoreSeriesCancellation'),
      );
      expect(draft.fingerprint, contains(cancellationId.value));
      expect(
        ResumeRepeatingChoreSeriesCancellationDraft.tryCreate(
          householdId: request.householdId,
          seriesId: request.seriesId,
          cancellationIdempotencyKey: cancellationId,
          expectedVersion: 0,
        ),
        isNull,
      );
    });
  });

  group('ChoreOccurrenceHistory', () {
    test('parses only source-qualified immutable history IDs', () {
      final ChoreHistoryEntryId id = ChoreHistoryEntryId.tryParse(
        'COMPLETION:61000000-0000-4000-8000-000000000701',
      )!;

      expect(id.value, 'completion:61000000-0000-4000-8000-000000000701');
      expect(id.source, 'completion');
      expect(ChoreHistoryEntryId.tryParse('completion:not-a-uuid'), isNull);
      expect(
        ChoreHistoryEntryId.tryParse(
          'unknown:61000000-0000-4000-8000-000000000701',
        ),
        isNull,
      );
    });

    test('accepts status, schedule, and assignment event shapes', () {
      final ChoreOccurrenceHistoryEvent completed = _historyEvent(
        type: ChoreOccurrenceHistoryEventType.completed,
        source: 'completion',
        suffix: '701',
        occurredAt: DateTime.parse('2026-08-07T03:00:00Z'),
      );
      final ChoreOccurrenceHistoryEvent rescheduled = _historyEvent(
        type: ChoreOccurrenceHistoryEventType.rescheduled,
        source: 'reschedule',
        suffix: '702',
        occurredAt: DateTime.parse('2026-08-07T02:00:00Z'),
        previousDueLocalDate: _date(),
        previousDueLocalTime: ChoreLocalTime.tryParse('09:00'),
        newDueLocalDate: ChoreLocalDate.tryParse('2026-08-07'),
        newDueLocalTime: ChoreLocalTime.tryParse('18:30'),
      );
      final ChoreOccurrenceHistoryEvent reassigned = _historyEvent(
        type: ChoreOccurrenceHistoryEventType.reassigned,
        source: 'assignment',
        suffix: '703',
        occurredAt: DateTime.parse('2026-08-07T01:00:00Z'),
        previousAssigneeMemberId: _memberId(),
        previousAssigneeDisplayName: 'Alex',
        newAssigneeMemberId: _otherMemberId(),
        newAssigneeDisplayName: 'Sam',
      );

      expect(completed.actorDisplayName, 'Alex');
      expect(rescheduled.newDueLocalTime?.value, '18:30');
      expect(reassigned.newAssigneeDisplayName, 'Sam');
    });

    test('rejects source, UTC, display-name, and variant shape mismatches', () {
      expect(
        ChoreOccurrenceHistoryEvent.tryCreate(
          id: ChoreHistoryEntryId.tryParse(
            'assignment:61000000-0000-4000-8000-000000000701',
          )!,
          type: ChoreOccurrenceHistoryEventType.completed,
          actorMemberId: _memberId(),
          actorDisplayName: 'Alex',
          actingMemberId: null,
          actingDisplayName: null,
          occurredAt: DateTime(2026, 8, 7),
          occurrenceVersion: 1,
          previousDueLocalDate: null,
          previousDueLocalTime: null,
          newDueLocalDate: null,
          newDueLocalTime: null,
          previousAssigneeMemberId: null,
          previousAssigneeDisplayName: null,
          newAssigneeMemberId: null,
          newAssigneeDisplayName: null,
        ),
        isNull,
      );
      expect(
        ChoreOccurrenceHistoryEvent.tryCreate(
          id: ChoreHistoryEntryId.tryParse(
            'reschedule:61000000-0000-4000-8000-000000000702',
          )!,
          type: ChoreOccurrenceHistoryEventType.rescheduled,
          actorMemberId: _memberId(),
          actorDisplayName: ' Alex ',
          actingMemberId: _otherMemberId(),
          actingDisplayName: null,
          occurredAt: DateTime.parse('2026-08-07T01:00:00Z'),
          occurrenceVersion: 0,
          previousDueLocalDate: _date(),
          previousDueLocalTime: null,
          newDueLocalDate: _date(),
          newDueLocalTime: null,
          previousAssigneeMemberId: null,
          previousAssigneeDisplayName: null,
          newAssigneeMemberId: null,
          newAssigneeDisplayName: null,
        ),
        isNull,
      );
    });

    test('requires unique descending pages and a non-empty continuation', () {
      final ChoreOccurrenceHistoryEvent newer = _historyEvent(
        type: ChoreOccurrenceHistoryEventType.completed,
        source: 'completion',
        suffix: '701',
        occurredAt: DateTime.parse('2026-08-07T02:00:00Z'),
      );
      final ChoreOccurrenceHistoryEvent older = _historyEvent(
        type: ChoreOccurrenceHistoryEventType.reopened,
        source: 'completion',
        suffix: '702',
        occurredAt: DateTime.parse('2026-08-07T01:00:00Z'),
      );

      final ChoreOccurrenceHistoryPage page =
          ChoreOccurrenceHistoryPage.tryCreate(
            householdId: _householdId(),
            occurrenceId: _occurrenceId(),
            events: <ChoreOccurrenceHistoryEvent>[newer, older],
            hasMore: true,
          )!;

      expect(page.nextCursor?.entryId, older.id);
      expect(
        ChoreOccurrenceHistoryPage.tryCreate(
          householdId: _householdId(),
          occurrenceId: _occurrenceId(),
          events: <ChoreOccurrenceHistoryEvent>[older, newer],
          hasMore: false,
        ),
        isNull,
      );
      expect(
        ChoreOccurrenceHistoryPage.tryCreate(
          householdId: _householdId(),
          occurrenceId: _occurrenceId(),
          events: <ChoreOccurrenceHistoryEvent>[newer, newer],
          hasMore: false,
        ),
        isNull,
      );
      expect(
        ChoreOccurrenceHistoryPage.tryCreate(
          householdId: _householdId(),
          occurrenceId: _occurrenceId(),
          events: const <ChoreOccurrenceHistoryEvent>[],
          hasMore: true,
        ),
        isNull,
      );
    });

    test('bounds requests and accepts only UTC cursors', () {
      final ChoreHistoryEntryId entryId = ChoreHistoryEntryId.tryParse(
        'completion:61000000-0000-4000-8000-000000000701',
      )!;
      final ChoreOccurrenceHistoryCursor cursor =
          ChoreOccurrenceHistoryCursor.tryCreate(
            occurredAt: DateTime.parse('2026-08-07T01:00:00Z'),
            entryId: entryId,
          )!;

      expect(
        ChoreOccurrenceHistoryRequest.tryCreate(
          householdId: _householdId(),
          occurrenceId: _occurrenceId(),
          cursor: cursor,
        )?.cursor,
        same(cursor),
      );
      expect(
        ChoreOccurrenceHistoryCursor.tryCreate(
          occurredAt: DateTime(2026, 8, 7),
          entryId: entryId,
        ),
        isNull,
      );
      expect(
        ChoreOccurrenceHistoryRequest.tryCreate(
          householdId: _householdId(),
          occurrenceId: _occurrenceId(),
          limit: 0,
        ),
        isNull,
      );
      expect(
        ChoreOccurrenceHistoryRequest.tryCreate(
          householdId: _householdId(),
          occurrenceId: _occurrenceId(),
          limit: 101,
        ),
        isNull,
      );
    });
  });
}

HouseholdId _householdId() {
  return HouseholdId.tryParse('22222222-2222-4222-8222-222222222222')!;
}

HouseholdMemberId _memberId() {
  return HouseholdMemberId.tryParse('33333333-3333-4333-8333-333333333333')!;
}

HouseholdMemberId _otherMemberId() {
  return HouseholdMemberId.tryParse('33333333-3333-4333-8333-333333333334')!;
}

ChoreOccurrenceId _occurrenceId() {
  return ChoreOccurrenceId.tryParse('55555555-5555-4555-8555-555555555555')!;
}

ChoreCommandId _commandId() {
  return ChoreCommandId.tryParse('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')!;
}

ChoreSeriesId _seriesId() {
  return ChoreSeriesId.tryParse('44444444-4444-4444-8444-444444444444')!;
}

OneTimeChoreUpdateDraft? _oneTimeUpdateDraft({
  int expectedSeriesVersion = 1,
  int expectedOccurrenceVersion = 1,
  String title = 'Updated recycling',
  String description = 'Use the blue bin',
}) {
  return OneTimeChoreUpdateDraft.tryCreate(
    householdId: _householdId(),
    seriesId: _seriesId(),
    occurrenceId: _occurrenceId(),
    expectedSeriesVersion: expectedSeriesVersion,
    expectedOccurrenceVersion: expectedOccurrenceVersion,
    title: title,
    description: description,
    assigneeMemberId: _otherMemberId(),
    dueLocalDate: ChoreLocalDate.tryParse('2026-08-07')!,
    dueLocalTime: ChoreLocalTime.tryParse('18:30'),
  );
}

ChoreLocalDate _date() {
  return ChoreLocalDate.tryParse('2026-08-06')!;
}

ChoreOccurrence _occurrence(ChoreOccurrenceId id) {
  return ChoreOccurrence(
    id: id,
    seriesId: ChoreSeriesId.tryParse('44444444-4444-4444-8444-444444444444')!,
    title: 'Take out recycling',
    assigneeMemberId: _memberId(),
    assigneeDisplayName: 'Alex',
    dueLocalDate: _date(),
    status: ChoreOccurrenceStatus.scheduled,
    version: 1,
  );
}

ChoreOccurrenceHistoryEvent _historyEvent({
  required ChoreOccurrenceHistoryEventType type,
  required String source,
  required String suffix,
  required DateTime occurredAt,
  ChoreLocalDate? previousDueLocalDate,
  ChoreLocalTime? previousDueLocalTime,
  ChoreLocalDate? newDueLocalDate,
  ChoreLocalTime? newDueLocalTime,
  HouseholdMemberId? previousAssigneeMemberId,
  String? previousAssigneeDisplayName,
  HouseholdMemberId? newAssigneeMemberId,
  String? newAssigneeDisplayName,
}) {
  return ChoreOccurrenceHistoryEvent.tryCreate(
    id: ChoreHistoryEntryId.tryParse(
      '$source:61000000-0000-4000-8000-000000000$suffix',
    )!,
    type: type,
    actorMemberId: _memberId(),
    actorDisplayName: 'Alex',
    actingMemberId: null,
    actingDisplayName: null,
    occurredAt: occurredAt,
    occurrenceVersion: 1,
    previousDueLocalDate: previousDueLocalDate,
    previousDueLocalTime: previousDueLocalTime,
    newDueLocalDate: newDueLocalDate,
    newDueLocalTime: newDueLocalTime,
    previousAssigneeMemberId: previousAssigneeMemberId,
    previousAssigneeDisplayName: previousAssigneeDisplayName,
    newAssigneeMemberId: newAssigneeMemberId,
    newAssigneeDisplayName: newAssigneeDisplayName,
  )!;
}
