import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

/// Full Transaction History screen for Rider App showing all earnings, admin adjustments, and payouts.
class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  int _selectedFilterIndex = 0; // 0: All, 1: Deliveries, 2: Adjustments

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
        isDark ? AppTheme.darkSurface : Colors.white;
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
                  // ── Filter Segment Bar ────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkBorder.withValues(alpha: 0.3) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Row(
                      children: [
                        _buildFilterButton(0, 'All', purpleColor, isDark),
                        _buildFilterButton(1, 'Deliveries', purpleColor, isDark),
                        _buildFilterButton(2, 'Adjustments', purpleColor, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

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

                          // Filter records based on selected tab
                          final filteredDocs = sortedDocs.where((docSnap) {
                            if (_selectedFilterIndex == 0) return true;
                            final d = docSnap.data() as Map<String, dynamic>;
                            final type = (d['type'] ?? '').toString().toLowerCase();
                            final isExpense = d['isExpense'] as bool? ?? false;
                            final source = (d['source'] ?? '').toString().toLowerCase();

                            if (_selectedFilterIndex == 1) {
                              // Deliveries
                              return !isExpense && type.contains('delivery') && source != 'admin';
                            } else {
                              // Adjustments & Payouts
                              return type.contains('top up') ||
                                  type.contains('deduct') ||
                                  type.contains('payout') ||
                                  source == 'admin';
                            }
                          }).toList();

                          if (filteredDocs.isEmpty) {
                            return _buildEmptyState(
                              purpleColor: purpleColor,
                              primaryTextColor: primaryTextColor,
                              mutedTextColor: mutedTextColor,
                              title: 'No matching transactions',
                              subtitle: 'No records found for the selected filter category.',
                            );
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredDocs.length,
                            separatorBuilder: (context, index) => Divider(
                              color: isDark ? AppTheme.darkBorder : const Color(0xFFEFF1F6),
                              height: 22,
                            ),
                            itemBuilder: (context, index) {
                              final tx = filteredDocs[index].data() as Map<String, dynamic>;
                              final amountVal = (tx['amount'] as num?) ?? 0;
                              final isExpense = tx['isExpense'] as bool? ?? false;
                              final typeStr = (tx['type'] ?? (isExpense ? 'Deduction' : 'Delivery')).toString();
                              final title = (tx['title'] ?? (isExpense ? 'Wallet Deduction' : 'Earnings Credit')).toString();
                              final description = (tx['description'] ?? '').toString();
                              final timeStr = _formatTimestamp(tx['createdAt'] ?? tx['timestamp']);

                              IconData icon;
                              Color iconColor;
                              if (isExpense) {
                                icon = typeStr.toLowerCase().contains('deduct')
                                    ? LucideIcons.minusCircle
                                    : LucideIcons.wallet;
                                iconColor = const Color(0xFFE11D48);
                              } else {
                                if (typeStr.toLowerCase().contains('top up') ||
                                    title.toLowerCase().contains('top-up')) {
                                  icon = LucideIcons.plusCircle;
                                  iconColor = const Color(0xFF16A34A);
                                } else {
                                  icon = LucideIcons.packageCheck;
                                  iconColor = const Color(0xFF16A34A);
                                }
                              }

                              return _buildTransactionRow(
                                context: context,
                                title: title,
                                description: description,
                                time: timeStr,
                                amount: '${isExpense ? '-' : '+'}₦${_formatCurrency(amountVal)}',
                                type: typeStr,
                                isExpense: isExpense,
                                icon: icon,
                                iconColor: iconColor,
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
                              return _buildEmptyState(
                                purpleColor: purpleColor,
                                primaryTextColor: primaryTextColor,
                                mutedTextColor: mutedTextColor,
                                title: 'No transactions yet',
                                subtitle: 'Your delivery earnings, admin adjustments, and payout records will appear here.',
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: orderDocs.length,
                              separatorBuilder: (context, index) => Divider(
                                color: isDark ? AppTheme.darkBorder : const Color(0xFFEFF1F6),
                                height: 22,
                              ),
                              itemBuilder: (context, index) {
                                final orderData =
                                    orderDocs[index].data() as Map<String, dynamic>;
                                final orderId = orderDocs[index].id;
                                final deliveryFee =
                                    (orderData['deliveryFee'] as num?) ?? 0;
                                final timestamp = orderData['timeline']?['deliveredAt'] ??
                                    orderData['createdAt'];
                                final timeStr = _formatTimestamp(timestamp);

                                return _buildTransactionRow(
                                  context: context,
                                  title: 'Delivery Earning',
                                  description: 'Order #$orderId',
                                  time: timeStr,
                                  amount: '+₦${_formatCurrency(deliveryFee)}',
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

  Widget _buildFilterButton(int index, String label, Color purpleColor, bool isDark) {
    final isSelected = _selectedFilterIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilterIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? purpleColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[300] : const Color(0xFF64748B)),
              fontSize: AppTypography.font(12),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required Color purpleColor,
    required Color primaryTextColor,
    required Color mutedTextColor,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
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
                LucideIcons.receiptText,
                color: purpleColor,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: primaryTextColor,
              fontSize: AppTypography.font(AppFontSizes.bodyLarge),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: mutedTextColor,
              fontSize: AppTypography.font(AppFontSizes.bodySmall),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow({
    required BuildContext context,
    required String title,
    String? description,
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
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
                    fontSize: AppTypography.font(AppFontSizes.bodySmall),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  color: mutedTextColor,
                  fontSize: AppTypography.font(AppFontSizes.caption),
                  fontWeight: FontWeight.w600,
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
                color: isExpense
                    ? (isDark ? const Color(0xFFF87171) : const Color(0xFFE11D48))
                    : (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A)),
                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
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
                      fontSize: AppTypography.font(AppFontSizes.caption),
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
