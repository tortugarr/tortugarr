/// Shared scaffolding for the Task 7 download status screen widget tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moonfin/presentation/features/downloads/screens/download_status_screen.dart';

GoRouter buildDownloadTestRouter({String initialLocation = '/downloads'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/downloads',
        builder: (context, state) => const DownloadStatusScreen(),
      ),
    ],
  );
}

/// Everything a test needs to poke at after pumping: the router (for the
/// current location) and the container (for provider state).
class DownloadHarness {
  DownloadHarness(this.router, this.container);

  final GoRouter router;
  final ProviderContainer container;

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
}

/// Pumps the download status screen under a [ProviderScope].
Future<DownloadHarness> pumpDownloadApp(
  WidgetTester tester, {
  required List<Override> overrides,
  String initialLocation = '/downloads',
  bool settle = true,
}) async {
  final router = buildDownloadTestRouter(initialLocation: initialLocation);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }

  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
    listen: false,
  );
  return DownloadHarness(router, container);
}
