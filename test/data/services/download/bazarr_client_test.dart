import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/download/bazarr_client.dart';

void main() {
  group('id mapping', () {
    test('radarr id comes from the movie with the same TMDB id', () {
      final movies = [
        {'id': 3, 'tmdbId': 11},
        {'id': 7, 'tmdbId': 42},
      ];
      expect(BazarrSubtitleService.radarrIdFor(movies, 42), 7);
      expect(BazarrSubtitleService.radarrIdFor(movies, 99), isNull);
      expect(BazarrSubtitleService.radarrIdFor(null, 42), isNull);
    });

    test('sonarr series id comes from the matching TVDB id', () {
      final series = [
        {'id': 5, 'tvdbId': 100},
        {'id': 6, 'tvdbId': 200},
      ];
      expect(BazarrSubtitleService.sonarrSeriesIdFor(series, 200), 6);
      expect(BazarrSubtitleService.sonarrSeriesIdFor(series, 300), isNull);
    });

    test('sonarr episode id needs both season and episode to match', () {
      final episodes = [
        {'id': 1, 'seasonNumber': 3, 'episodeNumber': 1},
        {'id': 2, 'seasonNumber': 3, 'episodeNumber': 4},
        {'id': 9, 'seasonNumber': 2, 'episodeNumber': 4},
      ];
      expect(BazarrSubtitleService.sonarrEpisodeIdFor(episodes, 3, 4), 2);
      expect(BazarrSubtitleService.sonarrEpisodeIdFor(episodes, 2, 4), 9);
      expect(BazarrSubtitleService.sonarrEpisodeIdFor(episodes, 4, 4), isNull);
      expect(BazarrSubtitleService.sonarrEpisodeIdFor('oops', 3, 4), isNull);
    });
  });

  group('parseState', () {
    test('reads which languages are there and which are missing', () {
      final state = BazarrSubtitleService.parseState({
        'data': [
          {
            'subtitles': [
              {'code2': 'en', 'forced': false, 'hi': false, 'path': '/x.en.srt'},
              // Embedded tracks count as present too.
              {'code2': 'it', 'forced': false, 'hi': false, 'path': null},
              // A forced (signs only) track is not a real subtitle.
              {'code2': 'no', 'forced': true, 'hi': false, 'path': '/x.no.forced.srt'},
            ],
            'missing_subtitles': [
              {'code2': 'no', 'forced': false, 'hi': false},
            ],
          },
        ],
      })!;
      expect(state.have, {'en', 'it'});
      expect(state.missing, {'no'});
    });

    test('returns null when Bazarr does not know the title', () {
      expect(BazarrSubtitleService.parseState({'data': []}), isNull);
      expect(BazarrSubtitleService.parseState('Movie not found'), isNull);
    });
  });

  group('parseCandidates', () {
    test('sorts by score and keeps what the download call needs', () {
      final list = BazarrSubtitleService.parseCandidates({
        'data': [
          {
            'language': 'no',
            'provider': 'opensubtitlescom',
            'score': 68,
            'release_info': ['Dead.Mans.Wire.2025.1080p.BluRay.x264-PiGNUS'],
            'subtitle': 'abc',
            'hearing_impaired': 'False',
            'forced': 'False',
            'original_format': 'False',
          },
          {
            'language': 'en',
            'provider': 'opensubtitlescom',
            'score': 91,
            'release_info': [],
            'subtitle': 'def',
            'hearing_impaired': 'True',
            'forced': 'False',
            'original_format': 'False',
          },
          // No subtitle id: cannot be downloaded, so it is dropped.
          {'language': 'en', 'provider': 'yifysubtitles', 'score': 99},
        ],
      });
      expect(list.map((c) => c.subtitleId), ['def', 'abc']);
      expect(list.first.score, 91);
      expect(list.first.release, '');
      expect(list.first.hearingImpaired, 'True');
      expect(list.last.release, 'Dead.Mans.Wire.2025.1080p.BluRay.x264-PiGNUS');
      expect(list.last.language, 'no');
    });

    test('an unexpected body gives an empty list', () {
      expect(BazarrSubtitleService.parseCandidates('boom'), isEmpty);
      expect(BazarrSubtitleService.parseCandidates({'data': null}), isEmpty);
    });
  });
}
