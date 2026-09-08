import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider_app/core/services/notification_service.dart';

class RiderProfile {
  final String displayName;
  final String username;
  final String avatarUrl;
  final double balance;
  final String verificationStatus; 
  final String rejectionReason;
  final String status;
  final String suspensionReason;
  final String email;
  final String phone;
  final String vehicleLabel;
  final int completedOrders;
  final int acceptedOrdersCount;
  final int declinedOrdersCount;
  final GeoPoint? currentLocation;

  bool get isSuspended => status == 'suspended';

  String get balanceLabel {
    final parts = balance.toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return '₦$whole.${parts[1]}';
  }

  bool get identityVerified => verificationStatus == 'verified';

  /// Live calculated acceptance rate (%)
  int get acceptanceRate {
    final total = acceptedOrdersCount + declinedOrdersCount;
    if (total == 0) return 100;
    final rate = ((acceptedOrdersCount / total) * 100).round();
    return rate.clamp(0, 100);
  }

  String get acceptanceRateLabel => '$acceptanceRate%';

  const RiderProfile({
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.balance,
    required this.verificationStatus,
    required this.rejectionReason,
    this.status = 'active',
    this.suspensionReason = '',
    required this.email,
    required this.phone,
    required this.vehicleLabel,
    required this.completedOrders,
    this.acceptedOrdersCount = 0,
    this.declinedOrdersCount = 0,
    this.currentLocation,
  });

  factory RiderProfile.fromMap(Map<String, dynamic> data) {
    final completed = (data['completedOrders'] as num?)?.toInt() ?? 0;
    final accepted = (data['acceptedOrdersCount'] as num?)?.toInt() ?? completed;
    final declined = (data['declinedOrdersCount'] as num?)?.toInt() ?? 0;
    final loc = data['currentLocation'] ?? data['location'];
    GeoPoint? geoPoint;
    if (loc is GeoPoint) {
      geoPoint = loc;
    } else if (data['lat'] != null && data['lng'] != null) {
      geoPoint = GeoPoint((data['lat'] as num).toDouble(), (data['lng'] as num).toDouble());
    }

    return RiderProfile(
      displayName: data['fullName'] ?? '',
      username: data['username'] ?? '',
      avatarUrl: data['photoUrl'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&q=80',
      balance: (data['walletBalance'] ?? 0.0).toDouble(),
      verificationStatus: data['verificationStatus'] ?? 'unverified',
      rejectionReason: data['rejectionReason'] ?? '',
      status: data['status'] ?? 'active',
      suspensionReason: data['suspensionReason'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      vehicleLabel: data['vehicleType'] ?? 'Bicycle',
      completedOrders: completed,
      acceptedOrdersCount: accepted,
      declinedOrdersCount: declined,
      currentLocation: geoPoint,
    );
  }
}

class RiderProfileNotifier extends Notifier<RiderProfile> {
  StreamSubscription<DocumentSnapshot>? _sub;

  @override
  RiderProfile build() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      NotificationService.registerRiderToken(uid);
      NotificationService.listenToFirestoreNotifications(uid);
    }
    _listenToProfile();
    ref.onDispose(() => _sub?.cancel());
    return const RiderProfile(
      displayName: 'Loading...',
      username: '',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&q=80',
      balance: 0.0,
      verificationStatus: 'unverified',
      rejectionReason: '',
      email: '',
      phone: '',
      vehicleLabel: 'Bicycle',
      completedOrders: 0,
      acceptedOrdersCount: 0,
      declinedOrdersCount: 0,
      currentLocation: null,
    );
  }

  void _listenToProfile() {
    _sub?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _sub = FirebaseFirestore.instance
        .collection('riders')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        state = RiderProfile.fromMap(doc.data()!);
      }
    });
  }
}

final riderProfileProvider =
    NotifierProvider<RiderProfileNotifier, RiderProfile>(
  RiderProfileNotifier.new,
);
