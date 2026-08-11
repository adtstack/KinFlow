import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/data/services/secure_guided_chore_setup_resume_store.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_template.dart';
import 'package:kinflow_app/features/chores/domain/entities/guided_chore_setup.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/infrastructure/secure_storage/secure_string_store.dart';

import '../../support/fakes/fake_household_dependencies.dart';

void main() {
  test('strict secure record round trips in canonical catalog order', () async {
    final _MemorySecureStringStore memory = _MemorySecureStringStore();
    final SecureGuidedChoreSetupResumeStore store =
        SecureGuidedChoreSetupResumeStore(memory);
    final GuidedChoreSetupResumePlan plan = _plan(completedCount: 1);

    expect(await store.write(plan), isTrue);
    final GuidedChoreSetupResumePlan? restored = await store.read(
      expectedHouseholdId: plan.householdId,
      expectedAssigneeMemberId: plan.assigneeMemberId,
    );

    expect(restored, isNotNull);
    expect(restored!.completedCount, 1);
    expect(
      restored.inputs.map((GuidedChoreSetupInput input) => input.template),
      <ChoreTemplatePreset>[
        ChoreTemplatePreset.wipeCounters,
        ChoreTemplatePreset.changeBedLinen,
        ChoreTemplatePreset.cleanPetArea,
      ],
    );
    expect(restored.commandIds, plan.commandIds);
    expect(
      restored.inputs
          .map(
            (GuidedChoreSetupInput input) => input.recurrenceRule!.fingerprint,
          )
          .toList(),
      plan.inputs
          .map(
            (GuidedChoreSetupInput input) => input.recurrenceRule!.fingerprint,
          )
          .toList(),
    );
    expect(memory.initializeCount, 1);
  });

  test('invalid, noncanonical, or unknown records are purged', () async {
    final _MemorySecureStringStore memory = _MemorySecureStringStore();
    final SecureGuidedChoreSetupResumeStore store =
        SecureGuidedChoreSetupResumeStore(memory);
    final GuidedChoreSetupResumePlan plan = _plan();
    expect(await store.write(plan), isTrue);
    final String valid =
        memory.values[SecureGuidedChoreSetupResumeStore.storageKey]!;

    final List<(String, Object?)> cases = <(String, Object?)>[
      ('not JSON', '{'),
      ('unknown version', _mutate(valid, 'contractVersion', 3)),
      ('wrong completed type', _mutate(valid, 'completedCount', true)),
      (
        'noncanonical household',
        _mutate(valid, 'householdId', '${plan.householdId.value} '),
      ),
      ('unknown top-level key', _withUnknownKey(valid)),
      ('out-of-order entries', _reverseEntries(valid)),
      ('nonnormalized title', _padFirstTitle(valid)),
      ('widened recurrence', _widenFirstRecurrence(valid)),
      ('noncanonical weekdays', _reverseWeeklyWeekdays(valid)),
    ];
    for (final (String label, Object? raw) in cases) {
      memory.values[SecureGuidedChoreSetupResumeStore.storageKey] =
          raw is String ? raw : jsonEncode(raw);
      expect(
        await store.read(
          expectedHouseholdId: plan.householdId,
          expectedAssigneeMemberId: plan.assigneeMemberId,
        ),
        isNull,
        reason: label,
      );
      expect(
        memory.values.containsKey(SecureGuidedChoreSetupResumeStore.storageKey),
        isFalse,
        reason: label,
      );
    }
  });

  test('scope mismatch and oversized payload are purged', () async {
    final _MemorySecureStringStore memory = _MemorySecureStringStore();
    final SecureGuidedChoreSetupResumeStore store =
        SecureGuidedChoreSetupResumeStore(memory);
    final GuidedChoreSetupResumePlan plan = _plan();
    expect(await store.write(plan), isTrue);

    expect(
      await store.read(
        expectedHouseholdId: HouseholdId.tryParse(
          '99999999-9999-4999-8999-999999999999',
        )!,
        expectedAssigneeMemberId: plan.assigneeMemberId,
      ),
      isNull,
    );
    expect(memory.deleteCount, 2);

    memory.values[SecureGuidedChoreSetupResumeStore.storageKey] =
        'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
    final SecureGuidedChoreSetupResumeStore tinyStore =
        SecureGuidedChoreSetupResumeStore(memory, maxEncodedBytes: 16);
    expect(
      await tinyStore.read(
        expectedHouseholdId: plan.householdId,
        expectedAssigneeMemberId: plan.assigneeMemberId,
      ),
      isNull,
    );
    expect(memory.deleteCount, 4);
  });

  test('legacy v1 record is never resumed and is removed', () async {
    final _MemorySecureStringStore memory = _MemorySecureStringStore();
    memory.values[SecureGuidedChoreSetupResumeStore.legacyStorageKey] =
        '{"contractVersion":1}';
    final SecureGuidedChoreSetupResumeStore store =
        SecureGuidedChoreSetupResumeStore(memory);
    final GuidedChoreSetupResumePlan plan = _plan();

    expect(
      await store.read(
        expectedHouseholdId: plan.householdId,
        expectedAssigneeMemberId: plan.assigneeMemberId,
      ),
      isNull,
    );
    expect(
      memory.values.containsKey(
        SecureGuidedChoreSetupResumeStore.legacyStorageKey,
      ),
      isFalse,
    );
    expect(memory.deleteCount, 1);
  });

  test('failed checkpoint write preserves the last durable plan', () async {
    final _MemorySecureStringStore memory = _MemorySecureStringStore();
    final SecureGuidedChoreSetupResumeStore store =
        SecureGuidedChoreSetupResumeStore(memory);
    final GuidedChoreSetupResumePlan initial = _plan();
    expect(await store.write(initial), isTrue);

    memory.failNextWrite = true;
    expect(await store.write(initial.withCompletedCount(1)!), isFalse);
    final GuidedChoreSetupResumePlan? restored = await store.read(
      expectedHouseholdId: initial.householdId,
      expectedAssigneeMemberId: initial.assigneeMemberId,
    );
    expect(restored!.completedCount, 0);

    await store.purgeSensitiveLocalState();
    expect(memory.deleteAllCount, 1);
    expect(memory.values, isEmpty);
  });

  test('storage exceptions stay typed as null or false', () async {
    final _MemorySecureStringStore memory = _MemorySecureStringStore(
      failInitialization: true,
    );
    final SecureGuidedChoreSetupResumeStore store =
        SecureGuidedChoreSetupResumeStore(memory);
    final GuidedChoreSetupResumePlan plan = _plan();

    expect(await store.write(plan), isFalse);
    expect(
      await store.read(
        expectedHouseholdId: plan.householdId,
        expectedAssigneeMemberId: plan.assigneeMemberId,
      ),
      isNull,
    );
    expect(await store.clear(), isFalse);
  });
}

