import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/rider_location_service.dart';
import '../domain/bank_details.dart';
import 'session_provider.dart';

class RiderAvailabilityNotifier extends Notifier<bool> {
  StreamSubscription<DocumentSnapshot>? _sub;

  @override
  bool build() {
    final uid = ref.watch(currentRiderUidProvider);
    _sub?.cancel();
    ref.onDispose(() {
      _sub?.cancel();
      RiderLocationService.instance.stopLiveTracking();
    });

    if (uid == null || uid.isEmpty) {
      return false;
    }

    _listenToAvailability(uid);
    return false;
  }

  void _listenToAvailability(String uid) {
    _sub?.cancel();

    _sub = FirebaseFirestore.instance
        .collection('riders')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        final status = (doc.data()!['status'] ?? 'offline').toString().toLowerCase().trim();
        final isOnlineFlag = doc.data()!['isOnline'] == true ||
            doc.data()!['isOnline']?.toString().toLowerCase() == 'true';
        final isOnline = (status == 'online' || status == 'available' || isOnlineFlag) && status != 'offline';
        state = isOnline;

        if (isOnline) {
          RiderLocationService.instance.startLiveTracking();
        } else {
          RiderLocationService.instance.stopLiveTracking();
        }
      } else {
        state = false;
        RiderLocationService.instance.stopLiveTracking();
      }
    });
  }

  Future<void> setOnline(bool value) async {
    final uid = ref.read(currentRiderUidProvider) ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (value) {
      RiderLocationService.instance.startLiveTracking();
    } else {
      RiderLocationService.instance.stopLiveTracking();
    }

    final batch = FirebaseFirestore.instance.batch();

    final riderRef = FirebaseFirestore.instance.collection('riders').doc(uid);
    batch.update(riderRef, {
      'status': value ? 'online' : 'offline',
      'isOnline': value,
    });

    final presenceRef = FirebaseFirestore.instance.collection('rider_presence').doc(uid);
    batch.set(presenceRef, {
      'uid': uid,
      'status': value ? 'online' : 'offline',
      'isOnline': value,
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}

final riderAvailabilityProvider =
    NotifierProvider<RiderAvailabilityNotifier, bool>(
  RiderAvailabilityNotifier.new,
);

class BankDetailsNotifier extends Notifier<BankDetails?> {
  StreamSubscription<DocumentSnapshot>? _sub;

  @override
  BankDetails? build() {
    final uid = ref.watch(currentRiderUidProvider);
    _sub?.cancel();
    ref.onDispose(() => _sub?.cancel());

    if (uid == null || uid.isEmpty) {
      return null;
    }

    _listenToBankDetails(uid);
    return null;
  }

  void _listenToBankDetails(String uid) {
    _sub?.cancel();

    _sub = FirebaseFirestore.instance
        .collection('riders')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['bankDetails'] != null) {
          final bank = data['bankDetails'] as Map<String, dynamic>;
          state = BankDetails(
            bankName: bank['bankName'] ?? '',
            accountName: bank['accountName'] ?? '',
            accountNumber: bank['accountNumber'] ?? '',
            bankCode: bank['bankCode'],
          );
        } else {
          state = null;
        }
      } else {
        state = null;
      }
    });
  }

  Future<void> save(BankDetails details) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('riders').doc(uid).update({
      'bankDetails': {
        'bankName': details.bankName,
        'accountName': details.accountName,
        'accountNumber': details.accountNumber,
        'bankCode': details.bankCode,
      }
    });
  }

  Future<void> delete() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('riders').doc(uid).update({
      'bankDetails': FieldValue.delete(),
    });
    state = null;
  }
}

final bankDetailsProvider = NotifierProvider<BankDetailsNotifier, BankDetails?>(
  BankDetailsNotifier.new,
);
