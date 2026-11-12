import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../preference/user_preferences.dart';
import '../../widgets/adaptive/adaptive_list_section.dart';
import '../../widgets/focus/request_initial_focus.dart';
import '../../widgets/settings/clean_settings_typography.dart';
import '../../widgets/settings/preference_tiles.dart';
import 'settings_app_bar.dart';

/// Settings > Appearance > Home Screen > Poster badges: BB / MB on films,
/// the network logo on series, how they look, and whether mockbusters show.
class PosterBadgesSettingsScreen extends StatelessWidget {
  const PosterBadgesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = {
      'D9B44A': l10n.tgColorBrass,
      'F2C94C': l10n.tgColorGold,
      'E0703A': l10n.tgColorOrange,
      'C0452F': l10n.tgColorRed,
      '4FA3D9': l10n.tgColorBlue,
      '5FBF77': l10n.tgColorGreen,
      'FFFFFF': l10n.tgColorWhite,
      '000000': l10n.tgColorBlack,
    };
    final corners = {
      'topLeft': l10n.tgCornerTopLeft,
      'topRight': l10n.tgCornerTopRight,
      'bottomLeft': l10n.tgCornerBottomLeft,
      'bottomRight': l10n.tgCornerBottomRight,
    };
    final sizes = {
      'small': l10n.tgSizeSmall,
      'medium': l10n.tgSizeMedium,
      'large': l10n.tgSizeLarge,
    };
    String pct(int v) => '$v %';
    return RequestInitialFocus(
      child: withCleanSettingsTypography(
        context,
        Scaffold(
          appBar: buildSettingsAppBar(context, Text(l10n.tgPosterBadges)),
          body: ListView(
            children: [
              adaptiveListSection(
                children: [
                  SwitchPreferenceTile(
                    preference: UserPreferences.tgBadgesEnabled,
                    title: l10n.tgPosterBadges,
                    subtitle: l10n.tgPosterBadgesSubtitle,
                    icon: Icons.local_offer_outlined,
                  ),
                  SwitchPreferenceTile(
                    preference: UserPreferences.tgShowMockbusters,
                    title: l10n.tgShowMockbusters,
                    subtitle: l10n.tgShowMockbustersSubtitle,
                    icon: Icons.visibility_outlined,
                  ),
                  StringPickerPreferenceTile(
                    preference: UserPreferences.tgBbColor,
                    title: l10n.tgBbColor,
                    icon: Icons.palette_outlined,
                    options: colors,
                  ),
                  StringPickerPreferenceTile(
                    preference: UserPreferences.tgMbColor,
                    title: l10n.tgMbColor,
                    icon: Icons.palette_outlined,
                    options: colors,
                  ),
                  SliderPreferenceTile(
                    preference: UserPreferences.tgBadgeOpacity,
                    title: l10n.tgBadgeOpacity,
                    icon: Icons.opacity,
                    min: 20,
                    max: 100,
                    divisions: 8,
                    labelOf: pct,
                  ),
                  StringPickerPreferenceTile(
                    preference: UserPreferences.tgBadgeCorner,
                    title: l10n.tgBadgeCorner,
                    icon: Icons.crop_free,
                    options: corners,
                  ),
                  StringPickerPreferenceTile(
                    preference: UserPreferences.tgBadgeSize,
                    title: l10n.tgBadgeSize,
                    icon: Icons.format_size,
                    options: sizes,
                  ),
                ],
              ),
              adaptiveListSection(
                children: [
                  SwitchPreferenceTile(
                    preference: UserPreferences.tgNetworkLogos,
                    title: l10n.tgNetworkLogos,
                    subtitle: l10n.tgNetworkLogosSubtitle,
                    icon: Icons.tv,
                  ),
                  StringPickerPreferenceTile(
                    preference: UserPreferences.tgLogoStyle,
                    title: l10n.tgLogoStyle,
                    icon: Icons.short_text,
                    options: {
                      'logo': l10n.tgLogoStyleFull,
                      'icon': l10n.tgLogoStyleMark,
                    },
                  ),
                  StringPickerPreferenceTile(
                    preference: UserPreferences.tgNetworkBoxColor,
                    title: l10n.tgNetworkBoxColor,
                    icon: Icons.palette_outlined,
                    options: colors,
                  ),
                  SliderPreferenceTile(
                    preference: UserPreferences.tgNetworkOpacity,
                    title: l10n.tgNetworkOpacity,
                    icon: Icons.opacity,
                    min: 0,
                    max: 100,
                    divisions: 10,
                    labelOf: pct,
                  ),
                  StringPickerPreferenceTile(
                    preference: UserPreferences.tgNetworkCorner,
                    title: l10n.tgNetworkCorner,
                    icon: Icons.crop_free,
                    options: corners,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
