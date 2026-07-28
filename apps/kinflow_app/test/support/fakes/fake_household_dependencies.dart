import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/domain/entities/first_household_request.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/domain/services/household_creation_id_generator.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class FakeHouseholdRepository implements HouseholdRepository {
  FakeHouseholdRepository({
    this.loadCallback,
    this.createCallback,
    LoadActiveHouseholdResult? defaultLoadResult,
    CreateFirstHouseholdResult? defaultCreateResult,
    List<LoadActiveHouseholdResult> loadResults =
        const <LoadActiveHouseholdResult>[],
    List<CreateFirstHouseholdResult> createResults =
        const <CreateFirstHouseholdResult>[],
  }) : defaultLoadResult = defaultLoadResult ?? const NoActiveHousehold(),
       defaultCreateResult =
           defaultCreateResult ??
           FirstHouseholdCreated(activeHouseholdFixture()),
       _loadResults = List<LoadActiveHouseholdResult>.of(loadResults),
       _createResults = List<CreateFirstHouseholdResult>.of(createResults);

  final Future<LoadActiveHouseholdResult> Function()? loadCallback;
  final Future<CreateFirstHouseholdResult> Function(
    CreateFirstHouseholdRequest request,
  )?
  createCallback;
  final LoadActiveHouseholdResult defaultLoadResult;
  final CreateFirstHouseholdResult defaultCreateResult;
  final List<LoadActiveHouseholdResult> _loadResults;
  final List<CreateFirstHouseholdResult> _createResults;
  final List<CreateFirstHouseholdRequest> createRequests =
      <CreateFirstHouseholdRequest>[];

  var loadCount = 0;
  var createCount = 0;

  @override
  Future<LoadActiveHouseholdResult> loadActiveHousehold() async {
    loadCount += 1;
    final Future<LoadActiveHouseholdResult> Function()? callback = loadCallback;
    if (callback != null) {
      return callback();
    }
    if (_loadResults.isNotEmpty) {
      return _loadResults.removeAt(0);
    }
    return defaultLoadResult;
  }

  @override
  Future<CreateFirstHouseholdResult> createFirstHousehold(
    CreateFirstHouseholdRequest request,
  ) async {
    createCount += 1;
    createRequests.add(request);
    final Future<CreateFirstHouseholdResult> Function(
      CreateFirstHouseholdRequest request,
    )?
    callback = createCallback;
    if (callback != null) {
      return callback(request);
    }
    if (_createResults.isNotEmpty) {
      return _createResults.removeAt(0);
    }
    return defaultCreateResult;
  }
}

final class FakeHouseholdCreationIdGenerator
    implements HouseholdCreationIdGenerator {
  FakeHouseholdCreationIdGenerator({
    List<String> values = const <String>[
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    ],
  }) : _values = values.map(_creationId).toList(growable: false);

  final List<HouseholdCreationId> _values;
  var generateCount = 0;

  @override
  HouseholdCreationId generate() {
    final int index = generateCount;
    generateCount += 1;
    if (index >= _values.length) {
      throw StateError('No fake household creation ID remains.');
    }
    return _values[index];
  }
}

ActiveHousehold activeHouseholdFixture({
  String householdId = '22222222-2222-4222-8222-222222222222',
  String memberId = '33333333-3333-4333-8333-333333333333',
}) {
  final HouseholdId? parsedHouseholdId = HouseholdId.tryParse(householdId);
  final HouseholdMemberId? parsedMemberId = HouseholdMemberId.tryParse(
    memberId,
  );
  if (parsedHouseholdId == null || parsedMemberId == null) {
    throw StateError('Static active household fixture must use UUIDs.');
  }
  return ActiveHousehold(
    householdId: parsedHouseholdId,
    memberId: parsedMemberId,
  );
}

HouseholdCreationId _creationId(String value) {
  final HouseholdCreationId? id = HouseholdCreationId.tryParse(value);
  if (id == null) {
    throw StateError('Static household creation fixture must be a UUID.');
  }
  return id;
}
