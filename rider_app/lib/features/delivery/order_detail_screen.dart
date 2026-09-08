import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/notification_service.dart';
import '../../domain/order_stage.dart';
import '../../domain/rider_order.dart';
import '../../providers/orders_providers.dart';
import '../../providers/rider_profile_provider.dart';

/// Full order detail screen matching the Active Delivery reference UI.
class OrderDetailScreen extends ConsumerStatefulWidget {
  /// Creates the order detail screen for [orderId].
  const OrderDetailScreen({super.key, required this.orderId});

  /// Order identifier from the route.
  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  // 4-digit PIN controllers and focus nodes
  final List<TextEditingController> _pinControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(4, (_) => FocusNode());

  bool _isSubmitting = false;
  String? _pinErrorMessage;

  @override
  void dispose() {
    for (final controller in _pinControllers) {
      controller.dispose();
    }
    for (final node in _pinFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _currentPinCode => _pinControllers.map((c) => c.text.trim()).join();

  Future<void> _setStage(OrderStage stage) async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(ordersProvider.notifier).setStage(widget.orderId, stage);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update order status: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _makeCall(String phone) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number not available')),
        );
      }
      return;
    }

    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open phone dialer: $e')),
        );
      }
    }
  }

  Future<void> _callVendor(String vendorId, String fallbackPhone) async {
    String phoneToCall = fallbackPhone.trim();
    if (vendorId.isNotEmpty) {
      try {
        final vendorDoc = await FirebaseFirestore.instance.collection('vendors').doc(vendorId).get();
        if (vendorDoc.exists) {
          final vData = vendorDoc.data();
          final personalPhone = (vData?['phone'] ?? vData?['phoneNumber'] ?? vData?['personalPhone'])?.toString().trim();
          if (personalPhone != null && personalPhone.isNotEmpty) {
            phoneToCall = personalPhone;
          }
        }
      } catch (e) {
        debugPrint('Error fetching vendor personal phone: $e');
      }
    }

    if (phoneToCall.isNotEmpty) {
      await _makeCall(phoneToCall);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vendor phone number not available')),
        );
      }
    }
  }

  Future<void> _handlePrimaryAction(RiderOrder order, bool isDark, Color purpleColor) async {
    if (_isSubmitting) return;

    switch (order.stage) {
      case OrderStage.enRouteToRestaurant:
        await _setStage(OrderStage.atRestaurant);
        break;

      case OrderStage.atRestaurant:
        await _setStage(OrderStage.headingToCustomer);
        break;

      case OrderStage.headingToCustomer:
        await _setStage(OrderStage.awaitingDeliveryCode);
        break;

      case OrderStage.readyToMarkDelivered:
      case OrderStage.awaitingDeliveryCode:
        await _verifyAndCompleteDelivery(order, isDark, purpleColor);
        break;

      case OrderStage.delivered:
        if (mounted) {
          context.pop();
        }
        break;
    }
  }

  Future<void> _verifyAndCompleteDelivery(RiderOrder order, bool isDark, Color purpleColor) async {
    final code = _currentPinCode;
    if (code.length < 4) {
      setState(() {
        _pinErrorMessage = 'Please enter the 4-digit PIN code.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _pinErrorMessage = null;
    });

    try {
      final ok = await ref.read(ordersProvider.notifier).tryCompleteWithCode(widget.orderId, code);

      if (!mounted) return;

      if (!ok) {
        for (final controller in _pinControllers) {
          controller.clear();
        }
        setState(() {
          _isSubmitting = false;
          _pinErrorMessage = 'Incorrect PIN code. Ask customer for the 4-digit code.';
        });
        if (_pinFocusNodes.isNotEmpty) {
          _pinFocusNodes[0].requestFocus();
        }
        return;
      }

      // Success notifications & wallet credit
      _triggerDeliveredNotifications(order);

      setState(() => _isSubmitting = false);
      _showDeliveredSuccessSheet(order, isDark, purpleColor);
    } catch (err) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _pinErrorMessage = 'Could not verify delivery. Please check connection and try again.';
        });
      }
    }
  }

  void _showDeliveredSuccessSheet(RiderOrder order, bool isDark, Color purpleColor) {
    final sheetBg = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1E2D);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetBg,
      elevation: 0,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(LucideIcons.circleCheck, size: 40, color: Color(0xFF10B981)),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Delivery Completed! 🎉',
                  style: TextStyle(
                    fontSize: AppTypography.font(20),
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Great job! ${order.deliveryFeeLabel} has been credited to your wallet balance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTypography.font(13),
                    color: mutedTextColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      ctx.pop();
                      if (context.mounted) {
                        context.pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purpleColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      'Back to Deliveries',
                      style: TextStyle(
                        fontSize: AppTypography.font(15),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

  void _triggerDeliveredNotifications(RiderOrder order) async {
    try {
      final orderDoc = await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).get();
      final data = orderDoc.data() ?? {};
      final deliveryFee = (data['deliveryFee'] ?? order.deliveryFee).toDouble();
      final profile = ref.read(riderProfileProvider);
      final riderId = FirebaseAuth.instance.currentUser?.uid;

      if (profile.email.isNotEmpty) {
        NotificationService.sendEmail(
          to: profile.email,
          subject: 'Order Delivered Successfully! 📦',
          htmlContent: '''
<!DOCTYPE html>
<html>
<body style="font-family: Arial, sans-serif; padding: 20px; color: #334155;">
  <div style="max-width: 600px; margin: 0 auto; background-color: white; border-radius: 12px; border: 1px solid #e2e8f0; overflow: hidden;">
    <div style="background-color: #7C3AED; padding: 24px; text-align: center;">
      <h2 style="color: #ffffff; margin: 0; font-size: 22px;">Order Delivered Successfully! 🎉</h2>
    </div>
    <div style="padding: 24px;">
      <p>Hi ${profile.displayName},</p>
      <p>Great job! Order <strong>#${widget.orderId}</strong> has been successfully delivered.</p>
      <div style="background-color: #F5F3FF; padding: 16px; border-radius: 8px; margin: 20px 0;">
        <p><strong>Restaurant:</strong> ${order.restaurantName}</p>
        <p><strong>Customer:</strong> ${order.customerName}</p>
        <p><strong>Earnings Credited:</strong> ₦${deliveryFee.toStringAsFixed(2)}</p>
      </div>
      <p>Best Regards,<br/><strong>The MartFood Team</strong></p>
    </div>
  </div>
</body>
</html>''',
        );
      }

      if (riderId != null) {
        NotificationService.sendPushNotification(
          riderId: riderId,
          title: 'Order Delivered! 📦',
          body: 'Order #${widget.orderId} was delivered successfully.',
          data: {'type': 'order_delivered', 'orderId': widget.orderId},
        );

        NotificationService.sendPushNotification(
          riderId: riderId,
          title: 'Wallet Credited! ₦',
          body: 'Your wallet has been credited with ₦${deliveryFee.toStringAsFixed(2)} for the delivery.',
          data: {'type': 'wallet_credited', 'amount': deliveryFee},
        );
      }
    } catch (e) {
      debugPrint('Error triggering delivery notifications: $e');
    }
  }

  // ── Stage Helpers ──────────────────────────────────────────────────────────

  String _getStageTitle(OrderStage stage) {
    switch (stage) {
      case OrderStage.enRouteToRestaurant:
        return 'Heading to Pickup';
      case OrderStage.atRestaurant:
        return 'Order Picked Up';
      case OrderStage.headingToCustomer:
        return 'Heading to Customer';
      case OrderStage.readyToMarkDelivered:
      case OrderStage.awaitingDeliveryCode:
        return 'Arrived at Customer';
      case OrderStage.delivered:
        return 'Order Delivered';
    }
  }

  String _getStageSubtitle(OrderStage stage) {
    switch (stage) {
      case OrderStage.enRouteToRestaurant:
        return 'Please, go to the restaurant to\npick order';
      case OrderStage.atRestaurant:
        return 'Collect package and start delivery\nto customer';
      case OrderStage.headingToCustomer:
        return 'Deliver order to customer\ndestination address';
      case OrderStage.readyToMarkDelivered:
      case OrderStage.awaitingDeliveryCode:
        return 'Ask customer for the 4-digit PIN\nto complete delivery';
      case OrderStage.delivered:
        return 'Order has been successfully delivered';
    }
  }

  int _getActiveStepIndex(OrderStage stage) {
    switch (stage) {
      case OrderStage.enRouteToRestaurant:
        return 0; // "To Pickup" active
      case OrderStage.atRestaurant:
        return 1; // "Picked Up" active
      case OrderStage.headingToCustomer:
        return 2; // "To Customer" active
      case OrderStage.readyToMarkDelivered:
      case OrderStage.awaitingDeliveryCode:
      case OrderStage.delivered:
        return 3; // "Delivered" active
    }
  }

  String _getPrimaryButtonLabel(OrderStage stage) {
    switch (stage) {
      case OrderStage.enRouteToRestaurant:
        return 'Confirm Pickup';
      case OrderStage.atRestaurant:
        return 'Start Delivery to Customer';
      case OrderStage.headingToCustomer:
        return 'Arrived at Customer';
      case OrderStage.readyToMarkDelivered:
      case OrderStage.awaitingDeliveryCode:
        return 'Confirm Delivery';
      case OrderStage.delivered:
        return 'Delivered ✓';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1E2D);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final bgColor = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              bottom: BorderSide(color: borderColor.withValues(alpha: 0.6), width: 1),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cardBg,
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        child: Center(
                          child: Icon(Icons.arrow_back, color: purpleColor, size: 20),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      'Active Delivery',
                      style: TextStyle(
                        fontSize: AppTypography.font(18),
                        fontWeight: FontWeight.w800,
                        color: purpleColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: purpleColor));
          }

          final orderFromProvider = ref.watch(orderByIdProvider(widget.orderId));
          final data = snapshot.hasData && snapshot.data!.exists
              ? snapshot.data!.data() as Map<String, dynamic>? ?? {}
              : <String, dynamic>{};

          if (data.isEmpty && orderFromProvider == null) {
            return Center(
              child: Text(
                'Order not found',
                style: TextStyle(color: mutedTextColor, fontSize: AppTypography.font(14)),
              ),
            );
          }

          final effectiveOrder = data.isNotEmpty
              ? RiderOrder.fromMap(widget.orderId, data)
              : (orderFromProvider ?? RiderOrder.fromMap(widget.orderId, data));
          final items = (data['items'] as List<dynamic>?) ?? [];
          final vendorId = (data['vendorId'] ??
                  data['merchantId'] ??
                  data['restaurantId'] ??
                  data['vendor_id'] ??
                  effectiveOrder.vendorId)
              .toString();
          final restaurantName = (data['restaurantName'] ?? effectiveOrder.restaurantName).toString();
          final restaurantPhone = (data['restaurantPhone'] ??
                  data['vendorPhone'] ??
                  effectiveOrder.restaurantPhone)
              .toString();
          final restaurantAddress = (data['restaurantAddress'] ?? data['pickupAddress'] ?? effectiveOrder.restaurantAddress).toString();
          final customerName = (data['customerName'] ?? data['recipientName'] ?? effectiveOrder.customerName).toString();
          final customerPhone = (data['customerPhone'] ?? data['recipientPhone'] ?? data['phoneNumber'] ?? effectiveOrder.customerPhone).toString();
          final customerId = (data['customerId'] ?? data['userId'] ?? '').toString();
          final customerAddress = ((data['deliveryAddress'] is Map ? data['deliveryAddress']['address'] : null) ??
                  data['dropoffAddress'] ??
                  data['customerAddress'] ??
                  effectiveOrder.customerAddress)
              .toString();
          final customerNote = (data['deliveryInstructions'] ?? data['note'] ?? data['instructions'] ?? '').toString();

          final deliveryFee = (data['deliveryFee'] as num?)?.toDouble() ??
              (data['fee'] as num?)?.toDouble() ??
              effectiveOrder.deliveryFee;
          final totalAmount = (data['totalAmount'] as num?)?.toDouble() ??
              (data['total'] as num?)?.toDouble() ??
              deliveryFee;

          final orderShortId = widget.orderId.length > 8 ? widget.orderId.substring(0, 8).toUpperCase() : widget.orderId.toUpperCase();
          final activeStepIndex = _getActiveStepIndex(effectiveOrder.stage);
          final isDeliveryPinStage = effectiveOrder.stage == OrderStage.awaitingDeliveryCode ||
              effectiveOrder.stage == OrderStage.readyToMarkDelivered;

          return SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Responsive.maxContainer(
                context: context,
                maxWidth: 600,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── CARD 1: Active Delivery Status Tracker & Updating Button ─
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row: Title & Subtitle + Order ID
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getStageTitle(effectiveOrder.stage),
                                        style: TextStyle(
                                          fontSize: AppTypography.font(16),
                                          fontWeight: FontWeight.w800,
                                          color: purpleColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _getStageSubtitle(effectiveOrder.stage),
                                        style: TextStyle(
                                          fontSize: AppTypography.font(12),
                                          color: mutedTextColor,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Order ID',
                                      style: TextStyle(
                                        fontSize: AppTypography.font(13),
                                        fontWeight: FontWeight.w600,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '#$orderShortId',
                                      style: TextStyle(
                                        fontSize: AppTypography.font(13),
                                        fontWeight: FontWeight.w600,
                                        color: mutedTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),

                            // 4-Step Horizontal Stepper
                            _buildHorizontalStepper(
                              activeStepIndex: activeStepIndex,
                              purpleColor: purpleColor,
                              isDark: isDark,
                              borderColor: borderColor,
                              mutedTextColor: mutedTextColor,
                            ),
                            const SizedBox(height: 20),

                            // 4-Digit PIN Input Section (Delivering Stage)
                            if (isDeliveryPinStage) ...[
                              _buildPinInputSection(
                                isDark: isDark,
                                purpleColor: purpleColor,
                                borderColor: borderColor,
                                primaryTextColor: primaryTextColor,
                                mutedTextColor: mutedTextColor,
                              ),
                              const SizedBox(height: 18),
                            ],

                            // Stage Updating Action Button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => _handlePrimaryAction(effectiveOrder, isDark, purpleColor),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: purpleColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _getPrimaryButtonLabel(effectiveOrder.stage),
                                        style: TextStyle(
                                          fontSize: AppTypography.font(15),
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── CARD 2: Pick Up & Drop Off Route ─────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Pick Up Section
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? AppTheme.darkSurface : const Color(0xFFFAF5FF),
                                    border: Border.all(
                                      color: isDark ? AppTheme.darkBorder : const Color(0xFFE9D5FF),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(LucideIcons.store, size: 18, color: purpleColor),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pick Up',
                                        style: TextStyle(
                                          fontSize: AppTypography.font(11),
                                          fontWeight: FontWeight.w600,
                                          color: purpleColor,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        restaurantName,
                                        style: TextStyle(
                                          fontSize: AppTypography.font(14),
                                          fontWeight: FontWeight.w700,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      _VendorStoreAddressText(
                                        vendorId: vendorId,
                                        fallbackAddress: restaurantAddress,
                                        style: TextStyle(
                                          fontSize: AppTypography.font(12),
                                          color: mutedTextColor,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Circular Action Buttons (Phone & Chat with Vendor)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildCircleAction(
                                      icon: LucideIcons.phone,
                                      purpleColor: purpleColor,
                                      borderColor: isDark ? AppTheme.darkBorder : const Color(0xFFE9D5FF),
                                      bgColor: isDark ? AppTheme.darkSurface : const Color(0xFFFAF5FF),
                                      onTap: () => _callVendor(vendorId, restaurantPhone),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildCircleAction(
                                      icon: LucideIcons.mail,
                                      purpleColor: purpleColor,
                                      borderColor: isDark ? AppTheme.darkBorder : const Color(0xFFE9D5FF),
                                      bgColor: isDark ? AppTheme.darkSurface : const Color(0xFFFAF5FF),
                                      onTap: () {
                                        context.push('/conversation', extra: {
                                          'id': vendorId,
                                          'name': restaurantName,
                                          'isVendor': true,
                                          'orderId': widget.orderId,
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // Vertical Dotted Connector
                            Padding(
                              padding: const EdgeInsets.only(left: 18, top: 4, bottom: 4),
                              child: _buildVerticalDottedLine(height: 28, color: isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1)),
                            ),

                            // Drop Off Section
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? AppTheme.darkSurface : const Color(0xFFFAF5FF),
                                    border: Border.all(
                                      color: isDark ? AppTheme.darkBorder : const Color(0xFFE9D5FF),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(LucideIcons.mapPin, size: 18, color: purpleColor),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Drop Off',
                                        style: TextStyle(
                                          fontSize: AppTypography.font(11),
                                          fontWeight: FontWeight.w600,
                                          color: purpleColor,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        customerName,
                                        style: TextStyle(
                                          fontSize: AppTypography.font(14),
                                          fontWeight: FontWeight.w700,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        customerAddress,
                                        style: TextStyle(
                                          fontSize: AppTypography.font(12),
                                          color: mutedTextColor,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Circular Action Buttons (Phone & Chat)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildCircleAction(
                                      icon: LucideIcons.phone,
                                      purpleColor: purpleColor,
                                      borderColor: isDark ? AppTheme.darkBorder : const Color(0xFFE9D5FF),
                                      bgColor: isDark ? AppTheme.darkSurface : const Color(0xFFFAF5FF),
                                      onTap: () => _makeCall(customerPhone),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildCircleAction(
                                      icon: LucideIcons.mail,
                                      purpleColor: purpleColor,
                                      borderColor: isDark ? AppTheme.darkBorder : const Color(0xFFE9D5FF),
                                      bgColor: isDark ? AppTheme.darkSurface : const Color(0xFFFAF5FF),
                                      onTap: () {
                                        context.push('/conversation', extra: {
                                          'id': customerId,
                                          'name': customerName,
                                          'isVendor': false,
                                          'orderId': widget.orderId,
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── CARD 3: Order Items & Subtotal ───────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Order items',
                                  style: TextStyle(
                                    fontSize: AppTypography.font(15),
                                    fontWeight: FontWeight.w700,
                                    color: primaryTextColor,
                                  ),
                                ),
                                Text(
                                  items.isNotEmpty
                                      ? '${items.length} item${items.length == 1 ? '' : 's'}'
                                      : '${effectiveOrder.menuLines.length} item${effectiveOrder.menuLines.length == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    fontSize: AppTypography.font(13),
                                    color: mutedTextColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Items List
                            if (items.isEmpty && effectiveOrder.menuLines.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Prepared dishes for delivery',
                                  style: TextStyle(color: mutedTextColor, fontSize: AppTypography.font(13)),
                                ),
                              )
                            else if (items.isNotEmpty)
                              ...items.map((item) {
                                final iMap = item is Map<String, dynamic> ? item : <String, dynamic>{};
                                final name = (iMap['name'] ?? iMap['title'] ?? 'Food Item').toString();
                                final quantity = (iMap['quantity'] ?? iMap['qty'] ?? 1).toString();
                                final price = (iMap['price'] as num?)?.toDouble() ?? 0.0;
                                final imgUrl = (iMap['imageUrl'] ?? iMap['image'] ?? '').toString();

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          color: purpleColor.withValues(alpha: 0.08),
                                          child: imgUrl.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: imgUrl,
                                                  fit: BoxFit.cover,
                                                  placeholder: (c, u) => Center(
                                                    child: Icon(LucideIcons.utensils, size: 18, color: purpleColor),
                                                  ),
                                                  errorWidget: (c, u, e) => Center(
                                                    child: Icon(LucideIcons.utensils, size: 18, color: purpleColor),
                                                  ),
                                                )
                                              : Center(
                                                  child: Icon(LucideIcons.utensils, size: 18, color: purpleColor),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          '$name x $quantity',
                                          style: TextStyle(
                                            fontSize: AppTypography.font(14),
                                            fontWeight: FontWeight.w600,
                                            color: primaryTextColor,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '₦${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                                        style: TextStyle(
                                          fontSize: AppTypography.font(14),
                                          fontWeight: FontWeight.w700,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              })
                            else
                              ...effectiveOrder.menuLines.map((line) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: purpleColor.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Icon(LucideIcons.utensils, size: 18, color: purpleColor),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          line,
                                          style: TextStyle(
                                            fontSize: AppTypography.font(14),
                                            fontWeight: FontWeight.w600,
                                            color: primaryTextColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),

                            const SizedBox(height: 6),

                            // Sub-total Pill Box Banner
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? purpleColor.withValues(alpha: 0.18) : const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Sub-total',
                                    style: TextStyle(
                                      fontSize: AppTypography.font(14),
                                      fontWeight: FontWeight.w700,
                                      color: purpleColor,
                                    ),
                                  ),
                                  Text(
                                    '₦${totalAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                                    style: TextStyle(
                                      fontSize: AppTypography.font(15),
                                      fontWeight: FontWeight.w800,
                                      color: purpleColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Customer Note / Instructions (if present)
                      if (customerNote.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor, width: 1),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: purpleColor.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(LucideIcons.notepadText, size: 16, color: purpleColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  customerNote,
                                  style: TextStyle(
                                    fontSize: AppTypography.font(12),
                                    color: primaryTextColor,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────

  Widget _buildHorizontalStepper({
    required int activeStepIndex,
    required Color purpleColor,
    required bool isDark,
    required Color borderColor,
    required Color mutedTextColor,
  }) {
    final steps = [
      const _StepperItemData(
        title: 'To Pickup',
        icon: LucideIcons.bike,
      ),
      const _StepperItemData(
        title: 'Picked Up',
        icon: LucideIcons.package,
      ),
      const _StepperItemData(
        title: 'To Customer',
        icon: LucideIcons.bike,
      ),
      const _StepperItemData(
        title: 'Delivered',
        icon: LucideIcons.check,
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          // Step Node
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= activeStepIndex ? purpleColor : (isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC)),
                    border: Border.all(
                      color: i <= activeStepIndex ? purpleColor : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      steps[i].icon,
                      size: 16,
                      color: i <= activeStepIndex ? Colors.white : (isDark ? Colors.grey[500] : const Color(0xFF94A3B8)),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  steps[i].title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTypography.font(10.5),
                    fontWeight: i <= activeStepIndex ? FontWeight.w700 : FontWeight.w500,
                    color: i <= activeStepIndex ? purpleColor : mutedTextColor,
                  ),
                ),
              ],
            ),
          ),

          // Dashed Connector Line between nodes
          if (i < steps.length - 1)
            Container(
              margin: const EdgeInsets.only(top: 17),
              width: 20,
              child: _buildHorizontalDottedLine(
                color: i < activeStepIndex
                    ? purpleColor
                    : (isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1)),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildPinInputSection({
    required bool isDark,
    required Color purpleColor,
    required Color borderColor,
    required Color primaryTextColor,
    required Color mutedTextColor,
  }) {
    return Column(
      children: [
        Text(
          'Enter the 4-digit PIN from the customer',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppTypography.font(12),
            fontWeight: FontWeight.w500,
            color: primaryTextColor,
          ),
        ),
        const SizedBox(height: 12),

        // Error message banner if PIN fails
        if (_pinErrorMessage != null) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.circleAlert,
                  size: 14,
                  color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _pinErrorMessage!,
                    style: TextStyle(
                      fontSize: AppTypography.font(11.5),
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // 4 Individual PIN Boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final isFilled = _pinControllers[index].text.isNotEmpty;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: 40,
              height: 46,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurface
                    : (isFilled ? const Color(0xFFF3E8FF).withValues(alpha: 0.6) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _pinErrorMessage != null
                      ? const Color(0xFFEF4444)
                      : (isFilled
                          ? purpleColor.withValues(alpha: 0.5)
                          : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0))),
                  width: 1,
                ),
              ),
              child: Center(
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.backspace) {
                      if (_pinControllers[index].text.isEmpty && index > 0) {
                        _pinControllers[index - 1].clear();
                        _pinFocusNodes[index - 1].requestFocus();
                        setState(() {});
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _pinControllers[index],
                    focusNode: _pinFocusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: TextStyle(
                      fontSize: AppTypography.font(18),
                      fontWeight: FontWeight.w800,
                      color: purpleColor,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: () {
                      _pinControllers[index].selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _pinControllers[index].text.length,
                      );
                    },
                    onChanged: (value) {
                      setState(() {
                        if (_pinErrorMessage != null) {
                          _pinErrorMessage = null;
                        }
                      });
                      if (value.isNotEmpty) {
                        if (index < 3) {
                          _pinFocusNodes[index + 1].requestFocus();
                        } else {
                          _pinFocusNodes[index].unfocus();
                        }
                      } else if (value.isEmpty && index > 0) {
                        _pinFocusNodes[index - 1].requestFocus();
                      }
                    },
                  ),
                ),
              ),
            );
          }),
        ),

        // Quick Clear PIN Action
        if (_currentPinCode.isNotEmpty) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              for (final c in _pinControllers) {
                c.clear();
              }
              setState(() {
                _pinErrorMessage = null;
              });
              _pinFocusNodes[0].requestFocus();
            },
            child: Text(
              'Clear PIN',
              style: TextStyle(
                fontSize: AppTypography.font(12),
                fontWeight: FontWeight.w600,
                color: purpleColor,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCircleAction({
    required IconData icon,
    required Color purpleColor,
    required Color borderColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Center(
          child: Icon(icon, size: 16, color: purpleColor),
        ),
      ),
    );
  }

  Widget _buildHorizontalDottedLine({required Color color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (_) {
        return Container(
          width: 3,
          height: 1.5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  Widget _buildVerticalDottedLine({required double height, required Color color}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (_) {
        return Container(
          width: 1.5,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 1.5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

class _StepperItemData {
  final String title;
  final IconData icon;

  const _StepperItemData({
    required this.title,
    required this.icon,
  });
}

class _VendorStoreAddressText extends StatelessWidget {
  final String vendorId;
  final String fallbackAddress;
  final TextStyle style;

  const _VendorStoreAddressText({
    required this.vendorId,
    required this.fallbackAddress,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (fallbackAddress.isNotEmpty && fallbackAddress != 'Vendor Store') {
      return Text(fallbackAddress, style: style);
    }
    if (vendorId.isEmpty) {
      return Text(fallbackAddress.isNotEmpty ? fallbackAddress : 'Store Location', style: style);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('vendors').doc(vendorId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final vData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final bp = vData['businessProfile'] as Map<String, dynamic>?;
          final address = (bp?['address'] ?? bp?['storeAddress'] ?? vData['address'] ?? vData['storeAddress'])?.toString();
          if (address != null && address.trim().isNotEmpty) {
            return Text(address.trim(), style: style);
          }
        }
        return Text(fallbackAddress.isNotEmpty ? fallbackAddress : 'Store Location', style: style);
      },
    );
  }
}
