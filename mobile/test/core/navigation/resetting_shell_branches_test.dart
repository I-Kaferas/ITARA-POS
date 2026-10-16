import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_mobile/core/navigation/app_router.dart';

class _Counter extends StatefulWidget {
  const _Counter(this.name);

  final String name;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => setState(() => _count++),
      child: Text('${widget.name} $_count'),
    );
  }
}

GoRoute _route(String path) => GoRoute(path: path, builder: (_, _) => _Counter(path));

void main() {
  testWidgets('screens reset when reopened while the cashier keeps its state', (tester) async {
    final router = GoRouter(
      initialLocation: '/pos',
      routes: [
        StatefulShellRoute(
          builder: (_, _, shell) => shell,
          navigatorContainerBuilder: (_, shell, children) =>
              ResettingShellBranches(currentIndex: shell.currentIndex, children: children),
          branches: [
            StatefulShellBranch(routes: [_route('/pos')]),
            StatefulShellBranch(routes: [_route('/orders')]),
            StatefulShellBranch(routes: [_route('/stock')]),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('/pos 0'));
    await tester.pumpAndSettle();
    expect(find.text('/pos 1'), findsOneWidget);

    router.go('/orders');
    await tester.pumpAndSettle();
    await tester.tap(find.text('/orders 0'));
    await tester.pumpAndSettle();
    expect(find.text('/orders 1'), findsOneWidget);

    router.go('/stock');
    await tester.pumpAndSettle();
    router.go('/orders');
    await tester.pumpAndSettle();
    expect(find.text('/orders 0'), findsOneWidget);

    router.go('/pos');
    await tester.pumpAndSettle();
    expect(find.text('/pos 1'), findsOneWidget);
  });
}
