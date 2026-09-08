import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

class RiderTermsOfUseScreen extends StatelessWidget {
  const RiderTermsOfUseScreen({super.key});

  static const String _fallbackContent = '''1. Independent Contractor Relationship
As a MartFood delivery rider, you operate as an independent dispatch contractor and not as an employee of MartFood. You retain full flexibility in choosing your active working hours.

2. Verification & Safety Requirements
You agree to maintain a valid government ID, appropriate driver's license, roadworthy vehicle, and adhere to all local traffic laws and safety standards.

3. Order Handling & Delivery PIN
You agree to pick up orders promptly, ensure sanitary food handling in insulated bags, and collect the customer's 4-digit Delivery PIN before completing the dropoff in your rider app.

4. Earnings & Payouts
Delivery fees and tips accrue in your MartFood Rider Wallet in real time. Payouts are transferred automatically to your verified bank account on scheduled payout cycles.

5. Code of Conduct & Deactivation
MartFood maintains zero tolerance for harassment, theft, unauthorized order tampering, or fraudulent completion of deliveries. Violations may result in immediate deactivation of your rider account.''';

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
          'Terms of Use',
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
                String title = 'Rider Terms of Use';
                String lastUpdated = 'August 15, 2026';
                String content = _fallbackContent;

                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  if (data != null && data['riderTermsOfUse'] != null) {
                    final terms = data['riderTermsOfUse'] as Map<String, dynamic>;
                    title = terms['title']?.toString() ?? title;
                    lastUpdated = terms['lastUpdated']?.toString() ?? lastUpdated;
                    content = terms['content']?.toString() ?? content;
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
