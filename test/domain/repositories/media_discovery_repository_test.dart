import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/models/dto/jellyseerr_dto.dart';
import 'package:moonfin/data/repositories/media_discovery_repository_impl.dart';
import 'package:moonfin/data/services/jellyseerr_service.dart';
import 'package:moonfin/domain/models/media_discovery.dart';
import 'package:moonfin/domain/repositories/media_discovery_repository.dart';

class _MockJellyseerrService extends Mock implements JellyseerrService {}

JellyseerrSearchResultDto _searchDto({
  int id = 693134,
  String title = 'Dune: Part Two',
  String releaseYear = '2024',
  String description = 'Paul Atreides unites with the Fremen.',
  String posterPath = '/dune2.jpg',
  String mediaType = 'movie',
  double voteAverage = 8.2,
}) =>
    JellyseerrSearchResultDto(
      id: id,
      title: title,
      releaseYear: releaseYear,
      description: description,
      posterPath: posterPath,
      mediaType: mediaType,
      voteAverage: voteAverage,
    );

JellyseerrFileOptionDto _fileDto({
  String path = 'Dune.Part.Two.2024.1080p.WEB-DL.mkv',
  String resolution = '1080p',
  int sizeInMb = 4096,
  int seeders = 42,
  int leechers = 3,
}) =>
    JellyseerrFileOptionDto(
      path: path,
      resolution: resolution,
      sizeInMb: sizeInMb,
      seeders: seeders,
      leechers: leechers,
    );

