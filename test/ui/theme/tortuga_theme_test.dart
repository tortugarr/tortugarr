import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/preference/preference_constants.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/theme/app_theme.dart' as theming;
import 'package:moonfin/ui/theme/app_theme_controller.dart';
import 'package:moonfin_design/moonfin_design.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<UserPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'pref_last_server_id': 'srv1',
    'pref_last_user_id': 'usr1',
  });
  final store = PreferenceStore();
  await store.init();
  return UserPreferences(store);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Tortuga is a built-in theme, reachable from the theme picker id', () {
    expect(ThemeRegistry.builtInIds, contains(ThemeRegistry.tortugaId));
    expect(ThemeRegistry.availableThemes[ThemeRegistry.tortugaId]?.displayName, 'Tortuga');
    expect(AppThemeController.builtInThemeIdFor(VisualThemeId.tortuga), ThemeRegistry.tortugaId);
  });

  test('choosing Tortuga makes it active and gives the brass focus colour', () async {
    final prefs = await _prefs();
    final controller = AppThemeController.fromPreferences(prefs);
    // By registry id, the way the Appearance > Theme picker calls it.
    await controller.applyThemeById(prefs, ThemeRegistry.tortugaId);
    expect(controller.activeSpec.id, ThemeRegistry.tortugaId);
    expect(prefs.get(UserPreferences.visualTheme), VisualThemeId.tortuga);
    expect(prefs.get(UserPreferences.focusColor), AppTheme.tortugaBrass);
  });

  test('headings use the pirate font, body text and small titles do not', () {
    final theme = theming.AppTheme.buildTheme(ThemeRegistry.resolveById(ThemeRegistry.tortugaId));
    final t = theme.textTheme;
    for (final s in [t.displayLarge, t.headlineMedium, t.headlineSmall, t.titleLarge]) {
      expect(s?.fontFamily, 'TortugaHeading');
    }
    for (final s in [t.titleMedium, t.titleSmall, t.bodyLarge, t.bodyMedium, t.labelLarge]) {
      expect(s?.fontFamily, isNot('TortugaHeading'));
    }
  });

  test('themes without a heading font keep one font everywhere', () {
    final t = theming.AppTheme.buildTheme(ThemeRegistry.resolveById(ThemeRegistry.moonfinId)).textTheme;
    expect(t.titleLarge?.fontFamily, t.bodyMedium?.fontFamily);
  });

  test('headingFontFamily survives JSON (Theme Store and server themes)', () {
    final spec = ThemeRegistry.resolveById(ThemeRegistry.tortugaId);
    final json = spec.toJson();
    expect(json['headingFontFamily'], 'TortugaHeading');
    expect(ThemeSpec.fromJson(json).headingFontFamily, 'TortugaHeading');
    expect(ThemeSpec.fromJson({...json}..remove('headingFontFamily')).headingFontFamily, isNull);
  });

  test('OLED mode keeps the heading font', () {
    final spec = ThemeRegistry.resolveById(ThemeRegistry.tortugaId);
    expect(spec.withColors(spec.colors).headingFontFamily, 'TortugaHeading');
  });
}
