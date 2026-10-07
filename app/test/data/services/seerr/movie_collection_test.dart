import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/seerr/movie_collection.dart';
import 'package:moonfin/data/services/seerr/seerr_api_models.dart';
import 'package:moonfin/ui/widgets/movie_collection/movie_collection_strip.dart';
import 'dart:ui' show Locale;
import 'package:intl/date_symbol_data_local.dart';
import 'package:moonfin/util/app_l10n.dart';

SeerrDiscoverItem part(int id, String title, String? date, {int? status, bool downloading = false}) =>
    SeerrDiscoverItem(
      id: id,
      mediaType: 'movie',
      title: title,
      releaseDate: date,
      mediaInfo: status == null && !downloading
          ? null
          : SeerrMediaInfo(
              status: status,
              downloadStatus: downloading ? [SeerrDownloadingItem.fromJson(const {})] : null,
            ),
    );

void main() {
  // These expectations are written in Norwegian Bokmål.
  setUpAll(() async {
    debugAppLocaleOverride = const Locale('nb');
    await initializeDateFormatting('nb');
  });
  tearDownAll(() => debugAppLocaleOverride = null);

  final now = DateTime.utc(2026, 10, 3);

  group('ordering', () {
    test('dated parts by date, undated (announced) parts last', () {
      final ordered = MovieCollections.ordered([
        part(340023, 'Mad Max: The Wasteland', ''),
        part(76341, 'Mad Max: Fury Road', '2015-05-13'),
        part(9659, 'Mad Max', '1979-04-12'),
        part(8810, 'Mad Max 2', '1981-12-24'),
      ]);
      expect(ordered.map((p) => p.id), [9659, 8810, 76341, 340023]);
    });
  });

  group('build', () {
    final bttf = SeerrCollection(id: 264, name: 'Back to the Future Collection', parts: [
      part(196, 'Back to the Future Part III', '1990-05-25', status: 5),
      part(105, 'Back to the Future', '1985-07-03', status: 5),
      part(165, 'Back to the Future Part II', '1989-11-22', status: 5),
    ]);
    const owned = {105: 'jf105', 165: 'jf165', 196: 'jf196'};

    test('leaves the current movie out and numbers "Del N av M" in release order', () {
      final strip = MovieCollections.build(
        collection: bttf, currentTmdbId: 165, owned: owned, now: now)!;
      expect(strip.name, 'Back to the Future');
      expect(strip.currentNumber, 2);
      expect(strip.total, 3);
      expect(strip.others.map((p) => p.tmdbId), [105, 196]);
      expect(strip.others.map((p) => p.partLabel), ['Del 1 av 3', 'Del 3 av 3']);
      expect(strip.others.every((p) => p.state == CollectionPartState.owned), isTrue);
      expect(strip.others.first.jellyfinItemId, 'jf105');
    });

    test('no strip when the collection has only the current movie', () {
      final solo = SeerrCollection(id: 1, name: 'Solo', parts: [part(1, 'A', '2000-01-01')]);
      expect(
        MovieCollections.build(collection: solo, currentTmdbId: 1, owned: const {}, now: now),
        isNull,
      );
    });

    test('Seerr "available" without a Jellyfin item counts as missing', () {
      final strip = MovieCollections.build(
          collection: bttf, currentTmdbId: 105, owned: const {105: 'jf105'}, now: now)!;
      expect(strip.others.map((p) => p.state),
          [CollectionPartState.missing, CollectionPartState.missing]);
      expect(strip.others.first.canDownload, isTrue);
    });
  });

  group('state', () {
    test('owned, missing, unreleased, requested, downloading', () {
      CollectionPartState s(SeerrDiscoverItem p, [Map<int, String> owned = const {}]) =>
          MovieCollections.stateFor(p, owned: owned, now: now);
      expect(s(part(1, 'A', '1999-01-01'), {1: 'x'}), CollectionPartState.owned);
      expect(s(part(2, 'B', '1999-01-01')), CollectionPartState.missing);
      expect(s(part(3, 'C', '1999-01-01', status: 7)), CollectionPartState.missing);
      expect(s(part(4, 'D', '2027-06-01')), CollectionPartState.unreleased);
      expect(s(part(5, 'E', null)), CollectionPartState.unreleased);
      expect(s(part(6, 'F', '1999-01-01', status: 2)), CollectionPartState.requested);
      expect(s(part(7, 'G', '1999-01-01', status: 3)), CollectionPartState.downloading);
      expect(s(part(8, 'H', '1999-01-01', downloading: true)), CollectionPartState.downloading);
    });

    test('unreleased and downloading parts are not downloadable', () {
      const unreleased = CollectionPart(
          tmdbId: 1, title: 'X', number: 1, total: 2, state: CollectionPartState.unreleased);
      const downloading = CollectionPart(
          tmdbId: 1, title: 'X', number: 1, total: 2, state: CollectionPartState.downloading);
      expect(unreleased.canDownload, isFalse);
      expect(downloading.canDownload, isFalse);
    });

    test('badges', () {
      CollectionPart p(CollectionPartState s, [DateTime? d]) => CollectionPart(
          tmdbId: 1, title: 'X', number: 1, total: 2, state: s, releaseDate: d);
      expect(collectionPartBadge(p(CollectionPartState.owned)), '');
      expect(collectionPartBadge(p(CollectionPartState.missing)), 'Mangler');
      expect(collectionPartBadge(p(CollectionPartState.unreleased)), 'Kommer');
      expect(
        collectionPartBadge(p(CollectionPartState.unreleased, DateTime(2026, 10, 12)), now: now),
        'Kommer 12. okt.',
      );
    });
  });

  group('owned map from Jellyfin items', () {
    test('reads the Tmdb provider id case-insensitively, skips box sets and items without one', () {
      final owned = MovieCollections.ownedFromItems([
        {'Id': 'a', 'ProviderIds': {'Tmdb': '105'}},
        {'Id': 'b', 'ProviderIds': {'tmdb': '165'}},
        {'Id': 'c', 'ProviderIds': {'Imdb': 'tt1'}},
        {'Id': 'd'},
        {'Id': 'e', 'Type': 'BoxSet', 'ProviderIds': {'Tmdb': '264'}},
        {'Id': 'f', 'Type': 'Movie', 'ProviderIds': {'Tmdb': '196'}},
      ]);
      expect(owned, {105: 'a', 165: 'b', 196: 'f'});
    });
  });

  test('cleanName drops the English "Collection" suffix', () {
    expect(MovieCollections.cleanName('Mad Max Collection'), 'Mad Max');
    expect(MovieCollections.cleanName('Rambo'), 'Rambo');
  });
}
