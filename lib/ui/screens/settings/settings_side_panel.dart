import 'dart:async';
import 'dart:convert';

import 'package:custom_tv_text_field/custom_tv_text_field.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoSlider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin_design/moonfin_design.dart';
import 'package:path_provider/path_provider.dart';
import 'package:server_core/server_core.dart' hide ImageType;
import 'package:url_launcher/url_launcher.dart';

import '../../../data/services/achievements_service.dart';
import '../../../data/services/auto_download_service.dart';
import '../../../data/services/plugin_sync_service.dart';
import '../../../data/services/tortugarr/download_features.dart';
import '../../../data/services/custom_external_lists_service.dart';
import '../../../data/services/topshelf_service.dart';
import '../../../data/models/media_segment.dart';
import '../../../data/utils/media_segment_actions.dart';
import '../../../data/repositories/seerr_repository.dart';
import '../../../data/services/seerr/seerr_discover_sliders.dart';
import '../../../di/providers.dart';
import '../../../util/idiom/app_ui_idiom.dart';
import '../../../util/insecure_certificates.dart';
import '../../../platform/web_runtime_config.dart';
import '../../../playback/display_hdr_probe.dart';
import '../../../util/focus/dpad_keys.dart';
import '../../../util/focus/gamepad/gamepad_navigation_scope.dart';
import '../../../util/language_codes.dart';
import '../../../util/locale_names.dart';
import '../../util/home_row_title_localizer.dart';
import '../../../util/locale_english_names.dart';
import '../../../util/overlay_color_palette.dart';
import '../../../util/game_cores.dart';
import '../../../util/platform_detection.dart';
import '../../../util/playback_time_label.dart';
import '../../../util/app_beta.dart';
import '../../../util/subtitle_track_logic.dart';
import '../../../util/app_distribution.dart';
import '../../../util/pin_code_util.dart';
import '../../widgets/pin_entry_dialog.dart';
import '../../widgets/app_update_dialog.dart';

import '../../../auth/store/authentication_preferences.dart';
import '../../../auth/store/client_certificate_store.dart';
import '../../../auth/repositories/server_repository.dart';
import '../../../data/services/client_certificate_service.dart';
import '../../../util/server_url.dart';
import '../../../auth/repositories/session_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../util/error_message.dart';
import '../../../playback/audio_capability_profile.dart';
import '../../../playback/audio_capability_probe.dart';
import '../../../playback/device_profile_builder.dart';
import '../../../playback/external_player_service.dart';
import '../../../playback/letterbox_croppers.dart';
import '../../../preference/bottom_nav_tabs.dart';
import '../../../preference/preference_constants.dart';
import '../../../preference/user_preferences.dart';
import '../../../preference/home_section_config.dart';
import '../../../preference/seerr_preferences.dart';
import '../../../preference/seerr_row_config.dart';
import '../../navigation/destinations.dart';
import '../admin/admin_nav.dart';
import '../setup/setup_wizard_gate.dart';
import '../../navigation/home_refresh_bus.dart';
import '../../widgets/adaptive/adaptive_dialog.dart';
import '../../widgets/adaptive/adaptive_list_section.dart';
import '../../widgets/keyboard_shortcuts/keyboard_shortcut_reference.dart';
import '../../widgets/overlay_sheet.dart';
import '../../widgets/client_certificate_dialog.dart';
import '../../widgets/playback/playback_time_row.dart';
import '../../widgets/playback/player_loading_overlay.dart';
import '../../widgets/playback/loading_animation_widget.dart';
import '../../widgets/settings/preference_binding.dart';
import '../../widgets/settings/clean_settings_typography.dart';
import '../../widgets/settings/button_layout_list.dart';
import '../../widgets/settings/preference_tiles.dart';
import '../../widgets/settings/settings_panel.dart';
import '../../widgets/settings/settings_section_header.dart';
import '../../widgets/bottom_nav/bottom_nav_destinations.dart';
import '../../widgets/navigation_layout.dart';
import '../../widgets/support_dialog.dart';
import '../../widgets/trickplay_settings_preview.dart';
import '../../widgets/download_now/free_space_dialog.dart';
import '../../widgets/adult_library_dialog.dart';
import '../../widgets/focus/request_initial_focus.dart';
import '../home/home_view_model.dart';
import 'appearance_theme_screen.dart';
import 'diagnostics_settings_screen.dart';
import 'download_settings_screen.dart';
import 'saved_themes_screen.dart';
import 'theme_store_screen.dart';
import 'home_sections_screen.dart';
import 'home_row_toggles_screen.dart';
import 'home_rows_image_type_screen.dart';
import 'emulator_cores_screen.dart';
import 'achievements_screen.dart';
import 'downloaded_games_screen.dart';
import 'library_order_screen.dart';
import 'library_settings_screen.dart';
import 'media_bar_settings_screen.dart';
import 'screensaver_settings_screen.dart';
import 'parental_settings_screen.dart';
import 'pin_code_settings_screen.dart';
import 'plugin_settings_screen.dart';
import 'ratings_config_screen.dart';
import 'seerr_config_screen.dart';
import 'settings_app_bar.dart';
import 'subtitle_customization_screen.dart';
import 'subtitle_settings_screen.dart';
import '../../../preference/detail_metadata_layout.dart';
import '../../../preference/detail_section_layout.dart';
import '../detail/detail_buttons.dart';
import '../playback/osd_buttons.dart';
import '../syncplay/syncplay_screen.dart';
import 'package:moonfin/util/app_l10n.dart';

