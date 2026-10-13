import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/preference/preference_constants.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/screensaver/screensaver_view.dart';

void main() {
  test('screensaver sound is off by default', () {
    expect(UserPreferences.screensaverAudio.defaultValue, isFalse);
  });

  test('preview sound is on by default', () {
    expect(UserPreferences.previewAudioEnabled.defaultValue, isTrue);
  });

  test('mode is a single choice between video and logo', () {
    expect(ScreensaverMode.values, [ScreensaverMode.library, ScreensaverMode.logo]);
    expect(UserPreferences.screensaverMode.defaultValue, ScreensaverMode.library);
  });

  test('the logo defaults to the Tortugarr badge, and every choice has its own asset', () {
    expect(UserPreferences.screensaverLogoImage.defaultValue, ScreensaverLogoImage.badge);
    final assets = ScreensaverLogoImage.values.map((v) => screensaverLogoAsset(v).asset).toSet();
    expect(assets.length, ScreensaverLogoImage.values.length);
    expect(assets.every((a) => a.startsWith('assets/images/screensaver_')), isTrue);
  });
}
