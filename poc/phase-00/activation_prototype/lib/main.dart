import 'package:flutter/material.dart';

import 'activation_model.dart';

void main() {
  runApp(const KinFlowActivationApp());
}

class KinFlowActivationApp extends StatefulWidget {
  const KinFlowActivationApp({super.key, this.model});

  final ActivationModel? model;

  @override
  State<KinFlowActivationApp> createState() => _KinFlowActivationAppState();
}

class _KinFlowActivationAppState extends State<KinFlowActivationApp> {
  late final ActivationModel _model;
  late final bool _ownsModel;

  @override
  void initState() {
    super.initState();
    _ownsModel = widget.model == null;
    _model = widget.model ?? ActivationModel();
  }

  @override
  void dispose() {
    if (_ownsModel) {
      _model.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2B6B57);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KinFlow Activation PoC',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7F2),
        useMaterial3: true,
        cardTheme: const CardThemeData(margin: EdgeInsets.zero, elevation: 0),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: ActivationHomePage(model: _model),
    );
  }
}

class ActivationHomePage extends StatefulWidget {
  const ActivationHomePage({super.key, required this.model});

  final ActivationModel model;

  @override
  State<ActivationHomePage> createState() => _ActivationHomePageState();
}

class _ActivationHomePageState extends State<ActivationHomePage> {
  final _householdController = TextEditingController();
  final _choreController = TextEditingController();
  AdultActor _newChoreAssignee = AdultActor.coordinator;

  @override
  void dispose() {
    _householdController.dispose();
    _choreController.dispose();
    super.dispose();
  }

  void _createHousehold() {
    widget.model.createHousehold(_householdController.text);
  }

  void _addChore() {
    final added = widget.model.addChore(
      title: _choreController.text,
      assignee: _newChoreAssignee,
    );
    if (added) {
      _choreController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.model,
      builder: (context, _) {
        final model = widget.model;
        return Scaffold(
          appBar: AppBar(
            title: const Text('KinFlow 검증 프로토타입'),
            actions: [
              if (model.householdCreated)
                IconButton(
                  key: const Key('resetButton'),
                  tooltip: '처음부터 다시 시작',
                  onPressed: () {
                    model.reset();
                    _householdController.clear();
                    _choreController.clear();
                  },
                  icon: const Icon(Icons.restart_alt),
                ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HeroHeader(model: model),
                          const SizedBox(height: 16),
                          if (!model.householdCreated)
                            _HouseholdSetupCard(
                              controller: _householdController,
                              onCreate: _createHousehold,
                            )
                          else if (!model.inviteAccepted)
                            _InviteCard(onAccept: model.acceptInvite)
                          else ...[
                            _ActorSwitcher(model: model),
                            const SizedBox(height: 12),
                            _ProgressCard(model: model),
                            const SizedBox(height: 12),
                            _ChoreComposer(
                              controller: _choreController,
                              assignee: _newChoreAssignee,
                              onAssigneeChanged: (actor) {
                                setState(() => _newChoreAssignee = actor);
                              },
                              onAdd: _addChore,
                              onSeed: model.seedRecommendedChores,
                              showSeed: model.chores.isEmpty,
                            ),
                            const SizedBox(height: 12),
                            _ChoreList(model: model),
                            if (model.canVisitNextDay) ...[
                              const SizedBox(height: 12),
                              _NextDayCard(model: model),
                            ],
                            if (model.isActivated) ...[
                              const SizedBox(height: 12),
                              const _ActivationSuccessCard(),
                            ],
                            const SizedBox(height: 12),
                            _EventLog(model: model),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.model});

  final ActivationModel model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            model.householdCreated ? model.householdName : '성인 두 명이 함께 움직이는가?',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            model.householdCreated
                ? '한 기기에서 성인 역할을 바꿔가며 Activation 루프를 검증합니다.'
                : '가구 생성부터 다음 날 재방문까지, 가장 작은 가치 루프만 확인합니다.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}

class _HouseholdSetupCard extends StatelessWidget {
  const _HouseholdSetupCard({required this.controller, required this.onCreate});

  final TextEditingController controller;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '1. 우리 가구 만들기',
      subtitle: '실명 대신 인터뷰용 가구 별칭을 사용하세요.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('householdNameField'),
            controller: controller,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onCreate(),
            decoration: const InputDecoration(
              labelText: '가구 별칭',
              hintText: '예: 초록집',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('createHouseholdButton'),
            onPressed: onCreate,
            icon: const Icon(Icons.home_outlined),
            label: const Text('가구 만들기'),
          ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.onAccept});

  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '2. 두 번째 성인 초대',
      subtitle: '실제 링크 전송 대신 수락 순간과 안내 문구가 이해되는지 확인합니다.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.link),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '초대 코드 KINFLOW-2A\n성인 2가 이 가구의 집안일을 함께 볼 수 있습니다.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('acceptInviteButton'),
            onPressed: onAccept,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('성인 2의 초대 수락 시뮬레이션'),
          ),
        ],
      ),
    );
  }
}

class _ActorSwitcher extends StatelessWidget {
  const _ActorSwitcher({required this.model});

