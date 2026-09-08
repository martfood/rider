import 'package:flutter/material.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

/// Notification toggles for the rider app (mock persistence).
class NotificationsSettingsRiderScreen extends StatefulWidget {
  /// Creates the notifications settings screen.
  const NotificationsSettingsRiderScreen({super.key});

  @override
  State<NotificationsSettingsRiderScreen> createState() =>
      _NotificationsSettingsRiderScreenState();
}

class _NotificationsSettingsRiderScreenState
    extends State<NotificationsSettingsRiderScreen> {
  bool _assignments = true;
  bool _payouts = true;
  bool _promos = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Notifications',
            style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: Responsive.maxContainer(
        context: context,
        maxWidth: 600,
        child: ListView(
          padding: Responsive.padding(context),
          children: [
            SwitchListTile.adaptive(
              value: _assignments,
              onChanged: (v) => setState(() => _assignments = v),
              title: Text('New assignments', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text('Alerts when you’re matched to an order.', style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey)),
              activeTrackColor: AppTheme.primaryColor,
            ),
            SwitchListTile.adaptive(
              value: _payouts,
              onChanged: (v) => setState(() => _payouts = v),
              title: Text('Payout updates', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text('Weekly payout confirmations and issues.', style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey)),
              activeTrackColor: AppTheme.primaryColor,
            ),
            SwitchListTile.adaptive(
              value: _promos,
              onChanged: (v) => setState(() => _promos = v),
              title: Text('Tips & promotions', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text('Optional rider incentives and education.', style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey)),
              activeTrackColor: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
