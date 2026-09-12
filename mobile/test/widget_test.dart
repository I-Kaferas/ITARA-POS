import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/main.dart';

void main() {
  testWidgets('POS app renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PosApp());
    await tester.pumpAndSettle();

    expect(find.text('POS Terminal'), findsOneWidget);
    expect(find.text('API Status'), findsOneWidget);
  });
}
