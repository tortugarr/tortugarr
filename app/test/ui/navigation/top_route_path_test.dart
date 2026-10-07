import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moonfin/ui/navigation/app_router.dart';

void main() {
  testWidgets('a page pushed over home is the top route even though the uri stays /home',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (context, state, child) => child,
          routes: [
            GoRoute(path: '/home', builder: (_, __) => const Text('home')),
            GoRoute(path: '/seerr/discover', builder: (_, __) => const Text('seerr')),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(topRoutePathOf(router.routerDelegate.currentConfiguration), '/home');

    router.push('/seerr/discover');
    await tester.pumpAndSettle();

    final config = router.routerDelegate.currentConfiguration;
    // The bug: the uri still said /home, so Home's trailer kept playing behind Seerr.
    expect(config.uri.path, '/home');
    expect(topRoutePathOf(config), '/seerr/discover');
  });
}
