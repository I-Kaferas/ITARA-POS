import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/core/i18n/app_locale.dart';
import 'package:pos_mobile/core/theme/theme_controller.dart';
import 'package:pos_mobile/features/settings/domain/cashier_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Reader extends StatelessWidget {
  const _Reader();

  @override
  Widget build(BuildContext context) {
    final prefs = CashierPreferences.instance;
    return Text(
      '${prefs.standardPos ? 'commerce' : 'restaurant'} '
      '${LocaleController.instance.code}',
      textDirection: TextDirection.ltr,
    );
  }
}

void main() {
  testWidgets('settings changes rebuild widgets that do not listen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = CashierPreferences.instance;
    await prefs.load();
    LocaleController.instance.bind('fr');

    await tester.pumpWidget(
      ThemeRefresh(
        sources: [LocaleController.instance, prefs],
        child: const _Reader(),
      ),
    );
    expect(find.text('restaurant fr'), findsOneWidget);

    await prefs.setStandardPos(true);
    await tester.pump();
    await tester.pump();
    expect(find.text('commerce fr'), findsOneWidget);

    LocaleController.instance.bind('en');
    await tester.pump();
    await tester.pump();
    expect(find.text('commerce en'), findsOneWidget);

    await prefs.setStandardPos(false);
    LocaleController.instance.bind('fr');
  });
}
