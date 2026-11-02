import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

class OrderBroadcastStatus {
  final GeoPoint? vendorLocation;
  final double? distanceKm;
  final double broadcastRadiusKm;

  const OrderBroadcastStatus({
    required this.vendorLocation,
    required this.distanceKm,
    required this.broadcastRadiusKm,
  });

  bool get exceedsRadius =>
      distanceKm != null && distanceKm! > broadcastRadiusKm;
}

class OrderBroadcastHelper {
  static final Map<String, Map<String, dynamic>> _vendorDocCache = {};
  static double? _cachedAdminRadiusKm;

  static String extractVendorId(Map<String, dynamic> data) {
    for (final key in ['vendorId', 'merchantId', 'restaurantId', 'vendor_id']) {
      final val = (data[key] ?? '').toString().trim();
      if (val.isNotEmpty && val.toLowerCase() != 'null') {
        return val;
      }
    }
    final items = data['items'];
    if (items is List && items.isNotEmpty) {
      final first = items.first;
      if (first is Map) {
        for (final key in ['vendorId', 'merchantId', 'restaurantId']) {
          final val = (first[key] ?? '').toString().trim();
          if (val.isNotEmpty && val.toLowerCase() != 'null') {
            return val;
          }
        }
      }
    }
    return '';
  }

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

  static GeoPoint? extractVendorLocation(
    Map<String, dynamic> orderData, {
    Map<String, dynamic>? vendorDoc,
  }) {
    final bProfOrder = orderData['businessProfile'] as Map<String, dynamic>?;
    final direct = extractGeoPoint(orderData['currentvendorLocation']) ??
        extractGeoPoint(orderData['currentVendorLocation']) ??
        extractGeoPoint(bProfOrder?['currentvendorLocation']) ??
        extractGeoPoint(bProfOrder?['currentVendorLocation']) ??
        extractGeoPoint(orderData['restaurantLocation']) ??
        extractGeoPoint(orderData['vendorLocation']) ??
        extractGeoPoint(orderData['pickupLocation']);

    if (direct != null) return direct;

    if (vendorDoc != null) {
      final bProf = vendorDoc['businessProfile'] as Map<String, dynamic>?;
      final pProf =
          vendorDoc['pendingBusinessProfile'] as Map<String, dynamic>?;
      final fromVendor = extractGeoPoint(bProf?['currentvendorLocation']) ??
          extractGeoPoint(bProf?['currentVendorLocation']) ??
          extractGeoPoint(pProf?['currentvendorLocation']) ??
          extractGeoPoint(pProf?['currentVendorLocation']) ??
          extractGeoPoint(vendorDoc['currentvendorLocation']) ??
          extractGeoPoint(vendorDoc['currentVendorLocation']) ??
          extractGeoPoint(vendorDoc['location']);
      if (fromVendor != null) return fromVendor;
    }

    return null;
  }

  static String? extractVendorAddress(
    Map<String, dynamic> orderData, {
    Map<String, dynamic>? vendorDoc,
  }) {
    bool isValidAddr(String val) {
      final lower = val.trim().toLowerCase();
      return lower.isNotEmpty &&
          lower != 'null' &&
          lower != 'pickup location' &&
          lower != 'merchant store';
    }

    // 1. Check vendor document businessProfile address first if available
    if (vendorDoc != null) {
      final bProf = vendorDoc['businessProfile'] as Map<String, dynamic>?;
      final pProf =
          vendorDoc['pendingBusinessProfile'] as Map<String, dynamic>?;
      for (final candidate in [
        bProf?['address'],
        bProf?['businessAddress'],
        pProf?['address'],
        pProf?['businessAddress'],
        vendorDoc['address'],
        vendorDoc['businessAddress'],
        vendorDoc['storeAddress'],
        vendorDoc['location'] is String ? vendorDoc['location'] : null,
      ]) {
        final str = (candidate ?? '').toString().trim();
        if (isValidAddr(str)) return str;
      }
    }

    // 2. Check order data address fields
    final bProfOrder = orderData['businessProfile'] as Map<String, dynamic>?;
    for (final candidate in [
      bProfOrder?['address'],
      bProfOrder?['businessAddress'],
      orderData['restaurantAddress'],
      orderData['pickupAddress'],
      orderData['vendorAddress'],
      orderData['businessAddress'],
      orderData['storeAddress'],
      orderData['address'],
    ]) {
      final str = (candidate ?? '').toString().trim();
      if (isValidAddr(str)) return str;
    }

    // 3. Fallback to formatted currentvendorLocation coordinates if present
    final geo = extractVendorLocation(orderData, vendorDoc: vendorDoc);
    if (geo != null) {
      return '${geo.latitude.toStringAsFixed(4)}, ${geo.longitude.toStringAsFixed(4)}';
    }

    return null;
  }

