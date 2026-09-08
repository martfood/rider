import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/splash/splash_screen.dart';

void main() {
  testWidgets('SplashScreen displays martfood_logo_light image', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(),
      ),
    );

    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);

    final image = tester.widget<Image>(imageFinder);
    expect((image.image as AssetImage).assetName, 'lib/assets/martfood_logo_light.png');
  });
}
