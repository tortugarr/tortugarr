part of '../settings_side_panel.dart';

class _GeneralScreen extends StatefulWidget {
  const _GeneralScreen();

  @override
  State<_GeneralScreen> createState() => _GeneralScreenState();
}

class _GeneralScreenState extends State<_GeneralScreen> {
  final _generalScope = FocusScopeNode(
    debugLabel: 'GeneralSettingsScope',
    traversalEdgeBehavior: TraversalEdgeBehavior.stop,
  );

  @override
  void dispose() {
    _generalScope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomPad =
        (PlatformDetection.isTV ? 96.0 : 24.0) +
        MediaQuery.paddingOf(context).bottom;

    final showSiriSensitivity =
        GamepadNavigationScope.isConfigurable && PlatformDetection.isAppleTV;
    final showInput =
        PlatformDetection.isTV ||
        showSiriSensitivity ||
        PlatformDetection.useDesktopUi;

    return Scaffold(
      appBar: buildSettingsAppBar(context, Text(l10n.general)),
      body: FocusScope(
        node: _generalScope,
        autofocus: true,
        child: ListView(
          padding: EdgeInsets.only(bottom: bottomPad),
          children: [
            // Interface language lives under Settings > Language.
            _SectionHeader(l10n.clock),
            adaptiveListSection(
              children: [
                EnumPreferenceTile<ClockBehavior>(
                  preference: UserPreferences.clockBehavior,
                  title: l10n.clockDisplay,
                  icon: Icons.access_time,
                  labelOf: (v) => switch (v) {
                    ClockBehavior.always => l10n.always,
                    ClockBehavior.inMenus => l10n.inMenus,
                    ClockBehavior.never => l10n.never,
                  },
                ),
                SwitchPreferenceTile(
                  preference: UserPreferences.use24HourClock,
                  title: l10n.settingsTwentyFourHourClock,
                  subtitle: l10n.settingsTwentyFourHourClockSubtitle,
                  icon: Icons.schedule,
                ),
              ],
            ),
            if (showInput) ...[
              _SectionHeader(l10n.settingsInputSection),
              adaptiveListSection(
                children: [
                  if (PlatformDetection.isTV)
                    SwitchPreferenceTile(
                      preference: UserPreferences.preferSystemImeKeyboard,
                      title: l10n.keyboardPreferSystemIme,
                      subtitle: l10n.keyboardPreferSystemImeDescription,
                      icon: Icons.keyboard_alt_outlined,
                    ),
                  if (showSiriSensitivity)
                    EnumPreferenceTile<SiriRemoteSwipeSensitivity>(
                      preference: UserPreferences.siriRemoteSwipeSensitivity,
                      title: l10n.siriRemoteSwipeSensitivity,
                      description: l10n.siriRemoteSwipeSensitivityDescription,
                      icon: Icons.swipe,
                      labelOf: (v) => switch (v) {
                        SiriRemoteSwipeSensitivity.low => l10n.settingsLow,
                        SiriRemoteSwipeSensitivity.medium => l10n.medium,
                        SiriRemoteSwipeSensitivity.high => l10n.settingsHigh,
                      },
                    ),
                  if (PlatformDetection.useDesktopUi)
                    SliderPreferenceTile(
                      preference: UserPreferences.desktopScrollSensitivity,
                      title: l10n.scrollSensitivity,
                      description: l10n.scrollSensitivitySubtitle,
                      icon: Icons.mouse,
                      min: 50,
                      max: 300,
                      divisions: 25,
                      labelOf: (v) => '${(v / 100).toStringAsFixed(1)}x',
                      onChangeEnd: _pushPersonalizationSync,
                    ),
                ],
              ),
            ],
            if (!PlatformDetection.isWeb) ...[
              _SectionHeader(l10n.behavior),
              adaptiveListSection(
                children: [
                  SwitchPreferenceTile(
                    preference: UserPreferences.confirmExit,
                    title: l10n.confirmExit,
                    subtitle: l10n.showConfirmationBeforeExiting,
                    icon: Icons.exit_to_app,
                  ),
                ],
              ),
            ],
            if (PlatformDetection.isAndroid) ...[
              _SectionHeader(l10n.performanceMode),
              adaptiveListSection(
                children: [
                  EnumPreferenceTile<DevicePerformanceMode>(
                    preference: UserPreferences.performanceMode,
                    title: l10n.performanceMode,
                    description: l10n.performanceModeSubtitle,
                    icon: Icons.speed_outlined,
                    labelOf: (v) => switch (v) {
                      DevicePerformanceMode.auto => l10n.performanceModeAuto,
                      DevicePerformanceMode.standard =>
                        l10n.performanceModeStandard,
                      DevicePerformanceMode.reduced =>
                        l10n.performanceModeReduced,
                    },
                  ),
                  if (PlatformDetection.isTV)
                    EnumPreferenceTile<RendererMode>(
                      preference: UserPreferences.rendererMode,
                      title: l10n.rendererMode,
                      description: l10n.rendererModeSubtitle,
                      icon: Icons.brush_outlined,
                      labelOf: (v) => switch (v) {
                        RendererMode.auto => l10n.rendererModeAuto,
                        RendererMode.skia => l10n.rendererModeSkia,
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
