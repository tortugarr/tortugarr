/// Shared scaffolding for the Task 6 discovery widget tests.
///
/// The router built here is a *stand-in* for `lib/ui/navigation/app_router.dart`.
/// It registers exactly the routes Task 6 adds, plus a stub for Task 7's
/// `/discover/downloading`, so the flow can be driven end to end. Importing the
/// real router instead is not possible today: its import graph reaches
/// `lib/ui/screens/settings/panel/about_category_screen.dart`, which does not
/// compile (pre-existing, uncommitted, `Icons.applications` and
/// `l10n.settingsBuiltOnOriginal` are undefined). See the Task 6 report.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/domain/models/media_discovery.dart';
import 'package:moonfin/domain/repositories/media_discovery_repository.dart';
import 'package:moonfin/presentation/features/discover/discover_routes.dart';
import 'package:moonfin/presentation/features/discover/screens/discover_screen.dart';
import 'package:moonfin/presentation/features/discover/screens/file_picker_screen.dart';
import 'package:moonfin/presentation/features/discover/screens/search_results_screen.dart';

class MockDiscoveryRepository extends Mock
    implements MediaDiscoveryRepository {}

/// Marks the Task 7 screen the file picker hands off to.
const Key downloadingStubKey = Key('downloadingStub');

/// Posters are left empty on purpose: an empty [SearchResult.posterPath]
/// renders the local placeholder, so no test ever reaches the network.
const SearchResult dune = SearchResult(
  id: 693134,
  title: 'Dune: Part Two',
  releaseYear: 2024,
  description: 'Paul Atreides unites with the Fremen.',
  posterPath: '',
  mediaType: MediaType.movie,
  rating: 8.2,
);

const SearchResult severance = SearchResult(
  id: 95396,
  title: 'Severance',
  releaseYear: 2022,
  description: 'Work-life balance, surgically enforced.',
  posterPath: '',
  mediaType: MediaType.tv,
  rating: 8.4,
);

const FileOption release2160 = FileOption(
  path: 'Dune.Part.Two.2024.2160p.WEB-DL',
  resolution: Resolution.p2160,
  sizeInMb: 22528,
  seeders: 91,
);

const FileOption release1080 = FileOption(
  path: 'Dune.Part.Two.2024.1080p.WEB-DL',
  resolution: Resolution.p1080,
  sizeInMb: 8192,
  seeders: 240,
);

const FileOption release1080Alt = FileOption(
  path: 'Dune.Part.Two.2024.1080p.BluRay',
  resolution: Resolution.p1080,
  sizeInMb: 12288,
  seeders: 12,
);

GoRouter buildDiscoverTestRouter({String initialLocation = DiscoverRoutes.discover}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: DiscoverRoutes.discover,
        builder: (context, state) => const DiscoverScreen(),
        routes: [
          GoRoute(
            path: DiscoverRoutes.resultsSegment,
            builder: (context, state) => const SearchResultsScreen(),
          ),
          GoRoute(
            path: DiscoverRoutes.filesSegment,
            builder: (context, state) => const FilePickerScreen(),
          ),
          GoRoute(
            path: DiscoverRoutes.downloadingSegment,
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Downloads', key: downloadingStubKey)),
            ),
          ),
        ],
      ),
    ],
  );
}

/// Everything a test needs to poke at after pumping: the router (for the
/// current location) and the container (for provider state).
class DiscoverHarness {
  DiscoverHarness(this.router, this.container);

  final GoRouter router;
  final ProviderContainer container;

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
}

/// Pumps the three screens under a [ProviderScope].
///
/// [settle] is off for tests that assert on a spinner — `pumpAndSettle` never
/// returns while a [CircularProgressIndicator] is on screen.
Future<DiscoverHarness> pumpDiscoverApp(
  WidgetTester tester, {
  required List<Override> overrides,
  String initialLocation = DiscoverRoutes.discover,
  bool settle = true,
}) async {
  final router = buildDiscoverTestRouter(initialLocation: initialLocation);
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
  return DiscoverHarness(router, container);
}
