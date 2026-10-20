import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/episode_query.dart';

void main() {
  test('SxxEyy is split out', () {
    final q = parseEpisodeQuery('American Horror Story S13E04');
    expect(q.title, 'American Horror Story');
    expect(q.season, 13);
    expect(q.episode, 4);
  });

  test('lower case season only', () {
    final q = parseEpisodeQuery('the boys s02');
    expect(q.title, 'the boys');
    expect(q.season, 2);
    expect(q.episode, isNull);
  });

  test('season words in English and Norwegian', () {
    expect(parseEpisodeQuery('Wisting sesong 3').season, 3);
    final q = parseEpisodeQuery('Lost season 2 episode 5');
    expect(q.title, 'Lost');
    expect(q.season, 2);
    expect(q.episode, 5);
  });

  test('1x05 style', () {
    final q = parseEpisodeQuery('Friends 1x05');
    expect(q.title, 'Friends');
    expect((q.season, q.episode), (1, 5));
  });

  test('titles without a code are untouched, including ones with numbers', () {
    expect(parseEpisodeQuery('Dune').hasSeason, isFalse);
    expect(parseEpisodeQuery('Blade Runner 2049').title, 'Blade Runner 2049');
    expect(parseEpisodeQuery('Se7en').title, 'Se7en');
    expect(parseEpisodeQuery('Se7en').hasSeason, isFalse);
  });

  test('a code alone still searches the raw text', () {
    expect(parseEpisodeQuery('S01E01').title, 'S01E01');
  });
}
