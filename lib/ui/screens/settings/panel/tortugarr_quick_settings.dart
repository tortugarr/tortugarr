part of '../settings_side_panel.dart';

/// Tortugarr's own quick settings. They used to sit as loose rows on top of
/// the settings panel; the groups below (Administration, Language, and the
/// Startup and Browsing sections under Appearance) share them through this
/// mixin.
mixin _TortugarrQuickSettings<T extends StatefulWidget> on State<T> {
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

  bool get _shortIntro => _userPrefs.get(UserPreferences.shortIntro);

  Future<void> _toggleShortIntro() async {
    await _userPrefs.set(UserPreferences.shortIntro, !_shortIntro);
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

  Widget _switchTrailing(bool value) => ExcludeFocus(
        child: IgnorePointer(
          child: Switch(value: value, onChanged: (_) {}),
        ),
      );

  List<_PanelEntry> _languageEntries() => [
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
          trailing: _switchTrailing(_hideForeign),
          onTap: () => unawaited(_toggleHideForeign()),
        ),
        if (_hideForeign)
          _PanelEntry(
            icon: Icons.checklist,
            title: appL10n().tgDiscoveryLanguages,
            subtitle: _discoveryLanguagesSummary(),
            onTap: () => unawaited(_pickDiscoveryLanguages()),
          ),
        if (_hideForeign)
          _PanelEntry(
            icon: Icons.bug_report,
            title: appL10n().tgShowHidden,
            subtitle: _previewForeign ? appL10n().tgShowHiddenOn : appL10n().tgShowHiddenOff,
            trailing: _switchTrailing(_previewForeign),
            onTap: () => unawaited(_togglePreviewForeign()),
          ),
        _PanelEntry(
          icon: Icons.label_outline,
          title: appL10n().tgShowLanguageBadges,
          subtitle: _showLanguageBadges
              ? appL10n().tgShowLanguageBadgesOn
              : appL10n().tgShowLanguageBadgesOff,
          trailing: _switchTrailing(_showLanguageBadges),
          onTap: () => unawaited(_toggleShowLanguageBadges()),
        ),
        _PanelEntry(
          icon: Icons.subtitles,
          title: appL10n().tgShowAllSubLangs,
          subtitle: _showAllSubtitleLanguages
              ? appL10n().tgShowAllSubLangsOn
              : appL10n().tgShowAllSubLangsOffChosen,
          trailing: _switchTrailing(_showAllSubtitleLanguages),
          onTap: () => unawaited(_toggleShowAllSubtitleLanguages()),
        ),
        if (!_showAllSubtitleLanguages)
          _PanelEntry(
            icon: Icons.checklist,
            title: appL10n().tgSubtitleLanguages,
            subtitle: _subtitleLanguagesSummary(),
            onTap: () => unawaited(_pickSubtitleLanguages()),
          ),
      ];

  List<_PanelEntry> _startupEntries() => [
        _PanelEntry(
          icon: Icons.movie_outlined,
          title: appL10n().tgShortIntro,
          subtitle: _shortIntro ? appL10n().tgShortIntroOn : appL10n().tgShortIntroOff,
          trailing: _switchTrailing(_shortIntro),
          onTap: () => unawaited(_toggleShortIntro()),
        ),
        _PanelEntry(
          icon: Icons.photo_size_select_large,
          title: appL10n().tgLoadingLogoSize,
          subtitle: '${appL10n().tgLoadingLogoSizeSubtitle} · $_loadingLogoScale %',
          onTap: () => unawaited(_pickLoadingLogoScale()),
        ),
      ];

  List<_PanelEntry> _browsingEntries() => [
        _PanelEntry(
          icon: Icons.volume_up,
          title: appL10n().tgPreviewSound,
          subtitle: _previewAudio ? appL10n().tgPreviewSoundOn : appL10n().tgPreviewSoundOff,
          trailing: _switchTrailing(_previewAudio),
          onTap: () => unawaited(_togglePreviewAudio()),
        ),
        _PanelEntry(
          icon: Icons.playlist_add_check,
          title: appL10n().tgShowMissingEpisodes,
          subtitle: _showMissingEpisodes
              ? appL10n().tgShowMissingEpisodesOn
              : appL10n().tgShowMissingEpisodesOff,
          trailing: _switchTrailing(_showMissingEpisodes),
          onTap: () => unawaited(_toggleShowMissingEpisodes()),
        ),
        _PanelEntry(
          icon: Icons.movie_filter_outlined,
          title: appL10n().tgShowCollections,
          subtitle: _showMovieCollections
              ? appL10n().tgShowCollectionsOn
              : appL10n().tgShowCollectionsOff,
          trailing: _switchTrailing(_showMovieCollections),
          onTap: () => unawaited(_toggleShowMovieCollections()),
        ),
      ];
}

