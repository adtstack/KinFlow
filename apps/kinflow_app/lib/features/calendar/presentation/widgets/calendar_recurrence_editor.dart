import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

enum CalendarRecurrenceEndMode { never, count, until }

CalendarRecurrenceEndMode calendarRecurrenceEndMode(CalendarRecurrenceEnd end) {
  return switch (end) {
    CalendarRecurrenceNeverEnds() => CalendarRecurrenceEndMode.never,
    CalendarRecurrenceCountEnd() => CalendarRecurrenceEndMode.count,
    CalendarRecurrenceUntilEnd() => CalendarRecurrenceEndMode.until,
  };
}

CalendarRecurrenceEnd? calendarRecurrenceEndFromEditor({
  required CalendarRecurrenceEndMode mode,
  required String countText,
  required DateTime untilDate,
}) {
  return switch (mode) {
    CalendarRecurrenceEndMode.never => const CalendarRecurrenceNeverEnds(),
    CalendarRecurrenceEndMode.count => switch (int.tryParse(countText.trim())) {
      final int count when count >= 1 && count <= 1000 =>
        CalendarRecurrenceCountEnd(count),
      _ => null,
    },
    CalendarRecurrenceEndMode.until => CalendarRecurrenceUntilEnd(
      CalendarLocalDate.fromDateTime(untilDate),
    ),
  };
}

String calendarRecurrencePattern(
  AppLocalizations localizations,
  CalendarRecurrenceFrequency frequency,
  int interval,
) {
  if (interval == 1) {
    return switch (frequency) {
      CalendarRecurrenceFrequency.daily =>
        localizations.calendarRecurrenceDaily,
      CalendarRecurrenceFrequency.weekly =>
        localizations.calendarRecurrenceWeekly,
      CalendarRecurrenceFrequency.monthly =>
        localizations.calendarRecurrenceMonthly,
    };
  }
  return switch (frequency) {
    CalendarRecurrenceFrequency.daily =>
      localizations.calendarRecurrenceEveryDays(interval),
    CalendarRecurrenceFrequency.weekly =>
      localizations.calendarRecurrenceEveryWeeks(interval),
    CalendarRecurrenceFrequency.monthly =>
      localizations.calendarRecurrenceEveryMonths(interval),
  };
}

String calendarRecurrenceWeekdayLabel(
  AppLocalizations localizations,
  CalendarWeekday weekday,
) {
  return switch (weekday) {
    CalendarWeekday.monday => localizations.calendarRecurrenceWeekdayMonday,
    CalendarWeekday.tuesday => localizations.calendarRecurrenceWeekdayTuesday,
    CalendarWeekday.wednesday =>
      localizations.calendarRecurrenceWeekdayWednesday,
    CalendarWeekday.thursday => localizations.calendarRecurrenceWeekdayThursday,
    CalendarWeekday.friday => localizations.calendarRecurrenceWeekdayFriday,
    CalendarWeekday.saturday => localizations.calendarRecurrenceWeekdaySaturday,
    CalendarWeekday.sunday => localizations.calendarRecurrenceWeekdaySunday,
  };
}

String calendarRecurrenceWeekdayList(
  AppLocalizations localizations,
  Iterable<CalendarWeekday> weekdays,
) {
  final Set<CalendarWeekday> selected = weekdays.toSet();
  return CalendarWeekday.values
      .where(selected.contains)
      .map(
        (CalendarWeekday weekday) =>
            calendarRecurrenceWeekdayLabel(localizations, weekday),
      )
      .join(', ');
}

final class CalendarRecurrenceEditor extends StatelessWidget {
  const CalendarRecurrenceEditor({
    required this.keyPrefix,
    required this.frequency,
    required this.startLocalDate,
    required this.minimumUntilDate,
    required this.weekdays,
    required this.anchorWeekday,
    required this.intervalController,
    required this.endMode,
    required this.countController,
    required this.untilDate,
    required this.enabled,
    required this.onWeekdaysChanged,
    required this.onInputChanged,
    required this.onEndModeChanged,
    required this.onUntilDateChanged,
    super.key,
  });

