import '../../preference/preference_constants.dart';
import '../../preference/user_preferences.dart';

/// Tortuga and Harbor are Tortugarr's own look and are on from the start (2026-11-12: an updated
/// phone still opened in Moonfin's theme and rows). Once per install, an app still on Moonfin's
/// defaults moves to them: theme Moonfin (no custom theme) becomes Tortuga with its brass focus,
/// Classic or Modern rows become Harbor. Chosen later, anything else stays.
void applyTortugarrDefaultsOnce(UserPreferences prefs) {
  if (prefs.get(UserPreferences.tgDefaultsApplied)) return;
  if (prefs.get(UserPreferences.customThemeId).isEmpty &&
      prefs.get(UserPreferences.visualTheme) == VisualThemeId.moonfin) {
    prefs.set(UserPreferences.visualTheme, VisualThemeId.tortuga);
    prefs.set(UserPreferences.focusColor, AppTheme.tortugaBrass);
  }
  final rows = prefs.get(UserPreferences.homeRowsStyle);
  if (rows == HomeRowsStyle.v1 || rows == HomeRowsStyle.v2) {
    prefs.set(UserPreferences.homeRowsStyle, HomeRowsStyle.harbor);
  }
  prefs.set(UserPreferences.tgDefaultsApplied, true);
}
