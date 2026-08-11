import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Keeps keyboard focus indicators visible in the Web Companion.
///
/// The optional override exists so the policy can be verified without launching
/// a browser engine. Native platforms retain Flutter's automatic input policy.
void configurePlatformFocusHighlightStrategy({bool platformIsWeb = kIsWeb}) {
  if (!platformIsWeb) {
    return;
  }
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
}
