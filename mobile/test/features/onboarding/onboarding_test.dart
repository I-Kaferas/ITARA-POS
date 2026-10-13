import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_mobile/core/navigation/app_routes.dart';
import 'package:pos_mobile/features/onboarding/onboarding_gate.dart';
import 'package:pos_mobile/features/onboarding/presentation/onboarding_cubit.dart';
import 'package:pos_mobile/features/onboarding/presentation/onboarding_finish_screen.dart';
import 'package:pos_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:pos_mobile/features/onboarding/presentation/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OnboardingGate.instance.seen = false;
  });

  test('presentation stays hidden after it is completed', () async {
    expect(OnboardingGate.instance.seen, isFalse);
    await OnboardingGate.instance.complete();
    expect(OnboardingGate.instance.seen, isTrue);

    final fresh = OnboardingGate.instance;
    await fresh.load();
    expect(fresh.seen, isTrue);
    await fresh.complete();
    expect(fresh.seen, isTrue);
  });

  test('slides move forward and back without passing the ends', () {
    final cubit = OnboardingCubit(length: 4);
    expect(cubit.isFirst, isTrue);
    cubit.previous();
    expect(cubit.state.index, 0);
    cubit.next();
    cubit.next();
    expect(cubit.state.index, 2);
    cubit.go(99);
    expect(cubit.isLast, isTrue);
    cubit.close();
  });

  testWidgets('welcome offers discovery and start', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    expect(find.text('Gérez. Vendez. Développez.'), findsOneWidget);
    expect(find.text('Découvrir le logiciel'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
    expect(find.text('ITARA POS'), findsOneWidget);
  });

  testWidgets('skip leaves the slides for the sign-in step', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.onboarding,
      routes: [
        GoRoute(
          path: AppRoutes.onboarding,
          builder: (_, _) => const OnboardingScreen(),
        ),
        GoRoute(
          path: AppRoutes.onboardingFinish,
          builder: (_, _) => const Scaffold(body: Text('sortie')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    expect(find.text('Gestion commerciale'), findsOneWidget);
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Point de vente'), findsOneWidget);
    await tester.tap(find.text('Ignorer'));
    await tester.pumpAndSettle();
    expect(find.text('sortie'), findsOneWidget);
  });

  testWidgets('finish hides setup and offline until the terminal allows them', (
    tester,
  ) async {
    var signedIn = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFinishScreen(
          canConfigure: false,
          canContinueOffline: false,
          onSignIn: () => signedIn = true,
        ),
      ),
    );
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Configurer mon entreprise'), findsNothing);
    expect(find.text('Continuer hors ligne'), findsNothing);
    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    expect(signedIn, isTrue);
    expect(OnboardingGate.instance.seen, isTrue);
  });

  testWidgets('reduced motion still shows the welcome', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: WelcomeScreen()),
      ),
    );
    expect(find.text('Gérez. Vendez. Développez.'), findsOneWidget);
  });
}
