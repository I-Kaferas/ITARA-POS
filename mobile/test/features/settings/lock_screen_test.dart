import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/features/settings/presentation/lock_screen.dart';

void main() {
  testWidgets('lock screen shows the clock, then the PIN pad on tap', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LockScreen())));
    await tester.pump();

    expect(find.textContaining('déverrouiller'), findsOneWidget);
    expect(find.text('Saisissez votre PIN'), findsNothing);

    await tester.tap(find.byType(LockScreen));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Saisissez votre PIN'), findsOneWidget);
    expect(find.text('Changer d’utilisateur'), findsOneWidget);
    for (final digit in ['1', '2', '3', '0']) {
      expect(find.text(digit), findsOneWidget);
    }
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
