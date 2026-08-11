import 'dart:async';
import 'dart:convert';

import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/chores/application/guided_chore_setup_resume_store.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_template.dart';
import 'package:kinflow_app/features/chores/domain/entities/guided_chore_setup.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/infrastructure/secure_storage/secure_string_store.dart';

final class SecureGuidedChoreSetupResumeStore
    implements
        GuidedChoreSetupResumeStore,
        SensitiveLocalStatePurgeParticipant {
  SecureGuidedChoreSetupResumeStore(this._store, {this.maxEncodedBytes = 8192});

  static const int contractVersion = 2;
  static const String storageKey = 'kinflow.guided_chore_setup.resume.v2';
  static const String legacyStorageKey = 'kinflow.guided_chore_setup.resume.v1';
  static const Set<String> _envelopeKeys = <String>{
    'contractVersion',
    'householdId',
    'assigneeMemberId',
    'startLocalDate',
    'householdTimezone',
    'entries',
    'completedCount',
  };
  static const Set<String> _entryKeys = <String>{
    'templateKey',
    'title',
    'recurrenceRule',
    'commandId',
  };

  final SecureStringStore _store;
  final int maxEncodedBytes;

  Future<void> _tail = Future<void>.value();
  var _initialized = false;

  @override
  Future<GuidedChoreSetupResumePlan?> read({
    required HouseholdId expectedHouseholdId,
    required HouseholdMemberId expectedAssigneeMemberId,
  }) {
    return _serialized<GuidedChoreSetupResumePlan?>(() async {
      try {
        await _initialize();
        if (await _store.containsKey(legacyStorageKey)) {
          await _store.delete(legacyStorageKey);
        }
        final String? encoded = await _store.read(storageKey);
        if (encoded == null) {
          return null;
        }
        if (utf8.encode(encoded).length > maxEncodedBytes) {
          await _deleteUnsafe();
          return null;
        }
        final GuidedChoreSetupResumePlan? plan = _decode(encoded);
        if (plan == null ||
            plan.householdId != expectedHouseholdId ||
            plan.assigneeMemberId != expectedAssigneeMemberId) {
          await _deleteUnsafe();
          return null;
        }
        return plan;
      } on Object {
        return null;
      }
    });
  }

  @override
  Future<bool> write(GuidedChoreSetupResumePlan plan) {
    return _serialized<bool>(() async {
      try {
        await _initialize();
        final String encoded = _encode(plan);
        if (utf8.encode(encoded).length > maxEncodedBytes) {
          return false;
        }
        await _store.write(storageKey, encoded);
        return true;
      } on Object {
        return false;
      }
    });
  }

  @override
  Future<bool> clear() {
    return _serialized<bool>(() async {
      try {
        await _initialize();
        await _deleteUnsafe();
        return true;
      } on Object {
        return false;
      }
    });
  }

  @override
  Future<void> purgeSensitiveLocalState() {
    return _serialized<void>(() async {
      await _initialize();
      await _store.deleteAll();
    });
  }

  String _encode(GuidedChoreSetupResumePlan plan) {
    return jsonEncode(<String, Object>{
      'contractVersion': contractVersion,
      'householdId': plan.householdId.value,
      'assigneeMemberId': plan.assigneeMemberId.value,
      'startLocalDate': plan.startLocalDate.value,
      'householdTimezone': plan.householdTimezone,
      'entries': List<Map<String, Object>>.generate(
        plan.inputs.length,
        (int index) => <String, Object>{
          'templateKey': plan.inputs[index].template.stableKey,
          'title': plan.inputs[index].title,
          'recurrenceRule': plan.inputs[index].recurrenceRule!.toJson(),
          'commandId': plan.commandIds[index].value,
        },
        growable: false,
      ),
      'completedCount': plan.completedCount,
    });
  }

  GuidedChoreSetupResumePlan? _decode(String encoded) {
    final Object? raw;
    try {
      raw = jsonDecode(encoded);
    } on FormatException {
      return null;
    }
    final Map<String, Object?>? envelope = _exactMap(raw, _envelopeKeys);
    if (envelope == null ||
        envelope['contractVersion'] != contractVersion ||
        envelope['householdId'] is! String ||
        envelope['assigneeMemberId'] is! String ||
        envelope['startLocalDate'] is! String ||
        envelope['householdTimezone'] is! String ||
        envelope['entries'] is! List<Object?> ||
        envelope['completedCount'] is! int) {
      return null;
    }
    final String householdValue = envelope['householdId']! as String;
    final String memberValue = envelope['assigneeMemberId']! as String;
    final String dateValue = envelope['startLocalDate']! as String;
    final HouseholdId? householdId = HouseholdId.tryParse(householdValue);
    final HouseholdMemberId? assigneeMemberId = HouseholdMemberId.tryParse(
      memberValue,
    );
    final ChoreLocalDate? startLocalDate = ChoreLocalDate.tryParse(dateValue);
    if (householdId == null ||
        householdId.value != householdValue ||
        assigneeMemberId == null ||
        assigneeMemberId.value != memberValue ||
        startLocalDate == null ||
        startLocalDate.value != dateValue) {
      return null;
    }
    final List<Object?> rawEntries = envelope['entries']! as List<Object?>;
    if (rawEntries.length != GuidedChoreSetupDraft.requiredEntryCount) {
      return null;
    }
    final List<GuidedChoreSetupInput> inputs = <GuidedChoreSetupInput>[];
    final List<ChoreCommandId> commandIds = <ChoreCommandId>[];
    for (final Object? rawEntry in rawEntries) {
      final Map<String, Object?>? entry = _exactMap(rawEntry, _entryKeys);
      if (entry == null ||
          entry['templateKey'] is! String ||
          entry['title'] is! String ||
          entry['commandId'] is! String) {
        return null;
      }
      final String commandValue = entry['commandId']! as String;
      final ChoreTemplatePreset? template =
          ChoreTemplatePreset.tryParseStableKey(
            entry['templateKey']! as String,
          );
      final ChoreRecurrenceRule? recurrenceRule = ChoreRecurrenceRule.tryParse(
        entry['recurrenceRule'],
      );
      final ChoreCommandId? commandId = ChoreCommandId.tryParse(commandValue);
      if (template == null ||
          recurrenceRule == null ||
          !_hasCanonicalWeekdayOrder(recurrenceRule) ||
          commandId == null ||
          commandId.value != commandValue) {
        return null;
      }
      inputs.add(
        GuidedChoreSetupInput.withRecurrence(
          template: template,
          title: entry['title']! as String,
          recurrenceRule: recurrenceRule,
        ),
      );
      commandIds.add(commandId);
    }
    final GuidedChoreSetupResumePlan? plan =
        GuidedChoreSetupResumePlan.tryCreate(
          householdId: householdId,
          assigneeMemberId: assigneeMemberId,
          startLocalDate: startLocalDate,
          householdTimezone: envelope['householdTimezone']! as String,
          inputs: inputs,
          commandIds: commandIds,
          completedCount: envelope['completedCount']! as int,
        );
    if (plan == null || !_isCanonical(plan, envelope, rawEntries)) {
      return null;
    }
    return plan;
  }

  bool _isCanonical(
    GuidedChoreSetupResumePlan plan,
    Map<String, Object?> envelope,
    List<Object?> rawEntries,
  ) {
    if (envelope['householdTimezone'] != plan.householdTimezone) {
      return false;
    }
    for (var index = 0; index < rawEntries.length; index += 1) {
      final Map<String, Object?> entry = Map<String, Object?>.from(
        rawEntries[index]! as Map,
      );
      if (entry['templateKey'] != plan.inputs[index].template.stableKey ||
          entry['title'] != plan.inputs[index].title ||
          jsonEncode(entry['recurrenceRule']) !=
              jsonEncode(plan.inputs[index].recurrenceRule!.toJson()) ||
          entry['commandId'] != plan.commandIds[index].value) {
        return false;
      }
    }
    return true;
  }

  Map<String, Object?>? _exactMap(Object? raw, Set<String> expectedKeys) {
    if (raw is! Map || raw.keys.any((Object? key) => key is! String)) {
      return null;
    }
    final Map<String, Object?> value = Map<String, Object?>.from(raw);
    if (value.length != expectedKeys.length ||
        !value.keys.toSet().containsAll(expectedKeys)) {
      return null;
    }
    return value;
  }

  Future<void> _initialize() async {
    if (_initialized) {
      return;
    }
    await _store.initialize();
    _initialized = true;
  }

  Future<void> _deleteUnsafe() async {
    await _store.delete(storageKey);
    await _store.delete(legacyStorageKey);
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final Completer<T> completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

bool _hasCanonicalWeekdayOrder(ChoreRecurrenceRule rule) {
  if (rule.frequency != ChoreRecurrenceFrequency.weekly) {
    return true;
  }
  var previousIndex = -1;
  for (final ChoreWeekday weekday in rule.weekdays) {
    final int index = ChoreWeekday.values.indexOf(weekday);
    if (index <= previousIndex) {
      return false;
    }
    previousIndex = index;
  }
  return true;
}