GuidedChoreSetupResumePlan _plan({int completedCount = 0}) {
  final ChoreLocalDate startLocalDate = ChoreLocalDate.tryParse('2026-08-06')!;
  final ChoreRecurrenceRule weekly =
      ChoreRecurrenceRule.tryAnchored(
        frequency: ChoreRecurrenceFrequency.weekly,
        startLocalDate: startLocalDate,
        interval: 2,
        end: const ChoreRecurrenceCountEnd(8),
      )!.tryWithWeeklyWeekdays(
        weekdays: const <ChoreWeekday>[
          ChoreWeekday.monday,
          ChoreWeekday.thursday,
        ],
        interval: 2,
        end: const ChoreRecurrenceCountEnd(8),
        minimumLocalDate: startLocalDate,
        requiredStartLocalDate: startLocalDate,
      )!;
  final ChoreRecurrenceRule monthly = ChoreRecurrenceRule.tryAnchored(
    frequency: ChoreRecurrenceFrequency.monthly,
    startLocalDate: startLocalDate,
    interval: 3,
    end: const ChoreRecurrenceNeverEnds(),
  )!;
  return GuidedChoreSetupResumePlan.tryCreate(
    householdId: activeHouseholdFixture().householdId,
    assigneeMemberId: activeHouseholdFixture().memberId,
    startLocalDate: startLocalDate,
    householdTimezone: 'Asia/Seoul',
    inputs: <GuidedChoreSetupInput>[
      GuidedChoreSetupInput.withRecurrence(
        template: ChoreTemplatePreset.cleanPetArea,
        title: 'Clean pet area',
        recurrenceRule: weekly,
      ),
      GuidedChoreSetupInput.withRecurrence(
        template: ChoreTemplatePreset.wipeCounters,
        title: 'Wipe counters',
        recurrenceRule: ChoreRecurrenceRule.tryAnchored(
          frequency: ChoreRecurrenceFrequency.daily,
          startLocalDate: startLocalDate,
          interval: 4,
          end: ChoreRecurrenceUntilEnd(ChoreLocalDate.tryParse('2026-12-31')!),
        )!,
      ),
      GuidedChoreSetupInput.withRecurrence(
        template: ChoreTemplatePreset.changeBedLinen,
        title: 'Change bed linen',
        recurrenceRule: monthly,
      ),
    ],
    commandIds: <String>[
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    ].map((String value) => ChoreCommandId.tryParse(value)!).toList(),
    completedCount: completedCount,
  )!;
}

