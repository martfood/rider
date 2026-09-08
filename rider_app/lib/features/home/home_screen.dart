import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

import '../../providers/rider_app_providers.dart';
import '../../providers/rider_profile_provider.dart';
import '../../core/services/app_update_service.dart';
import 'order_acceptance_success_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  bool _obscureBalance = false;
  late final Stream<QuerySnapshot> _broadcastOrdersStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _broadcastOrdersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('broadcastStatus', isEqualTo: 'broadcasting')
        .snapshots();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdateService.checkAndPromptUpdate(context);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // App is closing completely — auto update rider availability to offline
      ref.read(riderAvailabilityProvider.notifier).setOnline(false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }


  Future<void> _declineOrder(String orderId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'declinedRiders': FieldValue.arrayUnion([uid]),
      });
      await FirebaseFirestore.instance.collection('riders').doc(uid).set({
        'declinedOrdersCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order request dismissed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error declining order: $e');
    }
  }

  Future<void> _acceptOrder(Map<String, dynamic> orderData, String orderId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final profile = ref.read(riderProfileProvider);
    final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
    final riderRef = FirebaseFirestore.instance.collection('riders').doc(uid);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snap = await transaction.get(orderRef);
        if (!snap.exists) {
          throw Exception('This order is no longer available.');
        }

        final data = snap.data()!;
        final broadcastStatus = data['broadcastStatus'] as String? ?? '';
        final existingRiderId = data['riderId'] as String? ?? '';

        if (broadcastStatus == 'claimed' || existingRiderId.isNotEmpty) {
          throw Exception('Another rider has already accepted this order.');
        }

        transaction.update(orderRef, {
          'riderId': uid,
          'riderName': profile.displayName.isNotEmpty ? profile.displayName : 'Rider',
          'riderPhone': profile.phone,
          'riderPhotoUrl': profile.avatarUrl,
          'broadcastStatus': 'claimed',
          'status': 'rider_assigned',
          'riderAssignedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(riderRef, {
          'acceptedOrdersCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
      });

      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final restaurantName = (orderData['restaurantName'] ?? 'Restaurant').toString();
        final restaurantAddress = (orderData['restaurantAddress'] ?? orderData['pickupAddress'] ?? 'Pickup Location').toString();
        final deliveryFee = (orderData['deliveryFee'] as num?)?.toDouble() ?? (orderData['fee'] as num?)?.toDouble() ?? 0.0;
        final deliveryFeeLabel = '₦${deliveryFee.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

        showOrderAcceptedSuccessSheet(
          context: context,
          orderId: orderId,
          restaurantName: restaurantName,
          pickupAddress: restaurantAddress,
          deliveryFeeLabel: deliveryFeeLabel,
          isDark: isDark,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(riderProfileProvider);
    final online = ref.watch(riderAvailabilityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    final firstName = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim().split(RegExp(r'\s+')).first
        : 'Rider';

    final currentRiderUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Responsive.maxContainer(
            context: context,
            maxWidth: 600,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rider Suspended Banner
                  if (profile.isSuspended) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.shieldAlert, color: Colors.red, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Account Currently Suspended',
                                  style: TextStyle(
                                    fontSize: AppTypography.font(15),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Reason: ${profile.suspensionReason.isNotEmpty ? profile.suspensionReason : 'Fleet Operational Audit'}. Order dispatch and online availability are disabled.',
                            style: TextStyle(
                              fontSize: AppTypography.font(12),
                              color: isDark ? Colors.red[200] : Colors.red[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── 1. Top Header: Avatar + Greeting + Notification Bell ───────
                  Row(
                    children: [
                      // Circular Rider Avatar
                      GestureDetector(
                        onTap: () => context.go('/account'),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: purpleColor.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: profile.avatarUrl,
                              fit: BoxFit.cover,
                              placeholder: (c, u) => Container(
                                color: purpleColor.withValues(alpha: 0.1),
                                child: Icon(LucideIcons.user, color: purpleColor, size: 22),
                              ),
                              errorWidget: (c, u, e) => Container(
                                color: purpleColor.withValues(alpha: 0.1),
                                child: Icon(LucideIcons.user, color: purpleColor, size: 22),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Greeting & Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_getGreeting()}, $firstName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppTypography.font(17),
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              online ? 'Ready to Deliver ?' : 'You are currently offline',
                              style: TextStyle(
                                fontSize: AppTypography.font(13),
                                color: mutedTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Notification Bell Button with Realtime Unread Count Badge
                      StreamBuilder<QuerySnapshot>(
                        stream: currentRiderUid.isNotEmpty
                            ? FirebaseFirestore.instance
                                .collection('riders')
                                .doc(currentRiderUid)
                                .collection('notifications')
                                .where('read', isEqualTo: false)
                                .snapshots()
                            : const Stream.empty(),
                        builder: (context, snapshot) {
                          final unreadCount = snapshot.data?.docs.length ?? 0;

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cardBg,
                                  border: Border.all(color: borderColor, width: 1),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: Image.asset(
                                    'lib/assets/icon/dark/notification.png',
                                    width: 22,
                                    height: 22,
                                    fit: BoxFit.contain,
                                  ),
                                  onPressed: () => context.push('/notifications'),
                                ),
                              ),
                              if (unreadCount > 0)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: unreadCount > 9 ? 5 : 4,
                                      vertical: 2,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                      minHeight: 18,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark
                                            ? AppTheme.darkSurface
                                            : Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        unreadCount > 99 ? '99+' : '$unreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          height: 1.1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ── 2. Current Balance Card with Container Background Asset ───────
                  Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A154B),
                      borderRadius: BorderRadius.circular(24),
                      image: const DecorationImage(
                        image: AssetImage('lib/assets/home/wallet balance container.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Current Balance',
                            style: TextStyle(
                              fontSize: AppTypography.font(12),
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _obscureBalance ? '••••••' : profile.balanceLabel,
                                style: TextStyle(
                                  fontSize: AppTypography.font(24),
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() => _obscureBalance = !_obscureBalance);
                                },
                                child: Icon(
                                  _obscureBalance
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── 3. Availability Switch ─────────────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        Transform.scale(
                          scale: 1.1,
                          child: Switch(
                            value: online,
                            activeThumbColor: Colors.white,
                            activeTrackColor: purpleColor,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: isDark ? Colors.grey[700] : Colors.grey[300],
                            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                            onChanged: (v) {
                              if (profile.verificationStatus != 'verified') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Please verify your identity before you can come online or accept orders.",
                                    ),
                                  ),
                                );
                                return;
                              }
                              ref.read(riderAvailabilityProvider.notifier).setOnline(v);
                            },
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Available for Deliveries',
                          style: TextStyle(
                            fontSize: AppTypography.font(13),
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── 4. Metrics Card (Deliveries & Acceptance Rate) ──────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Row(
                      children: [
                        // Left: Deliveries
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF3E8FF),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Image.asset(
                                    'lib/assets/icon/dark/deliveries.png',
                                    width: 20,
                                    height: 20,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Deliveries',
                                style: TextStyle(
                                  fontSize: AppTypography.font(12),
                                  color: mutedTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${profile.completedOrders}',
                                style: TextStyle(
                                  fontSize: AppTypography.font(18),
                                  fontWeight: FontWeight.w800,
                                  color: primaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Vertical Hairline Divider
                        Container(
                          width: 1,
                          height: 50,
                          color: borderColor,
                        ),

                        // Right: Acceptance Rate
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF3E8FF),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Image.asset(
                                    'lib/assets/icon/dark/rating.png',
                                    width: 20,
                                    height: 20,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Acceptance Rate',
                                style: TextStyle(
                                  fontSize: AppTypography.font(12),
                                  color: mutedTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profile.acceptanceRateLabel,
                                style: TextStyle(
                                  fontSize: AppTypography.font(18),
                                  fontWeight: FontWeight.w800,
                                  color: primaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── 5. Available Orders Section Header ─────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Available Orders',
                        style: TextStyle(
                          fontSize: AppTypography.font(18),
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/incoming-orders'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkBorder : const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'View all',
                            style: TextStyle(
                              fontSize: AppTypography.font(13),
                              fontWeight: FontWeight.bold,
                              color: purpleColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── 6. Active Broadcast Order Card or Empty State ──────────────
                  StreamBuilder<QuerySnapshot>(
                    stream: _broadcastOrdersStream,
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];

                      final riderLat = profile.currentLocation?.latitude ?? 6.5244;
                      final riderLng = profile.currentLocation?.longitude ?? 3.3792;

                      // Filter out orders that the rider has declined, already assigned, or outside broadcast radius
                      final availableOrders = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final declined = (data['declinedRiders'] as List<dynamic>?) ?? [];
                        final riderId = (data['riderId'] ?? '').toString();
                        final status = (data['status'] ?? '').toString();
                        final radiusKm = (data['broadcastRadiusKm'] as num?)?.toDouble() ?? 3.0;

                        if (declined.contains(currentRiderUid) ||
                            riderId.isNotEmpty ||
                            !(status == 'ready_for_pickup' || status == 'order_ready' || status == 'order_accepted' || status == 'broadcasting')) {
                          return false;
                        }

                        // Strictly enforce broadcast radius set by admin/vendor
                        final vendorLoc = _VendorDistanceText.extractGeoPoint(data['currentvendorLocation']) ??
                            _VendorDistanceText.extractGeoPoint(data['currentVendorLocation']) ??
                            _VendorDistanceText.extractGeoPoint(data['restaurantLocation']) ??
                            _VendorDistanceText.extractGeoPoint(data['vendorLocation']) ??
                            _VendorDistanceText.extractGeoPoint(data['pickupLocation']);

                        if (vendorLoc != null) {
                          final dist = _VendorDistanceText.calcHaversine(riderLat, riderLng, vendorLoc.latitude, vendorLoc.longitude);
                          if (dist > radiusKm) {
                            return false;
                          }
                        }
                        return true;
                      }).toList();

                      if (availableOrders.isEmpty) {
                        return _buildEmptyOrdersState(isDark, cardBg, borderColor, purpleColor);
                      }

                      // Show top available broadcast order
                      final topDoc = availableOrders.first;
                      final topData = topDoc.data() as Map<String, dynamic>;
                      final orderId = topDoc.id;

                      return _buildFeaturedOrderCard(
                        context,
                        orderId,
                        topData,
                        isDark,
                        cardBg,
                        borderColor,
                        purpleColor,
                        primaryTextColor,
                        mutedTextColor,
                      );
                    },
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyOrdersState(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color purpleColor,
  ) {
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: purpleColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.packageCheck, color: purpleColor, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            'No Available Orders',
            style: TextStyle(
              fontSize: AppTypography.font(15),
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'New delivery requests will appear here when restaurants nearby broadcast orders.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTypography.font(12),
              color: mutedTextColor,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 38,
            child: OutlinedButton(
              onPressed: () => context.push('/incoming-orders'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: purpleColor, width: 1),
                foregroundColor: purpleColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(19),
                ),
              ),
              child: Text(
                'View Incoming Requests',
                style: TextStyle(
                  fontSize: AppTypography.font(13),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedOrderCard(
    BuildContext context,
    String orderId,
    Map<String, dynamic> data,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color purpleColor,
    Color primaryTextColor,
    Color mutedTextColor,
  ) {
    final restaurantName = (data['restaurantName'] ?? 'Restaurant').toString();
    final restaurantAddress = (data['restaurantAddress'] ?? data['pickupAddress'] ?? 'Pickup Location').toString();
    final customerAddress = ((data['deliveryAddress'] is Map ? data['deliveryAddress']['address'] : null) ??
            data['dropoffAddress'] ??
            data['customerAddress'] ??
            'Delivery Location')
        .toString();
    final logoUrl = (data['logoUrl'] ??
            data['vendorLogo'] ??
            data['vendorLogoUrl'] ??
            data['restaurantLogo'] ??
            data['restaurantPhoto'] ??
            '')
        .toString();
    final vendorId = (data['vendorId'] ?? data['merchantId'] ?? '').toString();
    final deliveryFee = (data['deliveryFee'] as num?)?.toDouble() ??
        (data['fee'] as num?)?.toDouble() ??
        0.0;

    final riderProfile = ref.watch(riderProfileProvider);
    final riderLoc = riderProfile.currentLocation;

    return GestureDetector(
      onTap: () => context.push('/order-request/$orderId'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Restaurant Thumbnail + Name + Location ────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OrderVendorLogo(
                  logoUrl: logoUrl,
                  vendorId: vendorId,
                  purpleColor: purpleColor,
                  size: 44,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppTypography.font(15),
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(LucideIcons.package, size: 12, color: purpleColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              restaurantAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppTypography.font(12),
                                color: mutedTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Stepper: Pick Up & Drop Off ──────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dots & Connector Line
                Column(
                  children: [
                    _buildStepperDot(purpleColor),
                    Container(
                      width: 1.5,
                      height: 38,
                      color: isDark ? AppTheme.darkBorder : const Color(0xFFD8B4FE),
                    ),
                    _buildStepperDot(purpleColor),
                  ],
                ),
                const SizedBox(width: 12),

                // Pickup & Dropoff Labels and Addresses
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pickup
                      Text(
                        'Pick Up',
                        style: TextStyle(
                          fontSize: AppTypography.font(11),
                          color: mutedTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        restaurantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppTypography.font(14),
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Dropoff
                      Text(
                        'Drop Off',
                        style: TextStyle(
                          fontSize: AppTypography.font(11),
                          color: mutedTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        customerAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppTypography.font(14),
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Distance ─────────────────────────────────────────────────────
            Row(
              children: [
                Icon(LucideIcons.locate, size: 14, color: mutedTextColor),
                const SizedBox(width: 4),
                _VendorDistanceText(
                  data: data,
                  riderLocation: riderLoc,
                  textColor: mutedTextColor,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Estimated Earnings Pill Box ──────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? purpleColor.withValues(alpha: 0.12)
                    : const Color(0xFFFAF5FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    '₦${deliveryFee.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                    style: TextStyle(
                      fontSize: AppTypography.font(20),
                      fontWeight: FontWeight.w800,
                      color: purpleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Estimated earnings',
                    style: TextStyle(
                      fontSize: AppTypography.font(11),
                      color: mutedTextColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Action Buttons (Decline / Accept) ──────────────────────────────
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => _declineOrder(orderId),
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
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _acceptOrder(data, orderId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purpleColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
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
          ],
        ),
      ),
    );
  }

  Widget _buildStepperDot(Color purpleColor) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: purpleColor, width: 2),
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: purpleColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Dynamic Vendor Logo with Firestore lookup & caching
class _OrderVendorLogo extends StatelessWidget {
  final String logoUrl;
  final String vendorId;
  final Color purpleColor;
  final double size;

  const _OrderVendorLogo({
    required this.logoUrl,
    required this.vendorId,
    required this.purpleColor,
    this.size = 44,
  });

  static final Map<String, String> _cache = {};

  @override
  Widget build(BuildContext context) {
    if (logoUrl.isNotEmpty) {
      return _buildImage(logoUrl);
    }
    if (vendorId.isNotEmpty && _cache.containsKey(vendorId)) {
      final cached = _cache[vendorId]!;
      if (cached.isNotEmpty) {
        return _buildImage(cached);
      }
    }
    if (vendorId.isNotEmpty) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('vendors').doc(vendorId).get(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final bProfile = data['businessProfile'] as Map<String, dynamic>?;
            final pProfile = data['pendingBusinessProfile'] as Map<String, dynamic>?;
            final logo = (bProfile?['logoUrl'] ??
                    pProfile?['logoUrl'] ??
                    data['logoUrl'] ??
                    data['vendorLogo'] ??
                    data['profilePic'] ??
                    data['photoUrl'] ??
                    '')
                .toString();
            if (logo.isNotEmpty) {
              _cache[vendorId] = logo;
              return _buildImage(logo);
            }
          }
          return _buildPlaceholder();
        },
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildImage(String url) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size > 44 ? 12 : 10),
        color: purpleColor.withValues(alpha: 0.1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size > 44 ? 12 : 10),
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (c, u) => Container(
            color: purpleColor.withValues(alpha: 0.1),
            child: Icon(LucideIcons.store, color: purpleColor, size: size * 0.5),
          ),
          errorWidget: (c, u, e) => Container(
            color: purpleColor.withValues(alpha: 0.1),
            child: Icon(LucideIcons.store, color: purpleColor, size: size * 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size > 44 ? 12 : 10),
        color: purpleColor.withValues(alpha: 0.1),
      ),
      child: Center(
        child: Icon(LucideIcons.store, color: purpleColor, size: size * 0.5),
      ),
    );
  }
}

/// Dynamic Vendor Distance with Firestore lookup & caching
class _VendorDistanceText extends StatelessWidget {
  final Map<String, dynamic> data;
  final GeoPoint? riderLocation;
  final Color textColor;

  const _VendorDistanceText({
    required this.data,
    required this.riderLocation,
    required this.textColor,
  });

  static final Map<String, GeoPoint> _vendorLocCache = {};

  static GeoPoint? extractGeoPoint(dynamic val) {
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

  @override
  Widget build(BuildContext context) {
    GeoPoint? vendorLoc = extractGeoPoint(data['currentvendorLocation']) ??
        extractGeoPoint(data['currentVendorLocation']) ??
        extractGeoPoint(data['restaurantLocation']) ??
        extractGeoPoint(data['vendorLocation']) ??
        extractGeoPoint(data['pickupLocation']);

    if (vendorLoc != null) {
      return _renderDistance(vendorLoc);
    }

    final vendorId = (data['vendorId'] ?? data['merchantId'] ?? data['restaurantId'] ?? '').toString();
    if (vendorId.isNotEmpty && _vendorLocCache.containsKey(vendorId)) {
      return _renderDistance(_vendorLocCache[vendorId]!);
    }

    if (vendorId.isNotEmpty) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('vendors').doc(vendorId).get(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final vData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final bProf = vData['businessProfile'] as Map<String, dynamic>?;
            final pProf = vData['pendingBusinessProfile'] as Map<String, dynamic>?;

            final found = extractGeoPoint(bProf?['currentvendorLocation']) ??
                extractGeoPoint(bProf?['currentVendorLocation']) ??
                extractGeoPoint(pProf?['currentvendorLocation']) ??
                extractGeoPoint(pProf?['currentVendorLocation']) ??
                extractGeoPoint(vData['currentvendorLocation']) ??
                extractGeoPoint(vData['currentVendorLocation']) ??
                extractGeoPoint(vData['location']);

            if (found != null) {
              _vendorLocCache[vendorId] = found;
              return _renderDistance(found);
            }
          }
          return _renderFallback();
        },
      );
    }

    return _renderFallback();
  }

  Widget _renderDistance(GeoPoint vendorLoc) {
    final riderLat = riderLocation?.latitude ?? 6.5244;
    final riderLng = riderLocation?.longitude ?? 3.3792;
    final km = calcHaversine(riderLat, riderLng, vendorLoc.latitude, vendorLoc.longitude);
    return Text(
      '${km.toStringAsFixed(1)} km',
      style: TextStyle(
        fontSize: AppTypography.font(12),
        color: textColor,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _renderFallback() {
    return Text(
      '-- km',
      style: TextStyle(
        fontSize: AppTypography.font(12),
        color: textColor,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  static double calcHaversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * (pi / 180.0);
    final dLon = (lon2 - lon1) * (pi / 180.0);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) * cos(lat2 * (pi / 180.0)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }
}
