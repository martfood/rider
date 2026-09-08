import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

import '../../core/services/notification_service.dart';

/// Real-time In-App Notifications screen for Riders.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String _formatTimestamp(dynamic createdAt) {
    if (createdAt == null) return 'Just now';

    DateTime dt;
    if (createdAt is Timestamp) {
      dt = createdAt.toDate();
    } else if (createdAt is String) {
      dt = DateTime.tryParse(createdAt) ?? DateTime.now();
    } else {
      return 'Just now';
    }

    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  Map<String, dynamic> _getNotificationStyle(
      String title, String body, Map<String, dynamic> data, bool isDark) {
    final lowerTitle = title.toLowerCase();
    final lowerBody = body.toLowerCase();
    final type = (data['type'] ?? '').toString().toLowerCase();

    if (lowerTitle.contains('cancel') ||
        lowerBody.contains('cancel') ||
        lowerTitle.contains('rejected') ||
        type == 'order_cancelled' ||
        type == 'verification_rejected') {
      return {
        'icon': Icons.cancel_outlined,
        'iconColor': isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
        'bgColor': isDark
            ? const Color(0xFF450A0A)
            : const Color(0xFFFEF2F2),
      };
    } else if (lowerTitle.contains('payout') ||
        lowerBody.contains('payout') ||
        lowerTitle.contains('wallet') ||
        lowerBody.contains('wallet') ||
        lowerTitle.contains('earned') ||
        type == 'payout' ||
        type == 'wallet_credit') {
      return {
        'icon': LucideIcons.wallet,
        'iconColor': isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669),
        'bgColor': isDark
            ? const Color(0xFF064E3B)
            : const Color(0xFFECFDF5),
      };
    } else if (lowerTitle.contains('verified') ||
        lowerTitle.contains('approved') ||
        lowerTitle.contains('success') ||
        lowerTitle.contains('completed') ||
        type == 'delivery_completed' ||
        type == 'verification_approved') {
      return {
        'icon': LucideIcons.circleCheck,
        'iconColor': isDark ? const Color(0xFF6EE7B7) : const Color(0xFF10B981),
        'bgColor': isDark
            ? const Color(0xFF064E3B)
            : const Color(0xFFE8F5E9),
      };
    } else if (lowerTitle.contains('order') ||
        lowerTitle.contains('matched') ||
        lowerTitle.contains('assignment') ||
        lowerTitle.contains('broadcast') ||
        type == 'new_order' ||
        type == 'order_broadcast') {
      return {
        'icon': LucideIcons.package,
        'iconColor': isDark ? const Color(0xFFC084FC) : const Color(0xFF7C3AED),
        'bgColor': isDark
            ? const Color(0xFF3B0764)
            : const Color(0xFFF3E8FF),
      };
    } else if (lowerTitle.contains('support') ||
        lowerTitle.contains('message') ||
        type == 'support_chat') {
      return {
        'icon': LucideIcons.headphones,
        'iconColor': isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
        'bgColor': isDark
            ? const Color(0xFF172554)
            : const Color(0xFFEFF6FF),
      };
    } else if (lowerTitle.contains('security') ||
        lowerTitle.contains('pin') ||
        lowerTitle.contains('document') ||
        type == 'security') {
      return {
        'icon': LucideIcons.shieldCheck,
        'iconColor': isDark ? const Color(0xFFFDBA74) : const Color(0xFFEA580C),
        'bgColor': isDark
            ? const Color(0xFF451A03)
            : const Color(0xFFFFF7ED),
      };
    }

    return {
      'icon': LucideIcons.bell,
      'iconColor': isDark ? const Color(0xFFC084FC) : const Color(0xFF6D28D9),
      'bgColor': isDark
          ? const Color(0xFF3B0764)
          : const Color(0xFFF3E8FF),
    };
  }

  Future<void> _handleNotificationTap(
      BuildContext context, String uid, String notificationId, Map<String, dynamic> data) async {
    NotificationService.markRiderNotificationAsRead(uid, notificationId);

    final orderId = (data['orderId'] ?? '').toString();
    final type = (data['type'] ?? '').toString();

    if (orderId.isNotEmpty) {
      if (type == 'order_broadcast') {
        try {
          final snap = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
          if (snap.exists && context.mounted) {
            final orderData = snap.data() ?? {};
            final assignedRiderId = (orderData['riderId'] ?? '').toString();
            if (assignedRiderId == uid) {
              context.push('/order/$orderId');
              return;
            }
          }
        } catch (_) {}
        if (context.mounted) {
          context.push('/order-request/$orderId');
        }
      } else {
        context.push('/order/$orderId');
      }
    } else if (type == 'support' || type == 'support_chat') {
      context.push('/account/help/support');
    } else if (type == 'payout' || type == 'wallet') {
      context.go('/earnings');
    } else if (type == 'verification' || type == 'id_documents') {
      context.push('/account/id-documents');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final primaryTextColor = isDark ? Colors.white : Colors.black;
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Text(
            'Please log in to view notifications',
            style: TextStyle(
              color: primaryTextColor,
              fontSize: AppTypography.font(14),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('riders')
          .doc(user.uid)
          .collection('notifications')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>?;
          final bData = b.data() as Map<String, dynamic>?;

          dynamic aTime = aData?['createdAt'];
          dynamic bTime = bData?['createdAt'];

          DateTime aDt = DateTime.fromMillisecondsSinceEpoch(0);
          DateTime bDt = DateTime.fromMillisecondsSinceEpoch(0);

          if (aTime is Timestamp) {
            aDt = aTime.toDate();
          } else if (aTime is String) {
            aDt = DateTime.tryParse(aTime) ?? aDt;
          }

          if (bTime is Timestamp) {
            bDt = bTime.toDate();
          } else if (bTime is String) {
            bDt = DateTime.tryParse(bTime) ?? bDt;
          }

          return bDt.compareTo(aDt);
        });

        final hasUnread = docs.any((d) {
          final data = d.data() as Map<String, dynamic>;
          return (data['read'] as bool?) == false;
        });

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            scrolledUnderElevation: 0,
            backgroundColor: backgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: primaryTextColor),
              onPressed: () => context.pop(),
            ),
            centerTitle: true,
            title: Text(
              'Notifications',
              style: TextStyle(
                color: primaryTextColor,
                fontSize: AppTypography.font(18),
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              if (hasUnread)
                TextButton(
                  onPressed: () =>
                      NotificationService.markAllRiderNotificationsAsRead(user.uid),
                  child: Text(
                    'Mark all read',
                    style: TextStyle(
                      color: purpleColor,
                      fontSize: AppTypography.font(13),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Responsive.maxContainer(
                context: context,
                maxWidth: 600,
                child: docs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: purpleColor.withValues(alpha: 0.10),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    LucideIcons.bellOff,
                                    color: purpleColor,
                                    size: 30,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'No notifications yet',
                                style: TextStyle(
                                  fontSize: AppTypography.font(17),
                                  fontWeight: FontWeight.w800,
                                  color: primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'When you receive order broadcasts, delivery updates, or payout alerts, they will appear here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: AppTypography.font(13),
                                  color: mutedTextColor,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final title = (data['title'] ?? 'Notification').toString();
                          final body = (data['body'] ?? '').toString();
                          final isUnread = (data['read'] as bool?) == false;
                          final extraData = (data['data'] as Map<String, dynamic>?) ?? {};
                          final timeStr = _formatTimestamp(data['createdAt']);

                          final style = _getNotificationStyle(
                              title, body, extraData, isDark);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Dismissible(
                              key: Key(doc.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  LucideIcons.trash2,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              onDismissed: (_) {
                                NotificationService.deleteRiderNotification(
                                    user.uid, doc.id);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isUnread
                                        ? purpleColor.withValues(alpha: 0.35)
                                        : borderColor,
                                    width: isUnread ? 1.4 : 1.0,
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => _handleNotificationTap(
                                        context, user.uid, doc.id, extraData),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: style['bgColor'] as Color,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Icon(
                                                style['icon'] as IconData,
                                                color:
                                                    style['iconColor'] as Color,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        title,
                                                        style: TextStyle(
                                                          fontWeight: isUnread
                                                              ? FontWeight.w800
                                                              : FontWeight.w700,
                                                          fontSize:
                                                              AppTypography
                                                                  .font(14),
                                                          color:
                                                              primaryTextColor,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      timeStr,
                                                      style: TextStyle(
                                                        fontSize:
                                                            AppTypography
                                                                .font(11),
                                                        color: mutedTextColor,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (body.isNotEmpty) ...[
                                                  const SizedBox(height: 5),
                                                  Text(
                                                    body,
                                                    style: TextStyle(
                                                      fontSize:
                                                          AppTypography.font(
                                                              13),
                                                      color: mutedTextColor,
                                                      height: 1.35,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          if (isUnread) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 8,
                                              height: 8,
                                              margin: const EdgeInsets.only(
                                                  top: 6),
                                              decoration: BoxDecoration(
                                                color: purpleColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
