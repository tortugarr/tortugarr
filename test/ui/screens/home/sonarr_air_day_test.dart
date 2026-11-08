import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moonfin/ui/screens/home/home_view_model.dart';
import 'package:moonfin/util/app_l10n.dart';

// Tortugarr shows the date in the app's language (appShortDate) instead of
// Moonfin's English "Oct. 24th"; what is tested is that it is the local day.

void main() {
  setUpAll(() => initializeDateFormatting());

  group('a Sonarr episode shows the local day it airs', () {
    test('a late evening airing is that evening, not the next UTC day', () {
      final airDateUtc = DateTime(2026, 10, 24, 21).toUtc();

      expect(HomeViewModel.sonarrAirDay(airDateUtc), appShortDate(DateTime(2026, 10, 24)));
    });

    test('an airing just after local midnight is the next day', () {
      final airDateUtc = DateTime(2026, 10, 25, 0, 30).toUtc();

      expect(HomeViewModel.sonarrAirDay(airDateUtc), appShortDate(DateTime(2026, 10, 25)));
    });
  });
}
