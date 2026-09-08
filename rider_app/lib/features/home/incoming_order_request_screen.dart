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

import '../../providers/rider_profile_provider.dart';
import 'order_acceptance_success_sheet.dart';

class IncomingOrderRequestScreen extends ConsumerStatefulWidget {
  const IncomingOrderRequestScreen({super.key});

  @override
  ConsumerState<IncomingOrderRequestScreen> createState() =>
      _IncomingOrderRequestScreenState();
}

class _IncomingOrderRequestScreenState
    extends ConsumerState<IncomingOrderRequestScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late final Stream<QuerySnapshot> _broadcastOrdersStream;

  @override
  void initState() {
    super.initState();
    _broadcastOrdersStream = _firestore
        .collection('orders')
        .where('broadcastStatus', isEqualTo: 'broadcasting')
        .snapshots();
  }


  Future<void> _declineOrder(String orderId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore.collection('orders').doc(orderId).update({
        'declinedRiders': FieldValue.arrayUnion([uid]),
      });
      await _firestore.collection('riders').doc(uid).set({
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
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final profile = ref.read(riderProfileProvider);
    final orderRef = _firestore.collection('orders').doc(orderId);
    final riderRef = _firestore.collection('riders').doc(uid);

    try {
      await _firestore.runTransaction((transaction) async {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final currentRider = _auth.currentUser;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Incoming Requests',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
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
            child: StreamBuilder<QuerySnapshot>(
              stream: _broadcastOrdersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(color: purpleColor),
                  );
                }

                final uid = currentRider?.uid ?? '';
                final profile = ref.watch(riderProfileProvider);
                final riderLat = profile.currentLocation?.latitude ?? 6.5244;
                final riderLng = profile.currentLocation?.longitude ?? 3.3792;
                final docs = snapshot.data?.docs ?? [];

                // Filter out orders that the rider has declined, already assigned, or outside broadcast radius
                final availableOrders = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final declined = (data['declinedRiders'] as List<dynamic>?) ?? [];
                  final riderId = (data['riderId'] ?? '').toString();
                  final status = (data['status'] ?? '').toString();
                  final radiusKm = (data['broadcastRadiusKm'] as num?)?.toDouble() ?? 3.0;

                  if (declined.contains(uid) ||
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
                  return _buildEmptyState(isDark, purpleColor);
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  itemCount: availableOrders.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final doc = availableOrders[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final orderId = doc.id;

                    return _buildOrderRequestCard(
                      context,
                      orderId,
                      data,
                      isDark,
                      purpleColor,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color purpleColor) {
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
                LucideIcons.radar,
                size: 52,
                color: purpleColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Available Requests',
              style: TextStyle(
                fontSize: AppTypography.font(AppFontSizes.titleLarge),
                color: primaryTextColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When nearby restaurants broadcast delivery requests, they will appear here in real time.',
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

  Widget _buildOrderRequestCard(
    BuildContext context,
    String orderId,
    Map<String, dynamic> data,
    bool isDark,
    Color purpleColor,
  ) {
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    final restaurantName = data['restaurantName'] as String? ?? 'Restaurant';
    final restaurantAddress = data['restaurantAddress'] as String? ?? 'Pickup Location';
    final customerAddress = data['customerAddress'] as String? ?? data['dropoffAddress'] as String? ?? 'Delivery Location';
    final logoUrl = (data['logoUrl'] ??
            data['vendorLogo'] ??
            data['vendorLogoUrl'] ??
            data['restaurantLogo'] ??
            data['restaurantPhoto'] ??
            data['vendorPhoto'] ??
            data['storeLogo'] ??
            data['businessLogo'] ??
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
          // ── Header: Restaurant details ───────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OrderVendorLogo(
                logoUrl: logoUrl,
                vendorId: vendorId,
                purpleColor: purpleColor,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.titleMedium),
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
          const SizedBox(height: 20),

          // ── Stepper: Pick Up & Drop-Off ────────────────────────────────────
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
                      restaurantAddress,
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
                      customerAddress,
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
          const SizedBox(height: 14),

          // ── Distance Chip ────────────────────────────────────────────────
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
          const SizedBox(height: 18),

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
                  '₦${deliveryFee > 0 ? deliveryFee.toStringAsFixed(0) : '1,250'}',
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
          const SizedBox(height: 18),

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
    this.size = 48,
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
