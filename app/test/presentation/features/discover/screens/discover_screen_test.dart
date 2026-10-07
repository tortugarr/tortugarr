import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/application/providers/discovery_provider.dart';
import 'package:moonfin/domain/models/media_discovery.dart';
import 'package:moonfin/presentation/features/discover/discover_routes.dart';
import 'package:moonfin/presentation/features/discover/screens/discover_screen.dart';
import 'package:moonfin/presentation/features/discover/screens/search_results_screen.dart';

import '../discover_test_app.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(MediaType.movie);
  });

  late MockDiscoveryRepository repository;
  late List<Override> overrides;

  setUp(() {
    repository = MockDiscoveryRepository();
    when(() => repository.searchMedia(any()))
        .thenAnswer((_) async => <SearchResult>[]);
    overrides = [discoveryRepositoryProvider.overrideWithValue(repository)];
  });

  testWidgets('renders a search field and a search button', (tester) async {
    await pumpDiscoverApp(tester, overrides: overrides);

    expect(find.byType(DiscoverScreen), findsOneWidget);
    expect(find.byKey(const Key('discoverSearchField')), findsOneWidget);
    expect(find.byKey(const Key('discoverSearchButton')), findsOneWidget);
  });

  testWidgets('tapping Search stores the trimmed query and navigates',
      (tester) async {
    final harness = await pumpDiscoverApp(tester, overrides: overrides);

    await tester.enterText(
      find.byKey(const Key('discoverSearchField')),
      '  dune  ',
    );
    await tester.tap(find.byKey(const Key('discoverSearchButton')));
    await tester.pumpAndSettle();

    expect(harness.container.read(searchQueryProvider), 'dune');
    expect(harness.location, DiscoverRoutes.results);
    expect(find.byType(SearchResultsScreen), findsOneWidget);
  });

  testWidgets('submitting from the keyboard navigates too', (tester) async {
    final harness = await pumpDiscoverApp(tester, overrides: overrides);

    await tester.enterText(
      find.byKey(const Key('discoverSearchField')),
      'severance',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(harness.container.read(searchQueryProvider), 'severance');
    expect(harness.location, DiscoverRoutes.results);
  });

  testWidgets('a blank query shows a hint and does not navigate',
      (tester) async {
    final harness = await pumpDiscoverApp(tester, overrides: overrides);

    await tester.enterText(
      find.byKey(const Key('discoverSearchField')),
      '   ',
    );
    await tester.tap(find.byKey(const Key('discoverSearchButton')));
    await tester.pumpAndSettle();

    expect(find.text('Type a title before searching.'), findsOneWidget);
    expect(harness.container.read(searchQueryProvider), '');
    expect(harness.location, DiscoverRoutes.discover);
    verifyNever(() => repository.searchMedia(any()));
  });

  testWidgets('the field is seeded from the existing query', (tester) async {
    await pumpDiscoverApp(
      tester,
      overrides: [
        ...overrides,
        searchQueryProvider.overrideWith((ref) => 'blade runner'),
      ],
    );

    expect(find.text('blade runner'), findsOneWidget);
  });

  testWidgets('a new search drops the previous title and its ticked releases',
      (tester) async {
    final harness = await pumpDiscoverApp(
      tester,
      overrides: [
        ...overrides,
        selectedMediaProvider.overrideWith((ref) => severance),
        selectedFilesProvider.overrideWith((ref) => const [release1080]),
      ],
    );

    await tester.enterText(
      find.byKey(const Key('discoverSearchField')),
      'dune',
    );
    await tester.tap(find.byKey(const Key('discoverSearchButton')));
    await tester.pumpAndSettle();

    expect(harness.container.read(selectedMediaProvider), isNull);
    expect(harness.container.read(selectedFilesProvider), isEmpty);
  });
}