/// One settings page built from [_PanelEntry] rows.
Widget _entryListScreen(
  BuildContext context, {
  required String title,
  required FocusScopeNode scope,
  required List<_PanelEntry> entries,
}) {
  return Scaffold(
    appBar: buildSettingsAppBar(context, Text(title)),
    body: FocusScope(
      node: scope,
      autofocus: true,
      child: ListView(
        children: [
          adaptiveListSection(
            children: [
              for (final (i, entry) in entries.indexed)
                _TvSettingsListTile(
                  autofocus: i == 0,
                  leading: Icon(entry.icon),
                  title: Text(entry.title),
                  subtitle: Text(entry.subtitle),
                  trailing: entry.trailing ?? const Icon(Icons.chevron_right),
                  onTap: entry.onTap,
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Administration: the Jellyfin admin panel and the server-wide Tortugarr
/// settings. Only administrators see the entry.
class _TortugarrAdminScreen extends StatefulWidget {
  final VoidCallback openAdmin;

  const _TortugarrAdminScreen({required this.openAdmin});

  @override
  State<_TortugarrAdminScreen> createState() => _TortugarrAdminScreenState();
}

class _TortugarrAdminScreenState extends State<_TortugarrAdminScreen>
    with _TortugarrQuickSettings {
  final _scope = FocusScopeNode(
    debugLabel: 'TortugarrAdminScope',
    traversalEdgeBehavior: TraversalEdgeBehavior.stop,
  );

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _entryListScreen(
      context,
      title: l10n.administration,
      scope: _scope,
      entries: [
        _PanelEntry(
          icon: Icons.admin_panel_settings,
          title: appL10n().tgAdminPanel,
          subtitle: l10n.settingsAdministrationSubtitle,
          onTap: widget.openAdmin,
        ),
        if (DownloadFeatures.freeSpace)
          _PanelEntry(
            icon: Icons.storage,
            title: appL10n().tgDiskSpace,
            subtitle: appL10n().tgDiskSpaceSubtitle,
            onTap: () => unawaited(showManualFreeSpaceDialog(context)),
          ),
        // Showing/hiding the adult library only uses Jellyfin, so the public
        // build has it too; its download part follows the plugin.
        _PanelEntry(
          icon: Icons.no_adult_content,
          title: appL10n().tgAdultTitle,
          subtitle: appL10n().tgAdultSubtitle,
          onTap: () => unawaited(showAdultLibraryDialog(context)),
        ),
        // The plugin's quality minimum; the private build filters in the app.
        if (DownloadFeatures.viaPlugin && DownloadFeatures.downloadNow)
          _PanelEntry(
            icon: Icons.sd_outlined,
            title: appL10n().tgShowSdReleases,
            subtitle: _showSdReleases ? appL10n().tgShowSdReleasesOn : appL10n().tgShowSdReleasesOff,
            trailing: _switchTrailing(_showSdReleases),
            onTap: () => unawaited(_toggleShowSdReleases()),
          ),
      ],
    );
  }
}

/// Language: the app language, which titles show, and which subtitle
/// languages the menus offer.
class _TortugarrLanguageScreen extends StatefulWidget {
  const _TortugarrLanguageScreen();

  @override
  State<_TortugarrLanguageScreen> createState() =>
      _TortugarrLanguageScreenState();
}

class _TortugarrLanguageScreenState extends State<_TortugarrLanguageScreen>
    with _TortugarrQuickSettings {
  final _scope = FocusScopeNode(
    debugLabel: 'TortugarrLanguageScope',
    traversalEdgeBehavior: TraversalEdgeBehavior.stop,
  );

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _entryListScreen(
        context,
        title: appL10n().tgLanguageGroup,
        scope: _scope,
        entries: _languageEntries(),
      );
}
