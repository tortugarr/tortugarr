import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/playback/player_loading_overlay.dart';

void main() {
  // 2026-10-21: full size on the TV, 40 % on a phone, until one is picked.
  test('the loading logo default depends on the device', () {
    expect(loadingLogoScale(null, tv: true), 1.0);
    expect(loadingLogoScale(0, tv: true), 1.0);
    expect(loadingLogoScale(null, tv: false), 0.40);
    expect(loadingLogoScale(0, tv: false), 0.40);
  });

  test('a picked size stays within 25-100 %', () {
    expect(loadingLogoScale(45, tv: true), 0.45);
    expect(loadingLogoScale(75, tv: false), 0.75);
    expect(loadingLogoScale(10, tv: false), 0.25);
    expect(loadingLogoScale(110, tv: true), 1.0);
  });
}