void main() {
  late _MockJellyseerrService jellyseerr;
  late MediaDiscoveryRepository repository;

  setUp(() {
    jellyseerr = _MockJellyseerrService();
    repository = MediaDiscoveryRepositoryImpl(jellyseerr: jellyseerr);
  });

  group('searchMedia', () {
    test('maps every DTO field onto SearchResult', () async {
      when(() => jellyseerr.search('dune')).thenAnswer(
        (_) async => [_searchDto()],
      );

      final results = await repository.searchMedia('dune');

      expect(results, hasLength(1));
      final result = results.single;
      expect(result.id, 693134);
      expect(result.title, 'Dune: Part Two');
      expect(result.releaseYear, 2024);
      expect(result.description, 'Paul Atreides unites with the Fremen.');
      expect(result.posterPath, '/dune2.jpg');
      expect(result.mediaType, MediaType.movie);
      expect(result.rating, 8.2);
      expect(result.hasReleaseYear, isTrue);
    });

    test('maps a tv row onto MediaType.tv', () async {
      when(() => jellyseerr.search(any())).thenAnswer(
        (_) async => [_searchDto(id: 1399, title: 'Shogun', mediaType: 'tv')],
      );

      final results = await repository.searchMedia('shogun');

      expect(results.single.mediaType, MediaType.tv);
      expect(results.single.mediaType.toDisplay(), 'TV Series');
    });

    test('drops rows whose media type has no domain equivalent', () async {
      when(() => jellyseerr.search(any())).thenAnswer(
        (_) async => [
          _searchDto(id: 1, mediaType: 'movie'),
          _searchDto(id: 2, mediaType: 'person'),
          _searchDto(id: 3, mediaType: ''),
          _searchDto(id: 4, mediaType: 'tv'),
        ],
      );

      final results = await repository.searchMedia('villeneuve');

      expect(results.map((r) => r.id), [1, 4]);
    });

    test('turns an absent release year into 0 rather than throwing', () async {
      when(() => jellyseerr.search(any())).thenAnswer(
        (_) async => [_searchDto(releaseYear: '')],
      );

      final result = (await repository.searchMedia('unreleased')).single;

      expect(result.releaseYear, 0);
      expect(result.hasReleaseYear, isFalse);
    });

    test('lets a JellyseerrServiceException through unchanged', () async {
      const failure = JellyseerrServiceException(
        'Jellyseerr search for "dune" failed: could not reach host',
        statusCode: 503,
      );
      when(() => jellyseerr.search(any())).thenThrow(failure);

      await expectLater(
        repository.searchMedia('dune'),
        throwsA(same(failure)),
      );
    });
  });

  group('getAvailableFiles', () {
    test('sends the media type as its wire value and maps the DTOs', () async {
      when(() => jellyseerr.getAvailableFiles(any(), any())).thenAnswer(
        (_) async => [_fileDto()],
      );

      final files = await repository.getAvailableFiles(693134, MediaType.movie);

      verify(() => jellyseerr.getAvailableFiles(693134, 'movie')).called(1);
      expect(files, hasLength(1));
      final file = files.single;
      expect(file.path, 'Dune.Part.Two.2024.1080p.WEB-DL.mkv');
      expect(file.resolution, Resolution.p1080);
      expect(file.sizeInMb, 4096);
      expect(file.seeders, 42);
      expect(file.hasSeeders, isTrue);
    });

    test("sends 'tv' for MediaType.tv", () async {
      when(() => jellyseerr.getAvailableFiles(any(), any()))
          .thenAnswer((_) async => const <JellyseerrFileOptionDto>[]);

      await repository.getAvailableFiles(1399, MediaType.tv);

      verify(() => jellyseerr.getAvailableFiles(1399, 'tv')).called(1);
    });

    test('parses every resolution tier the picker offers', () async {
      when(() => jellyseerr.getAvailableFiles(any(), any())).thenAnswer(
        (_) async => [
          _fileDto(path: 'a.720p.mkv', resolution: '720p'),
          _fileDto(path: 'b.1080p.mkv', resolution: '1080p'),
          _fileDto(path: 'c.2160p.mkv', resolution: '2160p'),
          _fileDto(path: 'd.4k.mkv', resolution: '4K'),
        ],
      );

      final files = await repository.getAvailableFiles(1, MediaType.movie);

      expect(
        files.map((f) => f.resolution),
        [
          Resolution.p720,
          Resolution.p1080,
          Resolution.p2160,
          Resolution.p2160,
        ],
      );
      expect(files.last.resolution.toDisplay(), '2160p (4K)');
    });

    test('falls back to the release name when the tag is unusable', () async {
      when(() => jellyseerr.getAvailableFiles(any(), any())).thenAnswer(
        (_) async => [
          // Indexer reported a quality profile name, not a resolution.
          _fileDto(path: 'Dune.2024.2160p.REMUX.mkv', resolution: 'Ultra-HD'),
          // Nothing usable anywhere — the total-enum fallback applies.
          _fileDto(path: 'Dune.2024.DVDRip.avi', resolution: ''),
        ],
      );

      final files = await repository.getAvailableFiles(1, MediaType.movie);

      expect(files.first.resolution, Resolution.p2160);
      expect(files.last.resolution, Resolution.p720);
    });

    test('lets a JellyseerrServiceException through unchanged', () async {
      const failure = JellyseerrServiceException(
        "Unsupported mediaType 'book'",
      );
      when(() => jellyseerr.getAvailableFiles(any(), any())).thenThrow(failure);

      await expectLater(
        repository.getAvailableFiles(1, MediaType.movie),
        throwsA(same(failure)),
      );
    });
  });

  group('requestMedia', () {
    final files = [
      const FileOption(
        path: 'Dune.Part.Two.2024.2160p.mkv',
        resolution: Resolution.p2160,
        sizeInMb: 20480,
        seeders: 12,
      ),
      const FileOption(
        path: 'Dune.Part.Two.2024.1080p.mkv',
        resolution: Resolution.p1080,
        sizeInMb: 4096,
        seeders: 90,
      ),
    ];

    test('submits the selected paths and maps the confirmation', () async {
      final requestedAt = DateTime.utc(2026, 9, 8, 12, 30);
      when(() => jellyseerr.submitRequest(any(), any(), any())).thenAnswer(
        (_) async => JellyseerrMediaRequestDto(
          requestId: 77,
          mediaId: 693134,
          status: '1',
          requestedAt: requestedAt,
        ),
      );

      final request =
          await repository.requestMedia(693134, MediaType.movie, files);

      verify(
        () => jellyseerr.submitRequest(693134, 'movie', [
          'Dune.Part.Two.2024.2160p.mkv',
          'Dune.Part.Two.2024.1080p.mkv',
        ]),
      ).called(1);

      expect(request.id, 77);
      expect(request.mediaId, 693134);
      expect(request.status, MediaRequestStatus.pending);
      expect(request.isPending, isTrue);
      expect(request.requestedAt, requestedAt);
      // The confirmation echoes only ids, so the caller's selection is the
      // only record of which releases the request covers.
      expect(request.selectedFiles, files);
    });

    test('normalises the status codes Jellyseerr sends', () async {
      Future<String> statusFor(String raw) async {
        when(() => jellyseerr.submitRequest(any(), any(), any())).thenAnswer(
          (_) async => JellyseerrMediaRequestDto(
            requestId: 1,
            mediaId: 2,
            status: raw,
            requestedAt: DateTime.utc(2026),
          ),
        );
        final request =
            await repository.requestMedia(2, MediaType.tv, const []);
        return request.status;
      }

      expect(await statusFor('1'), MediaRequestStatus.pending);
      expect(await statusFor('2'), MediaRequestStatus.approved);
      expect(await statusFor('3'), MediaRequestStatus.declined);
      expect(await statusFor('4'), MediaRequestStatus.failed);
      expect(await statusFor('APPROVED'), MediaRequestStatus.approved);
      expect(await statusFor('available'), MediaRequestStatus.completed);
      expect(await statusFor('flerbling'), MediaRequestStatus.unknown);
    });

    test('falls back to the requested media id when the DTO has none',
        () async {
      when(() => jellyseerr.submitRequest(any(), any(), any())).thenAnswer(
        (_) async => JellyseerrMediaRequestDto(
          requestId: 5,
          // A proxy that strips the nested media object leaves this at 0.
          mediaId: 0,
          status: 'approved',
          requestedAt: DateTime.utc(2026),
        ),
      );

      final request = await repository.requestMedia(1399, MediaType.tv, files);

      expect(request.mediaId, 1399);
      expect(request.isApproved, isTrue);
    });

    test('returns an unmodifiable selection', () async {
      when(() => jellyseerr.submitRequest(any(), any(), any())).thenAnswer(
        (_) async => JellyseerrMediaRequestDto(
          requestId: 5,
          mediaId: 1,
          status: 'pending',
          requestedAt: DateTime.utc(2026),
        ),
      );

      final request = await repository.requestMedia(1, MediaType.movie, files);

      expect(
        () => request.selectedFiles.add(files.first),
        throwsUnsupportedError,
      );
    });

    test('lets a JellyseerrServiceException through unchanged', () async {
      const failure = JellyseerrServiceException(
        'Jellyseerr request for movie 1 failed: server responded 409',
        statusCode: 409,
      );
      when(() => jellyseerr.submitRequest(any(), any(), any()))
          .thenThrow(failure);

      await expectLater(
        repository.requestMedia(1, MediaType.movie, files),
        throwsA(same(failure)),
      );
    });
  });

  group('domain model behaviour', () {
    test('SearchResult compares by value', () {
      const a = SearchResult(
        id: 1,
        title: 'Dune',
        releaseYear: 2021,
        description: '',
        posterPath: '',
        mediaType: MediaType.movie,
        rating: 8.0,
      );

      expect(a, equals(a.copyWith()));
      expect(a.hashCode, a.copyWith().hashCode);
      expect(a, isNot(equals(a.copyWith(releaseYear: 2024))));
    });

    test('MediaRequest compares its selection by value, not identity', () {
      final base = MediaRequest(
        id: 1,
        mediaId: 2,
        status: MediaRequestStatus.pending,
        requestedAt: DateTime.utc(2026),
        selectedFiles: const [
          FileOption(
            path: 'a.mkv',
            resolution: Resolution.p1080,
            sizeInMb: 1,
            seeders: 1,
          ),
        ],
      );

      final twin = base.copyWith(
        selectedFiles: const [
          FileOption(
            path: 'a.mkv',
            resolution: Resolution.p1080,
            sizeInMb: 1,
            seeders: 1,
          ),
        ],
      );

      expect(base, equals(twin));
      expect(base.hashCode, twin.hashCode);
      expect(base, isNot(equals(base.copyWith(selectedFiles: const []))));
    });

    test('FileOption reports size in gigabytes', () {
      const file = FileOption(
        path: 'a.mkv',
        resolution: Resolution.p2160,
        sizeInMb: 2048,
        seeders: 0,
      );

      expect(file.sizeInGb, 2.0);
      expect(file.hasSeeders, isFalse);
      expect(file.resolution.heightInPixels, 2160);
    });
  });
}
