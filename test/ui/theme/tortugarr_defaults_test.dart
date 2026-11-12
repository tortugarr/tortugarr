import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/preference/preference_constants.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/theme/tortugarr_defaults.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<UserPreferences> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  final store = PreferenceStore();
  await store.init();
  return UserPreferences(store);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a new install starts in Tortuga with Harbor', () async {
    final prefs = await _prefs({});
    expect(prefs.get(UserPreferences.visualTheme), VisualThemeId.tortuga);
    expect(prefs.get(UserPreferences.focusColor), AppTheme.tortugaBrass);
    expect(prefs.get(UserPreferences.homeRowsStyle), HomeRowsStyle.harbor);
  });

  test('an update still on Moonfin moves to Tortuga and Harbor once', () async {
    final prefs = await _prefs({});
    await prefs.set(UserPreferences.visualTheme, VisualThemeId.moonfin);
    await prefs.set(UserPreferences.homeRowsStyle, HomeRowsStyle.v1);
    applyTortugarrDefaultsOnce(prefs);
    expect(prefs.get(UserPreferences.visualTheme), VisualThemeId.tortuga);
    expect(prefs.get(UserPreferences.homeRowsStyle), HomeRowsStyle.harbor);

    // Chosen afterwards, it stays.
    await prefs.set(UserPreferences.visualTheme, VisualThemeId.moonfin);
    await prefs.set(UserPreferences.homeRowsStyle, HomeRowsStyle.v2);
    applyTortugarrDefaultsOnce(prefs);
    expect(prefs.get(UserPreferences.visualTheme), VisualThemeId.moonfin);
    expect(prefs.get(UserPreferences.homeRowsStyle), HomeRowsStyle.v2);
  });

  test('another theme picked before the update is kept', () async {
    final prefs = await _prefs({});
    await prefs.set(UserPreferences.visualTheme, VisualThemeId.neonPulse);
    applyTortugarrDefaultsOnce(prefs);
    expect(prefs.get(UserPreferences.visualTheme), VisualThemeId.neonPulse);
  });
}
