import '../models/aggregated_item.dart';
import 'download/bazarr_client.dart';

/// What the "Find subtitles" dialog needs, whichever way it reaches Bazarr:
/// directly with the private build's key ([BazarrSubtitleService]) or
/// through the server's Tortugarr plugin (the public build). [T] is the
/// backend's own way of naming a movie or episode.
abstract class SubtitleBackend<T extends Object> {
  /// The backend's name for [item], or null when Radarr/Sonarr do not
  /// manage it (Bazarr only knows what they know).
  Future<T?> resolve(AggregatedItem item);

  Future<BazarrSubtitleState> state(T target);

  /// Lets Bazarr pick the best match for each missing language; returns
  /// the state afterwards.
  Future<BazarrSubtitleState> searchMissing(T target, Iterable<String> languages);

  /// Every subtitle the providers offer, best match first.
  Future<List<BazarrCandidate>> candidates(T target);

  Future<void> download(T target, BazarrCandidate candidate);
}
