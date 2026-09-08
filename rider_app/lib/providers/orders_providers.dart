import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ledger_entry.dart';
import '../domain/order_stage.dart';
import '../domain/rider_order.dart';
import '../core/services/notification_service.dart';

/// Holds active and completed orders for the rider (mock).
class OrdersState extends Equatable {
  /// Orders currently in progress.
  final List<RiderOrder> active;

  /// Finished orders.
  final List<RiderOrder> completed;

  const OrdersState({
    required this.active,
    required this.completed,
  });

  @override
  List<Object?> get props => [active, completed];
}

class OrdersNotifier extends Notifier<OrdersState> {
  StreamSubscription<QuerySnapshot>? _ordersSub;

  @override
  OrdersState build() {
    _listenToOrders();
    ref.onDispose(() => _ordersSub?.cancel());
    return const OrdersState(active: [], completed: []);
  }

  void _listenToOrders() {
    _ordersSub?.cancel();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _ordersSub = FirebaseFirestore.instance
        .collection('orders')
        .where('riderId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      final active = <RiderOrder>[];
      final completed = <RiderOrder>[];

      final docs = List<QueryDocumentSnapshot>.from(snapshot.docs);
      docs.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>?;
        final bData = b.data() as Map<String, dynamic>?;
        final aTime = aData?['createdAt'];
        final bTime = bData?['createdAt'];
        if (aTime is Timestamp && bTime is Timestamp) {
          return bTime.compareTo(aTime);
        }
        if (aTime is String && bTime is String) {
          return bTime.compareTo(aTime);
        }
        return 0;
      });

      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = (data['status'] ?? '').toString();
        if (status == 'cancelled' || status == 'pending' || status == 'preparing') {
          continue;
        }

