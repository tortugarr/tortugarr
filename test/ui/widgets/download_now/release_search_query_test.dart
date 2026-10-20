import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/download_now/release_picker_dialog.dart';

void main() {
  test('tv episode searches never get the series start year', () {
    expect(
      releaseSearchQuery('American Horror Story S13E04', mediaType: 'tv', year: 2011),
      'American Horror Story S13E04',
    );
    expect(
      releaseSearchQuery('American Horror Story S13', mediaType: 'tv', year: 2011),
      'American Horror Story S13',
    );
  });

  test('movie searches keep the year', () {
    expect(releaseSearchQuery('Dune', mediaType: 'movie', year: 2021), 'Dune 2021');
  });

  test('no year leaves the query alone', () {
    expect(releaseSearchQuery('Dune', mediaType: 'movie'), 'Dune');
  });
}
