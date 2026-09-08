import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/delivery/order_detail_screen.dart';

void main() {
  testWidgets('Order detail shows primary action for active order', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, _) {
            return const MaterialApp(
              home: OrderDetailScreen(orderId: 'MF-20481'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("I'm at the restaurant"), findsOneWidget);
    expect(find.text('Chicken Republic — Ikeja'), findsOneWidget);
  });
}
