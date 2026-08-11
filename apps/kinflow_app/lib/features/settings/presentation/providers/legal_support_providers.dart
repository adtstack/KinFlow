import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/settings/application/ports/legal_support_resource_launcher.dart';
import 'package:kinflow_app/features/settings/application/unavailable_legal_support_resource_launcher.dart';

final legalSupportResourceLauncherProvider =
    Provider<LegalSupportResourceLauncher>((ref) {
      return const UnavailableLegalSupportResourceLauncher();
    });
