import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'seerr_api_models.dart';
import 'package:moonfin/util/app_l10n.dart';
import 'package:moonfin/preference/seerr_preferences.dart';
import 'package:moonfin/util/subtitle_track_logic.dart';

/// Settings > "Skjul utenlandsk innhold": the discovery rows (Trending,
/// Popular, Upcoming and genre/studio/network browsing) only show titles
/// whose original language is one the household watches. TMDB buzz is full
/// of anime and Asian TV, which made the rows mostly noise.
///
/// Anything already in the library always stays.
class SeerrLanguageFilter {
  /// TMDB original_language codes (ISO 639-1). Norwegian shows up as "no",
  /// "nb" or "nn" depending on who entered the title.
  static const Set<String> allowedLanguages = {
    'en',
    'no',
    'nb',
    'nn',
    'sv',
    'da',
    'de',
    'fr',
  };

  /// The TMDB codes the filter keeps right now: the languages picked in
  /// Settings > Languages in Trending and Popular ([allowedLanguages] by
  /// default).
  static Set<String> get currentAllowed =>
      tmdbCodesFor(discoveryLanguagesSetting(), languages: discoveryMenuLanguages);

  /// Titles without a language are dropped: TMDB fills it in for every real
  /// movie and series, so a missing one is a person or a broken entry.
  static bool keeps(SeerrDiscoverItem item, {Set<String>? allowed}) {
    if (item.isAvailable) return true;
    final lang = item.originalLanguage?.trim().toLowerCase();
    return lang != null && (allowed ?? currentAllowed).contains(lang);
  }

  static List<SeerrDiscoverItem> apply(
    List<SeerrDiscoverItem> items, {
    Set<String>? allowed,
  }) {
    final codes = allowed ?? currentAllowed;
    return items.where((item) => keeps(item, allowed: codes)).toList();
  }

  /// How the household reads the allowed languages on a badge (country
  /// style for the Nordic ones).
  static const Map<String, String> displayCodes = {
    'en': 'EN',
    'no': 'NO',
    'nb': 'NO',
    'nn': 'NO',
    'sv': 'SE',
    'da': 'DK',
    'de': 'DE',
    'fr': 'FR',
    'es': 'ES',
    'it': 'IT',
    'nl': 'NL',
    'fi': 'FI',
    'pt': 'PT',
    'pl': 'PL',
  };

  /// The language badge a discovery card shows.
  ///
  /// With [active] (Settings > Show what is hidden) the rows stay unfiltered
  /// and every title carries its language; titles the filter would drop get
  /// the red HIDDEN badge with the ISO code ("?" when TMDB has none).
  /// With only [badges] (Settings > Show language badges) the kept titles
  /// show their language in green and every foreign title a grey badge;
  /// nothing is marked hidden. Null when neither is on.
  static SeerrLanguageMark? previewMark(
    SeerrDiscoverItem item, {
    required bool active,
    bool badges = false,
    Set<String>? allowed,
  }) {
    if (!active && !badges) return null;
    final codes = allowed ?? currentAllowed;
    final lang = item.originalLanguage?.trim().toLowerCase() ?? '';
    if (lang.isNotEmpty && codes.contains(lang)) {
      return SeerrLanguageMark(
        displayCodes[lang] ?? lang.toUpperCase(),
        SeerrLanguageMarkKind.kept,
      );
    }
    final code = lang.isEmpty ? '?' : lang.toUpperCase();
    if (item.isAvailable) {
      return SeerrLanguageMark(code, SeerrLanguageMarkKind.libraryForeign);
    }
    // Foreign titles that are still on screen (Seerr browse/search, which the
    // filter does not thin out) carry their code too, so every card is labelled.
    return active
        ? SeerrLanguageMark(code, SeerrLanguageMarkKind.hidden)
        : SeerrLanguageMark(code, SeerrLanguageMarkKind.foreign);
  }
}

enum SeerrLanguageMarkKind {
  /// Allowed language: stays in the rows.
  kept,

  /// Foreign, but stays because it is in the library.
  libraryForeign,

  /// The filter removes it when preview is off.
  hidden,

  /// Foreign and not in the library, shown where the filter does not apply
  /// (grey badge, like [libraryForeign]).
  foreign,
}

