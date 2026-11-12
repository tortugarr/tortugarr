import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/title_badge.dart';

void main() {
  test('known studios and networks get their short mark', () {
    expect(studioMark('Netflix').text, 'N');
    expect(studioMark('Disney+').text, 'D+');
    expect(studioMark('Walt Disney Pictures').text, 'D');
    expect(studioMark('Warner Bros. Pictures').text, 'WB');
    expect(studioMark('Universal Pictures').text, 'U');
    expect(studioMark('HBO').text, 'HBO');
    expect(studioMark('Apple TV+').text, 'tv+');
    expect(studioMark('Columbia Pictures').text, 'S');
  });

  test('unknown names fall back to two initials', () {
    expect(studioMark('Broken Lizard').text, 'BL');
    expect(studioMark('Syncopy').text, 'S');
  });
}