  static double calcHaversine(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * (pi / 180.0);
    final dLon = (lon2 - lon1) * (pi / 180.0);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) *
            cos(lat2 * (pi / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static Map<String, dynamic>? getCachedVendorDoc(String vendorId) {
    if (vendorId.isEmpty) return null;
    return _vendorDocCache[vendorId];
  }

  static Future<Map<String, dynamic>?> fetchVendorDoc(String vendorId) async {
    if (vendorId.isEmpty) return null;
    if (_vendorDocCache.containsKey(vendorId)) {
      return _vendorDocCache[vendorId];
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(vendorId)
          .get();
      if (snap.exists && snap.data() != null) {
        _vendorDocCache[vendorId] = snap.data()!;
        return snap.data()!;
      }
    } catch (_) {}
    return null;
  }

  static Future<double> fetchAdminBroadcastRadiusKm() async {
    if (_cachedAdminRadiusKm != null) return _cachedAdminRadiusKm!;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('settings')
          .doc('rider_settings')
          .get();
      if (snap.exists && snap.data() != null) {
        final val = (snap.data()!['broadcastRadiusKm'] as num?)?.toDouble();
        if (val != null && val > 0) {
          _cachedAdminRadiusKm = val;
          return val;
        }
      }
    } catch (_) {}
    _cachedAdminRadiusKm = 3.0;
    return 3.0;
  }

  static OrderBroadcastStatus computeStatusSync({
    required Map<String, dynamic> orderData,
    required GeoPoint? riderLocation,
  }) {
    final vendorId = extractVendorId(orderData);
    final vendorDoc = getCachedVendorDoc(vendorId);
    final vendorLoc = extractVendorLocation(orderData, vendorDoc: vendorDoc);
    final orderRadius = (orderData['broadcastRadiusKm'] as num?)?.toDouble();
    final radiusKm = (orderRadius != null && orderRadius > 0)
        ? orderRadius
        : (_cachedAdminRadiusKm ?? 3.0);

    double? distanceKm;
    if (vendorLoc != null) {
      final riderLat = riderLocation?.latitude ?? 6.5244;
      final riderLng = riderLocation?.longitude ?? 3.3792;
      distanceKm = calcHaversine(
        riderLat,
        riderLng,
        vendorLoc.latitude,
        vendorLoc.longitude,
      );
    }

    return OrderBroadcastStatus(
      vendorLocation: vendorLoc,
      distanceKm: distanceKm,
      broadcastRadiusKm: radiusKm,
    );
  }

  static Future<OrderBroadcastStatus> resolveBroadcastStatus({
    required Map<String, dynamic> orderData,
    required GeoPoint? riderLocation,
  }) async {
    final vendorId = extractVendorId(orderData);
    final results = await Future.wait([
      fetchVendorDoc(vendorId),
      fetchAdminBroadcastRadiusKm(),
    ]);
    final vendorDoc = results[0] as Map<String, dynamic>?;
    final adminRadius = results[1] as double;

    final vendorLoc = extractVendorLocation(orderData, vendorDoc: vendorDoc);
    final orderRadius = (orderData['broadcastRadiusKm'] as num?)?.toDouble();
    final radiusKm =
        (orderRadius != null && orderRadius > 0) ? orderRadius : adminRadius;

    double? distanceKm;
    if (vendorLoc != null) {
      final riderLat = riderLocation?.latitude ?? 6.5244;
      final riderLng = riderLocation?.longitude ?? 3.3792;
      distanceKm = calcHaversine(
        riderLat,
        riderLng,
        vendorLoc.latitude,
        vendorLoc.longitude,
      );
    }

    return OrderBroadcastStatus(
      vendorLocation: vendorLoc,
      distanceKm: distanceKm,
      broadcastRadiusKm: radiusKm,
    );
  }
}

/// Reactive builder that resolves vendor `currentvendorLocation` and `broadcastRadiusKm`
/// from the order document, `vendors/{vendorId}`, and `settings/rider_settings`.
class OrderBroadcastStatusBuilder extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final GeoPoint? riderLocation;
  final Widget Function(BuildContext context, OrderBroadcastStatus status)
      builder;