part 'panel/settings_panel_infra.dart';
part 'panel/settings_search_field.dart';
part 'panel/settings_search_index.dart';
part 'panel/account_screen.dart';
part 'panel/general_screen.dart';
part 'panel/appearance_screen.dart';
part 'panel/details_screen_settings_screen.dart';
part 'panel/navigation_category_screen.dart';
part 'panel/bottom_nav_tabs_screen.dart';
part 'panel/home_screen_category_screen.dart';
part 'panel/libraries_category_screen.dart';
part 'panel/seasonal_effects_screen.dart';
part 'panel/loading_animation_screen.dart';
part 'panel/services_screen.dart';
part 'panel/external_lists_screen.dart';
part 'panel/plugin_screen.dart';
part 'panel/about_category_screen.dart';
part 'panel/keyboard_shortcuts_screen.dart';
part 'panel/playback_category_screen.dart';
part 'panel/video_playback_screen.dart';
part 'panel/quality_decoding_screen.dart';
part 'panel/playback_time_layout_screen.dart';
part 'panel/osd_buttons_screen.dart';
part 'panel/detail_buttons_screen.dart';
part 'panel/detail_metadata_screen.dart';
part 'panel/detail_sections_screen.dart';
part 'panel/audio_preferences_screen.dart';
part 'panel/automation_queue_screen.dart';
part 'panel/advanced_options_screen.dart';
part 'panel/syncplay_settings_screen.dart';
part 'panel/settings_panel_tiles.dart';

bool get _showThemeEditorEntry =>
    PlatformDetection.isWeb && webRuntimeConfig.pluginMode;

Uri _resolveThemeEditorUri() {
  final base = Uri.base;
  final path = base.path;
  final markerIndex = path.toLowerCase().indexOf('/moonfin/web');

  final prefix = markerIndex >= 0 ? path.substring(0, markerIndex) : '';

  return Uri(
    scheme: base.scheme,
    userInfo: base.userInfo,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: '$prefix/Moonfin/Web/theme/index.html',
  );
}

Future<void> _openThemeEditor(BuildContext context) async {
  final uri = _resolveThemeEditorUri();
  final ok = await launchUrl(
    uri,
    mode: PlatformDetection.isWeb
        ? LaunchMode.platformDefault
        : LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );

  if (!ok && context.mounted) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.adminCouldNotOpenUrl('$uri'))),
    );
  }
}

class SettingsSidePanel extends ConsumerStatefulWidget {
  const SettingsSidePanel({super.key});

  @override
  ConsumerState<SettingsSidePanel> createState() => _SettingsSidePanelState();
}

