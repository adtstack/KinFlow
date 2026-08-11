import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kinflow_app/app/presentation/widgets/app_modal_route.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/settings/domain/entities/timezone_catalog.dart';
import 'package:kinflow_app/features/settings/domain/repositories/timezone_catalog_repository.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

Future<String?> showTimezonePickerSheet({
  required BuildContext context,
  required TimezoneCatalogRepository repository,
  required String selectedTimezone,
  required String title,
}) {
  return showAppModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(
      maxWidth: AppLayoutTokens.statusContentMaxWidth,
    ),
    builder: (BuildContext context) {
      return FractionallySizedBox(
        heightFactor: 0.9,
        child: TimezonePickerSheet(
          repository: repository,
          selectedTimezone: selectedTimezone,
          title: title,
        ),
      );
    },
  );
}

class TimezoneSelectionFormField extends StatelessWidget {
  const TimezoneSelectionFormField({
    required this.fieldKey,
    required this.controller,
    required this.repository,
    required this.pickerTitle,
    required this.labelText,
    this.enabled = true,
    this.helperText,
    this.hintText,
    this.errorText,
    this.validator,
    this.onSelected,
    super.key,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final TimezoneCatalogRepository repository;
  final String pickerTitle;
  final String labelText;
  final bool enabled;
  final String? helperText;
  final String? hintText;
  final String? errorText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      readOnly: true,
      showCursor: false,
      enableInteractiveSelection: false,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      decoration: InputDecoration(
        labelText: labelText,
        helperText: helperText,
        hintText: hintText,
        errorText: errorText,
        suffixIcon: const Icon(Icons.travel_explore_outlined),
      ),
      validator: validator,
      onTap: enabled ? () => unawaited(_select(context)) : null,
    );
  }

  Future<void> _select(BuildContext context) async {
    final String? selection = await showTimezonePickerSheet(
      context: context,
      repository: repository,
      selectedTimezone: controller.text.trim(),
      title: pickerTitle,
    );
    if (!context.mounted || selection == null) return;
    controller.text = selection;
    onSelected?.call(selection);
  }
}

class TimezonePickerSheet extends StatefulWidget {
  const TimezonePickerSheet({
    required this.repository,
    required this.selectedTimezone,
    required this.title,
    super.key,
  });

  final TimezoneCatalogRepository repository;
  final String selectedTimezone;
  final String title;

  @override
  State<TimezonePickerSheet> createState() => _TimezonePickerSheetState();
}

class _TimezonePickerSheetState extends State<TimezonePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  TimezoneCatalog? _catalog;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return SafeArea(
      child: ListView(
        key: const Key('timezonePicker.sheet'),
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          top: AppSpacing.sm,
          right: AppSpacing.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.sm,
        ),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                key: const Key('timezonePicker.close'),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: localizations.timezonePickerCloseAction,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: ListTile(
              key: const Key('timezonePicker.current'),
              leading: const Icon(Icons.check_circle_outline),
              title: Text(localizations.timezonePickerCurrentLabel),
              subtitle: Text(widget.selectedTimezone),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('timezonePicker.search'),
            controller: _searchController,
            enabled: !_loading && !_failed,
            maxLength: TimezoneCatalog.maximumQueryCharacters,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: localizations.timezonePickerSearchLabel,
              helperText: localizations.timezonePickerSearchHelper,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      key: const Key('timezonePicker.clearSearch'),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      tooltip: localizations.timezonePickerClearSearchAction,
                      icon: const Icon(Icons.clear),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._results(localizations),
        ],
      ),
    );
  }

  List<Widget> _results(AppLocalizations localizations) {
    if (_loading) {
      return <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Column(
            key: const Key('timezonePicker.loading'),
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text(
                localizations.timezonePickerLoadingLabel,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ];
    }
    if (_failed || _catalog == null) {
      return <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Column(
            key: const Key('timezonePicker.failure'),
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.public_off_outlined, size: AppIconSize.status),
              const SizedBox(height: AppSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  localizations.timezonePickerLoadFailure,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                key: const Key('timezonePicker.retry'),
                onPressed: () => unawaited(_load()),
                icon: const Icon(Icons.refresh),
                label: Text(localizations.retryAction),
              ),
            ],
          ),
        ),
      ];
    }

    final List<TimezoneCatalogEntry> results = _catalog!.search(
      _searchController.text,
      selectedIdentifier: widget.selectedTimezone,
    );
    if (results.isEmpty) {
      return <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Semantics(
            liveRegion: true,
            child: Text(
              localizations.timezonePickerEmptyLabel,
              key: const Key('timezonePicker.empty'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ];
    }
    return <Widget>[
      Column(
        key: const Key('timezonePicker.results'),
        children: <Widget>[
          for (int index = 0; index < results.length; index += 1) ...<Widget>[
            if (index > 0) const Divider(height: 1),
            Builder(
              builder: (BuildContext context) {
                final TimezoneCatalogEntry entry = results[index];
                final bool selected =
                    entry.identifier == widget.selectedTimezone;
                return Semantics(
                  selected: selected,
                  button: true,
                  child: ListTile(
                    key: Key('timezonePicker.result.${entry.identifier}'),
                    selected: selected,
                    leading: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    title: Text(entry.identifier),
                    subtitle: Text(_metadata(localizations, entry)),
                    onTap: () => Navigator.of(context).pop(entry.identifier),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    ];
  }

  String _metadata(AppLocalizations localizations, TimezoneCatalogEntry entry) {
    final int minutes = entry.currentUtcOffsetMinutes;
    final String sign = minutes < 0 ? '-' : '+';
    final int absolute = minutes.abs();
    final String offset =
        '$sign${(absolute ~/ 60).toString().padLeft(2, '0')}:'
        '${(absolute % 60).toString().padLeft(2, '0')}';
    final String clockKind = entry.isDaylightSaving
        ? localizations.timezonePickerDaylightSavingLabel
        : localizations.timezonePickerStandardTimeLabel;
    return localizations.timezonePickerMetadata(offset, clockKind);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final TimezoneCatalogResult result;
    try {
      result = await widget.repository.load();
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    if (!mounted) return;
    switch (result) {
      case TimezoneCatalogSucceeded(:final catalog):
        setState(() {
          _catalog = catalog;
          _loading = false;
          _failed = false;
        });
      case TimezoneCatalogFailed():
        setState(() {
          _catalog = null;
          _loading = false;
          _failed = true;
        });
    }
  }
}
