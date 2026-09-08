import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

import '../../domain/order_stage.dart';
import '../../domain/rider_order.dart';
import '../../providers/orders_providers.dart';
import '../../providers/rider_profile_provider.dart';

/// Lists active and completed deliveries matching the Minimal & Flat mockup design.
class DeliveryShellScreen extends ConsumerStatefulWidget {
  const DeliveryShellScreen({super.key});

  @override
  ConsumerState<DeliveryShellScreen> createState() =>
      _DeliveryShellScreenState();
}

class _DeliveryShellScreenState extends ConsumerState<DeliveryShellScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    final orders = ref.watch(ordersProvider);
    final activeOrders = orders.active;
    final completedOrders = orders.completed;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: bg,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          'My Deliveries',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: AppTypography.font(AppFontSizes.titleLarge),
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: borderColor, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabs,
              indicatorColor: purpleColor,
              indicatorWeight: 3.0,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: purpleColor,
              unselectedLabelColor: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: AppTypography.font(15),
              ),
              unselectedLabelStyle: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: AppTypography.font(15),
              ),
              tabs: const [
                Tab(text: 'Active'),
                Tab(text: 'Complete'),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Responsive.maxContainer(
            context: context,
            maxWidth: 600,
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildOrderList(activeOrders, isActiveTab: true, isDark: isDark, purpleColor: purpleColor),
                _buildOrderList(completedOrders, isActiveTab: false, isDark: isDark, purpleColor: purpleColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderList(
    List<RiderOrder> orderList, {
    required bool isActiveTab,
    required bool isDark,
    required Color purpleColor,
  }) {
    if (orderList.isEmpty) {
      return _buildEmptyState(isActiveTab: isActiveTab, isDark: isDark, purpleColor: purpleColor);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: orderList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final order = orderList[index];
        return _buildDeliveryCard(order, isActiveTab: isActiveTab, isDark: isDark, purpleColor: purpleColor);
      },
    );
  }

  Widget _buildDeliveryCard(
    RiderOrder order, {
    required bool isActiveTab,
    required bool isDark,
    required Color purpleColor,
  }) {
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    final pickupText = order.pickupAddress.isNotEmpty
        ? order.pickupAddress
        : (order.restaurantAddress.isNotEmpty ? order.restaurantAddress : order.restaurantName);
    final dropoffText = order.customerAddress.isNotEmpty
        ? order.customerAddress
        : 'Customer Delivery Address';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Vendor Logo + Restaurant info + Status Chip ──────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VendorLogoThumbnail(order: order, purpleColor: purpleColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.restaurantName,
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
                            order.restaurantAddress.isNotEmpty
                                ? order.restaurantAddress
                                : 'Merchant Store',
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
              const SizedBox(width: 8),
              _buildStatusPill(order, isActiveTab: isActiveTab, purpleColor: purpleColor, isDark: isDark),
            ],
          ),
          const SizedBox(height: 18),

          // ── Stepper: Pick Up & Drop-Off ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  _buildStepperDot(purpleColor),
                  Container(
                    width: 2,
                    height: 36,
                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                  ),
                  _buildStepperDot(purpleColor),
                ],
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
                        color: mutedTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pickupText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Drop-Off',
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.bodySmall),
                        color: mutedTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dropoffText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
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
              _OrderDistanceLive(
                order: order,
                riderLocation: ref.watch(riderProfileProvider).currentLocation,
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
                  order.deliveryFeeLabel,
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
                    fontSize: AppTypography.font(AppFontSizes.bodySmall),
                    color: mutedTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── View Details Action Button ───────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => context.push('/order/${order.id}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: purpleColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(
                'View Details',
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
    );
  }

  Widget _buildStatusPill(
    RiderOrder order, {
    required bool isActiveTab,
    required Color purpleColor,
    required bool isDark,
  }) {
    if (!isActiveTab || order.stage == OrderStage.delivered || order.rawStatus == 'delivered') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF052E16) : const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF15803D),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'Completed',
              style: TextStyle(
                color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                fontSize: AppTypography.font(12),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (order.stage == OrderStage.atRestaurant ||
        order.rawStatus == 'at_restaurant' ||
        order.rawStatus == 'ready_for_pickup' ||
        order.rawStatus == 'order_ready') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFFB45309),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'Awaiting Pickup',
              style: TextStyle(
                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                fontSize: AppTypography.font(12),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    // Default active: In progress
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBorder : const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: purpleColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'In progress',
            style: TextStyle(
              color: purpleColor,
              fontSize: AppTypography.font(12),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required bool isActiveTab,
    required bool isDark,
    required Color purpleColor,
  }) {
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: purpleColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActiveTab ? LucideIcons.bike : LucideIcons.packageCheck,
                size: 48,
                color: purpleColor,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isActiveTab ? 'No Active Deliveries' : 'No Completed Deliveries',
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.titleLarge),
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isActiveTab
                  ? 'When you accept an order from the incoming requests feed, it will show up here.'
                  : 'Your successfully fulfilled orders and deliveries history will be listed here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                color: mutedTextColor,
                height: 1.4,
              ),
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

