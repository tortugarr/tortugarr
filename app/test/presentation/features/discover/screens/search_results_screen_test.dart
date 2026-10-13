import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/application/providers/discovery_provider.dart';
import 'package:moonfin/domain/models/media_discovery.dart';
import 'package:moonfin/presentation/features/discover/discover_routes.dart';
import 'package:moonfin/presentation/features/discover/screens/discover_screen.dart';
import 'package:moonfin/presentation/features/discover/screens/file_picker_screen.dart';

import '../discover_test_app.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(MediaType.movie);
  });

  late MockDiscoveryRepository repository;

  setUp(() {
    repository = MockDiscoveryRepository();
    // The picker is one tap away in the navigation tests, so it needs an
    // answer too.
    when(() => repository.getAvailableFiles(any(), any()))
        .thenAnswer((_) async => <FileOption>[]);
  });

  /// Overrides that land the app on the results screen for `dune`.
  List<Override> overridesFor() => [
        discoveryRepositoryProvider.overrideWithValue(repository),
        searchQueryProvider.overrideWith((ref) => 'dune'),
      ];

  testWidgets('shows a spinner while the search is in flight', (tester) async {
    final gate = Completer<List<SearchResult>>();
    when(() => repository.searchMedia(any())).thenAnswer((_) => gate.future);

    await pumpDiscoverApp(
      tester,
      overrides: overridesFor(),
      initialLocation: DiscoverRoutes.results,
      settle: false,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete(const <SearchResult>[]);
    await tester.pumpAndSettle();
  });

  testWidgets('shows the failure when the repository throws', (tester) async {
    when(() => repository.searchMedia(any()))
        .thenThrow(StateError('jellyseerr unreachable'));

    await pumpDiscoverApp(
      tester,
      overrides: overridesFor(),
      initialLocation: DiscoverRoutes.results,
    );

    expect(find.byKey(const Key('searchResultsError')), findsOneWidget);
    expect(
      find.textContaining('jellyseerr unreachable'),
      findsOneWidget,
    );
  });

  testWidgets('shows an empty-state message when nothing matched',
      (tester) async {
    when(() => repository.searchMedia(any()))
        .thenAnswer((_) async => <SearchResult>[]);

    await pumpDiscoverApp(
      tester,
      overrides: overridesFor(),
      initialLocation: DiscoverRoutes.results,
    );

    expect(find.byKey(const Key('searchResultsEmpty')), findsOneWidget);
    expect(find.text('No results for "dune".'), findsOneWidget);
    expect(find.byKey(const Key('searchResultsGrid')), findsNothing);
  });

  testWidgets('renders one card per result with title, year and rating',
      (tester) async {
    when(() => repository.searchMedia(any()))
        .thenAnswer((_) async => const [dune, severance]);

    await pumpDiscoverApp(
      tester,
      overrides: overridesFor(),
      initialLocation: DiscoverRoutes.results,
    );

    expect(find.byKey(const Key('searchResultsGrid')), findsOneWidget);
    expect(find.byKey(Key('searchResultCard-${dune.id}')), findsOneWidget);
    expect(find.byKey(Key('searchResultCard-${severance.id}')), findsOneWidget);
    expect(find.text('Dune: Part Two'), findsOneWidget);
    expect(find.text('2024 · Movie · ★ 8.2'), findsOneWidget);
    expect(find.text('2022 · TV Series · ★ 8.4'), findsOneWidget);
    // Empty posterPath falls back to the local icon, never the network.
    expect(find.byIcon(Icons.movie), findsNWidgets(2));
  });

  testWidgets('tapping a card selects it and opens the file picker',
      (tester) async {
    when(() => repository.searchMedia(any()))
        .thenAnswer((_) async => const [dune, severance]);

    final harness = await pumpDiscoverApp(
      tester,
      overrides: overridesFor(),
      initialLocation: DiscoverRoutes.results,
    );

    await tester.tap(find.byKey(Key('searchResultCard-${severance.id}')));
    await tester.pumpAndSettle();

    expect(harness.container.read(selectedMediaProvider), severance);
    expect(harness.location, DiscoverRoutes.files);
    expect(find.byType(FilePickerScreen), findsOneWidget);
  });

  testWidgets('picking a different title clears the previous ticks',
      (tester) async {
    when(() => repository.searchMedia(any()))
        .thenAnswer((_) async => const [dune, severance]);

    final harness = await pumpDiscoverApp(
      tester,
      overrides: [
        ...overridesFor(),
        selectedFilesProvider.overrideWith((ref) => const [release1080]),
      ],
      initialLocation: DiscoverRoutes.results,
    );

    expect(harness.container.read(selectedFilesProvider), isNotEmpty);

    await tester.tap(find.byKey(Key('searchResultCard-${dune.id}')));
    await tester.pumpAndSettle();

    expect(harness.container.read(selectedFilesProvider), isEmpty);
  });

  testWidgets('the back button returns to the search screen', (tester) async {
    when(() => repository.searchMedia(any()))
        .thenAnswer((_) async => const [dune]);

    final harness = await pumpDiscoverApp(
      tester,
      overrides: overridesFor(),
      initialLocation: DiscoverRoutes.results,
    );

    await tester.tap(find.byKey(const Key('searchResultsBackButton')));
    await tester.pumpAndSettle();

    expect(harness.location, DiscoverRoutes.discover);
    expect(find.byType(DiscoverScreen), findsOneWidget);
  });
}
