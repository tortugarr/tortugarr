import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/title_badge.dart';

void main() {
  test('streaming services get their real app icon from TMDB', () {
    for (final n in ['Netflix', 'Disney+', 'Walt Disney Pictures', 'Apple TV+', 'Apple Original Films', 'Amazon MGM Studios', 'Prime Video', 'HBO', 'Max', 'SkyShowtime']) {
      expect(providerIconUrl(n), startsWith('https://image.tmdb.org/t/p/w92/'), reason: n);
    }
  });

  test('studios without an app keep their own logo (no icon)', () {
    for (final n in ['Universal Pictures', 'Warner Bros. Pictures', 'Broken Lizard', 'Maximum Effort']) {
      expect(providerIconUrl(n), isNull, reason: n);
    }
  });

  test('the big studios and networks reuse the white logos of the Networks / Studios rows', () {
    for (final n in ['Netflix', 'HBO', 'Universal Pictures', 'Warner Bros. Pictures', 'Columbia Pictures', 'Walt Disney Pictures', 'Apple Original Films', 'A24']) {
      final url = curatedLogoUrl(n, width: 300);
      expect(url, isNotNull, reason: n);
      expect(url, contains('/w300_filter(duotone'), reason: n);
    }
    expect(curatedLogoUrl('Broken Lizard'), isNull);
  });
}
