import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/subtitle_track_logic.dart';

Map<String, dynamic> sub(int index, String? language,
        {String? title, bool forced = false}) =>
    {
      'Index': index,
      'Type': 'Subtitle',
      'Language': ?language,
      'DisplayTitle': ?title,
      'IsForced': forced,
    };

List<int?> indexes(List<Map<String, dynamic>> streams) =>
    streams.map((s) => s['Index'] as int?).toList();

void main() {
  group('isMenuLanguageSubtitleStream', () {
    test('keeps Norwegian and English codes in any case by default', () {
      for (final code in ['nor', 'NOB', 'nno', 'no', 'nb', 'nn', 'eng', 'EN']) {
        expect(isMenuLanguageSubtitleStream(sub(1, code)), isTrue, reason: code);
      }
    });

    test('drops other languages by default', () {
      for (final code in ['spa', 'ita', 'jpn', 'kor', 'swe', 'dan', 'ger', 'fre']) {
        expect(isMenuLanguageSubtitleStream(sub(1, code)), isFalse, reason: code);
      }
    });

    test('keeps tracks with no or unknown language', () {
      expect(isMenuLanguageSubtitleStream(sub(1, null)), isTrue);
      expect(isMenuLanguageSubtitleStream(sub(1, '')), isTrue);
      expect(isMenuLanguageSubtitleStream(sub(1, 'und', title: 'Und - SUBRIP')), isTrue);
    });

    test('reads full language names', () {
      expect(isMenuLanguageSubtitleStream(sub(1, 'Norwegian')), isTrue);
      expect(isMenuLanguageSubtitleStream(sub(1, 'English')), isTrue);
      expect(isMenuLanguageSubtitleStream(sub(1, 'Spanish')), isFalse);
      expect(
        isMenuLanguageSubtitleStream(sub(1, 'Spanish'), languages: {'spa'}),
        isTrue,
      );
    });

    test('a custom language set decides what is kept', () {
      const picked = {'swe', 'ger'};
      expect(isMenuLanguageSubtitleStream(sub(1, 'swe'), languages: picked), isTrue);
      expect(isMenuLanguageSubtitleStream(sub(1, 'deu'), languages: picked), isTrue);
      expect(isMenuLanguageSubtitleStream(sub(1, 'de'), languages: picked), isTrue);
      expect(isMenuLanguageSubtitleStream(sub(1, 'eng'), languages: picked), isFalse);
      expect(isMenuLanguageSubtitleStream(sub(1, 'nor'), languages: picked), isFalse);
    });

    test('a forced track is filtered like any other', () {
      expect(isMenuLanguageSubtitleStream(sub(1, 'ita', forced: true)), isFalse);
      expect(isMenuLanguageSubtitleStream(sub(1, 'eng', forced: true)), isTrue);
    });
  });

  group('filterSubtitleMenuStreams', () {
    final streams = [
      sub(2, 'eng'),
      sub(3, 'spa'),
      sub(4, 'ita', forced: true),
      sub(5, 'nor'),
      sub(6, 'und'),
      sub(7, 'jpn'),
    ];

    test('keeps only Norwegian, English and unknown by default', () {
      expect(indexes(filterSubtitleMenuStreams(streams, showAll: false)), [2, 5, 6]);
    });

    test('uses the picked languages', () {
      expect(
        indexes(filterSubtitleMenuStreams(streams, showAll: false, languages: {'ita', 'spa'})),
        [3, 4, 6],
      );
    });

    test('keeps the order of the input', () {
      final reversed = streams.reversed.toList();
      expect(indexes(filterSubtitleMenuStreams(reversed, showAll: false)), [6, 5, 2]);
    });

    test('showAll returns every stream', () {
      expect(filterSubtitleMenuStreams(streams, showAll: true), same(streams));
    });

    test('a file with only other languages gives an empty menu', () {
      final foreign = [sub(1, 'spa'), sub(2, 'ita')];
      expect(filterSubtitleMenuStreams(foreign, showAll: false), isEmpty);
    });

    test('empty input stays empty', () {
      expect(filterSubtitleMenuStreams(const [], showAll: false), isEmpty);
    });

    test('a broken stream map falls back to every stream', () {
      final broken = [
        {'Index': 1, 'Language': 42},
        sub(2, 'spa'),
      ];
      expect(filterSubtitleMenuStreams(broken, showAll: false), same(broken));
    });
  });

  group('shouldAutoDisableSubtitle', () {
    final streams = [
      sub(1, 'ita', forced: true),
      sub(2, 'eng'),
      sub(3, 'nor'),
    ];

    test('switches off an auto-selected forced Italian track', () {
      expect(shouldAutoDisableSubtitle(streams, 1, showAll: false), isTrue);
    });

    test('leaves a picked-language track on', () {
      expect(shouldAutoDisableSubtitle(streams, 2, showAll: false), isFalse);
      expect(shouldAutoDisableSubtitle(streams, 3, showAll: false), isFalse);
    });

    test('does nothing when subtitles are off or unknown', () {
      expect(shouldAutoDisableSubtitle(streams, -1, showAll: false), isFalse);
      expect(shouldAutoDisableSubtitle(streams, null, showAll: false), isFalse);
      expect(shouldAutoDisableSubtitle(streams, 99, showAll: false), isFalse);
    });

    test('does nothing when every language is shown', () {
      expect(shouldAutoDisableSubtitle(streams, 1, showAll: true), isFalse);
    });

    test('respects a custom language set', () {
      expect(
        shouldAutoDisableSubtitle(streams, 1, showAll: false, languages: {'ita'}),
        isFalse,
      );
      expect(
        shouldAutoDisableSubtitle(streams, 2, showAll: false, languages: {'ita'}),
        isTrue,
      );
    });
  });

  test('default picks are Norwegian and English', () {
    expect(defaultSubtitleMenuLanguageCodes, {'nor', 'eng'});
    expect(subtitleMenuLanguages.map((l) => l.code), contains('pol'));
    expect(subtitleMenuLanguages.length, 12);
  });
}
