import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

enum ChoreListView {
  today('today'),
  upcoming('upcoming'),
  overdue('overdue'),
  completed('completed');

  const ChoreListView(this.wireName);

  final String wireName;

  static ChoreListView? tryParse(String value) {
    for (final ChoreListView view in values) {
      if (view.wireName == value) {
        return view;
      }
    }
    return null;
  }
}

final class ChoreListCursor {
  const ChoreListCursor._(this.value);

  final String value;

  static final RegExp _validValue = RegExp(r'^[0-9a-f]+$');

  static ChoreListCursor? tryParse(String value) {
    return value.length >= 2 &&
            value.length <= 1000 &&
            value.length.isEven &&
            _validValue.hasMatch(value)
        ? ChoreListCursor._(value)
        : null;
  }

  @override
  bool operator ==(Object other) {
    return other is ChoreListCursor && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final class ChoreListRequest {
  const ChoreListRequest._({
    required this.householdId,
    required this.view,
    required this.assigneeMemberId,
    required this.limit,
    required this.cursor,
  });

  final HouseholdId householdId;
  final ChoreListView view;
  final HouseholdMemberId? assigneeMemberId;
  final int limit;
  final ChoreListCursor? cursor;

  static ChoreListRequest? tryCreate({
    required HouseholdId householdId,
    ChoreListView view = ChoreListView.today,
    HouseholdMemberId? assigneeMemberId,
    int limit = 30,
    ChoreListCursor? cursor,
  }) {
    return limit >= 1 && limit <= 100
        ? ChoreListRequest._(
            householdId: householdId,
            view: view,
            assigneeMemberId: assigneeMemberId,
            limit: limit,
            cursor: cursor,
          )
        : null;
  }

  ChoreListRequest get firstPage => ChoreListRequest._(
    householdId: householdId,
    view: view,
    assigneeMemberId: assigneeMemberId,
    limit: limit,
    cursor: null,
  );

  ChoreListRequest? continuation(ChoreListCursor nextCursor) {
    return tryCreate(
      householdId: householdId,
      view: view,
      assigneeMemberId: assigneeMemberId,
      limit: limit,
      cursor: nextCursor,
    );
  }

  bool hasSameQuery(ChoreListRequest other) {
    return householdId == other.householdId &&
        view == other.view &&
        assigneeMemberId == other.assigneeMemberId &&
        limit == other.limit;
  }
}
