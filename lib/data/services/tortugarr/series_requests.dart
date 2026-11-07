import '../seerr/seerr_api_models.dart';

/// Series downloaded in the app, shown in Seerr › Requests next to the movies.
///
/// 2026-11-07: a movie downloaded in the app files a Seerr request, so it
/// shows in Requests. A series does not, on purpose (Seerr requests whole
/// seasons; one picked episode became every season), so series never showed.
/// The plugin keeps its own list (`GET /Tortugarr/v1/SeriesRequests`); each
/// row becomes a read-only request card. Its id is negative, so it never
/// clashes with a Seerr request and gets no approve/decline buttons.

/// Which kind of title the Requests list shows.
enum SeerrRequestKind { all, movies, series }

/// True for a card made from the plugin's list, not a Seerr request.
bool isPluginSeriesRequest(SeerrRequest r) => r.id < 0;

/// The plugin's rows as request cards. A row without a TMDB id is left out:
/// the card could not open the series.
List<SeerrRequest> seriesRequestsFromPlugin(List<Map<String, dynamic>> rows) {
  final users = <String>[];
  final out = <SeerrRequest>[];
  for (final row in rows) {
    final tvdbId = (row['tvdbId'] as num?)?.toInt();
    final tmdbId = (row['tmdbId'] as num?)?.toInt();
    if (tvdbId == null || tvdbId <= 0 || tmdbId == null || tmdbId <= 0) {
      continue;
    }
    final user = '${row['userId'] ?? ''}';
    if (!users.contains(user)) users.add(user);
    final downloading = row['downloading'] == true;
    final at = row['at'] as String?;
    final title = row['title'] as String?;
    out.add(SeerrRequest(
      id: -(tvdbId * 1000 + users.indexOf(user) % 1000 + 1),
      status: SeerrRequest.statusApproved,
      createdAt: at,
      updatedAt: at,
      type: 'tv',
      requestedBy: SeerrUser(id: -1, displayName: row['userName'] as String?),
      seasons: [
        for (final s in (row['seasons'] as List? ?? const []))
          if (s is num)
            SeerrSeasonRequest(
              id: 0,
              seasonNumber: s.toInt(),
              status: SeerrRequest.statusApproved,
            ),
      ],
      media: SeerrMedia(
        id: 0,
        mediaType: 'tv',
        tmdbId: tmdbId,
        tvdbId: tvdbId,
        name: title == null || title.isEmpty ? null : title,
        // Downloading: "Processing" (an entry in the download list is what
        // makes the card say so; it has no size, so it draws no bar of its
        // own). Done: available. The live bar comes from the plugin's queue.
        status: downloading ? 3 : 5,
        downloadStatus: downloading ? const [SeerrDownloadingItem()] : null,
      ),
    ));
  }
  return out;
}

/// The plugin's series cards that pass a status filter.
List<SeerrRequest> seriesForStatus(List<SeerrRequest> series, String? filter) =>
    switch (filter) {
      null || 'approved' => series,
      'processing' => series.where((r) => r.media?.status == 3).toList(),
      'available' => series.where((r) => r.media?.status == 5).toList(),
      _ => const [],
    };

/// Seerr's requests and the plugin's series cards in one list, newest first.
///
/// While Seerr has more pages, only series newer than the oldest request
/// loaded so far join, so a series never jumps above cards loaded later.
List<SeerrRequest> mergeSeriesRequests({
  required List<SeerrRequest> seerr,
  required List<SeerrRequest> series,
  required bool seerrHasMore,
  required String sort,
  required SeerrRequestKind kind,
}) {
  DateTime when(SeerrRequest r) {
    final text = sort == 'modified' ? (r.updatedAt ?? r.createdAt) : r.createdAt;
    return (text == null ? null : DateTime.tryParse(text)) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  final oldest = seerr.isEmpty
      ? null
      : seerr.map(when).reduce((a, b) => a.isBefore(b) ? a : b);
  final joining = series.where(
    (r) => !seerrHasMore || oldest == null || !when(r).isBefore(oldest),
  );
  final merged = [...seerr, ...joining];
  // Seerr sorts by the same date, so this only places the series cards.
  merged.sort((a, b) => when(b).compareTo(when(a)));
  return switch (kind) {
    SeerrRequestKind.all => merged,
    SeerrRequestKind.movies => merged.where((r) => r.type == 'movie').toList(),
    SeerrRequestKind.series => merged.where((r) => r.type == 'tv').toList(),
  };
}
