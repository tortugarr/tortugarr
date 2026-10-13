import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/home/home_view_model.dart';

void main() {
  // A row restored from the cache is on screen before any request answers, so
  // a section that fails on a flaky link has to leave it alone. Otherwise the
  // row appears, clears when the request gives up, and comes back on the next
  // load.
  group('a section whose load threw', () {
    bool keeps({
      bool preserveExisting = false,
      bool hydratedFromCache = false,
      bool hasVisibleRow = true,
    }) => HomeViewModel.keepsRowsOnFailure(
      preserveExisting: preserveExisting,
      hydratedFromCache: hydratedFromCache,
      hasVisibleRow: hasVisibleRow,
    );

    test('keeps rows the cache put on screen during a first load', () {
      expect(keeps(hydratedFromCache: true), isTrue);
    });

    test('keeps rows a refresh already had', () {
      expect(keeps(preserveExisting: true), isTrue);
    });

    test('clears when a cold load has nothing to keep', () {
      expect(keeps(), isFalse);
    });

    test('clears a placeholder rather than leaving it spinning', () {
      expect(keeps(hydratedFromCache: true, hasVisibleRow: false), isFalse);
      expect(keeps(preserveExisting: true, hasVisibleRow: false), isFalse);
    });
  });
}
