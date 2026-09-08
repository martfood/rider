import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'order_stage.dart';

/// A delivery assignment shown to the rider.
class RiderOrder extends Equatable {
  /// Unique order id for routing and updates.
  final String id;

  /// Restaurant display name.
  final String restaurantName;

  /// Restaurant address line.
  final String restaurantAddress;

  /// Customer display name.
  final String customerName;

  /// Masked phone for display.
  final String customerPhoneMasked;

  /// Drop-off address.
  final String customerAddress;

  /// Pickup address or store name.
  final String pickupAddress;

  /// Line items (name × qty).
  final List<String> menuLines;

  /// Current workflow stage.
  final OrderStage stage;

  /// Raw order status string from Firestore.
  final String rawStatus;

  /// Customer-provided delivery confirmation code (mock).
  final String deliveryCode;

  /// Estimated pickup or delivery window label.
  final String etaLabel;

  /// Raw customer phone number for phone dialer.
  final String customerPhone;

  /// Raw restaurant/vendor phone number for phone dialer.
  final String restaurantPhone;

  /// Vendor ID associated with the restaurant.
  final String vendorId;

  /// Delivery fee / earnings for this order.
  final double deliveryFee;

  /// Restaurant/Vendor photo URL.
  final String restaurantPhoto;

  /// Vendor logo URL.
  final String logoUrl;

  /// Vendor pickup location coordinates.
  final GeoPoint? vendorLocation;

  /// Formatted delivery earnings label.
  String get deliveryFeeLabel {
    final parts = deliveryFee.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return '₦$parts';
  }

  const RiderOrder({
    required this.id,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.customerName,
    required this.customerPhoneMasked,
    required this.customerAddress,
    this.pickupAddress = '',
    required this.menuLines,
    required this.stage,
    this.rawStatus = 'pending',
    required this.deliveryCode,
    required this.etaLabel,
    required this.customerPhone,
    required this.restaurantPhone,
    required this.vendorId,
    this.deliveryFee = 0.0,
    this.restaurantPhoto = '',
    this.logoUrl = '',
    this.vendorLocation,
  });

  /// Returns a copy with selective overrides.
  RiderOrder copyWith({
    OrderStage? stage,
    String? rawStatus,
    GeoPoint? vendorLocation,
  }) {
    return RiderOrder(
      id: id,
      restaurantName: restaurantName,
      restaurantAddress: restaurantAddress,
      customerName: customerName,
      customerPhoneMasked: customerPhoneMasked,
      customerAddress: customerAddress,
      pickupAddress: pickupAddress,
      menuLines: menuLines,
      stage: stage ?? this.stage,
      rawStatus: rawStatus ?? this.rawStatus,
      deliveryCode: deliveryCode,
      etaLabel: etaLabel,
      customerPhone: customerPhone,
      restaurantPhone: restaurantPhone,
      vendorId: vendorId,
      deliveryFee: deliveryFee,
      restaurantPhoto: restaurantPhoto,
      logoUrl: logoUrl,
      vendorLocation: vendorLocation ?? this.vendorLocation,
    );
  }

  @override
  List<Object?> get props => [
        id,
        restaurantName,
        restaurantAddress,
        customerName,
        customerPhoneMasked,
        customerAddress,
        pickupAddress,
        menuLines,
        stage,
        rawStatus,
        deliveryCode,
        etaLabel,
        customerPhone,
        restaurantPhone,
        vendorId,
        deliveryFee,
        restaurantPhoto,
        logoUrl,
      ];

  static OrderStage stageFromStatus(String status) {
    switch (status) {
      case 'pending':
      case 'pending_verification':
      case 'preparing':
      case 'accepted':
      case 'rider_assigned':
        return OrderStage.enRouteToRestaurant;
      case 'at_restaurant':
      case 'order_ready':
      case 'ready_for_pickup':
        return OrderStage.atRestaurant;
      case 'in_transit':
      case 'heading_to_customer':
        return OrderStage.headingToCustomer;
      case 'arrived':
      case 'awaiting_delivery_code':
        return OrderStage.awaitingDeliveryCode;
      case 'delivered':
      case 'completed':
        return OrderStage.delivered;
      default:
        return OrderStage.enRouteToRestaurant;
    }
  }

