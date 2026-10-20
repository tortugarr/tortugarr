import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/application/providers/discovery_provider.dart';
import 'package:moonfin/domain/models/media_discovery.dart';
import 'package:moonfin/presentation/features/discover/discover_routes.dart';
import 'package:moonfin/presentation/features/discover/screens/file_picker_screen.dart';
import 'package:moonfin/presentation/features/discover/screens/search_results_screen.dart';

import '../discover_test_app.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(MediaType.movie);
    registerFallbackValue(<FileOption>[]);
  });

  late MockDiscoveryRepository repository;

  setUp(() {
    repository = MockDiscoveryRepository();
    when(() => repository.searchMedia(any()))
        .thenAnswer((_) async => const [dune]);
  });

  /// Lands the app on the picker with [dune] already chosen.
  List<Override> overridesFor() => [
        discoveryRepositoryProvider.overrideWithValue(repository),
        searchQueryProvider.overrideWith((ref) => 'dune'),
        selectedMediaProvider.overrideWith((ref) => dune),
      ];

  Future<DiscoverHarness> pumpPicker(
    WidgetTester tester, {
    List<Override> extraOverrides = const [],
    bool settle = true,
  }) {
    return pumpDiscoverApp(
      tester,
      overrides: [...overridesFor(), ...extraOverrides],
      initialLocation: DiscoverRoutes.files,
      settle: settle,
    );
  }

  testWidgets('groups releases by resolution, highest tier first',
      (tester) async {
    when(() => repository.getAvailableFiles(any(), any()))
        .thenAnswer((_) async => const [release1080, release2160, release1080Alt]);

    await pumpPicker(tester);

    expect(find.byKey(const Key('resolutionGroup-p2160')), findsOneWidget);
    expect(find.byKey(const Key('resolutionGroup-p1080')), findsOneWidget);
    expect(find.byKey(const Key('resolutionGroup-p720')), findsNothing);

    expect(find.text('2160p (4K)'), findsOneWidget);
    expect(find.text('1 release'), findsOneWidget);
    expect(find.text('2 releases'), findsOneWidget);

    // Size and seeders on the subtitle line.
    expect(find.text('22.0 GB · 91 seeders'), findsOneWidget);
    expect(find.text('8.0 GB · 240 seeders'), findsOneWidget);

    // 2160p above 1080p on screen.
    final tier2160 = tester.getTopLeft(
      find.byKey(const Key('resolutionGroup-p2160')),
    );
    final tier1080 = tester.getTopLeft(
      find.byKey(const Key('resolutionGroup-p1080')),
    );
    expect(tier2160.dy, lessThan(tier1080.dy));
  });

  testWidgets('ticking and unticking a release updates the selection',
      (tester) async {
    when(() => repository.getAvailableFiles(any(), any()))
        .thenAnswer((_) async => const [release2160, release1080]);

    final harness = await pumpPicker(tester);
    expect(harness.container.read(selectedFilesProvider), isEmpty);

    await tester.tap(find.byKey(Key('fileOption-${release2160.path}')));
    await tester.pumpAndSettle();
    expect(harness.container.read(selectedFilesProvider), [release2160]);

    await tester.tap(find.byKey(Key('fileOption-${release1080.path}')));
    await tester.pumpAndSettle();
    expect(
      harness.container.read(selectedFilesProvider),
      [release2160, release1080],
    );

    await tester.tap(find.byKey(Key('fileOption-${release2160.path}')));
    await tester.pumpAndSettle();
    expect(harness.container.read(selectedFilesProvider), [release1080]);
  });

  testWidgets('Submit is disabled until something is ticked', (tester) async {
    when(() => repository.getAvailableFiles(any(), any()))
        .thenAnswer((_) async => const [release2160]);

    await pumpPicker(tester);

    ElevatedButton submitButton() => tester.widget<ElevatedButton>(
          find.byKey(const Key('filePickerSubmitButton')),
        );

    expect(submitButton().onPressed, isNull);
    expect(find.text('Select a release to continue'), findsOneWidget);

    await tester.tap(find.byKey(Key('fileOption-${release2160.path}')));
    await tester.pumpAndSettle();

    expect(submitButton().onPressed, isNotNull);
    expect(find.text('Request 1 release'), findsOneWidget);
  });

  testWidgets('Submit sends the selection and moves to the download screen',
      (tester) async {
    when(() => repository.getAvailableFiles(any(), any()))
        .thenAnswer((_) async => const [release2160, release1080]);
    when(() => repository.requestMedia(any(), any(), any())).thenAnswer(
      (_) async => MediaRequest(
        id: 42,
        mediaId: dune.id,
        status: MediaRequestStatus.pending,
        requestedAt: DateTime.utc(2026, 9, 8),
        selectedFiles: const [release2160],
      ),
    );

    final harness = await pumpPicker(tester);

    await tester.tap(find.byKey(Key('fileOption-${release2160.path}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filePickerSubmitButton')));
    await tester.pumpAndSettle();

    verify(
      () => repository.requestMedia(dune.id, dune.mediaType, [release2160]),
    ).called(1);
    expect(harness.location, DiscoverRoutes.downloading);
    expect(find.byKey(downloadingStubKey), findsOneWidget);
  });

  testWidgets('a failed request shows a message and stays on the picker',
      (tester) async {
    when(() => repository.getAvailableFiles(any(), any()))
        .thenAnswer((_) async => const [release2160]);
    when(() => repository.requestMedia(any(), any(), any()))
        .thenThrow(StateError('jellyseerr rejected the request'));

    final harness = await pumpPicker(tester);

    await tester.tap(find.byKey(Key('fileOption-${release2160.path}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filePickerSubmitButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.textContaining('jellyseerr rejected the request'),
      findsOneWidget,
    );
    expect(harness.location, DiscoverRoutes.files);
    expect(find.byType(FilePickerScreen), findsOneWidget);
  });

  testWidgets('renders the failure when the release lookup throws',
      (tester) async {
    when(() => repository.getAvailableFiles(any(), any()))
        .thenThrow(StateError('indexer offline'));

    await pumpPicker(tester);

    expect(find.byKey(const Key('filePickerError')), findsOneWidget);
    expect(find.textContaining('indexer offline'), findsOneWidget);
  });

  testWidgets('renders an empty state when there is nothing to grab',
      (tester) async {
    when(() => repository.getAvailableFiles(any(), any()))
        .thenAnswer((_) async => <FileOption>[]);

    await pumpPicker(tester);

    expect(find.byKey(const Key('filePickerEmpty')), findsOneWidget);
    expect(find.byKey(const Key('filePickerList')), findsNothing);
  });

  testWidgets('the back button returns to the results grid', (tester) async {
    when(() => repository.getAvailableFiles(any(), any()))
        .thenAnswer((_) async => const [release2160]);

    final harness = await pumpPicker(tester);

    await tester.tap(find.byKey(const Key('filePickerBackButton')));
    await tester.pumpAndSettle();

    expect(harness.location, DiscoverRoutes.results);
    expect(find.byType(SearchResultsScreen), findsOneWidget);
  });
}