  final ActivationModel model;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '현재 사용 중인 성인',
      subtitle: '각 성인이 자기 담당 항목을 직접 완료해야 합니다.',
      child: Row(
        children: AdultActor.values.map((actor) {
          final selected = model.activeActor == actor;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: actor == AdultActor.coordinator ? 6 : 0,
                left: actor == AdultActor.invitedAdult ? 6 : 0,
              ),
              child: selected
                  ? FilledButton(
                      key: Key('actor-${actor.name}'),
                      onPressed: () => model.switchActor(actor),
                      child: Text(actor.label),
                    )
                  : OutlinedButton(
                      key: Key('actor-${actor.name}'),
                      onPressed: () => model.switchActor(actor),
                      child: Text(actor.label),
                    ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.model});

  final ActivationModel model;

  @override
  Widget build(BuildContext context) {
    final steps = <({String label, bool done})>[
      (label: '가구 생성', done: model.householdCreated),
      (label: '성인 2 초대 수락', done: model.inviteAccepted),
      (label: '집안일 3개 생성', done: model.hasMinimumChores),
      (label: '두 성인 모두 완료', done: model.bothAdultsCompleted),
      (label: '다음 날 Today 재방문', done: model.nextDayVisited),
    ];

    return _SectionCard(
      title: 'Activation ${model.completedStepCount}/5',
      subtitle: '완료 수가 아니라 두 번째 성인의 독립 행동이 핵심입니다.',
      child: Column(
        children: [
          LinearProgressIndicator(value: model.completedStepCount / 5),
          const SizedBox(height: 12),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    step.done ? Icons.check_circle : Icons.circle_outlined,
                    color: step.done
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(step.label),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoreComposer extends StatelessWidget {
  const _ChoreComposer({
    required this.controller,
    required this.assignee,
    required this.onAssigneeChanged,
    required this.onAdd,
    required this.onSeed,
    required this.showSeed,
  });

  final TextEditingController controller;
  final AdultActor assignee;
  final ValueChanged<AdultActor> onAssigneeChanged;
  final VoidCallback onAdd;
  final VoidCallback onSeed;
  final bool showSeed;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '3. 집안일 만들기',
      subtitle: '최소 세 개를 만들고 두 성인에게 나눠 주세요.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showSeed) ...[
            OutlinedButton.icon(
              key: const Key('seedChoresButton'),
              onPressed: onSeed,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('추천 집안일 3개로 빠르게 시작'),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('또는 직접 입력'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
            ),
          ],
          TextField(
            key: const Key('choreTitleField'),
            controller: controller,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onAdd(),
            decoration: const InputDecoration(
              labelText: '집안일',
              hintText: '예: 식탁 닦기',
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<AdultActor>(
            segments: AdultActor.values
                .map(
                  (actor) => ButtonSegment<AdultActor>(
                    value: actor,
                    label: Text(actor.label),
                  ),
                )
                .toList(),
            selected: {assignee},
            onSelectionChanged: (selection) {
              onAssigneeChanged(selection.single);
            },
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const Key('addChoreButton'),
            onPressed: onAdd,
            icon: const Icon(Icons.add_task),
            label: const Text('집안일 추가'),
          ),
        ],
      ),
    );
  }
}

class _ChoreList extends StatelessWidget {
  const _ChoreList({required this.model});

  final ActivationModel model;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '오늘의 집안일 ${model.chores.length}개',
      subtitle: '${model.activeActor.label} 화면입니다.',
      child: model.chores.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('아직 집안일이 없습니다.'),
            )
          : Column(
              children: model.chores.map((chore) {
                final canComplete = model.canComplete(chore);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(child: Text(chore.assignee.shortLabel)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                chore.title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      decoration: chore.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                              ),
                              Text(
                                chore.isCompleted
                                    ? '${chore.completedBy!.label} 완료'
                                    : '${chore.assignee.label} 담당',
                              ),
                            ],
                          ),
                        ),
                        if (chore.isCompleted)
                          const Icon(Icons.check_circle, color: Colors.green)
                        else
                          FilledButton.tonal(
                            key: Key('complete-${chore.id}'),
                            onPressed: canComplete
                                ? () => model.completeChore(chore.id)
                                : null,
                            child: const Text('완료'),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _NextDayCard extends StatelessWidget {
  const _NextDayCard({required this.model});

  final ActivationModel model;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '4. 다음 날 다시 열기',
      subtitle: '인터뷰 진행자가 하루가 지난 상황을 설명한 뒤 눌러 주세요.',
      child: FilledButton.icon(
        key: const Key('nextDayButton'),
        onPressed: model.nextDayVisited ? null : model.visitNextDayToday,
        icon: const Icon(Icons.wb_sunny_outlined),
        label: Text(model.nextDayVisited ? '재방문 기록 완료' : '다음 날 Today 열기'),
      ),
    );
  }
}

class _ActivationSuccessCard extends StatelessWidget {
  const _ActivationSuccessCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('activationComplete'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(Icons.celebration, size: 42, color: colors.primary),
          const SizedBox(height: 8),
          Text(
            'Activation 루프 완료',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            '두 번째 성인이 왜 참여했는지, 다시 쓸 이유가 있었는지 지금 질문하세요.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EventLog extends StatelessWidget {
  const _EventLog({required this.model});

  final ActivationModel model;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: const Text('관찰용 로컬 이벤트'),
        subtitle: const Text('외부 전송·저장 없음'),
        children: model.events
            .map(
              (event) => ListTile(
                dense: true,
                leading: const Icon(Icons.bolt, size: 18),
                title: Text(event),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
