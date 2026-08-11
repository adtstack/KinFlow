import 'package:flutter/material.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_template.dart';
import 'package:kinflow_app/features/chores/presentation/chore_template_localization.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class ChoreTemplateBrowser extends StatefulWidget {
  const ChoreTemplateBrowser({
    required this.keyPrefix,
    required this.selectedTemplates,
    required this.onSelected,
    this.multiSelect = false,
    this.selectionEnabled = true,
    this.canSelect,
    super.key,
  });

  final String keyPrefix;
  final Set<ChoreTemplatePreset> selectedTemplates;
  final void Function(ChoreTemplatePreset template, bool selected) onSelected;
  final bool multiSelect;
  final bool selectionEnabled;
  final bool Function(ChoreTemplatePreset template)? canSelect;

  @override
  State<ChoreTemplateBrowser> createState() => _ChoreTemplateBrowserState();
}

class _ChoreTemplateBrowserState extends State<ChoreTemplateBrowser> {
  final TextEditingController _searchController = TextEditingController();
  ChoreTemplateCategory? _category;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final String query = _searchController.text.trim().toLowerCase();
    final List<ChoreTemplatePreset> visibleTemplates = ChoreTemplateCatalog
        .templates
        .where((ChoreTemplatePreset template) {
          if (_category != null && template.category != _category) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }
          return localizedChoreTemplateTitle(
            localizations,
            template,
          ).toLowerCase().contains(query);
        })
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          key: Key('${widget.keyPrefix}.template.search'),
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: localizations.choreTemplateSearchLabel,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    key: Key('${widget.keyPrefix}.template.search.clear'),
                    tooltip: localizations.choreTemplateSearchClearAction,
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear),
                  ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            key: Key('${widget.keyPrefix}.template.categories'),
            children: <Widget>[
              FilterChip(
                key: Key('${widget.keyPrefix}.template.category.all'),
                label: Text(localizations.choreTemplateCategoryAll),
                selected: _category == null,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (_) => setState(() => _category = null),
              ),
              for (final ChoreTemplateCategory category
                  in ChoreTemplateCatalog.categories) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                FilterChip(
                  key: Key(
                    '${widget.keyPrefix}.template.category.${category.stableKey}',
                  ),
                  label: Text(
                    localizedChoreTemplateCategory(localizations, category),
                  ),
                  selected: _category == category,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (_) => setState(() => _category = category),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (visibleTemplates.isEmpty)
          Semantics(
            liveRegion: true,
            child: Text(
              localizations.choreTemplateNoResults,
              key: Key('${widget.keyPrefix}.template.empty'),
            ),
          )
        else
          Wrap(
            key: Key('${widget.keyPrefix}.templates'),
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: visibleTemplates
                .map(_buildTemplateChip)
                .toList(growable: false),
          ),
      ],
    );
  }

  Widget _buildTemplateChip(ChoreTemplatePreset template) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final bool selected = widget.selectedTemplates.contains(template);
    final bool selectable =
        widget.selectionEnabled &&
        (selected || widget.canSelect?.call(template) != false);
    final Key key = Key('${widget.keyPrefix}.template.${template.stableKey}');
    final Text label = Text(
      localizedChoreTemplateTitle(localizations, template),
    );
    final ValueChanged<bool>? onSelected = selectable
        ? (bool value) => widget.onSelected(template, value)
        : null;

    if (widget.multiSelect) {
      return FilterChip(
        key: key,
        label: label,
        selected: selected,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        onSelected: onSelected,
      );
    }
    return ChoiceChip(
      key: key,
      label: label,
      selected: selected,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      onSelected: onSelected,
    );
  }
}
