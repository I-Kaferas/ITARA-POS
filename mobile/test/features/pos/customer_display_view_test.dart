import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/features/pos/presentation/customer_display_view.dart';
import 'package:pos_mobile/features/pos/services/customer_display_bus.dart';

void main() {
  const snapshot = CustomerDisplaySnapshot(
    brandName: 'ITARA Market',
    tagline: 'Better Business. Brighter Future.',
    customerName: 'Walk-in customer',
    currencyCode: 'USD',
    total: 4500,
    lines: [
      CustomerDisplayLine(name: 'Tomates', quantity: 2, price: 1500),
      CustomerDisplayLine(name: 'Carottes', quantity: 1, price: 1500),
    ],
  );

  for (final size in const [Size(390, 844), Size(390, 560), Size(1280, 800)]) {
    testWidgets('customer display lays out at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const MaterialApp(home: CustomerDisplayView(snapshot: snapshot)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Produce / fruit hero must always be on screen (wide and phone).
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Votre commande'), findsOneWidget);
      expect(find.text('Tomates'), findsOneWidget);
    });
  }
}