/// Dynamic Vendor Logo thumbnail with Firestore lookup & caching
class _VendorLogoThumbnail extends StatelessWidget {
  final RiderOrder order;
  final Color purpleColor;

  const _VendorLogoThumbnail({
    required this.order,
    required this.purpleColor,
  });

  static final Map<String, String> _vendorLogoCache = {};

  @override
  Widget build(BuildContext context) {
    if (order.logoUrl.isNotEmpty) {
      return _buildImage(order.logoUrl);
    }

    if (order.vendorId.isNotEmpty && _vendorLogoCache.containsKey(order.vendorId)) {
      final cached = _vendorLogoCache[order.vendorId]!;
      if (cached.isNotEmpty) {
        return _buildImage(cached);
      }
    }

    if (order.vendorId.isNotEmpty) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('vendors').doc(order.vendorId).get(),
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
              _vendorLogoCache[order.vendorId] = logo;
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: purpleColor.withValues(alpha: 0.1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          placeholder: (c, u) => Container(
            color: purpleColor.withValues(alpha: 0.1),
            child: Icon(LucideIcons.store, color: purpleColor, size: 22),
          ),
          errorWidget: (c, u, e) => Container(
            color: purpleColor.withValues(alpha: 0.1),
            child: Icon(LucideIcons.store, color: purpleColor, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: purpleColor.withValues(alpha: 0.1),
      ),
      child: Center(
        child: Icon(LucideIcons.store, color: purpleColor, size: 22),
      ),
    );
  }
}

/// Live distance display for active deliveries
class _OrderDistanceLive extends StatelessWidget {
  final RiderOrder order;
  final GeoPoint? riderLocation;
  final Color textColor;

  const _OrderDistanceLive({
    required this.order,
    required this.riderLocation,
    required this.textColor,
  });

  static final Map<String, GeoPoint> _vendorLocCache = {};

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

  @override
  Widget build(BuildContext context) {
    if (order.vendorLocation != null) {
      return _renderDistance(order.vendorLocation!);
    }

    final vendorId = order.vendorId;
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

            final found = _extractGeoPoint(bProf?['currentvendorLocation']) ??
                _extractGeoPoint(bProf?['currentVendorLocation']) ??
                _extractGeoPoint(pProf?['currentvendorLocation']) ??
                _extractGeoPoint(pProf?['currentVendorLocation']) ??
                _extractGeoPoint(vData['currentvendorLocation']) ??
                _extractGeoPoint(vData['currentVendorLocation']) ??
                _extractGeoPoint(vData['location']);

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
    final km = _calcHaversine(riderLat, riderLng, vendorLoc.latitude, vendorLoc.longitude);
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

  static double _calcHaversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * (pi / 180.0);
    final dLon = (lon2 - lon1) * (pi / 180.0);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) * cos(lat2 * (pi / 180.0)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }
}
