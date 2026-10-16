import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/core/i18n/app_locale.dart';
import 'package:pos_mobile/core/navigation/config_top_bar.dart';
import 'package:pos_mobile/core/network/network_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNetworkBloc extends Cubit<NetworkState> implements NetworkBloc {
  _FakeNetworkBloc(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('configuration header shows status and wires its actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    LocaleController.instance.bind('en');
    addTearDown(() => LocaleController.instance.bind('fr'));

    var features = 0;
    var logout = 0;
    var home = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<NetworkBloc>.value(
          value: _FakeNetworkBloc(const NetworkState(internetReachable: true, masterReachable: true)),
          child: Scaffold(
            body: ConfigTopBar(
              onHome: () => home++,
              onFeatures: () => features++,
              onLogout: () => logout++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Configuration Mode'), findsOneWidget);
    expect(find.text('App features'), findsOneWidget);
    expect(find.text('Internet connected'), findsOneWidget);
    expect(find.text('Server running'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('App features'));
    await tester.tap(find.text('Logout'));
    await tester.tap(find.byType(Tooltip));
    expect(features, 1);
    expect(logout, 1);
    expect(home, 1);
  });
}
