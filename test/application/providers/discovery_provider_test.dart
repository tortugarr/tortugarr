import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/application/providers/discovery_provider.dart';
import 'package:moonfin/domain/models/media_discovery.dart';
import 'package:moonfin/domain/repositories/media_discovery_repository.dart';

class _MockDiscoveryRepository extends Mock
    implements MediaDiscoveryRepository {}

const SearchResult _dune = SearchResult(
  id: 693134,
  title: 'Dune: Part Two',
  releaseYear: 2024,
  description: 'Paul Atreides unites with the Fremen.',
  posterPath: '/dune.jpg',
  mediaType: MediaType.movie,
  rating: 8.2,
);

const SearchResult _severance = SearchResult(
  id: 95396,
  title: 'Severance',
  releaseYear: 2022,
  description: 'Work-life balance, surgically enforced.',
  posterPath: '/severance.jpg',
  mediaType: MediaType.tv,
  rating: 8.4,
);

const FileOption _release = FileOption(
  path: 'Dune.Part.Two.2024.2160p.WEB-DL',
  resolution: Resolution.p2160,
  sizeInMb: 22528,
  seeders: 91,
);

void main() {
  setUpAll(() {
    registerFallbackValue(MediaType.movie);
    registerFallbackValue(const <FileOption>[]);
  });

  late _MockDiscoveryRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _MockDiscoveryRepository();
    container = ProviderContainer(
      overrides: [
        discoveryRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Holds an `autoDispose` provider alive for the duration of a test, the way
  /// a mounted widget would. Without it the provider is torn down between
  /// reads and the assertions measure disposal, not behaviour.
  void keepAlive<T>(ProviderListenable<T> provider) {
    final subscription = container.listen<T>(provider, (_, _) {});
    addTearDown(subscription.close);
  }

  group('searchResultsProvider', () {
    test('returns an empty list for a blank query without calling the '
        'repository', () async {
      keepAlive(searchResultsProvider);

      final results = await container.read(searchResultsProvider.future);

      expect(results, isEmpty);
      verifyNever(() => repository.searchMedia(any()));
    });

    test('treats a whitespace-only query as blank', () async {
      keepAlive(searchResultsProvider);
      container.read(searchQueryProvider.notifier).state = '   ';

      final results = await container.read(searchResultsProvider.future);

      expect(results, isEmpty);
      verifyNever(() => repository.searchMedia(any()));
    });

    test('refetches when the query changes', () async {
      when(() => repository.searchMedia('dune'))
          .thenAnswer((_) async => const <SearchResult>[_dune]);
      when(() => repository.searchMedia('severance'))
          .thenAnswer((_) async => const <SearchResult>[_severance]);

      keepAlive(searchResultsProvider);

      container.read(searchQueryProvider.notifier).state = 'dune';
      expect(
        await container.read(searchResultsProvider.future),
        const <SearchResult>[_dune],
      );

      container.read(searchQueryProvider.notifier).state = 'severance';
      expect(
        await container.read(searchResultsProvider.future),
        const <SearchResult>[_severance],
      );

      verify(() => repository.searchMedia('dune')).called(1);
      verify(() => repository.searchMedia('severance')).called(1);
    });

    test('surfaces a repository failure as an AsyncError', () async {
      when(() => repository.searchMedia('dune'))
          .thenThrow(Exception('jellyseerr unreachable'));

      keepAlive(searchResultsProvider);
      container.read(searchQueryProvider.notifier).state = 'dune';

      await expectLater(
        container.read(searchResultsProvider.future),
        throwsA(isA<Exception>()),
      );
      expect(container.read(searchResultsProvider).hasError, isTrue);
    });
  });

  group('availableFilesProvider', () {
    test('returns an empty list while nothing is selected', () async {
      keepAlive(availableFilesProvider);

      final files = await container.read(availableFilesProvider.future);

      expect(files, isEmpty);
      verifyNever(() => repository.getAvailableFiles(any(), any()));
    });

    test('refetches when the selected media changes', () async {
      when(() => repository.getAvailableFiles(_dune.id, MediaType.movie))
          .thenAnswer((_) async => const <FileOption>[_release]);
      when(() => repository.getAvailableFiles(_severance.id, MediaType.tv))
          .thenAnswer((_) async => const <FileOption>[]);

      keepAlive(availableFilesProvider);

      container.read(selectedMediaProvider.notifier).state = _dune;
      expect(
        await container.read(availableFilesProvider.future),
        const <FileOption>[_release],
      );

      container.read(selectedMediaProvider.notifier).state = _severance;
      expect(await container.read(availableFilesProvider.future), isEmpty);

      verify(() => repository.getAvailableFiles(_dune.id, MediaType.movie))
          .called(1);
      verify(() => repository.getAvailableFiles(_severance.id, MediaType.tv))
          .called(1);
    });
  });

  group('submitMediaRequestProvider', () {
    test('throws when no media is selected', () async {
      container.read(selectedFilesProvider.notifier).state =
          const <FileOption>[_release];

      await expectLater(
        container.read(submitMediaRequestProvider(null).future),
        throwsA(isA<StateError>()),
      );
      verifyNever(() => repository.requestMedia(any(), any(), any()));
    });

    test('throws when no files are selected', () async {
      container.read(selectedMediaProvider.notifier).state = _dune;

      await expectLater(
        container.read(submitMediaRequestProvider(null).future),
        throwsA(isA<StateError>()),
      );
      verifyNever(() => repository.requestMedia(any(), any(), any()));
    });

    test('forwards the current selection to the repository', () async {
      final submitted = MediaRequest(
        id: 42,
        mediaId: _dune.id,
        status: MediaRequestStatus.pending,
        requestedAt: DateTime.utc(2026, 9, 8),
        selectedFiles: const <FileOption>[_release],
      );
      when(
        () => repository.requestMedia(
          _dune.id,
          MediaType.movie,
          const <FileOption>[_release],
        ),
      ).thenAnswer((_) async => submitted);

      container.read(selectedMediaProvider.notifier).state = _dune;
      container.read(selectedFilesProvider.notifier).state =
          const <FileOption>[_release];

      final result =
          await container.read(submitMediaRequestProvider(null).future);

      expect(result, submitted);
      verify(
        () => repository.requestMedia(
          _dune.id,
          MediaType.movie,
          const <FileOption>[_release],
        ),
      ).called(1);
    });

    test('does not resubmit when the selection changes underneath it',
        () async {
      final submitted = MediaRequest(
        id: 42,
        mediaId: _dune.id,
        status: MediaRequestStatus.pending,
        requestedAt: DateTime.utc(2026, 9, 8),
        selectedFiles: const <FileOption>[_release],
      );
      when(() => repository.requestMedia(any(), any(), any()))
          .thenAnswer((_) async => submitted);

      container.read(selectedMediaProvider.notifier).state = _dune;
      container.read(selectedFilesProvider.notifier).state =
          const <FileOption>[_release];

      keepAlive(submitMediaRequestProvider(null));
      await container.read(submitMediaRequestProvider(null).future);

      // The action reads its inputs, it does not watch them: changing the
      // selection afterwards must not fire a second request.
      container.read(selectedMediaProvider.notifier).state = _severance;
      await Future<void>.delayed(Duration.zero);

      verify(() => repository.requestMedia(any(), any(), any())).called(1);
    });
  });
}
