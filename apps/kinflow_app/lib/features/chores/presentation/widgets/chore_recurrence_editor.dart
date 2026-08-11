import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

enum ChoreRecurrenceEndMode { never, count, until }

ChoreRecurrenceEndMode choreRecurrenceEndMode(ChoreRecurrenceEnd end) {
  return switch (end) {
    ChoreRecurrenceNeverEnds() => ChoreRecurrenceEndMode.never,
    ChoreRecurrenceCountEnd() => ChoreRecurrenceEndMode.count,
    ChoreRecurrenceUntilEnd() => ChoreRecurrenceEndMode.until,
  };
}

ChoreRecurrenceEnd? choreRecurrenceEndFromEditor({
  required ChoreRecurrenceEndMode mode,
  required String countText,
  required DateTime untilDate,
}) {
  return switch (mode) {
    ChoreRecurrenceEndMode.never => const ChoreRecurrenceNeverEnds(),
    ChoreRecurrenceEndMode.count => switch (int.tryParse(countText.trim())) {
      final int count when count >= 1 && count <= 1000 =>
        ChoreRecurrenceCountEnd(count),
      _ => null,
    },
    ChoreRecurrenceEndMode.until => ChoreRecurrenceUntilEnd(
      ChoreLocalDate.fromDateTime(untilDate),
    ),
  };
}

String choreRecurrenceWeekdayLabel(
  AppLocalizations localizations,
  ChoreWeekday weekday,
) {
  return switch (weekday) {
    ChoreWeekday.monday => localizations.choreRecurrenceWeekdayMonday,
    ChoreWeekday.tuesday => localizations.choreRecurrenceWeekdayTuesday,
    ChoreWeekday.wednesday => localizations.choreRecurrenceWeekdayWednesday,
    ChoreWeekday.thursday => localizations.choreRecurrenceWeekdayThursday,
    ChoreWeekday.friday => localizations.choreRecurrenceWeekdayFriday,
    ChoreWeekday.saturday => localizations.choreRecurrenceWeekdaySaturday,
    ChoreWeekday.sunday => localizations.choreRecurrenceWeekdaySunday,
  };
}

String choreRecurrenceWeekdayList(
  AppLocalizations localizations,
  Iterable<ChoreWeekday> weekdays,
) {
  final Set<ChoreWeekday> selected = weekdays.toSet();
  return ChoreWeekday.values
      .where(selected.contains)
      .map(
        (ChoreWeekday weekday) =>
            choreRecurrenceWeekdayLabel(localizations, weekday),
      )
      .join(', ');
}

final class ChoreRecurrenceEditor extends StatelessWidget {
  const ChoreRecurrenceEditor({
    required this.keyPrefix,
    required this.frequency,
    required this.startLocalDate,
    required this.weekdays,
    required this.requiredWeekday,
    required this.monthDay,
    required this.monthDayEditable,
    required this.intervalController,
    required this.endMode,
    required this.countController,
    required this.untilDate,
    required this.enabled,
    required this.onWeekdaysChanged,
    required this.onMonthDayChanged,
    required this.onInputChanged,
    required this.onEndModeChanged,
    required this.onUntilDateChanged,
    super.key,
  });

