import 'dart:convert';

import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class OneTimeChoreDraft {
  const OneTimeChoreDraft._({
    required this.householdId,
    required this.title,
    required this.description,
    required this.assigneeMemberId,
    required this.dueLocalDate,
    required this.dueLocalTime,
  });

  final HouseholdId householdId;
  final String title;
  final String? description;
  final HouseholdMemberId assigneeMemberId;
  final ChoreLocalDate dueLocalDate;
  final ChoreLocalTime? dueLocalTime;

  static OneTimeChoreDraft? tryCreate({
    required HouseholdId householdId,
    required String title,
    required String description,
    required HouseholdMemberId assigneeMemberId,
    required ChoreLocalDate dueLocalDate,
    required ChoreLocalTime? dueLocalTime,
  }) {
    final String normalizedTitle = title.trim();
    final String normalizedDescription = description.trim();
    if (normalizedTitle.isEmpty ||
        normalizedTitle.length > 160 ||
        _containsControlCharacter(normalizedTitle) ||
        normalizedDescription.length > 4000) {
      return null;
    }
    return OneTimeChoreDraft._(
      householdId: householdId,
      title: normalizedTitle,
      description: normalizedDescription.isEmpty ? null : normalizedDescription,
      assigneeMemberId: assigneeMemberId,
      dueLocalDate: dueLocalDate,
      dueLocalTime: dueLocalTime,
    );
  }

  String get fingerprint => jsonEncode(<String, Object?>{
    'householdId': householdId.value,
    'title': title,
    'description': description,
    'assigneeMemberId': assigneeMemberId.value,
    'dueLocalDate': dueLocalDate.value,
    'dueLocalTime': dueLocalTime?.value,
  });

  CreateOneTimeChoreRequest withId(ChoreCommandId idempotencyKey) {
    return CreateOneTimeChoreRequest(
      idempotencyKey: idempotencyKey,
      householdId: householdId,
      title: title,
      description: description,
      assigneeMemberId: assigneeMemberId,
      dueLocalDate: dueLocalDate,
      dueLocalTime: dueLocalTime,
    );
  }
}

final class CreateOneTimeChoreRequest {
  const CreateOneTimeChoreRequest({
    required this.idempotencyKey,
    required this.householdId,
    required this.title,
    required this.description,
    required this.assigneeMemberId,
    required this.dueLocalDate,
    required this.dueLocalTime,
  });

  final ChoreCommandId idempotencyKey;
  final HouseholdId householdId;
  final String title;
  final String? description;
  final HouseholdMemberId assigneeMemberId;
  final ChoreLocalDate dueLocalDate;
  final ChoreLocalTime? dueLocalTime;
}

bool _containsControlCharacter(String value) {
  return value.codeUnits.any(
    (int codeUnit) => codeUnit < 32 || codeUnit == 127,
  );
}
