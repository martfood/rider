import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/widgets/rider_bottom_nav_bar.dart';

/// Scaffold hosting the four main tabs via [StatefulNavigationShell].
class RiderShellScreen extends StatelessWidget {
  /// Shell provided by [StatefulShellRoute.indexedStack].
  final StatefulNavigationShell navigationShell;

  /// Creates the rider tab shell.
  const RiderShellScreen({
    super.key,
    required this.navigationShell,
  });

  void _onTabSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: RiderBottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}
