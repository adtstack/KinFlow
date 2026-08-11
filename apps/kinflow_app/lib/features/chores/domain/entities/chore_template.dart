enum ChoreTemplateCadence { daily, weekly }

enum ChoreTemplateCategory {
  kitchen('kitchen'),
  cleaning('cleaning'),
  laundry('laundry'),
  homeCare('home_care'),
  petCare('pet_care');

  const ChoreTemplateCategory(this.stableKey);

  final String stableKey;

  static ChoreTemplateCategory? tryParseStableKey(String value) {
    return switch (value) {
      'kitchen' => ChoreTemplateCategory.kitchen,
      'cleaning' => ChoreTemplateCategory.cleaning,
      'laundry' => ChoreTemplateCategory.laundry,
      'home_care' => ChoreTemplateCategory.homeCare,
      'pet_care' => ChoreTemplateCategory.petCare,
      _ => null,
    };
  }
}

enum ChoreTemplatePreset {
  dishes('dishes', ChoreTemplateCategory.kitchen, ChoreTemplateCadence.daily),
  kitchenReset(
    'kitchen_reset',
    ChoreTemplateCategory.kitchen,
    ChoreTemplateCadence.daily,
  ),
  laundry(
    'laundry',
    ChoreTemplateCategory.laundry,
    ChoreTemplateCadence.weekly,
  ),
  vacuuming(
    'vacuuming',
    ChoreTemplateCategory.cleaning,
    ChoreTemplateCadence.weekly,
  ),
  bathroomCleaning(
    'bathroom_cleaning',
    ChoreTemplateCategory.cleaning,
    ChoreTemplateCadence.weekly,
  ),
  trashAndRecycling(
    'trash_and_recycling',
    ChoreTemplateCategory.homeCare,
    ChoreTemplateCadence.weekly,
  ),
  wipeCounters(
    'wipe_counters',
    ChoreTemplateCategory.kitchen,
    ChoreTemplateCadence.daily,
  ),
  fridgeCleanout(
    'fridge_cleanout',
    ChoreTemplateCategory.kitchen,
    ChoreTemplateCadence.weekly,
  ),
  mopFloors(
    'mop_floors',
    ChoreTemplateCategory.cleaning,
    ChoreTemplateCadence.weekly,
  ),
  dusting(
    'dusting',
    ChoreTemplateCategory.cleaning,
    ChoreTemplateCadence.weekly,
  ),
  changeBedLinen(
    'change_bed_linen',
    ChoreTemplateCategory.laundry,
    ChoreTemplateCadence.weekly,
  ),
  foldClothes(
    'fold_clothes',
    ChoreTemplateCategory.laundry,
    ChoreTemplateCadence.weekly,
  ),
  makeBeds(
    'make_beds',
    ChoreTemplateCategory.homeCare,
    ChoreTemplateCadence.daily,
  ),
  waterPlants(
    'water_plants',
    ChoreTemplateCategory.homeCare,
    ChoreTemplateCadence.weekly,
  ),
  feedPets(
    'feed_pets',
    ChoreTemplateCategory.petCare,
    ChoreTemplateCadence.daily,
  ),
  cleanPetArea(
    'clean_pet_area',
    ChoreTemplateCategory.petCare,
    ChoreTemplateCadence.weekly,
  );

  const ChoreTemplatePreset(
    this.stableKey,
    this.category,
    this.suggestedCadence,
  );

  final String stableKey;
  final ChoreTemplateCategory category;
  final ChoreTemplateCadence suggestedCadence;

  static ChoreTemplatePreset? tryParseStableKey(String value) {
    return switch (value) {
      'dishes' => ChoreTemplatePreset.dishes,
      'kitchen_reset' => ChoreTemplatePreset.kitchenReset,
      'laundry' => ChoreTemplatePreset.laundry,
      'vacuuming' => ChoreTemplatePreset.vacuuming,
      'bathroom_cleaning' => ChoreTemplatePreset.bathroomCleaning,
      'trash_and_recycling' => ChoreTemplatePreset.trashAndRecycling,
      'wipe_counters' => ChoreTemplatePreset.wipeCounters,
      'fridge_cleanout' => ChoreTemplatePreset.fridgeCleanout,
      'mop_floors' => ChoreTemplatePreset.mopFloors,
      'dusting' => ChoreTemplatePreset.dusting,
      'change_bed_linen' => ChoreTemplatePreset.changeBedLinen,
      'fold_clothes' => ChoreTemplatePreset.foldClothes,
      'make_beds' => ChoreTemplatePreset.makeBeds,
      'water_plants' => ChoreTemplatePreset.waterPlants,
      'feed_pets' => ChoreTemplatePreset.feedPets,
      'clean_pet_area' => ChoreTemplatePreset.cleanPetArea,
      _ => null,
    };
  }
}

abstract final class ChoreTemplateCatalog {
  static const String version = '2026-08-09-wp03-19';

  static const List<ChoreTemplateCategory> categories = <ChoreTemplateCategory>[
    ChoreTemplateCategory.kitchen,
    ChoreTemplateCategory.cleaning,
    ChoreTemplateCategory.laundry,
    ChoreTemplateCategory.homeCare,
    ChoreTemplateCategory.petCare,
  ];

  static const List<ChoreTemplatePreset> templates = <ChoreTemplatePreset>[
    ChoreTemplatePreset.dishes,
    ChoreTemplatePreset.kitchenReset,
    ChoreTemplatePreset.laundry,
    ChoreTemplatePreset.vacuuming,
    ChoreTemplatePreset.bathroomCleaning,
    ChoreTemplatePreset.trashAndRecycling,
    ChoreTemplatePreset.wipeCounters,
    ChoreTemplatePreset.fridgeCleanout,
    ChoreTemplatePreset.mopFloors,
    ChoreTemplatePreset.dusting,
    ChoreTemplatePreset.changeBedLinen,
    ChoreTemplatePreset.foldClothes,
    ChoreTemplatePreset.makeBeds,
    ChoreTemplatePreset.waterPlants,
    ChoreTemplatePreset.feedPets,
    ChoreTemplatePreset.cleanPetArea,
  ];
}
