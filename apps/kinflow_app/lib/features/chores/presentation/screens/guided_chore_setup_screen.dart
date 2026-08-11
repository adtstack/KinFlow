import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/widgets/app_modal_route.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/chores/application/guided_chore_setup_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_template.dart';
import 'package:kinflow_app/features/chores/domain/entities/guided_chore_setup.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/chores/presentation/chore_failure_message.dart';
import 'package:kinflow_app/features/chores/presentation/chore_template_localization.dart';
import 'package:kinflow_app/features/chores/presentation/providers/chore_providers.dart';
import 'package:kinflow_app/features/chores/presentation/widgets/chore_recurrence_editor.dart';
import 'package:kinflow_app/features/chores/presentation/widgets/chore_template_browser.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class GuidedChoreSetupScreen extends ConsumerStatefulWidget {
  const GuidedChoreSetupScreen({super.key});

  @override
  ConsumerState<GuidedChoreSetupScreen> createState() =>
      _GuidedChoreSetupScreenState();
}

class _GuidedChoreSetupScreenState
    extends ConsumerState<GuidedChoreSetupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Set<ChoreTemplatePreset> _selected = <ChoreTemplatePreset>{};
  late final Map<ChoreTemplatePreset, TextEditingController> _titleControllers =
      <ChoreTemplatePreset, TextEditingController>{
        for (final ChoreTemplatePreset template
            in ChoreTemplateCatalog.templates)
          template: TextEditingController(),
      };
  late final Map<ChoreTemplatePreset, ChoreRecurrenceFrequency> _frequencies =
      <ChoreTemplatePreset, ChoreRecurrenceFrequency>{
        for (final ChoreTemplatePreset template
            in ChoreTemplateCatalog.templates)
          template: _suggestedFrequency(template),
      };
  late final Map<ChoreTemplatePreset, TextEditingController>
  _intervalControllers = <ChoreTemplatePreset, TextEditingController>{
    for (final ChoreTemplatePreset template in ChoreTemplateCatalog.templates)
      template: TextEditingController(text: '1'),
  };
  late final Map<ChoreTemplatePreset, TextEditingController> _countControllers =
      <ChoreTemplatePreset, TextEditingController>{
        for (final ChoreTemplatePreset template
            in ChoreTemplateCatalog.templates)
          template: TextEditingController(text: '10'),
      };
  final Map<ChoreTemplatePreset, Set<ChoreWeekday>> _weekdays =
      <ChoreTemplatePreset, Set<ChoreWeekday>>{};
  final Map<ChoreTemplatePreset, int> _monthDays = <ChoreTemplatePreset, int>{};
  final Map<ChoreTemplatePreset, ChoreRecurrenceEndMode> _endModes =
      <ChoreTemplatePreset, ChoreRecurrenceEndMode>{};
  final Map<ChoreTemplatePreset, DateTime> _untilDates =
      <ChoreTemplatePreset, DateTime>{};
  var _loadRequested = false;
  var _successHandled = false;
  String? _appliedFrozenFingerprint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _titleControllers.values) {
      controller.dispose();
    }
    for (final TextEditingController controller
        in _intervalControllers.values) {
      controller.dispose();
    }
    for (final TextEditingController controller in _countControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _load({bool force = false}) {
    if (!mounted || (_loadRequested && !force)) {
      return;
    }
    final ActiveHousehold? household = ref
        .read(authLifecycleProvider)
        .activeHousehold;
    if (household == null) {
      context.go(AppRoutes.home);
      return;
    }
    _loadRequested = true;
    unawaited(
      ref
          .read(guidedChoreSetupProvider.notifier)
          .load(
            householdId: household.householdId,
            assigneeMemberId: household.memberId,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final GuidedChoreSetupState state = ref.watch(guidedChoreSetupProvider);
    final List<GuidedChoreSetupInput> frozenInputs = switch (state) {
      GuidedChoreSetupSubmitting(:final frozenInputs) => frozenInputs,
      GuidedChoreSetupSubmissionFailed(:final frozenInputs) => frozenInputs,
      _ => const <GuidedChoreSetupInput>[],
    };
    final ChoreLocalDate? frozenStartLocalDate = switch (state) {
      GuidedChoreSetupSubmitting(:final startLocalDate) => startLocalDate,
      GuidedChoreSetupSubmissionFailed(:final startLocalDate) => startLocalDate,
      _ => null,
    };
    _scheduleApplyFrozenInputs(frozenInputs, frozenStartLocalDate);
    final bool submitting = state is GuidedChoreSetupSubmitting;
    final int completedCount = switch (state) {
      GuidedChoreSetupSubmitting(:final completedCount) => completedCount,
      GuidedChoreSetupSubmissionFailed(:final completedCount) => completedCount,
      GuidedChoreSetupSucceeded(:final createdCount) => createdCount,
      _ => 0,
    };
    ref.listen<GuidedChoreSetupState>(guidedChoreSetupProvider, (
      GuidedChoreSetupState? previous,
      GuidedChoreSetupState next,
    ) {
      if (next is GuidedChoreSetupSucceeded) {
        _handleSuccess();
      }
    });

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, void result) {
        if (!didPop && !submitting) {
          unawaited(_confirmExit(completedCount));
        }
      },
      child: AppResponsiveScaffold(
        key: const Key('chore.guided.screen'),
        title: localizations.guidedChoreSetupTitle,
        actions: <Widget>[
          IconButton(
            key: const Key('chore.guided.close'),
            onPressed: submitting
                ? null
                : () => unawaited(_confirmExit(completedCount)),
            tooltip: localizations.guidedChoreSetupSkipAction,
            icon: const Icon(Icons.close),
          ),
        ],
        body: _body(localizations, state),
      ),
    );
  }

  Widget _body(AppLocalizations localizations, GuidedChoreSetupState state) {
    return switch (state) {
      GuidedChoreSetupInitial() ||
      GuidedChoreSetupLoading() => ScrollableStatusLayout(
        child: Column(
          key: const Key('chore.guided.loading'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              localizations.guidedChoreSetupLoading,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      GuidedChoreSetupLoadFailed(:final failure) => ScrollableStatusLayout(
        child: Column(
          key: const Key('chore.guided.loadError'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.sync_problem_outlined, size: AppIconSize.status),
            const SizedBox(height: AppSpacing.md),
            Text(
              choreFailureMessage(localizations, failure),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('chore.guided.loadRetry'),
              onPressed: () => _load(force: true),
              icon: const Icon(Icons.refresh),
              label: Text(localizations.retryAction),
            ),
          ],
        ),
      ),
      GuidedChoreSetupReady(:final startLocalDate, :final householdTimezone) =>
        _form(
          localizations,
          startLocalDate: startLocalDate,
          householdTimezone: householdTimezone,
          completedCount: 0,
          submitting: false,
          failure: null,
          draftFrozen: false,
          resumed: false,
        ),
      GuidedChoreSetupSubmitting(
        :final startLocalDate,
        :final householdTimezone,
        :final completedCount,
        :final resumed,
      ) =>
        _form(
          localizations,
          startLocalDate: startLocalDate,
          householdTimezone: householdTimezone,
          completedCount: completedCount,
          submitting: true,
          failure: null,
          draftFrozen: true,
          resumed: resumed,
        ),
      GuidedChoreSetupSubmissionFailed(
        :final startLocalDate,
        :final householdTimezone,
        :final completedCount,
        :final failure,
        :final draftFrozen,
        :final resumed,
      ) =>
        _form(
          localizations,
          startLocalDate: startLocalDate,
          householdTimezone: householdTimezone,
          completedCount: completedCount,
          submitting: false,
          failure: failure,
          draftFrozen: draftFrozen,
          resumed: resumed,
        ),
      GuidedChoreSetupSucceeded() => ScrollableStatusLayout(
        child: Column(
          key: const Key('chore.guided.success'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.check_circle_outline, size: AppIconSize.status),
            const SizedBox(height: AppSpacing.md),
            Text(
              localizations.guidedChoreSetupAddingProgress(
                GuidedChoreSetupDraft.requiredEntryCount,
                GuidedChoreSetupDraft.requiredEntryCount,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    };
  }

  Widget _form(
    AppLocalizations localizations, {
    required ChoreLocalDate startLocalDate,
    required String householdTimezone,
    required int completedCount,
    required bool submitting,
    required ChoreFailure? failure,
    required bool draftFrozen,
    required bool resumed,
  }) {
    final bool controlsLocked = submitting || draftFrozen;
    final List<ChoreTemplatePreset> selectedTemplates = ChoreTemplateCatalog
        .templates
        .where(_selected.contains)
        .toList(growable: false);
    final String formattedDate = MaterialLocalizations.of(
      context,
    ).formatFullDate(startLocalDate.toDateTime());

    return ScrollableStatusLayout(
      maxWidth: AppLayoutTokens.dialogContentMaxWidth,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                localizations.guidedChoreSetupHeading,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              localizations.guidedChoreSetupBody,
              textAlign: TextAlign.center,
            ),
            if (resumed) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                liveRegion: true,
                child: Container(
                  key: const Key('chore.guided.resumeNotice'),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: AppRadii.medium,
                  ),
                  child: Text(
                    localizations.guidedChoreSetupResumeNotice,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Container(
                key: const Key('chore.guided.progress'),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: AppRadii.medium,
                ),
                child: Text(
                  submitting || failure != null && draftFrozen
                      ? localizations.guidedChoreSetupAddingProgress(
                          completedCount,
                          GuidedChoreSetupDraft.requiredEntryCount,
                        )
                      : localizations.guidedChoreSetupSelectionProgress(
                          _selected.length,
                          GuidedChoreSetupDraft.requiredEntryCount,
                        ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              localizations.guidedChoreSetupDefaultsBody(
                formattedDate,
                householdTimezone,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              header: true,
              child: Text(
                localizations.choreTemplatesHeading,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(localizations.guidedChoreSetupChooseBody),
            const SizedBox(height: AppSpacing.sm),
            ChoreTemplateBrowser(
              keyPrefix: 'chore.guided',
              selectedTemplates: Set<ChoreTemplatePreset>.unmodifiable(
                _selected,
              ),
              multiSelect: true,
              selectionEnabled: !controlsLocked,
              canSelect: (_) =>
                  _selected.length < GuidedChoreSetupDraft.requiredEntryCount,
              onSelected: (ChoreTemplatePreset template, bool selected) =>
                  _setSelected(
                    localizations,
                    template,
                    startLocalDate: startLocalDate,
                    selected: selected,
                  ),
            ),
            if (selectedTemplates.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                header: true,
                child: Text(
                  localizations.guidedChoreSetupReviewHeading,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final ChoreTemplatePreset template
                  in selectedTemplates) ...<Widget>[
                _entryCard(
                  localizations,
                  template,
                  startLocalDate: startLocalDate,
                  controlsLocked: controlsLocked,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
            if (failure != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  choreFailureMessage(localizations, failure),
                  key: const Key('chore.guided.error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('chore.guided.submit'),
              onPressed:
                  submitting ||
                      _selected.length !=
                          GuidedChoreSetupDraft.requiredEntryCount
                  ? null
                  : () => _submit(startLocalDate),
              icon: submitting
                  ? const SizedBox.square(
                      dimension: AppSpacing.md,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(draftFrozen ? Icons.refresh : Icons.add_task),
              label: Text(
                submitting
                    ? localizations.guidedChoreSetupAddingProgress(
                        completedCount,
                        GuidedChoreSetupDraft.requiredEntryCount,
                      )
                    : draftFrozen
                    ? localizations.guidedChoreSetupRetryAction
                    : localizations.guidedChoreSetupAddAction,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              key: const Key('chore.guided.skip'),
              onPressed: submitting
                  ? null
                  : () => unawaited(_confirmExit(completedCount)),
              child: Text(
                completedCount > 0
                    ? localizations.guidedChoreSetupContinueTodayAction
                    : localizations.guidedChoreSetupSkipAction,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryCard(
    AppLocalizations localizations,
    ChoreTemplatePreset template, {
    required ChoreLocalDate startLocalDate,
    required bool controlsLocked,
  }) {
    _ensureRecurrenceState(template, startLocalDate);
    final DateTime startDate = startLocalDate.toDateTime();
    final ChoreWeekday requiredWeekday = ChoreWeekday.fromDateTime(startDate);
    return Card(
      key: Key('chore.guided.entry.${template.stableKey}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: <Widget>[
            TextFormField(
              key: Key('chore.guided.title.${template.stableKey}'),
              controller: _titleControllers[template],
              enabled: !controlsLocked,
              maxLength: 160,
              decoration: InputDecoration(
                labelText: localizations.choreTitleLabel,
              ),
              validator: (String? value) {
                final String title = value?.trim() ?? '';
                if (title.isEmpty ||
                    title.length > 160 ||
                    RegExp(r'[\x00-\x1f\x7f]').hasMatch(title)) {
                  return localizations.choreTitleValidation;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<ChoreRecurrenceFrequency>(
              key: Key('chore.guided.repeat.${template.stableKey}'),
              initialValue: _frequencies[template],
              isExpanded: true,
              decoration: InputDecoration(
                labelText: localizations.choreRecurrenceLabel,
              ),
              items: ChoreRecurrenceFrequency.values
                  .map((ChoreRecurrenceFrequency frequency) {
                    return DropdownMenuItem<ChoreRecurrenceFrequency>(
                      value: frequency,
                      child: Text(
                        _frequencyLabel(localizations, frequency),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  })
                  .toList(growable: false),
              onChanged: controlsLocked
                  ? null
                  : (ChoreRecurrenceFrequency? value) {
                      if (value != null) {
                        setState(() {
                          _frequencies[template] = value;
                          if (value == ChoreRecurrenceFrequency.weekly) {
                            _weekdays[template]!.add(requiredWeekday);
                          } else if (value ==
                              ChoreRecurrenceFrequency.monthly) {
                            _monthDays[template] = startDate.day;
                          }
                        });
                      }
                    },
            ),
            const SizedBox(height: AppSpacing.sm),
            ChoreRecurrenceEditor(
              keyPrefix: 'chore.guided.recurrence.${template.stableKey}',
              frequency: _frequencies[template]!,
              startLocalDate: startDate,
              weekdays: Set<ChoreWeekday>.unmodifiable(_weekdays[template]!),
              requiredWeekday: requiredWeekday,
              monthDay: _monthDays[template]!,
              monthDayEditable: false,
              intervalController: _intervalControllers[template]!,
              endMode: _endModes[template]!,
              countController: _countControllers[template]!,
              untilDate: _untilDates[template]!,
              enabled: !controlsLocked,
              onWeekdaysChanged: (Set<ChoreWeekday> value) {
                setState(() {
                  _weekdays[template] = <ChoreWeekday>{...value};
                });
              },
              onMonthDayChanged: (_) {},
              onInputChanged: () {
                if (mounted) {
                  setState(() {});
                }
              },
              onEndModeChanged: (ChoreRecurrenceEndMode value) {
                setState(() {
                  _endModes[template] = value;
                  if (value == ChoreRecurrenceEndMode.until &&
                      _untilDates[template]!.isBefore(startDate)) {
                    _untilDates[template] = startDate;
                  }
                });
              },
              onUntilDateChanged: (DateTime value) {
                setState(() => _untilDates[template] = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _setSelected(
    AppLocalizations localizations,
    ChoreTemplatePreset template, {
    required ChoreLocalDate startLocalDate,
    required bool selected,
  }) {
    setState(() {
      if (selected) {
        _selected.add(template);
        _titleControllers[template]!.text = localizedChoreTemplateTitle(
          localizations,
          template,
        );
        _resetRecurrenceState(template, startLocalDate);
      } else {
        _selected.remove(template);
        _titleControllers[template]!.clear();
        _resetRecurrenceState(template, startLocalDate);
      }
    });
  }

  Future<void> _submit(ChoreLocalDate startLocalDate) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    final List<GuidedChoreSetupInput> inputs = <GuidedChoreSetupInput>[];
    for (final ChoreTemplatePreset template
        in ChoreTemplateCatalog.templates.where(_selected.contains)) {
      final ChoreRecurrenceRule? recurrenceRule = _recurrenceRuleFor(
        template,
        startLocalDate,
      );
      if (recurrenceRule == null) {
        return;
      }
      inputs.add(
        GuidedChoreSetupInput.withRecurrence(
          template: template,
          title: _titleControllers[template]!.text,
          recurrenceRule: recurrenceRule,
        ),
      );
    }
    await ref.read(guidedChoreSetupProvider.notifier).submit(inputs);
  }

  Future<void> _confirmExit(int completedCount) async {
    if (!mounted) {
      return;
    }
    final AppLocalizations localizations = AppLocalizations.of(context);
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          key: const Key('chore.guided.exitDialog'),
          title: Text(localizations.guidedChoreSetupExitTitle),
          content: Text(
            completedCount > 0
                ? localizations.guidedChoreSetupPartialExitBody(completedCount)
                : localizations.guidedChoreSetupExitBody,
          ),
          actions: <Widget>[
            TextButton(
              key: const Key('chore.guided.stay'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(localizations.guidedChoreSetupStayAction),
            ),
            FilledButton(
              key: const Key('chore.guided.confirmExit'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(localizations.guidedChoreSetupContinueTodayAction),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      final bool discarded = await ref
          .read(guidedChoreSetupProvider.notifier)
          .discard();
      if (discarded && mounted) {
        context.go(AppRoutes.today);
      }
    }
  }

  void _scheduleApplyFrozenInputs(
    List<GuidedChoreSetupInput> inputs,
    ChoreLocalDate? startLocalDate,
  ) {
    if (inputs.isEmpty || startLocalDate == null) {
      return;
    }
    final String fingerprint = inputs
        .map(
          (GuidedChoreSetupInput input) =>
              '${input.template.stableKey}\u0000${input.title}\u0000'
              '${input.recurrenceRule?.fingerprint ?? input.frequency.wireValue}',
        )
        .join('\u0001');
    if (_appliedFrozenFingerprint == fingerprint) {
      return;
    }
    _appliedFrozenFingerprint = fingerprint;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _selected
          ..clear()
          ..addAll(inputs.map((GuidedChoreSetupInput input) => input.template));
        for (final GuidedChoreSetupInput input in inputs) {
          _titleControllers[input.template]!.text = input.title;
          final ChoreRecurrenceRule rule =
              input.recurrenceRule ??
              ChoreRecurrenceRule.anchored(
                frequency: input.frequency,
                startLocalDate: startLocalDate,
              );
          _applyRecurrenceRule(input.template, startLocalDate, rule);
        }
      });
    });
  }

  void _ensureRecurrenceState(
    ChoreTemplatePreset template,
    ChoreLocalDate startLocalDate,
  ) {
    if (_weekdays.containsKey(template)) {
      return;
    }
    _resetRecurrenceState(template, startLocalDate);
  }

  void _resetRecurrenceState(
    ChoreTemplatePreset template,
    ChoreLocalDate startLocalDate,
  ) {
    final DateTime startDate = startLocalDate.toDateTime();
    _frequencies[template] = _suggestedFrequency(template);
    _intervalControllers[template]!.text = '1';
    _countControllers[template]!.text = '10';
    _weekdays[template] = <ChoreWeekday>{ChoreWeekday.fromDateTime(startDate)};
    _monthDays[template] = startDate.day;
    _endModes[template] = ChoreRecurrenceEndMode.never;
    _untilDates[template] = startDate;
  }

  ChoreRecurrenceRule? _recurrenceRuleFor(
    ChoreTemplatePreset template,
    ChoreLocalDate startLocalDate,
  ) {
    final ChoreRecurrenceEnd? end = choreRecurrenceEndFromEditor(
      mode: _endModes[template]!,
      countText: _countControllers[template]!.text,
      untilDate: _untilDates[template]!,
    );
    if (end == null) {
      return null;
    }
    ChoreRecurrenceRule? rule = ChoreRecurrenceRule.tryAnchored(
      frequency: _frequencies[template]!,
      startLocalDate: startLocalDate,
      interval: int.tryParse(_intervalControllers[template]!.text.trim()) ?? 0,
      end: end,
    );
    if (rule != null && rule.frequency == ChoreRecurrenceFrequency.weekly) {
      rule = rule.tryWithWeeklyWeekdays(
        weekdays: _weekdays[template]!,
        interval: rule.interval,
        end: rule.end,
        minimumLocalDate: startLocalDate,
        requiredStartLocalDate: startLocalDate,
      );
    }
    return rule;
  }

  void _applyRecurrenceRule(
    ChoreTemplatePreset template,
    ChoreLocalDate startLocalDate,
    ChoreRecurrenceRule rule,
  ) {
    final DateTime startDate = startLocalDate.toDateTime();
    _frequencies[template] = rule.frequency;
    _intervalControllers[template]!.text = rule.interval.toString();
    _weekdays[template] = rule.frequency == ChoreRecurrenceFrequency.weekly
        ? rule.weekdays.toSet()
        : <ChoreWeekday>{ChoreWeekday.fromDateTime(startDate)};
    _monthDays[template] = rule.monthDay ?? startDate.day;
    _endModes[template] = choreRecurrenceEndMode(rule.end);
    _countControllers[template]!.text = switch (rule.end) {
      ChoreRecurrenceCountEnd(:final count) => count.toString(),
      _ => '10',
    };
    _untilDates[template] = switch (rule.end) {
      ChoreRecurrenceUntilEnd(:final localDate) => localDate.toDateTime(),
      _ => startDate,
    };
  }

  void _handleSuccess() {
    if (_successHandled) {
      return;
    }
    _successHandled = true;
    ref.invalidate(todayChoresProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go(AppRoutes.today);
      }
    });
  }

  String _frequencyLabel(
    AppLocalizations localizations,
    ChoreRecurrenceFrequency frequency,
  ) {
    return switch (frequency) {
      ChoreRecurrenceFrequency.daily => localizations.choreRecurrenceDaily,
      ChoreRecurrenceFrequency.weekly => localizations.choreRecurrenceWeekly,
      ChoreRecurrenceFrequency.monthly => localizations.choreRecurrenceMonthly,
    };
  }

  static ChoreRecurrenceFrequency _suggestedFrequency(
    ChoreTemplatePreset template,
  ) {
    return switch (template.suggestedCadence) {
      ChoreTemplateCadence.daily => ChoreRecurrenceFrequency.daily,
      ChoreTemplateCadence.weekly => ChoreRecurrenceFrequency.weekly,
    };
  }
}
