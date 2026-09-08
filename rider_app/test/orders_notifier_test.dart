import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider_app/domain/order_stage.dart';
import 'package:rider_app/providers/orders_providers.dart';

void main() {
  test('OrdersNotifier seeds MF-20481 at restaurant pickup stage', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final state = container.read(ordersProvider);
    final order = state.active.firstWhere((o) => o.id == 'MF-20481');
    expect(order.stage, OrderStage.enRouteToRestaurant);
  });

  test('tryCompleteWithCode moves order to completed', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(ordersProvider.notifier);
    notifier.setStage('MF-20481', OrderStage.awaitingDeliveryCode);
    final ok = notifier.tryCompleteWithCode('MF-20481', '1234');
    expect(ok, isTrue);
    final after = container.read(ordersProvider);
    expect(after.active.any((o) => o.id == 'MF-20481'), isFalse);
    expect(after.completed.any((o) => o.id == 'MF-20481'), isTrue);
  });
}
