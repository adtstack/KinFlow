# 원본 파일 문서화: `contracts/chore-templates.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/chore-templates.yaml`
- 원본 형식: `yaml`
- 범위: WP03-19 PII-free app-bundled searchable chore template library (WP03-08 successor)

```yaml
version: "2026-08-09-wp03-19"
requirements: [FR-CHORE-010, FR-CHORE-001, FR-CHORE-002, NFR-PRIV-01, NFR-A11Y-01, NFR-I18N-01, D-058]
authority:
  catalog: app-bundled immutable domain catalog
  displayTitle: localized ARB selected by exact stable key
  categoryLabel: localized ARB selected by exact category key
  search: process-memory localized title match
  persistedChore: existing one-time or recurring chore create contract
catalog:
  exactCategories: [kitchen, cleaning, laundry, home_care, pet_care]
  exactEntries:
    - {stableKey: dishes, category: kitchen, suggestedCadence: daily, titleKey: choreTemplateDishes}
    - {stableKey: kitchen_reset, category: kitchen, suggestedCadence: daily, titleKey: choreTemplateKitchenReset}
    - {stableKey: laundry, category: laundry, suggestedCadence: weekly, titleKey: choreTemplateLaundry}
    - {stableKey: vacuuming, category: cleaning, suggestedCadence: weekly, titleKey: choreTemplateVacuuming}
    - {stableKey: bathroom_cleaning, category: cleaning, suggestedCadence: weekly, titleKey: choreTemplateBathroomCleaning}
    - {stableKey: trash_and_recycling, category: home_care, suggestedCadence: weekly, titleKey: choreTemplateTrashAndRecycling}
    - {stableKey: wipe_counters, category: kitchen, suggestedCadence: daily, titleKey: choreTemplateWipeCounters}
    - {stableKey: fridge_cleanout, category: kitchen, suggestedCadence: weekly, titleKey: choreTemplateFridgeCleanout}
    - {stableKey: mop_floors, category: cleaning, suggestedCadence: weekly, titleKey: choreTemplateMopFloors}
    - {stableKey: dusting, category: cleaning, suggestedCadence: weekly, titleKey: choreTemplateDusting}
    - {stableKey: change_bed_linen, category: laundry, suggestedCadence: weekly, titleKey: choreTemplateChangeBedLinen}
    - {stableKey: fold_clothes, category: laundry, suggestedCadence: weekly, titleKey: choreTemplateFoldClothes}
    - {stableKey: make_beds, category: home_care, suggestedCadence: daily, titleKey: choreTemplateMakeBeds}
    - {stableKey: water_plants, category: home_care, suggestedCadence: weekly, titleKey: choreTemplateWaterPlants}
    - {stableKey: feed_pets, category: pet_care, suggestedCadence: daily, titleKey: choreTemplateFeedPets}
    - {stableKey: clean_pet_area, category: pet_care, suggestedCadence: weekly, titleKey: choreTemplateCleanPetArea}
  stableKeyFormat: lowercase ASCII snake case
  lookup: exact only
  unknownKey: reject
  mutableAtRuntime: false
application:
  initialSelection: none
  discovery:
    initialCategory: all
    initialQuery: empty
    categoryAndQuery: intersect
    queryMatch: trimmed case-insensitive contains on localized title only
    emptyResult: explicit localized state
    selectedValuePreservedWhenHidden: true
    persistence: none
  onSelect:
    setEditableTitle: localized template title
    setEditableRepeat: suggested cadence
    preserve: [description, assigneeMemberId, dueLocalDate, dueLocalTime]
    resetStaleCreationFailure: true
  onManualTitleOrRepeatEdit:
    clearSelectionIndicator: true
    preserveDraftValues: true
  templateOptional: true
persistence:
  databaseMigration: none
  serverSeed: none
  localStorage: none
  requestFieldsAdded: none
  templateStableKeySent: false
  catalogVersionSent: false
  analyticsEventAdded: false
  existingRequests: [CreateOneTimeChoreRequest, CreateRecurringChoreRequest]
composition:
  guidedThreeChoreSetup:
    contract: guided-chore-setup.yaml
    implementedBy: WP03-10
    extendedBy: WP03-19
    catalogVersionRequired: "2026-08-09-wp03-19"
privacy:
  allowed: [stable generic chore key, stable generic category key, daily cadence, weekly cadence]
  forbidden:
    - user, account, household, or member identifier
    - name, email, location, date, time, description, or household content
    - URL, remote image, HTML, markdown, executable content, or token
security:
  authorizationChange: none
  activeHouseholdAndMemberChecks: existing create path remains authoritative
  remoteCatalog: forbidden in this version
client:
  routes: [existing chore creation screen, first-household guided chore setup]
  controls: [localized search field, horizontally scrollable category FilterChip row, wrapping template ChoiceChip or FilterChip]
  stableWidgetKeyPrefix: chore.template.
  localization: [EN, KO, EN-XA]
  compactTextScale: 200 percent scrollable
  minimumActionTarget: 48 dp
rollback:
  removeSearchCategoryAndTenAdditionalEntries: true
  restoreWp0308SixEntryCatalogAndChipSections: true
  existingCreateFlowPreserved: true
  remoteOrPersistedDataRollback: none
deferred:
  - server-managed or household-specific templates
  - recommendation or personalization
  - search history, recently used, ranking, or usage analytics
  - real-account and physical-device UX validation
```
