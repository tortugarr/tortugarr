import 'seerr_api_models.dart';
import 'package:moonfin/util/app_l10n.dart';

/// Where one movie of a collection stands for this library.
enum CollectionPartState {
  /// In the library: selecting it opens the movie.
  owned,

  /// Released, not in the library: selecting it opens Download Now.
  missing,

  /// Asked for in Seerr but not downloading yet; still downloadable.
  requested,

  /// Seerr reports it as being processed/downloaded.
  downloading,

  /// No release date yet, or the release date is in the future.
  unreleased,
}

/// One of the other movies in the collection the current movie belongs to.
class CollectionPart {
  final int tmdbId;
  final String title;
  final DateTime? releaseDate;
  final String? posterPath;

  /// 1-based position in release order, counting every part.
  final int number;
  final int total;
  final CollectionPartState state;

  /// Jellyfin item id when [state] is [CollectionPartState.owned].
  final String? jellyfinItemId;

  const CollectionPart({
    required this.tmdbId,
    required this.title,
    required this.number,
    required this.total,
    required this.state,
    this.releaseDate,
    this.posterPath,
    this.jellyfinItemId,
  });

  int? get year => releaseDate?.year;

  bool get canDownload =>
      state == CollectionPartState.missing ||
      state == CollectionPartState.requested;

  /// "Del 2 av 5".
  String get partLabel => appL10n().tgPartOf(number, total);
}

/// What the "Del av filmserien" strip shows on a movie's detail screen.
class MovieCollectionStrip {
  final int collectionId;
  final String name;

  /// Position of the movie being viewed, or null when it is not a part.
  final int? currentNumber;
  final int total;

  /// The other parts, in release order.
  final List<CollectionPart> others;

  const MovieCollectionStrip({
    required this.collectionId,
    required this.name,
    required this.currentNumber,
    required this.total,
    required this.others,
  });
}

/// Pure rules for the collection strip, so they can be tested without a
/// server.
class MovieCollections {
  /// Seerr media statuses (MediaStatus in Seerr's source).
  static const _statusPending = 2;
  static const _statusProcessing = 3;

  static DateTime? parseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim());
  }

  /// Release order: dated parts by date, then undated ones (announced
  /// sequels) by title.
  static List<SeerrDiscoverItem> ordered(List<SeerrDiscoverItem> parts) {
    final list = List<SeerrDiscoverItem>.from(parts);
    list.sort((a, b) {
      final da = parseDate(a.releaseDate);
      final db = parseDate(b.releaseDate);
      if (da != null && db != null) {
        final byDate = da.compareTo(db);
        if (byDate != 0) return byDate;
      } else if (da != null) {
        return -1;
      } else if (db != null) {
        return 1;
      }
      return a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase());
    });
    return list;
  }

  /// Owned only counts when Jellyfin really has the movie: Seerr can say
  /// "available" for a file that is gone.
  static CollectionPartState stateFor(
    SeerrDiscoverItem part, {
    required Map<int, String> owned,
    required DateTime now,
  }) {
    if (owned.containsKey(part.id)) return CollectionPartState.owned;
    final info = part.mediaInfo;
    if ((info?.downloadStatus?.isNotEmpty ?? false) ||
        info?.status == _statusProcessing) {
      return CollectionPartState.downloading;
    }
    final released = parseDate(part.releaseDate);
    if (released == null || released.isAfter(now)) {
      return CollectionPartState.unreleased;
    }
    if (info?.status == _statusPending) return CollectionPartState.requested;
    return CollectionPartState.missing;
  }

  /// The strip for the movie with TMDB id [currentTmdbId]; null when the
  /// collection has no other parts. [owned] maps TMDB id to Jellyfin item id.
  static MovieCollectionStrip? build({
    required SeerrCollection collection,
    required int currentTmdbId,
    required Map<int, String> owned,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final parts = ordered(collection.parts);
    final total = parts.length;
    int? current;
    final others = <CollectionPart>[];
    for (var i = 0; i < parts.length; i++) {
      final p = parts[i];
      if (p.id == currentTmdbId) {
        current = i + 1;
        continue;
      }
      final state = stateFor(p, owned: owned, now: at);
      others.add(CollectionPart(
        tmdbId: p.id,
        title: p.displayTitle.isEmpty ? appL10n().tgUnknownTitle : p.displayTitle,
        releaseDate: parseDate(p.releaseDate),
        posterPath: p.posterPath,
        number: i + 1,
        total: total,
        state: state,
        jellyfinItemId: state == CollectionPartState.owned ? owned[p.id] : null,
      ));
    }
    if (others.isEmpty) return null;
    final name = (collection.name ?? '').trim();
    return MovieCollectionStrip(
      collectionId: collection.id,
      name: name.isEmpty ? appL10n().tgMovieCollection : cleanName(name),
      currentNumber: current,
      total: total,
      others: others,
    );
  }

  /// TMDB names collections "Back to the Future Collection"; the strip
  /// already says "filmserien", so drop the English suffix.
  static String cleanName(String name) =>
      name.replaceFirst(RegExp(r'\s+Collection$', caseSensitive: false), '');

  /// TMDB id -> Jellyfin item id for Jellyfin movie items (raw API maps).
  static Map<int, String> ownedFromItems(Iterable<Map<String, dynamic>> items) {
    final out = <int, String>{};
    for (final raw in items) {
      // A box set carries the collection's TMDB id, not a movie's.
      final type = raw['Type'];
      if (type != null && type != 'Movie') continue;
      final ids = raw['ProviderIds'];
      if (ids is! Map) continue;
      String? tmdb;
      for (final e in ids.entries) {
        if ('${e.key}'.toLowerCase() == 'tmdb') tmdb = '${e.value}';
      }
      final id = int.tryParse(tmdb ?? '');
      final itemId = raw['Id']?.toString();
      if (id == null || itemId == null || itemId.isEmpty) continue;
      out.putIfAbsent(id, () => itemId);
    }
    return out;
  }
}
