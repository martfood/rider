import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

class RiderPrivacyPolicyScreen extends StatelessWidget {
  const RiderPrivacyPolicyScreen({super.key});

  static const String _fallbackContent = '''1. Information We Collect from Riders
MartFood collects rider personal information including your full name, email, phone number, government-issued identification documents, driver's license, vehicle details, bank account credentials for payouts, and real-time GPS location.

2. Real-Time Location Tracking
Real-time foreground and background location data is collected while you are marked "Online" to match you with nearby delivery requests and allow customers and dispatchers to track active order transit.

3. Usage of Information
Your data is used to:
• Verify your rider identity and vehicle credentials.
• Dispatch nearby vendor pickup orders.
• Calculate delivery mileage, earnings, and disburse weekly payouts.
• Facilitate communication between you, customers, and dispatch support during active deliveries.

4. Data Sharing
Customers only see your first name, profile picture, vehicle type, and live order location during an active delivery. Customer and vendor contact details provided to you must only be used for active delivery purposes.

5. Data Retention & Deletion
Rider records and transaction histories are retained in compliance with applicable financial and commercial record-keeping regulations. Riders may request account deletion via the Settings screen.''';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFF0E6FF);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? Colors.grey[800]! : const Color(0xFFE9EAF0),
                width: 1,
              ),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black, size: 20),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          'Privacy Policy',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: AppTypography.font(18),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Responsive.maxContainer(
            context: context,
            maxWidth: 600,
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('settings')
                  .doc('legal')
                  .snapshots(),
              builder: (context, snapshot) {
                String title = 'Rider Privacy Policy';
                String lastUpdated = 'August 15, 2026';
                String content = _fallbackContent;

                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  if (data != null && data['riderPrivacyPolicy'] != null) {
                    final policy = data['riderPrivacyPolicy'] as Map<String, dynamic>;
                    title = policy['title']?.toString() ?? title;
                    lastUpdated = policy['lastUpdated']?.toString() ?? lastUpdated;
                    content = policy['content']?.toString() ?? content;
                  }
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: purpleColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        LucideIcons.calendar,
                                        size: 13,
                                        color: purpleColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Updated $lastUpdated',
                                        style: TextStyle(
                                          color: purpleColor,
                                          fontSize: AppTypography.font(12),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: AppTypography.font(18),
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              content,
                              style: TextStyle(
                                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                                color: primaryTextColor.withValues(alpha: 0.90),
                                height: 1.65,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
