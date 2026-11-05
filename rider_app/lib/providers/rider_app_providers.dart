import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/notification_service.dart';
import '../core/services/rider_location_service.dart';
import '../domain/bank_details.dart';
import '../domain/bank_request.dart';
import 'rider_profile_provider.dart';
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

  /// Submits a bank details update request to the central `bank_requests` collection
  /// for administrative review, sends confirmation email, and records in-app notification.
  Future<void> submitUpdateRequest({
    required BankDetails requestedBank,
    BankDetails? currentBank,
    required RiderProfile profile,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('You must be logged in to update bank details.');

    final reqId = 'req_${uid}_${DateTime.now().millisecondsSinceEpoch}';
    final riderName = profile.displayName.isNotEmpty
        ? profile.displayName
        : (profile.username.isNotEmpty ? profile.username : 'Rider Partner');

    final bankReq = BankRequest(
      id: reqId,
      riderId: uid,
      userType: 'rider',
      riderName: riderName,
      riderEmail: profile.email,
      riderPhone: profile.phone,
      businessName: 'Rider Partner',
      currentBank: currentBank,
      requestedBank: requestedBank,
      status: 'pending',
      createdAt: DateTime.now().toUtc(),
    );

    // 1. Write bank request to Firestore
    await FirebaseFirestore.instance
        .collection('bank_requests')
        .doc(reqId)
        .set(bankReq.toMap());

    // 2. Dispatch in-app notification to riders/{uid}/notifications
    try {
      final last4 = requestedBank.accountNumber.length >= 4
          ? requestedBank.accountNumber.substring(requestedBank.accountNumber.length - 4)
          : requestedBank.accountNumber;
      await FirebaseFirestore.instance
          .collection('riders')
          .doc(uid)
          .collection('notifications')
          .add({
        'title': 'Bank Details Request Submitted',
        'body': 'Your request to update your settlement bank account to ${requestedBank.bankName} (**** $last4) is awaiting admin review.',
        'type': 'payout',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'actionUrl': '/account/bank-details',
      });
    } catch (_) {}

    // 3. Send email confirmation to the rider via Resend
    if (profile.email.isNotEmpty) {
      try {
        await NotificationService.sendEmail(
          to: profile.email,
          subject: 'Bank Details Update Request Received - MartFood',
          htmlContent: '''
            <div style="font-family: Arial, sans-serif; padding: 24px; color: #334155; max-width: 600px; margin: 0 auto; background: white; border: 1px solid #e2e8f0; border-radius: 12px;">
              <h2 style="color: #4F1174; margin-top: 0;">Bank Details Update Request Received</h2>
              <p>Hi $riderName,</p>
              <p>We have received your request to update your settlement bank account details on MartFood.</p>
              <div style="background: #f8fafc; border: 1px solid #e2e8f0; padding: 16px; border-radius: 8px; margin: 16px 0;">
                <p style="margin: 4px 0;"><strong>Bank Name:</strong> ${requestedBank.bankName}</p>
                <p style="margin: 4px 0;"><strong>Account Number:</strong> ${requestedBank.accountNumber}</p>
                <p style="margin: 4px 0;"><strong>Account Name:</strong> ${requestedBank.accountName}</p>
              </div>
              <p>Your request is currently under review by our administrative team. To ensure uninterrupted service, your existing active account (if any) will continue to receive weekly payouts until this update is approved.</p>
              <p>You will receive an in-app and push notification as soon as the review is complete.</p>
              <br/>
              <p>Thank you,</p>
              <p><strong>The MartFood Team</strong></p>
            </div>
          ''',
        );
      } catch (_) {}
    }
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

/// Real-time stream provider that listens for any active pending bank update requests for this rider
final riderPendingBankRequestProvider = StreamProvider.autoDispose<BankRequest?>((ref) {
  final uid = ref.watch(currentRiderUidProvider);
  if (uid == null || uid.isEmpty) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collection('bank_requests')
      .where('riderId', isEqualTo: uid)
      .snapshots()
      .map((snapshot) {
    final list = <BankRequest>[];
    for (final doc in snapshot.docs) {
      list.add(BankRequest.fromMap(doc.id, doc.data()));
    }
    final pending = list.where((r) => r.isPending).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return pending.isNotEmpty ? pending.first : null;
  });
});
