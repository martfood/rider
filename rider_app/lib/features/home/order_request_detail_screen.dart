import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/rider_profile_provider.dart';
import 'order_acceptance_success_sheet.dart';

/// Screen displaying the details of an incoming order broadcast request.
class OrderRequestDetailScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderRequestDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<OrderRequestDetailScreen> createState() =>
      _OrderRequestDetailScreenState();
}

class _OrderRequestDetailScreenState
    extends ConsumerState<OrderRequestDetailScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _isProcessing = false;
  bool _hasRedirected = false;

  Future<void> _declineOrder() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _isProcessing) return;

    setState(() => _isProcessing = true);
    try {
      await _firestore.collection('orders').doc(widget.orderId).update({
        'declinedRiders': FieldValue.arrayUnion([uid]),
      });
      await _firestore.collection('riders').doc(uid).set({
        'declinedOrdersCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      debugPrint('Error declining order: $e');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _acceptOrder(Map<String, dynamic> data) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _isProcessing) return;

    final profile = ref.read(riderProfileProvider);
    final orderRef = _firestore.collection('orders').doc(widget.orderId);
    final riderRef = _firestore.collection('riders').doc(uid);

    setState(() => _isProcessing = true);

    try {
      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(orderRef);
        if (!snap.exists) {
          throw Exception('This order is no longer available.');
        }

        final currentData = snap.data()!;
        final broadcastStatus = currentData['broadcastStatus'] as String? ?? '';
        final existingRiderId = currentData['riderId'] as String? ?? '';

        if (broadcastStatus == 'claimed' || (existingRiderId.isNotEmpty && existingRiderId != uid)) {
          throw Exception('Another rider has already accepted this order.');
        }

        transaction.update(orderRef, {
          'broadcastStatus': 'claimed',
          'riderId': uid,
          'riderName': profile.displayName.isNotEmpty ? profile.displayName : 'Assigned Rider',
          'riderPhone': profile.phone,
          'status': 'rider_assigned',
          'acceptedAt': FieldValue.serverTimestamp(),
          'timeline.assignedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(
          riderRef,
          {
            'activeOrderId': widget.orderId,
            'acceptedOrdersCount': FieldValue.increment(1),
          },
          SetOptions(merge: true),
        );
      });

      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final restaurantName = (data['restaurantName'] ?? 'Restaurant').toString();
        final restaurantAddress = (data['restaurantAddress'] ?? data['pickupAddress'] ?? 'Pickup Location').toString();
        final deliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? (data['fee'] as num?)?.toDouble() ?? 0.0;
        final deliveryFeeLabel = '₦${deliveryFee.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

        // Pop current request detail screen and show success bottom sheet
        context.pop();
        showOrderAcceptedSuccessSheet(
          context: context,
          orderId: widget.orderId,
          restaurantName: restaurantName,
          pickupAddress: restaurantAddress,
          deliveryFeeLabel: deliveryFeeLabel,
          isDark: isDark,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _callPhone(String? phone) async {
    final cleanPhone = (phone ?? '').trim();
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Could not launch phone dialer: $e');
    }
  }

  static GeoPoint? _extractGeoPoint(dynamic val) {
    if (val is GeoPoint) return val;
    if (val is Map) {
      final lat = (val['latitude'] ?? val['lat'] ?? val['_latitude']) as num?;
      final lng = (val['longitude'] ?? val['lng'] ?? val['_longitude']) as num?;
      if (lat != null && lng != null) {
        return GeoPoint(lat.toDouble(), lng.toDouble());
      }
    }
    return null;
  }

  static double _calcHaversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * (pi / 180.0);
    final dLon = (lon2 - lon1) * (pi / 180.0);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) * cos(lat2 * (pi / 180.0)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E1E2D);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF718096);
    final bgColor = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final currentUid = _auth.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cardBg,
                border: Border.all(color: borderColor, width: 1),
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black, size: 20),
                onPressed: () => context.pop(),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        title: Text(
          'Order Request',
          style: TextStyle(
            fontSize: AppTypography.font(18),
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('orders').doc(widget.orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: purpleColor));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: purpleColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(LucideIcons.packageX, size: 40, color: purpleColor),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Order No Longer Available',
                      style: TextStyle(
                        fontSize: AppTypography.font(16),
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This order request was removed or cancelled.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppTypography.font(13),
                        color: mutedTextColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purpleColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Back to Home'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final assignedRiderId = (data['riderId'] ?? '').toString();
          final broadcastStatus = (data['broadcastStatus'] ?? '').toString();
          final rawStatus = (data['status'] ?? '').toString();

          // If assigned to CURRENT rider, redirect to active delivery screen
          final isAssignedToCurrentRider = assignedRiderId.isNotEmpty && assignedRiderId == currentUid;
          if (isAssignedToCurrentRider && !_hasRedirected) {
            _hasRedirected = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.pushReplacement('/order/${widget.orderId}');
              }
            });
          }

          // Check if order is already claimed by ANOTHER rider or no longer broadcasting
          final isClaimedByOther = (assignedRiderId.isNotEmpty && assignedRiderId != currentUid) ||
              (broadcastStatus == 'claimed' && !isAssignedToCurrentRider) ||
              rawStatus == 'delivered' ||
              rawStatus == 'cancelled';

          final items = (data['items'] as List<dynamic>?) ?? [];
          final restaurantName = (data['restaurantName'] ?? 'Restaurant').toString();
          final restaurantAddress = (data['restaurantAddress'] ?? data['pickupAddress'] ?? 'Pickup Location').toString();
          final customerName = (data['customerName'] ?? data['recipientName'] ?? 'Customer').toString();
          final customerPhone = (data['customerPhone'] ?? data['recipientPhone'] ?? data['phone'] ?? '').toString();
          final customerAddress = ((data['deliveryAddress'] is Map ? data['deliveryAddress']['address'] : null) ??
                  data['dropoffAddress'] ??
                  data['customerAddress'] ??
                  'Drop-off Location')
              .toString();
          final customerNote = (data['deliveryInstructions'] ?? data['note'] ?? data['instructions'] ?? '').toString();

          final deliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? (data['fee'] as num?)?.toDouble() ?? 0.0;
          final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? (data['total'] as num?)?.toDouble() ?? deliveryFee;

          // Distance calculation
          final riderProfile = ref.watch(riderProfileProvider);
          final riderLat = riderProfile.currentLocation?.latitude ?? 6.5244;
          final riderLng = riderProfile.currentLocation?.longitude ?? 3.3792;
          final vendorLoc = _extractGeoPoint(data['currentvendorLocation']) ??
              _extractGeoPoint(data['currentVendorLocation']) ??
              _extractGeoPoint(data['restaurantLocation']) ??
              _extractGeoPoint(data['vendorLocation']) ??
              _extractGeoPoint(data['pickupLocation']);

          double distanceKm = 4.2;
          if (vendorLoc != null) {
            distanceKm = _calcHaversine(riderLat, riderLng, vendorLoc.latitude, vendorLoc.longitude);
          }

          final orderShortId = widget.orderId.length > 8 ? widget.orderId.substring(0, 8).toUpperCase() : widget.orderId.toUpperCase();

          return SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Responsive.maxContainer(
                context: context,
                maxWidth: 600,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Card 1: Estimated Earnings & Distance ───────────────
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: borderColor, width: 1),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: isClaimedByOther
                                              ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2))
                                              : (isDark ? const Color(0xFF064E3B) : const Color(0xFFE8F5E9)),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          isClaimedByOther ? 'Already Claimed' : 'New Order Request',
                                          style: TextStyle(
                                            fontSize: AppTypography.font(12),
                                            fontWeight: FontWeight.w700,
                                            color: isClaimedByOther
                                                ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626))
                                                : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF2E7D32)),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Order ID #$orderShortId',
                                        style: TextStyle(
                                          fontSize: AppTypography.font(13),
                                          fontWeight: FontWeight.w600,
                                          color: mutedTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Estimated earnings',
                                    style: TextStyle(
                                      fontSize: AppTypography.font(12),
                                      color: mutedTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₦${deliveryFee.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                                    style: TextStyle(
                                      fontSize: AppTypography.font(26),
                                      fontWeight: FontWeight.w900,
                                      color: purpleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 18),

                                  // Sub-container for Time & Distance
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppTheme.darkSurface : const Color(0xFFFAF5FF),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: borderColor, width: 0.5),
                                    ),
                                    child: Row(
                                      children: [
                                        // Est. Time
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: purpleColor.withValues(alpha: 0.12),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(LucideIcons.clock, size: 16, color: purpleColor),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Est. Time',
                                                      style: TextStyle(
                                                        fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                                        fontWeight: FontWeight.w500,
                                                        color: mutedTextColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '25 - 30 mins',
                                                      style: TextStyle(
                                                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                                                        fontWeight: FontWeight.w700,
                                                        color: purpleColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(width: 1, height: 32, color: borderColor),
                                        const SizedBox(width: 12),
                                        // Total Distance
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: purpleColor.withValues(alpha: 0.12),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(LucideIcons.mapPin, size: 16, color: purpleColor),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Total Distance',
                                                      style: TextStyle(
                                                        fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                                        fontWeight: FontWeight.w500,
                                                        color: mutedTextColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${distanceKm.toStringAsFixed(1)} km',
                                                      style: TextStyle(
                                                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                                                        fontWeight: FontWeight.w700,
                                                        color: purpleColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── Card 2: Pickup & Dropoff Stepper ────────────────────
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: borderColor, width: 1),
                              ),
                              child: Column(
                                children: [
                                  // Pick Up Row
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: purpleColor.withValues(alpha: 0.08),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: purpleColor.withValues(alpha: 0.2), width: 1),
                                        ),
                                        child: Icon(LucideIcons.store, size: 18, color: purpleColor),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Pick Up',
                                              style: TextStyle(
                                                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                                fontWeight: FontWeight.w600,
                                                color: purpleColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              restaurantName,
                                              style: TextStyle(
                                                fontSize: AppTypography.font(15),
                                                fontWeight: FontWeight.w700,
                                                color: primaryTextColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              restaurantAddress,
                                              style: TextStyle(
                                                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                                fontWeight: FontWeight.w500,
                                                color: mutedTextColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Connector
                                  Padding(
                                    padding: const EdgeInsets.only(left: 19, top: 4, bottom: 4),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        width: 1.5,
                                        height: 28,
                                        color: isDark ? AppTheme.darkBorder : const Color(0xFFD8B4FE),
                                      ),
                                    ),
                                  ),

                                  // Drop Off Row
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: purpleColor.withValues(alpha: 0.08),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: purpleColor.withValues(alpha: 0.2), width: 1),
                                        ),
                                        child: Icon(LucideIcons.mapPin, size: 18, color: purpleColor),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Drop Off',
                                              style: TextStyle(
                                                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                                fontWeight: FontWeight.w600,
                                                color: purpleColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              customerName,
                                              style: TextStyle(
                                                fontSize: AppTypography.font(15),
                                                fontWeight: FontWeight.w700,
                                                color: primaryTextColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              customerAddress,
                                              style: TextStyle(
                                                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                                fontWeight: FontWeight.w500,
                                                color: mutedTextColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Action icons (Phone & Chat)
                                      Row(
                                        children: [
                                          _buildCircleAction(
                                            icon: LucideIcons.phone,
                                            purpleColor: purpleColor,
                                            borderColor: borderColor,
                                            onTap: () => _callPhone(customerPhone),
                                          ),
                                          const SizedBox(width: 8),
                                          _buildCircleAction(
                                            icon: LucideIcons.mail,
                                            purpleColor: purpleColor,
                                            borderColor: borderColor,
                                            onTap: () {
                                              context.push('/conversation', extra: {
                                                'id': data['customerId'] ?? data['userId'] ?? '',
                                                'name': customerName,
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

                            // ── Card 3: Order Items & Subtotal ──────────────────────
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
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Order items',
                                        style: TextStyle(
                                          fontSize: AppTypography.font(15),
                                          fontWeight: FontWeight.w800,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                      Text(
                                        '${items.length} item${items.length == 1 ? '' : 's'}',
                                        style: TextStyle(
                                          fontSize: AppTypography.font(13),
                                          color: mutedTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Items List
                                  if (items.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Text(
                                        'Prepared dishes for delivery',
                                        style: TextStyle(color: mutedTextColor, fontSize: AppTypography.font(13)),
                                      ),
                                    )
                                  else
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
                                              borderRadius: BorderRadius.circular(12),
                                              child: Container(
                                                width: 48,
                                                height: 48,
                                                color: purpleColor.withValues(alpha: 0.08),
                                                child: imgUrl.isNotEmpty
                                                    ? CachedNetworkImage(
                                                        imageUrl: imgUrl,
                                                        fit: BoxFit.cover,
                                                        placeholder: (c, u) => Center(
                                                          child: Icon(LucideIcons.utensils, size: 20, color: purpleColor),
                                                        ),
                                                        errorWidget: (c, u, e) => Center(
                                                          child: Icon(LucideIcons.utensils, size: 20, color: purpleColor),
                                                        ),
                                                      )
                                                    : Center(
                                                        child: Icon(LucideIcons.utensils, size: 20, color: purpleColor),
                                                      ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                '$name x $quantity',
                                                style: TextStyle(
                                                  fontSize: AppTypography.font(14),
                                                  fontWeight: FontWeight.w700,
                                                  color: primaryTextColor,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '₦${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                                              style: TextStyle(
                                                fontSize: AppTypography.font(14),
                                                fontWeight: FontWeight.w800,
                                                color: primaryTextColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),

                                  const SizedBox(height: 8),

                                  // Subtotal Banner Pill Box
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? purpleColor.withValues(alpha: 0.15) : const Color(0xFFF3E8FF),
                                      borderRadius: BorderRadius.circular(14),
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
                            const SizedBox(height: 16),

                            // ── Card 4: Special Instructions Note ───────────────────
                            if (customerNote.isNotEmpty)
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

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    // ── Bottom Action Controls ──────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border(top: BorderSide(color: borderColor, width: 1)),
                      ),
                      child: isClaimedByOther
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        LucideIcons.circleAlert,
                                        size: 16,
                                        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'This order request has already been accepted and assigned to another rider.',
                                          style: TextStyle(
                                            fontSize: AppTypography.font(12),
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: () => context.pop(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: purpleColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                    child: Text(
                                      'Back to Home',
                                      style: TextStyle(
                                        fontSize: AppTypography.font(15),
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                // Decline Button
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: OutlinedButton(
                                      onPressed: _isProcessing ? null : _declineOrder,
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                                        foregroundColor: const Color(0xFFEF4444),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                      ),
                                      child: Text(
                                        'Decline',
                                        style: TextStyle(
                                          fontSize: AppTypography.font(15),
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFEF4444),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Accept Button
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: _isProcessing ? null : () => _acceptOrder(data),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: purpleColor,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                      ),
                                      child: _isProcessing
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              'Accept',
                                              style: TextStyle(
                                                fontSize: AppTypography.font(15),
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCircleAction({
    required IconData icon,
    required Color purpleColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Center(
          child: Icon(icon, size: 16, color: purpleColor),
        ),
      ),
    );
  }
}