  final String keyPrefix;
  final ChoreRecurrenceFrequency frequency;
  final DateTime startLocalDate;
  final Set<ChoreWeekday> weekdays;
  final ChoreWeekday? requiredWeekday;
  final int monthDay;
  final bool monthDayEditable;
  final TextEditingController intervalController;
  final ChoreRecurrenceEndMode endMode;
  final TextEditingController countController;
  final DateTime untilDate;
  final bool enabled;
  final ValueChanged<Set<ChoreWeekday>> onWeekdaysChanged;
  final ValueChanged<int> onMonthDayChanged;
  final VoidCallback onInputChanged;
  final ValueChanged<ChoreRecurrenceEndMode> onEndModeChanged;
  final ValueChanged<DateTime> onUntilDateChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final int? interval = int.tryParse(intervalController.text.trim());
    final int? count = int.tryParse(countController.text.trim());
    final bool intervalValid =
        interval != null && interval >= 1 && interval <= 30;
    final bool weekdaysValid =
        frequency != ChoreRecurrenceFrequency.weekly ||
        weekdays.isNotEmpty &&
            weekdays.length <= ChoreWeekday.values.length &&
            (requiredWeekday == null || weekdays.contains(requiredWeekday));
    final bool monthDayValid =
        frequency != ChoreRecurrenceFrequency.monthly ||
        monthDay >= 1 && monthDay <= 31;
    final bool endValid = switch (endMode) {
      ChoreRecurrenceEndMode.never => true,
      ChoreRecurrenceEndMode.count =>
        count != null && count >= 1 && count <= 1000,
      ChoreRecurrenceEndMode.until => !DateUtils.dateOnly(
        untilDate,
      ).isBefore(DateUtils.dateOnly(startLocalDate)),
    };
    final String pattern = intervalValid && weekdaysValid && monthDayValid
        ? _pattern(localizations, frequency, interval)
        : localizations.choreRecurrenceInvalidSummary;
    final String endSummary = endValid
        ? _endSummary(
            localizations,
            material,
            mode: endMode,
            count: count,
            untilDate: untilDate,
          )
        : localizations.choreRecurrenceInvalidSummary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (frequency == ChoreRecurrenceFrequency.weekly) ...<Widget>[
          Text(
            localizations.choreRecurrenceWeekdaysLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            key: Key('$keyPrefix.weekdays'),
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: ChoreWeekday.values
                .map((ChoreWeekday weekday) {
                  final bool selected = weekdays.contains(weekday);
                  final bool locked =
                      selected &&
                      (weekday == requiredWeekday || weekdays.length == 1);
                  final Widget chip = ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: AppTouchTarget.minimum,
                      minHeight: AppTouchTarget.minimum,
                    ),
                    child: FilterChip(
                      key: Key('$keyPrefix.weekday.${weekday.wireValue}'),
                      label: Text(
                        choreRecurrenceWeekdayLabel(localizations, weekday),
                      ),
                      selected: selected,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onSelected: !enabled || locked
                          ? null
                          : (bool value) {
                              final Set<ChoreWeekday> updated = <ChoreWeekday>{
                                ...weekdays,
                              };
                              if (value) {
                                updated.add(weekday);
                              } else {
                                updated.remove(weekday);
                              }
                              onWeekdaysChanged(
                                Set<ChoreWeekday>.unmodifiable(updated),
                              );
                            },
                    ),
                  );
                  return locked
                      ? Tooltip(
                          message: _weekdayHelper(localizations),
                          child: chip,
                        )
                      : chip;
                })
                .toList(growable: false),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            _weekdayHelper(localizations),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (frequency == ChoreRecurrenceFrequency.monthly) ...<Widget>[
          KeyedSubtree(
            key: Key('$keyPrefix.monthDay'),
            child: DropdownButtonFormField<int>(
              key: ValueKey<int>(monthDay),
              initialValue: monthDay,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: localizations.choreRecurrenceMonthDayLabel,
                helperText: monthDayEditable
                    ? localizations.choreRecurrenceMonthDayMissingDateHelper
                    : localizations.choreRecurrenceMonthDayCreationAnchorHelper,
                helperMaxLines: 3,
              ),
              items: List<DropdownMenuItem<int>>.generate(
                31,
                (int index) => DropdownMenuItem<int>(
                  value: index + 1,
                  child: Text(
                    localizations.choreRecurrenceMonthDayOption(index + 1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              onChanged: !enabled || !monthDayEditable
                  ? null
                  : (int? value) {
                      if (value != null) {
                        onMonthDayChanged(value);
                      }
                    },
            ),
          ),
          if (!monthDayEditable) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              localizations.choreRecurrenceMonthDayMissingDateHelper,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
        TextFormField(
          key: Key('$keyPrefix.interval'),
          controller: intervalController,
          enabled: enabled,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          maxLength: 2,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            labelText: localizations.choreRecurrenceIntervalLabel,
            helperText: localizations.choreRecurrenceIntervalHelper,
            counterText: '',
          ),
          validator: (String? value) {
            final int? parsed = int.tryParse(value?.trim() ?? '');
            return parsed == null || parsed < 1 || parsed > 30
                ? localizations.choreRecurrenceIntervalValidation
                : null;
          },
          onChanged: (_) => onInputChanged(),
        ),
        const SizedBox(height: AppSpacing.sm),
        KeyedSubtree(
          key: Key('$keyPrefix.end'),
          child: DropdownButtonFormField<ChoreRecurrenceEndMode>(
            key: ValueKey<ChoreRecurrenceEndMode>(endMode),
            initialValue: endMode,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: localizations.choreRecurrenceEndLabel,
            ),
            items: ChoreRecurrenceEndMode.values
                .map(
                  (ChoreRecurrenceEndMode mode) =>
                      DropdownMenuItem<ChoreRecurrenceEndMode>(
                        value: mode,
                        child: Text(
                          _endModeLabel(localizations, mode),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                )
                .toList(growable: false),
            onChanged: !enabled
                ? null
                : (ChoreRecurrenceEndMode? value) {
                    if (value != null) {
                      onEndModeChanged(value);
                    }
                  },
          ),
        ),
        if (endMode == ChoreRecurrenceEndMode.count) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            key: Key('$keyPrefix.count'),
            controller: countController,
            enabled: enabled,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 4,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              labelText: localizations.choreRecurrenceCountLabel,
              helperText: localizations.choreRecurrenceCountHelper,
              counterText: '',
            ),
            validator: (String? value) {
              final int? parsed = int.tryParse(value?.trim() ?? '');
              return parsed == null || parsed < 1 || parsed > 1000
                  ? localizations.choreRecurrenceCountValidation
                  : null;
            },
            onChanged: (_) => onInputChanged(),
          ),
        ],
        if (endMode == ChoreRecurrenceEndMode.until) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          ListTile(
            key: Key('$keyPrefix.until'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(localizations.choreRecurrenceUntilDateLabel),
            subtitle: Text(material.formatFullDate(untilDate)),
            trailing: const Icon(Icons.chevron_right),
            enabled: enabled,
            onTap: !enabled ? null : () => _chooseUntilDate(context),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          liveRegion: true,
          child: Container(
            key: Key('$keyPrefix.summary'),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: AppRadii.medium,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  localizations.choreRecurrenceSummary(
                    pattern,
                    material.formatFullDate(startLocalDate),
                  ),
                ),
                if (frequency == ChoreRecurrenceFrequency.weekly &&
                    weekdaysValid) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    localizations.choreRecurrenceWeekdaysSummary(
                      choreRecurrenceWeekdayList(localizations, weekdays),
                    ),
                  ),
                ],
                if (frequency == ChoreRecurrenceFrequency.monthly &&
                    monthDayValid) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(localizations.choreRecurrenceMonthDaySummary(monthDay)),
                ],
                const SizedBox(height: AppSpacing.xxs),
                Text(endSummary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _weekdayHelper(AppLocalizations localizations) {
    return requiredWeekday == null
        ? localizations.choreRecurrenceWeekdayMinimumHelper
        : localizations.choreRecurrenceWeekdayCreationAnchorHelper;
  }

  Future<void> _chooseUntilDate(BuildContext context) async {
    final DateTime minimum = DateUtils.dateOnly(startLocalDate);
    final DateTime initial = untilDate.isBefore(minimum)
        ? minimum
        : DateUtils.dateOnly(untilDate);
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minimum,
      lastDate: DateTime(2100, 12, 31),
    );
    if (selected != null && context.mounted) {
      onUntilDateChanged(DateUtils.dateOnly(selected));
    }
  }