  static String statusFromStage(OrderStage stage) {
    switch (stage) {
      case OrderStage.enRouteToRestaurant:
        return 'rider_assigned';
      case OrderStage.atRestaurant:
        return 'at_restaurant';
      case OrderStage.headingToCustomer:
        return 'in_transit';
      case OrderStage.readyToMarkDelivered:
      case OrderStage.awaitingDeliveryCode:
        return 'arrived';
      case OrderStage.delivered:
        return 'delivered';
    }
  }

  factory RiderOrder.fromMap(String id, Map<String, dynamic> data) {
    final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
    final deliveryAddress =
        Map<String, dynamic>.from(data['deliveryAddress'] ?? {});

    final rawStat = (data['status'] ?? 'pending').toString();
    final fee = (data['deliveryFee'] as num?)?.toDouble() ??
        (data['fee'] as num?)?.toDouble() ??
        1250.0;
    final vendorId = (data['vendorId'] ??
            data['merchantId'] ??
            data['restaurantId'] ??
            data['vendor_id'] ??
            '')
        .toString();
    final logo = (data['logoUrl'] ??
            data['vendorLogo'] ??
            data['vendorLogoUrl'] ??
            data['restaurantLogo'] ??
            data['restaurantPhoto'] ??
            data['vendorPhoto'] ??
            data['storeLogo'] ??
            data['businessLogo'] ??
            '')
        .toString();
    final pickup = (data['pickupAddress'] ?? data['restaurantAddress'] ?? data['restaurantName'] ?? '').toString();

    GeoPoint? extractGeoPoint(dynamic val) {
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

    final vendorLoc = extractGeoPoint(data['currentvendorLocation']) ??
        extractGeoPoint(data['currentVendorLocation']) ??
        extractGeoPoint(data['restaurantLocation']) ??
        extractGeoPoint(data['vendorLocation']) ??
        extractGeoPoint(data['pickupLocation']);

    return RiderOrder(
      id: id,
      restaurantName: (data['restaurantName'] ?? 'MartFood').toString(),
      restaurantAddress: (data['restaurantAddress'] ?? '').toString(),
      customerName: (data['customerName'] ?? 'Customer').toString(),
      customerPhoneMasked: (data['customerPhone'] ?? '').toString(),
      customerAddress: (deliveryAddress['address'] ?? data['dropoffAddress'] ?? data['customerAddress'] ?? '').toString(),
      pickupAddress: pickup,
      customerPhone: (data['phoneNumber'] ?? data['customerPhone'] ?? '').toString(),
      restaurantPhone: (data['phone'] ?? data['restaurantPhone'] ?? '').toString(),
      vendorId: vendorId,
      deliveryFee: fee,
      restaurantPhoto: logo,
      logoUrl: logo,
      vendorLocation: vendorLoc,
      rawStatus: rawStat,
      menuLines: items.map((item) {
        final title = (item['title'] ?? 'Item').toString();
        final quantity = item['quantity'] ?? 1;
        final selectedChoices =
            List<Map<String, dynamic>>.from(item['selectedChoices'] ?? []);
        final selectedAddOns =
            List<Map<String, dynamic>>.from(item['selectedAddOns'] ?? []);

        final options = selectedChoices
            .map((choice) {
              final group = (choice['group'] ?? '').toString();
              final label = (choice['label'] ?? '').toString();
              if (label.isEmpty) return '';
              return group.isEmpty ? label : '$group: $label';
            })
            .where((v) => v.isNotEmpty)
            .toList();

        final addOns = selectedAddOns
            .map((addon) {
              final name = (addon['name'] ?? addon['title'] ?? '').toString();
              return name.isNotEmpty ? '+$name' : '';
            })
            .where((v) => v.isNotEmpty)
            .toList();

        final combined = [...options, ...addOns];

        if (combined.isEmpty) {
          return '$quantity × $title';
        }

        return '$quantity × $title — ${combined.join(', ')}';
      }).toList(),
      stage: stageFromStatus(rawStat),
      deliveryCode: (data['deliveryPin'] ?? data['deliveryCode'] ?? '').toString(),
      etaLabel: rawStat,
    );
  }
}