        final order = RiderOrder.fromMap(doc.id, data);
        if (status == 'delivered') {
          completed.add(order);
        } else {
          active.add(order);
        }
      }

      state = OrdersState(active: active, completed: completed);
    }, onError: (err) {
      debugPrint('[ordersProvider] Error listening to orders: $err');
    });
  }

  Future<void> setStage(String id, OrderStage stage) async {
    final status = RiderOrder.statusFromStage(stage);
    await FirebaseFirestore.instance.collection('orders').doc(id).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      final orderIndex = state.active.indexWhere((o) => o.id == id);
      if (orderIndex >= 0) {
        final order = state.active[orderIndex];
        
        final orderSnap = await FirebaseFirestore.instance.collection('orders').doc(id).get();
        if (orderSnap.exists) {
          final orderData = orderSnap.data();
          final customerId = orderData?['customerId'] as String?;
          
          if (customerId != null && customerId.isNotEmpty) {
            String title = '';
            String body = '';
            
            switch (status) {
              case 'at_restaurant':
                title = 'Rider at Restaurant 🏪';
                body = 'Your rider has arrived at the restaurant to pick up your order.';
                break;
              case 'in_transit':
                title = 'Order in Transit! 🚴';
                body = 'Your rider is on the way with your order from ${order.restaurantName}.';
                break;
              case 'arrived':
                title = 'Order has Arrived! 📦';
                body = 'Your rider is at your location. Please share delivery PIN: ${order.deliveryCode}.';
                break;
            }
            
            if (title.isNotEmpty) {
              await NotificationService.sendPushToCustomer(
                customerId: customerId,
                title: title,
                body: body,
                data: {'type': 'order_status', 'orderId': id, 'status': status},
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error triggering stage notification to customer: $e');
    }
  }

  Future<bool> tryCompleteWithCode(String id, String code) async {
    final firestore = FirebaseFirestore.instance;
    final orderRef = firestore.collection('orders').doc(id);

    // 1. Fetch order document first to verify existence and PIN
    final initialSnap = await orderRef.get();
    if (!initialSnap.exists) {
      debugPrint('[tryCompleteWithCode] Order $id does not exist');
      return false;
    }

    final initialData = initialSnap.data() as Map<String, dynamic>;
    final expectedPin = (initialData['deliveryPin'] ??
            initialData['deliveryCode'] ??
            initialData['pin'] ??
            initialData['verificationPin'] ??
            '')
        .toString()
        .trim();

    // If order has an assigned PIN, verify code against it.
    // If order has no PIN or empty PIN in database, accept any 4-digit code provided.
    if (expectedPin.isNotEmpty && expectedPin != code.trim()) {
      debugPrint('[tryCompleteWithCode] PIN mismatch. Expected: $expectedPin, got: $code');
      return false;
    }

    try {
      await firestore.runTransaction((tx) async {
        // 1. PERFORM ALL READS FIRST
        final snap = await tx.get(orderRef);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;

        final settingsRef = firestore.collection('settings').doc('rider_settings');
        final settingsSnap = await tx.get(settingsRef);

        final vendorId = (data['vendorId'] ?? '').toString();
        final paymentStatus = (data['paymentStatus'] ?? '').toString();
        final alreadyCredited = data['vendorPayoutCredited'] == true;

        double subtotal = 0.0;
        final rawSubtotal = data['vendorSubtotal'] ?? data['subtotal'];
        if (rawSubtotal is num) {
          subtotal = rawSubtotal.toDouble();
        } else {
          subtotal = double.tryParse(rawSubtotal?.toString() ?? '') ?? 0.0;
        }

        final vendorRef = firestore.collection('vendors').doc(vendorId);
        DocumentSnapshot? vendorSnap;
        if (!alreadyCredited && paymentStatus == 'paid' && vendorId.isNotEmpty && subtotal > 0) {
          vendorSnap = await tx.get(vendorRef);
        }

        // 2. NOW COMPUTE AND PERFORM WRITES
        double commissionPercent = 0.0;
        if (settingsSnap.exists && settingsSnap.data() != null) {
          final settingsData = settingsSnap.data() as Map<String, dynamic>;
          final rawComm = settingsData['commissionPercent'];
          if (rawComm is num) {
            commissionPercent = rawComm.toDouble();
          } else {
            commissionPercent = double.tryParse(rawComm?.toString() ?? '') ?? 0.0;
          }
        }
        if (commissionPercent < 0) commissionPercent = 0.0;
        if (commissionPercent > 100) commissionPercent = 100.0;

        double deliveryFee = 0.0;
        final rawDeliveryFee = data['deliveryFee'];
        if (rawDeliveryFee is num) {
          deliveryFee = rawDeliveryFee.toDouble();
        } else {
          deliveryFee = double.tryParse(rawDeliveryFee?.toString() ?? '') ?? 0.0;
        }

        final riderEarning = deliveryFee * (1.0 - (commissionPercent / 100.0));
        final riderId = (data['riderId'] ?? FirebaseAuth.instance.currentUser?.uid ?? '').toString();

        if (riderId.isNotEmpty && riderEarning > 0) {
          final riderRef = firestore.collection('riders').doc(riderId);
          tx.update(riderRef, {
            'walletBalance': FieldValue.increment(riderEarning),
            'completedOrders': FieldValue.increment(1),
            'activeOrderId': FieldValue.delete(),
          });

          final parts = riderEarning.toStringAsFixed(2).split('.');
          final whole = parts[0].replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (match) => '${match[1]},',
          );
          final formattedEarning = '$whole.${parts[1]}';

          final ledgerRef = firestore.collection('ledger_entries').doc();
          tx.set(ledgerRef, {
            'riderId': riderId,
            'kind': 'credit',
            'title': 'Delivery Earning',
            'subtitle': 'Order #$id',
            'dateLabel': 'Today',
            'amountLabel': '+₦$formattedEarning',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        tx.update(orderRef, {
          'status': 'delivered',
          'timeline.deliveredAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (alreadyCredited) return;
        if (paymentStatus != 'paid') return;
        if (vendorId.isEmpty || subtotal <= 0) return;
        if (vendorSnap == null || !vendorSnap.exists) return;

        final txn = {
          'id': '${id}_earning',
          'type': 'earning',
          'title': 'Order earning ($id)',
          'amount': subtotal,
          'createdAt': DateTime.now().toIso8601String(),
        };

        tx.update(vendorRef, {
          'wallet.balance': FieldValue.increment(subtotal),
          'wallet.transactions': FieldValue.arrayUnion([txn]),
        });

        tx.update(orderRef, {
          'vendorPayoutCredited': true,
          'vendorPayoutAmount': subtotal,
          'vendorPayoutAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      debugPrint('[tryCompleteWithCode] Transaction error: $e');
      return false;
    }

    try {
      final orderSnap = await FirebaseFirestore.instance.collection('orders').doc(id).get();
      if (orderSnap.exists) {
        final orderData = orderSnap.data();
        final customerId = orderData?['customerId'] as String?;
        final customerEmail = orderData?['customerEmail'] as String?;
        final customerName = orderData?['customerName'] as String?;
        final orderTotal = (orderData?['total'] ?? 0.0).toDouble();
        final restaurantName = orderData?['restaurantName'] as String? ?? 'MartFood';

        if (customerId != null && customerId.isNotEmpty) {
          await NotificationService.sendPushToCustomer(
            customerId: customerId,
            title: 'Order Delivered! 🍕',
            body: 'Your order #$id from $restaurantName has been delivered successfully.',
            data: {'type': 'order_status', 'orderId': id, 'status': 'delivered'},
          );
        }

        if (customerEmail != null && customerEmail.isNotEmpty) {
          final emailHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Order Delivered - MartFood</title>
</head>
<body style="font-family: sans-serif; background-color: #f8fafc; padding: 20px; color: #334155; line-height: 1.6;">
  <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; padding: 0; border: 1px solid #e2e8f0; overflow: hidden;">
    <div style="background-color: #7C3AED; padding: 24px; text-align: center;">
      <h2 style="color: #ffffff; margin: 0; font-size: 22px;">Order Delivered! 🍕</h2>
    </div>
    <div style="padding: 24px;">
      <p>Hi $customerName,</p>
      <p>Your order at <strong>$restaurantName</strong> has been delivered successfully. We hope you enjoy your meal!</p>
      <div style="background-color: #F5F3FF; padding: 16px; border-radius: 8px; margin: 20px 0; border: 1px solid #C4B5FD;">
        <h3 style="margin-top: 0; font-size: 16px; color: #0f172a;">Delivery Details</h3>
        <p style="margin: 4px 0;"><strong>Order ID:</strong> #$id</p>
        <p style="margin: 4px 0;"><strong>Restaurant:</strong> $restaurantName</p>
        <p style="margin: 4px 0;"><strong>Total Amount:</strong> ₦${orderTotal.toStringAsFixed(2)}</p>
        <p style="margin: 4px 0;"><strong>Status:</strong> ✅ Delivered</p>
      </div>
      <p>Please rate your rider in the app to help us improve the delivery experience.</p>
      <br/>
      <p>Best Regards,</p>
      <p><strong>The MartFood Team</strong></p>
    </div>
    <div style="background-color: #f8fafc; padding: 16px; text-align: center; border-top: 1px solid #e2e8f0; font-size: 12px; color: #94a3b8;">
      &copy; 2026 MartFood Technologies. All rights reserved.
    </div>
  </div>
</body>
</html>
''';

          await NotificationService.sendEmail(
            to: customerEmail,
            subject: 'Order #$id Delivered - MartFood',
            htmlContent: emailHtml,
          );
        }

        // Send completed/delivered email notification to the vendor
        try {
          final vendorId = orderData?['vendorId'] as String?;
          if (vendorId != null && vendorId.isNotEmpty) {
            final vendorSnap = await FirebaseFirestore.instance.collection('vendors').doc(vendorId).get();
            if (vendorSnap.exists) {
              final vendorData = vendorSnap.data() ?? {};
              final vendorEmail = (vendorData['email'] ?? '').toString();
              final vendorName = (vendorData['fullName'] ?? 'Vendor').toString();

              if (vendorEmail.isNotEmpty) {
                final subtotal = (orderData?['vendorSubtotal'] ?? orderData?['subtotal'] ?? 0.0).toDouble();
                final itemsList = orderData?['items'] as List<dynamic>? ?? [];
                final itemsHtmlList = itemsList.map((item) {
                  final title = item['title']?.toString() ?? 'Item';
                  final quantity = item['quantity'] ?? 1;
                  return '<li style="margin-bottom: 8px;"><strong>$quantity ×</strong> $title</li>';
                }).join('\n');

                final vendorDeliveredHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Order Completed &amp; Delivered - MartFood</title>
</head>
<body style="font-family: sans-serif; background-color: #f8fafc; padding: 20px; color: #334155; line-height: 1.6;">
  <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; padding: 0; border: 1px solid #e2e8f0; overflow: hidden;">
    <div style="background-color: #7C3AED; padding: 24px; text-align: center;">
      <h2 style="color: #ffffff; margin: 0; font-size: 22px;">Order Completed &amp; Delivered! 🏪 ✅</h2>
    </div>
    <div style="padding: 24px;">
      <p>Hi $vendorName,</p>
      <p>Great news! Order #$id from your store has been successfully completed and delivered by the rider.</p>
      <div style="background-color: #F5F3FF; padding: 16px; border-radius: 8px; margin: 20px 0; border: 1px solid #C4B5FD;">
        <h3 style="margin-top: 0; font-size: 16px; color: #0f172a;">Order Summary</h3>
        <p style="margin: 4px 0;"><strong>Order ID:</strong> #$id</p>
        <p style="margin: 4px 0;"><strong>Customer Name:</strong> $customerName</p>
        <p style="margin: 4px 0;"><strong>Total Earned:</strong> ₦${subtotal.toStringAsFixed(2)}</p>
        <p style="margin: 4px 0;"><strong>Status:</strong> ✅ Completed &amp; Delivered</p>
      </div>
      <h4 style="color: #0f172a; margin-bottom: 8px;">Items Details:</h4>
      <ul style="padding-left: 20px; color: #475569; margin-top: 0;">
        $itemsHtmlList
      </ul>
      <p>The order earnings have been added to your live wallet balance.</p>
      <br/>
      <p>Best Regards,</p>
      <p><strong>The MartFood Team</strong></p>
    </div>
    <div style="background-color: #f8fafc; padding: 16px; text-align: center; border-top: 1px solid #e2e8f0; font-size: 12px; color: #94a3b8;">
      &copy; 2026 MartFood Technologies. All rights reserved.
    </div>
  </div>
</body>
</html>
''';

                await NotificationService.sendEmail(
                  to: vendorEmail,
                  subject: 'Order Completed & Delivered: #$id - MartFood',
                  htmlContent: vendorDeliveredHtml,
                );
              }
            }
          }
        } catch (ex) {
          debugPrint('Error triggering vendor delivered email: $ex');
        }
      }
    } catch (e) {
      debugPrint('Error triggering customer delivery notifications: $e');
    }

    return true;
  }
}

/// Provides [OrdersNotifier].
final ordersProvider = NotifierProvider<OrdersNotifier, OrdersState>(
  OrdersNotifier.new,
);

/// Finds an order by id in active or completed lists.
final orderByIdProvider = Provider.family<RiderOrder?, String>((ref, id) {
  final s = ref.watch(ordersProvider);
  for (final o in s.active) {
    if (o.id == id) return o;
  }
  for (final o in s.completed) {
    if (o.id == id) return o;
  }
  return null;
});

class LedgerEntriesNotifier extends Notifier<List<LedgerEntry>> {
  StreamSubscription<QuerySnapshot>? _sub;

  @override
  List<LedgerEntry> build() {
    _listenToLedger();
    ref.onDispose(() => _sub?.cancel());
    return const [];
  }

  void _listenToLedger() {
    _sub?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _sub = FirebaseFirestore.instance
        .collection('ledger_entries')
        .where('riderId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      final list = <LedgerEntry>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        list.add(LedgerEntry(
          id: doc.id,
          kind: data['kind'] == 'credit' ? LedgerEntryKind.credit : LedgerEntryKind.debit,
          title: data['title'] ?? '',
          subtitle: data['subtitle'] ?? '',
          dateLabel: data['dateLabel'] ?? '',
          amountLabel: data['amountLabel'] ?? '',
        ));
      }
      state = list;
    });
  }
}

final ledgerEntriesProvider = NotifierProvider<LedgerEntriesNotifier, List<LedgerEntry>>(
  LedgerEntriesNotifier.new,
);
