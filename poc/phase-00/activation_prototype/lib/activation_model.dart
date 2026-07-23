import 'package:flutter/foundation.dart';

enum AdultActor { coordinator, invitedAdult }

extension AdultActorLabel on AdultActor {
  String get label => switch (this) {
    AdultActor.coordinator => '성인 1',
    AdultActor.invitedAdult => '성인 2',
  };

  String get shortLabel => switch (this) {
    AdultActor.coordinator => '1',
    AdultActor.invitedAdult => '2',
  };
}

@immutable
class PrototypeChore {
  const PrototypeChore({
    required this.id,
    required this.title,
    required this.assignee,
    this.completedBy,
  });

  final String id;
  final String title;
  final AdultActor assignee;
  final AdultActor? completedBy;

  bool get isCompleted => completedBy != null;

  PrototypeChore completeBy(AdultActor actor) {
    return PrototypeChore(
      id: id,
      title: title,
      assignee: assignee,
      completedBy: actor,
    );
  }
}

class ActivationModel extends ChangeNotifier {
  String householdName = '';
  bool inviteAccepted = false;
  AdultActor activeActor = AdultActor.coordinator;
  bool nextDayVisited = false;

  final List<PrototypeChore> _chores = [];
  final List<String> _events = [];
  int _nextChoreNumber = 1;

  List<PrototypeChore> get chores => List.unmodifiable(_chores);
  List<String> get events => List.unmodifiable(_events);

  bool get householdCreated => householdName.isNotEmpty;
  bool get hasMinimumChores => _chores.length >= 3;

  bool get bothAdultsCompleted {
    return AdultActor.values.every(
      (actor) => _chores.any((chore) => chore.completedBy == actor),
    );
  }

  bool get canVisitNextDay {
    return householdCreated &&
        inviteAccepted &&
        hasMinimumChores &&
        bothAdultsCompleted;
  }

  bool get isActivated => canVisitNextDay && nextDayVisited;

  int get completedStepCount {
    return [
      householdCreated,
      inviteAccepted,
      hasMinimumChores,
      bothAdultsCompleted,
      nextDayVisited,
    ].where((step) => step).length;
  }

  bool createHousehold(String rawName) {
    final name = rawName.trim();
    if (name.isEmpty || householdCreated) {
      return false;
    }
    householdName = name;
    _record('household_created');
    notifyListeners();
    return true;
  }

  bool acceptInvite() {
    if (!householdCreated || inviteAccepted) {
      return false;
    }
    inviteAccepted = true;
    _record('adult_invite_accepted');
    notifyListeners();
    return true;
  }

  void switchActor(AdultActor actor) {
    if (!inviteAccepted || activeActor == actor) {
      return;
    }
    activeActor = actor;
    _record('active_adult_switched:${actor.name}');
    notifyListeners();
  }

  bool addChore({required String title, required AdultActor assignee}) {
    final normalizedTitle = title.trim();
    if (!inviteAccepted || normalizedTitle.isEmpty) {
      return false;
    }
    _chores.add(
      PrototypeChore(
        id: 'chore-${_nextChoreNumber++}',
        title: normalizedTitle,
        assignee: assignee,
      ),
    );
    _record('chore_created:${assignee.name}');
    notifyListeners();
    return true;
  }

  void seedRecommendedChores() {
    if (!inviteAccepted || _chores.isNotEmpty) {
      return;
    }
    _chores.addAll([
      PrototypeChore(
        id: 'chore-${_nextChoreNumber++}',
        title: '설거지 정리',
        assignee: AdultActor.coordinator,
      ),
      PrototypeChore(
        id: 'chore-${_nextChoreNumber++}',
        title: '쓰레기 버리기',
        assignee: AdultActor.invitedAdult,
      ),
      PrototypeChore(
        id: 'chore-${_nextChoreNumber++}',
        title: '빨래 개기',
        assignee: AdultActor.coordinator,
      ),
    ]);
    _record('three_chore_seed_created');
    notifyListeners();
  }

  bool canComplete(PrototypeChore chore) {
    return !chore.isCompleted && chore.assignee == activeActor;
  }

  bool completeChore(String choreId) {
    final index = _chores.indexWhere((chore) => chore.id == choreId);
    if (index < 0 || !canComplete(_chores[index])) {
      return false;
    }
    _chores[index] = _chores[index].completeBy(activeActor);
    _record('chore_completed:${activeActor.name}');
    notifyListeners();
    return true;
  }

  bool visitNextDayToday() {
    if (!canVisitNextDay || nextDayVisited) {
      return false;
    }
    nextDayVisited = true;
    _record('next_day_today_visited');
    notifyListeners();
    return true;
  }

  void reset() {
    householdName = '';
    inviteAccepted = false;
    activeActor = AdultActor.coordinator;
    nextDayVisited = false;
    _chores.clear();
    _events.clear();
    _nextChoreNumber = 1;
    notifyListeners();
  }

  void _record(String event) {
    _events.add(event);
  }
}
