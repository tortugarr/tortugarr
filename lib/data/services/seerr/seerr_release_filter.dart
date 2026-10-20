import 'package:flutter/foundation.dart';

import 'seerr_api_models.dart';

/// Keeps "Trending" to things you can actually watch or download in decent
/// quality.
///
/// TMDB trending measures buzz on TMDB, so it is full of films that are only
/// in cinemas or not out at all. Those only exist as CAM/TS copies. A movie
/// is kept once it has a digital or physical (DVD/Blu-ray) release; series
/// once they have aired, since episodes appear as web releases when they air.
/// Anything already in the library always stays.
class SeerrReleaseFilter {
  /// Movies with no digital/physical date on TMDB at all: assume a home
  /// release exists once the premiere is this old.
  static const Duration assumeHomeReleaseAfter = Duration(days: 120);

  /// tmdbId -> earliest digital/physical release, or null when TMDB has none.
  /// Release dates do not change often; "none" is re-checked after a while.
  static final Map<int, ({DateTime? date, DateTime checkedAt})> _cache = {};
  static const Duration _recheckUnknownAfter = Duration(hours: 12);

  final Future<Map<String, dynamic>> Function(int tmdbId) _movieDetails;
  final DateTime Function() _now;

  SeerrReleaseFilter(
    this._movieDetails, {
    @visibleForTesting DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  Future<SeerrDiscoverPage> apply(SeerrDiscoverPage page) async {
    final keep = await Future.wait(page.results.map(_isWatchable));
    return SeerrDiscoverPage(
      results: [
        for (var i = 0; i < page.results.length; i++)
          if (keep[i]) page.results[i],
      ],
      totalPages: page.totalPages,
      totalResults: page.totalResults,
      page: page.page,
    );
  }

  Future<bool> _isWatchable(SeerrDiscoverItem item) async {
    if (item.isAvailable) return true;
    final today = _now();
    if (item.mediaType == 'tv') {
      final aired = _parse(item.firstAirDate);
      return aired != null && !aired.isAfter(today);
    }
    if (item.mediaType != 'movie') return true; // people, collections

    final premiere = _parse(item.releaseDate);
    if (premiere == null || premiere.isAfter(today)) return false;

    final DateTime? home;
    try {
      home = await _homeRelease(item.id);
    } catch (e) {
      // Never blank the row because Seerr hiccuped: fall back to the age rule.
      debugPrint('[TrendingFilter] details for ${item.id} failed: $e');
      return today.difference(premiere) > assumeHomeReleaseAfter;
    }
    if (home != null) return !home.isAfter(today);
    return today.difference(premiere) > assumeHomeReleaseAfter;
  }

  Future<DateTime?> _homeRelease(int tmdbId) async {
    final cached = _cache[tmdbId];
    final now = _now();
    if (cached != null &&
        (cached.date != null ||
            now.difference(cached.checkedAt) < _recheckUnknownAfter)) {
      return cached.date;
    }
    final details = await _movieDetails(tmdbId);
    final date = earliestHomeRelease(details);
    _cache[tmdbId] = (date: date, checkedAt: now);
    return date;
  }

  /// Earliest TMDB release of type 4 (digital) or 5 (physical) in any country.
  @visibleForTesting
  static DateTime? earliestHomeRelease(Map<String, dynamic> movieDetails) {
    final releases = movieDetails['releases'];
    final results = releases is Map ? releases['results'] : null;
    if (results is! List) return null;
    DateTime? earliest;
    for (final country in results.whereType<Map>()) {
      final dates = country['release_dates'];
      if (dates is! List) continue;
      for (final d in dates.whereType<Map>()) {
        final type = d['type'];
        if (type != 4 && type != 5) continue;
        final date = _parse(d['release_date'] as String?);
        if (date != null && (earliest == null || date.isBefore(earliest))) {
          earliest = date;
        }
      }
    }
    return earliest;
  }

  static DateTime? _parse(String? s) =>
      (s == null || s.isEmpty) ? null : DateTime.tryParse(s);

  @visibleForTesting
  static void clearCache() => _cache.clear();
}
