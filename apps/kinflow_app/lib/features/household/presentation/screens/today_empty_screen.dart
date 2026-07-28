import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class TodayEmptyScreen extends ConsumerWidget {
  const TodayEmptyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);

    return AppResponsiveScaffold(
      key: const Key('today.screen'),
      title: localizations.todayTitle,
      actions: <Widget>[
        IconButton(
          key: const Key('auth.logout'),
          onPressed: () =>
              unawaited(ref.read(authLifecycleProvider.notifier).logout()),
          tooltip: localizations.authLogoutAction,
          icon: const Icon(Icons.logout),
        ),
      ],
      body: ScrollableStatusLayout(
        child: Column(
          key: const Key('today.empty'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(
                Icons.today_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: AppIconSize.status,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              header: true,
              child: Text(
                localizations.todayEmptyTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(localizations.todayEmptyBody, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
