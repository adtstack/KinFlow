import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/app/presentation/widgets/app_bootstrap_gate.dart';
import 'package:kinflow_app/app/presentation/widgets/environment_banner.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_theme.dart';
import 'package:kinflow_app/features/analytics/presentation/widgets/analytics_lifecycle_host.dart';
import 'package:kinflow_app/features/auth/presentation/widgets/auth_session_lifecycle_host.dart';
import 'package:kinflow_app/features/billing/presentation/widgets/billing_lifecycle_host.dart';
import 'package:kinflow_app/features/notifications/presentation/widgets/notification_center_lifecycle_host.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';
import 'package:kinflow_app/features/notifications/presentation/widgets/notification_push_lifecycle_host.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/widgets/app_runtime_policy_lifecycle_host.dart';
import 'package:kinflow_app/features/settings/presentation/widgets/profile_preferences_lifecycle_host.dart';

class KinFlowApp extends ConsumerWidget {
  const KinFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(appEnvironmentProvider);
    final locale = ref.watch(appLocaleProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      builder: (BuildContext context, Widget? child) {
        return EnvironmentBanner(
          environment: environment,
          child: AuthSessionLifecycleHost(
            child: AnalyticsLifecycleHost(
              child: AppRuntimePolicyLifecycleHost(
                child: ProfilePreferencesLifecycleHost(
                  child: BillingLifecycleHost(
                    child: NotificationPushLifecycleHost(
                      child: NotificationCenterLifecycleHost(
                        child: AppBootstrapGate(
                          child: child ?? const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      darkTheme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      onGenerateTitle: (BuildContext context) {
        return AppLocalizations.of(context).appTitle;
      },
      routerConfig: router,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      themeMode: ThemeMode.system,
    );
  }
}
