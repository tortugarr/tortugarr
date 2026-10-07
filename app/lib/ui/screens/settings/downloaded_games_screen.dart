import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../l10n/app_localizations.dart';
import '../../../util/game_storage.dart';
import '../../../util/platform_detection.dart';
import '../../widgets/adaptive/adaptive_dialog.dart';
import '../../widgets/adaptive/adaptive_list_section.dart';
import '../../widgets/focus/request_initial_focus.dart';
import '../../widgets/overlay_sheet.dart';
import '../../widgets/settings/clean_settings_typography.dart';
import '../../widgets/settings/preference_tiles.dart';
import 'settings_app_bar.dart';

/// Lists the games whose files are sitting on this device so they can be
/// removed. Native playback copies the whole ROM down before it starts, and DS
/// cartridges in particular are large enough to fill a TV on their own.
class DownloadedGamesScreen extends StatefulWidget {
  const DownloadedGamesScreen({super.key});

  @override
  State<DownloadedGamesScreen> createState() => _DownloadedGamesScreenState();
}

class _DownloadedGamesScreenState extends State<DownloadedGamesScreen> {
  final FocusNode _firstTileFocusNode = FocusNode(debugLabel: 'first_game_tile');

  List<CachedGame>? _games;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstTileFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final games = await GameStorage.list();
    if (mounted) setState(() => _games = games);
  }

  Future<bool> _confirm(String message) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showFocusRestoringDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog.adaptive(
        title: Text(l10n.downloadedGames),
        content: Text(message),
        actions: [
          adaptiveDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _remove(CachedGame game) async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.removeDownloadedGameConfirm(game.title))) return;
    await GameStorage.delete(game);
    await _load();
  }

  Future<void> _removeAll() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.removeAllDownloadedGamesConfirm)) return;
    await GameStorage.deleteAll();
    await _load();
  }

  @override
  Widget build(BuildContext context) => RequestInitialFocus(
        targetNode: PlatformDetection.isTV ? _firstTileFocusNode : null,
        child: _buildContent(context),
      );

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final games = _games;
    return withCleanSettingsTypography(
      context,
      Scaffold(
        appBar: buildSettingsAppBar(context, Text(l10n.downloadedGames)),
        body: games == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(l10n.downloadedGamesDescription),
                  ),
                  if (games.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                      child: Text(l10n.downloadedGamesEmpty),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        l10n.downloadedGamesTotal(
                          games.length,
                          formatBytes(games.fold(0, (a, b) => a + b.bytes)),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    adaptiveListSection(
                      children: [
                        for (var i = 0; i < games.length; i++)
                          _buildGameTile(games[i], first: i == 0),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: OutlinedButton.icon(
                        onPressed: _removeAll,
                        icon: const Icon(Icons.delete_sweep),
                        label: Text(l10n.removeAllDownloadedGames),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildGameTile(CachedGame game, {required bool first}) {
    final system = game.system;

    return TvFocusHighlight(
      builder: (_, focused) => ListTile(
        focusNode: first ? _firstTileFocusNode : null,
        leading: Icon(
          Icons.sports_esports,
          color: focused ? AppColors.black.withValues(alpha: 0.54) : null,
        ),
        title: Text(
          game.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: focused
                ? AppColors.black.withValues(alpha: 0.87)
                : AppColorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          system == null ? game.sizeLabel : '$system  •  ${game.sizeLabel}',
          style: TextStyle(
            color: focused ? AppColors.black.withValues(alpha: 0.54) : null,
          ),
        ),
        trailing: Icon(
          Icons.delete_outline,
          color: focused ? AppColors.black.withValues(alpha: 0.54) : null,
        ),
        // The whole row is the remove action so a remote can reach it without
        // having to focus a separate button.
        onTap: () => _remove(game),
      ),
    );
  }
}
