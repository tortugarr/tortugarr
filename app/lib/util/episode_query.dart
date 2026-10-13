/// A search query split into the show title and an optional season/episode.
///
/// TMDB (and so Seerr) only searches titles: "American Horror Story S13E04"
/// finds nothing, "American Horror Story" finds the show.
class EpisodeQuery {
  final String title;
  final int? season;
  final int? episode;

  const EpisodeQuery(this.title, {this.season, this.episode});

  bool get hasSeason => season != null;

  @override
  String toString() => 'EpisodeQuery($title, s=$season, e=$episode)';
}

final _sxxeyy = RegExp(r'\bs(\d{1,2})\s*e(\d{1,3})\b', caseSensitive: false);
final _nxm = RegExp(r'\b(\d{1,2})x(\d{1,3})\b', caseSensitive: false);
final _sxx = RegExp(r'\bs(\d{1,2})\b', caseSensitive: false);
final _seasonWord =
    RegExp(r'\b(?:season|sesong|saison|staffel)\s*(\d{1,2})\b', caseSensitive: false);
final _episodeWord =
    RegExp(r'\b(?:episode|episod|ep|e)\s*(\d{1,3})\b', caseSensitive: false);

/// Splits episode codes out of [raw]. When nothing but a code is left, the
/// title falls back to the raw query so a search still happens.
EpisodeQuery parseEpisodeQuery(String raw) {
  var text = raw;
  int? season;
  int? episode;

  RegExpMatch? m = _sxxeyy.firstMatch(text) ?? _nxm.firstMatch(text);
  if (m != null) {
    season = int.parse(m.group(1)!);
    episode = int.parse(m.group(2)!);
    text = text.replaceRange(m.start, m.end, ' ');
  } else {
    m = _seasonWord.firstMatch(text) ?? _sxx.firstMatch(text);
    if (m != null) {
      season = int.parse(m.group(1)!);
      text = text.replaceRange(m.start, m.end, ' ');
      final e = _episodeWord.firstMatch(text);
      if (e != null) {
        episode = int.parse(e.group(1)!);
        text = text.replaceRange(e.start, e.end, ' ');
      }
    }
  }

  final title = text
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\s\-:–,.]+|[\s\-:–,.]+$'), '')
      .trim();
  if (title.isEmpty) return EpisodeQuery(raw.trim());
  return EpisodeQuery(title, season: season, episode: episode);
}