  const OrderBroadcastStatusBuilder({
    super.key,
    required this.orderData,
    required this.riderLocation,
    required this.builder,
  });

  @override
  State<OrderBroadcastStatusBuilder> createState() =>
      _OrderBroadcastStatusBuilderState();
}

class _OrderBroadcastStatusBuilderState
    extends State<OrderBroadcastStatusBuilder> {
  Future<OrderBroadcastStatus>? _future;

  @override
  void initState() {
    super.initState();
    _initFuture();
  }

  @override
  void didUpdateWidget(covariant OrderBroadcastStatusBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderData != widget.orderData ||
        oldWidget.riderLocation != widget.riderLocation) {
      _initFuture();
    }
  }

  void _initFuture() {
    _future = OrderBroadcastHelper.resolveBroadcastStatus(
      orderData: widget.orderData,
      riderLocation: widget.riderLocation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialStatus = OrderBroadcastHelper.computeStatusSync(
      orderData: widget.orderData,
      riderLocation: widget.riderLocation,
    );

    return FutureBuilder<OrderBroadcastStatus>(
      future: _future,
      initialData: initialStatus,
      builder: (context, snapshot) {
        final status = snapshot.data ?? initialStatus;
        return widget.builder(context, status);
      },
    );
  }
}

/// Dynamic Vendor Address (businessProfile.address / currentvendorLocation) with Firestore lookup & caching
class VendorAddressText extends StatelessWidget {
  final Map<String, dynamic> data;
  final TextStyle style;
  final int maxLines;
  final TextOverflow overflow;

