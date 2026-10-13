import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/playback/player_loading_overlay.dart';

void main() {
  test('the loading logo keeps its size by default', () {
    expect(loadingLogoScale(null), 1.0);
    expect(loadingLogoScale(100), 1.0);
  });

  test('the loading logo size stays within 25-110 %', () {
    expect(loadingLogoScale(25), 0.25);
    expect(loadingLogoScale(75), 0.75);
    expect(loadingLogoScale(110), 1.10);
    expect(loadingLogoScale(10), 0.25);
    expect(loadingLogoScale(200), 1.10);
  });
}
