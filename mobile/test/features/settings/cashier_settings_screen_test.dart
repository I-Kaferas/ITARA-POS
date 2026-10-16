import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/core/theme/theme_controller.dart';
import 'package:pos_mobile/core/theme/theme_cubit.dart';
import 'package:pos_mobile/features/settings/domain/cashier_preferences.dart';
import 'package:pos_mobile/features/settings/presentation/cashier_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('print text levels scale receipts from the default size', () {
    final prefs = CashierPreferences.instance;
    prefs.printTextLevel = 1;
    expect(CashierPreferences.text(10), 10);
    expect(CashierPreferences.space(8), 8);
    prefs.printTextLevel = 3;
    expect(CashierPreferences.text(10), closeTo(13.5, 0.01));
    expect(CashierPreferences.space(8), closeTo(10.8, 0.01));
    prefs.printTextLevel = 5;
    expect(CashierPreferences.text(10), 18);
    expect(CashierPreferences.space(8), closeTo(14.4, 0.01));
    prefs.printTextLevel = 1;
  });

  testWidgets('cashier settings lays out on a phone and a desk', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.text('Thème'), findsOneWidget);
    expect(find.text('Format du ticket'), findsOneWidget);
    expect(find.text('Rôle de l’appareil non configuré'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(1280, 900));
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.text('Verrouillage automatique'), findsOneWidget);
    expect(find.text('Écran client'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app() {
  return BlocProvider(
    create: (_) => ThemeCubit(ThemeController.instance),
    child: const MaterialApp(home: Scaffold(body: CashierSettingsScreen())),
  );
}
