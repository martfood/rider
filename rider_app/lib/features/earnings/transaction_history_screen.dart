import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

/// Full Transaction History screen for Rider App showing all earnings and payouts.
class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  String _formatTimestamp(dynamic createdAt) {
    if (createdAt == null) return 'Just now';
    DateTime date;
    if (createdAt is Timestamp) {
      date = createdAt.toDate();
    } else if (createdAt is String) {
      date = DateTime.tryParse(createdAt) ?? DateTime.now();
    } else {
      return 'Just now';
    }

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final monthStr = months[date.month - 1];
    final hour =
        date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final minStr = date.minute.toString().padLeft(2, '0');
    return '$monthStr ${date.day}, ${date.year} | $hour:$minStr $ampm';
  }

  String _formatCurrency(num value) {
    return value.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Text(
            'Please login to view transaction history',
            style: TextStyle(
              color: primaryTextColor,
              fontSize: AppTypography.font(14),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Transaction History',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: AppTypography.font(18),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Responsive.maxContainer(
            context: context,
            maxWidth: 600,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Realtime Transaction Stream ────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('riders')
                          .doc(user.uid)
                          .collection('transactions')
                          .snapshots(),
                      builder: (context, txSnapshot) {
                        final txDocs = txSnapshot.data?.docs ?? [];

                        if (txDocs.isNotEmpty) {
                          final sortedDocs = List<QueryDocumentSnapshot>.from(txDocs);
                          sortedDocs.sort((a, b) {
                            final aData = a.data() as Map<String, dynamic>?;
                            final bData = b.data() as Map<String, dynamic>?;
                            dynamic aTime = aData?['createdAt'] ?? aData?['timestamp'];
                            dynamic bTime = bData?['createdAt'] ?? bData?['timestamp'];
                            DateTime aDt = DateTime.fromMillisecondsSinceEpoch(0);
                            DateTime bDt = DateTime.fromMillisecondsSinceEpoch(0);
                            if (aTime is Timestamp) aDt = aTime.toDate();
                            if (bTime is Timestamp) bDt = bTime.toDate();
                            return bDt.compareTo(aDt);
                          });

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: sortedDocs.length,
                            separatorBuilder: (context, index) => Divider(
                              color: isDark ? AppTheme.darkBorder : const Color(0xFFEFF1F6),
                              height: 22,
                            ),
                            itemBuilder: (context, index) {
                              final tx = sortedDocs[index].data() as Map<String, dynamic>;
                              final amountVal = (tx['amount'] as num?) ?? 0;
                              final isExpense = tx['isExpense'] as bool? ?? false;
                              final typeStr = (tx['type'] ?? (isExpense ? 'Payout' : 'Delivery')).toString();
                              final title = (tx['title'] ?? 'Earnings Credit').toString();
                              final timeStr = _formatTimestamp(tx['createdAt'] ?? tx['timestamp']);

                              return _buildTransactionRow(
                                context: context,
                                title: title,
                                time: timeStr,
                                amount: '${isExpense ? '-' : '+'}₦${_formatCurrency(amountVal)}',
                                type: typeStr,
                                isExpense: isExpense,
                                icon: isExpense ? LucideIcons.wallet : LucideIcons.packageCheck,
                                iconColor: isExpense
                                    ? const Color(0xFFE11D48)
                                    : const Color(0xFF16A34A),
                                purpleColor: purpleColor,
                              );
                            },
                          );
                        }

                        // Fallback: Query delivered orders for this rider
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('orders')
                              .where('riderId', isEqualTo: user.uid)
                              .where('status', isEqualTo: 'delivered')
                              .snapshots(),
                          builder: (context, ordersSnapshot) {
                            final orderDocs = ordersSnapshot.data?.docs ?? [];

                            if (orderDocs.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 36, horizontal: 12),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 58,
                                      height: 58,
                                      decoration: BoxDecoration(
                                        color: purpleColor.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Icon(
                                          LucideIcons.receipt,
                                          color: purpleColor,
                                          size: 26,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'No transactions yet',
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontSize: AppTypography.font(15),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Your delivery earnings and payout records will appear here as soon as transactions are processed.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: mutedTextColor,
                                        fontSize: AppTypography.font(12),
                                        fontWeight: FontWeight.w500,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final sortedOrders = List<QueryDocumentSnapshot>.from(orderDocs);
                            sortedOrders.sort((a, b) {
                              final aData = a.data() as Map<String, dynamic>?;
                              final bData = b.data() as Map<String, dynamic>?;
                              dynamic aTime = aData?['deliveredAt'] ?? aData?['createdAt'];
                              dynamic bTime = bData?['deliveredAt'] ?? bData?['createdAt'];
                              DateTime aDt = DateTime.fromMillisecondsSinceEpoch(0);
                              DateTime bDt = DateTime.fromMillisecondsSinceEpoch(0);
                              if (aTime is Timestamp) aDt = aTime.toDate();
                              if (bTime is Timestamp) bDt = bTime.toDate();
                              return bDt.compareTo(aDt);
                            });

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: sortedOrders.length,
                              separatorBuilder: (context, index) => Divider(
                                color: isDark ? AppTheme.darkBorder : const Color(0xFFEFF1F6),
                                height: 22,
                              ),
                              itemBuilder: (context, index) {
                                final orderData = sortedOrders[index].data() as Map<String, dynamic>;
                                final orderNum = (orderData['orderNumber'] ?? sortedOrders[index].id).toString();
                                final shortOrderNum = orderNum.length > 8 ? orderNum.substring(0, 8) : orderNum;
                                final deliveryFee = (orderData['deliveryFee'] as num?)?.toDouble() ?? 1200.0;
                                final tip = (orderData['tip'] as num?)?.toDouble() ?? 0.0;
                                final earnedAmount = deliveryFee + tip;
                                final restaurantName = (orderData['restaurantName'] ?? orderData['vendorName'] ?? 'Food Delivery').toString();
                                final timeStr = _formatTimestamp(orderData['deliveredAt'] ?? orderData['createdAt']);

                                return _buildTransactionRow(
                                  context: context,
                                  title: '$restaurantName (#$shortOrderNum)',
                                  time: timeStr,
                                  amount: '+₦${_formatCurrency(earnedAmount)}',
                                  type: 'Delivery',
                                  isExpense: false,
                                  icon: LucideIcons.packageCheck,
                                  iconColor: const Color(0xFF16A34A),
                                  purpleColor: purpleColor,
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionRow({
    required BuildContext context,
    required String title,
    required String time,
    required String amount,
    required String type,
    required bool isExpense,
    required IconData icon,
    required Color iconColor,
    required Color purpleColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final chipBackground = iconColor.withValues(alpha: 0.12);

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: chipBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: AppTypography.font(14),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  color: mutedTextColor,
                  fontSize: AppTypography.font(11),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount,
              style: TextStyle(
                color: isExpense ? const Color(0xFFE11D48) : primaryTextColor,
                fontSize: AppTypography.font(14),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: chipBackground,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isExpense
                        ? LucideIcons.arrowUpRight
                        : LucideIcons.arrowDownLeft,
                    size: 11,
                    color: iconColor,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    type,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: AppTypography.font(10),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
