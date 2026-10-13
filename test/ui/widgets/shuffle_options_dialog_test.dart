import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/models/aggregated_library.dart';
import 'package:moonfin/ui/widgets/shuffle_options_dialog.dart';

AggregatedLibrary _library(String name, String collectionType) {
  return AggregatedLibrary(
    id: 'id-$name',
    name: name,
    collectionType: collectionType,
    serverId: 'server',
  );
}

void main() {
  group('supportsShuffleLibraryForContentType', () {
    // A mixed content library holds movies and shows together, and the server says so by
    // sending no collection type, so it has to survive every content type.
    test('offers a mixed library whatever the content type', () {
      for (final collectionType in ['', 'mixed', 'unknown']) {
        final library = _library('Japanese', collectionType);
        for (final contentType in ['both', 'movies', 'shows']) {
          expect(
            supportsShuffleLibraryForContentType(library, contentType),
            isTrue,
            reason: 'collectionType "$collectionType" with "$contentType"',
          );
        }
      }
    });

    test('keeps movie and show libraries on their own content type', () {
      final movies = _library('Movies', 'movies');
      final shows = _library('Shows', 'tvshows');

      expect(supportsShuffleLibraryForContentType(movies, 'movies'), isTrue);
      expect(supportsShuffleLibraryForContentType(movies, 'shows'), isFalse);
      expect(supportsShuffleLibraryForContentType(shows, 'shows'), isTrue);
      expect(supportsShuffleLibraryForContentType(shows, 'movies'), isFalse);
      expect(supportsShuffleLibraryForContentType(movies, 'both'), isTrue);
      expect(supportsShuffleLibraryForContentType(shows, 'both'), isTrue);
    });

    test('drops the collection types that hold nothing to shuffle', () {
      for (final collectionType in ['books', 'playlists', 'livetv', 'boxsets']) {
        expect(
          supportsShuffleLibraryForContentType(
            _library(collectionType, collectionType),
            'both',
          ),
          isFalse,
        );
      }
    });

    // The name check has to run first, otherwise these two arrive with no collection type
    // and get waved through as mixed libraries.
    test('drops folders and recordings even without a collection type', () {
      expect(
        supportsShuffleLibraryForContentType(_library('Folders', ''), 'both'),
        isFalse,
      );
      expect(
        supportsShuffleLibraryForContentType(_library('Recordings', ''), 'both'),
        isFalse,
      );
    });
  });
}
