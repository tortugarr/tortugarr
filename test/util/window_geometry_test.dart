import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/window_geometry.dart';

void main() {
  // A 3440x1440 ultrawide with a 40px taskbar along the bottom.
  const ultrawide = Rect.fromLTWH(0, 0, 3440, 1400);

  // What Windows reports for a window maximized on that screen: the frame
  // reaches 8px past every edge, so saving it as the windowed geometry brings
  // the next launch up with its title bar above the top of the screen.
  const savedWhileMaximized = Rect.fromLTWH(-8, -8, 3456, 1416);

  group('fitBoundsToWorkAreas', () {
    test('leaves bounds that already sit on a screen alone', () {
      const windowed = Rect.fromLTWH(400, 200, 1600, 900);

      expect(fitBoundsToWorkAreas(windowed, const [ultrawide]), windowed);
    });

    test('pulls geometry saved while maximized back onto the screen', () {
      expect(
        fitBoundsToWorkAreas(savedWhileMaximized, const [ultrawide]),
        ultrawide,
      );
    });

    test('keeps a window on the second screen it was closed on', () {
      const secondary = Rect.fromLTWH(3440, 0, 1080, 1880);
      const onSecondary = Rect.fromLTWH(3600, 300, 800, 1000);

      expect(
        fitBoundsToWorkAreas(onSecondary, const [ultrawide, secondary]),
        onSecondary,
      );
    });

    test('rescues a window left on a display that is now gone', () {
      const onUnpluggedScreen = Rect.fromLTWH(3600, 300, 800, 1000);

      final fitted = fitBoundsToWorkAreas(onUnpluggedScreen, const [ultrawide]);

      expect(fitted.size, onUnpluggedScreen.size);
      expect(ultrawide.contains(fitted.topLeft), isTrue);
      expect(fitted.right, lessThanOrEqualTo(ultrawide.right));
    });

    test('shrinks a window too large for the screen that is left', () {
      const oversized = Rect.fromLTWH(0, 0, 3440, 1400);
      const smallScreen = Rect.fromLTWH(0, 0, 1920, 1040);

      expect(fitBoundsToWorkAreas(oversized, const [smallScreen]), smallScreen);
    });

    test('leaves bounds untouched when no display can be read', () {
      expect(
        fitBoundsToWorkAreas(savedWhileMaximized, const []),
        savedWhileMaximized,
      );
    });
  });
}
