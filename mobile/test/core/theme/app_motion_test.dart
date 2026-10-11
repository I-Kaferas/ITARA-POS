import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/core/theme/app_motion.dart';

void main() {
  test('an entrance plays once for the same id', () {
    AppMotion.resetEntrances();
    expect(AppMotion.claimEntrance('sale-1'), isTrue);
    expect(AppMotion.claimEntrance('sale-1'), isFalse);
    expect(AppMotion.claimEntrance('sale-2'), isTrue);
    AppMotion.resetEntrances();
  });

  test('durations stay short', () {
    expect(AppMotion.micro.inMilliseconds, inInclusiveRange(100, 180));
    expect(AppMotion.content.inMilliseconds, inInclusiveRange(160, 240));
    expect(AppMotion.navigation.inMilliseconds, inInclusiveRange(200, 300));
    expect(AppMotion.modal.inMilliseconds, inInclusiveRange(180, 280));
    expect(AppMotion.slideFraction, lessThan(0.08));
  });

  testWidgets('reduced motion shows content immediately', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: AppFadeIn(child: Text('Panier vide')),
        ),
      ),
    );

    expect(find.text('Panier vide'), findsOneWidget);
  });

  testWidgets('a press fires the action once', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTapScale(
            onTap: () => taps++,
            child: const Text('Payer'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Payer'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('a value change keeps the real amount', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppValueFade(value: 1500, child: Text('1500')),
      ),
    );
    expect(find.text('1500'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: AppValueFade(value: 1800, child: Text('1800')),
      ),
    );
    await tester.pump();
    expect(find.text('1800'), findsOneWidget);
    expect(find.text('1650'), findsNothing);
  });

  testWidgets('a list row stays visible when seen again', (tester) async {
    AppMotion.resetEntrances();
    await tester.pumpWidget(
      const MaterialApp(home: AppOnce(id: 'row-1', child: Text('Commande'))),
    );
    expect(find.text('Commande'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(home: AppOnce(id: 'row-1', child: Text('Commande'))),
    );
    expect(find.text('Commande'), findsOneWidget);
    AppMotion.resetEntrances();
  });
}
