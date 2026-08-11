import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/domain/entities/pending_chore_completion.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

void main() {
  final HouseholdId householdId = HouseholdId.tryParse(
    '11111111-1111-4111-8111-111111111111',
  )!;
  final HouseholdMemberId actorMemberId = HouseholdMemberId.tryParse(
    '22222222-2222-4222-8222-222222222222',
  )!;
  final ChoreOccurrenceId occurrenceId = ChoreOccurrenceId.tryParse(
    '33333333-3333-4333-8333-333333333333',
  )!;
  final ChoreCommandId commandId = ChoreCommandId.tryParse(
    '44444444-4444-4444-8444-444444444444',
  )!;
  final DateTime createdAt = DateTime.parse('2026-08-09T01:00:00.000Z');

  test('creates only bounded canonical completion commands', () {
    final PendingChoreCompletion item = PendingChoreCompletion.tryCreate(
      householdId: householdId,
      actorMemberId: actorMemberId,
      occurrenceId: occurrenceId,
      expectedVersion: 7,
      idempotencyKey: commandId,
      createdAt: createdAt,
      expiresAt: createdAt.add(PendingChoreCompletion.maximumAge),
      attemptCount: 0,
    )!;

    expect(item.canAttemptAutomatically, isTrue);
    expect(item.request.completed, isTrue);
    expect(item.request.expectedVersion, 7);
    expect(item.request.idempotencyKey, commandId);
  });

  test('rejects invalid version, time, TTL, and attempt bounds', () {
    PendingChoreCompletion? create({
      int version = 1,
      DateTime? created,
      DateTime? expires,
      int attempts = 0,
    }) {
      return PendingChoreCompletion.tryCreate(
        householdId: householdId,
        actorMemberId: actorMemberId,
        occurrenceId: occurrenceId,
        expectedVersion: version,
        idempotencyKey: commandId,
        createdAt: created ?? createdAt,
        expiresAt: expires ?? createdAt.add(PendingChoreCompletion.maximumAge),
        attemptCount: attempts,
      );
    }

    expect(create(version: 0), isNull);
    expect(create(created: createdAt.toLocal()), isNull);
    expect(create(expires: createdAt), isNull);
    expect(create(expires: createdAt.add(const Duration(minutes: 31))), isNull);
    expect(create(attempts: -1), isNull);
    expect(create(attempts: 4), isNull);
  });

  test('advances automatic attempts exactly three times', () {
    PendingChoreCompletion? item = PendingChoreCompletion.tryCreate(
      householdId: householdId,
      actorMemberId: actorMemberId,
      occurrenceId: occurrenceId,
      expectedVersion: 1,
      idempotencyKey: commandId,
      createdAt: createdAt,
      expiresAt: createdAt.add(const Duration(minutes: 30)),
      attemptCount: 0,
    );

    for (var attempt = 1; attempt <= 3; attempt += 1) {
      item = item!.nextAttempt();
      expect(item?.attemptCount, attempt);
    }
    expect(item?.canAttemptAutomatically, isFalse);
    expect(item?.nextAttempt(), isNull);
  });

  test('can durably stop automatic replay without changing the command', () {
    final PendingChoreCompletion item = PendingChoreCompletion.tryCreate(
      householdId: householdId,
      actorMemberId: actorMemberId,
      occurrenceId: occurrenceId,
      expectedVersion: 5,
      idempotencyKey: commandId,
      createdAt: createdAt,
      expiresAt: createdAt.add(const Duration(minutes: 30)),
      attemptCount: 1,
    )!;

    final PendingChoreCompletion exhausted = item.exhaustAutomaticAttempts();

    expect(exhausted.hasSameCommand(item), isTrue);
    expect(exhausted.attemptCount, 3);
    expect(exhausted.canAttemptAutomatically, isFalse);
  });
}
