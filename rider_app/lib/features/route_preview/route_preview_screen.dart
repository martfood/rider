import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_widgets/widgets/custom_button.dart';
import 'package:shared_widgets/widgets/custom_text_field.dart';
import 'package:shared_widgets/widgets/map_placeholder.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

/// Preview pickup → drop-off with Map placeholder (frontend only).
class RoutePreviewScreen extends ConsumerStatefulWidget {
  /// Creates the route preview screen.
  const RoutePreviewScreen({super.key});

  @override
  ConsumerState<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends ConsumerState<RoutePreviewScreen> {
  final _from = TextEditingController(text: 'Current location (mock)');
  final _to = TextEditingController(text: 'Drop-off — Allen Ave, Ikeja');

  bool _builtRoute = false;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _getRoute() {
    setState(() => _builtRoute = true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final useSideBySide = !Responsive.isPhone(context) || MediaQuery.of(context).orientation == Orientation.landscape;

    Widget buildInputs() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomTextField(
            hintText: 'Current location',
            controller: _from,
            prefixIcon: Icons.my_location_outlined,
          ),
          const SizedBox(height: 12),
          CustomTextField(
            hintText: 'Destination',
            controller: _to,
            prefixIcon: Icons.flag_outlined,
          ),
          const SizedBox(height: 12),
          CustomButton(text: 'Get route', onPressed: _getRoute),
        ],
      );
    }

    Widget buildMap() {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: _builtRoute
            ? const MapPlaceholder(
                message: 'Route preview from Lagos to Allen Ave',
              )
            : const MapPlaceholder(
                message: 'Tap “Get route” to see preview',
              ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Route preview',
          style: AppTextStyles.headlineSmall.copyWith(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: useSideBySide
          ? Padding(
              padding: Responsive.padding(context),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      child: buildInputs(),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 3,
                    child: buildMap(),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: buildInputs(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: buildMap(),
                  ),
                ),
              ],
            ),
    );
  }
}