  final String keyPrefix;
  final CalendarRecurrenceFrequency frequency;
  final DateTime startLocalDate;
  final DateTime minimumUntilDate;
  final Set<CalendarWeekday> weekdays;
  final CalendarWeekday anchorWeekday;
  final TextEditingController intervalController;
  final CalendarRecurrenceEndMode endMode;
  final TextEditingController countController;
  final DateTime untilDate;
  final bool enabled;
  final ValueChanged<Set<CalendarWeekday>> onWeekdaysChanged;
  final VoidCallback onInputChanged;
  final ValueChanged<CalendarRecurrenceEndMode> onEndModeChanged;
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
        frequency != CalendarRecurrenceFrequency.weekly ||
        weekdays.isNotEmpty &&
            weekdays.length <= CalendarWeekday.values.length &&
            weekdays.contains(anchorWeekday);
    final bool endValid = switch (endMode) {
      CalendarRecurrenceEndMode.never => true,
      CalendarRecurrenceEndMode.count =>
        count != null && count >= 1 && count <= 1000,
      CalendarRecurrenceEndMode.until => !DateUtils.dateOnly(
        untilDate,
      ).isBefore(DateUtils.dateOnly(minimumUntilDate)),
    };
    final String pattern = intervalValid && weekdaysValid
        ? calendarRecurrencePattern(localizations, frequency, interval)
        : localizations.calendarRecurrenceInvalidSummary;
    final String endSummary = endValid
        ? _endSummary(
            localizations,
            material,
            mode: endMode,
            count: count,
            untilDate: untilDate,
          )
        : localizations.calendarRecurrenceInvalidSummary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (frequency == CalendarRecurrenceFrequency.weekly) ...<Widget>[
          Text(
            localizations.calendarRecurrenceWeekdaysLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            key: Key('$keyPrefix.weekdays'),
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: CalendarWeekday.values
                .map((CalendarWeekday weekday) {
                  final bool selected = weekdays.contains(weekday);
                  final bool isAnchor = weekday == anchorWeekday;
                  final Widget chip = ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: AppTouchTarget.minimum,
                      minHeight: AppTouchTarget.minimum,
                    ),
                    child: FilterChip(
                      key: Key('$keyPrefix.weekday.${weekday.wireValue}'),
                      label: Text(
                        calendarRecurrenceWeekdayLabel(localizations, weekday),
                      ),
                      selected: selected,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onSelected: !enabled || isAnchor
                          ? null
                          : (bool value) {
                              final Set<CalendarWeekday> updated =
                                  <CalendarWeekday>{...weekdays};
                              if (value) {
                                updated.add(weekday);
                              } else {
                                updated.remove(weekday);
                              }
                              onWeekdaysChanged(
                                Set<CalendarWeekday>.unmodifiable(updated),
                              );
                            },
                    ),
                  );
                  return isAnchor
                      ? Tooltip(
                          message: localizations
                              .calendarRecurrenceWeekdayAnchorHelper,
                          child: chip,
                        )
                      : chip;
                })
                .toList(growable: false),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            localizations.calendarRecurrenceWeekdayAnchorHelper,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (frequency == CalendarRecurrenceFrequency.monthly) ...<Widget>[
          KeyedSubtree(
            key: Key('$keyPrefix.monthDay'),
            child: DropdownButtonFormField<int>(
              key: ValueKey<int>(startLocalDate.day),
              initialValue: startLocalDate.day,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: localizations.calendarRecurrenceMonthDayLabel,
                helperText:
                    localizations.calendarRecurrenceMonthDayAnchorHelper,
                helperMaxLines: 3,
              ),
              items: List<DropdownMenuItem<int>>.generate(
                31,
                (int index) => DropdownMenuItem<int>(
                  value: index + 1,
                  child: Text(
                    localizations.calendarRecurrenceMonthDayOption(index + 1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              onChanged: null,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            localizations.calendarRecurrenceMonthDayMissingDateHelper,
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
            labelText: localizations.calendarRecurrenceIntervalLabel,
            helperText: localizations.calendarRecurrenceIntervalHelper,
            counterText: '',
          ),
          validator: (String? value) {
            final int? parsed = int.tryParse(value?.trim() ?? '');
            return parsed == null || parsed < 1 || parsed > 30
                ? localizations.calendarRecurrenceIntervalValidation
                : null;
          },
          onChanged: (_) => onInputChanged(),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<CalendarRecurrenceEndMode>(
          key: Key('$keyPrefix.end'),
          initialValue: endMode,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: localizations.calendarRecurrenceEndLabel,
          ),
          items: CalendarRecurrenceEndMode.values
              .map(
                (CalendarRecurrenceEndMode mode) =>
                    DropdownMenuItem<CalendarRecurrenceEndMode>(
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
              : (CalendarRecurrenceEndMode? value) {
                  if (value != null) {
                    onEndModeChanged(value);
                  }
                },
        ),
        if (endMode == CalendarRecurrenceEndMode.count) ...<Widget>[
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
              labelText: localizations.calendarRecurrenceCountLabel,
              helperText: localizations.calendarRecurrenceCountHelper,
              counterText: '',
            ),
            validator: (String? value) {
              final int? parsed = int.tryParse(value?.trim() ?? '');
              return parsed == null || parsed < 1 || parsed > 1000
                  ? localizations.calendarRecurrenceCountValidation
                  : null;
            },
            onChanged: (_) => onInputChanged(),
          ),
        ],
        if (endMode == CalendarRecurrenceEndMode.until) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          ListTile(
            key: Key('$keyPrefix.until'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(localizations.calendarRecurrenceUntilDateLabel),
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
                  localizations.calendarRecurrenceEditorSummary(
                    pattern,
                    material.formatFullDate(startLocalDate),
                  ),
                ),
                if (frequency == CalendarRecurrenceFrequency.weekly &&
                    weekdaysValid) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    localizations.calendarRecurrenceWeekdaysSummary(
                      calendarRecurrenceWeekdayList(localizations, weekdays),
                    ),
                  ),
                ],
                if (frequency ==
                    CalendarRecurrenceFrequency.monthly) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    localizations.calendarRecurrenceMonthDaySummary(
                      startLocalDate.day,
                    ),
                  ),
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

  Future<void> _chooseUntilDate(BuildContext context) async {
    final DateTime minimum = DateUtils.dateOnly(minimumUntilDate);
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

  String _endModeLabel(
    AppLocalizations localizations,
    CalendarRecurrenceEndMode mode,
  ) {
    return switch (mode) {
      CalendarRecurrenceEndMode.never =>
        localizations.calendarRecurrenceEndNever,
      CalendarRecurrenceEndMode.count =>
        localizations.calendarRecurrenceEndAfterCount,
      CalendarRecurrenceEndMode.until =>
        localizations.calendarRecurrenceEndOnDate,
    };
  }

  String _endSummary(
    AppLocalizations localizations,
    MaterialLocalizations material, {
    required CalendarRecurrenceEndMode mode,
    required int? count,
    required DateTime untilDate,
  }) {
    return switch (mode) {
      CalendarRecurrenceEndMode.never =>
        localizations.calendarRecurrenceEndNeverSummary,
      CalendarRecurrenceEndMode.count =>
        localizations.calendarRecurrenceEndCountSummary(count!),
      CalendarRecurrenceEndMode.until =>
        localizations.calendarRecurrenceEndUntilSummary(
          material.formatFullDate(untilDate),
        ),
    };
  }
}
