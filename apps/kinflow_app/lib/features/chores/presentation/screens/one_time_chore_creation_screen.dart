import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/chores/application/one_time_chore_creation_state.dart';
import 'package:kinflow_app/features/chores/application/recurring_chore_creation_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_template.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/chores/presentation/chore_failure_message.dart';
import 'package:kinflow_app/features/chores/presentation/chore_template_localization.dart';
import 'package:kinflow_app/features/chores/presentation/providers/chore_providers.dart';
import 'package:kinflow_app/features/chores/presentation/widgets/chore_recurrence_editor.dart';
import 'package:kinflow_app/features/chores/presentation/widgets/chore_template_browser.dart';
import 'package:kinflow_app/features/household/application/household_members_state.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

enum _ChoreRepeatSelection { once, daily, weekly, monthly }

class OneTimeChoreCreationScreen extends ConsumerStatefulWidget {
  const OneTimeChoreCreationScreen({
    required this.initialDueLocalDate,
    super.key,
  });

  final ChoreLocalDate initialDueLocalDate;

  @override
  ConsumerState<OneTimeChoreCreationScreen> createState() =>
      _OneTimeChoreCreationScreenState();
}

class _OneTimeChoreCreationScreenState
    extends ConsumerState<OneTimeChoreCreationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormFieldState<_ChoreRepeatSelection>> _repeatFieldKey =
      GlobalKey<FormFieldState<_ChoreRepeatSelection>>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _recurrenceIntervalController =
      TextEditingController(text: '1');
  final TextEditingController _recurrenceCountController =
      TextEditingController(text: '10');

  late DateTime _dueDate;
  late DateTime _recurrenceUntilDate;
  late Set<ChoreWeekday> _recurrenceWeekdays;
  TimeOfDay? _dueTime;
  HouseholdMemberId? _assigneeMemberId;
  _ChoreRepeatSelection _repeatSelection = _ChoreRepeatSelection.once;
  ChoreRecurrenceEndMode _recurrenceEndMode = ChoreRecurrenceEndMode.never;
  ChoreTemplatePreset? _selectedTemplate;
  var _applyingTemplate = false;
  var _loadRequested = false;
  var _successHandled = false;

  @override
  void initState() {
    super.initState();
    _dueDate = widget.initialDueLocalDate.toDateTime();
    _recurrenceUntilDate = _dueDate;
    _recurrenceWeekdays = <ChoreWeekday>{ChoreWeekday.fromDateTime(_dueDate)};
    _titleController.addListener(_handleTitleChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMembers());
  }

  @override
  void dispose() {
    _titleController.removeListener(_handleTitleChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _recurrenceIntervalController.dispose();
    _recurrenceCountController.dispose();
    super.dispose();
  }

  void _loadMembers({bool force = false}) {
    if (!mounted || (_loadRequested && !force)) {
      return;
    }
    final HouseholdId? householdId = ref
        .read(authLifecycleProvider)
        .activeHousehold
        ?.householdId;
    if (householdId == null) {
      context.go(AppRoutes.home);
      return;
    }
    _loadRequested = true;
    unawaited(ref.read(householdMembersProvider.notifier).load(householdId));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final HouseholdMembersState membersState = ref.watch(
      householdMembersProvider,
    );
    final OneTimeChoreCreationState creationState = ref.watch(
      oneTimeChoreCreationProvider,
    );
    final RecurringChoreCreationState recurringCreationState = ref.watch(
      recurringChoreCreationProvider,
    );
    final bool submitting =
        creationState is OneTimeChoreCreationSubmitting ||
        recurringCreationState is RecurringChoreCreationSubmitting;
    final ChoreFailure? failure = switch ((
      creationState,
      recurringCreationState,
    )) {
      (OneTimeChoreCreationFailed(:final failure), _) => failure,
      (_, RecurringChoreCreationFailed(:final failure)) => failure,
      _ => null,
    };
    ref.listen<OneTimeChoreCreationState>(oneTimeChoreCreationProvider, (
      OneTimeChoreCreationState? previous,
      OneTimeChoreCreationState next,
    ) {
      if (next is OneTimeChoreCreationSucceeded) {
        _handleSuccess(localizations);
      }
    });
    ref.listen<RecurringChoreCreationState>(recurringChoreCreationProvider, (
      RecurringChoreCreationState? previous,
      RecurringChoreCreationState next,
    ) {
      if (next is RecurringChoreCreationSucceeded) {
        _handleSuccess(localizations);
      }
    });

    return AppResponsiveScaffold(
      key: const Key('chore.create.screen'),
      title: localizations.choreCreateTitle,
      actions: <Widget>[
        IconButton(
          key: const Key('chore.create.close'),
          onPressed: submitting ? null : () => context.go(AppRoutes.today),
          tooltip: localizations.memberCancelAction,
          icon: const Icon(Icons.close),
        ),
      ],
      body: _body(
        localizations,
        membersState,
        submitting: submitting,
        failure: failure,
      ),
    );
  }

  Widget _body(
    AppLocalizations localizations,
    HouseholdMembersState membersState, {
    required bool submitting,
    required ChoreFailure? failure,
  }) {
    return switch (membersState) {
      HouseholdMembersInitial() ||
      HouseholdMembersLoading() ||
      HouseholdMembersLeft() => ScrollableStatusLayout(
        child: Column(
          key: const Key('chore.create.membersLoading'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              localizations.membersLoadingLabel,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      HouseholdMembersLoadFailed() ||
      HouseholdMembersDepartureFailed() => ScrollableStatusLayout(
        child: Column(
          key: const Key('chore.create.membersError'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.group_off_outlined, size: AppIconSize.status),
            const SizedBox(height: AppSpacing.md),
            Text(localizations.membersLoadError, textAlign: TextAlign.center),
            if (membersState is HouseholdMembersLoadFailed) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                key: const Key('chore.create.membersRetry'),
                onPressed: () => _loadMembers(force: true),
                icon: const Icon(Icons.refresh),
                label: Text(localizations.retryAction),
              ),
            ],
          ],
        ),
      ),
      HouseholdMembersReady(:final roster) => _form(
        localizations,
        roster,
        submitting: submitting,
        failure: failure,
      ),
    };
  }

  Widget _form(
    AppLocalizations localizations,
    HouseholdMemberRoster roster, {
    required bool submitting,
    required ChoreFailure? failure,
  }) {
    final HouseholdMemberId defaultAssignee = roster.currentMember.id;
    final bool selectedStillExists = roster.members.any(
      (HouseholdMember member) => member.id == _assigneeMemberId,
    );
    final HouseholdMemberId effectiveAssignee = selectedStillExists
        ? _assigneeMemberId!
        : defaultAssignee;
    final MaterialLocalizations material = MaterialLocalizations.of(context);

    return ScrollableStatusLayout(
      maxWidth: AppLayoutTokens.dialogContentMaxWidth,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                localizations.choreCreateHeading,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(localizations.choreCreateBody, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            _templateSection(localizations, submitting: submitting),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              key: const Key('chore.create.title'),
              controller: _titleController,
              enabled: !submitting,
              autofocus: true,
              maxLength: 160,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: localizations.choreTitleLabel,
              ),
              validator: (String? value) {
                final String title = value?.trim() ?? '';
                return title.isEmpty
                    ? localizations.choreTitleValidation
                    : null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const Key('chore.create.description'),
              controller: _descriptionController,
              enabled: !submitting,
              maxLength: 4000,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: localizations.choreDescriptionLabel,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<HouseholdMemberId>(
              key: const Key('chore.create.assignee'),
              initialValue: effectiveAssignee,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: localizations.choreAssigneeLabel,
              ),
              items: roster.members
                  .map(
                    (HouseholdMember member) =>
                        DropdownMenuItem<HouseholdMemberId>(
                          value: member.id,
                          child: Text(
                            member.isCurrentUser
                                ? localizations.choreAssigneeYou(
                                    member.displayName,
                                  )
                                : member.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                  )
                  .toList(growable: false),
              onChanged: submitting
                  ? null
                  : (HouseholdMemberId? value) {
                      setState(() => _assigneeMemberId = value);
                    },
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              key: const Key('chore.create.repeat'),
              child: DropdownButtonFormField<_ChoreRepeatSelection>(
                key: _repeatFieldKey,
                initialValue: _repeatSelection,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: localizations.choreRecurrenceLabel,
                ),
                items: _ChoreRepeatSelection.values
                    .map(
                      (_ChoreRepeatSelection selection) =>
                          DropdownMenuItem<_ChoreRepeatSelection>(
                            value: selection,
                            child: Text(
                              _repeatLabel(localizations, selection),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                    )
                    .toList(growable: false),
                onChanged: submitting
                    ? null
                    : (_ChoreRepeatSelection? value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _repeatSelection = value;
                          if (value == _ChoreRepeatSelection.weekly) {
                            _recurrenceWeekdays.add(
                              ChoreWeekday.fromDateTime(_dueDate),
                            );
                          }
                          if (_recurrenceUntilDate.isBefore(_dueDate)) {
                            _recurrenceUntilDate = _dueDate;
                          }
                          if (!_applyingTemplate) {
                            _selectedTemplate = null;
                          }
                        });
                        if (!_applyingTemplate) {
                          _resetCreationStates();
                        }
                      },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              key: const Key('chore.create.date'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(localizations.choreDueDateLabel),
              subtitle: Text(material.formatFullDate(_dueDate)),
              trailing: const Icon(Icons.chevron_right),
              enabled: !submitting,
              onTap: submitting ? null : _chooseDate,
            ),
            ListTile(
              key: const Key('chore.create.time'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined),
              title: Text(localizations.choreDueTimeLabel),
              subtitle: Text(
                _dueTime == null
                    ? localizations.choreAllDayLabel
                    : material.formatTimeOfDay(_dueTime!),
              ),
              trailing: _dueTime == null
                  ? const Icon(Icons.add)
                  : IconButton(
                      key: const Key('chore.create.clearTime'),
                      onPressed: submitting
                          ? null
                          : () => setState(() => _dueTime = null),
                      tooltip: localizations.choreClearTimeAction,
                      icon: const Icon(Icons.clear),
                    ),
              enabled: !submitting,
              onTap: submitting ? null : _chooseTime,
            ),
            if (_repeatSelection != _ChoreRepeatSelection.once) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              ChoreRecurrenceEditor(
                keyPrefix: 'chore.create.recurrence',
                frequency: _selectedFrequency!,
                startLocalDate: _dueDate,
                weekdays: Set<ChoreWeekday>.unmodifiable(_recurrenceWeekdays),
                requiredWeekday: ChoreWeekday.fromDateTime(_dueDate),
                monthDay: _dueDate.day,
                monthDayEditable: false,
                intervalController: _recurrenceIntervalController,
                endMode: _recurrenceEndMode,
                countController: _recurrenceCountController,
                untilDate: _recurrenceUntilDate,
                enabled: !submitting,
                onWeekdaysChanged: (Set<ChoreWeekday> value) {
                  setState(() {
                    _recurrenceWeekdays = <ChoreWeekday>{...value};
                    _selectedTemplate = null;
                  });
                  _resetCreationStates();
                },
                onMonthDayChanged: (_) {},
                onInputChanged: _handleAdvancedRecurrenceChanged,
                onEndModeChanged: (ChoreRecurrenceEndMode value) {
                  setState(() {
                    _recurrenceEndMode = value;
                    if (value == ChoreRecurrenceEndMode.until &&
                        _recurrenceUntilDate.isBefore(_dueDate)) {
                      _recurrenceUntilDate = _dueDate;
                    }
                    _selectedTemplate = null;
                  });
                  _resetCreationStates();
                },
                onUntilDateChanged: (DateTime value) {
                  setState(() {
                    _recurrenceUntilDate = value;
                    _selectedTemplate = null;
                  });
                  _resetCreationStates();
                },
              ),
            ],
            if (failure != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  choreFailureMessage(localizations, failure),
                  key: const Key('chore.create.error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('chore.create.submit'),
              onPressed: submitting
                  ? null
                  : () => _submit(roster.householdId, effectiveAssignee),
              icon: submitting
                  ? const SizedBox.square(
                      dimension: AppSpacing.md,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_task),
              label: Text(
                submitting
                    ? localizations.choreCreatingAction
                    : localizations.choreCreateAction,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _templateSection(
    AppLocalizations localizations, {
    required bool submitting,
  }) {
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              localizations.choreTemplatesHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(localizations.choreTemplatesBody),
          const SizedBox(height: AppSpacing.sm),
          ChoreTemplateBrowser(
            keyPrefix: 'chore',
            selectedTemplates: _selectedTemplate == null
                ? const <ChoreTemplatePreset>{}
                : <ChoreTemplatePreset>{_selectedTemplate!},
            selectionEnabled: !submitting,
            onSelected: (ChoreTemplatePreset template, bool selected) {
              if (selected) {
                _applyTemplate(localizations, template);
                return;
              }
              setState(() => _selectedTemplate = null);
            },
          ),
        ],
      ),
    );
  }

  void _applyTemplate(
    AppLocalizations localizations,
    ChoreTemplatePreset template,
  ) {
    final _ChoreRepeatSelection repeatSelection =
        switch (template.suggestedCadence) {
          ChoreTemplateCadence.daily => _ChoreRepeatSelection.daily,
          ChoreTemplateCadence.weekly => _ChoreRepeatSelection.weekly,
        };
    _applyingTemplate = true;
    final String title = localizedChoreTemplateTitle(localizations, template);
    _titleController.value = TextEditingValue(
      text: title,
      selection: TextSelection.collapsed(offset: title.length),
    );
    setState(() {
      _selectedTemplate = template;
      _repeatSelection = repeatSelection;
      _recurrenceEndMode = ChoreRecurrenceEndMode.never;
      _recurrenceUntilDate = _dueDate;
      _recurrenceWeekdays = <ChoreWeekday>{ChoreWeekday.fromDateTime(_dueDate)};
    });
    _recurrenceIntervalController.text = '1';
    _recurrenceCountController.text = '10';
    _repeatFieldKey.currentState?.didChange(repeatSelection);
    _applyingTemplate = false;
    _resetCreationStates();
  }

  void _handleTitleChanged() {
    if (_applyingTemplate || _selectedTemplate == null || !mounted) {
      return;
    }
    setState(() => _selectedTemplate = null);
  }

  void _handleAdvancedRecurrenceChanged() {
    if (!mounted) {
      return;
    }
    setState(() => _selectedTemplate = null);
    _resetCreationStates();
  }

  void _resetCreationStates() {
    ref.read(oneTimeChoreCreationProvider.notifier).reset();
    ref.read(recurringChoreCreationProvider.notifier).reset();
  }

  Future<void> _chooseDate() async {
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100, 12, 31),
    );
    if (selected != null && mounted) {
      setState(() {
        _dueDate = selected;
        _recurrenceWeekdays.add(ChoreWeekday.fromDateTime(selected));
        if (_recurrenceUntilDate.isBefore(selected)) {
          _recurrenceUntilDate = selected;
        }
      });
      _resetCreationStates();
    }
  }

  Future<void> _chooseTime() async {
    final TimeOfDay? selected = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (selected != null && mounted) {
      setState(() => _dueTime = selected);
    }
  }

  Future<void> _submit(
    HouseholdId householdId,
    HouseholdMemberId assigneeMemberId,
  ) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final ChoreLocalDate date = ChoreLocalDate.fromDateTime(_dueDate);
    final String? time = _dueTime == null
        ? null
        : '${_dueTime!.hour.toString().padLeft(2, '0')}:'
              '${_dueTime!.minute.toString().padLeft(2, '0')}';
    final ChoreRecurrenceFrequency? frequency = _selectedFrequency;
    if (frequency == null) {
      await ref
          .read(oneTimeChoreCreationProvider.notifier)
          .create(
            householdId: householdId,
            title: _titleController.text,
            description: _descriptionController.text,
            assigneeMemberId: assigneeMemberId,
            dueLocalDate: date.value,
            dueLocalTime: time,
          );
      return;
    }
    final ChoreRecurrenceEnd? recurrenceEnd = choreRecurrenceEndFromEditor(
      mode: _recurrenceEndMode,
      countText: _recurrenceCountController.text,
      untilDate: _recurrenceUntilDate,
    );
    ChoreRecurrenceRule? recurrenceRule = recurrenceEnd == null
        ? null
        : ChoreRecurrenceRule.tryAnchored(
            frequency: frequency,
            startLocalDate: date,
            interval: int.tryParse(_recurrenceIntervalController.text) ?? 0,
            end: recurrenceEnd,
          );
    if (recurrenceRule != null &&
        frequency == ChoreRecurrenceFrequency.weekly) {
      recurrenceRule = recurrenceRule.tryWithWeeklyWeekdays(
        weekdays: _recurrenceWeekdays,
        interval: recurrenceRule.interval,
        end: recurrenceRule.end,
        minimumLocalDate: date,
        requiredStartLocalDate: date,
      );
    }
    if (recurrenceRule == null) {
      return;
    }
    await ref
        .read(recurringChoreCreationProvider.notifier)
        .create(
          householdId: householdId,
          title: _titleController.text,
          description: _descriptionController.text,
          assigneeMemberId: assigneeMemberId,
          startLocalDate: date.value,
          dueLocalTime: time,
          recurrenceRule: recurrenceRule,
        );
  }

  ChoreRecurrenceFrequency? get _selectedFrequency {
    return switch (_repeatSelection) {
      _ChoreRepeatSelection.once => null,
      _ChoreRepeatSelection.daily => ChoreRecurrenceFrequency.daily,
      _ChoreRepeatSelection.weekly => ChoreRecurrenceFrequency.weekly,
      _ChoreRepeatSelection.monthly => ChoreRecurrenceFrequency.monthly,
    };
  }

  String _repeatLabel(
    AppLocalizations localizations,
    _ChoreRepeatSelection selection,
  ) {
    return switch (selection) {
      _ChoreRepeatSelection.once => localizations.choreRecurrenceOnce,
      _ChoreRepeatSelection.daily => localizations.choreRecurrenceDaily,
      _ChoreRepeatSelection.weekly => localizations.choreRecurrenceWeekly,
      _ChoreRepeatSelection.monthly => localizations.choreRecurrenceMonthly,
    };
  }

  void _handleSuccess(AppLocalizations localizations) {
    if (_successHandled) {
      return;
    }
    _successHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(localizations.choreCreatedBody)));
      if (context.canPop()) {
        context.pop(true);
      } else {
        ref.invalidate(todayChoresProvider);
        context.go(AppRoutes.today);
      }
    });
  }
}
