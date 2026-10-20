part of '../settings_side_panel.dart';

class _AboutCategoryScreen extends StatelessWidget {
  const _AboutCategoryScreen();

  @override
  Widget build(BuildContext context) {
    final appVersion = GetIt.instance<DeviceInfo>().appVersion;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: buildSettingsAppBar(context, Text(l10n.aboutTitle)),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          Center(
            child: Image.asset('assets/images/logo_and_text.png', height: 120),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              l10n.versionValue(appVersion),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          _SectionHeader(l10n.settingsAppInfo),
          _TvSettingsListTile(
            leading: const Icon(Icons.code),
            title: Text(l10n.tgProjectOnGitHub),
            subtitle: Text(
              '${l10n.tgProjectOnGitHubSubtitle}\n$_tortugarrGitHub',
              style: const TextStyle(fontSize: 13),
            ),
            onTap: () => showQrOrLaunch(
              context,
              url: _tortugarrGitHub,
              title: l10n.tgProjectOnGitHub,
            ),
          ),
          // GPL attribution: keep this credit to Moonfin.
          _TvSettingsListTile(
            leading: const Icon(Icons.apps),
            title: Text(l10n.settingsBuiltOnOriginal),
            subtitle: Text(
              '${l10n.tgBuiltOnMoonfinCredit}\n$_moonfinGitHub',
              style: const TextStyle(fontSize: 13),
            ),
            onTap: () => showQrOrLaunch(
              context,
              url: _moonfinGitHub,
              title: l10n.settingsBuiltOnOriginal,
            ),
          ),
          _SectionHeader(l10n.tgCredits),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.tgCreditsThanks,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
          for (final credit in _credits(l10n))
            _TvSettingsListTile(
              leading: const Icon(Icons.favorite_border),
              title: Text(credit.name),
              subtitle: Text(
                '${credit.role}\n${credit.url}',
                style: const TextStyle(fontSize: 13),
              ),
              onTap: () => showQrOrLaunch(
                context,
                url: credit.url,
                title: credit.name,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              l10n.tgTmdbNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          // TMDB's terms specify this exact English sentence; keep it under the
          // translation in every language.
          if (l10n.tgTmdbNotice != _tmdbNoticeEnglish)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _tmdbNoticeEnglish,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          adaptiveListSection(
            children: [
              // Removed: Check for Updates, Source Code, Report an Issue, Join Discord, Support Moonfin, Licenses, Privacy Policy.
            ],
          ),
          _SectionHeader(l10n.settingsLegal),
          adaptiveListSection(
            children: [
              // Removed: Licenses, Privacy Policy.
            ],
          ),
          const Divider(),
          _SectionHeader(l10n.tgAboutProjectTitle),
          // One focus stop per paragraph, so the remote can scroll down to the
          // text below the last tile. A single focusable block is taller than
          // the panel and scrolls to its end, which hid the first lines.
          // TvFocusHighlight marks the paragraph and scrolls it to the same
          // spot as any tile, so up undoes down step by step.
          for (final paragraph in l10n.tgAboutProjectBody.split('\n\n'))
            TvFocusHighlight(
              builder: (context, focused) => Focus(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Text(
                    paragraph,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: focused && settingsTileInvertsOnFocus
                              ? AppColors.black.withValues(alpha: 0.87)
                              : null,
                        ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

const _tortugarrGitHub = 'https://github.com/tortugarr';
const _moonfinGitHub = 'https://github.com/Moonfin-Client/Moonfin-Core';
const _tmdbNoticeEnglish =
    'This product uses the TMDB API but is not endorsed or certified by TMDB.';

class _Credit {
  final String name;
  final String role;
  final String url;
  const _Credit(this.name, this.role, this.url);
}

/// The open-source projects and services Tortugarr builds on. Moonfin stays
/// first: the GPL requires the attribution.
List<_Credit> _credits(AppLocalizations l10n) => [
      _Credit('Moonfin', l10n.tgCreditMoonfin, _moonfinGitHub),
      _Credit('Jellyfin', l10n.tgCreditJellyfin, 'https://jellyfin.org'),
      _Credit('Seerr / Jellyseerr', l10n.tgCreditSeerr, 'https://github.com/seerr-team/seerr'),
      _Credit('Radarr', l10n.tgCreditRadarr, 'https://radarr.video'),
      _Credit('Sonarr', l10n.tgCreditSonarr, 'https://sonarr.tv'),
      _Credit('Prowlarr', l10n.tgCreditProwlarr, 'https://prowlarr.com'),
      _Credit('Bazarr', l10n.tgCreditBazarr, 'https://www.bazarr.media'),
      _Credit('FlareSolverr', l10n.tgCreditFlareSolverr, 'https://github.com/FlareSolverr/FlareSolverr'),
    ];

class _CheckForUpdatesTile extends StatefulWidget {
  const _CheckForUpdatesTile();

  @override
  State<_CheckForUpdatesTile> createState() => _CheckForUpdatesTileState();
}

class _CheckForUpdatesTileState extends State<_CheckForUpdatesTile> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    await checkAndShowUpdateResult(context);
    if (!mounted) return;
    setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _TvSettingsListTile(
      leading: _checking
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.system_update_alt),
      title: Text(l10n.settingsCheckForUpdates),
      subtitle: Text(l10n.settingsCheckForUpdatesSubtitle),
      onTap: _checking ? null : _check,
    );
  }
}