class _SettingsSidePanelState extends ConsumerState<SettingsSidePanel> {
  // The panel opens on its top entry. Admins and other users get a node of
  // their own: the admin entries can appear on top after the panel opened.
  final _firstFocusNode = FocusNode(debugLabel: 'TvSettingsPanelFirstItem');
  final _firstUserFocusNode = FocusNode(debugLabel: 'TvSettingsPanelFirstUserItem');

  FocusNode get _topNode => _shownAsAdmin == true ? _firstFocusNode : _firstUserFocusNode;
  final _searchController = TextEditingController();
  final _searchFieldFocus = FocusNode(debugLabel: 'SettingsSearchField');
  final _searchTvFieldKey = GlobalKey<CustomTVTextFieldState>();
  String _query = '';

  /// The admin check can finish after the panel opened; the admin entries
  /// then appear on top and the first-item focus has to follow them, or it
  /// is left on whatever entry slid into its old place.
  bool? _shownAsAdmin;

  /// Turns Kids Mode off once the PIN checks out. The PIN is the whole
  /// boundary, so a missing one leaves the mode on rather than opening it up.
  Future<void> _exitKidsMode(BuildContext context) async {
    final prefs = GetIt.instance<UserPreferences>();
    final userId = GetIt.instance<SessionRepository>().activeUserId ?? '';
    final pin = PinCodeUtil.kidsMode(GetIt.instance<PreferenceStore>(), userId);

    if (pin.isPinEnabled) {
      final verified = await PinEntryDialog.show(
        context,
        mode: PinEntryMode.verify,
        onVerify: pin.verifyPin,
        onFailedAttempt: pin.registerFailedAttempt,
        lockoutRemaining: () => pin.lockoutRemaining,
      );
      if (!verified) return;
    }

    await prefs.set(UserPreferences.kidsModeEnabled, false);
    // The PIN belonged to this stretch of the mode. Clearing it means the next
    // time Kids Mode goes on, someone picks a code for it rather than a
    // forgotten one still quietly being the way out.
    await pin.removePin();
  }

  void _openAdmin(BuildContext context) =>
      closeThenNavigateTopLevel(context, _closeSettingsPanel, Destinations.admin);

  void _closeSettingsPanel() {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    if (rootNavigator.canPop()) {
      rootNavigator.pop();
    }
  }

