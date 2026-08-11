import 'package:kinflow_app/features/chores/domain/entities/chore_template.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

String localizedChoreTemplateTitle(
  AppLocalizations localizations,
  ChoreTemplatePreset template,
) {
  return switch (template) {
    ChoreTemplatePreset.dishes => localizations.choreTemplateDishes,
    ChoreTemplatePreset.kitchenReset => localizations.choreTemplateKitchenReset,
    ChoreTemplatePreset.laundry => localizations.choreTemplateLaundry,
    ChoreTemplatePreset.vacuuming => localizations.choreTemplateVacuuming,
    ChoreTemplatePreset.bathroomCleaning =>
      localizations.choreTemplateBathroomCleaning,
    ChoreTemplatePreset.trashAndRecycling =>
      localizations.choreTemplateTrashAndRecycling,
    ChoreTemplatePreset.wipeCounters => localizations.choreTemplateWipeCounters,
    ChoreTemplatePreset.fridgeCleanout =>
      localizations.choreTemplateFridgeCleanout,
    ChoreTemplatePreset.mopFloors => localizations.choreTemplateMopFloors,
    ChoreTemplatePreset.dusting => localizations.choreTemplateDusting,
    ChoreTemplatePreset.changeBedLinen =>
      localizations.choreTemplateChangeBedLinen,
    ChoreTemplatePreset.foldClothes => localizations.choreTemplateFoldClothes,
    ChoreTemplatePreset.makeBeds => localizations.choreTemplateMakeBeds,
    ChoreTemplatePreset.waterPlants => localizations.choreTemplateWaterPlants,
    ChoreTemplatePreset.feedPets => localizations.choreTemplateFeedPets,
    ChoreTemplatePreset.cleanPetArea => localizations.choreTemplateCleanPetArea,
  };
}

String localizedChoreTemplateCategory(
  AppLocalizations localizations,
  ChoreTemplateCategory category,
) {
  return switch (category) {
    ChoreTemplateCategory.kitchen => localizations.choreTemplateCategoryKitchen,
    ChoreTemplateCategory.cleaning =>
      localizations.choreTemplateCategoryCleaning,
    ChoreTemplateCategory.laundry => localizations.choreTemplateCategoryLaundry,
    ChoreTemplateCategory.homeCare =>
      localizations.choreTemplateCategoryHomeCare,
    ChoreTemplateCategory.petCare => localizations.choreTemplateCategoryPetCare,
  };
}
