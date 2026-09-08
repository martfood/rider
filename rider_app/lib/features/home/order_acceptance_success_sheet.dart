import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

/// Shows a Minimal & Flat Success Bottom Sheet when a rider accepts an order.
Future<void> showOrderAcceptedSuccessSheet({
  required BuildContext context,
  required String orderId,
  required String restaurantName,
  required String pickupAddress,
  required String deliveryFeeLabel,
  required bool isDark,
}) {
  final purpleColor = AppTheme.primaryPurpleFor(isDark);
  final sheetBg = isDark ? AppTheme.darkSurface : Colors.white;
  final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1E2D);
  final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
  final cardBg = isDark ? AppTheme.darkSurface : const Color(0xFFFAF5FF);
  final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE9D5FF);

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: sheetBg,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle Bar ──────────────────────────────────────────
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // ── Success Icon Badge ──────────────────────────────────
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: purpleColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    LucideIcons.circleCheck,
                    size: 40,
                    color: purpleColor,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ── Title & Subtitle ─────────────────────────────────────
              Text(
                'Order Accepted!',
                style: TextStyle(
                  fontSize: AppTypography.font(20),
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You have successfully claimed this delivery for ${restaurantName.isNotEmpty ? restaurantName : 'Restaurant'}.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.font(13),
                  color: mutedTextColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // ── Order Summary Mini Card ─────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: purpleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(LucideIcons.store, color: purpleColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            restaurantName.isNotEmpty ? restaurantName : 'Restaurant',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppTypography.font(14),
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pickupAddress.isNotEmpty ? pickupAddress : 'Pickup Location',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppTypography.font(11),
                              color: mutedTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      deliveryFeeLabel,
                      style: TextStyle(
                        fontSize: AppTypography.font(15),
                        fontWeight: FontWeight.w800,
                        color: purpleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Primary Action: Go to Active Delivery ────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    ctx.pop();
                    context.push('/order/$orderId');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A154B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    'Go to Active Delivery',
                    style: TextStyle(
                      fontSize: AppTypography.font(15),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Secondary Action: Back to Home ───────────────────────
              SizedBox(
                width: double.infinity,
                height: 46,
                child: TextButton(
                  onPressed: () => ctx.pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: mutedTextColor,
                  ),
                  child: Text(
                    'Stay on this screen',
                    style: TextStyle(
                      fontSize: AppTypography.font(14),
                      fontWeight: FontWeight.w600,
                      color: mutedTextColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
