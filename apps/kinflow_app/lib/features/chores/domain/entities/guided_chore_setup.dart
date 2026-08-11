import 'dart:convert';

import 'package:kinflow_app/features/chores/domain/entities/chore_template.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class GuidedChoreSetupInput {
  const GuidedChoreSetupInput({
    required this.template,
    required this.title,
    required this.frequency,
  }) : recurrenceRule = null;

  GuidedChoreSetupInput.withRecurrence({
    required this.template,
    required this.title,
    required ChoreRecurrenceRule recurrenceRule,
  }) : frequency = recurrenceRule.frequency,
       recurrenceRule = recurrenceRule;

  final ChoreTemplatePreset template;
  final String title;
  final ChoreRecurrenceFrequency frequency;
  final ChoreRecurrenceRule? recurrenceRule;
}

final class GuidedChoreSetupEntry {
  const GuidedChoreSetupEntry._({required this.template, required this.draft});

  final ChoreTemplatePreset template;
  final RecurringChoreDraft draft;
}

final class GuidedChoreSetupDraft {
  GuidedChoreSetupDraft._(List<GuidedChoreSetupEntry> entries)
    : entries = List<GuidedChoreSetupEntry>.unmodifiable(entries);

  static const int requiredEntryCount = 3;

  final List<GuidedChoreSetupEntry> entries;

  static GuidedChoreSetupDraft? tryCreate({
    required HouseholdId householdId,
    required HouseholdMemberId assigneeMemberId,
    required ChoreLocalDate startLocalDate,
    required List<GuidedChoreSetupInput> inputs,
  }) {
    if (inputs.length != requiredEntryCount ||
        inputs
                .map((GuidedChoreSetupInput input) => input.template)
                .toSet()
                .length !=
            requiredEntryCount) {
      return null;
    }

    final List<GuidedChoreSetupInput> ordered =
        List<GuidedChoreSetupInput>.of(inputs)
          ..sort((GuidedChoreSetupInput left, GuidedChoreSetupInput right) {
            return ChoreTemplateCatalog.templates
                .indexOf(left.template)
                .compareTo(
                  ChoreTemplateCatalog.templates.indexOf(right.template),
                );
          });
    final List<GuidedChoreSetupEntry> entries = <GuidedChoreSetupEntry>[];
    for (final GuidedChoreSetupInput input in ordered) {
      final ChoreRecurrenceRule recurrenceRule =
          input.recurrenceRule ??
          ChoreRecurrenceRule.anchored(
            frequency: input.frequency,
            startLocalDate: startLocalDate,
          );
      final RecurringChoreDraft? draft = RecurringChoreDraft.tryCreate(
        householdId: householdId,
        title: input.title,
        description: '',
        assigneeMemberId: assigneeMemberId,
        startLocalDate: startLocalDate,
        dueLocalTime: null,
        recurrenceRule: recurrenceRule,
      );
      if (draft == null) {
        return null;
      }
      entries.add(
        GuidedChoreSetupEntry._(template: input.template, draft: draft),
      );
    }
    return GuidedChoreSetupDraft._(entries);
  }

  String get fingerprint => jsonEncode(
    entries
        .map(
          (GuidedChoreSetupEntry entry) => <String, Object>{
            'template': entry.template.stableKey,
            'draft': entry.draft.fingerprint,
          },
        )
        .toList(growable: false),
  );
}

final class GuidedChoreSetupResumePlan {
  GuidedChoreSetupResumePlan._({
    required this.householdId,
    required this.assigneeMemberId,
    required this.startLocalDate,
    required this.householdTimezone,
    required List<GuidedChoreSetupInput> inputs,
    required List<ChoreCommandId> commandIds,
    required this.completedCount,
    required this.draft,
  }) : inputs = List<GuidedChoreSetupInput>.unmodifiable(inputs),
       commandIds = List<ChoreCommandId>.unmodifiable(commandIds);

  final HouseholdId householdId;
  final HouseholdMemberId assigneeMemberId;
  final ChoreLocalDate startLocalDate;
  final String householdTimezone;
  final List<GuidedChoreSetupInput> inputs;
  final List<ChoreCommandId> commandIds;
  final int completedCount;
  final GuidedChoreSetupDraft draft;

  static GuidedChoreSetupResumePlan? tryCreate({
    required HouseholdId householdId,
    required HouseholdMemberId assigneeMemberId,
    required ChoreLocalDate startLocalDate,
    required String householdTimezone,
    required List<GuidedChoreSetupInput> inputs,
    required List<ChoreCommandId> commandIds,
    required int completedCount,
  }) {
    if (householdTimezone.isEmpty ||
        householdTimezone != householdTimezone.trim() ||
        householdTimezone.length > 255 ||
        _containsSetupControlCharacter(householdTimezone) ||
        commandIds.length != GuidedChoreSetupDraft.requiredEntryCount ||
        commandIds.toSet().length != GuidedChoreSetupDraft.requiredEntryCount ||
        completedCount < 0 ||
        completedCount > GuidedChoreSetupDraft.requiredEntryCount) {
      return null;
    }
    final GuidedChoreSetupDraft? draft = GuidedChoreSetupDraft.tryCreate(
      householdId: householdId,
      assigneeMemberId: assigneeMemberId,
      startLocalDate: startLocalDate,
      inputs: inputs,
    );
    if (draft == null) {
      return null;
    }
    final List<GuidedChoreSetupInput> normalizedInputs = draft.entries
        .map(
          (GuidedChoreSetupEntry entry) => GuidedChoreSetupInput.withRecurrence(
            template: entry.template,
            title: entry.draft.title,
            recurrenceRule: entry.draft.recurrenceRule,
          ),
        )
        .toList(growable: false);
    return GuidedChoreSetupResumePlan._(
      householdId: householdId,
      assigneeMemberId: assigneeMemberId,
      startLocalDate: startLocalDate,
      householdTimezone: householdTimezone,
      inputs: normalizedInputs,
      commandIds: List<ChoreCommandId>.of(commandIds, growable: false),
      completedCount: completedCount,
      draft: draft,
    );
  }

  GuidedChoreSetupResumePlan? withCompletedCount(int value) {
    return tryCreate(
      householdId: householdId,
      assigneeMemberId: assigneeMemberId,
      startLocalDate: startLocalDate,
      householdTimezone: householdTimezone,
      inputs: inputs,
      commandIds: commandIds,
      completedCount: value,
    );
  }
}

bool _containsSetupControlCharacter(String value) {
  return value.runes.any(
    (int rune) => rune <= 0x1f || rune >= 0x7f && rune <= 0x9f,
  );
}
