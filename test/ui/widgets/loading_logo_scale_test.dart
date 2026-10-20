import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/playback/player_loading_overlay.dart';

void main() {
  // 2026-10-21: the full size was too large on the TV; 45 % is the default.
  test('the loading logo is 45 % by default', () {
    expect(loadingLogoScale(null), 0.45);
    expect(loadingLogoScale(100), 1.0);
  });

  test('the loading logo size stays within 25-100 %', () {
    expect(loadingLogoScale(25), 0.25);
    expect(loadingLogoScale(75), 0.75);
    expect(loadingLogoScale(10), 0.25);
    expect(loadingLogoScale(110), 1.0);
  });
}