  const VendorAddressText({
    super.key,
    required this.data,
    required this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    final vendorId = OrderBroadcastHelper.extractVendorId(data);
    final cachedVendor = OrderBroadcastHelper.getCachedVendorDoc(vendorId);
    final immediateAddr = OrderBroadcastHelper.extractVendorAddress(
      data,
      vendorDoc: cachedVendor,
    );

    if (immediateAddr != null && cachedVendor != null) {
      return Text(
        immediateAddr,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    if (vendorId.isNotEmpty) {
      return FutureBuilder<Map<String, dynamic>?>(
        future: OrderBroadcastHelper.fetchVendorDoc(vendorId),
        builder: (context, snapshot) {
          final resolved = OrderBroadcastHelper.extractVendorAddress(
            data,
            vendorDoc: snapshot.data ?? cachedVendor,
          );
          return Text(
            resolved ?? immediateAddr ?? 'Pickup Location',
            style: style,
            maxLines: maxLines,
            overflow: overflow,
          );
        },
      );
    }

    return Text(
      immediateAddr ?? 'Pickup Location',
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Dynamic Vendor Rating & Reviews Row displayed below the vendor name in the card header.
/// Queries `vendors/{vendorId}/reviews` and `vendors/{vendorId}` with zero hardcoded mock numbers.
class VendorRatingReviewsRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color primaryTextColor;
  final Color mutedTextColor;

  const VendorRatingReviewsRow({
    super.key,
    required this.data,
    required this.primaryTextColor,
    required this.mutedTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final vendorId = OrderBroadcastHelper.extractVendorId(data);

    if (vendorId.isEmpty) {
      final fallbackRating =
          (data['vendorRating'] ?? data['rating'] as num?)?.toDouble() ?? 0.0;
      final fallbackCount = (data['vendorReviewsCount'] ??
                  data['reviewsCount'] ??
                  data['ratingCount'] as num?)
              ?.toInt() ??
          0;
      return _buildRow(fallbackRating, fallbackCount);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vendors')
          .doc(vendorId)
          .collection('reviews')
          .snapshots(),
      builder: (context, reviewsSnap) {
        final reviewDocs = reviewsSnap.data?.docs ?? [];
        if (reviewDocs.isNotEmpty) {
          double sum = 0.0;
          for (final doc in reviewDocs) {
            final rData = doc.data() as Map<String, dynamic>? ?? {};
            sum += (rData['rating'] as num?)?.toDouble() ?? 0.0;
          }
          final avg = sum / reviewDocs.length;
          return _buildRow(avg, reviewDocs.length);
        }

        return FutureBuilder<Map<String, dynamic>?>(
          future: OrderBroadcastHelper.fetchVendorDoc(vendorId),
          builder: (context, vendorSnap) {
            final vDoc = vendorSnap.data ??
                OrderBroadcastHelper.getCachedVendorDoc(vendorId);
            final bProf = vDoc?['businessProfile'] as Map<String, dynamic>?;
            final rating = (vDoc?['rating'] ??
                        vDoc?['averageRating'] ??
                        bProf?['rating'] ??
                        data['vendorRating'] ??
                        data['rating'] as num?)
                    ?.toDouble() ??
                0.0;
            final count = (vDoc?['ratingCount'] ??
                        vDoc?['reviewsCount'] ??
                        bProf?['ratingCount'] ??
                        bProf?['reviewsCount'] ??
                        data['vendorReviewsCount'] ??
                        data['reviewsCount'] as num?)
                    ?.toInt() ??
                0;
            return _buildRow(rating, count);
          },
        );
      },
    );
  }

  Widget _buildRow(double rating, int reviewsCount) {
    final formattedRating = rating > 0 ? rating.toStringAsFixed(1) : '0.0';
    final reviewsLabel =
        '$reviewsCount ${reviewsCount == 1 ? 'review' : 'reviews'}';

    return Row(
      children: [
        const Icon(
          Icons.star_rounded,
          size: 15,
          color: AppTheme.accentColor,
        ),
        const SizedBox(width: 4),
        Text(
          formattedRating,
          style: TextStyle(
            fontSize: AppTypography.font(AppFontSizes.caption),
            fontWeight: FontWeight.w700,
            color: primaryTextColor,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '($reviewsLabel)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppTypography.font(AppFontSizes.caption),
              fontWeight: FontWeight.w500,
              color: mutedTextColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows a Minimal & Flat Bottom Sheet explaining why the rider cannot accept an order
/// when their distance to the vendor's `currentvendorLocation` exceeds `broadcastRadiusKm`.
Future<void> showOutOfBroadcastRadiusSheet({
  required BuildContext context,
  required double distanceKm,
  required double broadcastRadiusKm,
  String? restaurantName,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final purpleColor = AppTheme.primaryPurpleFor(isDark);
  final sheetBg = isDark ? AppTheme.darkSurface : Colors.white;
  final containerFill = isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
  final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
  final primaryTextColor = isDark ? Colors.white : Colors.black;
  final mutedTextColor = AppTheme.mutedTextColorFor(isDark);

  final vendorLabel =
      (restaurantName != null && restaurantName.trim().isNotEmpty)
          ? restaurantName.trim()
          : 'the vendor';

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    elevation: 0,
    backgroundColor: sheetBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Responsive.maxContainer(
          context: sheetContext,
          maxWidth: 460,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: containerFill,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Center(
                    child: Icon(
                      LucideIcons.mapPinOff,
                      size: 34,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Outside Broadcast Radius',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.displaySmall),
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'You cannot accept this delivery request because the distance from your current location to $vendorLabel (${distanceKm.toStringAsFixed(1)} km) exceeds the maximum allowed broadcast radius of ${broadcastRadiusKm.toStringAsFixed(1)} km.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodySmall),
                    color: mutedTextColor,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: containerFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Your Distance',
                              style: TextStyle(
                                fontSize:
                                    AppTypography.font(AppFontSizes.caption),
                                fontWeight: FontWeight.w600,
                                color: mutedTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${distanceKm.toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontSize:
                                    AppTypography.font(AppFontSizes.titleSmall),
                                fontWeight: FontWeight.w800,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: borderColor,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Max Broadcast Radius',
                              style: TextStyle(
                                fontSize:
                                    AppTypography.font(AppFontSizes.caption),
                                fontWeight: FontWeight.w600,
                                color: mutedTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${broadcastRadiusKm.toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontSize:
                                    AppTypography.font(AppFontSizes.titleSmall),
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
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purpleColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      'Understood',
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.titleSmall),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void showOfflineCannotAcceptOrderSheet({
  required BuildContext context,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final purpleColor = AppTheme.primaryPurpleFor(isDark);
  final sheetBg = isDark ? AppTheme.darkSurface : Colors.white;
  final primaryTextColor = isDark ? Colors.white : Colors.black;
  final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
  final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
  final containerFill =
      isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;

  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: sheetBg,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Responsive.maxContainer(
          context: sheetContext,
          maxWidth: 460,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: containerFill,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: const Center(
                    child: Icon(
                      LucideIcons.powerOff,
                      size: 34,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Availability Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.displaySmall),
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'You cannot accept this delivery request while offline. Please toggle "Available for Deliveries" to ON before accepting an order request.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodySmall),
                    color: mutedTextColor,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purpleColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      'Understood',
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.titleSmall),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      );
    },
  );
}
