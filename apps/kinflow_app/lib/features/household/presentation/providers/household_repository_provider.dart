import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  throw StateError('HouseholdRepository override is required.');
});