Map<String, Object?> _mutate(String encoded, String key, Object? value) {
  return Map<String, Object?>.from(jsonDecode(encoded) as Map)..[key] = value;
}

Map<String, Object?> _withUnknownKey(String encoded) {
  return Map<String, Object?>.from(jsonDecode(encoded) as Map)
    ..['unexpected'] = 'value';
}

Map<String, Object?> _reverseEntries(String encoded) {
  final Map<String, Object?> value = Map<String, Object?>.from(
    jsonDecode(encoded) as Map,
  );
  value['entries'] = List<Object?>.from(
    value['entries']! as List,
  ).reversed.toList();
  return value;
}

Map<String, Object?> _padFirstTitle(String encoded) {
  final Map<String, Object?> value = Map<String, Object?>.from(
    jsonDecode(encoded) as Map,
  );
  final List<Object?> entries = List<Object?>.from(value['entries']! as List);
  entries[0] = Map<String, Object?>.from(entries[0]! as Map)
    ..['title'] = ' Dishes ';
  value['entries'] = entries;
  return value;
}

Map<String, Object?> _widenFirstRecurrence(String encoded) {
  final Map<String, Object?> value = Map<String, Object?>.from(
    jsonDecode(encoded) as Map,
  );
  final List<Object?> entries = List<Object?>.from(value['entries']! as List);
  final Map<String, Object?> first = Map<String, Object?>.from(
    entries[0]! as Map,
  );
  first['recurrenceRule'] = Map<String, Object?>.from(
    first['recurrenceRule']! as Map,
  )..['unexpected'] = true;
  entries[0] = first;
  value['entries'] = entries;
  return value;
}

Map<String, Object?> _reverseWeeklyWeekdays(String encoded) {
  final Map<String, Object?> value = Map<String, Object?>.from(
    jsonDecode(encoded) as Map,
  );
  final List<Object?> entries = List<Object?>.from(value['entries']! as List);
  final Map<String, Object?> weekly = Map<String, Object?>.from(
    entries[2]! as Map,
  );
  final Map<String, Object?> recurrence = Map<String, Object?>.from(
    weekly['recurrenceRule']! as Map,
  );
  recurrence['weekdays'] = List<Object?>.from(
    recurrence['weekdays']! as List,
  ).reversed.toList();
  weekly['recurrenceRule'] = recurrence;
  entries[2] = weekly;
  value['entries'] = entries;
  return value;
}

final class _MemorySecureStringStore implements SecureStringStore {
  _MemorySecureStringStore({this.failInitialization = false});

  final bool failInitialization;
  final Map<String, String> values = <String, String>{};
  var failNextWrite = false;
  var initializeCount = 0;
  var deleteCount = 0;
  var deleteAllCount = 0;

  @override
  Future<void> initialize() async {
    initializeCount += 1;
    if (failInitialization) {
      throw StateError('initialize failed');
    }
  }

  @override
  Future<bool> containsKey(String key) async => values.containsKey(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('write failed');
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    deleteCount += 1;
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    deleteAllCount += 1;
    values.clear();
  }
}