  void _requestInitialFocus({int attempt = 0}) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final focusScope = FocusScope.of(context);
      final node = _topNode;
      if (node.context == null && attempt < 10) {
        Future<void>.delayed(const Duration(milliseconds: 16), () {
          _requestInitialFocus(attempt: attempt + 1);
        });
        return;
      }
      node.requestFocus();
      focusScope.requestFocus(node);
    });
  }

  @override
  void initState() {
    super.initState();
    if (!PlatformDetection.useMobileUi) {
      _requestInitialFocus();
    }
    _searchController.addListener(_onSearchChanged);
    if (PlatformDetection.useDesktopUi) {
      // Attached to the node so it runs before the text field consumes the
      // key. Down leaves the field for the list, left and right stay caret
      // moves.
      _searchFieldFocus.onKeyEvent = _onDesktopSearchKey;
    }
  }

  bool get _hideForeign =>
      GetIt.instance<SeerrPreferences>().hideForeignContent;

  Future<void> _toggleHideForeign() async {
    await GetIt.instance<SeerrPreferences>().setHideForeignContent(
      !_hideForeign,
    );
    if (mounted) setState(() {});
    homeRefreshBus.requestNowOrAfterNavigation();
  }

  bool get _previewForeign =>
      GetIt.instance<SeerrPreferences>().previewForeignContent;

  Future<void> _togglePreviewForeign() async {
    await GetIt.instance<SeerrPreferences>().setPreviewForeignContent(
      !_previewForeign,
    );
    if (mounted) setState(() {});
    homeRefreshBus.requestNowOrAfterNavigation();
  }

  bool get _showAllSubtitleLanguages =>
      GetIt.instance<SeerrPreferences>().showAllSubtitleLanguages;

  Future<void> _toggleShowAllSubtitleLanguages() async {
    await GetIt.instance<SeerrPreferences>().setShowAllSubtitleLanguages(
      !_showAllSubtitleLanguages,
    );
    if (mounted) setState(() {});
  }

  String _subtitleLanguagesSummary() {
    final picked = GetIt.instance<SeerrPreferences>().subtitleMenuLanguageCodes;
    final names = subtitleMenuLanguages
        .where((l) => picked.contains(l.code))
        .map((l) => l.endonym)
        .join(', ');
    return appL10n().tgSubtitleLanguagesSubtitle(names.isEmpty ? '-' : names);
  }


  /// One row in the side-panel pickers: the same focus highlight as the
  /// settings tiles (so the d-pad position is visible on TV), and the chosen
  /// item drawn bold with a filled check/radio.
  Widget _choiceRow({
    required String label,
    required bool selected,
    required bool multi,
    required bool autofocus,
    required VoidCallback onTap,
  }) {
    return TvFocusHighlight(
      builder: (_, _) => ListTile(
        autofocus: autofocus,
        leading: Icon(
          multi
              ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
              : (selected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
        ),
        title: Text(
          label,
          style: selected ? const TextStyle(fontWeight: FontWeight.w700) : null,
        ),
        trailing: selected ? const Icon(Icons.check) : null,
        onTap: onTap,
      ),
    );
  }

  /// Checkbox list over the shared language list. Each change is saved right
  /// away through [onChanged].
  Future<void> _pickLanguages({
    required String title,
    required Set<String> initial,
    required Future<void> Function(Set<String>) onChanged,
    List<SubtitleMenuLanguage> languages = subtitleMenuLanguages,
  }) async {
    var picked = initial;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final (i, language) in languages.indexed)
                  _choiceRow(
                    label: language.endonym,
                    selected: picked.contains(language.code),
                    multi: true,
                    autofocus: i == 0,
                    onTap: () {
                      final next = Set.of(picked);
                      if (!next.remove(language.code)) next.add(language.code);
                      setDialogState(() => picked = next);
                      unawaited(onChanged(next));
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(appL10n().tgClose),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// Languages the subtitle menus show.
  Future<void> _pickSubtitleLanguages() {
    final prefs = GetIt.instance<SeerrPreferences>();
    return _pickLanguages(
      title: appL10n().tgSubtitleLanguages,
      initial: prefs.subtitleMenuLanguageCodes,
      onChanged: prefs.setSubtitleMenuLanguageCodes,
    );
  }

  String _discoveryLanguagesSummary() {
    final picked = GetIt.instance<SeerrPreferences>().discoveryLanguageCodes;
    final names = discoveryMenuLanguages
        .where((l) => picked.contains(l.code))
        .map((l) => l.endonym)
        .join(', ');
    return appL10n().tgDiscoveryLanguagesSubtitle(names.isEmpty ? '-' : names);
  }

  /// Original languages Trending, Popular and the other discovery rows keep.
  Future<void> _pickDiscoveryLanguages() async {
    final prefs = GetIt.instance<SeerrPreferences>();
    await _pickLanguages(
      title: appL10n().tgDiscoveryLanguages,
      initial: prefs.discoveryLanguageCodes,
      onChanged: prefs.setDiscoveryLanguageCodes,
      languages: discoveryMenuLanguages,
    );
    homeRefreshBus.requestNowOrAfterNavigation();
  }

  bool get _showLanguageBadges =>
      GetIt.instance<SeerrPreferences>().showLanguageBadges;

  Future<void> _toggleShowLanguageBadges() async {
    await GetIt.instance<SeerrPreferences>().setShowLanguageBadges(
      !_showLanguageBadges,
    );
    if (mounted) setState(() {});
    homeRefreshBus.requestNowOrAfterNavigation();
  }

  /// "System default" plus every locale the app ships, each in its own name
  /// (the same list as Account & Security > Interface language).
  Map<String, String> _interfaceLanguageOptions() {
    final options = <String, String>{
      'system': bilingualSystemDefaultLabel(appL10n().systemLanguageDefault),
    };
    String nameOf(Locale l) =>
        kLocaleDisplayNames[l.toLanguageTag()] ?? l.toLanguageTag();
    final locales = List<Locale>.from(AppLocalizations.supportedLocales)
      ..sort((a, b) => nameOf(a).toLowerCase().compareTo(nameOf(b).toLowerCase()));
    for (final locale in locales) {
      options[locale.toLanguageTag()] =
          bilingualLocaleLabel(locale.toLanguageTag(), nameOf(locale));
    }
    return options;
  }

  /// Settings > Interface language, also reachable here so it is easy to find.
  /// Saving the preference switches the app language at once.
  Future<void> _pickInterfaceLanguage() async {
    final options = _interfaceLanguageOptions();
    final current = _userPrefs.get(UserPreferences.languageOverride);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(appL10n().interfaceLanguage),
        content: SizedBox(
          width: 420,
          height: 480,
          child: ListView(
            children: [
              for (final entry in options.entries)
                _choiceRow(
                  label: entry.value,
                  selected: entry.key == current,
                  multi: false,
                  autofocus: entry.key == current,
                  onTap: () {
                    unawaited(_userPrefs.set(UserPreferences.languageOverride, entry.key));
                    Navigator.of(dialogContext).pop();
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(appL10n().tgClose),
          ),
        ],
      ),
    );
    if (mounted) setState(() {});
  }

  UserPreferences get _userPrefs => GetIt.instance<UserPreferences>();

  int get _loadingLogoScale =>
      (loadingLogoScale(_userPrefs.get(UserPreferences.loadingLogoScale)) * 100).round();

  /// Size of the spinning loading logo, 25-100 % in steps of 5.
  Future<void> _pickLoadingLogoScale() async {
    final current = _loadingLogoScale;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(appL10n().tgLoadingLogoSize),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (var v = 25; v <= 100; v += 5)
                _choiceRow(
                  label: '$v %',
                  selected: v == current,
                  multi: false,
                  autofocus: v == current,
                  onTap: () {
                    unawaited(_userPrefs.set(UserPreferences.loadingLogoScale, v));
                    Navigator.of(dialogContext).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// Sound for the clip that plays when you stop on a title while browsing
  /// (home row previews and media bar trailers). On by default.
  bool get _previewAudio => _userPrefs.get(UserPreferences.previewAudioEnabled);

  Future<void> _togglePreviewAudio() async {
    final value = !_previewAudio;
    await _userPrefs.set(UserPreferences.previewAudioEnabled, value);
    await _userPrefs.set(UserPreferences.mediaBarTrailerAudio, value);
    if (mounted) setState(() {});
  }

  bool get _showMissingEpisodes =>
      GetIt.instance<SeerrPreferences>().showMissingEpisodes;

  Future<void> _toggleShowMissingEpisodes() async {
    await GetIt.instance<SeerrPreferences>().setShowMissingEpisodes(
      !_showMissingEpisodes,
    );
    if (mounted) setState(() {});
  }

  bool get _showSdReleases => _userPrefs.get(UserPreferences.showSdReleases);

  Future<void> _toggleShowSdReleases() async {
    await _userPrefs.set(UserPreferences.showSdReleases, !_showSdReleases);
    if (mounted) setState(() {});
  }

  bool get _showMovieCollections =>
      GetIt.instance<SeerrPreferences>().showMovieCollections;

  Future<void> _toggleShowMovieCollections() async {
    await GetIt.instance<SeerrPreferences>().setShowMovieCollections(
      !_showMovieCollections,
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _firstFocusNode.dispose();
    _firstUserFocusNode.dispose();
    _searchController.dispose();
    _searchFieldFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query == _query) return;
    setState(() => _query = query);
    if (PlatformDetection.useMobileUi) return;
    // If the focused result just filtered away, fall back to the field so the
    // d-pad is never stranded on a dead node. Skipped while the TV keyboard
    // is up so it cannot pull key events away from the keyboard grid.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (CustomTVTextField.isKeyboardVisibleNotifier.value) return;
      final primary = FocusManager.instance.primaryFocus;
      if (primary == null || primary.context == null) {
        _searchFieldFocus.requestFocus();
      }
    });
  }

  KeyEventResult _onDesktopSearchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey.isDownKey) {
      return node.focusInDirection(TraversalDirection.down)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kidsMode = ref.watch(kidsModeProvider);
    // Tortugarr shows administration on TV too: the admin pages work with
    // the remote there.
    final showAdmin =
        !kidsMode && ref.watch(isAdminProvider) && adminServerSupported();
    final enablePanelAutofocus = !PlatformDetection.useMobileUi;
    if (_shownAsAdmin != null && _shownAsAdmin != showAdmin && enablePanelAutofocus) {
      _requestInitialFocus();
    }
    _shownAsAdmin = showAdmin;

    // Kids Mode leaves one entry standing. Hiding settings outright would
    // leave no way back, and a hidden gesture is worse than an obvious tile.
    // Otherwise: administration and Tortugarr's own quick settings first,
    // then Moonfin's setting groups.
    final entries = kidsMode
        ? <_PanelEntry>[
            _PanelEntry(
              icon: Icons.lock_open,
              title: l10n.kidsModeExit,
              subtitle: l10n.kidsModeExitSubtitle,
              onTap: () => unawaited(_exitKidsMode(context)),
            ),
          ]
        : <_PanelEntry>[
            if (showAdmin)
              _PanelEntry(
                icon: Icons.admin_panel_settings,
                title: l10n.administration,
                subtitle: l10n.settingsAdministrationSubtitle,
                onTap: () => _openAdmin(context),
              ),
            if (showAdmin && DownloadFeatures.freeSpace)
              _PanelEntry(
                icon: Icons.storage,
                title: appL10n().tgDiskSpace,
                subtitle: appL10n().tgDiskSpaceSubtitle,
                onTap: () => unawaited(showManualFreeSpaceDialog(context)),
              ),
            // Showing/hiding the adult library only uses Jellyfin, so the public
            // build has it too; its download part follows the plugin.
            if (showAdmin)
              _PanelEntry(
                icon: Icons.no_adult_content,
                title: appL10n().tgAdultTitle,
                subtitle: appL10n().tgAdultSubtitle,
                onTap: () => unawaited(showAdultLibraryDialog(context)),
              ),
            // The plugin's quality minimum; the private build filters in the app.
            if (showAdmin && DownloadFeatures.viaPlugin && DownloadFeatures.downloadNow)
              _PanelEntry(
                icon: Icons.sd_outlined,
                title: appL10n().tgShowSdReleases,
                subtitle: _showSdReleases ? appL10n().tgShowSdReleasesOn : appL10n().tgShowSdReleasesOff,
                trailing: ExcludeFocus(
                  child: IgnorePointer(
                    child: Switch(value: _showSdReleases, onChanged: (_) {}),
                  ),
                ),
                onTap: () => unawaited(_toggleShowSdReleases()),
              ),
            if (!kForceEnglish)
            _PanelEntry(
              icon: Icons.language,
              title: appL10n().interfaceLanguage,
              subtitle: _interfaceLanguageOptions()[
                      _userPrefs.get(UserPreferences.languageOverride)] ??
                  appL10n().systemLanguageDefault,
              onTap: () => unawaited(_pickInterfaceLanguage()),
            ),
            _PanelEntry(
              icon: Icons.translate,
              title: appL10n().tgHideForeign,
              subtitle: _hideForeign ? appL10n().tgHideForeignOnChosen : appL10n().tgHideForeignOff,
              trailing: ExcludeFocus(
                child: IgnorePointer(
                  child: Switch(value: _hideForeign, onChanged: (_) {}),
                ),
              ),
              onTap: () => unawaited(_toggleHideForeign()),
            ),
            if (_hideForeign)
              _PanelEntry(
                icon: Icons.checklist,
                title: appL10n().tgDiscoveryLanguages,
                subtitle: _discoveryLanguagesSummary(),
                onTap: () => unawaited(_pickDiscoveryLanguages()),
              ),
            _PanelEntry(
              icon: Icons.label_outline,
              title: appL10n().tgShowLanguageBadges,
              subtitle: _showLanguageBadges
                  ? appL10n().tgShowLanguageBadgesOn
                  : appL10n().tgShowLanguageBadgesOff,
              trailing: ExcludeFocus(
                child: IgnorePointer(
                  child: Switch(value: _showLanguageBadges, onChanged: (_) {}),
                ),
              ),
              onTap: () => unawaited(_toggleShowLanguageBadges()),
            ),
            if (_hideForeign)
              _PanelEntry(
                icon: Icons.bug_report,
                title: appL10n().tgShowHidden,
                subtitle: _previewForeign ? appL10n().tgShowHiddenOn : appL10n().tgShowHiddenOff,
                trailing: ExcludeFocus(
                  child: IgnorePointer(
                    child: Switch(value: _previewForeign, onChanged: (_) {}),
                  ),
                ),
                onTap: () => unawaited(_togglePreviewForeign()),
              ),
            _PanelEntry(
              icon: Icons.subtitles,
              title: appL10n().tgShowAllSubLangs,
              subtitle: _showAllSubtitleLanguages
                  ? appL10n().tgShowAllSubLangsOn
                  : appL10n().tgShowAllSubLangsOffChosen,
              trailing: ExcludeFocus(
                child: IgnorePointer(
                  child: Switch(value: _showAllSubtitleLanguages, onChanged: (_) {}),
                ),
              ),
              onTap: () => unawaited(_toggleShowAllSubtitleLanguages()),
            ),
            if (!_showAllSubtitleLanguages)
              _PanelEntry(
                icon: Icons.checklist,
                title: appL10n().tgSubtitleLanguages,
                subtitle: _subtitleLanguagesSummary(),
                onTap: () => unawaited(_pickSubtitleLanguages()),
              ),
            _PanelEntry(
              icon: Icons.volume_up,
              title: appL10n().tgPreviewSound,
              subtitle: _previewAudio ? appL10n().tgPreviewSoundOn : appL10n().tgPreviewSoundOff,
              trailing: ExcludeFocus(
                child: IgnorePointer(
                  child: Switch(value: _previewAudio, onChanged: (_) {}),
                ),
              ),
              onTap: () => unawaited(_togglePreviewAudio()),
            ),
            if (PlatformDetection.isTV)
              _PanelEntry(
                icon: Icons.wallpaper,
                title: appL10n().tgScreensaver,
                subtitle: appL10n().tgScreensaverSubtitle,
                onTap: () =>
                    context.pushSettingsScreen(const ScreensaverSettingsScreen()),
              ),
            _PanelEntry(
              icon: Icons.photo_size_select_large,
              title: appL10n().tgLoadingLogoSize,
              subtitle: '${appL10n().tgLoadingLogoSizeSubtitle} · $_loadingLogoScale %',
              onTap: () => unawaited(_pickLoadingLogoScale()),
            ),
            _PanelEntry(
              icon: Icons.playlist_add_check,
              title: appL10n().tgShowMissingEpisodes,
              subtitle: _showMissingEpisodes
                  ? appL10n().tgShowMissingEpisodesOn
                  : appL10n().tgShowMissingEpisodesOff,
              trailing: ExcludeFocus(
                child: IgnorePointer(
                  child: Switch(value: _showMissingEpisodes, onChanged: (_) {}),
                ),
              ),
              onTap: () => unawaited(_toggleShowMissingEpisodes()),
            ),
            _PanelEntry(
              icon: Icons.movie_filter_outlined,
              title: appL10n().tgShowCollections,
              subtitle: _showMovieCollections
                  ? appL10n().tgShowCollectionsOn
                  : appL10n().tgShowCollectionsOff,
              trailing: ExcludeFocus(
                child: IgnorePointer(
                  child: Switch(value: _showMovieCollections, onChanged: (_) {}),
                ),
              ),
              onTap: () => unawaited(_toggleShowMovieCollections()),
            ),
            _PanelEntry(
              icon: Icons.lock,
              title: l10n.account,
              subtitle: l10n.settingsAccountSubtitle,
              onTap: () => context.pushSettingsScreen(const _AccountScreen()),
            ),
            _PanelEntry(
              icon: Icons.tune,
              title: l10n.general,
              subtitle: l10n.settingsGeneralSubtitle,
              onTap: () => context.pushSettingsScreen(const _GeneralScreen()),
            ),
            _PanelEntry(
              icon: Icons.palette,
              title: l10n.appearance,
              subtitle: l10n.settingsAppearanceSubtitle,
              onTap: () => context.pushSettingsScreen(const _AppearanceScreen()),
            ),
            _PanelEntry(
              icon: Icons.play_circle,
              title: l10n.playback,
              subtitle: l10n.settingsPlaybackSubtitle,
              onTap: () =>
                  context.pushSettingsScreen(const _PlaybackCategoryScreen()),
            ),
            // The image cache lives here, so the entry stays on every native
            // platform. The download sections inside gate themselves.
            if (!PlatformDetection.isWeb)
              _PanelEntry(
                icon: Icons.download_for_offline,
                title: l10n.storageAndDownloads,
                subtitle: l10n.settingsStorageSubtitle,
                onTap: () =>
                    context.pushSettingsScreen(const DownloadSettingsScreen()),
              ),
            _PanelEntry(
              icon: Icons.hub,
              title: l10n.integrations,
              subtitle: l10n.settingsServicesSubtitle,
              onTap: () => context.pushSettingsScreen(const _ServicesScreen()),
            ),
            _PanelEntry(
              icon: Icons.info_outline,
              title: l10n.aboutTitle,
              subtitle: l10n.settingsAboutSubtitle,
              onTap: () => context.pushSettingsScreen(const _AboutCategoryScreen()),
            ),
          ];
    if (enablePanelAutofocus && entries.isNotEmpty) {
      entries[0] = entries[0].withFocusNode(_topNode);
    }

    return Scaffold(
      appBar: AppBar(
        leading: PlatformDetection.isTV
            ? null
            : IconButton(
                onPressed: _closeSettingsPanel,
                icon: const Icon(Icons.close),
              ),
        automaticallyImplyLeading: false,
        title: Text(l10n.settings),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _SettingsSearchField(
              controller: _searchController,
              focusNode: _searchFieldFocus,
              tvFieldKey: _searchTvFieldKey,
              hint: l10n.settingsSearchHint,
              onClear: _searchController.clear,
            ),
          ),
          Expanded(
            child: (_query.isEmpty || kidsMode)
                ? ListView(
                    children: [
                      adaptiveListSection(
                        children: [
                          // Keyed by title: entries appear above others once
                          // the admin check and the preferences are in, and a
                          // tile must keep its own focus state, not inherit the
                          // one of whatever stood in its place before.
                          for (final entry in entries)
                            _PanelEntryTile(key: ValueKey(entry.title), entry: entry),
                        ],
                      ),
                    ],
                  )
                : _buildSearchResults(context, l10n, showAdmin),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    AppLocalizations l10n,
    bool showAdmin,
  ) {
    final index = _buildSettingsSearchIndex(
      l10n: l10n,
      showAdmin: showAdmin,
      showThemeEditor: _showThemeEditorEntry,
      push: (screen) => context.pushSettingsScreen(screen),
      openAdmin: () => _openAdmin(context),
      openThemeEditor: () => unawaited(_openThemeEditor(context)),
    );
    final results = _filterSettingsIndex(index, _query);
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.noResultsForQuery(_query)),
        ),
      );
    }
    return ListView(
      children: [
        adaptiveListSection(
          children: [
            for (final result in results)
              _TvSettingsListTile(
                key: ValueKey(result.id),
                leading: Icon(result.icon),
                title: Text(result.title),
                subtitle: result.subtitle.isEmpty
                    ? null
                    : Text(result.subtitle),
                onTap: () {
                  if (PlatformDetection.useMobileUi) {
                    _searchFieldFocus.unfocus();
                  }
                  result.onOpen();
                },
              ),
          ],
        ),
      ],
    );
  }
}
