import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_template.dart';
import 'package:kinflow_app/features/chores/domain/entities/guided_chore_setup.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';

import '../../support/fakes/fake_household_dependencies.dart';

void main() {
  final ChoreLocalDate startLocalDate = ChoreLocalDate.tryParse('2026-08-06')!;

  test('normalizes exact three unique entries into catalog order', () {
    final GuidedChoreSetupDraft draft = GuidedChoreSetupDraft.tryCreate(
      householdId: activeHouseholdFixture().householdId,
      assigneeMemberId: activeHouseholdFixture().memberId,
      startLocalDate: startLocalDate,
      inputs: const <GuidedChoreSetupInput>[
        GuidedChoreSetupInput(
          template: ChoreTemplatePreset.laundry,
          title: '  Laundry  ',
          frequency: ChoreRecurrenceFrequency.weekly,
        ),
        GuidedChoreSetupInput(
          template: ChoreTemplatePreset.dishes,
          title: '  Dishes  ',
          frequency: ChoreRecurrenceFrequency.daily,
        ),
        GuidedChoreSetupInput(
          template: ChoreTemplatePreset.kitchenReset,
          title: 'Kitchen reset',
          frequency: ChoreRecurrenceFrequency.daily,
        ),
      ],
    )!;

    expect(
      draft.entries.map((GuidedChoreSetupEntry entry) => entry.template),
      <ChoreTemplatePreset>[
        ChoreTemplatePreset.dishes,
        ChoreTemplatePreset.kitchenReset,
        ChoreTemplatePreset.laundry,
      ],
    );
    expect(draft.entries.first.draft.title, 'Dishes');
    expect(draft.entries.first.draft.description, isNull);
    expect(draft.entries.first.draft.dueLocalTime, isNull);
    expect(
      draft.entries.first.draft.assigneeMemberId,
      activeHouseholdFixture().memberId,
    );
    expect(
      draft.entries.last.draft.recurrenceRule.weekdays.single.wireValue,
      'TH',
    );
    expect(
      () => draft.entries.add(draft.entries.first),
      throwsUnsupportedError,
    );
  });

  test('fingerprint is stable when input selection order changes', () {
    final List<GuidedChoreSetupInput> inputs = _validInputs();
    final GuidedChoreSetupDraft first = _draft(startLocalDate, inputs)!;
    final GuidedChoreSetupDraft second = _draft(
      startLocalDate,
      inputs.reversed.toList(),
    )!;

    expect(first.fingerprint, second.fingerprint);
  });

  test('rejects wrong count, duplicate templates, or invalid title', () {
    expect(_draft(startLocalDate, _validInputs().take(2).toList()), isNull);
    expect(
      _draft(startLocalDate, <GuidedChoreSetupInput>[
        _validInputs().first,
        _validInputs().first,
        _validInputs().last,
      ]),
      isNull,
    );
    expect(
      _draft(startLocalDate, <GuidedChoreSetupInput>[
        const GuidedChoreSetupInput(
          template: ChoreTemplatePreset.dishes,
          title: '',
          frequency: ChoreRecurrenceFrequency.daily,
        ),
        ..._validInputs().skip(1),
      ]),
      isNull,
    );
  });

  test('preserves the exact supported advanced recurrence rules', () {
    final ChoreRecurrenceRule daily = ChoreRecurrenceRule.tryAnchored(
      frequency: ChoreRecurrenceFrequency.daily,
      startLocalDate: startLocalDate,
      interval: 3,
      end: const ChoreRecurrenceCountEnd(12),
    )!;
    final ChoreRecurrenceRule weekly =
        ChoreRecurrenceRule.tryAnchored(
          frequency: ChoreRecurrenceFrequency.weekly,
          startLocalDate: startLocalDate,
          interval: 2,
          end: ChoreRecurrenceUntilEnd(ChoreLocalDate.tryParse('2026-12-31')!),
        )!.tryWithWeeklyWeekdays(
          weekdays: const <ChoreWeekday>[
            ChoreWeekday.monday,
            ChoreWeekday.thursday,
          ],
          interval: 2,
          end: ChoreRecurrenceUntilEnd(ChoreLocalDate.tryParse('2026-12-31')!),
          minimumLocalDate: startLocalDate,
          requiredStartLocalDate: startLocalDate,
        )!;
    final ChoreRecurrenceRule monthly = ChoreRecurrenceRule.tryAnchored(
      frequency: ChoreRecurrenceFrequency.monthly,
      startLocalDate: startLocalDate,
      interval: 4,
      end: const ChoreRecurrenceNeverEnds(),
    )!;

    final GuidedChoreSetupDraft draft =
        _draft(startLocalDate, <GuidedChoreSetupInput>[
          GuidedChoreSetupInput.withRecurrence(
            template: ChoreTemplatePreset.dishes,
            title: 'Dishes',
            recurrenceRule: daily,
          ),
          GuidedChoreSetupInput.withRecurrence(
            template: ChoreTemplatePreset.kitchenReset,
            title: 'Kitchen reset',
            recurrenceRule: weekly,
          ),
          GuidedChoreSetupInput.withRecurrence(
            template: ChoreTemplatePreset.laundry,
            title: 'Laundry',
            recurrenceRule: monthly,
          ),
        ])!;

    expect(
      draft.entries.map(
        (GuidedChoreSetupEntry entry) => entry.draft.recurrenceRule.fingerprint,
      ),
      <String>[daily.fingerprint, weekly.fingerprint, monthly.fingerprint],
    );
  });

  test(
    'rejects weekly and monthly rules that do not include the start date',
    () {
      final ChoreRecurrenceRule wrongWeekly =
          ChoreRecurrenceRule.tryAnchored(
            frequency: ChoreRecurrenceFrequency.weekly,
            startLocalDate: startLocalDate,
            interval: 1,
            end: const ChoreRecurrenceNeverEnds(),
          )!.tryWithWeeklyWeekdays(
            weekdays: const <ChoreWeekday>[ChoreWeekday.monday],
            interval: 1,
            end: const ChoreRecurrenceNeverEnds(),
            minimumLocalDate: startLocalDate,
          )!;
      final ChoreRecurrenceRule wrongMonthly =
          ChoreRecurrenceRule.tryAnchored(
            frequency: ChoreRecurrenceFrequency.monthly,
            startLocalDate: startLocalDate,
            interval: 1,
            end: const ChoreRecurrenceNeverEnds(),
          )!.tryWithMonthlyDay(
            monthDay: 7,
            interval: 1,
            end: const ChoreRecurrenceNeverEnds(),
            minimumLocalDate: startLocalDate,
          )!;

      for (final ChoreRecurrenceRule invalid in <ChoreRecurrenceRule>[
        wrongWeekly,
        wrongMonthly,
      ]) {
        expect(
          _draft(startLocalDate, <GuidedChoreSetupInput>[
            GuidedChoreSetupInput.withRecurrence(
              template: ChoreTemplatePreset.dishes,
              title: 'Dishes',
              recurrenceRule: invalid,
            ),
            ..._validInputs().skip(1),
          ]),
          isNull,
        );
      }
    },
  );

  test('resume plan normalizes immutable inputs and preserves checkpoint', () {
    final GuidedChoreSetupResumePlan plan =
        GuidedChoreSetupResumePlan.tryCreate(
          householdId: activeHouseholdFixture().householdId,
          assigneeMemberId: activeHouseholdFixture().memberId,
          startLocalDate: startLocalDate,
          householdTimezone: 'Asia/Seoul',
          inputs: _validInputs().reversed.toList(),
          commandIds: _commandIds(),
          completedCount: 1,
        )!;

    expect(
      plan.inputs.map((GuidedChoreSetupInput input) => input.template),
      <ChoreTemplatePreset>[
        ChoreTemplatePreset.dishes,
        ChoreTemplatePreset.kitchenReset,
        ChoreTemplatePreset.laundry,
      ],
    );
    expect(plan.completedCount, 1);
    expect(
      plan.inputs.every(
        (GuidedChoreSetupInput input) => input.recurrenceRule != null,
      ),
      isTrue,
    );
    expect(plan.withCompletedCount(2)!.completedCount, 2);
    expect(plan.withCompletedCount(4), isNull);
    expect(() => plan.inputs.add(plan.inputs.first), throwsUnsupportedError);
    expect(
      () => plan.commandIds.add(plan.commandIds.first),
      throwsUnsupportedError,
    );
  });

  test('resume plan rejects duplicate IDs and noncanonical timezone', () {
    final List<ChoreCommandId> duplicateIds = _commandIds();
    duplicateIds[2] = duplicateIds.first;
    expect(
      GuidedChoreSetupResumePlan.tryCreate(
        householdId: activeHouseholdFixture().householdId,
        assigneeMemberId: activeHouseholdFixture().memberId,
        startLocalDate: startLocalDate,
        householdTimezone: 'Asia/Seoul',
        inputs: _validInputs(),
        commandIds: duplicateIds,
        completedCount: 0,
      ),
      isNull,
    );
    expect(
      GuidedChoreSetupResumePlan.tryCreate(
        householdId: activeHouseholdFixture().householdId,
        assigneeMemberId: activeHouseholdFixture().memberId,
        startLocalDate: startLocalDate,
        householdTimezone: ' Asia/Seoul ',
        inputs: _validInputs(),
        commandIds: _commandIds(),
        completedCount: 0,
      ),
      isNull,
    );
  });
}

GuidedChoreSetupDraft? _draft(
  ChoreLocalDate startLocalDate,
  List<GuidedChoreSetupInput> inputs,
) {
  return GuidedChoreSetupDraft.tryCreate(
    householdId: activeHouseholdFixture().householdId,
    assigneeMemberId: activeHouseholdFixture().memberId,
    startLocalDate: startLocalDate,
    inputs: inputs,
  );
}

List<GuidedChoreSetupInput> _validInputs() {
  return const <GuidedChoreSetupInput>[
    GuidedChoreSetupInput(
      template: ChoreTemplatePreset.dishes,
      title: 'Dishes',
      frequency: ChoreRecurrenceFrequency.daily,
    ),
    GuidedChoreSetupInput(
      template: ChoreTemplatePreset.kitchenReset,
      title: 'Kitchen reset',
      frequency: ChoreRecurrenceFrequency.daily,
    ),
    GuidedChoreSetupInput(
      template: ChoreTemplatePreset.laundry,
      title: 'Laundry',
      frequency: ChoreRecurrenceFrequency.weekly,
    ),
  ];
}

List<ChoreCommandId> _commandIds() {
  return <String>[
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  ].map((String value) => ChoreCommandId.tryParse(value)!).toList();
}
