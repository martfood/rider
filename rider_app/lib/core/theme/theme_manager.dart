import 'package:flutter/material.dart';

/// Manages application-wide dynamic theme switching (Light / Dark / System).
class ThemeManager {
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier(ThemeMode.system);
}
