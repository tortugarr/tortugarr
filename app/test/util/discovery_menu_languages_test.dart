import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/subtitle_track_logic.dart';

void main() {
  test('the discovery list offers the non-European languages too', () {
    final codes = discoveryMenuLanguages.map((l) => l.code).toSet();
    expect(codes, containsAll(['jpn', 'kor', 'chi', 'yue', 'hin', 'tha']));
    // The subtitle list is unchanged and stays the first part.
    expect(discoveryMenuLanguages.take(subtitleMenuLanguages.length).map((l) => l.code),
        subtitleMenuLanguages.map((l) => l.code));
  });

  test('picking Japanese or Cantonese keeps their TMDB codes', () {
    expect(tmdbCodesFor({'jpn'}, languages: discoveryMenuLanguages), {'ja'});
    expect(tmdbCodesFor({'yue'}, languages: discoveryMenuLanguages), {'cn'});
    expect(tmdbCodesFor({'chi'}, languages: discoveryMenuLanguages), {'zh'});
  });

  test('stored picks are unique per language', () {
    final codes = discoveryMenuLanguages.map((l) => l.code).toList();
    expect(codes.toSet().length, codes.length);
  });

  test('the defaults still keep the six household languages only', () {
    expect(tmdbCodesFor(defaultDiscoveryLanguageCodes, languages: discoveryMenuLanguages),
        {'en', 'no', 'nb', 'nn', 'sv', 'da', 'de', 'fr'});
  });
}