  String _pattern(
    AppLocalizations localizations,
    ChoreRecurrenceFrequency frequency,
    int interval,
  ) {
    return switch (frequency) {
      ChoreRecurrenceFrequency.daily => localizations.choreRecurrenceEveryDays(
        interval,
      ),
      ChoreRecurrenceFrequency.weekly =>
        localizations.choreRecurrenceEveryWeeks(interval),
      ChoreRecurrenceFrequency.monthly =>
        localizations.choreRecurrenceEveryMonths(interval),
    };
  }

  String _endModeLabel(
    AppLocalizations localizations,
    ChoreRecurrenceEndMode mode,
  ) {
    return switch (mode) {
      ChoreRecurrenceEndMode.never => localizations.choreRecurrenceEndNever,
      ChoreRecurrenceEndMode.count =>
        localizations.choreRecurrenceEndAfterCount,
      ChoreRecurrenceEndMode.until => localizations.choreRecurrenceEndOnDate,
    };
  }

  String _endSummary(
    AppLocalizations localizations,
    MaterialLocalizations material, {
    required ChoreRecurrenceEndMode mode,
    required int? count,
    required DateTime untilDate,
  }) {
    return switch (mode) {
      ChoreRecurrenceEndMode.never =>
        localizations.choreRecurrenceEndNeverSummary,
      ChoreRecurrenceEndMode.count =>
        localizations.choreRecurrenceEndCountSummary(count!),
      ChoreRecurrenceEndMode.until =>
        localizations.choreRecurrenceEndUntilSummary(
          material.formatFullDate(untilDate),
        ),
    };
  }
}
