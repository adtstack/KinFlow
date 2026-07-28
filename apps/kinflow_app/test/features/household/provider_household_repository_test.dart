import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/household/data/datasources/household_data_source.dart';
import 'package:kinflow_app/features/household/data/repositories/provider_household_repository.dart';
import 'package:kinflow_app/features/household/domain/entities/first_household_request.dart';
import 'package:kinflow_app/features/household/domain/failures/household_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

void main() {
  group('ProviderHouseholdRepository', () {
    test('maps active selection records to domain identifiers', () async {
      final _FakeHouseholdDataSource dataSource = _FakeHouseholdDataSource(
        loadResult: const ActiveHouseholdDataFound(
          ActiveHouseholdRecord(
            householdId: '22222222-2222-4222-8222-222222222222',
            memberId: '33333333-3333-4333-8333-333333333333',
          ),
        ),
      );
      final ProviderHouseholdRepository repository =
          ProviderHouseholdRepository(dataSource);

      final LoadActiveHouseholdResult result = await repository
          .loadActiveHousehold();

      expect(result, isA<ActiveHouseholdLoaded>());
      final ActiveHouseholdLoaded loaded = result as ActiveHouseholdLoaded;
      expect(
        loaded.household.householdId.value,
        '22222222-2222-4222-8222-222222222222',
      );
      expect(
        loaded.household.memberId.value,
        '33333333-3333-4333-8333-333333333333',
      );
    });

    test('keeps an absent active selection distinct from failures', () async {
      final ProviderHouseholdRepository repository =
          ProviderHouseholdRepository(_FakeHouseholdDataSource());

      expect(await repository.loadActiveHousehold(), isA<NoActiveHousehold>());
    });

    test('rejects malformed provider identifiers fail closed', () async {
      final ProviderHouseholdRepository repository =
          ProviderHouseholdRepository(
            _FakeHouseholdDataSource(
              loadResult: const ActiveHouseholdDataFound(
                ActiveHouseholdRecord(
                  householdId: 'provider-controlled-value',
                  memberId: '33333333-3333-4333-8333-333333333333',
                ),
              ),
            ),
          );

      final LoadActiveHouseholdResult result = await repository
          .loadActiveHousehold();

      expect(result, isA<LoadActiveHouseholdFailed>());
      expect(
        (result as LoadActiveHouseholdFailed).failure.kind,
        HouseholdFailureKind.invalidPayload,
      );
    });

    test('maps stable data failures without provider details', () async {
      const Map<HouseholdDataFailureKind, HouseholdFailureKind> cases =
          <HouseholdDataFailureKind, HouseholdFailureKind>{
            HouseholdDataFailureKind.unauthenticated:
                HouseholdFailureKind.unauthenticated,
            HouseholdDataFailureKind.invalidInput:
                HouseholdFailureKind.invalidInput,
            HouseholdDataFailureKind.activeHouseholdExists:
                HouseholdFailureKind.activeHouseholdExists,
            HouseholdDataFailureKind.idempotencyConflict:
                HouseholdFailureKind.idempotencyConflict,
            HouseholdDataFailureKind.profileUnavailable:
                HouseholdFailureKind.profileUnavailable,
            HouseholdDataFailureKind.temporarilyUnavailable:
                HouseholdFailureKind.temporarilyUnavailable,
            HouseholdDataFailureKind.invalidPayload:
                HouseholdFailureKind.invalidPayload,
            HouseholdDataFailureKind.unknown: HouseholdFailureKind.internal,
          };

      for (final MapEntry<HouseholdDataFailureKind, HouseholdFailureKind> entry
          in cases.entries) {
        final ProviderHouseholdRepository repository =
            ProviderHouseholdRepository(
              _FakeHouseholdDataSource(
                loadResult: LoadActiveHouseholdDataFailed(entry.key),
              ),
            );

        final LoadActiveHouseholdResult result = await repository
            .loadActiveHousehold();

        expect(
          (result as LoadActiveHouseholdFailed).failure.kind,
          entry.value,
          reason: entry.key.name,
        );
      }
    });

    test('forwards only normalized command fields and maps result', () async {
      final _FakeHouseholdDataSource dataSource = _FakeHouseholdDataSource(
        createResult: const FirstHouseholdDataCreated(
          ActiveHouseholdRecord(
            householdId: '22222222-2222-4222-8222-222222222222',
            memberId: '33333333-3333-4333-8333-333333333333',
          ),
        ),
      );
      final ProviderHouseholdRepository repository =
          ProviderHouseholdRepository(dataSource);

      final CreateFirstHouseholdResult result = await repository
          .createFirstHousehold(_request());

      expect(result, isA<FirstHouseholdCreated>());
      expect(dataSource.lastIdempotencyKey, _idempotencyKey().value);
      expect(dataSource.lastHouseholdName, 'Kim Home');
      expect(dataSource.lastOwnerDisplayName, 'Alex');
      expect(dataSource.lastLocale, 'en');
      expect(dataSource.lastTimezone, 'Asia/Seoul');
    });
  });
}

final class _FakeHouseholdDataSource implements HouseholdDataSource {
  _FakeHouseholdDataSource({
    this.loadResult = const ActiveHouseholdDataAbsent(),
    this.createResult = const CreateFirstHouseholdDataFailed(
      HouseholdDataFailureKind.temporarilyUnavailable,
    ),
  });

  final LoadActiveHouseholdDataResult loadResult;
  final CreateFirstHouseholdDataResult createResult;
  String? lastIdempotencyKey;
  String? lastHouseholdName;
  String? lastOwnerDisplayName;
  String? lastLocale;
  String? lastTimezone;

  @override
  Future<LoadActiveHouseholdDataResult> loadActiveHousehold() async {
    return loadResult;
  }

  @override
  Future<CreateFirstHouseholdDataResult> createFirstHousehold({
    required String idempotencyKey,
    required String householdName,
    required String ownerDisplayName,
    required String locale,
    required String timezone,
  }) async {
    lastIdempotencyKey = idempotencyKey;
    lastHouseholdName = householdName;
    lastOwnerDisplayName = ownerDisplayName;
    lastLocale = locale;
    lastTimezone = timezone;
    return createResult;
  }
}

CreateFirstHouseholdRequest _request() {
  final FirstHouseholdDraft? draft = FirstHouseholdDraft.tryCreate(
    householdName: '  Kim Home  ',
    ownerDisplayName: ' Alex ',
    locale: 'EN',
    timezone: 'Asia/Seoul',
  );
  if (draft == null) {
    throw StateError('Static first household draft must be valid.');
  }
  return draft.withId(_idempotencyKey());
}

HouseholdCreationId _idempotencyKey() {
  final HouseholdCreationId? id = HouseholdCreationId.tryParse(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  );
  if (id == null) {
    throw StateError('Static idempotency key must be a UUID.');
  }
  return id;
}
