import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/presentation/focus_highlight_policy.dart';
import 'package:kinflow_app/app/presentation/widgets/app_modal_route.dart';
import 'package:kinflow_app/app/theme/app_theme.dart';

void main() {
  testWidgets(
    'dialog traps Tab and Shift+Tab, activates with Enter, and returns focus',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const _ModalKeyboardHarness()),
      );
      final _ModalKeyboardHarnessState state = tester.state(
        find.byType(_ModalKeyboardHarness),
      );

      state.dialogOpener.requestFocus();
      await tester.pump();
      expect(state.dialogOpener.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('focus.dialog')), findsOneWidget);
      expect(state.dialogOpener.hasFocus, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(state.dialogCancel.hasFocus, isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(state.dialogConfirm.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('focus.dialog')), findsNothing);
      expect(state.dialogResult, isTrue);
      expect(state.dialogOpener.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('focus.dialog')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('focus.dialog')), findsNothing);
      expect(state.dialogResult, isNull);
      expect(state.dialogOpener.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('modal sheet traps keyboard traversal and returns focus', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const _ModalKeyboardHarness()),
    );
    final _ModalKeyboardHarnessState state = tester.state(
      find.byType(_ModalKeyboardHarness),
    );

    state.sheetOpener.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('focus.sheet')), findsOneWidget);
    expect(state.sheetOpener.hasFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(state.sheetCancel.hasFocus, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(state.sheetConfirm.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('focus.sheet')), findsNothing);
    expect(state.sheetOpener.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Web focus policy uses traditional highlights', (
    WidgetTester tester,
  ) async {
    final FocusHighlightStrategy original =
        FocusManager.instance.highlightStrategy;
    addTearDown(() {
      FocusManager.instance.highlightStrategy = original;
    });

    configurePlatformFocusHighlightStrategy(platformIsWeb: true);

    expect(
      FocusManager.instance.highlightStrategy,
      FocusHighlightStrategy.alwaysTraditional,
    );
    expect(FocusManager.instance.highlightMode, FocusHighlightMode.traditional);
    expect(
      AppTheme.light.focusColor,
      AppTheme.light.colorScheme.primary.withValues(alpha: 0.24),
    );
  });
}

class _ModalKeyboardHarness extends StatefulWidget {
  const _ModalKeyboardHarness();

  @override
  State<_ModalKeyboardHarness> createState() => _ModalKeyboardHarnessState();
}

class _ModalKeyboardHarnessState extends State<_ModalKeyboardHarness> {
  final FocusNode dialogCancel = FocusNode(debugLabel: 'dialog cancel');
  final FocusNode dialogConfirm = FocusNode(debugLabel: 'dialog confirm');
  final FocusNode dialogOpener = FocusNode(debugLabel: 'dialog opener');
  final FocusNode sheetCancel = FocusNode(debugLabel: 'sheet cancel');
  final FocusNode sheetConfirm = FocusNode(debugLabel: 'sheet confirm');
  final FocusNode sheetOpener = FocusNode(debugLabel: 'sheet opener');

  bool? dialogResult;

  @override
  void dispose() {
    dialogCancel.dispose();
    dialogConfirm.dispose();
    dialogOpener.dispose();
    sheetCancel.dispose();
    sheetConfirm.dispose();
    sheetOpener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FilledButton(
              key: const Key('focus.dialogOpener'),
              focusNode: dialogOpener,
              onPressed: _openDialog,
              child: const Text('Open dialog'),
            ),
            FilledButton(
              key: const Key('focus.sheetOpener'),
              focusNode: sheetOpener,
              onPressed: _openSheet,
              child: const Text('Open sheet'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDialog() async {
    final bool? result = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        key: const Key('focus.dialog'),
        title: const Text('Confirm'),
        actions: <Widget>[
          TextButton(
            key: const Key('focus.dialogCancel'),
            focusNode: dialogCancel,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('focus.dialogConfirm'),
            focusNode: dialogConfirm,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (mounted) {
      setState(() {
        dialogResult = result;
      });
    }
  }

  Future<void> _openSheet() async {
    await showAppModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          key: const Key('focus.sheet'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextButton(
              key: const Key('focus.sheetCancel'),
              focusNode: sheetCancel,
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('focus.sheetConfirm'),
              focusNode: sheetConfirm,
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
