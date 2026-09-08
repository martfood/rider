import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:shared_widgets/widgets/no_internet_overlay.dart';

import 'core/router/app_router.dart';
import 'core/theme/theme_manager.dart';

/// Root widget for the MartFood rider application.
class MartFoodRiderApp extends StatelessWidget {
  /// Creates the rider app root.
  const MartFoodRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager.themeModeNotifier,
      builder: (context, currentThemeMode, child) {
        return MaterialApp.router(
          title: 'MartFood Rider',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentThemeMode,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            final size = mediaQuery.size;
            final diagonal =
                math.sqrt(size.width * size.width + size.height * size.height);

            // ── DEVICE DETECTION (MOBILE vs TABLET 8.7"+) ───────────────────
            // In Flutter, MediaQuery.size is in logical pixels (dp).
            // • Phones (5.0"–6.8"): shortestSide is 360–440 dp (diagonal < 1000 dp).
            // • Tablets (8.7"+): shortestSide is >= 500 dp or diagonal >= 1000 dp.
            final isTablet = size.shortestSide >= 500 || diagonal >= 1000;

            // ── GLOBAL FONT SCALING (MOBILE & TABLET) ────────────────────────
            // Tablet (>= 8.7 inches): 1.6
            // Mobile (< 8.7 inches):  1.0
            final scaleFactor = isTablet ? 1.4 : 1.0;

            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(scaleFactor),
              ),
              child: ConnectivityWrapper(
                onGoHome: () => appRouter.go('/home'),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          routerConfig: appRouter,
        );
      },
    );
  }
}