/// The language badge a card shows in preview mode.
@immutable
class SeerrLanguageMark {
  final String code;
  final SeerrLanguageMarkKind kind;

  const SeerrLanguageMark(this.code, this.kind);

  String get label =>
      kind == SeerrLanguageMarkKind.hidden ? appL10n().tgHiddenBadge(code) : code;

  /// Cards get their data as a raw map; these keep the mark readable there.
  static const codeKey = 'SeerrLangMark';
  static const kindKey = 'SeerrLangKind';

  Map<String, String> toRaw() => {codeKey: code, kindKey: kind.name};

  static SeerrLanguageMark? fromRaw(Map<String, dynamic> raw) {
    final code = raw[codeKey];
    final kind = SeerrLanguageMarkKind.values.asNameMap()[raw[kindKey]];
    if (code is! String || kind == null) return null;
    return SeerrLanguageMark(code, kind);
  }

  @override
  bool operator ==(Object other) =>
      other is SeerrLanguageMark && other.code == code && other.kind == kind;

  @override
  int get hashCode => Object.hash(code, kind);

  @override
  String toString() => 'SeerrLanguageMark($code, ${kind.name})';
}

/// Keeps filtered rows full.
///
/// Filtering a 20-title TMDB page down to a handful leaves rows with two
/// posters here and one there. For each row page the app asks for, this pulls
/// further upstream pages until the row has as many titles as one unfiltered
/// page would, at most [maxExtraPages] more. The upstream page each row page
/// starts at is remembered per row, so paging on continues where the last
/// page stopped instead of repeating or skipping titles.
class SeerrFilledPager {
  static const int maxExtraPages = 5;

  /// Row key -> row page -> upstream page it starts at.
  final Map<String, Map<int, int>> _starts = {};

  Future<SeerrDiscoverPage> load({
    required String key,
    required int page,
    required Future<SeerrDiscoverPage> Function(int upstreamPage) fetch,
    required Future<List<SeerrDiscoverItem>> Function(
      List<SeerrDiscoverItem> items,
    )
    filter,
  }) async {
    final starts = _starts.putIfAbsent(key, () => {});
    starts[1] = 1;
    final wanted = math.max(page, 1);

    // Rows page one after the other, so the start is normally known. If a
    // page is asked for out of order, walk forward from the last known one.
    var p = wanted;
    while (!starts.containsKey(p)) {
      p--;
    }
    while (true) {
      final result = await _fill(starts, p, fetch, filter);
      if (p == wanted) return result;
      if (result.totalPages <= p) {
        // Upstream ran out before the asked-for page.
        return SeerrDiscoverPage(
          totalPages: p,
          totalResults: result.totalResults,
          page: wanted,
        );
      }
      p++;
    }
  }

  Future<SeerrDiscoverPage> _fill(
    Map<int, int> starts,
    int page,
    Future<SeerrDiscoverPage> Function(int upstreamPage) fetch,
    Future<List<SeerrDiscoverItem>> Function(List<SeerrDiscoverItem> items)
    filter,
  ) async {
    var upstream = starts[page]!;
    final kept = <SeerrDiscoverItem>[];
    final seen = <String>{};
    var target = 0;
    var fetched = 0;
    var totalPages = 0;
    var totalResults = 0;
    bool exhausted;
    while (true) {
      final raw = await fetch(upstream);
      fetched++;
      if (target == 0) target = raw.results.length;
      totalPages = raw.totalPages;
      totalResults = raw.totalResults;
      for (final item in await filter(raw.results)) {
        if (seen.add('${item.mediaType}:${item.id}')) kept.add(item);
      }
      exhausted = raw.results.isEmpty || upstream >= raw.totalPages;
      upstream++;
      if (exhausted || kept.length >= target || fetched > maxExtraPages) {
        break;
      }
    }
    starts[page + 1] = upstream;
    return SeerrDiscoverPage(
      results: kept,
      // Callers stop paging once page >= totalPages.
      totalPages: exhausted ? page : math.max(totalPages, page + 1),
      totalResults: totalResults,
      page: page,
    );
  }

  @visibleForTesting
  int? upstreamStart(String key, int page) => _starts[key]?[page];
}
