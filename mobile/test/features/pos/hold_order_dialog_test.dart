import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/core/i18n/app_locale.dart';
import 'package:pos_mobile/features/pos/presentation/widgets/hold_order_dialog.dart';

void main() {
  tearDown(() => LocaleController.instance.bind('fr'));

  testWidgets('hold dialog asks whether to print the kitchen ticket', (tester) async {
    LocaleController.instance.bind('en');
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                result = await showHoldOrderDialog(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Hold Order?'), findsOneWidget);
    expect(find.textContaining('NOT sent to kitchen'), findsOneWidget);
    expect(find.text('Print kitchen ticket'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Hold'), findsOneWidget);

    await tester.tap(find.text('Print kitchen ticket'));
    await tester.pump();
    await tester.tap(find.text('Hold'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hold'));
    await tester.pumpAndSettle();
    expect(result, isTrue);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });
}
