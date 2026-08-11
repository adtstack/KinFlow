import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/settings/domain/entities/timezone_catalog.dart';
import 'package:kinflow_app/features/settings/domain/repositories/timezone_catalog_repository.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

final class TimezoneDateTimePreviewItem {
  const TimezoneDateTimePreviewItem({
    required this.keyValue,
    required this.label,
    required this.timezone,
  });

  final String keyValue;
  final String label;
  final String timezone;
}

class TimezoneDateTimePreviewPanel extends StatefulWidget {
  const TimezoneDateTimePreviewPanel({
    required this.repository,
    required this.languageCode,
    required this.items,
    this.clock = DateTime.now,
    super.key,
  });

  final TimezoneCatalogRepository repository;
  final String languageCode;
  final List<TimezoneDateTimePreviewItem> items;
  final DateTime Function() clock;

  @override
  State<TimezoneDateTimePreviewPanel> createState() =>
      _TimezoneDateTimePreviewPanelState();
}

class _TimezoneDateTimePreviewPanelState
    extends State<TimezoneDateTimePreviewPanel> {
  TimezoneCatalog? _catalog;
  DateTime? _previewInstant;
  bool _loading = false;
  bool _failed = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load(preserveContent: false));
  }

  @override
  void didUpdateWidget(TimezoneDateTimePreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.repository, oldWidget.repository)) {
      unawaited(_load(preserveContent: false, force: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return Material(
      key: const Key('timezonePreview.panel'),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xs),
                  child: Icon(Icons.schedule_outlined),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      localizations.timezonePreviewHeading,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('timezonePreview.refresh'),
                  constraints: const BoxConstraints(
                    minWidth: AppTouchTarget.minimum,
                    minHeight: AppTouchTarget.minimum,
                  ),
                  onPressed: _loading
                      ? null
                      : () => unawaited(_load(preserveContent: true)),
                  tooltip: localizations.timezonePreviewRefreshAction,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(localizations.timezonePreviewBody),
            if (_loading && _catalog != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              const LinearProgressIndicator(
                key: Key('timezonePreview.refreshing'),
              ),
            ],
            if (_catalog == null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              if (_loading)
                _loadingState(localizations)
              else
                _failureState(localizations),
            ] else ...<Widget>[
              if (_failed) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                _failureBanner(localizations),
              ],
              const SizedBox(height: AppSpacing.sm),
              for (int index = 0; index < widget.items.length; index += 1) ...[
                if (index > 0) const Divider(height: 1),
                _previewRow(localizations, widget.items[index]),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _loadingState(AppLocalizations localizations) {
    return Semantics(
      liveRegion: true,
      child: Row(
        key: const Key('timezonePreview.loading'),
        children: <Widget>[
          const SizedBox.square(
            dimension: AppSpacing.lg,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(localizations.timezonePreviewLoadingLabel)),
        ],
      ),
    );
  }

  Widget _failureState(AppLocalizations localizations) {
    return Column(
      key: const Key('timezonePreview.failure'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          liveRegion: true,
          child: Text(localizations.timezonePreviewLoadFailure),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: const Key('timezonePreview.retry'),
          onPressed: () => unawaited(_load(preserveContent: false)),
          icon: const Icon(Icons.refresh),
          label: Text(localizations.retryAction),
        ),
      ],
    );
  }

  Widget _failureBanner(AppLocalizations localizations) {
    return Semantics(
      key: const Key('timezonePreview.refreshFailure'),
      liveRegion: true,
      child: Text(
        localizations.timezonePreviewLoadFailure,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  Widget _previewRow(
    AppLocalizations localizations,
    TimezoneDateTimePreviewItem item,
  ) {
    final TimezoneCatalogEntry? entry = _catalog?.entryForIdentifier(
      item.timezone,
    );
    if (entry == null || _previewInstant == null) {
      return Semantics(
        label: localizations.timezonePreviewUnavailableSemantics(
          item.label,
          item.timezone,
        ),
        child: ExcludeSemantics(
          child: Padding(
            key: Key('timezonePreview.${item.keyValue}.unavailable'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  localizations.timezonePreviewMissingTimezone(item.timezone),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final DateTime shifted = _previewInstant!.add(
      Duration(minutes: entry.currentUtcOffsetMinutes),
    );
    final DateTime wallTime = DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
    );
    final Locale previewLocale = Locale(
      widget.languageCode == 'ko' ? 'ko' : 'en',
    );
    return Localizations.override(
      context: context,
      locale: previewLocale,
      child: Builder(
        builder: (BuildContext previewContext) {
          final MaterialLocalizations material = MaterialLocalizations.of(
            previewContext,
          );
          final String date = material.formatFullDate(wallTime);
          final String time = material.formatTimeOfDay(
            TimeOfDay.fromDateTime(wallTime),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          );
          final String metadata = _metadata(localizations, entry);
          return Semantics(
            label: localizations.timezonePreviewSemantics(
              item.label,
              entry.identifier,
              date,
              time,
              metadata,
            ),
            child: ExcludeSemantics(
              child: Padding(
                key: Key('timezonePreview.${item.keyValue}'),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      entry.identifier,
                      key: Key('timezonePreview.${item.keyValue}.timezone'),
                    ),
                    Text(
                      date,
                      key: Key('timezonePreview.${item.keyValue}.date'),
                    ),
                    Text(
                      time,
                      key: Key('timezonePreview.${item.keyValue}.time'),
                    ),
                    Text(
                      metadata,
                      key: Key('timezonePreview.${item.keyValue}.metadata'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
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

  Future<void> _load({
    required bool preserveContent,
    bool force = false,
  }) async {
    if (_loading && !force) return;
    final int generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _failed = false;
      if (!preserveContent) {
        _catalog = null;
        _previewInstant = null;
      }
    });
    final DateTime instant;
    final TimezoneCatalogResult result;
    try {
      instant = widget.clock().toUtc();
      result = await widget.repository.load();
    } on Object {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    if (!mounted || generation != _loadGeneration) return;
    switch (result) {
      case TimezoneCatalogSucceeded(:final catalog):
        setState(() {
          _catalog = catalog;
          _previewInstant = instant;
          _loading = false;
          _failed = false;
        });
      case TimezoneCatalogFailed():
        setState(() {
          _loading = false;
          _failed = true;
        });
    }
  }
}
