import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/tortugarr/smart_tube.dart';

void main() {
  test('search goes to SmartTube as youtube://search with the words encoded', () {
    expect(SmartTube.searchUri(' dune part two '), 'youtube://search?query=dune%20part%20two');
  });

  test('only YouTube trailers go to SmartTube', () {
    expect(SmartTube.watchUri(videoId: 'abc'), 'https://www.youtube.com/watch?v=abc');
    expect(SmartTube.watchUri(url: 'https://www.youtube.com/watch?v=x'), 'https://www.youtube.com/watch?v=x');
    expect(SmartTube.watchUri(url: 'https://youtu.be/x'), 'https://youtu.be/x');
    expect(SmartTube.watchUri(url: 'https://vimeo.com/1'), isNull);
    expect(SmartTube.watchUri(), isNull);
  });

  test('only SmartTube packages are ever opened (never the YouTube app)', () {
    expect(SmartTube.packages, isNot(contains('com.google.android.youtube.tv')));
    expect(SmartTube.packages.first, 'org.smarttube.beta');
  });
}
